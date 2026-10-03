-- Quest rewards + "quest complete" notifications. Progress itself is derived from player stats
-- (Config.GetStat), so quests can never get out of sync with the data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local QuestService = {}

local announced = {} -- [Player] = { [questId] = true }

local function isComplete(data, quest)
	return Config.GetStat(data, quest.Stat) >= quest.Goal
end

local function claim(player, questId)
	local data = DataService.Get(player)
	local quest = type(questId) == "string" and Config.QuestById[questId]
	if not data or not quest then
		return false, "Unknown quest."
	end
	if data.Claimed[quest.Id] then
		return false, "Already claimed."
	end
	if not isComplete(data, quest) then
		return false, "Quest not complete yet."
	end
	data.Claimed[quest.Id] = true
	data.Coins += quest.Reward
	DataService.Commit(player)
	return true, `+{Config.Abbrev(quest.Reward)} coins - {quest.Title}!`
end

function QuestService.Init()
	Remotes.ClaimQuest.OnServerInvoke = claim

	DataService.OnCommit(function(player, data)
		local seen = announced[player]
		local firstPass = seen == nil
		if firstPass then
			seen = {}
			announced[player] = seen
		end
		for _, quest in Config.Quests do
			if not seen[quest.Id] and not data.Claimed[quest.Id] and isComplete(data, quest) then
				seen[quest.Id] = true
				if not firstPass then
					Remotes.Notify:FireClient(player, `Quest complete: {quest.Title} - claim your reward!`, "good")
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		announced[p] = nil
	end)
end

return QuestService
