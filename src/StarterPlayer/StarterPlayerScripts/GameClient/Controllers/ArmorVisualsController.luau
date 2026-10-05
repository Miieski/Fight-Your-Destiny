--!strict
-- Armor on the characters (docs/menu_systems_brief.txt C4): reads every player's "ArmorLook" attribute (set by
-- ArmorService) and welds the procedural pieces (GameSystem/Util/ArmorLook) to their R15 body, client-side.
-- The "Show Armor" setting off removes them (the stats stay). Players farther than VIEW_DISTANCE studs get no armor
-- parts (checked once per second), so a crowded server costs little.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorLook = require(ReplicatedStorage.GameSystem.Util.ArmorLook)
local Settings = require(script.Parent.SettingsController)

local ArmorVisualsController = { Priority = 31 }

local VIEW_DISTANCE = 150
local CHECK_SECONDS = 1

type Entry = { character: Model?, built: string?, ready: boolean }
local entries: { [Player]: Entry } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function wanted(player: Player): string
	if Settings.get("ShowArmor") == false then
		return ""
	end
	local text = player:GetAttribute("ArmorLook")
	if typeof(text) ~= "string" then
		return ""
	end
	if player ~= Players.LocalPlayer then
		local mine, theirs = rootOf(Players.LocalPlayer), rootOf(player)
		if not mine or not theirs or (mine.Position - theirs.Position).Magnitude > VIEW_DISTANCE then
			return ""
		end
	end
	return text
end

local function refresh(player: Player, force: boolean?)
	local entry = entries[player]
	local character = player.Character
	if not entry or not character or not entry.ready then
		return
	end
	local key = wanted(player)
	local folder = character:FindFirstChild("ArmorLook")
	-- rebuilt when the pieces change, on a new character, or when the body parts were replaced (folder lost)
	if not force and character == entry.character and key == entry.built and (key == "" or folder ~= nil) then
		return
	end
	entry.character = character
	entry.built = key
	if key == "" then
		ArmorLook.clear(character)
		return
	end
	if not character:FindFirstChild("UpperTorso") then
		entry.built = nil -- body not there yet: try again next check
		return
	end
	ArmorLook.apply(character, ArmorLook.parse(key), { Weld = true, LowFx = Settings.get("LowFx") == true })
end

local function track(player: Player)
	local entry: Entry = { character = nil, built = nil, ready = false }
	entries[player] = entry
	local function onCharacter(character: Model)
		entry.ready = false
		entry.built = nil
		-- the avatar's body parts and accessories arrive a moment after the character
		task.delay(1.5, function()
			if player.Character == character then
				entry.ready = true
				refresh(player, true)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	player:GetAttributeChangedSignal("ArmorLook"):Connect(function()
		refresh(player)
	end)
end

function ArmorVisualsController:Start()
	for _, player in ipairs(Players:GetPlayers()) do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
	local function all(force: boolean?)
		for player in pairs(entries) do
			refresh(player, force)
		end
	end
	Settings.changed("ShowArmor", function()
		all(true)
	end)
	Settings.changed("LowFx", function()
		all(true)
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			all(false)
		end
	end)
end

return ArmorVisualsController
