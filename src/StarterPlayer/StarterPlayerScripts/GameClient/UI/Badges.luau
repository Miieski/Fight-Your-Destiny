--!strict
-- BadgeRegistry (docs/ui_hud_brief.txt section 4.8): the red count on each menu button.
-- Each id reads State. Until the real systems exist, counts also come from the admin command
-- setBadge (State "DebugBadges", not saved). Settings never shows a badge.
local State = require(script.Parent.Parent.State)

local Badges = {}

type Entry = { Keys: { string }, Count: () -> number }

local function debugCount(id: string): number
	local values = State.get("DebugBadges")
	return if typeof(values) == "table" then tonumber(values[id]) or 0 else 0
end

local function debugOnly(id: string): Entry
	return { Keys = { "DebugBadges" }, Count = function()
		return debugCount(id)
	end }
end

local REGISTRY: { [string]: Entry } = {
	Inventory = debugOnly("Inventory"), -- later: new loot not seen yet
	Quests = debugOnly("Quests"), -- later: claimable quests
	Index = debugOnly("Index"), -- later: claimable Index rewards
	Pets = debugOnly("Pets"), -- later: new pets
	Shop = debugOnly("Shop"), -- later: new reward / daily
	RebirthShop = { Keys = { "DebugBadges", "RebirthCredits" }, Count = function() -- unspent Rebirth Credits
		return math.max(debugCount("RebirthShop"), tonumber(State.get("RebirthCredits")) or 0)
	end },
	Settings = { Keys = {}, Count = function()
		return 0
	end },
}

function Badges.count(id: string): number
	local entry = REGISTRY[id]
	return if entry then entry.Count() else 0
end

-- Calls fn(count) now and whenever the count may have changed.
function Badges.watch(id: string, fn: (number) -> ())
	local entry = REGISTRY[id]
	if not entry then
		return
	end
	fn(entry.Count())
	for _, key in ipairs(entry.Keys) do
		State.changed(key, function()
			fn(entry.Count())
		end)
	end
end

return Badges
