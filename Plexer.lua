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

-- apply saved colors
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

-- ─── Loader ───────────────────────────────────────────────
local loader = Instance.new("Frame")
loader.Name = "Loader"
loader.Size = UDim2.new(0, 280, 0, 100)
loader.Position = UDim2.new(0.5, -140, 0.5, -50)
loader.BackgroundColor3 = COLORS.Main
loader.BorderSizePixel = 0
loader.Visible = true
loader.Parent = gui
addCorner(loader, 12)
addStroke(loader, COLORS.Stroke, 1)

local loaderTitle = Instance.new("TextLabel")
loaderTitle.Size = UDim2.new(1, 0, 0, 28)
loaderTitle.Position = UDim2.new(0, 0, 0, 18)
loaderTitle.BackgroundTransparency = 1
loaderTitle.Text = "Plexer"
loaderTitle.TextColor3 = COLORS.Text
loaderTitle.Font = Enum.Font.GothamBold
loaderTitle.TextSize = 16
loaderTitle.TextXAlignment = Enum.TextXAlignment.Center
loaderTitle.Parent = loader

local loaderStatus = Instance.new("TextLabel")
loaderStatus.Size = UDim2.new(1, -20, 0, 20)
loaderStatus.Position = UDim2.new(0, 10, 0, 52)
loaderStatus.BackgroundTransparency = 1
loaderStatus.Text = "Initializing"
loaderStatus.TextColor3 = COLORS.TextDim
loaderStatus.Font = Enum.Font.Gotham
loaderStatus.TextSize = 13
loaderStatus.TextXAlignment = Enum.TextXAlignment.Center
loaderStatus.Parent = loader

local loaderBarBg = Instance.new("Frame")
loaderBarBg.Size = UDim2.new(1, -40, 0, 4)
loaderBarBg.Position = UDim2.new(0, 20, 0, 80)
loaderBarBg.BackgroundColor3 = COLORS.Tab
loaderBarBg.BorderSizePixel = 0
loaderBarBg.Parent = loader
addCorner(loaderBarBg, 2)

local loaderBar = Instance.new("Frame")
loaderBar.Size = UDim2.new(0, 0, 1, 0)
loaderBar.BackgroundColor3 = COLORS.Accent
loaderBar.BorderSizePixel = 0
loaderBar.Parent = loaderBarBg
addCorner(loaderBar, 2)

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

local TABS = {"Skyboxes", "FFlags", "Settings", "Info"}
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
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = content
	pages[name] = page

end

-- ─── Skyboxes Tab ─────────────────────────────────────────
do
	local page = pages["Skyboxes"]
	local Lighting = game:GetService("Lighting")

	local function clearOldSky()
		for _, c in ipairs(Lighting:GetChildren()) do
			if c:IsA("Sky") then
				c:Destroy()
			end
		end
	end

	local function applySky(faces, opts)
		opts = opts or {}
		clearOldSky()
		local sky = Instance.new("Sky")
		local facesList = {"Bk", "Dn", "Ft", "Lf", "Rt", "Up"}
		if type(faces) == "string" then
			for _, f in ipairs(facesList) do
				sky["Skybox" .. f] = faces
			end
		else
			for _, f in ipairs(facesList) do
				sky["Skybox" .. f] = faces[f] or faces.Up or ""
			end
		end
		sky.CelestialBodiesShown = opts.celestial == true
		sky.StarCount = opts.stars or 0
		sky.Parent = Lighting
		return sky
	end

	local function isValidCdn(url)
		if type(url) ~= "string" or url == "" then return false end
		local lower = url:lower()
		if lower:find("rbxassetid://", 1, true) or lower:find("rbxasset://", 1, true) then
			return true
		end
		if tonumber(url) then return true end
		if not lower:find("^https?://") then return false end
		local cdns = {
			"roblox.com", "rbxcdn.com", "robloxcdn.com",
			"discordapp.com", "discord.com", "cdn.discordapp",
			"media.discordapp.net", "media.discordapp",
			"imgur.com", "i.imgur.com",
			"github.com", "githubusercontent.com",
			"cloudflare", "googleusercontent", "giphy.com",
			"tenor.com", "catbox.moe", "imgbb.com", "postimg",
		}
		for _, c in ipairs(cdns) do
			if lower:find(c, 1, true) then return true end
		end
		return lower:find("^https://") ~= nil
	end

	-- pure black texture used for Black Sky (all faces)
	local BLACK_TEX = "rbxassetid://1509448"

	local PRESETS = {
		{
			name = "Pink Sky",
			faces = {
				Bk = "rbxassetid://271042516",
				Dn = "rbxassetid://271042516",
				Ft = "rbxassetid://271042516",
				Lf = "rbxassetid://271042516",
				Rt = "rbxassetid://271042516",
				Up = "rbxassetid://271042516",
			},
			opts = {celestial = false, stars = 0},
		},
		{
			name = "Black Sky",
			faces = {
				Bk = BLACK_TEX,
				Dn = BLACK_TEX,
				Ft = BLACK_TEX,
				Lf = BLACK_TEX,
				Rt = BLACK_TEX,
				Up = BLACK_TEX,
			},
			opts = {celestial = false, stars = 0},
		},
		{
			name = "Aurora Borealis",
			faces = {
				Bk = "rbxassetid://159454299",
				Dn = "rbxassetid://159454286",
				Ft = "rbxassetid://159454293",
				Lf = "rbxassetid://159454286",
				Rt = "rbxassetid://159454300",
				Up = "rbxassetid://159454288",
			},
			opts = {celestial = true, stars = 3000},
		},
	}

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, -24, 0, 18)
	statusLbl.Position = UDim2.new(0, 12, 1, -24)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = ""
	statusLbl.TextColor3 = COLORS.TextDim
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 12
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Parent = page

	local function setStatus(text, ok)
		statusLbl.Text = text
		statusLbl.TextColor3 = ok and Color3.fromRGB(80, 200, 120) or COLORS.Danger
		task.delay(2.5, function()
			if statusLbl and statusLbl.Parent then
				statusLbl.Text = ""
			end
		end)
	end

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -24, 0, 20)
	titleLbl.Position = UDim2.new(0, 12, 0, 10)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "Presets"
	titleLbl.TextColor3 = COLORS.TextDim
	titleLbl.Font = Enum.Font.GothamMedium
	titleLbl.TextSize = 13
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = page

	for i, preset in ipairs(PRESETS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -24, 0, 36)
		btn.Position = UDim2.new(0, 12, 0, 34 + (i - 1) * 42)
		btn.BackgroundColor3 = COLORS.Tab
		btn.BorderSizePixel = 0
		btn.Text = "  " .. preset.name
		btn.TextColor3 = COLORS.Text
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 14
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = true
		btn.Parent = page
		addCorner(btn, 8)

		btn.MouseButton1Click:Connect(function()
			applySky(preset.faces, preset.opts)
			setStatus("Applied " .. preset.name, true)
		end)
	end

	local customY = 34 + #PRESETS * 42 + 12
	local customTitle = Instance.new("TextLabel")
	customTitle.Size = UDim2.new(1, -24, 0, 20)
	customTitle.Position = UDim2.new(0, 12, 0, customY)
	customTitle.BackgroundTransparency = 1
	customTitle.Text = "Custom (CDN / asset link)"
	customTitle.TextColor3 = COLORS.TextDim
	customTitle.Font = Enum.Font.GothamMedium
	customTitle.TextSize = 13
	customTitle.TextXAlignment = Enum.TextXAlignment.Left
	customTitle.Parent = page

	local linkBox = Instance.new("TextBox")
	linkBox.Size = UDim2.new(1, -24, 0, 32)
	linkBox.Position = UDim2.new(0, 12, 0, customY + 24)
	linkBox.BackgroundColor3 = COLORS.Tab
	linkBox.BorderSizePixel = 0
	linkBox.PlaceholderText = "https://cdn... or rbxassetid://..."
	linkBox.PlaceholderColor3 = COLORS.TextDim
	linkBox.Text = ""
	linkBox.TextColor3 = COLORS.Text
	linkBox.Font = Enum.Font.Gotham
	linkBox.TextSize = 12
	linkBox.ClearTextOnFocus = false
	linkBox.TextXAlignment = Enum.TextXAlignment.Left
	linkBox.Parent = page
	addCorner(linkBox, 6)
	addStroke(linkBox, COLORS.Stroke, 1)

	local linkPad = Instance.new("UIPadding")
	linkPad.PaddingLeft = UDim.new(0, 10)
	linkPad.Parent = linkBox

	local applyCustom = Instance.new("TextButton")
	applyCustom.Size = UDim2.new(0.48, -4, 0, 32)
	applyCustom.Position = UDim2.new(0, 12, 0, customY + 64)
	applyCustom.BackgroundColor3 = COLORS.Accent
	applyCustom.BorderSizePixel = 0
	applyCustom.Text = "Apply Link"
	applyCustom.TextColor3 = Color3.new(1, 1, 1)
	applyCustom.Font = Enum.Font.GothamBold
	applyCustom.TextSize = 13
	applyCustom.AutoButtonColor = true
	applyCustom.Parent = page
	addCorner(applyCustom, 6)

	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(0.48, -4, 0, 32)
	resetBtn.Position = UDim2.new(0.52, 0, 0, customY + 64)
	resetBtn.BackgroundColor3 = COLORS.Tab
	resetBtn.BorderSizePixel = 0
	resetBtn.Text = "Reset Sky"
	resetBtn.TextColor3 = COLORS.Text
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = 13
	resetBtn.AutoButtonColor = true
	resetBtn.Parent = page
	addCorner(resetBtn, 6)

	local function resolveHttpToAsset(url)
		-- download image then getcustomasset so Sky can use it
		local req = (syn and syn.request) or http_request or request
		if not req then
			return nil, "no http request"
		end
		if not getcustomasset then
			return nil, "no getcustomasset"
		end

		local ok, res = pcall(function()
			return req({
				Url = url,
				Method = "GET",
				Headers = {
					["User-Agent"] = "Mozilla/5.0",
				},
			})
		end)
		if not ok or not res or not res.Body or #res.Body < 100 then
			return nil, "download failed"
		end

		local ext = ".png"
		local cl = (res.Headers and (res.Headers["Content-Type"] or res.Headers["content-type"])) or ""
		if cl:find("jpeg") or cl:find("jpg") or url:lower():find("%.jpe?g") then
			ext = ".jpg"
		elseif cl:find("webp") or url:lower():find("%.webp") then
			ext = ".webp"
		end

		local path = "PlexerSky_" .. tostring(player.UserId) .. ext
		local wok = pcall(function()
			writefile(path, res.Body)
		end)
		if not wok then
			return nil, "write failed"
		end

		local aok, asset = pcall(getcustomasset, path)
		if not aok or not asset then
			return nil, "getcustomasset failed"
		end
		return asset, nil
	end

	applyCustom.MouseButton1Click:Connect(function()
		local url = linkBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if not isValidCdn(url) then
			setStatus("Invalid link — use CDN or rbxassetid://", false)
			return
		end

		-- plain asset id / rbxassetid
		if tonumber(url) then
			url = "rbxassetid://" .. url
		end
		if url:lower():find("rbxassetid://", 1, true) or url:lower():find("rbxasset://", 1, true) then
			applySky(url, {celestial = false, stars = 0})
			setStatus("Applied custom skybox", true)
			return
		end

		-- Discord / other CDN → download + getcustomasset
		setStatus("Downloading image...", true)
		task.spawn(function()
			local asset, err = resolveHttpToAsset(url)
			if not asset then
				setStatus("Failed: " .. tostring(err) .. " (try rbxassetid)", false)
				return
			end
			applySky(asset, {celestial = false, stars = 0})
			setStatus("Applied Discord/CDN skybox", true)
		end)
	end)

	resetBtn.MouseButton1Click:Connect(function()
		clearOldSky()
		local sky = Instance.new("Sky")
		sky.Parent = Lighting
		setStatus("Sky reset", true)
	end)
end

-- ─── FFlags Tab (Voidstrap-style editor) ──────────────────
do
	local page = pages["FFlags"]

	local function trySetFFlag(name, value)
		local ok = pcall(function()
			if setfflag then
				setfflag(name, tostring(value))
			elseif setfenv and getfenv then
				-- fallback no-op
			end
		end)
		return ok
	end

	local function tryGetFFlag(name)
		local ok, val = pcall(function()
			if getfflag then
				return getfflag(name)
			end
			return nil
		end)
		if ok then return val end
		return nil
	end

	-- preset flags (common / allowlist-style)
	local PRESETS = {
		{name = "DFIntTaskSchedulerTargetFps", value = "999", cat = "Performance"},
		{name = "FFlagDisablePostFx", value = "True", cat = "Graphics"},
		{name = "FIntDebugForceMSAASamples", value = "0", cat = "Graphics"},
		{name = "DFFlagTextureQualityOverrideEnabled", value = "True", cat = "Graphics"},
		{name = "DFIntTextureQualityOverride", value = "1", cat = "Graphics"},
		{name = "FFlagDebugGraphicsPreferD3D11", value = "True", cat = "Graphics"},
		{name = "DFFlagDisableDPIScale", value = "True", cat = "UI"},
		{name = "FFlagHandleAltEnterFullscreenManually", value = "True", cat = "UI"},
		{name = "FIntFRMMaxGrassDistance", value = "0", cat = "Graphics"},
		{name = "FIntFRMMinGrassDistance", value = "0", cat = "Graphics"},
		{name = "DFIntDebugFRMQualityLevelOverride", value = "1", cat = "Graphics"},
		{name = "FFlagDebugDisableTelemetryEphemeralCounter", value = "True", cat = "Telemetry"},
		{name = "FFlagDebugDisableTelemetryEphemeralStat", value = "True", cat = "Telemetry"},
		{name = "FFlagDebugDisableTelemetryEventIngest", value = "True", cat = "Telemetry"},
		{name = "FFlagDebugDisableTelemetryPoint", value = "True", cat = "Telemetry"},
		{name = "FFlagDebugDisableTelemetryV2Counter", value = "True", cat = "Telemetry"},
		{name = "FFlagDebugDisableTelemetryV2Event", value = "True", cat = "Telemetry"},
		{name = "FFlagDebugDisableTelemetryV2Stat", value = "True", cat = "Telemetry"},
	}

	-- active flags table (name -> value string)
	local activeFlags = {}
	for _, p in ipairs(PRESETS) do
		activeFlags[p.name] = p.value
	end

	-- load saved fflags from config if present
	if type(config.fflags) == "table" then
		for k, v in pairs(config.fflags) do
			activeFlags[k] = tostring(v)
		end
	end

	local function persistFlags()
		config.fflags = activeFlags
		saveConfig()
	end

	-- search bar
	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -24, 0, 32)
	searchBox.Position = UDim2.new(0, 12, 0, 10)
	searchBox.BackgroundColor3 = COLORS.Tab
	searchBox.BorderSizePixel = 0
	searchBox.PlaceholderText = "Search flags..."
	searchBox.PlaceholderColor3 = COLORS.TextDim
	searchBox.Text = ""
	searchBox.TextColor3 = COLORS.Text
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 13
	searchBox.ClearTextOnFocus = false
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.Parent = page
	addCorner(searchBox, 6)
	addStroke(searchBox, COLORS.Stroke, 1)

	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 10)
	searchPad.Parent = searchBox

	-- add custom row
	local addRow = Instance.new("Frame")
	addRow.Size = UDim2.new(1, -24, 0, 32)
	addRow.Position = UDim2.new(0, 12, 0, 48)
	addRow.BackgroundTransparency = 1
	addRow.Parent = page

	local nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.new(0.55, -4, 1, 0)
	nameBox.BackgroundColor3 = COLORS.Tab
	nameBox.BorderSizePixel = 0
	nameBox.PlaceholderText = "Flag name"
	nameBox.PlaceholderColor3 = COLORS.TextDim
	nameBox.Text = ""
	nameBox.TextColor3 = COLORS.Text
	nameBox.Font = Enum.Font.Gotham
	nameBox.TextSize = 12
	nameBox.ClearTextOnFocus = false
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.Parent = addRow
	addCorner(nameBox, 6)

	local namePad = Instance.new("UIPadding")
	namePad.PaddingLeft = UDim.new(0, 8)
	namePad.Parent = nameBox

	local valBox = Instance.new("TextBox")
	valBox.Size = UDim2.new(0.25, -4, 1, 0)
	valBox.Position = UDim2.new(0.55, 2, 0, 0)
	valBox.BackgroundColor3 = COLORS.Tab
	valBox.BorderSizePixel = 0
	valBox.PlaceholderText = "Value"
	valBox.PlaceholderColor3 = COLORS.TextDim
	valBox.Text = ""
	valBox.TextColor3 = COLORS.Text
	valBox.Font = Enum.Font.Gotham
	valBox.TextSize = 12
	valBox.ClearTextOnFocus = false
	valBox.Parent = addRow
	addCorner(valBox, 6)

	local addBtn = Instance.new("TextButton")
	addBtn.Size = UDim2.new(0.2, -2, 1, 0)
	addBtn.Position = UDim2.new(0.8, 2, 0, 0)
	addBtn.BackgroundColor3 = COLORS.Accent
	addBtn.BorderSizePixel = 0
	addBtn.Text = "Add"
	addBtn.TextColor3 = Color3.new(1, 1, 1)
	addBtn.Font = Enum.Font.GothamBold
	addBtn.TextSize = 13
	addBtn.AutoButtonColor = true
	addBtn.Parent = addRow
	addCorner(addBtn, 6)

	-- scroll list
	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, -24, 1, -168)
	listFrame.Position = UDim2.new(0, 12, 0, 88)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.ScrollBarImageColor3 = COLORS.Stroke
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = page

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = listFrame

	local flagRows = {} -- name -> row frame

	local function makeFlagRow(flagName, flagValue)
		if flagRows[flagName] then
			flagRows[flagName]:Destroy()
			flagRows[flagName] = nil
		end

		local row = Instance.new("Frame")
		row.Name = flagName
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundColor3 = COLORS.Tab
		row.BorderSizePixel = 0
		row.Parent = listFrame
		addCorner(row, 6)

		local nLbl = Instance.new("TextLabel")
		nLbl.Size = UDim2.new(0.62, -8, 1, 0)
		nLbl.Position = UDim2.new(0, 8, 0, 0)
		nLbl.BackgroundTransparency = 1
		nLbl.Text = flagName
		nLbl.TextColor3 = COLORS.Text
		nLbl.Font = Enum.Font.Gotham
		nLbl.TextSize = 11
		nLbl.TextXAlignment = Enum.TextXAlignment.Left
		nLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nLbl.Parent = row

		local vBox = Instance.new("TextBox")
		vBox.Size = UDim2.new(0, 70, 0, 24)
		vBox.Position = UDim2.new(1, -110, 0.5, -12)
		vBox.BackgroundColor3 = COLORS.Content
		vBox.BorderSizePixel = 0
		vBox.Text = tostring(flagValue)
		vBox.TextColor3 = COLORS.Accent
		vBox.Font = Enum.Font.GothamBold
		vBox.TextSize = 12
		vBox.ClearTextOnFocus = false
		vBox.Parent = row
		addCorner(vBox, 4)

		vBox.FocusLost:Connect(function()
			activeFlags[flagName] = vBox.Text
			persistFlags()
		end)

		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.new(0, 28, 0, 24)
		delBtn.Position = UDim2.new(1, -34, 0.5, -12)
		delBtn.BackgroundColor3 = COLORS.Content
		delBtn.BorderSizePixel = 0
		delBtn.Text = "×"
		delBtn.TextColor3 = COLORS.Danger
		delBtn.Font = Enum.Font.GothamBold
		delBtn.TextSize = 16
		delBtn.AutoButtonColor = true
		delBtn.Parent = row
		addCorner(delBtn, 4)

		delBtn.MouseButton1Click:Connect(function()
			activeFlags[flagName] = nil
			row:Destroy()
			flagRows[flagName] = nil
			persistFlags()
		end)

		flagRows[flagName] = row
		return row
	end

	local function refreshList(filter)
		filter = string.lower(filter or "")
		for name, row in pairs(flagRows) do
			if filter == "" or string.find(string.lower(name), filter, 1, true) then
				row.Visible = true
			else
				row.Visible = false
			end
		end
	end

	for name, value in pairs(activeFlags) do
		makeFlagRow(name, value)
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		refreshList(searchBox.Text)
	end)

	addBtn.MouseButton1Click:Connect(function()
		local n = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		local v = valBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if n == "" or v == "" then return end
		activeFlags[n] = v
		makeFlagRow(n, v)
		nameBox.Text = ""
		valBox.Text = ""
		persistFlags()
		refreshList(searchBox.Text)
	end)

	-- import JSON
	local jsonBox = Instance.new("TextBox")
	jsonBox.Size = UDim2.new(1, -24, 0, 28)
	jsonBox.Position = UDim2.new(0, 12, 1, -78)
	jsonBox.BackgroundColor3 = COLORS.Tab
	jsonBox.BorderSizePixel = 0
	jsonBox.PlaceholderText = 'Import JSON  {"DFIntTaskSchedulerTargetFps":"999"}'
	jsonBox.PlaceholderColor3 = COLORS.TextDim
	jsonBox.Text = ""
	jsonBox.TextColor3 = COLORS.Text
	jsonBox.Font = Enum.Font.Gotham
	jsonBox.TextSize = 11
	jsonBox.ClearTextOnFocus = false
	jsonBox.TextXAlignment = Enum.TextXAlignment.Left
	jsonBox.Parent = page
	addCorner(jsonBox, 6)

	local jsonPad = Instance.new("UIPadding")
	jsonPad.PaddingLeft = UDim.new(0, 8)
	jsonPad.Parent = jsonBox

	-- apply bar
	local applyBar = Instance.new("Frame")
	applyBar.Size = UDim2.new(1, -24, 0, 30)
	applyBar.Position = UDim2.new(0, 12, 1, -42)
	applyBar.BackgroundTransparency = 1
	applyBar.Parent = page

	local importBtn = Instance.new("TextButton")
	importBtn.Size = UDim2.new(0.32, -4, 1, 0)
	importBtn.BackgroundColor3 = COLORS.Tab
	importBtn.BorderSizePixel = 0
	importBtn.Text = "Import JSON"
	importBtn.TextColor3 = COLORS.Text
	importBtn.Font = Enum.Font.GothamBold
	importBtn.TextSize = 12
	importBtn.AutoButtonColor = true
	importBtn.Parent = applyBar
	addCorner(importBtn, 6)

	local applyBtn = Instance.new("TextButton")
	applyBtn.Size = UDim2.new(0.32, -4, 1, 0)
	applyBtn.Position = UDim2.new(0.32, 2, 0, 0)
	applyBtn.BackgroundColor3 = COLORS.Accent
	applyBtn.BorderSizePixel = 0
	applyBtn.Text = "Apply All"
	applyBtn.TextColor3 = Color3.new(1, 1, 1)
	applyBtn.Font = Enum.Font.GothamBold
	applyBtn.TextSize = 12
	applyBtn.AutoButtonColor = true
	applyBtn.Parent = applyBar
	addCorner(applyBtn, 6)

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.36, -4, 1, 0)
	statusLbl.Position = UDim2.new(0.64, 4, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = ""
	statusLbl.TextColor3 = COLORS.TextDim
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 11
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Parent = applyBar

	importBtn.MouseButton1Click:Connect(function()
		local raw = jsonBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if raw == "" then
			statusLbl.Text = "Paste JSON first"
			statusLbl.TextColor3 = COLORS.Danger
			return
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not ok or type(decoded) ~= "table" then
			statusLbl.Text = "Invalid JSON"
			statusLbl.TextColor3 = COLORS.Danger
			return
		end
		local count = 0
		for k, v in pairs(decoded) do
			if type(k) == "string" then
				activeFlags[k] = tostring(v)
				makeFlagRow(k, tostring(v))
				count += 1
			end
		end
		persistFlags()
		refreshList(searchBox.Text)
		jsonBox.Text = ""
		statusLbl.Text = "Imported " .. count
		statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
	end)

	applyBtn.MouseButton1Click:Connect(function()
		local applied, failed = 0, 0
		for name, value in pairs(activeFlags) do
			if trySetFFlag(name, value) then
				applied += 1
			else
				failed += 1
			end
		end
		persistFlags()
		if failed > 0 and applied == 0 then
			statusLbl.Text = "setfflag not available"
			statusLbl.TextColor3 = COLORS.Danger
		else
			statusLbl.Text = "Applied " .. applied .. (failed > 0 and (" (" .. failed .. " failed)") or "")
			statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
		end
		task.delay(2.5, function()
			if statusLbl and statusLbl.Parent then
				statusLbl.Text = ""
			end
		end)
	end)
end

-- ─── Settings Tab ─────────────────────────────────────────
do
	local page = pages["Settings"]

	local function makeRow(y, labelText)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -24, 0, 40)
		row.Position = UDim2.new(0, 12, 0, y)
		row.BackgroundColor3 = COLORS.Tab
		row.BorderSizePixel = 0
		row.Parent = page
		addCorner(row, 8)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.5, -10, 1, 0)
		lbl.Position = UDim2.new(0, 12, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = labelText
		lbl.TextColor3 = COLORS.Text
		lbl.Font = Enum.Font.GothamMedium
		lbl.TextSize = 14
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		return row
	end

	-- Close keybind
	local keyRow = makeRow(14, "Close keybind")
	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(0, 90, 0, 28)
	keyBtn.Position = UDim2.new(1, -102, 0.5, -14)
	keyBtn.BackgroundColor3 = COLORS.Content
	keyBtn.BorderSizePixel = 0
	keyBtn.Text = config.closeKey
	keyBtn.TextColor3 = COLORS.Accent
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.TextSize = 14
	keyBtn.AutoButtonColor = false
	keyBtn.Parent = keyRow
	addCorner(keyBtn, 6)
	addStroke(keyBtn, COLORS.Stroke, 1)

	local listening = false
	keyBtn.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keyBtn.Text = "..."
		keyBtn.TextColor3 = COLORS.TextDim

		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			local name = input.KeyCode.Name
			if name == "Unknown" or name == "L" then return end -- L is kill
			closeKeyCode = input.KeyCode
			config.closeKey = name
			keyBtn.Text = name
			keyBtn.TextColor3 = COLORS.Accent
			title.Text = "Plexer  [" .. name .. "] close  [L] kill"
			saveConfig()
			listening = false
			conn:Disconnect()
		end)
	end)

	-- UI size slider
	local sizeLabel = Instance.new("TextLabel")
	sizeLabel.Size = UDim2.new(1, -24, 0, 18)
	sizeLabel.Position = UDim2.new(0, 12, 0, 60)
	sizeLabel.BackgroundTransparency = 1
	sizeLabel.Text = "UI size  " .. UI_W .. "x" .. UI_H
	sizeLabel.TextColor3 = COLORS.Text
	sizeLabel.Font = Enum.Font.GothamMedium
	sizeLabel.TextSize = 14
	sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
	sizeLabel.Parent = page

	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -24, 0, 8)
	sliderBg.Position = UDim2.new(0, 12, 0, 86)
	sliderBg.BackgroundColor3 = COLORS.Tab
	sliderBg.BorderSizePixel = 0
	sliderBg.Parent = page
	addCorner(sliderBg, 4)

	local MIN_W, MAX_W = 400, 1000
	local function widthToAlpha(w)
		return (w - MIN_W) / (MAX_W - MIN_W)
	end
	local function alphaToWidth(a)
		return math.floor(MIN_W + a * (MAX_W - MIN_W) + 0.5)
	end

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(widthToAlpha(UI_W), 0, 1, 0)
	sliderFill.BackgroundColor3 = COLORS.Accent
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderBg
	addCorner(sliderFill, 4)

	local sliderKnob = Instance.new("Frame")
	sliderKnob.Size = UDim2.new(0, 16, 0, 16)
	sliderKnob.Position = UDim2.new(widthToAlpha(UI_W), -8, 0.5, -8)
	sliderKnob.BackgroundColor3 = COLORS.Text
	sliderKnob.BorderSizePixel = 0
	sliderKnob.Parent = sliderBg
	addCorner(sliderKnob, 8)

	local sliding = false
	local function setSizeFromAlpha(a)
		a = math.clamp(a, 0, 1)
		local w = alphaToWidth(a)
		local h = math.floor(w * 0.72 + 0.5)
		h = math.clamp(h, 280, 700)
		UI_W, UI_H = w, h
		config.uiWidth, config.uiHeight = w, h
		sliderFill.Size = UDim2.new(a, 0, 1, 0)
		sliderKnob.Position = UDim2.new(a, -8, 0.5, -8)
		sizeLabel.Text = "UI size  " .. w .. "x" .. h
		main.Size = UDim2.new(0, w, 0, h)
		main.Position = UDim2.new(0.5, -math.floor(w / 2), 0.5, -math.floor(h / 2))
		savedPos = main.Position
	end

	sliderBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
			setSizeFromAlpha(rel)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not sliding then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / math.max(sliderBg.AbsoluteSize.X, 1)
		setSizeFromAlpha(rel)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if sliding then
				sliding = false
				saveConfig()
			end
		end
	end)

	-- Accent color RGB
	local colorTitle = Instance.new("TextLabel")
	colorTitle.Size = UDim2.new(1, -24, 0, 18)
	colorTitle.Position = UDim2.new(0, 12, 0, 110)
	colorTitle.BackgroundTransparency = 1
	colorTitle.Text = "Accent color (RGB)"
	colorTitle.TextColor3 = COLORS.Text
	colorTitle.Font = Enum.Font.GothamMedium
	colorTitle.TextSize = 14
	colorTitle.TextXAlignment = Enum.TextXAlignment.Left
	colorTitle.Parent = page

	local function makeRGBBox(x, placeholder, defaultVal)
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0, 52, 0, 28)
		box.Position = UDim2.new(0, x, 0, 134)
		box.BackgroundColor3 = COLORS.Tab
		box.BorderSizePixel = 0
		box.Text = tostring(defaultVal)
		box.PlaceholderText = placeholder
		box.TextColor3 = COLORS.Text
		box.Font = Enum.Font.Gotham
		box.TextSize = 13
		box.ClearTextOnFocus = false
		box.Parent = page
		addCorner(box, 6)
		return box
	end

	local acc = config.colors and config.colors.Accent or {100, 140, 255}
	local rBox = makeRGBBox(12, "R", acc[1] or 100)
	local gBox = makeRGBBox(70, "G", acc[2] or 140)
	local bBox = makeRGBBox(128, "B", acc[3] or 255)

	local preview = Instance.new("Frame")
	preview.Size = UDim2.new(0, 28, 0, 28)
	preview.Position = UDim2.new(0, 188, 0, 134)
	preview.BackgroundColor3 = COLORS.Accent
	preview.BorderSizePixel = 0
	preview.Parent = page
	addCorner(preview, 6)

	local applyColorBtn = Instance.new("TextButton")
	applyColorBtn.Size = UDim2.new(0, 70, 0, 28)
	applyColorBtn.Position = UDim2.new(0, 224, 0, 134)
	applyColorBtn.BackgroundColor3 = COLORS.Content
	applyColorBtn.BorderSizePixel = 0
	applyColorBtn.Text = "Apply"
	applyColorBtn.TextColor3 = COLORS.Accent
	applyColorBtn.Font = Enum.Font.GothamBold
	applyColorBtn.TextSize = 13
	applyColorBtn.AutoButtonColor = true
	applyColorBtn.Parent = page
	addCorner(applyColorBtn, 6)

	applyColorBtn.MouseButton1Click:Connect(function()
		local r = math.clamp(tonumber(rBox.Text) or 100, 0, 255)
		local g = math.clamp(tonumber(gBox.Text) or 140, 0, 255)
		local b = math.clamp(tonumber(bBox.Text) or 255, 0, 255)
		local c = Color3.fromRGB(r, g, b)
		COLORS.Accent = c
		if not config.colors then config.colors = {} end
		config.colors.Accent = {r, g, b}
		preview.BackgroundColor3 = c
		applyColorBtn.TextColor3 = c
		sliderFill.BackgroundColor3 = c
		title.TextColor3 = COLORS.Text
		saveConfig()
		applyColorBtn.Text = "OK"
		task.delay(1, function()
			if applyColorBtn and applyColorBtn.Parent then
				applyColorBtn.Text = "Apply"
			end
		end)
	end)

	-- Save config
	local saveRow = makeRow(178, "Save config")
	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(0, 90, 0, 28)
	saveBtn.Position = UDim2.new(1, -102, 0.5, -14)
	saveBtn.BackgroundColor3 = COLORS.Content
	saveBtn.BorderSizePixel = 0
	saveBtn.Text = "Save"
	saveBtn.TextColor3 = COLORS.Accent
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextSize = 14
	saveBtn.AutoButtonColor = false
	saveBtn.Parent = saveRow
	addCorner(saveBtn, 6)
	addStroke(saveBtn, COLORS.Stroke, 1)

	local saveHint = Instance.new("TextLabel")
	saveHint.Size = UDim2.new(1, -24, 0, 18)
	saveHint.Position = UDim2.new(0, 12, 0, 228)
	saveHint.BackgroundTransparency = 1
	saveHint.Text = "Auto-loads for your userId on inject"
	saveHint.TextColor3 = COLORS.TextDim
	saveHint.Font = Enum.Font.Gotham
	saveHint.TextSize = 12
	saveHint.TextXAlignment = Enum.TextXAlignment.Left
	saveHint.Parent = page

	saveBtn.MouseButton1Click:Connect(function()
		local ok = saveConfig()
		saveBtn.Text = ok and "Saved!" or "Failed"
		saveBtn.TextColor3 = ok and Color3.fromRGB(80, 200, 120) or COLORS.Danger
		task.delay(1.2, function()
			if saveBtn and saveBtn.Parent then
				saveBtn.Text = "Save"
				saveBtn.TextColor3 = COLORS.Accent
			end
		end)
	end)
end

-- ─── Info Tab Content ─────────────────────────────────────
do
	local infoPage = pages["Info"]
	local DEV_USERNAME = "xxxvcxxxv"

	local avatarFrame = Instance.new("Frame")
	avatarFrame.Size = UDim2.new(0, 80, 0, 80)
	avatarFrame.Position = UDim2.new(0.5, -40, 0, 24)
	avatarFrame.BackgroundColor3 = COLORS.Tab
	avatarFrame.BorderSizePixel = 0
	avatarFrame.Parent = infoPage
	addCorner(avatarFrame, 40)
	addStroke(avatarFrame, COLORS.Stroke, 1)

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Size = UDim2.new(1, 0, 1, 0)
	avatarImg.BackgroundTransparency = 1
	avatarImg.Image = ""
	avatarImg.Parent = avatarFrame
	addCorner(avatarImg, 40)

	local displayLbl = Instance.new("TextLabel")
	displayLbl.Size = UDim2.new(1, -20, 0, 24)
	displayLbl.Position = UDim2.new(0, 10, 0, 116)
	displayLbl.BackgroundTransparency = 1
	displayLbl.Text = "..."
	displayLbl.TextColor3 = COLORS.Text
	displayLbl.Font = Enum.Font.GothamBold
	displayLbl.TextSize = 18
	displayLbl.TextXAlignment = Enum.TextXAlignment.Center
	displayLbl.Parent = infoPage

	local userLbl = Instance.new("TextLabel")
	userLbl.Size = UDim2.new(1, -20, 0, 20)
	userLbl.Position = UDim2.new(0, 10, 0, 140)
	userLbl.BackgroundTransparency = 1
	userLbl.Text = "@" .. DEV_USERNAME
	userLbl.TextColor3 = COLORS.TextDim
	userLbl.Font = Enum.Font.Gotham
	userLbl.TextSize = 14
	userLbl.TextXAlignment = Enum.TextXAlignment.Center
	userLbl.Parent = infoPage

	local creditLbl = Instance.new("TextLabel")
	creditLbl.Size = UDim2.new(1, -20, 0, 22)
	creditLbl.Position = UDim2.new(0, 10, 0, 180)
	creditLbl.BackgroundTransparency = 1
	creditLbl.Text = "Plexer — made by Complex"
	creditLbl.TextColor3 = COLORS.Accent
	creditLbl.Font = Enum.Font.GothamMedium
	creditLbl.TextSize = 14
	creditLbl.TextXAlignment = Enum.TextXAlignment.Center
	creditLbl.Parent = infoPage

	local verLbl = Instance.new("TextLabel")
	verLbl.Size = UDim2.new(1, -20, 0, 20)
	verLbl.Position = UDim2.new(0, 10, 0, 210)
	verLbl.BackgroundTransparency = 1
	verLbl.Text = "Version 1.0.0"
	verLbl.TextColor3 = COLORS.TextDim
	verLbl.Font = Enum.Font.Gotham
	verLbl.TextSize = 13
	verLbl.TextXAlignment = Enum.TextXAlignment.Center
	verLbl.Parent = infoPage

	task.spawn(function()
		local okId, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(DEV_USERNAME)
		end)
		if not okId or not userId then
			displayLbl.Text = DEV_USERNAME
			return
		end

		local okInfo, infos = pcall(function()
			return game:GetService("UserService"):GetUserInfosByUserIdsAsync({userId})
		end)
		if okInfo and infos and infos[1] and infos[1].DisplayName then
			displayLbl.Text = infos[1].DisplayName
		else
			displayLbl.Text = DEV_USERNAME
		end

		local okThumb, url = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)
		if okThumb and url then
			avatarImg.Image = url
		end
	end)
end

-- ─── Tab Logic ────────────────────────────────────────────
local activeTab = nil

local function setTab(name)
	if name == activeTab then return end
	if activeTab then
		tabButtons[activeTab].BackgroundColor3 = COLORS.Tab
		tabButtons[activeTab].TextColor3 = COLORS.TextDim
		pages[activeTab].Visible = false
	end
	activeTab = name
	tabButtons[name].BackgroundColor3 = COLORS.TabActive
	tabButtons[name].TextColor3 = COLORS.Text
	pages[name].Visible = true
end

for _, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function()
		setTab(btn.Name:sub(5))
	end)
end

setTab("Skyboxes")

-- ─── Notification ─────────────────────────────────────────
local notif = Instance.new("Frame")
notif.Size = UDim2.new(0, 280, 0, 48)
notif.Position = UDim2.new(0.5, -140, 1, -20)
notif.BackgroundColor3 = COLORS.Main
notif.BorderSizePixel = 0
notif.Visible = false
notif.Parent = gui
addCorner(notif, 10)
addStroke(notif, COLORS.Stroke, 1)

local nText = Instance.new("TextLabel")
nText.Size = UDim2.new(1, 0, 0, 24)
nText.Position = UDim2.new(0, 0, 0, 6)
nText.BackgroundTransparency = 1
nText.Text = "Script closed"
nText.TextColor3 = COLORS.Text
nText.Font = Enum.Font.GothamMedium
nText.TextSize = 14
nText.TextXAlignment = Enum.TextXAlignment.Center
nText.Parent = notif

local nKey = Instance.new("TextLabel")
nKey.Size = UDim2.new(1, 0, 0, 20)
nKey.Position = UDim2.new(0, 0, 0, 28)
nKey.BackgroundTransparency = 1
nKey.Text = "Press [" .. config.closeKey .. "] to open"
nKey.TextColor3 = COLORS.Accent
nKey.Font = Enum.Font.GothamBold
nKey.TextSize = 13
nKey.TextXAlignment = Enum.TextXAlignment.Center
nKey.Parent = notif

-- ─── Open / Close ─────────────────────────────────────────
local isOpen = false
local destroyed = false
local loading = true
local lastToggle = 0
local savedPos = main.Position
local closeToken = 0
local inputConn, renderConn

local function hideNotif()
	if not notif.Visible then return end
	notif:TweenPosition(UDim2.new(0.5, -140, 1, -20), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.15, true, function()
		notif.Visible = false
	end)
end

local function openMenu()
	if isOpen or destroyed then return end
	isOpen = true
	closeToken += 1

	hideNotif()

	main.Position = savedPos
	main.Size = UDim2.new(0, 0, 0, 0)
	main.Visible = true
	main:TweenSize(UDim2.new(0, UI_W, 0, UI_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true)
end

local function closeMenu()
	if not isOpen or destroyed then return end
	isOpen = false
	savedPos = main.Position
	closeToken += 1
	local token = closeToken

	nKey.Text = "Press [" .. config.closeKey .. "] to open"

	main:TweenSize(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)

	task.delay(0.2, function()
		if destroyed or token ~= closeToken then return end
		main.Visible = false
		notif.Visible = true
		notif.Position = UDim2.new(0.5, -140, 1, -20)
		notif:TweenPosition(UDim2.new(0.5, -140, 1, -60), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)

		task.delay(2.5, function()
			if destroyed or token ~= closeToken then return end
			if not notif.Visible then return end
			notif:TweenPosition(UDim2.new(0.5, -140, 1, -20), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.25, true, function()
				if token == closeToken then
					notif.Visible = false
				end
			end)
		end)
	end)
end

local function killScript()
	if destroyed then return end
	destroyed = true
	closeToken += 1

	if inputConn then inputConn:Disconnect() end
	if renderConn then renderConn:Disconnect() end

	gui:Destroy()
end

-- ─── Key Handling ─────────────────────────────────────────
inputConn = UserInputService.InputBegan:Connect(function(input)
	if destroyed or loading then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	if input.KeyCode == closeKeyCode then
		local now = tick()
		if now - lastToggle < 0.25 then return end
		lastToggle = now
		if isOpen then
			closeMenu()
		else
			openMenu()
		end
	elseif input.KeyCode == Enum.KeyCode.L then
		killScript()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	closeMenu()
end)

-- ─── Draggable ────────────────────────────────────────────
local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local pos = input.Position
	local abs = closeBtn.AbsolutePosition
	local size = closeBtn.AbsoluteSize
	if pos.X >= abs.X and pos.X <= abs.X + size.X
		and pos.Y >= abs.Y and pos.Y <= abs.Y + size.Y then
		return
	end
	dragging = true
	dragStart = input.Position
	startPos = main.Position
end)

titleBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local d = input.Position - dragStart
	main.Position = UDim2.new(
		startPos.X.Scale, startPos.X.Offset + d.X,
		startPos.Y.Scale, startPos.Y.Offset + d.Y
	)
end)

-- ─── Startup Loader ───────────────────────────────────────
task.spawn(function()
	local steps = {
		{text = "Initializing", progress = 0.15},
		{text = "Loading content", progress = 0.4},
		{text = "Auto-loading settings", progress = 0.7},
		{text = "Ready", progress = 1},
	}

	for _, step in ipairs(steps) do
		if destroyed then return end
		loaderStatus.Text = step.text
		loaderBar:TweenSize(
			UDim2.new(step.progress, 0, 1, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quart,
			0.35,
			true
		)
		task.wait(0.45)
	end

	task.wait(0.2)
	if destroyed then return end

	loader:TweenSize(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
	task.wait(0.2)
	if destroyed then return end
	loader.Visible = false
	loader:Destroy()

	loading = false
	openMenu()
end)
