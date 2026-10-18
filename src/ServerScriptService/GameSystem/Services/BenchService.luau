--!strict
-- Hub benches (owner 2026-10-18: "Remake the bench ... and make a functionality where you can sit on it"): every
-- model in workspace.Hub that holds Seat parts (the hub benches, 2 seats each) gets ONE "Sit" prompt (E key / tap)
-- in its middle; it seats the player on the free seat nearest to them. Seat.CanTouch is off, so nobody sits by
-- running past. Jumping stands up (Roblox default). The prompt hides while every seat of the bench is taken.
local BenchService = { Priority = 60 }

local PROMPT_DISTANCE = 7 -- studs from the bench's middle
local PROMPT_HEIGHT = 1.5 -- studs above the seats

local hooked: { [Instance]: boolean } = {}

local function seatsOf(bench: Instance): { Seat }
	local seats = {}
	for _, child in ipairs(bench:GetDescendants()) do
		if child:IsA("Seat") then
			table.insert(seats, child)
		end
	end
	return seats
end

local function hook(bench: Model)
	if hooked[bench] then
		return
	end
	local seats = seatsOf(bench)
	if #seats == 0 then
		return
	end
	hooked[bench] = true
	local middle = Vector3.zero
	for _, seat in ipairs(seats) do
		seat.CanTouch = false -- the prompt seats players, touching does not
		middle += seat.Position
	end
	middle /= #seats
	-- the prompt hangs on an attachment in the middle of the bench, a little above the seats
	local first = seats[1]
	local point = Instance.new("Attachment")
	point.Name = "SitPoint"
	point.Parent = first
	point.WorldPosition = middle + Vector3.new(0, PROMPT_HEIGHT, 0)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Sit"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = point

	local function refresh()
		local free = false
		for _, seat in ipairs(seats) do
			if seat.Occupant == nil then
				free = true
			end
		end
		prompt.Enabled = free
	end
	for _, seat in ipairs(seats) do
		seat:GetPropertyChangedSignal("Occupant"):Connect(refresh)
	end
	refresh()

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
			return
		end
		if (root.Position - middle).Magnitude > PROMPT_DISTANCE + 4 then
			return
		end
		local best, bestDistance = nil, math.huge
		for _, seat in ipairs(seats) do
			local distance = (seat.Position - root.Position).Magnitude
			if seat.Occupant == nil and not seat.Disabled and distance < bestDistance then
				best, bestDistance = seat, distance
			end
		end
		if best then
			best:Sit(humanoid)
		end
	end)
end

local function benchOf(seat: Seat): Model?
	return seat:FindFirstAncestorOfClass("Model")
end

function BenchService:Start()
	local hub = workspace:FindFirstChild("Hub")
	if not hub then
		return
	end
	for _, child in ipairs(hub:GetDescendants()) do
		if child:IsA("Seat") then
			local bench = benchOf(child)
			if bench then
				hook(bench)
			end
		end
	end
	hub.DescendantAdded:Connect(function(child)
		if child:IsA("Seat") then
			task.defer(function()
				local bench = benchOf(child)
				if bench then
					hook(bench)
				end
			end)
		end
	end)
end

return BenchService
