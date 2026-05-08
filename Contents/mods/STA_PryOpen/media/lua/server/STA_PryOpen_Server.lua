local Utils = require "STA_PryOpen_Utils"
local Log = require "STA_PryOpen_Log"

local Server = STA_PryOpen_Server or {}
Server.modID = "STA_PryOpen"

-- Local Functions

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function getSquare(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(x, y, z)
end

local function iterateObjectsOnSquare(sq, fn)
    if not sq then return end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        fn(o)
    end
    local specs = sq:getSpecialObjects()
    for i = 0, specs:size() - 1 do
        local o = specs:get(i)
        fn(o)
    end
end

local function spriteName(obj)
    local sp = obj and obj:getSprite() or nil
    if sp and sp:getName() then return sp:getName() end
    return nil
end

local function resolveWorldObject(args, playerObj)
    local sq = getSquare(args.x, args.y, args.z)
    if not sq then return nil end

    local selected, fallback
    iterateObjectsOnSquare(sq, function(o)
        if not fallback then
            local cat = Utils.getWorldCategoryForObject(o)
            if cat and Utils.isLockedWorldObject(o) and not Utils.isBarricadedForPlayer(o, playerObj) then
                fallback = o
            end
        end
        if not selected and args.sprite then
            local name = spriteName(o)
            if name == args.sprite and Utils.isLockedWorldObject(o) and not Utils.isBarricadedForPlayer(o, playerObj) then
                selected = o
            end
        end
    end)
    return selected or fallback
end

local function giveXP(player, perk, amount)
    if not player or not perk or amount <= 0 then return end
    player:getXp():AddXP(perk, amount)
end

local function resolveVehicleAndPart(args)
    if not args.vehicleId or not args.partId then return nil, nil end
    local vehicle = getVehicleById(args.vehicleId)
    if not vehicle then return nil, nil end
    local part = vehicle:getPartById(args.partId)
    if not part or not part:getDoor() then return nil, nil end
    return vehicle, part
end

local function transmitWorldObject(obj)
    if not obj then return end
    if obj.transmitUpdatedSpriteToClients then obj:transmitUpdatedSpriteToClients() end
    if obj:getSquare() and obj:getSquare().InvalidateSpecialObjectPaths then
        obj:getSquare():InvalidateSpecialObjectPaths()
    end
end

local function getAdjacentBuilding(sq)
    local cell = getCell()
    local x,y,z = sq:getX(), sq:getY(), sq:getZ()
    local offsets = {{1,0},{0,1},{0,-1},{-1,0}}
    for i = 1, #offsets do
        local nx, ny = x + offsets[i][1], y + offsets[i][2]
        local nsq = cell:getGridSquare(nx, ny, z)
        if not nsq:isOutside() then
            return nsq
        end
    end
    return nil
end

local function addNoiseFrom(playerObj, x, y, z)
    local r = Utils.computeNoiseRadius(playerObj)
    addSound(playerObj, x, y, z, r, 10)
end

local function maybeTriggerBuildingAlarm(playerObj, obj, chance)
    local category = Utils.getWorldCategoryForObject(obj)
    local sq
    if category == "Window" then
        sq = obj:getIndoorSquare()
    else
        sq = obj:getOtherSideOfDoor(playerObj)
    end
    if not sq then return end
    if sq:isOutside() then
        Log.debug("Square for %s is outside; checking adjacent squares", category)
        sq = getAdjacentBuilding(sq)
        if not sq then
            Log.error("No building found for %s; aborting", category)
            return
        end
    end
    local building, room
    if not sq:isOutside() then
        building = sq:getBuilding():getDef()
        room = sq:getRoom():getRoomDef()
    end

    if building and room then
        if Utils.isCategoryEnabled("AlarmForce") then
            building:setAlarmed(false)

            local alarmChance = ZombRandFloat(0.0, 1.0)
            local alarmDC = clamp01(chance or 0)

            if alarmChance <= alarmDC then
                -- local sOpt = getSandboxOptions()
                -- local decayOpt = sOpt:getOptionByName("AlarmDecay")
                -- local alarmDecay = sOpt:randomAlarmDecay(decayOpt:getValue())
                local alarmDecay = getSandboxOptions():getElecShutModifier() + ZombRand(30)
                local worldAge = getWorld():getWorldAgeDays()
                if worldAge <= alarmDecay then
                    building:setAlarmed(true)
                    getAmbientStreamManager():doAlarm(room)
                end
            end
        elseif building:isAlarmed() then
            getAmbientStreamManager():doAlarm(room)
        end
    end

    -- if building and ZombRandFloat(0.0, 1.0) <= clamp01(chance or 0) then
    --     if not building:isAlarmed() and not Utils.isCategoryEnabled("AlarmForce") then
    --         return
    --     elseif building:isAlarmed() or Utils.isCategoryEnabled("AlarmForce") then
    --         building:setAlarmed(false)
    --         --local alarmSound = sq:playSound("HouseAlarm")
    --         local alarmSound = getSoundManager():PlayWorldSound("HouseAlarm", sq, 0, 600, 1, true)
    --         if alarmSound then
    --             local timer = ZombRand(80, 90) * 30
    --             local timerFunc
    --             timerFunc = function()
    --                 timer = timer - 1
    --                 if timer < 0 then
    --                     getSoundManager():StopSound(alarmSound)
    --                     Events.OnTick.Remove(timerFunc)
    --                 end
    --             end
    --             addSound(obj, obj:getX(), obj:getY(), obj:getZ(), 600, 10)
    --             Events.OnTick.Add(timerFunc)
    --         end
    --     else
    --         return
    --     end
    -- end
end

local function maybeTriggerVehicleAlarm(vehicle, chance)
    if vehicle and ZombRandFloat(0.0, 1.0) <= clamp01(chance or 0) then
        if Utils.isCategoryEnabled("AlarmForce") then
            local md = ModData.getOrCreate("STA_PryOpen")
            if not md[vehicle:getId()] then
                vehicle:setAlarmed(true)
                vehicle:triggerAlarm()
                md[vehicle:getId()] = true
            elseif vehicle:isAlarmed() then
                vehicle:triggerAlarm()
            end
        end
    end
end

local function applyInjuryToHands(playerObj, failChances, window)
    if not playerObj or not failChances then return end

    local injL, injR = 0.5 * failChances.PryChanceInjuryL, 0.5 * failChances.PryChanceInjuryR
    local scr, cut, dpw = failChances.InjurySeverity[1], failChances.InjurySeverity[2], failChances.InjurySeverity[3]

    local bd = playerObj:getBodyDamage()
    if not bd then return end

    local chance = ZombRandFloat(0.0, 1.0)
    Log.info("Roll: chance=%.2f", chance)
    if chance <= injL then
        if chance <= (injL * scr) then
            bd:getBodyPart(BodyPartType.Hand_L):setScratched(true, true)
        elseif chance > (injL * scr) and chance <= (injL * (cut + scr)) then
            bd:getBodyPart(BodyPartType.Hand_L):setCut(true, true)
        elseif chance > (injL * (cut + scr)) and chance <= (injL * (cut + scr + dpw)) then
            if window then bd:getBodyPart(BodyPartType.Hand_L):generateDeepShardWound()
            else bd:getBodyPart(BodyPartType.Hand_L):generateDeepWound() end
        else
            Log.debug("Injury sevarity chance unexpected. Roll: chance%.2f max%.2f", chance, (injL * (cut + scr + dpw)))
            bd:getBodyPart(BodyPartType.Hand_L):setAdditionalPain(30)
        end
    elseif chance > injL and chance <= injL + injR then
        if chance <= ((injL + injR) * scr) then
            bd:getBodyPart(BodyPartType.Hand_R):setScratched(true, true)
        elseif chance > ((injL + injR) * scr) and chance <= ((injL + injR) * (cut + scr)) then
            bd:getBodyPart(BodyPartType.Hand_R):setCut(true, true)
        elseif chance > ((injL + injR) * (cut + scr)) and chance <= ((injL + injR) * (cut + scr + dpw)) then
            if window then bd:getBodyPart(BodyPartType.Hand_L):generateDeepShardWound()
            else bd:getBodyPart(BodyPartType.Hand_R):generateDeepWound() end
        else
            Log.debug("Injury sevarity chance unexpected. Roll: chance%.2f max%.2f", chance, ((injL + injR) * (cut + scr + dpw)))
            bd:getBodyPart(BodyPartType.Hand_R):setAdditionalPain(30)
        end
    else return false end
    return true
end

local function rollAndApplyDurability(playerObj)
    local crowbar = playerObj:getPrimaryHandItem()
    local equippedItemIsCrowbar = false

    if not Utils.isEquippedItemValidPryTool(crowbar) then
        crowbar = Utils.findUsableCrowbar(playerObj)
    end

    -- if crowbar:hasTag("Crowbar") then
    --     equippedItemIsCrowbar = true
    -- end
    -- if not equippedItemIsCrowbar then
    --     crowbar = Utils.findUsableCrowbar(playerObj)
    -- end
    if not crowbar then return end

    if crowbar and crowbar:getTags():contains("Crowbar") and ZombRand(crowbar:getConditionLowerChance()) == 0 then
        crowbar:setCondition(crowbar:getCondition() - 1)
        giveXP(playerObj, Perks.Maintenance, 2)
    end
end

local function getCategoryFromVehiclePart(part)
    local id = tostring(part and part:getId() or ""):lower()
    return id:find("trunk") and "Trunk" or "Vehicle"
end

local function applyWorldUnlock(obj, playerObj, worldObjects)
    if not obj then return end
    if instanceof(obj, "IsoWindow") then
        obj:setIsLocked(false)
        if isServer() then
            sendServerCommand(playerObj, "STA_PryOpen", "DoClientOpenAnim", { x=obj:getX(), y=obj:getY(), z=obj:getZ(), playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        end
        if not isClient() and not isServer() then
            STA_PryOpen_Client.onServerCommand("STA_PryOpen", "DoClientOpenAnim", { x=obj:getX(), y=obj:getY(), z=obj:getZ(), playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        end
    elseif instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor()) then
        obj:setLockedByKey(false)
        obj:setLocked(false)
        if isServer() then
            sendServerCommand(playerObj, "STA_PryOpen", "DoClientOpenAnim", { x=obj:getX(), y=obj:getY(), z=obj:getZ(), playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        end
        if not isClient() and not isServer() then
            STA_PryOpen_Client.onServerCommand("STA_PryOpen", "DoClientOpenAnim", { x=obj:getX(), y=obj:getY(), z=obj:getZ(), playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        end
    end
end

local function applyVehicleUnlock(vehicle, part)
    if not vehicle or not part then return end
    if part:getDoor() then
        part:getDoor():setLocked(false)
    end
    if vehicle.transmitPartDoor then
        vehicle:transmitPartDoor(part)
    end
end

local function smashIsoWindow(obj)
    if obj and instanceof(obj, "IsoWindow") then
        obj:smashWindow()
        transmitWorldObject(obj)
    end
end

local function smashVehicleWindow(playerObj, part)
    if not playerObj or not part or not part:getChildWindow() then return end
    local window = part:getChildWindow():getWindow()
    if window and not window:isOpen() then
        if not window:isDestroyed() then
            window:hit(playerObj)
            return true
        end
    end
end

local function breakVehicleLock(vehicle, part)
    if not vehicle or not part then return end
    if not part:getDoor():isLockBroken() then
        part:getDoor():setLockBroken(true)
        if vehicle.transmitPartModData then
            vehicle:transmitPartModData(part)
        end
        return true
    end
end

local function applyPityBonus(playerObj, baseChance)
    local enabled = Utils.isCategoryEnabled("Pity")
    if not enabled then return baseChance end
    local perFail = 0.01
    local maxBonus = 0.15

    local md = playerObj:getModData()
    md.STA_PryOpen = md.STA_PryOpen or {}
    local fs = md.STA_PryOpen.failStreak or 0
    local bonus = math.min(maxBonus, fs * perFail)
    return clamp01(baseChance + bonus)
end

local function recordAnalytics(playerObj, success)
    local md = playerObj:getModData()
    md.STA_PryOpen = md.STA_PryOpen or {}
    local stats = md.STA_PryOpen
    stats.attampts = (stats.attampts or 0) + 1
    if success then
        stats.success = (stats.success or 0)+ 1
        stats.failStreak = 0
    else
        stats.fail = (stats.fail or 0) + 1
        stats.failStreak = (stats.failStreak or 0) + 1
    end
    playerObj:transmitModData()
end

-- Handlers

local function handlePryWorld(playerObj, args)
    if not playerObj then return end
    local obj = resolveWorldObject(args, playerObj)
    if not obj then Log.warn("World resolve failed at %d,%d,%d", args.x or -1, args.y or -1, args.z or -1) return end
    local category = Utils.getWorldCategoryForObject(obj)
    if not category then return end
    local worldObjects = args.worldObjects
    Log.debug("World target: sprite=%s cat=%s", tostring(spriteName(obj)), category)

    if not Utils.isCategoryEnabled(category) then Log.info("Denied: category disabled (%s)", category) return end
    if not Utils.meetsStrengthRequirement(playerObj, category) then Log.info("Denied: strength too low for %s", category) return end
    if not args.crowbarID then Log.info("Denied: no crowbar") return end
    local crowbar = Utils.findUsableCrowbar(playerObj)
    if not Utils.isLockedWorldObject(obj) then Log.info("Denied: not locked") return end
    if Utils.isBarricadedForPlayer(obj, playerObj) then Log.info("Denied: is barricaded for player") return end

    local chance = Utils.computePrySuccessChance(playerObj, category, crowbar)
    chance = applyPityBonus(playerObj, chance)
    Log.info("Roll: cat=%s chance=%.2f", category, chance)

    local sq
    if category == "Window" then
        sq = obj:getIndoorSquare()
    else
        sq = obj:getOtherSideOfDoor(playerObj)
        if sq:isOutside() then
            Log.debug("Square for %s is outside; checking adjacent squares", category)
            sq = getAdjacentBuilding(sq)
            if not sq then
                Log.error("No building found for %s; aborting", category)
                return
            end
        end
    end
    local success = (ZombRandFloat(0.0, 1.0) <= chance)
    local windowBroke = false
    local injury

    if success then
        Log.info("SUCCESS: %s unlocked @ %d,%d,%d", category, sq:getX(), sq:getY(), sq:getZ())
        if Utils.isCategoryEnabled("AlarmSuccess") then
            if not sq:isOutside() then
                sq:getBuilding():getDef():setAlarmed(false)
            end
        end
        applyWorldUnlock(obj, playerObj, worldObjects)
        if sq then addNoiseFrom(playerObj, sq:getX(), sq:getY(), sq:getZ()) end
        recordAnalytics(playerObj, true)
        if category == "Building" or category == "Window" then
            giveXP(playerObj, Perks.Woodwork, 3)
        elseif category == "Secure" or category == "Garage" then
            giveXP(playerObj, Perks.MetalWelding, 3)
        end
    else
        Log.info("FAIL: %s @ %d,%d,%d", category, sq:getX(), sq:getY(), sq:getZ())
        local fail = Utils.getFailureChances(playerObj)

        if instanceof(obj, "IsoWindow") then
            if ZombRandFloat(0.0, 1.0) <= clamp01(fail.PryChanceBreakWindow) then
                windowBroke = smashIsoWindow(obj) or false
                if windowBroke then Log.info("Window smashed") end
            end
        end

        if sq then
            maybeTriggerBuildingAlarm(playerObj, obj, fail.PryChanceAlarm)
            addNoiseFrom(playerObj, sq:getX(), sq:getY(), sq:getZ())
        end

        injury = applyInjuryToHands(playerObj, fail, windowBroke)

        recordAnalytics(playerObj, false)
    end
    if isServer() then
        Log.info("Command %s were sent to player %s", "SoundOutcome", playerObj:getUsername())
        sendServerCommand(playerObj, "STA_PryOpen", "SoundOutcome", { result = success, category = category, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        Log.info("Command %s was sent to player %s", "SayOutcome [357]", playerObj:getUsername())
        local message
        if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
        sendServerCommand(playerObj, "STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
    end
    if not isClient() and not isServer() then
        Log.info("Ran command: Sound Outcome on Single Player")
        STA_PryOpen_Sounds.onServerCommand("STA_PryOpen", "SoundOutcome", { result = success, category = category, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        Log.info("Ran command: SayOutcome on Single Player [365]")
        local message
        if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
        STA_PryOpen_Client.onServerCommand("STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
    end
    giveXP(playerObj, Perks.Strength, 2)
    rollAndApplyDurability(playerObj)
end

local function handlePryVehicle(playerObj, args)
    if not playerObj then return end
    local vehicle, part = resolveVehicleAndPart(args)
    if not vehicle or not part then return end
    local category = getCategoryFromVehiclePart(part)
    if not category then return end
    Log.debug("Vehicle target: id=%s part=%s cat=%s", tostring(vehicle:getId()), tostring(part:getId()), category)

    if not Utils.isCategoryEnabled(category) then return end
    if not Utils.meetsStrengthRequirement(playerObj, category) then return end
    if not args.crowbarID then Log.info("Denied: no crowbar") return end
    local crowbar = Utils.findUsableCrowbar(playerObj)
    if not part:getDoor() or not part:getDoor():isLocked() then return end

    local chance = Utils.computePrySuccessChance(playerObj, category, crowbar)
    chance = applyPityBonus(playerObj, chance)
    Log.info("Roll: cat=%s chance=%.2f", category, chance)

    local vsq = vehicle:getSquare()
    if not vsq then return end
    local success = ZombRandFloat(0.0, 1.0) <= chance
    local windowBroken = false
    local injury

    if success then
        Log.info("SUCCESS: Vehicle %s unlocked", tostring(part:getId()))
        if Utils.isCategoryEnabled("AlarmSuccess") then vehicle:setAlarmed(false) end
        applyVehicleUnlock(vehicle, part)
        recordAnalytics(playerObj, true)
        giveXP(playerObj, Perks.Mechanics, 3)
    else
        Log.info("FAIL: Vehicle %s unlocked", tostring(part:getId()))
        local fail = Utils.getFailureChances(playerObj)

        if ZombRandFloat(0.0, 1.0) <= clamp01(fail.PryChanceBreakVehicleLock) then
            if breakVehicleLock(vehicle, part) then Log.info("Vehicle lock broken on part=%s", tostring(part:getId())) end
        end
        if ZombRandFloat(0.0, 1.0) <= clamp01(fail.PryChanceBreakVehicleWindow) then
            windowBroken = smashVehicleWindow(playerObj, part) or false
        end

        if maybeTriggerVehicleAlarm(vehicle, fail.PryChanceAlarm) then Log.info("Vehicle alarm triggered") end

        injury = applyInjuryToHands(playerObj, fail, windowBroken)

        recordAnalytics(playerObj, false)
    end

    if vsq then addNoiseFrom(playerObj, vsq:getX(), vsq:getY(), vsq:getZ()) end

    if isServer() then
        Log.info("Command %s was sent to player %s", "SoundOutcome", playerObj:getUsername())
        sendServerCommand(playerObj, "STA_PryOpen", "SoundOutcome", { result = success, category = category, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        Log.info("Command %s was sent to player %s", "SayOutcome [425]", playerObj:getUsername())
        local message
        if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
        sendServerCommand(playerObj, "STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
    end
    if not isClient() and not isServer() then
        Log.info("Ran command: Sound Outcome on Single Player")
        STA_PryOpen_Sounds.onServerCommand("STA_PryOpen", "SoundOutcome", { result = success, category = category, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
        Log.info("Ran command: SayOutcome on Single Player [433]")
        local message
        if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
        STA_PryOpen_Client.onServerCommand("STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = playerObj:getOnlineID(), playerIndex = playerObj:getPlayerNum() or 0 })
    end
    giveXP(playerObj, Perks.Strength, 2)
    rollAndApplyDurability(playerObj)
end
-- OnClientCommand

local function onClientCommand(module, command, playerObj, args)
    if module ~= Server.modID then return end
    Log.info("Cmd '%s' from %s (steam=%s)", command, playerObj:getUsername(), tostring(playerObj:getSteamID()))
    if command == "PryWorld" then
        handlePryWorld(playerObj, args)
    elseif command == "PryVehicle" then
        handlePryVehicle(playerObj, args)
    else
        Log.warn("Unknown command '%s'", tostring(command))
    end
end

Events.OnClientCommand.Add(onClientCommand)

_G.STA_PryOpen_Server = Server
return Server