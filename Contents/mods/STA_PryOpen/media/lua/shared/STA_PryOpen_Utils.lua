local Utils = STA_PryOpen_Utils or {}

-- Variables

Utils.SandboxDefaults = {
    ["PryEnablePity"] = false,
    ["PryChanceBase"] = 0.25,
    ["PryBonusSkillStrength"] = 0.03,
    ["PryBonusSkillCarpentry"] = 0.03,
    ["PryBonusSkillBlacksmith"] = 0.03,
    ["PryBonusSkillMechanics"] = 0.03,
    ["PryBonusTraitBurglar"] = 0.15,
    ["PryBonusSkillNimble"] = 0.20,
    ["PryBonusTraitDextrous"] = 1.00,
    ["PryEnableBuilding"] = true,
    ["PryLevelBuilding"] = 3,
    ["PryChanceMultiplierBuilding"] = 1.00,
    ["PryTimeBuilding"] = 8,
    ["PryEnableWindow"] = true,
    ["PryLevelWindow"] = 2,
    ["PryChanceMultiplierWindow"] = 1.10,
    ["PryTimeWindow"] = 6,
    ["PryEnableGarage"] = true,
    ["PryLevelGarage"] = 6,
    ["PryChanceMultiplierGarage"] = 0.85,
    ["PryTimeGarage"] = 10,
    ["PryEnableSecure"] = true,
    ["PryLevelSecure"] = 8,
    ["PryChanceMultiplierSecure"] = 0.80,
    ["PryTimeSecure"] = 14,
    ["PryEnableVehicle"] = true,
    ["PryLevelVehicle"] = 3,
    ["PryChanceMultiplierVehicle"] = 1.00,
    ["PryTimeVehicle"] = 10,
    ["PryEnableTrunk"] = true,
    ["PryLevelTrunk"] = 2,
    ["PryChanceMultiplierTrunk"] = 1.05,
    ["PryTimeTrunk"] = 8,
    ["PryChanceBreakWindow"] = 0.30,
    ["PryChanceBreakVehicleWindow"] = 0.20,
    ["PryChanceBreakVehicleLock"] = 0.15,
    ["PryChanceInjury"] = 0.08,
    ["PryBonusTraitSkin"] = 0.05,
    ["PryChanceInjurySeverity01"] = 0.65,
    ["PryChanceInjurySeverity02"] = 0.30,
    ["PryChanceInjurySeverity03"] = 0.05,
    ["PryNoiseRadius"] = 15,
    ["PryBonusSkillSneak"] = 0.5,
    ["PryEnableAlarmSuccess"] = true,
    ["PryEnableAlarmForce"] = true,
    ["PryChanceAlarm"] = 0.12,
    ["PryBonusSkillElectricity"] = 0.01,
    ["PryToolTagsList"] = "base:crowbar:1.0;",
    ["PryToolItemsList"] = "",
}

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function clamp(x, min, max)
    if x < min then return min end
    if x > max then return max end
    return x
end

-- Sandbox Functions

local function getSandboxValue(key)
    local moduleName = "STA_PryOpen"
    if SandboxVars and SandboxVars[moduleName] and SandboxVars[moduleName][key] ~= nil then
        return SandboxVars[moduleName][key]
    end
    return nil
end

function Utils.getSandboxBool(key, defaultVal)
    local v = getSandboxValue(key)
    if v == nil then return defaultVal end
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local vl = v:lower()
        return vl == "true" or vl == "1" or vl == "yes" or vl == "on"
    end
    return defaultVal
end

function Utils.getSandboxNum(key, defaultVal)
    local v = getSandboxValue(key)
    if v == nil then return defaultVal end
    if type(v) == "number" then return v end
    if type(v) == "boolean" then return v and 1 or 0 end
    if type(v) == "string" then
        local n = tonumber(v)
        if n then return n end
    end
    return defaultVal
end

function Utils.getSandboxInt(key, defaultVal)
    local n = Utils.getSandboxNum(key, defaultVal)
    return math.floor(n or 0)
end

function Utils.getSandboxString(key)
    local defaultVal = Utils.SandboxDefaults[key]
    local val = getSandboxValue(key)
    if val == nil then return type(defaultVal) == "string" and defaultVal or nil end
    if type(val) == "string" then return val end
    if type(val) ~= "string" then return tostring(val) end
    return type(defaultVal) == "string" and defaultVal or nil
end

local function getBaseChance(chance)
    return Utils.getSandboxNum("PryChance" .. chance, Utils.SandboxDefaults["PryChance" .. chance])
end

local function getCategoryMultiplier(category)
    local key = "PryChanceMultiplier" .. category
    return Utils.getSandboxNum(key, Utils.SandboxDefaults[key])
end

local function getTraitBonus(player, trait)
    return (player and player:HasTrait(trait)) and Utils.getSandboxNum("PryBonusTrait" .. trait, Utils.SandboxDefaults["PryBonusTrait" .. trait]) or 0
end

local function getSkillBonus(player, skill)
    local perLevel = Utils.getSandboxNum("PryBonusSkill" .. skill, Utils.SandboxDefaults["PryBonusSkill" .. skill])
    return (player and player:getPerkLevel(Perks.FromString(skill)) or 0) * perLevel
end

local function getBaseTime(category)
    local key = "PryTime" .. category
    return Utils.getSandboxNum(key, Utils.SandboxDefaults["PryTime" .. category])
end

-- Item Functions

local function predicateNotBroken(item)
    return not item:isBroken()
end

local function parseSandboxPairs(str)
    local t = {}
    if not str or str == "" then return t end

    for entry in string.gmatch(str, "([^;]+)") do
        local id, val = entry:match("^([^=]+):([%d%.]+)$")
        if not id then id = entry end

        if id then
            local num = clamp(tonumber(val) or 1.0, 0.0, 5.0)
            t[id] = num
        end
    end
    return t
end

function Utils.findUsableCrowbar(player)
    if not player then return nil end

    local inv = player:getInventory()
    if not inv then return nil end

    local tagValues = parseSandboxPairs(Utils.getSandboxString("PryToolTagsList"))
    local itemValues = parseSandboxPairs(Utils.getSandboxString("PryToolItemsList"))

    if #tagValues < 1 and #itemValues < 1 then tagValues["Crowbar"] = 1.0 end

    local bestItem, bestValue = nil, -1

    for fullType, val in pairs(itemValues) do
        local resultList = ArrayList.new()
        inv:getAllTypeEvalRecurse(fullType, predicateNotBroken, resultList)

        for i = 0, resultList:size() - 1 do
            local it = resultList:get(i)
            if it and val > bestValue then
                bestItem = it
                bestValue = val
            end
        end
    end

    for tag, modVal in pairs(tagValues) do
        local resultList = ArrayList.new()
        inv:getAllTagEvalRecurse(tag, predicateNotBroken, resultList)

        for i = 0, resultList:size() - 1 do
            local it = resultList:get(i)
            if it then
                local fullType = it:getFullType()
                local hasTypeVal = itemValues[fullType] ~= nil
                if (not hasTypeVal) and modVal > bestValue then
                    bestItem = it
                    bestValue = modVal
                end
            end
        end
    end

    return bestItem
end

function Utils.isEquippedItemValidPryTool(item)
    if not item then return false end
    
    local tagValues = parseSandboxPairs(Utils.getSandboxString("PryToolTagsList"))
    local itemValues = parseSandboxPairs(Utils.getSandboxString("PryToolItemsList"))

    if #tagValues < 1 and #itemValues < 1 then tagValues["Crowbar"] = 1.0 end

    if itemValues[item:getFullType()] then
        return true
    end

    for tag, _ in pairs(tagValues) do
        if item:hasTag(tag) then
            return true
        end
    end

    return false
end

function Utils.getPryToolValue(item)
    if not item then return 1.0 end

    local tagValues = parseSandboxPairs(Utils.getSandboxString("PryToolTagsList"))
    local itemValues = parseSandboxPairs(Utils.getSandboxString("PryToolItemsList"))

    if #tagValues < 1 and #itemValues < 1 then tagValues["Crowbar"] = 1.0 end

    local fullType = item:getFullType()
    local val = itemValues[fullType]

    if not val then
        for tag, modVal in pairs(tagValues) do
            if item:hasTag(tag) then
                val = modVal
                break
            end
        end
    end

    return val or 1.0
end

-- World Object Functions

local SECURITY_DOORS = {
    "fixtures_doors_01_32",
    "fixtures_doors_01_33",
    "location_community_police_01_4",
    "location_community_police_01_5",
}

local function getSpriteName(obj)
    local sp = obj and obj:getSprite() or nil
    if sp and sp.getName then return sp:getName() end
    return nil
end

function Utils.isSecurityDoor(obj)
    if not obj then return false end

    if instanceof(obj, "IsoDoor") or (instanceof(obj, "IsoThumpable") and obj:isDoor()) then
        local name = getSpriteName(obj)
        for _, value in ipairs(SECURITY_DOORS) do
            if name == value then return true end
        end
    end
    return false
end

function Utils.isPryableWorldObject(obj)
    if not obj then return false end
    
    if instanceof(obj, "IsoWindow") then
        if obj:IsOpen() then return true end
        if obj:isSmashed() then return true end
        if obj:isPermaLocked() then return false end
        if obj:isLocked() then return true end
        return true
    end
    if instanceof(obj, "IsoDoor") then
        if obj:IsOpen() then return true end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return true
    end
    if instanceof(obj, "IsoThumpable") and obj:isDoor() then
        if obj:IsOpen() then return true end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return true
    end
    return false
end

function Utils.isLockedWorldObject(obj)
    if not obj then return false end

    if instanceof(obj, "IsoWindow") then
        if obj:IsOpen() then return false end
        if obj:isSmashed() then return false end
        if obj:isPermaLocked() then return false end
        if obj:isLocked() then return true end
        return false
    end
    if instanceof(obj, "IsoDoor") then
        if obj:IsOpen() then return false end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return false
    end
    if instanceof(obj, "IsoThumpable") and obj:isDoor() then
        if obj:IsOpen() then return false end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return false
    end
    return false
end

function Utils.isBarricadedForPlayer(obj, playerObj)
    if not obj or not playerObj then return false end
    if obj.getBarricadeForCharacter then
        return obj:getBarricadeForCharacter(playerObj) ~= nil
    end
    return false
end

function Utils.getWorldCategoryForObject(obj)
    if not obj then return end
    if instanceof(obj, "IsoWindow") then
        return "Window"
    end
    if Utils.isSecurityDoor(obj) then
        return "Secure"
    end
    if instanceof(obj, "I") and obj:isDoor() then
        return "Garage"
    end
    if instanceof(obj, "IsoDoor") then
        if string.find(tostring(obj), "garage") then
            return "Garage"
        else
            return "Building"
        end
    end
    return nil
end

function Utils.findWorldTarget(worldObjects, playerObj)
    if not worldObjects or #worldObjects == 0 then return end
    local o
    for i = 1, #worldObjects do
        o = worldObjects[i]
        local category = Utils.getWorldCategoryForObject(o)
        if category and Utils.isPryableWorldObject(o) and not Utils.isBarricadedForPlayer(o, playerObj) then

            if Utils.isCategoryEnabled(category) then
                return o
            end
        end
    end
    if not o and worldObjects:size() > 0 then
        local obj = worldObjects:get(0)
        local sq
        if obj and obj.getSquare then sq = obj:getSquare() end
    end
    return nil
end

-- Vehicle Functions

local function isDoorOrTrunkPart(part)
    if not part then return false end
    if not part:getDoor() then return false end
    local id = tostring(part:getId() or ""):lower()
    return id:find("door") or  id:find("trunk")
end

function Utils.findVehicleAtContext(playerObj, worldObjects)
    local vehicle = nil
    if ISVehicleMenu and ISVehicleMenu.getVehicleToInteractWith then
        vehicle = ISVehicleMenu.getVehicleToInteractWith(playerObj)
    end
    if not vehicle and worldObjects then
        for i = 1, #worldObjects do
            local o = worldObjects[i]
            if instanceof(o, "BaseVehicle") then
                vehicle = o
                break
            end
        end
    end
    return vehicle
end

function Utils.getUnderCursorVehiclePart(playerObj, vehicle)
    if vehicle and vehicle.getUseablePart then
        return vehicle:getUseablePart(playerObj)
    end
    return nil
end

function Utils.findLockedVehicleTargetPart(playerObj, vehicle)
    if not vehicle then return end

    local hover = Utils.getUnderCursorVehiclePart(playerObj, vehicle)
    if hover and isDoorOrTrunkPart(hover) then
        local door = hover:getDoor()
        if door and door:isLocked() then
            return hover
        end
    end
    return nil
end

-- Routing Functions

function Utils.getTargetCategory(target)
    if target.type == "world" then
        return Utils.getWorldCategoryForObject(target.obj)
    elseif target.type == "vehicle" then
        local id = tostring(target.part and target.part:getId() or ""):lower()
        if id:find("trunk") then
            return "Trunk"
        else
            return "Vehicle"
        end
    end
    return nil
end

function Utils.isCategoryEnabled(category)
    if category then
        return Utils.getSandboxBool("PryEnable" .. category, Utils.SandboxDefaults["PryEnable" .. category])
    end
    return true
end

function Utils.getCategoryStrength(category)
    if category then
        return Utils.getSandboxInt("PryLevel" .. category, Utils.SandboxDefaults["PryLevel" .. category])
    end
    return 0
end

function Utils.meetsStrengthRequirement(playerObj, category)
    if not playerObj then return false, 0, Utils.getCategoryStrength(category) end
    local required = STA_PryOpen_Utils.getCategoryStrength(category)
    local current = playerObj:getPerkLevel(Perks.Strength)
    return current >= required, current, required
end

-- Math Functions

function Utils.computePrySuccessChance(player, category, crowbar)
    local chance = getBaseChance("Base") * Utils.getPryToolValue(crowbar)
    chance = chance + getSkillBonus(player, "Strength")

    if category == "Building" or category == "Window" then chance = chance + getSkillBonus(player, "Carpentry") end
    if category == "Garage" or category == "Secure" then chance = chance + getSkillBonus(player, "Blacksmith") end
    if category == "Vehicle" or category == "Trunk" then chance = chance + getSkillBonus(player, "Mechanics") end

    chance = chance + getTraitBonus(player, "Burglar")

    chance = chance * getCategoryMultiplier(category)
    return clamp(chance, 0, 0.99)
end

local function secondsToTick(sec)
    return math.floor((sec or 0) * 30 + 0.5)
end

function Utils.computePryTimeTicks(player, category)
    if player:isTimedActionInstant() then return 1 end
    local sec = getBaseTime(category) - getSkillBonus(player, "Nimble") - getTraitBonus(player, "Dextrous")
    sec = math.max(sec, 2.0)
    return secondsToTick(sec), sec
end

local function glovesMitigationMultiplier(player)
    if not player then return 1.0 end

    local worn = player:getWornItems()
    if worn and worn.getItem then
        local gloves = worn:getItem("Hands") or false
        local gloveL = worn:getItem("HandsLeft") or false
        local gloveR = worn:getItem("HandsRight") or false

        local gLDef1, gLDef2, gRDef1, gRDef2

        if gloves then gLDef1 = gloves:getDefForPart(BloodBodyPartType.Hand_L, false, false) else gLDef1 = 0 end
        if gloves then gRDef1 = gloves:getDefForPart(BloodBodyPartType.Hand_R, false, false) else gRDef1 = 0 end
        if gloveL then gLDef2 = gloveL:getDefForPart(BloodBodyPartType.Hand_L, false, false) else gLDef2 = 0 end
        if gloveR then gRDef2 = gloveR:getDefForPart(BloodBodyPartType.Hand_R, false, false) else gRDef2 = 0 end

        local multiL = (100 - clamp(gLDef1 + gLDef2, 0, 100)) / 100
        local multiR = (100 - clamp(gRDef1 + gRDef2, 0, 100)) / 100

        return multiL, multiR
    end
    return 1, 1
end

function Utils.getFailureChances(player)
    local t = {}

    t.PryChanceBreakWindow = getBaseChance("BreakWindow")
    t.PryChanceBreakVehicleWindow = getBaseChance("BreakVehicleWindow")
    t.PryChanceBreakVehicleLock = getBaseChance("BreakVehicleLock")

    local baseInjury = getBaseChance("Injury")

    if player:HasTrait("ThickSkinned") then
        baseInjury = clamp01(baseInjury - Utils.getSandboxNum("PryBonusTraitSkin", Utils.SandboxDefaults["PryBonusTraitSkin"]))
    end
    if player:HasTrait("ThinSkinned") then
        baseInjury = clamp01(baseInjury + Utils.getSandboxNum("PryBonusTraitSkin", Utils.SandboxDefaults["PryBonusTraitSkin"]))
    end

    local multL, multR = glovesMitigationMultiplier(player)
    t.PryChanceInjuryL = clamp01(baseInjury * multL)
    t.PryChanceInjuryR = clamp01(baseInjury * multR)

    local s1, s2, s3 = getBaseChance("InjurySeverity01"), getBaseChance("InjurySeverity02"), getBaseChance("InjurySeverity03")
    local sum = s1 + s2 + s3
    if sum == 1 or sum == 0 then
        t.InjurySeverity = { s1, s2, s3}
    else
        t.InjurySeverity = { s1/sum, s2/sum, s3/sum}
    end

    local baseAlarm = getBaseChance("Alarm")
    local elec = getSkillBonus(player, "Electricity")
    t.PryChanceAlarm = clamp01(baseAlarm - elec)

    return t
end

function Utils.computeNoiseRadius(player)
    local base = Utils.getSandboxNum("PryNoiseRadius", Utils.SandboxDefaults["PryNoiseRadius"])
    local sneak = getSkillBonus(player, "Sneak")
    local r = base - sneak
    return math.max(2, r)
end

-- function Utils.computeDurabilityLossChance(player)
--     local base = getBaseChance("Durability")
--     local maint = getSkillBonus(player, "Maintenance")
--     local m = base - maint
--     return clamp01(m)
-- end

-- Label and Tooltip Functions

local function vehicleDoorLabelKeyFromId(partId)
    local mod = "ContextMenu_STA_PryOpen_Vehicle_"
    local id = tostring(partId or ""):lower()

    local loc, side = nil, nil
    local plural = ""

    local locations = { "Front", "Middle", "Rear", "Trunk" }
    local sides = { "Left", "Right" }

    for _, l in ipairs(locations) do
        if id:find(l:lower()) then
            loc = l
            break
        end
    end

    for _, s in ipairs(sides) do
        if id:find(s:lower()) then
            side = s
            break
        end
    end

    if loc == "Rear" and not side then
        plural = "P"
    end

    local locText = loc and getText(mod .. "Loc_" .. loc .. plural) or ""
    local sideText = side and getText(mod .. "Side_" .. side) or ""
    local nounText = ""
    if loc ~= "Trunk" then
        local nounKey = mod .. "Door" .. plural
        -- local nounKey = plural and (mod .. "Doors") or (mod .. "Door")
        nounText = getText(nounKey)
    end

    if not loc and not side then
        return getText(mod .. "Generic")
    else
        return (getText("ContextMenu_STA_PryOpen_Vehicle", locText, sideText, nounText):gsub("%s+", " ")):gsub("^%s*(.-)%s*$", "%1")
    end
end

-- local function vehicleDoorLabelKeyFromId(partId)
--     local mod = "ContextMenu_STA_PryOpen_Vehicle_"
--     local loc = { "Front", "Middle", "Rear", "Trunk" }
--     local side = { "Left", "Right" }
--     local id = tostring(partId or ""):lower()

--     for _, l in ipairs(loc) do
--         if id:find(string.lower(l)) then
--             if l == "Trunk" then return getText(tostring(mod .. l)) end
--             for _, s in ipairs(side) do
--                 if id:find(string.lower(s)) then
--                     return getText(tostring(mod .. l .. s))
--                 end
--             end
--             if l == "Rear" then return getText(tostring(mod .. l)) end
--         end
--     end
--     return getText("ContextMenu_STA_PryOpen_Pry") .. getText(tostring(mod .. "Generic"))
-- end

function Utils.buildLabelForTarget(target)
    if target.type == "world" then
        local cat = Utils.getWorldCategoryForObject(target.obj)
        return getText("ContextMenu_STA_PryOpen_Pry", getText("ContextMenu_STA_PryOpen_" .. cat))
    elseif target.type == "vehicle" then
        local key = vehicleDoorLabelKeyFromId(target.part and target.part:getId())
        return getText("ContextMenu_STA_PryOpen_Pry", getText(key))
    end
    return getText("ContextMenu_STA_PryOpen_Pry",  getText("ContextMenu_STA_PryOpen_Building"))
end

function Utils.attachRedTooltip(option, textKey, ...)
    if not option then return end
    local tip = ISToolTip:new()
    tip:initialise()
    tip.description = " <RGB:1,0,0>" .. tostring(getText(textKey, ...))
    option.toolTip = tip
end

function Utils.attachRedTooltipMulti(option, reasons)
    if not option or not reasons or #reasons == 0 then return end
    local desc = ""
    for i = 1, #reasons do
        local r = reasons[i]
        local key = r[1]
        local args = {}
        for j = 2, #r do args[#args+1] = r[j] end
        local line = getText(key, unpack(args))
        desc = desc .. " <RGB:1,0,0>" .. tostring(line)
        if i < #reasons then
            desc = desc .. "\n"
        end
    end
    local tip = ISToolTip:new()
    tip:initialise()
    tip.description = desc
    option.toolTip = tip
end

_G.STA_PryOpen_Utils = Utils
return Utils