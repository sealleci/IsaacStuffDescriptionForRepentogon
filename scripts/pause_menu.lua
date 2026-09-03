local PauseMenuController = {}
local game = Game()
local SHARED_CONFIG = include("scripts/shared_config")
local CONFIG = {
    PLAYER_INDEX = 0
}

function PauseMenuController:Initialize(mod, renderer)
    self.Mod = mod
    self.Renderer = renderer
    self.ItemSlots = {}
    self.InspectMode = false
    self.PauseSessionActive = false
    self.SelectedIndex = 1
    self.FirstColumnNumber = 1
    self.HiddenPauseMenuLayers = {}
    self.SavedPauseMenuSelection = 0
    self.PauseMenuSpritesheetReplaced = false
    self.OriginalPauseMenuSpritesheet = nil
end

function PauseMenuController:GetColumnNumber(index)
    if index <= 0 then
        return 1
    end

    return ((index - 1) // SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT) + 1
end

function PauseMenuController:ClampSelectedIndex()
    self.SelectedIndex = math.max(
        1,
        math.min(
            self.SelectedIndex,
            #self.ItemSlots
        )
    )
end

function PauseMenuController:ClampFirstColumnNumber()
    self.FirstColumnNumber = math.max(
        1,
        math.min(
            self.FirstColumnNumber,
            self:GetColumnNumber(#self.ItemSlots)
        )
    )
end

function PauseMenuController:GetControllerIndex()
    local player = Isaac.GetPlayer(CONFIG.PLAYER_INDEX)

    if not player then
        return 0
    end

    return player.ControllerIndex
end

function PauseMenuController:GetSelectedSlot()
    return self.ItemSlots[self.SelectedIndex]
end

function PauseMenuController:ReplacePauseMenuSpritesheet(pauseBody)
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

function PauseMenuController:RestorePauseMenuSpritesheet()
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

function PauseMenuController:HideLayer(spriteName, layer)
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

function PauseMenuController:RestorePauseMenuLayers()
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

function PauseMenuController:GetItemSlots()
    local player = Isaac.GetPlayer(CONFIG.PLAYER_INDEX)

    if not player then
        return {}
    end

    local slots = {}
    local history = player:GetHistory():SearchCollectibles()
    local itemIndex = 1

    for i = #history, 1, -1 do
        table.insert(
            slots,
            {
                ID = history[i]:GetItemID(),
                Index = itemIndex
            }
        )
        itemIndex = itemIndex + 1
    end

    return slots
end

function PauseMenuController:RefreshItemSlots()
    self.ItemSlots = self:GetItemSlots()

    if #self.ItemSlots == 0 then
        self.SelectedIndex = 1
        self.FirstColumnNumber = 1
        return
    end

    self:ClampSelectedIndex()
    self:ClampFirstColumnNumber()
end

function PauseMenuController:EnterInspectMode()
    self:RefreshItemSlots()

    if #self.ItemSlots == 0 then
        return
    end

    self:ClampSelectedIndex()
    self.InspectMode = true
    self.SavedPauseMenuSelection = PauseMenu.GetSelectedElement()
end

function PauseMenuController:ExitInspectMode()
    self.InspectMode = false
    self:RestorePauseMenuSpritesheet()
    self:RestorePauseMenuLayers()

    if game:IsPauseMenuOpen()
        and PauseMenu.GetState() ~= PauseMenuStates.OPTIONS
    then
        PauseMenu.SetSelectedElement(self.SavedPauseMenuSelection)
    end
end

function PauseMenuController:ResetInspectMode()
    self.InspectMode = false
    self.SelectedIndex = 1
    self.FirstColumnNumber = 1
    self.ItemSlots = {}
end

function PauseMenuController:MoveSelection(offset)
    if #self.ItemSlots == 0 then
        return
    end

    if self.SelectedIndex + offset < 1 then
        return
    end

    if self.SelectedIndex + offset > #self.ItemSlots
        and self:GetColumnNumber(self.SelectedIndex)
        >= self:GetColumnNumber(#self.ItemSlots)
    then
        self:ExitInspectMode()
        return
    end

    local prevColumnNumber = self:GetColumnNumber(self.SelectedIndex)
    self.SelectedIndex = self.SelectedIndex + offset
    self:ClampSelectedIndex()
    local curColumnNumber = self:GetColumnNumber(self.SelectedIndex)

    if prevColumnNumber ~= curColumnNumber then
        local columnNumberDiff = curColumnNumber - self.FirstColumnNumber

        if columnNumberDiff >= SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT then
            self.FirstColumnNumber = curColumnNumber
                - (SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT - 1)
        elseif columnNumberDiff < 0 then
            self.FirstColumnNumber = curColumnNumber
        end
    end
end

function PauseMenuController:HandlePauseMenuInput()
    local controller = self:GetControllerIndex()

    if not self.InspectMode then
        if Input.IsActionTriggered(
                ButtonAction.ACTION_MENULEFT,
                controller
            )
        then
            self:EnterInspectMode()
        end

        return
    end

    if Input.IsActionTriggered(
            ButtonAction.ACTION_MENUUP,
            controller
        )
    then
        self:MoveSelection(-1)
    elseif Input.IsActionTriggered(
            ButtonAction.ACTION_MENUDOWN,
            controller
        )
    then
        self:MoveSelection(1)
    elseif Input.IsActionTriggered(
            ButtonAction.ACTION_MENULEFT,
            controller
        )
    then
        self:MoveSelection(-SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT)
    elseif Input.IsActionTriggered(
            ButtonAction.ACTION_MENURIGHT,
            controller
        )
    then
        self:MoveSelection(SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT)
    end
end

function PauseMenuController:OnPrePauseScreenRender(
    pauseBody,
    pauseStats
)
    if not game:IsPauseMenuOpen()
        or PauseMenu.GetState() == PauseMenuStates.OPTIONS
    then
        self:ExitInspectMode()

        return
    end

    local animation = pauseBody:GetAnimation()

    if animation == "Appear"
        or animation == "Dissapear"
    then
        self.Renderer:SetMyStuffPageFrame(
            animation,
            pauseBody:GetFrame()
        )
    else
        self.Renderer:SetMyStuffPageIdle()
    end

    if pauseBody then
        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            local layerName = tostring(layer:GetName())

            if layerName == "MyStuff" then
                layer:SetVisible(false)
            end
        end
    end

    if not self.InspectMode then
        return
    end

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

function PauseMenuController:OnPostPauseScreenRender(
    pauseBody,
    pauseStats
)
    if not game:IsPauseMenuOpen()
        or PauseMenu.GetState() == PauseMenuStates.OPTIONS
        or not pauseBody
    then
        return
    end

    local animation = pauseBody:GetAnimation()

    if animation == "Appear"
        or animation == "Dissapear"
    then
        self.Renderer:RenderEmptyMyStuffPage()
        return
    end

    if not self.PauseSessionActive then
        self.PauseSessionActive = true
        self:RefreshItemSlots()
    end

    self:HandlePauseMenuInput()
    self.Renderer:RenderMyStuffPage(
        self.ItemSlots,
        self.FirstColumnNumber
    )

    if self.InspectMode then
        local selectedSlot = self:GetSelectedSlot()

        if selectedSlot then
            self.Renderer:RenderInspect(
                selectedSlot,
                self.SelectedIndex,
                self.FirstColumnNumber
            )
        end

        PauseMenu.SetSelectedElement(self.SavedPauseMenuSelection)
    end
end

function PauseMenuController:OnPostRender()
    if game:IsPauseMenuOpen() then
        return
    end

    if self.InspectMode then
        self:ExitInspectMode()
        self:ResetInspectMode()
    end

    self.PauseSessionActive = false
end

function PauseMenuController:DumpSpriteInfo(name, sprite)
    if not sprite then
        Isaac.ConsoleOutput(
            "[MSD4R] "
            .. name
            .. ": nil\n"
        )

        return
    end

    Isaac.ConsoleOutput(
        "\n[MSD4R] ===== "
        .. name
        .. " =====\n"
    )

    Isaac.ConsoleOutput(string.format(
        "[MSD4R] spriteOffset=(%.1f, %.1f) "
        .. "spriteScale=(%.3f, %.3f) "
        .. "animation='%s' "
        .. "frame=%d\n",
        sprite.Offset.X,
        sprite.Offset.Y,
        sprite.Scale.X,
        sprite.Scale.Y,
        tostring(sprite:GetAnimation()),
        sprite:GetFrame()
    ))

    for _, layer in ipairs(sprite:GetAllLayers()) do
        local layerID = layer:GetLayerID()
        local layerPos = layer:GetPos()
        local frame = sprite:GetLayerFrameData(layerID)
        local frameX = 0
        local frameY = 0
        local frameVisible = false

        if frame then
            local framePos = frame:GetPos()
            frameX = framePos.X
            frameY = framePos.Y
            frameVisible = frame:IsVisible()
        end

        Isaac.ConsoleOutput(string.format(
            "[MSD4R] "
            .. "id=%d "
            .. "name='%s' "
            .. "visible=%s "
            .. "layerPos=(%.1f, %.1f) "
            .. "framePos=(%.1f, %.1f) "
            .. "frameVisible=%s "
            .. "sheet='%s'\n",
            layerID,
            tostring(layer:GetName()),
            tostring(layer:IsVisible()),
            layerPos.X,
            layerPos.Y,
            frameX,
            frameY,
            tostring(frameVisible),
            tostring(layer:GetSpritesheetPath())
        ))
    end
end

function PauseMenuController:OnExecuteCommand(command, params)
    if command ~= "msd4r_dump" then
        return
    end

    if not game:IsPauseMenuOpen() then
        Isaac.ConsoleOutput(
            "[MSD4R] Open the pause menu first.\n"
        )

        return
    end

    local screenCenter = Vector(
        math.floor(Isaac.GetScreenWidth() * 0.5),
        math.floor(Isaac.GetScreenHeight() * 0.5)
    )
    local extraOffset = self.Renderer:GetPauseMenuExtraOffset()
    local pauseAnchor = self.Renderer:GetPauseMenuAnchor()
    local eidCenter = self.Mod.EID:getScreenSize() / 2

    Isaac.ConsoleOutput(string.format(
        "\n[MSD4R] screen=(%.1f, %.1f) "
        .. "screenCenter=(%.1f, %.1f) "
        .. "pauseExtra=(%.1f, %.1f) "
        .. "pauseAnchor=(%.1f, %.1f) "
        .. "eidCenter=(%.1f, %.1f)\n",
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

    self:DumpSpriteInfo(
        "My Stuff",
        PauseMenu.GetMyStuffSprite()
    )

    self:DumpSpriteInfo(
        "Pause Menu",
        PauseMenu.GetSprite()
    )

    self:DumpSpriteInfo(
        "Pause Stats",
        PauseMenu.GetStatsSprite()
    )
end

return PauseMenuController
