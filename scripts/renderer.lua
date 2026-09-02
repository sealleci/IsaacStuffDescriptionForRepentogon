local Renderer = {}
local SHARED_CONFIG = include("scripts/shared_config")
local CONFIG = {
    MY_STUFF_PAGE_DISPLAY_OFFSET = Vector(50, 0),
    MY_STUFF_ITEM_ICON_DISPLAY_OFFSET = Vector(84, -20),
    CURSOR_SIZE = Vector(8, 8),
    DESCRIPTION_OFFSET = Vector(0, -65),
    DESCRIPTION_WIDTH = 140,
    DESCRIPTION_SCALE = 1.0
}

function Renderer:Initialize(mod)
    self.Mod = mod
    self.EID = mod.EID
    self.DeathScreenSprite = Sprite()
    self.DeathScreenSprite:Load(
        "gfx/ui/death screen.anm2",
        true
    )
    self.DeathScreenSprite:Play("Diary", true)
    self.StuffArrowSprite = Sprite()
    self.StuffArrowSprite:Load(
        "gfx/ui/pausescreen.anm2",
        true
    )
    self.StuffArrowSprite:SetFrame("Idle", 0)
end

function Renderer:GetScreenCenter()
    return self.EID:getScreenSize() / 2
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

function Renderer:RenderCursor(slot, firstColumnNumber)
    local position = slot.Position - Vector(
        (firstColumnNumber - 1) * SHARED_CONFIG.ITEM_DISPLAY_STEP_X,
        0
    )

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
    local desc = self:GetDescription(slot.ID)

    if not desc then
        return
    end

    local renderPosition = self:GetScreenCenter() + CONFIG.DESCRIPTION_OFFSET
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

        if desc.Name and desc.Name ~= "" then
            local nameColor = self.EID:getNameColor()

            self.EID:renderString(
                desc.Name,
                renderPosition,
                textScale,
                nameColor
            )
            renderPosition.Y = renderPosition.Y + self.EID.lineHeight * self.EID.Scale
        end

        if desc.Description and desc.Description ~= "" then
            self.EID:printBulletPoints(
                desc.Description,
                renderPosition,
                desc.IgnoreBulletPointIconConfig
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

function Renderer:RenderItemIcon(
    itemID,
    position
)
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
        position + CONFIG.MY_STUFF_ITEM_ICON_DISPLAY_OFFSET
    )
end

function Renderer:RenderStuffArrows(
    itemSlots,
    firstColumnNumber
)
    local leftArrowLayer = self.StuffArrowSprite:GetLayer("StuffArrow1")
    local rightArrowLayer = self.StuffArrowSprite:GetLayer("StuffArrow2")
    local lastColumnNumber = CalcColumnNumber(#itemSlots)
    local hasLeftPage = firstColumnNumber > 1
    local hasRightPage = firstColumnNumber + (SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT - 1)
        < lastColumnNumber
    local renderPosition = self:GetScreenCenter() + CONFIG.MY_STUFF_PAGE_DISPLAY_OFFSET

    if hasLeftPage and leftArrowLayer then
        self.StuffArrowSprite:RenderLayer(
            leftArrowLayer:GetLayerID(),
            renderPosition
        )
    end

    if hasRightPage and rightArrowLayer then
        self.StuffArrowSprite:RenderLayer(
            rightArrowLayer:GetLayerID(),
            renderPosition
        )
    end
end

function Renderer:RenderMyStaffPage(
    itemSlots,
    firstColumnNumber,
    pauseBody
)
    function CalcColumnNumber(value)
        return ((value - 1) // SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT) + 1
    end

    if not pauseBody then
        pauseBody = PauseMenu:GetSprite()
    end

    local myStuffLayer = pauseBody:GetLayer("MyStuff")

    if myStuffLayer then
        pauseBody:RenderLayer(
            myStuffLayer:GetLayerID(),
            self:GetScreenCenter() + CONFIG.MY_STUFF_PAGE_DISPLAY_OFFSET
        )
        self:RenderStuffArrows(itemSlots, firstColumnNumber)
    end

    local renderedItemCount = 0
    local MAX_ITEM_COUNT = SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT * SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT

    for i, slot in ipairs(itemSlots) do
        if i >= (firstColumnNumber - 1) * SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT + 1
            and renderedItemCount < MAX_ITEM_COUNT
        then
            self:RenderItemIcon(
                slot.ID,
                slot.Position - Vector(
                    (firstColumnNumber - 1) * SHARED_CONFIG.ITEM_DISPLAY_STEP_X,
                    0
                )
            )
            renderedItemCount = renderedItemCount + 1
        end

        if renderedItemCount >= MAX_ITEM_COUNT then
            break
        end
    end
end

function Renderer:RenderInspect(slot, firstColumnNumber)
    self:RenderCursor(slot, firstColumnNumber)
    self:RenderDescription(slot)
end

return Renderer
