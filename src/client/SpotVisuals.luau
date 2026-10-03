-- Client-side visuals for dig mounds. The server only replicates the Hp / Depleted attributes;
-- shrinking, fading and the hit "punch" are tweened locally, so there is no extra network or server cost.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local SpotVisuals = {}

local active = {} -- [spot] = { Tween, Tips }

local function target(spot)
	local base = spot:GetAttribute("BaseSize") or spot.Size
	if spot:GetAttribute("Depleted") then
		return Vector3.new(base.X * 0.6, 0.2, base.Z * 0.6), 1, 1
	end
	local f = math.clamp((spot:GetAttribute("Hp") or 1) / (spot:GetAttribute("MaxHp") or 1), 0, 1)
	local tipFade = if f < 1 then 1 else 0 -- bone tip disappears once you start digging
	return Vector3.new(base.X * (0.72 + 0.28 * f), base.Y * (0.5 + 0.5 * f), base.Z * (0.72 + 0.28 * f)), 0, tipFade
end

local function refresh(spot, animate: boolean)
	local entry = active[spot]
	if not entry then
		return
	end
	local size, transparency, tipFade = target(spot)
	if entry.Tween then
		entry.Tween:Cancel()
	end
	if animate then
		local popBack = transparency == 0 and spot.Transparency == 1
		entry.Tween = TweenService:Create(
			spot,
			TweenInfo.new(popBack and 0.4 or 0.14, popBack and Enum.EasingStyle.Back or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = size, Transparency = transparency }
		)
		entry.Tween:Play()
		for _, tip in entry.Tips do
			TweenService:Create(tip, TweenInfo.new(0.2), { Transparency = tipFade }):Play()
		end
	else
		spot.Size = size
		spot.Transparency = transparency
		for _, tip in entry.Tips do
			tip.Transparency = tipFade
		end
	end
end

local function setup(spot)
	if active[spot] or not spot:IsA("BasePart") then
		return
	end
	local tips = {}
	for _, c in spot:GetChildren() do
		if c:IsA("BasePart") then
			table.insert(tips, c)
		end
	end
	active[spot] = { Tips = tips }
	spot.AttributeChanged:Connect(function(name)
		if name == "Hp" or name == "Depleted" then
			refresh(spot, true)
		end
	end)
	refresh(spot, false)
end

-- Squash-and-stretch on each pickaxe hit.
function SpotVisuals.Punch(spot)
	local entry = active[spot]
	if not entry or spot:GetAttribute("Depleted") then
		return
	end
	local size = target(spot)
	if entry.Tween then
		entry.Tween:Cancel()
	end
	spot.Size = Vector3.new(size.X * 1.14, size.Y * 0.8, size.Z * 1.14)
	entry.Tween = TweenService:Create(spot, TweenInfo.new(0.22, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Size = size })
	entry.Tween:Play()
end

function SpotVisuals.Init()
	for _, spot in CollectionService:GetTagged("DigSpot") do
		setup(spot)
	end
	CollectionService:GetInstanceAddedSignal("DigSpot"):Connect(function(spot)
		task.defer(setup, spot)
	end)
	CollectionService:GetInstanceRemovedSignal("DigSpot"):Connect(function(spot)
		active[spot] = nil
	end)
end

return SpotVisuals
