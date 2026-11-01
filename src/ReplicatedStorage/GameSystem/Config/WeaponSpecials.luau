--!strict
-- The special attacks of the weapon skill trees (Round 8 part 6), data only: 5 per weapon type. Each is a move like any other
-- (fields: Config/WeaponMoves), added to Moves[category] under its Key and to Config/Skills, so it runs through the same server
-- path, rate rules and attack-state replication as the Z skill. Clip = an existing clip of the category; Fx = whose effects
-- it shows ("Skill" | "Heavy" | "Dash" | "Air"). Cooldown seconds, Cost mana (the staff). The last one of a list is the ultimate.
return {
	Sword = {
		{ Key = "S_Whirlwind", Name = "Whirlwind", Cooldown = 10, Fx = "Heavy", Move = { Name = "Whirlwind", Clip = "Sword_Attack5", Impact = 0.14, Hits = { 0.32 }, Duration = 0.7, Damage = 3.2, Knockback = 8, Shape = { Kind = "Circle", Radius = 9, MaxTargets = 8 } } },
		{ Key = "S_PiercingDrive", Name = "Piercing Drive", Cooldown = 12, Fx = "Skill", Move = { Name = "PiercingDrive", Clip = "Sword_DashAttack", Impact = 0.14, Duration = 0.55, Damage = 7, Lunge = 13, LungeSeconds = 0.2, Knockback = 10, Shape = { Kind = "Line", Length = 17, Width = 4, MaxTargets = 8 } } },
		{ Key = "S_CrossCut", Name = "Cross Cut", Cooldown = 9, Fx = "Heavy", Move = { Name = "CrossCut", Clip = "Sword_Heavy", Impact = 0.12, Hits = { 0.26 }, Duration = 0.6, Damage = 3.6, Lunge = 3, Stagger = 0.4, Shape = { Angle = 170, Radius = 8.5, MaxTargets = 6 } } },
		{ Key = "S_RisingGale", Name = "Rising Gale", Cooldown = 14, Fx = "Air", Move = { Name = "RisingGale", Clip = "Sword_Attack3", Impact = 0.12, Duration = 0.6, Damage = 6, Stagger = 0.8, Knockback = 12, Shape = { Kind = "Circle", Radius = 10, MaxTargets = 8 } } },
		{ Key = "S_ThousandCuts", Name = "Thousand Cuts", Cooldown = 24, Fx = "Heavy", Move = { Name = "ThousandCuts", Clip = "Sword_Attack5", Impact = 0.12, Hits = { 0.24, 0.36, 0.48, 0.6, 0.72 }, Duration = 1.1, Damage = 3, Knockback = 6, Shape = { Kind = "Circle", Radius = 10, MaxTargets = 10 } } },
	},
	Spear = {
		{ Key = "S_JavelinBurst", Name = "Javelin Burst", Cooldown = 10, Fx = "Skill", Move = { Name = "JavelinBurst", Clip = "Spear_Attack5", Impact = 0.14, Duration = 0.7, Damage = 6, Knockback = 9, Shape = { Kind = "Line", Length = 22, Width = 3.5, MaxTargets = 8 } } },
		{ Key = "S_DragonTail", Name = "Dragon Tail", Cooldown = 12, Fx = "Heavy", Move = { Name = "DragonTail", Clip = "Spear_Attack3", Impact = 0.12, Hits = { 0.3 }, Duration = 0.7, Damage = 3.4, Knockback = 10, Shape = { Kind = "Circle", Radius = 12, MaxTargets = 8 } } },
		{ Key = "S_PhalanxThrust", Name = "Phalanx Thrust", Cooldown = 9, Fx = "Dash", Move = { Name = "PhalanxThrust", Clip = "Spear_Attack1", Impact = 0.11, Hits = { 0.22, 0.33 }, Duration = 0.65, Damage = 2.4, Shape = { Length = 13, MaxTargets = 6 } } },
		{ Key = "S_VaultStrike", Name = "Vault Strike", Cooldown = 14, Fx = "Air", Move = { Name = "VaultStrike", Clip = "Spear_DashAttack", Impact = 0.18, Duration = 0.7, Damage = 6, Lunge = 11, LungeSeconds = 0.22, Knockback = 10, Stagger = 0.5, Shape = { Kind = "Circle", Radius = 8, MaxTargets = 8 } } },
		{ Key = "S_HeavenPiercer", Name = "Heaven Piercer", Cooldown = 24, Fx = "Skill", Move = { Name = "HeavenPiercer", Clip = "Spear_Heavy", Impact = 0.16, Hits = { 0.4 }, Duration = 0.95, Damage = 9, Lunge = 6, Knockback = 14, Shape = { Kind = "Line", Length = 26, Width = 5, MaxTargets = 12 } } },
	},
	Heavy = {
		{ Key = "S_Quake", Name = "Quake", Cooldown = 12, Fx = "Skill", Move = { Name = "Quake", Clip = "Heavy_Attack4", Impact = 0.2, Duration = 0.95, Damage = 5, Knockback = 12, Stagger = 0.6, Shape = { Kind = "Circle", Radius = 11, MaxTargets = 10, SlamRadius = 12 } } },
		{ Key = "S_HammerSpin", Name = "Hammer Spin", Cooldown = 11, Fx = "Heavy", Move = { Name = "HammerSpin", Clip = "Heavy_Attack1", Impact = 0.12, Hits = { 0.34, 0.56 }, Duration = 0.9, Damage = 2.6, Knockback = 8, Shape = { Kind = "Circle", Radius = 9.5, MaxTargets = 8 } } },
		{ Key = "S_TitanDrop", Name = "Titan Drop", Cooldown = 14, Fx = "Air", Move = { Name = "TitanDrop", Clip = "Heavy_DashAttack", Impact = 0.3, Duration = 0.9, Damage = 7, Lunge = 8, LungeSeconds = 0.25, Knockback = 12, Stagger = 0.6, Shape = { Kind = "Circle", Radius = 10, MaxTargets = 8, SlamRadius = 9 } } },
		{ Key = "S_Shatter", Name = "Shatter", Cooldown = 10, Fx = "Heavy", Move = { Name = "Shatter", Clip = "Heavy_Attack3", Impact = 0.13, Duration = 0.7, Damage = 5.5, Stagger = 1, Shape = { Kind = "Arc", Angle = 160, Radius = 10, MaxTargets = 8 } } },
		{ Key = "S_WorldBreaker", Name = "World Breaker", Cooldown = 26, Fx = "Skill", Move = { Name = "WorldBreaker", Clip = "Heavy_Heavy", Impact = 0.22, Hits = { 0.6 }, Duration = 1.2, Damage = 9, Knockback = 16, Stagger = 1, Shape = { Kind = "Circle", Radius = 15, MaxTargets = 14, SlamRadius = 16 } } },
	},
	Dagger = {
		{ Key = "S_ShadowStep", Name = "Shadow Step", Cooldown = 9, Fx = "Dash", Move = { Name = "ShadowStep", Clip = "Dagger_DashAttack", Impact = 0.1, Duration = 0.45, Damage = 5, Lunge = 13, LungeSeconds = 0.16, Shape = { Kind = "Line", Length = 15, Width = 4, MaxTargets = 6 } } },
		{ Key = "S_ViperFlurry", Name = "Viper Flurry", Cooldown = 10, Fx = "Skill", Move = { Name = "ViperFlurry", Clip = "Dagger_Attack3", Impact = 0.08, Hits = { 0.16, 0.24, 0.32, 0.4 }, Duration = 0.65, Damage = 1.5, Shape = { Angle = 120, Radius = 6.5, MaxTargets = 4 } } },
		{ Key = "S_FanOfBlades", Name = "Fan of Blades", Cooldown = 11, Fx = "Heavy", Move = { Name = "FanOfBlades", Clip = "Dagger_Attack5", Impact = 0.1, Hits = { 0.24 }, Duration = 0.6, Damage = 2.8, Knockback = 7, Shape = { Kind = "Circle", Radius = 9, MaxTargets = 8 } } },
		{ Key = "S_Backstab", Name = "Backstab", Cooldown = 12, Fx = "Dash", Move = { Name = "Backstab", Clip = "Dagger_Heavy", Impact = 0.1, Duration = 0.55, Damage = 8, Lunge = 5, Shape = { Kind = "Line", Length = 8, Width = 3, MaxTargets = 2, BonusCrit = 0.5 } } },
		{ Key = "S_DeathLotus", Name = "Death Lotus", Cooldown = 22, Fx = "Skill", Move = { Name = "DeathLotus", Clip = "Dagger_Attack5", Impact = 0.1, Hits = { 0.2, 0.3, 0.4, 0.5, 0.6 }, Duration = 0.95, Damage = 2.8, Knockback = 8, Shape = { Kind = "Circle", Radius = 10, MaxTargets = 10 } } },
	},
	Ranged = {
		{ Key = "S_Scatter", Name = "Scatter Shot", Cooldown = 8, Fx = "Skill", Move = { Name = "Scatter", Clip = "Ranged_Skill", Impact = 0.12, Duration = 0.55, Damage = 2, Shots = 5, Spread = 11, Shape = { Kind = "Projectile" } } },
		{ Key = "S_Piercing", Name = "Piercing Arrow", Cooldown = 10, Fx = "Skill", Move = { Name = "PiercingArrow", Clip = "Ranged_Heavy", Impact = 0.14, Duration = 0.6, Damage = 6, Pierce = 8, Size = 1.6, Shape = { Kind = "Projectile" } } },
		{ Key = "S_Snipe", Name = "Snipe", Cooldown = 14, Fx = "Skill", Move = { Name = "Snipe", Clip = "Ranged_Heavy", Impact = 0.3, Duration = 0.8, Damage = 12, Size = 1.4, Shape = { Kind = "Projectile", MaxTargets = 1, BonusCrit = 0.3 } } },
		{ Key = "S_ArrowRain", Name = "Arrow Rain", Cooldown = 13, Fx = "Air", Move = { Name = "ArrowRain", Clip = "Ranged_JumpAttack", Impact = 0.2, Hits = { 0.45, 0.7 }, Duration = 0.95, Damage = 2.6, Shape = { Kind = "AoE", Radius = 11, Range = 70, MaxTargets = 10 } } },
		{ Key = "S_StormVolley", Name = "Storm Volley", Cooldown = 24, Fx = "Skill", Move = { Name = "StormVolley", Clip = "Ranged_Skill", Impact = 0.14, Duration = 0.9, Damage = 3.4, Shots = 9, Spread = 9, Pierce = 3, Shape = { Kind = "Projectile" } } },
	},
	Magic = {
		{ Key = "S_FireWave", Name = "Fire Wave", Cooldown = 9, Cost = 20, Fx = "Skill", Move = { Name = "FireWave", Clip = "Magic_Skill", Impact = 0.14, Duration = 0.6, Damage = 4, Knockback = 8, Shape = { Kind = "Circle", Radius = 12, MaxTargets = 8 } } },
		{ Key = "S_Meteor", Name = "Meteor", Cooldown = 12, Cost = 30, Fx = "Air", Move = { Name = "Meteor", Clip = "Magic_Heavy", Impact = 0.35, Duration = 0.85, Damage = 7, Stagger = 0.5, Shape = { Kind = "AoE", Radius = 10, Range = 70, MaxTargets = 10 } } },
		{ Key = "S_EmberBarrage", Name = "Ember Barrage", Cooldown = 10, Cost = 25, Fx = "Skill", Move = { Name = "EmberBarrage", Clip = "Magic_Attack1", Impact = 0.12, Duration = 0.65, Damage = 2.2, Shots = 5, Spread = 9, Shape = { Kind = "Fireball" } } },
		{ Key = "S_PhoenixBurst", Name = "Phoenix Burst", Cooldown = 14, Cost = 35, Fx = "Heavy", Move = { Name = "PhoenixBurst", Clip = "Magic_Skill", Impact = 0.16, Hits = { 0.4 }, Duration = 0.8, Damage = 4, Knockback = 12, Shape = { Kind = "Circle", Radius = 13, MaxTargets = 10 } } },
		{ Key = "S_InfernoStorm", Name = "Inferno Storm", Cooldown = 24, Cost = 55, Fx = "Air", Move = { Name = "InfernoStorm", Clip = "Magic_Heavy", Impact = 0.3, Hits = { 0.6, 0.9 }, Duration = 1.2, Damage = 5, Stagger = 0.4, Shape = { Kind = "AoE", Radius = 14, Range = 70, MaxTargets = 12 } } },
	},
} :: { [string]: { { [string]: any } } }
