--!strict
-- Game pass and Developer Product ids (DESIGN.md section 9). 0 = not created yet (hidden).
return {
	Passes = {
		AutoAttack = 0,
		DoubleGold = 0,
		ExtraPetSlots = 0,
		VIP = 0,
		ExclusiveWeapon = 0,
	},
	-- Premium pets (Developer Products, Robux): PetService.grantPremium gives them. 0 = hidden.
	PremiumPets = {
		premium_dragonling = 0,
		premium_phoenix = 0,
		premium_golem = 0,
		premium_kitsune = 0,
	},
	DiamondPacks = {
		{ Id = 0, Diamonds = 50 },
		{ Id = 0, Diamonds = 150 },
		{ Id = 0, Diamonds = 400 },
		{ Id = 0, Diamonds = 1000 },
	},
}
