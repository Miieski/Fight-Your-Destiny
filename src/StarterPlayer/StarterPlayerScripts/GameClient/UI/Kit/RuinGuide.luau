--!strict
-- Round 9 part 14: the Zones menu's Locate button. For about 10 s a Beam of chevrons runs from the player to the ruin of the next portal, a
-- light pillar stands on it and a small wooden label shows the distance (Config/PortalRuins.Locate). It uses the stored anchors, so it works
-- from any zone. A few Beams and one label: nothing runs per frame. It stops when the player is teleported or dies and when the zone opens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PortalRuins = require(ReplicatedStorage.GameSystem.Config.PortalRuins)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local RuinGuide = {}

local player = Players.LocalPlayer
local running: { Instance }? = nil -- what the current guide has made

local function beam(from: Attachment, to: Attachment, color: Color3, width: number, parent: Instance): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = from
	b.Attachment1 = to
	b.Color = ColorSequence.new(color)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Brightness = PortalRuins.Locate.Brightness
	b.Width0 = width
	b.Width1 = width
	b.Segments = 1
	b.FaceCamera = true
	b.Parent = parent
	return b
end

function RuinGuide.stop()
	if running then
		for _, item in ipairs(running) do
			item:Destroy()
		end
		running = nil
	end
end

function RuinGuide.start(zoneId: string)
	RuinGuide.stop()
	local conf = PortalRuins.Zones[zoneId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (conf and root) then
		return
	end
	local locate = PortalRuins.Locate

	local mark = Instance.new("Part")
	mark.Name = "RuinGuide"
	mark.Size = Vector3.one
	mark.Transparency = 1
	mark.Anchored = true
	mark.CanCollide, mark.CanQuery, mark.CanTouch, mark.CastShadow = false, false, false, false
	mark.Position = conf.Anchor.Position + Vector3.new(0, 4, 0)
	local foot = Instance.new("Attachment")
	foot.Parent = mark
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, locate.PillarHeight, 0)
	top.Parent = mark
	local hip = Instance.new("Attachment")
	hip.Name = "RuinGuideStart"
	hip.Parent = root

	local line = beam(hip, foot, conf.Rune, locate.Width, mark)
	line.Texture = locate.Texture
	line.TextureMode = Enum.TextureMode.Static
	line.TextureLength = locate.TextureLength
	line.TextureSpeed = locate.TextureSpeed
	local pillar = beam(foot, top, conf.Rune, locate.PillarWidth, mark)

	local colors = Theme.Colors
	local screen = Instance.new("ScreenGui")
	screen.Name = "RuinGuideLabel"
	screen.ResetOnSpawn = false
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(300, 44)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	Theme.gradient(panel, colors.WoodLight, colors.WoodBottom)
	Theme.corner(panel, 8)
	Theme.stroke(panel, colors.GoldDark, 2)
	panel.Parent = screen
	local text = Theme.text({ Font = "Button", Text = "", TextSize = 24, Color = colors.Gold, Size = UDim2.fromScale(1, 1), Parent = panel })
	screen.Parent = player:WaitForChild("PlayerGui")
	mark.Parent = workspace

	local mine = { mark, hip, screen } :: { Instance }
	running = mine
	local name = Zones.ById[zoneId].Name
	local function show(from: BasePart)
		text.Text = `{name}: {math.round((from.Position - conf.Anchor.Position).Magnitude * locate.MetersPerStud)} m`
	end
	show(root)
	task.spawn(function()
		local start, last = os.clock(), root.Position
		while running == mine do
			task.wait(locate.Tick)
			if running ~= mine then
				return
			end
			if not root.Parent or (root.Position - last).Magnitude > locate.TeleportJump or Zones.isUnlocked(State.get("Zones"), zoneId) then
				RuinGuide.stop()
				return
			end
			last = root.Position
			show(root)
			local left = locate.Seconds - (os.clock() - start)
			if left <= 0 then
				RuinGuide.stop()
				return
			elseif left < locate.Fade then
				local see = NumberSequence.new(1 - left / locate.Fade)
				line.Transparency, pillar.Transparency = see, see
			end
		end
	end)
end

return RuinGuide
