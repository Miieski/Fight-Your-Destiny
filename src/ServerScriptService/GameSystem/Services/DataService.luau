--!strict
-- Player profiles (DESIGN.md section 11): one DataStore entry per player with a session lock,
-- UpdateAsync only, autosave, save on leave and on shutdown. In Studio without API access it
-- keeps profiles in memory for the session (one warning).
-- Replication: the client asks for a snapshot with Net.request("GetProfile"), then receives
-- Net "Data" patches { key = wholeValue } for every change.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local Profile = require(ReplicatedStorage.GameSystem.Config.Profile)
local Settings = require(ReplicatedStorage.GameSystem.Config.Settings)

local DataService = { Priority = 1 }

type Data = { [string]: any }

local STORE = Profile.Store
local profiles: { [Player]: Data } = {}
local transient: { [Player]: Data } = {} -- replicated but never saved (debug badges, ...)
local loadedEvent = Instance.new("BindableEvent")
local memoryMode = false
local store: DataStore? = nil

-- Fires (player, profile) when a profile is ready.
DataService.Loaded = loadedEvent.Event

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds missing keys from the defaults. Nested tables are only reconciled when their default is a
-- non-empty record (Settings, Daily, ...), so maps such as Weapons are never touched.
local function reconcile(target: Data, defaults: Data)
	for key, default in pairs(defaults) do
		local current = target[key]
		if current == nil then
			target[key] = deepCopy(default)
		elseif typeof(default) == "table" and typeof(current) == "table" and next(default) ~= nil then
			reconcile(current, default)
		end
	end
end

local function useMemory(reason: string)
	if not memoryMode then
		memoryMode = true
		warn(`DataService: DataStore unavailable ({reason}). Profiles are kept in memory for this session only.`)
	end
end

local function keyOf(player: Player): string
	return "Player_" .. player.UserId
end

local function snapshot(player: Player): Data
	local result = {}
	for key, value in pairs(profiles[player] or {}) do
		if not Profile.NotReplicated[key] then
			result[key] = value
		end
	end
	for key, value in pairs(transient[player] or {}) do
		result[key] = value
	end
	return result
end

-- Loads and locks the profile. Returns nil if another live server still holds the lock.
local function load(player: Player): Data?
	if memoryMode or not store then
		return Profile.new()
	end
	for _ = 1, STORE.LoadRetries do
		local locked = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(keyOf(player), function(old: Data?)
				local entry = old or {}
				local session = entry.Session
				if session and session.JobId ~= game.JobId and os.time() - (session.Time or 0) < STORE.LockSeconds then
					locked = true
					return nil
				end
				entry.Session = { JobId = game.JobId, Time = os.time() }
				return entry
			end)
		end)
		if not ok then
			if RunService:IsStudio() then
				useMemory(tostring(result))
				return Profile.new()
			end
			warn(`DataService: load failed for {player.UserId}: {result}`)
		elseif not locked then
			local profile = if typeof(result) == "table" and typeof(result.Profile) == "table" then result.Profile else Profile.new()
			reconcile(profile, Profile.new())
			return profile
		end
		if not player.Parent then
			return nil
		end
		task.wait(STORE.RetrySeconds)
	end
	return nil
end

local function save(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or memoryMode or not store then
		return true
	end
	profile.LastOnline = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyOf(player), function(old: Data?)
			local entry = old or {}
			local session = entry.Session
			if session and session.JobId ~= game.JobId then
				return nil -- another server owns this profile now: never overwrite it
			end
			entry.Profile = profile
			entry.Session = if release then nil else { JobId = game.JobId, Time = os.time() }
			return entry
		end)
	end)
	if not ok then
		warn(`DataService: save failed for {player.UserId}: {err}`)
	end
	return ok
end

local function onPlayerAdded(player: Player)
	local profile = load(player)
	if not player.Parent then
		if profile then
			profiles[player] = profile
			save(player, true)
			profiles[player] = nil
		end
		return
	end
	if not profile then
		player:Kick("Your data is still open in another server. Please rejoin in a moment.")
		return
	end
	profiles[player] = profile
	transient[player] = transient[player] or {}
	Net.fire(player, "Data", snapshot(player))
	loadedEvent:Fire(player, profile)
end

function DataService:Get(player: Player): Data?
	return profiles[player]
end

-- Waits until the profile is loaded (or the timeout / the player leaves).
function DataService:WaitFor(player: Player, timeout: number?): Data?
	local deadline = os.clock() + (timeout or STORE.WaitSeconds)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Sets a top-level key and replicates the whole value to the owner.
function DataService:Set(player: Player, key: string, value: any)
	local profile = profiles[player]
	if profile then
		profile[key] = value
		if not Profile.NotReplicated[key] then
			Net.fire(player, "Data", { [key] = value })
		end
	end
end

-- Replicated to the owner, never saved (used for test/debug state).
function DataService:SetTransient(player: Player, key: string, value: any)
	local values = transient[player]
	if values then
		values[key] = value
		Net.fire(player, "Data", { [key] = value })
	end
end

function DataService:GetTransient(player: Player, key: string): any
	local values = transient[player]
	return values and values[key]
end

function DataService:AddGold(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		DataService:Set(player, "Gold", math.max(0, profile.Gold + amount))
	end
end

function DataService:AddDiamonds(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		DataService:Set(player, "Diamonds", math.max(0, math.floor(profile.Diamonds + amount)))
	end
end

function DataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE.Name)
	end)
	if ok then
		store = result
	else
		useMemory(tostring(result))
	end
	if RunService:IsStudio() and store then
		-- Probe once so Studio without API access goes straight to memory mode.
		local probeOk, probeErr = pcall(function()
			return (store :: DataStore):GetAsync("Probe")
		end)
		if not probeOk then
			useMemory(tostring(probeErr))
		end
	end

	Net.handle("GetProfile", function(player: Player)
		if not DataService:WaitFor(player) then
			return nil
		end
		return snapshot(player)
	end, 1)

	-- The client applies settings locally first; the server validates and stores them silently.
	Net.handle("SetSetting", function(player: Player, key: any, value: any)
		local profile = profiles[player]
		if not profile then
			return false, "Profile not loaded"
		end
		local ok, clean = Settings.validate(key, value, profile.Passes)
		if not ok then
			return false, clean, profile.Settings[key]
		end
		profile.Settings[key] = clean
		return true, clean
	end, 0.05)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
		transient[player] = nil
	end)
	game:BindToClose(function()
		if memoryMode then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + STORE.ShutdownSeconds
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService:Start()
	while true do
		task.wait(STORE.AutosaveSeconds)
		for player in pairs(profiles) do
			task.spawn(save, player, false)
		end
	end
end

return DataService
