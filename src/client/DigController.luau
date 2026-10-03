-- Player input + the dig loop: hold click / F / R2 / the mobile button to keep swinging.
-- Targets the mound under the cursor (if in reach) or the nearest one in reach, faces it, plays the swing,
-- and at the moment of impact sends the hit to the server and fires local effects optimistically.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Audio)
local Config = require(ReplicatedStorage.Shared.Config)
local Effects = require(script.Parent.Effects)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpotVisuals = require(script.Parent.SpotVisuals)
local State = require(script.Parent.State)
local Swing = require(script.Parent.Swing)

local player = Players.LocalPlayer

local DigController = {}

local sources = {} -- active hold sources: mouse / key / touch
local loopRunning = false
local target = nil
local lastHint = 0
local highlight

-- Set by Main: returns true while a menu is open (digging is paused).
DigController.IsBlocked = function()
	return false
end
-- Set by Main: shows a toast.
DigController.Hint = function(_text) end

local function character()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return char, hrp, hum
	end
	return nil
end

local function hoverSpot(char)
	if not UserInputService.MouseEnabled then
		return nil
	end
	local camera = Workspace.CurrentCamera
	local loc = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(loc.X, loc.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	if not hit then
		return nil
	end
	local inst = hit.Instance
	if CollectionService:HasTag(inst, "DigSpot") then
		return inst
	end
	if inst.Parent and CollectionService:HasTag(inst.Parent, "DigSpot") then
		return inst.Parent
	end
	return nil
end

local function reachOf()
	local data = State.Data
	return data and Config.Pickaxes[data.Pickaxe].Reach or 12
end

local function flatDistance(a: Vector3, b: Vector3)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function findTarget()
	local char, hrp = character()
	if not char then
		return nil
	end
	local reach = reachOf() + 3 -- mound radius
	local hover = hoverSpot(char)
	if hover and not hover:GetAttribute("Depleted") and flatDistance(hover.Position, hrp.Position) <= reach then
		return hover
	end
	local best, bestD = nil, math.huge
	for _, spot in CollectionService:GetTagged("DigSpot") do
		if not spot:GetAttribute("Depleted") then
			local d = flatDistance(spot.Position, hrp.Position)
			if d <= reach and d < bestD then
				best, bestD = spot, d
			end
		end
	end
	return best
end

local function swingAt(spot)
	local char, hrp, hum = character()
	local data = State.Data
	if not char or not data then
		return
	end
	local pick = Config.Pickaxes[data.Pickaxe]

	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(spot.Position.X, hrp.Position.Y, spot.Position.Z))
	Remotes.SwingStart:FireServer()
	Audio.Play("Swing", 0.2)

	Swing.Play(char, pick.Speed, function()
		if not spot.Parent then
			return
		end
		Remotes.Dig:FireServer(spot)
		Effects.Hit(spot, false)
		SpotVisuals.Punch(spot)
		Audio.Play("Hit", 0.3)
		-- tiny camera nudge
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * 0.3, -0.12, 0)
		TweenService:Create(hum, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CameraOffset = Vector3.zero }):Play()
	end)
	task.wait(pick.Speed)
end

local function anyHeld()
	return next(sources) ~= nil
end

local function startLoop()
	if loopRunning then
		return
	end
	loopRunning = true
	task.spawn(function()
		while anyHeld() do
			if DigController.IsBlocked() or not State.Data or not character() then
				task.wait(0.1)
			else
				local spot = findTarget()
				if spot then
					swingAt(spot)
				else
					if os.clock() - lastHint > 4 then
						lastHint = os.clock()
						DigController.Hint("Walk up to a dirt mound with a bone sticking out to dig!")
					end
					task.wait(0.15)
				end
			end
		end
		loopRunning = false
	end)
end

local function setSource(name: string, held: boolean)
	sources[name] = if held then true else nil
	if held then
		startLoop()
	end
end

-- Server told us what happened with the swing we just sent.
function DigController.OnResult(res)
	if res.Full then
		if os.clock() - lastHint > 2 then
			lastHint = os.clock()
			DigController.Hint("Backpack full! Sell at the Fossil Museum or upgrade your pack.")
		end
		return
	end
	if res.Broke and res.FossilId then
		local fossil = Config.FossilById[res.FossilId]
		local spot = res.Spot
		Effects.Hit(spot, true)
		Effects.Reveal(spot, fossil)
		local rarity = Config.RarityByName[fossil.Rarity]
		Audio.Play("Break", 0.2)
		Audio.Play(if rarity.Index >= 3 then "Rare" else "Find")
		DigController.OnFind(fossil, res.IsNew)
	end
end
DigController.OnFind = function(_fossil, _isNew) end

function DigController.Init()
	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.85
	highlight.FillColor = Color3.fromRGB(255, 220, 140)
	highlight.OutlineColor = Color3.fromRGB(255, 190, 70)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = Workspace

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			setSource("mouse", true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			setSource("mouse", false)
		end
	end)

	ContextActionService:BindAction("FossilDig", function(_, state)
		setSource("action", state == Enum.UserInputState.Begin)
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("FossilDig", "⛏")
	ContextActionService:SetPosition("FossilDig", UDim2.new(1, -110, 1, -170))

	-- Highlight the mound you'd hit (cheap: ~8 Hz).
	task.spawn(function()
		while true do
			task.wait(0.12)
			if DigController.IsBlocked() then
				target = nil
			else
				target = findTarget()
			end
			highlight.Adornee = target
		end
	end)
end

return DigController
