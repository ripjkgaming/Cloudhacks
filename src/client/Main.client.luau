-- Client entry point: builds the UI, starts systems, and routes server events to them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent

local Audio = require(Client.Audio)
local Config = require(ReplicatedStorage.Shared.Config)
local DigController = require(Client.DigController)
local Effects = require(Client.Effects)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpotVisuals = require(Client.SpotVisuals)
local _State = require(Client.State) -- required early so the State listener is connected before ClientReady
local Swing = require(Client.Swing)
local UI = require(Client.UI)
local ZoneAtmosphere = require(Client.ZoneAtmosphere)

UI.Init()
SpotVisuals.Init()
DigController.Init()
ZoneAtmosphere.Init()

DigController.IsBlocked = UI.IsModalOpen
DigController.Hint = function(text)
	UI.Toast(text, "info")
end

-- Fossil found: popup card + a little extra drama for the good stuff.
DigController.OnFind = function(fossil, isNew)
	UI.ShowFind(fossil, isNew)
	local rarity = Config.RarityByName[fossil.Rarity]
	if rarity.Index >= 4 then
		UI.Flash(rarity.Color)
		local cam = Workspace.CurrentCamera
		local base = cam.FieldOfView
		cam.FieldOfView = base + 6
		TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
	end
end

ZoneAtmosphere.OnZoneChanged = function(def)
	UI.ZoneBanner(def.Name, def.Blurb)
end

Remotes.DigResult.OnClientEvent:Connect(DigController.OnResult)

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	UI.Toast(text, kind)
end)

Remotes.Announce.OnClientEvent:Connect(function(text, color)
	UI.Announce(text, color)
end)

Remotes.SellFx.OnClientEvent:Connect(function(total, count)
	UI.SellFx(total, count)
	Effects.CoinBurst()
end)

-- Other players' swings / hits (only sent for players near you).
Remotes.SwingFx.OnClientEvent:Connect(function(userId, speed)
	local other = Players:GetPlayerByUserId(userId)
	if other and other.Character and other ~= Players.LocalPlayer then
		Swing.Play(other.Character, speed)
	end
end)

Remotes.HitFx.OnClientEvent:Connect(function(spot, broke)
	if typeof(spot) == "Instance" and spot.Parent then
		Effects.Hit(spot, broke)
		Audio.Play("Hit", 0.3)
	end
end)

Remotes.ClientReady:FireServer()
