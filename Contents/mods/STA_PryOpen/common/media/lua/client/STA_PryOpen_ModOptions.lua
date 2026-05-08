local config = {}

local options = PZAPI.ModOptions:create("STA_PryOpen", "STA Pry Open")
options:addTitle("UI_STA_PryOpen_Options_Settings")
options:addTickBox("sayOnAction", getText("UI_STA_PryOpen_Options_CharacterSayOnSuccess"), true, getText("UI_STA_PryOpen_Options_CharacterSayOnSuccess_tooltip"))
options:addSlider("volumeAdjust", getText("UI_STA_PryOpen_Options_VolumeAdjust"), 0.00, 1.00, 0.10, 0.50, getText("UI_STA_PryOpen_Options_VolumeAdjust_tooltip"))

options.apply = function(self)
    for k,v in pairs(self.dict) do
        if v.type == "multipletickbox" then
            for i=1, #v.values do
                config[(k.."_"..tostring(i))] = v:getValue(i)
            end
        elseif v.type == "button" then
        else
            config[k] = v:getValue()
        end
    end
end

Events.OnMainMenuEnter.Add(function()
    options:apply()
end)

return config