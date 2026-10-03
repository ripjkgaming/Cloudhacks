-- All game design data lives here: rarities, fossils, zones, pickaxes, backpacks, quests.
-- Tweak numbers freely; both server and client read from this module.

local Config = {}

----------------------------------------------------------------------
-- Rarities
----------------------------------------------------------------------
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(196, 196, 196) },
	{ Name = "Uncommon", Color = Color3.fromRGB(96, 214, 116) },
	{ Name = "Rare", Color = Color3.fromRGB(72, 150, 255) },
	{ Name = "Epic", Color = Color3.fromRGB(176, 96, 255) },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 176, 48) },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 72, 128) },
}
Config.RarityByName = {}
for i, r in Config.Rarities do
	r.Index = i
	Config.RarityByName[r.Name] = r
end

----------------------------------------------------------------------
-- Fossils
----------------------------------------------------------------------
Config.Fossils = {
	-- Dusty Quarry
	{ Id = "trilobite", Name = "Trilobite", Rarity = "Common", Value = 8, Icon = "🐚" },
	{ Id = "ammonite", Name = "Ammonite Shell", Rarity = "Common", Value = 10, Icon = "🌀" },
	{ Id = "fern_imprint", Name = "Fern Imprint", Rarity = "Common", Value = 9, Icon = "🌿" },
	{ Id = "fish_skel", Name = "Ancient Fish", Rarity = "Uncommon", Value = 28, Icon = "🐟" },
	{ Id = "shark_tooth", Name = "Megalodon Tooth", Rarity = "Rare", Value = 90, Icon = "🦷" },
	{ Id = "raptor_claw", Name = "Raptor Claw", Rarity = "Epic", Value = 320, Icon = "🪝" },
	-- Fern Hollow
	{ Id = "amber_bug", Name = "Amber Beetle", Rarity = "Uncommon", Value = 55, Icon = "🪲" },
	{ Id = "dragonfly", Name = "Giant Dragonfly", Rarity = "Uncommon", Value = 70, Icon = "🪰" },
	{ Id = "stego_plate", Name = "Stegosaurus Plate", Rarity = "Rare", Value = 180, Icon = "🦕" },
	{ Id = "bronto_vert", Name = "Brachio Vertebra", Rarity = "Rare", Value = 220, Icon = "🦴" },
	{ Id = "raptor_skull", Name = "Raptor Skull", Rarity = "Epic", Value = 700, Icon = "💀" },
	{ Id = "amber_gem", Name = "Glowing Amber", Rarity = "Legendary", Value = 2400, Icon = "🔶" },
	-- Amber Dunes
	{ Id = "petrified_wood", Name = "Petrified Wood", Rarity = "Common", Value = 90, Icon = "🪵" },
	{ Id = "snake_fossil", Name = "Coiled Serpent", Rarity = "Uncommon", Value = 200, Icon = "🐍" },
	{ Id = "sauropod_bone", Name = "Sauropod Bone", Rarity = "Rare", Value = 520, Icon = "🦴" },
	{ Id = "spino_sail", Name = "Spinosaurus Sail", Rarity = "Epic", Value = 1800, Icon = "🦖" },
	{ Id = "tricera_horn", Name = "Triceratops Horn", Rarity = "Epic", Value = 2600, Icon = "🦏" },
	{ Id = "pharaoh_scarab", Name = "Pharaoh's Scarab", Rarity = "Legendary", Value = 9000, Icon = "🪲" },
	-- Frostbite Tundra
	{ Id = "ice_fern", Name = "Frozen Fern", Rarity = "Uncommon", Value = 900, Icon = "❄️" },
	{ Id = "mammoth_tusk", Name = "Mammoth Tusk", Rarity = "Rare", Value = 1500, Icon = "🐘" },
	{ Id = "saber_tooth", Name = "Saber Tooth", Rarity = "Epic", Value = 5200, Icon = "🐯" },
	{ Id = "frozen_dire", Name = "Dire Wolf Skull", Rarity = "Epic", Value = 7000, Icon = "🐺" },
	{ Id = "ice_trex", Name = "Frozen T-Rex Tooth", Rarity = "Legendary", Value = 24000, Icon = "🧊" },
	{ Id = "cryo_egg", Name = "Cryo Egg", Rarity = "Mythic", Value = 90000, Icon = "🥚" },
	-- Magma Depths
	{ Id = "obsidian_shard", Name = "Obsidian Shard", Rarity = "Uncommon", Value = 1200, Icon = "🔻" },
	{ Id = "magma_ammonite", Name = "Magma Ammonite", Rarity = "Rare", Value = 4200, Icon = "🐌" },
	{ Id = "lava_trex", Name = "Lava-Forged T-Rex", Rarity = "Epic", Value = 16000, Icon = "🌋" },
	{ Id = "phoenix_bone", Name = "Phoenix Bone", Rarity = "Legendary", Value = 70000, Icon = "🔥" },
	{ Id = "dragon_skull", Name = "Dragon Skull", Rarity = "Mythic", Value = 250000, Icon = "🐉" },
	{ Id = "primal_core", Name = "Primal Core", Rarity = "Mythic", Value = 400000, Icon = "💎" },
}
Config.FossilById = {}
for _, f in Config.Fossils do
	Config.FossilById[f.Id] = f
end

----------------------------------------------------------------------
-- Zones
----------------------------------------------------------------------
Config.ZoneRingRadius = 420 -- distance of each zone centre from the hub
Config.ZoneHalfSize = 95 -- ground plate is 190 x 190
Config.HubSpawn = Vector3.new(0, 6, 44)

Config.Zones = {
	{
		Id = "quarry",
		Name = "Dusty Quarry",
		Blurb = "Sun-baked cliffs full of easy finds.",
		Icon = "⛏️",
		Price = 0,
		SpotHp = 3,
		Respawn = 10,
		SpotCount = 14,
		GroundColor = Color3.fromRGB(150, 124, 94),
		GroundMaterial = Enum.Material.Ground,
		SpotColor = Color3.fromRGB(96, 70, 50),
		SpotMaterial = Enum.Material.Ground,
		Weather = "dust",
		Lighting = {
			ClockTime = 16.2,
			Ambient = Color3.fromRGB(120, 105, 90),
			AtmoColor = Color3.fromRGB(235, 205, 165),
			AtmoDensity = 0.34,
			AtmoHaze = 1.6,
			Tint = Color3.fromRGB(255, 244, 228),
			Saturation = 0.12,
		},
		Loot = {
			{ "trilobite", 40 },
			{ "ammonite", 34 },
			{ "fern_imprint", 30 },
			{ "fish_skel", 14 },
			{ "shark_tooth", 5 },
			{ "raptor_claw", 1.2 },
		},
	},
	{
		Id = "fern",
		Name = "Fern Hollow",
		Blurb = "A humid jungle where amber hides insects from the ages.",
		Icon = "🌿",
		Price = 1500,
		SpotHp = 5,
		Respawn = 12,
		SpotCount = 14,
		GroundColor = Color3.fromRGB(64, 112, 60),
		GroundMaterial = Enum.Material.Grass,
		SpotColor = Color3.fromRGB(72, 54, 40),
		SpotMaterial = Enum.Material.Mud,
		Weather = "fireflies",
		Lighting = {
			ClockTime = 10.5,
			Ambient = Color3.fromRGB(80, 110, 85),
			AtmoColor = Color3.fromRGB(165, 220, 180),
			AtmoDensity = 0.42,
			AtmoHaze = 2.1,
			Tint = Color3.fromRGB(235, 255, 238),
			Saturation = 0.2,
		},
		Loot = {
			{ "ammonite", 20 },
			{ "amber_bug", 30 },
			{ "dragonfly", 26 },
			{ "stego_plate", 14 },
			{ "bronto_vert", 12 },
			{ "raptor_skull", 4 },
			{ "amber_gem", 0.8 },
		},
	},
	{
		Id = "dunes",
		Name = "Amber Dunes",
		Blurb = "Endless dunes hiding giant bones and ancient relics.",
		Icon = "🏜️",
		Price = 8000,
		SpotHp = 9,
		Respawn = 14,
		SpotCount = 14,
		GroundColor = Color3.fromRGB(228, 192, 122),
		GroundMaterial = Enum.Material.Sand,
		SpotColor = Color3.fromRGB(176, 134, 78),
		SpotMaterial = Enum.Material.Sand,
		Weather = "sand",
		Lighting = {
			ClockTime = 13.2,
			Ambient = Color3.fromRGB(140, 120, 90),
			AtmoColor = Color3.fromRGB(255, 218, 156),
			AtmoDensity = 0.3,
			AtmoHaze = 1.2,
			Tint = Color3.fromRGB(255, 236, 205),
			Saturation = 0.22,
		},
		Loot = {
			{ "petrified_wood", 34 },
			{ "snake_fossil", 26 },
			{ "sauropod_bone", 14 },
			{ "spino_sail", 6 },
			{ "tricera_horn", 5 },
			{ "pharaoh_scarab", 0.8 },
		},
	},
	{
		Id = "tundra",
		Name = "Frostbite Tundra",
		Blurb = "Frozen giants sleep beneath the permafrost.",
		Icon = "❄️",
		Price = 40000,
		SpotHp = 15,
		Respawn = 16,
		SpotCount = 14,
		GroundColor = Color3.fromRGB(228, 238, 248),
		GroundMaterial = Enum.Material.Snow,
		SpotColor = Color3.fromRGB(150, 178, 204),
		SpotMaterial = Enum.Material.Ice,
		Weather = "snow",
		Lighting = {
			ClockTime = 8.2,
			Ambient = Color3.fromRGB(110, 125, 150),
			AtmoColor = Color3.fromRGB(200, 226, 255),
			AtmoDensity = 0.46,
			AtmoHaze = 2.4,
			Tint = Color3.fromRGB(226, 240, 255),
			Saturation = 0.05,
		},
		Loot = {
			{ "ice_fern", 26 },
			{ "mammoth_tusk", 18 },
			{ "saber_tooth", 8 },
			{ "frozen_dire", 6 },
			{ "ice_trex", 1.2 },
			{ "cryo_egg", 0.25 },
		},
	},
	{
		Id = "magma",
		Name = "Magma Depths",
		Blurb = "Scorching caverns where legends are forged.",
		Icon = "🌋",
		Price = 200000,
		SpotHp = 26,
		Respawn = 18,
		SpotCount = 14,
		GroundColor = Color3.fromRGB(52, 40, 42),
		GroundMaterial = Enum.Material.Basalt,
		SpotColor = Color3.fromRGB(86, 52, 44),
		SpotMaterial = Enum.Material.Slate,
		Weather = "embers",
		Lighting = {
			ClockTime = 0.5,
			Ambient = Color3.fromRGB(96, 46, 34),
			AtmoColor = Color3.fromRGB(150, 60, 36),
			AtmoDensity = 0.5,
			AtmoHaze = 2.8,
			Tint = Color3.fromRGB(255, 208, 192),
			Saturation = 0.25,
		},
		Loot = {
			{ "obsidian_shard", 34 },
			{ "magma_ammonite", 22 },
			{ "lava_trex", 8 },
			{ "phoenix_bone", 1.5 },
			{ "dragon_skull", 0.3 },
			{ "primal_core", 0.12 },
		},
	},
}
Config.ZoneById = {}
for i, z in Config.Zones do
	z.Index = i
	Config.ZoneById[z.Id] = z
end

Config.Hub = {
	Id = "hub",
	Name = "Fossil Hub",
	Blurb = "Sell finds at the Museum.",
	Lighting = {
		ClockTime = 14.5,
		Ambient = Color3.fromRGB(112, 108, 104),
		AtmoColor = Color3.fromRGB(205, 220, 238),
		AtmoDensity = 0.3,
		AtmoHaze = 1.4,
		Tint = Color3.fromRGB(255, 250, 242),
		Saturation = 0.15,
	},
}

-- Zone 1 lies straight "south" (+Z) of the hub so new players can walk to it;
-- the rest are spread around the ring.
function Config.ZoneCenter(index: number): Vector3
	local a = math.pi / 2 + (index - 1) * (2 * math.pi / #Config.Zones)
	return Vector3.new(math.cos(a) * Config.ZoneRingRadius, 0, math.sin(a) * Config.ZoneRingRadius)
end

-- Where players land when travelling: the hub-facing edge of the zone.
function Config.ZoneArrival(index: number): Vector3
	local c = Config.ZoneCenter(index)
	return c - c.Unit * (Config.ZoneHalfSize - 20) + Vector3.new(0, 6, 0)
end

----------------------------------------------------------------------
-- Pickaxes (tier order = purchase order)
----------------------------------------------------------------------
-- Power: damage per hit vs. mound HP   Speed: seconds per swing
-- Luck: shifts loot odds toward rarer fossils   Reach: studs
Config.Pickaxes = {
	{ Name = "Wooden Pickaxe", Price = 0, Power = 1, Speed = 0.9, Luck = 1.0, Reach = 12, Scale = 0.95,
		HeadColor = Color3.fromRGB(132, 100, 70), HeadMaterial = Enum.Material.Wood, HandleColor = Color3.fromRGB(100, 70, 45) },
	{ Name = "Stone Pickaxe", Price = 350, Power = 1.6, Speed = 0.82, Luck = 1.15, Reach = 12, Scale = 1.0,
		HeadColor = Color3.fromRGB(128, 130, 136), HeadMaterial = Enum.Material.Slate, HandleColor = Color3.fromRGB(104, 74, 48) },
	{ Name = "Iron Pickaxe", Price = 3000, Power = 2.6, Speed = 0.72, Luck = 1.35, Reach = 13, Scale = 1.05,
		HeadColor = Color3.fromRGB(205, 210, 220), HeadMaterial = Enum.Material.Metal, HandleColor = Color3.fromRGB(110, 78, 50) },
	{ Name = "Golden Pickaxe", Price = 18000, Power = 4, Speed = 0.64, Luck = 1.7, Reach = 13, Scale = 1.1,
		HeadColor = Color3.fromRGB(255, 205, 72), HeadMaterial = Enum.Material.Metal, HandleColor = Color3.fromRGB(80, 56, 38) },
	{ Name = "Diamond Pickaxe", Price = 100000, Power = 6.5, Speed = 0.56, Luck = 2.1, Reach = 14, Scale = 1.15,
		HeadColor = Color3.fromRGB(70, 205, 245), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(60, 60, 72), Glow = true },
	{ Name = "Magma Pickaxe", Price = 600000, Power = 10, Speed = 0.48, Luck = 2.6, Reach = 14, Scale = 1.2,
		HeadColor = Color3.fromRGB(255, 112, 40), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(40, 32, 34), Glow = true },
	{ Name = "Starforged Pickaxe", Price = 4000000, Power = 16, Speed = 0.42, Luck = 3.2, Reach = 15, Scale = 1.3,
		HeadColor = Color3.fromRGB(184, 108, 255), HeadMaterial = Enum.Material.Neon, HandleColor = Color3.fromRGB(30, 25, 52), Glow = true, Trail = true },
}

Config.Backpacks = {
	{ Name = "Satchel", Capacity = 10, Price = 0 },
	{ Name = "Canvas Pack", Capacity = 20, Price = 150 },
	{ Name = "Hiker Pack", Capacity = 35, Price = 1000 },
	{ Name = "Explorer Pack", Capacity = 55, Price = 6000 },
	{ Name = "Expedition Pack", Capacity = 85, Price = 30000 },
	{ Name = "Titan Pack", Capacity = 130, Price = 150000 },
	{ Name = "Void Pack", Capacity = 200, Price = 750000 },
	{ Name = "Infinity Pack", Capacity = 300, Price = 3500000 },
}

-- Swing animation angles (radians about the shoulder). See Swing.luau / PickaxeVisual.luau.
Config.Swing = { Carry = 2.5, Wind = 3.2, Strike = 0.85 }

----------------------------------------------------------------------
-- Quests
----------------------------------------------------------------------
-- Stat keys: Finds, Earned, Species, Zones, Pickaxe, Backpack, Rarity:<Name> (that rarity or better)
Config.Quests = {
	{ Id = "q_first", Title = "First Strike", Desc = "Dig up your first fossil", Stat = "Finds", Goal = 1, Reward = 40 },
	{ Id = "q_sell", Title = "Open for Business", Desc = "Earn 100 coins selling to the Museum", Stat = "Earned", Goal = 100, Reward = 60 },
	{ Id = "q_finds10", Title = "Getting the Hang of It", Desc = "Dig up 10 fossils", Stat = "Finds", Goal = 10, Reward = 120 },
	{ Id = "q_pick2", Title = "Upgrade Time", Desc = "Buy the Stone Pickaxe", Stat = "Pickaxe", Goal = 2, Reward = 200 },
	{ Id = "q_bp2", Title = "Room to Grow", Desc = "Upgrade your backpack", Stat = "Backpack", Goal = 2, Reward = 250 },
	{ Id = "q_finds50", Title = "Fossil Hunter", Desc = "Dig up 50 fossils", Stat = "Finds", Goal = 50, Reward = 500 },
	{ Id = "q_rare1", Title = "Something Special", Desc = "Find a Rare (or better) fossil", Stat = "Rarity:Rare", Goal = 1, Reward = 400 },
	{ Id = "q_zone2", Title = "New Horizons", Desc = "Unlock a second dig zone", Stat = "Zones", Goal = 2, Reward = 900 },
	{ Id = "q_species8", Title = "Curator", Desc = "Discover 8 different fossils", Stat = "Species", Goal = 8, Reward = 1400 },
	{ Id = "q_pick4", Title = "Golden Touch", Desc = "Buy the Golden Pickaxe", Stat = "Pickaxe", Goal = 4, Reward = 4000 },
	{ Id = "q_finds250", Title = "Dig Dig Dig", Desc = "Dig up 250 fossils", Stat = "Finds", Goal = 250, Reward = 3000 },
	{ Id = "q_epic1", Title = "Purple Haze", Desc = "Find an Epic (or better) fossil", Stat = "Rarity:Epic", Goal = 1, Reward = 3000 },
	{ Id = "q_earn25k", Title = "Fossil Tycoon", Desc = "Earn 25,000 coins selling fossils", Stat = "Earned", Goal = 25000, Reward = 5000 },
	{ Id = "q_zone3", Title = "Desert Wanderer", Desc = "Unlock 3 dig zones", Stat = "Zones", Goal = 3, Reward = 9000 },
	{ Id = "q_bp5", Title = "Heavy Hauler", Desc = "Reach the Expedition Pack", Stat = "Backpack", Goal = 5, Reward = 12000 },
	{ Id = "q_species16", Title = "Museum Wing", Desc = "Discover 16 different fossils", Stat = "Species", Goal = 16, Reward = 15000 },
	{ Id = "q_leg1", Title = "Golden Glow", Desc = "Find a Legendary fossil", Stat = "Rarity:Legendary", Goal = 1, Reward = 25000 },
	{ Id = "q_pick6", Title = "Forged in Fire", Desc = "Buy the Magma Pickaxe", Stat = "Pickaxe", Goal = 6, Reward = 60000 },
	{ Id = "q_earn500k", Title = "Fossil Mogul", Desc = "Earn 500,000 coins selling fossils", Stat = "Earned", Goal = 500000, Reward = 80000 },
	{ Id = "q_zone5", Title = "To the Core", Desc = "Unlock every dig zone", Stat = "Zones", Goal = 5, Reward = 100000 },
	{ Id = "q_myth1", Title = "Myth Made Real", Desc = "Find a Mythic fossil", Stat = "Rarity:Mythic", Goal = 1, Reward = 300000 },
	{ Id = "q_all", Title = "Complete Collection", Desc = "Discover every fossil", Stat = "Species", Goal = #Config.Fossils, Reward = 750000 },
}
Config.QuestById = {}
for _, q in Config.Quests do
	Config.QuestById[q.Id] = q
end

function Config.GetStat(data, stat: string): number
	local s = data.Stats
	if stat == "Finds" then
		return s.Finds
	elseif stat == "Earned" then
		return s.Earned
	elseif stat == "Species" then
		local n = 0
		for _ in data.Collection do
			n += 1
		end
		return n
	elseif stat == "Zones" then
		local n = 0
		for _, unlocked in data.ZonesUnlocked do
			if unlocked then
				n += 1
			end
		end
		return n
	elseif stat == "Pickaxe" then
		return data.Pickaxe
	elseif stat == "Backpack" then
		return data.Backpack
	elseif string.sub(stat, 1, 7) == "Rarity:" then
		local minIndex = Config.RarityByName[string.sub(stat, 8)].Index
		local n = 0
		for name, count in s.ByRarity do
			local r = Config.RarityByName[name]
			if r and r.Index >= minIndex then
				n += count
			end
		end
		return n
	end
	return 0
end

----------------------------------------------------------------------
-- Player data template
----------------------------------------------------------------------
function Config.DefaultData()
	return {
		Coins = 0,
		Pickaxe = 1,
		Backpack = 1,
		ZonesUnlocked = { quarry = true },
		Inventory = {}, -- [fossilId] = count carried
		Collection = {}, -- [fossilId] = total ever found
		Claimed = {}, -- [questId] = true
		Stats = { Swings = 0, Finds = 0, Earned = 0, ByRarity = {} },
	}
end

----------------------------------------------------------------------
-- Sounds (Roblox built-ins as placeholders; swap in your own asset ids)
----------------------------------------------------------------------
Config.Sounds = {
	Swing = { Id = "rbxasset://sounds/action_swim.mp3", Volume = 0.25, Speed = 2.4 },
	Hit = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.6, Speed = 0.7 },
	Break = { Id = "rbxasset://sounds/bass.mp3", Volume = 0.5, Speed = 1.6 },
	Find = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.0 },
	Rare = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Speed = 1.0 },
	Coin = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6, Speed = 1.4 },
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.5 },
	Click = { Id = "rbxasset://sounds/switch.wav", Volume = 0.4, Speed = 1.2 },
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local suffixes = { "", "K", "M", "B", "T" }
function Config.Abbrev(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local i, v = 1, n
	while v >= 1000 and i < #suffixes do
		v /= 1000
		i += 1
	end
	local s = string.format("%.2f", v)
	s = (string.gsub(s, "%.?0+$", ""))
	return s .. suffixes[i]
end

function Config.InventoryCount(data): number
	local n = 0
	for _, c in data.Inventory do
		n += c
	end
	return n
end

return Config
