-- Fire-and-forget sound player. Sound ids/volumes live in Config.Sounds so they're easy to swap.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Audio = {}

function Audio.Play(name: string, pitchJitter: number?)
	local def = Config.Sounds[name]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def.Id
	s.Volume = def.Volume
	s.PlaybackSpeed = def.Speed * (1 + (math.random() - 0.5) * (pitchJitter or 0))
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

return Audio
