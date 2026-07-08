local UIS = game:GetService("UserInputService")
local particles = game:GetService("Workspace").Particles
local field = game:GetService("Workspace").FlowerZones["Coconut Field"]
local BV
local enabled = false
local hoverY = 101
local hoverX, hoverZ
local key = Enum.KeyCode.M

local zonePos = field.Position
local zoneSize = field.Size
local minX = zonePos.X - zoneSize.X / 2
local maxX = zonePos.X + zoneSize.X / 2
local minZ = zonePos.Z - zoneSize.Z / 2
local maxZ = 470

local centerX = (minX + maxX) / 2
local centerZ = maxZ

local function isSafe(x, z)
    for _, disk in pairs(particles:GetChildren()) do
        if disk.Name == "WarningDisk" and disk.Transparency < 0.4 then
            local diskPos = disk.Position
            local diskSize = disk.Size
            local halfSizeX = diskSize.X / 2
            local halfSizeZ = diskSize.Z / 2
            
            local diskMinX = diskPos.X - halfSizeX
            local diskMaxX = diskPos.X + halfSizeX
            local diskMinZ = diskPos.Z - halfSizeZ
            local diskMaxZ = diskPos.Z + halfSizeZ
            
            if x >= diskMinX and x <= diskMaxX and z >= diskMinZ and z <= diskMaxZ then
                return false
            end
        end
    end
    return true
end

local function getLocation()
    if isSafe(centerX, centerZ) then
        return centerX, centerZ
    end

    for x = minX, maxX, 5 do
        for z = maxZ, minZ, -5 do
            if isSafe(x, z) then
                return x, z
            end
        end
    end
    return centerX, centerZ
end

local function teleportPlayer(x, y, z)
    local character = game.Players.LocalPlayer.Character
    if character then
        character:SetPrimaryPartCFrame(CFrame.new(x, y, z))
    end
end

local function toggleFloat(v)
    if v then
        game.Players.LocalPlayer.Character.Humanoid.PlatformStand = true
        game.Workspace.Gravity = 0
        BV = Instance.new("BodyVelocity")
        BV.Parent = game.Players.LocalPlayer.Character.HumanoidRootPart
        BV.Velocity = Vector3.new(0, 0, 0)
    else
        if BV then
            BV:Destroy()
        end
        game.Players.LocalPlayer.Character.Humanoid.PlatformStand = false
        game.Workspace.Gravity = 192.5
    end
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == key then
        enabled = not enabled
        hoverX, hoverZ = getLocation()
        toggleFloat(enabled)
    end
end)

task.spawn(function()
    while task.wait(0.05) do
        if enabled then
            pcall(function()
                hoverX, hoverZ = getLocation()
                teleportPlayer(hoverX, hoverY, hoverZ)
            end)
        end
    end
end)

warn("---COCONUT CRAB SCRIPT INITIALIZED---")