--!strict
-- Mana and the heal channel (server only). Mana lives in the profile (saved), Stats.compute MaxMana / ManaRegen come from Mind;
-- it regenerates on a Combat.Mana.Tick loop, faster out of combat. The client reads the attributes Mana / MaxMana, written only
-- when they move by at least 1. The heal channel (Config/Combat Heal) is the staff's Block: CombatService routes it here; the
-- attribute Channeling shows the light circle to every client.
--   ManaService:Has(player, amount)  ManaService:Spend(player, amount) -> boolean  ManaService:Touch(player)  in combat
--   ManaService:Channel(player, on)  ManaService:IsChanneling(player)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)
local Stats = require(ReplicatedStorage.GameSystem.Util.Stats)
local DataService = require(script.Parent.DataService)

local ManaService = { Priority = 4 }

local CFG, HEAL = Combat.Mana, Combat.Heal

type Entry = { stats: { [string]: any }?, combatAt: number, channelFor: number, readyAt: number, shown: number, shownMax: number }
local entries: { [Player]: Entry } = {}

local function entryOf(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { stats = nil, combatAt = -math.huge, channelFor = -1, readyAt = 0, shown = -1, shownMax = -1 }
		entries[player] = entry
	end
	return entry
end

local function statsOf(player: Player, entry: Entry): { [string]: any }?
	if not entry.stats then
		local profile = DataService:Get(player)
		entry.stats = if profile then Stats.compute(profile, { now = os.time() }) else nil
	end
	return entry.stats
end

local function publish(player: Player, entry: Entry, mana: number, maxMana: number)
	if math.abs(mana - entry.shown) >= 1 or mana >= maxMana and entry.shown ~= mana then
		entry.shown = mana
		player:SetAttribute("Mana", math.floor(mana + 0.5))
	end
	if entry.shownMax ~= maxMana then
		entry.shownMax = maxMana
		player:SetAttribute("MaxMana", math.floor(maxMana + 0.5))
	end
end

function ManaService:Has(player: Player, amount: number): boolean
	local profile = DataService:Get(player)
	return profile ~= nil and (profile.Mana or 0) >= amount
end

function ManaService:Spend(player: Player, amount: number): boolean
	local profile = DataService:Get(player)
	if not profile or (profile.Mana or 0) < amount then
		return false
	end
	profile.Mana -= amount
	local entry = entryOf(player)
	entry.combatAt = os.clock()
	local stats = statsOf(player, entry)
	publish(player, entry, profile.Mana, if stats then stats.MaxMana else profile.Mana)
	return true
end

function ManaService:Touch(player: Player)
	entryOf(player).combatAt = os.clock()
end

function ManaService:IsChanneling(player: Player): boolean
	return entryOf(player).channelFor >= 0
end

local function setSpeed(player: Player, entry: Entry, factor: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local stats = statsOf(player, entry)
	if humanoid and stats then
		humanoid.WalkSpeed = stats.WalkSpeed * factor
	end
end

function ManaService:Channel(player: Player, on: boolean)
	local entry = entryOf(player)
	local channeling = entry.channelFor >= 0
	if on == channeling then
		return
	end
	if on then
		if os.clock() < entry.readyAt or not ManaService:Has(player, HEAL.ManaPerSecond * CFG.Tick) then
			return
		end
		entry.channelFor = 0
		player:SetAttribute("Channeling", true)
		setSpeed(player, entry, HEAL.SpeedFactor)
	else
		entry.channelFor = -1
		entry.readyAt = os.clock() + HEAL.Cooldown
		player:SetAttribute("Channeling", false)
		setSpeed(player, entry, 1)
	end
end

local function healOf(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- One tick of the channel: mana out, heal in, a share for the allies around.
local function channelTick(player: Player, entry: Entry, stats: { [string]: any })
	local humanoid, root = healOf(player)
	if not (humanoid and root) or entry.channelFor >= HEAL.Seconds or not ManaService:Spend(player, HEAL.ManaPerSecond * CFG.Tick) then
		ManaService:Channel(player, false)
		return
	end
	entry.channelFor += CFG.Tick
	local heal = humanoid.MaxHealth * HEAL.Fraction * (1 + (stats.HealingBonus or 0)) * CFG.Tick / HEAL.Seconds
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ally, allyRoot = healOf(other)
			if ally and allyRoot and (allyRoot.Position - root.Position).Magnitude <= HEAL.AllyRange then
				ally.Health = math.min(ally.MaxHealth, ally.Health + ally.MaxHealth * HEAL.Fraction * HEAL.AllyShare * CFG.Tick / HEAL.Seconds)
			end
		end
	end
end

function ManaService:Start()
	DataService.Changed:Connect(function(player: Player)
		local entry = entries[player]
		if entry then
			entry.stats = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CFG.Tick)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService:Get(player)
				local entry = entryOf(player)
				local stats = profile and statsOf(player, entry)
				if profile and stats then
					if entry.channelFor >= 0 then
						channelTick(player, entry, stats)
					else
						local rate = stats.ManaRegen * (if now - entry.combatAt >= CFG.OutOfCombatDelay then CFG.OutOfCombat else 1)
						profile.Mana = math.min(stats.MaxMana, (profile.Mana or 0) + rate * CFG.Tick)
					end
					profile.Mana = math.min(stats.MaxMana, profile.Mana)
					publish(player, entry, profile.Mana, stats.MaxMana)
				end
			end
		end
	end)
end

return ManaService
