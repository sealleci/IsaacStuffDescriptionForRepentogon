local Renderer = {}
local SHARED_CONFIG = include("scripts/shared_config")
local CONFIG = {
    PAUSE_MENU_RENDER_ORIGIN_OFFSET = Vector(48, 0),
    PIVOT_AT_ITEMS_DISPLAY_ROW_NUMBER = 1 - (1 / 16),
    PIVOT_AT_ITEMS_DISPLAY_COLUMN_NUMBER = 2 + (5 / 16),

    CURSOR_SIZE = Vector(8, 8),
    CURSOR_DISPLAY_OFFSET = Vector(0, 1),

    DESCRIPTION_WIDTH = 140,
    DESCRIPTION_SCALE = 1.0,
    DESCRIPTION_DISPLAY_OFFSET = Vector(184, -36),

    FIXED_MY_STUFF_PAGE_TOP_LEFT = Vector(48, 108),
    FIXED_MY_STUFF_PAGE_PIVOT = Vector(60, 60),
    FIXED_MY_STUFF_PAGE_SIZE = Vector(128, 128),

    --[[
    Large ANM2 positions such as (-500, -500) are commonly used to
    hide a layer off-screen. Treat them as an opt-out from auto layout.
    ]]
    MY_STUFF_FRAME_POSITION_LIMIT = 400,

    --[[
    A scale outside this range is almost an animation transition, a hidden layer,
    or an unsupported layout. Item rendering only happens on pause menu's idle frame,
    but these guards make the fallback explicit.
    ]]
    AUTO_LAYOUT_MIN_SCALE = 0.1,
    AUTO_LAYOUT_MAX_SCALE = 3.0,

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
    },

    PLAYER_TYPE_TO_AVATAR_LAYER_ID = {
        [PlayerType.PLAYER_ISAAC] = 0,
        [PlayerType.PLAYER_MAGDALENE] = 1,
        [PlayerType.PLAYER_CAIN] = 2,
        [PlayerType.PLAYER_JUDAS] = 3,
        [PlayerType.PLAYER_BLACKJUDAS] = 3,
        [PlayerType.PLAYER_BLUEBABY] = 4,
        [PlayerType.PLAYER_EVE] = 5,
        [PlayerType.PLAYER_SAMSON] = 6,
        [PlayerType.PLAYER_AZAZEL] = 7,
        [PlayerType.PLAYER_LAZARUS] = 8,
        [PlayerType.PLAYER_LAZARUS2] = 8,
        [PlayerType.PLAYER_EDEN] = 9,
        [PlayerType.PLAYER_THELOST] = 10,
        [PlayerType.PLAYER_LILITH] = 11,
        [PlayerType.PLAYER_KEEPER] = 12,
        [PlayerType.PLAYER_APOLLYON] = 13,
        [PlayerType.PLAYER_THEFORGOTTEN] = 14,
        [PlayerType.PLAYER_THESOUL] = 14,
        [PlayerType.PLAYER_BETHANY] = 15,
        [PlayerType.PLAYER_JACOB] = 16,
        [PlayerType.PLAYER_ESAU] = 17,
        [PlayerType.PLAYER_ISAAC_B] = 18,
        [PlayerType.PLAYER_MAGDALENE_B] = 19,
        [PlayerType.PLAYER_CAIN_B] = 20,
        [PlayerType.PLAYER_JUDAS_B] = 21,
        [PlayerType.PLAYER_BLUEBABY_B] = 22,
        [PlayerType.PLAYER_EVE_B] = 23,
        [PlayerType.PLAYER_SAMSON_B] = 24,
        [PlayerType.PLAYER_AZAZEL_B] = 25,
        [PlayerType.PLAYER_LAZARUS_B] = 26,
        [PlayerType.PLAYER_LAZARUS2_B] = 26,
        [PlayerType.PLAYER_EDEN_B] = 27,
        [PlayerType.PLAYER_THELOST_B] = 28,
        [PlayerType.PLAYER_LILITH_B] = 29,
        [PlayerType.PLAYER_KEEPER_B] = 30,
        [PlayerType.PLAYER_APOLLYON_B] = 31,
        [PlayerType.PLAYER_THEFORGOTTEN_B] = 32,
        [PlayerType.PLAYER_THESOUL_B] = 32,
        [PlayerType.PLAYER_BETHANY_B] = 33,
        [PlayerType.PLAYER_JACOB_B] = 34,
        [PlayerType.PLAYER_JACOB2_B] = 34,
    },
    PLACEHOLDER_AVATAR_LAYER_ID = 35
}

function Renderer:Initialize(mod)
    self.Mod = mod
    self.EID = mod.EID
    self.Settings = mod.Settings
    self.HiddenPauseMenuLayers = {}
    self.PauseMenuSpritesheetReplaced = false
    self.ReplacedPauseMenuLayerName = nil
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

    local x = math.abs(scale.X)
    local y = math.abs(scale.Y)

    if x > 4 then
        x = x / 100
    end
    if y > 4 then
        y = y / 100
    end

    return Vector(x, y)
end

function Renderer:GetPauseMenuOrigin()
    return Vector(
        math.floor(Isaac.GetScreenWidth() * 0.5),
        math.floor(Isaac.GetScreenHeight() * 0.5)
    ) + CONFIG.PAUSE_MENU_RENDER_ORIGIN_OFFSET
end

function Renderer:GetPauseMenuExtraOffset()
    return Vector(
        math.floor(Isaac.GetScreenWidth() / 10 - 48),
        0
    )
end

function Renderer:GetPauseMenuAnchor()
    return self:GetPauseMenuOrigin() + self:GetPauseMenuExtraOffset()
end

function Renderer:GetLayerFrame(animation, layerID)
    local animationLayer = animation:GetLayer(layerID)
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

function Renderer:GetRawFrameInfo(pauseBody, layerName)
    if not pauseBody then
        return nil
    end

    local layer = pauseBody:GetLayer(layerName)
    if not layer then
        return nil
    end

    local frame = self:GetLayerFrame(
        pauseBody:GetAnimationData("Idle"),
        layer:GetLayerID()
    )
    if not frame then
        return nil
    end

    local position = frame:GetPos()
    local pivot = frame:GetPivot()
    local rawScale = frame:GetScale()
    if not position
        or not rawScale
        or not pivot
        or math.abs(position.X) >= CONFIG.MY_STUFF_FRAME_POSITION_LIMIT
        or math.abs(position.Y) >= CONFIG.MY_STUFF_FRAME_POSITION_LIMIT
    then
        return nil
    end

    local scale = self:NormalizeFrameScale(rawScale)
    if scale.X < CONFIG.AUTO_LAYOUT_MIN_SCALE
        or scale.Y < CONFIG.AUTO_LAYOUT_MIN_SCALE
        or scale.X > CONFIG.AUTO_LAYOUT_MAX_SCALE
        or scale.Y > CONFIG.AUTO_LAYOUT_MAX_SCALE
    then
        return nil
    end

    return {
        Layer = layer,
        Frame = frame,
        Position = position,
        Pivot = pivot,
        Scale = scale,
        Width = frame:GetWidth(),
        Height = frame:GetHeight(),
        Size = Vector(
            frame:GetWidth() * scale.X,
            frame:GetHeight() * scale.Y
        ),
        TopLeft = position - Vector(
            pivot.X * scale.X,
            pivot.Y * scale.Y
        )
    }
end

function Renderer:GetFrameInfo(pauseBody, layerName)
    local frameInfo = self:GetRawFrameInfo(pauseBody, layerName)
    if not frameInfo then
        return nil
    end

    frameInfo.TopLeft = frameInfo.TopLeft + self:GetPauseMenuAnchor()

    return frameInfo
end

function Renderer:IsClassicMyStuffLayout(pauseBody)
    local myStuffFrameInfo = self:GetFrameInfo(pauseBody, "MyStuff")
    if not myStuffFrameInfo then
        return false
    end

    return math.abs(myStuffFrameInfo.Scale.X - 1) < 0.01
        and math.abs(myStuffFrameInfo.Scale.Y - 1) < 0.01
        and math.abs(myStuffFrameInfo.Width - 128) < 1
        and math.abs(myStuffFrameInfo.Height - 128) < 1
        and math.abs(myStuffFrameInfo.Position.X) < CONFIG.MY_STUFF_FRAME_POSITION_LIMIT
        and math.abs(myStuffFrameInfo.Position.Y) < CONFIG.MY_STUFF_FRAME_POSITION_LIMIT
end

function Renderer:GetFixedLayout()
    local offset = self.Settings:GetOffset()
    local itemsDisplayOffset = Vector(
        math.floor(SHARED_CONFIG.ITEMS_DISPLAY_STEP_X * CONFIG.PIVOT_AT_ITEMS_DISPLAY_COLUMN_NUMBER + 0.5),
        math.floor(SHARED_CONFIG.ITEMS_DISPLAY_STEP_Y * CONFIG.PIVOT_AT_ITEMS_DISPLAY_ROW_NUMBER + 0.5)
    )
    local itemOrigin = CONFIG.FIXED_MY_STUFF_PAGE_TOP_LEFT
        + CONFIG.FIXED_MY_STUFF_PAGE_PIVOT
        - itemsDisplayOffset
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
        MyStuffFrameInfo = {
            Layer = nil,
            Frame = nil,
            Position = Vector(0, 0),
            Pivot = CONFIG.FIXED_MY_STUFF_PAGE_PIVOT,
            Scale = Vector(1, 1),
            Width = CONFIG.FIXED_MY_STUFF_PAGE_SIZE.X,
            Height = CONFIG.FIXED_MY_STUFF_PAGE_SIZE.Y,
            Size = CONFIG.FIXED_MY_STUFF_PAGE_SIZE,
            TopLeft = CONFIG.FIXED_MY_STUFF_PAGE_TOP_LEFT
        }
    }
end

function Renderer:GetAutoLayout(frameInfo)
    if not frameInfo then
        return nil
    end

    local pivot = self:MultiplyVector(
        frameInfo.Pivot,
        frameInfo.Scale
    )
    local itemStep = Vector(
        SHARED_CONFIG.ITEMS_DISPLAY_STEP_X * frameInfo.Scale.X,
        SHARED_CONFIG.ITEMS_DISPLAY_STEP_Y * frameInfo.Scale.Y
    )

    -- Pivot is at the 2nd row, 3rd column of item list.
    local itemsDisplayOffset = Vector(
        math.floor(itemStep.X * CONFIG.PIVOT_AT_ITEMS_DISPLAY_COLUMN_NUMBER + 0.5),
        math.floor(itemStep.Y * CONFIG.PIVOT_AT_ITEMS_DISPLAY_ROW_NUMBER + 0.5)
    )

    -- Offset relative to the bottom-center origin.
    local itemOrigin = frameInfo.TopLeft
        + pivot
        - itemsDisplayOffset
        + self.Settings:GetOffset()

    return {
        Mode = "auto",
        ItemOrigin = itemOrigin,
        ItemScale = frameInfo.Scale,
        ItemStep = itemStep,
        MyStuffFrameInfo = frameInfo,
    }
end

function Renderer:GetLayout(pauseBody)
    local myStuffFrameInfo = self:GetFrameInfo(pauseBody, "MyStuff")

    if myStuffFrameInfo then
        local autoLayout = self:GetAutoLayout(myStuffFrameInfo)

        if autoLayout then
            return autoLayout
        end
    end

    return self:GetFixedLayout()
end

function Renderer:ReplacePauseMenuSpritesheet(pauseBody)
    function ReplaceSpritesheet(layerName, imagePath)
        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            if layer:GetName() == layerName then
                local layerID = layer:GetLayerID()
                self.ReplacedPauseMenuLayerName = layerName
                self.OriginalPauseMenuSpritesheet = layer:GetSpritesheetPath()
                pauseBody:ReplaceSpritesheet(layerID, imagePath)
                pauseBody:LoadGraphics()
                self.PauseMenuSpritesheetReplaced = true

                return
            end
        end
    end

    if self.PauseMenuSpritesheetReplaced
        or not pauseBody
    then
        return
    end

    if not self:IsClassicMyStuffLayout(pauseBody) then
        ReplaceSpritesheet(
            "PaperFrame",
            "gfx/ui/pausescreen_mini_msd4r.png"
        )

        return
    end

    ReplaceSpritesheet(
        "Paper",
        "gfx/ui/pausescreen_msd4r.png"
    )
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
        if targetLayers[layer:GetName()] then
            layer:SetVisible(false)
        end
    end

    local myStuffSprite = PauseMenu.GetMyStuffSprite()
    if myStuffSprite then
        for _, layer in ipairs(myStuffSprite:GetAllLayers()) do
            if layer:GetName() == "Items" then
                layer:SetVisible(false)
            end
        end
    end
end

function Renderer:HidePartialPauseMenu(pauseBody, pauseStats)
    if pauseStats
        and self:IsClassicMyStuffLayout(pauseBody)
    then
        for _, layer in ipairs(pauseStats:GetAllLayers()) do
            self:HideLayer("PauseStats", layer)
        end
    end

    if pauseBody then
        local targetLayers = {
            Cursor = true,
            Blood = self:IsClassicMyStuffLayout(pauseBody),
        }

        self:ReplacePauseMenuSpritesheet(pauseBody)

        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            if targetLayers[layer:GetName()] then
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

    if pauseBody
        and self.ReplacedPauseMenuLayerName
        and self.OriginalPauseMenuSpritesheet
    then
        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            if layer:GetName() == self.ReplacedPauseMenuLayerName then
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
    self.ReplacedPauseMenuLayerName = nil
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
            if layer:GetName() == "Items" then
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
        self:GetPauseMenuAnchor()
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
    modTrinketSprite.Rotation = 0
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

function Renderer:RenderModAvatar(
    playerType,
    renderPosition,
    scale
)
    local modPlayerConfig = EntityConfig.GetPlayer(playerType)
    if not modPlayerConfig then
        return false
    end

    local modAvatarSprite = modPlayerConfig:GetModdedCoopMenuSprite()
    if not modAvatarSprite then
        return false
    end

    local previousScale = modAvatarSprite.Scale
    modAvatarSprite:SetFrame(modPlayerConfig:GetName(), 0)
    modAvatarSprite.Scale = scale
    modAvatarSprite.Rotation = 0

    modAvatarSprite:Render(renderPosition)
    modAvatarSprite.Scale = previousScale

    return true
end

function Renderer:RenderAvatar(
    playerType,
    playerCount,
    layout
)
    local renderPosition = layout.MyStuffFrameInfo.TopLeft
        + self:MultiplyVector(
            layout.MyStuffFrameInfo.Pivot,
            layout.ItemScale
        )
        + Vector(
            0,
            layout.ItemStep.Y * (layout.Mode == "fixed" and 3.5 or 4)
        )
        + self.Settings:GetOffset()

    local avatarLayerID = CONFIG.PLAYER_TYPE_TO_AVATAR_LAYER_ID[playerType]
    local modAvatarRendered = false
    if not avatarLayerID then
        modAvatarRendered = self:RenderModAvatar(
            playerType,
            renderPosition,
            layout.ItemScale
        )
        if not modAvatarRendered then
            avatarLayerID = CONFIG.PLACEHOLDER_AVATAR_LAYER_ID
        end
    end
    if avatarLayerID
        and not modAvatarRendered
    then
        self.AvatarSprite:SetFrame("Main", avatarLayerID)
        self.AvatarSprite.Scale = layout.ItemScale

        local avatarLayer = self.AvatarSprite:GetLayer("Main")
        if not avatarLayer then
            return
        end

        self.AvatarSprite:RenderLayer(
            avatarLayer:GetLayerID(),
            renderPosition
        )
    end

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

function Renderer:GetDescription(itemID, isTrinket)
    local entityType = PickupVariant.PICKUP_COLLECTIBLE
    if isTrinket then
        entityType = PickupVariant.PICKUP_TRINKET
    end

    local successful, result = pcall(
        self.EID.getDescriptionObj,
        self.EID,
        EntityType.ENTITY_PICKUP,
        entityType,
        itemID,
        nil,
        true
    )

    if not successful then
        Isaac.ConsoleOutput(string.format(
            "[MSD4R] Failed to get EID description: %s\n",
            tostring(result)
        ))

        return nil
    end

    return result
end

function Renderer:RenderDescription(slot, layout)
    local description = self:GetDescription(slot.ID, slot.IsTrinket)

    if not description then
        return
    end

    local prevScale = self.EID.Scale
    local prevTextboxWidth = self.EID.Config["TextboxWidth"]
    local prevInsideItemReminder = self.EID.InsideItemReminder
    self.EID.Scale = CONFIG.DESCRIPTION_SCALE
    self.EID.Config["TextboxWidth"] = CONFIG.DESCRIPTION_WIDTH
    self.EID.InsideItemReminder = true

    local renderPosition = self:GetPauseMenuAnchor()
    if layout
        and layout.MyStuffFrameInfo
    then
        if math.abs(Isaac.GetScreenWidth()
                - (layout.MyStuffFrameInfo.TopLeft.X
                    + layout.MyStuffFrameInfo.Size.X))
            >= CONFIG.DESCRIPTION_WIDTH
            + layout.ItemStep.X * 0.5
        then
            renderPosition = layout.MyStuffFrameInfo.TopLeft
                + self:MultiplyVector(
                    CONFIG.DESCRIPTION_DISPLAY_OFFSET,
                    layout.ItemScale
                )

            if renderPosition.Y < 0 then
                renderPosition.Y = layout.MyStuffFrameInfo.TopLeft.Y
                    + layout.MyStuffFrameInfo.Pivot.Y
                    * layout.ItemScale.Y
            end
        else
            renderPosition = layout.MyStuffFrameInfo.TopLeft
                + Vector(0, layout.MyStuffFrameInfo.Size.Y)
                + Vector(0, layout.ItemStep.X)
        end
    end
    renderPosition = renderPosition + self.Settings:GetOffset()

    local successful, err = pcall(function()
        local textScale = Vector(
            self.EID.Scale,
            self.EID.Scale
        )

        if description.Name
            and description.Name ~= ""
        then
            local nameColor = self.EID:getNameColor()

            self.EID:renderString(
                description.Name,
                renderPosition,
                textScale,
                nameColor
            )
            renderPosition.Y = renderPosition.Y
                + self.EID.lineHeight
                * self.EID.Scale
        end

        if description.Description
            and description.Description ~= ""
        then
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

    if not successful then
        Isaac.ConsoleOutput(string.format(
            "[MSD4R] EID rendering error: %s\n",
            tostring(err)
        ))
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

    if layout.Mode == "fixed" then
        self.Settings:Set("IconBrightness", 20)
    end

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
    self:RenderDescription(slot, layout)
end

function Renderer:DrawPivot(position)
    local size = Vector(2, 2)

    Isaac.DrawQuad(
        position - size,
        position + Vector(size.X, -size.Y),
        position + Vector(-size.X, size.Y),
        position + size,
        KColor(0, 1, 0, 1),
        1
    )
end

function Renderer:DrawMyStuffBounds(pauseBody)
    local myStuffFrameInfo = self:GetFrameInfo(pauseBody, "MyStuff")
    if not myStuffFrameInfo then
        return
    end

    local topLeft = myStuffFrameInfo.TopLeft
    local bottomRight = topLeft + myStuffFrameInfo.Size
    local topRight = Vector(
        bottomRight.X,
        topLeft.Y
    )
    local bottomLeft = Vector(
        topLeft.X,
        bottomRight.Y
    )
    local thickness = 1
    local color = KColor(1, 0, 0, 1)

    -- Top edge
    Isaac.DrawQuad(
        topLeft,
        topRight,
        topLeft + Vector(0, thickness),
        topRight + Vector(0, thickness),
        color,
        1
    )
    -- Bottom edge
    Isaac.DrawQuad(
        bottomLeft - Vector(0, thickness),
        bottomRight - Vector(0, thickness),
        bottomLeft,
        bottomRight,
        color,
        1
    )
    -- Left edge
    Isaac.DrawQuad(
        topLeft,
        topLeft + Vector(thickness, 0),
        bottomLeft,
        bottomLeft + Vector(thickness, 0),
        color,
        1
    )
    -- Right edge
    Isaac.DrawQuad(
        topRight - Vector(thickness, 0),
        topRight,
        bottomRight - Vector(thickness, 0),
        bottomRight,
        color,
        1
    )

    self:DrawPivot(myStuffFrameInfo.TopLeft + self:MultiplyVector(
        myStuffFrameInfo.Pivot,
        myStuffFrameInfo.Scale
    ))
end

function Renderer:DumpSpriteInfo(name, sprite)
    if not sprite then
        Isaac.ConsoleOutput(string.format(
            "[MSD4R] Sprite %s: nil\n",
            name
        ))

        return
    end

    Isaac.ConsoleOutput(string.format(
        "\n[MSD4R] ===== Sprite %s =====\n",
        name
    ))

    Isaac.ConsoleOutput(string.format(
        "[MSD4R] Sprite info:\n"
        .. "        spriteOffset=(%.1f, %.1f)\n"
        .. "        spriteScale=(%.3f, %.3f)\n"
        .. "        animation=%s\n"
        .. "        frame=%d\n",
        sprite.Offset.X,
        sprite.Offset.Y,
        sprite.Scale.X,
        sprite.Scale.Y,
        sprite:GetAnimation(),
        sprite:GetFrame()
    ))

    for _, layer in ipairs(sprite:GetAllLayers()) do
        Isaac.ConsoleOutput(string.format(
            "[MSD4R] Layer %s:\n"
            .. "        id=%d\n"
            .. "        visible=%s\n"
            .. "        sheet=%s\n",
            layer:GetName(),
            layer:GetLayerID(),
            tostring(layer:IsVisible()),
            layer:GetSpritesheetPath()
        ))
    end
end

function Renderer:DumpLayoutInfo(pauseBody)
    if not pauseBody then
        Isaac.ConsoleOutput("[MSD4R] Layout: nil\n")
        return
    end

    local layout = self:GetLayout(pauseBody)
    Isaac.ConsoleOutput(string.format(
        "\n[MSD4R] ===== Layout =====\n"
        .. "        mode=%s\n"
        .. "        itemOrigin=(%.1f, %.1f)\n"
        .. "        itemScale=(%.3f, %.3f)\n",
        layout.Mode,
        layout.ItemOrigin.X,
        layout.ItemOrigin.Y,
        layout.ItemScale.X,
        layout.ItemScale.Y
    ))
end

function Renderer:DumpMyStuffFrameInfo(pauseBody, layerName)
    local myStuffFrameInfo = self:GetFrameInfo(pauseBody, layerName)
    if not myStuffFrameInfo then
        Isaac.ConsoleOutput(string.format("[MSD4R] %s frame: nil\n", layerName))
        return
    end

    Isaac.ConsoleOutput(string.format(
        "\n[MSD4R] ===== %s frame =====\n"
        .. "        pos=(%.1f, %.1f)\n"
        .. "        pivot=(%.1f, %.1f)\n"
        .. "        scale=(%.3f, %.3f)\n"
        .. "        widthHeight=(%.1f, %.1f)\n"
        .. "        size=(%.1f, %.1f)\n"
        .. "        topLeft=(%.1f, %.1f)\n",
        layerName,
        myStuffFrameInfo.Position.X,
        myStuffFrameInfo.Position.Y,
        myStuffFrameInfo.Pivot.X,
        myStuffFrameInfo.Pivot.Y,
        myStuffFrameInfo.Scale.X,
        myStuffFrameInfo.Scale.Y,
        myStuffFrameInfo.Width,
        myStuffFrameInfo.Height,
        myStuffFrameInfo.Size.X,
        myStuffFrameInfo.Size.Y,
        myStuffFrameInfo.TopLeft.X,
        myStuffFrameInfo.TopLeft.Y
    ))
end

function Renderer:DumpScreenInfo()
    local screenCenter = Vector(
        math.floor(Isaac.GetScreenWidth() * 0.5),
        math.floor(Isaac.GetScreenHeight() * 0.5)
    )
    local extraOffset = self:GetPauseMenuExtraOffset()
    local pauseAnchor = self:GetPauseMenuAnchor()
    local eidCenter = self.Mod.EID:getScreenSize() / 2

    Isaac.ConsoleOutput(string.format(
        "\n[MSD4R] ===== Screen =====\n"
        .. "        screenSize=(%.1f, %.1f)\n"
        .. "        screenCenter=(%.1f, %.1f)\n"
        .. "        extraOffset=(%.1f, %.1f)\n"
        .. "        anchor=(%.1f, %.1f)\n"
        .. "        eidCenter=(%.1f, %.1f)\n",
        Isaac.GetScreenWidth(),
        Isaac.GetScreenHeight(),
        screenCenter.X,
        screenCenter.Y,
        extraOffset.X,
        extraOffset.Y,
        pauseAnchor.X,
        pauseAnchor.Y,
        eidCenter.X,
        eidCenter.Y
    ))
end

function Renderer:DumpRenderInfo()
    local pauseBody = PauseMenu.GetSprite()

    self:DumpSpriteInfo(
        "Pause Menu",
        pauseBody
    )
    self:DumpSpriteInfo(
        "Pause Stats",
        PauseMenu.GetStatsSprite()
    )
    self:DumpSpriteInfo(
        "My Stuff",
        PauseMenu.GetMyStuffSprite()
    )
    self:DumpLayoutInfo(pauseBody)
    self:DumpScreenInfo()
    self:DumpMyStuffFrameInfo(pauseBody, "MyStuff")
    self:DumpMyStuffFrameInfo(pauseBody, "Paper")
end

return Renderer
