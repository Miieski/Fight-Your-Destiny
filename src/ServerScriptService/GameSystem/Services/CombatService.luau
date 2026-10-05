--!strict
-- Player combat (docs/enemies_npcs_pets_brief.txt Part A, DESIGN.md section 2). Server authoritative; the client
-- only sends its inputs and shows the results.
--   Net.send("Attack", aimDir: Vector3, aimPoint: Vector3?)   rate = weapon HitsPerSecond x (1 + attack speed)
--   Net.send("Roll", dir: Vector3?)       cooldown = Stats RollCooldown, i-frames Config/Combat Roll.IFrames
--   Net.send("Block", holding: boolean)   damage x (1 - Stats Block), speed x Combat.Block.SpeedFactor, no attacks
--   CombatService:DamagePlayer(player, raw, source?) -> dealt   (enemies and bosses call this)
-- Hits use the shapes of Config/Combat at the swing's impact moment. Damage per hit = Stats.compute WeaponDamage
-- (the weapon's OWN zone base x category x rarity x attributes x pets x Rebirth Shop; NEVER the player's zone,
-- rule 1B) x crit (Stats CritChance, +20% with daggers; x Stats CritDamage) x (1 + Boss Slayer) on bosses.
-- Starter weapon: a player who owns no weapon (new player, after a Rebirth wipe) gets a free Common sword of the
-- zone they are in (Plains outside the zones).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local WeaponCategories = require(ReplicatedStorage.GameSystem.Config.WeaponCategories)
local Weapons = require(ReplicatedStorage.GameSystem.Config.Weapons)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local WeaponService = require(script.Parent.WeaponService)

local CombatService = { Priority = 5 }

type PlayerState = {
	lastAttack: number,
	combo: number,
	comboAt: number,
	lastRoll: number,
	rollUntil: number,
	blocking: boolean,
	stats: { [string]: any }?,
}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()

local function stateOf(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { lastAttack = -math.huge, combo = 0, comboAt = 0, lastRoll = -math.huge, rollUntil = 0, blocking = false, stats = nil }
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

-- One hit on one enemy: crit roll, Boss Slayer, the "Hit" number for the attacker.
local function hit(player: Player, enemy: any, stats: { [string]: any }, multiplier: number, bonusCrit: number)
	if not enemy.alive then
		return
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
	EnemyService:Damage(player, enemy, damage)
	Net.fire(player, "Hit", at, damage, crit)
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

local function attack(player: Player, aimDir: any, aimPoint: any)
	local root, humanoid = rootOf(player)
	if not (root and humanoid) or player:GetAttribute("Spectating") then
		return
	end
	local state = stateOf(player)
	if state.blocking then
		return
	end
	local weapon, category = weaponOf(player)
	local stats = CombatService:Stats(player)
	if not stats then
		return
	end
	local id = if category then category.Id else "Sword"
	local shape = Combat.Shapes[id]
	local hitsPerSecond = (if category then category.HitsPerSecond else 1) * (1 + (stats.AttackSpeed or 0))
	local now = os.clock()
	if now - state.lastAttack < Combat.RateTolerance / hitsPerSecond then
		return -- faster than the weapon allows
	end
	state.lastAttack = now
	local dir = if finite(aimDir) and aimDir.Magnitude > 0.01 then flat(aimDir) else flat(root.CFrame.LookVector)
	local multiplier = 1
	if shape.Combo then
		if now - state.comboAt > shape.ComboReset then
			state.combo = 0
		end
		state.combo = state.combo % shape.Combo + 1
		state.comboAt = now
		if state.combo == shape.Combo then
			multiplier = shape.FinisherMult
		end
	end
	local bonusCrit = shape.BonusCrit or 0
	local origin = root.Position

	if shape.Kind == "Projectile" then
		local muzzle = origin + Vector3.new(0, 1.2, 0) + dir * 1.5
		local target, distance = firstOnRay(muzzle, dir, shape.Range)
		for _, viewer in ipairs(visualTo(origin)) do
			Net.fire(viewer, "Projectile", muzzle, dir, shape.Speed, distance, if weapon then weapon.Element else "Physical")
		end
		if target then
			task.delay(shape.Impact + distance / shape.Speed, function()
				hit(player, target, stats, multiplier, bonusCrit)
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
		task.delay(shape.Impact, function()
			local targets = inCircle(point, radius)
			for i = 1, math.min(#targets, shape.MaxTargets) do
				hit(player, targets[i].enemy, stats, multiplier, bonusCrit)
			end
		end)
		return
	end
	task.delay(shape.Impact, function()
		local now2 = rootOf(player)
		local from = if now2 then now2.Position else origin
		local targets
		if shape.Kind == "Line" then
			targets = inLine(from, dir, shape.Length, shape.Width)
		else
			targets = inArc(from, dir, shape.Radius, shape.Angle)
		end
		local hitSet = {}
		for i = 1, math.min(#targets, shape.MaxTargets) do
			local enemy = targets[i].enemy
			hitSet[enemy] = true
			hit(player, enemy, stats, multiplier, bonusCrit)
		end
		if shape.SlamRadius then
			-- Heavy: a small ground slam in front, with a short stagger
			local center = from + dir * 3
			for _, viewer in ipairs(visualTo(from)) do
				Net.fire(viewer, "Burst", center, shape.SlamRadius, "Slam")
			end
			for _, entry in ipairs(inCircle(center, shape.SlamRadius)) do
				local enemy = entry.enemy
				if not hitSet[enemy] then
					hitSet[enemy] = true
					hit(player, enemy, stats, multiplier, bonusCrit)
				end
				if enemy.alive and EnemyService.Stagger then
					EnemyService:Stagger(enemy, shape.Stagger)
				end
			end
		end
	end)
end

local function roll(player: Player, dir: any)
	local root = rootOf(player)
	local state = stateOf(player)
	local stats = CombatService:Stats(player)
	if not root or state.blocking or not stats then
		return
	end
	local now = os.clock()
	if now - state.lastRoll < (stats.RollCooldown or 1.5) * Combat.RateTolerance then
		return
	end
	state.lastRoll = now
	state.rollUntil = now + Combat.Roll.IFrames
end

local function setBlocking(player: Player, holding: any)
	local state = stateOf(player)
	local _, humanoid = rootOf(player)
	local stats = CombatService:Stats(player)
	local want = holding == true
	if state.blocking == want then
		return
	end
	state.blocking = want
	player:SetAttribute("Blocking", want)
	if humanoid and stats then
		humanoid.WalkSpeed = stats.WalkSpeed * (if want then Combat.Block.SpeedFactor else 1)
	end
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
	local amount = raw
	local kind = "hit"
	if state.blocking then
		amount *= 1 - (if stats then stats.Block else 0.6)
		kind = "block"
	end
	if stats then
		amount *= 1 - (stats.DamageReduction or 0)
	end
	amount = math.max(1, math.floor(amount + 0.5))
	humanoid:TakeDamage(amount)
	Net.fire(player, "Hurt", amount, kind)
	return amount
end

-- A free Common sword of the zone the player is in when they own no weapon at all.
function CombatService:EnsureStarterWeapon(player: Player)
	local profile = DataService:Get(player)
	if not profile or next(profile.Weapons or {}) ~= nil then
		return
	end
	local zoneId = player:GetAttribute("CurrentZone")
	local zone = if typeof(zoneId) == "string" then Zones.ById[zoneId] else nil
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
	Net.handle("Roll", roll, 0.2)
	Net.handle("Block", setBlocking, 0.05)
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
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local state = states[player]
			if state then
				state.blocking = false
				state.rollUntil = 0
			end
			player:SetAttribute("Blocking", false)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
