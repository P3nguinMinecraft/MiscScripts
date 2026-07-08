-- 612 591 574 farthest to closest
-- 93, 50, 574 hover location

local UIS = game:GetService("UserInputService")
local obstacles = game:GetService("Workspace").Toys["Ant Challenge"].Obstacles
local BV
local enabled = false
local currentLaneZ = 574
local hoverY = 50
local hoverX = 93
local key = Enum.KeyCode.N

local function isObstacleInLane(zMin, zMax)
    for _, obstacle in pairs(obstacles:GetChildren()) do
        local pos = obstacle.WorldPivot
        if pos.Z >= zMin and pos.Z <= zMax and pos.X >= hoverX - 40 and pos.X <= hoverX + 40 then
            return true
        end
    end
    return false
end

local function getTargetLane()
    if isObstacleInLane(570, 580) then
        if isObstacleInLane(585, 595) then
            return 612
        else
            return 591
        end
    else
        return 574
    end
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
        currentLaneZ = 574
        toggleFloat(enabled)
    end
end)

task.spawn(function()
    while task.wait(0.05) do
        if enabled then
            pcall(function()
                currentLaneZ = getTargetLane()
                teleportPlayer(hoverX, hoverY, currentLaneZ)
            end)
        end
    end
end)

warn("---ANT CHALLENGE SCRIPT INITIALIZED---")