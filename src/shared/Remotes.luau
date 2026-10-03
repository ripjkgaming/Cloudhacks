-- Creates (server) / fetches (client) every RemoteEvent and RemoteFunction the game uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"State", -- S->C  full player data snapshot
	"ClientReady", -- C->S  client finished connecting, send me state
	"Dig", -- C->S  (spot) swing impact
	"DigResult", -- S->C  result table for the local player's swing
	"SwingStart", -- C->S  cosmetic swing start (relayed to nearby players)
	"SwingFx", -- S->C  (userId, speed) someone nearby started a swing
	"HitFx", -- S->C  (spot, broke) someone nearby hit a mound
	"Notify", -- S->C  (text, kind)
	"Announce", -- S->C  (text, color) server-wide banner
	"SellFx", -- S->C  (total, count)
}
local FUNCTIONS = {
	"Buy", -- (kind, id) -> ok, message
	"Travel", -- (zoneId | "Hub") -> ok, message
	"ClaimQuest", -- (questId) -> ok, message
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		Remotes[name] = r
	end
	for _, name in FUNCTIONS do
		local r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = folder
		Remotes[name] = r
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in EVENTS do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
