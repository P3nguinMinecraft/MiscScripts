repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local placeids = {
    main = 1537690962,
    hub = 15579077077,
    retro_challenge = 17579225831,
    retro_lobby = 17579226768
}

local function inBSS()
    for _, id in pairs(placeids) do
        if game.PlaceId == id then
            return true
        end
    end
    return false
end

if not inBSS() then
    return
end

local function isLoaded()
    return game:GetService("Players").LocalPlayer.PlayerGui.LoadingScreenGui.LoadingMessage.Visible == false
end

repeat task.wait(0.1) until isLoaded()

local names = {}

local methods = {}

function methods:getTable()
    return self
end

function methods:get(name)
    return rawget(self, name)
end

function methods:contains(name)
    return rawget(self, name) ~= nil
end

function methods:containsId(id)
    return names[id] ~= nil
end

function methods:getName(id)
    return names[id]
end

local tokens = setmetatable({}, {
    __index = methods,
    __newindex = function(self, name, id)
        if name == nil or id == nil then return end
        if names[id] then return end
        names[id] = name
        rawset(self, name, id)
    end
})

-- Hard code
tokens["Honey"] = "rbxassetid://1472135114"
tokens["Royal Jelly"] = "rbxassetid://1471882621"
tokens["Basic Egg"] = "rbxassetid://1471846464"

local eggs = require(ReplicatedStorage.EggTypes)

for _, egg in pairs(eggs:GetTypes()) do
    tokens[egg.DisplayName] = egg.Icon
end

for _, collectible in pairs(ReplicatedStorage.Collectibles:GetChildren()) do
    if collectible:IsA("ModuleScript") then
        local icon = collectible:FindFirstChild("Icon")
        if icon then
            tokens[collectible.Name] = icon.Texture
        end
    end
end

for _, buff in pairs(ReplicatedStorage.Buffs:GetChildren()) do
    if buff:IsA("Decal") then
        tokens[buff.Name:sub(1, -6)] = buff.Texture
    end
end

local removePickedUp = true
local destroyBalloons = false
local destroyParticles = false
local hideDecorations = false
local destroyHidden = false
local teleportOffset = Vector3.new(0, -3, 0)
local teleportDelay = 0.5
local teleportCooldown = 0.5

local decorationWhitelist = {
    "workspace.Decorations.Stump.Stump"
}

local espColor = Color3.fromRGB(255, 255, 255)
local espBackgroundColor = Color3.fromRGB(24, 26, 33)

local espFont = Enum.Font.SourceSansBold
local espTextSize = 14
local espPaddingX = 12
local espPaddingY = 6

local tokenNames = {}
for name in pairs(tokens) do
    table.insert(tokenNames, name)
end
table.sort(tokenNames)

local modes = { "None", "ESP", "Hide" }
local modeLabels = { None = "None", ESP = "ESP", Hide = "Hide" }

local function canTP(entry)
    return entry ~= nil and entry.tp == true and entry.mode ~= "Hide"
end

local function readPriority(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number then
        return fallback
    end
    return number
end

local modeExists = {}
for _, mode in ipairs(modes) do
    modeExists[mode] = true
end

local config = {}
local draft = {}

local function defaultEntry(name)
    return {
        mode = "None",
        tp = false,
        priority = 0,
        text = name,
        color = { math.floor(espColor.R * 255 + 0.5), math.floor(espColor.G * 255 + 0.5), math.floor(espColor.B * 255 + 0.5) },
        background = { math.floor(espBackgroundColor.R * 255 + 0.5), math.floor(espBackgroundColor.G * 255 + 0.5), math.floor(espBackgroundColor.B * 255 + 0.5) }
    }
end

local function getEntry(name)
    local entry = draft[name]
    if not entry then
        entry = defaultEntry(name)
        draft[name] = entry
    end
    return entry
end

local function copyEntry(entry)
    return {
        mode = entry.mode,
        tp = entry.tp,
        priority = entry.priority,
        text = entry.text,
        color = { entry.color[1], entry.color[2], entry.color[3] },
        background = { entry.background[1], entry.background[2], entry.background[3] }
    }
end

local function sameEntry(a, b)
    if a.mode ~= b.mode or a.text ~= b.text then return false end
    if a.tp ~= b.tp or a.priority ~= b.priority then return false end
    for index = 1, 3 do
        if a.color[index] ~= b.color[index] then return false end
        if a.background[index] ~= b.background[index] then return false end
    end
    return true
end

local function hasUnsavedChanges()
    for name, entry in pairs(draft) do
        if not sameEntry(entry, config[name] or defaultEntry(name)) then return true end
    end
    for name, entry in pairs(config) do
        if not draft[name] and not sameEntry(entry, defaultEntry(name)) then return true end
    end
    return false
end

local function applyDraft()
    table.clear(config)
    for name, entry in pairs(draft) do
        config[name] = copyEntry(entry)
    end
end

local HttpService = game:GetService("HttpService")

local configFolder = "BSScript"
local configFile = "BSScript/config.json"
local legacyConfigFile = "Tokens/config.json"

local canSaveConfig = writefile ~= nil and readfile ~= nil and isfile ~= nil and isfolder ~= nil and makefolder ~= nil

if not canSaveConfig then
    print("[BSScript] You cannot save configs because your executor does not support files!")
end

local function saveConfig()
    if not canSaveConfig then return false end

    local saved = {
        removePickedUp = removePickedUp,
        destroyBalloons = destroyBalloons,
        destroyParticles = destroyParticles,
        hideDecorations = hideDecorations,
        destroyHidden = destroyHidden,
        tokens = {}
    }
    for name, entry in pairs(config) do
        saved.tokens[name] = {
            mode = entry.mode,
            tp = entry.tp,
            priority = entry.priority,
            text = entry.text,
            color = { entry.color[1], entry.color[2], entry.color[3] },
            background = { entry.background[1], entry.background[2], entry.background[3] }
        }
    end

    local ok = pcall(function()
        if not isfolder(configFolder) then
            makefolder(configFolder)
        end
        writefile(configFile, HttpService:JSONEncode(saved))
    end)

    if not ok then
        warn("[BSScript] failed to save config")
    end

    return ok
end

local function readChannel(value, fallback)
    return math.clamp(math.floor(tonumber(value) or fallback), 0, 255)
end

local function loadConfig()
    if not canSaveConfig then
        return
    end

    local source = configFile
    if not isfile(source) then
        source = legacyConfigFile
        if not isfile(source) then
            return
        end
    end

    local ok, saved = pcall(function()
        return HttpService:JSONDecode(readfile(source))
    end)

    if not ok or type(saved) ~= "table" then
        warn("[BSScript] config is unreadable, starting empty")
        return
    end

    local storedRemovePickedUp = saved.removePickedUp
    if storedRemovePickedUp == nil then
        storedRemovePickedUp = saved.removeHidden
    end

    if type(storedRemovePickedUp) == "boolean" then
        removePickedUp = storedRemovePickedUp
    end

    if type(saved.destroyBalloons) == "boolean" then
        destroyBalloons = saved.destroyBalloons
    end

    if type(saved.destroyParticles) == "boolean" then
        destroyParticles = saved.destroyParticles
    end

    if type(saved.hideDecorations) == "boolean" then
        hideDecorations = saved.hideDecorations
    end

    if type(saved.destroyHidden) == "boolean" then
        destroyHidden = saved.destroyHidden
    end

    local storedTokens = type(saved.tokens) == "table" and saved.tokens or saved

    for name, stored in pairs(storedTokens) do
        if type(stored) ~= "table" then
            warn("[BSScript] skipped malformed config entry: " .. tostring(name))
        elseif not tokens:contains(name) then
            warn("[BSScript] skipped unknown token in config: " .. tostring(name))
        else
            local entry = getEntry(name)
            local defaults = defaultEntry(name)

            local storedMode = stored.mode
            local legacyTP = storedMode == "TP" or storedMode == "ESP+TP"
            if storedMode == "TP" then
                storedMode = "None"
            elseif storedMode == "ESP+TP" then
                storedMode = "ESP"
            end

            entry.mode = modeExists[storedMode] and storedMode or defaults.mode
            if type(stored.tp) == "boolean" then
                entry.tp = stored.tp
            else
                entry.tp = legacyTP
            end
            entry.priority = readPriority(stored.priority, defaults.priority)
            entry.text = type(stored.text) == "string" and stored.text ~= "" and stored.text or defaults.text

            for index = 1, 3 do
                entry.color[index] = readChannel(type(stored.color) == "table" and stored.color[index] or nil, defaults.color[index])
                entry.background[index] = readChannel(type(stored.background) == "table" and stored.background[index] or nil, defaults.background[index])
            end
        end
    end
end

loadConfig()
applyDraft()

local function toColor(rgb)
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function measure(text)
    local bounds = TextService:GetTextSize(text, espTextSize, espFont, Vector2.new(1024, 1024))
    return math.ceil(bounds.X) + espPaddingX, math.ceil(bounds.Y) + espPaddingY
end

getgenv().connections = getgenv().connections or {}
getgenv().esps = getgenv().esps or {}

local function removeESP(token)
    if typeof(token) ~= "Instance" or not token.Parent then return end
    local gui = token:FindFirstChild("ESP")
    if gui then
        gui:Destroy()
    end
end

local function clearESP()
    for _, token in pairs(getgenv().esps) do
        removeESP(token)
    end
    table.clear(getgenv().esps)
end

local function esp(obj, entry)
    if not obj then return end

    removeESP(obj)

    local width, height = measure(entry.text)

    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP"
    gui.Adornee = obj
    gui.Size = UDim2.fromOffset(width, height)
    gui.AlwaysOnTop = true
    gui.StudsOffset = Vector3.new(0, 2, 0)
    gui.Parent = obj

    local label = Instance.new("TextLabel")
    label.Name = "TEXT"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 0.5
    label.BackgroundColor3 = toColor(entry.background)
    label.Text = entry.text
    label.TextColor3 = toColor(entry.color)
    label.TextStrokeTransparency = 0.5
    label.Font = espFont
    label.TextSize = espTextSize
    label.Parent = gui

    if not table.find(getgenv().esps, obj) then
        table.insert(getgenv().esps, obj)
    end

    return gui, label
end

local function getRoot()
    local character = Players.LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

local function isCollectible(part)
    return part:IsA("Part") and part.Name == "C"
end

local function isToken(part)
    if not isCollectible(part) then return false end
    local transparency = part.Transparency
    return transparency < 0.69999 or transparency > 0.7
end

local function isPickedUp(token)
    return token.Orientation.Z > 0.01
end

local decalNames = { "BackDecal", "FrontDecal" }

local function tokenName(collectible)
    if not isCollectible(collectible) then return nil end
    local decal = collectible:FindFirstChild("FrontDecal")
    if not decal then return nil end
    return tokens:getName(decal.Texture)
end

local function tokenMode(collectible)
    local name = tokenName(collectible)
    if not name then return nil end
    local entry = config[name]
    if not entry then return nil end
    return entry.mode, entry
end

getgenv().hidden = getgenv().hidden or {}

local hidden = getgenv().hidden
local applyToken
local destroyToken

local function shouldHide(token)
    return isCollectible(token) and tokenMode(token) == "Hide"
end

local function restoreToken(token)
    local state = hidden[token]
    if not state then return end

    hidden[token] = nil

    if state.connection then
        state.connection:Disconnect()
    end

    if not token.Parent then return end

    token.Transparency = state.transparency
    for name, transparency in pairs(state.decals) do
        local decal = token:FindFirstChild(name)
        if decal then
            decal.Transparency = transparency
        end
    end
end

local function restoreAllHidden()
    for token in pairs(hidden) do
        restoreToken(token)
    end
    table.clear(hidden)
end

local function applyHidden(token, state)
    if token.Transparency < 1 then
        token.Transparency = 1
    end
    for _, name in ipairs(decalNames) do
        local decal = token:FindFirstChild(name)
        if decal then
            if state.decals[name] == nil then
                state.decals[name] = decal.Transparency
            end
            if decal.Transparency < 1 then
                decal.Transparency = 1
            end
        end
    end
end

local function hideToken(token)
    local state = hidden[token]
    if state then
        applyHidden(token, state)
        return
    end

    removeESP(token)

    state = { transparency = token.Transparency, decals = {} }
    hidden[token] = state
    applyHidden(token, state)

    state.connection = token:GetPropertyChangedSignal("Transparency"):Connect(function()
        if hidden[token] ~= state or token.Transparency >= 0.5 then return end
        if not shouldHide(token) then
            restoreToken(token)
            task.spawn(applyToken, token)
        elseif isPickedUp(token) or destroyHidden then
            destroyToken(token)
        else
            applyHidden(token, state)
        end
    end)
end

function destroyToken(token)
    local state = hidden[token]
    if state then
        if state.connection then
            state.connection:Disconnect()
        end
        hidden[token] = nil
    end
    removeESP(token)
    token:Destroy()
end

local function applyHideMode(token)
    if destroyHidden then
        destroyToken(token)
    else
        hideToken(token)
    end
end

function applyToken(collectible)
    if not isCollectible(collectible) then return end
    task.wait()
    if not collectible.Parent then return end
    if not isToken(collectible) then
        removeESP(collectible)
        return
    end
    local mode, entry = tokenMode(collectible)
    if isPickedUp(collectible) then
        if removePickedUp or mode == "Hide" then
            destroyToken(collectible)
        end
        return
    end
    if not mode or mode == "None" then
        removeESP(collectible)
        return
    end
    if mode == "Hide" then
        applyHideMode(collectible)
        return
    end
    if mode == "ESP" then
        esp(collectible, entry)
        return
    end
end

clearESP()

if getgenv().connections["tokensConnection"] then
    getgenv().connections["tokensConnection"]:Disconnect()
end

if getgenv().connections["tokenLoop"] then
    task.cancel(getgenv().connections["tokenLoop"])
end

if getgenv().connections["tokenTeleport"] then
    task.cancel(getgenv().connections["tokenTeleport"])
end

if getgenv().connections["tokenDrag"] then
    getgenv().connections["tokenDrag"]:Disconnect()
end

if getgenv().connections["tokenRemoved"] then
    getgenv().connections["tokenRemoved"]:Disconnect()
end

restoreAllHidden()

local spawnTimes = {}

local function tpReady(token)
    local spawned = spawnTimes[token]
    return spawned == nil or os.clock() - spawned >= teleportDelay
end

local collectibles = Workspace:WaitForChild("Collectibles")
getgenv().connections["tokensConnection"] = collectibles.ChildAdded:Connect(function(collectible)
    spawnTimes[collectible] = os.clock()
    applyToken(collectible)
end)
getgenv().connections["tokenRemoved"] = collectibles.ChildRemoved:Connect(function(collectible)
    spawnTimes[collectible] = nil
end)

local function applyAll()
    for _, collectible in ipairs(collectibles:GetChildren()) do
        if isToken(collectible) then
            task.spawn(applyToken, collectible)
        end
    end
end

getgenv().connections["tokenTeleport"] = task.spawn(function()
    while task.wait() do
        local root = getRoot()
        if root then
            local target, priority, distance
            for _, token in ipairs(collectibles:GetChildren()) do
                if isToken(token) and not isPickedUp(token) and tpReady(token) then
                    local _, entry = tokenMode(token)
                    if canTP(entry) then
                        local away = (token.Position - root.Position).Magnitude
                        if not target or entry.priority < priority or (entry.priority == priority and away < distance) then
                            target, priority, distance = token, entry.priority, away
                        end
                    end
                end
            end
            while target and target.Parent and not isPickedUp(target) and canTP(select(2, tokenMode(target))) do
                root = getRoot()
                if not root then break end
                root.CFrame = CFrame.new(target.Position + teleportOffset)
                task.wait()
            end
            if target then
                task.wait(teleportCooldown)
            end
        end
    end
end)

getgenv().connections["tokenLoop"] = task.spawn(function()
    while task.wait() do
        local list = getgenv().esps
        for i = #list, 1, -1 do
            local token = list[i]
            if typeof(token) ~= "Instance" or not token.Parent then
                table.remove(list, i)
            elseif isPickedUp(token) or token.Transparency > 0.99 then
                removeESP(token)
                table.remove(list, i)
            end
        end
        for token, state in pairs(hidden) do
            if not token.Parent then
                if state.connection then
                    state.connection:Disconnect()
                end
                hidden[token] = nil
            elseif not shouldHide(token) then
                restoreToken(token)
                task.spawn(applyToken, token)
            elseif isPickedUp(token) or destroyHidden then
                destroyToken(token)
            else
                applyHidden(token, state)
            end
        end

        for _, token in ipairs(collectibles:GetChildren()) do
            if isToken(token) then
                if isPickedUp(token) then
                    if removePickedUp or shouldHide(token) then
                        destroyToken(token)
                    end
                elseif shouldHide(token) then
                    applyHideMode(token)
                end
            end
        end
    end
end)

local theme = {
    background = Color3.fromRGB(22, 24, 30),
    panel = Color3.fromRGB(31, 34, 43),
    field = Color3.fromRGB(40, 44, 55),
    stroke = Color3.fromRGB(54, 58, 72),
    accent = Color3.fromRGB(97, 122, 247),
    text = Color3.fromRGB(233, 236, 245),
    muted = Color3.fromRGB(146, 152, 170)
}


local function new(class, props, parent)
    local instance = Instance.new(class)
    for key, value in pairs(props) do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

local function corner(parent, radius)
    new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent, color)
    new("UIStroke", { Color = color or theme.stroke, Thickness = 1 }, parent)
end

if getgenv().tokenGui then
    pcall(function()
        getgenv().tokenGui:Destroy()
    end)
end

local screen = Instance.new("ScreenGui")
screen.Name = "BSScript"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
getgenv().tokenGui = screen

if syn and syn.protect_gui then
    pcall(syn.protect_gui, screen)
end

local mounted = pcall(function()
    screen.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)

if not mounted then
    screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(360, 520),
    Position = UDim2.new(0.99, -360, 0.01, 0),
    BackgroundColor3 = theme.background,
    BorderSizePixel = 0
}, screen)
corner(main, 10)
stroke(main)

local headerFill = new("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.fromOffset(0, 24),
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    ZIndex = 1
}, main)

local header = new("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    ZIndex = 2
}, main)
corner(header, 10)

local titleLabel = new("TextLabel", {
    Size = UDim2.new(1, -214, 1, 0),
    Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "BSScript",
    TextSize = 15,
    TextColor3 = theme.text,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)

local function headerButton(text, width, offset)
    local button = new("TextButton", {
        Size = UDim2.fromOffset(width, 26),
        Position = UDim2.new(1, -offset, 0, 5),
        BackgroundColor3 = theme.field,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextSize = 12,
        TextColor3 = theme.text
    }, header)
    corner(button, 6)
    stroke(button)
    return button
end

local saveButton = headerButton("Save", 46, 198)
local reloadEspButton = headerButton("Reload ESP", 74, 146)
local minimizeButton = headerButton("-", 26, 66)
local closeButton = headerButton("X", 26, 34)

local body = new("ScrollingFrame", {
    Name = "Body",
    Size = UDim2.new(1, 0, 1, -36),
    Position = UDim2.fromOffset(0, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.stroke,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, main)

new("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12)
}, body)

new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder
}, body)

local statusWarn = Color3.fromRGB(240, 176, 86)
local statusGood = Color3.fromRGB(126, 209, 137)
local statusBad = Color3.fromRGB(232, 108, 108)

local footerFill = new("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -26),
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    ZIndex = 1,
    Visible = false
}, main)

local footer = new("TextLabel", {
    Name = "Footer",
    Size = UDim2.new(1, 0, 0, 26),
    Position = UDim2.new(0, 0, 1, -26),
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamMedium,
    Text = "Unsaved changes!",
    TextSize = 12,
    TextColor3 = statusWarn,
    ZIndex = 2,
    Visible = false
}, main)
corner(footer, 10)

local minimized = false
local statusMessage = nil
local statusColor = statusWarn
local statusId = 0

local function refreshUnsaved()
    local text, color

    if statusMessage then
        text, color = statusMessage, statusColor
    elseif hasUnsavedChanges() then
        text, color = "Unsaved changes!", statusWarn
    end

    local shown = text ~= nil and not minimized

    if text then
        footer.Text = text
        footer.TextColor3 = color
    end

    footer.Visible = shown
    footerFill.Visible = shown
    body.Size = UDim2.new(1, 0, 1, shown and -62 or -36)
end

local function setStatus(text, color)
    statusMessage = text
    statusColor = color
    statusId = statusId + 1

    local id = statusId
    refreshUnsaved()

    task.delay(1.6, function()
        if statusId ~= id or not footer.Parent then return end
        statusMessage = nil
        refreshUnsaved()
    end)
end

local contentWidth = 360 - 24 - 6

local function sectionLabel(text, order)
    return new("TextLabel", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextSize = 12,
        TextColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left
    }, body)
end

local function toggleRow(text, order, get, set, onLabel, offLabel)
    onLabel = onLabel or "On"
    offLabel = offLabel or "Off"

    local width = 48
    for _, label in ipairs({ onLabel, offLabel }) do
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(label, 12, Enum.Font.GothamMedium, Vector2.new(1024, 1024))
        end)
        if ok and bounds then
            width = math.max(width, math.ceil(bounds.X) + 16)
        end
    end

    local row = new("Frame", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = theme.panel,
        BorderSizePixel = 0
    }, body)
    corner(row)
    stroke(row)

    new("TextLabel", {
        Size = UDim2.new(1, -(width + 28), 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = text,
        TextSize = 12,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)

    local button = new("TextButton", {
        Size = UDim2.fromOffset(width, 22),
        Position = UDim2.new(1, -(width + 10), 0.5, -11),
        BackgroundColor3 = theme.field,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Font = Enum.Font.GothamMedium,
        Text = offLabel,
        TextSize = 12,
        TextColor3 = theme.muted
    }, row)
    corner(button, 5)
    stroke(button)

    local function refresh()
        local enabled = get()
        button.Text = enabled and onLabel or offLabel
        button.BackgroundColor3 = enabled and theme.accent or theme.field
        button.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or theme.muted
    end

    button.MouseButton1Click:Connect(function()
        set(not get())
        refresh()
    end)

    refresh()

    return refresh
end

local function createPurger(...)
    local path = { ... }
    local enabled = false
    local sweep
    local hook
    local hooked

    local function resolve()
        local node = Workspace
        for index = 1, #path do
            node = node:FindFirstChild(path[index])
            if not node then return nil end
        end
        return node
    end

    local function destroy(child)
        pcall(function()
            child:Destroy()
        end)
    end

    local function clear(target)
        for _, child in ipairs(target:GetChildren()) do
            destroy(child)
        end
    end

    local function unhook()
        if hook then
            hook:Disconnect()
            hook = nil
        end
        hooked = nil
    end

    local function step()
        local target = resolve()

        if target ~= hooked then
            unhook()
            if target then
                hooked = target
                hook = target.ChildAdded:Connect(function(child)
                    if enabled then
                        destroy(child)
                    end
                end)
            end
        end

        if target then
            clear(target)
        end
    end

    return function(value)
        enabled = value

        if sweep then
            sweep:Disconnect()
            sweep = nil
        end

        if not enabled then
            unhook()
            return
        end

        step()
        sweep = RunService.Heartbeat:Connect(step)
    end
end

local function splitPath(path)
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        if #parts > 0 or (part ~= "Workspace" and part ~= "workspace" and part ~= "game") then
            table.insert(parts, part)
        end
    end
    return parts
end

local function createStasher(name, stash, whitelist)
    local originalParent
    local moved
    local kept = {}

    local paths = {}
    for _, path in ipairs(whitelist or {}) do
        local parts = splitPath(path)
        if #parts > 1 and parts[1] == name then
            table.insert(paths, parts)
        end
    end

    local function resolve(parts)
        local node = Workspace
        for index = 1, #parts do
            node = node:FindFirstChild(parts[index])
            if not node then return nil end
        end
        return node
    end

    local function restoreKept()
        for _, entry in ipairs(kept) do
            if entry.instance.Parent and entry.parent.Parent then
                entry.instance.Parent = entry.parent
            end
        end
        table.clear(kept)
    end

    return function(enabled)
        if enabled then
            local target = Workspace:FindFirstChild(name)

            if not target then
                return
            end

            restoreKept()

            for _, parts in ipairs(paths) do
                local node = resolve(parts)
                if node and node.Parent and node ~= target then
                    table.insert(kept, { instance = node, parent = node.Parent })
                    node.Parent = Workspace
                end
            end

            originalParent = target.Parent
            moved = target

            target.Parent = stash
        else
            if moved and moved.Parent then
                moved.Parent = originalParent or Workspace
            end

            moved = nil
            originalParent = nil

            restoreKept()
        end
    end
end

if getgenv().connections["purgers"] then
    for _, setPurge in ipairs(getgenv().connections["purgers"]) do
        pcall(setPurge, false)
    end
end

local setBalloonPurge = createPurger("Balloons", "FieldBalloons")
local setParticlePurge = createPurger("Particles")

local setDecorationsStash = createStasher("Decorations", ReplicatedStorage, decorationWhitelist)
local setFieldDecosStash = createStasher("FieldDecos", ReplicatedStorage, decorationWhitelist)

local function setDecorationsHidden(enabled)
    setDecorationsStash(enabled)
    setFieldDecosStash(enabled)
end

getgenv().connections["purgers"] = {
    setBalloonPurge,
    setParticlePurge,
    setDecorationsHidden
}

toggleRow("Remove Picked Up", 0, function()
    return removePickedUp
end, function(value)
    removePickedUp = value
end)

toggleRow("Destroy Balloons", 1, function()
    return destroyBalloons
end, function(value)
    destroyBalloons = value
    setBalloonPurge(value)
end)

toggleRow("Destroy Particles", 2, function()
    return destroyParticles
end, function(value)
    destroyParticles = value
    setParticlePurge(value)
end)

toggleRow("Hide Decorations", 3, function()
    return hideDecorations
end, function(value)
    hideDecorations = value
    setDecorationsHidden(value)
end)

toggleRow("Hidden Tokens", 4, function()
    return destroyHidden
end, function(value)
    destroyHidden = value
    if value then
        for token in pairs(hidden) do
            if token.Parent then
                destroyToken(token)
            end
        end
    end
    applyAll()
end, "Destroy", "Transparent")

setBalloonPurge(destroyBalloons)
setParticlePurge(destroyParticles)
setDecorationsHidden(hideDecorations)

sectionLabel("Token", 5)

local selector = new("TextButton", {
    LayoutOrder = 6,
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = theme.field,
    BorderSizePixel = 0,
    AutoButtonColor = true,
    Font = Enum.Font.Gotham,
    Text = "  Select a token...",
    TextSize = 13,
    TextColor3 = theme.text,
    TextXAlignment = Enum.TextXAlignment.Left
}, body)
corner(selector)
stroke(selector)

new("TextLabel", {
    Size = UDim2.fromOffset(24, 32),
    Position = UDim2.new(1, -26, 0, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "v",
    TextSize = 12,
    TextColor3 = theme.muted
}, selector)

local dropdown = new("Frame", {
    LayoutOrder = 7,
    Size = UDim2.new(1, 0, 0, 208),
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    Visible = false
}, body)
corner(dropdown)
stroke(dropdown)

local search = new("TextBox", {
    Size = UDim2.new(1, -16, 0, 28),
    Position = UDim2.fromOffset(8, 8),
    BackgroundColor3 = theme.field,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    PlaceholderText = "Search tokens...",
    PlaceholderColor3 = theme.muted,
    Text = "",
    TextSize = 13,
    TextColor3 = theme.text,
    TextXAlignment = Enum.TextXAlignment.Left
}, dropdown)
corner(search)
stroke(search)

new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, search)

local list = new("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -48),
    Position = UDim2.fromOffset(8, 42),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.stroke,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, dropdown)

new("UIListLayout", {
    Padding = UDim.new(0, 2),
    SortOrder = Enum.SortOrder.LayoutOrder
}, list)

local modeTitle = sectionLabel("Mode", 8)
modeTitle.Visible = false

local modeRow = new("Frame", {
    LayoutOrder = 9,
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Visible = false
}, body)

new("UIListLayout", {
    Padding = UDim.new(0, 6),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder
}, modeRow)

local modeButtonWidth = math.floor((contentWidth - (#modes - 1) * 6) / #modes)

local tpRow = new("Frame", {
    LayoutOrder = 10,
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Visible = false
}, body)

local tpButton = new("TextButton", {
    Size = UDim2.fromOffset(modeButtonWidth, 30),
    BackgroundColor3 = theme.field,
    BorderSizePixel = 0,
    AutoButtonColor = true,
    Font = Enum.Font.GothamMedium,
    Text = "⚠ TP ⚠",
    TextSize = 12,
    TextColor3 = theme.muted
}, tpRow)
corner(tpButton)
stroke(tpButton)

local priorityLabel = new("TextLabel", {
    Size = UDim2.fromOffset(60, 30),
    Position = UDim2.fromOffset(modeButtonWidth + 12, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Text = "Priority",
    TextSize = 12,
    TextColor3 = theme.muted,
    TextXAlignment = Enum.TextXAlignment.Left,
    Visible = false
}, tpRow)

local priorityBox = new("TextBox", {
    Size = UDim2.new(1, -(modeButtonWidth + 76), 0, 30),
    Position = UDim2.fromOffset(modeButtonWidth + 76, 0),
    BackgroundColor3 = theme.field,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    Text = "0",
    TextSize = 13,
    TextColor3 = theme.text,
    Visible = false
}, tpRow)
corner(priorityBox)
stroke(priorityBox)

local espSection = new("Frame", {
    LayoutOrder = 11,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    Visible = false
}, body)
corner(espSection)
stroke(espSection)

new("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10)
}, espSection)

new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder
}, espSection)

new("TextLabel", {
    LayoutOrder = 1,
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Text = "Text",
    TextSize = 12,
    TextColor3 = theme.muted,
    TextXAlignment = Enum.TextXAlignment.Left
}, espSection)

local textBox = new("TextBox", {
    LayoutOrder = 2,
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = theme.field,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    Text = "",
    TextSize = 13,
    TextColor3 = theme.text,
    TextXAlignment = Enum.TextXAlignment.Left
}, espSection)
corner(textBox)
stroke(textBox)

new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, textBox)

local selected = nil
local updatePreview

local function currentEntry()
    if not selected then return nil end
    return getEntry(selected)
end

local function colorRow(order, title, key)
    local row = new("Frame", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1
    }, espSection)

    new("TextLabel", {
        Size = UDim2.fromOffset(110, 26),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Text = title,
        TextSize = 12,
        TextColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)

    local swatch = new("Frame", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -26, 0, 0),
        BackgroundColor3 = theme.field,
        BorderSizePixel = 0
    }, row)
    corner(swatch, 5)
    stroke(swatch)

    local boxes = {}
    for index = 1, 3 do
        local box = new("TextBox", {
            Size = UDim2.fromOffset(46, 26),
            Position = UDim2.fromOffset(112 + (index - 1) * 52, 0),
            BackgroundColor3 = theme.field,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = Enum.Font.Gotham,
            Text = "0",
            TextSize = 13,
            TextColor3 = theme.text
        }, row)
        corner(box, 5)
        stroke(box)

        box.FocusLost:Connect(function()
            local entry = currentEntry()
            if not entry then return end
            local value = math.clamp(math.floor(tonumber(box.Text) or entry[key][index]), 0, 255)
            entry[key][index] = value
            box.Text = tostring(value)
            updatePreview()
            refreshUnsaved()
        end)

        boxes[index] = box
    end

    return boxes, swatch
end

local colorBoxes, colorSwatch = colorRow(3, "ESP Color", "color")
local backgroundBoxes, backgroundSwatch = colorRow(4, "Background Color", "background")

local previewTitle = sectionLabel("Preview", 12)
previewTitle.Visible = false

local previewArea = new("Frame", {
    LayoutOrder = 13,
    Size = UDim2.new(1, 0, 0, 80),
    BackgroundColor3 = theme.panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false
}, body)
corner(previewArea)
stroke(previewArea)

local previewLabel = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(50, 26),
    BackgroundTransparency = 0.5,
    BackgroundColor3 = espBackgroundColor,
    BorderSizePixel = 0,
    Font = espFont,
    Text = "",
    TextSize = espTextSize,
    TextColor3 = espColor,
    TextStrokeTransparency = 0.5
}, previewArea)

function updatePreview()
    local entry = currentEntry()
    if not entry or entry.mode ~= "ESP" then
        previewTitle.Visible = false
        previewArea.Visible = false
        return
    end

    previewTitle.Visible = true
    previewArea.Visible = true

    local width, height = measure(entry.text)
    previewLabel.Size = UDim2.fromOffset(width, height)
    previewLabel.Text = entry.text
    previewLabel.TextColor3 = toColor(entry.color)
    previewLabel.BackgroundColor3 = toColor(entry.background)

    colorSwatch.BackgroundColor3 = toColor(entry.color)
    backgroundSwatch.BackgroundColor3 = toColor(entry.background)
end

local modeButtons = {}

local function refreshModeButtons()
    local entry = currentEntry()
    for _, mode in ipairs(modes) do
        local button = modeButtons[mode]
        local active = entry ~= nil and entry.mode == mode
        button.BackgroundColor3 = active and theme.accent or theme.field
        button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or theme.muted
    end
    modeTitle.Visible = entry ~= nil
    modeRow.Visible = entry ~= nil
    espSection.Visible = entry ~= nil and entry.mode == "ESP"

    local tpOn = canTP(entry)
    tpRow.Visible = entry ~= nil and entry.mode ~= "Hide"
    tpButton.BackgroundColor3 = tpOn and theme.accent or theme.field
    tpButton.TextColor3 = tpOn and Color3.fromRGB(255, 255, 255) or theme.muted
    priorityLabel.Visible = tpOn
    priorityBox.Visible = tpOn
end

local refreshList

local function refreshFields()
    local entry = currentEntry()

    if entry then
        textBox.Text = entry.text
        priorityBox.Text = tostring(entry.priority)
        for index = 1, 3 do
            colorBoxes[index].Text = tostring(entry.color[index])
            backgroundBoxes[index].Text = tostring(entry.background[index])
        end
    end

    refreshModeButtons()
    updatePreview()
end

local function setMode(mode)
    local entry = currentEntry()
    if not entry then return end
    entry.mode = mode
    refreshModeButtons()
    updatePreview()
    refreshList()
    refreshUnsaved()
end

for index, mode in ipairs(modes) do
    local button = new("TextButton", {
        LayoutOrder = index,
        Size = UDim2.fromOffset(modeButtonWidth, 30),
        BackgroundColor3 = theme.field,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Font = Enum.Font.GothamMedium,
        Text = modeLabels[mode],
        TextSize = 12,
        TextColor3 = theme.muted
    }, modeRow)
    corner(button)
    stroke(button)

    button.MouseButton1Click:Connect(function()
        setMode(mode)
    end)

    modeButtons[mode] = button
end

tpButton.MouseButton1Click:Connect(function()
    local entry = currentEntry()
    if not entry or entry.mode == "Hide" then return end
    entry.tp = not entry.tp
    refreshModeButtons()
    refreshList()
    refreshUnsaved()
end)

priorityBox.FocusLost:Connect(function()
    local entry = currentEntry()
    if not entry then return end
    entry.priority = readPriority(priorityBox.Text, entry.priority)
    priorityBox.Text = tostring(entry.priority)
    refreshUnsaved()
end)

local function selectToken(name)
    if selected == name then
        selected = nil
        selector.Text = "  Select a token..."
    else
        selected = name
        selector.Text = "  " .. name
    end
    dropdown.Visible = false
    refreshFields()
    refreshList()
    refreshUnsaved()
end

refreshList = function()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local query = search.Text:lower()
    local order = 0

    for _, name in ipairs(tokenNames) do
        if query == "" or name:lower():find(query, 1, true) then
            order = order + 1
            local entry = draft[name]
            local mode = entry and entry.mode or "None"
            local tag = mode ~= "None" and modeLabels[mode] or nil
            if canTP(entry) then
                tag = tag and (tag .. " + TP") or "TP"
            end

            local button = new("TextButton", {
                LayoutOrder = order,
                Size = UDim2.new(1, -4, 0, 26),
                BackgroundColor3 = name == selected and theme.field or theme.panel,
                BackgroundTransparency = name == selected and 0 or 1,
                BorderSizePixel = 0,
                AutoButtonColor = true,
                Font = Enum.Font.Gotham,
                Text = name,
                TextSize = 13,
                TextColor3 = tag and theme.accent or theme.text,
                TextXAlignment = Enum.TextXAlignment.Left
            }, list)
            corner(button, 5)

            new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, button)

            if tag then
                new("TextLabel", {
                    Size = UDim2.fromOffset(62, 26),
                    Position = UDim2.new(1, -62, 0, 0),
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Text = tag,
                    TextSize = 11,
                    TextColor3 = theme.muted,
                    TextXAlignment = Enum.TextXAlignment.Right
                }, button)
            end

            button.MouseButton1Click:Connect(function()
                selectToken(name)
            end)
        end
    end
end

selector.MouseButton1Click:Connect(function()
    dropdown.Visible = not dropdown.Visible
    if dropdown.Visible then
        refreshList()
    end
end)

search:GetPropertyChangedSignal("Text"):Connect(refreshList)

textBox.FocusLost:Connect(function()
    local entry = currentEntry()
    if not entry then return end
    local text = textBox.Text
    if text == "" then
        text = selected
    end
    entry.text = text
    textBox.Text = text
    updatePreview()
    refreshUnsaved()
end)

local function reloadESP()
    clearESP()
    applyAll()
end

reloadEspButton.MouseButton1Click:Connect(function()
    reloadESP()
end)

saveButton.MouseButton1Click:Connect(function()
    applyDraft()
    refreshList()
    updatePreview()
    reloadESP()

    if not canSaveConfig then
        setStatus("No filesystem", statusBad)
        return
    end

    if saveConfig() then
        setStatus("Save successful", statusGood)
    else
        setStatus("Save failed", statusBad)
    end
end)

closeButton.MouseButton1Click:Connect(function()
    local connections = getgenv().connections
    for _, key in ipairs({ "tokensConnection", "tokenRemoved", "tokenDrag" }) do
        if connections[key] then
            connections[key]:Disconnect()
            connections[key] = nil
        end
    end
    for _, key in ipairs({ "tokenLoop", "tokenTeleport" }) do
        if connections[key] then
            task.cancel(connections[key])
            connections[key] = nil
        end
    end
    setBalloonPurge(false)
    setParticlePurge(false)
    setDecorationsHidden(false)
    restoreAllHidden()
    clearESP()
    table.clear(spawnTimes)
    screen:Destroy()
end)

local expandedSize = main.Size

local function refreshMinimized()
    body.Visible = not minimized
    headerFill.Visible = not minimized
    saveButton.Visible = not minimized
    reloadEspButton.Visible = not minimized
    closeButton.Visible = not minimized
    minimizeButton.Text = minimized and "+" or "-"
    minimizeButton.Position = UDim2.new(1, minimized and -34 or -66, 0, 5)
    titleLabel.Size = UDim2.new(1, minimized and -46 or -214, 1, 0)
    main.Size = minimized and UDim2.fromOffset(150, 36) or expandedSize
    refreshUnsaved()
end

minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    refreshMinimized()
end)

local dragging = false
local dragStart, startPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
        local ended
        ended = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                ended:Disconnect()
            end
        end)
    end
end)

getgenv().connections["tokenDrag"] = UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    main.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end)

refreshList()
refreshModeButtons()
updatePreview()
refreshUnsaved()
applyAll()
