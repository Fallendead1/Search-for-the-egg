--!strict
local Format = {}

-- Inserts thousand separators into a plain (already non-negative, integer)
-- digit string: "1000" -> "1,000", "1234567" -> "1,234,567". Works by
-- reversing the digits, splitting into groups of 3 from what is now the
-- front (originally the least-significant end), then reversing back -- a
-- trailing comma only appears when the digit count is an exact multiple of
-- 3 (e.g. "123456" -> "654,321," before the reverse), so it's stripped
-- before reversing rather than left to become a leading comma.
local function withThousandsSeparators(digits: string): string
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", "")
	return grouped:reverse()
end

-- Whole, comma-separated integer: 1000 -> "1,000". For raw stat counts
-- (e.g. Wins) where Format.compactNumber's K/M abbreviation isn't wanted.
function Format.integer(n: number): string
	local rounded = math.floor(math.abs(n) + 0.5)
	local sign = n < 0 and "-" or ""
	return sign .. withThousandsSeparators(tostring(rounded))
end

-- amountCents is integer cents (the canonical server Cash representation --
-- see RunPlayerStateService/DisplayConfig). 25 -> "$0.25", 100000 -> "$1,000.00".
function Format.cash(amountCents: number): string
	local rounded = math.floor(math.abs(amountCents) + 0.5)
	local sign = amountCents < 0 and "-" or ""
	local wholeDollars = rounded // 100
	local centsPart = rounded % 100
	return ("%s$%s.%02d"):format(sign, withThousandsSeparators(tostring(wholeDollars)), centsPart)
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return ("%02d:%02d"):format(minutes, secs)
end

function Format.compactNumber(n: number): string
	if n >= 1_000_000 then
		return ("%.1fM"):format(n / 1_000_000)
	elseif n >= 1_000 then
		return ("%.1fK"):format(n / 1_000)
	end
	return tostring(math.floor(n))
end

function Format.percent(fraction: number): string
	return ("%.1f%%"):format(fraction * 100)
end

return Format
