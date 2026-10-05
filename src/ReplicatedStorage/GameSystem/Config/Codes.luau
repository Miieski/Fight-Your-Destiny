--!strict
-- Redeemable codes (docs/menu_systems_brief.txt D4). Keys are UPPERCASE; each player can use a code once.
-- Gold is in G (2000 x 10^(Z-1), Z = highest zone unlocked). Optional Expires = os.time() after which it fails.
-- The owner adds codes here.
return {
	WELCOME = { Gold = 5, Diamonds = 5 },
	DESTINY = { Diamonds = 10 },
	BOSSKEY = { Gold = 10 },
}
