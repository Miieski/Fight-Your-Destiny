--!strict
-- Boss rooms (docs/enemies_npcs_pets_brief.txt Part C). Minimal rooms: no boss patterns yet - the next step fills
-- Bosses.Patterns from docs/boss_patterns_document.txt and BossService.OnEnrage.
local Bosses = {}

Bosses.LOBBY_SECONDS = 5 -- countdown in the room before the door locks
Bosses.INTRO_SECONDS = 2 -- boss roar + name banner, invulnerable
Bosses.CLEANUP_SECONDS = 15 -- after the boss dies: rewards screen, then back to sub-zone 4
Bosses.FAIL_SECONDS = 4 -- everyone dead: the room closes after this
Bosses.MAX_PLAYERS = 5
Bosses.HP_PER_EXTRA_PLAYER = 0.6 -- boss HP x (1 + 0.6 x (players - 1))
Bosses.REWARD_MIN_SHARE = 0.05 -- a player needs 5% of an enemy's HP in damage to be rewarded for it
Bosses.GATE_RANGE = 30 -- studs from the gate to use it
Bosses.ENRAGE_AT = 0.5 -- OnEnrage() runs once when the boss falls under this HP fraction
Bosses.SPECTATOR_HEIGHT = 28 -- dead players watch from this high above the player spawns
Bosses.PLAYABLE_ZONES = 4 -- zones with enemy data (1-4)

-- [zoneId] = ordered list of pattern ids (next step: docs/boss_patterns_document.txt). Empty = basic attack only.
Bosses.Patterns = {
	Plains = {},
	Desert = {},
	Jungle = {},
	Tundra = {},
} :: { [string]: { string } }

return Bosses
