-- Holds the latest player data snapshot sent by the server and notifies listeners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local State = { Data = nil }
local listeners = {}

function State.Connect(fn)
	table.insert(listeners, fn)
	if State.Data then
		fn(State.Data)
	end
end

Remotes.State.OnClientEvent:Connect(function(data)
	State.Data = data
	for _, fn in listeners do
		task.spawn(fn, data)
	end
end)

return State
