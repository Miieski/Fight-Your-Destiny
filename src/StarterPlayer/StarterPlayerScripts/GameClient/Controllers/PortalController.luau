--!strict
-- Hub portals (docs/menu_systems_brief.txt section 1). Touching workspace.Hub.Portals.Portal_<ZoneId> asks the server to go
-- straight to sub-zone 1 of that zone (Net "UsePortal"; the server checks everything). The screen fades like the Zones menu.
-- Round 9 part 12: a portal exists only for players who have opened its zone. For the others, on this client only, nothing of it is
-- left: no part, sign, text, light, particle, sound, collision or touch (Hub.Portals.Portal_<Zone>, Hub.Decor.PortalFrames.PortalFrame_<Zone>,
-- Hub.Decor.VFX.Portal_Swirl_<Zone>); the Zones menu shows what it takes. When the zone opens the portal assembles from its real
-- bricks (Config/PortalBuild, Assets.PortalBricks), bottom up, keystone last, then it lights up. A zone open at join: finished at once.
-- A zone locked again: gone at once. A part that streams back in returns with the server's look, so it is hidden again on arrival.
-- Round 9 part 14: the NEXT portal stands in ruins instead (Controllers/PortalRuinController, Config/PortalRuins), and when its zone opens
-- the portal builds itself from them: the lying bricks fly back, the stumps grow, moss and cracks fade, the sign sinks, then it lights up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.GameSystem.Net)
local PortalBuild = require(ReplicatedStorage.GameSystem.Config.PortalBuild)
local PortalRuins = require(ReplicatedStorage.GameSystem.Config.PortalRuins)
local Sfx = require(ReplicatedStorage.GameSystem.Util.Sfx)
local Zones = require(ReplicatedStorage.GameSystem.Config.Zones)
local State = require(script.Parent.Parent.State)
local UI = script.Parent.Parent.UI
local Notifier = require(UI.Notifier)
local Fade = require(UI.Kit.Fade)
local ZoneVisibility = require(UI.Kit.ZoneVisibility)
local PortalRuinController = require(script.Parent.PortalRuinController)

local PortalController = { Priority = 20 }

local REFRESH_SECONDS = 1 -- safety net: DescendantAdded already re-hides what streams in
local CLEAR_SECONDS = 0.2 -- how often a finished portal looks whether the player has left its spot
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FX_CLASSES = { "ParticleEmitter", "Light", "Beam", "Trail", "Fire", "Smoke", "Sparkles", "LayerCollector", "ProximityPrompt", "Highlight" } -- all have Enabled

-- hidden: nothing at all. ghost: seen, no collision and no touch (the player stands on the spot). ramp: ghost while it lights up. shown: the server's look.
type Mode = "hidden" | "ghost" | "ramp" | "shown"
type SavedPart = { collide: boolean, touch: boolean, query: boolean, shadow: boolean }
type Brick = { root: BasePart, parts: { BasePart }, offsets: { CFrame }, target: CFrame, from: CFrame, at: number, flight: number, group: string, lying: boolean }

local player = Players.LocalPlayer
local busy = false
local lastTry: { [string]: number } = {} -- zone id -> os.clock() of the last refused try
local modes: { [string]: Mode } = {}
local pending: { [string]: boolean } = {} -- zone id -> opened just now, waits to assemble
local building: { [string]: number } = {} -- zone id -> token of the running assembly
local tokens = 0
local nextZone: string? = nil -- the portal that stands in ruins for this player
local fromRuin: { [string]: boolean } = {} -- zone id -> opened while it was the next one: it builds from its ruin
local softUntil = 0 -- os.clock(): until then a new ruin fades in
-- strong keys on purpose: a weak table can lose an Instance that is alive (its Lua wrapper is collected), and a part saved again
-- while hidden would stay hidden for good. About 40 instances per portal.
local savedParts: { [BasePart]: SavedPart } = {}
local savedFx: { [Instance]: boolean } = {}
local hooked: { [BasePart]: boolean } = {}
local watched: { [string]: boolean } = {}

local function hubChild(...: string): Instance?
	local item: Instance? = workspace:FindFirstChild("Hub")
	for _, name in ipairs({ ... }) do
		item = item and item:FindFirstChild(name)
	end
	return item
end

local function portalOf(zoneId: string): BasePart?
	local portal = hubChild("Portals", "Portal_" .. zoneId)
	return if portal and portal:IsA("BasePart") then portal else nil
end

local function frameOf(zoneId: string): Instance?
	return hubChild("Decor", "PortalFrames", "PortalFrame_" .. zoneId)
end

local function swirlOf(zoneId: string): Instance?
	return hubChild("Decor", "VFX", "Portal_Swirl_" .. zoneId)
end

local function isOpen(zoneId: string): boolean
	return Zones.isUnlocked(State.get("Zones"), zoneId)
end

local function applyPart(part: BasePart, mode: Mode)
	local saved = savedParts[part]
	if not saved then
		saved = { collide = part.CanCollide, touch = part.CanTouch, query = part.CanQuery, shadow = part.CastShadow }
		savedParts[part] = saved
	end
	local hidden = mode == "hidden"
	local solid = mode == "shown"
	part.CanCollide = saved.collide and solid
	part.CanTouch = saved.touch and solid
	part.CanQuery = saved.query and solid
	part.CastShadow = saved.shadow and not hidden
	part.LocalTransparencyModifier = if hidden then 1 else 0
end

local function applyFx(item: Instance, mode: Mode)
	if item:IsA("Decal") then -- a Texture is a Decal; the part's modifier does not reach them
		item.LocalTransparencyModifier = if mode == "hidden" then 1 else 0
	elseif item:IsA("Sound") then
		if savedFx[item] == nil then
			savedFx[item] = item.Playing
		end
		item.Playing = mode ~= "hidden" and savedFx[item]
	else
		for _, class in ipairs(FX_CLASSES) do
			if item:IsA(class) then
				local fx = item :: any
				if savedFx[item] == nil then
					savedFx[item] = fx.Enabled
				end
				fx.Enabled = mode ~= "hidden" and savedFx[item]
				if mode == "hidden" and item:IsA("ParticleEmitter") then
					item:Clear()
				end
				return
			end
		end
	end
end

local function apply(zoneId: string, mode: Mode)
	for _, root in ipairs({ portalOf(zoneId) :: Instance?, frameOf(zoneId), swirlOf(zoneId) } :: { Instance? }) do
		if root then
			local list = root:GetDescendants()
			table.insert(list, root)
			for _, item in ipairs(list) do
				if item:IsA("BasePart") then
					applyPart(item, mode)
				else
					applyFx(item, mode)
				end
			end
		end
	end
end

local function setMode(zoneId: string, mode: Mode)
	modes[zoneId] = mode
	apply(zoneId, mode)
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onSpot(portal: BasePart): boolean
	local root = rootPart()
	if not root then
		return false
	end
	local rel = portal.CFrame:PointToObjectSpace(root.Position)
	local clear = PortalBuild.Clearance
	return math.abs(rel.X) < clear.X and math.abs(rel.Y) < clear.Y and math.abs(rel.Z) < clear.Z
end

local function slowdown(): number
	return if RunService:IsStudio() then player:GetAttribute("PortalBuildSlow") or 1 else 1 -- for the filmstrip
end

-- The bricks, in the order they come, each at its start.
local function layOut(holder: Instance, origin: CFrame, frame: Instance, ruin: PortalRuinController.Ruin?): { Brick }
	local config = PortalBuild
	local build = PortalRuins.Build
	local random = Random.new()
	local realGem = frame:FindFirstChild("Gem") :: BasePart?
	local realKey = frame:FindFirstChild("Keystone") :: BasePart?
	local gemColor = if realGem then realGem.Color:Lerp(Color3.new(), config.GemDim) else nil
	local rank: { [string]: number } = {}
	for i, group in ipairs(config.Order) do
		rank[group] = i
	end
	local bricks: { Brick } = {}
	for _, root in ipairs(holder:GetChildren()) do
		if root:IsA("BasePart") then
			local group = root:GetAttribute("Group") :: string
			local target = origin * root.CFrame
			local parts: { BasePart }, offsets: { CFrame } = { root }, { CFrame.identity }
			for _, item in ipairs(root:GetDescendants()) do
				if item:IsA("BasePart") then
					table.insert(parts, item)
					table.insert(offsets, root.CFrame:ToObjectSpace(item.CFrame))
					if item:GetAttribute("Glow") and gemColor then
						item.Color = gemColor
					elseif item.Name == "NamePlate" then
						local real = frame:FindFirstChild("NamePlate")
						local gui = real and real:FindFirstChildWhichIsA("SurfaceGui")
						if gui then
							local copy = gui:Clone()
							copy.Enabled = true
							copy.Parent = item
						end
					end
				end
			end
			if group == "Keystone" and realKey then
				root.Color = realKey.Color
			end
			local lying = ruin and ruin.bricks[root:GetAttribute("BrickId") :: number]
			local kind = if ruin then build.Missing[group] else config.Force[group]
			local from: CFrame
			if lying then
				from = lying.CFrame
			elseif ruin and kind == "Pile" then
				local scatter = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * build.PileScatter
				from = CFrame.new(ruin.pile + scatter - Vector3.new(0, build.PileDrop, 0)) * target.Rotation
			else
				if not kind then
					local roll = random:NextNumber()
					for _, name in ipairs({ "Ground", "Sides", "Above" }) do
						kind = name
						roll -= config.Offsets[name].Chance
						if roll <= 0 then
							break
						end
					end
				end
				local spec = config.Offsets[kind]
				local far = random:NextNumber(spec.Min, spec.Max)
				local side = if random:NextNumber() < 0.5 then -1 else 1
				local shift = if kind == "Ground" then Vector3.new(0, -far, 0) elseif kind == "Above" then Vector3.new(0, far, 0) else Vector3.new(side * far, random:NextNumber(-1, 2), 0)
				local scatter = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * config.Scatter
				local start = (origin.Rotation * (shift + scatter)) + target.Position
				local spin = config.Spin
				from = CFrame.new(start) * target.Rotation * CFrame.Angles(random:NextNumber(-spin, spin), random:NextNumber(-spin, spin), random:NextNumber(-spin, spin))
			end
			if lying and (from.Position - target.Position).Magnitude < 0.02 and from.LookVector:Dot(target.LookVector) > 0.9999 then
				for k, part in ipairs(parts) do -- it has not moved: a stone of a stump or of the steps
					part.CFrame = target * offsets[k]
				end
			else
				table.insert(bricks, { root = root, parts = parts, offsets = offsets, target = target, from = from, at = 0, flight = if group == "Keystone" then config.KeystoneFlight else config.Flight, group = group, lying = lying ~= nil })
			end
		end
	end
	table.sort(bricks, function(a, b)
		if a.group ~= b.group then
			return rank[a.group] < rank[b.group]
		end
		local ya, yb = a.target.Position.Y, b.target.Position.Y
		if math.abs(ya - yb) > 0.01 then
			return ya < yb
		end
		return a.target.Position.X < b.target.Position.X
	end)
	local stones = #bricks - 1 -- the keystone has its own beat
	local span = config.Seconds - config.Flight - config.KeystoneFlight - config.KeystonePause
	for i, brick in ipairs(bricks) do
		if i == #bricks then
			brick.at = span + config.Flight + config.KeystonePause
		else
			brick.at = math.max(0, (i - 1) / math.max(1, stones - 1) * (span - config.Jitter) + random:NextNumber(0, config.Jitter))
		end
	end
	table.sort(bricks, function(a, b)
		return a.at < b.at
	end)
	return bricks
end

local function dustSpot(color: Color3): (BasePart, ParticleEmitter)
	local spot = Instance.new("Part")
	spot.Name = "PortalBuildDust"
	spot.Size = Vector3.one
	spot.Transparency = 1
	spot.Anchored = true
	spot.CanCollide, spot.CanQuery, spot.CanTouch, spot.CastShadow = false, false, false, false
	local fx = Instance.new("ParticleEmitter")
	fx.Texture = DUST_TEXTURE
	fx.Color = ColorSequence.new(color)
	fx.Rate = 0
	fx.Lifetime = NumberRange.new(0.5, 1)
	fx.Speed = NumberRange.new(1, 4)
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.6) })
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	fx.Parent = spot
	spot.Parent = workspace
	return spot, fx
end

-- The field, the moss, the gems and the lights come up. The real pieces are the ones lit: the bricks are gone.
local function activate(zoneId: string, token: number, portal: BasePart, spot: BasePart, fx: ParticleEmitter)
	local config = PortalBuild
	setMode(zoneId, "ghost")
	modes[zoneId] = "ramp"
	local frame = frameOf(zoneId)
	local gem = frame and frame:FindFirstChild("Gem") :: BasePart?
	local gemColor = gem and gem.Color
	local fades: { BasePart } = { portal }
	local moss = frame and frame:FindFirstChild("Moss") :: BasePart?
	if moss then
		table.insert(fades, moss)
	end
	local lights: { [Light]: number } = {}
	local swirl = swirlOf(zoneId)
	for _, item in ipairs(if swirl then swirl:GetDescendants() else {}) do
		if item:IsA("Light") then
			lights[item] = item.Brightness
		end
	end
	Sfx.play(config.LightSound, portal.Position)
	spot.Position = portal.Position
	fx.Color = ColorSequence.new(portal.Color)
	fx:Emit(config.PulseBurst)
	local start = os.clock()
	local seconds = config.RampSeconds * slowdown()
	while building[zoneId] == token do
		local a = math.clamp((os.clock() - start) / seconds, 0, 1)
		local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		for _, part in ipairs(fades) do
			part.LocalTransparencyModifier = 1 - e
		end
		if gem and gemColor then
			gem.Color = gemColor:Lerp(Color3.new(), config.GemDim * (1 - e))
		end
		for light, brightness in pairs(lights) do
			light.Brightness = brightness * e
		end
		if a >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if gem and gemColor then
		gem.Color = gemColor
	end
	for light, brightness in pairs(lights) do
		light.Brightness = brightness
	end
	for _, part in ipairs(fades) do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
end

local refresh: () -> ()

local function assemble(zoneId: string, token: number, portal: BasePart, frame: Instance, set: Instance, ruin: PortalRuinController.Ruin?)
	local config = PortalBuild
	local alive = function()
		return building[zoneId] == token
	end
	local holder = set:Clone()
	holder.Name = "PortalBuild_" .. zoneId
	local origin = portal.CFrame * CFrame.new(0, set:GetAttribute("PivotY") :: number, 0)
	local bricks = layOut(holder, origin, frame, ruin)
	for _, brick in ipairs(bricks) do
		for k, part in ipairs(brick.parts) do
			if brick.lying then
				part.CFrame = brick.from * brick.offsets[k]
			else
				part.LocalTransparencyModifier = 1
				part.CastShadow = false
			end
		end
	end
	local spot, fx = dustSpot(config.DustColor)
	holder.Parent = workspace
	if ruin then
		ruin.hideBricks() -- same frame: the flying copies stand exactly where the ruin's bricks were
	end
	local slow = slowdown()
	local style = config.Ease
	local start = os.clock()
	local active: { Brick } = {}
	local nextBrick, landed, sound = 1, 0, 0
	local moved: { BasePart }, poses: { CFrame } = {}, {}
	local worst, spent, frames = 0, 0, 0
	while alive() do
		local clock = os.clock()
		local now = (clock - start) / slow
		while bricks[nextBrick] and bricks[nextBrick].at <= now do
			table.insert(active, bricks[nextBrick])
			nextBrick += 1
		end
		table.clear(moved)
		table.clear(poses)
		for i = #active, 1, -1 do
			local brick = active[i]
			local a = math.clamp((now - brick.at) / brick.flight, 0, 1)
			local pose = brick.from:Lerp(brick.target, TweenService:GetValue(a, style, Enum.EasingDirection.Out))
			if brick.lying then
				pose += Vector3.new(0, math.sin(a * math.pi) * PortalRuins.Build.Arc, 0)
			end
			local fade = if brick.lying then 0 else math.clamp(1 - a / config.FadeIn, 0, 1)
			for k, part in ipairs(brick.parts) do
				table.insert(moved, part)
				table.insert(poses, pose * brick.offsets[k])
				part.LocalTransparencyModifier = fade
			end
			if a >= 1 then
				landed += 1
				for _, part in ipairs(brick.parts) do
					part.CastShadow = part:GetAttribute("Glow") == nil
				end
				if landed % config.DustEvery == 0 then
					spot.Position = brick.target.Position
					fx:Emit(config.DustBurst)
				end
				if brick.group == "Keystone" then
					Sfx.play(config.KeystoneSound, brick.target.Position)
				elseif landed % config.SoundEvery == 1 then
					sound = sound % #config.Sound + 1
					Sfx.play(config.Sound[sound], brick.target.Position)
				end
				active[i] = active[#active]
				table.remove(active)
			end
		end
		if #moved > 0 then
			workspace:BulkMoveTo(moved, poses, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if ruin then
			ruin.step(now / config.Seconds)
		end
		local cost = (os.clock() - clock) * 1000
		worst, spent, frames = math.max(worst, cost), spent + cost, frames + 1
		if nextBrick > #bricks and #active == 0 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if RunService:IsStudio() then
		player:SetAttribute("PortalBuildCost", string.format("%s: %d bricks, %d frames, %.3f ms mean, %.3f ms worst, %.2f s", zoneId, #bricks, frames, spent / math.max(frames, 1), worst, os.clock() - start))
	end
	holder:Destroy()
	if ruin then
		ruin.destroy()
	end
	if alive() then
		activate(zoneId, token, portal, spot, fx)
	end
	if alive() then
		-- finished: the player may stand where it has just appeared; it stays without collision until they walk out
		modes[zoneId] = "ghost"
		while alive() and onSpot(portal) do
			task.wait(CLEAR_SECONDS)
		end
	end
	task.delay(1.5, function()
		spot:Destroy()
	end)
	if alive() then
		building[zoneId] = nil
		setMode(zoneId, "shown")
	end
	refresh()
end

local function brickSet(frame: Instance): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local sets = assets and assets:FindFirstChild("PortalBricks")
	return sets and sets:FindFirstChild(tostring(frame:GetAttribute("MapPropId")))
end

-- A zone that opened: it assembles when its portal is streamed in and the player is near, at most MaxAtOnce at a time.
local function tryAssemble(zoneId: string)
	local portal, frame = portalOf(zoneId), frameOf(zoneId)
	local root = rootPart()
	if not (portal and frame and root and frame:FindFirstChild("Keystone") and frame:FindFirstChild("Gem")) then
		return
	end
	if (root.Position - portal.Position).Magnitude >= PortalBuild.Range then
		return
	end
	local running = 0
	for _ in pairs(building) do
		running += 1
	end
	if running >= PortalBuild.MaxAtOnce then
		return
	end
	pending[zoneId] = nil
	local set = brickSet(frame)
	if not set then
		warn(`PortalController: no bricks for {zoneId}, shown finished`)
		return
	end
	tokens += 1
	building[zoneId] = tokens
	local ruin = if fromRuin[zoneId] then PortalRuinController.take(zoneId) else nil
	fromRuin[zoneId] = nil
	task.spawn(assemble, zoneId, tokens, portal, frame, set, ruin)
end

local function use(zoneId: string)
	if busy or modes[zoneId] ~= "shown" or not isOpen(zoneId) then
		return
	end
	local now = os.clock()
	if now - (lastTry[zoneId] or -math.huge) < Zones.TELEPORT.PortalRetry then
		return
	end
	busy = true
	local zone = Zones.ById[zoneId]
	local expectOk = zone ~= nil and not Zones.NOT_BUILT[zoneId]
	if expectOk then
		Fade.cover()
	end
	local called, ok, message = pcall(Net.request, "UsePortal", zoneId)
	ok = called and ok == true
	if ok then
		Sfx.play("PortalEnter")
		lastTry[zoneId] = nil
	else
		lastTry[zoneId] = os.clock()
		Sfx.play("Denied")
	end
	Notifier.push({ Kind = if ok then "info" else "error", Text = tostring(if called then message or "Portal failed" else "Portal failed"), Icon = if ok and ZoneVisibility.isRevealed(zoneId) then zoneId else "Lock" })
	if expectOk then
		Fade.reveal(ok)
	end
	busy = false
end

local function hook(zoneId: string, portal: BasePart)
	if not hooked[portal] then
		hooked[portal] = true
		portal.Touched:Connect(function(hit)
			local character = player.Character
			if character and hit:IsDescendantOf(character) then
				task.spawn(use, zoneId)
			end
		end)
	end
end

-- The next portal's ruin, and the ruin of a zone that opened and waits to build. Later locked portals stay as they are: nothing.
local function syncRuins()
	nextZone = PortalRuins.nextZone(State.get("Zones"))
	local wanted: { [string]: boolean } = {}
	if nextZone then
		wanted[nextZone] = true
	end
	for id in pairs(fromRuin) do
		if pending[id] then
			wanted[id] = true
		else
			fromRuin[id] = nil
		end
	end
	PortalRuinController.sync(wanted, os.clock() < softUntil)
end

refresh = function()
	syncRuins()
	for _, zone in ipairs(Zones.List) do
		local zoneId = zone.Id
		local portal = portalOf(zoneId)
		if portal then
			hook(zoneId, portal)
		end
		if not isOpen(zoneId) then
			pending[zoneId], building[zoneId] = nil, nil -- silently gone, an assembly under way stops
			setMode(zoneId, "hidden")
		elseif pending[zoneId] then
			setMode(zoneId, "hidden")
			tryAssemble(zoneId)
		elseif building[zoneId] then
			if modes[zoneId] ~= "ramp" then
				apply(zoneId, modes[zoneId] or "hidden") -- what streamed in meanwhile
			end
		elseif modes[zoneId] ~= "shown" then
			setMode(zoneId, "shown")
		end
	end
end

-- Parts that stream in come with the server's look: put right in the same frame.
local function watch()
	local queued = false
	local function queue()
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				refresh()
			end)
		end
	end
	for name, folder in pairs({ Portals = hubChild("Portals"), PortalFrames = hubChild("Decor", "PortalFrames"), VFX = hubChild("Decor", "VFX") }) do
		if folder and not watched[name] then
			watched[name] = true
			folder.DescendantAdded:Connect(function(item)
				if name ~= "VFX" or string.find(item:GetFullName(), "Portal_Swirl_", 1, true) then
					queue()
				end
			end)
		end
	end
end

function PortalController:Start()
	State.changed("Zones", function(new: any, old: any)
		-- old is nil at join: what is open then is simply there, no animation
		if typeof(new) == "table" and typeof(old) == "table" then
			for id, open in pairs(new) do
				if open == true and old[id] ~= true and Zones.ById[id] then
					pending[id] = true
					fromRuin[id] = id == nextZone or nil
				end
			end
			softUntil = os.clock() + 1
		end
		refresh()
	end)
	if RunService:IsStudio() then
		-- tests: a portal that cannot be locked (Plains) assembles too
		player:GetAttributeChangedSignal("PortalBuildTest"):Connect(function()
			local id = player:GetAttribute("PortalBuildTest")
			if typeof(id) == "string" and Zones.ById[id] then
				pending[id] = true
				refresh()
			end
		end)
	end
	while true do
		watch()
		refresh()
		task.wait(REFRESH_SECONDS)
	end
end

return PortalController
