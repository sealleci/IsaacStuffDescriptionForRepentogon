local Renderer = {}
local SHARED_CONFIG = include("scripts/shared_config")
local CONFIG = {
    PAUSE_MENU_LAYER_OFFSET = Vector(49, 0),
    FIXED_FIRST_ITEM_DISPLAY_OFFSET = Vector(-208, 8),
    AUTO_LAYOUT_ITEMS_DISPLAY_OFFSET = Vector(0, 4),
    AVATAR_DISPLAY_OFFSET = Vector(-120, 96),
    CURSOR_SIZE = Vector(8, 8),
    CURSOR_DISPLAY_OFFSET = Vector(0, 1),
    DESCRIPTION_OFFSET = Vector(0, -65),
    DESCRIPTION_WIDTH = 140,
    DESCRIPTION_SCALE = 1.0,

    --[[
    Large ANM2 positions such as (-500, -500) are commonly used to
    hide a layer off-screen. Treat them as an opt-out from auto layout.
    ]]
    AUTO_LAYOUT_POSITION_LIMIT = 400,

    --[[
    A scale outside this range is almost an animation transition, a hidden layer,
    or an unsupported layout. Item rendering only happens on pause menu's idle frame,
    but these guards make the fallback explicit.
    ]]
    AUTO_LAYOUT_MIN_SCALE = 0.1,
    AUTO_LAYOUT_MAX_SCALE = 3.0,

    PLAYER_TYPE_TO_AVATAR_LAYER_ID = {
        [PlayerType.PLAYER_ISAAC] = 1,
        [PlayerType.PLAYER_MAGDALENE] = 2,
        [PlayerType.PLAYER_CAIN] = 3,
        [PlayerType.PLAYER_JUDAS] = 4,
        [PlayerType.PLAYER_BLACKJUDAS] = 4,
        [PlayerType.PLAYER_BLUEBABY] = 5,
        [PlayerType.PLAYER_EVE] = 6,
        [PlayerType.PLAYER_SAMSON] = 7,
        [PlayerType.PLAYER_AZAZEL] = 8,
        [PlayerType.PLAYER_LAZARUS] = 9,
        [PlayerType.PLAYER_LAZARUS2] = 9,
        [PlayerType.PLAYER_EDEN] = 10,
        [PlayerType.PLAYER_THELOST] = 11,
        [PlayerType.PLAYER_LILITH] = 12,
        [PlayerType.PLAYER_KEEPER] = 13,
        [PlayerType.PLAYER_APOLLYON] = 14,
        [PlayerType.PLAYER_THEFORGOTTEN] = 15,
        [PlayerType.PLAYER_THESOUL] = 15,
        [PlayerType.PLAYER_BETHANY] = 16,
        [PlayerType.PLAYER_JACOB] = 17,
        [PlayerType.PLAYER_ESAU] = 18,
        [PlayerType.PLAYER_ISAAC_B] = 19,
        [PlayerType.PLAYER_MAGDALENE_B] = 20,
        [PlayerType.PLAYER_CAIN_B] = 21,
        [PlayerType.PLAYER_JUDAS_B] = 22,
        [PlayerType.PLAYER_BLUEBABY_B] = 23,
        [PlayerType.PLAYER_EVE_B] = 24,
        [PlayerType.PLAYER_SAMSON_B] = 25,
        [PlayerType.PLAYER_AZAZEL_B] = 26,
        [PlayerType.PLAYER_LAZARUS_B] = 27,
        [PlayerType.PLAYER_LAZARUS2_B] = 27,
        [PlayerType.PLAYER_EDEN_B] = 28,
        [PlayerType.PLAYER_THELOST_B] = 29,
        [PlayerType.PLAYER_LILITH_B] = 30,
        [PlayerType.PLAYER_KEEPER_B] = 31,
        [PlayerType.PLAYER_APOLLYON_B] = 32,
        [PlayerType.PLAYER_THEFORGOTTEN_B] = 33,
        [PlayerType.PLAYER_THESOUL_B] = 33,
        [PlayerType.PLAYER_BETHANY_B] = 34,
        [PlayerType.PLAYER_JACOB_B] = 35,
        [PlayerType.PLAYER_JACOB2_B] = 35,
    },
    THIN_OUTLINE_OFFSETS = {
        Vector(-1, 0),
        Vector(1, 0),
        Vector(0, -1),
        Vector(0, 1),
    },
    FULL_OUTLINE_OFFSETS = {
        Vector(-1, 0),
        Vector(1, 0),
        Vector(0, -1),
        Vector(0, 1),
        Vector(-1, -1),
        Vector(1, -1),
        Vector(-1, 1),
        Vector(1, 1),
    }
}

function Renderer:Initialize(mod)
    self.Mod = mod
    self.EID = mod.EID
    self.Settings = mod.Settings
    self.HiddenPauseMenuLayers = {}
    self.PauseMenuSpritesheetReplaced = false
    self.OriginalPauseMenuSpritesheet = nil

    self.TrinketSprite = Sprite()
    self.TrinketSprite:Load(
        "gfx/ui/death trinkets_msd4r.anm2",
        true
    )
    self.TrinketSprite:Play("Diary", true)

    self.ModTrinketSprites = {}

    self.AvatarSprite = Sprite()
    self.AvatarSprite:Load(
        "gfx/ui/coop menu_msd4r.anm2",
        true
    )
    self.AvatarSprite:Play("Main", true)
end

function Renderer:MultiplyVector(left, right)
    return Vector(
        left.X * right.X,
        left.Y * right.Y
    )
end

function Renderer:NormalizeFrameScale(scale)
    --[[
    AnimationFrame values correspond to ANM2 values.
    Scale values encountered by mods may be exposed
    either as 100-based or 1-based render multipliers.
    Accept both forms to keep compatibility.
    ]]

    local x = scale.X
    local y = scale.Y

    if math.abs(x) > 4 then
        x = x / 100
    end
    if math.abs(y) > 4 then
        y = y / 100
    end

    return Vector(x, y)
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

function Renderer:GetMyStuffFrame(pauseBody)
    if not pauseBody then
        return nil
    end

    local layer = pauseBody:GetLayer("MyStuff")
    if not layer then
        return nil
    end

    local animation = pauseBody:GetAnimationData("Idle")
    if not animation then
        return nil
    end

    local animationLayer = animation:GetLayer(layer:GetLayerID())

    if not animationLayer
        or not animationLayer:IsVisible()
    then
        return nil
    end

    local frame = animationLayer:GetFrame(0)
    if not frame then
        return nil
    end

    return frame
end

function Renderer:GetMyStuffFrameInfo(pauseBody)
    if not pauseBody then
        return nil
    end

    local layer = pauseBody:GetLayer("MyStuff")
    if not layer then
        return nil
    end

    local frame = self:GetMyStuffFrame(pauseBody)
    if not frame then
        return nil
    end

    local position = frame:GetPos()
    local rawScale = frame:GetScale()
    local pivot = frame:GetPivot()
    if not position
        or not rawScale
        or not pivot
    then
        return nil
    end

    local scale = self:NormalizeFrameScale(rawScale)
    local scaleX = math.abs(scale.X)
    local scaleY = math.abs(scale.Y)

    if scaleX < CONFIG.AUTO_LAYOUT_MIN_SCALE
        or scaleY < CONFIG.AUTO_LAYOUT_MIN_SCALE
        or scaleX > CONFIG.AUTO_LAYOUT_MAX_SCALE
        or scaleY > CONFIG.AUTO_LAYOUT_MAX_SCALE
    then
        return nil
    end

    local pivot = frame:GetPivot()
    local size = Vector(
        frame:GetWidth() * scaleX,
        frame:GetHeight() * scaleY
    )
    local topLeft = self:GetPauseMenuAnchor()
        + position
        - Vector(
            pivot.X * scale.X,
            pivot.Y * scale.Y
        )

    return {
        Layer = layer,
        Frame = frame,
        Position = position,
        Pivot = pivot,
        Scale = Vector(scaleX, scaleY),
        Size = size,
        TopLeft = topLeft,
        Width = frame:GetWidth(),
        Height = frame:GetHeight()
    }
end

function Renderer:GetFixedLayout(frameInfo)
    local offset = self.Settings:GetOffset()
    local itemOrigin = self:GetPauseMenuAnchor()
        + CONFIG.FIXED_FIRST_ITEM_DISPLAY_OFFSET
        + offset

    return {
        Mode = "fixed",
        ItemOrigin = itemOrigin,
        ItemScale = Vector(1, 1),
        ItemStep = Vector(
            SHARED_CONFIG.ITEMS_DISPLAY_STEP_X,
            SHARED_CONFIG.ITEMS_DISPLAY_STEP_Y
        ),
        OverlayDelta = offset,
        MyStuffFrameInfo = frameInfo
    }
end

function Renderer:GetAutoLayout(frameInfo)
    if not frameInfo then
        return nil
    end

    local scale = frameInfo.Scale
    local itemStep = Vector(
        SHARED_CONFIG.ITEMS_DISPLAY_STEP_X * scale.X,
        SHARED_CONFIG.ITEMS_DISPLAY_STEP_Y * scale.Y
    )

    --[[
    Positions passed to RenderCollectionItem are the item sprite origin.
    Center items grid inside the current MyStuff frame.
    This lets compact pause-menu mods change both position and scale
    without an ID-specific method.
    ]]
    local gridCenterSpan = Vector(
        (SHARED_CONFIG.ITEMS_DISPLAY_COLUMN_COUNT - 1) * itemStep.X,
        (SHARED_CONFIG.ITEMS_DISPLAY_ROW_COUNT - 1) * itemStep.Y
    )
    local itemOrigin = frameInfo.TopLeft
        + Vector(
            (frameInfo.Size.X - gridCenterSpan.X) * 0.5,
            (frameInfo.Size.Y - gridCenterSpan.Y) * 0.5
        )
        + self.Settings:GetOffset()
        + CONFIG.AUTO_LAYOUT_ITEMS_DISPLAY_OFFSET
    local legacyOrigin = self:GetPauseMenuAnchor()
        + CONFIG.FIXED_FIRST_ITEM_DISPLAY_OFFSET

    return {
        Mode = "auto",
        ItemOrigin = itemOrigin,
        ItemScale = scale,
        ItemStep = itemStep,
        OverlayDelta = itemOrigin - legacyOrigin,
        MyStuffFrameInfo = frameInfo,
    }
end

function Renderer:GetLayout(pauseBody)
    local frameInfo = self:GetMyStuffFrameInfo(pauseBody)

    if self.Settings:GetLayoutMode() == "auto"
        and frameInfo
    then
        local autoLayout = self:GetAutoLayout(frameInfo)

        if autoLayout then
            return autoLayout
        end
    end

    return self:GetFixedLayout(frameInfo)
end

function Renderer:IsStandardPauseLayout(pauseBody)
    local frameInfo = self:GetMyStuffFrameInfo(pauseBody)

    if not frameInfo then
        return false
    end

    return math.abs(frameInfo.Scale.X - 1) < 0.01
        and math.abs(frameInfo.Scale.Y - 1) < 0.01
        and math.abs(frameInfo.Width - 128) < 1
        and math.abs(frameInfo.Height - 128) < 1
end

function Renderer:GetItemSlotPosition(
    index,
    firstColumnNumber,
    layout
)
    local columnNumber = (index - 1)
        // SHARED_CONFIG.ITEMS_DISPLAY_ROW_COUNT + 1
    local rowNumber = (index - 1)
        % SHARED_CONFIG.ITEMS_DISPLAY_ROW_COUNT

    return layout.ItemOrigin
        + Vector(
            (columnNumber - firstColumnNumber) * layout.ItemStep.X,
            rowNumber * layout.ItemStep.Y
        ) + CONFIG.PAUSE_MENU_LAYER_OFFSET
end

function Renderer:GetDescription(itemID, isTrinket)
    local entityType = PickupVariant.PICKUP_COLLECTIBLE
    if isTrinket then
        entityType = PickupVariant.PICKUP_TRINKET
    end
    local success, result = pcall(
        self.EID.getDescriptionObj,
        self.EID,
        EntityType.ENTITY_PICKUP,
        entityType,
        itemID,
        nil,
        true
    )

    if not success then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to get EID description: "
            .. "for collectible "
            .. tostring(result)
            .. "\n"
        )

        return nil
    end

    return result
end

function Renderer:ReplacePauseMenuSpritesheet(pauseBody)
    if self.PauseMenuSpritesheetReplaced
        or not pauseBody
    then
        return
    end

    --[[
    The replacement texture was authored against the vanilla 128x128 MyStuff layout.
    Do not impose it on Mini Pause Menu, Unintrusive or other non-standard pause screens,
    those mods should keep their own paper art.
    ]]
    if not self:IsStandardPauseLayout(pauseBody) then
        return
    end

    for _, layer in ipairs(pauseBody:GetAllLayers()) do
        if tostring(layer:GetName()) == "Paper" then
            local layerID = layer:GetLayerID()
            self.OriginalPauseMenuSpritesheet = layer:GetSpritesheetPath()
            pauseBody:ReplaceSpritesheet(
                layerID,
                "gfx/ui/pausescreen_msd4r.png"
            )
            pauseBody:LoadGraphics()
            self.PauseMenuSpritesheetReplaced = true

            return
        end
    end
end

function Renderer:HideLayer(spriteName, layer)
    if not layer
        or not layer:IsVisible()
    then
        return
    end

    layer:SetVisible(false)
    table.insert(self.HiddenPauseMenuLayers, {
        SpriteName = spriteName,
        LayerID = layer:GetLayerID()
    })
end

function Renderer:HideOriginalMyStuffPage(pauseBody)
    if not pauseBody then
        return
    end

    local targetLayers = {
        MyStuff = true,
        StuffArrow1 = true,
        StuffArrow2 = true,
    }
    for _, layer in ipairs(pauseBody:GetAllLayers()) do
        local layerName = tostring(layer:GetName())
        if targetLayers[layerName] then
            layer:SetVisible(false)
        end
    end

    local myStuffSprite = PauseMenu.GetMyStuffSprite()
    if myStuffSprite then
        for _, layer in ipairs(myStuffSprite:GetAllLayers()) do
            local layerName = tostring(layer:GetName())
            if layerName == "Items" then
                layer:SetVisible(false)
            end
        end
    end
end

function Renderer:HidePartialPauseMenu(pauseBody, pauseStats)
    if pauseStats then
        for _, layer in ipairs(pauseStats:GetAllLayers()) do
            self:HideLayer("PauseStats", layer)
        end
    end

    if pauseBody then
        local targetLayers = {
            Cursor = true,
            Blood = true
        }
        self:ReplacePauseMenuSpritesheet(pauseBody)

        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            local layerName = tostring(layer:GetName())

            if targetLayers[layerName] then
                self:HideLayer("PauseMenu", layer)
            end
        end
    end
end

function Renderer:RestorePauseMenuSpritesheet()
    if not self.PauseMenuSpritesheetReplaced then
        return
    end

    local pauseBody = PauseMenu.GetSprite()

    if pauseBody and self.OriginalPauseMenuSpritesheet then
        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            if tostring(layer:GetName()) == "Paper" then
                pauseBody:ReplaceSpritesheet(
                    layer:GetLayerID(),
                    self.OriginalPauseMenuSpritesheet
                )
                pauseBody:LoadGraphics()
                break
            end
        end
    end

    self.PauseMenuSpritesheetReplaced = false
    self.OriginalPauseMenuSpritesheet = nil
end

function Renderer:RestorePauseMenuLayers()
    local pauseMenuSprite = PauseMenu.GetSprite()
    local pauseStatsSprite = PauseMenu.GetStatsSprite()

    for _, layerInfo in ipairs(self.HiddenPauseMenuLayers) do
        local sprite = nil

        if layerInfo.SpriteName == "PauseMenu" then
            sprite = pauseMenuSprite
        elseif layerInfo.SpriteName == "PauseStats" then
            sprite = pauseStatsSprite
        end

        if sprite then
            local layer = sprite:GetLayer(layerInfo.LayerID)

            if layer then
                layer:SetVisible(true)
            end
        end
    end

    self.HiddenPauseMenuLayers = {}

    local myStuffSprite = PauseMenu.GetMyStuffSprite()
    if myStuffSprite then
        for _, layer in ipairs(myStuffSprite:GetAllLayers()) do
            local layerName = tostring(layer:GetName())
            if layerName == "Items" then
                layer:SetVisible(true)
            end
        end
    end
end

function Renderer:RenderPauseMenuLayer(
    pauseBody,
    layerName
)
    if not pauseBody then
        return
    end

    local layer = pauseBody:GetLayer(layerName)
    if not layer then
        return
    end

    local layerID = layer:GetLayerID()
    local frame = pauseBody:GetLayerFrameData(layerID)
    if not frame or not frame:IsVisible() then
        return
    end

    -- Layer should be visible before being rendered
    local isVisible = layer:IsVisible()
    layer:SetVisible(true)
    pauseBody:RenderLayer(
        layerID,
        self:GetPauseMenuAnchor() + CONFIG.PAUSE_MENU_LAYER_OFFSET
    )
    layer:SetVisible(isVisible)
end

function Renderer:RenderItemIcon(
    itemID,
    position,
    scale
)
    local outlineMode = self.Settings:GetOutlineMode()
    local outlineColor = self.Settings:GetOutlineColor()
    local outlineOffsets = nil
    if outlineMode == "thin" then
        outlineOffsets = CONFIG.THIN_OUTLINE_OFFSETS
    elseif outlineMode == "full" then
        outlineOffsets = CONFIG.FULL_OUTLINE_OFFSETS
    end

    if outlineOffsets then
        for _, offset in ipairs(outlineOffsets) do
            Isaac.RenderCollectionItem(
                itemID,
                position + offset,
                scale,
                outlineColor
            )
        end
    end

    Isaac.RenderCollectionItem(
        itemID,
        position,
        scale,
        self.Settings:GetIconColor()
    )
end

function Renderer:GetModTrinketSprite(trinketID)
    trinketID = trinketID & TrinketType.TRINKET_ID_MASK
    if self.ModTrinketSprites[trinketID] then
        return self.ModTrinketSprites[trinketID]
    end

    local modTrinketConfig = Isaac.GetItemConfig():GetTrinket(trinketID)
    if not modTrinketConfig then
        return nil
    end

    local modTrinketSprite = Sprite()
    modTrinketSprite:Load("gfx/ui/mod_trinket_icon_msd4r.anm2", false)
    modTrinketSprite:ReplaceSpritesheet(0, modTrinketConfig.GfxFileName)
    modTrinketSprite:LoadGraphics()
    modTrinketSprite:SetFrame("Idle", 0)
    self.ModTrinketSprites[trinketID] = modTrinketSprite

    return modTrinketSprite
end

function Renderer:RenderModTrinketIcon(
    trinketID,
    position,
    scale
)
    local modTrinketSprite = self:GetModTrinketSprite(trinketID)
    if not modTrinketSprite then
        return
    end

    modTrinketSprite.Scale = scale * 0.5
    modTrinketSprite.Color = self.Settings:GetIconColor()
    modTrinketSprite:Render(position)
end

function Renderer:RenderTrinketIcon(
    trinketID,
    position,
    scale
)
    trinketID = trinketID & TrinketType.TRINKET_ID_MASK
    if trinketID >= TrinketType.NUM_TRINKETS then
        self:RenderModTrinketIcon(trinketID, position, scale)
        return
    end

    self.TrinketSprite:SetFrame("Diary", trinketID - 1)

    local layer = self.TrinketSprite:GetLayer("Trinkets")
    if not layer then
        return
    end

    local outlineMode = self.Settings:GetOutlineMode()
    local outlineOffsets = nil
    if outlineMode == "thin" then
        outlineOffsets = CONFIG.THIN_OUTLINE_OFFSETS
    elseif outlineMode == "full" then
        outlineOffsets = CONFIG.FULL_OUTLINE_OFFSETS
    end

    self.TrinketSprite.Scale = scale
    self.TrinketSprite.Color = self.Settings:GetOutlineColor()

    if outlineOffsets then
        for _, offset in ipairs(outlineOffsets) do
            self.TrinketSprite:RenderLayer(
                layer:GetLayerID(),
                position + offset
            )
        end
    end

    self.TrinketSprite.Color = self.Settings:GetIconColor()
    self.TrinketSprite:RenderLayer(
        layer:GetLayerID(),
        position
    )
end

function Renderer:RenderStuffArrows(
    pauseBody,
    itemSlots,
    firstColumnNumber
)
    local lastColumnNumber = SHARED_CONFIG:GetColumnNumber(#itemSlots)
    local hasLeftColumn = firstColumnNumber > 1
    local hasRightColumn = firstColumnNumber
        + (SHARED_CONFIG.ITEMS_DISPLAY_COLUMN_COUNT - 1)
        < lastColumnNumber

    if hasLeftColumn then
        self:RenderPauseMenuLayer(
            pauseBody,
            "StuffArrow1"
        )
    end
    if hasRightColumn then
        self:RenderPauseMenuLayer(
            pauseBody,
            "StuffArrow2"
        )
    end
end

function Renderer:RenderAvatar(
    playerType,
    playerCount,
    layout
)
    local avatarLayerID = 0
    if CONFIG.PLAYER_TYPE_TO_AVATAR_LAYER_ID[playerType] then
        avatarLayerID = CONFIG.PLAYER_TYPE_TO_AVATAR_LAYER_ID[playerType]
    end

    self.AvatarSprite:SetFrame(
        "Main",
        avatarLayerID
    )

    local avatarLayer = self.AvatarSprite:GetLayer("Main")
    if not avatarLayer then
        return
    end

    local renderPosition = self:GetPauseMenuAnchor()
        + CONFIG.AVATAR_DISPLAY_OFFSET
        + layout.OverlayDelta
    self.AvatarSprite:RenderLayer(
        avatarLayer:GetLayerID(),
        renderPosition
    )

    if playerCount < 2 then
        return
    end

    local upArrowLayer = self.AvatarSprite:GetLayer("UpArrow")
    local downArrowLayer = self.AvatarSprite:GetLayer("DownArrow")
    if upArrowLayer then
        self.AvatarSprite:RenderLayer(
            upArrowLayer:GetLayerID(),
            renderPosition
        )
    end
    if downArrowLayer then
        self.AvatarSprite:RenderLayer(
            downArrowLayer:GetLayerID(),
            renderPosition
        )
    end
end

function Renderer:RenderEmptyMyStuffPage(pauseBody)
    self:RenderPauseMenuLayer(pauseBody, "MyStuff")
end

function Renderer:RenderMyStuffPage(
    pauseBody,
    playerType,
    itemSlots,
    firstColumnNumber,
    playerCount
)
    local layout = self:GetLayout(pauseBody)
    if layout.MyStuffFrameInfo then
        self:RenderEmptyMyStuffPage(pauseBody)
    end

    if not itemSlots then
        return
    end

    local firstVisibleIndex = (firstColumnNumber - 1)
        * SHARED_CONFIG.ITEMS_DISPLAY_ROW_COUNT + 1
    local maxItemCount = SHARED_CONFIG.ITEMS_DISPLAY_COLUMN_COUNT
        * SHARED_CONFIG.ITEMS_DISPLAY_ROW_COUNT
    local lastVisibleIndex = math.min(
        #itemSlots,
        firstVisibleIndex + maxItemCount - 1
    )

    for i = firstVisibleIndex, lastVisibleIndex do
        local itemSlot = itemSlots[i]

        if itemSlot then
            local position = self:GetItemSlotPosition(
                itemSlot.Index,
                firstColumnNumber,
                layout
            )
            if not itemSlot.IsTrinket then
                self:RenderItemIcon(
                    itemSlot.ID,
                    position,
                    layout.ItemScale
                )
            else
                self:RenderTrinketIcon(
                    itemSlot.ID,
                    position,
                    layout.ItemScale
                )
            end
        end
    end

    if layout.MyStuffFrameInfo then
        self:RenderStuffArrows(
            pauseBody,
            itemSlots,
            firstColumnNumber
        )
    end
    self:RenderAvatar(
        playerType,
        playerCount,
        layout
    )
end

function Renderer:RenderCursor(
    index,
    firstColumnNumber,
    layout
)
    local position = self:GetItemSlotPosition(
        index,
        firstColumnNumber,
        layout
    ) + self:MultiplyVector(
        CONFIG.CURSOR_DISPLAY_OFFSET,
        layout.ItemScale
    )
    local cursorSize = self:MultiplyVector(
        CONFIG.CURSOR_SIZE,
        layout.ItemScale
    )

    Isaac.DrawQuad(
        position - cursorSize,
        position + Vector(
            cursorSize.X,
            -cursorSize.Y
        ),
        position + Vector(
            -cursorSize.X,
            cursorSize.Y
        ),
        position + cursorSize,
        KColor(1, 1, 1, 1),
        1
    )
end

function Renderer:RenderDescription(slot, layout)
    local description = self:GetDescription(slot.ID, slot.IsTrinket)

    if not description then
        return
    end

    local renderPosition = self:GetPauseMenuAnchor()
        + CONFIG.DESCRIPTION_OFFSET
        + layout.OverlayDelta
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

function Renderer:RenderInspect(
    pauseBody,
    slot,
    selectedIndex,
    firstColumnNumber
)
    local layout = self:GetLayout(pauseBody)
    self:RenderCursor(
        selectedIndex,
        firstColumnNumber,
        layout
    )
    self:RenderDescription(
        slot,
        layout
    )
end

function Renderer:DumpLayoutInfo(pauseBody)
    local frameInfo = self:GetMyStuffFrameInfo(pauseBody)
    local layout = self:GetLayout(pauseBody)

    Isaac.ConsoleOutput(
        "[MSD4R] layoutMode="
        .. tostring(layout.Mode)
        .. string.format(
            " itemOrigin=(%.1f, %.1f)"
            .. " itemScale=(%.3f, %.3f)"
            .. " overlayDelta=(%.1f, %.1f)\n",
            layout.ItemOrigin.X,
            layout.ItemOrigin.Y,
            layout.ItemScale.X,
            layout.ItemScale.Y,
            layout.OverlayDelta.X,
            layout.OverlayDelta.Y
        )
    )

    if not frameInfo then
        Isaac.ConsoleOutput(
            "[MSD4R] MyStuff frame is unavailable/hidden; using fixed fallback.\n"
        )
        return
    end

    Isaac.ConsoleOutput(string.format(
        "[MSD4R] MyStuff pos=(%.1f, %.1f)"
        .. " pivot=(%.1f, %.1f)"
        .. " scale=(%.3f, %.3f)"
        .. " size=(%.1f, %.1f)"
        .. " topLeft=(%.1f, %.1f)\n",
        frameInfo.Position.X,
        frameInfo.Position.Y,
        frameInfo.Pivot.X,
        frameInfo.Pivot.Y,
        frameInfo.Scale.X,
        frameInfo.Scale.Y,
        frameInfo.Size.X,
        frameInfo.Size.Y,
        frameInfo.TopLeft.X,
        frameInfo.TopLeft.Y
    ))
end

return Renderer
