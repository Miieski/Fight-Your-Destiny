--[[
	PropsJungleDecor (dev tool, Edit mode only) - the owner's "JUNGLE ZONE PROP IMPROVEMENT - Props and decor"
	(2026-10-20, jungle PROMPT_05): the standing torch, the drum, the skull on a pole and the war banner rebuilt in the
	jungle recipe (docs/prop_texture_guide.md sections A, C1, C2, C6), keeping each object's colours, place, size,
	function and collision. Source of truth: tools/PropsJungleDecor.luau. Inventory: docs/prop_inventory.md
	"Jungle decor".

	Collision: the visible unions never collide; invisible "Collision" parts are the kit's colliding parts (same shape,
	size and place), so no copy is more (or less) solid than today. None of the four has a script, prompt, sound, tag,
	attribute or light (checked in Studio and src/). The torch's fire and light are NOT in the torch: each placed torch
	has a Fire_Torch part (Flame / Core / Ember particles, PointLight #FFAA50 range 16) in its zone's Decor.VFX folder,
	exactly on the torch's Ember.FirePoint (pivot + (0, 8.2, 0)); that point is kept exact, so every fire still burns in
	the new cup.

	It uses DevTools.PropsJungleTotems (and through it the jungle ruins / gates / buildings / desert helpers, finish()
	and the SHAPES table) and registers its builders into the same PropsBatch2 table:
		local D = require(game.ServerStorage.DevTools.PropsJungleDecor:Clone())
		print(D.install("jungle_drum"))
		local Sync = require(game.ServerStorage.DevTools.SyncMapProps:Clone())
		print(Sync.run({ only = { "jungle_drum" } }))
]]
local ServerStorage = game:GetService("ServerStorage")

local T = require(ServerStorage.DevTools.PropsJungleTotems:Clone()) :: any
local DData = require(ServerStorage.DevTools.PropsJungleDecorData:Clone()) :: any -- Agent A's decor facets
local R = T.R
local G = R.G
local J = G.J
local M, B2, H = J.M, J.B2, J.H
local piece, chamfered = H.piece, H.chamfered
local finish = M.finish

local Decor = {}

local rgb = Color3.fromRGB
local rad = math.rad

-- shared colours (C6: the kits' real colours)
local WOOD = rgb(168, 98, 56) -- #A86238 (drum body)
local WOOD_DARK = rgb(112, 62, 38) -- #703E26 (poles, drum foot, crossbar)
local WOOD_DEEP = rgb(74, 48, 34) -- #4A3022
local RED = rgb(196, 70, 50) -- #C44632
local BONE = rgb(232, 226, 208) -- #E8E2D0
local ROPE = rgb(196, 160, 104) -- #C4A068
local GOLD = rgb(255, 201, 60) -- #FFC93C
local IRON = rgb(74, 78, 87)

-- a point on a vertical circle (radius r, angle a, height y)
local function onCircle(r: number, a: number, y: number): Vector3
	return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
end

-- a frame on a vertical cylinder at angle a, height y, radius r: -Z looks outward, Y up
local function outFrame(r: number, a: number, y: number): CFrame
	local p = onCircle(r, a, y)
	return CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a)))
end

-- a ring (n-sided, apothem r, y0 .. y1) round the vertical axis, facets turned so a facet faces angle 0
local function ringY(list: { BasePart }, n: number, r0: number, r1: number, y0: number, y1: number, colors: { Color3 })
	table.insert(list, M.frustumN(n, r0, r1, y0, y1, CFrame.Angles(0, -math.pi / n, 0), colors))
end

---------------------------------------------------------------------
-- 02 DRUM (kit MapAssets.Jungle.Drum_A, 5 parts, 4.6 x 3.7 x 4.6; Jungle_2 x2 (1.2, 0.8), BossArenas x3 (1.2, 0.9,
-- 0.8): all resized part by part with Model scale 1 -> bakedScale from the Foot)
---------------------------------------------------------------------
local ZUP = CFrame.Angles(0, 0, rad(90)) -- a Cylinder part's axis (X) turned to Y
M.SHAPES.jungle_drum = { -- today's colliding parts: Body, 2 Bands, Skin (cylinders), Foot
	J.shape("Cylinder", 3.2, 4, 4, CFrame.new(0, 1.9, 0) * ZUP),
	J.shape("Cylinder", 0.45, 4.25, 4.25, CFrame.new(0, 0.75, 0) * ZUP),
	J.shape("Cylinder", 0.45, 4.25, 4.25, CFrame.new(0, 3.1, 0) * ZUP),
	J.shape("Cylinder", 0.2, 3.8, 3.8, CFrame.new(0, 3.6, 0) * ZUP),
	J.shape("Block", 4.6, 0.3, 4.6, CFrame.new(0, 0.15, 0)),
}

-- The drum (guide C6): a wooden barrel body of 16 staves (today's #A86238 in 3 tones, V plank lines from 0.06
-- chamfers, a few grain lines) over a dark core; today's 2 red bands as painted hoops 0.13 proud with bevelled edges, 2
-- dark rules and a row of cream / gold diamonds; a rope lacing of 12 V's between the hoops with a rope ring along each
-- hoop; the skin on top (today's #E8E2D0, top at today's 3.7, a lighter centre) whose edge is pulled down over the rim
-- as a flap with 32 cross stitches and 16 iron tacks under it; a small wooden base (today's Foot: 4 chamfered planks
-- with gaps over 2 battens, nail heads, 4 carved feet holding the drum); a red ring and a gold diamond painted on the
-- skin; a drumstick with a padded head and a small soft moss patch on the base.
-- Parts: Paint, Rope, Skin, Wood, Collision x5.
function Decor.jungle_drum(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_drum"
	local rng = Random.new(20261271)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Paint = {}, Rope = {}, Skin = {} }
	local HT = 3.7
	-- the base (today's Foot 4.6 x 0.3 x 4.6): 4 planks along X (0.05 gaps) on 2 battens, a dark core, nail heads
	table.insert(U.Wood, piece("Part", Vector3.new(4.5, 0.2, 4.5), CFrame.new(0, 0.12, 0), WOOD_DEEP))
	local pw = (4.6 - 3 * 0.08) / 4
	local prev = nil
	for k = 0, 3 do
		local z = -2.3 + pw / 2 + k * (pw + 0.08)
		local ti = H.toneIndex(rng, prev)
		prev = ti
		local len = 4.6 - rng:NextNumber(0, 0.12)
		table.insert(U.Wood, chamfered(Vector3.new(len, 0.2, pw), CFrame.new((4.6 - len) * (if k % 2 == 0 then -0.5 else 0.5), 0.2, z), H.scaled(WOOD_DARK, H.TONES[ti] * 1.05), { "topFrontBack", "topSides" }, 0.06))
		for _, x in ipairs({ -1.75, 1.75 }) do
			table.insert(U.Wood, piece("Part", Vector3.new(0.12, 0.03, 0.12), CFrame.new(x, 0.31, z) * CFrame.Angles(0, rad(45), 0), IRON))
		end
	end
	for _, x in ipairs({ -1.75, 1.75 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.45, 0.12, 4.4), CFrame.new(x, 0.06, 0), H.scaled(WOOD_DEEP, 0.9), { "vertical" }, 0.08))
	end
	-- 4 carved feet holding the drum on the base (at 45 deg, half under the staves)
	for k = 0, 3 do
		local a = rad(45 + k * 90)
		local f = outFrame(2.05, a, 0.48)
		table.insert(U.Wood, chamfered(Vector3.new(0.55, 0.36, 0.42), f, H.scaled(WOOD_DARK, 0.95), { "vertical", "topFrontBack", "topSides" }, 0.1))
		table.insert(U.Wood, piece("Part", Vector3.new(0.3, 0.06, 0.04), f * CFrame.new(0, 0.02, -0.215), WOOD_DEEP))
	end
	-- the barrel: a dark core and 16 staves (outer face at r 2.0, y 0.3 .. 3.5), V plank lines from their chamfers
	ringY(U.Wood, 16, 1.8, 1.8, 0.3, 3.5, { H.scaled(WOOD_DEEP, 0.8) })
	for k = 0, 15 do
		local a = (k + 0.5) * 2 * math.pi / 16
		table.insert(U.Wood, chamfered(Vector3.new(0.78, 3.2, 0.24), outFrame(1.88, a, 1.9), H.graded(WOOD, 2.4, HT, H.TONES[H.toneIndex(rng, nil)]), { "vertical" }, 0.06))
	end
	-- 2 grain lines on a few staves
	for _, k in ipairs({ 1, 6, 11 }) do
		local a = (k + 0.5) * 2 * math.pi / 16
		table.insert(U.Wood, piece("Part", Vector3.new(0.05, 0.9, 0.03), outFrame(2.0, a, 1.5) * CFrame.new(0.12, 0, 0) * CFrame.Angles(0, 0, rad(4)), H.scaled(WOOD, 0.72)))
		table.insert(U.Wood, piece("Part", Vector3.new(0.05, 0.7, 0.03), outFrame(2.0, a + 0.15, 2.45) * CFrame.new(-0.1, 0, 0) * CFrame.Angles(0, 0, rad(-3)), H.scaled(WOOD, 0.72)))
	end
	-- today's 2 red bands as painted hoops (r 2.125, 0.45 tall): bevelled edges, 2 dark rules, a row of diamonds
	for bi, y in ipairs({ 0.75, 3.1 }) do
		ringY(U.Paint, 16, 2.125, 2.125, y - 0.17, y + 0.17, { RED, H.scaled(RED, 0.93) })
		ringY(U.Paint, 16, 2.125, 2.06, y + 0.17, y + 0.225, { H.scaled(RED, 1.1) })
		ringY(U.Paint, 16, 2.06, 2.125, y - 0.225, y - 0.17, { H.scaled(RED, 0.85) })
		for _, dy in ipairs({ -0.15, 0.15 }) do
			ringY(U.Paint, 16, 2.135, 2.135, y + dy - 0.025, y + dy + 0.025, { H.scaled(RED, 0.62) })
		end
		for k = 0, 15 do
			-- on the facet centres (the frustum's apothem 2.125); the top hoop starts with gold
			local f = outFrame(2.15, k * 2 * math.pi / 16, y)
			table.insert(U.Paint, piece("Part", Vector3.new(0.19, 0.19, 0.05), f * CFrame.Angles(0, 0, rad(45)), if (k + bi) % 2 == 0 then GOLD else BONE))
		end
	end
	-- the rope lacing: 12 V's between the hoops (rope 0.11 on the staves), a rope ring along each hoop
	local yTop, yBot = 2.83, 1.02
	for k = 0, 11 do
		local a0 = k * 2 * math.pi / 12
		local a1 = a0 + math.pi / 12
		local a2 = a0 + 2 * math.pi / 12
		local c = if k % 2 == 0 then ROPE else H.scaled(ROPE, 0.9)
		table.insert(U.Rope, H.bar(onCircle(2.1, a0, yTop), onCircle(2.1, a1, yBot), 0.11, c))
		table.insert(U.Rope, H.bar(onCircle(2.1, a1, yBot), onCircle(2.1, a2, yTop), 0.11, H.scaled(c, 0.95)))
	end
	ringY(U.Rope, 16, 2.09, 2.09, yTop - 0.04, yTop + 0.06, { ROPE, H.scaled(ROPE, 0.88) })
	ringY(U.Rope, 16, 2.09, 2.09, yBot - 0.06, yBot + 0.04, { ROPE, H.scaled(ROPE, 0.88) })
	-- the skin: today's top at 3.7 (#E8E2D0), a lighter centre, the edge pulled over the rim as a flap with 32 cross
	-- stitches; 16 iron tacks on the staves under the flap
	ringY(U.Skin, 16, 1.98, 1.9, 3.48, 3.66, { BONE, H.scaled(BONE, 0.95) })
	ringY(U.Skin, 16, 1.9, 1.7, 3.66, 3.7, { H.scaled(BONE, 1.03) })
	ringY(U.Skin, 16, 2.07, 2.02, 3.33, 3.6, { H.scaled(BONE, 0.9), H.scaled(BONE, 0.86) })
	ringY(U.Skin, 16, 2.08, 2.08, 3.33, 3.37, { H.scaled(BONE, 0.78) })
	for k = 0, 31 do
		local a = (k + 0.25) * 2 * math.pi / 32
		local f = outFrame(2.07, a, 3.46)
		table.insert(U.Skin, piece("Part", Vector3.new(0.045, 0.2, 0.04), f * CFrame.Angles(0, 0, rad(if k % 2 == 0 then 32 else -32)), rgb(92, 56, 36)))
	end
	for k = 0, 15 do
		local a = (k + 0.5) * 2 * math.pi / 16
		table.insert(U.Wood, M.frustumN(6, 0.075, 0.05, 0, 0.05, outFrame(2.0, a, 3.25) * CFrame.Angles(rad(-90), 0, 0), { IRON, H.scaled(IRON, 1.2) }))
	end
	-- a painted mark on the skin: a red ring with a gold diamond in the middle (0.02 proud)
	ringY(U.Paint, 16, 1.3, 1.3, 3.7, 3.715, { RED })
	ringY(U.Skin, 16, 1.12, 1.12, 3.7, 3.72, { H.scaled(BONE, 1.03) })
	table.insert(U.Paint, piece("Part", Vector3.new(0.5, 0.03, 0.5), CFrame.new(0, 3.72, 0) * CFrame.Angles(0, rad(45), 0), GOLD))
	-- a small soft moss patch on the base's back-left corner
	R.mossMat(U.Skin, rng, CFrame.new(-1.8, 0.3, 1.8) * CFrame.Angles(0, rad(-45), 0), 1.1, 0.5, 0.45)
	-- a drumstick lying on the base's front-right corner: a 6-sided handle and a padded head (leather + rope wrap)
	local s0, s1 = Vector3.new(1.3, 0.5, -2.05), Vector3.new(2.1, 0.37, -1.25)
	table.insert(U.Wood, H.bar(s0, s1, 0.13, H.scaled(WOOD, 1.08)))
	table.insert(U.Skin, M.frustumN(8, 0.2, 0.2, -0.17, 0.17, CFrame.lookAt(s0, s1) * CFrame.Angles(rad(90), 0, 0), { H.scaled(BONE, 0.92), H.scaled(BONE, 0.85) }))
	table.insert(U.Rope, M.frustumN(8, 0.21, 0.21, -0.2, -0.12, CFrame.lookAt(s0, s1) * CFrame.Angles(rad(90), 0, 0), { RED }))
	finish(m, "jungle_drum", U, "Wood")
	return m
end

---------------------------------------------------------------------
-- 01 STANDING TORCH (kit MapAssets.Jungle.Tribal_Torch, 6 parts, 1.9 x 8.15 x 1.9; 24 copies: test, kit, Jungle_1 x4,
-- Jungle_2 x6, Jungle_3 x10, BossArenas x2; 22 of them have a Decor.VFX Fire_Torch on their FirePoint)
---------------------------------------------------------------------
M.SHAPES.jungle_torch = { -- today's colliding parts: Foot, Pole, Wrap, Bowl
	J.shape("Block", 1.7, 0.5, 1.7, CFrame.new(0, 0.25, 0)),
	J.shape("Block", 0.7, 7, 0.7, CFrame.new(0, 3.6, 0)),
	J.shape("Block", 0.95, 0.8, 0.95, CFrame.new(0, 5.2, 0)),
	J.shape("Block", 1.9, 0.8, 1.9, CFrame.new(0, 7.3, 0)),
}
local TORCH_FIRE = Vector3.new(0, 8.2, 0) -- today's Ember.FirePoint (the Fire_Torch VFX part sits exactly here)

-- a small bump (a knot on a pole, a rivet) of n sides, radius r, `len` out of the surface at `at` along `dir`
local function bump(list: { BasePart }, n: number, at: Vector3, dir: Vector3, r: number, len: number, colors: { Color3 })
	local d = dir.Unit
	local helper = if math.abs(d.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local x = helper:Cross(d).Unit
	table.insert(list, M.frustumN(n, r, r * 0.55, -r * 0.4, len, CFrame.fromMatrix(at, x, d), colors))
end

-- The standing torch (guide C6): today's stone Foot as a chamfered stone block (#848A7C) with a darker stepped collar,
-- 2 cut lines on the front and a soft moss tuft on a corner; today's pole as an 8-sided pole (#703E26, 2 bark tones,
-- 2 bark lines, a knot); today's Wrap (y 4.8 .. 5.6) as a leather grip of 3 overlapping tilted bands (3 tones of
-- #C4A068) crossed by a dark leather thong; today's white Skull part (the owner's "white wrap", y 5.85 .. 6.75) as a
-- linen wrap (#E8E2D0) of 3 tilted bands with a hanging loose end; double rope rings at y 4.75, 5.65, 5.8 and 6.8;
-- a carved pole head (#68442C, today's Bowl colour): an octagonal collar with 4 dark notches and 4 wooden prongs rising
-- against the cup; Agent A's iron cup (replacing today's Bowl) and his layered Neon flame on today's Ember, which is
-- kept exactly (Neon #FF8C28 1.2 x 0.5 x 1.2 at y 7.9, its FirePoint at y 8.2, where the zone's Fire_Torch VFX part
-- burns). No light here: the torch's light and flicker are the Fire_Torch part's (unchanged).
-- Parts: Cloth, Flame, Iron, Stone, Wood, Ember (+ FirePoint), Collision x4.
function Decor.jungle_torch(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_torch"
	local rng = Random.new(20261272)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Stone = {}, Cloth = {}, Iron = {}, Glow = {} }
	local STONE = rgb(132, 138, 124) -- #848A7C
	local STONE_DARK = rgb(92, 100, 92) -- #5C645C
	local HEAD = rgb(104, 68, 44) -- #68442C (today's Bowl)
	local RECESS = rgb(41, 45, 41) -- #292D29
	-- the stone foot: today's Foot as a 1.7 x 0.35 block (0.1 chamfer on the top edges), a stepped collar 1.15 x 0.2,
	-- 2 cut lines on the front, a soft moss tuft on the back-left corner
	table.insert(U.Stone, chamfered(Vector3.new(1.7, 0.35, 1.7), CFrame.new(0, 0.175, 0), STONE, { "vertical", "topFrontBack", "topSides" }, 0.1))
	table.insert(U.Stone, chamfered(Vector3.new(1.15, 0.2, 1.15), CFrame.new(0, 0.45, 0), STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.06))
	for _, c in ipairs({ { -0.45, 0.2, 10 }, { 0.38, 0.14, -14 } }) do
		table.insert(U.Stone, piece("Part", Vector3.new(0.06, c[2], 0.03), CFrame.new(c[1], 0.35 - c[2] / 2, -0.855) * CFrame.Angles(0, 0, rad(c[3])), RECESS))
	end
	R.mossMat(U.Stone, rng, CFrame.new(-0.58, 0.35, 0.58) * CFrame.Angles(0, rad(-45), 0), 0.75, 0.32, 0.32)
	-- the pole (today's 0.7 x 7, y 0.1 .. 7.1): 8 sides in 2 bark tones, 2 bark lines, a knot
	ringY(U.Wood, 8, 0.35, 0.33, 0.1, 6.95, { WOOD_DARK, H.scaled(WOOD_DARK, 0.9) })
	for _, b in ipairs({ { 0, 1.6, 1.3 }, { math.pi * 0.75, 3.1, 1.0 } }) do
		table.insert(U.Wood, piece("Part", Vector3.new(0.06, b[3], 0.03), outFrame(0.35, b[1], b[2]), H.scaled(WOOD_DARK, 0.78)))
	end
	bump(U.Wood, 6, Vector3.new(0.32, 2.6, -0.12), Vector3.new(1, 0.15, -0.35), 0.125, 0.1, { H.scaled(WOOD_DARK, 0.82), H.scaled(WOOD_DARK, 0.72) })
	-- the leather grip (today's Wrap, y 4.8 .. 5.6): 3 overlapping bands 0.3 x 0.82, tilted 6 deg the other way each,
	-- 3 tones; a dark leather thong crossing it
	for k, y in ipairs({ 4.95, 5.2, 5.45 }) do
		local tilt = if k % 2 == 0 then -6 else 6
		table.insert(U.Cloth, chamfered(Vector3.new(0.82, 0.3, 0.82), CFrame.new(0, y, 0) * CFrame.Angles(rad(tilt), rad(k * 30), 0), H.scaled(ROPE, H.TONES[k]), { "vertical" }, 0.18))
	end
	table.insert(U.Cloth, H.bar(Vector3.new(-0.3, 4.85, -0.45), Vector3.new(0.3, 5.55, -0.45), 0.06, WOOD_DEEP))
	-- the linen wrap (today's white Skull part, y 5.85 .. 6.75): 3 bands 0.32 x 0.85 tilted 8 deg, a loose end
	for k, y in ipairs({ 6.02, 6.3, 6.58 }) do
		local tilt = if k % 2 == 0 then 8 else -8
		table.insert(U.Cloth, chamfered(Vector3.new(0.85, 0.32, 0.85), CFrame.new(0, y, 0) * CFrame.Angles(0, rad(k * 25), rad(tilt)), H.scaled(BONE, ({ 1.0, 0.95, 0.9 })[k]), { "vertical" }, 0.18))
	end
	table.insert(U.Cloth, chamfered(Vector3.new(0.25, 0.6, 0.05), CFrame.new(0.12, 5.75, -0.45) * CFrame.Angles(rad(-6), 0, rad(-7)), H.scaled(BONE, 0.93), { "frontFace" }, 0.03))
	-- double rope rings (0.92 across, 2 turns of 0.1)
	for _, y in ipairs({ 4.75, 5.65, 5.8, 6.8 }) do
		for t = -1, 1, 2 do
			ringY(U.Cloth, 8, 0.46, 0.46, y + t * 0.05 - 0.045, y + t * 0.05 + 0.045, { H.scaled(ROPE, 0.86), H.scaled(ROPE, 0.78) })
		end
	end
	-- the carved pole head (#68442C): an octagonal collar 1.0 x 0.25 (6.85 .. 7.1) with 4 dark notches, 4 wooden prongs
	-- (0.2 x 0.45 x 0.25 wedges) rising against the cup at 45 / 135 / 225 / 315 deg
	table.insert(U.Wood, M.frustumN(8, 0.5, 0.47, 6.85, 7.1, CFrame.Angles(0, -math.pi / 8, 0), { HEAD, H.scaled(HEAD, 0.9) }))
	for k = 0, 3 do
		local f = outFrame(0.5, k * math.pi / 2, 6.975)
		table.insert(U.Wood, piece("Part", Vector3.new(0.1, 0.3, 0.06), f * CFrame.new(0, 0, -0.02), H.scaled(HEAD, 0.6)))
	end
	for k = 0, 3 do
		local a = math.pi / 4 + k * math.pi / 2
		local w = Instance.new("WedgePart")
		w.Size = Vector3.new(0.2, 0.45, 0.25)
		w.CFrame = outFrame(0.8, a, 7.325) -- the slope looks out, the tall back leans on the cup
		w.Color = H.scaled(HEAD, 1.08)
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		table.insert(U.Wood, w)
	end
	-- Agent A's iron cup (replacing today's Bowl) and layered flame (Neon, on the kept Ember)
	J.facets(U, DData.torch_cup, Vector3.one, CFrame.identity, "Iron")
	J.facets(U, DData.torch_flame, Vector3.one, CFrame.identity, "Glow")
	finish(m, "jungle_torch", U, "Wood", { Glow = { material = Enum.Material.Neon, shadow = false } })
	local flame = m:FindFirstChild("Glow") :: BasePart
	flame.Name = "Flame"
	-- today's Ember (kept exactly) with its FirePoint
	local ember = G.exact(m, "Part", "Ember", Vector3.new(1.2, 0.5, 1.2), CFrame.new(0, 7.9, 0), rgb(255, 140, 40), { touch = true, neon = true })
	local fp = Instance.new("Attachment")
	fp.Name = "FirePoint"
	fp.Position = Vector3.new(0, 0.3, 0)
	fp.Parent = ember
	assert((fp.WorldPosition - TORCH_FIRE).Magnitude < 1e-4, "jungle_torch: FirePoint moved")
	return m
end

---------------------------------------------------------------------
-- 03 SKULL ON A POLE (kit MapAssets.Jungle.SkullPike_A, 5 parts, 1.8 x 7.9 x 1.9; 14 copies: test, kit, Jungle_1 x3,
-- Jungle_2 x4, BossArenas x5, all at scale 1)
---------------------------------------------------------------------
local PIKE_POLE = CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, rad(3)) -- today's Pole (leaning 3 deg toward -X)
M.SHAPES.jungle_skull_pole = { -- today's colliding parts: Pole, Skull
	J.shape("Block", 0.5, 6.6, 0.5, PIKE_POLE),
	J.shape("Block", 1.8, 1.6, 1.8, CFrame.new(0.15, 7.1, 0)),
}

-- a string of beads hanging from `top` (n rounded beads of 0.16 .. 0.2 on a thin rope: chamfered cubes, far cheaper
-- than Ball parts in a union)
local BEADS = { rgb(60, 170, 190), RED, GOLD, BONE } -- #3CAABE, #C44632, #FFC93C, #E8E2D0
local function beadString(rope: { BasePart }, beads: { BasePart }, top: Vector3, len: number, n: number, first: number)
	table.insert(rope, H.bar(top, top - Vector3.new(0, len, 0), 0.05, H.scaled(ROPE, 0.86)))
	for k = 1, n do
		local s = if k == n then 0.2 else 0.16
		local cf = CFrame.new(top - Vector3.new(0, len * k / (n + 0.4), 0)) * CFrame.Angles(0, rad(k * 25), 0)
		table.insert(beads, chamfered(Vector3.one * s, cf, BEADS[(first + k - 2) % #BEADS + 1], { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, s * 0.3))
	end
end

-- The skull on a pole (guide C6): Agent A's skull (cranium, cheekbones, brow ridge, deep eye sockets in today's
-- #4A3022 with darker hollows, nose hole, a lower jaw with 5 + 4 teeth) replacing today's Skull, Jaw and Eyes, its
-- cranium centre on today's Skull centre; today's pole (0.5, leaning 3 deg) as an 8-sided pole (#703E26, 2 tones, a bark
-- line) with a carved top under the skull (2 rings #68442C with a notched band between); 2 rope rings, 2 rope strings of
-- teal / red / gold / bone beads and 2 of Agent A's small feathers hanging under the jaw; a chamfered stone stand
-- (#5C645C) with 3 small stones round the pole foot and a moss tuft (the pole foot stays at y 0).
-- Parts: Bone, Rope, Stone, Wood, Collision x2.
function Decor.jungle_skull_pole(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_skull_pole"
	local rng = Random.new(20261273)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Stone = {}, Rope = {}, Bone = {} }
	local STONE = rgb(132, 138, 124) -- #848A7C
	local STONE_DARK = rgb(92, 100, 92) -- #5C645C
	local HEAD = rgb(104, 68, 44) -- #68442C
	local axis = PIKE_POLE * CFrame.Angles(0, -math.pi / 8, 0) -- the pole's frame (Y along it, facets on the axes)
	local function onPole(y: number): CFrame -- a frame on the pole axis at the height y (in today's pole's own Y)
		return PIKE_POLE * CFrame.new(0, y - 3.3, 0)
	end
	-- the stone stand (1.4 x 0.4 x 1.4, 0.1 chamfer), 3 small stones round the pole foot, a moss tuft
	table.insert(U.Stone, chamfered(Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 0.2, 0) * CFrame.Angles(0, rad(12), 0), STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.1))
	for k, s in ipairs({ 0.5, 0.42, 0.56 }) do
		local a = rad(40 + k * 115)
		local p = Vector3.new(math.cos(a) * 0.48, 0.4 + s * 0.22, math.sin(a) * 0.48)
		R.looseStone(U.Stone, rng, Vector3.new(s, s * 0.5, s * 0.8), CFrame.lookAt(p, Vector3.new(0, p.Y, 0)) * CFrame.Angles(rad(-10), 0, 0), H.scaled(STONE, rng:NextNumber(0.88, 1.05)))
	end
	R.mossMat(U.Stone, rng, CFrame.new(0.42, 0.4, 0.42) * CFrame.Angles(0, rad(-45), 0), 0.6, 0.3, 0.3)
	-- the pole: 8 sides (2 tones) from the ground into the skull, a bark line
	table.insert(U.Wood, M.frustumN(8, 0.25, 0.23, -3.3, 3.2, axis, { WOOD_DARK, H.scaled(WOOD_DARK, 0.88) }))
	table.insert(U.Wood, piece("Part", Vector3.new(0.05, 1.6, 0.03), onPole(2.2) * CFrame.new(0, 0, -0.25), H.scaled(WOOD_DARK, 0.75)))
	-- the carved top: 2 rings 0.62 x 0.12 (#68442C) at y 5.4 and 5.7, a notched band between them
	for _, y in ipairs({ 5.4, 5.7 }) do
		table.insert(U.Wood, M.frustumN(8, 0.31, 0.31, -0.06, 0.06, onPole(y) * CFrame.Angles(0, -math.pi / 8, 0), { HEAD, H.scaled(HEAD, 0.9) }))
	end
	table.insert(U.Wood, M.frustumN(8, 0.27, 0.27, -0.09, 0.09, onPole(5.55) * CFrame.Angles(0, -math.pi / 8, 0), { H.scaled(HEAD, 1.1) }))
	for k = 0, 3 do
		table.insert(U.Wood, piece("Part", Vector3.new(0.08, 0.16, 0.04), onPole(5.55) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -0.275), H.scaled(HEAD, 0.55)))
	end
	-- 2 rope rings (0.6 x 0.1) at y 5.25 and 5.85
	for _, y in ipairs({ 5.25, 5.85 }) do
		table.insert(U.Rope, M.frustumN(8, 0.3, 0.3, -0.05, 0.05, onPole(y) * CFrame.Angles(0, -math.pi / 8, 0), { ROPE, H.scaled(ROPE, 0.86) }))
	end
	-- 2 bead strings from the upper ring, 2 small feathers hanging under the jaw
	local ring = onPole(5.85)
	beadString(U.Rope, U.Rope, (ring * CFrame.new(-0.22, -0.03, -0.22)).Position, 0.6, 3, 1)
	beadString(U.Rope, U.Rope, (ring * CFrame.new(0.24, -0.03, -0.18)).Position, 0.45, 2, 3)
	J.facets(U, DData.feather, Vector3.one * 0.42, CFrame.new(-0.45, 6.0, -0.55) * CFrame.fromOrientation(0, rad(15), rad(188)), "Bone")
	J.facets(U, DData.feather, Vector3.one * 0.38, CFrame.new(0.75, 6.1, -0.4) * CFrame.fromOrientation(0, rad(-25), rad(172)), "Bone")
	table.insert(U.Rope, H.bar(Vector3.new(-0.45, 6.0, -0.55), Vector3.new(-0.35, 6.12, -0.6), 0.05, H.scaled(ROPE, 0.86)))
	table.insert(U.Rope, H.bar(Vector3.new(0.75, 6.1, -0.4), Vector3.new(0.62, 6.2, -0.5), 0.05, H.scaled(ROPE, 0.86)))
	-- Agent A's skull (replacing today's Skull, Jaw and Eyes)
	J.facets(U, DData.pike_skull, Vector3.one, CFrame.identity, "Bone")
	finish(m, "jungle_skull_pole", U, "Wood")
	return m
end

---------------------------------------------------------------------
-- 04 WAR BANNER (kit MapAssets.Jungle.WarBanner_A, 8 parts, 5.6 x 17.7 x 1.5; 9 copies: test, kit, Jungle_1 x1,
-- Jungle_2 x2, BossArenas x4, all at scale 1)
---------------------------------------------------------------------
M.SHAPES.jungle_war_banner = { -- today's colliding parts: Pole, Crossbar
	J.shape("Block", 0.6, 15, 0.6, CFrame.new(0, 7.5, 0)),
	J.shape("Block", 5.6, 0.5, 0.5, CFrame.new(0, 13.4, 0)),
}
-- Agent A's banner__finial_skull is his pike skull at 0.83 with its cranium centre on (0, 15.6, 0): the same triangles
-- through this frame (fitted on his two files: within 0.09)
local FINIAL = CFrame.new(-0.1244, 9.7075, 0)

-- The war banner (guide C6): Agent A's cloth (today's red banner with a flat centre field and 2 pleats a side, a darker
-- sleeve hem, today's cyan stripe following the pleats, a zigzag lower edge of 7 gold-trimmed teeth with the centre
-- point at today's tail tip, the stitched emblem: a dark patch, today's gold diamond, a cyan centre and 12 cream
-- stitches) replacing today's Cloth, ClothTail, Stripe and Emblem; today's crossbar as a chamfered beam with carved end
-- knobs (#68442C), a rope X-lashing on the pole and 5 rope loops holding the sleeve; today's pole as an 8-sided pole
-- (#703E26, 2 tones, a bark line) with a carved collar under the finial and a 3-turn rope wrap low down; Agent A's
-- skull finial (today's Skull, top at 16.31) and feather (today's Feather place and tilt); a chamfered stone collar
-- with 2 small stones and a moss tuft at the foot.
-- Parts: Bone, Cloth, Rope, Stone, Wood, Collision x2.
function Decor.jungle_war_banner(): Model
	local m = Instance.new("Model")
	m.Name = "jungle_war_banner"
	local rng = Random.new(20261274)
	H.setBevelSelf(true)
	local U: any = { Wood = {}, Stone = {}, Rope = {}, Bone = {}, Cloth = {} }
	local STONE = rgb(132, 138, 124) -- #848A7C
	local STONE_DARK = rgb(92, 100, 92) -- #5C645C
	local HEAD = rgb(104, 68, 44) -- #68442C
	-- the stone collar at the foot (1.5 x 0.35, chamfered), 2 small stones, a moss tuft
	table.insert(U.Stone, chamfered(Vector3.new(1.5, 0.35, 1.5), CFrame.new(0, 0.175, 0), STONE_DARK, { "vertical", "topFrontBack", "topSides" }, 0.1))
	for k, s in ipairs({ 0.42, 0.36 }) do
		local a = rad(-60 + k * 150)
		local p = Vector3.new(math.cos(a) * 0.5, 0.35 + s * 0.2, math.sin(a) * 0.5)
		R.looseStone(U.Stone, rng, Vector3.new(s, s * 0.5, s * 0.8), CFrame.lookAt(p, Vector3.new(0, p.Y, 0)) * CFrame.Angles(rad(-10), 0, 0), H.scaled(STONE, rng:NextNumber(0.9, 1.05)))
	end
	R.mossMat(U.Stone, rng, CFrame.new(-0.3, 0.35, 0.3) * CFrame.Angles(0, rad(-45), 0), 0.5, 0.3, 0.3)
	-- the pole (today's 0.6 x 15): 8 sides in 2 tones, a bark line, a 3-turn rope wrap at y 2.0, the carved collar
	-- under the finial (2 rings 0.75 x 0.12 at y 14.5 and 14.85 with a lighter band between)
	ringY(U.Wood, 8, 0.3, 0.28, 0, 15.0, { WOOD_DARK, H.scaled(WOOD_DARK, 0.88) })
	table.insert(U.Wood, piece("Part", Vector3.new(0.05, 2.2, 0.03), outFrame(0.3, 0, 6.5), H.scaled(WOOD_DARK, 0.75)))
	for t = 0, 2 do
		ringY(U.Rope, 8, 0.34, 0.34, 1.82 + t * 0.12, 1.92 + t * 0.12, { ROPE, H.scaled(ROPE, 0.86) })
	end
	for _, y in ipairs({ 14.5, 14.85 }) do
		ringY(U.Wood, 8, 0.375, 0.375, y - 0.06, y + 0.06, { HEAD, H.scaled(HEAD, 0.9) })
	end
	ringY(U.Wood, 8, 0.33, 0.33, 14.56, 14.79, { H.scaled(HEAD, 1.12) })
	-- today's crossbar (5.6 x 0.5 x 0.5 at y 13.4): a chamfered beam, carved end knobs (0.6, chamfered) within its length
	table.insert(U.Wood, chamfered(Vector3.new(4.4, 0.5, 0.5), CFrame.new(0, 13.4, 0), WOOD_DARK, { "topFrontBack", "bottomFrontBack" }, 0.1))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(U.Wood, chamfered(Vector3.new(0.6, 0.6, 0.6), CFrame.new(sx * 2.5, 13.4, 0), HEAD, { "vertical", "topFrontBack", "topSides", "bottomFrontBack", "bottomSides" }, 0.12))
		table.insert(U.Wood, piece("Part", Vector3.new(0.04, 0.4, 0.4), CFrame.new(sx * 2.81, 13.4, 0) * CFrame.Angles(rad(45), 0, 0), H.scaled(HEAD, 0.7)))
	end
	-- the rope X-lashing where the crossbar crosses the pole (2 crossed strips on the front and back, 2 rings)
	for _, z in ipairs({ -0.31, 0.31 }) do
		for _, sgn in ipairs({ -1, 1 }) do
			table.insert(U.Rope, piece("Part", Vector3.new(0.12, 0.95, 0.06), CFrame.new(0, 13.4, z) * CFrame.Angles(0, 0, rad(sgn * 45)), H.scaled(ROPE, if sgn < 0 then 1 else 0.9)))
		end
	end
	for _, y in ipairs({ 12.95, 13.85 }) do
		ringY(U.Rope, 8, 0.35, 0.35, y - 0.05, y + 0.05, { ROPE, H.scaled(ROPE, 0.86) })
	end
	-- 5 rope loops round the crossbar (0.62 across, tilted 10 deg), each with a short tie down to the sleeve
	local XAX = CFrame.Angles(0, 0, rad(90)) -- a frame whose Y runs along X
	for k, x in ipairs({ -2.0, -1.0, 0.0, 1.0, 2.0 }) do
		if x ~= 0 then
			table.insert(U.Rope, M.frustumN(8, 0.31, 0.31, -0.05, 0.05, CFrame.new(x, 13.4, 0) * XAX * CFrame.Angles(0, 0, rad(if k % 2 == 0 then 10 else -10)), { ROPE, H.scaled(ROPE, 0.86) }))
		end
		table.insert(U.Rope, H.bar(Vector3.new(x + 0.02, 13.4, -0.28), Vector3.new(x - 0.02, 13.08, -0.5), 0.08, H.scaled(ROPE, 0.9)))
	end
	-- Agent A's cloth, skull finial and feather
	J.facets(U, DData.banner_cloth, Vector3.one, CFrame.identity, "Cloth")
	J.facets(U, DData.pike_skull, Vector3.one * 0.83, FINIAL, "Bone")
	J.facets(U, DData.feather, Vector3.one, CFrame.new(0.44, 15.6, 0.3) * CFrame.fromOrientation(0, 0, rad(-25)), "Bone")
	finish(m, "jungle_war_banner", U, "Wood")
	return m
end

---------------------------------------------------------------------
-- registration: the builders go into the same PropsBatch2 table as the jungle totems; its install() builds them
---------------------------------------------------------------------
Decor.BUILDERS = { jungle_drum = true, jungle_torch = true, jungle_skull_pole = true, jungle_war_banner = true }
for id in pairs(Decor.BUILDERS) do
	B2[id] = (Decor :: any)[id]
	B2.BUILDERS[id] = true
end
Decor.install = B2.install
Decor.SHAPES = M.SHAPES
Decor.T = T

return Decor
