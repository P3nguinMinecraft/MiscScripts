repeat task.wait() until game:IsLoaded()
if game.PlaceId ~= 129009554587176 then return end

local blocked = false
local tpService = cloneref(game:GetService("TeleportService"))
tpService:SetTeleportGui(tpService)

local startTime = tick()
local logService = cloneref(game:GetService("LogService"))
while not blocked do
    for _,l in logService:GetLogHistory() do
        if l.message:find("Teleport Service cannot be cloned") then
            warn("Auto TP Blocked!")
            blocked = true
            break
        end
    end
    if tick() - startTime > 10 then break end
    task.wait()
end

tpService:TeleportCancel()
tpService:SetTeleportGui(nil)