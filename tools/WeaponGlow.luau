--!strict
-- Glow of the V2 weapon meshes. Studio's 3D Importer merges the "<id>_Glow" faces of each FBX into the one textured
-- MeshPart, so the glow comes back as a SurfaceAppearance emissive mask: white where the glow faces are, in the same
-- UV layout as the baked color map (made by tools/blender/weapon_emissive_masks.py from Blender/Weapons/**/*.blend,
-- ids in Blender/Weapons/weapons_emissive_ids.json). ApplyWeaponMeshes calls it after swapping the meshes; alone:
--   require(game.ServerStorage.DevTools.WeaponGlow)()   -- every Tool of ReplicatedStorage.Assets.Weapons
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local STRENGTH = 1.5 -- emissive multiplier: the baked glow color stays readable instead of clipping to white

local MASKS: { [string]: number } = {
	abyss_dagger = 86376825948107,
	abyss_heavy = 110447539434455,
	abyss_magic = 77436852276523,
	abyss_ranged = 102276062529906,
	abyss_spear = 93619415567401,
	abyss_sword = 137357709604962,
	dead_dagger = 127790139343151,
	dead_heavy = 107296869583785,
	dead_magic = 123997572280749,
	dead_ranged = 108567511812334,
	dead_spear = 102190246335013,
	dead_sword = 135680866714623,
	desert_magic = 95026299787313,
	heaven_dagger = 132243858880899,
	heaven_heavy = 98244276225458,
	heaven_magic = 74250294540185,
	heaven_ranged = 96924814138539,
	heaven_spear = 84362621664942,
	heaven_sword = 86906430710489,
	hell_dagger = 75451147842063,
	hell_heavy = 104122259079486,
	hell_magic = 117019444863419,
	hell_ranged = 130542500740366,
	hell_spear = 122650928320721,
	hell_sword = 130982537484501,
	jungle_dagger = 109395492924915,
	jungle_magic = 77283927166548,
	jungle_ranged = 93628763328427,
	mechanical_dagger = 72696324127771,
	mechanical_heavy = 104870193240253,
	mechanical_magic = 94791630965722,
	mechanical_ranged = 128268743631283,
	mechanical_spear = 100933420581474,
	mechanical_sword = 70759591090808,
	plains_magic = 120351797522594,
	swamp_dagger = 74991873623319,
	swamp_heavy = 85323463792240,
	swamp_magic = 124683822497189,
	swamp_ranged = 127971376351327,
	swamp_spear = 124451008250303,
	swamp_sword = 89495384550742,
	tundra_dagger = 126709182058879,
	tundra_heavy = 119693242464048,
	tundra_magic = 127482770397748,
	tundra_ranged = 119318014309712,
	tundra_spear = 75429393738105,
	tundra_sword = 130604322947363,
	void_dagger = 96048261629009,
	void_heavy = 115264015476743,
	void_magic = 82887425210896,
	void_ranged = 127691682443801,
	void_spear = 139878073508708,
	void_sword = 103962557390827,
	volcano_dagger = 110698502620025,
	volcano_heavy = 104584190190282,
	volcano_magic = 109020901631469,
	volcano_ranged = 135263644233319,
	volcano_spear = 108036397942302,
	volcano_sword = 116075069463230,
}

local function apply(tool: Instance): boolean
	local id = tool:GetAttribute("WeaponId") or tool.Name
	local mask = MASKS[id]
	local handle = tool:FindFirstChild("Handle")
	local appearance = handle and handle:FindFirstChildWhichIsA("SurfaceAppearance")
	if not (mask and appearance) then
		return false
	end
	local sa = appearance :: SurfaceAppearance
	sa.EmissiveMaskContent = Content.fromUri("rbxassetid://" .. mask)
	sa.EmissiveStrength = STRENGTH
	sa.EmissiveTint = Color3.new(1, 1, 1)
	return true
end

return setmetatable({ MASKS = MASKS, STRENGTH = STRENGTH, apply = apply }, {
	__call = function(_, folder: Instance?): number
		local weapons = folder or (ReplicatedStorage:FindFirstChild("Assets") :: Instance):FindFirstChild("Weapons") :: Instance
		local count = 0
		for _, tool in ipairs(weapons:GetChildren()) do
			if tool:IsA("Tool") and apply(tool) then
				count += 1
			end
		end
		print(`WeaponGlow: emissive mask on {count} weapon(s)`)
		return count
	end,
})
