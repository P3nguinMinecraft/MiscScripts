return function(placeid, smallServer)
    smallServer = smallServer or true

    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")

    local DATA_MAX_AGE = 1
    local folder = "servers"
    local filename = folder .. "/" .. placeid .. (smallServer and "L" or "H") .. ".json"

    if not isfolder(folder) then
        makefolder(folder)
    end

    local function now()
        return DateTime.now().UnixTimestamp
    end

    local function LoadCache()
        if not isfile(filename) then return nil end

        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(filename))
        end)

        if not ok or not data.timestamp or not data.data then
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

    local function FetchServers()
        local url =
            "https://games.roblox.com/v1/games/" .. placeid ..
            "/servers/Public?limit=100&excludeFullGames=true&sortOrder=" .. (smallServer and "Asc" or "Desc")

        local success, raw = pcall(function()
            return game:HttpGet(url)
        end)

        if not success or not raw then
            return nil
        end

        local decodeSuccess, decoded = pcall(function()
            return HttpService:JSONDecode(raw)
        end)

        if not decodeSuccess or not decoded then
            return nil
        end

        if decoded.errors then
            return nil
        end
        return decoded
    end

    local Servers = LoadCache()
    local cacheTimestamp = 0

    if Servers then
        local ok, cachedData = pcall(function()
            return HttpService:JSONDecode(readfile(filename))
        end)
        if ok and cachedData and cachedData.timestamp then
            cacheTimestamp = cachedData.timestamp
        end
    end

    local shouldFetch = not Servers or (now() - cacheTimestamp) >= DATA_MAX_AGE

    if shouldFetch then
        local result = FetchServers()
        if result and result.data then
            Servers = result.data
            SaveCache(Servers)
        end
    end

    local function RemoveServer(serverId)
        if not isfile(filename) then return end
        local cache = HttpService:JSONDecode(readfile(filename))

        local new = {}
        for _, s in ipairs(cache.data) do
            if s.id ~= serverId then
                table.insert(new, s)
            end
        end

        cache.data = new
        writefile(filename, HttpService:JSONEncode(cache))
    end

    local target = nil

    for _, s in ipairs(Servers) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            target = s
            break
        end
    end

    if not target then
        warn("No valid server found - Servers: ", (not Servers or #Servers < 0) and "Empty" or #Servers)
    end

    RemoveServer(target.id)
    
    TeleportService:TeleportToPlaceInstance(
        placeid,
        target.id,
        Players.LocalPlayer
    )
end
