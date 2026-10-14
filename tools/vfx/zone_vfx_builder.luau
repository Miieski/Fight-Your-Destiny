-- Builds ReplicatedStorage.Assets.VFX.Zone_<Zone> (burst particles) and Zone_<Zone>_Shed (the swing's shed emitter)
-- for the 12 zone fighting styles (VFX sub-agent, 2026-10-14). Run in Studio Edit (execute_luau). Replaces existing ones.
local VFX = game.ReplicatedStorage.Assets.VFX
local T = {
	SQ = "rbxasset://textures/particles/SquareParticle.png",
	SOFT = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	GLOW = "rbxasset://textures/particles/forcefield_glow_main.dds",
	RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	VORTEX = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	FIRE = "rbxasset://textures/particles/fire_main.dds",
	EMBER = "rbxasset://textures/particles/fire_sparks_main.dds",
	SMOKE = "rbxasset://textures/particles/smoke_main.dds",
	SPARKLE = "rbxasset://textures/particles/sparkles_main.dds",
}
local V = Vector3.new
local FC, VP = Enum.ParticleOrientation.FacingCamera, Enum.ParticleOrientation.VelocityParallel

local function cs(c)
	if typeof(c[1]) == "number" and #c == 3 then
		return ColorSequence.new(Color3.fromRGB(c[1], c[2], c[3]))
	end
	local keys = {}
	for _, k in ipairs(c) do
		table.insert(keys, ColorSequenceKeypoint.new(k[1], Color3.fromRGB(k[2], k[3], k[4])))
	end
	return ColorSequence.new(keys)
end
local function ns(v)
	if typeof(v) == "number" then
		return NumberSequence.new(v)
	end
	local keys = {}
	for _, k in ipairs(v) do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	return NumberSequence.new(keys)
end

local function emitter(name, p)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = T[p.Tex]
	e.Color = cs(p.Color)
	e.Size = ns(p.Size)
	e.Transparency = ns(p.Transp or 0)
	e.Lifetime = NumberRange.new(p.Life[1], p.Life[2])
	e.Speed = NumberRange.new(p.Speed[1], p.Speed[2])
	e.SpreadAngle = Vector2.new(p.Spread or 0, p.Spread or 0)
	e.Acceleration = p.Acc or Vector3.zero
	e.Drag = p.Drag or 0
	e.Rotation = NumberRange.new(p.Rot and p.Rot[1] or 0, p.Rot and p.Rot[2] or 0)
	e.RotSpeed = NumberRange.new(p.Spin and p.Spin[1] or 0, p.Spin and p.Spin[2] or 0)
	e.LightEmission = p.LE or 0
	e.LightInfluence = p.LI or 0
	e.Brightness = p.Bright or 1
	e.ZOffset = p.Z or 0
	e.Orientation = p.Orient or FC
	e.Squash = ns(p.Squash or 0)
	e.EmissionDirection = p.Dir or Enum.NormalId.Top
	e.Rate = p.Rate or 0
	e.LockedToPart = false
	e.VelocityInheritance = 0
	e.Enabled = false
	if p.Shape then
		e.Shape = p.Shape
		e.ShapeStyle = p.ShapeStyle or Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = p.ShapeInOut or Enum.ParticleEmitterShapeInOut.Outward
	end
	if p.Count then
		e:SetAttribute("EmitCount", p.Count)
	end
	return e
end

local Z = {}
-- PLAINS (Squire): grass blades and leaves
local LEAFC = { { 0, 120, 195, 70 }, { 1, 150, 205, 85 } }
Z.Plains = {
	Shed = { Tex = "SOFT", Color = LEAFC, Size = { { 0, 0.32 }, { 1, 0.22 } }, Squash = 1.3, Transp = { { 0, 0 }, { 0.7, 0 }, { 1, 1 } },
		Life = { 0.45, 0.7 }, Speed = { 1.5, 3.5 }, Spread = 180, Acc = V(0, -7, 0), Drag = 2, Rot = { 0, 360 }, Spin = { -240, 240 }, LI = 1, Rate = 16, Z = 0.3 },
	Emit = {
		Leaves = { Tex = "SOFT", Color = LEAFC, Size = { { 0, 0.4 }, { 1, 0.28 } }, Squash = 1.3, Transp = { { 0, 0 }, { 0.75, 0 }, { 1, 1 } },
			Life = { 0.5, 0.8 }, Speed = { 7, 13 }, Spread = 60, Acc = V(0, -20, 0), Drag = 2.5, Rot = { 0, 360 }, Spin = { -300, 300 }, LI = 1, Count = 8 },
	},
}
-- DESERT (Dune Dancer): sand swirls, grains, sand clouds
local SANDC = { { 0, 245, 215, 150 }, { 1, 210, 170, 100 } }
Z.Desert = {
	Shed = { Tex = "VORTEX", Color = SANDC, Size = { { 0, 0.8 }, { 1, 1.9 } }, Transp = { { 0, 0.3 }, { 0.6, 0.55 }, { 1, 1 } },
		Life = { 0.35, 0.55 }, Speed = { 0.5, 1.5 }, Spread = 180, Drag = 2, Rot = { 0, 360 }, Spin = { 300, 600 }, LE = 0.25, LI = 0.6, Rate = 32, Z = 0.2 },
	Emit = {
		Grains = { Tex = "SQ", Color = SANDC, Size = { { 0, 0.2 }, { 1, 0.1 } }, Transp = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } },
			Life = { 0.4, 0.65 }, Speed = { 10, 18 }, Spread = 180, Acc = V(0, -30, 0), Drag = 3, Rot = { 0, 360 }, Spin = { -200, 200 }, LE = 0.15, LI = 0.8, Count = 10 },
		Cloud = { Tex = "SMOKE", Color = { 232, 200, 140 }, Size = { { 0, 1.2 }, { 1, 3.4 } }, Transp = { { 0, 0.3 }, { 0.5, 0.5 }, { 1, 1 } },
			Life = { 0.45, 0.7 }, Speed = { 6, 10 }, Spread = 180, Drag = 5, Rot = { 0, 360 }, Spin = { -90, 90 }, LI = 0.7, Count = 3 },
		Swirl = { Tex = "VORTEX", Color = SANDC, Size = { { 0, 1.6 }, { 1, 4.2 } }, Transp = { { 0, 0.25 }, { 1, 1 } },
			Life = { 0.35, 0.5 }, Speed = { 0, 0 }, Rot = { 0, 360 }, Spin = { 400, 700 }, LE = 0.3, LI = 0.5, Z = 0.5, Count = 1 },
	},
}
-- JUNGLE (Feral): leaves, toxic droplets, a toxic splat
local JLEAF = { { 0, 70, 165, 50 }, { 1, 130, 210, 60 } }
local TOXC = { { 0, 200, 255, 90 }, { 1, 140, 220, 40 } }
Z.Jungle = {
	Shed = { Tex = "SOFT", Color = JLEAF, Size = { { 0, 0.42 }, { 1, 0.3 } }, Squash = 1.4, Transp = { { 0, 0 }, { 0.7, 0 }, { 1, 1 } },
		Life = { 0.5, 0.8 }, Speed = { 2, 4 }, Spread = 180, Acc = V(0, -6, 0), Drag = 3, Rot = { 0, 360 }, Spin = { -220, 220 }, LE = 0.05, LI = 0.9, Rate = 30, Z = 0.3 },
	Emit = {
		Leaves = { Tex = "SOFT", Color = JLEAF, Size = { { 0, 0.5 }, { 1, 0.35 } }, Squash = 1.4, Transp = { { 0, 0 }, { 0.75, 0 }, { 1, 1 } },
			Life = { 0.55, 0.85 }, Speed = { 8, 15 }, Spread = 75, Acc = V(0, -18, 0), Drag = 2.5, Rot = { 0, 360 }, Spin = { -300, 300 }, LE = 0.05, LI = 0.9, Count = 8 },
		Drops = { Tex = "SOFT", Color = TOXC, Size = { { 0, 0.22 }, { 1, 0.14 } }, Squash = 1.6, Orient = VP, Transp = { { 0, 0 }, { 0.8, 0 }, { 1, 1 } },
			Life = { 0.35, 0.55 }, Speed = { 10, 18 }, Spread = 75, Acc = V(0, -45, 0), Drag = 1, LE = 0.6, LI = 0.2, Count = 8 },
		Splat = { Tex = "SMOKE", Color = TOXC, Size = { { 0, 1 }, { 1, 2.6 } }, Transp = { { 0, 0.4 }, { 1, 1 } },
			Life = { 0.35, 0.5 }, Speed = { 2, 4 }, Spread = 180, Drag = 4, Rot = { 0, 360 }, LE = 0.35, LI = 0.3, Count = 1 },
	},
}
-- TUNDRA (Glacier): frost glitter, ice shards, crystals, frost mist
local ICEC = { { 0, 235, 250, 255 }, { 1, 150, 215, 255 } }
Z.Tundra = {
	Shed = { Tex = "SPARKLE", Color = ICEC, Size = { { 0, 0.55 }, { 1, 0 } }, Transp = { { 0, 0 }, { 1, 0.2 } },
		Life = { 0.35, 0.6 }, Speed = { 0.5, 2 }, Spread = 180, Acc = V(0, -2, 0), Drag = 2, Rot = { 0, 360 }, LE = 0.8, Rate = 42, Z = 0.3 },
	Emit = {
		Shards = { Tex = "SQ", Color = ICEC, Size = { { 0, 0.3 }, { 1, 0.1 } }, Squash = 2.4, Orient = VP, Transp = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
			Life = { 0.25, 0.4 }, Speed = { 18, 30 }, Spread = 180, Drag = 6, LE = 0.5, LI = 0.3, Z = 0.8, Count = 10 },
		Crystals = { Tex = "SPARKLE", Color = ICEC, Size = { { 0, 1.3 }, { 1, 0 } }, Life = { 0.3, 0.5 }, Speed = { 2, 5 }, Spread = 180, Drag = 3,
			Rot = { 0, 360 }, Spin = { -60, 60 }, LE = 1, Z = 1, Count = 3 },
		Mist = { Tex = "SMOKE", Color = { 215, 240, 255 }, Size = { { 0, 1.5 }, { 1, 3.6 } }, Transp = { { 0, 0.4 }, { 1, 1 } },
			Life = { 0.5, 0.8 }, Speed = { 2, 4 }, Spread = 180, Drag = 2, Rot = { 0, 360 }, Spin = { -40, 40 }, LE = 0.2, LI = 0.6, Count = 2 },
	},
}
-- SWAMP (Hexblade): curse smoke, purple wisps, bubbles
local CURSEC = { { 0, 150, 80, 210 }, { 1, 70, 35, 100 } }
Z.Swamp = {
	Shed = { Tex = "SMOKE", Color = CURSEC, Size = { { 0, 0.6 }, { 1, 1.5 } }, Transp = { { 0, 0.3 }, { 1, 1 } },
		Life = { 0.45, 0.7 }, Speed = { 0.5, 1.5 }, Spread = 180, Acc = V(0, 2.5, 0), Rot = { 0, 360 }, Spin = { -120, 120 }, LE = 0.35, LI = 0.3, Rate = 34, Z = 0.2 },
	Emit = {
		Bubbles = { Tex = "RING", Color = { { 0, 185, 230, 120 }, { 1, 170, 110, 220 } }, Size = { { 0, 0.25 }, { 0.85, 0.6 }, { 1, 0.75 } },
			Transp = { { 0, 0.1 }, { 0.85, 0.15 }, { 1, 1 } }, Life = { 0.4, 0.8 }, Speed = { 2, 6 }, Spread = 180, Acc = V(0, 5, 0), Drag = 3, LE = 0.5, Z = 0.8, Count = 6 },
		Smoke = { Tex = "SMOKE", Color = { 70, 35, 95 }, Size = { { 0, 1.2 }, { 1, 3.2 } }, Transp = { { 0, 0.25 }, { 1, 1 } },
			Life = { 0.5, 0.75 }, Speed = { 4, 8 }, Spread = 180, Drag = 5, Rot = { 0, 360 }, Spin = { -60, 60 }, LE = 0.1, LI = 0.5, Count = 2 },
		Wisps = { Tex = "SOFT", Color = { 190, 120, 255 }, Size = { { 0, 0.5 }, { 1, 0 } }, Squash = 0.8, Life = { 0.4, 0.7 }, Speed = { 3, 7 }, Spread = 120,
			Acc = V(0, 6, 0), Drag = 2, LE = 0.8, Z = 0.6, Count = 5 },
	},
}
-- VOLCANO (Berserker): embers, lava sparks, flames, dark smoke
local EMBERC = { { 0, 255, 210, 90 }, { 0.5, 255, 120, 30 }, { 1, 200, 40, 10 } }
Z.Volcano = {
	Shed = { Tex = "SQ", Color = EMBERC, Size = { { 0, 0.18 }, { 1, 0 } }, Life = { 0.35, 0.7 }, Speed = { 2, 5 }, Spread = 180, Acc = V(0, 5, 0), Drag = 2,
		Rot = { 0, 360 }, Spin = { -200, 200 }, LE = 1, Rate = 60, Z = 0.4 },
	Emit = {
		Lava = { Tex = "SQ", Color = EMBERC, Size = { { 0, 0.26 }, { 1, 0.1 } }, Squash = 1.6, Orient = VP, Life = { 0.4, 0.6 }, Speed = { 16, 28 }, Spread = 80,
			Acc = V(0, -45, 0), Drag = 1.5, LE = 1, Z = 0.8, Count = 8 },
		Embers = { Tex = "SQ", Color = EMBERC, Size = { { 0, 0.2 }, { 1, 0 } }, Life = { 0.6, 1.0 }, Speed = { 3, 8 }, Spread = 180, Acc = V(0, 8, 0), Drag = 2,
			Rot = { 0, 360 }, Spin = { -200, 200 }, LE = 1, Z = 0.6, Count = 6 },
		Flame = { Tex = "FIRE", Color = { { 0, 255, 190, 90 }, { 1, 255, 70, 15 } }, Size = { { 0, 1.6 }, { 1, 3 } }, Transp = { { 0, 0.15 }, { 1, 1 } },
			Life = { 0.2, 0.35 }, Speed = { 2, 5 }, Spread = 180, Acc = V(0, 6, 0), Rot = { 0, 360 }, LE = 0.9, Z = 0.5, Count = 1 },
		Smoke = { Tex = "SMOKE", Color = { 48, 38, 34 }, Size = { { 0, 1.5 }, { 1, 3.6 } }, Transp = { { 0, 0.35 }, { 1, 1 } },
			Life = { 0.6, 0.9 }, Speed = { 3, 6 }, Spread = 180, Acc = V(0, 4, 0), Drag = 3, Rot = { 0, 360 }, Spin = { -40, 40 }, LI = 0.5, Count = 2 },
	},
}
-- HELL (Demon): hellfire, black smoke, red sparks
local HELLC = { { 0, 255, 120, 50 }, { 0.5, 230, 30, 10 }, { 1, 90, 0, 0 } }
Z.Hell = {
	Shed = { Tex = "FIRE", Color = HELLC, Size = { { 0, 0.9 }, { 1, 0.3 } }, Transp = { { 0, 0.15 }, { 1, 1 } }, Life = { 0.2, 0.35 }, Speed = { 1, 3 },
		Spread = 180, Acc = V(0, 8, 0), Rot = { 0, 360 }, LE = 0.9, Rate = 46, Z = 0.3 },
	Emit = {
		Flames = { Tex = "FIRE", Color = HELLC, Size = { { 0, 1.4 }, { 1, 2.8 } }, Transp = { { 0, 0.1 }, { 1, 1 } }, Life = { 0.25, 0.4 }, Speed = { 4, 9 },
			Spread = 180, Acc = V(0, 10, 0), Rot = { 0, 360 }, LE = 0.9, Z = 0.5, Count = 3 },
		Smoke = { Tex = "SMOKE", Color = { 24, 10, 10 }, Size = { { 0, 1.5 }, { 1, 3.5 } }, Transp = { { 0, 0.2 }, { 1, 1 } }, Life = { 0.5, 0.8 },
			Speed = { 4, 8 }, Spread = 180, Acc = V(0, 3, 0), Drag = 4, Rot = { 0, 360 }, Spin = { -50, 50 }, LI = 0.2, Count = 2 },
		Sparks = { Tex = "SQ", Color = HELLC, Size = { { 0, 0.22 }, { 1, 0 } }, Squash = 2, Orient = VP, Life = { 0.2, 0.35 }, Speed = { 18, 28 }, Spread = 180,
			Drag = 5, LE = 1, Z = 0.8, Count = 6 },
	},
}
-- HEAVEN (Seraph): feathers, golden rays, a soft glow
local GOLDC = { { 0, 255, 245, 200 }, { 1, 255, 210, 100 } }
local FEATHERC = { { 0, 255, 255, 250 }, { 1, 255, 238, 190 } }
Z.Heaven = {
	Shed = { Tex = "SOFT", Color = FEATHERC, Size = { { 0, 0.5 }, { 1, 0.4 } }, Squash = 1.7, Transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } },
		Life = { 0.7, 1.1 }, Speed = { 1, 2.5 }, Spread = 180, Acc = V(0, -1.5, 0), Drag = 2.5, Rot = { 0, 360 }, Spin = { -90, 90 }, LE = 0.4, LI = 0.3, Rate = 20, Z = 0.3 },
	Emit = {
		Rays = { Tex = "SQ", Color = GOLDC, Size = { { 0, 0.24 }, { 1, 0.06 } }, Squash = 2.8, Orient = VP, Life = { 0.2, 0.32 }, Speed = { 12, 22 }, Spread = 180,
			Drag = 6, LE = 1, Z = 1, Count = 8 },
		Feathers = { Tex = "SOFT", Color = FEATHERC, Size = { { 0, 0.6 }, { 1, 0.45 } }, Squash = 1.7, Transp = { { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } },
			Life = { 0.8, 1.2 }, Speed = { 5, 10 }, Spread = 180, Acc = V(0, -3, 0), Drag = 4, Rot = { 0, 360 }, Spin = { -120, 120 }, LE = 0.4, LI = 0.3, Count = 6 },
		Glow = { Tex = "GLOW", Color = { 255, 230, 150 }, Size = { { 0, 3 }, { 1, 5 } }, Transp = { { 0, 0.3 }, { 1, 1 } }, Life = { 0.2, 0.25 }, Speed = { 0, 0 },
			LE = 1, Z = 1.2, Count = 1 },
	},
}
-- DEAD (Revenant): ghost wisps, soul flames, soul motes (green-cyan)
local SOULC = { { 0, 175, 255, 225 }, { 1, 70, 200, 180 } }
Z.Dead = {
	Shed = { Tex = "SMOKE", Color = SOULC, Size = { { 0, 0.5 }, { 1, 1.3 } }, Transp = { { 0, 0.35 }, { 1, 1 } }, Life = { 0.5, 0.8 }, Speed = { 0.5, 1.5 },
		Spread = 180, Acc = V(0, 3, 0), Rot = { 0, 360 }, Spin = { -90, 90 }, LE = 0.7, Rate = 34, Z = 0.2 },
	Emit = {
		Souls = { Tex = "FIRE", Color = SOULC, Size = { { 0, 1.1 }, { 1, 0.3 } }, Transp = { { 0, 0.1 }, { 1, 1 } }, Life = { 0.35, 0.6 }, Speed = { 3, 7 },
			Spread = 60, Acc = V(0, 8, 0), Rot = { -20, 20 }, LE = 1, Z = 0.6, Count = 2 },
		Wisps = { Tex = "SMOKE", Color = SOULC, Size = { { 0, 1.2 }, { 1, 2.8 } }, Transp = { { 0, 0.3 }, { 1, 1 } }, Life = { 0.4, 0.7 }, Speed = { 4, 8 },
			Spread = 180, Drag = 4, Rot = { 0, 360 }, Spin = { -90, 90 }, LE = 0.6, Count = 2 },
		Motes = { Tex = "SPARKLE", Color = SOULC, Size = { { 0, 0.7 }, { 1, 0 } }, Life = { 0.4, 0.7 }, Speed = { 4, 10 }, Spread = 180, Drag = 3,
			Acc = V(0, 3, 0), Rot = { 0, 360 }, LE = 1, Z = 0.8, Count = 5 },
	},
}
-- ABYSS (Tidecaller): bubbles, water droplets, spray
local WATERC = { { 0, 215, 240, 255 }, { 1, 90, 175, 255 } }
Z.Abyss = {
	Shed = { Tex = "RING", Color = WATERC, Size = { { 0, 0.22 }, { 0.85, 0.42 }, { 1, 0.5 } }, Transp = { { 0, 0.1 }, { 0.85, 0.15 }, { 1, 1 } },
		Life = { 0.5, 0.9 }, Speed = { 0.5, 2 }, Spread = 180, Acc = V(0, 3, 0), Drag = 1.5, LE = 0.4, Rate = 34, Z = 0.3 },
	Emit = {
		Splash = { Tex = "SOFT", Color = WATERC, Size = { { 0, 0.26 }, { 1, 0.14 } }, Squash = 1.8, Orient = VP, Transp = { { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } },
			Life = { 0.35, 0.55 }, Speed = { 14, 24 }, Spread = 70, Acc = V(0, -55, 0), Drag = 1, LE = 0.4, LI = 0.4, Z = 0.6, Count = 10 },
		Bubbles = { Tex = "RING", Color = WATERC, Size = { { 0, 0.25 }, { 0.85, 0.6 }, { 1, 0.75 } }, Transp = { { 0, 0.1 }, { 0.85, 0.15 }, { 1, 1 } },
			Life = { 0.4, 0.8 }, Speed = { 2, 6 }, Spread = 180, Acc = V(0, 5, 0), Drag = 3, LE = 0.45, Z = 0.8, Count = 5 },
		Spray = { Tex = "SMOKE", Color = { 205, 235, 255 }, Size = { { 0, 1.2 }, { 1, 3 } }, Transp = { { 0, 0.35 }, { 1, 1 } }, Life = { 0.35, 0.55 },
			Speed = { 6, 10 }, Spread = 180, Drag = 5, Rot = { 0, 360 }, LE = 0.25, LI = 0.5, Count = 2 },
	},
}
-- MECHANICAL (Automaton): electric sparks, a cold flash
local VOLTC = { { 0, 255, 255, 220 }, { 0.5, 255, 235, 110 }, { 1, 120, 200, 255 } }
Z.Mechanical = {
	Shed = { Tex = "SQ", Color = VOLTC, Size = { { 0, 0.15 }, { 1, 0 } }, Squash = 2, Orient = VP, Life = { 0.12, 0.25 }, Speed = { 6, 14 }, Spread = 180,
		Acc = V(0, -25, 0), Drag = 5, LE = 1, Rate = 60, Z = 0.5 },
	Emit = {
		Sparks = { Tex = "SQ", Color = VOLTC, Size = { { 0, 0.2 }, { 1, 0 } }, Squash = 2.4, Orient = VP, Life = { 0.15, 0.3 }, Speed = { 16, 30 }, Spread = 180,
			Acc = V(0, -30, 0), Drag = 5, LE = 1, Z = 0.8, Count = 12 },
		Flash = { Tex = "GLOW", Color = { 200, 235, 255 }, Size = { { 0, 2.2 }, { 1, 3.2 } }, Transp = { { 0, 0.15 }, { 1, 1 } }, Life = { 0.08, 0.1 },
			Speed = { 0, 0 }, LE = 1, Z = 1.2, Count = 1 },
	},
}
-- VOID (Voidwalker): stars, a dark swirl, motes converging (Implode: on the Part, a sphere shell moving inward)
local VOIDC = { { 0, 240, 225, 255 }, { 1, 150, 80, 255 } }
Z.Void = {
	PartSize = 4.4,
	Shed = { Tex = "SPARKLE", Color = VOIDC, Size = { { 0, 0.55 }, { 1, 0 } }, Life = { 0.4, 0.7 }, Speed = { 0.3, 1.5 }, Spread = 180, Drag = 2,
		Rot = { 0, 360 }, Spin = { -90, 90 }, LE = 1, Rate = 36, Z = 0.3 },
	Emit = {
		Stars = { Tex = "SPARKLE", Color = VOIDC, Size = { { 0, 0.8 }, { 1, 0 } }, Life = { 0.35, 0.6 }, Speed = { 4, 10 }, Spread = 180, Drag = 3,
			Rot = { 0, 360 }, Spin = { -90, 90 }, LE = 1, Z = 0.8, Count = 6 },
		Distort = { Tex = "VORTEX", Color = { { 0, 45, 12, 80 }, { 1, 150, 80, 255 } }, Size = { { 0, 3.2 }, { 1, 0.6 } }, Transp = { { 0, 0.15 }, { 1, 1 } },
			Life = { 0.35, 0.45 }, Speed = { 0, 0 }, Rot = { 0, 360 }, Spin = { 500, 800 }, LE = 0.2, Z = 0.5, Count = 1 },
	},
	OnPart = {
		Implode = { Tex = "SPARKLE", Color = VOIDC, Size = { { 0, 0.5 }, { 1, 0.1 } }, Life = { 0.28, 0.32 }, Speed = { 7, 8 }, LE = 1, Z = 0.8,
			Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward, Count = 6 },
	},
}

local made = {}
for zone, def in pairs(Z) do
	for _, name in ipairs({ "Zone_" .. zone, "Zone_" .. zone .. "_Shed" }) do
		local old = VFX:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local part = Instance.new("Part")
	part.Name = "Zone_" .. zone
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Material = Enum.Material.SmoothPlastic
	local s = def.PartSize or 0.2
	part.Size = Vector3.new(s, s, s)
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = part
	local names = {}
	for name in pairs(def.Emit) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		emitter(name, def.Emit[name]).Parent = center
	end
	for name, p in pairs(def.OnPart or {}) do
		emitter(name, p).Parent = part
	end
	part:SetAttribute("ZoneStyle", zone)
	part.Parent = VFX
	local shed = emitter("Zone_" .. zone .. "_Shed", def.Shed)
	shed:SetAttribute("ZoneStyle", zone)
	shed.Parent = VFX
	table.insert(made, part.Name)
end
table.sort(made)
return table.concat(made, ", ")
