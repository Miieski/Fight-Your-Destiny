--!strict
-- PLACEHOLDER enemies: one generic dummy per spawn point, tinted per zone, with the real HP and
-- Gold values of the enemy it stands for. No AI and no attacks yet. Enemies only exist in
-- sub-zones where a player is present.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Playtest = require(ReplicatedStorage.GameSystem.Config.Playtest)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local RewardService = require(script.Parent.RewardService)

local EnemyService = { Priority = 3 }

type EnemyState = { def: any, hp: number, model: Model, group: any, cframe: CFrame, damage: { [Player]: number }, alive: boolean, radius: number }
type Group = { enemies: { EnemyState }, active: boolean, emptySince: number?, onDeath: ((EnemyState) -> ())? }

local groups: { [string]: Group } = {}
local container: Folder

local function fallbackDummy(): Model
	local model = Instance.new("Model")
	model.Name = "Dummy"
	local root = Instance.new("Part")
	root.Name = "Body"
	root.Size = Vector3.new(3, 5, 2.5)
	root.Anchored = true
	root.Material = Enum.Material.SmoothPlastic
	root.CFrame = CFrame.new(0, 2.5, 0)
	root.Parent = model
	model.PrimaryPart = root
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local function template(): Model
	local placeholder = ServerStorage.Enemies:FindFirstChild("_Placeholder")
	local dummy = placeholder and placeholder:FindFirstChild("Dummy")
	return if dummy and dummy:IsA("Model") then dummy else fallbackDummy()
end

local function addInfo(model: Model, def: any, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromScale(8, 1.8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.6, 0)
	gui.MaxDistance = 140
	gui.Adornee = model.PrimaryPart
	local name = Instance.new("TextLabel")
	name.Name = "EnemyName"
	name.Size = UDim2.fromScale(1, 0.5)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.Fantasy
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0
	name.Text = def.Name
	name.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromScale(0.1, 0.56)
	bar.Size = UDim2.fromScale(0.8, 0.36)
	bar.BackgroundColor3 = Color3.fromRGB(40, 24, 16)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(217, 59, 59)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local hp = Instance.new("TextLabel")
	hp.Name = "HP"
	hp.Size = UDim2.fromScale(1, 1)
	hp.BackgroundTransparency = 1
	hp.Font = Enum.Font.GothamMedium
	hp.TextScaled = true
	hp.TextColor3 = Color3.new(1, 1, 1)
	hp.TextStrokeTransparency = 0.3
	hp.Text = Format.number(def.MaxHP)
	hp.ZIndex = 2
	hp.Parent = bar
	gui.Parent = model
end

local function spawnEnemy(group: Group, def: any, cframe: CFrame): EnemyState
	local model = template():Clone()
	local scale = Playtest.DummyScale[def.Role] or 1
	model:ScaleTo(scale)
	model.Name = def.Id
	model:SetAttribute("EnemyId", def.Id)
	local tint = Playtest.DummyColors[def.ZoneId]
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = d.Name == "Body"
			if d.Name == "Body" and tint then
				d.Color = tint
			end
		end
	end
	model:PivotTo(cframe)
	local size = model:GetExtentsSize()
	addInfo(model, def, size.Y)
	model.Parent = container
	local state: EnemyState = {
		def = def, hp = def.MaxHP, model = model, group = group, cframe = cframe,
		damage = {}, alive = true, radius = math.max(size.X, size.Z) / 2,
	}
	table.insert(group.enemies, state)
	return state
end

local function remove(state: EnemyState)
	state.alive = false
	local index = table.find(state.group.enemies, state)
	if index then
		table.remove(state.group.enemies, index)
	end
	state.model:Destroy()
end

local function deathEffect(position: Vector3)
	local vfx = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets.VFX:FindFirstChild("Enemy_Death_Puff")
	if vfx and vfx:IsA("BasePart") then
		local clone = vfx:Clone()
		clone.CFrame = CFrame.new(position)
		clone.Parent = workspace:FindFirstChild("VFX") or workspace
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d:Emit(d:GetAttribute("EmitCount") or 12)
			end
		end
		Debris:AddItem(clone, 2)
	end
end

-- Applies damage decided by CombatService. Returns true if the enemy died.
function EnemyService:Damage(player: Player, state: EnemyState, amount: number): boolean
	if not state.alive then
		return false
	end
	local dealt = math.min(state.hp, amount)
	state.hp = math.max(0, state.hp - amount)
	state.damage[player] = (state.damage[player] or 0) + amount
	RewardService.progress(player, "DealDamage", dealt)
	local info = state.model:FindFirstChild("Info")
	if info then
		local bar = info:FindFirstChild("Bar") :: any
		bar.Fill.Size = UDim2.fromScale(state.hp / state.def.MaxHP, 1)
		bar.HP.Text = Format.number(state.hp)
	end
	if state.hp > 0 then
		return false
	end
	-- The player who dealt the most damage gets the Gold (DESIGN.md section 5).
	local best, bestDamage = player, 0
	for who, dealt in pairs(state.damage) do
		if dealt > bestDamage and who.Parent then
			best, bestDamage = who, dealt
		end
	end
	local gold = state.def.Gold * Playtest.GoldMultiplier
	DataService:AddGold(best, gold)
	-- daily quests and the Index (docs/menu_systems_brief.txt D3, D4)
	RewardService.progress(best, "KillEnemies", 1)
	RewardService.progress(best, "EarnGold", gold)
	if state.def.Role == "MiniBoss" then
		RewardService.progress(best, "KillMiniBoss", 1)
	elseif state.def.Role == "Boss" then
		RewardService.progress(best, "BeatBoss", 1)
	end
	IndexService:Discover(best, state.def.Id)
	deathEffect(state.model:GetPivot().Position + Vector3.new(0, 2.5, 0))
	local group, def, cframe = state.group, state.def, state.cframe
	remove(state)
	if group.onDeath then
		group.onDeath(state)
	else
		task.delay(Enemies.RESPAWN_SECONDS, function()
			if group.active then
				spawnEnemy(group, def, cframe)
			end
		end)
	end
	return true
end

-- Living enemies whose body is within range of position.
function EnemyService:GetNear(position: Vector3, range: number): { EnemyState }
	local found = {}
	for _, group in pairs(groups) do
		for _, state in ipairs(group.enemies) do
			local offset = state.model:GetPivot().Position - position
			if state.alive and Vector3.new(offset.X, 0, offset.Z).Magnitude <= range + state.radius and math.abs(offset.Y) < 14 then
				table.insert(found, state)
			end
		end
	end
	return found
end

local function clear(group: Group)
	group.active = false
	for _, state in ipairs(table.clone(group.enemies)) do
		remove(state)
	end
end

-- Spawns the enemies of a sub-zone on its spawn points (about ALIVE_PER_SUBZONE in total).
local function activate(subZoneId: string, spawns: Folder)
	local group: Group = { enemies = {}, active = true }
	groups[subZoneId] = group
	local defs = Enemies.BySubZone[subZoneId]
	local perType = math.floor(Enemies.ALIVE_PER_SUBZONE / #defs)
	local extra = Enemies.ALIVE_PER_SUBZONE - perType * #defs
	for i, def in ipairs(defs) do
		local wanted = perType + (if i <= extra then 1 else 0)
		for _, point in ipairs(spawns:GetChildren()) do
			if wanted > 0 and point:IsA("BasePart") and point:GetAttribute("EnemyId") == def.Id then
				spawnEnemy(group, def, CFrame.new(point.Position - Vector3.new(0, point.Size.Y / 2, 0)))
				wanted -= 1
			end
		end
	end
end

-- Called by ZoneService with the sub-zones that currently have players in them.
function EnemyService:SetOccupied(occupied: { [string]: boolean })
	for subZoneId in pairs(occupied) do
		local group = groups[subZoneId]
		if group then
			group.emptySince = nil
		else
			local zoneId, n = Zones.parseSubZoneId(subZoneId)
			local zoneFolder = zoneId and workspace.Zones:FindFirstChild(zoneId)
			local subZone = zoneFolder and zoneFolder:FindFirstChild(subZoneId)
			local spawns = subZone and subZone:FindFirstChild("Spawns")
			if spawns and n then
				activate(subZoneId, spawns :: Folder)
			end
		end
	end
	for subZoneId, group in pairs(groups) do
		if not occupied[subZoneId] and not group.onDeath then
			group.emptySince = group.emptySince or os.clock()
			if os.clock() - (group.emptySince :: number) > Playtest.EmptySubZoneDespawnSeconds then
				clear(group)
				groups[subZoneId] = nil
			end
		end
	end
end

-- Boss room flow: both mini-bosses first, then the boss. onCleared runs when the boss dies.
function EnemyService:StartArena(key: string, arena: Model, zoneId: string, onCleared: () -> ())
	local room = Enemies.BossRoom[zoneId]
	local group: Group = { enemies = {}, active = true }
	groups[key] = group
	local function at(name: string): CFrame
		local point = arena:FindFirstChild(name) :: BasePart
		return CFrame.new(point.Position - Vector3.new(0, point.Size.Y / 2, 0))
	end
	local minisLeft = 2
	group.onDeath = function(state: EnemyState)
		if state.def.Role == "MiniBoss" then
			minisLeft -= 1
			if minisLeft == 0 and group.active then
				spawnEnemy(group, room.Boss, at("BossSpawn"))
			end
		elseif state.def.Role == "Boss" then
			onCleared()
		end
	end
	spawnEnemy(group, room.Mini1, at("MiniBossSpawn1"))
	spawnEnemy(group, room.Mini2, at("MiniBossSpawn2"))
end

function EnemyService:EndArena(key: string)
	local group = groups[key]
	if group then
		clear(group)
		groups[key] = nil
	end
end

function EnemyService:Init()
	container = Instance.new("Folder")
	container.Name = "Enemies"
	container.Parent = workspace
end

return EnemyService
