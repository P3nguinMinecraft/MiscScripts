-- BeeHop by Penguin!
-- https://discord.gg/fWncS2vFxn

if not game:IsLoaded() then game.Loaded:Wait() end

if not writefile then print("[BeeHop] You cannot change configs because your executor does not support files!") end

print("[BeeHop] Loading")

local Services = setmetatable({}, {
	__index = function(self, name)
		local success, cache = pcall(function()
			return cloneref(game:GetService(name))
		end)
		if success then
			rawset(self, name, cache)
			return cache
		else
			error("Invalid Service: " .. tostring(name))
		end
	end
})

-- Version info
local version = "1.2.1"
local versid = "nsl9enbl"
local updmsg = "Update"
local changelog = "+Supreme Sprout Support"
local settingchanged = true
local settingmsg = "+Supreme Sprout Option\n+Remove autoscan"
local link = "https://discord.gg/fWncS2vFxn"

-- Data structure
local data = {
    version = version,
    versid = versid,
    updmsg = updmsg,
    changelog = changelog,
    settingchanged = settingchanged,
    settingmsg = settingmsg,
    link = link,
    placeids = {
        main = 1537690962,
        hub = 15579077077,
        retro_challenge = 17579225831,
        retro_lobby = 17579226768
    },
    prerequisites = {
        {setting = "autoClaimHive", requires = "autohop"},
        {setting = "fullAutoVic", requires = "autohop"},
        {setting = "fullAutoVic", requires = "autoClaimHive"},
    },
    defaultConfig = {
        autohop = false,
        autoClaimHive = false,
        fullAutoVic = false,
        -- autowebhook = false,
        -- webhookUrl = "https://discord.com/api/webhooks/#/#",
        prioritizeSmallServer = false,
        giftedViciousOnly = false,
        vicMinLevel = 1,
        vicMaxLevel = 12,
        stopList = {
            ["Windy"] = false,
            ["Vicious"] = false,
            ["StickBug"] = false,
            ["Puffshroom"] = false,
            ["Sprout"] = false,
        },
        sproutList = {
            ["Normal"] = true,
            ["Rare"] = true,
            ["Moon"] = true,
            ["Gummy"] = true,
            ["Epic"] = true,
            ["Legendary"] = true,
            ["Supreme"] = true,
        },
    },
}

local function inBSS()
    for _, id in pairs(data.placeids) do
        if game.PlaceId == id then
            return true
        end
    end
    return false
end

if not inBSS() then
    return
end

local config
local newversion = false

local function saveConfig()
    if not writefile then return end
    local encode = Services.HttpService:JSONEncode(config)
    writefile("BeeHop/config.json", encode)
end

local function loadConfig()
    if isfile("BeeHop/config.json") then
        config = Services.HttpService:JSONDecode(readfile("BeeHop/config.json"))
    else
        config = data.defaultConfig
    end

    newversion = not string.match(config.versid or "", data.versid)

    if not writefile then return end

    if not isfile("BeeHop/config.json") and writefile then
        if not isfolder("BeeHop") then
            makefolder("BeeHop")
        end
        writefile("BeeHop/config.json", Services.HttpService:JSONEncode(data.defaultConfig))
    end

    if newversion then
        local function updateTable(default, previous)
            local updated = {}
            for key, value in pairs(default) do
                if type(value) == "table" then
                    updated[key] = updateTable(value, type(previous[key]) == "table" and previous[key] or {})
                elseif previous[key] ~= nil then
                    updated[key] = previous[key]
                else
                    updated[key] = value
                end
            end
            return updated
        end
        
        config = updateTable(data.defaultConfig, config)
        config.version = data.version
        config.versid = data.versid
        saveConfig()
    end
end

local function checkPrerequisites()
    for _, rule in ipairs(data.prerequisites) do
        if config[rule.setting] and not config[rule.requires] then
            config[rule.setting] = false
            warn("[BeeHop] Disabled " .. rule.setting .. ", it requires " .. rule.requires)
        end
    end
    config.vicMinLevel = math.clamp(tonumber(config.vicMinLevel) or data.defaultConfig.vicMinLevel, 1, 12)
    config.vicMaxLevel = math.clamp(tonumber(config.vicMaxLevel) or data.defaultConfig.vicMaxLevel, 1, 12)

    if config.vicMaxLevel <= config.vicMinLevel then
        config.vicMaxLevel = config.vicMinLevel
    end
end

loadConfig()
checkPrerequisites()
saveConfig()

local desiredserver = false
local viciousKill = nil
local viciousModel = nil
local camera = game.Workspace.CurrentCamera
local defaultGravity = game.Workspace.Gravity

local npcBees = game.Workspace:FindFirstChild("NPCBees")
local monsters = game.Workspace:FindFirstChild("Monsters")
local happenings = game.Workspace:FindFirstChild("Happenings")
local zones = game.Workspace:FindFirstChild("FlowerZones")
local sprouts = game.Workspace:FindFirstChild("Sprouts")

-- ESP tracking
local activeESPs = {
	windy = nil,
	vicious = nil,
}

-- Utility functions

local scan
local notifygui
local notifyBee

local function isLoaded()
    return Services.Players.LocalPlayer.PlayerGui.LoadingScreenGui.LoadingMessage.Visible == false
end

local function tpc(cframe)
    Services.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(cframe)
end

local function tp(x, y, z)
    tpc(Vector3.new(x, y, z))
end

local hop = loadstring(game:HttpGet("https://raw.githubusercontent.com/P3nguinMinecraft/MiscScripts/refs/heads/main/serverhop.lua"))()

local teleport = function(placeid)
    if not isLoaded() then
        print("[BeeHop] Waiting for load completely")
    end
    repeat
        task.wait(0.5)
    until isLoaded()
    notifygui("Teleporting", 60, 140, 210)
    repeat
        hop(placeid, config.prioritizeSmallServer)
        task.wait(1)
    until false
end

-- Returns the position of a Vector3 / BasePart / Model, or nil
local getPosition = function(obj)
    if not obj then return nil end
    if typeof(obj) == "Vector3" then return obj end
    if typeof(obj) ~= "Instance" then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local success, pivot = pcall(function() return obj:GetPivot() end)
        if success then return pivot.Position end
    end
    return nil
end

-- Returns the name of the FlowerZone closest to pos (horizontal distance to the
-- zone's rectangle, so a point inside a zone is always distance 0)
local getClosestZone = function(pos)
    pos = getPosition(pos)
    if not pos then return nil end

    local zoneFolder = zones or game.Workspace:FindFirstChild("FlowerZones")
    if not zoneFolder then return nil end

    local closest, closestDist, closestCenter = nil, math.huge, math.huge
    for _, zone in pairs(zoneFolder:GetChildren()) do
        if zone:IsA("BasePart") then
            local offset = zone.CFrame:PointToObjectSpace(pos)
            local half = zone.Size / 2
            local dx = math.max(math.abs(offset.X) - half.X, 0)
            local dz = math.max(math.abs(offset.Z) - half.Z, 0)
            local dist = math.sqrt(dx * dx + dz * dz)
            -- Overlapping zones both give a distance of 0, so break the tie on
            -- distance to the zone's center instead
            local center = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
            if dist < closestDist or (dist == closestDist and center < closestCenter) then
                closestDist = dist
                closestCenter = center
                closest = zone
            end
        end
    end

    return closest and closest.Name or nil
end

local shortZone = function(name)
    return name and string.match(name, "^%S+") or nil
end

local zoneSuffix = function(obj)
    local zone = shortZone(getClosestZone(obj))
    return zone and (" - " .. zone) or ""
end

-- ESP function to attach billboard to bee
local removeESP = function(part)
	if part:FindFirstChild("ESP") then
        part.ESP:Destroy()
    end
    if part:FindFirstChild("TEXT") then
        part.TEXT:Destroy()
    end
end

local createESP = function(part, beeType, r, g, b)
	if not part then return end
	removeESP(part)
    local esp = Instance.new("BillboardGui")
    esp.Name = "ESP"
    esp.Adornee = part
    esp.Parent = part
    esp.Size = UDim2.new(0, 200, 0, 50)
    esp.AlwaysOnTop = true
    esp.StudsOffset = Vector3.new(0, 2, 0)

    local label = Instance.new("TextLabel")
    label.Name = "TEXT"
    label.Parent = esp
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = beeType
    label.TextColor3 = Color3.new(r/255, g/255, b/255)
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true

    return esp, label
end

local ui = {
    background = Color3.fromRGB(16, 27, 45),
    topbar = Color3.fromRGB(29, 52, 84),
    list = Color3.fromRGB(10, 17, 28),
    notification = Color3.fromRGB(23, 37, 58),
    primary = Color3.fromRGB(45, 98, 168),
    secondary = Color3.fromRGB(60, 140, 210),
    accent = Color3.fromRGB(96, 186, 240),
    input = Color3.fromRGB(214, 232, 248),
    text = Color3.fromRGB(240, 248, 255),
    dark = Color3.fromRGB(9, 20, 34),
    close = Color3.fromRGB(198, 40, 40),
    kill = Color3.fromRGB(196, 48, 48),
    killactive = Color3.fromRGB(122, 24, 24),
}

-- GUI Functions
local minimizegui = function(minimizeButton)
    local screenGui = minimizeButton.Parent.Parent.Parent

    local mainFrame = screenGui:FindFirstChild("MainFrame")
    local scrollFrame = mainFrame:FindFirstChild("NotificationContainer")
    local topBar = mainFrame:FindFirstChild("TopBar")
    local watermark = mainFrame:FindFirstChild("Watermark")

    if minimizeButton.Text == "-" then
        minimizeButton.Text = "+"
        mainFrame.Size = UDim2.new(0.25, 0, 0.09, 0)
        scrollFrame.Visible = false
        topBar.Size = UDim2.new(0.95, 0, 0.8, 0)
        topBar.Position = UDim2.new(0.5, 0, 0.06, 0)
        if watermark then
            watermark.Visible = false
        end
    else
        minimizeButton.Text = "-"
        mainFrame.Size = UDim2.new(0.25, 0, 0.6, 0)
        scrollFrame.Visible = true
        topBar.Size = UDim2.new(0.95, 0, 0.12, 0)
        topBar.Position = UDim2.new(0.5, 0, 0.01, 0)
        if watermark then
            watermark.Visible = true
        end
    end
end

local creategui = function()
    local CoreGui = Services.CoreGui or Services.Players.LocalPlayer.PlayerGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BeeHop"
    screenGui.Parent = CoreGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0.25, 0, 0.6, 0)
    mainFrame.Position = UDim2.new(0.1, 0, 0.4, 0)
    mainFrame.BackgroundColor3 = ui.background
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(0.95, 0, 0.12, 0)
    topBar.Position = UDim2.new(0.5, 0, 0.01, 0)
    topBar.BackgroundColor3 = ui.topbar
    topBar.BorderSizePixel = 0
    topBar.Active = true
    topBar.AnchorPoint = Vector2.new(0.5, 0)
    topBar.Parent = mainFrame

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "NotificationContainer"
    scrollFrame.Size = UDim2.new(0.95, 0, 0.79, 0)
    scrollFrame.Position = UDim2.new(0.5, 0, 0.14, 0)
    scrollFrame.AnchorPoint = Vector2.new(0.5, 0)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.BackgroundColor3 = ui.list
    scrollFrame.BorderSizePixel = 0
    scrollFrame.Parent = mainFrame

    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.Name = "UIList"
    uiListLayout.Padding = UDim.new(0, 5)
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Parent = scrollFrame

    local closeGUI = Instance.new("TextButton")
    closeGUI.Name = "CloseGUI"
    closeGUI.Size = UDim2.new(0.07, 0, 0.4, 0)
    closeGUI.Position = UDim2.new(0.02, 0, 0.25, 0)
    closeGUI.BackgroundColor3 = ui.close
    closeGUI.Text = "X"
    closeGUI.TextColor3 = ui.text
    closeGUI.TextScaled = true
    closeGUI.Font = Enum.Font.SourceSans
    closeGUI.AnchorPoint = Vector2.new(0, 0.5)
    closeGUI.Parent = topBar
    closeGUI.Selectable = false

    local hop_btn = Instance.new("TextButton")
    hop_btn.Name = "ServerHop"
    hop_btn.Size = UDim2.new(0.25, 0, 0.4, 0)
    hop_btn.Position = UDim2.new(0.12, 0, 0.25, 0)
    hop_btn.BackgroundColor3 = ui.primary
    hop_btn.Text = "Server Hop"
    hop_btn.TextColor3 = ui.text
    hop_btn.TextScaled = true
    hop_btn.Font = Enum.Font.SourceSans
    hop_btn.AnchorPoint = Vector2.new(0, 0.5)
    hop_btn.Parent = topBar
    hop_btn.Selectable = false

    local rescan_btn = Instance.new("TextButton")
    rescan_btn.Name = "Rescan"
    rescan_btn.Size = UDim2.new(0.2, 0, 0.4, 0)
    rescan_btn.Position = UDim2.new(0.39, 0, 0.25, 0)
    rescan_btn.BackgroundColor3 = ui.secondary
    rescan_btn.Text = "Rescan"
    rescan_btn.TextColor3 = ui.text
    rescan_btn.TextScaled = true
    rescan_btn.Font = Enum.Font.SourceSans
    rescan_btn.AnchorPoint = Vector2.new(0, 0.5)
    rescan_btn.Parent = topBar
    rescan_btn.Selectable = false

    local JobId_btn = Instance.new("TextButton")
    JobId_btn.Name = "JobId"
    JobId_btn.Size = UDim2.new(0.28, 0, 0.4, 0)
    JobId_btn.Position = UDim2.new(0.61, 0, 0.25, 0)
    JobId_btn.BackgroundColor3 = ui.primary
    JobId_btn.Text = "Copy JobId"
    JobId_btn.TextColor3 = ui.text
    JobId_btn.TextScaled = true
    JobId_btn.Font = Enum.Font.SourceSans
    JobId_btn.AnchorPoint = Vector2.new(0, 0.5)
    JobId_btn.Parent = topBar
    JobId_btn.Selectable = false

    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "minimizeButton"
    minimizeButton.Size = UDim2.new(0.07, 0, 0.4, 0)
    minimizeButton.Position = UDim2.new(0.91, 0, 0.25, 0)
    minimizeButton.BackgroundColor3 = ui.accent
    minimizeButton.Text = "-"
    minimizeButton.TextColor3 = ui.dark
    minimizeButton.TextScaled = true
    minimizeButton.Font = Enum.Font.SourceSans
    minimizeButton.AnchorPoint = Vector2.new(0, 0.5)
    minimizeButton.Parent = topBar
    minimizeButton.Selectable = false

    local JobIdBox = Instance.new("TextBox")
    JobIdBox.Name = "JobIdBox"
    JobIdBox.Size = UDim2.new(0.7, 0, 0.4, 0)
    JobIdBox.Position = UDim2.new(0.02, 0, 0.75, 0)
    JobIdBox.BackgroundColor3 = ui.input
    JobIdBox.TextColor3 = ui.dark
    JobIdBox.TextScaled = true
    JobIdBox.Font = Enum.Font.SourceSans
    JobIdBox.Text = "Input JobId"
    JobIdBox.PlaceholderText = "Input JobId"
    JobIdBox.AnchorPoint = Vector2.new(0, 0.5)
    JobIdBox.Parent = topBar

    local TPJobId = Instance.new("TextButton")
    TPJobId.Name = "TPJobId"
    TPJobId.Size = UDim2.new(0.24, 0, 0.4, 0)
    TPJobId.Position = UDim2.new(0.74, 0, 0.75, 0)
    TPJobId.BackgroundColor3 = ui.secondary
    TPJobId.Text = "Goto JobId"
    TPJobId.TextColor3 = ui.text
    TPJobId.TextScaled = true
    TPJobId.Font = Enum.Font.SourceSans
    TPJobId.AnchorPoint = Vector2.new(0, 0.5)
    TPJobId.Parent = topBar
    TPJobId.Selectable = false

    local watermark = Instance.new("TextLabel")
    watermark.Name = "Watermark"
    watermark.Size = UDim2.new(0.95, 0, 0.04, 0)
    watermark.Position = UDim2.new(0.5, 0, 0.945, 0)
    watermark.AnchorPoint = Vector2.new(0.5, 0)
    watermark.BackgroundTransparency = 1
    watermark.BorderSizePixel = 0
    watermark.Text = "BeeHop by Penguin - " .. version
    watermark.TextColor3 = ui.accent
    watermark.TextScaled = true
    watermark.Font = Enum.Font.GothamBold
    watermark.Parent = mainFrame

    -- Button click events
    closeGUI.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    hop_btn.MouseButton1Click:Connect(function()
        teleport(game.PlaceId)
    end)

    rescan_btn.MouseButton1Click:Connect(function()
        notifygui("Rescanning", 96, 186, 240)
        scan()
    end)

    JobId_btn.MouseButton1Click:Connect(function()
        setclipboard(game.JobId)
        notifygui("Copied JobId", 170, 215, 245)
    end)

    minimizeButton.MouseButton1Click:Connect(function()
        minimizegui(minimizeButton)
    end)

    TPJobId.MouseButton1Click:Connect(function()
        notifygui("TPing to JobId", 170, 215, 245)
        Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, JobIdBox.Text, Services.Players.LocalPlayer)
    end)

    return screenGui
end

local ensuregui = function()
    local CoreGui = Services.CoreGui or Services.Players.LocalPlayer.PlayerGui
    return CoreGui:FindFirstChild("BeeHop") or creategui()
end

local createframe = function()
    local screenGui = ensuregui()

    local mainFrame = screenGui:FindFirstChild("MainFrame")
    local scrollFrame = mainFrame:FindFirstChild("NotificationContainer")
    local uiListLayout = scrollFrame:FindFirstChild("UIList")
    
    local frame = Instance.new("Frame")
    frame.Name = "NotificationFrame"
    frame.Size = UDim2.new(1, 0, 0, camera.ViewportSize.Y * 0.05)
    frame.BackgroundColor3 = ui.notification
    frame.BorderSizePixel = 0
    frame.Parent = scrollFrame
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y)
    
    return frame
end

notifygui = function(text, r, g, b)
    text = tostring(text)
    if not r then r = 255 end
    if not g then g = 255 end
    if not b then b = 255 end
    print(text)
    
    local frame = createframe()
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0.06, 0, 0.4, 0)
    closeButton.Position = UDim2.new(0.015, 0, 0.3, 0)
    closeButton.BackgroundColor3 = ui.close
    closeButton.Text = "X"
    closeButton.TextColor3 = ui.text
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.SourceSans
    closeButton.Parent = frame
    closeButton.Selectable = false
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "NotificationText"
    textLabel.Size = UDim2.new(0.9, 0, 1, 0)
    textLabel.Position = UDim2.new(0.1, 0, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = Color3.new(r/255, g/255, b/255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSans
    textLabel.Parent = frame
    
    closeButton.MouseButton1Click:Connect(function()
        frame:Destroy()
    end)
    
    return frame, textLabel
end

local addButton = function(frame, name, text, color, x, width)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(width, 0, 0.7, 0)
    button.Position = UDim2.new(x, 0, 0.15, 0)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = ui.text
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.Parent = frame
    button.Selectable = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button

    return button
end

local attachESP = function(beeModel, beeType, r, g, b)
    if not beeModel then return end
    if beeModel:IsA("BasePart") then
        return createESP(beeModel, beeType, r, g, b)
    end
    return createESP(beeModel.PrimaryPart or beeModel:FindFirstChildWhichIsA("BasePart"), beeType, r, g, b)
end

local tpTo = function(beeModel, x, y, z)
    local modelPos = getPosition(beeModel)
    if modelPos then
        pcall(tpc, modelPos + Vector3.new(x or 0, y or 0, z or 0))
    end
end

local isGone = function(beeModel)
    if not beeModel or not beeModel.Parent then return true end
    local humanoid = beeModel:IsA("Model") and beeModel:FindFirstChildWhichIsA("Humanoid") or nil
    if humanoid and humanoid.Health <= 0 then return true end
    return false
end

local floatBV = nil

local setFloat = function(state)
    local character = Services.Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not state then
        if floatBV then
            floatBV:Destroy()
            floatBV = nil
        end
        if humanoid then
            humanoid.PlatformStand = false
        end
        game.Workspace.Gravity = defaultGravity
        return
    end

    if not humanoid or not root then return end

    humanoid.PlatformStand = true
    game.Workspace.Gravity = 0

    if not floatBV or floatBV.Parent ~= root then
        if floatBV then
            floatBV:Destroy()
        end
        floatBV = Instance.new("BodyVelocity")
        floatBV.Velocity = Vector3.new(0, 0, 0)
        floatBV.Parent = root
    end
end

local notifyMissing = function(beeType)
    notifygui((beeType or "Target") .. " does not exist anymore", 255, 153, 0)
end

local tpToBee = function(beeModel, beeType)
    if isGone(beeModel) then
        notifyMissing(beeType)
        return
    end
    tpTo(beeModel)
end

local watchVicious = function(beeModel)
    task.spawn(function()
        while not isGone(beeModel) do
            task.wait(0.25)
        end
        notifygui("Vicious killed", 96, 186, 240)
        task.wait(1)
        scan()
    end)
end

notifyBee = function(text, r, g, b, beeType, beeModel, isWindy)
    text = tostring(text)

    local frame, textLabel = notifygui(text, r, g, b)
    textLabel.Size = UDim2.new(0.62, 0, 1, 0)

    local espButton = addButton(frame, "ESPButton", "ESP", ui.secondary, 0.73, 0.12)
    espButton.MouseButton1Click:Connect(function()
        if isWindy and npcBees and npcBees:FindFirstChild("Windy") then
            local esp, label = createESP(npcBees:FindFirstChild("Windy"), beeType, r, g, b)

            task.spawn(function()
                while esp and esp.Parent do
                    local monsterWindy
                    for _, monster in pairs(monsters:GetChildren()) do
                        if string.find(monster.Name, "Windy Bee") then
                            monsterWindy = monster
                            break
                        end
                    end
                    if monsterWindy then
                        label.Text = monsterWindy.Name
                    else
                        label.Text = "Windy (Inactive)"
                    end
                    task.wait(0.5)
                end
            end)
        else
            attachESP(beeModel, beeType, r, g, b)
        end
    end)

    local tpButton = addButton(frame, "TPButton", "TP", ui.accent, 0.86, 0.12)
    tpButton.MouseButton1Click:Connect(function()
        local windy = isWindy and npcBees and npcBees:FindFirstChild("Windy")
        if windy then
            tpTo(windy)
        else
            tpToBee(beeModel, beeType)
        end
    end)

    return frame, textLabel
end

local notifyVicious = function(text, r, g, b, beeType, beeModel)
    text = tostring(text)

    local frame, textLabel = notifygui(text, r, g, b)
    textLabel.Size = UDim2.new(0.55, 0, 1, 0)

    local espButton = addButton(frame, "ESPButton", "ESP", ui.secondary, 0.66, 0.13)
    espButton.MouseButton1Click:Connect(function()
        attachESP(beeModel, beeType, r, g, b)
    end)

    local killButton = addButton(frame, "KillButton", "KILL", ui.kill, 0.81, 0.17)

    local killing = false
    local setKill
    setKill = function(state)
        if state == killing then return end
        killing = state

        if not killing then
            killButton.Text = "KILL"
            killButton.BackgroundColor3 = ui.kill
            return
        end

        killButton.Text = "STOP"
        killButton.BackgroundColor3 = ui.killactive

        task.spawn(function()
            while killing and frame.Parent and not isGone(beeModel) do
                setFloat(true)
                tpTo(beeModel, 10, 5, 0)
                task.wait()
            end

            setFloat(false)
            killing = false
            if killButton.Parent then
                killButton.Text = "KILL"
                killButton.BackgroundColor3 = ui.kill
            end
        end)
    end

    killButton.MouseButton1Click:Connect(function()
        if not killing and isGone(beeModel) then
            notifyMissing(beeType)
            return
        end
        setKill(not killing)
    end)

    return frame, textLabel, setKill
end

local sproutTypes = {
    {name = "Normal", r = 180, g = 190, b = 186},
    {name = "Rare", r = 168, g = 167, b = 169},
    {name = "Moon", r = 103, g = 162, b = 201},
    {name = "Gummy", r = 242, g = 129, b = 255},
    {name = "Epic", r = 169, g = 157, b = 5},
    {name = "Legendary", r = 20, g = 165, b = 199},
    {name = "Supreme", r = 71, g = 255, b = 88}
}

local getSproutType = function(sprout)
    local color = sprout.Color
    local r = math.floor(color.R * 255 + 0.5)
    local g = math.floor(color.G * 255 + 0.5)
    local b = math.floor(color.B * 255 + 0.5)

    for _, sproutType in ipairs(sproutTypes) do
        if sproutType.r == r and sproutType.g == g and sproutType.b == b then
            return sproutType.name, sproutType.r, sproutType.g, sproutType.b
        end
    end

    return "Unknown", 124, 252, 0
end

local sproutAllowed = function(sproutType)
    if sproutType == "Unknown" or not config.sproutList then return true end
    return config.sproutList[sproutType] == true
end

local viciousLevel = function(name)
    return tonumber(string.match(name, "%(Lvl%s*(%d+)%)"))
end

local viciousAllowed = function(vicious)
    if config.giftedViciousOnly and not string.find(vicious.Name, "Gifted") then
        return false
    end

    local level = viciousLevel(vicious.Name)
    if not level then return true end

    return level >= config.vicMinLevel and level <= config.vicMaxLevel
end

-- Main conditions
local conditionsMain = function()
    local conditions = {}
    for _, monster in pairs(monsters and monsters:GetChildren() or {}) do
        if string.find(monster.Name, "Windy Bee") then
            conditions.windy = monster
            break
        end
    end

    for _, monster in pairs(monsters and monsters:GetChildren() or {}) do
        if string.find(monster.Name, "Vicious Bee") then
            conditions.vicious = monster
            break
        end
    end
    if not conditions.windy then
        conditions.windy = npcBees and npcBees:FindFirstChild("Windy") or nil 
    end
    if not conditions.vicious then
        conditions.vicious = npcBees and npcBees:FindFirstChild("Vicious") or nil
    end

    for _, monster in pairs(monsters and monsters:GetChildren() or {}) do
        if string.find(monster.Name, "Stick Bug") then
            conditions.stickbug = monster
            break
        end
    end

    local puffshrooms = happenings and happenings:FindFirstChild("Puffshrooms")
    if puffshrooms and #puffshrooms:GetChildren() > 1 then
        conditions.puffshroom = puffshrooms
    end

    local sproutFolder = sprouts or game.Workspace:FindFirstChild("Sprouts")
    if sproutFolder then
        local found = {}
        for _, child in pairs(sproutFolder:GetChildren()) do
            local sprout
            if child:IsA("BasePart") and child.Name == "Sprout" then
                sprout = child
            else
                sprout = child:FindFirstChild("Sprout", true)
            end
            if sprout and sprout:IsA("BasePart") then
                table.insert(found, sprout)
            end
        end
        if #found > 0 then
            conditions.sprouts = found
        end
    end

    return conditions
end

-- Hub conditions
local conditionsHub = function()
    local conditions = {}
    return conditions
end

scan = function()
    desiredserver = false
    viciousKill = nil
    viciousModel = nil

    local conditions
    if game.PlaceId == data.placeids.main then
        conditions = conditionsMain()
    elseif game.PlaceId == data.placeids.hub then
        conditions = conditionsHub()
    else
        warn("[BeeHop] Invalid PlaceId during scan!")
        return
    end
    
    if config.stopList["Windy"] and conditions.windy then
        local zone = getClosestZone(conditions.windy)
        local inCloud = conditions.windy.Parent == npcBees
        -- Windy in cloud over Pepper Patch is unreachable (out of map) - ignore
        if not (inCloud and zone == "Pepper Patch") then
            local short = shortZone(zone)
            local suffix = short and (" - " .. short) or ""
            desiredserver = true
            if conditions.windy.Parent == monsters then
                notifyBee(conditions.windy.Name .. " active" .. suffix, 255, 200, 0, conditions.windy.Name, conditions.windy, true)
            elseif inCloud then
                notifyBee("Windy in cloud" .. suffix, 255, 200, 0, "Windy (Inactive)", conditions.windy, true)
            else
                notifyBee("Windy ??" .. suffix, 255, 200, 0, "Windy", conditions.windy, true)
            end
        end
    end

    if config.stopList["Vicious"] and conditions.vicious and viciousAllowed(conditions.vicious) then
        desiredserver = true
        local r, g, b = 255, 80, 80
        if string.find(conditions.vicious.Name, "Gifted") then
            r, g, b = 255, 200, 0
        end
        local _, _, setKill = notifyVicious(conditions.vicious.Name .. zoneSuffix(conditions.vicious), r, g, b, conditions.vicious.Name, conditions.vicious)
        viciousKill = setKill
        viciousModel = conditions.vicious
    end

    if config.stopList["StickBug"] and conditions.stickbug then
        desiredserver = true
        notifyBee(conditions.stickbug.Name .. zoneSuffix(conditions.stickbug), 255, 165, 0, conditions.stickbug.Name, conditions.stickbug)
    end

    if config.stopList["Puffshroom"] and conditions.puffshroom then
        desiredserver = true
        local puffZones, seen = {}, {}
        for _, puff in pairs(conditions.puffshroom:GetChildren()) do
            local zone = shortZone(getClosestZone(puff))
            if zone and not seen[zone] then
                seen[zone] = true
                table.insert(puffZones, zone)
            end
        end
        local suffix = #puffZones > 0 and (" - " .. table.concat(puffZones, ", ")) or ""
        notifygui("Puffshrooms  (" .. #conditions.puffshroom:GetChildren() .. ")" .. suffix, 139, 69, 19)
    end

    if config.stopList["Sprout"] and conditions.sprouts then
        for _, sprout in pairs(conditions.sprouts) do
            local sproutType, r, g, b = getSproutType(sprout)
            if sproutAllowed(sproutType) then
                desiredserver = true
                local label = sproutType .. " Sprout"
                notifyBee(label .. zoneSuffix(sprout), r, g, b, label, sprout)
            end
        end
    end

    if not desiredserver then
        notifygui("Nothing found", 255, 153, 0)
        if config.autohop then
            task.spawn(function()
                notifygui("Autohopping", 60, 140, 210)
                teleport(game.PlaceId)
            end)
        end
    end
end

local claimAttempts = 5
local claimWait = 1
local walkTimeout = 15
local moveRefresh = 4
local walkPoll = 0.25
local arriveDistance = 4

local getMover = function()
    local character = Services.Players.LocalPlayer.Character
    if not character then return nil, nil end
    return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

local walkTo = function(target)
    if typeof(target) == "CFrame" then
        target = target.Position
    end
    if typeof(target) ~= "Vector3" then return false end

    local started = os.clock()
    local issued = -math.huge
    while os.clock() - started < walkTimeout do
        local humanoid, root = getMover()
        if not humanoid or not root then
            task.wait(walkPoll)
        else
            local offset = target - root.Position
            if Vector3.new(offset.X, 0, offset.Z).Magnitude <= arriveDistance then
                humanoid:MoveTo(root.Position)
                return true
            end

            if os.clock() - issued >= moveRefresh then
                issued = os.clock()
                humanoid:MoveTo(target)
            end

            task.wait(walkPoll)
        end
    end

    local humanoid, root = getMover()
    if humanoid and root then
        humanoid:MoveTo(root.Position)
    end

    return false
end

local claimHive
claimHive = function(attempt)
    local getHives = function()
        local folder = game.Workspace:FindFirstChild("Honeycombs")
        if not folder then return {} end
    
        local hives = {}
        for _, model in ipairs(folder:GetChildren()) do
            local id = model:FindFirstChild("HiveID")
            local owner = model:FindFirstChild("Owner")
            local spawnPos = model:FindFirstChild("SpawnPos")
            if id and owner and spawnPos then
                table.insert(hives, {
                    model = model,
                    id = id.Value,
                    owner = owner,
                    spawn = spawnPos
                })
            end
        end
    
        table.sort(hives, function(a, b)
            return a.id > b.id
        end)
    
        return hives
    end
    
    local ownedHive = function(hives)
        for _, hive in ipairs(hives or getHives()) do
            if hive.owner.Value == Services.Players.LocalPlayer then
                return hive
            end
        end
        return nil
    end
    
    local firstUnclaimed = function(hives)
        for _, hive in ipairs(hives or getHives()) do
            if hive.owner.Value == nil then
                return hive
            end
        end
        return nil
    end

    attempt = attempt or 1

    if attempt > claimAttempts then
        notifygui("Could not claim a hive", 255, 153, 0)
        return false
    end

    local events = Services.ReplicatedStorage:FindFirstChild("Events")
    local claimEvent = events and events:FindFirstChild("ClaimHive")
    if not claimEvent then
        warn("[BeeHop] ClaimHive event missing")
        return false
    end

    local hives = getHives()
    if #hives == 0 then
        warn("[BeeHop] No honeycombs found")
        return false
    end

    local mine = ownedHive(hives)
    if mine then
        print("[BeeHop] Already own Hive " .. tostring(mine.id))
        return true, mine
    end

    local target = firstUnclaimed(hives)
    if not target then
        notifygui("No unclaimed hives", 255, 153, 0)
        return false
    end

    notifygui("Claiming Hive " .. tostring(target.id), 120, 200, 250)

    if not walkTo(target.spawn.Value) then
        return claimHive(attempt + 1)
    end

    claimEvent:FireServer(target.id)
    task.wait(claimWait)

    local claimed = ownedHive()
    if claimed then
        print("[BeeHop] Claimed Hive " .. tostring(claimed.id))
        return true, claimed
    end

    return claimHive(attempt + 1)
end

-- Initialize
print("[BeeHop] BeeHop by Penguin - " .. version)
ensuregui()

if newversion then
    notifygui(updmsg .. " - " .. version, 96, 186, 240)
    for line in string.gmatch(changelog, "[^\n]+") do
        notifygui(line, 170, 215, 245)
    end
    if settingchanged then
        notifygui("New settings", 96, 186, 240)
        for line in string.gmatch(settingmsg, "[^\n]+") do
            notifygui(line, 170, 215, 245)
        end
    end
end

scan()

if config.autoClaimHive and desiredserver and game.PlaceId == data.placeids.main then
    task.spawn(function()
        if not isLoaded() then
            print("[BeeHop] Waiting for load completely")
        end
        repeat
            task.wait(0.5)
        until isLoaded()

        if claimHive() and config.fullAutoVic and viciousKill and viciousModel then
            watchVicious(viciousModel)
            viciousKill(true)
        end
    end)
end

print("[BeeHop] Loaded!")
