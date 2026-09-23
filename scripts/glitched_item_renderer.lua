local GlitchedItemRenderer = {}
local UI_CONFIG = include("scripts/ui_config")
local Utility = include("scripts/utility")
local CONFIG = {
    ICON_SIZE = 16,
    TILE_SIZE = 2
}

function GlitchedItemRenderer:Initialize()
    if self.Initialized then
        return
    end

    if not _G.Renderer
        or not _G.Renderer.LoadImage
        or not SourceQuad
        or not DestinationQuad
    then
        Isaac.ConsoleOutput(
            "[MSD4R] REPENTOGON Image/Quad API is unavailable. "
            .. "Glitched item rendering is disabled.\n"
        )

        return
    end

    self.ItemIconsFilepath = "gfx/ui/death items.png"

    local successful, image = pcall(
        _G.Renderer.LoadImage,
        self.ItemIconsFilepath
    )
    if not successful
        or not image
    then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to load "
            .. self.ItemIconsFilepath
            .. ".\n"
        )

        return
    end

    self.ItemIconsImage = image
    self.AtlasWidth = image:GetWidth()
    self.AtlasHeight = image:GetHeight()
    self.AtlasColumnCount = math.floor(self.AtlasWidth / CONFIG.ICON_SIZE)
    self.AtlasRowCount = math.floor(self.AtlasHeight / CONFIG.ICON_SIZE)
    self.Initialized = true
end

function GlitchedItemRenderer:GetNextProceduralRNG(state)
    state = Utility.ConvertToU32(state ~ (state >> 4))
    state = Utility.ConvertToU32(state ~ (state << 3))
    state = Utility.ConvertToU32(state ~ (state >> 27))

    return state
end

function GlitchedItemRenderer:AdjustItemID(itemID)
    local adjustedItemID = itemID

    if itemID > 360 then
        adjustedItemID = adjustedItemID + 1
    end
    if itemID > 396 then
        adjustedItemID = adjustedItemID + 3
    end
    if itemID > 552 then
        adjustedItemID = adjustedItemID + 4
    end

    return adjustedItemID
end

function GlitchedItemRenderer:GetValidItemConfig(startIndex)
    local itemConfig = Isaac.GetItemConfig()
    local itemCount = Utility.GetItemCount()

    if itemCount <= 0 then
        return nil, nil
    end

    local index = startIndex % itemCount

    for _ = 1, itemCount do
        local config = itemConfig:GetCollectible(index)

        if config then
            return index, config
        end

        index = (index + 1) % itemCount
    end

    return nil, nil
end

function GlitchedItemRenderer:GetRandomSourceItemID(state)
    local function randomInt(value, max)
        value = self:GetNextProceduralRNG(value)

        if max == 0 then
            return value, 0
        end

        return value, value % max
    end

    local randomItemID
    randomItemID, state = randomInt(
        state,
        Utility.GetItemCount()
    )

    local itemID, config = self:GetValidItemConfig(randomItemID)
    if not itemID
        or not config
        or not config.GfxFileName
        or config.GfxFileName == ""
    then
        return nil, state
    end

    return itemID, state
end

function GlitchedItemRenderer:GenerateSourceItemIDs(state)
    local sourceItemIDs = {
        nil,
        nil,
        nil,
        nil
    }

    for sourceImageIndex = 1, 4 do
        for _ = 1, 10 do
            local itemID
            itemID, state = self:GetRandomSourceItemID(state)

            if itemID then
                sourceItemIDs[sourceImageIndex] = itemID
                break
            end
        end
    end

    return sourceItemIDs, state
end

function GlitchedItemRenderer:GenerateRecipe(state)
    state = Utility.ConvertToU32(state)
    local sourceTileIndex = 0
    local sourceImageIndex = 0
    local recipe = {}

    state = self:GetNextProceduralRNG(state)
    if state % 5 == 0 then
        state = self:GetNextProceduralRNG(state)
        sourceTileIndex = state & 0x3F
    end

    state = self:GetNextProceduralRNG(state)
    for destinationTileIndex = 0, 63 do
        if (sourceTileIndex & 0xFFFFFFF8) > 56 then
            recipe[destinationTileIndex + 1] = {
                SourceTileIndex = 0xFF,
                SourceImageIndex = 0xFF
            }
        else
            recipe[destinationTileIndex + 1] = {
                SourceTileIndex = sourceTileIndex,
                SourceImageIndex = sourceImageIndex
            }
            sourceTileIndex = sourceTileIndex + 1

            state = self:GetNextProceduralRNG(state)
            if state % 12 == 0 then
                state = self:GetNextProceduralRNG(state)
            end

            local changeSource = false
            if sourceTileIndex >= 64 then
                changeSource = true
            else
                state = self:GetNextProceduralRNG(state)
                changeSource = state % 12 == 0
            end

            if changeSource then
                sourceImageIndex = (sourceImageIndex + 1) & 3
                sourceTileIndex = destinationTileIndex

                state = self:GetNextProceduralRNG(state)
                if state % 20 == 0 then
                    sourceTileIndex = destinationTileIndex + 1
                end

                state = self:GetNextProceduralRNG(state)
                if state % 5 == 0 then
                    state = self:GetNextProceduralRNG(state)
                end
            end
        end
    end

    return recipe, state
end

function GlitchedItemRenderer:GetItemIconCellPosition(itemID)
    if itemID <= 0 then
        return nil
    end

    local index = self:AdjustItemID(itemID) - 1
    local maxCellCount = self.AtlasColumnCount * self.AtlasRowCount

    if index < 0
        or index >= maxCellCount
    then
        return nil
    end

    return Vector(
        (index % self.AtlasColumnCount) * CONFIG.ICON_SIZE,
        (index // self.AtlasColumnCount) * CONFIG.ICON_SIZE
    )
end

function GlitchedItemRenderer:RenderItemIconTile(
    itemID,
    sourceTileIndex,
    destinationTileIndex,
    position,
    scale,
    color
)
    if sourceTileIndex == 0xFF then
        return false
    end

    local cellPosition = self:GetItemIconCellPosition(itemID)
    if not cellPosition then
        return false
    end

    if not scale then
        scale = Vector(1, 1)
    end

    local sourceTopLeft = cellPosition + Vector(
        ((sourceTileIndex >> 3) & 7)
        * CONFIG.TILE_SIZE,
        (sourceTileIndex & 7)
        * CONFIG.TILE_SIZE
    )
    local destinationTopLeft = position + Vector(
        ((destinationTileIndex >> 3) & 7)
        * CONFIG.TILE_SIZE * scale.X,
        (destinationTileIndex & 7)
        * CONFIG.TILE_SIZE * scale.Y
    ) - Vector(
        UI_CONFIG.ITEMS_DISPLAY_STEP_X // 2
        * scale.X,
        UI_CONFIG.ITEMS_DISPLAY_STEP_X // 2
        * scale.Y
    )
    local sourceSize = Vector(CONFIG.TILE_SIZE, CONFIG.TILE_SIZE)
    local destinationSize = Vector(
        CONFIG.TILE_SIZE * scale.X,
        CONFIG.TILE_SIZE * scale.Y
    )
    local sourceQuad = SourceQuad.NewFromRectangle(
        sourceTopLeft,
        sourceSize.X,
        sourceSize.Y,
        false
    )
    local destinationQuad = DestinationQuad.NewFromRectangle(
        destinationTopLeft,
        destinationSize.X,
        destinationSize.Y
    )

    self.ItemIconsImage:Render(
        sourceQuad,
        destinationQuad,
        Utility.ConvertToKColor(color)
    )

    return true
end

function GlitchedItemRenderer:RenderItemIcon(
    proceduralSeed,
    position,
    scale,
    color
)
    local recipe, nextState = self:GenerateRecipe(proceduralSeed)
    local sourceItemIDs, _ = self:GenerateSourceItemIDs(nextState)
    local renderedTile = false

    for destinationTileIndex = 0, 63 do
        local tile = recipe[destinationTileIndex + 1]
        if tile
            and tile.SourceImageIndex ~= 0xFF
        then
            local itemID = sourceItemIDs[tile.SourceImageIndex + 1]
            if itemID then
                renderedTile = self:RenderItemIconTile(
                    itemID,
                    tile.SourceTileIndex,
                    destinationTileIndex,
                    position,
                    scale,
                    color
                )
            end
        end
    end

    return renderedTile
end

return GlitchedItemRenderer
