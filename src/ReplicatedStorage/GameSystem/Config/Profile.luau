--!strict
-- The player profile (DESIGN.md section 11): defaults and DataStore settings.
local Attributes = require(script.Parent.Attributes)
local Economy = require(script.Parent.Economy)
local Settings = require(script.Parent.Settings)

local Profile = {}

Profile.VERSION = 1

Profile.Store = {
	Name = "PlayerProfiles_v1",
	AutosaveSeconds = 90,
	LockSeconds = 1800, -- a session lock older than this belongs to a crashed server and may be taken
	LoadRetries = 5,
	RetrySeconds = 4,
	WaitSeconds = 20, -- how long requests wait for a profile that is still loading
	ShutdownSeconds = 25,
}

-- Keys that are saved but never sent to the client.
Profile.NotReplicated = { Purchases = true }

function Profile.new(): { [string]: any }
	return {
		Version = Profile.VERSION,
		Gold = Economy.StartGold,
		Diamonds = Economy.StartDiamonds,
		Rebirths = 0,
		RebirthCredits = 0,
		RebirthUpgrades = {},
		Keys = {},
		Zones = { Plains = true },
		SubZones = {},
		RedoneSinceRebirth = {},
		CurrentZone = "Plains",
		Attributes = Attributes.empty(), -- points bought per attribute (Config/Attributes), reset on Rebirth
		Weapons = {}, -- [uid] = { id = "plains_sword", rarity = 1 }
		Armor = {}, -- [uid] = { id = "plains_helmet", rarity = 1, locked = false } (Config/Armor)
		EquippedArmor = {}, -- { Helmet = uid, Chest = uid, Legs = uid }
		Eggs = {},
		Pets = {}, -- [uid] = { id = "plains_pet1", rarity = 1, premium = false }
		EquippedPets = {}, -- array of uids
		Trophies = {},
		Index = {},
		IndexClaimed = {},
		Boosts = {},
		Passes = {},
		Purchases = {},
		Daily = { Streak = 0, LastDay = 0 },
		Playtime = { Day = 0, Seconds = 0, Claimed = {} },
		Quests = { Day = 0, List = {} },
		Codes = {},
		Skins = {},
		Settings = Settings.defaults(),
		Stats_Lifetime = { TotalGold = 0, TotalDamage = 0, BossKills = 0, EnemyKills = 0, PlaySeconds = 0 },
		PityCounter = 0, -- weapon shop: purchases in a row without Epic or better (Config/WeaponRarities Pity)
		PityLegendary = 0, -- weapon shop: purchases in a row without Legendary or better
		LastOnline = 0,
		Tutorial = 0,
		-- EquippedWeapon (uid) and EquippedSkin are absent until set.
	}
end

return Profile
