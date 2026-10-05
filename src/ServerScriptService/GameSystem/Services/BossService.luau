--!strict
-- Boss rooms (docs/enemies_npcs_pets_brief.txt Part C, DESIGN.md section 7). Functional skeleton, no patterns yet.
--   BossGate at the end of sub-zone 4: prompts "Enter solo" / "Enter with team". With a team, the leader opens the
--   room for the members standing in sub-zone 4 (max 5); a member pressing the gate during the lobby joins it.
--   Each group gets its own copy of ServerStorage.BossArenas.<ZoneId> in workspace.BossArenas.
--   Flow: lobby 5 s (the door is open) -> door locks -> the 2 mini-bosses -> both dead -> the boss (2 s intro,
--   invulnerable) -> boss dies -> rewards screen -> 15 s later everyone is back at the Entrance of sub-zone 4.
--   Boss HP x (1 + 0.6 x (players - 1)). A dead player loses 35% Gold (ZoneService) and watches as a spectator until
--   the end; if everyone is dead the room closes.
--   Rewards: for the boss and for each mini-boss, every player who dealt at least 5% of its HP receives, rolled
--   separately: Gold (x Gold multiplier), the loot roll (mini 4%, boss 6%, x Loot Luck), diamonds (mini 15%:
--   2 + z / 3 + z, boss 40%: 10 + 3z, chance x (1 + Diamond Luck)) and, the first time they beat this boss, its Key.
--   BossService:Enter(player, zoneId, withTeam, admin?) / Leave(player, stay?) / RoomOf(player)
--   Hooks for the boss patterns (next step): Config/Bosses.Patterns, BossService.OnEnrage(room, state) at 50% HP.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Bosses = require(ReplicatedStorage.GameSystem.Config.Bosses)
local Enemies = require(ReplicatedStorage.GameSystem.Config.Enemies)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local Playtest = require(ReplicatedStorage.GameSystem.Config.Playtest)
local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local IndexService = require(script.Parent.IndexService)
local LootService = require(script.Parent.LootService)
local RewardService = require(script.Parent.RewardService)
local TeamService = require(script.Parent.TeamService)
local ZoneService = require(script.Parent.ZoneService)

local BossService = { Priority = 7 }

type Item = { Text: string, Icon: string, Rarity: number? }
export type Room = {
	key: string,
	zoneId: string,
	model: Model,
	slot: number,
	players: { Player },
	phase: string,
	scale: number,
	group: any,
	spectators: { [Player]: boolean },
	rewards: { [Player]: { Item } },
	connections: { RBXScriptConnection },
	doorParts: { BasePart },
	doorPrompt: ProximityPrompt?,
	enraged: boolean,
	closing: boolean,
}

local rooms: { [string]: Room } = {}
local roomOf: { [Player]: Room } = {}
local usedSlots: { [number]: boolean } = {}
local rng = Random.new()
local counter = 0

local function notify(player: Player, text: string, kind: string?, icon: string?)
	Net.fire(player, "Notify", { Kind = kind or "info", Text = text, Icon = icon })
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function broadcast(room: Room, data: { [string]: any })
	data.ZoneId = room.zoneId
	for _, player in ipairs(room.players) do
		if player.Parent then
			Net.fire(player, "BossRoom", data)
		end
	end
end

function BossService:RoomOf(player: Player): Room?
	return roomOf[player]
end

-- Empty hook for the next step (boss patterns): runs once when the boss falls under ENRAGE_AT of its HP.
function BossService.OnEnrage(room: Room, state: any)
	state.model:SetAttribute("Enraged", true)
	for _, player in ipairs(room.players) do
		notify(player, `{state.def.Name} is enraged!`, "error")
	end
end

local function setDoor(room: Room, open: boolean)
	for _, part in ipairs(room.doorParts) do
		part.CanCollide = not open
		part.Transparency = if open then math.max(part:GetAttribute("BaseTransparency") or 0, 0.6) else (part:GetAttribute("BaseTransparency") or 0)
	end
	if room.doorPrompt then
		room.doorPrompt.Enabled = open
	end
end

local function spectatorSpot(room: Room): CFrame
	local pads = room.model:FindFirstChild("PlayerSpawns")
	local first = pads and pads:FindFirstChildWhichIsA("BasePart")
	local base = if first then first.Position else (room.model.PrimaryPart :: BasePart).Position
	local boss = room.model:FindFirstChild("BossSpawn", true) :: BasePart?
	local look = if boss then Vector3.new(boss.Position.X, base.Y, boss.Position.Z) else base + Vector3.zAxis
	return CFrame.lookAt(base + Vector3.yAxis * Bosses.SPECTATOR_HEIGHT, look)
end

local function clearPlayer(player: Player)
	player:SetAttribute("ArenaKey", nil)
	player:SetAttribute("ArenaZone", nil)
	player:SetAttribute("Spectating", nil)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
	end
end

local function destroyRoom(room: Room)
	if rooms[room.key] ~= room then
		return
	end
	rooms[room.key] = nil
	EnemyService:EndGroup(room.key)
	for _, connection in ipairs(room.connections) do
		connection:Disconnect()
	end
	usedSlots[room.slot] = nil
	room.model:Destroy()
end

function BossService:Leave(player: Player, stay: boolean?)
	local room = roomOf[player]
	if not room then
		return
	end
	roomOf[player] = nil
	local index = table.find(room.players, player)
	if index then
		table.remove(room.players, index)
	end
	room.spectators[player] = nil
	clearPlayer(player)
	if player.Parent then
		Net.fire(player, "BossRoom", { Phase = "Left", ZoneId = room.zoneId })
		if not stay then
			local entrance = ZoneService:EntranceOf(room.zoneId, Zones.BOSS_SUBZONE)
			if entrance then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health <= 0 then
					player:LoadCharacter() -- spectators come back alive at the entrance
				else
					ZoneService:Teleport(player, entrance)
				end
			end
		end
	end
	if #room.players == 0 then
		destroyRoom(room)
	end
end

local function closeRoom(room: Room, seconds: number)
	if room.closing then
		return
	end
	room.closing = true
	task.delay(seconds, function()
		for _, player in ipairs(table.clone(room.players)) do
			BossService:Leave(player)
		end
		destroyRoom(room)
	end)
end

local function checkWipe(room: Room)
	if room.phase == "Victory" or room.phase == "Failed" then
		return
	end
	for _, player in ipairs(room.players) do
		if not room.spectators[player] and rootOf(player) then
			return
		end
	end
	room.phase = "Failed"
	broadcast(room, { Phase = "Failed", Seconds = Bosses.FAIL_SECONDS })
	EnemyService:EndGroup(room.key)
	closeRoom(room, Bosses.FAIL_SECONDS)
end

local function placeSpectator(room: Room, player: Player)
	local character = player.Character
	local root = character and character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root or roomOf[player] ~= room then
		return
	end
	task.wait(0.2)
	character:PivotTo(spectatorSpot(room))
	root.Anchored = true
end

local function watchCharacter(room: Room, player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	table.insert(room.connections, humanoid.Died:Connect(function()
		if roomOf[player] ~= room then
			return
		end
		if room.phase == "Lobby" then
			return -- the room has not started: the respawn goes back to sub-zone 4 (ZoneService)
		end
		room.spectators[player] = true
		player:SetAttribute("Spectating", true)
		notify(player, "You fell! You watch the fight until it ends.", "death")
		checkWipe(room)
	end))
end

local function addItem(room: Room, player: Player, item: Item)
	room.rewards[player] = room.rewards[player] or {}
	table.insert(room.rewards[player], item)
end

-- Rewards of one mini-boss / boss for every player with at least 5% of its HP in damage, rolled per player.
local function rewardEnemy(room: Room, state: any)
	local def = state.def
	local zone = Zones.ById[room.zoneId]
	local roomDefs = Enemies.BossRoom[room.zoneId]
	local isBoss = def.Tier == "boss"
	for _, player in ipairs(room.players) do
		local dealt = state.damage[player] or 0
		local profile = DataService:Get(player)
		if profile and player.Parent and dealt >= state.maxHP * Bosses.REWARD_MIN_SHARE then
			local stats = Stats.compute(profile, { now = os.time() })
			local gold = math.max(1, math.floor(def.Gold * (stats.GoldMult or 1) * Playtest.GoldMultiplier + 0.5))
			DataService:AddGold(player, gold)
			addItem(room, player, { Text = `{Format.number(gold)} Gold ({def.Name})`, Icon = "Gold" })
			RewardService.progress(player, "EarnGold", gold)
			RewardService.progress(player, if isBoss then "BeatBoss" else "KillMiniBoss", 1)
			IndexService:Discover(player, def.Id)
			if rng:NextNumber() < LootService.chance(def, stats.LootMult) then
				local kind = LootService:Grant(player, def)
				if kind then
					addItem(room, player, { Text = `{Rarities.get(def.LootRarity).Name} {def.Loot.Name} ({kind})`, Icon = if kind == "Armor" then "Defense" else kind, Rarity = def.LootRarity })
				end
			end
			local chance = (if isBoss then Enemies.DIAMONDS.BossChance else Enemies.DIAMONDS.MiniChance) * (1 + (stats.DiamondLuck or 0))
			if rng:NextNumber() < chance then
				local amount = if isBoss then 10 + 3 * zone.Index elseif def == roomDefs.Mini1 then 2 + zone.Index else 3 + zone.Index
				DataService:AddDiamonds(player, amount)
				addItem(room, player, { Text = `{amount} Diamonds`, Icon = "Diamond" })
			end
			if isBoss and not (profile.Keys and profile.Keys[room.zoneId]) then
				local keys = table.clone(profile.Keys or {})
				keys[room.zoneId] = true
				DataService:Set(player, "Keys", keys)
				addItem(room, player, { Text = `{zone.Name} Boss Key (first victory)`, Icon = "Key" })
			end
			DataService:Save(player)
		end
	end
end

local function victory(room: Room, boss: any)
	room.phase = "Victory"
	setDoor(room, true)
	for _, player in ipairs(room.players) do
		Net.fire(player, "BossRewards", {
			Boss = boss.def.Name,
			ZoneId = room.zoneId,
			Items = room.rewards[player] or {},
			Seconds = Bosses.CLEANUP_SECONDS,
		})
	end
	broadcast(room, { Phase = "Victory", Seconds = Bosses.CLEANUP_SECONDS, Name = boss.def.Name })
	closeRoom(room, Bosses.CLEANUP_SECONDS)
end

local function at(room: Room, name: string): Vector3
	local point = room.model:FindFirstChild(name, true) :: BasePart
	return point.Position - Vector3.yAxis * point.Size.Y / 2
end

local function startFight(room: Room)
	if rooms[room.key] ~= room or #room.players == 0 then
		return
	end
	room.phase = "Minis"
	setDoor(room, false)
	room.scale = 1 + Bosses.HP_PER_EXTRA_PLAYER * (#room.players - 1)
	local defs = Enemies.BossRoom[room.zoneId]
	local set = {}
	for _, player in ipairs(room.players) do
		set[player] = true
	end
	local minisLeft = 2
	room.group = EnemyService:CreateGroup(room.key, { kind = "arena", players = set, onDeath = function(state: any)
		rewardEnemy(room, state)
		if state.def.Tier == "mini" then
			minisLeft -= 1
			if minisLeft == 0 and room.phase == "Minis" then
				room.phase = "Boss"
				local boss = EnemyService:Spawn(room.group, defs.Boss, at(room, "BossSpawn"), { hpMult = room.scale })
				EnemyService:Intro(boss, Bosses.INTRO_SECONDS)
				boss.model:SetAttribute("ArenaKey", room.key)
				broadcast(room, { Phase = "Boss", Name = defs.Boss.Name, Seconds = Bosses.INTRO_SECONDS })
				table.insert(room.connections, boss.model:GetAttributeChangedSignal("HP"):Connect(function()
					if not room.enraged and boss.alive and boss.hp <= boss.maxHP * Bosses.ENRAGE_AT then
						room.enraged = true
						BossService.OnEnrage(room, boss)
					end
				end))
			end
		elseif state.def.Tier == "boss" then
			victory(room, state)
		end
	end })
	for _, name in ipairs({ "Mini1", "Mini2" }) do
		local mini = EnemyService:Spawn(room.group, defs[name], at(room, "MiniBossSpawn" .. string.sub(name, 5)))
		mini.model:SetAttribute("ArenaKey", room.key)
	end
	broadcast(room, { Phase = "Minis", Name = `{defs.Mini1.Name} & {defs.Mini2.Name}` })
end

local function addPlayer(room: Room, player: Player, index: number)
	roomOf[player] = room
	table.insert(room.players, player)
	player:SetAttribute("ArenaKey", room.key)
	player:SetAttribute("ArenaZone", room.zoneId)
	local pads = room.model:FindFirstChild("PlayerSpawns")
	local list = if pads then pads:GetChildren() else {}
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	local pad = list[((index - 1) % math.max(1, #list)) + 1] :: BasePart?
	local position = if pad then pad.Position + Vector3.yAxis * 3 else at(room, "BossSpawn") + Vector3.new(0, 3, 40)
	local boss = room.model:FindFirstChild("BossSpawn", true) :: BasePart?
	local look = if boss then Vector3.new(boss.Position.X, position.Y, boss.Position.Z) else position + Vector3.zAxis
	ZoneService:Teleport(player, CFrame.lookAt(position, look))
	if player.Character then
		task.spawn(watchCharacter, room, player, player.Character)
	end
	table.insert(room.connections, player.CharacterAdded:Connect(function(character)
		if roomOf[player] ~= room then
			return
		end
		task.spawn(watchCharacter, room, player, character)
		if room.spectators[player] then
			placeSpectator(room, player)
		elseif room.phase == "Lobby" then
			-- died in the lobby: out of the room
			task.defer(BossService.Leave, BossService, player)
		end
	end))
	Net.fire(player, "BossRoom", { Phase = "Lobby", Seconds = Bosses.LOBBY_SECONDS, ZoneId = room.zoneId, Name = Enemies.BossRoom[room.zoneId].Boss.Name })
end

local function createRoom(zoneId: string): Room?
	local template = ServerStorage:FindFirstChild("BossArenas") and ServerStorage.BossArenas:FindFirstChild(zoneId)
	if not (template and template:IsA("Model") and template.PrimaryPart) then
		return nil
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	counter += 1
	local model = template:Clone()
	model:PivotTo(CFrame.new(Playtest.ArenaOrigin + Vector3.new(slot * Playtest.ArenaSpacing, 0, 0)))
	model.Parent = workspace:FindFirstChild("BossArenas") or workspace
	local room: Room = {
		key = `boss_{zoneId}_{counter}`, zoneId = zoneId, model = model, slot = slot, players = {}, phase = "Lobby",
		scale = 1, group = nil, spectators = {}, rewards = {}, connections = {}, doorParts = {}, doorPrompt = nil,
		enraged = false, closing = false,
	}
	local door = model:FindFirstChild("Door")
	if door then
		local parts = if door:IsA("BasePart") then { door } else door:GetDescendants()
		for _, part in ipairs(parts) do
			if part:IsA("BasePart") then
				part:SetAttribute("BaseTransparency", part.Transparency)
				table.insert(room.doorParts, part)
			end
		end
		local anchorPart = room.doorParts[1]
		if anchorPart then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "LeavePrompt"
			prompt.ActionText = "Leave"
			prompt.ObjectText = "Boss room"
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 18
			prompt.RequiresLineOfSight = false
			prompt.Parent = anchorPart
			room.doorPrompt = prompt
			table.insert(room.connections, prompt.Triggered:Connect(function(who)
				if roomOf[who] == room and (room.phase == "Lobby" or room.phase == "Victory" or room.phase == "Failed") then
					BossService:Leave(who)
				end
			end))
		end
	end
	rooms[room.key] = room
	setDoor(room, true)
	task.delay(Bosses.LOBBY_SECONDS, startFight, room)
	return room
end

local function gateOf(zoneId: string): BasePart?
	local folder = workspace.Zones:FindFirstChild(zoneId)
	local subZone = folder and folder:FindFirstChild(Zones.subZoneId(zoneId, Zones.BOSS_SUBZONE))
	local gate = subZone and subZone:FindFirstChild("BossGate")
	local interact = gate and gate:FindFirstChild("Interact", true)
	return if interact and interact:IsA("BasePart") then interact else nil
end

local function canEnter(player: Player, zoneId: string): (boolean, string?)
	local profile = DataService:Get(player)
	local zone = Zones.ById[zoneId]
	if not profile or not zone then
		return false, "Not ready yet"
	end
	if zone.Index > Bosses.PLAYABLE_ZONES or not Enemies.BossRoom[zoneId].Boss.Rig then
		return false, `{zone.Name}'s boss room is coming soon`
	end
	if not Zones.isUnlocked(profile.Zones, zoneId) or not profile.SubZones[Zones.subZoneId(zoneId, Zones.BOSS_SUBZONE)] then
		return false, "Open the last gate of this zone first"
	end
	if roomOf[player] then
		return false, "You are already in a boss room"
	end
	if not rootOf(player) then
		return false, "Not ready yet"
	end
	return true, nil
end

-- A player at the gate: solo, with the team (leader), or joining the team's room during its lobby.
function BossService:Enter(player: Player, zoneId: string, withTeam: boolean, admin: boolean?): (boolean, string?)
	local ok, reason = canEnter(player, zoneId)
	if not ok and not (admin and reason == "Open the last gate of this zone first") then
		return false, reason
	end
	if not admin then
		local gate = gateOf(zoneId)
		local root = rootOf(player)
		if gate and root and (root.Position - gate.Position).Magnitude > Bosses.GATE_RANGE then
			return false, "Come closer to the gate"
		end
	end
	local team = TeamService.getTeam(player)
	-- a team mate's room still in its lobby: join it
	if team then
		for _, member in ipairs(team.Members) do
			local room = roomOf[member]
			if room and room.zoneId == zoneId and room.phase == "Lobby" and #room.players < Bosses.MAX_PLAYERS then
				addPlayer(room, player, #room.players + 1)
				return true, "Joined your team's boss room"
			end
		end
	end
	local group = { player }
	if withTeam then
		if not team then
			return false, "You are not in a team (Team menu)"
		end
		if team.Leader ~= player then
			return false, "Only the team leader can start a team fight"
		end
		for _, member in ipairs(team.Members) do
			if member ~= player and #group < Bosses.MAX_PLAYERS and member:GetAttribute("CurrentSubZone") == Zones.subZoneId(zoneId, Zones.BOSS_SUBZONE) and canEnter(member, zoneId) then
				table.insert(group, member)
			end
		end
	end
	local room = createRoom(zoneId)
	if not room then
		return false, "The boss arena is not built yet"
	end
	for index, member in ipairs(group) do
		addPlayer(room, member, index)
	end
	if withTeam and team then
		for _, member in ipairs(team.Members) do
			if not table.find(group, member) then
				notify(member, `Your team entered the {Zones.ById[zoneId].Name} boss room: press the gate within {Bosses.LOBBY_SECONDS} s to join`, "info", "Team")
			end
		end
	end
	return true, nil
end

local function hookGates()
	for _, zone in ipairs(Zones.List) do
		local interact = gateOf(zone.Id)
		local prompt = interact and interact:FindFirstChildOfClass("ProximityPrompt")
		if interact and prompt then
			prompt.ActionText = "Enter solo"
			prompt.ObjectText = "Boss room"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			local teamPrompt = Instance.new("ProximityPrompt")
			teamPrompt.Name = "TeamPrompt"
			teamPrompt.ActionText = "Enter with team"
			teamPrompt.ObjectText = "Boss room"
			teamPrompt.KeyboardKeyCode = Enum.KeyCode.F
			teamPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
			teamPrompt.HoldDuration = prompt.HoldDuration
			teamPrompt.MaxActivationDistance = prompt.MaxActivationDistance
			teamPrompt.RequiresLineOfSight = false
			teamPrompt.UIOffset = Vector2.new(0, 80)
			teamPrompt.Parent = interact
			local function use(player: Player, withTeam: boolean)
				local ok, message = BossService:Enter(player, zone.Id, withTeam)
				if not ok and message then
					notify(player, message, "error")
				elseif ok and message then
					notify(player, message, "info", "Team")
				end
			end
			prompt.Triggered:Connect(function(player)
				use(player, false)
			end)
			teamPrompt.Triggered:Connect(function(player)
				use(player, true)
			end)
		end
	end
end

function BossService:Init()
	hookGates()
	Net.handle("LeaveBossRoom", function(player: Player)
		local room = roomOf[player]
		if not room then
			return false, "Not in a boss room"
		end
		if room.phase ~= "Victory" and room.phase ~= "Failed" and room.phase ~= "Lobby" then
			return false, "The fight is not over"
		end
		BossService:Leave(player)
		return true, nil
	end, 1)
	Players.PlayerRemoving:Connect(function(player)
		local room = roomOf[player]
		BossService:Leave(player, true)
		if room and rooms[room.key] then
			checkWipe(room)
		end
	end)
end

return BossService
