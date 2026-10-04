--!strict
-- Who may use the admin panel (DESIGN.md section 13). The server checks this for EVERY command;
-- the client button is only cosmetic.
return {
	UserIds = { 1669613376 }, -- owner account (the creator of the experience)
	AllowCreator = true, -- the user who owns the experience is always an admin
	AllowInStudio = true, -- anyone testing inside Studio is an admin (never true in the live game)

	MaxAmount = 1e18, -- largest amount a command accepts
	GoldButtons = { 1e3, 1e6, 1e9, 1e12 },
	DiamondButtons = { 10, 100, 1000 },
}
