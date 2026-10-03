-- Player data: load/save (DataStore), leaderstats, and state sync to the client.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local STORE_NAME = "FossilDigV1"
local AUTOSAVE_SECONDS = 90

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles = {}
local saveDisabled = {} -- players whose load failed; never overwrite their real data
local commitListeners = {}
local loadedListeners = {}

local DataService = {}

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
	return data
end

local function save(player)
	local data = profiles[player]
	if not data or saveDisabled[player] then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync("P_" .. player.UserId, function()
			return data
		end)
	end)
	if not ok then
		warn(`[FossilDig] save failed for {player.Name}: {err}`)
	end
end

local function updateLeaderstats(player, data)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		for _, name in { "Coins", "Fossils" } do
			local v = Instance.new("IntValue")
			v.Name = name
			v.Parent = ls
		end
		ls.Parent = player
	end
	ls.Coins.Value = math.floor(data.Coins)
	ls.Fossils.Value = data.Stats.Finds
end

function DataService.Get(player)
	return profiles[player]
end

function DataService.OnCommit(fn)
	table.insert(commitListeners, fn)
end

function DataService.OnLoaded(fn)
	table.insert(loadedListeners, fn)
end

-- Call after mutating a player's data: refreshes leaderstats, runs listeners, syncs the client.
function DataService.Commit(player)
	local data = profiles[player]
	if not data then
		return
	end
	updateLeaderstats(player, data)
	for _, fn in commitListeners do
		local ok, err = pcall(fn, player, data)
		if not ok then
			warn("[FossilDig] commit listener error: " .. tostring(err))
		end
	end
	Remotes.State:FireClient(player, data)
end

local function onPlayerAdded(player)
	local data, loadedOk
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync("P_" .. player.UserId)
		end)
		if ok then
			data, loadedOk = result, true
			break
		end
		warn(`[FossilDig] load attempt {attempt} failed for {player.Name}: {result}`)
		task.wait(attempt)
	end
	if player.Parent == nil then
		return
	end
	if not loadedOk then
		saveDisabled[player] = true -- play with a temporary profile; progress won't be saved
		Remotes.Notify:FireClient(player, "Couldn't load your save - progress won't be saved this session.", "bad")
	end
	profiles[player] = reconcile(data or {}, Config.DefaultData())
	DataService.Commit(player)
	for _, fn in loadedListeners do
		task.spawn(fn, player, profiles[player])
	end
end

local function onPlayerRemoving(player)
	save(player)
	profiles[player] = nil
	saveDisabled[player] = nil
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end

	Remotes.ClientReady.OnServerEvent:Connect(function(player)
		local data = profiles[player]
		if data then
			Remotes.State:FireClient(player, data)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, p in Players:GetPlayers() do
				task.spawn(save, p)
			end
		end
	end)

	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			task.spawn(save, p)
		end
		task.wait(2)
	end)
end

return DataService
