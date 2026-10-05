--!strict
-- Game-wide balance switches (docs/enemies_npcs_pets_brief.txt 1B).
local Balance = {}

-- Zone Boost: a weapon / armor piece used in its own zone gets its rarity's Zone Boost. DISABLED for now (owner): the
-- code and the Rarities numbers stay; the HUD badge and the tooltip lines are hidden while this is false.
Balance.ZoneBoostEnabled = false

return Balance
