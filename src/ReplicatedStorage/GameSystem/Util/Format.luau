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

local MULTIPLIERS = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15 }

-- "2500", "2.5K", "1,000", "3qa" -> number; nil if the text is not an amount.
function Format.parse(text: string): number?
	local cleaned = string.lower((string.gsub(text, "[%s,]", "")))
	local digits, suffix = string.match(cleaned, "^([%d%.]+)(%a*)$")
	local value = tonumber(digits)
	if not value then
		return nil
	end
	if suffix ~= "" then
		local multiplier = MULTIPLIERS[suffix]
		if not multiplier then
			return nil
		end
		value *= multiplier
	end
	return value
end

return Format
