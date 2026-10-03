--!strict
-- Number formatting with K / M / B / T / Qa suffixes.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }

function Format.number(value: number): string
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	if value < 1000 then
		return sign .. tostring(math.floor(value + 0.5))
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return sign .. text .. SUFFIXES[index]
end

return Format
