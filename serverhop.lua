return function(placeid, smallServer)
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")

    local CACHE_TIME = 300 
    local folder = "servers"
    local filename = folder .. "/" .. placeid .. (smallServer and "S" or "R") .. ".json"

    if not isfolder(folder) then
        makefolder(folder)
    end

    local function now()
        return os.time()
    end

    local function LoadCache()
        if not isfile(filename) then return nil end

        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(filename))
        end)

        if not ok or not data.timestamp or not data.data then
            return nil
        end

        if now() - data.timestamp > CACHE_TIME then
            return nil
        end

        return data.data
    end

    local function SaveCache(data)
        writefile(filename, HttpService:JSONEncode({
            timestamp = now(),
            data = data
        }))
    end

    local function FetchServers(cursor)
        local url =
            "https://games.roblox.com/v1/games/" .. placeid ..
            "/servers/Public?limit=100&excludeFullGames=true&sortOrder=" .. (smallServer and "Asc" or "Desc") ..
            (cursor and "&cursor=" .. cursor or "")

        local raw = game:HttpGet(url)
        return HttpService:JSONDecode(raw)
    end

    local Servers = LoadCache()

    if not Servers then
        local collected = { data = {}, nextPageCursor = nil }
        local cursor = nil

        repeat
            local page = FetchServers(cursor)
            if page and page.data then
                for _, s in ipairs(page.data) do
                    table.insert(collected.data, s)
                end
            end
            cursor = page.nextPageCursor
        until not cursor

        Servers = collected
        SaveCache(Servers)
    end

    local function RemoveServer(serverId)
        if not isfile(filename) then return end
        local cache = HttpService:JSONDecode(readfile(filename))

        local new = {}
        for _, s in ipairs(cache.data.data) do
            if s.id ~= serverId then
                table.insert(new, s)
            end
        end

        cache.data.data = new
        writefile(filename, HttpService:JSONEncode(cache))
    end

    local target = nil

    for _, s in ipairs(Servers.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            target = s
            break
        end
    end

    if not target then
        return warn("No valid server found")
    end

    RemoveServer(target.id)

    TeleportService:TeleportToPlaceInstance(
        placeid,
        target.id,
        Players.LocalPlayer
    )

    task.spawn(function()
        task.wait(10)
        TeleportService:TeleportToPlaceInstance(placeid, game.JobId, Players.LocalPlayer)
    end)
end
