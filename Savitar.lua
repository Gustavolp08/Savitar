--[[
    ZenWare / FemWare — Criminality
    UI: Rayfield Gen2 (https://sirius.menu/gen2)

    O que mudou em relação à versão antiga:
      * Rayfield Gen2 (props minúsculas: name, value, callback, range, options...)
      * nenhuma chamada de elemento pode matar o script (todas em pcall + warn)
      * caminhos do Criminality checados antes de indexar (Map, Values, Debris...)
      * loops com task.wait() de verdade, nenhum while true "solto"
      * Drawing é opcional: sem a API, o tracer só avisa e não quebra o resto
      * física (strafe/bang/follow) protegida e resetada ao desligar/morrer
      * "game:service" (inexistente) trocado por GetService
--]]

-- ====================================================================
-- CONFIG
-- ====================================================================
local CFG = {
	LOADING_SECONDS = 5,           -- tempo da tela de loading
	KEEP_LOADING_WHEN_DONE = true, -- false = some assim que a janela abre
	LOADING_TEXT = "ZENWARE REMAKE",
	AUTHOR = "gustaaav0",
	DISCORD = "discord.gg/BFrytpMKWF",
	WINDOW_NAME = "ZenWare | Criminality",
	WINDOW_SUBTITLE = "",
	THEME = "rose",
}
CFG.WINDOW_SUBTITLE = "Remake by " .. CFG.AUTHOR

-- ====================================================================
-- SERVIÇOS
-- ====================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ====================================================================
-- UNLOAD (conexoes rastreadas + limpeza registrada)
-- ====================================================================
local unloaded = false
local connections = {}
local Cleanup = {}

local function connect(signal, fn)
	local ok, connection = pcall(function()
		return signal:Connect(fn)
	end)
	if ok and connection then
		table.insert(connections, connection)
	end
	return ok and connection or nil
end

local function addCleanup(fn)
	table.insert(Cleanup, fn)
end

local unloadScript

-- ====================================================================
-- TELA DE LOADING
-- ====================================================================
local loading = Instance.new("ScreenGui")
loading.Name = "ZenWareLoading"
loading.ResetOnSpawn = false
loading.IgnoreGuiInset = true
loading.DisplayOrder = 9999
loading.Parent = PlayerGui

local loadingLabel = Instance.new("TextLabel")
loadingLabel.Name = "Title"
loadingLabel.Text = CFG.LOADING_TEXT
loadingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
loadingLabel.TextSize = 36
loadingLabel.TextTransparency = 1
loadingLabel.Font = Enum.Font.SourceSansBold
loadingLabel.BackgroundTransparency = 1
loadingLabel.Size = UDim2.fromOffset(520, 60)
loadingLabel.Position = UDim2.new(0.5, -260, 0.5, -46)
loadingLabel.Parent = loading

local loadingBy = Instance.new("TextLabel")
loadingBy.Name = "By"
loadingBy.Text = "by " .. CFG.AUTHOR
loadingBy.TextColor3 = Color3.fromRGB(170, 170, 185)
loadingBy.TextSize = 16
loadingBy.TextTransparency = 1
loadingBy.Font = Enum.Font.Gotham
loadingBy.BackgroundTransparency = 1
loadingBy.Size = UDim2.fromOffset(520, 24)
loadingBy.Position = UDim2.new(0.5, -260, 0.5, 8)
loadingBy.Parent = loading

local loadingDiscord = Instance.new("TextLabel")
loadingDiscord.Name = "Discord"
loadingDiscord.Text = CFG.DISCORD
loadingDiscord.TextColor3 = Color3.fromRGB(150, 162, 255)
loadingDiscord.TextSize = 14
loadingDiscord.TextTransparency = 1
loadingDiscord.Font = Enum.Font.Code
loadingDiscord.BackgroundTransparency = 1
loadingDiscord.Size = UDim2.fromOffset(520, 22)
loadingDiscord.Position = UDim2.new(0.5, -260, 1, -58)
loadingDiscord.Parent = loading

local loadingCloseTimer = os.clock()
local function closeLoading()
	if not loading.Parent then
		return
	end
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, element in ipairs(loading:GetDescendants()) do
		if element:IsA("TextLabel") then
			pcall(function()
				TweenService:Create(element, info, { TextTransparency = 1 }):Play()
			end)
		end
	end
	task.wait(0.42)
	loading:Destroy()
end

task.spawn(function()
	TweenService:Create(
		loadingLabel,
		TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ TextTransparency = 0, TextSize = 42 }
	):Play()
	task.wait(0.35)
	TweenService:Create(loadingBy, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	TweenService:Create(loadingDiscord, TweenInfo.new(0.5), { TextTransparency = 0.15 }):Play()
end)

-- ====================================================================
-- RAYFIELD GEN2
-- ====================================================================
local Rayfield
do
	local ok, result = pcall(function()
		local source = game:HttpGet("https://sirius.menu/gen2")
		if type(source) ~= "string" or #source < 500 then
			error("payload invalid: " .. tostring(type(source)) .. " " .. tostring(#source) .. " bytes")
		end
		local chunk, compileError = loadstring(source, "@rayfield-gen2")
		if not chunk then
			error("loadstring: " .. tostring(compileError))
		end
		return chunk()
	end)
	if not ok or type(result) ~= "table" then
		warn("[ZenWare] Rayfield Gen2 fail: " .. tostring(result))
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "ZenWare",
				Text = "Interface not loaded: " .. tostring(result),
				Duration = 10,
			})
		end)
		loading:Destroy()
		return
	end
	Rayfield = result
end

-- ====================================================================
-- HELPERS DE UI (um erro em um elemento não derruba o resto)
-- ====================================================================
local function warnUi(what, err)
	warn("[ZenWare] UI " .. what .. ": " .. tostring(err))
end

local UI = {}
function UI.section(parent, text)
	local ok, handle = pcall(parent.CreateSection, parent, { name = text })
	if not ok then warnUi("section " .. text, handle) end
	return ok and handle or nil
end
function UI.toggle(parent, props)
	local ok, handle = pcall(parent.CreateToggle, parent, props)
	if not ok then warnUi("toggle " .. tostring(props.name), handle) end
	return ok and handle or nil
end
function UI.slider(parent, props)
	local ok, handle = pcall(parent.CreateSlider, parent, props)
	if not ok then warnUi("slider " .. tostring(props.name), handle) end
	return ok and handle or nil
end
function UI.dropdown(parent, props)
	local ok, handle = pcall(parent.CreateDropdown, parent, props)
	if not ok then warnUi("dropdown " .. tostring(props.name), handle) end
	return ok and handle or nil
end
function UI.button(parent, props)
	local ok, handle = pcall(parent.CreateButton, parent, props)
	if not ok then warnUi("button " .. tostring(props.name), handle) end
	return ok and handle or nil
end
function UI.input(parent, props)
	local ok, handle = pcall(parent.CreateInput, parent, props)
	if not ok then warnUi("input " .. tostring(props.name), handle) end
	return ok and handle or nil
end
function UI.color(parent, props)
	local ok, handle = pcall(parent.CreateColorPicker, parent, props)
	if not ok then warnUi("color " .. tostring(props.name), handle) end
	return ok and handle or nil
end
function UI.text(parent, props)
	local ok, handle = pcall(parent.CreateText, parent, props)
	if not ok then warnUi("text " .. tostring(props.name or props.text), handle) end
	return ok and handle or nil
end

local function copyToClipboard(text)
	if type(setclipboard) == "function" then
		return pcall(setclipboard, text)
	elseif syn and type(syn.set_clipboard) == "function" then
		return pcall(syn.set_clipboard, text)
	elseif type(toclipboard) == "function" then
		return pcall(toclipboard, text)
	end
	return false
end

-- ====================================================================
-- ESTADO
-- ====================================================================
local State = {
	-- aimbot
	aimbot = false,
	aimPart = "Head",
	aimRadius = 160,
	predictMovement = false,
	predictionVelocity = 16,
	ignoredUser = "",
	teamCheck = false,
	notifyTarget = false,
	aimKey = "Right Mouse (hold)",
	aimToggle = false,
	aimHeld = false,
	smoothing = 100,
	wallCheck = true,
	targetPriority = "Crosshair",
	verticalOffset = 0,
	maxAimDistance = 1000,
	fovCircle = false,
	targetMarker = false,
	-- visuals
	espPlayers = false,
	showHealth = false,
	showDistance = false,
	boxEsp = false,
	boxWidth = 2.4,
	skeleton = false,
	rgb = false,
	rgbSpeed = 1,
	fakeDick = false,
	fakeDickSize = 2,
	espColor = Color3.fromRGB(255, 255, 255),
	nameColor = Color3.fromRGB(255, 255, 255),
	boxColor = Color3.fromRGB(120, 200, 255),
	dickColor = Color3.fromRGB(255, 105, 180),
	textSize = 14,
	highlight = false,
	fillTransparency = 0.5,
	tracers = false,
	toolEsp = false,
	safeEsp = false,
	crateEsp = false,
	dealerEsp = false,
	-- movement
	speed = false,
	speedValue = 16,
	strafe = false,
	strafeRadius = 4,
	strafeSpeed = 5,
	follow = false,
	followDistance = 3,
	bang = false,
	bangSpeed = 1,
	spin = false,
	spinSpeed = 30,
	noFall = false,
}

local Window -- criada mais abaixo (a notificação usa antes)

local function notify(title, content, duration)
	if not Window then
		pcall(function()
			StarterGui:SetCore("SendNotification", { Title = title, Text = content, Duration = duration or 4 })
		end)
		return
	end
	pcall(function()
		Window:Notify({ title = title, content = content, duration = duration or 4 })
	end)
end

-- cores: cada sistema tem a sua; o RGB sobrescreve todas com um matiz diferente
local function rgbOr(fixed, offset)
	if not State.rgb then
		return fixed
	end
	local hue = ((os.clock() * (State.rgbSpeed or 1) * 0.12) + (offset or 0)) % 1
	return Color3.fromHSV(hue, 0.9, 1)
end

-- cor base: skeleton, tracers, highlight, FOV e marker
local function accentColor()
	return rgbOr(State.espColor, 0)
end

local function nameColor()
	return rgbOr(State.nameColor, 0.06)
end

local function boxColor()
	return rgbOr(State.boxColor, 0.12)
end

local function dickColor()
	return rgbOr(State.dickColor, 0.18)
end

local function getChar(plr)
	plr = plr or LocalPlayer
	local char = plr.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end
	return char, hum, root
end

local function healthOf(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health or 0
end

local function nearestPlayer(maxDistance, requireHealth)
	local char, _, myRoot = getChar(LocalPlayer)
	if not myRoot then
		return nil
	end
	local best, bestDistance = nil, maxDistance or math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local _, hum, root = getChar(plr)
			if root and (not requireHealth or (hum and hum.Health >= 15)) then
				local distance = (myRoot.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = plr, distance
				end
			end
		end
	end
	return best
end

-- ====================================================================
-- JANELA
-- ====================================================================
local okWindow, windowResult = pcall(Rayfield.CreateWindow, Rayfield, {
	name = CFG.WINDOW_NAME,
	subtitle = CFG.WINDOW_SUBTITLE,
	sidebarLayout = true,
	theme = CFG.THEME,
	configuration = { autoSave = false, autoLoad = false, fileName = "ZenWare" },
})
if not okWindow or not windowResult then
	warn("[ZenWare] CreateWindow fail: " .. tostring(windowResult))
	notify("ZenWare", "CreateWindow fail: " .. tostring(windowResult), 10)
	loading:Destroy()
	return
end
Window = windowResult

local function newTab(name)
	local ok, tab = pcall(Window.CreateTab, Window, { name = name })
	if not ok then
		warnUi("tab " .. name, tab)
		return nil
	end
	return tab
end

-- ====================================================================
-- ABA: AIMBOT
-- ====================================================================
local aimTab = newTab("ZenWare Main")

if aimTab then
	UI.section(aimTab, "ZenWare Aimbot")

	local Aim = { target = nil, marker = nil }

	local function aimPartOf(char)
		return char:FindFirstChild(State.aimPart) or char:FindFirstChild("Head")
	end

	local function canSee(origin, part, char)
		if not State.wallCheck then
			return true
		end
		local delta = part.Position - origin
		if delta.Magnitude < 0.05 then
			return true
		end
		local ignore = {}
		if LocalPlayer.Character then
			table.insert(ignore, LocalPlayer.Character)
		end
		table.insert(ignore, char)
		local ok, hitPos = pcall(function()
			local _, pos = workspace:FindPartOnRayWithIgnoreList(Ray.new(origin, delta.Unit * delta.Magnitude), ignore)
			return pos
		end)
		if not ok or not hitPos then
			return true
		end
		return (hitPos - part.Position).Magnitude <= 3
	end

	local function pickTarget()
		local cam = workspace.CurrentCamera
		if not cam then
			return nil
		end
		local origin = cam.CFrame.Position
		local viewport = cam.ViewportSize
		local centerX, centerY = viewport.X / 2, viewport.Y / 2
		local best, bestScore = nil, math.huge

		for _, plr in ipairs(Players:GetPlayers()) do
			local allowed = plr ~= LocalPlayer
				and string.lower(plr.Name) ~= string.lower(State.ignoredUser or "")
				and ((not State.teamCheck) or plr.Team ~= LocalPlayer.Team)
			local char = plr.Character
			if allowed and char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local part = aimPartOf(char)
				if hum and hum.Health > 0 and part then
					local delta = part.Position - origin
					local distance = delta.Magnitude
					if distance > 1 and distance <= State.maxAimDistance then
						local screen, onScreen = cam:WorldToViewportPoint(part.Position)
						local pixelDist = math.huge
						if onScreen then
							local dx, dy = screen.X - centerX, screen.Y - centerY
							pixelDist = math.sqrt(dx * dx + dy * dy)
						end
						if pixelDist <= State.aimRadius and canSee(origin, part, char) then
							local score = pixelDist
							if State.targetPriority == "Distance" then
								score = distance
							elseif State.targetPriority == "Health" then
								score = healthOf(plr)
							end
							if score < bestScore then
								best, bestScore = plr, score
							end
						end
					end
				end
			end
		end
		return best
	end

	local function clearMarker()
		if Aim.marker then
			pcall(function()
				Aim.marker:Destroy()
			end)
			Aim.marker = nil
		end
	end

	local function updateMarker(plr)
		if not State.targetMarker or not plr then
			clearMarker()
			return
		end
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		if not head then
			clearMarker()
			return
		end
		if not Aim.marker or Aim.marker.Parent ~= head then
			clearMarker()
			local gui = Instance.new("BillboardGui")
			gui.Name = "ZenAimMarker"
			gui.Adornee = head
			gui.AlwaysOnTop = true
			gui.Size = UDim2.new(0, 26, 0, 26)
			gui.StudsOffset = Vector3.new(0, 2.4, 0)
			local label = Instance.new("TextLabel")
			label.Name = "Plus"
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 1, 0)
			label.Font = Enum.Font.SourceSansBold
			label.TextSize = 24
			label.Text = "+"
			label.TextStrokeTransparency = 0
			label.Parent = gui
			gui.Parent = head
			Aim.marker = gui
		end
		local label = Aim.marker:FindFirstChild("Plus")
		if label then
			label.TextColor3 = accentColor()
		end
	end

	local function setTarget(plr)
		if plr == Aim.target then
			if plr then
				updateMarker(plr)
			end
			return
		end
		Aim.target = plr
		clearMarker()
		if plr then
			updateMarker(plr)
			if State.notifyTarget then
				notify("ZenWare", "Aimlock: " .. plr.Name, 3)
			end
		end
	end

	-- FOV circle (Drawing opcional) - segue o cursor
	local fovCircle
	local function mouseScreenPosition()
		local okMouse, mouse = pcall(function()
			return LocalPlayer:GetMouse()
		end)
		if okMouse and mouse then
			local okPos, x, y = pcall(function()
				return mouse.X, mouse.Y
			end)
			if okPos and type(x) == "number" and type(y) == "number" then
				return Vector2.new(x, y)
			end
		end
		local okLocation, location = pcall(function()
			return UserInputService:GetMouseLocation()
		end)
		if okLocation and location then
			return Vector2.new(location.X, location.Y)
		end
		return nil
	end

	local function updateFovCircle()
		if not Drawing then
			if State.fovCircle then
				State.fovCircle = false
				notify("ZenWare", "your executor is bad, change now!!!!: FOV circle off.", 6)
			end
			return
		end
		if not State.fovCircle and not fovCircle then
			return
		end
		if not fovCircle then
			local ok, circle = pcall(function()
				return Drawing.new("Circle")
			end)
			if not ok or not circle then
				State.fovCircle = false
				return
			end
			circle.Thickness = 1.5
			circle.Filled = false
			circle.Transparency = 1
			fovCircle = circle
		end
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local position = mouseScreenPosition()
		if not position then
			position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
		end
		fovCircle.Position = position
		fovCircle.Radius = State.aimRadius
		fovCircle.Color = accentColor()
		fovCircle.Visible = State.fovCircle and State.aimbot
	end

	addCleanup(function()
		clearMarker()
		if fovCircle then
			pcall(function()
				fovCircle.Visible = false
				fovCircle:Remove()
			end)
			fovCircle = nil
		end
	end)

	UI.toggle(aimTab, {
		name = "Aimlock",
		value = false,
		flag = "Aimlock",
		callback = function(on)
			State.aimbot = on
			if not on then
				State.aimHeld = false
				setTarget(nil)
			end
		end,
	})

	UI.toggle(aimTab, {
		name = "Predict movement",
		value = false,
		flag = "PredictMovement",
		callback = function(on)
			State.predictMovement = on
		end,
	})

	UI.toggle(aimTab, {
		name = "Notify aimlock target",
		value = false,
		flag = "NotifyTarget",
		callback = function(on)
			State.notifyTarget = on
		end,
	})

	UI.toggle(aimTab, {
		name = "Team check",
		value = false,
		flag = "TeamCheck",
		callback = function(on)
			State.teamCheck = on
		end,
	})

	UI.slider(aimTab, {
		name = "Prediction velocity",
		range = { 1, 50 },
		increment = 1,
		value = 16,
		flag = "PredictionVelocity",
		callback = function(value)
			State.predictionVelocity = math.max(value, 1)
		end,
	})

	UI.slider(aimTab, {
		name = "Aim radius (FOV)",
		range = { 10, 600 },
		increment = 5,
		value = 160,
		suffix = "px",
		flag = "AimRadius",
		description = "Radius in pixels around the crosshair. Also the FOV circle radius.",
		callback = function(value)
			State.aimRadius = value
		end,
	})

	UI.dropdown(aimTab, {
		name = "Aim part",
		options = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso" },
		value = "Head",
		flag = "AimPart",
		callback = function(option)
			State.aimPart = option
		end,
	})

	UI.input(aimTab, {
		name = "Ignored user",
		value = "",
		placeholder = "Username to ignore",
		flag = "IgnoredUser",
		callback = function(text)
			State.ignoredUser = text
		end,
	})

	UI.toggle(aimTab, {
		name = "Toggle aim (no need to hold)",
		value = false,
		flag = "AimToggle",
		description = "Press the key once to turn it on, again to turn it off.",
		callback = function(on)
			State.aimToggle = on
			if not on then
				State.aimHeld = false
				setTarget(nil)
			end
		end,
	})

	UI.dropdown(aimTab, {
		name = "Aim key",
		options = { "Right Mouse (hold)", "Left Mouse (hold)", "E", "Q", "Left Shift", "Always" },
		value = "Right Mouse (hold)",
		flag = "AimKey",
		callback = function(option)
			State.aimKey = option
			State.aimHeld = false
			setTarget(nil)
		end,
	})

	UI.dropdown(aimTab, {
		name = "Target priority",
		options = { "Crosshair", "Distance", "Health" },
		value = "Crosshair",
		flag = "TargetPriority",
		callback = function(option)
			State.targetPriority = option
		end,
	})

	UI.toggle(aimTab, {
		name = "Wall check (no aiming through walls)",
		value = true,
		flag = "AimWallCheck",
		callback = function(on)
			State.wallCheck = on
		end,
	})

	UI.slider(aimTab, {
		name = "Aim smoothing",
		range = { 1, 100 },
		increment = 1,
		value = 100,
		suffix = "%",
		flag = "AimSmoothing",
		description = "100% = instant. Lower values make the aim glide.",
		callback = function(value)
			State.smoothing = value
		end,
	})

	UI.slider(aimTab, {
		name = "Aim height offset",
		range = { -5, 5 },
		increment = 0.5,
		value = 0,
		flag = "AimVerticalOffset",
		description = "Moves the aim point up/down (higher headshots, etc).",
		callback = function(value)
			State.verticalOffset = value
		end,
	})

	UI.slider(aimTab, {
		name = "Max aim distance",
		range = { 50, 2000 },
		increment = 25,
		value = 1000,
		flag = "AimMaxDistance",
		callback = function(value)
			State.maxAimDistance = value
		end,
	})

	UI.toggle(aimTab, {
		name = "FOV circle",
		value = false,
		flag = "FovCircle",
		callback = function(on)
			State.fovCircle = on
			updateFovCircle()
		end,
	})

	UI.toggle(aimTab, {
		name = "Target marker (+)",
		value = false,
		flag = "TargetMarker",
		callback = function(on)
			State.targetMarker = on
			updateMarker(Aim.target)
		end,
	})

	local aimKeys = {
		["Right Mouse (hold)"] = { inputType = Enum.UserInputType.MouseButton2 },
		["Left Mouse (hold)"] = { inputType = Enum.UserInputType.MouseButton1 },
		["E"] = { key = Enum.KeyCode.E },
		["Q"] = { key = Enum.KeyCode.Q },
		["Left Shift"] = { key = Enum.KeyCode.LeftShift },
	}

	local function isAimInput(input)
		local mapped = aimKeys[State.aimKey]
		if not mapped then
			return false
		end
		if mapped.inputType and input.UserInputType == mapped.inputType then
			return true
		end
		if mapped.key and input.KeyCode == mapped.key then
			return true
		end
		return false
	end

	connect(UserInputService.InputBegan, function(input, processed)
		if processed or not State.aimbot then
			return
		end
		if not isAimInput(input) then
			return
		end
		local focused = nil
		pcall(function()
			focused = UserInputService:GetFocusedTextBox()
		end)
		if focused then
			return
		end
		if State.aimToggle then
			State.aimHeld = not State.aimHeld
		else
			State.aimHeld = true
		end
		if State.aimHeld then
			setTarget(pickTarget())
		else
			setTarget(nil)
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if State.aimToggle or not isAimInput(input) then
			return
		end
		State.aimHeld = false
		setTarget(nil)
	end)

	connect(RunService.RenderStepped, function()
		if unloaded then
			return
		end
		pcall(updateFovCircle)

		if not State.aimbot then
			if Aim.target then
				setTarget(nil)
			end
			return
		end

		local aiming = State.aimHeld or State.aimKey == "Always"
		if not aiming then
			if Aim.target then
				setTarget(nil)
			end
			return
		end

		local ok = pcall(function()
			local target = Aim.target
			local char = target and target.Character
			local part = char and aimPartOf(char)
			if not part then
				setTarget(pickTarget())
				target = Aim.target
				char = target and target.Character
				part = char and aimPartOf(char)
				if not part then
					return
				end
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				setTarget(nil)
				return
			end
			local root = char:FindFirstChild("HumanoidRootPart")
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local origin = cam.CFrame.Position
			local aimAt = part.Position + Vector3.new(0, State.verticalOffset, 0)
			if State.predictMovement and root then
				aimAt = aimAt + root.AssemblyLinearVelocity / math.max(State.predictionVelocity, 1)
			end
			if (aimAt - origin).Magnitude < 0.05 then
				return
			end
			local goal = CFrame.new(origin, aimAt)
			local alpha = math.clamp(State.smoothing / 100, 0.05, 1)
			if alpha >= 1 then
				cam.CFrame = goal
			else
				cam.CFrame = cam.CFrame:Lerp(goal, alpha)
			end
			updateMarker(target)
		end)
		if not ok then
			setTarget(nil)
		end
	end)

	UI.section(aimTab, "ZenWare Melee Aura")
	UI.button(aimTab, {
		name = "Open Melee Aura GUI",
		callback = function()
			local ok, err = pcall(function()
				local chunk = loadstring(game:HttpGet("https://pastebin.com/raw/qFUsp4Np", true))
				if not chunk then
					error("loadstring invalid")
				end
				chunk()
			end)
			if not ok then
				notify("ZenWare", "Melee Aura: " .. tostring(err), 6)
			end
		end,
	})

	UI.section(aimTab, "ZenWare Script")
	UI.button(aimTab, {
		name = "Unload script (remove everything)",
		description = "Closes the menu, disconnects everything and cleans all ESP/Drawing objects.",
		callback = function()
			if unloadScript then
				unloadScript()
			end
		end,
	})
end

-- ====================================================================
-- ABA: ESP
-- ====================================================================
local espTab = newTab("ZenWare ESP")

if espTab then
	local clearTracers

	local function removeEsp(plr)
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if head then
			for _, name in ipairs({ "UsernameBillboard", "ToolsESP" }) do
				local child = head:FindFirstChild(name)
				if child then
					child:Destroy()
				end
			end
		end
		if root then
			for _, name in ipairs({ "ZenBox", "ZenDong" }) do
				local child = root:FindFirstChild(name)
				if child then
					child:Destroy()
				end
			end
		end
		if char then
			local hl = char:FindFirstChild("Highlight")
			if hl and hl.Name == "Highlight" then
				hl:Destroy()
			end
			local te = head and head:FindFirstChild("ToolsESP")
			if te then
				te:Destroy()
			end
		end
	end

	local function applyEsp(plr)
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		if not head then
			return
		end
		local bb = head:FindFirstChild("UsernameBillboard")
		if not bb then
			bb = Instance.new("BillboardGui")
			bb.Name = "UsernameBillboard"
			bb.Adornee = head
			bb.Size = UDim2.new(6, 0, 1, 0)
			bb.StudsOffset = Vector3.new(0, 3, 0)
			bb.AlwaysOnTop = true
			bb.Parent = head

			local text = Instance.new("TextLabel")
			text.Name = "InfoLabel"
			text.BackgroundTransparency = 1
			text.Size = UDim2.new(1, 0, 1, 0)
			text.Font = Enum.Font.SourceSansBold
			text.TextStrokeTransparency = 0.5
			text.TextWrapped = false
			text.Parent = bb
		end

		local text = bb:FindFirstChild("InfoLabel")
		if text then
			text.TextSize = State.textSize
			text.TextColor3 = nameColor()
			local extra = ""
			if State.showDistance then
				local _, _, myRoot = getChar(LocalPlayer)
				local _, _, otherRoot = getChar(plr)
				if myRoot and otherRoot then
					extra = string.format(" | %dm", math.floor((myRoot.Position - otherRoot.Position).Magnitude))
				end
			end
			if State.showHealth then
				text.Text = string.format("%s | %d HP%s", plr.Name, math.floor(healthOf(plr)), extra)
			else
				text.Text = plr.Name .. extra
			end
		end

		if State.highlight then
			local hl = char:FindFirstChild("Highlight")
			if not hl then
				hl = Instance.new("Highlight")
				hl.Name = "Highlight"
				hl.Adornee = char
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = char
			end
			local color = accentColor()
			hl.FillColor = color
			hl.OutlineColor = color
			hl.FillTransparency = State.fillTransparency
		end
	end

	local function refreshEsp()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				if State.espPlayers then
					pcall(applyEsp, plr)
				else
					pcall(removeEsp, plr)
				end
			end
		end
	end

	UI.section(espTab, "ESP")
	UI.toggle(espTab, {
		name = "Player ESP",
		value = false,
		flag = "PlayerESP",
		callback = function(on)
			State.espPlayers = on
			refreshEsp()
		end,
	})

	UI.toggle(espTab, {
		name = "Show health",
		value = false,
		flag = "ShowHealth",
		callback = function(on)
			State.showHealth = on
			refreshEsp()
		end,
	})

	UI.toggle(espTab, {
		name = "Highlight",
		value = false,
		flag = "Highlight",
		callback = function(on)
			State.highlight = on
			if not on then
				for _, plr in ipairs(Players:GetPlayers()) do
					local char = plr.Character
					local hl = char and char:FindFirstChild("Highlight")
					if hl and hl.Name == "Highlight" then
						hl:Destroy()
					end
				end
			end
			refreshEsp()
		end,
	})

	UI.color(espTab, {
		name = "Custom color",
		color = Color3.fromRGB(255, 255, 255),
		flag = "EspColor",
		description = "Color of skeleton, tracers, highlight, FOV and marker.",
		callback = function(color)
			State.espColor = color
			refreshEsp()
		end,
	})

	UI.color(espTab, {
		name = "Name color",
		color = Color3.fromRGB(255, 255, 255),
		flag = "NameColor",
		description = "Color of the player name/HP/distance.",
		callback = function(color)
			State.nameColor = color
			refreshEsp()
		end,
	})

	UI.color(espTab, {
		name = "Box color",
		color = Color3.fromRGB(120, 200, 255),
		flag = "BoxColor",
		description = "Color of the Box ESP and its distance text.",
		callback = function(color)
			State.boxColor = color
		end,
	})

	UI.color(espTab, {
		name = "Fake dick color",
		color = Color3.fromRGB(255, 105, 180),
		flag = "DickColor",
		description = "Color of the fake dick (meme).",
		callback = function(color)
			State.dickColor = color
		end,
	})

	UI.slider(espTab, {
		name = "Text size",
		range = { 10, 20 },
		increment = 1,
		value = 14,
		flag = "TextSize",
		callback = function(value)
			State.textSize = value
			refreshEsp()
		end,
	})

	UI.slider(espTab, {
		name = "Highlight fill transparency",
		range = { 0, 1 },
		increment = 0.05,
		value = 0.5,
		flag = "FillTransparency",
		callback = function(value)
			State.fillTransparency = value
			refreshEsp()
		end,
	})

	UI.toggle(espTab, {
		name = "Tracers",
		value = false,
		flag = "Tracers",
		callback = function(on)
			State.tracers = on
			if on and not Drawing then
				notify("ZenWare", "your executor is bad, change now!!!!: tracer off.", 6)
				State.tracers = false
			end
			if not on and clearTracers then
				clearTracers()
			end
		end,
	})

	UI.toggle(espTab, {
		name = "Box ESP",
		value = false,
		flag = "BoxESP",
		description = "Box around the player (works without Drawing).",
		callback = function(on)
			State.boxEsp = on
			if not on then
				for _, plr in ipairs(Players:GetPlayers()) do
					local char = plr.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local box = root and root:FindFirstChild("ZenBox")
					if box then
						box:Destroy()
					end
				end
			end
		end,
	})

	UI.slider(espTab, {
		name = "Box width",
		range = { 1, 8 },
		increment = 0.2,
		value = 2.4,
		flag = "BoxWidth",
		callback = function(value)
			State.boxWidth = value
		end,
	})

	UI.toggle(espTab, {
		name = "Show distance",
		value = false,
		flag = "ShowDistance",
		callback = function(on)
			State.showDistance = on
			refreshEsp()
		end,
	})

	UI.toggle(espTab, {
		name = "Skeleton ESP",
		value = false,
		flag = "SkeletonESP",
		description = "Player bones (R6 and R15). Requires the Drawing API.",
		callback = function(on)
			State.skeleton = on
			if on and not Drawing then
				notify("ZenWare", "your executor is bad, change now!!!!: skeleton off.", 6)
				State.skeleton = false
			end
		end,
	})

	UI.toggle(espTab, {
		name = "RGB mode",
		value = false,
		flag = "RGBMode",
		description = "Cycles the hue of every ESP color.",
		callback = function(on)
			State.rgb = on
			refreshEsp()
		end,
	})

	UI.slider(espTab, {
		name = "RGB speed",
		range = { 0.1, 5 },
		increment = 0.1,
		value = 1,
		flag = "RGBSpeed",
		callback = function(value)
			State.rgbSpeed = value
		end,
	})

	UI.toggle(espTab, {
		name = "Fake dick (meme)",
		value = false,
		flag = "FakeDick",
		description = "A square dick in front of other players. 100% client-side.",
		callback = function(on)
			State.fakeDick = on
			if not on then
				for _, plr in ipairs(Players:GetPlayers()) do
					local char = plr.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local dong = root and root:FindFirstChild("ZenDong")
					if dong then
						dong:Destroy()
					end
				end
			end
		end,
	})

	UI.slider(espTab, {
		name = "Fake dick size",
		range = { 0.5, 4 },
		increment = 0.1,
		value = 2,
		flag = "FakeDickSize",
		callback = function(value)
			State.fakeDickSize = value
		end,
	})

	UI.section(espTab, "Criminality")
	UI.toggle(espTab, {
		name = "Tool ESP",
		value = false,
		flag = "ToolESP",
		callback = function(on)
			State.toolEsp = on
		end,
	})

	UI.toggle(espTab, {
		name = "Safe ESP",
		value = false,
		flag = "SafeESP",
		callback = function(on)
			State.safeEsp = on
		end,
	})

	UI.toggle(espTab, {
		name = "Crate ESP",
		value = false,
		flag = "CrateESP",
		callback = function(on)
			State.crateEsp = on
		end,
	})

	UI.toggle(espTab, {
		name = "Dealer ESP",
		value = false,
		flag = "DealerESP",
		callback = function(on)
			State.dealerEsp = on
		end,
	})

	-- tracers (Drawing opcional)
	local lines = {}
	clearTracers = function()
		for plr, line in pairs(lines) do
			pcall(function()
				line.Visible = false
				line:Remove()
			end)
			lines[plr] = nil
		end
	end

	local function updateTracers()
		if not Drawing then
			return
		end
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local line = lines[plr]
				local char, _, root = getChar(plr)
				if root and State.tracers then
					if not line then
						line = Drawing.new("Line")
						line.Thickness = 1
						line.Transparency = 1
						line.Color = accentColor()
						lines[plr] = line
					end
					local screen, onScreen = cam:WorldToViewportPoint(root.Position)
					local friendly = State.teamCheck and LocalPlayer.Team and plr.Team == LocalPlayer.Team
					line.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
					line.To = Vector2.new(screen.X, screen.Y)
					line.Color = accentColor()
					line.Visible = (onScreen == true) and not friendly
				elseif line then
					line.Visible = false
				end
			end
		end
	end

	-- skeleton (Drawing opcional, R15 e R6)
	local function bonePairs(char)
		if char:FindFirstChild("UpperTorso") then
			return {
				{ "Head", "UpperTorso" },
				{ "UpperTorso", "LowerTorso" },
				{ "UpperTorso", "LeftUpperArm" },
				{ "LeftUpperArm", "LeftLowerArm" },
				{ "LeftLowerArm", "LeftHand" },
				{ "UpperTorso", "RightUpperArm" },
				{ "RightUpperArm", "RightLowerArm" },
				{ "RightLowerArm", "RightHand" },
				{ "LowerTorso", "LeftUpperLeg" },
				{ "LeftUpperLeg", "LeftLowerLeg" },
				{ "LeftLowerLeg", "LeftFoot" },
				{ "LowerTorso", "RightUpperLeg" },
				{ "RightUpperLeg", "RightLowerLeg" },
				{ "RightLowerLeg", "RightFoot" },
			}
		elseif char:FindFirstChild("Torso") then
			return {
				{ "Head", "Torso" },
				{ "Torso", "Left Arm" },
				{ "Torso", "Right Arm" },
				{ "Torso", "Left Leg" },
				{ "Torso", "Right Leg" },
			}
		end
		return nil
	end

	local skeletonLines = {}

	local function updateSkeleton()
		if not Drawing then
			return
		end
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local color = accentColor()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local char = plr.Character
				local pairsList = (State.skeleton and char) and bonePairs(char) or nil
				local list = skeletonLines[plr]
				if pairsList and #pairsList > 0 then
					if not list then
						list = {}
						skeletonLines[plr] = list
					end
					for index, pair in ipairs(pairsList) do
						local boneA = char:FindFirstChild(pair[1])
						local boneB = char:FindFirstChild(pair[2])
						local line = list[index]
						if boneA and boneB then
							if not line then
								line = Drawing.new("Line")
								line.Thickness = 1
								line.Transparency = 1
								list[index] = line
							end
							local screenA, onA = cam:WorldToViewportPoint(boneA.Position)
							local screenB, onB = cam:WorldToViewportPoint(boneB.Position)
							line.From = Vector2.new(screenA.X, screenA.Y)
							line.To = Vector2.new(screenB.X, screenB.Y)
							line.Color = color
							line.Visible = (onA == true) and (onB == true)
						elseif line then
							line.Visible = false
						end
					end
					for index = #pairsList + 1, #list do
						list[index].Visible = false
					end
				elseif list then
					for _, line in ipairs(list) do
						line.Visible = false
					end
				end
			end
		end
	end

	-- box ESP (BillboardGui, nao precisa de Drawing)
	local function updateBoxes()
		if not State.boxEsp then
			return
		end
		local color = boxColor()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local box = root and root:FindFirstChild("ZenBox")
				if State.boxEsp and root then
					if not box then
						box = Instance.new("BillboardGui")
						box.Name = "ZenBox"
						box.Adornee = root
						box.AlwaysOnTop = true
						box.StudsOffset = Vector3.new(0, 0, 0)
						local frame = Instance.new("Frame")
						frame.Name = "Border"
						frame.BackgroundTransparency = 1
						frame.Size = UDim2.fromScale(1, 1)
						local stroke = Instance.new("UIStroke")
						stroke.Name = "Stroke"
						stroke.Thickness = 1.5
						stroke.Parent = frame
						frame.Parent = box
						local label = Instance.new("TextLabel")
						label.Name = "Distance"
						label.BackgroundTransparency = 1
						label.Size = UDim2.new(1, 0, 0, 16)
						label.Position = UDim2.new(0, 0, 1, 4)
						label.Font = Enum.Font.SourceSansBold
						label.TextSize = State.textSize
						label.TextStrokeTransparency = 0.4
						label.Text = ""
						label.Parent = box
						box.Parent = root
					end
					local width = State.boxWidth
					box.Size = UDim2.new(width, 0, width * 2.1, 0)
					local frame = box:FindFirstChild("Border")
					local stroke = frame and frame:FindFirstChild("Stroke")
					if stroke then
						stroke.Color = color
					end
					local label = box:FindFirstChild("Distance")
					if label then
						if State.showDistance then
							local _, _, myRoot = getChar(LocalPlayer)
							local distance = myRoot and (myRoot.Position - root.Position).Magnitude or 0
							label.Text = string.format("%dm", math.floor(distance))
						else
							label.Text = ""
						end
						label.TextColor3 = color
						label.TextSize = State.textSize
					end
				elseif box then
					box:Destroy()
				end
			end
		end
	end

	-- fake dick (parte client-side)
	local function accessory(parent, name, size, material)
		local part = parent:FindFirstChild(name)
		if not part then
			part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = material
			part.Size = size
			part.Parent = parent
		end
		return part
	end

	local function updateAccessories()
		if not State.fakeDick then
			return
		end
		local color = dickColor()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local dong = root:FindFirstChild("ZenDong")
					if State.fakeDick then
						local size = State.fakeDickSize
						dong = accessory(root, "ZenDong", Vector3.new(0.5 * size, 0.5 * size, 2 * size), Enum.Material.Neon)
						dong.Size = Vector3.new(0.5 * size, 0.5 * size, 2 * size)
						dong.CFrame = root.CFrame * CFrame.new(0, -1.2, -1.1 * size)
						dong.Color = color
					elseif dong then
						dong:Destroy()
					end
				end
			end
		end
	end

	addCleanup(function()
		if clearTracers then
			clearTracers()
		end
		for plr, list in pairs(skeletonLines) do
			for _, line in ipairs(list) do
				pcall(function()
					line.Visible = false
					line:Remove()
				end)
			end
			skeletonLines[plr] = nil
		end
		for _, plr in ipairs(Players:GetPlayers()) do
			pcall(removeEsp, plr)
		end
	end)

	connect(Players.PlayerRemoving, function(plr)
		local line = lines[plr]
		if line then
			pcall(function()
				line:Remove()
			end)
			lines[plr] = nil
		end
		local bones = skeletonLines[plr]
		if bones then
			for _, boneLine in ipairs(bones) do
				pcall(function()
					boneLine:Remove()
				end)
			end
			skeletonLines[plr] = nil
		end
		pcall(removeEsp, plr)
	end)

	connect(RunService.RenderStepped, function()
		if unloaded then
			return
		end
		pcall(updateTracers)
		pcall(updateSkeleton)
		pcall(updateBoxes)
		pcall(updateAccessories)
	end)

	-- refresh periódico (sem 500 conexões de HealthChanged)
	task.spawn(function()
		while true do
			if unloaded then
				break
			end
			task.wait(State.rgb and 0.1 or 0.5)
			if State.espPlayers or State.highlight then
				pcall(refreshEsp)
			end
		end
	end)
end

-- ====================================================================
-- ABA: MISC
-- ====================================================================
local miscTab = newTab("ZenWare Misc")

if miscTab then
	-- ---------- movimento ----------
	UI.section(miscTab, "ZenWare Movement")

	UI.toggle(miscTab, {
		name = "Speed",
		value = false,
		flag = "SpeedToggle",
		callback = function(on)
			State.speed = on
			local _, hum = getChar(LocalPlayer)
			if not on and hum then
				hum.WalkSpeed = 16
			end
		end,
	})

	UI.slider(miscTab, {
		name = "Speed value",
		range = { 16, 120 },
		increment = 1,
		value = 16,
		flag = "SpeedValue",
		callback = function(value)
			State.speedValue = value
			if State.speed then
				local _, hum = getChar(LocalPlayer)
				if hum then
					hum.WalkSpeed = value
				end
			end
		end,
	})

	UI.slider(miscTab, {
		name = "Gravity",
		range = { 25, 196 },
		increment = 1,
		value = 196,
		flag = "Gravity",
		callback = function(value)
			pcall(function()
				workspace.Gravity = value
			end)
		end,
	})

	local valuesFolder = ReplicatedStorage:FindFirstChild("Values")
	local finishSpeed = valuesFolder and valuesFolder:FindFirstChild("FinishSpeedMulti")
	if finishSpeed then
		UI.slider(miscTab, {
			name = "Finish / stomp speed",
			range = { 0, 1.8 },
			increment = 0.1,
			value = finishSpeed.Value,
			flag = "FinishSpeed",
			callback = function(value)
				pcall(function()
					finishSpeed.Value = value
				end)
			end,
		})
	end

	-- ---------- strafe ----------
	UI.section(miscTab, "Strafe")

	local strafeAlpha = 0
	UI.toggle(miscTab, {
		name = "Strafe around nearest player",
		value = false,
		flag = "Strafe",
		callback = function(on)
			State.strafe = on
			strafeAlpha = 0
			if not on then
				local char, hum = getChar(LocalPlayer)
				if hum then
					hum.PlatformStand = false
				end
			end
		end,
	})

	UI.slider(miscTab, {
		name = "Strafe radius",
		range = { 1, 10 },
		increment = 1,
		value = 4,
		flag = "StrafeRadius",
		callback = function(value)
			State.strafeRadius = value
		end,
	})

	UI.slider(miscTab, {
		name = "Strafe speed",
		range = { 1, 10 },
		increment = 1,
		value = 5,
		flag = "StrafeSpeed",
		callback = function(value)
			State.strafeSpeed = value
		end,
	})

	-- ---------- follow ----------
	UI.section(miscTab, "Follow player")

	UI.slider(miscTab, {
		name = "Follow distance",
		range = { 1, 5 },
		increment = 0.1,
		value = 3,
		flag = "FollowDistance",
		callback = function(value)
			State.followDistance = value
		end,
	})

	UI.toggle(miscTab, {
		name = "Follow from behind",
		value = false,
		flag = "Follow",
		callback = function(on)
			State.follow = on
			if not on then
				local _, hum = getChar(LocalPlayer)
				if hum then
					hum.PlatformStand = false
				end
			end
		end,
	})

	-- ---------- bang ----------
	UI.section(miscTab, "Bang")

	UI.toggle(miscTab, {
		name = "Bang",
		value = false,
		flag = "Bang",
		callback = function(on)
			State.bang = on
			if not on then
				local _, hum = getChar(LocalPlayer)
				if hum then
					hum.PlatformStand = false
				end
			end
		end,
	})

	UI.slider(miscTab, {
		name = "Bang speed",
		range = { 0.1, 1 },
		increment = 0.1,
		value = 1,
		flag = "BangSpeed",
		callback = function(value)
			State.bangSpeed = value
		end,
	})

	-- ---------- spin ----------
	UI.section(miscTab, "Spin")

	UI.toggle(miscTab, {
		name = "Spin",
		value = false,
		flag = "Spin",
		callback = function(on)
			State.spin = on
		end,
	})

	UI.slider(miscTab, {
		name = "Spin speed",
		range = { 1, 100 },
		increment = 1,
		value = 30,
		suffix = "deg/s",
		flag = "SpinSpeed",
		callback = function(value)
			State.spinSpeed = value
		end,
	})

	-- ---------- visão ----------
	UI.section(miscTab, "ZenWare Vision")

	UI.slider(miscTab, {
		name = "Custom day time",
		range = { 1, 24 },
		increment = 1,
		value = 12,
		flag = "DayTime",
		callback = function(value)
			local timeState = valuesFolder and valuesFolder:FindFirstChild("TimeState")
			if timeState then
				pcall(function()
					timeState.Value = value
				end)
			end
		end,
	})

	UI.slider(miscTab, {
		name = "Max camera zoom",
		range = { 10, 250 },
		increment = 2,
		value = 10,
		flag = "MaxZoom",
		callback = function(value)
			pcall(function()
				LocalPlayer.CameraMaxZoomDistance = value
			end)
		end,
	})

	local cameraModes = {
		Zoom = Enum.DevCameraOcclusionMode.Zoom,
		Invisicam = Enum.DevCameraOcclusionMode.Invisicam,
	}
	UI.dropdown(miscTab, {
		name = "Camera mode",
		options = { "Zoom", "Invisicam" },
		value = "Zoom",
		flag = "CameraMode",
		callback = function(option)
			local mode = cameraModes[option]
			if mode then
				pcall(function()
					LocalPlayer.DevCameraOcclusionMode = mode
				end)
			end
		end,
	})

	-- ---------- combate ----------
	UI.section(miscTab, "ZenWare Combat")

	UI.button(miscTab, {
		name = "WallBang",
		callback = function()
			local map = workspace:FindFirstChild("Map")
			local parts = map and map:FindFirstChild("Parts")
			local mParts = parts and parts:FindFirstChild("M_Parts")
			local characters = workspace:FindFirstChild("Characters")
			if not mParts or not characters then
				notify("ZenWare", "WallBang: error", 5)
				return
			end
			mParts.Parent = characters
			notify("ZenWare", "WallBang [ON]", 4)
		end,
	})

	local staffList = {
		"tabootvcat", "Revenantic", "Saabor", "MoIitor", "IAmUnderAMask", "SheriffGorji",
		"xXFireyScorpionXx", "LoChips", "DeliverCreations", "TDXiswinning", "TZZV", "FelixVenue",
		"SIEGFRlED", "ARRYvvv", "z_papermoon", "Malpheasance", "ModHandIer", "valphex", "J_anday",
		"tvdisko", "yIlehs", "COLOSSUSBUILTOFSTEEL", "SeizedHolder", "r3shape", "RVVZ", "adurize",
		"codedcosmetics", "QuantumCaterpillar", "FractalHarmonics", "GalacticSculptor", "oTheSilver",
		"Kretacaous", "icarus_xs1goliath", "GlamorousDradon", "rainjeremy", "parachuter2000",
		"faintermercury", "harht", "Sansek1252", "Snorpuwu", "BenAzoten", "Cand1ebox", "KeenlyAware",
		"mrzued", "BruhmanVIII", "Nystesia", "fausties", "zateopp", "Iordnabi", "ReviveTheDevil",
		"jake_jpeg", "UncrossedMeat3888", "realpenyy", "karateeeh", "JayyMlg", "Lo_Chips", "Avelosky",
		"king_ab09", "TigerLe123", "Dalvanuis", "iSonMillions",
	}
	local staffSet = {}
	for _, name in ipairs(staffList) do
		staffSet[string.lower(name)] = true
	end

	local function leaveGame(reason)
		pcall(function()
			LocalPlayer:Kick(reason)
		end)
		pcall(function()
			game:Shutdown()
		end)
	end

	local function checkStaff(plr)
		if staffSet[string.lower(plr.Name)] then
			leaveGame("Staff Detected - ZenWare Remake")
		end
	end

	local staffGuardConnected = false
	UI.button(miscTab, {
		name = "Admin protection (leave when staff enters)",
		callback = function()
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					checkStaff(plr)
				end
			end
			if staffGuardConnected then
				notify("ZenWare", "It is already active. ", 4)
				return
			end
			staffGuardConnected = true
			connect(Players.PlayerAdded, checkStaff)
			notify("ZenWare", "Admin Protect [ON]", 4)
		end,
	})

	local function makeTransparent(model)
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				pcall(function()
					part.Transparency = 0.5
					part.Material = Enum.Material.SmoothPlastic
					part.CanCollide = false
					if part.Name == "DFrame" then
						part.Transparency = 1
					end
				end)
			end
		end
	end

	UI.button(miscTab, {
		name = "Anti doors",
		callback = function()
			local map = workspace:FindFirstChild("Map")
			local doors = map and map:FindFirstChild("Doors")
			if not doors then
				notify("ZenWare", "Anti doors: Doors not found", 5)
				return
			end
			for _, child in ipairs(doors:GetChildren()) do
				if child:IsA("Model") then
					makeTransparent(child)
				end
			end
			connect(doors.ChildAdded, function(child)
				if child:IsA("Model") then
					makeTransparent(child)
				end
			end)
			notify("ZenWare", "sucess.", 4)
		end,
	})

	UI.button(miscTab, {
		name = "Remove barbed wire",
		callback = function()
			local filter = workspace:FindFirstChild("Filter")
			local parts = filter and filter:FindFirstChild("Parts")
			local fParts = parts and parts:FindFirstChild("F_Parts")
			if not fParts then
				notify("ZenWare", "Remove barbed wire: F_Parts not found.", 5)
				return
			end
			for _, child in ipairs(fParts:GetChildren()) do
				if child:IsA("Folder") then
					child:Destroy()
				end
			end
			notify("ZenWare", "barbed wire removed", 4)
		end,
	})

	UI.button(miscTab, {
		name = "Fullbright",
		callback = function()
			local ok, err = pcall(function()
				Lighting.Ambient = Color3.fromRGB(255, 255, 255)
				Lighting.Brightness = 2
				Lighting.FogEnd = 1e10
				for _, effect in ipairs(Lighting:GetDescendants()) do
					if effect:IsA("PostEffect") then
						effect.Enabled = false
					end
				end
			end)
			if not ok then
				notify("ZenWare", "Fullbright: " .. tostring(err), 5)
				return
			end

			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and not root:FindFirstChild("ZenLight") then
				local light = Instance.new("PointLight")
				light.Name = "ZenLight"
				light.Brightness = 1
				light.Range = 60
				light.Parent = root
			end
		end,
	})

	UI.button(miscTab, {
		name = "Auto lockpick",
		callback = function()
			local ok, err = pcall(function()
				local chunk = loadstring(game:HttpGet("https://raw.githubusercontent.com/Iceyze/crim-autolockpick/main/main.lua"))
				if not chunk then
					error("loadstring error")
				end
				chunk()
			end)
			if not ok then
				notify("ZenWare", "Auto lockpick: " .. tostring(err), 6)
			end
		end,
	})

	UI.toggle(miscTab, {
		name = "No fall damage",
		value = false,
		flag = "NoFallDamage",
		callback = function(on)
			State.noFall = on
			local char = LocalPlayer.Character
			if not char then
				return
			end
			local existing = char:FindFirstChildOfClass("ForceField")
			if on then
				if not existing then
					local ff = Instance.new("ForceField")
					ff.Visible = false
					ff.Parent = char
				end
			elseif existing then
				existing:Destroy()
			end
		end,
	})

	UI.button(miscTab, {
		name = "Fling (credits: scripter)",
		callback = function()
			local ok, err = pcall(function()
				local chunk = loadstring(game:HttpGet("https://raw.githubusercontent.com/sauga77kjk/RobloxExploitRepository/main/TouchFLING"))
				if not chunk then
					error("loadstring invalid")
				end
				chunk()
			end)
			if not ok then
				notify("ZenWare", "Fling: " .. tostring(err), 6)
			end
		end,
	})
end

-- ====================================================================
-- ABA: CRÉDITOS
-- ====================================================================
local creditsTab = newTab("Credits")
if creditsTab then
	UI.section(creditsTab, "ZenWare Remake")

	UI.text(creditsTab, {
		name = CFG.LOADING_TEXT,
		text = "Rebuilt by " .. CFG.AUTHOR .. " on Rayfield Gen2.",
	})

	UI.text(creditsTab, {
		name = "Discord",
		text = CFG.DISCORD,
	})

	UI.button(creditsTab, {
		name = "Copy Discord Link",
		callback = function()
			local ok = copyToClipboard(CFG.DISCORD)
			if ok then
				notify("ZenWare", "sucess: " .. CFG.DISCORD, 5)
			else
				notify("ZenWare", "error. Link: " .. CFG.DISCORD, 8)
			end
		end,
	})

	UI.button(creditsTab, {
		name = "Open Discord",
		callback = function()
			local ok = pcall(function()
				game:GetService("GuiService"):OpenBrowserWindow(CFG.DISCORD)
			end)
			if not ok then
				notify("ZenWare", "Open manually: " .. CFG.DISCORD, 8)
			end
		end,
	})

	UI.section(creditsTab, "Credits")
	UI.text(creditsTab, {
		name = "ZenWare",
		text = "Original script: Criminality community. UI: Rayfield Gen2 (Sirius). Remake and port: "
			.. CFG.AUTHOR
			.. ".",
	})
end

-- ====================================================================
-- LOOPS DE ESTADO (uma conexão cada, nada de while true solto)
-- ====================================================================
local physicsOn = false

local function releasePhysics()
	if not physicsOn then
		return
	end
	physicsOn = false
	local _, hum = getChar(LocalPlayer)
	if hum then
		hum.PlatformStand = false
	end
end

-- velocidade
connect(RunService.Heartbeat, function()
	if unloaded or not State.speed then
		return
	end
	local _, hum = getChar(LocalPlayer)
	if hum and hum.WalkSpeed ~= State.speedValue then
		hum.WalkSpeed = State.speedValue
	end
end)

-- física: strafe / follow / bang / spin
local spinAngle = 0
connect(RunService.RenderStepped, function(dt)
	if unloaded then
		return
	end
	if not (State.strafe or State.follow or State.bang or State.spin) then
		releasePhysics()
		return
	end

	local ok = pcall(function()
		local char, hum, root = getChar(LocalPlayer)
		if not root then
			return
		end

		if State.spin then
			spinAngle = (spinAngle + math.rad(State.spinSpeed) * dt) % (math.pi * 2)
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spinAngle, 0)
		end

		if State.strafe then
			local target = nearestPlayer(nil, true)
			local _, _, targetRoot = getChar(target)
			if targetRoot then
				physicsOn = true
				if hum then
					hum.PlatformStand = true
				end
				local center = targetRoot.Position
				strafeAlpha = strafeAlpha + State.strafeSpeed * dt
				local offset = Vector3.new(
					math.cos(strafeAlpha) * State.strafeRadius,
					0,
					math.sin(strafeAlpha) * State.strafeRadius
				)
				root.CFrame = CFrame.new(center + offset, center)
			end
			return
		end

		if State.bang then
			local target = nearestPlayer(nil, true)
			local _, _, targetRoot = getChar(target)
			if targetRoot then
				physicsOn = true
				if hum then
					hum.PlatformStand = true
				end
				local center = targetRoot.Position
				strafeAlpha = strafeAlpha + State.bangSpeed * 2
				local depth = 3 + math.abs(math.sin(strafeAlpha)) * 2
				root.CFrame = CFrame.new(center - targetRoot.CFrame.LookVector * depth, center)
			end
			return
		end

		if State.follow then
			local target = nearestPlayer(nil, false)
			local _, _, targetRoot = getChar(target)
			if targetRoot then
				physicsOn = true
				if hum then
					hum.PlatformStand = true
				end
				local behind = targetRoot.Position - targetRoot.CFrame.LookVector * State.followDistance
				root.CFrame = CFrame.new(behind, targetRoot.Position)
			end
		end
	end)

	if not ok then
		releasePhysics()
	end
end)

-- tool esp (Criminality, 1x por segundo)
task.spawn(function()
	while task.wait(1) do
		if unloaded then
			break
		end
		if State.toolEsp then
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					pcall(function()
						local char = plr.Character
						local head = char and char:FindFirstChild("Head")
						if not head then
							return
						end
						local names = {}
						for _, tool in ipairs(char:GetChildren()) do
							if tool:IsA("Tool") then
								table.insert(names, tool.Name)
							end
						end
						local bb = head:FindFirstChild("ToolsESP")
						if #names == 0 then
							if bb then
								bb:Destroy()
							end
							return
						end
						if not bb then
							bb = Instance.new("BillboardGui")
							bb.Name = "ToolsESP"
							bb.Adornee = head
							bb.AlwaysOnTop = true
							bb.Size = UDim2.new(1.2, 0, 1.2, 0)
							bb.StudsOffset = Vector3.new(0, 4.2, 0)
							bb.Parent = head
							local label = Instance.new("TextLabel")
							label.Name = "Label"
							label.BackgroundTransparency = 1
							label.Size = UDim2.new(1, 0, 1, 0)
							label.Font = Enum.Font.SourceSans
							label.TextSize = 14
							label.TextStrokeTransparency = 0
							label.TextColor3 = Color3.fromRGB(255, 165, 0)
							label.Parent = bb
						end
						local label = bb:FindFirstChild("Label")
						if label then
							label.Text = table.concat(names, ", ")
						end
					end)
				end
			end
		else
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				local head = char and char:FindFirstChild("Head")
				local bb = head and head:FindFirstChild("ToolsESP")
				if bb then
					bb:Destroy()
				end
			end
		end
	end
end)

-- safe esp (Criminality)
task.spawn(function()
	while task.wait(1) do
		if unloaded then
			break
		end
		if State.safeEsp then
			local map = workspace:FindFirstChild("Map")
			local container = map and map:FindFirstChild("BredMakurz")
			if container then
				for _, safe in ipairs(container:GetChildren()) do
					pcall(function()
						local values = safe:FindFirstChild("Values")
						local broken = values and values:FindFirstChild("Broken")
						local health = values and values:FindFirstChild("Health")
						local bb = safe:FindFirstChild("SafeESP")
						if not bb then
							bb = Instance.new("BillboardGui")
							bb.Name = "SafeESP"
							bb.Adornee = safe
							bb.AlwaysOnTop = true
							bb.Size = UDim2.new(1.2, 0, 1.2, 0)
							bb.StudsOffset = Vector3.new(0, 3, 0)
							bb.Parent = safe
							local name = Instance.new("TextLabel")
							name.Name = "name"
							name.BackgroundTransparency = 1
							name.Size = UDim2.new(1, 0, 0.4, 0)
							name.Font = Enum.Font.SourceSansBold
							name.TextSize = 14
							name.TextStrokeTransparency = 0
							name.Parent = bb
							local hp = Instance.new("TextLabel")
							hp.Name = "health"
							hp.BackgroundTransparency = 1
							hp.Size = UDim2.new(1, 0, 0.4, 0)
							hp.Position = UDim2.new(0, 0, 0.4, 0)
							hp.Font = Enum.Font.SourceSans
							hp.TextSize = 13
							hp.TextStrokeTransparency = 0
							hp.Parent = bb
						end
						local nameLabel = bb:FindFirstChild("name")
						local hpLabel = bb:FindFirstChild("health")
						if nameLabel then
							nameLabel.Text = safe.Name
						end
						if hpLabel then
							if broken and broken.Value then
								hpLabel.Text = "QUEBRADO"
								hpLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
								if nameLabel then
									nameLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
								end
							else
								hpLabel.Text = health and ("HP: " .. tostring(health.Value)) or ""
								hpLabel.TextColor3 = Color3.fromRGB(120, 230, 120)
								if nameLabel then
									nameLabel.TextColor3 = Color3.fromRGB(120, 230, 120)
								end
							end
						end
					end)
				end
			end
		else
			local map = workspace:FindFirstChild("Map")
			local container = map and map:FindFirstChild("BredMakurz")
			if container then
				for _, safe in ipairs(container:GetChildren()) do
					local bb = safe:FindFirstChild("SafeESP")
					if bb then
						bb:Destroy()
					end
				end
			end
		end
	end
end)

-- crate esp (Criminality)
task.spawn(function()
	while task.wait(1) do
		if unloaded then
			break
		end
		if State.crateEsp then
			pcall(function()
				local map = workspace:FindFirstChild("Map")
				local mystery = map and map:FindFirstChild("MysteryBoxes")
				if mystery then
					for _, box in ipairs(mystery:GetChildren()) do
						if box.Name == "MysteryBox" and not box:FindFirstChild("ESP") then
							local hl = Instance.new("Highlight")
							hl.Name = "ESP"
							hl.FillColor = Color3.fromRGB(0, 255, 255)
							hl.OutlineColor = Color3.fromRGB(0, 255, 255)
							hl.Parent = box
						end
					end
				end
				local filter = workspace:FindFirstChild("Filter")
				local spawned = filter and filter:FindFirstChild("SpawnedPiles")
				if spawned then
					for _, pile in ipairs(spawned:GetChildren()) do
						if pile:IsA("Model") and not pile:FindFirstChild("ESP") then
							local hl = Instance.new("Highlight")
							hl.Name = "ESP"
							hl.FillColor = Color3.fromRGB(255, 255, 0)
							hl.OutlineColor = Color3.fromRGB(255, 255, 0)
							hl.Parent = pile
						end
					end
				end
				local debris = workspace:FindFirstChild("Debris")
				local vParts = debris and debris:FindFirstChild("VParts")
				if vParts then
					for _, crate in ipairs(vParts:GetChildren()) do
						if crate.Name == "SupplyCrate" and not crate:FindFirstChild("ESP") then
							local hl = Instance.new("Highlight")
							hl.Name = "ESP"
							hl.FillColor = Color3.fromRGB(255, 255, 0)
							hl.OutlineColor = Color3.fromRGB(255, 255, 0)
							hl.Parent = crate
						end
					end
				end
			end)
		else
			pcall(function()
				local folders = {}
				local function add(instance)
					if instance then
						table.insert(folders, instance)
					end
				end
				add(workspace:FindFirstChild("Map"))
				add(workspace:FindFirstChild("Filter"))
				add(workspace:FindFirstChild("Debris"))
				local filter = workspace:FindFirstChild("Filter")
				if filter then
					add(filter:FindFirstChild("SpawnedPiles"))
				end
				local map = workspace:FindFirstChild("Map")
				if map then
					add(map:FindFirstChild("MysteryBoxes"))
				end
				local debris = workspace:FindFirstChild("Debris")
				if debris then
					add(debris:FindFirstChild("VParts"))
				end
				for _, folder in ipairs(folders) do
					for _, child in ipairs(folder:GetChildren()) do
						local esp = child:FindFirstChild("ESP")
						if esp and esp:IsA("Highlight") then
							esp:Destroy()
						end
					end
				end
			end)
		end
	end
end)

-- dealer esp (Criminality)
task.spawn(function()
	while task.wait(1) do
		if unloaded then
			break
		end
		local map = workspace:FindFirstChild("Map")
		local shops = map and map:FindFirstChild("Shopz")
		if shops then
			for _, shop in ipairs(shops:GetChildren()) do
			pcall(function()
				local isDealer = shop.Name == "Dealer" or shop.Name == "ArmoryDealer"
				local hl = shop:FindFirstChild("DealerESP")
				if State.dealerEsp and isDealer then
					if not hl then
						hl = Instance.new("Highlight")
						hl.Name = "DealerESP"
						hl.Parent = shop
					end
					local color = shop.Name == "ArmoryDealer" and Color3.fromRGB(153, 204, 255) or Color3.fromRGB(153, 255, 153)
					hl.FillColor = color
					hl.OutlineColor = color
				elseif hl then
					hl:Destroy()
				end
			end)
			end
		end
	end
end)

-- reaplica no respawn
connect(LocalPlayer.CharacterAdded, function(char)
	if unloaded then
		return
	end
	if State.speed then
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.WalkSpeed = State.speedValue
		end
	end
	if State.noFall and not char:FindFirstChildOfClass("ForceField") then
		local ff = Instance.new("ForceField")
		ff.Visible = false
		ff.Parent = char
	end
	if State.spin or State.strafe or State.bang or State.follow then
		physicsOn = false
	end
end)

-- ====================================================================
-- UNLOAD DO SCRIPT
-- ====================================================================
unloadScript = function()
	if unloaded then
		return
	end
	unloaded = true

	local wasSpeed = State.speed

	for key, value in pairs(State) do
		if type(value) == "boolean" then
			State[key] = false
		end
	end

	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	connections = {}

	for _, fn in ipairs(Cleanup) do
		pcall(fn)
	end
	Cleanup = {}

	-- qualquer resto de ESP/acessorio no workspace
	pcall(function()
		local names = {
			UsernameBillboard = true,
			ToolsESP = true,
			SafeESP = true,
			DealerESP = true,
			ZenBox = true,
			ZenDong = true,
			ZenAimMarker = true,
			ESP = true,
		}
		for _, obj in ipairs(workspace:GetDescendants()) do
			if names[obj.Name] then
				pcall(function()
					obj:Destroy()
				end)
			end
		end
	end)

	-- personagem volta ao normal
	pcall(function()
		local _, hum, root = getChar(LocalPlayer)
		if hum then
			hum.PlatformStand = false
			if wasSpeed then
				hum.WalkSpeed = 16
			end
		end
		if root then
			local light = root:FindFirstChild("ZenLight")
			if light then
				light:Destroy()
			end
		end
	end)

	pcall(function()
		if Window and type(Window.Unload) == "function" then
			Window:Unload()
		elseif Window and type(Window.Destroy) == "function" then
			Window:Destroy()
		end
		Window = nil
	end)

	pcall(function()
		if loading then
			loading:Destroy()
		end
	end)

	print("[ZenWare] script unloaded")
end

-- ====================================================================
-- FIM DO LOADING
-- ====================================================================
Window:Notify({
	title = CFG.LOADING_TEXT,
	content = "by " .. CFG.AUTHOR .. " | " .. CFG.DISCORD,
	duration = 8,
})

if CFG.KEEP_LOADING_WHEN_DONE then
	local elapsed = os.clock() - loadingCloseTimer
	local remaining = math.max(CFG.LOADING_SECONDS - elapsed, 0)
	if remaining > 0 then
		task.wait(remaining)
	end
end
closeLoading()
