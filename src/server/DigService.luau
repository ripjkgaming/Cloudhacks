-- Server-authoritative digging: validates every swing, rolls loot, updates stats, respawns mounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local FX_RADIUS = 150 -- other players only see swings/hits within this distance

local DigService = {}

local spots = {} -- [Part] = { Hp, Max, Zone }
local lastHit = {} -- [Player] = os.clock()
local lastSwingFx = {}

local function rollFossil(zone, luck: number)
	local weights, total = {}, 0
	for i, entry in zone.Loot do
		local fossil = Config.FossilById[entry[1]]
		local ri = Config.RarityByName[fossil.Rarity].Index
		-- Luck pushes weight toward rarer tiers; common odds stay put.
		local w = entry[2] * (1 + (luck - 1) * (ri - 1))
		weights[i] = w
		total += w
	end
	local roll = math.random() * total
	for i, w in weights do
		roll -= w
		if roll <= 0 then
			return Config.FossilById[zone.Loot[i][1]]
		end
	end
	return Config.FossilById[zone.Loot[#zone.Loot][1]]
end

local function nearbyPlayers(origin: Vector3, except)
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= except then
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - origin).Magnitude <= FX_RADIUS then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function breakSpot(player, data, spot, info, pick)
	local zone = info.Zone
	local fossil = rollFossil(zone, pick.Luck)
	local rarity = Config.RarityByName[fossil.Rarity]

	data.Inventory[fossil.Id] = (data.Inventory[fossil.Id] or 0) + 1
	local isNew = data.Collection[fossil.Id] == nil
	data.Collection[fossil.Id] = (data.Collection[fossil.Id] or 0) + 1
	data.Stats.Finds += 1
	data.Stats.ByRarity[rarity.Name] = (data.Stats.ByRarity[rarity.Name] or 0) + 1

	spot:SetAttribute("Depleted", true)
	task.delay(zone.Respawn, function()
		info.Hp = info.Max
		spot:SetAttribute("Hp", info.Max)
		spot:SetAttribute("Depleted", false)
	end)

	Remotes.DigResult:FireClient(player, {
		Spot = spot,
		Broke = true,
		FossilId = fossil.Id,
		IsNew = isNew,
	})

	if rarity.Index >= Config.RarityByName.Legendary.Index then
		Remotes.Announce:FireAllClients(
			`{player.DisplayName} found a {string.upper(rarity.Name)} {fossil.Name}! {fossil.Icon}`,
			rarity.Color
		)
	end
end

local function onDig(player, spot)
	if typeof(spot) ~= "Instance" then
		return
	end
	local info = spots[spot]
	local data = DataService.Get(player)
	if not info or not data or spot:GetAttribute("Depleted") then
		return
	end
	if not data.ZonesUnlocked[info.Zone.Id] then
		return
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return
	end

	local pick = Config.Pickaxes[data.Pickaxe]
	if (hrp.Position - spot.Position).Magnitude > pick.Reach + 10 then
		return
	end

	local now = os.clock()
	if now - (lastHit[player] or 0) < pick.Speed * 0.7 then
		return
	end
	lastHit[player] = now

	if Config.InventoryCount(data) >= Config.Backpacks[data.Backpack].Capacity then
		Remotes.DigResult:FireClient(player, { Full = true })
		return
	end

	data.Stats.Swings += 1
	info.Hp = math.max(info.Hp - pick.Power, 0)
	spot:SetAttribute("Hp", info.Hp)
	local broke = info.Hp <= 0

	for _, other in nearbyPlayers(spot.Position, player) do
		Remotes.HitFx:FireClient(other, spot, broke)
	end

	if broke then
		breakSpot(player, data, spot, info, pick)
		DataService.Commit(player)
	else
		Remotes.DigResult:FireClient(player, { Spot = spot, Broke = false })
	end
end

function DigService.Init(spotList)
	for _, entry in spotList do
		local max = entry.Zone.SpotHp
		spots[entry.Part] = { Hp = max, Max = max, Zone = entry.Zone }
		entry.Part:SetAttribute("Hp", max)
		entry.Part:SetAttribute("MaxHp", max)
		entry.Part:SetAttribute("Depleted", false)
	end

	Remotes.Dig.OnServerEvent:Connect(onDig)

	-- Cosmetic swing relay so other players see your swing animation.
	Remotes.SwingStart.OnServerEvent:Connect(function(player)
		local data = DataService.Get(player)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not data or not hrp then
			return
		end
		local pick = Config.Pickaxes[data.Pickaxe]
		local now = os.clock()
		if now - (lastSwingFx[player] or 0) < pick.Speed * 0.6 then
			return
		end
		lastSwingFx[player] = now
		for _, other in nearbyPlayers(hrp.Position, player) do
			Remotes.SwingFx:FireClient(other, player.UserId, pick.Speed)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastHit[p] = nil
		lastSwingFx[p] = nil
	end)
end

return DigService
