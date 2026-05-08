local Log = require "STA_PryOpen_Log"
local Config = require "STA_PryOpen_ModOptions"

local Sounds = {}
Sounds.modID = "STA_PryOpen"

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

local function getOutcomeSoundName(result, category)
    local base
    if category == "Building" or category == "Window" then
        base = result and "BreakBarricadePlank" or "CrowbarBreak"
    elseif category == "Garage" or category == "Secure" then 
        base = result and "GarageDoorBreak" or "CrowbarBreak"
    elseif category == "Vehicle" or category == "Trunk" then
        base = result and "BreakBarricadeMetal" or "CrowbarBreak"
    else
        base = result and "BreakBarricadePlank" or "CrowbarBreak"
        Log.debug("Unexpected outcome, no category %s", category)
    end
    return base
end

---@param playerObj IsoPlayer
---@param result string
---@param category string
local function playOutcomeSound(playerObj, result, category)
    if not playerObj then return end

    local sound = getOutcomeSoundName(result, category)
    local actionVolume = 1 - Config["volumeAdjust"]
    local gameVolume = getSoundManager():getSoundVolume()
    local emitter = playerObj:getEmitter()
    local volume = gameVolume - ( gameVolume * actionVolume )
    if sound == "CrowbarBreak" then volume = volume * 0.5 end
    emitter:setVolume(emitter:playSound(sound), volume)
end

---@param module string
---@param command string
---@param args any
function Sounds.onServerCommand(module, command, args)
    if module ~= Sounds.modID or command ~= "SoundOutcome" then return end
    if not args then return end

    local player = resolveLocalPlayer(args)
    if not player then Log.warn("Player not found from args.") return end

    local result = args.result
    local category = args.category
    Log.debug("Outcome received: success=%s category=%s for local player=[%s]%s", tostring(result), category, tostring(player:getPlayerNum() or -1), player:getDisplayName())

    playOutcomeSound(player, result, category)
end

Events.OnServerCommand.Add(Sounds.onServerCommand)

_G.STA_PryOpen_Sounds = Sounds
return Sounds
