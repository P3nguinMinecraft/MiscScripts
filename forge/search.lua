-- EXAMPLE CONFIG
local config = {
    island = 3, -- 1, 2, 3
    loop = true, -- to continue checking after target is done
    targets = {
        enemy = {"Golem"}, -- Enemy Names
        rock = {"Heart of the Island", "Floating Crystal"} -- Rock Names
    }
}

local placeids = {
    [1] = 76558904092080,
    [2] = 129009554587176,
    [3] = 131884594917121
}

local function stopTP()
    local tpService = cloneref(game:GetService("TeleportService"))
    tpService:SetTeleportGui(tpService)

    local startTime = tick()
    local logService = cloneref(game:GetService("LogService"))
    while task.wait() do
        for _,l in logService:GetLogHistory() do
            if l.message:find("Teleport Service cannot be cloned") then
                break
            end
        end
        if tick() - startTime > 10 then break end
    end

    tpService:TeleportCancel()
    tpService:SetTeleportGui(nil)
end

local function hop(placeId)
    warn("No targets found, hopping...")
    game:GetService("Players").LocalPlayer:Kick("No targets found, hopping...")
    loadstring(game:HttpGet("https://raw.githubusercontent.com/P3nguinMinecraft/MiscScripts/refs/heads/main/serverhop.lua"))()(placeId)
end

local function getEnemy(name)
    local result = {}
    for _, child in ipairs(game:GetService("Workspace").Living:GetChildren()) do
        local enemy = child:FindFirstChild(name)
        if enemy then
            table.insert(result, enemy)
        end
    end
    return result
end

local function getRock(name)
    local result = {}
    for _, location in ipairs(game:GetService("Workspace").Rocks:GetChildren()) do
        for _, spawn in ipairs(location:GetChildren()) do
            local rock = spawn:FindFirstChild(name)
            if rock then
                table.insert(result, rock)
            end
        end
    end
    return result
end

local function searchSingle(category, name)
    local result = {}
    if category == "enemy" then
        result = getEnemy(name)
    elseif category == "rock" then
        result = getRock(name)
    end
    return result
end

local function search(targets)
    local result = {}
    local found = false
    for category, names in pairs(targets) do
        for _, name in ipairs(names) do
            local items = searchSingle(category, name)
            if #items > 0 then
                result[name] = items
                warn("Found " .. #items .. " " .. name)
                found = true
            end
        end
    end
    return result, found
end

local function try(config, id)
    local result, found = search(config.targets)
    if found then
        if not getgenv().firstSearch then
            task.spawn(stopTP)
            getgenv().firstSearch = true
        end
    else
        task.spawn(function() hop(id) end)
    end
    return result
end

return function(config)
    repeat task.wait() until game:IsLoaded()
    local id = placeids[config.island]
    if game.PlaceId ~= id then return end
    if config.loop then
        while task.wait(5) do
            try(config, id)
        end
    else
        try(config, id)
    end
end
