local UI_CONFIG = {
    ITEMS_DISPLAY_ROW_COUNT = 4,
    ITEMS_DISPLAY_COLUMN_COUNT = 6,
    ITEMS_DISPLAY_STEP_X = 16,
    ITEMS_DISPLAY_STEP_Y = 16,
    GetColumnNumber = function(self, index)
        if index <= 0 then
            return 1
        end

        return ((index - 1) // self.ITEMS_DISPLAY_ROW_COUNT) + 1
    end
}

return UI_CONFIG
