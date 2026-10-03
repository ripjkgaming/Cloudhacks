-- Server entry point. Wires up every service in dependency order.

local Server = script.Parent

local DataService = require(Server.DataService)
local DigService = require(Server.DigService)
local PickaxeVisual = require(Server.PickaxeVisual)
local QuestService = require(Server.QuestService)
local ShopService = require(Server.ShopService)
local WorldBuilder = require(Server.WorldBuilder)

local spots = WorldBuilder.Build({ OnSell = ShopService.Sell })

DataService.Init()
QuestService.Init()
ShopService.Init()
DigService.Init(spots)
PickaxeVisual.Init()
