local Renderer = {}
local SHARED_CONFIG = include("scripts/shared_config")
local CONFIG = {
    MY_STUFF_PAGE_DISPLAY_OFFSET = Vector(49, 0),
    MY_STUFF_ITEM_DISPLAY_OFFSET = Vector(84, -19),
    FIRST_ITEM_DISPLAY_OFFSET = Vector(-159, 11),
    CURSOR_SIZE = Vector(8, 8),
    DESCRIPTION_OFFSET = Vector(0, -65),
    DESCRIPTION_WIDTH = 140,
    DESCRIPTION_SCALE = 1.0
}

function Renderer:Initialize(mod)
    self.Mod = mod
    self.EID = mod.EID
    self.PauseMenuSprite = Sprite()
    self.PauseMenuSprite:Load(
        "gfx/ui/pausescreen.anm2",
        true
    )
    self.PauseMenuSprite:SetFrame("Idle", 0)
    self.DeathScreenSprite = Sprite()
    self.DeathScreenSprite:Load(
        "gfx/ui/death screen.anm2",
        true
    )
    self.DeathScreenSprite:Play("Diary", true)
end

function Renderer:GetPauseMenuExtraOffset()
    return Vector(
        math.floor(Isaac.GetScreenWidth() / 10 - 48),
        0
    )
end

function Renderer:GetPauseMenuAnchor()
    return Vector(
        math.floor(Isaac.GetScreenWidth() * 0.5),
        math.floor(Isaac.GetScreenHeight() * 0.5)
    ) + self:GetPauseMenuExtraOffset()
end

function Renderer:GetColumnNumber(index)
    if index <= 0 then
        return 1
    end

    return ((index - 1) // SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT) + 1
end

function Renderer:GetItemSlotPosition(index, firstColumnNumber)
    local columnNumber = (index - 1) // SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT + 1
    local rowNumber = (index - 1) % SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT

    return self:GetPauseMenuAnchor()
        + CONFIG.FIRST_ITEM_DISPLAY_OFFSET
        + Vector(
            (columnNumber - firstColumnNumber) * SHARED_CONFIG.ITEM_DISPLAY_STEP_X,
            rowNumber * SHARED_CONFIG.ITEM_DISPLAY_STEP_Y
        )
end

function Renderer:GetDescription(itemID)
    local success, result = pcall(
        self.EID.getDescriptionObj,
        self.EID,
        EntityType.ENTITY_PICKUP,
        PickupVariant.PICKUP_COLLECTIBLE,
        itemID,
        nil,
        true
    )

    if not success then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to get EID description "
            .. "for collectible "
            .. tostring(itemID)
            .. ": "
            .. tostring(result)
            .. "\n"
        )

        return nil
    end

    return result
end

function Renderer:SetMyStuffPageFrame(animation, frame)
    self.PauseMenuSprite:SetFrame(animation, frame)
end

function Renderer:SetMyStuffPageIdle()
    self.PauseMenuSprite:SetFrame("Idle", 0)
end

function Renderer:RenderItemIcon(itemID, position)
    self.DeathScreenSprite:SetFrame(
        "Diary",
        itemID - 1
    )

    local layer = self.DeathScreenSprite:GetLayer("Items")

    if not layer then
        return
    end

    self.DeathScreenSprite:RenderLayer(
        layer:GetLayerID(),
        position + CONFIG.MY_STUFF_ITEM_DISPLAY_OFFSET
    )
end

function Renderer:RenderEmptyMyStuffPage()
    local myStuffLayer = self.PauseMenuSprite:GetLayer("MyStuff")

    if myStuffLayer then
        self.PauseMenuSprite:RenderLayer(
            myStuffLayer:GetLayerID(),
            self:GetPauseMenuAnchor() + CONFIG.MY_STUFF_PAGE_DISPLAY_OFFSET
        )
    end
end

function Renderer:RenderStuffArrows(itemSlots, firstColumnNumber)
    local leftArrowLayer = self.PauseMenuSprite:GetLayer("StuffArrow1")
    local rightArrowLayer = self.PauseMenuSprite:GetLayer("StuffArrow2")
    local lastColumnNumber = self:GetColumnNumber(#itemSlots)
    local hasLeftPage = firstColumnNumber > 1
    local hasRightPage = firstColumnNumber
        + (SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT - 1)
        < lastColumnNumber
    local renderPosition = self:GetPauseMenuAnchor()
        + CONFIG.MY_STUFF_PAGE_DISPLAY_OFFSET

    if hasLeftPage and leftArrowLayer then
        self.PauseMenuSprite:RenderLayer(
            leftArrowLayer:GetLayerID(),
            renderPosition
        )
    end

    if hasRightPage and rightArrowLayer then
        self.PauseMenuSprite:RenderLayer(
            rightArrowLayer:GetLayerID(),
            renderPosition
        )
    end
end

function Renderer:RenderMyStuffPage(itemSlots, firstColumnNumber)
    self:RenderEmptyMyStuffPage()

    local firstVisibleIndex = (firstColumnNumber - 1)
        * SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT + 1
    local maxItemCount = SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT
        * SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT
    local lastVisibleIndex = math.min(
        #itemSlots,
        firstVisibleIndex + maxItemCount - 1
    )

    for i = firstVisibleIndex, lastVisibleIndex do
        local slot = itemSlots[i]

        if slot then
            self:RenderItemIcon(
                slot.ID,
                self:GetItemSlotPosition(slot.Index, firstColumnNumber)
            )
        end
    end

    self:RenderStuffArrows(itemSlots, firstColumnNumber)
end

function Renderer:RenderCursor(index, firstColumnNumber)
    local position = self:GetItemSlotPosition(index, firstColumnNumber)

    Isaac.DrawQuad(
        position - CONFIG.CURSOR_SIZE,
        position + Vector(CONFIG.CURSOR_SIZE.X, -CONFIG.CURSOR_SIZE.Y),
        position + Vector(-CONFIG.CURSOR_SIZE.X, CONFIG.CURSOR_SIZE.Y),
        position + CONFIG.CURSOR_SIZE,
        KColor(1, 1, 1, 1),
        1
    )
end

function Renderer:RenderDescription(slot)
    local description = self:GetDescription(slot.ID)

    if not description then
        return
    end

    local renderPosition = self:GetPauseMenuAnchor() + CONFIG.DESCRIPTION_OFFSET
    local prevScale = self.EID.Scale
    local prevTextboxWidth = self.EID.Config["TextboxWidth"]
    local prevInsideItemReminder = self.EID.InsideItemReminder

    self.EID.Scale = CONFIG.DESCRIPTION_SCALE
    self.EID.Config["TextboxWidth"] = CONFIG.DESCRIPTION_WIDTH
    self.EID.InsideItemReminder = true

    local success, err = pcall(function()
        local textScale = Vector(
            self.EID.Scale,
            self.EID.Scale
        )

        if description.Name and description.Name ~= "" then
            local nameColor = self.EID:getNameColor()

            self.EID:renderString(
                description.Name,
                renderPosition,
                textScale,
                nameColor
            )
            renderPosition.Y = renderPosition.Y
                + self.EID.lineHeight * self.EID.Scale
        end

        if description.Description and description.Description ~= "" then
            self.EID:printBulletPoints(
                description.Description,
                renderPosition,
                description.IgnoreBulletPointIconConfig
            )
        end
    end)

    self.EID.Scale = prevScale
    self.EID.Config["TextboxWidth"] = prevTextboxWidth
    self.EID.InsideItemReminder = prevInsideItemReminder

    if not success then
        Isaac.ConsoleOutput(
            "[MSD4R] EID rendering error: "
            .. tostring(err)
            .. "\n"
        )
    end
end

function Renderer:RenderInspect(slot, selectedIndex, firstColumnNumber)
    self:RenderCursor(selectedIndex, firstColumnNumber)
    self:RenderDescription(slot)
end

return Renderer
