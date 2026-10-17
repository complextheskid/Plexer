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
	linkedUserId = 0, -- Locks the key session to this specific Roblox User ID
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

-- ─── Key system (GitHub JSON + Base64 + HWID/UserId Lock) ──
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
loader.Visible = false
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

	local function clearBlackDome()
		local dome = workspace:FindFirstChild("PlexerBlackSky")
		if dome then dome:Destroy() end
	end

	local function clearOldSky()
		clearBlackDome()
		for _, c in ipairs(Lighting:GetChildren()) do
			if c:IsA("Sky") then
				c:Destroy()
			end
		end
	end

	local function applyBlackSky()
		clearOldSky()
		local dome = Instance.new("Part")
		dome.Name = "PlexerBlackSky"
		dome.Shape = Enum.PartType.Ball
		dome.Size = Vector3.new(4000, 4000, 4000)
		dome.Anchored = true
		dome.CanCollide = false
		dome.CanQuery = false
		dome.CanTouch = false
		dome.CastShadow = false
		dome.Material = Enum.Material.Neon
		dome.Color = Color3.new(0, 0, 0)
		dome.Transparency = 0
		dome.Parent = workspace

		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(-1, -1, -1)
		mesh.Parent = dome

		task.spawn(function()
			while dome.Parent do
				local cam = workspace.CurrentCamera
				if cam then
					dome.Position = cam.CFrame.Position
				end
				task.wait(0.1)
			end
		end)

		local sky = Instance.new("Sky")
		sky.CelestialBodiesShown = false
		sky.StarCount = 0
		sky.SkyboxBk = "rbxassetid://0"
		sky.SkyboxDn = "rbxassetid://0"
		sky.SkyboxFt = "rbxassetid://0"
		sky.SkyboxLf = "rbxassetid://0"
		sky.SkyboxRt = "rbxassetid://0"
		sky.SkyboxUp = "rbxassetid://0"
		sky.Parent = Lighting
		return sky
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
			special = nil,
		},
		{
			name = "Black Sky",
			faces = nil,
			opts = {celestial = false, stars = 0},
			special = "black",
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
			special = nil,
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
			if preset.special == "black" then
				applyBlackSky()
			else
				applySky(preset.faces, preset.opts)
			end
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
		local req = (syn and syn.request) or http_request or request
		if not req then return nil, "no http request" end
		if not getcustomasset then return nil, "no getcustomasset" end

		local ok, res = pcall(function()
			return req({
				Url = url,
				Method = "GET",
				Headers = {["User-Agent"] = "Mozilla/5.0"},
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
		if not wok then return nil, "write failed" end

		local aok, asset = pcall(getcustomasset, path)
		if not aok or not asset then return nil, "getcustomasset failed" end
		return asset, nil
	end

	applyCustom.MouseButton1Click:Connect(function()
		local url = linkBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if not isValidCdn(url) then
			setStatus("Invalid link — use CDN or rbxassetid://", false)
			return
		end

		if tonumber(url) then
			url = "rbxassetid://" .. url
		end
		if url:lower():find("rbxassetid://", 1, true) or url:lower():find("rbxasset://", 1, true) then
			applySky(url, {celestial = false, stars = 0})
			setStatus("Applied custom skybox", true)
			return
		end

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

-- ─── FFlags Tab ───────────────────────────────────────────
do
	local page = pages["FFlags"]

	local function trySetFFlag(name, value)
		local ok = pcall(function()
			if setfflag then
				setfflag(name, tostring(value))
			end
		end)
		return ok
	end

	local PRESETS = {
		{name = "DFIntTaskSchedulerTargetFps", value = "999", cat = "Performance"},
		{name = "FFlagDisablePostFx", value = "True", cat = "Graphics"},
		{name = "FIntDebugForceMSAASamples", value = "0", cat = "Graphics"},
		{name = "DFFlagTextureQualityOverrideEnabled", value = "True", cat = "Graphics"},
		{name = "DFIntTextureQualityOverride", value = "1", cat = "Graphics"},
		{name = "FFlagDebugGraphicsPreferD3D11", value = "True", cat = "Graphics"},
		{name = "DFFlagDisableDPIScale", value = "True", cat = "UI"},
	}

	local activeFlags = {}
	for _, p in ipairs(PRESETS) do
		activeFlags[p.name] = p.value
	end

	if type(config.fflags) == "table" then
		for k, v in pairs(config.fflags) do
			activeFlags[k] = tostring(v)
		end
	end

	local function persistFlags()
		config.fflags = activeFlags
		saveConfig()
	end

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

	local flagRows = {}

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

	local jsonBox = Instance.new("TextBox")
	jsonBox.Size = UDim2.new(1, -24, 0, 28)
	jsonBox.Position = UDim2.new(0, 12, 1, -78)
	jsonBox.BackgroundColor3 = COLORS.Tab
	jsonBox.BorderSizePixel = 0
	jsonBox.PlaceholderText = 'Import JSON'
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

	applyBtn.MouseButton1Click:Connect(function()
		local applied = 0
		for name, value in pairs(activeFlags) do
			if trySetFFlag(name, value) then
				applied += 1
			end
		end
		persistFlags()
		statusLbl.Text = "Applied " .. applied
		statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
		task.delay(2.5, function()
			if statusLbl and statusLbl.Parent then statusLbl.Text = "" end
		end)
	end)
end

-- ─── ScriptHub Tab ────────────────────────────────────────
do
	local page = pages["ScriptHub"]
	local function httpGet(url)
		local ok, body = pcall(function() return game:HttpGet(url) end)
		if ok and body then return body end
		local req = (syn and syn.request) or http_request or request
		if req then
			local rok, res = pcall(function() return req({Url = url, Method = "GET"}) end)
			if rok and res and res.Body then return res.Body end
		end
		return nil
	end

	local searchWrap = Instance.new("Frame")
	searchWrap.Size = UDim2.new(1, -24, 0, 40)
	searchWrap.Position = UDim2.new(0, 12, 0, 10)
	searchWrap.BackgroundColor3 = COLORS.Tab
	searchWrap.BorderSizePixel = 0
	searchWrap.Parent = page
	addCorner(searchWrap, 10)
	addStroke(searchWrap, COLORS.Stroke, 1)

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -100, 1, 0)
	searchBox.Position = UDim2.new(0, 34, 0, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText = "Search scripts..."
	searchBox.PlaceholderColor3 = COLORS.TextDim
	searchBox.Text = ""
	searchBox.TextColor3 = COLORS.Text
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 14
	searchBox.Parent = searchWrap

	local searchBtn = Instance.new("TextButton")
	searchBtn.Size = UDim2.new(0, 60, 0, 28)
	searchBtn.Position = UDim2.new(1, -66, 0.5, -14)
	searchBtn.BackgroundColor3 = COLORS.Accent
	searchBtn.BorderSizePixel = 0
	searchBtn.Text = "Go"
	searchBtn.TextColor3 = Color3.new(1, 1, 1)
	searchBtn.Font = Enum.Font.GothamBold
	searchBtn.Parent = searchWrap
	addCorner(searchBtn, 6)

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, -24, 1, -96)
	listFrame.Position = UDim2.new(0, 12, 0, 58)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = page

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = listFrame

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(1, -24, 0, 18)
	statusLbl.Position = UDim2.new(0, 12, 1, -28)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "Scripts from robloxscripts.com"
	statusLbl.TextColor3 = COLORS.TextDim
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 11
	statusLbl.Parent = page

	local function fetchScripts(query)
		for _, c in ipairs(listFrame:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		task.spawn(function()
			local q = query and query ~= "" and ("&q=" .. HttpService:UrlEncode(query)) or ""
			local url = "https://robloxscripts.com/api/v1/scripts?limit=20" .. q
			local body = httpGet(url)
			if not body then return end
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if not ok or not data then return end
			local list = data.data or data.scripts or {}
			for i, item in ipairs(list) do
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 52)
				row.BackgroundColor3 = COLORS.Tab
				row.Parent = listFrame
				addCorner(row, 6)

				local title = Instance.new("TextLabel")
				title.Size = UDim2.new(1, -90, 0, 20)
				title.Position = UDim2.new(0, 10, 0, 6)
				title.BackgroundTransparency = 1
				title.Text = item.title or "Untitled"
				title.TextColor3 = COLORS.Text
				title.Font = Enum.Font.GothamMedium
				title.TextSize = 13
				title.Parent = row

				local runBtn = Instance.new("TextButton")
				runBtn.Size = UDim2.new(0, 70, 0, 28)
				runBtn.Position = UDim2.new(1, -80, 0.5, -14)
				runBtn.BackgroundColor3 = COLORS.Accent
				runBtn.BorderSizePixel = 0
				runBtn.Text = "Run"
				runBtn.TextColor3 = Color3.new(1, 1, 1)
				runBtn.Font = Enum.Font.GothamBold
				runBtn.Parent = row
				addCorner(runBtn, 6)

				runBtn.MouseButton1Click:Connect(function()
					task.spawn(function()
						if item.script then
							local fn = loadstring(item.script)
							if fn then fn() end
						elseif item.rawScriptUrl then
							local src = httpGet(item.rawScriptUrl)
							if src then
								local fn = loadstring(src)
								if fn then fn() end
							end
						end
					end)
				end)
			end
		end)
	end

	searchBtn.MouseButton1Click:Connect(function() fetchScripts(searchBox.Text) end)
	task.defer(function() fetchScripts("") end)
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
		lbl.Parent = row
		return row
	end

	local keyRow = makeRow(14, "Close keybind")
	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(0, 90, 0, 28)
	keyBtn.Position = UDim2.new(1, -102, 0.5, -14)
	keyBtn.BackgroundColor3 = COLORS.Content
	keyBtn.BorderSizePixel = 0
	keyBtn.Text = config.closeKey
	keyBtn.TextColor3 = COLORS.Accent
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.Parent = keyRow
	addCorner(keyBtn, 6)

	keyBtn.MouseButton1Click:Connect(function()
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local name = input.KeyCode.Name
				if name ~= "Unknown" and name ~= "L" then
					closeKeyCode = input.KeyCode
					config.closeKey = name
					keyBtn.Text = name
					saveConfig()
					conn:Disconnect()
				end
			end
		end)
	end)

	local saveRow = makeRow(64, "Reset Key / HWID Lock")
	local resetKeyBtn = Instance.new("TextButton")
	resetKeyBtn.Size = UDim2.new(0, 90, 0, 28)
	resetKeyBtn.Position = UDim2.new(1, -102, 0.5, -14)
	resetKeyBtn.BackgroundColor3 = COLORS.Danger
	resetKeyBtn.BorderSizePixel = 0
	resetKeyBtn.Text = "Reset Key"
	resetKeyBtn.TextColor3 = Color3.new(1, 1, 1)
	resetKeyBtn.Font = Enum.Font.GothamBold
	resetKeyBtn.Parent = saveRow
	addCorner(resetKeyBtn, 6)

	resetKeyBtn.MouseButton1Click:Connect(function()
		config.savedKey = ""
		config.linkedUserId = 0
		saveConfig()
		resetKeyBtn.Text = "Cleared!"
		task.delay(1.5, function()
			game:GetService("TeleportService"):Teleport(game.PlaceId, player)
		end)
	end)
end

-- ─── Info Tab Content ─────────────────────────────────────
do
	local infoPage = pages["Info"]
	local creditLbl = Instance.new("TextLabel")
	creditLbl.Size = UDim2.new(1, -20, 0, 22)
	creditLbl.Position = UDim2.new(0, 10, 0, 180)
	creditLbl.BackgroundTransparency = 1
	creditLbl.Text = "Plexer — Dynamic GitHub Key System"
	creditLbl.TextColor3 = COLORS.Accent
	creditLbl.Font = Enum.Font.GothamMedium
	creditLbl.TextSize = 14
	creditLbl.TextXAlignment = Enum.TextXAlignment.Center
	creditLbl.Parent = infoPage
end

-- ─── Open / Close / Input ─────────────────────────────────
local isOpen = false
local destroyed = false
local loading = true
local lastToggle = 0
local savedPos = main.Position
local closeToken = 0
local inputConn

local function hideNotif()
	if not notif.Visible then return end
	notif.Visible = false
end

local function openMenu()
	if isOpen or destroyed then return end
	isOpen = true
	main.Position = savedPos
	main.Size = UDim2.new(0, UI_W, 0, UI_H)
	main.Visible = true
end

local function closeMenu()
	if not isOpen or destroyed then return end
	isOpen = false
	savedPos = main.Position
	main.Visible = false
end

local function killScript()
	if destroyed then return end
	destroyed = true
	if inputConn then inputConn:Disconnect() end
	gui:Destroy()
end

inputConn = UserInputService.InputBegan:Connect(function(input)
	if destroyed or loading then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if input.KeyCode == closeKeyCode then
		if isOpen then closeMenu() else openMenu() end
	elseif input.KeyCode == Enum.KeyCode.L then
		killScript()
	end
end)

closeBtn.MouseButton1Click:Connect(closeMenu)

-- ─── Key System + Startup with Auto-Load Linked UserID ────
local function startLoader()
	loader.Visible = true
	loader.Size = UDim2.new(0, 280, 0, 100)
	task.spawn(function()
		loaderStatus.Text = "Authenticating Key..."
		task.wait(0.4)
		loaderStatus.Text = "Ready"
		loaderBar:TweenSize(UDim2.new(1, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
		task.wait(0.3)
		loader.Visible = false
		loader:Destroy()
		loading = false
		openMenu()
	end)
end

-- Checks if saved key is valid AND locked to this user's ID
local function hasValidStoredSession()
	if config.savedKey ~= "" and config.linkedUserId == player.UserId then
		return isKeyValid(config.savedKey)
	end
	return false
end

if hasValidStoredSession() then
	startLoader()
else
	local keyFrame = Instance.new("Frame")
	keyFrame.Name = "KeySystem"
	keyFrame.Size = UDim2.new(0, 320, 0, 180)
	keyFrame.Position = UDim2.new(0.5, -160, 0.5, -90)
	keyFrame.BackgroundColor3 = COLORS.Main
	keyFrame.BorderSizePixel = 0
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
	keyTitle.TextXAlignment = Enum.TextXAlignment.Center
	keyTitle.Parent = keyFrame

	local keySub = Instance.new("TextLabel")
	keySub.Size = UDim2.new(1, -24, 0, 18)
	keySub.Position = UDim2.new(0, 12, 0, 46)
	keySub.BackgroundTransparency = 1
	keySub.Text = "Enter your Base64 key to auto-save"
	keySub.TextColor3 = COLORS.TextDim
	keySub.Font = Enum.Font.Gotham
	keySub.TextSize = 12
	keySub.Parent = keyFrame

	local keyBox = Instance.new("TextBox")
	keyBox.Size = UDim2.new(1, -24, 0, 34)
	keyBox.Position = UDim2.new(0, 12, 0, 72)
	keyBox.BackgroundColor3 = COLORS.Tab
	keyBox.BorderSizePixel = 0
	keyBox.PlaceholderText = "Paste long Base64 key..."
	keyBox.PlaceholderColor3 = COLORS.TextDim
	keyBox.Text = ""
	keyBox.TextColor3 = COLORS.Text
	keyBox.Font = Enum.Font.Gotham
	keyBox.TextSize = 12
	keyBox.ClearTextOnFocus = false
	keyBox.Parent = keyFrame
	addCorner(keyBox, 8)

	local keyErr = Instance.new("TextLabel")
	keyErr.Size = UDim2.new(1, -24, 0, 16)
	keyErr.Position = UDim2.new(0, 12, 0, 112)
	keyErr.BackgroundTransparency = 1
	keyErr.Text = ""
	keyErr.TextColor3 = COLORS.Danger
	keyErr.Font = Enum.Font.Gotham
	keyErr.TextSize = 11
	keyErr.Parent = keyFrame

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(1, -24, 0, 34)
	keyBtn.Position = UDim2.new(0, 12, 0, 132)
	keyBtn.BackgroundColor3 = COLORS.Accent
	keyBtn.BorderSizePixel = 0
	keyBtn.Text = "Unlock & Link Account"
	keyBtn.TextColor3 = Color3.new(1, 1, 1)
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.TextSize = 14
	keyBtn.AutoButtonColor = true
	keyBtn.Parent = keyFrame
	addCorner(keyBtn, 8)

	local function tryUnlock()
		local k = keyBox.Text
		if isKeyValid(k) then
			config.savedKey = normalizeKey(k)
			config.linkedUserId = player.UserId -- Locks key session to user ID
			saveConfig()
			keyFrame:Destroy()
			startLoader()
		else
			keyErr.Text = "Invalid or expired key!"
		end
	end

	keyBtn.MouseButton1Click:Connect(tryUnlock)
	keyBox.FocusLost:Connect(function(enter)
		if enter then tryUnlock() end
	end)
end
