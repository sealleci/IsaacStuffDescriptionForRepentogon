local SHARED_CONFIG = {
    ITEM_DISPLAY_ROW_COUNT = 6,
    ITEM_DISPLAY_COLUMN_COUNT = 4,
    ITEM_DISPLAY_STEP_X = 16,
    ITEM_DISPLAY_STEP_Y = 16,
    ITEMS_SPRITE_SHEET_COLUMN_COUNT = 20,
    GetColumnNumber = function(self, index)
        if index <= 0 then
            return 1
        end

        return ((index - 1) // self.ITEM_DISPLAY_COLUMN_COUNT) + 1
    end
}

return SHARED_CONFIG
