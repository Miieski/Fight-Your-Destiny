--!strict
-- Procedural animation of the Pets V2 rigs (docs/pets_v2_plan.md section 4; rigs made by DevTools/PetRigBuilder).
-- No Animator, no uploaded animations: every frame each piece is turned around its joint and the whole set is
-- moved with one BulkMoveTo (anchored parts, no physics), like the old followers' PivotTo.
--   PetMotion.new(model) -> Motion?   nil for models without the "Gait" attribute (procedural placeholders)
--       call it after ScaleTo / PetLook.apply: it records the rest pose of every piece and its children (shells)
--   motion:step(rootCFrame, dt, speed, now)   rootCFrame = where the Root (feet, looking -Z) goes
--   motion:cheer(now)                         a happy jump (the owner killed an enemy)
-- Rig convention: PrimaryPart "Root" at the feet; pieces are BaseParts under the model named Body, Head, Tail,
-- LegFL / LegFR / LegBL / LegBR, LegsF / LegsB, LegL / LegR, ArmL / ArmR, WingL / WingR, FinL / FinR / FinTop,
-- ClawL / ClawR, Tentacles, or anything else (rides on the Body, or on the Head when its "Rides" attribute is
-- "Head"); each may hold an Attachment "Joint" = its pivot. Model attribute Gait = Walk | Hop | Fly | Swim |
-- Float | Slither.
local PetMotion = {}
PetMotion.__index = PetMotion

type Kid = { part: BasePart, offset: CFrame }
type Piece = { part: BasePart, role: string, rest: CFrame, joint: Vector3, kids: { Kid }, rides: string }

local STEP_SPEED = 9 -- leg swings per second (radians / s) at full walk
local HAPPY_TIME = 0.6

local function rotAbout(joint: Vector3, rx: number, ry: number, rz: number): CFrame
	return CFrame.new(joint) * CFrame.Angles(rx, ry, rz) * CFrame.new(-joint)
end

-- smooth value noise in [-1, 1] (looking around)
local function wander(t: number, seed: number): number
	return math.sin(t * 0.61 + seed) * 0.6 + math.sin(t * 1.37 + seed * 2.3) * 0.4
end

local ROLES = {
	Body = true, Head = true, Tail = true, LegFL = true, LegFR = true, LegBL = true, LegBR = true, LegsF = true,
	LegsB = true, LegL = true, LegR = true, ArmL = true, ArmR = true, WingL = true, WingR = true, FinL = true,
	FinR = true, FinTop = true, ClawL = true, ClawR = true, Tentacles = true,
}

function PetMotion.new(model: Model): any
	local gait = model:GetAttribute("Gait")
	local root = model.PrimaryPart
	if typeof(gait) ~= "string" or not root then
		return nil
	end
	local rootCF = root.CFrame
	local pieces: { Piece } = {}
	local body: Piece? = nil
	for _, item in ipairs(model:GetChildren()) do
		if item:IsA("BasePart") and item ~= root then
			local jointAtt = item:FindFirstChild("Joint")
			local jointWorld = if jointAtt and jointAtt:IsA("Attachment") then jointAtt.WorldPosition else item.Position
			local kids: { Kid } = {}
			for _, kid in ipairs(item:GetDescendants()) do
				if kid:IsA("BasePart") then
					table.insert(kids, { part = kid, offset = item.CFrame:ToObjectSpace(kid.CFrame) })
				end
			end
			local rides = item:GetAttribute("Rides")
			local piece: Piece = {
				part = item,
				role = if ROLES[item.Name] then item.Name else "Extra",
				rest = rootCF:ToObjectSpace(item.CFrame),
				joint = rootCF:PointToObjectSpace(jointWorld),
				kids = kids,
				rides = if rides == "Head" then "Head" else "Body",
			}
			table.insert(pieces, piece)
			if piece.role == "Body" then
				body = piece
			end
		end
	end
	if #pieces == 0 then
		return nil
	end
	-- the head moves before the pieces riding on it
	table.sort(pieces, function(a, b)
		return (if a.role == "Body" then 0 elseif a.role == "Head" then 1 else 2) < (if b.role == "Body" then 0 elseif b.role == "Head" then 1 else 2)
	end)
	local _, size = model:GetBoundingBox()
	local parts: { BasePart } = { root }
	for _, piece in ipairs(pieces) do
		table.insert(parts, piece.part)
		for _, kid in ipairs(piece.kids) do
			table.insert(parts, kid.part)
		end
	end
	local self = setmetatable({
		model = model,
		root = root,
		gait = gait,
		pieces = pieces,
		bodyJoint = if body then body.joint else Vector3.new(0, size.Y * 0.4, 0),
		height = size.Y,
		parts = parts,
		cframes = table.create(#parts, CFrame.identity),
		move = 0,
		phase = (string.len(model.Name) % 7) * 0.9,
		happyStart = -100,
	}, PetMotion)
	return self
end

function PetMotion.cheer(self: any, now: number)
	if now - self.happyStart > HAPPY_TIME then
		self.happyStart = now
	end
end

function PetMotion.step(self: any, rootCF: CFrame, dt: number, speed: number, now: number)
	local h = self.height
	local target = math.clamp(speed / 10, 0, 1)
	self.move += (target - self.move) * (1 - math.exp(-8 * dt))
	local m = self.move
	local t = now + self.phase
	local gait = self.gait
	local walkT = t * STEP_SPEED
	local happyU = (now - self.happyStart) / HAPPY_TIME
	local happy = if happyU >= 0 and happyU < 1 then math.sin(happyU * math.pi) else 0

	-- body: bounce while walking, breathing at rest, sway / lean for the other gaits; the happy jump on top
	local bj = self.bodyJoint
	local B: CFrame
	if gait == "Walk" then
		local bob = math.abs(math.sin(walkT)) * 0.06 * h * m + (math.sin(t * 2.1) + 1) * 0.008 * h * (1 - m)
		B = CFrame.new(0, bob, 0) * rotAbout(bj, math.sin(walkT * 2) * 0.03 * m, 0, math.sin(walkT) * 0.035 * m)
	elseif gait == "Hop" then
		B = rotAbout(bj, -0.14 * m + math.sin(t * 2.4) * 0.03 * (1 - m), 0, 0)
	elseif gait == "Fly" then
		B = CFrame.new(0, math.sin(t * 3.2) * 0.03 * h, 0) * rotAbout(bj, -0.18 * m, 0, math.sin(t * 1.4) * 0.05)
	elseif gait == "Swim" then
		B = rotAbout(bj, math.sin(t * 1.7) * 0.04, math.sin(t * 3.4) * (0.1 + 0.08 * m), math.sin(t * 1.9) * 0.05)
	elseif gait == "Slither" then
		B = rotAbout(bj, 0, math.sin(t * 4) * (0.12 + 0.1 * m), 0)
	else -- Float
		B = CFrame.new(0, math.sin(t * 1.6) * 0.04 * h, 0) * rotAbout(bj, math.sin(t * 1.1) * 0.05, 0, math.sin(t * 1.5) * 0.08)
	end
	if happy > 0 then
		B = CFrame.new(0, happy * 0.45 * h, 0) * rotAbout(bj, happy * 0.25, 0, 0) * B
	end

	local headCF = B
	local parts = self.parts
	local cframes = self.cframes
	cframes[1] = rootCF
	local n = 1
	for _, piece in ipairs(self.pieces) do
		local role = piece.role
		local j = piece.joint
		local local_: CFrame
		if role == "Body" then
			local_ = B
		elseif role == "Head" then
			local nod = math.sin(walkT * 2) * 0.05 * m + math.sin(t * 1.3) * 0.04 * (1 - m) + happy * 0.2
			local look = wander(t, self.phase) * 0.35 * (1 - m)
			local tilt = math.sin(t * 0.9 + self.phase) * 0.06 * (1 - m) + happy * 0.15
			if gait == "Slither" then
				look -= math.sin(t * 4) * (0.12 + 0.1 * m) -- the head stays on course while the body waves
			end
			local_ = B * rotAbout(j, nod, look, tilt)
			headCF = local_
		elseif role == "Tail" then
			if gait == "Swim" then
				local_ = B * rotAbout(j, 0, math.sin(t * 6.5) * (0.4 + 0.2 * m), 0)
			elseif gait == "Slither" then
				local_ = B * rotAbout(j, 0, -math.sin(t * 4 - 0.8) * (0.3 + 0.15 * m), 0)
			elseif gait == "Fly" then
				local_ = B * rotAbout(j, math.sin(t * 3) * 0.12, 0, 0)
			else
				local wag = math.sin(t * (7 + 10 * happy)) * (0.3 + 0.25 * m + 0.3 * happy)
				local_ = B * rotAbout(j, math.sin(t * 2) * 0.05, wag, 0)
			end
		elseif role == "LegFL" or role == "LegBR" or role == "LegsF" or role == "LegL" then
			local swing = math.sin(walkT) * 0.5 * m
			local_ = (if gait == "Walk" or gait == "Hop" then CFrame.identity else B) * rotAbout(j, swing, 0, 0)
		elseif role == "LegFR" or role == "LegBL" or role == "LegsB" or role == "LegR" then
			local swing = math.sin(walkT + math.pi) * 0.5 * m
			local_ = (if gait == "Walk" or gait == "Hop" then CFrame.identity else B) * rotAbout(j, swing, 0, 0)
		elseif role == "ArmL" or role == "ArmR" then
			local side = if role == "ArmL" then -1 else 1
			local swing = math.sin(walkT + (if role == "ArmL" then math.pi else 0)) * 0.55 * m
			local wave = happy * 1.2 -- arms up for the cheer
			local_ = B * rotAbout(j, swing + math.sin(t * 1.8) * 0.04 * (1 - m) + wave * 0.6, 0, side * (0.05 + wave * 0.5))
		elseif role == "WingL" or role == "WingR" then
			local side = if role == "WingL" then -1 else 1
			local flap = if gait == "Fly" then math.sin(t * (11 + 4 * m)) * 0.65 else math.sin(t * 2.2) * 0.06 + happy * 0.6
			local_ = B * rotAbout(j, 0, 0, side * flap)
		elseif role == "FinL" or role == "FinR" then
			local side = if role == "FinL" then -1 else 1
			local_ = B * rotAbout(j, 0, side * math.sin(t * 6) * 0.35, side * math.sin(t * 6 + 1) * 0.15)
		elseif role == "FinTop" then
			local_ = B * rotAbout(j, 0, 0, math.sin(t * 3) * 0.08)
		elseif role == "ClawL" or role == "ClawR" then
			local snap = math.max(0, math.sin(t * 2.3 + (if role == "ClawL" then 0 else 1.7))) ^ 6
			local_ = B * rotAbout(j, snap * 0.35 + happy * 0.5, 0, 0)
		elseif role == "Tentacles" then
			local_ = B * rotAbout(j, math.sin(t * 2.8) * 0.12, 0, math.sin(t * 2.1) * 0.08)
		else
			local_ = if piece.rides == "Head" then headCF else B
		end
		local cf = rootCF * local_ * piece.rest
		n += 1
		cframes[n] = cf
		for _, kid in ipairs(piece.kids) do
			n += 1
			cframes[n] = cf * kid.offset
		end
	end
	if self.model:IsDescendantOf(workspace) then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, part in ipairs(parts) do
			part.CFrame = cframes[i]
		end
	end
end

return PetMotion
