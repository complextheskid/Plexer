local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DEFAULT_COLORS = {
	Main = Color3.fromRGB(10, 10, 10),
	Tab = Color3.fromRGB(20, 20, 20),
	TabActive = Color3.fromRGB(40, 40, 40),
	Content = Color3.fromRGB(15, 15, 15),
	Accent = Color3.fromRGB(100, 140, 255),
	Text = Color3.fromRGB(220, 220, 220),
	TextDim = Color3.fromRGB(100, 100, 100),
	Stroke = Color3.fromRGB(35, 35, 35),
	Danger = Color3.fromRGB(200, 50, 50),
}

local COLORS = {}
for k, v in pairs(DEFAULT_COLORS) do
	COLORS[k] = v
end

-- ─── Config (per userId) ──────────────────────────────────
local CONFIG_FILE = "Plexer_" .. tostring(player.UserId) .. ".json"

local DEFAULT_CONFIG = {
	closeKey = "K",
	uiWidth = 640,
	uiHeight = 460,
	fflags = {},
	theme = "Blue",
	savedKey = "",
	linkedUserId = 0,
	colors = {
		Main = {10, 10, 10},
		Tab = {20, 20, 20},
		TabActive = {40, 40, 40},
		Content = {15, 15, 15},
		Accent = {100, 140, 255},
		Text = {220, 220, 220},
		TextDim = {100, 100, 100},
		Stroke = {35, 35, 35},
	},
}

-- ─── Key system ───────────────────────────────────────────
local GITHUB_KEYS_URL = "https://raw.githubusercontent.com/complextheskid/Plexer/main/keys.json"

local FALLBACK_KEYS = {
	["UFxFWFJLRVlTVFJJTkdLRVlMSU5LRURTVEFSRFhYWFZDX1hYVj0="] = true,
	["Q09NUExFWEtFWUFSUExFWENPTVBMRVgyMDI2S0FZQUFBQUFBBQ=="] = true,
}

local FETCHED_KEYS = nil

local function normalizeKey(k)
	return (k or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function fetchGitHubKeys()
	if FETCHED_KEYS then return FETCHED_KEYS end

	local keysTable = {}
	local success, result = pcall(function()
		return game:HttpGet(GITHUB_KEYS_URL, true)
	end)

	if success and result and #result > 0 then
		local jsonSuccess, decoded = pcall(function()
			return HttpService:JSONDecode(result)
		end)

		if jsonSuccess and type(decoded) == "table" then
			for k, v in pairs(decoded) do
				if type(v) == "string" then
					keysTable[normalizeKey(v)] = true
				elseif type(k) == "string" and v == true then
					keysTable[normalizeKey(k)] = true
				end
			end
			FETCHED_KEYS = keysTable
			return FETCHED_KEYS
		end
	end

	FETCHED_KEYS = FALLBACK_KEYS
	return FETCHED_KEYS
end

local function isKeyValid(k)
	local validKeys = fetchGitHubKeys()
	return validKeys[normalizeKey(k)] == true
end

local config = {}
for k, v in pairs(DEFAULT_CONFIG) do
	if type(v) == "table" then
		config[k] = {}
		for k2, v2 in pairs(v) do
			config[k][k2] = v2
		end
	else
		config[k] = v
	end
end

local function saveConfig()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(config)
	end)
	if not ok then return false end
	local wok = pcall(function()
		writefile(CONFIG_FILE, encoded)
	end)
	return wok
end

local function loadConfig()
	local ok, data = pcall(function()
		return readfile(CONFIG_FILE)
	end)
	if not ok or not data then return end
	local dok, decoded = pcall(function()
		return HttpService:JSONDecode(data)
	end)
	if not dok or type(decoded) ~= "table" then return end
	for k, v in pairs(decoded) do
		config[k] = v
	end
end

loadConfig()

if type(config.colors) == "table" then
	for name, rgb in pairs(config.colors) do
		if type(rgb) == "table" and rgb[1] and COLORS[name] then
			COLORS[name] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		end
	end
end

local UI_W = math.clamp(tonumber(config.uiWidth) or 640, 400, 1000)
local UI_H = math.clamp(tonumber(config.uiHeight) or 460, 280, 700)
config.uiWidth = UI_W
config.uiHeight = UI_H
local closeKeyCode = Enum.KeyCode[config.closeKey] or Enum.KeyCode.K

local function addCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = parent
end

local function addStroke(parent, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or COLORS.Stroke
	s.Thickness = t or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

-- ─── ScreenGui ────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "Plexer"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.Parent = playerGui

-- ─── Main Frame ───────────────────────────────────────────
local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.new(0, UI_W, 0, UI_H)
main.Position = UDim2.new(0.5, -math.floor(UI_W / 2), 0.5, -math.floor(UI_H / 2))
main.BackgroundColor3 = COLORS.Main
main.BorderSizePixel = 0
main.Visible = false
main.ClipsDescendants = true
main.Parent = gui
addCorner(main, 14)
addStroke(main, COLORS.Stroke, 1)

-- ─── Title Bar ────────────────────────────────────────────
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = COLORS.Tab
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Plexer  [" .. config.closeKey .. "] close  [L] kill"
title.TextColor3 = COLORS.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 7)
closeBtn.BackgroundColor3 = COLORS.Content
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = COLORS.TextDim
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = true
closeBtn.Parent = titleBar
addCorner(closeBtn, 8)

-- ─── Tabs ─────────────────────────────────────────────────
local tabRow = Instance.new("Frame")
tabRow.Size = UDim2.new(1, -16, 0, 40)
tabRow.Position = UDim2.new(0, 8, 0, 54)
tabRow.BackgroundTransparency = 1
tabRow.Parent = main

local TABS = {"Skyboxes", "FFlags", "ScriptHub", "Settings", "Info"}
local tabButtons = {}

for i, name in ipairs(TABS) do
	local btn = Instance.new("TextButton")
	btn.Name = "Tab_" .. name
	btn.Size = UDim2.new(1 / #TABS, -4, 1, 0)
	btn.Position = UDim2.new((i - 1) / #TABS, 2, 0, 0)
	btn.BackgroundColor3 = COLORS.Tab
	btn.BorderSizePixel = 0
	btn.Text = name
	btn.TextColor3 = COLORS.TextDim
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 14
	btn.AutoButtonColor = false
	btn.Parent = tabRow
	addCorner(btn, 8)
	tabButtons[name] = btn
end

-- ─── Content ──────────────────────────────────────────────
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -110)
content.Position = UDim2.new(0, 8, 0, 102)
content.BackgroundColor3 = COLORS.Content
content.BorderSizePixel = 0
content.Parent = main
addCorner(content, 10)
addStroke(content, COLORS.Stroke, 1)

local pages = {}
for _, name in ipairs(TABS) do
	local page = Instance.new("Frame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = content
	pages[name] = page
end

-- ─── Tab Switching Logic ──────────────────────────────────
local activeTab = nil

local function setTab(name)
	if activeTab and pages[activeTab] then
		pages[activeTab].Visible = false
		if tabButtons[activeTab] then
			tabButtons[activeTab].BackgroundColor3 = COLORS.Tab
			tabButtons[activeTab].TextColor3 = COLORS.TextDim
		end
	end
	activeTab = name
	if pages[name] then
		pages[name].Visible = true
	end
	if tabButtons[name] then
		tabButtons[name].BackgroundColor3 = COLORS.TabActive
		tabButtons[name].TextColor3 = COLORS.Text
	end
end

for _, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function()
		setTab(btn.Name:sub(5))
	end)
end

-- ─── Skyboxes Tab ─────────────────────────────────────────
do
	local page = pages["Skyboxes"]
	local Lighting = game:GetService("Lighting")

	local function clearBlackDome()
		local dome = workspace:FindFirstChild("PlexerBlackSky")
		if dome then dome:Destroy() end
	end

	local function clearOldSky()
		clearBlackDome()
		for _, c in ipairs(Lighting:GetChildren()) do
			if c:IsA("Sky") then c:Destroy() end
		end
	end

	local function applySky(faces, opts)
		opts = opts or {}
		clearOldSky()
		local sky = Instance.new("Sky")
		local facesList = {"Bk", "Dn", "Ft", "Lf", "Rt", "Up"}
		if type(faces) == "string" then
			for _, f in ipairs(facesList) do sky["Skybox" .. f] = faces end
		else
			for _, f in ipairs(facesList) do sky["Skybox" .. f] = faces[f] or faces.Up or "" end
		end
		sky.CelestialBodiesShown = opts.celestial == true
		sky.StarCount = opts.stars or 0
		sky.Parent = Lighting
	end

	local PRESETS = {
		{name = "Pink Sky", faces = "rbxassetid://271042516"},
		{name = "Aurora Borealis", faces = {Bk="rbxassetid://159454299", Dn="rbxassetid://159454286", Ft="rbxassetid://159454293", Lf="rbxassetid://159454286", Rt="rbxassetid://159454300", Up="rbxassetid://159454288"}},
	}

	for i, preset in ipairs(PRESETS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -24, 0, 36)
		btn.Position = UDim2.new(0, 12, 0, 12 + (i - 1) * 42)
		btn.BackgroundColor3 = COLORS.Tab
		btn.BorderSizePixel = 0
		btn.Text = "  " .. preset.name
		btn.TextColor3 = COLORS.Text
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 14
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Parent = page
		addCorner(btn, 8)

		btn.MouseButton1Click:Connect(function()
			applySky(preset.faces)
		end)
	end
end

-- ─── FFlags Tab ───────────────────────────────────────────
do
	local page = pages["FFlags"]
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -24, 0, 30)
	lbl.Position = UDim2.new(0, 12, 0, 12)
	lbl.BackgroundTransparency = 1
	lbl.Text = "FFlag Fast Editor Active"
	lbl.TextColor3 = COLORS.Text
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = page
end

-- ─── ScriptHub Tab ────────────────────────────────────────
do
	local page = pages["ScriptHub"]
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -24, 0, 30)
	lbl.Position = UDim2.new(0, 12, 0, 12)
	lbl.BackgroundTransparency = 1
	lbl.Text = "ScriptHub Ready"
	lbl.TextColor3 = COLORS.Text
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = page
end

-- ─── Settings Tab ─────────────────────────────────────────
do
	local page = pages["Settings"]
	local resetKeyBtn = Instance.new("TextButton")
	resetKeyBtn.Size = UDim2.new(0, 140, 0, 32)
	resetKeyBtn.Position = UDim2.new(0, 12, 0, 12)
	resetKeyBtn.BackgroundColor3 = COLORS.Danger
	resetKeyBtn.BorderSizePixel = 0
	resetKeyBtn.Text = "Reset Key Lock"
	resetKeyBtn.TextColor3 = Color3.new(1, 1, 1)
	resetKeyBtn.Font = Enum.Font.GothamBold
	resetKeyBtn.TextSize = 13
	resetKeyBtn.Parent = page
	addCorner(resetKeyBtn, 6)

	resetKeyBtn.MouseButton1Click:Connect(function()
		config.savedKey = ""
		config.linkedUserId = 0
		saveConfig()
		resetKeyBtn.Text = "Cleared!"
	end)
end

-- ─── Info Tab ─────────────────────────────────────────────
do
	local infoPage = pages["Info"]
	local creditLbl = Instance.new("TextLabel")
	creditLbl.Size = UDim2.new(1, -20, 0, 22)
	creditLbl.Position = UDim2.new(0, 10, 0, 20)
	creditLbl.BackgroundTransparency = 1
	creditLbl.Text = "Plexer — Fixed Edition"
	creditLbl.TextColor3 = COLORS.Accent
	creditLbl.Font = Enum.Font.GothamMedium
	creditLbl.TextSize = 14
	creditLbl.TextXAlignment = Enum.TextXAlignment.Left
	creditLbl.Parent = infoPage
end

-- ─── Window Controls ──────────────────────────────────────
local isOpen = false
local destroyed = false

local function openMenu()
	if destroyed then return end
	isOpen = true
	main.Visible = true
	setTab(activeTab or "Skyboxes")
end

local function closeMenu()
	if destroyed then return end
	isOpen = false
	main.Visible = false
end

closeBtn.MouseButton1Click:Connect(closeMenu)

UserInputService.InputBegan:Connect(function(input)
	if destroyed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == closeKeyCode then
			if isOpen then closeMenu() else openMenu() end
		elseif input.KeyCode == Enum.KeyCode.L then
			destroyed = true
			gui:Destroy()
		end
	end
end)

-- ─── Draggable Mechanics ──────────────────────────────────
local dragging, dragStart, startPos

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)

titleBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y
		)
	end
end)

-- ─── Key System Check ─────────────────────────────────────
local function hasValidStoredSession()
	if config.savedKey ~= "" and config.linkedUserId == player.UserId then
		return isKeyValid(config.savedKey)
	end
	return false
end

if hasValidStoredSession() then
	openMenu()
else
	local keyFrame = Instance.new("Frame")
	keyFrame.Name = "KeySystemFrame"
	keyFrame.Size = UDim2.new(0, 320, 0, 180)
	keyFrame.Position = UDim2.new(0.5, -160, 0.5, -90)
	keyFrame.BackgroundColor3 = COLORS.Main
	keyFrame.BorderSizePixel = 0
	keyFrame.ZIndex = 10
	keyFrame.Parent = gui
	addCorner(keyFrame, 12)
	addStroke(keyFrame, COLORS.Stroke, 1)

	local keyTitle = Instance.new("TextLabel")
	keyTitle.Size = UDim2.new(1, 0, 0, 28)
	keyTitle.Position = UDim2.new(0, 0, 0, 16)
	keyTitle.BackgroundTransparency = 1
	keyTitle.Text = "Plexer Key System"
	keyTitle.TextColor3 = COLORS.Text
	keyTitle.Font = Enum.Font.GothamBold
	keyTitle.TextSize = 16
	keyTitle.Parent = keyFrame

	local keyBox = Instance.new("TextBox")
	keyBox.Size = UDim2.new(1, -24, 0, 34)
	keyBox.Position = UDim2.new(0, 12, 0, 60)
	keyBox.BackgroundColor3 = COLORS.Tab
	keyBox.BorderSizePixel = 0
	keyBox.PlaceholderText = "Paste Base64 Key..."
	keyBox.PlaceholderColor3 = COLORS.TextDim
	keyBox.Text = ""
	keyBox.TextColor3 = COLORS.Text
	keyBox.Font = Enum.Font.Gotham
	keyBox.TextSize = 12
	keyBox.ClearTextOnFocus = false
	keyBox.Parent = keyFrame
	addCorner(keyBox, 8)

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(1, -24, 0, 34)
	keyBtn.Position = UDim2.new(0, 12, 0, 110)
	keyBtn.BackgroundColor3 = COLORS.Accent
	keyBtn.BorderSizePixel = 0
	keyBtn.Text = "Unlock"
	keyBtn.TextColor3 = Color3.new(1, 1, 1)
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.TextSize = 14
	keyBtn.Parent = keyFrame
	addCorner(keyBtn, 8)

	local function tryUnlock()
		local k = keyBox.Text
		if isKeyValid(k) then
			config.savedKey = normalizeKey(k)
			config.linkedUserId = player.UserId
			saveConfig()
			keyFrame:Destroy()
			openMenu()
		else
			keyBtn.Text = "Invalid Key!"
			task.delay(1.5, function()
				if keyBtn and keyBtn.Parent then keyBtn.Text = "Unlock" end
			end)
		end
	end

	keyBtn.MouseButton1Click:Connect(tryUnlock)
	keyBox.FocusLost:Connect(function(enter)
		if enter then tryUnlock() end
	end)
end
