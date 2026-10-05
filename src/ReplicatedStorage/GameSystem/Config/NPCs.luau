--!strict
-- Hub NPCs (docs/enemies_npcs_pets_brief.txt Part F). Each one stands on its hub marker (workspace.Hub.<Marker>,
-- on the marker's "NpcSpot" part when there is one) and its prompt opens a window. Models: ServerStorage.NPCs.<Id>
-- once the Blender FBX files are imported (DevTools.EnemyModels.fromImport), part-built placeholders until then.
local rgb = Color3.fromRGB

local NPCs = {}

NPCs.WAVE_RANGE = 15 -- studs: the NPC waves when a player comes this close
NPCs.LOOK_RANGE = 22 -- studs: the head follows the nearest player within this range
NPCs.HEIGHT = 6
NPCs.TALK_SECONDS = 3

export type NPC = {
	Id: string, Name: string, Marker: string, Window: string, Tab: string?, Action: string,
	Color: Color3, Accent: Color3, Hooked: boolean?, Tips: { string }?,
}

NPCs.List = {
	{ Id = "npc_guide", Name = "Guide", Marker = "TutorialGuide", Window = "Quests", Action = "Talk",
		Color = rgb(42, 160, 138), Accent = rgb(240, 138, 42), Tips = {
			"Hold attack to swing your weapon; Q rolls, right click blocks.",
			"Buy better weapons from the Blacksmith with the Gold enemies drop.",
			"Open the last gate of a zone, then beat its boss to reveal the next zone.",
			"Train your attributes with the Trainer, and hatch eggs at the Egg Station.",
			"Head trophies dropped by enemies sell well at the Trophy Merchant.",
		} },
	{ Id = "npc_blacksmith", Name = "Blacksmith", Marker = "WeaponShop", Window = "Shop", Tab = "Weapons", Action = "Shop",
		Color = rgb(200, 138, 96), Accent = rgb(106, 74, 46) },
	{ Id = "npc_trainer", Name = "Trainer", Marker = "Trainer", Window = "Stats", Action = "Train",
		Color = rgb(200, 64, 46), Accent = rgb(232, 224, 208) },
	{ Id = "npc_egg_keeper", Name = "Egg Keeper", Marker = "EggStation", Window = "Pets", Tab = "Eggs", Action = "Hatch eggs",
		Color = rgb(74, 106, 176), Accent = rgb(230, 200, 112), Hooked = true }, -- PetService already opens Pets > Eggs
	{ Id = "npc_trophy_merchant", Name = "Trophy Merchant", Marker = "TrophyMerchant", Window = "Inventory", Tab = "Trophies",
		Action = "Sell trophies", Color = rgb(122, 58, 138), Accent = rgb(122, 90, 54) },
	{ Id = "npc_priest", Name = "Priest", Marker = "RebirthAltar", Window = "RebirthShop", Action = "Talk",
		Color = rgb(242, 238, 228), Accent = rgb(138, 90, 232) },
	{ Id = "npc_gem_merchant", Name = "Gem Merchant", Marker = "DiamondShop", Window = "Shop", Tab = "Diamonds", Action = "Shop",
		Color = rgb(42, 58, 138), Accent = rgb(224, 176, 64) },
	{ Id = "npc_quartermaster", Name = "Quartermaster", Marker = "TeamBoard", Window = "Team", Action = "Teams",
		Color = rgb(58, 90, 58), Accent = rgb(224, 176, 64) },
} :: { NPC }

-- Other hub objects with a prompt and no NPC: marker -> window, tab, action text
NPCs.Boards = {
	CodesBoard = { Window = "Quests", Tab = "Codes", Action = "Redeem codes", Name = "Codes Board" },
	RebirthShop = { Window = "RebirthShop", Action = "Open", Name = "Rebirth Shop" },
}

NPCs.ById = {} :: { [string]: NPC }
for _, npc in ipairs(NPCs.List) do
	NPCs.ById[npc.Id] = npc
end

return NPCs
