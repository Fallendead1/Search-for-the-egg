--[[
	Difficulty/chapter unlock resolution. Hard Mode itself has no bespoke
	mechanics beyond the standard Chapter 1 loop -- everything it changes
	(bigger pile, deeper Egg, better completion reward) is expressed purely
	through RunConfig.DIFFICULTY and consumed by FeatherPileService/
	EggService/RoundService. This module is just the single source of truth
	for "is this player allowed to pick X".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunConfig = require(ReplicatedStorage.SearchForTheEgg.GameplayConfig.RunConfig)

local CoreLocator = require(script.Parent.CoreLocator)

local HardModeService = {}

function HardModeService.ChapterUnlocked(player: Player, chapterId: string): boolean
	local chapter = RunConfig.CHAPTERS[chapterId]
	if not chapter or not chapter.Enabled then
		return false
	end
	if chapter.RequiresWins <= 0 then
		return true
	end
	return CoreLocator.GetWins(player) >= chapter.RequiresWins
end

function HardModeService.DifficultyUnlocked(player: Player, difficultyId: string): boolean
	local difficulty = RunConfig.DIFFICULTY[difficultyId]
	if not difficulty then
		return false
	end
	if difficulty.RequiresWins <= 0 then
		return true
	end
	return CoreLocator.GetWins(player) >= difficulty.RequiresWins
end

return HardModeService
