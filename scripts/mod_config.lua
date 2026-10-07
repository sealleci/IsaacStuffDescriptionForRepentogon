---@diagnostic disable: undefined-global

---@class MSD4RModConfig
---@field ModSave MSD4RModSave
local ModConfig = {}

---@type MSD4RUtility
local Utility = include("scripts/utility")

---@type MSD4RMenuInfo
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

---@return nil # No return value.
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
            ---@return integer result1
            CurrentSetting = function()
                return self.ModSave.Data.IconBrightness
            end,
            Minimum = 5,
            Maximum = 20,
            ---@return string result1
            Display = function()
                return string.format(
                    "Icon brightness: %.1fx",
                    self.ModSave.Data.IconBrightness / 10
                )
            end,
            ---@param value number
            ---@return nil # No return value.
            OnChange = function(value)
                self.ModSave:Set("IconBrightness", Utility.Round(value))
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
            ---@return integer result1
            CurrentSetting = function()
                return self.ModSave.Data.IconOutline
            end,
            Minimum = 1,
            Maximum = #MENU_INFO.OUTLINE_MODES,
            ---@return string result1
            Display = function()
                return "Icon outline: "
                    .. MENU_INFO.OUTLINE_MODES[self.ModSave.Data.IconOutline]
            end,
            ---@param value number
            ---@return nil # No return value.
            OnChange = function(value)
                self.ModSave:Set("IconOutline", Utility.Round(value))
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
            ---@return integer result1
            CurrentSetting = function()
                return self.ModSave.Data.OutlineColor
            end,
            Minimum = 1,
            Maximum = #MENU_INFO.OUTLINE_COLORS,
            ---@return string result1
            Display = function()
                return "Outline color: "
                    .. MENU_INFO.OUTLINE_COLORS[self.ModSave.Data.OutlineColor]
            end,
            ---@param value number
            ---@return nil # No return value.
            OnChange = function(value)
                self.ModSave:Set("OutlineColor", Utility.Round(value))
            end,
            Info = {
                "Changes color of outline around item icons."
            }
        }
    )
end

---@return nil # No return value.
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
            ---@return integer result1
            CurrentSetting = function()
                return self.ModSave.Data.OffsetX
            end,
            Minimum = -200,
            Maximum = 200,
            ---@return string result1
            Display = function()
                return "Horizontal offset: "
                    .. tostring(self.ModSave.Data.OffsetX)
            end,
            ---@param value number
            ---@return nil # No return value.
            OnChange = function(value)
                self.ModSave:Set("OffsetX", Utility.Round(value))
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
            ---@return integer result1
            CurrentSetting = function()
                return self.ModSave.Data.OffsetY
            end,
            Minimum = -200,
            Maximum = 200,
            ---@return string result1
            Display = function()
                return "Vertical offset: "
                    .. tostring(self.ModSave.Data.OffsetY)
            end,
            ---@param value number
            ---@return nil # No return value.
            OnChange = function(value)
                self.ModSave:Set("OffsetY", Utility.Round(value))
            end,
            Info = {
                "Adjusts content vertically in screen pixels."
            }
        }
    )
end

---@param modSave MSD4RModSave
---@return nil # No return value.
function ModConfig:Initialize(modSave)
    if not modSave.SaveAvailable then
        return
    end

    if ModConfigMenu == nil then
        return
    end

    self.ModSave = modSave

    self:RegisterAppearanceSettings()
    self:RegisterLayoutSettings()
end

---@type MSD4RModConfig
return ModConfig
