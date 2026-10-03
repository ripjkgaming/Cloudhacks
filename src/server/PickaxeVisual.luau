-- Builds the pickaxe model in the player's hand and sets the "carry" arm pose.
-- Everything is welded Parts (no meshes/unions) so it stays cheap.
-- R15 rigs only; R6 characters simply don't get the visual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local PickaxeVisual = {}

local function makePart(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function build(def, hand)
	local s = def.Scale
	local length = 3.6 * s
	local model = Instance.new("Model")
	model.Name = "Pickaxe"

	-- The shaft runs along the hand's -Y axis (out past the fingers); the grip is near its butt end.
	local handleCF = hand.CFrame * CFrame.new(0, -(length / 2 - 0.9), 0)
	local handle = makePart(model, "Handle", Vector3.new(0.28, length, 0.28), handleCF, def.HandleColor, Enum.Material.Wood)
	local headCF = handleCF * CFrame.new(0, -length / 2, 0)
	local head = makePart(model, "Head", Vector3.new(0.42, 0.42, 2.0 * s), headCF, def.HeadColor, def.HeadMaterial)

	-- Two curved tips bend toward the shaft's end so the head reads as a pick.
	for _, sign in { -1, 1 } do
		makePart(
			model,
			"Tip",
			Vector3.new(0.34, 0.34, 1.1 * s),
			headCF * CFrame.new(0, -0.22 * s, sign * 1.35 * s) * CFrame.Angles(sign * 0.55, 0, 0),
			def.HeadColor,
			def.HeadMaterial
		)
	end

	if def.Glow then
		local light = Instance.new("PointLight")
		light.Color = def.HeadColor
		light.Range = 9
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = head
	end
	if def.Trail then
		local att = Instance.new("Attachment")
		att.Parent = head
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(def.HeadColor)
		pe.LightEmission = 1
		pe.Rate = 10
		pe.Lifetime = NumberRange.new(0.5, 0.9)
		pe.Speed = NumberRange.new(0.5, 1.5)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		pe.Parent = att
	end

	model.PrimaryPart = handle
	return model, handle
end

function PickaxeVisual.Apply(player)
	local data = DataService.Get(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local hand = char:FindFirstChild("RightHand")
	local shoulder = char:FindFirstChild("RightShoulder", true)
	if not hand or not shoulder then
		return -- not an R15 rig
	end

	local old = char:FindFirstChild("Pickaxe")
	if old then
		old:Destroy()
	end

	local model, handle = build(Config.Pickaxes[data.Pickaxe], hand)
	model.Parent = char
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = part
			w.Parent = part
		end
	end
	local grip = Instance.new("WeldConstraint")
	grip.Part0 = hand
	grip.Part1 = handle
	grip.Parent = handle

	-- Raise the arm into the carry pose. The client swing animation tweens from OrigC0.
	if shoulder:GetAttribute("OrigC0") == nil then
		shoulder:SetAttribute("OrigC0", shoulder.C0)
	end
	shoulder.C0 = shoulder:GetAttribute("OrigC0") * CFrame.Angles(Config.Swing.Carry, 0, 0)
end

function PickaxeVisual.Init()
	local function onCharacter(player, char)
		char:WaitForChild("RightHand", 10)
		char:WaitForChild("UpperTorso", 10)
		task.wait(0.1) -- let the rig finish assembling
		PickaxeVisual.Apply(player)
	end
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end

	-- Data may finish loading after the character spawns; apply again then.
	DataService.OnLoaded(function(player)
		PickaxeVisual.Apply(player)
	end)
end

return PickaxeVisual
