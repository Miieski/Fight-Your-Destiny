--[[
	PortalRuins (dev tool, Edit mode only), Round 9 part 14: the ruin that marks the next portal to open. Source of truth: tools/PortalRuins.luau
	(= ServerStorage.DevTools.PortalRuins). Runs after DevTools.PortalBricks; images: tools/make_ruin_textures.py.

	A template holds the REAL bricks of the portal (Assets.PortalBricks.portal_frame, attribute BrickId), some in place (steps, stumps), some
	lying around (arch fragments, capitals, the keystone, the pile), so Controllers/PortalController flies them back. Everything else fades:
		Bricks  (Folder)  clones of the bricks, each with its BrickId; a brick left out rises from the ground or the pile during the build
		Decor   (Folder)  Cracks, Rune (invisible plates with a Decal), Pebbles, Chips, Cover and Glow (the zone's own moss, sand, snow ...)
		Sign    (Model)   posts, frame, Board (the client gives it its SurfaceGui and ProximityPrompt)
		Collide (Folder)  one invisible box per stump: the only collision of a ruin
	Attributes: Pile (Vector3, where the bricks left out come from), PreviewZone and SizeClass (BuildAssetPreview shows it in that block).

	Usage (execute_luau, Edit): one zone per call, CSG takes a while. Plains is always open, it has no ruin.
		local R = require(game.ServerStorage.DevTools.PortalRuins:Clone())
		print(R.ids())          -- gives the bricks their BrickId (once; PortalBricks.build does it too)
		print(R.build("Desert"))-- MapProps.portal_ruins_desert and its client copy Assets.PortalRuins.Desert
		print(R.check())        -- every zone: bricks, collision, height, parts, anchor against the real frame
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local B2 = require(ServerStorage.DevTools.PropsBatch2:Clone()) :: any
local Config = require(ReplicatedStorage.GameSystem.Config.PortalRuins) :: any -- not a Clone: it needs its Zones sibling

local R = {}

local rgb = Color3.fromRGB
local piece, chamfered, merge, P = B2.piece, B2.chamfered, B2.merge, B2.PALETTE
local G = 0.68 -- the ground, in template height (pivot at y -0.6, hub ground at 0.0 .. 0.2)
local STEP_TOP = 1.0
local OFF = 24 -- brick id on the right = brick id on the left + 24
local ORDER = { "Desert", "Jungle", "Tundra", "Swamp", "Volcano", "Hell", "Heaven", "Dead", "Abyss", "Mechanical", "Void" }

local function shade(c: Color3, f: number): Color3
	return Color3.new(math.min(c.R * f, 1), math.min(c.G * f, 1), math.min(c.B * f, 1))
end

function R.ids(): string
	local set = ReplicatedStorage.Assets.PortalBricks.portal_frame
	for i, brick in ipairs(set:GetChildren()) do
		brick:SetAttribute("BrickId", i)
	end
	return `{#set:GetChildren()} bricks numbered`
end

-- the lowest point of a part at a pose: union CFrames are not their centres
local function lowest(part: BasePart): number
	local half, box = part.ExtentsSize / 2, part.ExtentsCFrame
	local low = math.huge
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				low = math.min(low, box:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)).Y)
			end
		end
	end
	return low
end

type Ctx = { list: { BasePart }, glow: { BasePart }, rng: Random, s: number, tall: Vector3, short: Vector3, pile: Vector3 }

-- shapes of the covers ------------------------------------------------------------------------------------
local function pad(list: { BasePart }, cf: CFrame, size: Vector3, color: Color3, c: number?)
	local p = chamfered(size, cf, color, { "topFrontBack", "topSides" }, math.min(c or 0.14, size.Y * 0.7, size.Z * 0.4))
	if p:IsA("PartOperation") then
		p.UsePartColor = true -- the cut faces of a chamfer come out pale grey: a dark pad would get a light outline
		p.Color = color
	end
	table.insert(list, p)
end

-- a low dune or snow bank, 3 stepped pads
local function drift(ctx: Ctx, x: number, z: number, y: number, len: number, wid: number, yaw: number, color: Color3)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	local turn = ctx.rng:NextNumber(-0.22, 0.22)
	pad(ctx.list, cf * CFrame.new(0, 0.2, 0), Vector3.new(len, 0.52, wid), color, 0.26)
	pad(ctx.list, cf * CFrame.new(len * 0.06, 0.58, 0) * CFrame.Angles(0, turn, 0), Vector3.new(len * 0.68, 0.44, wid * 0.66), shade(color, 1.05), 0.2)
	pad(ctx.list, cf * CFrame.new(-len * 0.04, 0.9, 0.04) * CFrame.Angles(0, -turn, 0), Vector3.new(len * 0.36, 0.34, wid * 0.36), shade(color, 1.1), 0.14)
	-- the two ends run out into the ground
	for _, side in ipairs({ -1, 1 }) do
		table.insert(ctx.list, piece("WedgePart", Vector3.new(wid * 0.8, 0.5, 1.7), cf * CFrame.new(side * (len / 2 + 0.8), 0.2, 0) * CFrame.Angles(0, side * math.rad(90), 0), shade(color, 0.97)))
	end
end

-- a chain of blocks through points, its width going from w0 to w1 (roots, ivy, seaweed, pipes, slime)
local function strand(list: { BasePart }, points: { Vector3 }, w0: number, w1: number, color: Color3)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local w = w0 + (w1 - w0) * (i - 1) / math.max(#points - 2, 1)
		local length = (b - a).Magnitude + w * 0.5
		table.insert(list, piece("Part", Vector3.new(w, w, length), CFrame.lookAt((a + b) / 2, b, Vector3.new(0.1, 1, 0.1)), color))
	end
end

-- a root that leaves the stone at from and runs to to, on the way down
local function root(ctx: Ctx, from: Vector3, to: Vector3, w: number, color: Color3)
	local points, side = {}, Vector3.new(ctx.rng:NextNumber(-0.5, 0.5), 0, ctx.rng:NextNumber(-0.5, 0.5))
	for i = 0, 5 do
		local t = i / 5
		local bulge = math.sin(t * math.pi)
		table.insert(points, from:Lerp(to, t) + side * bulge + Vector3.new(0, 0.3 * bulge, 0))
	end
	strand(ctx.list, points, w, w * 0.35, color)
end

local function hang(ctx: Ctx, top: Vector3, drop: number, w: number, color: Color3, leaf: Color3?)
	local points = {}
	for i = 0, 4 do
		table.insert(points, top + Vector3.new(ctx.rng:NextNumber(-0.12, 0.12), -drop * i / 4, 0))
	end
	strand(ctx.list, points, w, w * 0.7, color)
	if leaf then
		for _, p in ipairs(points) do
			table.insert(ctx.list, piece("Part", Vector3.new(0.48, 0.07, 0.34), CFrame.new(p + Vector3.new(0.1, 0, -0.06)) * CFrame.Angles(ctx.rng:NextNumber(-0.7, 0.7), ctx.rng:NextNumber(0, 6.28), ctx.rng:NextNumber(-0.7, 0.7)), shade(leaf, ctx.rng:NextNumber(0.85, 1.1))))
		end
	end
end

-- a thin ridge, two wedges back to back: ice, crystal, horn, weed blade
local function shard(list: { BasePart }, base: Vector3, h: number, w: number, tilt: Vector3, color: Color3)
	local cf = CFrame.new(base) * CFrame.Angles(tilt.X, tilt.Y, tilt.Z) * CFrame.new(0, h / 2, 0)
	table.insert(list, piece("WedgePart", Vector3.new(w, h, w / 2), cf * CFrame.new(0, 0, -w / 4) * CFrame.Angles(0, math.pi, 0), color))
	table.insert(list, piece("WedgePart", Vector3.new(w, h, w / 2), cf * CFrame.new(0, 0, w / 4), shade(color, 0.86)))
end

local function tuft(ctx: Ctx, base: Vector3, h: number, color: Color3)
	for i = 1, 3 do
		local a = i * 2.1 + ctx.rng:NextNumber(0, 1)
		shard(ctx.list, base, h * ctx.rng:NextNumber(0.7, 1.1), 0.34, Vector3.new(math.cos(a) * 0.35, a, math.sin(a) * 0.35), shade(color, ctx.rng:NextNumber(0.9, 1.1)))
	end
end

local function disc(list: { BasePart }, center: Vector3, r: number, h: number, color: Color3)
	table.insert(list, piece("Part", Vector3.new(h, r * 2, r * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, { shape = Enum.PartType.Cylinder }))
end

local function puddle(ctx: Ctx, x: number, z: number, r: number, color: Color3)
	disc(ctx.list, Vector3.new(x, G + 0.05, z), r, 0.12, color)
	disc(ctx.list, Vector3.new(x + r * 0.9, G + 0.05, z + r * 0.4), r * 0.5, 0.1, shade(color, 1.1))
	disc(ctx.list, Vector3.new(x - r * 0.8, G + 0.05, z - r * 0.5), r * 0.38, 0.1, shade(color, 0.9))
end

local function mushroom(list: { BasePart }, base: Vector3, h: number, r: number, stem: Color3, cap: Color3)
	table.insert(list, piece("Part", Vector3.new(0.26, h, 0.26), CFrame.new(base + Vector3.new(0, h / 2, 0)), stem))
	disc(list, base + Vector3.new(0, h, 0), r, 0.14, cap)
	disc(list, base + Vector3.new(0, h + 0.1, 0), r * 0.62, 0.12, cap)
end

local function gear(ctx: Ctx, center: Vector3, r: number, tilt: number, color: Color3)
	local cf = CFrame.new(center) * CFrame.Angles(tilt, ctx.rng:NextNumber(0, 6.28), 0)
	table.insert(ctx.list, piece("Part", Vector3.new(0.3, r * 2, r * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, { shape = Enum.PartType.Cylinder }))
	table.insert(ctx.list, piece("Part", Vector3.new(0.42, r * 0.7, r * 0.7), cf * CFrame.Angles(0, 0, math.rad(90)), shade(color, 0.7), { shape = Enum.PartType.Cylinder }))
	for i = 1, 8 do
		local a = i / 8 * math.tau
		table.insert(ctx.list, piece("Part", Vector3.new(r * 0.36, 0.28, r * 0.34), cf * CFrame.Angles(0, a, 0) * CFrame.new(r + r * 0.1, 0, 0), color))
	end
end

-- the cover of each zone ----------------------------------------------------------------------------------
local THEMES: { [string]: (Ctx) -> () } = {}

function THEMES.Desert(ctx: Ctx)
	local sand, s = rgb(226, 196, 134), ctx.s
	drift(ctx, s * 9.2, -8.4, G, 7, 3.6, 0.3, sand)
	drift(ctx, -s * 8.8, -8.8, G, 6, 3.2, -0.25, shade(sand, 0.96))
	drift(ctx, s * 1.2, -2.2, STEP_TOP - 0.1, 5.5, 2.2, 0.12, shade(sand, 1.02))
	drift(ctx, -s * 11, 1.6, G, 5, 3, 1.2, shade(sand, 0.94))
	pad(ctx.list, CFrame.new(ctx.tall + Vector3.new(0.3, 0.06, 0.2)), Vector3.new(2.2, 0.2, 2.6), shade(sand, 1.06), 0.1)
	pad(ctx.list, CFrame.new(ctx.short + Vector3.new(-0.4, 0.06, -0.3)), Vector3.new(2.6, 0.2, 2.8), shade(sand, 1.04), 0.1)
	for _, p in ipairs({ Vector3.new(-s * 11.4, G, -2.2), Vector3.new(s * 5.4, G, -5.2), Vector3.new(-s * 3.4, G, -4.6) }) do
		tuft(ctx, p, 1.1, rgb(176, 150, 92))
	end
end

function THEMES.Jungle(ctx: Ctx)
	local bark, leaf, s = rgb(92, 66, 44), P.MossDark, ctx.s
	root(ctx, ctx.tall + Vector3.new(-s * 1.4, -0.4, 2.2), Vector3.new(s * 3.2, STEP_TOP + 0.1, -3.6), 0.62, bark)
	root(ctx, ctx.tall + Vector3.new(s * 1.8, -0.8, 2), Vector3.new(s * 12.4, G + 0.05, -2.4), 0.55, shade(bark, 0.9))
	root(ctx, ctx.short + Vector3.new(s * 1.2, -0.3, 2.2), Vector3.new(-s * 2.2, STEP_TOP + 0.1, -3.4), 0.56, shade(bark, 1.1))
	root(ctx, ctx.short + Vector3.new(-s * 1.8, -0.6, 2), Vector3.new(-s * 11.6, G + 0.05, 0.6), 0.5, bark)
	hang(ctx, ctx.tall + Vector3.new(-s * 0.8, 0, -2.2), 3.6, 0.1, rgb(70, 110, 52), leaf)
	hang(ctx, ctx.short + Vector3.new(s * 0.6, 0, -2.2), 2.2, 0.1, rgb(70, 110, 52), leaf)
	for _, p in ipairs({ Vector3.new(s * 6.4, STEP_TOP, -2.8), Vector3.new(-s * 6, STEP_TOP, -2.6), Vector3.new(s * 1, STEP_TOP, 2.6), Vector3.new(-s * 2.6, STEP_TOP, -2.9) }) do
		pad(ctx.list, CFrame.new(p) * CFrame.Angles(0, ctx.rng:NextNumber(0, 3), 0), Vector3.new(2, 0.2, 1), shade(P.Moss, ctx.rng:NextNumber(0.75, 0.95)), 0.1)
	end
	for _, p in ipairs({ Vector3.new(-s * 12, G, -3), Vector3.new(s * 4.6, G, -5.2), Vector3.new(-s * 10.4, G, 2.6) }) do
		tuft(ctx, p, 1.5, leaf)
	end
end

function THEMES.Tundra(ctx: Ctx)
	local snow, ice, s = rgb(236, 244, 250), rgb(166, 216, 244), ctx.s
	pad(ctx.list, CFrame.new(ctx.tall + Vector3.new(0, 0.08, 0)), Vector3.new(3.2, 0.3, 4.2), snow, 0.14)
	pad(ctx.list, CFrame.new(ctx.short + Vector3.new(0, 0.08, 0)), Vector3.new(3.4, 0.3, 4.4), snow, 0.14)
	drift(ctx, s * 10, -8.2, G, 7.5, 3.6, 0.2, snow)
	drift(ctx, -s * 9.6, -8.4, G, 6.5, 3.4, -0.3, shade(snow, 0.97))
	drift(ctx, -s * 1.6, 2.4, STEP_TOP - 0.1, 7, 1.8, 0, shade(snow, 0.99))
	for _, p in ipairs({ { -s * 11.8, -1, 2.4 }, { -s * 12.6, -2.2, 1.6 }, { s * 12.6, 1.4, 2.8 }, { s * 4.4, -5.2, 1.6 }, { -s * 3.6, -5.4, 1.2 } }) do
		shard(ctx.list, Vector3.new(p[1], G - 0.05, p[2]), p[3], 0.9, Vector3.new(ctx.rng:NextNumber(-0.3, 0.3), ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(-0.3, 0.3)), ice)
	end
	for i = 1, 3 do
		table.insert(ctx.list, piece("WedgePart", Vector3.new(0.24, 0.8, 0.3), CFrame.new(ctx.short + Vector3.new(-1.2 + i * 0.6, -0.4, -2.3)) * CFrame.Angles(math.pi, 0, 0), ice))
	end
end

function THEMES.Swamp(ctx: Ctx)
	local slime, dead, s = rgb(116, 170, 62), rgb(56, 46, 42), ctx.s
	puddle(ctx, s * 3.2, -8.8, 1.5, slime)
	puddle(ctx, -s * 10.4, -7, 1.8, shade(slime, 0.9))
	puddle(ctx, s * 12.4, 1.6, 1.4, shade(slime, 0.84))
	disc(ctx.list, Vector3.new(-s * 2.2, STEP_TOP + 0.04, 2.2), 1.2, 0.08, shade(slime, 1.08))
	for _, drop in ipairs({ { ctx.tall + Vector3.new(-1, 0, -2.2), 3.4 }, { ctx.tall + Vector3.new(0.7, 0, -2.2), 2.2 }, { ctx.short + Vector3.new(0.4, 0, -2.3), 1.8 } }) do
		hang(ctx, drop[1], drop[2], 0.26, shade(slime, 1.06))
	end
	root(ctx, ctx.tall + Vector3.new(s * 1.8, -0.6, 2), Vector3.new(s * 11.8, G + 0.05, -3), 0.5, dead)
	root(ctx, ctx.short + Vector3.new(-s * 1.8, -0.5, 2), Vector3.new(-s * 11.6, G + 0.05, 1), 0.46, shade(dead, 1.2))
	root(ctx, ctx.short + Vector3.new(s * 1.2, -0.4, -1.8), Vector3.new(-s * 1.6, STEP_TOP + 0.1, -3.4), 0.42, dead)
	mushroom(ctx.list, Vector3.new(s * 5.8, G, -5.4), 0.8, 0.5, rgb(190, 186, 150), rgb(120, 70, 150))
	mushroom(ctx.list, Vector3.new(-s * 5.6, G, -5), 0.6, 0.4, rgb(190, 186, 150), rgb(92, 130, 70))
end

local function embers(ctx: Ctx, list: { { number } }, color: Color3)
	for _, line in ipairs(list) do
		local a, b = Vector3.new(line[1], G + 0.04, line[2]), Vector3.new(line[3], G + 0.04, line[4])
		local mid = (a + b) / 2 + Vector3.new(ctx.rng:NextNumber(-0.7, 0.7), 0, ctx.rng:NextNumber(-0.7, 0.7))
		strand(ctx.glow, { a, mid, b }, 0.24, 0.1, color)
	end
end

function THEMES.Volcano(ctx: Ctx)
	local ash, rock, s = rgb(74, 70, 72), rgb(46, 42, 44), ctx.s
	drift(ctx, s * 10, -8.4, G, 7, 3.4, 0.25, ash)
	drift(ctx, -s * 10, -8, G, 6, 3, -0.3, shade(ash, 1.1))
	pad(ctx.list, CFrame.new(ctx.tall + Vector3.new(0, 0.06, 0)), Vector3.new(2.6, 0.22, 3.4), shade(ash, 1.15), 0.1)
	pad(ctx.list, CFrame.new(ctx.short + Vector3.new(0, 0.06, 0)), Vector3.new(2.8, 0.22, 3.4), ash, 0.1)
	embers(ctx, { { s * 2, -4.6, s * 7, -5.6 }, { -s * 2, -4.2, -s * 7, -5.4 }, { -s * 12, -2, -s * 12.6, 2 } }, rgb(255, 120, 30))
	for _, p in ipairs({ { s * 4.6, -5.4, 1.4 }, { -s * 5, -5.6, 1.2 }, { -s * 12.4, -3.6, 1.7 }, { s * 12.8, 1.8, 1.5 } }) do
		shard(ctx.list, Vector3.new(p[1], G - 0.05, p[2]), p[3], 1.1, Vector3.new(ctx.rng:NextNumber(-0.25, 0.25), ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(-0.25, 0.25)), rock)
	end
end

function THEMES.Hell(ctx: Ctx)
	local soot, bone, s = rgb(58, 34, 36), rgb(206, 190, 164), ctx.s
	drift(ctx, s * 10, -8.2, G, 6.5, 3.2, 0.2, soot)
	drift(ctx, -s * 10, -8.2, G, 6.5, 3.2, -0.2, shade(soot, 1.15))
	embers(ctx, { { s * 1, -4.4, s * 6, -5.8 }, { -s * 1.4, -4.8, -s * 6.4, -5.6 }, { s * 12.2, -1.4, s * 12.8, 2.2 }, { -s * 11.6, 0, -s * 13, 2.4 } }, rgb(232, 44, 40))
	for _, p in ipairs({ { s * 12.6, -2.6, 2.2, 0.3 }, { s * 11.2, 1.8, 1.8, 0.2 }, { -s * 12.4, -3.4, 2.4, -0.3 }, { -s * 3.6, -5.6, 1.5, -0.2 }, { s * 4.2, -5.8, 1.3, 0.2 } }) do
		shard(ctx.list, Vector3.new(p[1], G - 0.05, p[2]), p[3], 0.7, Vector3.new(0, 0.4, p[4]), bone)
	end
	pad(ctx.list, CFrame.new(ctx.tall + Vector3.new(0, 0.05, 0)), Vector3.new(2.4, 0.2, 3.2), shade(soot, 1.2), 0.1)
end

function THEMES.Heaven(ctx: Ctx)
	local cloud, gold, s = rgb(246, 248, 255), rgb(236, 196, 84), ctx.s
	drift(ctx, s * 10.6, -8, G, 7, 3.8, 0.3, cloud)
	drift(ctx, -s * 9.8, -8.4, G, 6.4, 3.6, -0.3, shade(cloud, 0.97))
	drift(ctx, -s * 2.4, 2.2, STEP_TOP - 0.1, 6, 1.9, 0, shade(cloud, 0.99))
	drift(ctx, s * 3.8, -10.600000000000001, G, 3.6, 2, 0.1, shade(cloud, 0.98))
	hang(ctx, ctx.tall + Vector3.new(-s * 0.7, 0, -2.2), 3.6, 0.09, gold, shade(gold, 1.1))
	hang(ctx, ctx.short + Vector3.new(s * 0.6, 0, -2.2), 2.2, 0.09, gold, shade(gold, 1.1))
	pad(ctx.list, CFrame.new(ctx.short + Vector3.new(0, 0.06, 0)), Vector3.new(3, 0.24, 3.8), cloud, 0.12)
	for _, p in ipairs({ Vector3.new(-s * 12.2, G, -1.4), Vector3.new(-s * 4.4, G, -5.2) }) do
		tuft(ctx, p, 1, gold)
	end
end

function THEMES.Dead(ctx: Ctx)
	local pale, ghost, s = rgb(172, 180, 168), rgb(120, 255, 190), ctx.s
	root(ctx, ctx.tall + Vector3.new(s * 1.8, -0.6, 2), Vector3.new(s * 12, G + 0.05, -2.8), 0.46, pale)
	root(ctx, ctx.short + Vector3.new(-s * 1.8, -0.5, 2), Vector3.new(-s * 11.8, G + 0.05, 0.8), 0.42, shade(pale, 0.86))
	root(ctx, ctx.tall + Vector3.new(-s * 1.4, -0.4, -1.6), Vector3.new(s * 2.8, STEP_TOP + 0.1, -3.4), 0.4, shade(pale, 0.92))
	for _, p in ipairs({ Vector3.new(s * 6.2, STEP_TOP, -2.8), Vector3.new(-s * 5.6, STEP_TOP, -2.7) }) do
		pad(ctx.list, CFrame.new(p), Vector3.new(2.2, 0.18, 0.9), rgb(92, 112, 96), 0.08)
	end
	mushroom(ctx.glow, Vector3.new(s * 5, G, -5.4), 0.9, 0.46, ghost, ghost)
	mushroom(ctx.glow, Vector3.new(-s * 4.6, G, -5.2), 0.7, 0.36, ghost, ghost)
	mushroom(ctx.glow, Vector3.new(-s * 12.2, G, -2.6), 0.8, 0.42, ghost, ghost)
	for i = 0, 3 do -- ribs of something old
		local x = -s * (10.4 + i * 0.6)
		strand(ctx.list, { Vector3.new(x, G, 2.2), Vector3.new(x, G + 0.8, 1.6), Vector3.new(x, G + 1, 0.9) }, 0.17, 0.09, rgb(214, 212, 196))
	end
end

function THEMES.Abyss(ctx: Ctx)
	local weed, s = rgb(46, 132, 96), ctx.s
	local function coral(base: Vector3, color: Color3)
		strand(ctx.list, { base, base + Vector3.new(0.1, 0.9, 0), base + Vector3.new(-0.1, 1.7, 0.1) }, 0.34, 0.2, color)
		strand(ctx.list, { base + Vector3.new(0.1, 0.8, 0), base + Vector3.new(0.6, 1.3, 0.1), base + Vector3.new(0.7, 1.9, 0.2) }, 0.24, 0.14, shade(color, 1.1))
		strand(ctx.list, { base + Vector3.new(0, 0.5, 0), base + Vector3.new(-0.6, 0.9, -0.1), base + Vector3.new(-0.7, 1.4, -0.1) }, 0.24, 0.14, shade(color, 0.9))
	end
	coral(Vector3.new(s * 12.6, G, -2.4), rgb(238, 110, 130))
	coral(Vector3.new(-s * 12, G, -3), rgb(250, 160, 90))
	coral(Vector3.new(-s * 4.4, G, -5.2), rgb(120, 110, 220))
	coral(Vector3.new(s * 11.6, G, 2), rgb(70, 200, 200))
	for _, p in ipairs({ Vector3.new(s * 5, G, -4.8), Vector3.new(s * 3.6, G, -5.6), Vector3.new(-s * 6, G, -4.8), Vector3.new(-s * 11, G, 1.8) }) do
		strand(ctx.list, { p, p + Vector3.new(0.2, 0.8, 0), p + Vector3.new(-0.15, 1.6, 0.1), p + Vector3.new(0.2, 2.4, 0) }, 0.22, 0.1, shade(weed, ctx.rng:NextNumber(0.85, 1.15)))
	end
	for i = 1, 9 do -- barnacles
		local on = if i % 2 == 0 then ctx.tall else ctx.short
		disc(ctx.list, on + Vector3.new(ctx.rng:NextNumber(-1.3, 1.3), 0.06, ctx.rng:NextNumber(-1.7, 1.7)), ctx.rng:NextNumber(0.16, 0.3), 0.16, rgb(206, 214, 200))
	end
end

function THEMES.Mechanical(ctx: Ctx)
	local rust, copper, steel, s = rgb(142, 84, 52), rgb(190, 116, 70), rgb(112, 120, 130), ctx.s
	gear(ctx, Vector3.new(-s * 12, G + 0.2, -2.6), 1.5, 0.06, rust)
	gear(ctx, Vector3.new(s * 4.6, G + 0.2, -5.4), 1.05, 0.1, steel)
	gear(ctx, Vector3.new(-s * 4.4, G + 0.16, -5.2), 0.8, 0.05, shade(rust, 1.1))
	strand(ctx.list, { ctx.tall + Vector3.new(s * 1.8, -1, 2), Vector3.new(s * 12, G + 0.8, 1.2), Vector3.new(s * 12.8, G + 0.3, -3) }, 0.52, 0.52, copper)
	strand(ctx.list, { ctx.short + Vector3.new(-s * 1.8, -0.8, 2), Vector3.new(-s * 11.6, G + 0.6, 1.6), Vector3.new(-s * 13, G + 0.3, 2.2) }, 0.46, 0.46, shade(copper, 0.9))
	for _, p in ipairs({ Vector3.new(s * 7.4, STEP_TOP, -3), Vector3.new(-s * 7, STEP_TOP, -2.8), Vector3.new(s * 1, STEP_TOP, 2.6) }) do
		pad(ctx.list, CFrame.new(p) * CFrame.Angles(0, ctx.rng:NextNumber(0, 3), 0), Vector3.new(1.8, 0.14, 1.2), shade(rust, ctx.rng:NextNumber(0.8, 1)), 0.05)
	end
	pad(ctx.list, CFrame.new(ctx.tall + Vector3.new(0, 0.05, 0)), Vector3.new(2.6, 0.18, 3.2), shade(rust, 0.9), 0.06)
end

function THEMES.Void(ctx: Ctx)
	local dust, dark, bright, s = rgb(44, 30, 62), rgb(60, 36, 90), rgb(255, 60, 220), ctx.s
	drift(ctx, s * 10, -8.2, G, 6.6, 3.2, 0.2, dust)
	drift(ctx, -s * 10, -8.2, G, 6.2, 3.2, -0.2, shade(dust, 1.2))
	for _, p in ipairs({ { s * 12.4, -1.6, 2.2 }, { -s * 12.4, -3.2, 1.8 }, { s * 4.6, -5.4, 1.4 }, { -s * 4, -5.6, 1.2 } }) do
		shard(ctx.list, Vector3.new(p[1], G - 0.05, p[2]), p[3], 1, Vector3.new(ctx.rng:NextNumber(-0.25, 0.25), ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(-0.25, 0.25)), dark)
	end
	for _, p in ipairs({ ctx.short + Vector3.new(0, 2.6, 0), ctx.tall + Vector3.new(0, 1.8, 0), Vector3.new(-s * 11.6, 5, -1.6), Vector3.new(s * 0.6, 5.4, 0) }) do -- they float
		shard(ctx.glow, p, 1.1, 0.5, Vector3.new(ctx.rng:NextNumber(-0.4, 0.4), ctx.rng:NextNumber(0, 3), ctx.rng:NextNumber(-0.4, 0.4)), bright)
		shard(ctx.glow, p, 0.9, 0.5, Vector3.new(math.pi + ctx.rng:NextNumber(-0.3, 0.3), ctx.rng:NextNumber(0, 3), 0), bright)
	end
end

-- what lies on each fallen stone: the zone reads from afar
local BLANKET: { [string]: Color3 } = {
	Desert = rgb(230, 200, 138), Jungle = rgb(96, 158, 66), Tundra = rgb(238, 245, 251), Swamp = rgb(104, 150, 60), Volcano = rgb(70, 66, 68), Hell = rgb(66, 36, 38),
	Heaven = rgb(246, 248, 255), Dead = rgb(104, 124, 106), Abyss = rgb(70, 140, 120), Mechanical = rgb(142, 84, 52), Void = rgb(52, 36, 74),
}

-- the template ---------------------------------------------------------------------------------------------
local function plate(folder: Instance, name: string, size: Vector3, cf: CFrame, image: string, color: Color3, transparency: number): Part
	local p = piece("Part", size, cf, Color3.new()) :: Part
	p.Name = name
	p.Transparency = 1
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = image
	d.Color3 = color
	d.Transparency = transparency
	d.Parent = p
	p.Parent = folder
	return p
end

local function sign(m: Model, cf: CFrame)
	local holder = Instance.new("Model")
	holder.Name = "Sign"
	local wood, dark, iron = P.WoodMid, P.WoodDark, P.Iron
	local posts: { BasePart } = {}
	for _, x in ipairs({ -3.1, 3.1 }) do
		table.insert(posts, chamfered(Vector3.new(0.56, 5.9, 0.56), cf * CFrame.new(x, 2.75, 0.34), shade(dark, 1.08), { "vertical", "topFrontBack", "topSides" }, 0.1))
		table.insert(posts, chamfered(Vector3.new(1.3, 0.5, 1.3), cf * CFrame.new(x, 0.14, 0.34), P.StoneDark, { "topFrontBack", "topSides" }, 0.14))
	end
	local frame: { BasePart } = {}
	for _, s in ipairs({ { 0, 2.0, 7.3, 0.34 }, { 0, -2.0, 7.3, 0.34 }, { -3.5, 0, 0.34, 4.3 }, { 3.5, 0, 0.34, 4.3 } }) do
		table.insert(frame, chamfered(Vector3.new(s[3], s[4], 0.36), cf * CFrame.new(s[1], 3.75 + s[2], 0.02), dark, { "frontFace" }, 0.08))
	end
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		table.insert(frame, piece("Part", Vector3.new(0.5, 0.5, 0.42), cf * CFrame.new(c[1] * 3.5, 3.75 + c[2] * 2, 0.02), iron))
	end
	merge(holder, "Posts", posts)
	merge(holder, "Frame", frame)
	local board = piece("Part", Vector3.new(6.8, 3.7, 0.2), cf * CFrame.new(0, 3.75, 0.1), wood) :: Part
	board.Name = "Board"
	board.CanCollide, board.CanQuery, board.CanTouch = false, false, false
	board.Parent = holder
	holder.Parent = m
end

function R.build(zoneId: string): string
	local conf = Config.Zones[zoneId]
	assert(conf, "no ruin for " .. zoneId)
	local index = table.find(ORDER, zoneId) :: number
	local rng = Random.new(20261102 + index * 37)
	local set = ReplicatedStorage.Assets.PortalBricks.portal_frame
	local byId: { [number]: BasePart } = {}
	for _, brick in ipairs(set:GetChildren()) do
		byId[brick:GetAttribute("BrickId") :: number] = brick
	end
	local m = Instance.new("Model")
	m.Name = conf.Template
	local work = Instance.new("Folder") -- union extents need the DataModel
	work.Name = "_RuinWork"
	work.Parent = ServerStorage
	m.Parent = work
	local bricks = Instance.new("Folder")
	bricks.Name = "Bricks"
	bricks.Parent = m
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = m
	local collide = Instance.new("Folder")
	collide.Name = "Collide"
	collide.Parent = m

	local s = if index % 2 == 0 then -1 else 1 -- the side of the tall stump and of the pile
	local tallOff, shortOff = if s == 1 then OFF else 0, if s == 1 then 0 else OFF

	local function put(id: number, pose: CFrame?): BasePart
		local real = byId[id]
		local copy = real:Clone()
		copy.Parent = bricks
		if pose then
			local offsets = {}
			for _, part in ipairs(copy:GetDescendants()) do
				if part:IsA("BasePart") then
					offsets[part] = real.CFrame:ToObjectSpace(part.CFrame)
				end
			end
			copy.CFrame = pose
			for part, offset in pairs(offsets) do
				part.CFrame = pose * offset
			end
		end
		return copy
	end
	local fallen: { BasePart } = {}
	-- a brick lying at (x, z), its underside on height y
	local function lay(id: number, x: number, z: number, y: number, tilt: number): BasePart
		local turn = CFrame.Angles(rng:NextNumber(-tilt, tilt), rng:NextNumber(0, math.pi), rng:NextNumber(-tilt, tilt))
		local brick = put(id, CFrame.new(x, 0, z) * turn)
		local drop = y - lowest(brick)
		local pose = brick.CFrame + Vector3.new(0, drop, 0)
		brick:Destroy()
		local placed = put(id, pose)
		table.insert(fallen, placed)
		return placed
	end
	local function chip(id: number, shift: Vector3, tilt: number): BasePart
		local real = byId[id]
		local c = real.CFrame
		return put(id, (c + shift) * CFrame.Angles(rng:NextNumber(-tilt, tilt), rng:NextNumber(-tilt, tilt), rng:NextNumber(-tilt, tilt)))
	end

	-- 1. the steps stay; two slabs have moved
	for id = 1, 13 do
		if id == 12 then
			chip(if s == 1 then 12 else 8, Vector3.new(s * 0.22, 0.1, 0), 0.05)
		elseif id == 8 then
			chip(if s == 1 then 8 else 12, Vector3.new(-s * 0.12, 0.02, -0.1), 0.03)
		else
			put(id)
		end
	end
	-- 2. two stumps: 4 courses (2 plinths, 2 of the shaft) and 2 or 3
	local x0 = s * 7.5
	put(14 + tallOff)
	put(15 + tallOff)
	put(16 + tallOff) -- the mortar core
	put(21 + tallOff)
	chip(22 + tallOff, Vector3.new(0, 0, rng:NextNumber(-0.14, 0.14)), 0.04)
	chip(23 + tallOff, Vector3.new(s * 0.16, 0.02, 0), 0.09)
	put(14 + shortOff)
	put(15 + shortOff)
	local three = index % 3 ~= 0
	if three then
		chip(21 + shortOff, Vector3.new(-s * 0.2, 0.05, 0.12), 0.08)
	end
	local tallTop = Vector3.new(x0, 5.56, 0)
	local shortTop = Vector3.new(-x0, if three then 4.28 else 3.02, 0)
	for _, stump in ipairs({ tallTop, shortTop }) do
		local box = piece("Part", Vector3.new(4.4, stump.Y - G, 5.6), CFrame.new(stump.X, (stump.Y + G) / 2, 0), Color3.new()) :: Part
		box.Name = "Stump"
		box.Transparency = 1
		box.CastShadow = false
		box.CanCollide, box.CanQuery, box.CanTouch = true, true, false
		box.Parent = collide
	end
	-- 3. what fell: the pile under the tall stump, arch stones and capitals in front
	local pile = Vector3.new(s * 11.2, G, -5.2)
	for _, p in ipairs({ { 9.6, -6.2, 24 + tallOff }, { 11.3, -6.7, 26 + tallOff }, { 12.6, -5.4, 27 + tallOff }, { 10.5, -4.3, 37 + tallOff }, { 12.5, -3.9, 30 + tallOff } }) do
		lay(p[3], s * p[1], p[2], G - 0.04, 0.05)
	end
	for _, p in ipairs({ { 10.4, -5.9, 25 + tallOff }, { 11.8, -5.5, 28 + tallOff }, { 11.3, -3.9, 29 + tallOff } }) do
		lay(p[3], s * p[1], p[2], G + 0.85, 0.25)
	end
	lay(71, s * 11.1, -5, G + 1.5, 0.3) -- the keystone on top, the zone's colour
	lay(if s == 1 then 64 else 69, -s * 5.2, -7.2, G - 0.03, 0.08) -- the middle stays clear: the way to the rune
	lay(if s == 1 then 66 else 67, s * 6.2, -5.8, G - 0.03, 0.1)
	lay(if s == 1 then 68 else 65, -s * 11.8, 1.6, G - 0.03, 0.1)
	lay(37 + shortOff, -s * 8, -4.9, G - 0.04, 0.06)
	lay(24 + shortOff, -s * 4.8, -4.6, G - 0.04, 0.12)
	lay(25 + shortOff, -s * 11, -1.2, G - 0.04, 0.2)
	lay(26 + shortOff, s * 4.4, -7.1, G - 0.04, 0.16)
	lay(if s == 1 then 63 else 62, -s * 1.6, -4.7, G - 0.02, 0.2) -- a gem in its setting, dull
	for _, part in ipairs(bricks:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("Glow") then
			part.Color = conf.Rune:Lerp(Color3.new(), 0.75)
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	for _, brick in ipairs(bricks:GetChildren()) do
		if brick:GetAttribute("Group") == "Keystone" then
			brick.Color = workspace.Hub.Decor.PortalFrames["PortalFrame_" .. zoneId].Keystone.Color
		end
	end

	-- 4. what fades with the ruin
	plate(decor, "Cracks", Vector3.new(16, 0.05, 5.8), CFrame.new(0, STEP_TOP + 0.03, 0), Config.Images.Cracks, Color3.new(1, 1, 1), 0.1)
	local rune = plate(decor, "Rune", Vector3.new(5.6, 0.05, 5.6), CFrame.new(0, STEP_TOP + 0.06, 0), Config.Images.Rune, conf.Rune, 0.08)
	local light = Instance.new("PointLight")
	light.Color = conf.Rune
	light.Brightness = 0.35
	light.Range = 9
	light.Shadows = false
	light.Parent = rune

	local pebbles: { BasePart } = {}
	for _ = 1, 12 do
		local size = Vector3.new(rng:NextNumber(0.3, 0.8), rng:NextNumber(0.2, 0.5), rng:NextNumber(0.3, 0.7))
		local x, z = rng:NextNumber(-13, 13), rng:NextNumber(-7, -4)
		table.insert(pebbles, piece("Part", size, CFrame.new(x, G + size.Y * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), shade(P.Stone, rng:NextNumber(0.6, 0.86))))
	end
	merge(decor :: any, "Pebbles", pebbles)
	-- the broken top of each stump: sharp stubs of the stone that went
	local chips: { BasePart } = {}
	for _, stump in ipairs({ tallTop, shortTop }) do
		for _ = 1, 3 do
			local at = stump + Vector3.new(rng:NextNumber(-1, 1), -0.08, rng:NextNumber(-1.5, 1.5))
			shard(chips, at, rng:NextNumber(0.5, 0.9), rng:NextNumber(0.7, 1.1), Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), shade(P.Stone, rng:NextNumber(0.72, 0.9)))
		end
	end
	merge(decor :: any, "Chips", chips)

	local ctx: Ctx = { list = {}, glow = {}, rng = rng, s = s, tall = tallTop, short = shortTop, pile = pile }
	THEMES[zoneId](ctx)
	for _, brick in ipairs(fallen) do
		local size, box = brick.ExtentsSize, brick.ExtentsCFrame
		if size.X > 1.5 and size.Z > 1.5 then
			local at = box * CFrame.new(rng:NextNumber(-0.12, 0.12) * size.X, size.Y / 2 + 0.03, rng:NextNumber(-0.12, 0.12) * size.Z)
			pad(ctx.list, at, Vector3.new(size.X * rng:NextNumber(0.6, 0.86), 0.22, size.Z * rng:NextNumber(0.6, 0.86)), shade(BLANKET[zoneId], rng:NextNumber(0.94, 1.06)), 0.1)
		end
	end
	merge(decor :: any, "Cover", ctx.list)
	if #ctx.glow > 0 then
		merge(decor :: any, "Glow", ctx.glow, { single = ctx.glow[1].Color, material = Enum.Material.Neon, shadow = false })
	end

	-- 5. the sign, on the side away from the pile
	sign(m, CFrame.new(-s * 12, G - 0.1, -6.4) * CFrame.Angles(0, -s * 0.2, 0))

	m.WorldPivot = CFrame.identity
	m:SetAttribute("Pile", pile)
	m:SetAttribute("PreviewZone", zoneId)
	m:SetAttribute("SizeClass", "medium")
	m:SetAttribute("MapPropId", conf.Template)

	local props = ServerStorage.MapProps
	local old = props:FindFirstChild(conf.Template)
	if old then
		old:Destroy()
	end
	m.Parent = props
	work:Destroy()
	local assets = ReplicatedStorage.Assets
	local sets = assets:FindFirstChild("PortalRuins")
	if not sets then
		sets = Instance.new("Folder")
		sets.Name = "PortalRuins"
		sets.Parent = assets
	end
	local gone = sets:FindFirstChild(zoneId)
	if gone then
		gone:Destroy()
	end
	local copy = m:Clone()
	copy.Name = zoneId
	copy.Parent = sets
	local parts = 0
	for _, item in ipairs(m:GetDescendants()) do
		if item:IsA("BasePart") then
			parts += 1
		end
	end
	return `{conf.Template}: {#bricks:GetChildren()} bricks, {parts} parts, cover {#ctx.list} + glow {#ctx.glow} pieces`
end

function R.check(): string
	local lines, good = {}, 0
	local set = ReplicatedStorage.Assets.PortalBricks.portal_frame
	local known: { [number]: boolean } = {}
	for _, brick in ipairs(set:GetChildren()) do
		known[brick:GetAttribute("BrickId") :: number] = true
	end
	for _, zoneId in ipairs(ORDER) do
		local conf = Config.Zones[zoneId]
		local m = ServerStorage.MapProps:FindFirstChild(conf.Template) :: Model
		local copy = ReplicatedStorage.Assets.PortalRuins:FindFirstChild(zoneId) :: Model
		local frame = workspace.Hub.Decor.PortalFrames:FindFirstChild("PortalFrame_" .. zoneId) :: Model
		local off = (frame:GetPivot().Position - conf.Anchor.Position).Magnitude
		local turn = (frame:GetPivot().LookVector - conf.Anchor.LookVector).Magnitude
		local parts, solid, top, seen, bad = 0, 0, 0, {}, 0
		for _, item in ipairs(m:GetDescendants()) do
			if item:IsA("BasePart") then
				parts += 1
				if item.CanCollide then
					solid += 1
					if item.Parent.Name ~= "Collide" then
						bad += 1
					end
					top = math.max(top, item.Position.Y + item.Size.Y / 2)
				end
			end
		end
		for _, brick in ipairs(m.Bricks:GetChildren()) do
			local id = brick:GetAttribute("BrickId")
			if not known[id] or seen[id] then
				bad += 1
			end
			seen[id] = true
		end
		local ok = copy ~= nil and off < 0.01 and turn < 0.001 and solid == 2 and bad == 0 and top <= 6
		good += if ok then 1 else 0
		table.insert(lines, string.format("%s %s: %d bricks, %d parts, %d solid, top %.2f, anchor off %.4f, bad %d", zoneId, if ok then "OK" else "NOT OK", #m.Bricks:GetChildren(), parts, solid, top, off, bad))
	end
	return `{good} / {#ORDER} OK\n` .. table.concat(lines, "\n")
end

return R
