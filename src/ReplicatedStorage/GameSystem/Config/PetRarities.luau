--!strict
-- Pet and egg numbers per rarity tier (docs/menu_systems_brief.txt B1-B2). Tier names / colors: Config/Rarities.
local PetRarities = {}

-- Value of EACH of a pet's two main stats (0.16 = +16%).
PetRarities.MainValue = { 0.02, 0.04, 0.07, 0.11, 0.16, 0.23, 0.32, 0.45 }
PetRarities.BonusShare = 0.25 -- the unique bonus = 25% of the main value

-- "rarityMult" of the weapon doc (Config/Rarities DamageMult): sell / release values.
PetRarities.EggSellBase = 100 -- auto-sold egg: rarityMult x 100 x 10^(zone-1) Gold
PetRarities.ReleaseBase = 150 -- released pet: rarityMult x 150 x 10^(zone-1) Gold

PetRarities.EggStorage = 30
PetRarities.PetStorage = 60
PetRarities.Slots = 3 -- equipped pets; the ExtraPetSlots game pass adds ExtraSlots
PetRarities.ExtraSlots = 2
PetRarities.MaxFollowing = 3 -- pets that follow the player visually (the first equipped ones)

-- Premium eggs (Diamonds): price per zone, rarity rolled with the shop odds (Config/WeaponRarities, no pity).
PetRarities.PremiumEggBase = 10
PetRarities.PremiumEggPerZone = 4
function PetRarities.premiumEggPrice(zone: number): number
	return PetRarities.PremiumEggBase + PetRarities.PremiumEggPerZone * zone
end

-- Egg Luck (Rebirth Shop "EggLuck", Config/RebirthShop): after the rarity is decided, chance = its bonus
-- (5% per level) that the pet is one tier rarer (max Secret).

-- Equip Best: powerScore = sum of (main % value x weight) for its 2 stats + bonus % x BonusWeight.
PetRarities.PowerWeights = { Gold = 1.0, HP = 1.0, Attack = 1.2, Speed = 0.5, Defense = 1.0 }
PetRarities.BonusWeight = 0.5

-- Hatch screen timing (seconds); the Fast Open setting uses the short one.
PetRarities.HatchSeconds = 2.6
PetRarities.FastHatchSeconds = 0.9

-- Followers (client side, GameClient/Controllers/PetFollowController).
PetRarities.Follow = {
	Offsets = { Vector3.new(-3, 0, 3.5), Vector3.new(3, 0, 3.5), Vector3.new(0, 0, 5.5) }, -- behind the owner (+Z = behind)
	Scale = 1.4, -- model scale in the world (the models are ~0.6-1.2 studs at scale 1)
	Smoothing = 7, -- higher = the pet catches up faster
	FlyHeight = 2.2, -- flying pets float this high above the ground
	BobHeight = 0.3,
	BobSpeed = 2.6,
	HopHeight = 0.45, -- walking pets hop while the owner moves
	HopSpeed = 11,
	ViewDistance = 80, -- other players' pets farther than this are not drawn
	CrowdPlayers = 10, -- with Low FX, other players' pets are hidden when more players than this are near
	TeleportDistance = 60, -- a pet farther than this from its spot jumps there
}

return PetRarities
