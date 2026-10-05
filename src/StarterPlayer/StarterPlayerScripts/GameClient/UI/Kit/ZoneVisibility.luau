--!strict
-- No spoilers for locked zones (docs/enemies_npcs_pets_brief.txt 1A). A zone the player has not unlocked (not in
-- profile.Zones; zone 1 always is) is a BLACK SILHOUETTE with "?" marks and the name "???" in every UI. No UI
-- reads a zone's name, boss, sub-zones, description or icon colors from Config directly; they ask here:
--   ZoneVisibility.isRevealed(zoneId)            "Hub" / nil = true
--   ZoneVisibility.displayName(zoneId), bossName(zoneId), subZoneName(zoneId, n), description(zoneId)
--   ZoneVisibility.requirement(zoneId, short?)    the generic text of Config/Zones (never the real requirements)
--   ZoneVisibility.displayIcon(zoneId)            the icon id to draw (silhouetted by icon / applySilhouette)
--   ZoneVisibility.icon(iconId, zoneId, parent, props) -> Icons.create(...), already black with "?" when hidden
--   ZoneVisibility.applySilhouette(holder), removeSilhouette(holder)   for icons, ImageLabels and ViewportFrames
--   ZoneVisibility.changed(fn) -> disconnect      fn() when the unlocked zones change
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local ZoneVisibility = {}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local MARKS = "MysteryMarks"

function ZoneVisibility.isRevealed(zoneId: string?): boolean
	return Zones.isUnlocked(State.get("Zones"), zoneId)
end

function ZoneVisibility.displayName(zoneId: string?): string
	if zoneId == nil or zoneId == "Hub" then
		return "Hub"
	end
	local zone = Zones.ById[zoneId]
	if not zone then
		return Zones.HIDDEN_NAME
	end
	return if ZoneVisibility.isRevealed(zoneId) then zone.Name else Zones.HIDDEN_NAME
end

function ZoneVisibility.bossName(zoneId: string?): string
	local zone = zoneId and Zones.ById[zoneId]
	return if zone and ZoneVisibility.isRevealed(zoneId) then zone.Boss else Zones.HIDDEN_NAME
end

function ZoneVisibility.subZoneName(zoneId: string?, n: number): string
	local zone = zoneId and Zones.ById[zoneId]
	return if zone and ZoneVisibility.isRevealed(zoneId) then zone.SubZones[n] or Zones.HIDDEN_NAME else Zones.HIDDEN_NAME
end

function ZoneVisibility.description(zoneId: string?): string
	return if zoneId and ZoneVisibility.isRevealed(zoneId) then (Zones.Descriptions and Zones.Descriptions[zoneId] or "") else "A mystery for now."
end

function ZoneVisibility.requirement(zoneId: string?, short: boolean?): string
	return if short then Zones.HIDDEN_SHORT else Zones.HIDDEN_REQUIREMENT
end

-- The zone's own icon id (the diorama); "Zones" when there is no icon for it.
function ZoneVisibility.displayIcon(zoneId: string?): string
	return if zoneId and Icons.asset(zoneId) then zoneId else "Zones"
end

-- Black silhouette + "?" marks on an icon holder, an ImageLabel or a ViewportFrame (and on what it contains).
function ZoneVisibility.applySilhouette(target: Instance)
	local function paint(item: Instance)
		if item:IsA("ImageLabel") or item:IsA("ImageButton") then
			item.ImageColor3 = BLACK
		elseif item:IsA("ViewportFrame") then
			item.ImageColor3 = BLACK
			item.Ambient = BLACK
			item.LightColor = BLACK
		elseif item:IsA("Frame") and item.Name ~= MARKS and item.BackgroundTransparency < 1 and not item:FindFirstAncestor(MARKS) then
			-- flat placeholder shapes of Kit/Icons
			if item:GetAttribute("RevealColor") == nil then
				item:SetAttribute("RevealColor", item.BackgroundColor3)
			end
			item.BackgroundColor3 = Color3.fromRGB(14, 12, 16)
		end
	end
	paint(target)
	for _, item in ipairs(target:GetDescendants()) do
		paint(item)
	end
	if target:IsA("GuiObject") and not target:FindFirstChild(MARKS) then
		local marks = Instance.new("Frame")
		marks.Name = MARKS
		marks.BackgroundTransparency = 1
		marks.Size = UDim2.fromScale(1, 1)
		marks.ZIndex = target.ZIndex + 2
		Theme.text({ Font = "Title", Text = "?", TextSize = 60, Size = UDim2.fromScale(0.62, 0.72), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 3, ZIndex = target.ZIndex + 3, Parent = marks })
		local small = Theme.text({ Font = "Title", Text = "?", TextSize = 28, Size = UDim2.fromScale(0.3, 0.36), Position = UDim2.fromScale(0.16, 0.2), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2, ZIndex = target.ZIndex + 3, Parent = marks })
		small.Rotation = -16
		marks.Parent = target
	end
end

function ZoneVisibility.removeSilhouette(target: Instance)
	local function restore(item: Instance)
		if item:IsA("ImageLabel") or item:IsA("ImageButton") then
			item.ImageColor3 = WHITE
		elseif item:IsA("Frame") and item:GetAttribute("RevealColor") ~= nil then
			item.BackgroundColor3 = item:GetAttribute("RevealColor") :: Color3
			item:SetAttribute("RevealColor", nil)
		end
	end
	restore(target)
	for _, item in ipairs(target:GetDescendants()) do
		restore(item)
	end
	local marks = target:FindFirstChild(MARKS)
	if marks then
		marks:Destroy()
	end
end

-- An icon that is already a silhouette when its zone is hidden.
function ZoneVisibility.icon(iconId: string, zoneId: string?, parent: Instance?, props: { [string]: any }?): Frame
	local holder = Icons.create(iconId, parent, props)
	if zoneId and not ZoneVisibility.isRevealed(zoneId) then
		ZoneVisibility.applySilhouette(holder)
	end
	return holder
end

function ZoneVisibility.changed(fn: () -> ()): () -> ()
	return State.changed("Zones", function()
		fn()
	end)
end

return ZoneVisibility
