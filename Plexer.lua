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
	boundUserId = 0,
	boundHwid = "",
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

-- ─── Key system (remote keys.json) ────────────────────────
-- Put your keys.json on GitHub and paste the RAW url here:
local KEYS_URL = "https://raw.githubusercontent.com/complextheskid/Plexer/main/keys.json"

local remoteKeys = {} -- [keyString] = true
local keysReady = false
local keysFetchError = nil

local function trimKey(k)
	return (k or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function httpGetBody(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and body and #body > 0 then return body end
	local req = (syn and syn.request) or http_request or request
	if req then
		local rok, res = pcall(function()
			return req({Url = url, Method = "GET"})
		end)
		if rok and res and res.Body and #res.Body > 0 then
			return res.Body
		end
	end
	return nil
end

local function fetchRemoteKeys()
	remoteKeys = {}
	keysReady = false
	keysFetchError = nil

	local body = httpGetBody(KEYS_URL)
	if not body then
		keysFetchError = "Could not fetch keys.json"
		return false
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(data) ~= "table" then
		keysFetchError = "Invalid keys.json"
		return false
	end

	local count = 0
	-- support array: ["key1","key2"] or object: {"keys":[...]}
	local list = data
	if data.keys and type(data.keys) == "table" then
		list = data.keys
	end

	for _, k in pairs(list) do
		if type(k) == "string" and #k > 0 then
			remoteKeys[trimKey(k)] = true
			count += 1
		end
	end

	if count == 0 then
		keysFetchError = "keys.json empty"
		return false
	end

	keysReady = true
	return true
end

local function isKeyValid(k)
	k = trimKey(k)
	if k == "" then return false end
	return remoteKeys[k] == true
end

local function getHardwareId()
	local getters = {
		"gethwid", "get_hwid", "GetHWID", "gethardwareid",
	}
	for _, name in ipairs(getters) do
		local fn = rawget(_G, name)
		if type(fn) ~= "function" and type(getgenv) == "function" then
			local ok, env = pcall(getgenv)
			if ok and type(env) == "table" then
				fn = env[name]
			end
		end
		if type(fn) == "function" then
			local ok, id = pcall(fn)
			if ok and id and tostring(id) ~= "" then
				return tostring(id)
			end
		end
	end
	-- fallback fingerprint from user + device-ish
	return "uid:" .. tostring(player.UserId)
end

local function isSessionAuthorized()
	if not keysReady then return false end
	local k = trimKey(config.savedKey)
	if not isKeyValid(k) then return false end

	-- must match the Roblox account that claimed the key
	local bound = tonumber(config.boundUserId) or 0
	if bound ~= 0 and bound ~= player.UserId then
		return false
	end

	-- hardware lock (if we stored one)
	local stored = tostring(config.boundHwid or "")
	if stored ~= "" then
		local current = getHardwareId()
		if stored ~= current then
			return false
		end
	end

	return true
end

local function claimKey(k)
	k = trimKey(k)
	config.savedKey = k
	config.boundUserId = player.UserId
	config.boundHwid = getHardwareId()
	saveConfig()
end

local function resetKeyBinding()
	config.savedKey = ""
	config.boundUserId = 0
	config.boundHwid = ""
	saveConfig()
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
		-- solid inverted sphere = guaranteed pure black, no bad asset ids
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
		mesh.Scale = Vector3.new(-1, -1, -1) -- invert so we see inside
		mesh.Parent = dome

		-- keep camera inside the dome
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

	local function findSetFFlag()
		local candidates = {}
		local function add(f)
			if type(f) == "function" then
				table.insert(candidates, f)
			end
		end

		-- direct globals
		add(rawget(_G, "setfflag"))
		add(rawget(_G, "SetFFlag"))
		add(rawget(_G, "set_fflag"))
		if type(setfflag) == "function" then add(setfflag) end

		-- getgenv
		if type(getgenv) == "function" then
			local ok, env = pcall(getgenv)
			if ok and type(env) == "table" then
				add(env.setfflag)
				add(env.SetFFlag)
				add(env.set_fflag)
			end
		end

		-- getfenv / getrenv
		if type(getfenv) == "function" then
			local ok, env = pcall(getfenv, 0)
			if ok and type(env) == "table" then
				add(env.setfflag)
				add(env.SetFFlag)
			end
		end
		if type(getrenv) == "function" then
			local ok, env = pcall(getrenv)
			if ok and type(env) == "table" then
				add(env.setfflag)
				add(env.SetFFlag)
			end
		end

		return candidates
	end

	local setFFlagFns = findSetFFlag()

	local function applyRuntimeEffect(name, value)
		local v = tostring(value)
		local lower = v:lower()
		local truthy = (lower == "true" or lower == "1" or lower == "yes")

		-- FPS
		if name == "DFIntTaskSchedulerTargetFps" or name:find("TargetFps") then
			local n = tonumber(v) or 0
			if type(setfpscap) == "function" then
				return pcall(setfpscap, n)
			end
			if type(setfps) == "function" then
				return pcall(setfps, n)
			end
		end

		-- grass distance
		if name == "FIntFRMMaxGrassDistance" or name == "FIntFRMMinGrassDistance" then
			local ok = pcall(function()
				local terrain = workspace:FindFirstChildOfClass("Terrain")
				if terrain and tonumber(v) == 0 then
					terrain.Decoration = false
				end
			end)
			return ok
		end

		-- quality override
		if name == "DFIntDebugFRMQualityLevelOverride" then
			local ok = pcall(function()
				settings().Rendering.QualityLevel = Enum.QualityLevel["Level" .. tostring(math.clamp(tonumber(v) or 1, 1, 21))]
					or Enum.QualityLevel.Level01
			end)
			if not ok then
				ok = pcall(function()
					UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
				end)
			end
			return ok
		end

		return false
	end

	local function trySetFFlag(name, value)
		value = tostring(value)
		local applied = false

		-- refresh fn list in case executor injects late
		if #setFFlagFns == 0 then
			setFFlagFns = findSetFFlag()
		end

		for _, fn in ipairs(setFFlagFns) do
			local ok = pcall(fn, name, value)
			if ok then
				applied = true
				break
			end
			-- some APIs want (name, value, true)
			ok = pcall(fn, name, value, true)
			if ok then
				applied = true
				break
			end
		end

		-- runtime equivalents always tried
		if applyRuntimeEffect(name, value) then
			applied = true
		end

		return applied
	end

	local function tryGetFFlag(name)
		local getters = {}
		if type(getfflag) == "function" then table.insert(getters, getfflag) end
		if type(getgenv) == "function" then
			local ok, env = pcall(getgenv)
			if ok and env and type(env.getfflag) == "function" then
				table.insert(getters, env.getfflag)
			end
		end
		for _, fn in ipairs(getters) do
			local ok, val = pcall(fn, name)
			if ok and val ~= nil then return val end
		end
		return nil
	end

	local function applyAllFlags()
		local applied, failed, total = 0, 0, 0
		-- re-scan in case executor loaded APIs after inject
		setFFlagFns = findSetFFlag()

		for name, value in pairs(activeFlags) do
			total += 1
			if trySetFFlag(name, value) then
				applied += 1
			else
				failed += 1
			end
		end

		-- also write ClientAppSettings snapshot for next launch (optional)
		pcall(function()
			if writefile and HttpService then
				writefile("Plexer_ClientAppSettings_" .. player.UserId .. ".json", HttpService:JSONEncode(activeFlags))
			end
		end)

		return applied, failed, total
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
	listFrame.Size = UDim2.new(1, -24, 1, -100)
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

	-- side popup for JSON import (draggable + resizable)
	local importPanel = Instance.new("Frame")
	importPanel.Name = "JsonImportPanel"
	importPanel.Size = UDim2.new(0, 420, 0, 480)
	importPanel.Position = UDim2.new(1, -440, 0.5, -240)
	importPanel.BackgroundColor3 = COLORS.Main
	importPanel.BorderSizePixel = 0
	importPanel.Visible = false
	importPanel.ZIndex = 50
	importPanel.Active = true
	importPanel.Parent = gui
	addCorner(importPanel, 12)
	addStroke(importPanel, COLORS.Stroke, 1)

	local importTitleBar = Instance.new("Frame")
	importTitleBar.Size = UDim2.new(1, 0, 0, 40)
	importTitleBar.BackgroundColor3 = COLORS.Tab
	importTitleBar.BorderSizePixel = 0
	importTitleBar.ZIndex = 51
	importTitleBar.Active = true
	importTitleBar.Parent = importPanel
	local itc = Instance.new("UICorner")
	itc.CornerRadius = UDim.new(0, 12)
	itc.Parent = importTitleBar

	local importTitle = Instance.new("TextLabel")
	importTitle.Size = UDim2.new(1, -50, 1, 0)
	importTitle.Position = UDim2.new(0, 14, 0, 0)
	importTitle.BackgroundTransparency = 1
	importTitle.Text = "Import FFlag JSON  (drag to move)"
	importTitle.TextColor3 = COLORS.Text
	importTitle.Font = Enum.Font.GothamBold
	importTitle.TextSize = 14
	importTitle.TextXAlignment = Enum.TextXAlignment.Left
	importTitle.ZIndex = 52
	importTitle.Parent = importTitleBar

	local importClose = Instance.new("TextButton")
	importClose.Size = UDim2.new(0, 28, 0, 28)
	importClose.Position = UDim2.new(1, -34, 0, 6)
	importClose.BackgroundColor3 = COLORS.Content
	importClose.BorderSizePixel = 0
	importClose.Text = "✕"
	importClose.TextColor3 = COLORS.TextDim
	importClose.Font = Enum.Font.Gotham
	importClose.TextSize = 14
	importClose.ZIndex = 52
	importClose.Parent = importTitleBar
	addCorner(importClose, 6)

	local importHint = Instance.new("TextLabel")
	importHint.Size = UDim2.new(1, -28, 0, 18)
	importHint.Position = UDim2.new(0, 14, 0, 46)
	importHint.BackgroundTransparency = 1
	importHint.Text = "Paste any size JSON — scroll supported"
	importHint.TextColor3 = COLORS.TextDim
	importHint.Font = Enum.Font.Gotham
	importHint.TextSize = 11
	importHint.TextXAlignment = Enum.TextXAlignment.Left
	importHint.ZIndex = 51
	importHint.Parent = importPanel

	local bigJsonBox = Instance.new("TextBox")
	bigJsonBox.Size = UDim2.new(1, -28, 1, -140)
	bigJsonBox.Position = UDim2.new(0, 14, 0, 70)
	bigJsonBox.BackgroundColor3 = COLORS.Tab
	bigJsonBox.BorderSizePixel = 0
	bigJsonBox.PlaceholderText = '{\n  "DFIntTaskSchedulerTargetFps": "999",\n  "FFlagDebugDisableTelemetryV2Event": "True"\n}'
	bigJsonBox.PlaceholderColor3 = COLORS.TextDim
	bigJsonBox.Text = ""
	bigJsonBox.TextColor3 = COLORS.Text
	bigJsonBox.Font = Enum.Font.Code
	bigJsonBox.TextSize = 13
	bigJsonBox.TextXAlignment = Enum.TextXAlignment.Left
	bigJsonBox.TextYAlignment = Enum.TextYAlignment.Top
	bigJsonBox.ClearTextOnFocus = false
	bigJsonBox.MultiLine = true
	bigJsonBox.TextWrapped = true
	bigJsonBox.ZIndex = 51
	bigJsonBox.Parent = importPanel
	addCorner(bigJsonBox, 8)

	local bigPad = Instance.new("UIPadding")
	bigPad.PaddingTop = UDim.new(0, 10)
	bigPad.PaddingBottom = UDim.new(0, 10)
	bigPad.PaddingLeft = UDim.new(0, 10)
	bigPad.PaddingRight = UDim.new(0, 10)
	bigPad.Parent = bigJsonBox

	-- resize handle
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Size = UDim2.new(0, 18, 0, 18)
	resizeHandle.Position = UDim2.new(1, -20, 1, -20)
	resizeHandle.BackgroundColor3 = COLORS.Stroke
	resizeHandle.BorderSizePixel = 0
	resizeHandle.Text = ""
	resizeHandle.ZIndex = 53
	resizeHandle.AutoButtonColor = false
	resizeHandle.Parent = importPanel
	addCorner(resizeHandle, 4)

	local panelImportBtn = Instance.new("TextButton")
	panelImportBtn.Size = UDim2.new(0.48, -10, 0, 34)
	panelImportBtn.Position = UDim2.new(0, 14, 1, -52)
	panelImportBtn.BackgroundColor3 = COLORS.Accent
	panelImportBtn.BorderSizePixel = 0
	panelImportBtn.Text = "Import + Apply"
	panelImportBtn.TextColor3 = Color3.new(1, 1, 1)
	panelImportBtn.Font = Enum.Font.GothamBold
	panelImportBtn.TextSize = 13
	panelImportBtn.ZIndex = 51
	panelImportBtn.Parent = importPanel
	addCorner(panelImportBtn, 8)

	local panelCancelBtn = Instance.new("TextButton")
	panelCancelBtn.Size = UDim2.new(0.48, -10, 0, 34)
	panelCancelBtn.Position = UDim2.new(0.52, 0, 1, -52)
	panelCancelBtn.BackgroundColor3 = COLORS.Tab
	panelCancelBtn.BorderSizePixel = 0
	panelCancelBtn.Text = "Cancel"
	panelCancelBtn.TextColor3 = COLORS.Text
	panelCancelBtn.Font = Enum.Font.GothamBold
	panelCancelBtn.TextSize = 13
	panelCancelBtn.ZIndex = 51
	panelCancelBtn.Parent = importPanel
	addCorner(panelCancelBtn, 8)

	-- drag panel
	local draggingPanel, panelDragStart, panelStartPos = false, nil, nil
	importTitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingPanel = true
			panelDragStart = input.Position
			panelStartPos = importPanel.Position
		end
	end)
	importTitleBar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingPanel = false
		end
	end)

	-- resize panel
	local resizingPanel, resizeStart, resizeStartSize = false, nil, nil
	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizingPanel = true
			resizeStart = input.Position
			resizeStartSize = importPanel.AbsoluteSize
		end
	end)
	resizeHandle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizingPanel = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if draggingPanel and panelDragStart and panelStartPos then
			local d = input.Position - panelDragStart
			importPanel.Position = UDim2.new(
				panelStartPos.X.Scale, panelStartPos.X.Offset + d.X,
				panelStartPos.Y.Scale, panelStartPos.Y.Offset + d.Y
			)
		elseif resizingPanel and resizeStart and resizeStartSize then
			local d = input.Position - resizeStart
			local nw = math.clamp(resizeStartSize.X + d.X, 300, 900)
			local nh = math.clamp(resizeStartSize.Y + d.Y, 280, 800)
			importPanel.Size = UDim2.new(0, nw, 0, nh)
		end
	end)

	local function closeImportPanel()
		importPanel.Visible = false
	end

	local function openImportPanel()
		importPanel.Visible = true
		task.defer(function()
			bigJsonBox:CaptureFocus()
		end)
	end

	importClose.MouseButton1Click:Connect(closeImportPanel)
	panelCancelBtn.MouseButton1Click:Connect(closeImportPanel)

	importBtn.MouseButton1Click:Connect(function()
		openImportPanel()
	end)

	panelImportBtn.MouseButton1Click:Connect(function()
		local raw = bigJsonBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
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
		-- apply immediately after import
		local applied, failed, total = applyAllFlags()
		bigJsonBox.Text = ""
		closeImportPanel()
		statusLbl.Text = "Imported " .. count .. " · Applied " .. applied .. "/" .. total
		statusLbl.TextColor3 = applied > 0 and Color3.fromRGB(80, 200, 120) or COLORS.Danger
	end)

	applyBtn.MouseButton1Click:Connect(function()
		local applied, failed, total = applyAllFlags()
		persistFlags()
		if total == 0 then
			statusLbl.Text = "No flags to apply"
			statusLbl.TextColor3 = COLORS.TextDim
		elseif applied == 0 then
			statusLbl.Text = "0 applied — executor may lack setfflag"
			statusLbl.TextColor3 = COLORS.Danger
		else
			statusLbl.Text = "Applied " .. applied .. "/" .. total
			statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
		end
		task.delay(3, function()
			if statusLbl and statusLbl.Parent then
				statusLbl.Text = ""
			end
		end)
	end)

	-- auto-apply saved flags after inject
	task.defer(function()
		task.wait(1)
		if destroyed then return end
		local applied, failed, total = applyAllFlags()
		if total > 0 and applied > 0 then
			statusLbl.Text = "Auto-loaded " .. applied .. " flags"
			statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
			task.delay(2.5, function()
				if statusLbl and statusLbl.Parent then statusLbl.Text = "" end
			end)
		end
	end)
end

-- ─── ScriptHub Tab (robloxscripts.com) ────────────────────
do
	local page = pages["ScriptHub"]
	local hubPage = 1
	local lastQuery = ""

	local function httpGet(url)
		local ok, body = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and body then return body end
		local req = (syn and syn.request) or http_request or request
		if req then
			local rok, res = pcall(function()
				return req({Url = url, Method = "GET"})
			end)
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

	local searchIcon = Instance.new("TextLabel")
	searchIcon.Size = UDim2.new(0, 28, 1, 0)
	searchIcon.Position = UDim2.new(0, 6, 0, 0)
	searchIcon.BackgroundTransparency = 1
	searchIcon.Text = "⌕"
	searchIcon.TextColor3 = COLORS.TextDim
	searchIcon.Font = Enum.Font.GothamBold
	searchIcon.TextSize = 18
	searchIcon.Parent = searchWrap

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -100, 1, 0)
	searchBox.Position = UDim2.new(0, 34, 0, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText = "Search scripts, games, hubs..."
	searchBox.PlaceholderColor3 = COLORS.TextDim
	searchBox.Text = ""
	searchBox.TextColor3 = COLORS.Text
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 14
	searchBox.ClearTextOnFocus = false
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.Parent = searchWrap

	local searchBtn = Instance.new("TextButton")
	searchBtn.Size = UDim2.new(0, 60, 0, 28)
	searchBtn.Position = UDim2.new(1, -66, 0.5, -14)
	searchBtn.BackgroundColor3 = COLORS.Accent
	searchBtn.BorderSizePixel = 0
	searchBtn.Text = "Go"
	searchBtn.TextColor3 = Color3.new(1, 1, 1)
	searchBtn.Font = Enum.Font.GothamBold
	searchBtn.TextSize = 13
	searchBtn.AutoButtonColor = true
	searchBtn.Parent = searchWrap
	addCorner(searchBtn, 6)

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(1, -24, 1, -96)
	listFrame.Position = UDim2.new(0, 12, 0, 58)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.ScrollBarImageColor3 = COLORS.Stroke
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = page

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
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
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Parent = page

	local function clearList()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
	end

	local function addScriptRow(scriptData, order)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 52)
		row.BackgroundColor3 = COLORS.Tab
		row.BorderSizePixel = 0
		row.LayoutOrder = order or 0
		row.Parent = listFrame
		addCorner(row, 6)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -90, 0, 20)
		title.Position = UDim2.new(0, 10, 0, 6)
		title.BackgroundTransparency = 1
		title.Text = scriptData.title or "Untitled"
		title.TextColor3 = COLORS.Text
		title.Font = Enum.Font.GothamMedium
		title.TextSize = 13
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Parent = row

		local gameName = (scriptData.game and scriptData.game.name) or (scriptData.isUniversal and "Universal") or "—"
		local access = scriptData.accessType or (scriptData.key and "key") or "free"
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -90, 0, 16)
		sub.Position = UDim2.new(0, 10, 0, 28)
		sub.BackgroundTransparency = 1
		sub.Text = gameName .. "  ·  " .. tostring(access)
		sub.TextColor3 = COLORS.TextDim
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 11
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		sub.Parent = row

		local runBtn = Instance.new("TextButton")
		runBtn.Size = UDim2.new(0, 70, 0, 28)
		runBtn.Position = UDim2.new(1, -80, 0.5, -14)
		runBtn.BackgroundColor3 = COLORS.Accent
		runBtn.BorderSizePixel = 0
		runBtn.Text = "Run"
		runBtn.TextColor3 = Color3.new(1, 1, 1)
		runBtn.Font = Enum.Font.GothamBold
		runBtn.TextSize = 12
		runBtn.AutoButtonColor = true
		runBtn.Parent = row
		addCorner(runBtn, 6)

		runBtn.MouseButton1Click:Connect(function()
			runBtn.Text = "..."
			task.spawn(function()
				local ok, err = pcall(function()
					if scriptData.script and type(scriptData.script) == "string" and scriptData.script ~= "" then
						local fn, cerr = loadstring(scriptData.script)
						if not fn then error(cerr or "loadstring failed") end
						fn()
					elseif scriptData.rawScriptUrl then
						local src = httpGet(scriptData.rawScriptUrl)
						if not src then error("HttpGet failed") end
						local fn, cerr = loadstring(src)
						if not fn then error(cerr or "loadstring failed") end
						fn()
					else
						error("no script source")
					end
				end)
				runBtn.Text = ok and "OK" or "Fail"
				if not ok then
					statusLbl.Text = "Run failed: " .. tostring(err):sub(1, 60)
					statusLbl.TextColor3 = COLORS.Danger
				else
					statusLbl.Text = "Executed: " .. (scriptData.title or "")
					statusLbl.TextColor3 = Color3.fromRGB(80, 200, 120)
				end
				task.delay(1.5, function()
					if runBtn and runBtn.Parent then runBtn.Text = "Run" end
				end)
			end)
		end)
	end

	local function fetchScripts(query, pageNum)
		statusLbl.Text = "Loading..."
		statusLbl.TextColor3 = COLORS.TextDim
		clearList()

		task.spawn(function()
			local q = query and query ~= "" and ("&q=" .. HttpService:UrlEncode(query)) or ""
			local url = "https://robloxscripts.com/api/v1/scripts?limit=20&page=" .. tostring(pageNum or 1) .. q .. "&sort=trending"
			local body = httpGet(url)
			if not body then
				statusLbl.Text = "Failed to reach robloxscripts.com"
				statusLbl.TextColor3 = COLORS.Danger
				return
			end
			local ok, data = pcall(function()
				return HttpService:JSONDecode(body)
			end)
			if not ok or type(data) ~= "table" then
				statusLbl.Text = "Bad API response"
				statusLbl.TextColor3 = COLORS.Danger
				return
			end
			local list = data.data or data.scripts or {}
			if type(list) ~= "table" or #list == 0 then
				-- might be dict not array
				local count = 0
				for _, item in pairs(list) do
					if type(item) == "table" and item.title then
						count += 1
						addScriptRow(item, count)
					end
				end
				if count == 0 then
					statusLbl.Text = "No scripts found"
					statusLbl.TextColor3 = COLORS.TextDim
					return
				end
				statusLbl.Text = count .. " scripts · robloxscripts.com"
				statusLbl.TextColor3 = COLORS.TextDim
				return
			end
			for i, item in ipairs(list) do
				addScriptRow(item, i)
			end
			statusLbl.Text = #list .. " scripts · robloxscripts.com"
			statusLbl.TextColor3 = COLORS.TextDim
		end)
	end

	searchBtn.MouseButton1Click:Connect(function()
		lastQuery = searchBox.Text
		hubPage = 1
		fetchScripts(lastQuery, hubPage)
	end)

	searchBox.FocusLost:Connect(function(enter)
		if enter then
			lastQuery = searchBox.Text
			hubPage = 1
			fetchScripts(lastQuery, hubPage)
		end
	end)

	-- load trending on first open-ish
	task.defer(function()
		fetchScripts("", 1)
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

	-- Theme presets
	local colorTitle = Instance.new("TextLabel")
	colorTitle.Size = UDim2.new(1, -24, 0, 18)
	colorTitle.Position = UDim2.new(0, 12, 0, 110)
	colorTitle.BackgroundTransparency = 1
	colorTitle.Text = "Theme"
	colorTitle.TextColor3 = COLORS.Text
	colorTitle.Font = Enum.Font.GothamMedium
	colorTitle.TextSize = 14
	colorTitle.TextXAlignment = Enum.TextXAlignment.Left
	colorTitle.Parent = page

	local THEMES = {
		{
			name = "Black",
			accent = {180, 180, 180},
			main = {8, 8, 8},
			tab = {16, 16, 16},
			content = {12, 12, 12},
			gradient = false,
		},
		{
			name = "Purple",
			accent = {160, 80, 255},
			main = {10, 8, 16},
			tab = {20, 14, 28},
			content = {14, 10, 20},
			gradient = false,
		},
		{
			name = "Blue",
			accent = {80, 140, 255},
			main = {8, 10, 16},
			tab = {14, 18, 28},
			content = {10, 14, 22},
			gradient = false,
		},
		{
			name = "Glow",
			accent = {140, 100, 255},
			main = {10, 8, 18},
			tab = {18, 12, 30},
			content = {12, 10, 22},
			gradient = true,
		},
	}

	local titleGradient = title:FindFirstChildOfClass("UIGradient")
	local function applyTheme(theme)
		local function rgb(t)
			return Color3.fromRGB(t[1], t[2], t[3])
		end
		COLORS.Accent = rgb(theme.accent)
		COLORS.Main = rgb(theme.main)
		COLORS.Tab = rgb(theme.tab)
		COLORS.Content = rgb(theme.content)
		COLORS.TabActive = Color3.fromRGB(
			math.min(255, theme.tab[1] + 20),
			math.min(255, theme.tab[2] + 20),
			math.min(255, theme.tab[3] + 20)
		)

		main.BackgroundColor3 = COLORS.Main
		titleBar.BackgroundColor3 = COLORS.Tab
		content.BackgroundColor3 = COLORS.Content
		sliderFill.BackgroundColor3 = COLORS.Accent
		closeBtn.BackgroundColor3 = COLORS.Content

		if activeTab and tabButtons[activeTab] then
			tabButtons[activeTab].BackgroundColor3 = COLORS.TabActive
		end

		if theme.gradient then
			if not titleGradient then
				titleGradient = Instance.new("UIGradient")
				titleGradient.Parent = title
			end
			titleGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 100, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 180, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 220)),
			})
			title.TextColor3 = Color3.new(1, 1, 1)
			-- animate gradient
			task.spawn(function()
				local t0 = tick()
				while titleGradient and titleGradient.Parent and config.theme == "Glow" do
					local o = ((tick() - t0) * 0.35) % 1
					titleGradient.Offset = Vector2.new(o * 2 - 1, 0)
					task.wait(0.03)
				end
			end)
		else
			if titleGradient then
				titleGradient:Destroy()
				titleGradient = nil
			end
			title.TextColor3 = COLORS.Text
		end

		config.theme = theme.name
		if not config.colors then config.colors = {} end
		config.colors.Accent = theme.accent
		config.colors.Main = theme.main
		config.colors.Tab = theme.tab
		config.colors.Content = theme.content
		saveConfig()
	end

	for i, theme in ipairs(THEMES) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.25, -6, 0, 32)
		btn.Position = UDim2.new((i - 1) * 0.25, 12 + (i - 1) * 2, 0, 134)
		btn.BackgroundColor3 = COLORS.Tab
		btn.BorderSizePixel = 0
		btn.Text = theme.name
		btn.TextColor3 = Color3.fromRGB(theme.accent[1], theme.accent[2], theme.accent[3])
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.AutoButtonColor = true
		btn.Parent = page
		addCorner(btn, 6)
		btn.MouseButton1Click:Connect(function()
			applyTheme(theme)
		end)
	end

	-- apply saved theme name on load
	if config.theme then
		for _, theme in ipairs(THEMES) do
			if theme.name == config.theme then
				task.defer(function()
					applyTheme(theme)
				end)
				break
			end
		end
	end

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

	-- Reset key / HWID
	local resetRow = makeRow(252, "Reset key / HWID")
	local resetKeyBtn = Instance.new("TextButton")
	resetKeyBtn.Size = UDim2.new(0, 90, 0, 28)
	resetKeyBtn.Position = UDim2.new(1, -102, 0.5, -14)
	resetKeyBtn.BackgroundColor3 = COLORS.Content
	resetKeyBtn.BorderSizePixel = 0
	resetKeyBtn.Text = "Reset"
	resetKeyBtn.TextColor3 = COLORS.Danger
	resetKeyBtn.Font = Enum.Font.GothamBold
	resetKeyBtn.TextSize = 14
	resetKeyBtn.AutoButtonColor = false
	resetKeyBtn.Parent = resetRow
	addCorner(resetKeyBtn, 6)
	addStroke(resetKeyBtn, COLORS.Stroke, 1)

	local resetHint = Instance.new("TextLabel")
	resetHint.Size = UDim2.new(1, -24, 0, 32)
	resetHint.Position = UDim2.new(0, 12, 0, 298)
	resetHint.BackgroundTransparency = 1
	resetHint.Text = "Clears key + hardware lock. Re-enter key after."
	resetHint.TextColor3 = COLORS.TextDim
	resetHint.Font = Enum.Font.Gotham
	resetHint.TextSize = 12
	resetHint.TextXAlignment = Enum.TextXAlignment.Left
	resetHint.TextWrapped = true
	resetHint.Parent = page

	local boundInfo = Instance.new("TextLabel")
	boundInfo.Size = UDim2.new(1, -24, 0, 18)
	boundInfo.Position = UDim2.new(0, 12, 0, 330)
	boundInfo.BackgroundTransparency = 1
	boundInfo.Text = "Bound UserId: " .. tostring(config.boundUserId or 0)
		.. "  ·  You: " .. tostring(player.UserId)
	boundInfo.TextColor3 = COLORS.TextDim
	boundInfo.Font = Enum.Font.Gotham
	boundInfo.TextSize = 11
	boundInfo.TextXAlignment = Enum.TextXAlignment.Left
	boundInfo.Parent = page

	resetKeyBtn.MouseButton1Click:Connect(function()
		resetKeyBinding()
		resetKeyBtn.Text = "Cleared"
		boundInfo.Text = "Bound UserId: 0  ·  You: " .. tostring(player.UserId)
		task.delay(1.2, function()
			if resetKeyBtn and resetKeyBtn.Parent then
				resetKeyBtn.Text = "Reset"
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

-- ─── Key System + Startup ─────────────────────────────────
local function startLoader()
	loader.Visible = true
	loader.Size = UDim2.new(0, 280, 0, 100)
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
end

local function showKeyUI()
	local keyFrame = Instance.new("Frame")
	keyFrame.Name = "KeySystem"
	keyFrame.Size = UDim2.new(0, 340, 0, 180)
	keyFrame.Position = UDim2.new(0.5, -170, 0.5, -90)
	keyFrame.BackgroundColor3 = COLORS.Main
	keyFrame.BorderSizePixel = 0
	keyFrame.Parent = gui
	addCorner(keyFrame, 12)
	addStroke(keyFrame, COLORS.Stroke, 1)

	local keyTitle = Instance.new("TextLabel")
	keyTitle.Size = UDim2.new(1, 0, 0, 28)
	keyTitle.Position = UDim2.new(0, 0, 0, 14)
	keyTitle.BackgroundTransparency = 1
	keyTitle.Text = "Plexer Key System"
	keyTitle.TextColor3 = COLORS.Text
	keyTitle.Font = Enum.Font.GothamBold
	keyTitle.TextSize = 16
	keyTitle.Parent = keyFrame

	local keySub = Instance.new("TextLabel")
	keySub.Size = UDim2.new(1, -24, 0, 18)
	keySub.Position = UDim2.new(0, 12, 0, 44)
	keySub.BackgroundTransparency = 1
	keySub.Text = keysReady and "Enter your key to continue" or "Fetching keys..."
	keySub.TextColor3 = COLORS.TextDim
	keySub.Font = Enum.Font.Gotham
	keySub.TextSize = 12
	keySub.Parent = keyFrame

	local keyBox = Instance.new("TextBox")
	keyBox.Size = UDim2.new(1, -24, 0, 34)
	keyBox.Position = UDim2.new(0, 12, 0, 70)
	keyBox.BackgroundColor3 = COLORS.Tab
	keyBox.BorderSizePixel = 0
	keyBox.PlaceholderText = "Paste key..."
	keyBox.PlaceholderColor3 = COLORS.TextDim
	keyBox.Text = ""
	keyBox.TextColor3 = COLORS.Text
	keyBox.Font = Enum.Font.Code
	keyBox.TextSize = 12
	keyBox.ClearTextOnFocus = false
	keyBox.Parent = keyFrame
	addCorner(keyBox, 8)

	local keyErr = Instance.new("TextLabel")
	keyErr.Size = UDim2.new(1, -24, 0, 16)
	keyErr.Position = UDim2.new(0, 12, 0, 108)
	keyErr.BackgroundTransparency = 1
	keyErr.Text = keysFetchError or ""
	keyErr.TextColor3 = COLORS.Danger
	keyErr.Font = Enum.Font.Gotham
	keyErr.TextSize = 11
	keyErr.Parent = keyFrame

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(1, -24, 0, 34)
	keyBtn.Position = UDim2.new(0, 12, 0, 128)
	keyBtn.BackgroundColor3 = COLORS.Accent
	keyBtn.BorderSizePixel = 0
	keyBtn.Text = "Unlock"
	keyBtn.TextColor3 = Color3.new(1, 1, 1)
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.TextSize = 14
	keyBtn.AutoButtonColor = true
	keyBtn.Parent = keyFrame
	addCorner(keyBtn, 8)

	local function tryUnlock()
		if not keysReady then
			keyErr.Text = keysFetchError or "Still loading keys..."
			return
		end
		local k = trimKey(keyBox.Text)
		if not isKeyValid(k) then
			keyErr.Text = "Invalid key"
			return
		end

		-- if this key was already claimed by another userId on this install, block
		local bound = tonumber(config.boundUserId) or 0
		local prevKey = trimKey(config.savedKey)
		if bound ~= 0 and bound ~= player.UserId and prevKey == k then
			keyErr.Text = "Key bound to another UserId — reset needed"
			return
		end

		claimKey(k)
		keySub.Text = "Linked to UserId " .. tostring(player.UserId)
		keyFrame:Destroy()
		startLoader()
	end

	keyBtn.MouseButton1Click:Connect(tryUnlock)
	keyBox.FocusLost:Connect(function(enter)
		if enter then tryUnlock() end
	end)
end

-- fetch keys.json then gate
task.spawn(function()
	fetchRemoteKeys()

	if isSessionAuthorized() then
		startLoader()
		return
	end

	-- key missing / wrong account / wrong HWID
	showKeyUI()
end)
