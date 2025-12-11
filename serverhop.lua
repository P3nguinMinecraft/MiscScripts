return function(placeId)
    local TeleportService = cloneref(game:GetService("TeleportService"))
    local HttpService = cloneref(game:GetService("HttpService"))
    local Players = cloneref(game:GetService("Players"))

    TeleportService:TeleportCancel()
    local function listServers(cursor)
        local url = (
            "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
        ):format(placeId)

        if cursor then
            url = url .. "&cursor=" .. cursor
        end

        local raw
        pcall(function()
            raw = game:HttpGet(url)
        end)

        if not raw then return nil end

        local decoded = HttpService:JSONDecode(raw)
        if decoded.errors then return nil end

        return decoded
    end

    local nextCursor = nil
    local chosenServer = nil

    while not chosenServer do
        local servers = listServers(nextCursor)

        if not servers or not servers.data then
            warn("Servers API cooldown or invalid response.")
            task.wait(2)
        else
            local pool = {}
            for i = 1, #servers.data do pool[i] = i end

            while #pool > 0 do
                local randIndex = math.random(#pool)
                local index = table.remove(pool, randIndex)
                local s = servers.data[index]

                if s and s.playing < s.maxPlayers and s.id ~= game.JobId then
                    chosenServer = s
                    break
                end
            end

            if not chosenServer then
                if servers.nextPageCursor then
                    nextCursor = servers.nextPageCursor
                else
                    warn("No available servers found.")
                    return
                end
            end
        end
    end

    print("Teleporting to:", chosenServer.id)
    TeleportService:TeleportToPlaceInstance(placeId, chosenServer.id, Players.LocalPlayer)
    
    task.spawn(function()
        task.wait(10)
        warn("Teleport failed, retrying...")
        TeleportService:TeleportToPlaceInstance(placeId, chosenServer.id, Players.LocalPlayer)
    end)
end