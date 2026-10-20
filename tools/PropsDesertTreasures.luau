--[[
	PropsDesertTreasures (dev tool, Edit mode only) - the owner's "DESERT ZONE PROP IMPROVEMENT - Props, furniture and
	treasures" (2026-10-20, PROMPT_05): the terracotta jar, amphora, rug, golden stand, throne and golden lamp rebuilt in
	the desert recipe (docs/prop_texture_guide.md sections A, B, B14), keeping each object's colours, place, size,
	glow, attachments and collision. Source of truth: tools/PropsDesertTreasures.luau. Inventory: docs/prop_inventory.md
	"Desert props".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today. The rug collides nowhere (as today).

	It uses DevTools.PropsDesertMonuments (its helpers, finish() and the SHAPES table) and registers its builders into
	PropsDesert's PropsBatch2 table:
		local T = require(game.ServerStorage.DevTools.PropsDesertTreasures:Clone())
		print(T.install("desert_rug"))   -- (re)builds ServerStorage.MapProps.desert_rug
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.tagAll({ only = { "desert_rug" } }), Sync.run({ only = { "desert_rug" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local M = require(ServerStorage.DevTools.PropsDesertMonuments:Clone()) :: any
local D = M.D -- the same PropsDesert / PropsBatch2 tables as the monuments (one bevel state, one install)
local B2 = D.B2
local H = B2.H
local C = D.PALETTE
local piece = H.piece
local finish = M.finish

local Treasures = {}

local rgb = Color3.fromRGB
local rad = math.rad

local LINEN = rgb(232, 226, 208)

---------------------------------------------------------------------
-- 03 RUG (kit MapAssets.Desert.Carpet_A, 6 parts, none collides; Desert_1 Camps x3, Desert_2 Village x7, BA x1)
---------------------------------------------------------------------
-- The rug (B14): today's footprint (the carpet 8 x 0.15 x 10 at z -1 and its 2 torn pieces), woven: a turquoise-blue
-- border band 0.6 wide inset 0.3 along both long sides with a gold chequer of 0.4 squares and linen lines; today's 2
-- cross stripes with a gold zigzag of small diamonds; today's gold diamond (same size and place) with a linen outline
-- and a red centre diamond 1.0 outlined in linen; faint weave rows; linen fringes (0.12 x 0.6) at the front short end
-- and on the far edges of the torn pieces; the front-left corner (+X, -Z) folded back over a 2 x 2 triangle, showing
-- the darker underside, with its fringe. Nothing collides (as today). Parts: Cloth, Pattern, Fringe.
function Treasures.desert_rug(): Model
	local m = Instance.new("Model")
	m.Name = "desert_rug"
	local rng = Random.new(20261220)
	H.setBevelSelf(true)
	local U = { Cloth = {}, Pattern = {}, Fringe = {} }
	local RED, RED2, STRIPE, GOLD = rgb(214, 74, 62), rgb(193, 66, 56), rgb(60, 150, 170), C.Gold
	-- the folded corner: everything with x - z > 8 is cut off (the fold line runs from (2, -6) to (4, -4))
	local function foldCut(): BasePart
		return piece("Part", Vector3.new(4, 2, 8), CFrame.new(5.414, 0, -5.414) * CFrame.Angles(0, rad(45), 0), RED)
	end
	local function folded(x: number, z: number): boolean
		return x - z > 7.9
	end
	-- the carpet and today's 2 cross stripes, cut at the fold
	table.insert(U.Cloth, H.subtractKeep(Vector3.new(8, 0.15, 10), CFrame.new(0, 0.075, -1), RED, { foldCut() }))
	for _, z in ipairs({ -5.4, 2.2 }) do
		local negs = if z < 0 then { foldCut() } else {}
		table.insert(U.Pattern, H.subtractKeep(Vector3.new(8.1, 0.18, 1), CFrame.new(0, 0.09, z), STRIPE, negs))
		for _, sz in ipairs({ -1, 1 }) do
			local x0, x1 = -4.0, if z < 0 then (if sz < 0 then 2.0 else 2.9) else 4.0
			table.insert(U.Pattern, piece("Part", Vector3.new(x1 - x0 - 0.1, 0.02, 0.08), CFrame.new((x0 + x1) / 2, 0.185, z + sz * 0.38), LINEN))
		end
		for i = -4, 4 do
			local x = i * 0.85
			if not folded(x + 0.25, z - 0.25) then
				table.insert(U.Pattern, piece("Part", Vector3.new(0.34, 0.02, 0.34), CFrame.new(x, 0.19, z) * CFrame.Angles(0, rad(45), 0), GOLD))
			end
		end
	end
	-- faint weave rows across the field
	for k = 0, 5 do
		local z = -4.4 + k * 1.1
		if z < 1.6 then
			table.insert(U.Cloth, piece("Part", Vector3.new(7.9, 0.01, 0.3), CFrame.new(0, 0.152, z), RED2))
		end
	end
	-- the long-side border bands (between the stripes) with a gold chequer and an inner linen line
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Pattern, piece("Part", Vector3.new(0.6, 0.03, 6.6), CFrame.new(sx * 3.4, 0.165, -1.6), STRIPE))
		table.insert(U.Pattern, piece("Part", Vector3.new(0.08, 0.02, 6.6), CFrame.new(sx * 2.98, 0.16, -1.6), LINEN))
		for k = 0, 7 do
			local z = -4.7 + k * 0.8 + 0.2
			local x = sx * 3.4 + (if k % 2 == 0 then -0.1 else 0.1)
			table.insert(U.Pattern, piece("Part", Vector3.new(0.4, 0.02, 0.4), CFrame.new(x, 0.185, z), GOLD))
		end
	end
	-- today's gold diamond (3.2, turned 45, at z -1.5) with a linen outline, a red centre diamond 1.0 outlined in linen
	local dc = CFrame.new(0, 0, -1.5) * CFrame.Angles(0, rad(45), 0)
	table.insert(U.Pattern, piece("Part", Vector3.new(3.5, 0.02, 3.5), dc * CFrame.new(0, 0.16, 0), LINEN))
	table.insert(U.Pattern, piece("Part", Vector3.new(3.2, 0.2, 3.2), dc * CFrame.new(0, 0.1, 0), GOLD))
	table.insert(U.Pattern, piece("Part", Vector3.new(1.3, 0.02, 1.3), dc * CFrame.new(0, 0.205, 0), LINEN))
	table.insert(U.Pattern, piece("Part", Vector3.new(1.0, 0.03, 1.0), dc * CFrame.new(0, 0.21, 0), RED))
	for _, e in ipairs({ { 0, -1.6 }, { 0, 1.6 }, { -1.6, 0 }, { 1.6, 0 } }) do
		table.insert(U.Pattern, piece("Part", Vector3.new(0.3, 0.02, 0.3), dc * CFrame.new(e[1], 0.21, e[2]), STRIPE))
	end
	-- today's 2 torn pieces (same size, place, turn, colour), fringed on their far edge
	local torn = {
		{ Vector3.new(4.5, 0.15, 2.6), CFrame.new(-1.9, 0.075, 5.2) * CFrame.Angles(0, rad(-14), 0), RED },
		{ Vector3.new(2.6, 0.15, 1.8), CFrame.new(2.6, 0.075, 5.6) * CFrame.Angles(0, rad(22), 0), RED2 },
	}
	local function strand(cf: CFrame)
		table.insert(U.Fringe, piece("Part", Vector3.new(0.12, 0.04, 0.6), cf * CFrame.Angles(0, rad(rng:NextNumber(-8, 8)), 0) * CFrame.new(0, 0, -0.3), if rng:NextNumber() < 0.5 then LINEN else rgb(216, 208, 186)))
	end
	for _, t in ipairs(torn) do
		table.insert(U.Cloth, piece("Part", t[1], t[2], t[3]))
		table.insert(U.Pattern, piece("Part", Vector3.new(t[1].X - 0.4, 0.02, 0.25), t[2] * CFrame.new(0, 0.085, t[1].Z / 2 - 0.45), STRIPE))
		local n = math.floor(t[1].X / 0.4)
		for k = 0, n - 1 do
			local x = -t[1].X / 2 + 0.2 + k * (t[1].X - 0.4) / math.max(n - 1, 1)
			strand(t[2] * CFrame.new(x, -0.055, t[1].Z / 2) * CFrame.Angles(0, math.pi, 0))
		end
	end
	-- the front fringe (z -6), up to the fold, with a linen knot band
	table.insert(U.Fringe, piece("Part", Vector3.new(5.9, 0.05, 0.12), CFrame.new(-1.05, 0.04, -5.97), LINEN))
	for k = 0, 14 do
		local x = -3.8 + k * 0.4
		if x < 1.85 then
			strand(CFrame.new(x, 0.02, -6.0))
		end
	end
	-- the folded corner: the flap (the corner (4, -6) turned over onto (2, -4)), its darker underside, the fold roll and
	-- the corner's fringe now lying on the rug pointing -X
	H.triangleParts(U.Cloth, Vector3.new(2, 0.21, -6), Vector3.new(4, 0.21, -4), Vector3.new(2, 0.21, -4), 0.12, CFrame.identity, H.scaled(RED, 0.86))
	table.insert(U.Cloth, piece("Part", Vector3.new(2.83, 0.24, 0.24), CFrame.new(3, 0.13, -5) * CFrame.Angles(0, rad(-45), 0), H.scaled(RED, 0.93), { shape = Enum.PartType.Cylinder }))
	table.insert(U.Fringe, piece("Part", Vector3.new(0.12, 0.05, 1.9), CFrame.new(2.03, 0.27, -5.0), LINEN))
	for k = 0, 3 do
		strand(CFrame.new(2.0, 0.28, -5.65 + k * 0.45) * CFrame.Angles(0, rad(90), 0))
	end
	finish(m, "desert_rug", U, "Cloth")
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into PropsDesert's fresh PropsBatch2 table; its install() builds them
---------------------------------------------------------------------
Treasures.BUILDERS = { desert_rug = true }
for id in pairs(Treasures.BUILDERS) do
	B2[id] = (Treasures :: any)[id]
	B2.BUILDERS[id] = true
end
Treasures.install = B2.install
Treasures.stats = B2.stats

return Treasures
