--!strict
-- The pet's light inside the egg on the hatch screen (owner 2026-10-18: "make a emission of light during the animation
-- in the egg according to the rarity of the pet inside"). While the egg wobbles and cracks, light glows from inside it:
-- faint at first, growing with the cracks, pulsing like a heartbeat that beats faster and faster, strongest just before
-- the shell breaks. Its colour is the pet's rarity (Divine: a white and gold shimmer, Secret: a rainbow) and it gets
-- stronger with every rarity: Common a soft glow, Epic a few sparks, Legendary and up flicker, glow wider and throw
-- more sparks, Secret the most.
-- A ViewportFrame renders no real lights, so the light is made of:
--   * the cracks (UI/EggCrack shell:glow): they shine in the light's colour as soon as they appear
--   * the egg's own lighting: the view's Ambient / LightColor are tinted toward the light
--   * a glowing outline: flat copies of the egg, a little bigger, in their own ViewportFrames behind it
--   * soft 2D glows (stacked round frames): an aura behind the egg and a bloom over it; sparks from Epic
--   * the hatch screen's halo and rays take the light's colour and strength (the screen still turns the rays)
-- Everything follows the egg while it drops in and rocks. Low FX: only the cracks, the viewport tint and the halo.
--   EggLight.new(opts) -> Light   opts = { Holder: GuiObject (the stage: the egg's view sits in it, or in a frame that
--       fills it), View: ViewportFrame (the egg), Tier: number (the pet's rarity), Low: boolean?, Halo: Frame?,
--       Rays: Frame? (light rays, children Frames) }
--   light:update(u, spread, dt, shell?)  every frame: u = wobble progress 0..1, spread = how far the cracks reached
--       0..1, shell = the UI/EggCrack shell once it exists
--   light:peak()     the break: full strength and a burst of sparks
--   light:destroy()  its own layers fade out in a moment (the view's tint, the halo and the rays stay as they are)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rarities = require(ReplicatedStorage.GameSystem.Config.Rarities)

local EggLight = {}
EggLight.__index = EggLight

-- per rarity: s = strength (0..1), aura = the back glow's size at full strength (of the egg's height), bloom = the glow
-- over the egg near the end (opacity), flicker = shimmer near the end, sparks = sparks per second at the end,
-- crack = how far the cracks go toward the light's colour
type Tune = { s: number, aura: number, bloom: number, flicker: number, sparks: number, crack: number }
local TUNE: { Tune } = {
	{ s = 0.38, aura = 1.25, bloom = 0.16, flicker = 0, sparks = 0, crack = 0.8 }, -- Common
	{ s = 0.46, aura = 1.35, bloom = 0.2, flicker = 0, sparks = 0, crack = 0.88 }, -- Uncommon
	{ s = 0.55, aura = 1.45, bloom = 0.24, flicker = 0, sparks = 0, crack = 0.94 }, -- Rare
	{ s = 0.66, aura = 1.6, bloom = 0.3, flicker = 0.06, sparks = 5, crack = 1 }, -- Epic
	{ s = 0.8, aura = 1.8, bloom = 0.4, flicker = 0.22, sparks = 12, crack = 1 }, -- Legendary
	{ s = 0.88, aura = 1.9, bloom = 0.46, flicker = 0.26, sparks = 15, crack = 1 }, -- Mythic
	{ s = 0.95, aura = 2, bloom = 0.52, flicker = 0.3, sparks = 18, crack = 1 }, -- Divine
	{ s = 1, aura = 2.15, bloom = 0.6, flicker = 0.34, sparks = 24, crack = 1 }, -- Secret
}
local DIVINE, SECRET = 7, 8
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local GOLD = Color3.fromRGB(255, 200, 60)
-- stacked discs = a soft glow: { size factor, opacity }
local AURA_RINGS = { { 1, 0.08 }, { 0.86, 0.09 }, { 0.73, 0.1 }, { 0.61, 0.11 }, { 0.5, 0.12 }, { 0.4, 0.14 }, { 0.31, 0.16 } }
local BLOOM_RINGS = { { 1, 0.3 }, { 0.7, 0.38 }, { 0.42, 0.5 } }
-- the outline: egg copies { size factor, opacity }
local RIMS = { { 1.3, 0.22 }, { 1.17, 0.4 }, { 1.07, 0.65 } }
local MAX_SPARKS = 40
local FADE_IN = 0.45 -- seconds: the egg drops in
local FADE_OUT = 0.3 -- seconds: after the reveal

type Spark = { frame: Frame, x: number, y: number, vx: number, vy: number, age: number, life: number, size: number }
type Rim = { view: ViewportFrame, part: BasePart, scale: UIScale }
type Fading = { inst: GuiObject, prop: string, from: number, quick: boolean } -- quick: the outline goes first

export type Light = typeof(setmetatable({} :: {
	_holder: GuiObject,
	_view: ViewportFrame,
	_egg: BasePart?,
	_tier: number,
	_tune: Tune,
	_halo: Frame?,
	_rays: { Frame },
	_ambient: Color3,
	_lightColor: Color3,
	_layers: { GuiObject },
	_aura: { Frame },
	_bloom: { Frame },
	_rims: { Rim },
	_sparkLayer: Frame?,
	_sparks: { Spark },
	_rng: Random,
	_t: number,
	_beat: number,
	_hue: number,
	_spawn: number,
	_spot: { number }, -- the egg's middle (holder scale x, y) and its height (of the holder's height)
	_color: Color3,
	_shell: any,
	_peaked: boolean,
	_dead: boolean,
	_fade: number, -- seconds left of the fade-out, -1 = not fading
	_fading: { Fading }, -- what fades out and from which opacity
	_mult: number, -- the sparks' opacity (1, less while fading out)
	_conn: RBXScriptConnection?,
}, EggLight))

local function bump(x: number, center: number, width: number): number
	local d = (x - center) / width
	return math.exp(-d * d)
end

local function layer(parent: GuiObject, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z
	frame.Active = false
	frame.Parent = parent
	return frame
end

-- a round frame sized on its parent's height (stays round in any frame)
local function disc(parent: GuiObject, z: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- A flat white copy of the egg, `grow` times bigger, in its own view behind the egg (tinted by ImageColor3).
local function rim(holder: GuiObject, view: ViewportFrame, egg: BasePart, grow: number): Rim?
	local camera = view.CurrentCamera
	if not camera then
		return nil
	end
	local rimView = Instance.new("ViewportFrame")
	rimView.Name = "EggLightRim"
	rimView.BackgroundTransparency = 1
	rimView.Ambient = WHITE
	rimView.LightColor = BLACK
	rimView.ImageTransparency = 1
	rimView.AnchorPoint = view.AnchorPoint
	rimView.Size = view.Size
	rimView.Position = view.Position
	rimView.ZIndex = 3
	rimView.Active = false
	local rimCamera = Instance.new("Camera")
	rimCamera.FieldOfView = camera.FieldOfView
	rimCamera.CFrame = camera.CFrame
	rimCamera.Parent = rimView
	rimView.CurrentCamera = rimCamera
	local part = egg:Clone()
	part:ClearAllChildren()
	pcall(function()
		(part :: any).TextureID = ""
	end)
	part.Color = WHITE
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0
	part.Size = egg.Size * grow
	part.CFrame = egg.CFrame
	part.Parent = rimView
	local scale = Instance.new("UIScale")
	scale.Parent = rimView
	rimView.Parent = holder
	return { view = rimView, part = part, scale = scale }
end

function EggLight.new(opts: { [string]: any }): Light
	local holder = opts.Holder :: GuiObject
	local view = opts.View :: ViewportFrame
	local tier = math.clamp(math.floor(tonumber(opts.Tier) or 1), 1, #TUNE)
	local low = opts.Low == true
	local model = view:FindFirstChildOfClass("Model")
	local found = model and model:FindFirstChild("Egg", true)
	local egg = if found and found:IsA("BasePart") then found else nil
	local rays: { Frame } = {}
	local rayHolder = opts.Rays :: Frame?
	if rayHolder and not low then
		for _, ray in ipairs(rayHolder:GetChildren()) do
			if ray:IsA("Frame") then
				table.insert(rays, ray)
			end
		end
	end
	local self: Light = setmetatable({
		_holder = holder,
		_view = view,
		_egg = egg,
		_tier = tier,
		_tune = TUNE[tier],
		_halo = opts.Halo :: Frame?,
		_rays = rays,
		_ambient = view.Ambient,
		_lightColor = view.LightColor,
		_layers = {},
		_aura = {},
		_bloom = {},
		_rims = {},
		_sparkLayer = nil,
		_sparks = {},
		_rng = Random.new(),
		_t = 0,
		_beat = 0,
		_hue = 0,
		_spawn = 0,
		_spot = { 0.5, 0.5, 0.6 },
		_color = Rarities.get(tier).Color,
		_shell = nil,
		_peaked = false,
		_dead = false,
		_fade = -1,
		_fading = {},
		_mult = 1,
		_conn = nil,
	}, EggLight)
	if not low then
		-- behind the egg (with the halo and rays): the aura, then the outline; over it: the bloom and the sparks
		local aura = layer(holder, "EggLightAura", 3)
		for _ in ipairs(AURA_RINGS) do
			table.insert(self._aura, disc(aura, 3))
		end
		table.insert(self._layers, aura)
		if egg then
			for _, r in ipairs(RIMS) do
				local made = rim(holder, view, egg, r[1])
				if made then
					table.insert(self._rims, made)
					table.insert(self._layers, made.view)
				end
			end
		end
		local bloom = layer(holder, "EggLightBloom", 5)
		for _ in ipairs(BLOOM_RINGS) do
			table.insert(self._bloom, disc(bloom, 5))
		end
		table.insert(self._layers, bloom)
		if self._tune.sparks > 0 then
			local sparks = layer(holder, "EggLightSparks", 5)
			self._sparkLayer = sparks
			table.insert(self._layers, sparks)
		end
	end
	return self
end

-- The light's colour; `offset` shifts it for the rainbow / shimmer layers (0 = the main colour).
function EggLight._colorAt(self: Light, offset: number): Color3
	if self._tier == SECRET then
		return Color3.fromHSV((self._hue + offset) % 1, 0.62, 1)
	elseif self._tier == DIVINE then
		return WHITE:Lerp(GOLD, 0.15 + 0.6 * (0.5 + 0.5 * math.sin(self._t * 5 + offset * 9)))
	end
	return self._color
end

-- Where the egg's middle is on the stage (it rocks around its base) and how tall it looks; the outline follows it.
function EggLight._follow(self: Light)
	local view, egg = self._view, self._egg
	local camera = view.CurrentCamera
	if not egg or not camera or not view.Parent then
		return
	end
	local squash = view:FindFirstChildOfClass("UIScale")
	local k = if squash then squash.Scale else 1
	for _, r in ipairs(self._rims) do
		r.view.Position = view.Position
		r.view.Size = view.Size
		r.scale.Scale = k
		r.part.CFrame = egg.CFrame
	end
	local p = camera.CFrame:PointToObjectSpace(egg.Position)
	local depth = -p.Z
	if depth < 1e-3 then
		return
	end
	local tanHalf = math.tan(math.rad(camera.FieldOfView / 2))
	local abs = view.AbsoluteSize
	local aspect = if abs.Y > 0 and abs.X > 0 then abs.X / abs.Y else 1
	local w, h = view.Size.X.Scale * k, view.Size.Y.Scale * k
	local anchor = view.AnchorPoint
	local cx = view.Position.X.Scale + (0.5 - anchor.X) * w
	local cy = view.Position.Y.Scale + (0.5 - anchor.Y) * h
	local spot = self._spot
	spot[1] = cx + p.X / (depth * tanHalf * aspect) * 0.5 * w
	spot[2] = cy - p.Y / (depth * tanHalf) * 0.5 * h
	spot[3] = egg.Size.Y / (depth * tanHalf) * 0.5 * h
end

function EggLight._spawnSpark(self: Light, burst: boolean)
	local layerFrame = self._sparkLayer
	if not layerFrame or #self._sparks >= MAX_SPARKS then
		return
	end
	local rng = self._rng
	local eggH = self._spot[3]
	local angle = rng:NextNumber(0, math.pi * 2)
	local start = rng:NextNumber(0.2, 0.38) * eggH -- from the shell
	local speed = rng:NextNumber(0.55, 1.0) * eggH * (if burst then 1.8 else 1)
	local frame = disc(layerFrame, 5)
	frame.BackgroundColor3 = if self._tier == SECRET then self:_colorAt(rng:NextNumber()) else self:_colorAt(rng:NextNumber()):Lerp(WHITE, 0.35)
	local spark: Spark = {
		frame = frame,
		x = math.cos(angle) * start,
		y = math.sin(angle) * start * 1.25,
		vx = math.cos(angle) * speed,
		vy = math.sin(angle) * speed - 0.2 * eggH,
		age = 0,
		life = rng:NextNumber(0.55, 0.9),
		size = rng:NextNumber(0.045, 0.075) * eggH,
	}
	table.insert(self._sparks, spark)
end

-- Moves the sparks (positions are around the egg's middle, in the holder's height).
function EggLight._moveSparks(self: Light, dt: number)
	local holderSize = self._holder.AbsoluteSize
	local aspect = if holderSize.X > 0 and holderSize.Y > 0 then holderSize.X / holderSize.Y else 1
	local cx, cy = self._spot[1], self._spot[2]
	local sparks = self._sparks
	for i = #sparks, 1, -1 do
		local s = sparks[i]
		s.age += dt
		if s.age >= s.life then
			s.frame:Destroy()
			table.remove(sparks, i)
			continue
		end
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.vx *= 1 - 1.2 * dt
		s.vy = s.vy * (1 - 1.2 * dt) - 0.25 * dt * self._spot[3]
		local f = s.age / s.life
		s.frame.Position = UDim2.fromScale(cx + s.x / aspect, cy + s.y)
		local size = s.size * (1 - 0.6 * f)
		s.frame.Size = UDim2.fromScale(size, size)
		s.frame.BackgroundTransparency = 1 - (1 - (0.05 + 0.95 * f * f)) * self._mult
	end
end

-- Puts the light on everything at `level` (0..1+, before the rarity's strength).
function EggLight._apply(self: Light, level: number, u: number, beat: number)
	local tune = self._tune
	local strength = tune.s * level
	local color = self:_colorAt(0)
	local soft = color:Lerp(WHITE, 0.2) -- light reads lighter than paint
	-- the egg lit from inside
	local tint = color:Lerp(WHITE, 0.3)
	local view = self._view
	view.Ambient = self._ambient:Lerp(tint, math.clamp(0.8 * strength, 0, 0.85))
	view.LightColor = self._lightColor:Lerp(tint, math.clamp(0.55 * strength, 0, 0.7))
	-- light through the cracks
	local shell = self._shell
	if shell and shell.glow then
		shell:glow(color, math.clamp(tune.crack * (0.35 + 0.65 * level), 0, 1))
	end
	-- the halo and rays behind the egg
	local halo = self._halo
	if halo and halo.Parent then
		halo.BackgroundColor3 = soft
		halo.BackgroundTransparency = math.clamp(0.88 - 0.42 * strength, 0.3, 1)
		local size = 0.95 + 0.25 * u + 0.06 * beat * u
		halo.Size = UDim2.fromScale(size, size)
	end
	local rayOpacity = math.clamp(0.85 * strength * math.clamp(0.15 + 1.3 * u, 0, 1), 0, 0.85)
	for i, ray in ipairs(self._rays) do
		ray.BackgroundColor3 = if self._tier == SECRET then self:_colorAt(i / #self._rays) elseif self._tier == DIVINE and i % 2 == 0 then GOLD else soft
		ray.BackgroundTransparency = 1 - rayOpacity
	end
	if #self._layers == 0 then
		return
	end
	local glow = math.clamp(level, 0, 1.3)
	-- the outline hugging the egg
	local rimOpacity = math.clamp(strength * 1.6, 0, 1)
	for i, r in ipairs(self._rims) do
		r.view.ImageColor3 = if self._tier == SECRET then self:_colorAt(i * 0.1) else color:Lerp(WHITE, 0.12 * (i - 1))
		r.view.ImageTransparency = 1 - math.clamp(RIMS[i][2] * rimOpacity, 0, 1)
	end
	-- the soft glows, centred on the egg's middle
	local x, y, eggH = self._spot[1], self._spot[2], self._spot[3]
	local auraSize = eggH * (0.8 + (tune.aura - 0.8) * math.min(glow, 1)) * (1 + 0.05 * beat)
	local auraOpacity = math.clamp(strength * 1.6, 0, 1.2)
	for i, frame in ipairs(self._aura) do
		local ring = AURA_RINGS[i]
		frame.Position = UDim2.fromScale(x, y)
		frame.Size = UDim2.fromScale(auraSize * ring[1], auraSize * ring[1])
		frame.BackgroundColor3 = if self._tier == SECRET then self:_colorAt(i * 0.07) else soft:Lerp(WHITE, 0.06 * (i - 1))
		frame.BackgroundTransparency = 1 - math.clamp(ring[2] * auraOpacity, 0, 1)
	end
	local bloomSize = eggH * (0.7 + 0.35 * math.min(glow, 1.2))
	local bloomOpacity = tune.bloom * glow * glow * 1.6
	for i, frame in ipairs(self._bloom) do
		local ring = BLOOM_RINGS[i]
		frame.Position = UDim2.fromScale(x, y)
		frame.Size = UDim2.fromScale(bloomSize * ring[1], bloomSize * ring[1])
		frame.BackgroundColor3 = color:Lerp(WHITE, 0.3 + 0.2 * i)
		frame.BackgroundTransparency = 1 - math.clamp(bloomOpacity * ring[2], 0, 0.9)
	end
end

function EggLight.update(self: Light, u: number, spread: number, dt: number, shell: any?)
	if self._dead or self._peaked then
		return
	end
	self._t += dt
	self._shell = shell
	-- heartbeat (lub-dub): about one beat a second at first, four at the end
	self._beat += dt * (1 + 3 * u * u)
	local p = self._beat % 1
	local beat = math.max(bump(p, 0.12, 0.08), 0.6 * bump(p, 0.36, 0.08))
	local depth = 0.3 + 0.3 * u
	local grow = math.clamp(0.45 * u + 0.55 * spread, 0, 1)
	local level = (0.14 + 0.86 * grow ^ 1.5) * (1 - depth + depth * beat) * math.clamp(self._t / FADE_IN, 0, 1)
	local tune = self._tune
	if tune.flicker > 0 then
		level *= 1 + tune.flicker * u * math.noise(self._t * 13, self._tier * 3.1, 0.5) * 2
	end
	self._hue += dt * (0.25 + 0.75 * u)
	self:_follow()
	self:_apply(math.max(level, 0), u, beat)
	if self._sparkLayer then
		self._spawn += dt * tune.sparks * math.clamp((u - 0.25) / 0.75, 0, 1) ^ 1.2
		while self._spawn >= 1 do
			self._spawn -= 1
			self:_spawnSpark(false)
		end
		self:_moveSparks(dt)
	end
end

-- The loop that keeps the sparks flying after the break and fades the light out after the reveal.
function EggLight._run(self: Light)
	if self._conn then
		return
	end
	self._conn = RunService.RenderStepped:Connect(function(dt)
		if not self._holder.Parent then
			self:_finish()
			return
		end
		if self._fade >= 0 then
			self._fade -= dt
			local k = math.clamp(self._fade / FADE_OUT, 0, 1)
			self._mult = k
			for _, f in ipairs(self._fading) do
				(f.inst :: any)[f.prop] = 1 - f.from * (if f.quick then k * k * k else k)
			end
			if self._fade <= 0 then
				self:_finish()
				return
			end
		end
		self:_moveSparks(dt)
	end)
end

-- The break: full strength, the cracks fully lit, a burst of sparks.
function EggLight.peak(self: Light)
	if self._dead or self._peaked then
		return
	end
	self:_follow()
	self:_apply(1.25, 1, 1)
	self._peaked = true
	if self._sparkLayer then
		for _ = 1, math.floor(self._tune.sparks * 0.6) do
			self:_spawnSpark(true)
		end
	end
	self:_run()
end

function EggLight._finish(self: Light)
	self._dead = true
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	for _, item in ipairs(self._layers) do
		item:Destroy()
	end
	table.clear(self._layers)
	table.clear(self._aura)
	table.clear(self._bloom)
	table.clear(self._rims)
	table.clear(self._sparks)
	table.clear(self._fading)
	self._sparkLayer = nil
	self._shell = nil
end

-- Its own layers fade out (the view's tint, the halo and the rays stay: the hatch screen takes them over).
function EggLight.destroy(self: Light)
	if self._dead or self._fade >= 0 then
		return
	end
	self._peaked = true
	self._shell = nil
	if #self._layers == 0 then
		self:_finish()
		return
	end
	for _, list in ipairs({ self._aura, self._bloom }) do
		for _, frame in ipairs(list) do
			table.insert(self._fading, { inst = frame, prop = "BackgroundTransparency", from = 1 - frame.BackgroundTransparency, quick = false })
		end
	end
	for _, r in ipairs(self._rims) do
		table.insert(self._fading, { inst = r.view, prop = "ImageTransparency", from = 1 - r.view.ImageTransparency, quick = true })
	end
	self._fade = FADE_OUT
	self:_run()
end

return EggLight
