getgenv().cons = getgenv().cons or {}
for _, obj in ipairs(getgenv().cons) do
    if typeof(obj) == "RBXScriptConnection" then
        obj:Disconnect()
    elseif typeof(obj) == "thread" then
        task.cancel(obj)
    end
end
getgenv().cons = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

getgenv().ESPConfig = getgenv().ESPConfig or {
    ESPDistance = 1000,
    HideLooted = true,
    FontSize = 16,
    Colors = {
        ["Tier 1"] = Color3.fromRGB(139, 69, 19),
        ["Tier 2"] = Color3.fromRGB(192, 192, 192),
        ["Tier 3"] = Color3.fromRGB(255, 215, 0)
    }
}
getgenv().trackedChests = {}

local chestsFolder = workspace.Game.Chests

local function toHex(color)
    return string.format("#%02X%02X%02X",
        math.floor(color.R * 255),
        math.floor(color.G * 255),
        math.floor(color.B * 255)
    )
end

local function isLooted(chest)
    for _, v in pairs(chest:GetDescendants()) do
        if v:IsA("ProximityPrompt") then return false end
    end
    return true
end

local function createESP(chestPart, wipe)
    local esp = chestPart:FindFirstChild("ESP")

    if esp then
        if wipe then
            esp:Destroy()
        else
            local text = esp:FindFirstChild("TEXT")
            if text then
                return esp
            else
                esp:Destroy()
            end
        end
    end

    esp = Instance.new("BillboardGui")
    esp.Name = "ESP"
    esp.Adornee = chestPart
    esp.Parent = chestPart
    esp.Size = UDim2.new(0, 200, 0, 50)
    esp.AlwaysOnTop = true
    esp.StudsOffset = Vector3.new(0, 5, 0)

    local label = Instance.new("TextLabel")
    label.Name = "TEXT"
    label.Parent = esp
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0.5
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = false
    label.TextSize = getgenv().ESPConfig.FontSize
    label.RichText = true

    return esp
end

for _, tierFolder in ipairs(chestsFolder:GetChildren()) do
    for _, chest in ipairs(tierFolder:GetChildren()) do
        table.insert(getgenv().trackedChests, {
            Model = chest,
            Tier = tierFolder.Name,
            ESP = createESP(chest, true)
        })
    end
end

local con = RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local rootPos = root.Position

    for _, chestData in ipairs(getgenv().trackedChests) do
        local chest = chestData.Model
        local tierName = chestData.Tier
        local esp = chestData.ESP
        if esp.Parent == nil then
            chestData.ESP = createESP(chest)
            esp = chestData.ESP
        end
        local label = esp:FindFirstChild("TEXT")

        local distance = (rootPos - chest.Position).Magnitude
        local enabled = true

        if distance > getgenv().ESPConfig.ESPDistance or (getgenv().ESPConfig.HideLooted and isLooted(chest)) then
            enabled = false
        end

        esp.Enabled = enabled
        label.TextSize = getgenv().ESPConfig.FontSize
        local tierColor = getgenv().ESPConfig.Colors[tierName] or Color3.new(1,1,1)
        local hex = toHex(tierColor)
        
        label.Text =
            "<font color='" .. hex .. "'>" .. tierName .. "</font>" ..
            "<br/><font color='#FFFFFF'>[" .. math.floor(distance) .. " studs]</font>"
    end
end)

table.insert(getgenv().cons, con)
