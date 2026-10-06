---@type MSD4RUIConfig
local UI_CONFIG = {
    ITEMS_DISPLAY_ROW_COUNT = 4,
    ITEMS_DISPLAY_COLUMN_COUNT = 6,
    ITEMS_DISPLAY_STEP_X = 16,
    ITEMS_DISPLAY_STEP_Y = 16,
    ---@param self MSD4RUIConfig
    ---@param index integer
    ---@return integer result1
    GetColumnNumber = function(self, index)
        if index <= 0 then
            return 1
        end

        return ((index - 1) // self.ITEMS_DISPLAY_ROW_COUNT) + 1
    end
}

---@type MSD4RUIConfig
return UI_CONFIG
