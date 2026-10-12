--!strict
-- Where an effect sits (OWNER: the VFX sub-agent): anchor points on the attacker and the attack frame.
--   Anchors.attachment(tool, name) -> Attachment?   e.g. "TipAttachment", searched once per Tool (cached), never by
--                                                   part names
--   Anchors.position(character, root, tool, kind) -> Vector3
--       kind: nil | "Root" (HumanoidRootPart), "Feet" (the ground under it), "Hand" (RightHand), or a Tool attachment
--       "Tip" | "Base" | "Muzzle" | "Impact" (falls back to the RightHand, then the root)
--   Anchors.frame(spec, character, root, tool, direction) -> CFrame
--       the anchor + Height (world up) + Offset { right, up, back } in the attack frame (looking along direction),
--       turned by Yaw (+ = left), Pitch (+ = up), Roll (+ raises the right side), in degrees
local Runner = require(script.Parent.Runner)

local Anchors = {}

local cache: { [Instance]: { [string]: Instance | false } } = setmetatable({}, { __mode = "k" }) :: any

function Anchors.attachment(tool: Instance?, name: string): Attachment?
	if not tool then
		return nil
	end
	local byName = cache[tool]
	if not byName then
		byName = {}
		cache[tool] = byName
	end
	local found = byName[name]
	if found == nil or (found and not found:IsDescendantOf(tool)) then
		local a = tool:FindFirstChild(name, true)
		found = if a and a:IsA("Attachment") then a else false
		byName[name] = found
	end
	return if found then found :: Attachment else nil
end

function Anchors.position(character: Instance, root: BasePart, tool: Instance?, kind: string?): Vector3
	if kind == nil or kind == "Root" then
		return root.Position
	elseif kind == "Feet" then
		return Runner.ground(root.Position, 0.5, 8) or (root.Position - Vector3.new(0, 3, 0))
	end
	if kind ~= "Hand" and tool and tool.Parent == character then
		local a = Anchors.attachment(tool, kind .. "Attachment")
		if a then
			return a.WorldPosition
		end
	end
	local hand = character:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		return hand.Position
	end
	return root.Position
end

function Anchors.frame(spec: any, character: Instance, root: BasePart, tool: Instance?, direction: Vector3): CFrame
	local at = Anchors.position(character, root, tool, spec.Anchor)
	if spec.Height then
		at += Vector3.new(0, spec.Height, 0)
	end
	local frame = CFrame.lookAt(at, at + direction)
	local o = spec.Offset
	if o then
		frame += frame:VectorToWorldSpace(Vector3.new(o[1], o[2], o[3]))
	end
	if spec.Yaw or spec.Pitch or spec.Roll then
		frame *= CFrame.fromEulerAnglesYXZ(math.rad(spec.Pitch or 0), math.rad(spec.Yaw or 0), math.rad(spec.Roll or 0))
	end
	return frame
end

return Anchors
