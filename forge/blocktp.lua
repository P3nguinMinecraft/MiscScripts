print("b")
require("constants")
print("a")
repeat task.wait() until game:IsLoaded()
if game.PlaceId ~= constants.FORGE_ISLAND_2 then return end

local tpService = cloneref(game:GetService("TeleportService"))
tpService:SetTeleportGui(tpService)

local startTime = tick()
local logService = cloneref(game:GetService("LogService"))
while task.wait() do
    for _,l in logService:GetLogHistory() do
        if l.message:find("Teleport Service cannot be cloned") then
            warn("Auto TP Blocked!")
            break
        end
    end
    if tick() - startTime > 10 then break end
end

tpService:TeleportCancel()
tpService:SetTeleportGui(nil)