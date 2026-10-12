--!strict
-- Pet mutations and sizes (docs/pets_v2_plan.md section 3, owner 2026-10-12, after Steal an Egg). Rolled at every
-- egg hatch on top of the rarity; premium (Robux) pets never mutate. A pet stores them as `mutation` / `size`
-- (nil = none / Normal, so pets hatched before V2 need no migration). Both multiply the pet's two main stats, its
-- bonus, its Equip Best score and its release value. Looks: Util/PetLook.
local PetMutations = {}

export type Mutation = { Id: string, Name: string, Chance: number, Mult: number, Color: Color3, Order: number }
export type Size = { Id: string, Name: string, Chance: number, Mult: number, Scale: number, Order: number }

local rgb = Color3.fromRGB

-- Rarest last. Chances are per hatch; what is left is "no mutation".
PetMutations.List = {
	{ Id = "Silver", Name = "Silver", Chance = 0.08, Mult = 1.2, Color = rgb(214, 226, 240), Order = 1 },
	{ Id = "Golden", Name = "Golden", Chance = 0.04, Mult = 1.5, Color = rgb(255, 196, 40), Order = 2 },
	{ Id = "Rainbow", Name = "Rainbow", Chance = 0.009, Mult = 2, Color = rgb(255, 90, 200), Order = 3 },
	{ Id = "Celestial", Name = "Celestial", Chance = 0.001, Mult = 3, Color = rgb(140, 220, 255), Order = 4 },
} :: { Mutation }

PetMutations.Sizes = {
	{ Id = "Big", Name = "Big", Chance = 0.09, Mult = 1.25, Scale = 1.35, Order = 1 },
	{ Id = "Huge", Name = "Huge", Chance = 0.01, Mult = 1.6, Scale = 1.8, Order = 2 },
} :: { Size }

PetMutations.ById = {} :: { [string]: Mutation }
for _, mutation in ipairs(PetMutations.List) do
	PetMutations.ById[mutation.Id] = mutation
end
PetMutations.SizeById = {} :: { [string]: Size }
for _, size in ipairs(PetMutations.Sizes) do
	PetMutations.SizeById[size.Id] = size
end

-- One draw over a list (rarest first so a low roll lands on the rarest), nil = none.
local function pick(rng: Random, list: { any }): any
	local roll = rng:NextNumber()
	local acc = 0
	for i = #list, 1, -1 do
		acc += list[i].Chance
		if roll < acc then
			return list[i]
		end
	end
	return nil
end

-- (mutation id?, size id?) for one hatch.
function PetMutations.roll(rng: Random): (string?, string?)
	local mutation = pick(rng, PetMutations.List)
	local size = pick(rng, PetMutations.Sizes)
	return if mutation then mutation.Id else nil, if size then size.Id else nil
end

function PetMutations.get(id: any): Mutation?
	return if typeof(id) == "string" then PetMutations.ById[id] else nil
end

function PetMutations.getSize(id: any): Size?
	return if typeof(id) == "string" then PetMutations.SizeById[id] else nil
end

-- Stat multiplier of a stored pet ({ mutation?, size? }).
function PetMutations.mult(pet: { [string]: any }?): number
	if not pet then
		return 1
	end
	local mutation = PetMutations.get(pet.mutation)
	local size = PetMutations.getSize(pet.size)
	return (if mutation then mutation.Mult else 1) * (if size then size.Mult else 1)
end

-- "x2.4" (the multiplier, rounded for display: 1.5 x 1.6 is not exactly 2.4 in floating point).
function PetMutations.multText(pet: { [string]: any }?): string
	return "x" .. string.format("%g", math.round(PetMutations.mult(pet) * 100) / 100)
end

-- Model scale of a size id (1 = Normal).
function PetMutations.scale(sizeId: any): number
	local size = PetMutations.getSize(sizeId)
	return if size then size.Scale else 1
end

-- "Huge Golden" / "Big" / "Rainbow" / "" (put before the species name).
function PetMutations.prefix(pet: { [string]: any }?): string
	if not pet then
		return ""
	end
	local parts = {}
	local size = PetMutations.getSize(pet.size)
	local mutation = PetMutations.get(pet.mutation)
	if size then
		table.insert(parts, size.Name)
	end
	if mutation then
		table.insert(parts, mutation.Name)
	end
	return table.concat(parts, " ")
end

-- Sort key: mutation order x 10 + size order (0 = plain).
function PetMutations.rank(pet: { [string]: any }?): number
	if not pet then
		return 0
	end
	local mutation = PetMutations.get(pet.mutation)
	local size = PetMutations.getSize(pet.size)
	return (if mutation then mutation.Order * 10 else 0) + (if size then size.Order else 0)
end

return PetMutations
