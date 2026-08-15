-- BeeHop by Penguin!
-- https://discord.gg/BeeHop

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
local version = "1.1.1"
local versid = "hjxvmqpzlc"
local updmsg = "Update"
local changelog = "+Added Sprouts\n+Added Sprout type filters\n+Added Gifted Vicious only\n+Flower zone display"
local settingchanged = true
local settingmsg = "+Sprouts/Sprout types\n+Gifted Vicious only"
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
    defaultConfig = {
        autoscan = true,
        autohop = false,
        -- autowebhook = false,
        -- webhookUrl = "https://discord.com/api/webhooks/#/#",
        prioritizeSmallServer = false,
        giftedViciousOnly = false,
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

    if not writefile then return end

    if not isfile("BeeHop/config.json") and writefile then
        if not isfolder("BeeHop") then
            makefolder("BeeHop")
        end
        writefile("BeeHop/config.json", Services.HttpService:JSONEncode(data.defaultConfig))
    end

    if not string.match(config.versid or "", data.versid) then
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


loadConfig()

print("[BeeHop] Loading")

local desiredserver = false
local camera = game.Workspace.CurrentCamera

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
        notifygui("Waiting for load completely", 255, 255, 255)
    end
    repeat
        task.wait(0.5)
    until isLoaded()
    notifygui("Teleporting", 22, 209, 242)
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
	removeESP(part)
	if not part then return end
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

-- GUI Functions
local minimizegui = function(minimizeButton)
    local screenGui = minimizeButton.Parent.Parent.Parent

    local mainFrame = screenGui:FindFirstChild("MainFrame")
    local scrollFrame = mainFrame:FindFirstChild("NotificationContainer")
    local topBar = mainFrame:FindFirstChild("TopBar")

    if minimizeButton.Text == "-" then
        minimizeButton.Text = "+"
        mainFrame.Size = UDim2.new(0.25, 0, 0.09, 0)
        scrollFrame.Visible = false
        topBar.Size = UDim2.new(0.95, 0, 0.8, 0)
        topBar.Position = UDim2.new(0.5, 0, 0.06, 0)
    else
        minimizeButton.Text = "-"
        mainFrame.Size = UDim2.new(0.25, 0, 0.6, 0)
        scrollFrame.Visible = true
        topBar.Size = UDim2.new(0.95, 0, 0.12, 0)
        topBar.Position = UDim2.new(0.5, 0, 0.01, 0)
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
    mainFrame.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(0.95, 0, 0.12, 0)
    topBar.Position = UDim2.new(0.5, 0, 0.01, 0)
    topBar.BackgroundColor3 = Color3.fromRGB(140, 140, 140)
    topBar.BorderSizePixel = 0
    topBar.Active = true
    topBar.AnchorPoint = Vector2.new(0.5, 0)
    topBar.Parent = mainFrame

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "NotificationContainer"
    scrollFrame.Size = UDim2.new(0.95, 0, 0.84, 0)
    scrollFrame.Position = UDim2.new(0.5, 0, 0.14, 0)
    scrollFrame.AnchorPoint = Vector2.new(0.5, 0)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
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
    closeGUI.BackgroundColor3 = Color3.new(1, 0, 0)
    closeGUI.Text = "X"
    closeGUI.TextColor3 = Color3.new(1, 1, 1)
    closeGUI.TextScaled = true
    closeGUI.Font = Enum.Font.SourceSans
    closeGUI.AnchorPoint = Vector2.new(0, 0.5)
    closeGUI.Parent = topBar
    closeGUI.Selectable = false

    local hop_btn = Instance.new("TextButton")
    hop_btn.Name = "ServerHop"
    hop_btn.Size = UDim2.new(0.25, 0, 0.4, 0)
    hop_btn.Position = UDim2.new(0.12, 0, 0.25, 0)
    hop_btn.BackgroundColor3 = Color3.new(0, 1, 1)
    hop_btn.Text = "Server Hop"
    hop_btn.TextColor3 = Color3.new(0.3, 0.3, 0.3)
    hop_btn.TextScaled = true
    hop_btn.Font = Enum.Font.SourceSans
    hop_btn.AnchorPoint = Vector2.new(0, 0.5)
    hop_btn.Parent = topBar
    hop_btn.Selectable = false

    local rescan_btn = Instance.new("TextButton")
    rescan_btn.Name = "Rescan"
    rescan_btn.Size = UDim2.new(0.2, 0, 0.4, 0)
    rescan_btn.Position = UDim2.new(0.39, 0, 0.25, 0)
    rescan_btn.BackgroundColor3 = Color3.new(0.42, 0.75, 0.82)
    rescan_btn.Text = "Rescan"
    rescan_btn.TextColor3 = Color3.new(0, 0, 0)
    rescan_btn.TextScaled = true
    rescan_btn.Font = Enum.Font.SourceSans
    rescan_btn.AnchorPoint = Vector2.new(0, 0.5)
    rescan_btn.Parent = topBar
    rescan_btn.Selectable = false

    local JobId_btn = Instance.new("TextButton")
    JobId_btn.Name = "JobId"
    JobId_btn.Size = UDim2.new(0.28, 0, 0.4, 0)
    JobId_btn.Position = UDim2.new(0.61, 0, 0.25, 0)
    JobId_btn.BackgroundColor3 = Color3.new(0.11, 0.81, 0.15)
    JobId_btn.Text = "Copy JobId"
    JobId_btn.TextColor3 = Color3.new(0, 0, 0)
    JobId_btn.TextScaled = true
    JobId_btn.Font = Enum.Font.SourceSans
    JobId_btn.AnchorPoint = Vector2.new(0, 0.5)
    JobId_btn.Parent = topBar
    JobId_btn.Selectable = false

    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "minimizeButton"
    minimizeButton.Size = UDim2.new(0.07, 0, 0.4, 0)
    minimizeButton.Position = UDim2.new(0.91, 0, 0.25, 0)
    minimizeButton.BackgroundColor3 = Color3.new(1, 0.93, 0)
    minimizeButton.Text = "-"
    minimizeButton.TextColor3 = Color3.new(0, 0, 0)
    minimizeButton.TextScaled = true
    minimizeButton.Font = Enum.Font.SourceSans
    minimizeButton.AnchorPoint = Vector2.new(0, 0.5)
    minimizeButton.Parent = topBar
    minimizeButton.Selectable = false

    local JobIdBox = Instance.new("TextBox")
    JobIdBox.Name = "JobIdBox"
    JobIdBox.Size = UDim2.new(0.7, 0, 0.4, 0)
    JobIdBox.Position = UDim2.new(0.02, 0, 0.75, 0)
    JobIdBox.BackgroundColor3 = Color3.new(0.93, 0.63, 1)
    JobIdBox.TextColor3 = Color3.new(0, 0, 0)
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
    TPJobId.BackgroundColor3 = Color3.new(0.57, 0.92, 0.63)
    TPJobId.Text = "Goto JobId"
    TPJobId.TextColor3 = Color3.new(0, 0, 0)
    TPJobId.TextScaled = true
    TPJobId.Font = Enum.Font.SourceSans
    TPJobId.AnchorPoint = Vector2.new(0, 0.5)
    TPJobId.Parent = topBar
    TPJobId.Selectable = false

    -- Button click events
    closeGUI.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    hop_btn.MouseButton1Click:Connect(function()
        teleport(game.PlaceId)
    end)

    rescan_btn.MouseButton1Click:Connect(function()
        notifygui("Rescanning", 107, 191, 209)
        scan()
    end)

    JobId_btn.MouseButton1Click:Connect(function()
        setclipboard(game.JobId)
        notifygui("Copied JobId", 255, 255, 255)
    end)

    minimizeButton.MouseButton1Click:Connect(function()
        minimizegui(minimizeButton)
    end)

    TPJobId.MouseButton1Click:Connect(function()
        notifygui("TPing to JobId", 255, 255, 255)
        Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, JobIdBox.Text, Services.Players.LocalPlayer)
    end)

    return screenGui
end

local createframe = function()
    local CoreGui = Services.CoreGui or Services.Players.LocalPlayer.PlayerGui
    local screenGui = CoreGui:FindFirstChild("BeeHop")
    
    if not screenGui then
        screenGui = creategui()
    end
    
    local mainFrame = screenGui:FindFirstChild("MainFrame")
    local scrollFrame = mainFrame:FindFirstChild("NotificationContainer")
    local uiListLayout = scrollFrame:FindFirstChild("UIList")
    
    local frame = Instance.new("Frame")
    frame.Name = "NotificationFrame"
    frame.Size = UDim2.new(1, 0, 0, camera.ViewportSize.Y * 0.05)
    frame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
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
    closeButton.BackgroundColor3 = Color3.new(1, 0, 0)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.new(1, 1, 1)
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

notifyBee = function(text, r, g, b, beeType, beeModel, isWindy)
    text = tostring(text)
    
    local frame, textLabel = notifygui(text, r, g, b)
    textLabel.Size = UDim2.new(0.62, 0, 1, 0)
    
    -- ESP button
    local espButton = Instance.new("TextButton")
    espButton.Name = "ESPButton"
    espButton.Size = UDim2.new(0.12, 0, 0.7, 0)
    espButton.Position = UDim2.new(0.73, 0, 0.15, 0)
    espButton.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
    espButton.Text = "ESP"
    espButton.TextColor3 = Color3.new(1, 1, 1)
    espButton.TextScaled = true
    espButton.Font = Enum.Font.GothamBold
    espButton.Parent = frame
    espButton.Selectable = false
    
    local espCorner = Instance.new("UICorner")
    espCorner.CornerRadius = UDim.new(0, 6)
    espCorner.Parent = espButton
    
    espButton.MouseButton1Click:Connect(function()
        if isWindy and npcBees:FindFirstChild("Windy") then
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
        elseif beeModel then
            if beeModel:IsA("BasePart") then
                createESP(beeModel, beeType, r, g, b)
            else
                createESP(beeModel.PrimaryPart, beeType, r, g, b)
            end
        end
    end)
    
    -- TP button
    local tpButton = Instance.new("TextButton")
    tpButton.Name = "TPButton"
    tpButton.Size = UDim2.new(0.12, 0, 0.7, 0)
    tpButton.Position = UDim2.new(0.86, 0, 0.15, 0)
    tpButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.8)
    tpButton.Text = "TP"
    tpButton.TextColor3 = Color3.new(1, 1, 1)
    tpButton.TextScaled = true
    tpButton.Font = Enum.Font.GothamBold
    tpButton.Parent = frame
    tpButton.Selectable = false
    
    local tpCorner = Instance.new("UICorner")
    tpCorner.CornerRadius = UDim.new(0, 6)
    tpCorner.Parent = tpButton
    
    tpButton.MouseButton1Click:Connect(function()
        if isWindy and npcBees:FindFirstChild("Windy") then
            tpc(npcBees.Windy.Position + Vector3.new(0, 3, 0))
        elseif beeModel then
            local modelPos = getPosition(beeModel)
            if modelPos then
                tpc(modelPos + Vector3.new(0, 3, 0))
            end
        end
    end)
    
    return frame, textLabel
end

local sproutTypes = {
    {name = "Normal", r = 180, g = 190, b = 186},
    {name = "Rare", r = 168, g = 167, b = 169},
    {name = "Moon", r = 103, g = 162, b = 201},
    {name = "Gummy", r = 242, g = 129, b = 255},
    {name = "Epic", r = 169, g = 157, b = 5},
    {name = "Legendary", r = 20, g = 165, b = 199},
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
        -- Windy sitting in its cloud over Pepper Patch is unreachable, ignore it
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

    if config.stopList["Vicious"] and conditions.vicious
        and not (config.giftedViciousOnly and not string.find(conditions.vicious.Name, "Gifted")) then
        desiredserver = true
        notifyBee(conditions.vicious.Name .. " found" .. zoneSuffix(conditions.vicious), 255, 200, 0, conditions.vicious.Name, conditions.vicious)
    end

    if config.stopList["StickBug"] and conditions.stickbug then
        desiredserver = true
        notifyBee(conditions.stickbug.Name .. " found" .. zoneSuffix(conditions.stickbug), 255, 165, 0, conditions.stickbug.Name, conditions.stickbug)
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
        notifygui("Puffshrooms found (" .. #conditions.puffshroom:GetChildren() .. ")" .. suffix, 139, 69, 19)
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
                notifygui("Autohopping", 247, 94, 229)
                teleport(game.PlaceId)
            end)
        end
    end
end

-- Initialize
notifygui("BeeHop by Penguin - " .. version, 0, 247, 255)

if config.autoscan then
    scan()
end

print("[BeeHop] Loaded!")
