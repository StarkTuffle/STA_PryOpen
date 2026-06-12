require "TimedActions/ISBaseTimedAction"
local Utils = require "STA_PryOpen_Utils"
local Log = require "STA_PryOpen_Log"

STA_PryOpen_ISPryOpenAction = ISBaseTimedAction:derive("STA_PryOpen_ISPryOpenAction")

STA_PryOpen_ISPryOpenAction.modID = "STA_PryOpen"

local function validateCommon(self)
    if not self.character or self.character:isDead() then
        return false
    end

    if not self.category or not Utils.isCategoryEnabled(self.category) then
        return false
    end

    self.crowbar = self.crowbar or Utils.findUsablePryTool(self.character)
    if not self.crowbar then return false end

    local okStrength = Utils.meetsStrengthRequirement(self.character, self.category)
    if not okStrength then
        return false
    end

    return true
end

function STA_PryOpen_ISPryOpenAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    Log.debug("getDuration character:%s category:%s", tostring(self.character), tostring(self.category))
    return Utils.computePryTimeTicks(self.character, self.category)
end

function STA_PryOpen_ISPryOpenAction:isValid()
    if not validateCommon(self) then return false end

    if self.type == "World" then
        local obj = self.target
        if not (obj and Utils.isLockedWorldObject(obj)) then return false end
        if Utils.isBarricadedForPlayer(obj, self.character) then return false end

        local sq = obj:getSquare()
        if not sq or self.character:DistToSquared(sq:getX()+0.5, sq:getY()+0.5) > 4 then return false end

        return true
    elseif self.type == "Vehicle" then
        local part = self.target
        local vehicle = part:getVehicle()
        if not (vehicle and part and part:getDoor() and part:getDoor():isLocked()) then return false end

        local area = vehicle:getAreaCenter(part:getArea())
        if not area or self.character:DistToSquared(area:getX()+0.5, area:getY()+0.5) > 4 then return false end

        return true
    end
    return false
end

function STA_PryOpen_ISPryOpenAction:waitToStart()
    if self.type == "World" and self.target then
        self.character:faceThisObject(self.target)
    elseif self.type == "Vehicle" then
        self.character:faceLocation(self.target:getVehicle():getX(), self.target:getVehicle():getY())
    end
    return self.character:shouldBeTurning()
end

function STA_PryOpen_ISPryOpenAction:update()
    if self.type == "World" and self.target then
        self.character:faceThisObject(self.target)
    elseif self.type == "Vehicle" and self.target then
        self.character:faceLocation(self.target:getVehicle():getX(), self.target:getVehicle():getY())
    end
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)

    self.crowbar:setJobDelta(self:getJobDelta())
    local skill = self.character:getPerkLevel(Perks.Strength)
    local strain = (1 - (skill * 0.05))/10 * getGameTime():getMultiplier()
    if self.crowbar then
        self.character:addCombatMuscleStrain(self.crowbar, 1, strain)
    end
end

function STA_PryOpen_ISPryOpenAction:start()
    local Config = require "STA_PryOpen_ModOptions"
    Log.debug("TA start: type=%s category=%s", tostring(self.target.type), tostring(self.category))

    self:setActionAnim("RemoveBarricade")
    if self.type == "World" and self.category == "Window" then
        self:setAnimVariable("RemoveBarricade", "CrowbarHigh")
    else
        self:setAnimVariable("RemoveBarricade", "CrowbarMid")
    end

    if self.crowbar then self:setOverrideHandModels(self.crowbar, nil) end

    self.crowbar:setJobType(getText("ContextMenu_STA_PryOpen_JobLabel"))
    self.crowbar:setJobDelta(0.0)
    local actionVolume = 0.5
    if Config and Config["volumeAdjust"] then
        actionVolume = 1 - Config["volumeAdjust"]
    end
    local gameVolume = getSoundManager():getSoundVolume()
    local emitter = self.character:getEmitter()
    local volume = gameVolume - ( gameVolume * actionVolume )
    self.sound = emitter:setVolume(emitter:playSound("CrowbarHit"), volume)
end

function STA_PryOpen_ISPryOpenAction:stop()
    if self.sound then self.character:getEmitter():stopSound(self.sound) end
    ISBaseTimedAction.stop(self)
    self.crowbar:setJobDelta(0.0)
end

function STA_PryOpen_ISPryOpenAction:perform()
    if self.sound then self.character:getEmitter():stopSound(self.sound) end
    
    self.crowbar:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function STA_PryOpen_ISPryOpenAction:complete()
    if self.type == "World" then
        local obj = self.target
        if not obj then return end
        local sq = obj:getSquare()
        if not sq then return end
        local worldObjects = sq:getWorldObjects()
        if not worldObjects then return end
        Log.debug("World target: sprite=%s cat=%s", tostring(obj:getSprite():getName()), self.category)

        if not Utils.isCategoryEnabled(self.category) then Log.info("Denied: category disabled (%s)", self.category) return end
        if not Utils.meetsStrengthRequirement(self.character, self.category) then Log.info("Denied: strength too low for %s", self.category) return end
        if not Utils.findUsablePryTool(self.character) then Log.info("Denied: no crowbar") return end
        if not Utils.isLockedWorldObject(obj) then Log.info("Denied: not locked") return end
        if Utils.isBarricadedForPlayer(obj, self.character) then Log.info("Denied: is barricaded for player") return end

        local chance = Utils.clamp(Utils.computePrySuccessChance(self.character, self.category, self.crowbar))
        Log.info("Roll: cat=%s chance=%.2f", self.category, chance)

        if self.category == "Window" then
            sq = obj:getIndoorSquare()
        else
            sq = obj:getOtherSideOfDoor(self.character)
            if sq:isOutside() then
                Log.debug("Square for %s is outside; checking adjacent squares", self.category)

                local cell = getCell()
                local x,y,z = sq:getX(), sq:getY(), sq:getZ()
                local offsets = {{1,0},{0,1},{0,-1},{-1,0}}
                for i = 1, #offsets do
                    local nx, ny = x + offsets[i][1], y + offsets[i][2]
                    local nsq = cell:getGridSquare(nx, ny, z)
                    if not nsq:isOutside() then
                        sq = nsq
                        break
                    end
                end
                if not sq then
                    Log.error("No building found for %s; aborting", self.category)
                    return
                end
            end
        end

        local success = (ZombRandFloat(0.0, 1.0) <= chance)
        local windowBroke = false
        local injury = false

        if success then
            Log.info("SUCCESS: %s unlocked @ %d,%d,%d", self.category, sq:getX(), sq:getY(), sq:getZ())
            if Utils.isCategoryEnabled("AlarmSuccess") then
                if not sq:isOutside() then
                    sq:getBuilding():getDef():setAlarmed(false)
                end
            end

            if instanceof(obj, "IsoWindow") then
                obj:setIsLocked(false)
                obj:setPermaLocked(false)
            elseif instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor()) then
                obj:setLockedByKey(false)
                obj:setLocked(false)
            end
            obj:sync()
            if isServer() then
                sendServerCommand(self.character, "STA_PryOpen", "DoClientOpenAnim", { x=obj:getX(), y=obj:getY(), z=obj:getZ(), playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
            end
            if not isClient() and not isServer() then
                STA_PryOpen_Client.onServerCommand("STA_PryOpen", "DoClientOpenAnim", { x=obj:getX(), y=obj:getY(), z=obj:getZ(), playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
            end

            Utils.setObjectModData(self.character, "failStreak", 0)
            if self.category == "Building" or self.category == "Window" then
                self.character:getXp():AddXP(Perks.Woodwork, 3)
            elseif self.category == "Secure" or self.category == "Garage" then
                self.character:getXp():AddXP(Perks.Blacksmith, 3)
            end
            addSound(self.character, sq:getX(), sq:getY(), sq:getZ(), Utils.computeNoiseRadius(self.character)/2, 10)
        else
            Log.info("FAIL: %s @ %d,%d,%d", self.category, sq:getX(), sq:getY(), sq:getZ())
            local fail = Utils.computeFailureChances(self.character)

            if instanceof(obj, "IsoWindow") then
                local breakWindowChance = ZombRandFloat(0.0, 1.0)
                local breakWindowDC = Utils.clamp(fail.PryChanceBreakWindow)
                Log.info("Break Window Roll: chance=%.2f dc=%.2f", breakWindowChance, breakWindowDC)
                if breakWindowChance <= breakWindowDC then
                    windowBroke = true
                    obj:smashWindow()
                    obj:transmitUpdatedSpriteToClients()
                end
            end

            if sq then
                -- local building = sq:getBuilding():getDef()
                local building, room
                if not sq:isOutside() then
                    building = sq:getBuilding():getDef()
                    room = sq:getRoom():getRoomDef()
                end

                if building and room then
                    if Utils.isCategoryEnabled("AlarmForce") then
                        building:setAlarmed(false)

                        local alarmChance = ZombRandFloat(0.0, 1.0)
                        local alarmDC = Utils.clamp(fail.PryChanceAlarm)
                        Log.info("Alarm Roll: chance=%.2f dc=%.2f", alarmChance, fail.PryChanceAlarm)

                        if alarmChance <= alarmDC then
                            local sOpt = getSandboxOptions()
                            local decayOpt = sOpt:getOptionByName("AlarmDecay")
                            local alarmDecay = sOpt:randomAlarmDecay(decayOpt:getValue())
                            if sq:hasGridPower(alarmDecay) then
                                building:setAlarmed(true)
                                getAmbientStreamManager():doAlarm(room)
                            end
                        end
                    elseif building:isAlarmed() then
                        getAmbientStreamManager():doAlarm(room)
                    end
                end
            end

            local injL, injR = 0.5 * fail.PryChanceInjuryL, 0.5 * fail.PryChanceInjuryR
            local scr, cut, dpw = fail.InjurySeverity[1], fail.InjurySeverity[2], fail.InjurySeverity[3]

            local bd = self.character:getBodyDamage()
            if bd then
                local injChance = ZombRandFloat(0.0, 1.0)
                Log.info("Injury Roll: chance=%.2f injL=%.2f injR=%.2f", injChance, injL, injL + injR)
                if injChance <= injL then
                    if injChance <= (injL * scr) then
                        bd:getBodyPart(BodyPartType.Hand_L):setScratched(true, true)
                    elseif injChance > (injL * scr) and injChance <= (injL * (cut + scr)) then
                        bd:getBodyPart(BodyPartType.Hand_L):setCut(true, true)
                    elseif injChance > (injL * (cut + scr)) and injChance <= (injL * (cut + scr + dpw)) then
                        if windowBroke then bd:getBodyPart(BodyPartType.Hand_L):generateDeepShardWound()
                        else bd:getBodyPart(BodyPartType.Hand_L):generateDeepWound() end
                    else
                        Log.debug("Injury sevarity chance unexpected. Roll: chance%.2f max%.2f", injChance, (injL * (cut + scr + dpw)))
                        bd:getBodyPart(BodyPartType.Hand_L):setAdditionalPain(30)
                    end
                    injury = true
                elseif injChance > injL and injChance <= injL + injR then
                    if injChance <= ((injL + injR) * scr) then
                        bd:getBodyPart(BodyPartType.Hand_R):setScratched(true, true)
                    elseif injChance > ((injL + injR) * scr) and injChance <= ((injL + injR) * (cut + scr)) then
                        bd:getBodyPart(BodyPartType.Hand_R):setCut(true, true)
                    elseif injChance > ((injL + injR) * (cut + scr)) and injChance <= ((injL + injR) * (cut + scr + dpw)) then
                        if windowBroke then bd:getBodyPart(BodyPartType.Hand_L):generateDeepShardWound()
                        else bd:getBodyPart(BodyPartType.Hand_R):generateDeepWound() end
                    else
                        Log.debug("Injury sevarity chance unexpected. Roll: chance%.2f max%.2f", injChance, ((injL + injR) * (cut + scr + dpw)))
                        bd:getBodyPart(BodyPartType.Hand_R):setAdditionalPain(30)
                    end
                    injury = true
                end
            end
            Utils.setObjectModData(self.character, "failStreak", (Utils.getObjectModData(self.character, "failStreak") or 0) + 1)
            addSound(self.character, sq:getX(), sq:getY(), sq:getZ(), Utils.computeNoiseRadius(self.character), 10)
        end
        if isServer() then
            sendServerCommand(self.character, "STA_PryOpen", "SoundOutcome", { result = success, category = self.category, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
            local message
            if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
            sendServerCommand(self.character, "STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
        end
        if not isClient() and not isServer() then
            STA_PryOpen_Sounds.onServerCommand("STA_PryOpen", "SoundOutcome", { result = success, category = self.category, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
            local message
            if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
            STA_PryOpen_Client.onServerCommand("STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
        end
    elseif self.type == "Vehicle" then
        local part = self.target
        local vehicle = part:getVehicle()
        if not (part and vehicle) then return end
        Log.debug("Vehicle target: id=%s part=%s cat=%s", tostring(vehicle:getId()), tostring(part:getId()), self.category)

        if not Utils.isCategoryEnabled(self.category) then return end
        if not Utils.meetsStrengthRequirement(self.character, self.category) then return end
        if not Utils.findUsablePryTool(self.character) then return end
        if not part:getDoor() or not part:getDoor():isLocked() then return end

        local chance = Utils.clamp(Utils.computePrySuccessChance(self.character, self.category, self.crowbar))
        Log.info("Roll: cat=%s chance=%.2f", self.category, chance)

        local vsq = vehicle:getSquare()
        if not vsq then return end
        local success = ZombRandFloat(0.0, 1.0) <= chance
        local windowBroken = false
        local injury = false

        if success then
            Log.info("SUCCESS: Vehicle %s unlocked", tostring(part:getId()))
            if Utils.isCategoryEnabled("AlarmSuccess") then vehicle:setAlarmed(false) end
            if part:getDoor() then
                part:getDoor():setLocked(false)
            end
            if vehicle.transmitPartDoor then
                vehicle:transmitPartDoor(part)
            end
            Utils.setObjectModData(self.character, "failStreak", 0)
            self.character:getXp():AddXP(Perks.Mechanics, 3)
            addSound(self.character, vsq:getX(), vsq:getY(), vsq:getZ(), Utils.computeNoiseRadius(self.character)/2, 10)
        else
            Log.info("FAIL: Vehicle %s unlocked", tostring(part:getId()))
            local fail = Utils.computeFailureChances(self.character)

            local breakLockChance = ZombRandFloat(0.0, 1.0)
            local breakLockDC = Utils.clamp(fail.PryChanceBreakVehicleLock)
            Log.info("Break Lock Roll: chance=%.2f dc=%.2f", breakLockChance, breakLockDC)
            if breakLockChance <= breakLockDC then
                if not part:getDoor():isLockBroken() then
                    part:getDoor():setLockBroken(true)
                    if vehicle.transmitPartModData then
                        vehicle:transmitPartModData(part)
                    end
                end
            end
            local breakWindowChance = ZombRandFloat(0.0, 1.0)
            local breakWindowDC = Utils.clamp(fail.PryChanceBreakVehicleWindow)
            Log.info("Break Window Roll: chance=%.2f dc=%.2f", breakWindowChance, breakWindowDC)
            if breakWindowChance <= breakWindowDC then
                local window = part:getChildWindow()
                if window then window = window:getWindow() end
                if window and not (window:isOpen() or window:isDestroyed()) then
                    windowBroken = true
                    window:hit(self.character)
                end
            end

            local alarmChance = ZombRandFloat(0.0, 1.0)
            local alarmDC = Utils.clamp(fail.PryChanceAlarm)
            Log.info("Alarm Roll: chance=%.2f dc=%.2f", alarmChance, alarmDC)
            if alarmChance <= alarmDC then
                if Utils.isCategoryEnabled("AlarmForce") then
                    local alarmForced = Utils.getObjectModData(vehicle,"forcedAlarm")
                    if not alarmForced then
                        vehicle:setAlarmed(true)
                        vehicle:triggerAlarm()
                        Utils.setObjectModData(vehicle, "forcedAlarm", true)
                    end
                elseif vehicle:isAlarmed() then
                    vehicle:triggerAlarm()
                end
            end

            local injL, injR = 0.5 * fail.PryChanceInjuryL, 0.5 * fail.PryChanceInjuryR
            local scr, cut, dpw = fail.InjurySeverity[1], fail.InjurySeverity[2], fail.InjurySeverity[3]

            local bd = self.character:getBodyDamage()
            if bd then
                local injChance = ZombRandFloat(0.0, 1.0)
                Log.info("Injury Roll: chance=%.2f injL=%.2f injR=%.2f", injChance, injL, injL + injR)
                if injChance <= injL then
                    if injChance <= (injL * scr) then
                        bd:getBodyPart(BodyPartType.Hand_L):setScratched(true, true)
                    elseif injChance > (injL * scr) and injChance <= (injL * (cut + scr)) then
                        bd:getBodyPart(BodyPartType.Hand_L):setCut(true, true)
                    elseif injChance > (injL * (cut + scr)) and injChance <= (injL * (cut + scr + dpw)) then
                        if windowBroken then bd:getBodyPart(BodyPartType.Hand_L):generateDeepShardWound()
                        else bd:getBodyPart(BodyPartType.Hand_L):generateDeepWound() end
                    else
                        Log.debug("Injury sevarity chance unexpected. Roll: chance%.2f max%.2f", injChance, (injL * (cut + scr + dpw)))
                        bd:getBodyPart(BodyPartType.Hand_L):setAdditionalPain(30)
                    end
                elseif injChance > injL and injChance <= injL + injR then
                    if injChance <= ((injL + injR) * scr) then
                        bd:getBodyPart(BodyPartType.Hand_R):setScratched(true, true)
                    elseif injChance > ((injL + injR) * scr) and injChance <= ((injL + injR) * (cut + scr)) then
                        bd:getBodyPart(BodyPartType.Hand_R):setCut(true, true)
                    elseif injChance > ((injL + injR) * (cut + scr)) and injChance <= ((injL + injR) * (cut + scr + dpw)) then
                        if windowBroken then bd:getBodyPart(BodyPartType.Hand_L):generateDeepShardWound()
                        else bd:getBodyPart(BodyPartType.Hand_R):generateDeepWound() end
                    else
                        Log.debug("Injury sevarity chance unexpected. Roll: chance%.2f max%.2f", injChance, ((injL + injR) * (cut + scr + dpw)))
                        bd:getBodyPart(BodyPartType.Hand_R):setAdditionalPain(30)
                    end
                end
            end
            Utils.setObjectModData(self.character, "failStreak", (Utils.getObjectModData(self.character, "failStreak") or 0) + 1)
            addSound(self.character, vsq:getX(), vsq:getY(), vsq:getZ(), Utils.computeNoiseRadius(self.character), 10)
        end

        if isServer() then
            sendServerCommand(self.character, "STA_PryOpen", "SoundOutcome", { result = success, category = self.category, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
            local message
            if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
            sendServerCommand(self.character, "STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
        end
        if not isClient() and not isServer() then
            STA_PryOpen_Sounds.onServerCommand("STA_PryOpen", "SoundOutcome", { result = success, category = self.category, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
            local message
            if success then message = "Success" elseif injury then message = "Injury" else message = "Failure" end
            STA_PryOpen_Client.onServerCommand("STA_PryOpen", "SayOutcome", { message = message, playerOnlineID = self.character:getOnlineID(), playerIndex = self.character:getPlayerNum() or 0 })
        end
    end

    self.character:getXp():AddXP(Perks.Strength, 2)
    local equippedItemIsCrowbar = false
    if not Utils.isEquippedItemValidPryTool(self.crowbar) then
        self.crowbar = Utils.findUsablePryTool(self.character)
    end
    -- if self.crowbar:hasTag(ItemTag.CROWBAR) then
    --     equippedItemIsCrowbar = true
    -- end
    -- if not equippedItemIsCrowbar then
    --     self.crowbar = Utils.findUsablePryTool(self.character)
    -- end
    if self.crowbar:damageCheck(0,1,true) then
        self.character:getXp():AddXP(Perks.Maintenance, 2)
    end

    return true
end

---@param character IsoPlayer
---@param target IsoThumpable | VehiclePart
---@param crowbar InventoryItem
---@param category string
---@param type string
---@return ISBaseTimedAction
function STA_PryOpen_ISPryOpenAction:new(character, target, crowbar, category, type)
    Log.debug("character:%s target:%s crowbar:%s category:%s type:%s", tostring(character), tostring(target), tostring(crowbar), category, type)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.target = target
    o.crowbar = crowbar
    o.category = category
    o.type = type
    o.maxTime = o:getDuration()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.caloriesModifier = 8
    return o
end

return STA_PryOpen_ISPryOpenAction