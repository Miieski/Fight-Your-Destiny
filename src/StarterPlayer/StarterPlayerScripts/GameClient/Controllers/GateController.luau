--!strict
-- Shows each sub-zone gate as open or closed for THIS player (gates are unlocked per player), and plays its opening when
-- the player unlocks it (Config/DoorAnimations: one row per door type, data only). The door is the gate's Barrier and
-- its descendants: left / right pieces by their side of the Barrier's centre (DevTools.GateSplit cut the ones across it).
-- An open door keeps its open pose on this client; its collision goes for this player only. The server still checks where
-- the player stands (ZoneService), so an open-looking gate grants nothing by itself. A gate that is already open at join,
-- or streams back in, is put in its open pose at once, with no animation; a gate locked again by a Rebirth goes back shut.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DoorAnimations = require(ReplicatedStorage.GameSystem.Config.DoorAnimations)
local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)

local GateController = {}

local OPEN_COLOR = Color3.fromRGB(91, 220, 110)
local PRICE_COLOR = Color3.fromRGB(255, 201, 60)
local REFRESH_SECONDS = 1 -- gates stream in and out, so the state is re-applied regularly
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FALL_FADE_FROM = 0.65 -- Fall / Retract: the fade starts here
local TWO_LEAVES = { Hinge = true, Slide = true, CrackSlide = true }

type Piece = { part: BasePart, home: CFrame, side: number, index: number, fadeOnly: boolean, posed: CFrame? }
type Gate = { cfg: DoorAnimations.DoorType, barrier: BasePart, frame: CFrame, open: boolean, playing: boolean, swing: number, pieces: { Piece }, seen: { [BasePart]: boolean }, proxies: { BasePart } }

local collide: { [BasePart]: boolean } = {}
local gates: { [BasePart]: Gate } = setmetatable({}, { __mode = "k" }) :: any
local animate: { [string]: boolean } = {} -- sub-zones unlocked just now: their gate plays its opening once

local function addPiece(g: Gate, part: BasePart, fadeOnly: boolean?)
	g.seen[part] = true
	-- a piece cut by GateSplit keeps the original's pivot: its side is in its name
	local side = if string.sub(part.Name, -2) == "_L" then -1 elseif string.sub(part.Name, -2) == "_R" then 1 elseif g.frame:PointToObjectSpace(part.Position).X >= 0 then 1 else -1
	table.insert(g.pieces, { part = part, home = part.CFrame, side = side, index = #g.pieces + 1, fadeOnly = fadeOnly == true })
end

-- t 0 (shut) .. 1 (open) for one piece
local function place(g: Gate, piece: Piece, t: number)
	local cfg, part = g.cfg, piece.part
	local mode = cfg.Mode
	if piece.fadeOnly then
		part.LocalTransparencyModifier = if t > 0 then 1 else 0 -- the Barrier's slab: the proxies stand in for it
		return
	end
	local f = g.frame
	if mode == "Hinge" then
		local hinge = f * CFrame.new(piece.side * g.barrier.Size.X / 2, 0, 0)
		local angle = math.rad(cfg.Angle or 90) * t * piece.side * g.swing
		part.CFrame = hinge * CFrame.Angles(0, angle, 0) * hinge:Inverse() * piece.home
	elseif mode == "Slide" or mode == "CrackSlide" then
		part.CFrame = piece.home + f.RightVector * piece.side * (cfg.Distance or 12) * t
	elseif mode == "Rise" then
		part.CFrame = piece.home + f.UpVector * (cfg.Height or 15) * t
	elseif mode == "Fall" then
		local n = math.max(1, #g.pieces)
		local k = math.clamp((t - 0.4 * (piece.index - 1) / n) / 0.6, 0, 1)
		local bounce = if k < 0.8 then (k / 0.8) ^ 2 else 1 - 0.08 * math.sin((k - 0.8) / 0.2 * math.pi)
		part.CFrame = (piece.home - f.UpVector * (cfg.Drop or 12) * bounce) * CFrame.Angles(0, 0, 0.35 * piece.side * k)
		part.LocalTransparencyModifier = math.clamp((k - FALL_FADE_FROM) / (1 - FALL_FADE_FROM), 0, 1)
	elseif mode == "Retract" then
		part.CFrame = piece.home + f.UpVector * (cfg.Height or 12) * t + f.RightVector * piece.side * 2 * t
		part.LocalTransparencyModifier = math.clamp((t - 0.4) / 0.6, 0, 1)
	else
		part.LocalTransparencyModifier = t
	end
end

local function proxy(g: Gate, width: number, x: number)
	local b = g.barrier
	local p = Instance.new("Part")
	p.Name = "DoorProxy"
	p.Size = Vector3.new(width, b.Size.Y, b.Size.Z)
	p.CFrame = g.frame * CFrame.new(x, 0, 0)
	p.Color, p.Material, p.Transparency = b.Color, b.Material, b.Transparency
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Parent = b
	table.insert(g.proxies, p)
	addPiece(g, p)
end

-- The door's pieces, the Barrier's slab replaced by moving proxies when it is visible.
local function collect(g: Gate)
	local b = g.barrier
	for _, part in ipairs(b:GetDescendants()) do
		if part:IsA("BasePart") and not g.seen[part] and part.Name ~= "DoorProxy" then
			addPiece(g, part)
		end
	end
	if not g.seen[b] then
		addPiece(g, b, true)
		if b.Transparency < 1 then
			local mode = g.cfg.Mode
			if TWO_LEAVES[mode] then
				proxy(g, b.Size.X / 2, -b.Size.X / 4)
				proxy(g, b.Size.X / 2, b.Size.X / 4)
			else
				proxy(g, b.Size.X, 0)
			end
		end
	end
end

local function flags(g: Gate, open: boolean)
	local barrier = g.barrier
	local list = barrier:GetDescendants()
	table.insert(list, barrier)
	for _, part in ipairs(list) do
		if part:IsA("BasePart") and part.Name ~= "DoorProxy" then
			if collide[part] == nil then
				collide[part] = part.CanCollide
			end
			part.CanCollide = collide[part] and not open
		elseif part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Light") then
			if part.Name ~= "DoorDust" then
				part.Enabled = not open
			end
		elseif part:IsA("ProximityPrompt") then
			part.Enabled = not open
		end
	end
end

local function dust(g: Gate)
	local spec = g.cfg.Dust
	if not spec then
		return
	end
	local fx = g.barrier:FindFirstChild("DoorDust") :: ParticleEmitter?
	if not fx then
		local new = Instance.new("ParticleEmitter")
		new.Name = "DoorDust"
		new.Texture = DUST_TEXTURE
		new.Rate = 0
		new.Lifetime = NumberRange.new(0.8, 1.5)
		new.Speed = NumberRange.new(2, 6)
		new.SpreadAngle = Vector2.new(60, 60)
		new.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		new.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		new.Rotation = NumberRange.new(0, 360)
		new.Parent = g.barrier
		fx = new
	end
	local emitter = fx :: ParticleEmitter
	emitter.Color = ColorSequence.new(spec.Color)
	emitter:Emit(spec.Burst)
end

local function shake(position: Vector3, amount: number)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > DoorAnimations.ShakeRange then
		return
	end
	local name = "DoorShake"
	local ends = os.clock() + DoorAnimations.ShakeSeconds
	pcall(function()
		RunService:UnbindFromRenderStep(name)
	end)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local left = ends - os.clock()
		if left <= 0 then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = amount * left / DoorAnimations.ShakeSeconds
		camera.CFrame *= CFrame.new(math.random() * 2 * k - k, math.random() * 2 * k - k, 0)
	end)
end

-- a glowing crack across the door, on both faces
local function crack(g: Gate, seconds: number)
	local f, b = g.frame, g.barrier
	local color = g.cfg.Glow or Color3.new(1, 1, 1)
	local points = { Vector2.new(0.2, 7.6), Vector2.new(-1.2, 4.4), Vector2.new(0.9, 2.1), Vector2.new(-0.6, -0.8), Vector2.new(1.1, -3.4), Vector2.new(-0.4, -7.6) }
	for _, face in ipairs({ -1, 1 }) do
		for i = 1, #points - 1 do
			local a, c = points[i], points[i + 1]
			local z = face * (b.Size.Z / 2 + 0.05)
			local pa, pc = (f * CFrame.new(a.X, a.Y, z)).Position, (f * CFrame.new(c.X, c.Y, z)).Position
			local bar = Instance.new("Part")
			bar.Name = "DoorCrack"
			bar.Size = Vector3.new(0.22, 0.22, (pc - pa).Magnitude)
			bar.CFrame = CFrame.lookAt((pa + pc) / 2, pc, f.RightVector)
			bar.Color, bar.Material = color, Enum.Material.Neon
			bar.Anchored = true
			bar.CanCollide, bar.CanQuery, bar.CanTouch, bar.CastShadow = false, false, false, false
			bar.Transparency = 1
			bar.Parent = b
			TweenService:Create(bar, TweenInfo.new(seconds * 0.5, Enum.EasingStyle.Quad), { Transparency = 0 }):Play()
			task.delay(seconds + 0.15, function()
				if bar.Parent then
					TweenService:Create(bar, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				end
			end)
			Debris:AddItem(bar, seconds + 0.6)
		end
	end
end

local function play(g: Gate)
	local cfg = g.cfg
	g.playing = true
	task.spawn(function()
		local barrier = g.barrier
		if cfg.CrackSeconds then
			Sfx.play(cfg.Sound or "", barrier.Position)
			crack(g, cfg.CrackSeconds)
			task.wait(cfg.CrackSeconds)
		else
			Sfx.play(cfg.Sound or "", barrier.Position)
		end
		for _, piece in ipairs(g.pieces) do
			if piece.fadeOnly then
				place(g, piece, 1)
			end
		end
		dust(g)
		if cfg.Shake then
			shake(barrier.Position, cfg.Shake)
		end
		local start = os.clock()
		while barrier.Parent do
			local a = math.clamp((os.clock() - start) / cfg.Seconds, 0, 1)
			local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			for _, piece in ipairs(g.pieces) do
				if not piece.fadeOnly and piece.part.Parent then
					place(g, piece, e)
				end
			end
			if a >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		g.playing = false
	end)
end

local function openGate(g: Gate, animated: boolean)
	g.open = true
	collect(g)
	flags(g, true)
	if animated then
		play(g)
	else
		for _, piece in ipairs(g.pieces) do
			place(g, piece, 1)
		end
	end
end

local function closeGate(g: Gate)
	g.open = false
	for _, piece in ipairs(g.pieces) do
		if piece.part.Parent then
			place(g, piece, 0)
			piece.part.CFrame = piece.home
			piece.part.LocalTransparencyModifier = 0
		end
	end
	for _, p in ipairs(g.proxies) do
		p:Destroy()
	end
	g.pieces, g.seen, g.proxies = {}, {}, {}
	flags(g, false)
end

local function setGate(gate: Model, open: boolean, priceText: string, animated: boolean)
	local barrier = gate.PrimaryPart or gate:FindFirstChild("Barrier", true)
	if barrier and barrier:IsA("BasePart") then
		local g = gates[barrier]
		if not g then
			local entrance = gate.Parent and gate.Parent:FindFirstChild("Entrance")
			local swing = if entrance and entrance:IsA("BasePart") and barrier.CFrame:PointToObjectSpace(entrance.Position).Z < 0 then -1 else 1
			g = { cfg = DoorAnimations.typeOf(gate:GetAttribute("MapPropId")), barrier = barrier, frame = barrier.CFrame, open = false, playing = false, swing = swing, pieces = {}, seen = {}, proxies = {} }
			gates[barrier] = g
		end
		local door = g :: Gate
		if open and not door.open then
			openGate(door, animated)
		elseif not open and door.open then
			closeGate(door)
		elseif open and not door.playing then
			-- a door that streamed back in (death, boss room, teleport) comes with the server's shut pose and collision: put
			-- right at every refresh, so a door that is open for this player can never stay shut more than REFRESH_SECONDS
			collect(door)
			for _, piece in ipairs(door.pieces) do
				local part = piece.part
				if part.Parent and (piece.fadeOnly or part.CFrame ~= piece.posed) then
					place(door, piece, 1)
					piece.posed = part.CFrame
				end
			end
			flags(door, true)
		end
	end
	for _, label in ipairs(gate:GetDescendants()) do
		if label:IsA("TextLabel") and label.Name == "PriceLabel" then
			label.Text = if open then "OPEN" else priceText
			label.TextColor3 = if open then OPEN_COLOR else PRICE_COLOR
		end
	end
end

local function refresh()
	local unlocked = State.get("SubZones") or {}
	local zonesFolder = workspace:FindFirstChild("Zones")
	for _, zoneFolder in ipairs(if zonesFolder then zonesFolder:GetChildren() else {}) do
		for _, subZone in ipairs(zoneFolder:GetChildren()) do
			local gate = subZone:FindFirstChild("Gate")
			local id = gate and gate:GetAttribute("SubZoneId")
			local zoneId, n = Zones.parseSubZoneId(id or "")
			if gate and gate:IsA("Model") and zoneId and n then
				setGate(gate, unlocked[id] == true, Format.number(Zones.subZonePrice(zoneId, n)) .. " Gold", animate[id] == true)
				animate[id] = nil
			end
		end
	end
end

function GateController:Start()
	State.changed("SubZones", function(new: any, old: any)
		if typeof(new) == "table" and typeof(old) == "table" then
			for id, open in pairs(new) do
				if open == true and old[id] ~= true then
					animate[id] = true
				end
			end
		end
		refresh()
	end)
	while true do
		refresh()
		task.wait(REFRESH_SECONDS)
	end
end

return GateController
