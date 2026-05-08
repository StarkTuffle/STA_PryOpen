require "TimedActions/STA_PryOpen_ISPryOpenAction"
local Utils = require "STA_PryOpen_Utils"
local Log = require "STA_PryOpen_Log"

ContextMenu = STA_PryOpen_ISContextMenu or {}
ContextMenu.modID = "STA_PryOpen"

local function clamp01(text,x)

    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

-- REMOVE WHEN ABLE: Jank code to fix issue with Garage Door sprites not being pick up by OnFillWorldObjectContextMenu event
local function getOriginSquare(worldObjects, playerObj)
    if worldObjects and #worldObjects > 0 then
        return worldObjects[1]:getSquare()
    end
    return playerObj and playerObj:getCurrentSquare()
end

local function collectSquareObjects(sq)
    local out = {}
    if not sq then return out end

    local objs = sq:getObjects()
    if objs then
        for i = 0, objs:size() - 1 do
            out[#out+1] = objs:get(i)
        end
    end

    local wobjs = sq:getWorldObjects()
    if wobjs then
        for i = 0, wobjs:size() - 1 do
            out[#out+1] = wobjs:get(i)
        end
    end
    return out
end
-- End of jank

local function buildDisableReasons(playerObj, category)
    local reasons = {}

    local crowbar = Utils.findUsableCrowbar(playerObj)
    if not crowbar then
        reasons[#reasons+1] = { "Tooltip_STA_PryOpen_NeedCrowbar" }
        playerObj:Say(getText("IGUI_STA_PryOpen_NeedCrowbar"))
    end

    local ok, current, required = Utils.meetsStrengthRequirement(playerObj, category)
    if not ok then
        reasons[#reasons+1] = { "Tooltip_STA_PryOpen_ReqStrength", tostring(required), tostring(current) }
        playerObj:Say(getText("IGUI_STA_PryOpen_RequiresStrength", tostring(required)))
    end

    return reasons
end

function ContextMenu.onPrySelect(target)
    local playerObj = target.player
    if not playerObj or playerObj:isDead() then return end
    
    local category = Utils.getTargetCategory(target)
    if not category or not Utils.isCategoryEnabled(category) then Log.debug("Client select denied: category not enabled") return end

    local crowbar = Utils.findUsableCrowbar(playerObj)
    if not crowbar then return end
    local crowbarID = crowbar:getFullType()
    local reasons = buildDisableReasons(playerObj)

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, crowbar)
    if not playerObj:hasEquipped(crowbarID) then
        ISInventoryPaneContextMenu.equipWeapon(crowbar, true, true, playerObj:getPlayerNum())
    end

    if #reasons > 0 then
        Log.debug("Client select denied: %d disable reasons", #reasons)
        return
    end

    Log.info("Queue TA: type=%s category=%s", target.type, category or "nil")
    if target.type == "world" then
        local obj = target.obj
        if not obj or not Utils.isLockedWorldObject(obj) or Utils.isBarricadedForPlayer(obj, playerObj) then
            playerObj:Say(getText("IGUI_STA_PryOpen_CantPry"))
            return
        end
        ISTimedActionQueue.add(STA_PryOpen_ISPryOpenAction.World:new(playerObj, target, crowbar))
    elseif target.type == "vehicle" then
        local part = target.part
        if not part or not part:getDoor() or not part:getDoor():isLocked() then
            playerObj:Say(getText("IGUI_STA_PryOpen_NoLockedVehiclePart"))
            return
        end
        ISTimedActionQueue.add(STA_PryOpen_ISPryOpenAction.Vehicle:new(playerObj, target, crowbar))
    end
end

local function attachTooltip(option, playerObj, target)
    if not option or not playerObj or not target then return end
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = getText("Tooltip_craft_Needs") .. " : <LINE>"
    option.toolTip = tooltip

    local category = Utils.getTargetCategory(target)
    local crowbar = Utils.findUsableCrowbar(playerObj)
    local ok, current, required = Utils.meetsStrengthRequirement(playerObj, category)
    local success = Utils.computePrySuccessChance(playerObj, category, crowbar)
    local fail = Utils.getFailureChances(playerObj)
    local injury = (0.5 * fail.PryChanceInjuryL) + (0.5 * fail.PryChanceInjuryR)
    local injuryMax = math.floor((100 * (clamp01("injuryMax",(Utils.getSandboxNum("PryChanceInjury", Utils.SandboxDefaults["PryChanceInjury"]) + Utils.getSandboxNum("PryBonusTraitSkin", Utils.SandboxDefaults["PryBonusTraitSkin"])))) + 0.5) or 0)
    local damage

    if current < required then option.notAvailable = true end
    if target.type == "world" and not Utils.isLockedWorldObject(target.obj) then
        tooltip.description = getText("Tooltip_STA_PryOpen_alreadyUnlocked", getText("ContextMenu_STA_PryOpen_" .. tostring(category)))
        option.toolTip = tooltip
        option.notAvailable = true
        return
    end

    if category == "Window" then
        damage = fail.PryChanceBreakWindow
    elseif category == "Vehicle" then
        damage = (fail.PryChanceBreakVehicleWindow + fail.PryChanceBreakVehicleLock) - (fail.PryChanceBreakVehicleWindow * fail.PryChanceBreakVehicleLock)
    elseif category == "Trunk" then
        damage = fail.PryChanceBreakVehicleLock
    end

    if success then success = math.floor((100 * (clamp01("success",success)) + 0.5) or 0) end
    if injury then injury = math.floor((100 * (clamp01("injury",injury)) + 0.5) or 0) end
    if damage then damage = math.floor((100 * (clamp01("damage",damage)) + 0.5) or 0) end

    if not crowbar then
        tooltip.description = tooltip.description .. " " .. ISVehicleMechanics.bhs .. getItemNameFromFullType("Base.Crowbar") .. " 0/1 <LINE>"
    else
        tooltip.description = tooltip.description .. " " .. ISVehicleMechanics.ghs .. getItemNameFromFullType("Base.Crowbar") .. " 1/1 <LINE>"
    end

    local rgb = ISVehicleMechanics.ghs
    if not ok then rgb = ISVehicleMechanics.bhs end
    tooltip.description = tooltip.description .. " " .. rgb .. getText("IGUI_perks_Strength") .. " " .. current .. "/" .. required .. " <LINE>"

    tooltip.description = tooltip.description .. " <LINE>"

    if success and success <= 100 and success >= 0 then
        local successCol = ColorInfo.new(1, 1, 1, 0)
        getCore():getBadHighlitedColor():interp(getCore():getGoodHighlitedColor(), success/100, successCol)
        local colorSuccess = "<RGB:" .. successCol:getR() .. "," .. successCol:getG() .. "," .. successCol:getB() .. ">"
        tooltip.description = tooltip.description .. colorSuccess .. getText("Tooltip_chanceSuccess") .. " " .. success .. "% <LINE>"
    end

    if injury and injury <= injuryMax and injury >= 0 then
        local injuryCol = ColorInfo.new(1, 1, 1, 0)
        getCore():getGoodHighlitedColor():interp(getCore():getBadHighlitedColor(), injury/injuryMax, injuryCol)
        local colorInjury = "<RGB:" .. injuryCol:getR() .. "," .. injuryCol:getG() .. "," .. injuryCol:getB() .. ">"
        tooltip.description = tooltip.description .. colorInjury .. getText("Tooltip_STA_PryOpen_chanceInjury") .. " " .. injury .. "% <LINE>"
    end

    if damage then
        tooltip.description = tooltip.description .. "<RGB:1,1,1>" .. getText("Tooltip_chanceFailure") .. " " .. damage .. "% <LINE>"
    end
end

function ContextMenu.onFillWorldContext(playerIdx, context, worldObjects, test)
    local player = getSpecificPlayer(playerIdx)

    if not player or player:isDead() then return end
    if not Utils.findUsableCrowbar(player) then return end

    local target = nil

    local worldObj = Utils.findWorldTarget(worldObjects, player)
    -- REMOVE WHEN ABLE: Jank code to fix issue with Garage Door sprites not being pick up by OnFillWorldObjectContextMenu event
    if not worldObj then
        local originSq = getOriginSquare(worldObjects, player)
        local cell = getCell()
        local x,y,z = originSq:getX(), originSq:getY(), originSq:getZ()
        local offsets = { {1,0},{1,1},{1,0},{2,0},{2,2},{0,2},{3,0},{3,3},{0,3} }

        for i = 1, #offsets do
            local nx, ny = x + offsets[i][1], y + offsets[i][2]
            local nsq = cell:getGridSquare(nx, ny, z)
            if nsq then
                local neighborObjects = collectSquareObjects(nsq)
                worldObj = Utils.findWorldTarget(neighborObjects, player)
                if worldObj and Utils.getWorldCategoryForObject(worldObj) == "Garage" then break end
            end
        end
    end
    -- End of jank
    if worldObj then
        target = { type = "world", obj = worldObj, player = player, worldObjects = worldObjects }
    end

    if not target then
        local vehicle = Utils.findVehicleAtContext(player, worldObjects)
        local part = Utils.findLockedVehicleTargetPart(player, vehicle)
        if vehicle and part then
            local t = { type = "vehicle", vehicle = vehicle, part = part, player = player }
            local category = Utils.getTargetCategory(t)
            if category and Utils.isCategoryEnabled(category) then
                target = t
            end
        end
    end

    if not target then return end

    local label = Utils.buildLabelForTarget(target)
    local option = context:addOption(label, target, ContextMenu.onPrySelect)
    local category = Utils.getTargetCategory(target)
    attachTooltip(option, player, target)
    Log.debug("Add option: label='%s' type=%s cat=%s", label, target.type, category or "nil")
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldContext)

_G.STA_PryOpen_ISContextMenu = ContextMenu
return ContextMenu