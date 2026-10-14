-- Tuning pass 1 on the zone assets (after the Play survey), applied on top of zone_vfx_builder.luau. Run in Edit.
local A = game.ReplicatedStorage.Assets.VFX
local function ns(t) local k = {} for _, p in ipairs(t) do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end return NumberSequence.new(k) end
local function cs(list) local k = {} for _, p in ipairs(list) do table.insert(k, ColorSequenceKeypoint.new(p[1], Color3.fromRGB(p[2], p[3], p[4]))) end return ColorSequence.new(k) end
-- shed rates: the window is ~0.2 s (TrailOn..TrailOff), so ~15-25 particles a swing
local rates = { Plains = 40, Desert = 80, Jungle = 70, Tundra = 90, Swamp = 80, Volcano = 120, Hell = 90, Heaven = 50, Dead = 80, Abyss = 80, Mechanical = 130, Void = 90 }
for z, r in pairs(rates) do A["Zone_" .. z .. "_Shed"].Rate = r end
-- Desert: falling sand puffs instead of the faint vortex rings; finer grains
do
	local e = A.Zone_Desert_Shed
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Size = ns({ { 0, 0.8 }, { 1, 1.8 } })
	e.Transparency = ns({ { 0, 0 }, { 0.5, 0.3 }, { 1, 1 } })
	e.Color = cs({ { 0, 238, 205, 140 }, { 1, 210, 165, 95 } })
	e.LightEmission = 0
	e.LightInfluence = 0.25
	e.Acceleration = Vector3.new(0, -3, 0)
	e.Drag = 2
	e.RotSpeed = NumberRange.new(-120, 120)
	local g = A.Zone_Desert.Center.Grains
	g.Size = ns({ { 0, 0.15 }, { 1, 0.06 } })
	g.LightEmission = 0.3
end
-- Jungle: wider leaves
A.Zone_Jungle_Shed.Squash = NumberSequence.new(0.8)
A.Zone_Jungle.Center.Leaves.Squash = NumberSequence.new(0.8)
-- Tundra: bluer ice shards
do
	local s = A.Zone_Tundra.Center.Shards
	s.Color = cs({ { 0, 210, 240, 255 }, { 1, 120, 195, 255 } })
	s.LightEmission = 0.4
	s.LightInfluence = 0.2
end
-- Swamp: a visible curse trail, purple bubbles, a saturated smoke
do
	local sh = A.Zone_Swamp_Shed
	sh.Transparency = ns({ { 0, 0.15 }, { 1, 1 } })
	sh.LightEmission = 0.5
	local S = A.Zone_Swamp.Center
	S.Bubbles.Color = cs({ { 0, 205, 150, 255 }, { 1, 150, 210, 110 } })
	S.Bubbles.LightEmission = 0.7
	S.Bubbles.Transparency = ns({ { 0, 0 }, { 0.85, 0.05 }, { 1, 1 } })
	S.Smoke.Color = cs({ { 0, 110, 50, 150 }, { 1, 110, 50, 150 } })
	S.Smoke.LightEmission = 0.3
	S.Smoke.Transparency = ns({ { 0, 0.1 }, { 1, 1 } })
end
-- Volcano: orange from the start (yellow-white read as plain sparks)
do
	local ember = cs({ { 0, 255, 175, 60 }, { 0.5, 255, 95, 20 }, { 1, 170, 30, 10 } })
	A.Zone_Volcano_Shed.Color = ember
	A.Zone_Volcano.Center.Lava.Color = ember
	A.Zone_Volcano.Center.Embers.Color = ember
	A.Zone_Volcano.Center.Flame.Transparency = ns({ { 0, 0 }, { 1, 1 } })
end
-- Heaven: bigger, brighter feathers
do
	local f = A.Zone_Heaven_Shed
	f.Size = ns({ { 0, 0.7 }, { 1, 0.55 } })
	f.Transparency = ns({ { 0, 0 }, { 0.75, 0 }, { 1, 1 } })
	f.LightEmission = 0.6
	f.LightInfluence = 0.2
	local b = A.Zone_Heaven.Center.Feathers
	b.Size = ns({ { 0, 0.9 }, { 1, 0.7 } })
	b.Transparency = ns({ { 0, 0 }, { 0.75, 0 }, { 1, 1 } })
	b.LightEmission = 0.6
	b.LightInfluence = 0.2
end
-- Dead: saturated, glowing soul wisps and flames
do
	local soul = cs({ { 0, 130, 255, 215 }, { 1, 40, 185, 165 } })
	local sh = A.Zone_Dead_Shed
	sh.Color = soul
	sh.Size = ns({ { 0, 0.6 }, { 1, 1.4 } })
	sh.Transparency = ns({ { 0, 0.1 }, { 1, 1 } })
	sh.LightEmission = 0.9
	local D = A.Zone_Dead.Center
	D.Souls.Color = soul
	D.Souls.Size = ns({ { 0, 1.5 }, { 1, 0.4 } })
	D.Souls.Transparency = ns({ { 0, 0 }, { 1, 1 } })
	D.Wisps.Color = soul
	D.Wisps.LightEmission = 0.8
	D.Wisps.Transparency = ns({ { 0, 0.15 }, { 1, 1 } })
	D.Motes.Color = soul
end
return "tweaks applied"
