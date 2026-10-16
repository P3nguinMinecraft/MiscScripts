local submit = game:GetService("ReplicatedStorage").Remotes.SubmitAnswerRemote
local marketplace = game:GetService("MarketplaceService")

local idignore = {
	"rbxasset://sounds/action_get_up.mp3",
	"rbxasset://sounds/uuhhh.mp3",
	"rbxasset://sounds/action_falling.mp3",
	"rbxasset://sounds/action_jump.mp3",
	"rbxasset://sounds/action_jump_land.mp3",
	"rbxasset://sounds/impact_water.mp3",
	"rbxasset://sounds/action_swim.mp3",
	"rbxasset://sounds/action_footsteps_plastic.mp3",
	"rbxasset://sounds/action_get_up.ogg",
	"rbxasset://sounds/uuhhh.ogg",
	"rbxasset://sounds/action_falling.ogg",
	"rbxasset://sounds/action_jump.ogg",
	"rbxasset://sounds/action_jump_land.ogg",
	"rbxasset://sounds/impact_water.ogg",
	"rbxasset://sounds/action_swim.ogg",
	"rbxasset://sounds/action_footsteps_plastic.ogg",
	"rbxassetid://17583900629"
}

local nameignore = {
    "BlockSound"
}

getgenv().delayTime = 0.1


getgenv().cons = getgenv().cons or {}
for _, obj in ipairs(getgenv().cons) do
    if typeof(obj) == "RBXScriptConnection" then
        obj:Disconnect()
    elseif typeof(obj) == "thread" then
        task.cancel(obj)
    end
end

getgenv().cons = {}
getgenv().lastPlayed = ""

local function contains(tbl, value)
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

local function getAssetId(soundId)
	return tonumber(soundId:match("%d+"))
end

local function getName(assetId)
	local info = marketplace:GetProductInfo(assetId)
	local name = info.Name

	name = name:gsub("%s*%(%d+%)$", "")

	return name
end

local function answer(assetId)
    task.wait(getgenv().delayTime)

	local name
	pcall(function()
		name = getName(assetId)
	end)
	if not name then return end

	submit:InvokeServer(
		string.upper(name) .. "  ",
		"keyboard",
		nil,
	    getgenv().delayTime
    )
    print("SUBMIT: " .. name) 
end

local gameAddCon = game.DescendantAdded:Connect(function(obj)
	if not obj:IsA("Sound") then return end
	if contains(idignore, obj.SoundId) then return end
	if contains(nameignore, obj.Name) then return end
    
	local assetId = getAssetId(obj.SoundId)
	if not assetId then return end

	obj.Played:Connect(function()
	    answer(assetId)
	end)
end)
table.insert(getgenv().cons, gameAddCon)

local gemLoop = task.spawn(function()
	while task.wait(1) do
		for _,v in pairs(game.Workspace.GEMS:GetChildren()) do
			if v.BillboardGui.SpiralImage.ImageTransparency ~= 1 then
				game.Players.LocalPlayer.Character:SetPrimaryPartCFrame(v.CFrame)
				task.wait(0.4)
			end
		end
	end
end)
table.insert(getgenv().cons, gemLoop)
