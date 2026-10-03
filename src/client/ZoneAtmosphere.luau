-- Detects which zone the player is in and cross-fades lighting/atmosphere/colour grading to match.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local ZoneAtmosphere = {}

local current
ZoneAtmosphere.OnZoneChanged = function(_def) end

local function apply(def)
	local L = def.Lighting
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, { ClockTime = L.ClockTime, Ambient = L.Ambient, OutdoorAmbient = L.Ambient }):Play()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, info, { Color = L.AtmoColor, Density = L.AtmoDensity, Haze = L.AtmoHaze }):Play()
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		TweenService:Create(cc, info, { TintColor = L.Tint, Saturation = L.Saturation }):Play()
	end
end

local function zoneAt(pos: Vector3)
	for _, zone in Config.Zones do
		local c = Config.ZoneCenter(zone.Index)
		if math.abs(pos.X - c.X) < Config.ZoneHalfSize + 20 and math.abs(pos.Z - c.Z) < Config.ZoneHalfSize + 20 then
			return zone
		end
	end
	if Vector3.new(pos.X, 0, pos.Z).Magnitude < 90 then
		return Config.Hub
	end
	return nil -- on the bridge / in between: keep whatever we had
end

function ZoneAtmosphere.Init()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local char = Players.LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local def = zoneAt(hrp.Position)
				if def and def ~= current then
					current = def
					apply(def)
					ZoneAtmosphere.OnZoneChanged(def)
				end
			end
		end
	end)
end

return ZoneAtmosphere
