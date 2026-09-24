---@diagnostic disable: undefined-global

local ModConfig = {}
local MENU_INFO = {
    CATEGORY = "My Stuff Desc",
    OUTLINE_MODES = {
        "Off",
        "Thin",
        "Full",
    },
    OUTLINE_COLORS = {
        "Black",
        "White",
    }
}

function ModConfig:Round(value)
    return math.floor(value + 0.5)
end

function ModConfig:RegisterLayoutSettings()
    ModConfigMenu.AddTitle(
        MENU_INFO.CATEGORY,
        "Layout",
        "My Stuff layout"
    )
    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Layout",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.ModSave.Data.OffsetX
            end,
            Minimum = -200,
            Maximum = 200,
            Display = function()
                return "Horizontal offset: "
                    .. tostring(self.ModSave.Data.OffsetX)
            end,
            OnChange = function(value)
                self.ModSave:Set("OffsetX", ModConfig:Round(value))
            end,
            Info = {
                "Adjusts content horizontally in screen pixels."
            }
        }
    )
    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Layout",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.ModSave.Data.OffsetY
            end,
            Minimum = -200,
            Maximum = 200,
            Display = function()
                return "Vertical offset: "
                    .. tostring(self.ModSave.Data.OffsetY)
            end,
            OnChange = function(value)
                self.ModSave:Set("OffsetY", self:Round(value))
            end,
            Info = {
                "Adjusts content vertically in screen pixels."
            }
        }
    )
end

function ModConfig:RegisterAppearanceSettings()
    ModConfigMenu.AddTitle(
        MENU_INFO.CATEGORY,
        "Appearance",
        "Item icon appearance"
    )

    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Appearance",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.ModSave.Data.ExtraRNG
            end,
            Minimum = 0,
            Maximum = 500,
            Display = function()
                return "Extra RNG: "
                    .. tostring(self.ModSave.Data.ExtraRNG)
            end,
            OnChange = function(value)
                self.ModSave:Set("ExtraRNG", ModConfig:Round(value))
            end,
            Info = {
                "Tries different RNG counts."
            }
        }
    )

    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Appearance",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.ModSave.Data.IconBrightness
            end,
            Minimum = 5,
            Maximum = 20,
            Display = function()
                return string.format(
                    "Icon brightness: %.1fx",
                    self.ModSave.Data.IconBrightness / 10
                )
            end,
            OnChange = function(value)
                self.ModSave:Set("IconBrightness", self:Round(value))
            end,
            Info = {
                "Adjusts brightness of item icons.",
                "1.0x represents the original brightness."
            }
        }
    )
    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Appearance",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.ModSave.Data.IconOutline
            end,
            Minimum = 1,
            Maximum = #MENU_INFO.OUTLINE_MODES,
            Display = function()
                return "Icon outline: "
                    .. MENU_INFO.OUTLINE_MODES[self.ModSave.Data.IconOutline]
            end,
            OnChange = function(value)
                self.ModSave:Set("IconOutline", self:Round(value))
            end,
            Info = {
                "Adds a contrast outline around item icons."
            }
        }
    )
    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Appearance",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.ModSave.Data.OutlineColor
            end,
            Minimum = 1,
            Maximum = #MENU_INFO.OUTLINE_COLORS,
            Display = function()
                return "Outline color: "
                    .. MENU_INFO.OUTLINE_COLORS[self.ModSave.Data.OutlineColor]
            end,
            OnChange = function(value)
                self.ModSave:Set("OutlineColor", self:Round(value))
            end,
            Info = {
                "Changes color of outline around item icons."
            }
        }
    )
end

function ModConfig:Initialize(modSave)
    if ModConfigMenu == nil then
        return
    end

    self.ModSave = modSave
    self:RegisterAppearanceSettings()
    self:RegisterLayoutSettings()
end

return ModConfig
