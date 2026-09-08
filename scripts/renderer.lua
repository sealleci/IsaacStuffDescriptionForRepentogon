local Renderer = {}
local SHARED_CONFIG = include("scripts/shared_config")
local CONFIG = {
    MY_STUFF_PAGE_DISPLAY_OFFSET = Vector(49, 0),
    MY_STUFF_ITEM_DISPLAY_OFFSET = Vector(84, -19),
    AVATAR_DISPLAY_OFFSET = Vector(-120, 96),
    FIRST_ITEM_DISPLAY_OFFSET = Vector(-159, 11),
    CURSOR_SIZE = Vector(8, 8),
    CURSOR_DISPLAY_OFFSET = Vector(0, 1),
    DESCRIPTION_OFFSET = Vector(0, -65),
    DESCRIPTION_WIDTH = 140,
    DESCRIPTION_SCALE = 1.0,
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
    }
}

function Renderer:Initialize(mod)
    self.Mod = mod
    self.EID = mod.EID
    self.HiddenPauseMenuLayers = {}
    self.PauseMenuSpritesheetReplaced = false
    self.OriginalPauseMenuSpritesheet = nil

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

    self.AvatarSprite = Sprite()
    self.AvatarSprite:Load(
        "gfx/ui/coop menu_msd4r.anm2",
        true
    )
    self.AvatarSprite:Play("Main", true)
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
end

function Renderer:ReplacePauseMenuSpritesheet(pauseBody)
    if self.PauseMenuSpritesheetReplaced then
        return
    end

    if not pauseBody then
        pauseBody = PauseMenu.GetSprite()

        if not pauseBody then
            return
        end
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

function Renderer:HideOriginalMyStuffPage(pauseBody)
    if pauseBody then
        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            local layerName = tostring(layer:GetName())

            if layerName == "MyStuff" then
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
    local lastColumnNumber = SHARED_CONFIG:GetColumnNumber(#itemSlots)
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

function Renderer:RenderAvatar(playerType, playerCount)
    local avatarLayerId = 0
    if CONFIG.PLAYER_TYPE_TO_AVATAR_LAYER_ID[playerType] then
        avatarLayerId = CONFIG.PLAYER_TYPE_TO_AVATAR_LAYER_ID[playerType]
    end

    self.AvatarSprite:SetFrame("Main", avatarLayerId)
    local avatarLayer = self.AvatarSprite:GetLayer("Main")

    if not avatarLayer then
        return
    end

    self.AvatarSprite:RenderLayer(
        avatarLayer:GetLayerID(),
        self:GetPauseMenuAnchor() + CONFIG.AVATAR_DISPLAY_OFFSET
    )

    if playerCount < 2 then
        return
    end

    local upArrowLayer = self.AvatarSprite:GetLayer("UpArrow")
    local downArrowLayer = self.AvatarSprite:GetLayer("DownArrow")
    if upArrowLayer then
        self.AvatarSprite:RenderLayer(
            upArrowLayer:GetLayerID(),
            self:GetPauseMenuAnchor() + CONFIG.AVATAR_DISPLAY_OFFSET
        )
    end
    if downArrowLayer then
        self.AvatarSprite:RenderLayer(
            downArrowLayer:GetLayerID(),
            self:GetPauseMenuAnchor() + CONFIG.AVATAR_DISPLAY_OFFSET
        )
    end
end

function Renderer:RenderMyStuffPage(
    playerType,
    itemSlots,
    firstColumnNumber,
    playerCount
)
    self:RenderEmptyMyStuffPage()

    if not itemSlots then
        return
    end

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
    self:RenderAvatar(playerType, playerCount)
end

function Renderer:RenderCursor(index, firstColumnNumber)
    local position = self:GetItemSlotPosition(index, firstColumnNumber) + CONFIG.CURSOR_DISPLAY_OFFSET

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
