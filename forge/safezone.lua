local UIS = game:GetService("UserInputService")
local enabled = false
local startCFrame = nil
local targetCFrame = nil
local BV = nil

local function calcTarget(start)
	return CFrame.new(startCFrame.Position + Vector3.new(0, 7, 0.5)) * CFrame.Angles(math.rad(-80), 0, 0)
end

local function toggleFloat(v)
    if v then
        game.Players.LocalPlayer.Character.Humanoid.PlatformStand = true
        BV = Instance.new("BodyVelocity")
        BV.Parent = game.Players.LocalPlayer.Character.HumanoidRootPart
        BV.Velocity = Vector3.new(0, 0, 0)
    else
        if BV then BV:Destroy() end
        game.Players.LocalPlayer.Character.Humanoid.PlatformStand = false
    end
end

if getgenv().FORGESAFEEXECUTED then return end

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.N then
	    startCFrame = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame
	    targetCFrame = calcTarget(startCFrame)
	    toggleFloat(true)
        pcall(function() game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(targetCFrame) end)
    	enabled = true
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.N then
	    toggleFloat(false)
	    pcall(function()
            game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(startCFrame)
	    end)
	    enabled = false
	end
end)

task.spawn(function()
    while task.wait() do
        if enabled then
            pcall(function()
                if game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame ~= targetCFrame then
                   warn("Moved from target!")
                   game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(targetCFrame)
                end
            end)
        end
    end
end)

getgenv().FORGESAFEEXECUTED = true
warn("---SCRIPT INITIALIZED---")