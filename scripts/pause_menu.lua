local PauseMenuController = {}
local game = Game()
local SHARED_CONFIG = include("scripts/shared_config")
local CONFIG = {
    PLAYER_INDEX = 0,
    FIRST_ITEM_DISPLAY_OFFSET = Vector(-159, 11)
}

function PauseMenuController:Initialize(mod, renderer)
    self.Mod = mod
    self.Renderer = renderer
    self.InspectMode = false
    self.SelectedIndex = 1
    self.FirstColumnNumber = 1
    self.ItemSlots = {}
    self.HiddenPauseLayers = {}
    self.SavedPauseSelection = 0
    self.InspectBackgroundApplied = false
    self.OriginalPaperSpritesheet = nil
end

function PauseMenuController:CalcColumnNumber(index)
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
            self:CalcColumnNumber(#self.ItemSlots)
        )
    )
end

function PauseMenuController:GetScreenCenter()
    return self.Mod.EID:getScreenSize() / 2
end

function PauseMenuController:GetControllerIndex()
    local player = Isaac.GetPlayer(CONFIG.PLAYER_INDEX)

    if not player then
        return 0
    end

    return player.ControllerIndex
end

function PauseMenuController:GetItemCount()
    local player = Isaac.GetPlayer(CONFIG.PLAYER_INDEX)

    if not player then
        return 0
    end

    return #player:GetHistory():SearchCollectibles()
end

function PauseMenuController:GetSelectedSlot()
    return self.ItemSlots[self.SelectedIndex]
end

function PauseMenuController:ApplyInspectBackground(pauseBody)
    if not pauseBody or self.InspectBackgroundApplied then
        return
    end

    for _, layer in ipairs(pauseBody:GetAllLayers()) do
        if tostring(layer:GetName()) == "Paper" then
            local layerID = layer:GetLayerID()

            self.OriginalPaperSpritesheet = layer:GetSpritesheetPath()
            pauseBody:ReplaceSpritesheet(
                layerID,
                "gfx/ui/pausescreen_msd4r.png"
            )
            pauseBody:LoadGraphics()
            self.InspectBackgroundApplied = true

            return
        end
    end
end

function PauseMenuController:RestoreInspectBackground()
    if not self.InspectBackgroundApplied then
        return
    end

    local pauseBody = PauseMenu:GetSprite()

    if pauseBody and self.OriginalPaperSpritesheet then
        for _, layer in ipairs(pauseBody:GetAllLayers()) do
            if tostring(layer:GetName()) == "Paper" then
                pauseBody:ReplaceSpritesheet(
                    layer:GetLayerID(),
                    self.OriginalPaperSpritesheet
                )

                pauseBody:LoadGraphics()
                break
            end
        end
    end

    self.InspectBackgroundApplied = false
    self.OriginalPaperSpritesheet = nil
end

function PauseMenuController:HideLayer(spriteName, layer)
    if not layer then
        return
    end

    layer:SetVisible(false)
    table.insert(self.HiddenPauseLayers, {
        SpriteName = spriteName,
        LayerID = layer:GetLayerID()
    })
end

function PauseMenuController:RestorePauseLayers()
    local pauseMenuSprite = PauseMenu:GetSprite()
    local pauseStatsSprite = PauseMenu:GetStatsSprite()

    for _, layerInfo in ipairs(self.HiddenPauseLayers) do
        if pauseStatsSprite then
            if layerInfo.SpriteName == "PauseMenu" then
                local layer = pauseMenuSprite:GetLayer(layerInfo.LayerID)

                if layer then
                    layer:SetVisible(true)
                end
            elseif layerInfo.SpriteName == "PauseStats" then
                local layer = pauseStatsSprite:GetLayer(layerInfo.LayerID)

                if layer then
                    layer:SetVisible(true)
                end
            end
        end
    end

    self.HiddenPauseLayers = {}
end

function PauseMenuController:GetItemSlots()
    local player = Isaac.GetPlayer(CONFIG.PLAYER_INDEX)

    if not player then
        return {}
    end

    local slots = {}
    local history = player:GetHistory():SearchCollectibles()
    local screenCenter = self:GetScreenCenter()
    local serialNumber = 1

    for i = #history, 1, -1 do
        local itemID = history[i]:GetItemID()
        local position = screenCenter + CONFIG.FIRST_ITEM_DISPLAY_OFFSET + Vector(
            (#slots // SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT) * SHARED_CONFIG.ITEM_DISPLAY_STEP_X,
            (#slots % SHARED_CONFIG.ITEM_DISPLAY_COLUMN_COUNT) * SHARED_CONFIG.ITEM_DISPLAY_STEP_Y
        )

        table.insert(
            slots,
            {
                ID = itemID,
                SerialNumber = serialNumber,
                Position = position
            }
        )
        serialNumber = serialNumber + 1
    end

    return slots
end

function PauseMenuController:RefreshItemSlots()
    self.ItemSlots = self:GetItemSlots()

    if #self.ItemSlots == 0 then
        self.SelectedIndex = 1
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
    self.SavedPauseSelection = PauseMenu.GetSelectedElement()
end

function PauseMenuController:ExitInspectMode()
    self.InspectMode = false

    self:RestoreInspectBackground()
    self:RestorePauseLayers()

    if game:IsPauseMenuOpen() then
        PauseMenu.SetSelectedElement(self.SavedPauseSelection)
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
        and self:CalcColumnNumber(self.SelectedIndex)
        >= self:CalcColumnNumber(#self.ItemSlots)
    then
        self:ExitInspectMode()
        return
    end

    local prevColumnNumber = self:CalcColumnNumber(self.SelectedIndex)
    self.SelectedIndex = self.SelectedIndex + offset
    self:ClampSelectedIndex()
    local curColumnNumber = self:CalcColumnNumber(self.SelectedIndex)

    if prevColumnNumber ~= curColumnNumber then
        local columnNumberDiff = curColumnNumber - self.FirstColumnNumber

        if columnNumberDiff >= SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT then
            self.FirstColumnNumber = curColumnNumber
                - (SHARED_CONFIG.ITEM_DISPLAY_ROW_COUNT - 1)
        elseif columnNumberDiff < 0 then
            self.FirstColumnNumber = curColumnNumber
        end
    end

    self.Renderer:RenderMyStaffPage(self.ItemSlots, self.FirstColumnNumber)
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
    if not self.InspectMode then
        self:RestoreInspectBackground()
        self:RestorePauseLayers()
        return
    end

    if pauseStats then
        for _, layer in ipairs(pauseStats:GetAllLayers()) do
            self:HideLayer("PauseStats", layer)
        end
    end

    if pauseBody then
        self:ApplyInspectBackground(pauseBody)

        local targetLayers = {
            Cursor = true,
            Blood = true,
        }

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
    if pauseBody:GetAnimation() == "Dissapear" then
        return
    end

    self:HandlePauseMenuInput()

    if #self.ItemSlots ~= self:GetItemCount() then
        self:RefreshItemSlots()
    end

    self.Renderer:RenderMyStaffPage(
        self.ItemSlots,
        self.FirstColumnNumber,
        pauseBody
    )

    if self.InspectMode then
        local selectedSlot = self:GetSelectedSlot()

        if selectedSlot then
            self.Renderer:RenderInspect(selectedSlot, self.FirstColumnNumber)
        end

        PauseMenu.SetSelectedElement(self.SavedPauseSelection)
    end
end

function PauseMenuController:OnPostRender()
    if self.InspectMode and not game:IsPauseMenuOpen() then
        self:ResetInspectMode()
    end
end

function PauseMenuController:DumpSpriteInfo(
    name,
    sprite
)
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

    for _, layer in ipairs(
        sprite:GetAllLayers()
    ) do
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

function PauseMenuController:OnExecuteCommand(
    command,
    params
)
    if command ~= "msd4r_dump" then
        return
    end

    if not game:IsPauseMenuOpen() then
        Isaac.ConsoleOutput(
            "[MSD4R] Open the pause menu first.\n"
        )

        return
    end

    self:DumpSpriteInfo(
        "My Stuff",
        PauseMenu:GetMyStuffSprite()
    )

    self:DumpSpriteInfo(
        "Pause Menu",
        PauseMenu:GetSprite()
    )

    self:DumpSpriteInfo(
        "Pause Stats",
        PauseMenu:GetStatsSprite()
    )
end

return PauseMenuController
