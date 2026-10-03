--!strict
-- Shows each sub-zone gate as open or closed for THIS player (gates are unlocked per player).
-- The server still checks where the player stands, so an open-looking gate grants nothing by itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.GameSystem.Util.Format)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)

local GateController = {}

local OPEN_COLOR = Color3.fromRGB(91, 220, 110)
local PRICE_COLOR = Color3.fromRGB(255, 201, 60)
local REFRESH_SECONDS = 1 -- gates stream in and out, so the state is re-applied regularly

local collide: { [BasePart]: boolean } = {}

local function setGate(gate: Model, open: boolean, priceText: string)
	local barrier = gate.PrimaryPart or gate:FindFirstChild("Barrier", true)
	if barrier and barrier:IsA("BasePart") then
		local parts = barrier:GetDescendants()
		table.insert(parts, barrier)
		for _, part in ipairs(parts) do
			if part:IsA("BasePart") then
				if collide[part] == nil then
					collide[part] = part.CanCollide
				end
				part.CanCollide = collide[part] and not open
				part.LocalTransparencyModifier = if open then 1 else 0
			elseif part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Light") then
				part.Enabled = not open
			elseif part:IsA("ProximityPrompt") then
				part.Enabled = not open
			end
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
				setGate(gate, unlocked[id] == true, Format.number(Zones.subZonePrice(zoneId, n)) .. " Gold")
			end
		end
	end
end

function GateController:Start()
	State.Changed:Connect(function(key)
		if key == "SubZones" then
			refresh()
		end
	end)
	while true do
		refresh()
		task.wait(REFRESH_SECONDS)
	end
end

return GateController
