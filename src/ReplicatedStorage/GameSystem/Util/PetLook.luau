--!strict
-- Mutation looks on a pet model clone (Config/PetMutations, docs/pets_v2_plan.md section 3). Client-side only.
--   PetLook.apply(model, mutationId?, opts?) -> Look?      opts = { Static: boolean?, LowFx: boolean? }
--   look.update(now)   -- Rainbow colors cycle (followers call it every frame; icons use Static = no cycling)
-- Textured mesh pieces (the AI pets) get see-through "shells": copies of the mesh without texture, a little
-- larger, parented to their piece with the same CFrame, so PivotTo / ScaleTo / Util/PetMotion move them with it
-- and the eyes and markings still show through. Silver = metal, Golden = foil, Rainbow = cycling colors,
-- Celestial = glowing shell + shimmering force field, stars and a light. Plain parts (the procedural
-- placeholders) are tinted instead. Static (icons, ViewportFrames): no particles, lights or cycling.
local PetMutations = require(script.Parent.Parent.Config.PetMutations)

local PetLook = {}

export type Look = { update: (now: number) -> () }

local CELESTIAL_GLOW = Color3.fromRGB(150, 225, 255)
local CELESTIAL_FIELD = Color3.fromRGB(205, 130, 255)

-- shell (or tint) settings per mutation
local STYLE = {
	Silver = { Material = Enum.Material.Metal, Transparency = 0.35, Reflectance = 0.15, Grow = 1.03, Tint = 0.6 },
	Golden = { Material = Enum.Material.Foil, Transparency = 0.42, Reflectance = 0.1, Grow = 1.03, Tint = 0.65 },
	Rainbow = { Material = Enum.Material.SmoothPlastic, Transparency = 0.4, Reflectance = 0, Grow = 1.03, Tint = 0.6 },
	Celestial = { Material = Enum.Material.Neon, Transparency = 0.55, Reflectance = 0, Grow = 1.03, Tint = 0.55 },
}

local function visiblePieces(model: Model): { BasePart }
	local list = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item ~= model.PrimaryPart and item.Name ~= "Root" and item.Transparency < 0.95
			and not item:GetAttribute("LookShell") then
			table.insert(list, item)
		end
	end
	return list
end

local function shell(piece: MeshPart, grow: number, color: Color3, material: Enum.Material, transparency: number): MeshPart
	local copy = piece:Clone()
	copy:ClearAllChildren()
	copy.Name = "Shell"
	copy.TextureID = ""
	copy.Size = piece.Size * grow
	copy.CFrame = piece.CFrame
	copy.Color = color
	copy.Material = material
	copy.Transparency = transparency
	copy.Reflectance = 0
	copy.CastShadow = false
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Massless = true
	copy:SetAttribute("LookShell", true)
	copy.Parent = piece
	return copy
end

local function luminance(c: Color3): number
	return 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
end

local function sparkles(parent: BasePart, colors: ColorSequence, rate: number, size: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationSparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = colors
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parent
end

-- The main piece (body) for particles / lights: the largest visible one.
local function mainPiece(pieces: { BasePart }): BasePart?
	local best, volume = nil, -1
	for _, piece in ipairs(pieces) do
		local v = piece.Size.X * piece.Size.Y * piece.Size.Z
		if piece.Name == "Body" then
			return piece
		elseif v > volume then
			best, volume = piece, v
		end
	end
	return best
end

function PetLook.apply(model: Model, mutationId: string?, opts: { Static: boolean?, LowFx: boolean? }?): Look?
	local mutation = PetMutations.get(mutationId)
	if not mutation then
		return nil
	end
	local style = STYLE[mutation.Id]
	local static = opts ~= nil and opts.Static == true
	local lowFx = opts ~= nil and opts.LowFx == true
	local pieces = visiblePieces(model)
	local rainbow: { { part: BasePart, offset: number, tint: boolean, base: Color3 } } = {}
	for index, piece in ipairs(pieces) do
		local offset = index * 0.11
		local color = if mutation.Id == "Rainbow" then Color3.fromHSV(offset % 1, 0.75, 1)
			elseif mutation.Id == "Celestial" then CELESTIAL_GLOW else mutation.Color
		if piece:IsA("MeshPart") and piece.TextureID ~= "" then
			local s = shell(piece, style.Grow, color, style.Material, style.Transparency)
			if mutation.Id == "Rainbow" then
				table.insert(rainbow, { part = s, offset = offset, tint = false, base = color })
			elseif mutation.Id == "Celestial" then
				local field = shell(piece, 1.08, CELESTIAL_FIELD, Enum.Material.ForceField, 0)
				field.Name = "Field"
			end
		elseif luminance(piece.Color) > 0.12 or piece.Material == Enum.Material.Neon then
			-- placeholder part: tint it (very dark parts are eyes and mouths: kept)
			piece.Color = piece.Color:Lerp(color, style.Tint)
			if piece.Material ~= Enum.Material.Neon then
				piece.Material = style.Material
				piece.Reflectance = style.Reflectance
			end
			if mutation.Id == "Rainbow" then
				table.insert(rainbow, { part = piece, offset = offset, tint = true, base = piece.Color })
			end
		end
	end
	local main = mainPiece(pieces)
	if main and not static and not lowFx then
		if mutation.Id == "Golden" then
			sparkles(main, ColorSequence.new(Color3.fromRGB(255, 230, 120)), 4, 0.35)
		elseif mutation.Id == "Rainbow" then
			sparkles(main, ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
			}), 7, 0.4)
		elseif mutation.Id == "Celestial" then
			sparkles(main, ColorSequence.new(Color3.fromRGB(200, 240, 255), Color3.fromRGB(220, 160, 255)), 10, 0.45)
			local light = Instance.new("PointLight")
			light.Name = "MutationLight"
			light.Color = CELESTIAL_GLOW
			light.Range = 8
			light.Brightness = 1.2
			light.Parent = main
		end
	end
	if static or #rainbow == 0 then
		return { update = function(_now: number) end }
	end
	return {
		update = function(now: number)
			for _, entry in ipairs(rainbow) do
				local hue = (now * 0.25 + entry.offset) % 1
				entry.part.Color = Color3.fromHSV(hue, if entry.tint then 0.6 else 0.75, 1)
			end
		end,
	}
end

return PetLook
