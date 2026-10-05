--!strict
-- Hub NPCs (docs/enemies_npcs_pets_brief.txt Part F, Config/NPCs): each NPC stands on its marker
-- (workspace.Hub.<Marker>.NpcSpot, else next to the marker's prompt) facing the plaza, in workspace.Hub.NPCs; the
-- marker's ProximityPrompt becomes "Talk"-style and opens the NPC's window (Net "OpenWindow"). The Guide also gives a
-- tip. Body: ServerStorage.NPCs.<Id> (imported Blender model) or a part-built placeholder (Lib/EnemyRigs, Biped).
-- The client (Controllers/NPCController) animates them: Idle, Wave within 15 studs, head turn, Talk.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local NPCs = require(ReplicatedStorage.GameSystem.Config.NPCs)
local Net = require(ReplicatedStorage.GameSystem.Net)
local EnemyRigs = require(script.Parent.Parent.Lib.EnemyRigs)

local NPCService = { Priority = 8 }

local tipIndex: { [Player]: number } = {}

local function bodyOf(npc: any): Model
	local folder = ServerStorage:FindFirstChild("NPCs")
	local imported = folder and folder:FindFirstChild(npc.Id)
	if imported and imported:IsA("Model") and imported.PrimaryPart then
		return imported:Clone()
	end
	local model = EnemyRigs.build({
		Id = npc.Id, Rig = "Biped", Height = NPCs.HEIGHT, Color = npc.Color, Accent = npc.Accent,
		Eyes = Color3.fromRGB(20, 18, 24), Tier = "normal", AttackType = "melee",
	})
	model:SetAttribute("Placeholder", true)
	return model
end

local function place(npc: any, marker: Instance, folder: Instance, facePoint: Vector3): Model?
	local old = marker:FindFirstChild("NPC")
	local spot = marker:FindFirstChild("NpcSpot")
	local position: Vector3
	if spot and spot:IsA("BasePart") then
		position = spot.Position - Vector3.new(0, spot.Size.Y / 2, 0)
	elseif old and old:IsA("Model") then
		local cf, size = old:GetBoundingBox()
		position = cf.Position - Vector3.new(0, size.Y / 2, 0)
	else
		local prompt = marker:FindFirstChildWhichIsA("ProximityPrompt", true)
		local anchor = prompt and prompt.Parent
		local base = if anchor and anchor:IsA("BasePart") then anchor.Position else (marker :: any):GetPivot().Position
		position = Vector3.new(base.X, (marker :: any):GetPivot().Position.Y, base.Z) + Vector3.new(3, 0, 0)
	end
	if old and old:IsA("Model") then
		old:Destroy() -- the world builder's stand-in
	end
	local model = bodyOf(npc)
	model.Name = npc.Id
	local look = Vector3.new(facePoint.X, position.Y, facePoint.Z)
	if (look - position).Magnitude < 0.5 then
		look = position - Vector3.zAxis
	end
	model:PivotTo(CFrame.lookAt(position, look))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = part == model.PrimaryPart
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	if model.PrimaryPart then
		model.PrimaryPart.CanCollide = true -- players bump into the NPC instead of walking through it
	end
	model:SetAttribute("NpcId", npc.Id)
	model:SetAttribute("NpcName", npc.Name)
	model.Parent = folder
	return model
end

local function open(player: Player, window: string, tab: string?)
	Net.fire(player, "OpenWindow", window, tab)
end

local function hook(prompt: ProximityPrompt, name: string, action: string, onTrigger: (Player) -> ())
	prompt.ActionText = action
	prompt.ObjectText = name
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onTrigger)
end

function NPCService:Start()
	local hub = workspace:FindFirstChild("Hub")
	if not hub then
		return
	end
	local folder = hub:FindFirstChild("NPCs") or Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = hub
	local spawn = hub:FindFirstChildOfClass("SpawnLocation")
	local facePoint = if spawn then spawn.Position else Vector3.new(0, 0, -50)
	for _, npc in ipairs(NPCs.List) do
		local marker = hub:FindFirstChild(npc.Marker)
		if not marker then
			warn(`NPCService: workspace.Hub.{npc.Marker} not found ({npc.Id})`)
			continue
		end
		local model = place(npc, marker, folder, facePoint)
		local prompt = marker:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt and model and model.PrimaryPart then
			prompt = Instance.new("ProximityPrompt")
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.Parent = model.PrimaryPart
		end
		if prompt then
			prompt:SetAttribute("NpcId", npc.Id)
			if npc.Hooked then
				prompt.ObjectText = npc.Name -- the service of the marker already opens the window
			else
				hook(prompt, npc.Name, npc.Action, function(player: Player)
					open(player, npc.Window, npc.Tab)
					if npc.Tips then
						local i = (tipIndex[player] or 0) % #npc.Tips + 1
						tipIndex[player] = i
						Net.fire(player, "Notify", { Kind = "info", Text = `{npc.Name}: {npc.Tips[i]}`, Icon = "Info" })
					end
				end)
			end
		end
	end
	for markerName, board in pairs(NPCs.Boards) do
		local marker = hub:FindFirstChild(markerName)
		local prompt = marker and marker:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			hook(prompt, board.Name, board.Action, function(player: Player)
				open(player, board.Window, board.Tab)
			end)
		end
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		tipIndex[player] = nil
	end)
end

return NPCService
