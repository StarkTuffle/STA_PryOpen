require "TimedActions/ISBaseTimedAction"
local Utils = require "STA_PryOpen_Utils"
local Log = require "STA_PryOpen_Log"

STA_PryOpen_ISPryOpenAction = ISBaseTimedAction:derive("STA_PryOpen_ISPryOpenAction");

STA_PryOpen_ISPryOpenAction.modID = "STA_PryOpen"

local function validateCommon(self)
    if not self.character or self.character:isDead() then return false end

    if not self.category or not Utils.isCategoryEnabled(self.category) then return false end

    self.crowbar = self.crowbar or Utils.findUsableCrowbar(self.character)
    if not self.crowbar then return false end

    local okStrength = Utils.meetsStrengthRequirement(self.character, self.category)
    if not okStrength then return false end

    return true
end

-- World Object Pry Timed Action

STA_PryOpen_ISPryOpenAction.World = ISBaseTimedAction:derive("STA_PryOpen_ISPryOpenAction.World")

function STA_PryOpen_ISPryOpenAction.World:isValid()
    if not validateCommon(self) then return false end

    local obj = self.target and self.target.obj
    if not obj then return false end
    if not Utils.isLockedWorldObject(obj) then return false end
    if Utils.isBarricadedForPlayer(obj, self.character) then return false end

    local sq = obj:getSquare()
    if not sq then return false end
    if self.character:DistToSquared(sq:getX() + 0.5, sq:getY() + 0.5) > 4 then return false end

    return true
end

function STA_PryOpen_ISPryOpenAction.World:waitToStart()
    self.character:faceThisObject(self.target.obj or self.character)
    return self.character:shouldBeTurning()
end

function STA_PryOpen_ISPryOpenAction.World:update()
    if self.target and self.target.obj then
        self.character:faceThisObject(self.target.obj)
    end
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function STA_PryOpen_ISPryOpenAction.World:start()
    Log.debug("TA start: %s @cat=%s", "World", self.category or Utils.getTargetCategory(self.target) or "nil")
    self:setActionAnim("RemoveBarricade")
    if self.target.type == "Window" then
        self:setAnimVariable("RemoveBarricade", "CrowbarHigh")
    else
        self:setAnimVariable("RemoveBarricade", "CrowbarMid")
    end

    if self.crowbar then
        self:setOverrideHandModels(self.crowbar, nil)
    end

    self.jobType = getText("ContextMenu_STA_PryOpen_JobLabel")
    local option = STA_PryOpen_Client.options.volumeAdjust
    local actionVolume = 1 - math.max(0, 1.1 - (option * 0.1))
    local gameVolume = getSoundManager():getSoundVolume()
    local emitter = self.character:getEmitter()
    local volume = gameVolume - ( gameVolume * actionVolume )
    emitter:setVolume(emitter:playSound("CrowbarHit"), volume)
end

function STA_PryOpen_ISPryOpenAction.World:stop()
    Log.debug("TA stop: %s (canceled=%s)", "World", tostring(self.character and self.character:isDoingActionThatCanBeCancelled()))
    if self.sound then
        self.character:getEmitter():stopSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function STA_PryOpen_ISPryOpenAction.World:complete()
end

function STA_PryOpen_ISPryOpenAction.World:canCancel()
    return true
end

function STA_PryOpen_ISPryOpenAction.World:perform()
    Log.info("TA perform sending: %s", "PryWorld")
    local obj = self.target and self.target.obj
    local sq = obj and obj:getSquare()

    if obj and sq then
        local payload = {
            x = sq:getX(),
            y = sq:getY(),
            z = sq:getZ(),
            crowbarID = self.crowbar:getID(),
            sprite = obj:getSprite() and obj:getSprite():getName() or "",
            category = self.category,
            worldObjects = self.target.worldObjects,
            px = self.character:getX(),
            py = self.character:getY(),
            pz = self.character:getZ(),
        }
        sendClientCommand(self.character, STA_PryOpen_ISPryOpenAction.modID, "PryWorld", payload)
    end
    ISBaseTimedAction.perform(self)
end

function STA_PryOpen_ISPryOpenAction.World:new(character, target, crowbar)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.player = character
    o.target = target
    o.category = Utils.getTargetCategory(target)
    o.crowbar = crowbar
    o.maxTime = Utils.computePryTimeTicks(character, o.category)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    return o
end

-- Vehicle Pry Timed Action

STA_PryOpen_ISPryOpenAction.Vehicle = ISBaseTimedAction:derive("STA_PryOpen_ISPryOpenAction.Vehicle")

function STA_PryOpen_ISPryOpenAction.Vehicle:isValid()
    if not validateCommon(self) then return false end

    local vehicle = self.target and self.target.vehicle
    local part = self.target and self.target.part

    if not vehicle then return false end
    if not part:getDoor() or not part:getDoor():isLocked() then return false end

    local area = vehicle:getAreaCenter(part:getArea())

    if not area then return false end
    if self.character:DistToSquared(area:getX() + 0.5, area:getY() + 0.5) > 4 then return false end

    return true
end

function STA_PryOpen_ISPryOpenAction.Vehicle:waitToStart()
    local vehicle = self.target and self.target.vehicle
    if vehicle then
        self.character:faceLocation(vehicle:getX(), vehicle:getY())
    end
    return self.character:shouldBeTurning()
end

function STA_PryOpen_ISPryOpenAction.Vehicle:update()
    local vehicle = self.target and self.target.vehicle
    if vehicle then
        self.character:faceLocation(vehicle:getX(), vehicle:getY())
    end

    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function STA_PryOpen_ISPryOpenAction.Vehicle:start()
    Log.debug("TA start: %s @cat=%s", "World", self.category or Utils.getTargetCategory(self.target) or "nil")
    self:setActionAnim("RemoveBarricade")
    self:setAnimVariable("RemoveBarricade", "CrowbarMid")
    
    if self.crowbar then
        self:setOverrideHandModels(self.crowbar, nil)
    end
    self.jobType = getText("ContextMenu_STA_PryOpen_JobLabel")

    self.sound = self.character:playSound("CrowbarHit")

    self.character:reportEvent("EventWashClothing")
end

function STA_PryOpen_ISPryOpenAction.Vehicle:stop()
    Log.debug("TA stop: %s (canceled=%s)", "Vehicle", tostring(self.character and self.character:isDoingActionThatCanBeCancelled()))
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function STA_PryOpen_ISPryOpenAction.Vehicle:canCancel()
    return true
end

function STA_PryOpen_ISPryOpenAction.Vehicle:perform()
    Log.info("TA perform sending: %s", "PryVehicle")

    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end

    local vehicle = self.target and self.target.vehicle
    local part = self.target and self.target.part
    if vehicle and part then
        local payload = {
            vehicleId = vehicle:getId(),
            partId = part:getId(),
            category = self.category,
            crowbarID = self.crowbar:getID(),
            px = self.character:getX(),
            py = self.character:getY(),
            pz = self.character:getZ(),
        }
        sendClientCommand(self.character, STA_PryOpen_ISPryOpenAction.modID, "PryVehicle", payload)
    end
    ISBaseTimedAction.perform(self)
end

function STA_PryOpen_ISPryOpenAction.Vehicle:new(character, target, crowbar)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.player = character
    o.target = target
    o.category = Utils.getTargetCategory(target)
    o.crowbar = crowbar
    o.maxTime = Utils.computePryTimeTicks(character, o.category)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    return o
end

return STA_PryOpen_ISPryOpenAction