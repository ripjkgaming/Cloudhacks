-- Particles and 3D flair: dust bursts on hits, the fossil "reveal" fly-out, light beams and shock rings.
-- Everything is short-lived and cleaned up with Debris; mound emitters are created lazily and reused.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}

local dustEmitters = setmetatable({}, { __mode = "k" })

local function getDust(spot)
	local e = dustEmitters[spot]
	if e and e.Parent then
		return e
	end
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, spot.Size.Y * 0.5, 0)
	att.Parent = spot
	e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(9, 17)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -26, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(spot.Color:Lerp(Color3.new(1, 1, 1), 0.15))
	e.Parent = att
	dustEmitters[spot] = e
	return e
end

function Effects.Hit(spot, broke: boolean?)
	local e = getDust(spot)
	e:Emit(if broke then 22 else 9)
end

local function flyingPart(color: Color3, size: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Parent = Workspace
	return p
end

local function sparkleEmitter(parent: Instance, color: Color3, rate: number, speed: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

local function lightBeam(pos: Vector3, color: Color3, height: number)
	local beam = flyingPart(color, Vector3.new(height, 2.2, 2.2))
	beam.Shape = Enum.PartType.Cylinder
	beam.CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Transparency = 0.2
	TweenService:Create(beam, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(height, 0.4, 0.4),
	}):Play()
	Debris:AddItem(beam, 1.3)
end

local function shockRing(pos: Vector3, color: Color3)
	local ring = flyingPart(color, Vector3.new(0.3, 4, 4))
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.3
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.3, 38, 38),
	}):Play()
	Debris:AddItem(ring, 1)
end

-- The fossil pops out of the mound, spins, then zips into the player.
function Effects.Reveal(spot, fossil)
	local rarity = Config.RarityByName[fossil.Rarity]
	local color = rarity.Color
	local origin = spot.Position + Vector3.new(0, spot.Size.Y * 0.5, 0)

	local scale = 1 + (rarity.Index - 1) * 0.25
	local chunk = flyingPart(color, Vector3.new(1.5, 0.7, 0.7) * scale)
	chunk.CFrame = CFrame.new(origin)
	local emitter = sparkleEmitter(chunk, color, 18 + rarity.Index * 10, 6 + rarity.Index)
	emitter:Emit(12 + rarity.Index * 6)

	if rarity.Index >= 3 then
		lightBeam(origin, color, 30 + rarity.Index * 6)
	end
	if rarity.Index >= 4 then
		shockRing(origin, color)
	end

	local rise, hold, fly = 0.7, 0.35, 0.35
	local height = 6 + rarity.Index
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if t < rise then
			local a = 1 - (1 - t / rise) ^ 3
			chunk.CFrame = CFrame.new(origin + Vector3.new(0, a * height, 0)) * CFrame.Angles(t * 6, t * 9, 0)
		elseif t < rise + hold or not hrp then
			chunk.CFrame = CFrame.new(origin + Vector3.new(0, height + math.sin(t * 8) * 0.25, 0)) * CFrame.Angles(t * 6, t * 9, 0)
			if t >= rise + hold then
				conn:Disconnect()
				chunk:Destroy()
			end
		elseif t < rise + hold + fly then
			local a = ((t - rise - hold) / fly) ^ 2
			local from = origin + Vector3.new(0, height, 0)
			chunk.CFrame = CFrame.new(from:Lerp(hrp.Position + Vector3.new(0, 1.5, 0), a)) * CFrame.Angles(t * 6, t * 9, 0)
			chunk.Size = Vector3.new(1.5, 0.7, 0.7) * scale * (1 - a * 0.8)
		else
			conn:Disconnect()
			chunk:Destroy()
		end
	end)
	Debris:AddItem(chunk, 3)
end

-- Small "ka-ching" burst around the player when selling.
function Effects.CoinBurst()
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = hrp
	local e = sparkleEmitter(att, Color3.fromRGB(255, 216, 80), 0, 14)
	e.Acceleration = Vector3.new(0, -12, 0)
	e:Emit(40)
	Debris:AddItem(att, 2)
end

return Effects
