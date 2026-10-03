--!strict
-- Server loader: requires every module in Services, then runs Init and Start by Priority.
local services = {}
for _, module in ipairs(script.Parent.Services:GetChildren()) do
	if module:IsA("ModuleScript") then
		local service = require(module) :: any
		service.Name = module.Name
		table.insert(services, service)
	end
end
table.sort(services, function(a, b)
	return (a.Priority or 50) < (b.Priority or 50)
end)
for _, service in ipairs(services) do
	if service.Init then
		service:Init()
	end
end
for _, service in ipairs(services) do
	if service.Start then
		task.spawn(service.Start, service)
	end
end
