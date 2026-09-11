--!strict
local Format = {}

-- amountCents is integer cents (the canonical server Cash representation --
-- see RunPlayerStateService/DisplayConfig). 25 -> "$0.25".
function Format.cash(amountCents: number): string
	return ("$%.2f"):format(amountCents / 100)
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
