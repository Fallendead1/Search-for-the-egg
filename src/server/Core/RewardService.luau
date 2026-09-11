--[[
	Pure lookup of configured chapter/difficulty completion rewards. Never
	mutates a profile -- MetaProgressionService.AwardRunCompletion applies the
	result. The Gameplay agent never supplies reward amounts directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RewardConfig = require(ReplicatedStorage.SearchForTheEgg.MetaConfig.RewardConfig)

local RewardService = {}

function RewardService.GetCompletionReward(chapterId: string, difficulty: string)
	local chapter = RewardConfig.Chapters[chapterId]
	if not chapter then
		return nil
	end
	local reward = chapter[difficulty]
	if not reward then
		return nil
	end
	return {
		Wins = reward.Wins,
		Gems = reward.Gems,
		AlienTokens = reward.AlienTokens,
	}
end

return RewardService
