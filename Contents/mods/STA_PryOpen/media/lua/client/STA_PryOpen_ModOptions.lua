require "STA_PryOpen_Client"

local options = {
    sayOnAction = true,
    volumeAdjust = 6,
}

if ModOptions and ModOptions.getInstance then
    local settings = ModOptions:getInstance(options, "STA_PryOpen", "ST Addtions - Pry Open")

    local sayOnAction = settings:getData("sayOnAction")
    sayOnAction.name = "UI_STA_PryOpen_Options_CharacterSayOnSuccess"
    sayOnAction.tooltip = "UI_STA_PryOpen_Options_CharacterSayOnSuccess_tooltip"

    local volumeAdjust = settings:getData("volumeAdjust")
    volumeAdjust.name = "UI_STA_PryOpen_Options_VolumeAdjust"
    volumeAdjust[1] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice100")
    volumeAdjust[2] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice90")
    volumeAdjust[3] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice80")
    volumeAdjust[4] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice70")
    volumeAdjust[5] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice60")
    volumeAdjust[6] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice50")
    volumeAdjust[7] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice40")
    volumeAdjust[8] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice30")
    volumeAdjust[9] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice20")
    volumeAdjust[10] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice10")
    volumeAdjust[11] = getText("UI_STA_PryOpen_Options_VolumeAdjust_Choice0")
    volumeAdjust.tooltip = "UI_STA_PryOpen_Options_VolumeAdjust_tooltip"

    SetModOptionsClient(options)
end