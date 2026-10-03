-- Procedural pickaxe swing: tweens the R15 shoulder + waist Motor6D C0s.
-- Used for the local player and (cosmetically) for nearby players. R6 rigs are skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Swing = {}

local waistBase = setmetatable({}, { __mode = "k" })
local activeToken = setmetatable({}, { __mode = "k" })

local function tween(inst, time, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style, dir), goal)
	tw:Play()
	return tw
end

-- Plays one swing. `onImpact` fires at the moment the pick would strike the ground.
function Swing.Play(char: Model, speed: number, onImpact: (() -> ())?)
	local shoulder = char:FindFirstChild("RightShoulder", true)
	local waist = char:FindFirstChild("Waist", true)
	local orig = shoulder and shoulder:GetAttribute("OrigC0")
	local windT, strikeT, recoverT = speed * 0.38, speed * 0.14, speed * 0.24

	if not shoulder or not orig then
		-- No animatable rig: just keep the timing so gameplay is identical.
		if onImpact then
			task.delay(windT + strikeT, onImpact)
		end
		return
	end

	if waist and not waistBase[waist] then
		waistBase[waist] = waist.C0
	end
	local wBase = waist and waistBase[waist]

	local token = {}
	activeToken[char] = token
	local A = Config.Swing

	task.spawn(function()
		tween(shoulder, windT, { C0 = orig * CFrame.Angles(A.Wind, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if waist then
			tween(waist, windT, { C0 = wBase * CFrame.Angles(-0.2, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
		task.wait(windT)
		if activeToken[char] ~= token then
			return
		end

		tween(shoulder, strikeT, { C0 = orig * CFrame.Angles(A.Strike, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if waist then
			tween(waist, strikeT, { C0 = wBase * CFrame.Angles(0.3, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(strikeT)
		if activeToken[char] ~= token then
			return
		end
		if onImpact then
			onImpact()
		end

		tween(shoulder, recoverT, { C0 = orig * CFrame.Angles(A.Carry, 0, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		if waist then
			tween(waist, recoverT, { C0 = wBase }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
	end)
end

return Swing
