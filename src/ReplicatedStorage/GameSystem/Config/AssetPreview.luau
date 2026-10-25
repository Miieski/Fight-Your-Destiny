--!strict
-- Asset preview settings (owner, round 4). Read by the dev tool tools/BuildAssetPreview.luau only (Edit mode, Studio):
-- the game never uses it. Size classes use the largest dimension of an asset at its real size (studs).
local AssetPreview = {
	SMALL_MAX = 6, -- largest dimension < 6 studs: SMALL row
	MEDIUM_MAX = 25, -- 6 to 25 studs: MEDIUM row; above 25: LARGE row

	-- grouping of identical objects into one asset (same name, part count and mesh ids): copies whose size matches
	-- after one uniform factor (Model scale, or parts resized one by one) are the same asset; a non-uniform size spread
	-- up to SIZE_TOLERANCE also merges (logged as a size variant), above it the copy is a separate variant asset
	UNIFORM_TOLERANCE = 0.01,
	SIZE_TOLERANCE = 0.10,

	-- layout of workspace._Staging.AssetPreview.ByZone (one block per zone, Hub first, then Config/Zones order)
	ORIGIN = Vector3.new(-4400, 0, 0), -- front-left corner of the first block; rows run toward -X, blocks toward +Z
	ROW_MAX = 1400, -- a row wraps onto a new line after this length (studs)
	BLOCK_GAP = 120, -- empty strip between two zone blocks (studs)
}

return AssetPreview
