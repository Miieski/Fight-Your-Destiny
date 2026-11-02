--!strict
-- Round 9 part 14: the ruin of this player's next portal, on this client only (Config/PortalRuins). PortalController says which ruins are
-- wanted (sync) and takes one to build the portal from it (take). Copies of Assets.PortalRuins.<Zone>, placed from the stored anchors, so a
-- ruin needs nothing of the hub to be streamed in. The sign shows the rules of Config/RebirthZoneUnlock and follows Gold, keys and Rebirths.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Net = require(ReplicatedStorage.GameSystem.Net)
local PortalRuins = require(ReplicatedStorage.GameSystem.Config.PortalRuins)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)
local UI = script.Parent.Parent.UI
local Notifier = require(UI.Notifier)
local ZonesPage = require(UI.Pages.ZonesPage)
local Kit = UI.Kit
local Components = require(Kit.Components)
local Theme = require(Kit.Theme)
local ZoneVisibility = require(Kit.ZoneVisibility)

local PortalRuinController = { Priority = 19 }

local SIGN_PIXELS = 60 -- per stud
local CLEAR = 2 -- studs around a stump where the player keeps it without collision: a ruin that appears never pushes anyone

export type Ruin = {
	zoneId: string,
	model: Model,
	bricks: { [number]: BasePart }, -- by BrickId
	pile: Vector3,
	step: (progress: number) -> (), -- the build, 0 .. 1: moss, cracks and rune fade, the sign sinks
	hideBricks: () -> (), -- the flying copies have taken over
	destroy: () -> (),
}
type Shown = { ruin: Ruin, stumps: { BasePart }, solid: boolean, paint: () -> (), prompt: ProximityPrompt, alive: boolean }

local player = Players.LocalPlayer
local shown: { [string]: Shown } = {}
local warned = false

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function template(zoneId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sets = assets and assets:FindFirstChild("PortalRuins")
	local found = sets and sets:FindFirstChild(zoneId)
	if not found and not warned then
		warned = true
		warn(`PortalRuinController: no ruin for {zoneId}`)
	end
	return found :: Model?
end

local function use(zoneId: string)
	local status = ZoneVisibility.unlockStatus(zoneId)
	if not status.ready then
		ZonesPage.open(zoneId)
		return
	end
	local called, ok, result = pcall(Net.request, "BuyZoneUnlock", zoneId)
	if not (called and ok) then
		Sfx.play("Denied")
		Notifier.push({ Kind = "error", Text = if called and typeof(result) == "string" then result else "Could not buy", Icon = "Lock" })
	end
end

-- The wooden board of the new menus, on the sign.
local function dressSign(board: BasePart, zoneId: string): (() -> (), ProximityPrompt, SurfaceGui)
	local text = PortalRuins.Sign
	local colors = Theme.Colors
	local zone = Zones.ById[zoneId]
	local gui = Instance.new("SurfaceGui")
	gui.Name = "RuinSign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SIGN_PIXELS
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	Theme.gradient(panel, colors.WoodLight, colors.WoodBottom)
	Theme.corner(panel, 8)
	Theme.stroke(panel, colors.GoldDark, 3)
	panel.Parent = gui
	Theme.text({ Name = "Title", Font = "Title", Text = zone.Name, TextSize = 42, Color = colors.Gold, Size = UDim2.new(1, -20, 0, 54), Position = UDim2.fromOffset(10, 6), Parent = panel })
	local rows = Components.CounterRow(panel, { Size = UDim2.new(1, -12, 0, 46), Align = "Center" })
	rows.Position = UDim2.fromOffset(6, 62)
	local key = Components.Counter(rows, "Key", "", { Height = 42, LayoutOrder = 1 })
	local goldRow = Components.CounterRow(panel, { Size = UDim2.new(1, -12, 0, 46), Align = "Center" })
	goldRow.Position = UDim2.fromOffset(6, 110)
	local gold = Components.Counter(goldRow, "Gold", "", { Height = 42, LayoutOrder = 1 })
	local rebirths = Theme.text({ Name = "Rebirths", Font = "Button", Text = "", TextSize = 26, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 160), Parent = panel })
	gui.Parent = board

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = zone.Name
	prompt.ActionText = text.Action
	prompt.HoldDuration = text.Hold
	prompt.MaxActivationDistance = text.Distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	prompt.Triggered:Connect(function()
		use(zoneId)
	end)

	local function paint()
		local status = ZoneVisibility.unlockStatus(zoneId)
		key:Set(string.format(text.Key, if status.hasKey then text.Owned else text.Missing), if status.hasKey then colors.Good else colors.Bad)
		gold:Set(string.format(text.Gold, Format.number(status.price)), if status.enoughGold then colors.Good else colors.Bad)
		rebirths.Text = string.format(text.Rebirths, status.rebirths, status.needRebirths)
		rebirths.TextColor3 = if status.rebirths >= status.needRebirths then colors.Good else colors.Bad
		prompt.ActionText = if status.ready then text.Buy else text.Action
	end
	paint()
	return paint, prompt, gui
end

local function create(zoneId: string, soft: boolean): Shown?
	local source = template(zoneId)
	if not source then
		return nil
	end
	local conf = PortalRuins.Zones[zoneId]
	local model = source:Clone()
	model.Name = "PortalRuin_" .. zoneId
	model:PivotTo(conf.Anchor)

	local bricks: { [number]: BasePart } = {}
	local brickParts: { BasePart } = {}
	for _, brick in ipairs((model :: any).Bricks:GetChildren()) do
		bricks[brick:GetAttribute("BrickId")] = brick
		for _, part in ipairs(brick:GetDescendants()) do
			table.insert(brickParts, part)
		end
		table.insert(brickParts, brick)
	end
	local fades: { any } = {}
	local light: PointLight? = nil
	for _, item in ipairs((model :: any).Decor:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then
			table.insert(fades, item)
		elseif item:IsA("PointLight") then
			light = item
		end
	end
	local brightness = light and light.Brightness or 0
	local signParts: { BasePart } = {}
	local signPoses: { CFrame } = {}
	for _, part in ipairs((model :: any).Sign:GetChildren()) do
		table.insert(signParts, part)
		table.insert(signPoses, part.CFrame)
	end
	local stumps: { BasePart } = (model :: any).Collide:GetChildren()
	for _, stump in ipairs(stumps) do
		stump.CanCollide = false
	end
	local paint, prompt, gui = dressSign((model :: any).Sign.Board, zoneId)

	local build = PortalRuins.Build
	local down = conf.Anchor.UpVector * -PortalRuins.Sign.Sink
	local entry: Shown
	local ruin: Ruin = {
		zoneId = zoneId,
		model = model,
		bricks = bricks,
		pile = conf.Anchor:PointToWorldSpace(model:GetAttribute("Pile") :: Vector3),
		step = function(progress: number)
			local gone = math.clamp(progress / build.DecorEnd, 0, 1)
			for _, item in ipairs(fades) do
				item.LocalTransparencyModifier = gone
			end
			if light then
				light.Brightness = brightness * (1 - gone)
			end
			local sink = TweenService:GetValue(math.clamp((progress - build.SignStart) / (build.SignEnd - build.SignStart), 0, 1), Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			local poses = table.create(#signPoses)
			for i, pose in ipairs(signPoses) do
				poses[i] = pose + down * sink
			end
			workspace:BulkMoveTo(signParts, poses, Enum.BulkMoveMode.FireCFrameChanged)
		end,
		hideBricks = function()
			for _, part in ipairs(brickParts) do
				part.LocalTransparencyModifier = 1
				part.CastShadow = false
			end
		end,
		destroy = function()
			entry.alive = false
			model:Destroy()
		end,
	}
	entry = { ruin = ruin, stumps = stumps, solid = false, paint = paint, prompt = prompt, alive = true }

	if soft then
		local items: { any } = table.clone(fades)
		table.move(brickParts, 1, #brickParts, #items + 1, items)
		table.move(signParts, 1, #signParts, #items + 1, items)
		for _, item in ipairs(items) do
			item.LocalTransparencyModifier = 1
		end
		gui.Enabled = false
		task.spawn(function()
			local start = os.clock()
			local a = 0
			while entry.alive and a < 1 do
				RunService.Heartbeat:Wait()
				a = math.clamp((os.clock() - start) / PortalRuins.FadeIn, 0, 1)
				for _, item in ipairs(items) do
					item.LocalTransparencyModifier = 1 - a
				end
			end
			gui.Enabled = true
		end)
	end
	model.Parent = workspace
	return entry
end

-- Stumps get their collision once the player is clear of them.
local function settle(entry: Shown)
	if entry.solid then
		return
	end
	local root = rootPart()
	if not root then
		return
	end
	for _, stump in ipairs(entry.stumps) do
		local rel = stump.CFrame:PointToObjectSpace(root.Position)
		local half = stump.Size / 2
		if math.abs(rel.X) < half.X + CLEAR and math.abs(rel.Z) < half.Z + CLEAR then
			return
		end
	end
	entry.solid = true
	for _, stump in ipairs(entry.stumps) do
		stump.CanCollide = true
	end
end

-- wanted: the ruins that should stand. A ruin stands only near the player. soft: the new ones fade in.
function PortalRuinController.sync(wanted: { [string]: boolean }, soft: boolean)
	local root = rootPart()
	for zoneId in pairs(wanted) do
		local conf = PortalRuins.Zones[zoneId]
		local near = conf ~= nil and root ~= nil and (root.Position - conf.Anchor.Position).Magnitude < PortalRuins.ShowRange
		if shown[zoneId] and not near then
			shown[zoneId].ruin.destroy()
			shown[zoneId] = nil
		elseif near and not shown[zoneId] then
			shown[zoneId] = create(zoneId, soft)
		end
	end
	for zoneId, entry in pairs(shown) do
		if wanted[zoneId] then
			settle(entry)
		else
			entry.ruin.destroy()
			shown[zoneId] = nil
		end
	end
end

-- The build takes the ruin over; it destroys it at the end.
function PortalRuinController.take(zoneId: string): Ruin?
	local entry = shown[zoneId]
	if not entry then
		return nil
	end
	shown[zoneId] = nil
	entry.prompt:Destroy()
	for _, stump in ipairs(entry.stumps) do
		stump.CanCollide = false
	end
	return entry.ruin
end

function PortalRuinController:Start()
	for _, key in ipairs({ "Gold", "Keys", "Rebirths", "Zones" }) do
		State.changed(key, function()
			for _, entry in pairs(shown) do
				entry.paint()
			end
		end)
	end
end

return PortalRuinController
