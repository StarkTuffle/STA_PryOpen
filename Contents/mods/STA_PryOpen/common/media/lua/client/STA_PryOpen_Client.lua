local Log = require "STA_PryOpen_Log"
local Config = require "STA_PryOpen_ModOptions"
local Utils = require "STA_PryOpen_Utils"

local Client = STA_PryOpen_Client or {}
Client.modID = "STA_PryOpen"

local function resolveLocalPlayer(args)
    local n = getNumActivePlayers() or 1

    if args.playerOnlineID then
        for i = 0, n - 1 do
            local p = getSpecificPlayer(i)
            if p and p:getOnlineID() == args.playerOnlineID then return p end
        end
    end

    if args.playerIndex ~= nil then
        local p = getSpecificPlayer(tonumber(args.playerIndex) or 0)
        if p then return p end
    end

    return getSpecificPlayer(0)
end

function Client.onServerCommand(module, command, args)
    Log.info("Client params: module=%s command=%s args=%s", tostring(module), tostring(command), tostring(args))
    if module ~= Client.modID then return end
    if not command then return end
    if not args then return end

    local playerObj = resolveLocalPlayer(args)
    if not playerObj then Log.warn("Player not found from args.") return end

    if command == "SayOutcome" then
        local message = args.message
        local option = Config["sayOnAction"]
        local idx = ZombRand(5) + 1

        if option then
            playerObj:Say(getText("IGUI_STA_PryOpen_" .. message .. "_" .. idx))
        end
    end
    if command == "DoClientOpenAnim" then
        local sq = getCell():getGridSquare(args.x, args.y, args.z)
        local playerObj = resolveLocalPlayer(args)
        if not playerObj then Log.warn("Player not found from args.") return end
        if sq then
            local objs = sq:getObjects()
            for i = 0, objs:size() - 1 do
                local o = objs:get(i)
                    if instanceof(o, "IsoWindow") then
                        o:setIsLocked(false)
                        ISWorldObjectContextMenu:onOpenCloseWindow(o, playerObj:getPlayerNum())
                    end
                    if instanceof(o, "IsoDoor") then
                        o:setLocked(false)
                        o:setLockedByKey(false)
                        o:getProperties():unset("forceLocked")
                        ISWorldObjectContextMenu:onOpenCloseDoor(o, playerObj:getPlayerNum())
                    end
                    if instanceof(o, "IsoThumpable") and o:isDoor() then
                        o:setLocked(false)
                        o:setLockedByKey(false)
                        ISWorldObjectContextMenu:onOpenCloseDoor(o, playerObj:getPlayerNum())
                    end
            end
        end
    end
end

Events.OnServerCommand.Add(Client.onServerCommand)

_G.STA_PryOpen_Client = Client
return Client