local Utils = require "STA_PryOpen_Utils"
local ContextMenu = require "ISUI/STA_PryOpen_ISContextMenu"

local Radial = STA_PryOpen_ISRadialMenu or {}
Radial.TAG = "STA_PryOpen"

Radial.ISVehicleMenu_showRadialMenuOutside_old = ISVehicleMenu.showRadialMenuOutside

---@diagnostic disable-next-line: duplicate-set-field
function ISVehicleMenu.showRadialMenuOutside(playerObj)
    Radial.ISVehicleMenu_showRadialMenuOutside_old(playerObj)

    if playerObj:getVehicle() then return end

    local playerIndex = playerObj:getPlayerNum()
    local menu = getPlayerRadialMenu(playerIndex)

    if menu:isReallyVisible() then
        if menu.joyfocus then
            setJoypadFocus(playerIndex, nil)
        end
        menu:undisplay()
        return
    end

    -- menu:clear()

    local vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    if vehicle then
        local doorPart = vehicle:getUseablePart(playerObj)
        local category = Utils.getVehicleCategoryForPart(doorPart)
        local crowbar = Utils.findUsablePryTool(playerObj)

        if Utils.isCategoryEnabled(category) then
            if doorPart and doorPart:getDoor() and doorPart:getInventoryItem() then
                if not doorPart:getDoor():isLocked() then return end
                if doorPart:getId() ~= "EngineDoor" then
                    if not crowbar then
                        menu:addSlice(getText("ContextMenu_STA_PryOpen_Radial_NoCrowbar"), getTexture("media/ui/vehicles/CrowbarNo.png"),nil)
                    elseif not Utils.meetsStrengthRequirement(playerObj, category) then
                        menu:addSlice(getText("ContextMenu_STA_PryOpen_Radial_NoStrength"), getTexture("media/ui/vehicles/CrowbarNo.png"),nil)
                    else
                        local label = getText("ContextMenu_STA_PryOpen_Pry", Utils.vehicleDoorLabelKeyFromId(doorPart and doorPart:getId()))
                        menu:addSlice(label, getTexture("media/ui/vehicles/CrowbarYes.png"), ContextMenu.onPrySelect, playerObj, doorPart, category, "Vehicle")
                    end
                end
            end
        end
    end
end

_G.STA_PryOpen_ISRadialMenu = Radial
return Radial