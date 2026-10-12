--!strict
-- Player combat (docs/enemies_npcs_pets_brief.txt Part A, DESIGN.md section 2). Server authoritative; the client
-- only sends its inputs and shows the results.
--   Net.send("Attack", aimDir: Vector3, aimPoint: Vector3?)   rate = weapon HitsPerSecond x (1 + attack speed); each
--                                         attack is the next step of the category's combo (Config/Combat Combos)
--                                         chosen here; no attack while a roll is under way
--   Net.send("Roll", dir: Vector3?)       cooldown = Stats RollCooldown, i-frames Config/Combat Roll.IFrames
--   Net.send("Block", holding: boolean)   damage x (1 - Stats Block), speed x Combat.Block.SpeedFactor, no attacks
--   CombatService:DamagePlayer(player, raw, source?) -> dealt   (enemies and bosses call this)
-- Events: "Swing" (attacker, category, step, dir, speed) to the other players nearby so they see the swing,
-- "Hit" (position, damage, crit, finisher, category) to the attacker, "Impact" (position, category, crit, finisher)
-- to the others. Animations / VFX / SFX never decide damage.
-- Hits use the shapes of Config/Combat (with the combo step's overrides) at the step's impact moment.
-- Damage per hit = Stats.compute WeaponDamage (the weapon's OWN zone base x category x rarity x attributes x pets x
-- Rebirth Shop; NEVER the player's zone, rule 1B) x the step's Damage x crit (Stats CritChance, +20% with daggers;
-- x Stats CritDamage) x (1 + Boss Slayer) on bosses.
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
	comboCategory: string?,
	lastRoll: number,
	rollUntil: number,
	rollEnd: number,
	blocking: boolean,
	stats: { [string]: any }?,
}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()

-- SHAPES[category][step] = the category shape with the step's overrides (a `false` field removes a feature,
-- for example the Heavy slam on the finisher).
local SHAPES: { [string]: { { [string]: any } } } = {}
for categoryId, steps in pairs(Combat.Combos) do
	local base = Combat.Shapes[categoryId] or Combat.Shapes.Sword
	SHAPES[categoryId] = {}
	for index, step in ipairs(steps) do
		local shape = table.clone(base)
		for key, value in pairs(step.Shape or {}) do
			shape[key] = value
		end
		SHAPES[categoryId][index] = shape
	end
end

local function stateOf(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { lastAttack = -math.huge, combo = 0, comboAt = 0, comboCategory = nil, lastRoll = -math.huge, rollUntil = 0, rollEnd = 0, blocking = false, stats = nil }
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

type Strike = { multiplier: number, bonusCrit: number, finisher: boolean, knockback: any, category: string }

-- One hit on one enemy: crit roll, Boss Slayer, knockback, the "Hit" number for the attacker and the "Impact" for
-- the players around.
local function hit(player: Player, enemy: any, stats: { [string]: any }, strike: Strike)
	if not enemy.alive then
		return
	end
	local multiplier, bonusCrit = strike.multiplier, strike.bonusCrit
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
	Net.fire(player, "Hit", at, damage, crit, strike.finisher, strike.category)
	for _, viewer in ipairs(visualTo(at)) do
		if viewer ~= player then
			Net.fire(viewer, "Impact", at, strike.category, crit, strike.finisher)
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
local function nextStep(state: PlayerState, categoryId: string, now: number, interval: number): number
	local steps = Combat.Combos[categoryId] or Combat.Combos.Sword
	if state.comboCategory ~= categoryId or now - state.comboAt > interval + Combat.ComboReset then
		state.combo = 0
	end
	state.combo = state.combo % #steps + 1
	state.comboAt = now
	state.comboCategory = categoryId
	return state.combo
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
	local id = if category and Combat.Combos[category.Id] then category.Id else "Sword"
	local speed = 1 + (stats.AttackSpeed or 0)
	local hitsPerSecond = (if category then category.HitsPerSecond else 1) * speed
	local now = os.clock()
	if now < state.rollEnd then
		return -- attacks cannot start during a roll
	end
	if now - state.lastAttack < Combat.RateTolerance / hitsPerSecond then
		return -- faster than the weapon allows
	end
	state.lastAttack = now
	local dir = if finite(aimDir) and aimDir.Magnitude > 0.01 then flat(aimDir) else flat(root.CFrame.LookVector)
	local index = nextStep(state, id, now, 1 / hitsPerSecond)
	local step = Combat.Combos[id][index]
	local shape = SHAPES[id][index]
	local impact = (step.Impact or shape.Impact) / speed
	local strike: Strike = {
		multiplier = step.Damage or 1,
		bonusCrit = shape.BonusCrit or 0,
		finisher = step.Finisher == true,
		knockback = step.Knockback,
		category = id,
	}
	local origin = root.Position
	for _, viewer in ipairs(visualTo(origin)) do
		if viewer ~= player then
			Net.fire(viewer, "Swing", player, id, index, dir, speed)
		end
	end

	if shape.Kind == "Projectile" then
		local muzzle = origin + Vector3.new(0, 1.2, 0) + dir * 1.5
		local target, distance = firstOnRay(muzzle, dir, shape.Range)
		for _, viewer in ipairs(visualTo(origin)) do
			Net.fire(viewer, "Projectile", muzzle, dir, shape.Speed, distance, if weapon then weapon.Element else "Physical")
		end
		if target then
			task.delay(impact + distance / shape.Speed, function()
				hit(player, target, stats, strike)
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
			local targets = inCircle(point, radius)
			for i = 1, math.min(#targets, shape.MaxTargets) do
				hit(player, targets[i].enemy, stats, strike)
			end
		end)
		return
	end
	local function strikeNow()
		local now2 = rootOf(player)
		local from = if now2 then now2.Position else origin
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
	state.rollEnd = now + Combat.Roll.Duration * Combat.RateTolerance
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
