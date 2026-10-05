--!strict
-- Enemies (docs/enemies_npcs_pets_brief.txt Part B, DESIGN.md section 5). Server authoritative: spawning, a 10 Hz AI,
-- movement, attacks, damage, Gold and loot. The client only draws them (Controllers/EnemyController).
--   EnemyService:GetNear(position, range) -> { EnemyState }   living enemies around a point (CombatService)
--   EnemyService:Damage(player, state, amount) -> died        a hit decided by CombatService
--   EnemyService:Stagger(state, seconds)                      Heavy slam
--   EnemyService:SetOccupied(occupied)                        ZoneService location loop: sub-zones with players
--   EnemyService:CreateGroup(key, opts) / Spawn(group, def, position, opts?) / Intro(state, s) / EndGroup(key)   boss rooms
--   EnemyService:SpawnNear(player, def) / KillAll(player)     admin
-- Per sub-zone 10 enemies are alive (types 4 / 3 / 3, sub-zone 4: 5 / 5) on the Spawns points (random free spots in
-- Area when a type has none); 2 s after a death a new one appears on a point at least 12 studs from every player.
-- A sub-zone without players pauses at once and despawns after Playtest.EmptySubZoneDespawnSeconds.
-- AI: Idle (wander) -> Chase (player within AggroRadius) -> Telegraph -> Attack -> Recover; Leash (target farther than
-- 60 studs from the spawn: walk back and heal to full). Bodies: ServerStorage.Enemies.<id> (or Bosses.<id>) when the
-- imported model exists, else a placeholder (Lib/EnemyRigs). The "Root" is moved by AlignPosition / AlignOrientation
-- with the server as network owner, so every client sees smooth movement; the ground is found by raycasts.
-- Replicated model attributes: EnemyId, Tier, HP, MaxHP, State, Telegraph (server time of the hit), Heavy, HitAt, Dead.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Playtest = require(ReplicatedStorage.GameSystem.Config.Playtest)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local EnemyRigs = require(script.Parent.Parent.Lib.EnemyRigs)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local LootService = require(script.Parent.LootService)
local RewardService = require(script.Parent.RewardService)

local EnemyService = { Priority = 5 }

local AI = Enemies.AI
local UP = Vector3.yAxis

export type Group = {
	key: string,
	kind: string, -- "subzone" | "arena" | "admin"
	enemies: { EnemyState },
	active: boolean,
	paused: boolean,
	emptySince: number?,
	area: BasePart?,
	points: { [string]: { Vector3 } },
	respawn: boolean,
	leash: boolean,
	players: { [Player]: boolean }?, -- arena: only these players are targets
	onDeath: ((EnemyState, Player?) -> ())?,
}

export type EnemyState = {
	def: any,
	model: Model,
	root: BasePart,
	align: AlignPosition,
	orient: AlignOrientation,
	group: Group,
	hp: number,
	maxHP: number,
	alive: boolean,
	radius: number,
	halfHeight: number,
	height: number,
	hover: number,
	speed: number,
	home: Vector3,
	position: Vector3, -- ground point under the body, updated every tick
	facing: Vector3,
	damage: { [Player]: number },
	lastHit: Player?,
	mode: string, -- AI state
	target: Player?,
	untilTime: number,
	nextAttack: number,
	nextHeavy: number,
	heavy: boolean,
	nextWander: number,
	wanderGoal: Vector3?,
	staggerUntil: number,
	invulnerableUntil: number,
	slot: number,
	progressAt: number,
	progressPos: Vector3,
	path: { Vector3 }?,
	pathIndex: number,
	pathing: boolean,
}

local groups: { [string]: Group } = {}
local container: Folder
local rng = Random.new()
local slotCounter = 0

-- Candidates of the current tick: living players with a root (not spectating).
type Candidate = { player: Player, root: BasePart, position: Vector3 }
local candidates: { Candidate } = {}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false

local CombatService: any = nil
local function combat(): any
	if not CombatService then
		CombatService = require(script.Parent.CombatService) :: any -- lazy: CombatService requires this module
	end
	return CombatService
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local f = flat(v)
	return if f.Magnitude > 1e-3 then f.Unit else fallback
end

local function refreshCandidates()
	table.clear(candidates)
	local ignore: { Instance } = { container }
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			table.insert(ignore, character)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and not player:GetAttribute("Spectating") then
				table.insert(candidates, { player = player, root = root, position = root.Position })
			end
		end
	end
	groundParams.FilterDescendantsInstances = ignore
end

-- Ground point under (or near) a position, or nil over the void.
local function ground(position: Vector3, above: number?): Vector3?
	local result = workspace:Raycast(position + UP * (above or 8), -UP * 60, groundParams)
	return if result then result.Position else nil
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function setMode(state: EnemyState, mode: string, untilTime: number?)
	if state.mode ~= mode then
		state.mode = mode
		state.model:SetAttribute("State", mode)
	end
	state.untilTime = untilTime or 0
end

local function face(state: EnemyState, dir: Vector3)
	local f = flat(dir)
	if f.Magnitude > 1e-3 then
		state.facing = f.Unit
		state.orient.CFrame = CFrame.lookAt(Vector3.zero, state.facing)
	end
end

local function halt(state: EnemyState)
	state.align.Position = state.root.Position
end

local function bodyHeight(state: EnemyState, floor: Vector3): Vector3
	return floor + UP * (state.halfHeight + state.hover)
end

-- Push away from the other enemies of the group that overlap this one (flat vector, 0 when free).
local function separation(state: EnemyState): Vector3
	local push = Vector3.zero
	for _, other in ipairs(state.group.enemies) do
		if other ~= state and other.alive then
			local offset = flat(state.position - other.position)
			local distance = offset.Magnitude
			local wanted = (state.radius + other.radius) * 0.85
			if distance < wanted then
				local away = if distance > 1e-3 then offset / distance else Vector3.new(math.cos(state.slot), 0, math.sin(state.slot))
				push += away * (wanted - distance) / wanted
			end
		end
	end
	return push
end

-- Small sideways step out of a crowd while standing still.
local function nudge(state: EnemyState)
	local push = separation(state)
	if push.Magnitude < 0.05 then
		return
	end
	local floor = ground(state.position + push.Unit * math.min(1.5, push.Magnitude * 2))
	if floor and math.abs(floor.Y - state.position.Y) < 3 then
		state.align.MaxVelocity = state.speed * 0.5
		state.align.Position = bodyHeight(state, floor)
	end
end

-- One step of movement toward goal (obstacle steering, ground snapping, stuck -> pathfinding).
local function moveToward(state: EnemyState, goal: Vector3, speed: number, now: number)
	local pos = state.position
	if state.path then
		local waypoint = state.path[state.pathIndex]
		if waypoint and flat(waypoint - pos).Magnitude < 2 then
			state.pathIndex += 1
			waypoint = state.path[state.pathIndex]
		end
		if waypoint then
			goal = waypoint
		else
			state.path = nil
		end
	end
	local offset = flat(goal - pos)
	local distance = offset.Magnitude
	if distance < 0.4 then
		halt(state)
		return
	end
	local dir = offset / distance
	local push = separation(state)
	if push.Magnitude > 0.05 then
		dir = flatUnit(dir + push * 1.2, dir)
	end
	-- steering: try the straight line, then 45 and 90 degrees on each side
	local eye = pos + UP * math.clamp(state.halfHeight + state.hover, 1, 4)
	local probe = state.radius + 2
	local chosen: Vector3? = nil
	for _, angle in ipairs({ 0, 45, -45, 90, -90 }) do
		local candidate = if angle == 0 then dir else (CFrame.Angles(0, math.rad(angle), 0) * dir)
		local hit = workspace:Raycast(eye, candidate * probe, groundParams)
		if not hit or hit.Normal.Y > 0.6 then
			chosen = candidate
			break
		end
	end
	local step = math.min(distance, speed * AI.LookAhead)
	local nextPos = if chosen then pos + chosen * step else pos
	local floor = if chosen then ground(nextPos) else nil
	if floor and (floor.Y - pos.Y > 4 or pos.Y - floor.Y > 12) then
		floor = nil -- wall or cliff
	end
	if floor and chosen then
		state.align.MaxVelocity = speed
		state.align.Position = bodyHeight(state, floor)
		face(state, chosen)
	else
		halt(state)
	end
	-- stuck detection: no progress for a while -> one pathfinding request
	if (pos - state.progressPos).Magnitude > 1 then
		state.progressPos = pos
		state.progressAt = now
	elseif now - state.progressAt > AI.StuckSeconds and not state.pathing and not state.path then
		state.pathing = true
		local from, to = pos, goal
		task.spawn(function()
			local path = PathfindingService:CreatePath({ AgentRadius = math.max(1, state.radius), AgentHeight = math.max(2, state.height), AgentCanJump = false })
			local ok = pcall(function()
				path:ComputeAsync(from, to)
			end)
			if ok and path.Status == Enum.PathStatus.Success and state.alive then
				local points = {}
				for _, waypoint in ipairs(path:GetWaypoints()) do
					table.insert(points, waypoint.Position)
				end
				state.path = points
				state.pathIndex = 2
			end
			state.progressAt = os.clock()
			state.pathing = false
		end)
	end
end

-- The imported model of this enemy when it exists, else the placeholder.
local function bodyOf(def: any): Model
	for _, folderName in ipairs({ "Enemies", "Bosses" }) do
		local folder = ServerStorage:FindFirstChild(folderName)
		local imported = folder and folder:FindFirstChild(def.Id)
		if imported and imported:IsA("Model") and imported.PrimaryPart then
			local clone = imported:Clone()
			if not clone:GetAttribute("HalfHeight") then
				clone:SetAttribute("HalfHeight", (clone.PrimaryPart :: BasePart).Size.Y / 2)
			end
			return clone
		end
	end
	return EnemyRigs.build(def)
end

local function setPhysics(state: EnemyState, running: boolean)
	state.root.Anchored = not running
	if running and state.root:IsDescendantOf(workspace) then
		pcall(function()
			state.root:SetNetworkOwner(nil)
		end)
	end
end

function EnemyService:Spawn(group: Group, def: any, at: Vector3, opts: { [string]: any }?): EnemyState
	local options = opts or {}
	local model = bodyOf(def)
	local root = model.PrimaryPart :: BasePart
	local halfHeight = model:GetAttribute("HalfHeight") or root.Size.Y / 2
	local hover = def.Hover or 0
	refreshCandidates()
	local floor = ground(at) or at
	local yaw = rng:NextNumber(0, math.pi * 2)
	local facing = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	local cframe = CFrame.lookAt(floor + UP * (halfHeight + hover), floor + UP * (halfHeight + hover) + facing)
	model:PivotTo(cframe * CFrame.new(0, -halfHeight, 0))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end
	local speed = def.WalkSpeed or 12
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = 1e8
	align.MaxVelocity = speed
	align.Responsiveness = 40
	align.Position = root.Position
	align.Parent = root
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = 1e9
	orient.Responsiveness = 18
	orient.CFrame = cframe.Rotation
	orient.Parent = root
	local maxHP = def.MaxHP * (options.hpMult or 1)
	local size = root.Size
	slotCounter += 1
	local state: EnemyState = {
		def = def, model = model, root = root, align = align, orient = orient, group = group,
		hp = maxHP, maxHP = maxHP, alive = true,
		radius = math.max(size.X, size.Z) / 2, halfHeight = halfHeight, height = halfHeight * 2, hover = hover, speed = speed,
		home = floor, position = floor, facing = facing, damage = {}, lastHit = nil,
		mode = "Idle", target = nil, untilTime = 0, nextAttack = 0, nextHeavy = os.clock() + 3, heavy = false,
		nextWander = os.clock() + rng:NextNumber(1, 4), wanderGoal = nil, staggerUntil = 0,
		invulnerableUntil = options.invulnerable and os.clock() + options.invulnerable or 0,
		slot = slotCounter, progressAt = os.clock(), progressPos = floor, path = nil, pathIndex = 1, pathing = false,
	}
	model:SetAttribute("EnemyId", def.Id)
	model:SetAttribute("Tier", def.Tier or "normal")
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("HP", maxHP)
	model:SetAttribute("State", "Idle")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- streams in and out as a whole
	model.Parent = container
	setPhysics(state, not group.paused)
	table.insert(group.enemies, state)
	return state
end

-- Random free ground spot inside a sub-zone Area, away from players.
local function randomSpot(area: BasePart): Vector3?
	local half = area.Size / 2
	for _ = 1, 20 do
		local local_ = Vector3.new(rng:NextNumber(-half.X + 10, half.X - 10), half.Y - 2, rng:NextNumber(-half.Z + 10, half.Z - 10))
		local top = area.CFrame:PointToWorldSpace(local_)
		local result = workspace:Raycast(top, -UP * (area.Size.Y + 20), groundParams)
		if result and result.Normal.Y > 0.7 then
			local far = true
			for _, candidate in ipairs(candidates) do
				if flat(candidate.position - result.Position).Magnitude < Enemies.RESPAWN_MIN_PLAYER_DISTANCE then
					far = false
					break
				end
			end
			if far then
				return result.Position
			end
		end
	end
	return nil
end

-- A spawn point of this enemy type at least RESPAWN_MIN_PLAYER_DISTANCE from every player.
local function spawnPoint(group: Group, def: any): Vector3?
	refreshCandidates()
	local points = group.points[def.Id] or {}
	local order = table.clone(points)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local best, bestDistance = nil, -1
	for _, point in ipairs(order) do
		local nearest = math.huge
		for _, candidate in ipairs(candidates) do
			nearest = math.min(nearest, flat(candidate.position - point).Magnitude)
		end
		if nearest >= Enemies.RESPAWN_MIN_PLAYER_DISTANCE then
			return point + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		end
		if nearest > bestDistance then
			best, bestDistance = point, nearest
		end
	end
	local spot = if group.area then randomSpot(group.area) else nil
	return spot or best
end

local function removeState(state: EnemyState)
	local index = table.find(state.group.enemies, state)
	if index then
		table.remove(state.group.enemies, index)
	end
end

local function topDealer(state: EnemyState): Player?
	local best, bestDamage = nil, -1
	for who, dealt in pairs(state.damage) do
		if who.Parent and (dealt > bestDamage or (dealt == bestDamage and who == state.lastHit)) then
			best, bestDamage = who, dealt
		end
	end
	return best
end

-- Gold, quests, Index and the loot roll of a normal enemy for its top damage dealer.
function EnemyService:Reward(player: Player, state: EnemyState)
	local profile = DataService:Get(player)
	if not profile then
		return
	end
	local stats = Stats.compute(profile, { now = os.time() })
	local gold = math.max(1, math.floor(state.def.Gold * (stats.GoldMult or 1) * Playtest.GoldMultiplier + 0.5))
	DataService:AddGold(player, gold)
	Net.fire(player, "EnemyKilled", state.root.Position + UP * state.halfHeight, gold)
	RewardService.progress(player, "KillEnemies", 1)
	RewardService.progress(player, "EarnGold", gold)
	IndexService:Discover(player, state.def.Id)
	LootService:Roll(player, state.def, stats.LootMult)
end

local function die(state: EnemyState)
	state.alive = false
	state.model:SetAttribute("Dead", true)
	state.model:SetAttribute("HP", 0)
	setMode(state, "Dead")
	state.root.Anchored = true
	removeState(state)
	local model = state.model
	task.delay(1.2, function()
		model:Destroy()
	end)
	local group = state.group
	local killer = topDealer(state)
	if group.onDeath then
		group.onDeath(state, killer)
	elseif killer then
		EnemyService:Reward(killer, state)
	end
	if group.respawn then
		local def = state.def
		task.delay(Enemies.RESPAWN_SECONDS, function()
			if group.active and groups[group.key] == group then
				local point = spawnPoint(group, def)
				if point then
					EnemyService:Spawn(group, def, point)
				end
			end
		end)
	end
end

-- A hit decided by CombatService. Returns true when the enemy died.
function EnemyService:Damage(player: Player, state: EnemyState, amount: number): boolean
	if not state.alive or amount ~= amount or amount <= 0 then
		return false
	end
	if os.clock() < state.invulnerableUntil then
		return false
	end
	local dealt = math.min(state.hp, amount)
	state.hp -= dealt
	state.damage[player] = (state.damage[player] or 0) + dealt
	state.lastHit = player
	RewardService.progress(player, "DealDamage", dealt)
	state.model:SetAttribute("HP", state.hp)
	state.model:SetAttribute("HitAt", serverNow())
	if state.hp <= 0 then
		die(state)
		return true
	end
	-- a hit pulls the enemy into the fight, a normal one is pushed back a little
	if not state.target and state.mode ~= "Leash" then
		state.target = player
	end
	if state.def.Tier == "normal" then
		local character = player.Character
		local from = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if from then
			local away = flatUnit(state.root.Position - from.Position, -state.facing)
			local floor = ground(state.position + away * AI.Knockback)
			if floor then
				state.align.Position = bodyHeight(state, floor)
			end
		end
	end
	return false
end

function EnemyService:Stagger(state: EnemyState, seconds: number)
	if state.alive and state.def.Tier ~= "boss" then
		state.staggerUntil = math.max(state.staggerUntil, os.clock() + seconds)
		if state.mode == "Telegraph" then
			setMode(state, "Chase") -- the stagger cancels the wind-up
		end
	end
end

-- Living enemies whose body is within range of a position (flat distance to the body edge).
function EnemyService:GetNear(position: Vector3, range: number): { EnemyState }
	local found = {}
	for _, group in pairs(groups) do
		if group.active and not group.paused then
			for _, state in ipairs(group.enemies) do
				if state.alive then
					local offset = state.root.Position - position
					if flat(offset).Magnitude <= range + state.radius and math.abs(offset.Y) < state.halfHeight + state.hover + 10 then
						table.insert(found, state)
					end
				end
			end
		end
	end
	return found
end

function EnemyService:All(): { EnemyState }
	local list = {}
	for _, group in pairs(groups) do
		for _, state in ipairs(group.enemies) do
			table.insert(list, state)
		end
	end
	return list
end

local function visualTo(origin: Vector3): { Player }
	local list = {}
	for _, candidate in ipairs(candidates) do
		if (candidate.position - origin).Magnitude <= AI.VisualRange then
			table.insert(list, candidate.player)
		end
	end
	return list
end

local function targetable(state: EnemyState, player: Player): boolean
	local only = state.group.players
	return only == nil or only[player] == true
end

local function candidateOf(player: Player?): Candidate?
	if not player then
		return nil
	end
	for _, candidate in ipairs(candidates) do
		if candidate.player == player then
			return candidate
		end
	end
	return nil
end

local function reach(state: EnemyState): number
	if state.heavy then
		return state.radius + Enemies.MINI_ATTACK.HeavyRadius * 0.6
	end
	return if state.def.AttackType == "ranged" then state.def.AttackRange else state.radius + state.def.AttackRange
end

local function attack(state: EnemyState, now: number)
	local def = state.def
	local heavy = state.heavy
	local raw = def.Damage * (if heavy then Enemies.MINI_ATTACK.HeavyMult elseif def.Tier == "boss" then Enemies.BOSS_ATTACK.Mult else 1)
	state.nextAttack = now + (def.AttackCooldown or Enemies.DEFAULTS.AttackCooldown)
	if heavy then
		state.nextHeavy = now + Enemies.MINI_ATTACK.HeavyCooldown
	end
	state.model:SetAttribute("AttackAt", serverNow())
	if def.AttackType == "ranged" and not heavy then
		local target = candidateOf(state.target)
		local from = state.root.Position + state.facing * state.radius + UP * 0.5
		local aim = if target then target.position else from + state.facing * def.AttackRange
		local dir = aim - from
		local distance = math.min(dir.Magnitude, def.AttackRange + 5)
		if dir.Magnitude < 1e-3 then
			return
		end
		dir = dir.Unit
		for _, viewer in ipairs(visualTo(from)) do
			Net.fire(viewer, "Projectile", from, dir, AI.ProjectileSpeed, distance, "Enemy")
		end
		local impact = from + dir * distance
		task.delay(distance / AI.ProjectileSpeed, function()
			if not state.alive then
				return
			end
			for _, candidate in ipairs(candidates) do
				local position = candidate.root.Position
				if targetable(state, candidate.player) and flat(position - impact).Magnitude <= AI.ProjectileRadius and math.abs(position.Y - impact.Y) < 6 then
					combat():DamagePlayer(candidate.player, raw, state)
				end
			end
		end)
		return
	end
	local origin = state.position
	local cosHalf = math.cos(math.rad(AI.MeleeCone / 2))
	local maxReach = reach(state) + AI.MeleeReachBonus
	if heavy then
		for _, viewer in ipairs(visualTo(origin)) do
			Net.fire(viewer, "Burst", origin + state.facing * state.radius, Enemies.MINI_ATTACK.HeavyRadius, "Enemy")
		end
	end
	for _, candidate in ipairs(candidates) do
		if targetable(state, candidate.player) then
			local offset = candidate.position - origin
			local f = flat(offset)
			local distance = f.Magnitude
			local inFront = distance < state.radius + 1 or f.Unit:Dot(state.facing) >= cosHalf
			if distance <= maxReach and (heavy or inFront) and math.abs(offset.Y) < state.height + 4 then
				combat():DamagePlayer(candidate.player, raw, state)
			end
		end
	end
end

local function nearestTarget(state: EnemyState): Candidate?
	local best, bestDistance = nil, state.def.AggroRadius or Enemies.DEFAULTS.AggroRadius
	if state.group.kind == "arena" then
		bestDistance = math.huge -- arena enemies always know where the players are
	end
	for _, candidate in ipairs(candidates) do
		if targetable(state, candidate.player) then
			local distance = flat(candidate.position - state.position).Magnitude
			local inLeash = not state.group.leash or flat(candidate.position - state.home).Magnitude <= AI.LeashRadius
			if distance < bestDistance and inLeash then
				best, bestDistance = candidate, distance
			end
		end
	end
	return best
end

local function update(state: EnemyState, now: number)
	local def = state.def
	state.position = state.root.Position - UP * (state.halfHeight + state.hover)
	if now < state.staggerUntil then
		halt(state)
		return
	end
	local mode = state.mode
	if mode == "Intro" then
		halt(state)
		if now >= state.untilTime then
			setMode(state, "Chase")
		end
		return
	end
	if mode == "Leash" then
		if flat(state.home - state.position).Magnitude < 2 then
			state.hp = state.maxHP
			state.model:SetAttribute("HP", state.hp)
			table.clear(state.damage)
			state.target = nil
			setMode(state, "Idle")
			halt(state)
		else
			moveToward(state, state.home, state.speed * AI.LeashSpeedFactor, now)
		end
		return
	end
	local target = candidateOf(state.target)
	if mode == "Telegraph" then
		halt(state)
		if now >= state.untilTime then
			attack(state, now)
			setMode(state, "Recover", now + AI.RecoverSeconds)
		end
		return
	end
	if mode == "Recover" then
		halt(state)
		if now >= state.untilTime then
			setMode(state, if target then "Chase" else "Idle")
		end
		return
	end
	if not target or not targetable(state, target.player) then
		target = nearestTarget(state)
		state.target = if target then target.player else nil
	end
	if target then
		if state.group.leash and flat(target.position - state.home).Magnitude > AI.LeashRadius then
			state.target = nil
			state.path = nil
			setMode(state, "Leash")
			return
		end
		setMode(state, "Chase")
		local toTarget = flat(target.position - state.position)
		local distance = toTarget.Magnitude
		state.heavy = def.Tier == "mini" and now >= state.nextHeavy
		local range = reach(state)
		if distance <= range and now >= state.nextAttack then
			face(state, toTarget)
			local telegraph = if state.heavy then Enemies.MINI_ATTACK.HeavyTelegraph else (def.Telegraph or Enemies.DEFAULTS.MeleeTelegraph)
			setMode(state, "Telegraph", now + telegraph)
			state.model:SetAttribute("Heavy", state.heavy)
			state.model:SetAttribute("Telegraph", serverNow() + telegraph)
			halt(state)
		elseif distance > range * 0.85 then
			-- melee enemies spread around the target; ranged ones keep their distance
			local goal
			if def.AttackType == "ranged" then
				goal = target.position + flatUnit(state.position - target.position, -state.facing) * range * 0.7
			else
				local angle = (state.slot * 2.39996) % (math.pi * 2)
				local ring = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.max(0, range - state.radius) * 0.6
				goal = target.position + ring
			end
			moveToward(state, goal, state.speed, now)
		else
			halt(state)
			nudge(state)
			face(state, toTarget)
		end
		return
	end
	-- Idle: short walks around the spawn
	setMode(state, "Idle")
	if now >= state.nextWander then
		local window = AI.WanderEvery
		state.nextWander = now + rng:NextNumber(window[1], window[2])
		local angle = rng:NextNumber(0, math.pi * 2)
		state.wanderGoal = state.home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(2, AI.WanderRadius)
	end
	local goal = state.wanderGoal
	if goal and flat(goal - state.position).Magnitude > 1 then
		moveToward(state, goal, state.speed * AI.WanderSpeedFactor, now)
	else
		state.wanderGoal = nil
		halt(state)
		nudge(state)
	end
end

local function tick()
	local now = os.clock()
	refreshCandidates()
	for _, group in pairs(groups) do
		if group.active and not group.paused then
			for _, state in ipairs(group.enemies) do
				if state.alive then
					local ok, err = pcall(update, state, now)
					if not ok then
						warn(`EnemyService: {state.def.Id} AI error: {err}`)
						state.staggerUntil = now + 1
					end
				end
			end
		end
	end
end

local function setPaused(group: Group, paused: boolean)
	if group.paused == paused then
		return
	end
	group.paused = paused
	for _, state in ipairs(group.enemies) do
		setPhysics(state, not paused)
		if not paused then
			state.progressAt = os.clock()
		end
	end
end

function EnemyService:CreateGroup(key: string, opts: { [string]: any }?): Group
	local options = opts or {}
	EnemyService:EndGroup(key)
	local group: Group = {
		key = key, kind = options.kind or "arena", enemies = {}, active = true, paused = false, emptySince = nil,
		area = options.area, points = options.points or {}, respawn = options.respawn == true,
		leash = options.leash ~= false and options.kind ~= "arena", players = options.players, onDeath = options.onDeath,
	}
	groups[key] = group
	return group
end

function EnemyService:GetGroup(key: string): Group?
	return groups[key]
end

function EnemyService:EndGroup(key: string)
	local group = groups[key]
	if not group then
		return
	end
	group.active = false
	groups[key] = nil
	for _, state in ipairs(table.clone(group.enemies)) do
		state.alive = false
		state.model:Destroy()
	end
	table.clear(group.enemies)
end

-- Spawns the 10 enemies of a sub-zone (types 4 / 3 / 3 or 5 / 5) on its spawn points.
local function activate(subZoneId: string, folder: Instance)
	local defs = Enemies.BySubZone[subZoneId]
	if not defs or not defs[1] or not defs[1].Rig then
		return -- zones without enemy data (5-12) stay empty
	end
	local points: { [string]: { Vector3 } } = {}
	local spawns = folder:FindFirstChild("Spawns")
	for _, point in ipairs(if spawns then spawns:GetChildren() else {}) do
		local id = point:GetAttribute("EnemyId")
		if point:IsA("BasePart") and typeof(id) == "string" then
			points[id] = points[id] or {}
			table.insert(points[id], point.Position - UP * point.Size.Y / 2)
		end
	end
	local area = folder:FindFirstChild("Area")
	local group = EnemyService:CreateGroup(subZoneId, {
		kind = "subzone", area = if area and area:IsA("BasePart") then area else nil, points = points, respawn = true, leash = true,
	})
	refreshCandidates()
	local perType = math.floor(Enemies.ALIVE_PER_SUBZONE / #defs)
	local extra = Enemies.ALIVE_PER_SUBZONE - perType * #defs
	for i, def in ipairs(defs) do
		local wanted = perType + (if i <= extra then 1 else 0)
		local list = table.clone(points[def.Id] or {})
		for n = 1, wanted do
			local point: Vector3? = nil
			if #list > 0 then
				point = table.remove(list, rng:NextInteger(1, #list))
			else
				point = (if group.area then randomSpot(group.area) else nil) or (points[def.Id] and points[def.Id][1])
			end
			if point then
				if n > #(points[def.Id] or {}) then
					point += Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
				end
				EnemyService:Spawn(group, def, point)
			end
		end
	end
end

-- Called by ZoneService with the sub-zones that currently have players in them.
function EnemyService:SetOccupied(occupied: { [string]: boolean })
	local now = os.clock()
	for subZoneId in pairs(occupied) do
		local group = groups[subZoneId]
		if group then
			group.emptySince = nil
			setPaused(group, false)
		else
			local zoneId = Zones.parseSubZoneId(subZoneId)
			local zoneFolder = zoneId and workspace.Zones:FindFirstChild(zoneId)
			local folder = zoneFolder and zoneFolder:FindFirstChild(subZoneId)
			if folder then
				activate(subZoneId, folder)
			end
		end
	end
	for subZoneId, group in pairs(groups) do
		if group.kind == "subzone" and not occupied[subZoneId] then
			group.emptySince = group.emptySince or now
			setPaused(group, true)
			if now - (group.emptySince :: number) > Playtest.EmptySubZoneDespawnSeconds then
				EnemyService:EndGroup(subZoneId)
			end
		end
	end
end

-- Admin: one enemy a few studs in front of the player (no respawn, no leash limit to its group).
function EnemyService:SpawnNear(player: Player, def: any): EnemyState?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local group = groups.admin or EnemyService:CreateGroup("admin", { kind = "admin", respawn = false, leash = false })
	return EnemyService:Spawn(group, def, root.Position + flatUnit(root.CFrame.LookVector, Vector3.zAxis) * (8 + (def.Height or 4)))
end

-- Admin: every living enemy dies, credited to the player (they respawn normally).
function EnemyService:KillAll(player: Player): number
	local n = 0
	for _, state in ipairs(EnemyService:All()) do
		if state.alive then
			state.invulnerableUntil = 0
			EnemyService:Damage(player, state, state.hp)
			n += 1
		end
	end
	return n
end

-- Boss rooms (BossService): an Intro of a few seconds (still and invulnerable) before the fight.
function EnemyService:Intro(state: EnemyState, seconds: number)
	state.invulnerableUntil = os.clock() + seconds
	setMode(state, "Intro", os.clock() + seconds)
end

function EnemyService:Init()
	container = Instance.new("Folder")
	container.Name = "Enemies"
	container.Parent = workspace
	task.spawn(function()
		while true do
			task.wait(AI.TickSeconds)
			tick()
		end
	end)
end

return EnemyService
