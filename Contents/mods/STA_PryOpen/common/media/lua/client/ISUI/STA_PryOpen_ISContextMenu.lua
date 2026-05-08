local Utils = require "STA_PryOpen_Utils"
local Log = require "STA_PryOpen_Log"
ContextMenu = STA_PryOpen_ISContextMenu or {}
Log.info("Module loaded: STA_PryOpen_ISContextMenu")
ContextMenu.modID = "STA_PryOpen"

-- Still jank

---@param worldObjects ArrayList<IsoObject>
---@param playerObj IsoPlayer
---@return IsoGridSquare
local function getOriginSquare(worldObjects, playerObj)
    if worldObjects and #worldObjects > 0 then
        return worldObjects[1]:getSquare()
    end
    return playerObj and playerObj:getCurrentSquare()
end

---@param sq IsoGridSquare
---@return table
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

---@param playerObj IsoPlayer
---@param category string
---@return table
local function buildDisableReasons(playerObj, category)
    local reasons = {}

    local crowbar = Utils.findUsablePryTool(playerObj)
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

---@param playerObj IsoPlayer
---@param target IsoThumpable | VehiclePart
---@param type string
---@return nil
function ContextMenu.onPrySelect(playerObj, target, category, type)
    Log.debug("player:%s target:%s category:%s type:%s", tostring(playerObj), tostring(target), tostring(category), tostring(type))
    if not (playerObj and target and category and type) then return end
    if playerObj:isDead() or not Utils.isCategoryEnabled(category) then return end

    local crowbar = Utils.findUsablePryTool(playerObj)
    if not crowbar then return end
    local crowbarID = crowbar:getFullType()
    local reasons = buildDisableReasons(playerObj, category)

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, crowbar)
    if not playerObj:hasEquipped(crowbarID) then
        ISInventoryPaneContextMenu.equipWeapon(crowbar, true, true, playerObj:getPlayerNum())
    end

    if #reasons > 0 then
        Log.debug("Client select denied: %d disable reasons", #reasons)
        return
    end

    Log.info("Queue TA: type=%s category=%s", type, category or "nil")
    if type == "World" then
        ---@cast target IsoThumpable
        if not Utils.isLockedWorldObject(target) or Utils.isBarricadedForPlayer(target, playerObj) then
            playerObj:Say(getText("IGUI_STA_PryOpen_CantPry"))
            return
        end
    elseif type == "Vehicle" then
        ---@cast target VehiclePart
        if not target:getDoor() or not target:getDoor():isLocked() then
            playerObj:Say(getText("IGUI_STA_PryOpen_NoLockedVehiclePart"))
            return
        end
    end
    ISTimedActionQueue.add(STA_PryOpen_ISPryOpenAction:new(playerObj, target, crowbar, category, type))
end

---@class option umbrella.ISContextMenu.Option
---@param playerObj IsoPlayer
---@param target IsoObject | VehiclePart
---@param category string | nil
---@param type string
local function attachTooltip(option, playerObj, target, category, type)
    if not (option and playerObj and target and type and category) then return end

    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = getText("Tooltip_craft_Needs") .. " : <LINE>"
    option.toolTip = tooltip

    local crowbar = Utils.findUsablePryTool(playerObj)
    local ok, current, required = Utils.meetsStrengthRequirement(playerObj, category)
    local success = Utils.computePrySuccessChance(playerObj, category, crowbar)
    local fail = Utils.computeFailureChances(playerObj)
    local injury = (0.5 * fail.PryChanceInjuryL) + (0.5 * fail.PryChanceInjuryR)
    local injuryMax = math.floor((100 * (Utils.clamp(Utils.getSandboxNum("PryChanceInjury") + Utils.getSandboxNum("PryBonusTraitSkin")))) or 0)
    local damage

    if current < required then option.notAvailable = true end
    if type == "World" and not Utils.isLockedWorldObject(target) then
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

    if success then success = Utils.clamp(math.floor((100 * (Utils.clamp(success)) + 0.5) or 0), 0, 100) end
    if injury then injury = math.floor((100 * (Utils.clamp(injury)) + 0.5) or 0) end
    if damage then damage = math.floor((100 * (Utils.clamp(damage)) + 0.5) or 0) end

    if not crowbar then
        tooltip.description = tooltip.description .. " " .. ISVehicleMechanics.bhs .. getItemDisplayName("Base.Crowbar") .. " 0/1 <LINE>"
    else
        tooltip.description = tooltip.description .. " " .. ISVehicleMechanics.ghs .. getItemDisplayName("Base.Crowbar") .. " 1/1 <LINE>"
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

---@param playerIdx integer
---@param context ISContextMenu
---@param worldObjects ArrayList<IsoObject>
---@param test boolean
function ContextMenu.onFillWorldContext(playerIdx, context, worldObjects, test)
    local playerObj = getSpecificPlayer(playerIdx)
    if not playerObj then return end
    if not Utils.findUsablePryTool(playerObj) then return end

    local category, label, option
    local worldObj = Utils.findWorldTarget(worldObjects, playerObj)
    -- REMOVE WHEN ABLE: Jank code to fix issue with Garage Door sprites not being pick up by OnFillWorldObjectContextMenu event
    if not worldObj then
        local originSq = getOriginSquare(worldObjects, playerObj)
        local cell = getCell()
        local x,y,z = originSq:getX(), originSq:getY(), originSq:getZ()
        local offsets = { {1,0},{1,1},{1,0},{2,0},{2,2},{0,2},{3,0},{3,3},{0,3} }

        for i = 1, #offsets do
            local nx, ny = x + offsets[i][1], y + offsets[i][2]
            local nsq = cell:getGridSquare(nx, ny, z)
            if nsq then
                local neighborObjects = collectSquareObjects(nsq)
                worldObj = Utils.findWorldTarget(neighborObjects, playerObj)
                if worldObj and Utils.getWorldCategoryForObject(worldObj) == "Garage" then break end
            end
        end
    end
    -- End of jank
    local vehicle = Utils.findVehicleAtContext(playerObj, worldObjects)
    local part = Utils.findLockedVehicleTargetPart(playerObj, vehicle)

    if worldObj then
        category = Utils.getWorldCategoryForObject(worldObj)
        if not Utils.isCategoryEnabled(category) then return end
        label = getText("ContextMenu_STA_PryOpen_Pry", getText("ContextMenu_STA_PryOpen_" .. category))
        if category == "Window" then
            for i,v in ipairs(context.options) do
                if v.name == getText("Window") then
                    local windowOption = v
                    local windowSubMenu = context:getSubMenu(windowOption.subOption)
                    option = windowSubMenu:addOption(label, playerObj, ContextMenu.onPrySelect, worldObj, category, "World")
                end
            end
        else
            option = context:addOption(label, playerObj, ContextMenu.onPrySelect, worldObj, category, "World")
        end
        attachTooltip(option, playerObj, worldObj, category, "World")
    end
    if vehicle and part then
        category = Utils.getVehicleCategoryForPart(part)
        if not Utils.isCategoryEnabled(category) then return end
        local key = Utils.vehicleDoorLabelKeyFromId(part and part:getId())
        label = getText("ContextMenu_STA_PryOpen_Pry", getText(key))
        option = context:addOption(label, playerObj, ContextMenu.onPrySelect, part, category, "Vehicle")
        attachTooltip(option, playerObj, part, category, "Vehicle")
    end
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.onFillWorldContext)

_G.STA_PryOpen_ISContextMenu = ContextMenu
return ContextMenu