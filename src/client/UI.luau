-- The whole interface, built in code (no assets): HUD, quest tracker, Shop / Quests / Collection / Map panels,
-- toasts, find popup, zone banner, server-wide announcements.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Audio = require(script.Parent.Audio)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)

local UI = {}

local player = Players.LocalPlayer

----------------------------------------------------------------------
-- Theme + tiny widget helpers
----------------------------------------------------------------------
local T = {
	Bg = Color3.fromRGB(38, 31, 27),
	Panel = Color3.fromRGB(58, 48, 41),
	Panel2 = Color3.fromRGB(74, 62, 52),
	Accent = Color3.fromRGB(255, 184, 64),
	Text = Color3.fromRGB(250, 240, 225),
	Dim = Color3.fromRGB(182, 168, 150),
	Good = Color3.fromRGB(112, 208, 120),
	Bad = Color3.fromRGB(232, 98, 88),
	Locked = Color3.fromRGB(96, 86, 76),
	Dark = Color3.fromRGB(40, 28, 10),
}
local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.GothamMedium

local function create(class: string, props, children)
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(r: number)
	return create("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color: Color3, thickness: number, transparency: number?)
	return create("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(p: number)
	return create("UIPadding", { PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p) })
end

local function label(parent, text: string, size: number, color: Color3?, font: Enum.Font?, props)
	local l = create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or T.Text,
		Font = font or BODY_FONT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	if props then
		for k, v in props do
			l[k] = v
		end
	end
	return l
end

local function tween(inst, time: number, goal, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function button(parent, size: UDim2, text: string, onClick)
	local b = create("TextButton", {
		Size = size,
		BackgroundColor3 = T.Accent,
		Text = text,
		Font = TITLE_FONT,
		TextSize = 18,
		TextColor3 = T.Dark,
		AutoButtonColor = false,
		Parent = parent,
	}, { corner(10) })
	local sc = create("UIScale", { Parent = b })
	b:SetAttribute("On", true)
	b.MouseEnter:Connect(function()
		if b:GetAttribute("On") then
			tween(sc, 0.1, { Scale = 1.06 })
		end
	end)
	b.MouseLeave:Connect(function()
		tween(sc, 0.1, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		if b:GetAttribute("On") then
			tween(sc, 0.06, { Scale = 0.94 })
		end
	end)
	b.MouseButton1Up:Connect(function()
		tween(sc, 0.1, { Scale = 1.04 })
	end)
	b.Activated:Connect(function()
		if b:GetAttribute("On") then
			Audio.Play("Click")
			onClick()
		end
	end)
	return b
end

local function setButton(b: TextButton, text: string, color: Color3, enabled: boolean)
	b.Text = text
	b.BackgroundColor3 = color
	b.TextColor3 = if enabled then T.Dark else T.Dim
	b:SetAttribute("On", enabled)
end

local function priceText(n: number)
	return "🪙 " .. Config.Abbrev(n)
end

----------------------------------------------------------------------
-- Root GUI (scaled for phones / small windows)
----------------------------------------------------------------------
local gui, root, uiScale
local fadeFrame
local toastHolder, findCard, bannerLabel
local panels = {}
local openPanelName
local hud = {}
local travelBusy = false

local function updateScale()
	local view = Workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(view.X / 1100, view.Y / 700), 0.6, 1.15)
	uiScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end

----------------------------------------------------------------------
-- Panels
----------------------------------------------------------------------
local function closePanel()
	if not openPanelName then
		return
	end
	local p = panels[openPanelName]
	openPanelName = nil
	tween(p.Scale, 0.12, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.12, function()
		if openPanelName ~= p.Name then
			p.Root.Visible = false
		end
	end)
end

local function showPanel(name: string)
	if openPanelName == name then
		closePanel()
		return
	end
	if openPanelName then
		panels[openPanelName].Root.Visible = false
	end
	local p = panels[name]
	openPanelName = name
	p.Root.Visible = true
	p.Scale.Scale = 0.85
	tween(p.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Audio.Play("Click")
	if State.Data and p.Refresh then
		p.Refresh(State.Data)
	end
end

local function newPanel(name: string, title: string, icon: string)
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.8),
		BackgroundColor3 = T.Bg,
		Visible = false,
		Parent = root,
	}, {
		corner(18),
		stroke(T.Accent, 2),
		create("UISizeConstraint", { MaxSize = Vector2.new(780, 540), MinSize = Vector2.new(360, 300) }),
	})
	local scale = create("UIScale", { Parent = frame })
	label(frame, `{icon}  {title}`, 28, T.Accent, TITLE_FONT, {
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -90, 0, 40),
	})
	local close = button(frame, UDim2.fromOffset(40, 40), "✕", closePanel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.BackgroundColor3 = T.Bad
	close.TextColor3 = T.Text
	local body = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -28, 1, -72),
		Parent = frame,
	})
	local p = { Name = name, Root = frame, Body = body, Scale = scale }
	panels[name] = p
	return p
end

local function scroller(parent, grid: boolean?)
	local sf = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Accent,
		Parent = parent,
	})
	if grid then
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(118, 112),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = sf,
		})
	else
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
	end
	create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4), Parent = sf })
	return sf
end

local function row(parent, height: number)
	return create("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = T.Panel, Parent = parent }, { corner(12), stroke(T.Panel2, 1.5) })
end

local function iconBox(parent, icon: string, color: Color3)
	local box = create("Frame", {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = color,
		Parent = parent,
	}, { corner(12) })
	label(box, icon, 30, T.Text, TITLE_FONT, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	return box
end

local function progressBar(parent, pos: UDim2, size: UDim2, color: Color3)
	local bg = create("Frame", { Position = pos, Size = size, BackgroundColor3 = T.Bg, Parent = parent }, { corner(8) })
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = bg }, {
		corner(8),
		create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)), Rotation = 90 }),
	})
	return bg, fill
end

----------------------------------------------------------------------
-- Shop (Pickaxes + Backpacks)
----------------------------------------------------------------------
local function buildShop()
	local p = newPanel("Shop", "Gear Shop", "🛒")
	local tabs = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = p.Body })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = tabs })
	local content = create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46), Parent = p.Body })

	local lists = { Pickaxes = scroller(content), Backpacks = scroller(content) }
	local tabButtons = {}
	local function selectTab(name)
		for n, l in lists do
			l.Visible = n == name
		end
		for n, b in tabButtons do
			b.BackgroundColor3 = if n == name then T.Accent else T.Panel2
			b.TextColor3 = if n == name then T.Dark else T.Text
		end
	end
	for _, n in { "Pickaxes", "Backpacks" } do
		tabButtons[n] = button(tabs, UDim2.fromOffset(140, 36), n, function()
			selectTab(n)
		end)
	end
	selectTab("Pickaxes")

	local function purchase(kind, id)
		local ok, msg = Remotes.Buy:InvokeServer(kind, id)
		UI.Toast(msg, if ok then "good" else "bad")
		if ok then
			Audio.Play("Buy")
		end
	end

	local rows = { Pickaxes = {}, Backpacks = {} }
	for i, def in Config.Pickaxes do
		local r = row(lists.Pickaxes, 74)
		r.LayoutOrder = i
		iconBox(r, "⛏️", def.HeadColor)
		label(r, def.Name, 20, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -220, 0, 24) })
		label(r, string.format("Power %.1f  ·  %.2fs/swing  ·  Luck x%.2f", def.Power, def.Speed, def.Luck), 14, T.Dim, BODY_FONT, {
			Position = UDim2.fromOffset(72, 36),
			Size = UDim2.new(1, -220, 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local b = button(r, UDim2.fromOffset(120, 42), "", function()
			purchase("pickaxe", i)
		end)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -12, 0.5, 0)
		rows.Pickaxes[i] = b
	end
	for i, def in Config.Backpacks do
		local r = row(lists.Backpacks, 74)
		r.LayoutOrder = i
		iconBox(r, "🎒", T.Panel2)
		label(r, def.Name, 20, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -220, 0, 24) })
		label(r, `Carry up to {def.Capacity} fossils`, 14, T.Dim, BODY_FONT, { Position = UDim2.fromOffset(72, 36), Size = UDim2.new(1, -220, 0, 20) })
		local b = button(r, UDim2.fromOffset(120, 42), "", function()
			purchase("backpack", i)
		end)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -12, 0.5, 0)
		rows.Backpacks[i] = b
	end

	function p.Refresh(data)
		for i, def in Config.Pickaxes do
			local b = rows.Pickaxes[i]
			if i < data.Pickaxe then
				setButton(b, "Owned", T.Locked, false)
			elseif i == data.Pickaxe then
				setButton(b, "Equipped", T.Good, false)
			elseif i == data.Pickaxe + 1 then
				setButton(b, priceText(def.Price), if data.Coins >= def.Price then T.Accent else T.Bad, true)
			else
				setButton(b, "🔒", T.Locked, false)
			end
		end
		for i, def in Config.Backpacks do
			local b = rows.Backpacks[i]
			if i < data.Backpack then
				setButton(b, "Owned", T.Locked, false)
			elseif i == data.Backpack then
				setButton(b, "Equipped", T.Good, false)
			elseif i == data.Backpack + 1 then
				setButton(b, priceText(def.Price), if data.Coins >= def.Price then T.Accent else T.Bad, true)
			else
				setButton(b, "🔒", T.Locked, false)
			end
		end
	end
end

----------------------------------------------------------------------
-- Quests
----------------------------------------------------------------------
local function buildQuests()
	local p = newPanel("Quests", "Quests", "📜")
	local list = scroller(p.Body)
	local rows = {}
	for i, q in Config.Quests do
		local r = row(list, 82)
		label(r, q.Title, 19, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 22) })
		label(r, q.Desc, 14, T.Dim, BODY_FONT, { Position = UDim2.fromOffset(14, 31), Size = UDim2.new(1, -170, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		local bg, fill = progressBar(r, UDim2.fromOffset(14, 56), UDim2.new(1, -170, 0, 14), T.Accent)
		local txt = label(bg, "", 11, T.Text, TITLE_FONT, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
		local reward = label(r, "", 14, T.Accent, TITLE_FONT, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(130, 18), TextXAlignment = Enum.TextXAlignment.Right })
		local claim = button(r, UDim2.fromOffset(120, 36), "Claim", function()
			local ok, msg = Remotes.ClaimQuest:InvokeServer(q.Id)
			UI.Toast(msg, if ok then "good" else "bad")
			if ok then
				Audio.Play("Coin")
			end
		end)
		claim.AnchorPoint = Vector2.new(1, 0)
		claim.Position = UDim2.new(1, -14, 0, 34)
		rows[i] = { Row = r, Fill = fill, Text = txt, Reward = reward, Claim = claim, Quest = q }
	end
	function p.Refresh(data)
		for i, e in rows do
			local q = e.Quest
			local prog = Config.GetStat(data, q.Stat)
			local done = prog >= q.Goal
			local claimed = data.Claimed[q.Id]
			tween(e.Fill, 0.25, { Size = UDim2.fromScale(math.clamp(prog / q.Goal, 0, 1), 1) })
			e.Fill.BackgroundColor3 = if done then T.Good else T.Accent
			e.Text.Text = `{Config.Abbrev(math.min(prog, q.Goal))} / {Config.Abbrev(q.Goal)}`
			e.Reward.Text = priceText(q.Reward)
			if claimed then
				setButton(e.Claim, "Claimed ✓", T.Locked, false)
				e.Row.LayoutOrder = 1000 + i
			elseif done then
				setButton(e.Claim, "Claim!", T.Good, true)
				e.Row.LayoutOrder = i - 1000
			else
				setButton(e.Claim, "In progress", T.Locked, false)
				e.Row.LayoutOrder = i
			end
		end
	end
end

----------------------------------------------------------------------
-- Collection
----------------------------------------------------------------------
local function buildCollection()
	local p = newPanel("Collection", "Fossil Collection", "🦴")
	local counter = label(p.Root, "", 16, T.Dim, BODY_FONT, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -64, 0, 20), Size = UDim2.fromOffset(180, 22), TextXAlignment = Enum.TextXAlignment.Right })
	local grid = scroller(p.Body, true)
	local cards = {}
	for i, f in Config.Fossils do
		local rarity = Config.RarityByName[f.Rarity]
		local c = create("Frame", { BackgroundColor3 = T.Panel, LayoutOrder = i, Parent = grid }, { corner(12), stroke(T.Panel2, 2) })
		local icon = label(c, "❓", 38, T.Dim, TITLE_FONT, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 48), TextXAlignment = Enum.TextXAlignment.Center })
		local name = label(c, "???", 13, T.Dim, TITLE_FONT, { Position = UDim2.fromOffset(4, 56), Size = UDim2.new(1, -8, 0, 32), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
		local tag = label(c, rarity.Name, 11, rarity.Color, TITLE_FONT, { Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
		cards[f.Id] = { Frame = c, Icon = icon, Name = name, Fossil = f, Rarity = rarity }
		tag.Visible = false
		cards[f.Id].Tag = tag
	end
	function p.Refresh(data)
		local found = 0
		for id, c in cards do
			local count = data.Collection[id]
			local s = c.Frame:FindFirstChildOfClass("UIStroke")
			if count then
				found += 1
				c.Icon.Text = c.Fossil.Icon
				c.Icon.TextColor3 = T.Text
				c.Name.Text = `{c.Fossil.Name}\nx{count}`
				c.Name.TextColor3 = T.Text
				c.Tag.Visible = true
				s.Color = c.Rarity.Color
			else
				c.Icon.Text = "❓"
				c.Icon.TextColor3 = T.Dim
				c.Name.Text = "???"
				c.Name.TextColor3 = T.Dim
				c.Tag.Visible = false
				s.Color = T.Panel2
			end
		end
		counter.Text = `{found} / {#Config.Fossils} discovered`
	end
end

----------------------------------------------------------------------
-- Map / travel
----------------------------------------------------------------------
function UI.Fade(show: boolean, time: number)
	fadeFrame.Visible = true
	tween(fadeFrame, time, { BackgroundTransparency = if show then 0 else 1 })
	if not show then
		task.delay(time, function()
			if fadeFrame.BackgroundTransparency >= 1 then
				fadeFrame.Visible = false
			end
		end)
	end
end

local function travel(zoneId: string)
	if travelBusy then
		return
	end
	travelBusy = true
	UI.Fade(true, 0.25)
	task.wait(0.28)
	local ok, msg = Remotes.Travel:InvokeServer(zoneId)
	if not ok then
		UI.Toast(msg, "bad")
	end
	task.wait(0.35)
	UI.Fade(false, 0.4)
	if ok then
		closePanel()
	end
	travelBusy = false
end

local function buildMap()
	local p = newPanel("Map", "World Map", "🗺️")
	local list = scroller(p.Body)
	local rows = {}

	local function mapRow(order, id, icon, name, blurb, color)
		local r = row(list, 80)
		r.LayoutOrder = order
		iconBox(r, icon, color)
		label(r, name, 20, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(72, 8), Size = UDim2.new(1, -220, 0, 24) })
		label(r, blurb, 14, T.Dim, BODY_FONT, { Position = UDim2.fromOffset(72, 34), Size = UDim2.new(1, -220, 0, 38), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		local b = button(r, UDim2.fromOffset(120, 42), "", function() end)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -12, 0.5, 0)
		rows[id] = b
		return b
	end

	local hubBtn = mapRow(0, "Hub", "🏛️", "Fossil Hub", "Sell your finds at the Museum.", T.Panel2)
	hubBtn.Activated:Connect(function()
		travel("Hub")
	end)
	setButton(hubBtn, "Travel", T.Accent, true)

	for _, zone in Config.Zones do
		local rarest = zone.Loot[#zone.Loot][1]
		local b = mapRow(zone.Index, zone.Id, zone.Icon, zone.Name, `{zone.Blurb}\nRarest: {Config.FossilById[rarest].Rarity}`, Config.ZoneById[zone.Id].GroundColor:Lerp(Color3.new(0, 0, 0), 0.25))
		b.Activated:Connect(function()
			local data = State.Data
			if not data or not b:GetAttribute("On") then
				return
			end
			if data.ZonesUnlocked[zone.Id] then
				travel(zone.Id)
			else
				local ok, msg = Remotes.Buy:InvokeServer("zone", zone.Id)
				UI.Toast(msg, if ok then "good" else "bad")
				if ok then
					Audio.Play("Buy")
				end
			end
		end)
	end

	function p.Refresh(data)
		for _, zone in Config.Zones do
			local b = rows[zone.Id]
			local prev = Config.Zones[zone.Index - 1]
			if data.ZonesUnlocked[zone.Id] then
				setButton(b, "Travel", T.Accent, true)
			elseif prev and not data.ZonesUnlocked[prev.Id] then
				setButton(b, "🔒", T.Locked, false)
			else
				setButton(b, "Unlock " .. priceText(zone.Price), if data.Coins >= zone.Price then T.Accent else T.Bad, true)
				b.TextSize = 14
			end
		end
	end
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------
local function pill(size: UDim2, pos: UDim2)
	return create("Frame", { Size = size, Position = pos, BackgroundColor3 = T.Bg, BackgroundTransparency = 0.1, Parent = root }, { corner(14), stroke(T.Accent, 2) })
end

local function buildHud()
	-- Coins
	local coinPill = pill(UDim2.fromOffset(210, 46), UDim2.fromOffset(16, 16))
	label(coinPill, "🪙", 28, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(34, 46), TextXAlignment = Enum.TextXAlignment.Center })
	hud.Coins = label(coinPill, "0", 26, T.Accent, TITLE_FONT, { Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -58, 1, 0) })
	hud.CoinScale = create("UIScale", { Parent = coinPill })
	hud.CoinValue = Instance.new("NumberValue")
	hud.CoinValue.Changed:Connect(function(v)
		hud.Coins.Text = Config.Abbrev(v)
	end)

	-- Backpack
	local bagPill = pill(UDim2.fromOffset(210, 38), UDim2.fromOffset(16, 70))
	local bg, fill = progressBar(bagPill, UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16), T.Good)
	hud.BagFill = fill
	hud.BagText = label(bg, "🎒 0 / 10", 14, T.Text, TITLE_FONT, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	hud.BagPill = bagPill

	-- Quest tracker
	local tracker = create("Frame", { Position = UDim2.fromOffset(16, 118), Size = UDim2.fromOffset(210, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Bg, BackgroundTransparency = 0.25, Parent = root }, {
		corner(14),
		padding(8),
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label(tracker, "QUESTS", 12, T.Accent, TITLE_FONT, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 0 })
	hud.Tracker = tracker
	hud.TrackerRows = {}
	for i = 1, 3 do
		local r = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = i, Parent = tracker })
		local title = label(r, "", 13, T.Text, BODY_FONT, { Size = UDim2.new(1, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local _, pfill = progressBar(r, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 10), T.Accent)
		hud.TrackerRows[i] = { Row = r, Title = title, Fill = pfill }
	end

	-- Right-hand buttons
	local bar = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(74, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = root }, {
		create("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local defs = {
		{ "Shop", "🛒", "Shop", "B" },
		{ "Quests", "📜", "Quests", "Q" },
		{ "Collection", "🦴", "Fossils", "C" },
		{ "Map", "🗺️", "Map", "M" },
	}
	hud.Buttons = {}
	for _, d in defs do
		local b = button(bar, UDim2.fromOffset(68, 68), "", function()
			showPanel(d[1])
		end)
		b.BackgroundColor3 = T.Bg
		b.BackgroundTransparency = 0.1
		create("UIStroke", { Color = T.Accent, Thickness = 2, Parent = b })
		label(b, d[2], 30, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center })
		label(b, d[3], 13, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
		hud.Buttons[d[1]] = b
	end
	-- red dot on Quests when something is claimable
	hud.QuestDot = create("TextLabel", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -6, 0, -6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bad,
		Text = "0",
		TextColor3 = T.Text,
		Font = TITLE_FONT,
		TextSize = 13,
		Visible = false,
		Parent = hud.Buttons.Quests,
	}, { corner(11) })

	-- Controls hint
	label(root, "Hold Click / F to dig   ·   B Shop  Q Quests  C Fossils  M Map", 14, T.Text, BODY_FONT, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(500, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 0.25,
		TextStrokeTransparency = 0.6,
	})
end

local lastCoins
local function refreshHud(data)
	-- coins (count up + bump)
	if lastCoins == nil then
		hud.CoinValue.Value = data.Coins
	else
		tween(hud.CoinValue, 0.45, { Value = data.Coins })
		if data.Coins > lastCoins then
			hud.CoinScale.Scale = 1.15
			tween(hud.CoinScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	lastCoins = data.Coins

	-- backpack
	local cap = Config.Backpacks[data.Backpack].Capacity
	local count = Config.InventoryCount(data)
	tween(hud.BagFill, 0.25, { Size = UDim2.fromScale(math.clamp(count / cap, 0, 1), 1) })
	hud.BagFill.BackgroundColor3 = if count >= cap then T.Bad elseif count / cap > 0.7 then T.Accent else T.Good
	hud.BagText.Text = `🎒 {count} / {cap}` .. (if count >= cap then "  FULL" else "")

	-- tracker: first 3 unclaimed quests
	local shown, claimable = 0, 0
	for _, q in Config.Quests do
		local prog = Config.GetStat(data, q.Stat)
		if not data.Claimed[q.Id] and prog >= q.Goal then
			claimable += 1
		end
	end
	for _, q in Config.Quests do
		if shown >= 3 then
			break
		end
		if not data.Claimed[q.Id] then
			shown += 1
			local e = hud.TrackerRows[shown]
			local prog = Config.GetStat(data, q.Stat)
			e.Row.Visible = true
			e.Title.Text = `{q.Title}  {Config.Abbrev(math.min(prog, q.Goal))}/{Config.Abbrev(q.Goal)}`
			e.Fill.BackgroundColor3 = if prog >= q.Goal then T.Good else T.Accent
			tween(e.Fill, 0.25, { Size = UDim2.fromScale(math.clamp(prog / q.Goal, 0, 1), 1) })
		end
	end
	for i = shown + 1, 3 do
		hud.TrackerRows[i].Row.Visible = false
	end
	hud.Tracker.Visible = shown > 0

	hud.QuestDot.Visible = claimable > 0
	hud.QuestDot.Text = tostring(claimable)

	for _, p in panels do
		if p.Root.Visible and p.Refresh then
			p.Refresh(data)
		end
	end
end

----------------------------------------------------------------------
-- Toasts, find popup, banners, flash
----------------------------------------------------------------------
local toastCounter = 0
function UI.Toast(text: string, kind: string?)
	if not text or text == "" then
		return
	end
	local color = if kind == "good" then T.Good elseif kind == "bad" then T.Bad else T.Accent
	for _, c in toastHolder:GetChildren() do
		if c:IsA("CanvasGroup") and #toastHolder:GetChildren() > 5 then
			c:Destroy()
			break
		end
	end
	toastCounter += 1
	local g = create("CanvasGroup", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = T.Bg,
		GroupTransparency = 1,
		LayoutOrder = toastCounter,
		Parent = toastHolder,
	}, { corner(12), stroke(color, 2), padding(10) })
	label(g, text, 17, T.Text, BODY_FONT, { AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextXAlignment = Enum.TextXAlignment.Center })
	tween(g, 0.2, { GroupTransparency = 0 })
	task.delay(3.2, function()
		if g.Parent then
			tween(g, 0.4, { GroupTransparency = 1 })
			task.delay(0.45, function()
				g:Destroy()
			end)
		end
	end)
end

local findToken = 0
function UI.ShowFind(fossil, isNew: boolean)
	findToken += 1
	local token = findToken
	local rarity = Config.RarityByName[fossil.Rarity]
	for _, c in findCard:GetChildren() do
		if not c:IsA("UIAspectRatioConstraint") then
			c:Destroy()
		end
	end
	local card = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 40),
		Size = UDim2.fromOffset(330, 92),
		BackgroundColor3 = T.Bg,
		GroupTransparency = 1,
		Parent = findCard,
	}, { corner(16), stroke(rarity.Color, 3) })
	create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rarity.Color, BackgroundTransparency = 0.82, Parent = card }, {
		create("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	local ib = create("Frame", { Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(14, 13), BackgroundColor3 = rarity.Color, Parent = card }, { corner(33) })
	label(ib, fossil.Icon, 38, T.Text, TITLE_FONT, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	label(card, fossil.Name, 22, T.Text, TITLE_FONT, { Position = UDim2.fromOffset(92, 12), Size = UDim2.new(1, -100, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd })
	label(card, string.upper(rarity.Name), 15, rarity.Color, TITLE_FONT, { Position = UDim2.fromOffset(92, 40), Size = UDim2.new(0, 120, 0, 18) })
	label(card, `Worth {priceText(fossil.Value)}`, 15, T.Accent, TITLE_FONT, { Position = UDim2.fromOffset(92, 62), Size = UDim2.new(1, -100, 0, 20) })
	if isNew then
		local nb = create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(54, 22),
			BackgroundColor3 = T.Good,
			Text = "NEW!",
			Font = TITLE_FONT,
			TextSize = 14,
			TextColor3 = T.Dark,
			Parent = card,
		}, { corner(8) })
		nb.Rotation = 6
	end
	tween(card, 0.35, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 1, 0) }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		if token == findToken and card.Parent then
			tween(card, 0.35, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 1, 30) })
		end
	end)
end

function UI.Flash(color: Color3)
	local f = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = gui })
	tween(f, 0.5, { BackgroundTransparency = 1 })
	task.delay(0.55, function()
		f:Destroy()
	end)
end

local announceToken = 0
function UI.Announce(text: string, color: Color3)
	announceToken += 1
	local token = announceToken
	local b = hud.Announce
	b.Text = text
	b.TextColor3 = color
	b.Visible = true
	b.TextTransparency = 1
	b.Position = UDim2.new(0.5, 0, 0, -10)
	tween(b, 0.4, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, 60) }, Enum.EasingStyle.Back)
	task.delay(5, function()
		if token == announceToken then
			tween(b, 0.5, { TextTransparency = 1 })
		end
	end)
end

local bannerToken = 0
function UI.ZoneBanner(name: string, blurb: string?)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = name
	bannerLabel.Sub.Text = blurb or ""
	bannerLabel.TextTransparency = 1
	bannerLabel.Sub.TextTransparency = 1
	tween(bannerLabel, 0.5, { TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.2) })
	tween(bannerLabel.Sub, 0.5, { TextTransparency = 0 })
	task.delay(3, function()
		if token == bannerToken then
			tween(bannerLabel, 0.6, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.18) })
			tween(bannerLabel.Sub, 0.6, { TextTransparency = 1 })
		end
	end)
end

function UI.SellFx(total: number, count: number)
	Audio.Play("Coin")
	UI.Toast(`+{Config.Abbrev(total)} coins`, "good")
end

function UI.IsModalOpen(): boolean
	return openPanelName ~= nil
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------
function UI.Init()
	gui = create("ScreenGui", {
		Name = "FossilDigGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = create("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	uiScale = create("UIScale", { Parent = root })
	updateScale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	fadeFrame = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 100, BorderSizePixel = 0, Parent = gui })

	toastHolder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(500, 200),
		BackgroundTransparency = 1,
		Parent = root,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })

	findCard = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(330, 92), BackgroundTransparency = 1, Parent = root })

	bannerLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.18),
		Size = UDim2.fromOffset(700, 60),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = T.Accent,
		Font = TITLE_FONT,
		TextSize = 54,
		TextTransparency = 1,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		Parent = root,
	})
	create("TextLabel", {
		Name = "Sub",
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = T.Text,
		Font = BODY_FONT,
		TextSize = 22,
		TextTransparency = 1,
		TextStrokeTransparency = 0.5,
		Parent = bannerLabel,
	})

	hud.Announce = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(900, 36),
		BackgroundTransparency = 1,
		Text = "",
		Font = TITLE_FONT,
		TextSize = 28,
		TextStrokeTransparency = 0.3,
		Visible = false,
		Parent = root,
	})

	buildHud()
	buildShop()
	buildQuests()
	buildCollection()
	buildMap()

	State.Connect(refreshHud)

	-- keyboard shortcuts
	local keys = {
		[Enum.KeyCode.B] = "Shop",
		[Enum.KeyCode.Q] = "Quests",
		[Enum.KeyCode.C] = "Collection",
		[Enum.KeyCode.M] = "Map",
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local name = keys[input.KeyCode]
		if name then
			showPanel(name)
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closePanel()
		end
	end)
end

return UI
