--!strict
-- Combat visual effects (docs/weapons_combat_brief.txt 4C, contract in docs/COMBAT_CONTRACTS.md).
-- OWNER: the VFX sub-agent (this folder, Config/CombatVFX, ReplicatedStorage.Assets.VFX). CombatController calls only
-- the functions below; keep their names and arguments. Effects are client-only and never decide damage.
--   VFX.play(name, cframe, options?)        one pooled effect from ReplicatedStorage.Assets.VFX.<name>
--   VFX.swing(ctx)        ctx = { Character, Tool?, Category, Step, Finisher, Direction, Rarity?, Element?, Speed, IsLocal }
--   VFX.impact(ctx)       ctx = { Position, Category?, Crit, Finisher, Element?, IsLocal }
--   VFX.shot(ctx)         ctx = { Origin, Direction, Speed, Distance, Style }      (Net "Projectile": Ranged, enemies)
--   VFX.burst(ctx)        ctx = { Position, Radius, Style }                         (Net "Burst": Magic area, Heavy slam)
--   VFX.roll(ctx)         ctx = { Character, Direction, IsLocal }
--   VFX.block(ctx)        ctx = { Character, On }
--   VFX.blockHit(ctx)     ctx = { Character, Position? }
--   VFX.damageNumber(position, text, kind)   kind = "normal" | "crit" | "hurt" | "block" | "dodge"
-- STUB until the VFX sub-agent delivers: the effects that CombatController drew before (damage numbers, neon shots,
-- area discs, the Hit_Spark / Crit_Spark bursts).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Combat = require(ReplicatedStorage.GameSystem.Config.Combat)

local VFX = {}

local NUMBER_TIME = 0.7
local NUMBER_COLORS = {
	normal = Color3.new(1, 1, 1),
	crit = Color3.fromRGB(255, 201, 60),
	hurt = Color3.fromRGB(255, 80, 70),
	block = Color3.fromRGB(130, 200, 255),
	dodge = Color3.fromRGB(200, 255, 200),
}
local rng = Random.new()

local function styleColor(style: any): Color3
	return Combat.StyleColors[style] or Combat.StyleColors.Physical
end

function VFX.play(name: string, cframe: CFrame, _options: { [string]: any }?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("VFX")
	local vfx = folder and folder:FindFirstChild(name)
	if vfx and vfx:IsA("BasePart") then
		local clone = vfx:Clone()
		clone.CFrame = cframe
		clone.Parent = workspace
		for _, emitter in ipairs(clone:GetDescendants()) do
			if emitter:IsA("ParticleEmitter") then
				emitter:Emit(emitter:GetAttribute("EmitCount") or 8)
			end
		end
		Debris:AddItem(clone, 1.5)
	end
end

function VFX.swing(_ctx: { [string]: any }) end

function VFX.impact(ctx: { [string]: any })
	VFX.play(if ctx.Crit then "Crit_Spark" else "Hit_Spark", CFrame.new(ctx.Position - Vector3.new(0, 1.5, 0)))
end

function VFX.shot(ctx: { [string]: any })
	local origin, dir, speed, distance = ctx.Origin, ctx.Direction, ctx.Speed, ctx.Distance
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or typeof(speed) ~= "number" or typeof(distance) ~= "number" or speed <= 0 then
		return
	end
	local color = styleColor(ctx.Style)
	local enemy = ctx.Style == "Enemy"
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * (if enemy then 1.4 else 0.9)
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide, ball.CanQuery, ball.CanTouch = false, false, false
	ball.CastShadow = false
	ball.CFrame = CFrame.new(origin)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.18
	trail.LightEmission = 1
	trail.Parent = ball
	ball.Parent = workspace
	local seconds = math.max(0.05, distance / speed)
	local finish = origin + dir.Unit * distance
	TweenService:Create(ball, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = CFrame.new(finish) }):Play()
	task.delay(seconds, function()
		VFX.play("Hit_Spark", CFrame.new(finish))
		ball.Transparency = 1
	end)
	Debris:AddItem(ball, seconds + 0.3)
end

local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), params)
	return if result then result.Position else position
end

function VFX.burst(ctx: { [string]: any })
	local position, radius = ctx.Position, ctx.Radius
	if typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local ground = groundBelow(position)
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = styleColor(ctx.Style)
	disc.Transparency = 0.3
	disc.Anchored = true
	disc.CanCollide, disc.CanQuery, disc.CanTouch = false, false, false
	disc.CastShadow = false
	disc.Size = Vector3.new(0.2, 1, 1)
	disc.CFrame = CFrame.new(ground + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = workspace
	TweenService:Create(disc, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, radius * 2, radius * 2) }):Play()
	task.delay(0.22, function()
		TweenService:Create(disc, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(disc, 0.6)
	VFX.play("Hit_Spark", CFrame.new(ground + Vector3.new(0, 1, 0)))
end

function VFX.roll(_ctx: { [string]: any }) end

function VFX.block(_ctx: { [string]: any }) end

function VFX.blockHit(_ctx: { [string]: any }) end

function VFX.damageNumber(position: Vector3, text: string, kind: string)
	local big = kind == "crit"
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	local gui = Instance.new("BillboardGui")
	gui.Size = if big then UDim2.fromScale(7, 2.6) else UDim2.fromScale(5, 1.8)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Fantasy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = NUMBER_COLORS[kind] or NUMBER_COLORS.normal
	label.TextStrokeTransparency = 0
	label.Parent = gui
	anchor.Parent = workspace
	TweenService:Create(gui, TweenInfo.new(NUMBER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(NUMBER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, NUMBER_TIME + 0.1)
end

return VFX
