--!strict
-- Player combat (docs/enemies_npcs_pets_brief.txt Part A, DESIGN.md section 2). Server authoritative; the client
-- only sends its inputs and shows the results.
--   Net.send("Attack", aimDir: Vector3, aimPoint: Vector3?, variant: string?)   each attack is the next step of the
--                                         category's combo (Config/WeaponMoves) chosen here; a move starts no sooner than
--                                         the previous move's Duration / speed x Combat.RateTolerance; no attack during a
--                                         roll or a block. variant "Air" (jump attack: checked airborne here), "Dash" (dash
--                                         strike right after a roll), "Heavy" (release of a charge opened by "Charge");
--                                         refused variants fall back to the combo
--   Net.send("Charge", on: boolean)       the hold starts (after the running swing's impact): the server's own clock
--                                         measures the charge, whatever the client claims
--   Net.send("Roll", dir: Vector3?)       cooldown = Stats RollCooldown, i-frames Combat.Roll.IFrames; refused before
--                                         the running attack's impact (a roll only cancels the recovery)
--   Net.send("Block", holding: boolean)   damage x (1 - Stats Block x guard strength), speed x Combat.Block.SpeedFactor,
--                                         no attacks; guard meter and perfect parry: Combat.Block
--   CombatService:DamagePlayer(player, raw, source?) -> dealt   (enemies and bosses call this; source = the enemy state,
--                                         a perfect parry staggers it)
-- Events: "Swing" (attacker, category, step, dir, speed, aim, variant?) = the compact attack state, to the other players
-- nearby: each client plays it; "Hit" (position, damage, crit, finisher, category) to the attacker, "Impact" (position,
-- category, crit, finisher) to the others, "AirSlam" (attacker, category, position, radius, element) to the others when a
-- jump attack lands. Animations / VFX / SFX never decide damage.
-- Hits use the shapes of Config/WeaponMoves at the move's impact moment.
-- Damage per hit = Stats.compute WeaponDamage (the weapon's OWN zone base x category x rarity x attributes x pets x
-- Rebirth Shop; NEVER the player's zone, rule 1B) x the move's Damage x crit (Stats CritChance, +20% with daggers;
-- x Stats CritDamage) x (1 + Boss Slayer) on bosses; finisher or heavy on a staggered enemy x GuardBreakMult.
-- Starter weapon: a player who owns no weapon (new player, after a Rebirth wipe) gets a free Common sword of the
-- zone they are in (Plains outside the zones).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)
local WeaponMoves = require(ReplicatedStorage.GameSystem.Config.WeaponMoves)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local WeaponService = require(script.Parent.WeaponService)

local CombatService = { Priority = 5 }

type PlayerState = {
	lastAttack: number,
	gap: number, -- the running move's Duration / speed
	impactAt: number, -- when the running move's first hit lands
	chargeAt: number?, -- the hold started (Net "Charge")
	combo: number,
	comboAt: number,
	comboCategory: string?,
	lastRoll: number,
	rollAt: number, -- when the last accepted roll started (dash attacks)
	rollUntil: number,
	rollEnd: number,
	lastAir: number, -- the last jump attack
	blocking: boolean,
	blockAt: number, -- the last block press
	parryUntil: number, -- a hit before this is a perfect parry
	guard: number, -- meter, refilled lazily (guardAt)
	guardAt: number,
	blockLockUntil: number, -- the guard broke: no block before this
	stats: { [string]: any }?,
}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()

local function stateOf(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = {
			lastAttack = -math.huge, gap = 0, impactAt = 0, chargeAt = nil, combo = 0, comboAt = 0, comboCategory = nil,
			lastRoll = -math.huge, rollAt = -math.huge, rollUntil = 0, rollEnd = 0, lastAir = -math.huge,
			blocking = false, blockAt = -math.huge, parryUntil = 0, guard = Combat.Block.GuardMax, guardAt = 0, blockLockUntil = 0, stats = nil,
		}
		states[player] = state
	end
	return state
end

-- Derived stats, cached until the profile changes (never zone-dependent).
function CombatService:Stats(player: Player): { [string]: any }?
	local state = stateOf(player)
	if not state.stats then
		local profile = DataService:Get(player)
		if not profile then
			return nil
		end
		state.stats = Stats.compute(profile, { now = os.time() })
	end
	return state.stats
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

local function weaponOf(player: Player): (any, any)
	local profile = DataService:Get(player)
	local item = profile and profile.EquippedWeapon and profile.Weapons[profile.EquippedWeapon]
	local weapon = item and Weapons.ById[item.id]
	if not weapon then
		return nil, nil
	end
	return weapon, WeaponCategories.ById[weapon.Category]
end

-- Ground point under the enemy's body (live position of its physics root).
local function positionOf(enemy: any): Vector3
	local root = enemy.root
	if root then
		return root.Position - Vector3.new(0, (enemy.halfHeight or 0) + (enemy.hover or 0), 0)
	end
	return enemy.model:GetPivot().Position
end

local function centerOf(enemy: any): Vector3
	return if enemy.root then enemy.root.Position else positionOf(enemy) + Vector3.new(0, (enemy.height or 4) * 0.5, 0)
end

-- A client vector we can trust: a Vector3 with finite, sane coordinates.
local function finite(v: any): boolean
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function isBossLike(enemy: any): boolean
	local role = enemy.def.Role or enemy.def.Tier
	return role == "MiniBoss" or role == "Boss" or role == "mini" or role == "boss"
end

local function visualTo(origin: Vector3): { Player }
	local list = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local root = rootOf(other)
		if root and (root.Position - origin).Magnitude <= Combat.VisualRange then
			table.insert(list, other)
		end
	end
	return list
end

type Strike = { multiplier: number, bonusCrit: number, finisher: boolean, breaker: number?, staggerChance: number?, knockback: any, stagger: number?, category: string, element: string? }

-- One hit on one enemy: crit roll, Boss Slayer, knockback, the "Hit" number for the attacker and the "Impact" for
-- the players around.
local function hit(player: Player, enemy: any, stats: { [string]: any }, strike: Strike)
	if not enemy.alive then
		return
	end
	local multiplier, bonusCrit = strike.multiplier, strike.bonusCrit
	if strike.breaker and (enemy.staggerUntil or 0) > os.clock() then
		multiplier *= strike.breaker -- a finisher / heavy on a staggered enemy: the guard is broken
	end
	local critChance = math.min(1, (stats.CritChance or 0) + bonusCrit)
	local crit = rng:NextNumber() < critChance
	local damage = (if stats.WeaponDamage > 0 then stats.WeaponDamage else Combat.UnarmedDamage) * multiplier
	if crit then
		damage *= stats.CritDamage or 2
	end
	if isBossLike(enemy) then
		damage *= 1 + (stats.BossDamage or 0)
	end
	damage = math.max(1, math.floor(damage + 0.5))
	local at = centerOf(enemy) + Vector3.new(0, (enemy.halfHeight or 2) + 1, 0)
	EnemyService:Damage(player, enemy, damage, strike.knockback)
	local staggerChance = strike.staggerChance
	if strike.stagger and enemy.alive and EnemyService.Stagger then
		EnemyService:Stagger(enemy, strike.stagger)
	elseif staggerChance and enemy.alive and EnemyService.Stagger and rng:NextNumber() < staggerChance then
		EnemyService:Stagger(enemy, WeaponMoves.Input.ChanceStagger)
	end
	Net.fire(player, "Hit", at, damage, crit, strike.finisher, strike.category)
	for _, viewer in ipairs(visualTo(at)) do
		if viewer ~= player then
			Net.fire(viewer, "Impact", at, strike.category, crit, strike.finisher, strike.element)
		end
	end
end

-- Enemies inside an arc / cone in front of origin (sorted by distance).
local function inArc(origin: Vector3, dir: Vector3, radius: number, angle: number): { any }
	local list = {}
	local cosHalf = math.cos(math.rad(angle / 2))
	for _, enemy in ipairs(EnemyService:GetNear(origin, radius)) do
		local offset = positionOf(enemy) - origin
		local f = Vector3.new(offset.X, 0, offset.Z)
		local distance = f.Magnitude
		if distance <= radius + (enemy.radius or 1) and (distance < Combat.CloseRange or f.Unit:Dot(dir) >= cosHalf) then
			table.insert(list, { enemy = enemy, distance = distance })
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	return list
end

local function inLine(origin: Vector3, dir: Vector3, length: number, width: number): { any }
	local list = {}
	for _, enemy in ipairs(EnemyService:GetNear(origin, length)) do
		local offset = positionOf(enemy) - origin
		local f = Vector3.new(offset.X, 0, offset.Z)
		local along = f:Dot(dir)
		local side = (f - dir * along).Magnitude
		local r = enemy.radius or 1
		if along >= -1 and along <= length + r and side <= width / 2 + r then
			table.insert(list, { enemy = enemy, distance = along })
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	return list
end

local function inCircle(center: Vector3, radius: number): { any }
	local list = {}
	for _, enemy in ipairs(EnemyService:GetNear(center, radius)) do
		local offset = positionOf(enemy) - center
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance <= radius + (enemy.radius or 1) then
			table.insert(list, { enemy = enemy, distance = distance })
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	return list
end

-- The first enemy along a shot (center within its radius of the line), or nil.
local function firstOnRay(origin: Vector3, dir: Vector3, range: number): (any, number)
	local best, bestAlong = nil, range
	for _, enemy in ipairs(EnemyService:GetNear(origin, range)) do
		local center = centerOf(enemy)
		local offset = center - origin
		local along = offset:Dot(dir)
		if along > 0 and along < bestAlong then
			local side = (offset - dir * along).Magnitude
			if side <= (enemy.radius or 1) + 1 then
				best, bestAlong = enemy, along
			end
		end
	end
	return best, bestAlong
end

-- The combo step of this attack: the next one, or the first after a pause / a weapon change.
local function nextStep(state: PlayerState, categoryId: string, now: number): number
	local steps = WeaponMoves.Moves[categoryId].Steps
	if state.comboCategory ~= categoryId or now - state.comboAt > state.gap + WeaponMoves.Input.ComboReset then
		state.combo = 0
	end
	state.combo = state.combo % #steps + 1
	state.comboAt = now
	state.comboCategory = categoryId
	return state.combo
end

-- The server's view of "in the air": rising / falling, or nothing under the feet within Combat.AirAttack.MinHeight
-- (the client sends its jump attacks from the air, a little before the server sees it: generous on purpose).
local airParams = RaycastParams.new()
airParams.FilterType = Enum.RaycastFilterType.Exclude
local function airborne(root: BasePart, humanoid: Humanoid): boolean
	if math.abs(root.AssemblyLinearVelocity.Y) > 4 then
		return true
	end
	local character = root.Parent
	-- enemies under the player do not count as ground
	airParams.FilterDescendantsInstances = if character then { character, workspace:FindFirstChild("Enemies") :: Instance } else {}
	local reach = humanoid.HipHeight + root.Size.Y / 2 + Combat.AirAttack.MinHeight * 0.5
	return workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), airParams) == nil
end

local SKILL = newproxy() -- the variant of a Z skill: only CombatService:Skill can pass it, never the network

local function attack(player: Player, aimDir: any, aimPoint: any, variant: any)
	local root, humanoid = rootOf(player)
	if not (root and humanoid) or player:GetAttribute("Spectating") then
		return
	end
	local state = stateOf(player)
	-- a refused request: the client predicted a step, it learns the real one
	local function refuse()
		Net.fire(player, "Combo", state.comboCategory or "", state.combo, false)
	end
	if state.blocking then
		return refuse()
	end
	local weapon, category = weaponOf(player)
	local stats = CombatService:Stats(player)
	if not stats then
		return refuse()
	end
	local id = if category and WeaponMoves.Moves[category.Id] then category.Id else "Sword"
	local moves = WeaponMoves.Moves[id]
	local speed = 1 + (stats.AttackSpeed or 0)
	local now = os.clock()
	if now < state.rollEnd then
		return refuse() -- attacks cannot start during a roll
	end
	local chargeAt = state.chargeAt
	state.chargeAt = nil
	local charged = variant == "Heavy" and moves.Heavy ~= nil and chargeAt ~= nil
	if not charged and now - state.lastAttack < state.gap * Combat.RateTolerance then
		return refuse() -- faster than the weapon allows
	end
	local dir = if finite(aimDir) and aimDir.Magnitude > 0.01 then flat(aimDir) else flat(root.CFrame.LookVector)
	-- heavy / jump attack / dash strike, else the next combo step
	local kind: string? = nil
	if charged then
		kind = "Heavy"
	elseif variant == SKILL then
		kind = "Skill"
	elseif variant == "Air" and moves.Air and now - state.lastAir >= Combat.AirAttack.MinGap and airborne(root, humanoid) then
		kind = "Air"
	elseif variant == "Dash" and moves.Dash and now - state.rollAt <= Combat.Roll.Duration + Combat.DashAttack.Window + Combat.DashAttack.Tolerance then
		kind = "Dash"
	end
	local index: number, step: { [string]: any }
	if kind then
		-- the combo restarts after it
		state.combo = 0
		state.comboAt = now
		state.comboCategory = id
		index = 1
		step = moves[kind]
		if kind == "Air" then
			state.lastAir = now
		end
		Net.fire(player, "Combo", id, 0, true)
	else
		index = nextStep(state, id, now)
		step = moves.Steps[index]
		Net.fire(player, "Combo", id, index, true)
	end
	local shape = WeaponMoves.shape(id, step)
	-- an early request (network jitter tolerance) is booked at its due time, so the long-run rate stays the weapon's
	state.lastAttack = if charged then now else math.max(now, state.lastAttack + state.gap)
	state.gap = step.Duration / speed
	local impact = step.Impact / speed
	state.impactAt = now + impact
	-- the server's own measure of the hold: 0 (just started) .. 1 (full), whatever the client says
	local charge = if charged then math.clamp((now - (chargeAt :: number)) * speed / step.MaxCharge, 0, 1) else 0
	local strike: Strike = {
		multiplier = (step.Damage or 1) * (1 + (step.ChargeDamage or 0) * charge),
		bonusCrit = shape.BonusCrit or 0,
		finisher = step.Finisher == true or kind ~= nil and kind ~= "Dash",
		breaker = if step.Finisher == true or kind == "Heavy" or kind == "Skill" then moves.GuardBreakMult or WeaponMoves.Input.GuardBreakMult else nil,
		staggerChance = moves.StaggerChance,
		knockback = step.Knockback,
		stagger = step.Stagger,
		category = id,
		element = if weapon then weapon.Element else nil,
	}
	local origin = root.Position
	-- the 3D aim (other players' Ranged / Magic aim pitch): toward the aimed point, else the flat direction
	local aim = dir
	if finite(aimPoint) then
		local offset = aimPoint - (origin + Vector3.new(0, 1.5, 0))
		if offset.Magnitude > 0.5 and offset.Magnitude < 500 then
			aim = offset.Unit
		end
	end
	for _, viewer in ipairs(visualTo(origin)) do
		if viewer ~= player then
			Net.fire(viewer, "Swing", player, id, index, dir, speed, aim, kind)
		end
	end

	if shape.Kind == "Projectile" then
		local muzzle = origin + Vector3.new(0, 1.2, 0) + dir * 1.5
		local style = if weapon then weapon.Element else "Physical"
		if kind == "Air" then
			-- the volley from the air: toward the aimed point (else down and forward), fanned out around the vertical
			local toward = if finite(aimPoint) then aimPoint - muzzle else nil
			local base = if toward and toward.Magnitude > 1 then toward.Unit else (dir - Vector3.new(0, 0.45, 0)).Unit
			-- always down at least 10 degrees (never up into the sky)
			local pitch = math.clamp(math.asin(math.clamp(base.Y, -1, 1)), math.rad(-85), math.rad(-10))
			base = flat(base) * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
			local shots = step.Shots or 1
			for i = 1, shots do
				local yaw = math.rad(((i - 1) - (shots - 1) / 2) * (step.Spread or 0))
				local d = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(base)
				local target, along = firstOnRay(muzzle, d, shape.Range)
				-- the arrow stops in the ground when it hits no enemy before
				airParams.FilterDescendantsInstances = { root.Parent :: Instance, workspace:FindFirstChild("Enemies") :: Instance }
				local wall = workspace:Raycast(muzzle, d * along, airParams)
				if wall then
					target, along = nil, wall.Distance
				end
				local distance = math.max(0.5, along)
				for _, viewer in ipairs(visualTo(origin)) do
					Net.fire(viewer, "Projectile", muzzle, d, shape.Speed, distance, style, player)
				end
				if target then
					task.delay(impact + distance / shape.Speed, function()
						if rootOf(player) then
							hit(player, target, stats, strike)
						end
					end)
				end
			end
			return
		end
		local target, along = firstOnRay(origin + Vector3.new(0, 1.2, 0), dir, shape.Range + 1.5)
		local distance = math.max(0.5, along - 1.5)
		for _, viewer in ipairs(visualTo(origin)) do
			Net.fire(viewer, "Projectile", muzzle, dir, shape.Speed, distance, style, player)
		end
		if target then
			task.delay(impact + distance / shape.Speed, function()
				if rootOf(player) then
					hit(player, target, stats, strike)
				end
			end)
		end
		return
	end
	if shape.Kind == "AoE" then
		local point = if finite(aimPoint) then aimPoint else origin + dir * shape.Range * 0.5
		local offset = point - origin
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > shape.Range then
			point = origin + flat(offset) * shape.Range
		end
		point = Vector3.new(point.X, math.clamp(point.Y, origin.Y - 20, origin.Y + 10), point.Z)
		local radius = shape.Radius * (1 + (stats.MagicRadius or 0))
		for _, viewer in ipairs(visualTo(origin)) do
			Net.fire(viewer, "Burst", point, radius, if weapon then weapon.Element else "Arcane")
		end
		task.delay(impact, function()
			if not rootOf(player) then
				return
			end
			local targets = inCircle(point, radius)
			for i = 1, math.min(#targets, shape.MaxTargets) do
				hit(player, targets[i].enemy, stats, strike)
			end
		end)
		return
	end
	local function strikeNow()
		local current, body = rootOf(player)
		if not (current and body) then
			return
		end
		local from = current.Position
		local moved = Vector3.new(from.X - origin.X, 0, from.Z - origin.Z)
		local limit = (step.Lunge or 0) * 1.5 + body.WalkSpeed * (os.clock() - now) + 2
		if moved.Magnitude > limit then
			from = Vector3.new(origin.X, from.Y, origin.Z) + moved.Unit * limit
		end
		local targets
		if shape.Kind == "Line" then
			targets = inLine(from, dir, shape.Length, shape.Width)
		elseif shape.Kind == "Circle" then
			targets = inCircle(from, shape.Radius)
		else
			targets = inArc(from, dir, shape.Radius, shape.Angle)
		end
		local hitSet = {}
		for i = 1, math.min(#targets, shape.MaxTargets) do
			local enemy = targets[i].enemy
			hitSet[enemy] = true
			hit(player, enemy, stats, strike)
		end
		if kind == "Air" then
			-- the landing shockwave of a jump attack, for the players around (the attacker draws its own at landing)
			local ground = from - Vector3.new(0, body.HipHeight + current.Size.Y / 2, 0)
			for _, viewer in ipairs(visualTo(from)) do
				if viewer ~= player then
					Net.fire(viewer, "AirSlam", player, id, ground, shape.Radius or 6, if weapon then weapon.Element else nil)
				end
			end
		end
		if shape.SlamRadius then
			-- Heavy: a ground slam in front with a short stagger, wider the longer the hold
			local center = from + dir * 3
			local slamRadius = shape.SlamRadius * (1 + (step.ChargeRadius or 0) * charge)
			for _, viewer in ipairs(visualTo(from)) do
				Net.fire(viewer, "Burst", center, slamRadius, "Slam")
			end
			for _, entry in ipairs(inCircle(center, slamRadius)) do
				local enemy = entry.enemy
				if not hitSet[enemy] then
					hitSet[enemy] = true
					hit(player, enemy, stats, strike)
				end
				if enemy.alive and EnemyService.Stagger then
					EnemyService:Stagger(enemy, shape.Stagger)
				end
			end
		end
	end
	task.delay(impact, strikeNow)
	for _, extra in ipairs(step.Hits or {}) do
		task.delay(extra / speed, strikeNow) -- Dagger finisher: the second slash of the double slash
	end
end

-- The hold of a heavy starts (after the running swing's impact). Other players see the wind-up.
local function charge(player: Player, on: any)
	local state = stateOf(player)
	state.chargeAt = nil
	local root = rootOf(player)
	local _, category = weaponOf(player)
	local stats = CombatService:Stats(player)
	local now = os.clock()
	if on ~= true or not (root and stats and category) or state.blocking or now < state.rollEnd or now < state.impactAt - Combat.Roll.ImpactTolerance then
		return
	end
	if not WeaponMoves.Moves[category.Id].Heavy then
		return
	end
	state.chargeAt = now
	for _, viewer in ipairs(visualTo(root.Position)) do
		if viewer ~= player then
			Net.fire(viewer, "Swing", player, category.Id, 1, flat(root.CFrame.LookVector), 1 + (stats.AttackSpeed or 0), nil, "Charge")
		end
	end
end

local function roll(player: Player, dir: any)
	local root = rootOf(player)
	local state = stateOf(player)
	local stats = CombatService:Stats(player)
	if not root or state.blocking or not stats then
		return
	end
	local now = os.clock()
	local cooldown = stats.RollCooldown or 1.2
	if now - state.lastRoll < cooldown * Combat.RateTolerance or now < state.impactAt - Combat.Roll.ImpactTolerance then
		return
	end
	state.chargeAt = nil
	state.lastRoll = math.max(now, state.lastRoll + cooldown)
	state.gap = 0 -- the dodge cancels the recovery: the next move may start after the roll
	state.rollAt = now
	state.rollUntil = now + Combat.Roll.IFrames
	state.rollEnd = now + Combat.Roll.Duration * Combat.RateTolerance
	local d = if finite(dir) then flat(dir) else flat(root.CFrame.LookVector)
	for _, viewer in ipairs(visualTo(root.Position)) do
		if viewer ~= player then
			Net.fire(viewer, "Motion", player, "Roll", d)
		end
	end
end

-- The guard meter now: it refills while not blocking.
local function guardOf(state: PlayerState, now: number): number
	if not state.blocking then
		state.guard = math.min(Combat.Block.GuardMax, state.guard + (now - state.guardAt) * Combat.Block.GuardRegen)
	end
	state.guardAt = now
	return state.guard
end

local function setBlocking(player: Player, holding: any)
	local state = stateOf(player)
	local _, humanoid = rootOf(player)
	local stats = CombatService:Stats(player)
	local want = holding == true
	local now = os.clock()
	if state.blocking == want or (want and now < state.blockLockUntil) then
		return
	end
	guardOf(state, now)
	state.blocking = want
	if want then
		-- a perfect parry needs a real press: spamming the button never keeps the window open
		state.parryUntil = if now - state.blockAt >= Combat.Block.ParryCooldown then now + Combat.Block.ParryWindow else 0
		state.blockAt = now
		state.chargeAt = nil
	end
	player:SetAttribute("Blocking", want)
	if humanoid and stats then
		humanoid.WalkSpeed = stats.WalkSpeed * (if want then Combat.Block.SpeedFactor else 1)
	end
end

-- Runs the Z skill's move (SkillService checked its cooldown and cost). False = the player cannot act right now.
function CombatService:Skill(player: Player, aimDir: any, aimPoint: any): boolean
	local state = stateOf(player)
	local now = os.clock()
	local root = rootOf(player)
	local _, category = weaponOf(player)
	if not (root and category) or not WeaponMoves.Moves[category.Id].Skill or state.blocking or now < state.rollEnd or now - state.lastAttack < state.gap * Combat.RateTolerance then
		return false
	end
	attack(player, aimDir, aimPoint, SKILL)
	return true
end

function CombatService:IsBlocking(player: Player): boolean
	return stateOf(player).blocking
end

-- Damage taken from an enemy / boss: i-frames (roll), block, defense, god mode. Returns the damage dealt.
function CombatService:DamagePlayer(player: Player, raw: number, source: any?): number
	local _, humanoid = rootOf(player)
	if not humanoid or player:GetAttribute("GodMode") or player:GetAttribute("Spectating") then
		return 0
	end
	local state = stateOf(player)
	local now = os.clock()
	if now < state.rollUntil then
		Net.fire(player, "Hurt", 0, "dodge")
		return 0
	end
	local stats = CombatService:Stats(player)
	local block = Combat.Block
	local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
	local function motion(name: string)
		if root and root:IsA("BasePart") then
			for _, viewer in ipairs(visualTo(root.Position)) do
				if viewer ~= player then
					Net.fire(viewer, "Motion", player, name)
				end
			end
		end
	end
	if state.blocking and now < state.parryUntil then
		-- perfect parry: nothing goes through, the attacker staggers, the guard comes back
		state.parryUntil = 0
		state.guard = block.GuardMax
		if source and source.def and EnemyService.Stagger then
			EnemyService:Stagger(source, block.ParryStagger)
		end
		Net.fire(player, "Hurt", 0, "parry")
		motion("Parry")
		return 0
	end
	local amount = raw
	local kind = "hit"
	local _, category = weaponOf(player)
	local heavy = category and WeaponMoves.Moves[category.Id].Heavy
	if state.chargeAt and heavy and heavy.ChargeArmor then
		amount *= 1 - heavy.ChargeArmor -- the feel of a hammer's wind-up: tougher, never immune
	end
	if state.blocking then
		-- each blocked hit wears the guard down: the block weakens, at 0 it breaks
		local guard = guardOf(state, now)
		local strength = block.MinStrength + (1 - block.MinStrength) * guard / block.GuardMax
		amount *= 1 - (if stats then stats.Block else 0.6) * strength
		kind = "block"
		state.guard = guard - block.GuardPerHit
		if state.guard <= 0 then
			state.guard = 0
			state.blockLockUntil = now + block.GuardBreakLock
			setBlocking(player, false)
			kind = "break"
		end
	end
	if stats then
		amount *= 1 - (stats.DamageReduction or 0)
	end
	amount = math.max(1, math.floor(amount + 0.5))
	humanoid:TakeDamage(amount)
	Net.fire(player, "Hurt", amount, kind)
	motion(if kind == "hit" then "Hurt" else "BlockHit")
	if source and source.def and source.def.Tier == "boss" and amount >= humanoid.MaxHealth * Combat.LockOn.BreakFraction then
		Net.fire(player, "LockBreak")
	end
	return amount
end

-- A free Common sword of the zone the player is in (or of zoneId: RebirthService) when they own no weapon at all.
function CombatService:EnsureStarterWeapon(player: Player, zoneId: string?)
	local profile = DataService:Get(player)
	if not profile or next(profile.Weapons or {}) ~= nil then
		return
	end
	local where: any = zoneId or player:GetAttribute("CurrentZone")
	local zone = if typeof(where) == "string" then Zones.ById[where] else nil
	local weaponId = string.lower(if zone then zone.Id else "Plains") .. "_sword"
	if not Weapons.ById[weaponId] then
		weaponId = "plains_sword"
	end
	local uid = HttpService:GenerateGUID(false)
	DataService:Set(player, "Weapons", { [uid] = { id = weaponId, rarity = Combat.StarterRarity } })
	local index = table.clone(profile.Index or {})
	if typeof(index[weaponId]) ~= "number" then
		index[weaponId] = Combat.StarterRarity
		DataService:Set(player, "Index", index)
	end
	WeaponService:Equip(player, uid)
	Net.fire(player, "Notify", { Kind = "loot", Text = `Starter weapon: {Weapons.ById[weaponId].Name}`, Icon = Weapons.ById[weaponId].Icon or "Sword" })
end

function CombatService:Init()
	Net.handle("Attack", attack, 0)
	Net.handle("Charge", charge, 0.1)
	Net.handle("Roll", roll, 0.2)
	Net.handle("Block", setBlocking, 0)
	-- stats change with the profile (weapon, attributes, pets, armor, upgrades, boosts)
	DataService.Changed:Connect(function(player: Player, key: string)
		local state = states[player]
		if state then
			state.stats = nil
		end
		if key == "Weapons" then
			task.defer(CombatService.EnsureStarterWeapon, CombatService, player)
		end
	end)
	local function loaded(player: Player)
		task.defer(CombatService.EnsureStarterWeapon, CombatService, player)
	end
	DataService.Loaded:Connect(loaded)
	for _, player in ipairs(Players:GetPlayers()) do
		if DataService:Get(player) then
			loaded(player)
		end
	end
	local function watchRespawn(player: Player)
		player.CharacterAdded:Connect(function()
			local state = states[player]
			if state then
				state.blocking = false
				state.rollUntil = 0
				state.chargeAt = nil
				state.guard = Combat.Block.GuardMax
			end
			player:SetAttribute("Blocking", false)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watchRespawn(player)
	end
	Players.PlayerAdded:Connect(watchRespawn)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
