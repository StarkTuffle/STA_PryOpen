local Utils = STA_PryOpen_Utils or {}
local Log = require "STA_PryOpen_Log"
Log.info("Module loaded: STA_PryOpen_Utils")

-- Variables
Utils.modID = "STA_PryOpen"

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

-- Sandbox Functions

---@param key string
---@return any
local function getSandboxValue(key)
    Log.trace("Utils.getSandboxValue invoked with key: %s", tostring(key))
    local moduleName = Utils.modID
    Log.trace("moduleName set to %s", tostring(moduleName))
    if SandboxVars and SandboxVars[moduleName] and SandboxVars[moduleName][key] ~= nil then
        Log.trace("Returning SandboxVars[%s][%s]", moduleName, key)
        return SandboxVars[moduleName][key]
    end
    Log.trace("Returning nil")
    return nil
end

---@param key string
---@return Boolean|nil
function Utils.getSandboxBool(key)
    Log.trace("Utils.getSandboxBool invoked with key: %s", tostring(key))
    local defaultVal = Utils.SandboxDefaults[key]
    Log.trace("defaultVal set to %s", tostring(defaultVal))
    local val = getSandboxValue(key)
    Log.trace("val set to %s", tostring(val))
    if val == nil then return type(defaultVal) == "boolean" and defaultVal or nil end
    if type(val) == "boolean" then return val end
    if type(val) == "number" then return val ~= 0 end
    if type(val) == "string" then
        local valLower = val:lower()
        return valLower == "true" or valLower =="1" or valLower == "yes" or valLower == "on"
    end
    Log.trace("val not returned, returning defaultVal")
    return type(defaultVal) == "boolean" and defaultVal or nil
end

---@param key string
---@return number|nil
function Utils.getSandboxNum(key)
    Log.trace("Utils.getSandboxNum invoked with key: %s", key)
    local defaultVal = Utils.SandboxDefaults[key]
    Log.trace("defaultVal set to %s", tostring(defaultVal))
    local val = getSandboxValue(key)
    Log.trace("val set to %s", tostring(val))
    if val == nil then return type(defaultVal) == "number" and defaultVal or nil end
    if type(val) == "number" then return val end
    if type(val) == "boolean" then return val and 1 or 0 end
    if type(val) == "string" then
        local num = tonumber(val)
        if num then return num end
    end
    Log.trace("val not returned, returning defaultVal")
    return type(defaultVal) == "number" and defaultVal or nil
end

---@param key String
---@return Integer
function Utils.getSandboxInt(key)
    Log.trace("Utils.getSandboxInt invoked with key: %s", key)
    local num = Utils.getSandboxNum(key)
    return math.floor(num or 0)
end

---@param key string
---@return string | nil
function Utils.getSandboxString(key)
    Log.trace("Utils.getSandboxString invoked with key: %s", key)
    local defaultVal = Utils.SandboxDefaults[key]
    Log.trace("defaultVal set to %s", tostring(defaultVal))
    local val = getSandboxValue(key)
    Log.trace("val set to %s", tostring(val))
    if val == nil then return type(defaultVal) == "string" and defaultVal or nil end
    if type(val) == "string" then return val end
    if type(val) ~= "string" then return tostring(val) end
    return type(defaultVal) == "string" and defaultVal or nil
end

-- Mod Data Functions

---@param obj IsoObject|InventoryItem
---@param key String
---@return any
function Utils.getObjectModData(obj, key)
    Log.debug("Utils.getObjectModData invoked with obj: %s key: %s", tostring(obj), tostring(key))
    local data = obj:getModData()
    if not data[Utils.modID] then data[Utils.modID] = {} end
    if data and data[Utils.modID] and data[Utils.modID][key] then
        local value = data[Utils.modID][key]
        Log.trace("Key found; returning value: %s", tostring(value))
        return value
    end
    Log.trace("Key not found; returning nil")
    return nil
end

---@param obj IsoObject|InventoryItem
---@param key String
---@param value any
function Utils.setObjectModData(obj, key, value)
    Log.trace("Utils.setObjectModData invoked with obj: %s key: %s value: %s", tostring(obj), tostring(key), tostring(value))
    local data = obj:getModData()
    if not data then Log.error("setObjectModData called with nil object; aborting") return end
    if not data[Utils.modID] then
        Log.trace("Mod Options Array not found; creating")
        data[Utils.modID] = {}
    end
    data[Utils.modID][key] = value
    Log.debug("Set Mod Options key: %s to %s", tostring(key), tostring(value))
end

-- Math Functions

---@overload fun(x: number): number
---@overload fun(x: number, max: number): number
---@overload fun(x: number, min: number, max: number): number
function Utils.clamp(...)
    local args = { ... }
    if args[3] then
        Log.trace("Utils.clamp invoked with args: x=%s min=%s max=%s", tostring(args[1]), tostring(args[2]), tostring(args[3]))
        if args[1] < args[2] then return args[2] end
        if args[1] > args[3] then return args[3] end
        return args[1]
    elseif args[2] then
        Log.trace("Utils.clamp invoked with args: x=%s max=%s", tostring(args[1]), tostring(args[2]))
        if args[1] < 0 then return 0 end
        if args[1] > args[2] then return args[2] end
        return args[1]
    else
        Log.trace("Utils.clamp invoked with args: x=%s", tostring(args[1]))
        if args[1] < 0 then return 0 end
        if args[1] > 1 then return 1 end
        return args[1]
    end
end

-- World Object Functions

local SECURITY_DOORS = {
    "fixtures_doors_01_32",
    "fixtures_doors_01_33",
    "location_community_police_01_4",
    "location_community_police_01_5",
}

local PERMALOCKED_WINDOWS = {
    "fixtures_doors_01_104",
    "fixtures_doors_01_105",
    "fixtures_doors_01_112",
    "fixtures_doors_01_113",

    "fixtures_windows_01_40",
    "fixtures_windows_01_41",
    "fixtures_windows_01_42",
    "fixtures_windows_01_43",
    "fixtures_windows_01_48",
    "fixtures_windows_01_49",
    "fixtures_windows_01_50",
    "fixtures_windows_01_51",
    "fixtures_windows_01_72",
    "fixtures_windows_01_73",

    "location_community_church_small_01_112",
    "location_community_church_small_01_113",
    "location_community_church_small_01_114",
    "location_community_church_small_01_115",
    "location_community_church_small_01_116",
    "location_community_church_small_01_117",
    "location_community_church_small_01_118",
    "location_community_church_small_01_119",
    "location_community_church_small_01_120",
    "location_community_church_small_01_121",
    "location_community_church_small_01_122",
    "location_community_church_small_01_123",
    "location_community_church_small_01_124",
    "location_community_church_small_01_125",
    "location_community_church_small_01_126",
    "location_community_church_small_01_127",

    "location_community_police_01_36",
    "location_community_police_01_37",
    "location_community_police_01_38",
    "location_community_police_01_39",
    "location_community_police_01_40",
    "location_community_police_01_41",

    "location_entertainment_theatre_01_24",
    "location_entertainment_theatre_01_25",
    "location_entertainment_theatre_01_26",
    "location_entertainment_theatre_01_27",

    "location_hospitality_sunstarmotel_01_28",
    "location_hospitality_sunstarmotel_01_29",
    "location_hospitality_sunstarmotel_01_30",
    "location_hospitality_sunstarmotel_01_31",

    "location_restaurant_diner_01_8",
    "location_restaurant_diner_01_9",
    "location_restaurant_diner_01_10",
    "location_restaurant_diner_01_11",
    "location_restaurant_diner_01_12",
    "location_restaurant_diner_01_13",

    "location_restaurant_seahorse_01_16",
    "location_restaurant_seahorse_01_17",
    "location_restaurant_seahorse_01_18",
    "location_restaurant_seahorse_01_19",
    "location_restaurant_seahorse_01_20",
    "location_restaurant_seahorse_01_21",

    "location_restaurant_spiffos_01_4",
    "location_restaurant_spiffos_01_5",
    "location_restaurant_spiffos_01_6",
    "location_restaurant_spiffos_01_12",
    "location_restaurant_spiffos_01_13",
    "location_restaurant_spiffos_01_14",
    "location_restaurant_spiffos_01_16",
    "location_restaurant_spiffos_01_17",
    "location_restaurant_spiffos_01_18",
    "location_restaurant_spiffos_01_19",
    "location_restaurant_spiffos_01_20",
    "location_restaurant_spiffos_01_21",

    "location_shop_fossoil_01_0",
    "location_shop_fossoil_01_2",

    "location_shop_gas2go_01_8",
    "location_shop_gas2go_01_9",

    "location_shop_greenes_01_8",
    "location_shop_greenes_01_9",
    "location_shop_greenes_01_13",
    "location_shop_greenes_01_14",
    "location_shop_greenes_01_16",
    "location_shop_greenes_01_17",
    "location_shop_greenes_01_18",
    "location_shop_greenes_01_19",

    "walls_commercial_01_0",
    "walls_commercial_01_1",
    "walls_commercial_01_16",
    "walls_commercial_01_17",
    "walls_commercial_01_32",
    "walls_commercial_01_33",
    "walls_commercial_01_40",
    "walls_commercial_01_41",
    "walls_commercial_01_64",
    "walls_commercial_01_65",
    "walls_commercial_01_80",
    "walls_commercial_01_81",
    "walls_commercial_01_96",
    "walls_commercial_01_97",
    "walls_commercial_01_112",
    "walls_commercial_01_113",

    "walls_commercial_02_0",
    "walls_commercial_02_1",
    "walls_commercial_02_8",
    "walls_commercial_02_9",
    "walls_commercial_02_48",
    "walls_commercial_02_49",
    "walls_commercial_02_50",
    "walls_commercial_02_51",
    "walls_commercial_02_52",
    "walls_commercial_02_53",
    "walls_commercial_02_54",
    "walls_commercial_02_55",
    "walls_commercial_02_72",
    "walls_commercial_02_73",
    "walls_commercial_02_76",
    "walls_commercial_02_77",

}

---@param obj IsoObject
---@return String|nil
local function getSpriteName(obj)
    local sp = obj and obj:getSprite() or nil
    if sp and sp.getName then return sp:getName() end
    return nil
end

---@param obj IsoThumpable
---@return boolean
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

---@param obj IsoWindow | IsoDoor | IsoThumpable
---@return boolean
function Utils.isPryableWorldObject(obj)
    if not obj then return false end
    ---@cast obj IsoWindow
    if instanceof(obj, "IsoWindow") then
        if obj:IsOpen() then return true end
        if obj:isSmashed() then return true end
        -- if obj:isPermaLocked() then return false end
        if obj:isPermaLocked() then
            local name = getSpriteName(obj)
            for _, value in ipairs(PERMALOCKED_WINDOWS) do
                if name == value then return false end
            end
        end
        if obj:isLocked() then return true end
        return true
    end
    ---@cast obj IsoDoor
    if instanceof(obj, "IsoDoor") then
        if obj:IsOpen() then return true end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return true
    end
    ---@cast obj IsoThumpable
    if instanceof(obj, "IsoThumpable") and obj:isDoor() then
        if obj:IsOpen() then return true end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return true
    end
    return false
end

---@param obj IsoWindow | IsoDoor | IsoThumpable
---@return boolean
function Utils.isLockedWorldObject(obj)
    if not obj then return false end
    ---@cast obj IsoWindow
    if instanceof(obj, "IsoWindow") then
        if obj:IsOpen() then return false end
        if obj:isSmashed() then return false end
        -- if obj:isPermaLocked() then return false end
        if obj:isPermaLocked() then
            local name = getSpriteName(obj)
            for _, value in ipairs(PERMALOCKED_WINDOWS) do
                if name == value then return false end
            end
        end
        if obj:isLocked() then return true end
        return false
    end
    ---@cast obj IsoDoor
    if instanceof(obj, "IsoDoor") then
        if obj:IsOpen() then return false end
        if obj:getProperties():has("forceLocked") then return true end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return false
    end
    ---@cast obj IsoThumpable
    if instanceof(obj, "IsoThumpable") and obj:isDoor() then
        if obj:IsOpen() then return false end
        if obj:getProperties():has("forceLocked") then return true end
        if obj:isLockedByKey() then return true end
        if obj:isLocked() then return true end
        return false
    end
    return false
end

---@param obj IsoThumpable
---@param playerObj IsoPlayer
---@return boolean
function Utils.isBarricadedForPlayer(obj, playerObj)
    if not obj or not playerObj then return false end
    if obj.getBarricadeForCharacter then
        return obj:getBarricadeForCharacter(playerObj) ~= nil
    end
    return false
end

---@param obj IsoThumpable
---@return string | nil
function Utils.getWorldCategoryForObject(obj)
    Log.debug("obj:%s", tostring(obj))
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
        if string.find(tostring(obj), "garage") or (obj:getSquare():getGarageDoor(true) or obj:getSquare():getGarageDoor(false)) then
            return "Garage"
        else
            return "Building"
        end
    end
    return nil
end

---@param worldObjects ArrayList<IsoObject>
---@param playerObj IsoPlayer
---@return IsoObject | nil
function Utils.findWorldTarget(worldObjects, playerObj)
    if not worldObjects or #worldObjects == 0 then return end
    local o
    for i = 1, #worldObjects do
        o = worldObjects[i]
        Log.debug("worldObject:%s", tostring(o))
        local category = Utils.getWorldCategoryForObject(o)
        if category and Utils.isPryableWorldObject(o) and not Utils.isBarricadedForPlayer(o, playerObj) then
            if Utils.isCategoryEnabled(category) then
                return o
            end
        end
    end
    return nil
end

-- Vehicle Functions

---@param part VehiclePart
---@return string | nil
function Utils.getVehicleCategoryForPart(part)
    local id = tostring(part and part:getId() or ""):lower()
    if id:find("trunk") then
        return "Trunk"
    elseif (id:find("door") and part:getDoor()) or (part and part.getDoor and part:getDoor()) then
        return "Vehicle"
    else
        return nil
    end
end

---@param part VehiclePart
---@return integer | nil
local function isDoorOrTrunkPart(part)
    if not part then return end
    if not part:getDoor() then return end
    local id = tostring(part:getId() or ""):lower()
    return id:find("door") or id:find("trunk")
end

---@param playerObj IsoPlayer
---@param worldObjects ArrayList<IsoObject>
---@return BaseVehicle
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

---@param playerObj IsoPlayer
---@param vehicle BaseVehicle
---@return VehiclePart | nil
function Utils.getUnderCursorVehiclePart(playerObj, vehicle)
    if vehicle and vehicle.getUseablePart then
        return vehicle:getUseablePart(playerObj)
    end
    return nil
end

---@param playerObj IsoPlayer
---@param vehicle BaseVehicle
---@return VehiclePart | nil
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

---@param category string
---@return boolean | nil
function Utils.isCategoryEnabled(category)
    if category then
        return Utils.getSandboxBool("PryEnable" .. category)
    end
    return true
end

---@param category string
---@return integer
function Utils.getCategoryStrength(category)
    if category then
        return Utils.getSandboxInt("PryLevel" .. category)
    end
    return 0
end

---@param playerObj IsoPlayer
---@param category string
---@return boolean
---@return integer
---@return integer
function Utils.meetsStrengthRequirement(playerObj, category)
    local required = STA_PryOpen_Utils.getCategoryStrength(category)
    if not playerObj then
        return false, 0, required
    end
    local current = playerObj:getPerkLevel(Perks.Strength)
    return (current >= required), current, required
end

-- Inventory Functions

---@param item InventoryItem
---@return boolean
local function predicateNotBroken(item)
    return not item:isBroken()
end

---@param str string | nil
---@param isTag boolean
local function parseSandboxPairs(str, isTag)
    local t = {}
    if not str or str == "" then return t end
    for entry in string.gmatch(str, "([^;]+)") do
        local id, val = entry:match("^([^=]+):([%d%.]+)$")
        if not id then id = entry end

        if id then
            local num = Utils.clamp(tonumber(val) or 1.0, 5.0)

            if isTag then
                local rl = ResourceLocation.of(id)
                local tagObj = ItemTag.get(rl)
                if tagObj then
                    t[tagObj] = num
                end
            else
                t[id] = num
            end
        end
    end
    return t
end

---@param playerObj IsoPlayer
---@return InventoryItem | nil
function Utils.findUsablePryTool(playerObj)
    if not playerObj then return end

    local inv = playerObj:getInventory()
    if not inv then return end

    local tagValues = parseSandboxPairs(Utils.getSandboxString("PryToolTagsList"), true)
    local itemValues = parseSandboxPairs(Utils.getSandboxString("PryToolItemsList"), false)

    if #tagValues < 1 and #itemValues < 1 then tagValues[ItemTag.CROWBAR] = 1.0 end

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

---@param item InventoryItem
---@return boolean
function Utils.isEquippedItemValidPryTool(item)
    if not item then return false end

    local tagValues = parseSandboxPairs(Utils.getSandboxString("PryToolTagsList"), true)
    local itemValues = parseSandboxPairs(Utils.getSandboxString("PryToolItemsList"), false)

    if #tagValues < 1 and #itemValues < 1 then tagValues[ItemTag.CROWBAR] = 1.0 end

    if itemValues[item:getFullType()] then
        return true
    end

    for tagObj, _ in pairs(tagValues) do
        if item:hasTag(tagObj) then
            return true
        end
    end
    
    return false
end

---@param item InventoryItem
---@return number
function Utils.getPryToolValue(item)
    if not item then return 1.0 end

    local tagValues = parseSandboxPairs(Utils.getSandboxString("PryToolTagsList"), true)
    local itemValues = parseSandboxPairs(Utils.getSandboxString("PryToolItemsList"), false)

    if #tagValues < 1 and #itemValues < 1 then tagValues[ItemTag.CROWBAR] = 1.0 end

    local fullType = item:getFullType()
    local val = itemValues[fullType]

    if not val then
        for tagObj, modVal in pairs(tagValues) do
            if item:hasTag(tagObj) then
                val = modVal
                break
            end
        end
    end

    return val or 1.0
end

-- Compute Functions

---@param playerObj IsoPlayer
---@param baseChance number
---@return number
local function applyPityBonus(playerObj, baseChance)
    if not Utils.isCategoryEnabled("Pity") then return baseChance end

    local perFail = 0.01
    local maxBonus = 0.15

    local failStreak = Utils.getObjectModData(playerObj, "failStreak") or 0
    local bonus = math.min(maxBonus, failStreak * perFail)
    return Utils.clamp(baseChance + bonus)
end

---@param playerObj IsoPlayer
---@return number
---@return number
local function glovesMitigationMultiplier(playerObj)
    if not playerObj then return 1.0, 1.0 end

    local worn = playerObj:getWornItems()
    if worn and worn.getItem then
        local gloves = worn:getItem(ItemBodyLocation.HANDS) or false
        local gloveL = worn:getItem(ItemBodyLocation.HANDS_LEFT) or false
        local gloveR = worn:getItem(ItemBodyLocation.HANDS_RIGHT) or false
        ---@cast gloves Clothing
        ---@cast gloveL Clothing
        ---@cast gloveR Clothing

        local gLDef1, gLDef2, gRDef1, gRDef2

        if gloves then gLDef1 = gloves:getDefForPart(BloodBodyPartType.Hand_L, false, false) else gLDef1 = 0 end
        if gloves then gRDef1 = gloves:getDefForPart(BloodBodyPartType.Hand_R, false, false) else gRDef1 = 0 end
        if gloveL then gLDef2 = gloveL:getDefForPart(BloodBodyPartType.Hand_L, false, false) else gLDef2 = 0 end
        if gloveR then gRDef2 = gloveR:getDefForPart(BloodBodyPartType.Hand_R, false, false) else gRDef2 = 0 end

        local multiL = (100 - Utils.clamp(gLDef1 + gLDef2, 100)) / 100
        local multiR = (100 - Utils.clamp(gRDef1 + gRDef2, 100)) / 100

        return multiL, multiR
    end
    return 1, 1
end

---@param playerObj IsoPlayer
---@param category string | nil
---@return number
function Utils.computePrySuccessChance(playerObj, category, crowbar)
    if not (playerObj and category) then return 0 end

    local chance = (Utils.getSandboxNum("PryChanceBase") * Utils.getPryToolValue(crowbar)) + (Utils.getSandboxNum("PryBonusSkillStrength") * (playerObj:getPerkLevel(Perks.Strength)))

    if category == "Building" or category == "Window" then chance = chance + (Utils.getSandboxNum("PryBonusSkillCarpentry") * (playerObj:getPerkLevel(Perks.Woodwork))) end
    if category == "Garage" or category == "Secure" then chance = chance + (Utils.getSandboxNum("PryBonusSkillBlacksmith") * (playerObj:getPerkLevel(Perks.Blacksmith))) end
    if category == "Vehicle" or category == "Trunk" then chance = chance + (Utils.getSandboxNum("PryBonusSkillMechanics") * (playerObj:getPerkLevel(Perks.Mechanics))) end

    if playerObj:hasTrait(CharacterTrait.BURGLAR) then
        chance = chance + Utils.getSandboxNum("PryBonusTraitBurglar")
    end

    chance = chance * Utils.getSandboxNum("PryChanceMultiplier" .. category)
    chance = applyPityBonus(playerObj, chance)
    return Utils.clamp(chance, 0.99)
end

---@param playerObj IsoPlayer
---@return table
function Utils.computeFailureChances(playerObj)
    local t = {}

    t.PryChanceBreakWindow = Utils.getSandboxNum("PryChanceBreakWindow")
    t.PryChanceBreakVehicleWindow = Utils.getSandboxNum("PryChanceBreakVehicleWindow")
    t.PryChanceBreakVehicleLock = Utils.getSandboxNum("PryChanceBreakVehicleLock")

    local baseInjury = Utils.getSandboxNum("PryChanceInjury")

    if playerObj:hasTrait(CharacterTrait.THICK_SKINNED) then
        baseInjury = Utils.clamp(baseInjury - Utils.getSandboxNum("PryBonusTraitSkin"))
    end
    if playerObj:hasTrait(CharacterTrait.THIN_SKINNED) then
        baseInjury = Utils.clamp(baseInjury + Utils.getSandboxNum("PryBonusTraitSkin"))
    end

    local multL, multR = glovesMitigationMultiplier(playerObj)
    t.PryChanceInjuryL = Utils.clamp(baseInjury * multL)
    t.PryChanceInjuryR = Utils.clamp(baseInjury * multR)

    local s1, s2, s3 = Utils.getSandboxNum("PryChanceInjurySeverity01"), Utils.getSandboxNum("PryChanceInjurySeverity02"), Utils.getSandboxNum("PryChanceInjurySeverity03")
    local sum = s1 + s2 + s3
    if sum == 1 or sum == 0 then
        t.InjurySeverity = { s1, s2, s3 }
    else
        t.InjurySeverity = { s1/sum, s2/sum, s3/sum }
    end

    local baseAlarm = Utils.getSandboxNum("PryChanceAlarm")
    local elec = Utils.getSandboxNum("PryBonusSkillElectricity") * playerObj:getPerkLevel(Perks.Electricity)
    t.PryChanceAlarm = Utils.clamp(baseAlarm - elec)

    return t
end

---@param playerObj IsoPlayer
---@return number
function Utils.computeNoiseRadius(playerObj)
    local base = Utils.getSandboxNum("PryNoiseRadius")
    local sneak = Utils.getSandboxNum("PryBonusSkillSneak") * playerObj:getPerkLevel(Perks.Sneak)
    local r = base - sneak
    return math.max(2, r)
end

---@param playerObj IsoPlayer
---@param category string
---@return number
function Utils.computePryTimeTicks(playerObj, category)
    if playerObj:isTimedActionInstant() then return 1 end
    local sec = Utils.getSandboxNum("PryTime" .. category) - (Utils.getSandboxNum("PryBonusSkillNimble") * playerObj:getPerkLevel(Perks.Nimble))
    if playerObj:hasTrait(CharacterTrait.DEXTROUS) then
        sec = sec - Utils.getSandboxNum("PryBonusTraitDextrous")
    end
    sec = math.max(sec, 2.0)
    return math.floor((sec or 0) * 30 + 0.5)
end

-- UI Functions

---@param partId string
---@return string
function Utils.vehicleDoorLabelKeyFromId(partId)
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
        return ((getText("ContextMenu_STA_PryOpen_Vehicle", locText, sideText, nounText):gsub("%s+", " ")):gsub("^%s*(.-)%s*$", "%1"))
    end
end

_G.STA_PryOpen_Utils = Utils
return Utils