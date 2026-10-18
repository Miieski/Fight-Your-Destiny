--!strict
-- The pet's light inside the egg on the hatch screen (owner 2026-10-18: "make a emission of light during the animation
-- in the egg according to the rarity of the pet inside", then "For the light behind the egg put it progressly during
-- the haching and relesing process, and make it more realistic").
-- Build-up: almost no light while the egg drops in; it grows smoothly with the wobble and the cracks (the crack bursts
-- are smoothed, a gentle heartbeat on top) and is brightest at the break. Its colour comes in gradually too: a faint
-- warm white light that saturates into the pet's rarity colour (hinted half way, clear at the end; Divine: a white and
-- gold shimmer, Secret: a rainbow). Release: at the break the light bursts out of the opening (a hot flash, wider glow,
-- flaring beams, sparks), then over about a second it settles into a calm glow behind the revealed pet, which stays
-- while the result is shown (several pets: it fades away instead).
-- Strength follows the rarity (TUNE): Common a soft glow, rarer pets brighter and wider, with beams that stay from Epic,
-- sparks from Epic and a flicker from Legendary.
-- Realistic light, no flat shapes: soft radial-falloff textures (white, the light in the alpha, tinted with
-- ImageColor3, layered for an additive look): a coloured aura and a hot near-white core behind the egg, soft god-ray
-- beams (two layers turning both ways), an egg-shaped rim light that follows the egg's tilt, a bloom over the egg near
-- the end, hot sparks. The egg's own viewport lighting is tinted and the cracks shine (UI/EggCrack shell:glow).
-- Textures: Previews/EggLight/make_egg_light_textures.py. Only a few ImageLabels (6 + at most 16 sparks).
-- Low FX: one soft glow, the crack glow and the viewport tint (no beams, rim, bloom or sparks).
--   EggLight.new(opts) -> Light   opts = { Holder: GuiObject (the stage: the egg's view sits in it, or in a frame that
--       fills it), View: ViewportFrame (the egg), Tier: number (the pet's rarity), Low: boolean? }
--       The glows behind the egg live in a frame next to the holder (same place), so they stay when the holder hides.
--   light:update(u, spread, dt, shell?)  every frame: u = wobble progress 0..1, spread = how far the cracks reached
--       0..1, shell = the UI/EggCrack shell once it exists
--   light:burst()          the break: the light bursts out (call before the egg's view grows)
--   light:reveal(keep)     the pet is shown: settle into the calm glow (keep) or fade away (several pets); bursts first
--                          when the egg did not break (skip, flat cracks)
--   light:destroy()
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)

local EggLight = {}
EggLight.__index = EggLight

-- white textures, the light in the alpha (Previews/EggLight/make_egg_light_textures.py)
local TEX = {
	Glow = "rbxassetid://86712078359989", -- radial glow with a long soft tail
	Beams = "rbxassetid://81406311014840", -- god rays from the middle
	Rim = "rbxassetid://138321255850643", -- egg-shaped glow: full inside the egg outline, soft outside
	Spark = "rbxassetid://110237868246803", -- a hot spark with a soft halo
}
local RIM_EGG = 0.66 -- the egg outline in rim.png, of the image's half-size

-- per rarity: s = strength (0..1), aura = the glow's size at full strength (of the egg's height), bloom = the glow over
-- the egg near the end (opacity), flicker = shimmer near the end, sparks = sparks per second at the end, crack = how far
-- the cracks go toward the light, beams = the beams' opacity once settled behind the pet (0 = they fade away)
type Tune = { s: number, aura: number, bloom: number, flicker: number, sparks: number, crack: number, beams: number }
local TUNE: { Tune } = {
	{ s = 0.38, aura = 2.0, bloom = 0.16, flicker = 0, sparks = 0, crack = 0.8, beams = 0 }, -- Common
	{ s = 0.46, aura = 2.15, bloom = 0.2, flicker = 0, sparks = 0, crack = 0.88, beams = 0 }, -- Uncommon
	{ s = 0.55, aura = 2.3, bloom = 0.24, flicker = 0, sparks = 0, crack = 0.94, beams = 0 }, -- Rare
	{ s = 0.66, aura = 2.5, bloom = 0.3, flicker = 0.06, sparks = 4, crack = 1, beams = 0.22 }, -- Epic
	{ s = 0.8, aura = 2.75, bloom = 0.38, flicker = 0.2, sparks = 8, crack = 1, beams = 0.3 }, -- Legendary
	{ s = 0.88, aura = 2.9, bloom = 0.42, flicker = 0.24, sparks = 10, crack = 1, beams = 0.34 }, -- Mythic
	{ s = 0.95, aura = 3.0, bloom = 0.46, flicker = 0.27, sparks = 12, crack = 1, beams = 0.38 }, -- Divine
	{ s = 1, aura = 3.2, bloom = 0.52, flicker = 0.3, sparks = 16, crack = 1, beams = 0.42 }, -- Secret
}
local DIVINE, SECRET = 7, 8
local WHITE = Color3.new(1, 1, 1)
local WARM = Color3.fromRGB(255, 236, 205) -- the light before it takes the pet's colour
local GOLD = Color3.fromRGB(255, 200, 60)
-- the beams' colours for the animated rarities (Divine: white and gold only)
local BEAM_COLORS: { [number]: ColorSequence } = {
	[DIVINE] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.25, GOLD),
		ColorSequenceKeypoint.new(0.5, WHITE),
		ColorSequenceKeypoint.new(0.75, GOLD),
		ColorSequenceKeypoint.new(1, WHITE),
	}),
}
local MAX_SPARKS = 16
local SETTLE = 1.0 -- seconds: from the burst to the calm glow
local SETTLE_FROM = 0.15 -- seconds after the burst

type Spark = { image: ImageLabel, x: number, y: number, vx: number, vy: number, age: number, life: number, size: number }
-- the numbers that make a frame of the light (sizes: of the holder's height)
type Look = {
	auraSize: number,
	auraOp: number,
	coreSize: number,
	coreOp: number,
	beamSize: number,
	beamOp: number,
	rimOp: number,
	bloomSize: number,
	bloomOp: number,
	x: number,
	y: number,
}

export type Light = typeof(setmetatable({} :: {
	_holder: GuiObject,
	_view: ViewportFrame,
	_egg: BasePart?,
	_tier: number,
	_tune: Tune,
	_low: boolean,
	_ambient: Color3,
	_lightColor: Color3,
	_back: Frame,
	_front: Frame?,
	_aura: ImageLabel,
	_core: ImageLabel?,
	_beams: { ImageLabel },
	_gradients: { UIGradient },
	_rim: ImageLabel?,
	_bloom: ImageLabel?,
	_sparks: { Spark },
	_rng: Random,
	_t: number,
	_beat: number,
	_hue: number,
	_spawn: number,
	_spread: number, -- the cracks' spread, smoothed (no jumps)
	_level: number,
	_sat: number, -- 0 = warm white .. 1 = the rarity colour
	_spot: { number }, -- the egg on the stage: middle x, y (holder scale), height, width (of the holder's height), tilt
	_shell: any,
	_snap: Look?, -- the light at the burst
	_burstAt: number, -- seconds since the burst, -1 = not yet
	_keep: boolean,
	_conn: RBXScriptConnection?,
	_dead: boolean,
}, EggLight))

local function bump(x: number, center: number, width: number): number
	local d = (x - center) / width
	return math.exp(-d * d)
end

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function layer(parent: Instance, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z
	frame.Active = false
	frame.Parent = parent
	return frame
end

-- a light texture, sized on its parent's height
local function image(parent: GuiObject, texture: string, z: number): ImageLabel
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = texture
	img.ImageTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.SizeConstraint = Enum.SizeConstraint.RelativeYY
	img.ZIndex = z
	img.Active = false
	img.Parent = parent
	return img
end

function EggLight.new(opts: { [string]: any }): Light
	local holder = opts.Holder :: GuiObject
	local view = opts.View :: ViewportFrame
	local tier = math.clamp(math.floor(tonumber(opts.Tier) or 1), 1, #TUNE)
	local low = opts.Low == true
	local model = view:FindFirstChildOfClass("Model")
	local found = model and model:FindFirstChild("Egg", true)
	local egg = if found and found:IsA("BasePart") then found else nil
	-- behind the egg: a frame on the holder's spot, next to it (below it), so it stays when the holder hides
	local parent = holder.Parent
	local back = layer(if parent then parent else holder, "EggLight", if parent then holder.ZIndex - 1 else 1)
	back.AnchorPoint = holder.AnchorPoint
	back.Size = holder.Size
	back.Position = if parent then holder.Position else UDim2.fromScale(0, 0)
	if not parent then
		back.Size = UDim2.fromScale(1, 1)
	end
	local self: Light = setmetatable({
		_holder = holder,
		_view = view,
		_egg = egg,
		_tier = tier,
		_tune = TUNE[tier],
		_low = low,
		_ambient = view.Ambient,
		_lightColor = view.LightColor,
		_back = back,
		_front = nil,
		_aura = image(back, TEX.Glow, 1),
		_core = nil,
		_beams = {},
		_gradients = {},
		_rim = nil,
		_bloom = nil,
		_sparks = {},
		_rng = Random.new(),
		_t = 0,
		_beat = 0,
		_hue = 0,
		_spawn = 0,
		_spread = 0,
		_level = 0,
		_sat = 0,
		_spot = { 0.5, 0.5, 0.6, 0.47, 0 },
		_shell = nil,
		_snap = nil,
		_burstAt = -1,
		_keep = true,
		_conn = nil,
		_dead = false,
	}, EggLight)
	if not low then
		for i = 1, 2 do
			local beams = image(back, TEX.Beams, 2)
			beams.Rotation = if i == 1 then 0 else 16
			if tier == SECRET or tier == DIVINE then
				-- the beams take every colour of the rarity's gradient (rebuilt as the colour comes in)
				local gradient = Instance.new("UIGradient")
				gradient.Rotation = if i == 1 then 0 else 120
				gradient.Parent = beams
				table.insert(self._gradients, gradient)
			end
			table.insert(self._beams, beams)
		end
		self._core = image(back, TEX.Glow, 3)
		if egg then
			self._rim = image(back, TEX.Rim, 4)
		end
		-- over the egg: the bloom and the sparks
		local front = layer(holder, "EggLightFront", 6)
		self._front = front
		self._bloom = image(front, TEX.Glow, 5)
	end
	return self
end

-- The rarity's colour; `offset` shifts it for the rainbow / shimmer (0 = the main colour).
function EggLight._rarityColor(self: Light, offset: number): Color3
	if self._tier == SECRET then
		return Color3.fromHSV((self._hue + offset) % 1, 0.62, 1)
	elseif self._tier == DIVINE then
		return WHITE:Lerp(GOLD, 0.15 + 0.6 * (0.5 + 0.5 * math.sin(self._t * 5 + offset * 9)))
	end
	return Rarities.get(self._tier).Color
end

-- The light's colour now: warm white, saturating into the rarity colour.
function EggLight._color(self: Light, offset: number): Color3
	return WARM:Lerp(self:_rarityColor(offset), self._sat)
end

-- Where the egg is on the stage (it drops in, rocks around its base and squashes) and how big it looks.
function EggLight._follow(self: Light)
	local holder = self._holder
	if self._back.Parent ~= holder then
		self._back.Position = holder.Position -- the stage trembles
	end
	local view, egg = self._view, self._egg
	local camera = view.CurrentCamera
	if not egg or not camera or not view.Parent then
		return
	end
	local p = camera.CFrame:PointToObjectSpace(egg.Position)
	local depth = -p.Z
	if depth < 1e-3 then
		return
	end
	local squash = view:FindFirstChildOfClass("UIScale")
	local k = if squash then squash.Scale else 1
	local tanHalf = math.tan(math.rad(camera.FieldOfView / 2))
	local abs = view.AbsoluteSize
	local aspect = if abs.Y > 0 and abs.X > 0 then abs.X / abs.Y else 1
	local w, h = view.Size.X.Scale * k, view.Size.Y.Scale * k
	local anchor = view.AnchorPoint
	local cx = view.Position.X.Scale + (0.5 - anchor.X) * w
	local cy = view.Position.Y.Scale + (0.5 - anchor.Y) * h
	local up = camera.CFrame:VectorToObjectSpace(egg.CFrame.UpVector)
	local spot = self._spot
	spot[1] = cx + p.X / (depth * tanHalf * aspect) * 0.5 * w
	spot[2] = cy - p.Y / (depth * tanHalf) * 0.5 * h
	spot[3] = egg.Size.Y / (depth * tanHalf) * 0.5 * h
	spot[4] = egg.Size.X / (depth * tanHalf) * 0.5 * h
	spot[5] = math.deg(math.atan2(up.X, up.Y))
end

-- The light while the egg is whole, at `level` (0..1+, before the rarity's strength).
function EggLight._building(self: Light, level: number, u: number): Look
	local tune = self._tune
	local strength = tune.s * level
	local eggH = self._spot[3]
	return {
		auraSize = eggH * (1.1 + (tune.aura - 1.1) * math.min(level, 1.2)),
		auraOp = math.clamp(0.95 * strength, 0, 0.92),
		coreSize = eggH * (1.05 + 0.6 * level),
		coreOp = math.clamp(1.15 * strength * level, 0, 0.95),
		beamSize = eggH * (2.3 + 1.3 * level),
		beamOp = math.clamp(0.8 * strength * smoothstep(0.12, 0.5, u), 0, 0.85),
		rimOp = math.clamp(1.2 * strength, 0, 0.95),
		bloomSize = eggH * (1.0 + 0.35 * level),
		bloomOp = math.clamp(tune.bloom * level ^ 2.5 * 1.3, 0, 0.75),
		x = self._spot[1],
		y = self._spot[2],
	}
end

-- The calm glow behind the shown pet (sizes of the holder; several pets: nothing, it fades away).
function EggLight._calm(self: Light): Look
	local tune = self._tune
	local keep = if self._keep then 1 else 0
	return {
		auraSize = 1.6,
		auraOp = (0.27 + 0.42 * tune.s) * keep,
		coreSize = 0.8,
		coreOp = (0.15 + 0.3 * tune.s) * keep,
		beamSize = 1.75,
		beamOp = tune.beams * keep,
		rimOp = 0,
		bloomSize = 1,
		bloomOp = 0,
		x = 0.5,
		y = 0.5,
	}
end

-- Puts a frame of the light on the layers.
function EggLight._paint(self: Light, look: Look, beamTurn: number, beat: number)
	local color = self:_color(0)
	local aura = self._aura
	aura.Position = UDim2.fromScale(look.x, look.y)
	aura.Size = UDim2.fromScale(look.auraSize, look.auraSize)
	aura.ImageColor3 = color
	aura.ImageTransparency = 1 - math.clamp(look.auraOp, 0, 1)
	local core = self._core
	if core then
		core.Position = aura.Position
		core.Size = UDim2.fromScale(look.coreSize, look.coreSize)
		core.ImageColor3 = self:_color(0.08):Lerp(WHITE, 0.6) -- the hot middle of the light
		core.ImageTransparency = 1 - math.clamp(look.coreOp, 0, 1)
	end
	for i, beams in ipairs(self._beams) do
		beams.Position = aura.Position
		local size = look.beamSize * (if i == 1 then 1 else 0.82)
		beams.Size = UDim2.fromScale(size, size)
		beams.Rotation += beamTurn * (if i == 1 then 1 else -0.7)
		beams.ImageColor3 = if #self._gradients > 0 then WHITE else color:Lerp(WHITE, 0.15)
		beams.ImageTransparency = 1 - math.clamp(look.beamOp * (if i == 1 then 1 else 0.75), 0, 1)
	end
	if #self._gradients > 0 then
		local source = BEAM_COLORS[self._tier] or Rarities.get(self._tier).Gradient
		if source then
			local points = {}
			for _, key in ipairs(source.Keypoints) do
				table.insert(points, ColorSequenceKeypoint.new(key.Time, WARM:Lerp(key.Value, self._sat)))
			end
			local sequence = ColorSequence.new(points)
			for i, gradient in ipairs(self._gradients) do
				gradient.Color = sequence
				gradient.Rotation = (self._t * (if i == 1 then 40 else -28)) % 360
			end
		end
	end
	local rim = self._rim
	if rim then
		local spot = self._spot
		rim.Position = UDim2.fromScale(spot[1], spot[2])
		local grow = 1 + 0.025 * beat
		rim.Size = UDim2.fromScale(spot[4] / RIM_EGG * grow, spot[3] / RIM_EGG * grow)
		rim.Rotation = spot[5]
		rim.ImageColor3 = self:_color(0.16):Lerp(WHITE, 0.3)
		rim.ImageTransparency = 1 - math.clamp(look.rimOp, 0, 1)
	end
	local bloom = self._bloom
	if bloom then
		bloom.Position = UDim2.fromScale(self._spot[1], self._spot[2])
		bloom.Size = UDim2.fromScale(look.bloomSize, look.bloomSize)
		bloom.ImageColor3 = color:Lerp(WHITE, 0.55)
		bloom.ImageTransparency = 1 - math.clamp(look.bloomOp, 0, 1)
	end
end

function EggLight._spawnSpark(self: Light, burst: boolean)
	local front = self._front
	if not front or #self._sparks >= MAX_SPARKS then
		return
	end
	local rng = self._rng
	local eggH = self._spot[3]
	local angle = rng:NextNumber(0, math.pi * 2)
	local start = rng:NextNumber(0.2, 0.36) * eggH -- from the shell
	local speed = rng:NextNumber(0.5, 0.95) * eggH * (if burst then 2.2 else 1)
	local img = image(front, TEX.Spark, 6)
	img.ImageColor3 = self:_color(rng:NextNumber()):Lerp(WHITE, 0.4)
	table.insert(self._sparks, {
		image = img,
		x = math.cos(angle) * start * 0.8,
		y = math.sin(angle) * start,
		vx = math.cos(angle) * speed,
		vy = math.sin(angle) * speed - 0.25 * eggH,
		age = 0,
		life = rng:NextNumber(0.6, 1.0),
		size = rng:NextNumber(0.1, 0.16) * eggH,
	})
end

-- Sparks fly out and drift up as they fade (positions around the egg's middle, in the holder's height).
function EggLight._moveSparks(self: Light, dt: number)
	local holderSize = self._holder.AbsoluteSize
	local aspect = if holderSize.X > 0 and holderSize.Y > 0 then holderSize.X / holderSize.Y else 1
	local cx, cy, eggH = self._spot[1], self._spot[2], self._spot[3]
	local sparks = self._sparks
	for i = #sparks, 1, -1 do
		local s = sparks[i]
		s.age += dt
		if s.age >= s.life then
			s.image:Destroy()
			table.remove(sparks, i)
			continue
		end
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.vx *= 1 - 1.6 * dt
		s.vy = s.vy * (1 - 1.6 * dt) - 0.35 * eggH * dt
		local f = s.age / s.life
		s.image.Position = UDim2.fromScale(cx + s.x / aspect, cy + s.y)
		local size = s.size * (1 - 0.5 * f)
		s.image.Size = UDim2.fromScale(size, size)
		s.image.ImageTransparency = 0.05 + 0.95 * f * f
	end
end

-- The egg's own lighting and the cracks, lit from inside.
function EggLight._inside(self: Light, strength: number, crackLevel: number)
	local tune = self._tune
	local color = self:_color(0)
	local tint = color:Lerp(WHITE, 0.3)
	local view = self._view
	view.Ambient = self._ambient:Lerp(tint, math.clamp(0.8 * strength, 0, 0.85))
	view.LightColor = self._lightColor:Lerp(tint, math.clamp(0.55 * strength, 0, 0.7))
	local shell = self._shell
	if shell and shell.glow then
		-- the cracks show the colour a little earlier: they are the light itself
		local crackColor = WARM:Lerp(self:_rarityColor(0), 0.45 + 0.55 * self._sat)
		shell:glow(crackColor, math.clamp(tune.crack * (0.3 + 0.7 * crackLevel), 0, 1))
	end
end

function EggLight.update(self: Light, u: number, spread: number, dt: number, shell: any?)
	if self._dead or self._burstAt >= 0 then
		return
	end
	self._t += dt
	self._shell = shell
	-- the crack bursts are smoothed, so the light grows without jumps
	self._spread += (spread - self._spread) * math.min(1, dt * 2.5)
	local grow = math.clamp(0.6 * u + 0.4 * self._spread, 0, 1)
	-- a gentle heartbeat (lub-dub): about one beat a second at first, four at the end
	self._beat += dt * (1 + 3 * u * u)
	local p = self._beat % 1
	local beat = math.max(bump(p, 0.12, 0.08), 0.6 * bump(p, 0.36, 0.08))
	local level = grow ^ 1.6 * (1 + (0.1 + 0.2 * u) * (beat - 0.3))
	local tune = self._tune
	if tune.flicker > 0 then
		level *= 1 + tune.flicker * 0.5 * u * math.noise(self._t * 9, self._tier * 3.1, 0.5) * 2
	end
	level = math.max(level, 0)
	self._level = level
	self._sat = smoothstep(0.2, 0.95, grow)
	self._hue += dt * (0.2 + 0.6 * u)
	self:_follow()
	self:_inside(self._tune.s * level, (0.3 + 0.7 * grow ^ 1.1) * (1 + (0.2 + 0.25 * u) * (beat - 0.3)))
	self:_paint(self:_building(level, u), dt * (8 + 40 * u), beat)
	if self._front and tune.sparks > 0 then
		self._spawn += dt * tune.sparks * smoothstep(0.35, 1, u)
		while self._spawn >= 1 do
			self._spawn -= 1
			self:_spawnSpark(false)
		end
	end
	self:_moveSparks(dt)
end

-- One frame of the release: from the light at the burst to the calm glow, with the burst on top.
function EggLight._release(self: Light, dt: number)
	local snap = self._snap
	if not snap then
		return
	end
	self._t += dt
	self._burstAt += dt
	local tau = self._burstAt
	self._hue += dt * 0.3
	self._sat = math.max(self._sat, smoothstep(0, 0.35, tau)) -- the rarity is clear now
	self:_follow()
	local calm = self:_calm()
	local k = smoothstep(SETTLE_FROM, SETTLE_FROM + SETTLE, tau)
	-- the burst: a quick rise, then it dies down
	local e = if tau < 0.05 then tau / 0.05 else math.exp(-(tau - 0.05) / 0.28)
	local breathe = 1 + 0.07 * math.sin(tau * 2.4) * smoothstep(0.9, 1.6, tau)
	local look: Look = {
		auraSize = lerp(snap.auraSize, calm.auraSize, k) + 0.7 * e,
		auraOp = (lerp(snap.auraOp, calm.auraOp, k) + 0.25 * e) * breathe,
		coreSize = lerp(snap.coreSize, calm.coreSize, k) + 1.0 * e,
		coreOp = (lerp(snap.coreOp, calm.coreOp, k) + 0.7 * e) * breathe,
		beamSize = lerp(snap.beamSize, calm.beamSize, k) + 0.45 * e,
		beamOp = lerp(snap.beamOp, calm.beamOp, k) + 0.3 * e * (if self._tune.beams > 0 then 1 else 0.5),
		rimOp = snap.rimOp * (1 - smoothstep(0, 0.2, tau)),
		bloomSize = snap.bloomSize + 1.0 * e,
		bloomOp = (snap.bloomOp * 0.6 + 0.2 * e) * (1 - smoothstep(0, 0.3, tau)), -- the glare over the opening
		x = lerp(snap.x, calm.x, k),
		y = lerp(snap.y, calm.y, k),
	}
	self:_paint(look, dt * (lerp(40, 6, k) + 120 * e), 0)
	self:_moveSparks(dt)
	if not self._keep and tau > SETTLE_FROM + SETTLE + 0.3 then
		self:destroy()
	end
end

-- The break: the light bursts out of the opening (before the egg's view grows for the pieces).
function EggLight.burst(self: Light)
	if self._dead or self._burstAt >= 0 then
		return
	end
	self:_follow()
	local level = math.max(self._level, 1)
	self._level = level
	self:_inside(self._tune.s * 1.25, 1.25)
	self._snap = self:_building(level, 1)
	self._burstAt = 0
	for _ = 1, math.floor(self._tune.sparks * 0.75) do
		self:_spawnSpark(true)
	end
	self:_release(0)
	self._conn = RunService.RenderStepped:Connect(function(dt)
		if not self._holder.Parent then
			self:destroy()
			return
		end
		self:_release(dt)
	end)
end

-- The pet is shown: the light settles behind it (keep) or fades away (several pets).
function EggLight.reveal(self: Light, keep: boolean)
	if self._dead then
		return
	end
	self._keep = keep
	if self._burstAt < 0 then
		self:burst()
	end
end

function EggLight.destroy(self: Light)
	if self._dead then
		return
	end
	self._dead = true
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	self._back:Destroy()
	if self._front then
		self._front:Destroy()
	end
	table.clear(self._sparks)
	table.clear(self._beams)
	table.clear(self._gradients)
	self._shell = nil
end

-- the textures are loaded ahead, so the first hatch has its light
task.spawn(function()
	pcall(ContentProvider.PreloadAsync, ContentProvider, { TEX.Glow, TEX.Beams, TEX.Rim, TEX.Spark })
end)

return EggLight
