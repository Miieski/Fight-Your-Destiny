--!strict
-- Client loader: requires every module in Controllers and UI, then runs Init and Start by Priority.
local modules = {}
for _, folderName in ipairs({ "Controllers", "UI" }) do
	for _, module in ipairs(script.Parent:WaitForChild(folderName):GetChildren()) do
		if module:IsA("ModuleScript") then
			local loaded = require(module) :: any
			loaded.Name = module.Name
			table.insert(modules, loaded)
		end
	end
end
table.sort(modules, function(a, b)
	return (a.Priority or 50) < (b.Priority or 50)
end)
for _, module in ipairs(modules) do
	if module.Init then
		module:Init()
	end
end
for _, module in ipairs(modules) do
	if module.Start then
		task.spawn(module.Start, module)
	end
end
