-- Builds the entire map from plain Parts at server start: hub + museum, bridge, 5 themed zones,
-- dig mounds, props, weather emitters and lighting.
--
-- Optimisation notes:
--  * every part is Anchored; decorations default to CanCollide/CanQuery/CanTouch/CastShadow = false
--  * no meshes, unions or per-part scripts; weather is one emitter per zone
--  * ~1000 parts total, grouped in folders so you can delete/stream them easily

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local PI = math.pi
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

----------------------------------------------------------------------
-- Part helpers
----------------------------------------------------------------------
local function new(parent: Instance, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Vertical cylinder centred on `pos` (Roblox cylinders run along X, so rotate 90deg about Z).
local function cyl(parent, pos: Vector3, height: number, diameter: number, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = V3(height, diameter, diameter)
	props.CFrame = CF(pos) * ANG(0, 0, PI / 2)
	return new(parent, props)
end

local function ball(parent, pos: Vector3, size: Vector3, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Size = size
	props.Position = pos
	return new(parent, props)
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function sign(parent, cf: CFrame, size: Vector3, title: string, subtitle: string?, color: Color3)
	local board = new(parent, { Name = "Sign", Size = size, CFrame = cf, Color = Color3.fromRGB(46, 36, 30), Material = Enum.Material.Wood, CanCollide = true })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0
		g.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, subtitle and 0.62 or 1, 0)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = title
		t.Parent = g
		if subtitle then
			local s = Instance.new("TextLabel")
			s.BackgroundTransparency = 1
			s.Position = UDim2.fromScale(0, 0.62)
			s.Size = UDim2.fromScale(1, 0.3)
			s.Font = Enum.Font.GothamMedium
			s.TextScaled = true
			s.TextColor3 = Color3.fromRGB(240, 228, 208)
			s.Text = subtitle
			s.Parent = g
		end
	end
	return board
end

----------------------------------------------------------------------
-- Lighting
----------------------------------------------------------------------
function WorldBuilder.SetupLighting()
	local hub = Config.Hub.Lighting
	Lighting.ClockTime = hub.ClockTime
	Lighting.Ambient = hub.Ambient
	Lighting.OutdoorAmbient = hub.Ambient
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.GeographicLatitude = 25

	local atmo = Instance.new("Atmosphere")
	atmo.Color = hub.AtmoColor
	atmo.Decay = Color3.fromRGB(120, 130, 150)
	atmo.Density = hub.AtmoDensity
	atmo.Offset = 0.2
	atmo.Glare = 0.2
	atmo.Haze = hub.AtmoHaze
	atmo.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.TintColor = hub.Tint
	cc.Saturation = hub.Saturation
	cc.Contrast = 0.08
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	rays.Parent = Lighting
end

----------------------------------------------------------------------
-- Props
----------------------------------------------------------------------
local function rock(parent, pos, rng, color, material)
	local s = rng:NextNumber(3, 8)
	new(parent, {
		Name = "Rock",
		Size = V3(s, s * rng:NextNumber(0.6, 1.1), s * rng:NextNumber(0.7, 1.2)),
		CFrame = CF(pos + V3(0, s * 0.2, 0)) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 2 * PI), rng:NextNumber(-0.3, 0.3)),
		Color = color,
		Material = material,
		CanCollide = true,
	})
end

local function tree(parent, pos, rng)
	local h = rng:NextNumber(14, 24)
	cyl(parent, pos + V3(0, h / 2, 0), h, 2.4, { Name = "Trunk", Color = Color3.fromRGB(94, 66, 44), Material = Enum.Material.Wood, CanCollide = true })
	for i = 1, 3 do
		local d = rng:NextNumber(11, 16)
		ball(parent, pos + V3(rng:NextNumber(-3, 3), h + rng:NextNumber(-1, 3), rng:NextNumber(-3, 3)), V3(d, d * 0.8, d), {
			Name = "Leaves",
			Color = Color3.fromRGB(rng:NextInteger(40, 70), rng:NextInteger(120, 160), rng:NextInteger(50, 80)),
			Material = Enum.Material.LeafyGrass,
		})
	end
end

local function fern(parent, pos, rng)
	local yaw0 = rng:NextNumber(0, 2 * PI)
	local green = Color3.fromRGB(rng:NextInteger(50, 80), rng:NextInteger(150, 185), rng:NextInteger(60, 90))
	for i = 0, 4 do
		local yaw = yaw0 + i * (2 * PI / 5)
		new(parent, {
			Name = "Frond",
			Size = V3(1.6, 0.2, 7),
			CFrame = CF(pos) * ANG(0, yaw, 0) * CF(0, 1.6, -3) * ANG(0.55, 0, 0),
			Color = green,
			Material = Enum.Material.Grass,
		})
	end
end

local function mushroom(parent, pos, rng)
	local h = rng:NextNumber(3, 7)
	cyl(parent, pos + V3(0, h / 2, 0), h, 1.2, { Name = "Stem", Color = Color3.fromRGB(235, 225, 205), Material = Enum.Material.SmoothPlastic })
	ball(parent, pos + V3(0, h, 0), V3(h * 1.6, h * 0.7, h * 1.6), { Name = "Cap", Color = Color3.fromRGB(210, 70, 70), Material = Enum.Material.SmoothPlastic })
end

local function cactus(parent, pos, rng)
	local h = rng:NextNumber(8, 14)
	local green = Color3.fromRGB(86, 150, 76)
	cyl(parent, pos + V3(0, h / 2, 0), h, 2.4, { Name = "Cactus", Color = green, Material = Enum.Material.Grass, CanCollide = true })
	local dir = if rng:NextNumber() < 0.5 then 1 else -1
	new(parent, { Name = "Arm", Shape = Enum.PartType.Cylinder, Size = V3(3.2, 1.6, 1.6), Position = pos + V3(dir * 2.4, h * 0.5, 0), Color = green, Material = Enum.Material.Grass })
	cyl(parent, pos + V3(dir * 3.7, h * 0.5 + 2, 0), 4, 1.6, { Name = "ArmUp", Color = green, Material = Enum.Material.Grass })
end

local function pillar(parent, pos, rng)
	local w = rng:NextNumber(6, 10)
	local h = rng:NextNumber(10, 24)
	new(parent, {
		Name = "Mesa",
		Size = V3(w, h, w * rng:NextNumber(0.8, 1.2)),
		CFrame = CF(pos + V3(0, h / 2 - 1, 0)) * ANG(0, rng:NextNumber(0, 2 * PI), 0),
		Color = Color3.fromRGB(205, 150, 95),
		Material = Enum.Material.Sandstone,
		CanCollide = true,
	})
	new(parent, {
		Name = "MesaCap",
		Size = V3(w * 1.25, 2, w * 1.25),
		CFrame = CF(pos + V3(0, h - 1, 0)) * ANG(0, rng:NextNumber(0, 2 * PI), 0),
		Color = Color3.fromRGB(185, 128, 80),
		Material = Enum.Material.Sandstone,
	})
end

local function dune(parent, pos, rng)
	ball(parent, pos + V3(0, -1, 0), V3(rng:NextNumber(30, 50), rng:NextNumber(7, 11), rng:NextNumber(24, 36)), {
		Name = "Dune",
		Color = Color3.fromRGB(236, 202, 136),
		Material = Enum.Material.Sand,
	})
end

local function pine(parent, pos, rng)
	local h = rng:NextNumber(14, 22)
	cyl(parent, pos + V3(0, h * 0.3, 0), h * 0.6, 1.8, { Name = "Trunk", Color = Color3.fromRGB(86, 64, 48), Material = Enum.Material.Wood, CanCollide = true })
	local sizes = { 14, 10, 6 }
	for i, d in sizes do
		ball(parent, pos + V3(0, h * (0.4 + i * 0.17), 0), V3(d, 6, d), { Name = "Boughs", Color = Color3.fromRGB(58, 110, 92), Material = Enum.Material.LeafyGrass })
		ball(parent, pos + V3(0, h * (0.4 + i * 0.17) + 1.6, 0), V3(d * 0.8, 3, d * 0.8), { Name = "Snow", Color = Color3.fromRGB(240, 246, 255), Material = Enum.Material.Snow })
	end
end

local function iceCrystal(parent, pos, rng)
	for i = 1, 3 do
		local h = rng:NextNumber(6, 14)
		new(parent, {
			Name = "Ice",
			Size = V3(2, h, 2),
			CFrame = CF(pos + V3(rng:NextNumber(-2, 2), h / 2 - 1, rng:NextNumber(-2, 2))) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, PI), rng:NextNumber(-0.3, 0.3)) * ANG(0, PI / 4, 0),
			Color = Color3.fromRGB(150, 215, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			CanCollide = i == 1,
		})
	end
end

local function snowMound(parent, pos, rng)
	ball(parent, pos + V3(0, -0.5, 0), V3(rng:NextNumber(10, 20), rng:NextNumber(4, 7), rng:NextNumber(10, 20)), { Name = "Snowdrift", Color = Color3.fromRGB(246, 250, 255), Material = Enum.Material.Snow })
end

local function lavaPool(parent, pos, rng)
	local d = rng:NextNumber(10, 18)
	cyl(parent, pos + V3(0, 0.06, 0), 0.2, d + 2.5, { Name = "LavaRim", Color = Color3.fromRGB(30, 22, 24), Material = Enum.Material.Basalt })
	cyl(parent, pos + V3(0, 0.2, 0), 0.2, d, { Name = "Lava", Color = Color3.fromRGB(255, 96, 28), Material = Enum.Material.Neon })
end

local function obsidianSpike(parent, pos, rng)
	for i = 1, 3 do
		local h = rng:NextNumber(7, 17)
		new(parent, {
			Name = "Obsidian",
			Size = V3(2.4, h, 2.4),
			CFrame = CF(pos + V3(rng:NextNumber(-2.5, 2.5), h / 2 - 1, rng:NextNumber(-2.5, 2.5))) * ANG(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, PI), rng:NextNumber(-0.25, 0.25)),
			Color = Color3.fromRGB(26, 22, 34),
			Material = Enum.Material.Glass,
			Reflectance = 0.1,
			CanCollide = i == 1,
		})
	end
end

local function emberCrystal(parent, pos, rng)
	local h = rng:NextNumber(2, 4)
	new(parent, {
		Name = "EmberCrystal",
		Size = V3(1.2, h, 1.2),
		CFrame = CF(pos + V3(0, h / 2, 0)) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, PI), 0),
		Color = Color3.fromRGB(255, 150, 60),
		Material = Enum.Material.Neon,
	})
end

local STYLES = {
	quarry = {
		{ 4, function(p, pos, rng) rock(p, pos, rng, Color3.fromRGB(128, 112, 98), Enum.Material.Slate) end },
		{ 2, function(p, pos, rng) rock(p, pos, rng, Color3.fromRGB(170, 140, 108), Enum.Material.Sandstone) end },
		{ 1, pillar },
	},
	fern = { { 3, tree }, { 4, fern }, { 2, mushroom }, { 1, function(p, pos, rng) rock(p, pos, rng, Color3.fromRGB(84, 100, 80), Enum.Material.Slate) end } },
	dunes = { { 3, cactus }, { 2, pillar }, { 3, dune } },
	tundra = { { 3, pine }, { 3, iceCrystal }, { 3, snowMound } },
	magma = { { 3, obsidianSpike }, { 3, lavaPool }, { 2, emberCrystal }, { 2, function(p, pos, rng) rock(p, pos, rng, Color3.fromRGB(40, 32, 36), Enum.Material.Basalt) end } },
}

local function pickBuilder(style, rng)
	local total = 0
	for _, e in style do
		total += e[1]
	end
	local roll = rng:NextNumber() * total
	for _, e in style do
		roll -= e[1]
		if roll <= 0 then
			return e[2]
		end
	end
	return style[1][2]
end

-- One emitter per zone, spread across a wide invisible volume. Very cheap compared to many emitters.
local function weather(parent, center: Vector3, kind: string)
	local vol = new(parent, { Name = "Weather", Size = V3(190, 2, 190), Position = center + V3(0, 28, 0), Transparency = 1 })
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Orientation = Enum.ParticleOrientation.FacingCamera
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if kind == "snow" then
		e.Rate = 40
		e.Lifetime = NumberRange.new(8, 11)
		e.Speed = NumberRange.new(2, 4)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Size = NumberSequence.new(0.5)
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		e.Acceleration = V3(2, 0, 1)
		e.LightEmission = 0.3
	elseif kind == "embers" then
		vol.Position = center + V3(0, 2, 0)
		e.Rate = 22
		e.Lifetime = NumberRange.new(5, 8)
		e.Speed = NumberRange.new(2, 5)
		e.EmissionDirection = Enum.NormalId.Top
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
		e.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 60, 20))
		e.LightEmission = 1
	elseif kind == "fireflies" then
		vol.Position = center + V3(0, 10, 0)
		vol.Size = V3(190, 14, 190)
		e.Rate = 14
		e.Lifetime = NumberRange.new(6, 9)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Size = NumberSequence.new(0.7)
		e.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120))
		e.LightEmission = 1
		e.RotSpeed = NumberRange.new(-30, 30)
	elseif kind == "sand" then
		vol.Position = center + V3(-90, 6, 0)
		vol.Size = V3(2, 12, 190)
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 16
		e.Lifetime = NumberRange.new(5, 7)
		e.Speed = NumberRange.new(14, 20)
		e.EmissionDirection = Enum.NormalId.Right
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.85), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(235, 200, 140))
	else -- dust motes
		vol.Position = center + V3(0, 8, 0)
		vol.Size = V3(190, 14, 190)
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 8
		e.Lifetime = NumberRange.new(6, 9)
		e.Speed = NumberRange.new(0.5, 1.5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(230, 205, 170))
	end
	e.Parent = vol
end

----------------------------------------------------------------------
-- Zones
----------------------------------------------------------------------
local function buildZone(zone, root, spotsOut)
	local index = zone.Index
	local center = Config.ZoneCenter(index)
	local f = folder(root, zone.Name)
	local propsFolder = folder(f, "Props")
	local spotsFolder = folder(f, "DigSpots")
	local rng = Random.new(index * 7919)
	local half = Config.ZoneHalfSize

	-- Ground plate + darker rock underneath for visual depth.
	new(f, { Name = "Ground", Size = V3(half * 2, 6, half * 2), Position = center + V3(0, -3, 0), Color = zone.GroundColor, Material = zone.GroundMaterial, CanCollide = true, CanQuery = true })
	new(f, { Name = "Underside", Size = V3(half * 2 + 8, 14, half * 2 + 8), Position = center + V3(0, -13, 0), Color = zone.GroundColor:Lerp(Color3.new(0, 0, 0), 0.55), Material = Enum.Material.Slate, CanCollide = true })

	local arrival = Config.ZoneArrival(index)
	local placed = {}

	local function farEnough(p: Vector3, minDist: number)
		for _, q in placed do
			if (p - q).Magnitude < minDist then
				return false
			end
		end
		return (p - V3(arrival.X, 0, arrival.Z)).Magnitude > 18
	end

	-- Dig mounds
	for _ = 1, zone.SpotCount do
		for _ = 1, 40 do
			local a, r = rng:NextNumber(0, 2 * PI), rng:NextNumber(20, half - 18)
			local pos = center + V3(math.cos(a) * r, 0, math.sin(a) * r)
			if farEnough(pos, 15) then
				table.insert(placed, pos)
				local size = V3(7, 3.4, 7)
				local spot = ball(spotsFolder, pos + V3(0, 0.2, 0), size, {
					Name = "DigSpot",
					Color = zone.SpotColor,
					Material = zone.SpotMaterial,
					CanQuery = true,
				})
				spot:SetAttribute("ZoneId", zone.Id)
				spot:SetAttribute("BaseSize", size)
				CollectionService:AddTag(spot, "DigSpot")
				-- a bone tip poking out marks it as a dig site
				new(spot, {
					Name = "Tip",
					Size = V3(0.5, 0.5, 2.4),
					CFrame = CF(pos + V3(rng:NextNumber(-1.2, 1.2), 1.8, rng:NextNumber(-1.2, 1.2))) * ANG(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 2 * PI), rng:NextNumber(0.3, 0.9)),
					Color = Color3.fromRGB(238, 228, 200),
					Material = Enum.Material.SmoothPlastic,
					CanQuery = true,
				})
				table.insert(spotsOut, { Part = spot, Zone = zone })
				break
			end
		end
	end

	-- Scenery
	local style = STYLES[zone.Id]
	local propTarget = 34
	local tries = 0
	while propTarget > 0 and tries < 400 do
		tries += 1
		local a, r = rng:NextNumber(0, 2 * PI), rng:NextNumber(10, half - 6)
		local pos = center + V3(math.cos(a) * r, 0, math.sin(a) * r)
		if farEnough(pos, 12) then
			table.insert(placed, pos)
			propTarget -= 1
			pickBuilder(style, rng)(propsFolder, pos, rng)
		end
	end

	weather(f, center, zone.Weather)

	-- Entrance sign beside the arrival point
	local toCenter = (center - arrival) * V3(1, 0, 1)
	local face = CFrame.lookAt(V3(arrival.X, 0, arrival.Z), V3(arrival.X, 0, arrival.Z) + toCenter)
	local signPos = face * CF(22, 0, 4)
	for _, side in { -1, 1 } do
		new(f, { Name = "SignPost", Size = V3(1.2, 12, 1.2), CFrame = signPos * CF(side * 8, 6, 0), Color = Color3.fromRGB(70, 52, 40), Material = Enum.Material.Wood, CanCollide = true })
	end
	sign(f, signPos * CF(0, 9.5, 0), V3(17, 5, 0.8), zone.Name, zone.Blurb, Color3.fromRGB(255, 196, 84))
end

----------------------------------------------------------------------
-- Hub: ground, museum, dino skeleton, bridge
----------------------------------------------------------------------
local function buildSkeleton(parent, origin: Vector3)
	local f = folder(parent, "Skeleton")
	local bone = Color3.fromRGB(240, 232, 208)
	local mat = Enum.Material.SmoothPlastic
	local function spineY(t: number)
		return 11 + math.sin(t * PI) * 2.2
	end
	new(f, { Name = "Pedestal", Size = V3(34, 2, 12), Position = origin + V3(0, 1, 0), Color = Color3.fromRGB(150, 146, 140), Material = Enum.Material.Marble, CanCollide = true, CastShadow = true })
	-- spine + tail (x from -14 tail to +10 neck)
	for i = 0, 16 do
		local t = i / 16
		local x = -15 + t * 25
		local d = if t < 0.5 then 1.0 + t * 2.4 else 2.2 - (t - 0.5) * 1.2
		ball(f, origin + V3(x, spineY(t), 0), V3(d, d, d), { Name = "Vertebra", Color = bone, Material = mat })
	end
	-- ribs
	for i = 6, 11 do
		local t = i / 16
		local x = -15 + t * 25
		for _, side in { -1, 1 } do
			new(f, { Name = "Rib", Size = V3(0.5, 5.5, 0.5), CFrame = CF(origin + V3(x, spineY(t) - 2.5, side * 1.4)) * ANG(side * -0.35, 0, 0), Color = bone, Material = mat })
		end
	end
	-- legs
	for _, x in { -1, 3.5 } do
		new(f, { Name = "Leg", Size = V3(1.4, 9, 1.4), CFrame = CF(origin + V3(x, 6, 2)) * ANG(0.12, 0, 0), Color = bone, Material = mat })
		new(f, { Name = "Foot", Size = V3(3.4, 0.9, 1.6), Position = origin + V3(x + 1, 2.4, 2.4), Color = bone, Material = mat })
	end
	-- skull
	new(f, { Name = "Skull", Size = V3(5.5, 2.6, 3), Position = origin + V3(13.5, spineY(1) + 1.3, 0), Color = bone, Material = mat })
	new(f, { Name = "Jaw", Size = V3(5, 0.8, 2.6), Position = origin + V3(13.4, spineY(1) - 0.4, 0), Color = bone, Material = mat })
	for _, side in { -1, 1 } do
		ball(f, origin + V3(14.5, spineY(1) + 1.9, side * 1.55), V3(0.9, 0.9, 0.9), { Name = "Eye", Color = Color3.fromRGB(20, 18, 16), Material = mat })
	end
end

local function buildMuseum(parent, onSell)
	local f = folder(parent, "Museum")
	local z0 = -42
	local stone = Color3.fromRGB(226, 218, 200)
	local trim = Color3.fromRGB(168, 120, 70)
	local function solid(props)
		props.CanCollide = true
		props.CanQuery = true
		props.CastShadow = true
		props.Color = props.Color or stone
		props.Material = props.Material or Enum.Material.Marble
		return new(f, props)
	end
	solid({ Name = "Steps", Size = V3(60, 1, 34), Position = V3(0, 0.5, z0), Material = Enum.Material.Slate, Color = Color3.fromRGB(150, 146, 140) })
	solid({ Name = "Floor", Size = V3(52, 0.6, 28), Position = V3(0, 1.3, z0 - 1) })
	solid({ Name = "BackWall", Size = V3(52, 16, 2), Position = V3(0, 9.6, z0 - 15) })
	for _, side in { -1, 1 } do
		solid({ Name = "SideWall", Size = V3(2, 16, 28), Position = V3(side * 25, 9.6, z0 - 1) })
	end
	for i = 0, 5 do
		local x = -22 + i * 8.8
		cyl(f, V3(x, 9.6, z0 + 12), 16, 2.6, { Name = "Column", Color = stone, Material = Enum.Material.Marble, CanCollide = true, CanQuery = true, CastShadow = true })
	end
	solid({ Name = "Roof", Size = V3(58, 2.4, 34), Position = V3(0, 18.8, z0 - 1), Color = trim, Material = Enum.Material.Wood })
	solid({ Name = "RoofTop", Size = V3(50, 2, 26), Position = V3(0, 20.8, z0 - 2), Color = trim:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Wood })
	sign(f, CF(0, 23.4, z0 + 14) * ANG(0, PI, 0), V3(30, 4.6, 1), "FOSSIL MUSEUM", nil, Color3.fromRGB(255, 205, 96))

	-- Sell counter
	local counter = solid({ Name = "Counter", Size = V3(18, 3.4, 3.4), Position = V3(0, 3.2, z0 + 2), Color = Color3.fromRGB(110, 78, 52), Material = Enum.Material.Wood })
	new(f, { Name = "CounterTop", Size = V3(19, 0.5, 4.2), Position = V3(0, 5.15, z0 + 2), Color = Color3.fromRGB(70, 50, 36), Material = Enum.Material.Wood })
	sign(f, CF(0, 10, z0 - 13.8), V3(22, 4, 0.8), "SELL YOUR FOSSILS", "Walk up to the counter and press E", Color3.fromRGB(255, 205, 96))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell All Fossils"
	prompt.ObjectText = "Museum Curator"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	prompt.Triggered:Connect(onSell)

	for _, x in { -14, 14 } do
		local lamp = Instance.new("PointLight")
		lamp.Range = 22
		lamp.Brightness = 1.4
		lamp.Color = Color3.fromRGB(255, 226, 170)
		lamp.Shadows = false
		local a = new(f, { Name = "Lamp", Size = V3(1.4, 1.4, 1.4), Position = V3(x, 15, z0 - 1), Color = Color3.fromRGB(255, 226, 170), Material = Enum.Material.Neon })
		lamp.Parent = a
	end
end

local function buildBridge(parent)
	local f = folder(parent, "Bridge")
	local dir = Config.ZoneCenter(1).Unit
	local startPos = dir * 70
	local endPos = dir * (Config.ZoneRingRadius - Config.ZoneHalfSize + 2)
	local length = (endPos - startPos).Magnitude
	local mid = (startPos + endPos) / 2
	local base = CFrame.lookAt(V3(mid.X, 0, mid.Z), V3(mid.X, 0, mid.Z) + dir)

	new(f, { Name = "Planks", Size = V3(14, 1, length), CFrame = base * CF(0, -0.5, 0), Color = Color3.fromRGB(142, 104, 70), Material = Enum.Material.WoodPlanks, CanCollide = true, CanQuery = true })
	for _, side in { -1, 1 } do
		new(f, { Name = "Rail", Size = V3(0.6, 0.6, length), CFrame = base * CF(side * 6.8, 3.2, 0), Color = Color3.fromRGB(96, 70, 48), Material = Enum.Material.Wood })
	end
	local count = math.floor(length / 20)
	for i = 0, count do
		local z = -length / 2 + i * (length / count)
		for _, side in { -1, 1 } do
			new(f, { Name = "Post", Size = V3(0.9, 4, 0.9), CFrame = base * CF(side * 6.8, 2, z), Color = Color3.fromRGB(80, 58, 40), Material = Enum.Material.Wood })
			if i % 2 == 0 then
				new(f, { Name = "Lantern", Size = V3(0.9, 0.9, 0.9), CFrame = base * CF(side * 6.8, 4.5, z), Color = Color3.fromRGB(255, 200, 110), Material = Enum.Material.Neon })
			end
		end
	end
end

local function buildHub(root, handlers)
	local f = folder(root, "Hub")
	cyl(f, V3(0, -3, 0), 6, 150, { Name = "Ground", Color = Color3.fromRGB(104, 156, 92), Material = Enum.Material.Grass, CanCollide = true, CanQuery = true })
	cyl(f, V3(0, -9, 0), 6, 158, { Name = "Underside", Color = Color3.fromRGB(86, 74, 66), Material = Enum.Material.Slate, CanCollide = true })
	cyl(f, V3(0, 0.05, 20), 0.2, 54, { Name = "Plaza", Color = Color3.fromRGB(196, 184, 160), Material = Enum.Material.Cobblestone })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = V3(10, 1, 10)
	spawn.Position = V3(0, 0.5, Config.HubSpawn.Z)
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = f

	buildMuseum(f, handlers.OnSell)
	buildSkeleton(f, V3(0, 1, 10))
	buildBridge(f)

	-- Directional sign toward the first dig zone
	sign(f, CF(14, 6, 62) * ANG(0, PI, 0), V3(14, 4, 0.8), "Dusty Quarry ->", "Cross the bridge to start digging", Color3.fromRGB(255, 196, 84))
	new(f, { Name = "SignPost", Size = V3(1, 6, 1), Position = V3(14, 3, 62.5), Color = Color3.fromRGB(70, 52, 40), Material = Enum.Material.Wood, CanCollide = true })

	-- trees
	local rng = Random.new(99)
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, 2 * PI), rng:NextNumber(52, 68)
		local pos = V3(math.cos(a) * r, 0, math.sin(a) * r)
		local nearBridge = math.abs(pos.X) < 22 and pos.Z > 30
		local nearMuseum = math.abs(pos.X) < 36 and pos.Z < -20
		if not nearBridge and not nearMuseum then
			tree(f, pos, rng)
		end
	end
end

----------------------------------------------------------------------
-- Entry point
----------------------------------------------------------------------
-- handlers.OnSell(player) is wired to the museum counter prompt.
-- Returns the list of dig spots: { { Part, Zone }, ... }
function WorldBuilder.Build(handlers)
	WorldBuilder.SetupLighting()

	local root = Instance.new("Folder")
	root.Name = "World"
	local spots = {}

	buildHub(root, handlers)
	for _, zone in Config.Zones do
		buildZone(zone, root, spots)
	end

	-- Abyss floor far below: anyone who falls off an island is returned to the hub.
	local abyss = new(root, { Name = "Abyss", Size = V3(6000, 2, 6000), Position = V3(0, -45, 0), Color = Color3.fromRGB(24, 38, 52), Material = Enum.Material.Slate, CanCollide = true, CanTouch = true })
	local recent = {}
	abyss.Touched:Connect(function(hit)
		local char = hit.Parent
		if char and char:FindFirstChildOfClass("Humanoid") and not recent[char] then
			recent[char] = true
			char:PivotTo(CFrame.new(Config.HubSpawn))
			task.delay(2, function()
				recent[char] = nil
			end)
		end
	end)

	root.Parent = Workspace
	return spots
end

return WorldBuilder
