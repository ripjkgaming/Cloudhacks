-- Purchases, zone travel, and selling fossils at the Museum.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PickaxeVisual = require(script.Parent.PickaxeVisual)

local ShopService = {}

local lastTravel = {}

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind or "info")
end

-- Called by the Museum's ProximityPrompt.
function ShopService.Sell(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local total, count = 0, 0
	for id, n in data.Inventory do
		local fossil = Config.FossilById[id]
		if fossil then
			total += fossil.Value * n
			count += n
		end
	end
	if count == 0 then
		notify(player, "Your backpack is empty - go dig something up!", "info")
		return
	end
	data.Inventory = {}
	data.Coins += total
	data.Stats.Earned += total
	Remotes.SellFx:FireClient(player, total, count)
	notify(player, `Sold {count} fossils for {Config.Abbrev(total)} coins`, "good")
	DataService.Commit(player)
end

local function buy(player, kind, id)
	local data = DataService.Get(player)
	if not data then
		return false, "Still loading..."
	end

	if kind == "pickaxe" then
		if type(id) ~= "number" or id ~= data.Pickaxe + 1 then
			return false, "You can't buy that yet."
		end
		local def = Config.Pickaxes[id]
		if not def then
			return false, "Unknown pickaxe."
		end
		if data.Coins < def.Price then
			return false, "Not enough coins!"
		end
		data.Coins -= def.Price
		data.Pickaxe = id
		DataService.Commit(player)
		PickaxeVisual.Apply(player)
		return true, `Equipped the {def.Name}!`
	elseif kind == "backpack" then
		if type(id) ~= "number" or id ~= data.Backpack + 1 then
			return false, "You can't buy that yet."
		end
		local def = Config.Backpacks[id]
		if not def then
			return false, "Unknown backpack."
		end
		if data.Coins < def.Price then
			return false, "Not enough coins!"
		end
		data.Coins -= def.Price
		data.Backpack = id
		DataService.Commit(player)
		return true, `{def.Name}: carry up to {def.Capacity} fossils!`
	elseif kind == "zone" then
		local zone = type(id) == "string" and Config.ZoneById[id]
		if not zone then
			return false, "Unknown zone."
		end
		if data.ZonesUnlocked[zone.Id] then
			return false, "Already unlocked."
		end
		local prev = Config.Zones[zone.Index - 1]
		if prev and not data.ZonesUnlocked[prev.Id] then
			return false, `Unlock {prev.Name} first.`
		end
		if data.Coins < zone.Price then
			return false, "Not enough coins!"
		end
		data.Coins -= zone.Price
		data.ZonesUnlocked[zone.Id] = true
		DataService.Commit(player)
		return true, `Unlocked {zone.Name}!`
	end
	return false, "Invalid purchase."
end

local function travel(player, zoneId)
	local data = DataService.Get(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not data or not hrp then
		return false, "Can't travel right now."
	end
	if os.clock() - (lastTravel[player] or 0) < 2 then
		return false, "Slow down!"
	end

	local target, lookAt
	if zoneId == "Hub" then
		target, lookAt = Config.HubSpawn, Vector3.new(0, 6, 0)
	else
		local zone = type(zoneId) == "string" and Config.ZoneById[zoneId]
		if not zone then
			return false, "Unknown zone."
		end
		if not data.ZonesUnlocked[zone.Id] then
			return false, "That zone is locked."
		end
		target = Config.ZoneArrival(zone.Index)
		lookAt = Config.ZoneCenter(zone.Index) + Vector3.new(0, 6, 0)
	end

	lastTravel[player] = os.clock()
	char:PivotTo(CFrame.lookAt(target, lookAt))
	return true, ""
end

function ShopService.Init()
	Remotes.Buy.OnServerInvoke = buy
	Remotes.Travel.OnServerInvoke = travel
	Players.PlayerRemoving:Connect(function(p)
		lastTravel[p] = nil
	end)
end

return ShopService
