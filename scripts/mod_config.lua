---@diagnostic disable: undefined-global

local ModConfig = {}
local MENU_INFO = {
    CATEGORY = "My Stuff Desc",
    LAYOUT_MODES = {
        "Auto (follow custom layout)",
        "Fixed (original layout)",
    },
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
                return self.Settings.Data.LayoutMode
            end,
            Minimum = 1,
            Maximum = #MENU_INFO.LAYOUT_MODES,
            Display = function()
                return "Layout mode: "
                    .. MENU_INFO.LAYOUT_MODES[self.Settings.Data.LayoutMode]
            end,
            OnChange = function(value)
                self.Settings:Set("LayoutMode", ModConfig:Round(value))
            end,
            Info = {
                "Auto option follows other mods' custom layout.",
                "Fixed option keeps the original position."
            }
        }
    )
    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Layout",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.Settings.Data.OffsetX
            end,
            Minimum = -200,
            Maximum = 200,
            Display = function()
                return "Horizontal offset: "
                    .. tostring(self.Settings.Data.OffsetX)
            end,
            OnChange = function(value)
                self.Settings:Set("OffsetX", ModConfig:Round(value))
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
                return self.Settings.Data.OffsetY
            end,
            Minimum = -200,
            Maximum = 200,
            Display = function()
                return "Vertical offset: "
                    .. tostring(self.Settings.Data.OffsetY)
            end,
            OnChange = function(value)
                self.Settings:Set("OffsetY", self:Round(value))
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
                return self.Settings.Data.IconOutline
            end,
            Minimum = 1,
            Maximum = #MENU_INFO.OUTLINE_MODES,
            Display = function()
                return "Icon outline: "
                    .. MENU_INFO.OUTLINE_MODES[self.Settings.Data.IconOutline]
            end,
            OnChange = function(value)
                self.Settings:Set("IconOutline", self:Round(value))
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
                return self.Settings.Data.OutlineColor
            end,
            Minimum = 1,
            Maximum = #MENU_INFO.OUTLINE_COLORS,
            Display = function()
                return "Outline color: "
                    .. MENU_INFO.OUTLINE_COLORS[self.Settings.Data.OutlineColor]
            end,
            OnChange = function(value)
                self.Settings:Set("OutlineColor", self:Round(value))
            end,
            Info = {
                "Changes color of outline around item icons."
            }
        }
    )
    ModConfigMenu.AddSetting(
        MENU_INFO.CATEGORY,
        "Appearance",
        {
            Type = ModConfigMenu.OptionType.NUMBER,
            CurrentSetting = function()
                return self.Settings.Data.IconBrightness
            end,
            Minimum = 5,
            Maximum = 20,
            Display = function()
                return string.format(
                    "Icon brightness: %.1fx",
                    self.Settings.Data.IconBrightness / 10
                )
            end,
            OnChange = function(value)
                self.Settings:Set("IconBrightness", self:Round(value))
            end,
            Info = {
                "Adjusts brightness of item icons.",
                "1.0x preserves the original visibility of item icons."
            }
        }
    )
end

function ModConfig:Initialize(settings)
    if ModConfigMenu == nil then
        return
    end

    self.Settings = settings
    self:RegisterLayoutSettings()
    self:RegisterAppearanceSettings()
end

return ModConfig
