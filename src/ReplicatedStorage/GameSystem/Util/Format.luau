--!strict
-- Number formatting with K / M / B / T / Qa suffixes (never "1e+15").
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

function Format.number(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	value = math.abs(value)
	if value < 999.5 then
		return sign .. tostring(math.floor(value + 0.5))
	end
	local index = 2
	value /= 1000
	while value >= 999.995 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return sign .. text .. SUFFIXES[index]
end

-- 0.4 -> "+40%"
function Format.bonus(fraction: number): string
	return "+" .. tostring(math.floor(fraction * 100 + 0.5)) .. "%"
end

local MULTIPLIERS = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21 }

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
