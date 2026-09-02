local PauseMenuController = {}

local game = Game()
local CONFIG = {
    PLAYER_INDEX = 0,
    FIRST_ITEM_DISPLAY_OFFSET = Vector(-159, 11),
    ITEM_DISPLAY_ROW_COUNT = 6,
    ITEM_DISPLAY_COLUMN_COUNT = 4,
    ITEM_DISPLAY_STEP_X = 16,
    ITEM_DISPLAY_STEP_Y = 16
}

function PauseMenuController:Initialize(mod, renderer)
    self.Mod = mod
    self.Renderer = renderer
    self.InspectMode = false
    self.SelectedIndex = 1
    self.ItemSlots = {}
    self.HiddenPauseLayers = {}
    self.SavedPauseSelection = 0
    self.InspectBackgroundApplied = false
    self.OriginalPaperSpritesheet = nil
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

    local pauseBody = PauseMenu.GetSprite()

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

function PauseMenuController:GetScreenCenter()
    return self.Mod.EID:getScreenSize() / 2
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
    local pauseMenuSprite = PauseMenu.GetSprite()
    local pauseStatsSprite = PauseMenu.GetStatsSprite()

    for _, layerInfo in ipairs(self.HiddenPauseLayers) do
        if pauseStatsSprite then
            if layerInfo.SpriteName == "pauseMenu" then
                local layer = pauseMenuSprite:GetLayer(layerInfo.LayerID)

                if layer then
                    layer:SetVisible(true)
                end
            end

            if layerInfo.SpriteName == "pauseStats" then
                local layer = pauseStatsSprite:GetLayer(layerInfo.LayerID)

                if layer then
                    layer:SetVisible(true)
                end
            end
        end
    end

    self.HiddenPauseLayers = {}
end

function PauseMenuController:GetControllerIndex()
    local player = Isaac.GetPlayer(CONFIG.PLAYER_INDEX)

    if not player then
        return 0
    end

    return player.ControllerIndex
end

function PauseMenuController:GetItemSlots()
    local player = Isaac.GetPlayer(CONFIG.PLAYER_INDEX)

    if not player then
        return {}
    end

    local slots = {}
    local history = player:GetHistory():SearchCollectibles()
    local screenCenter = self:GetScreenCenter()

    for i = #history, 1, -1 do
        local itemID = history[i]:GetItemID()
        local position = screenCenter + CONFIG.FIRST_ITEM_DISPLAY_OFFSET + Vector(
            (#slots // CONFIG.ITEM_DISPLAY_COLUMN_COUNT) * CONFIG.ITEM_DISPLAY_STEP_X,
            (#slots % CONFIG.ITEM_DISPLAY_COLUMN_COUNT) * CONFIG.ITEM_DISPLAY_STEP_Y
        )

        table.insert(
            slots,
            {
                ID = itemID,
                Position = position
            }
        )
    end

    return slots
end

function PauseMenuController:RefreshItemSlots()
    self.ItemSlots = self:GetItemSlots()

    if #self.ItemSlots == 0 then
        self.SelectedIndex = 1
        return
    end

    self.SelectedIndex = math.max(
        1,
        math.min(
            self.SelectedIndex,
            #self.ItemSlots
        )
    )
end

function PauseMenuController:EnterInspectMode()
    self:RefreshItemSlots()

    if #self.ItemSlots == 0 then
        return
    end

    self.SelectedIndex = 1
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
    self.ItemSlots = {}
end

function PauseMenuController:GetSelectedSlot()
    return self.ItemSlots[self.SelectedIndex]
end

function PauseMenuController:MoveSelection(offset)
    if #self.ItemSlots == 0 then
        return
    end

    local newIndex = self.SelectedIndex + offset

    newIndex = math.max(
        1,
        math.min(
            newIndex,
            #self.ItemSlots
        )
    )

    self.SelectedIndex = newIndex
end

function PauseMenuController:HandlePauseInput()
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
            ButtonAction.ACTION_MENUBACK,
            controller
        )
    then
        self:ExitInspectMode()
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
            self:HideLayer("pauseStats", layer)
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
                self:HideLayer("pauseMenu", layer)
            end
        end
    end
end

function PauseMenuController:OnPostPauseScreenRender(
    pauseBody,
    pauseStats
)
    if game:GetPauseMenuState() ~= PauseMenuStates.OPEN then
        self:ResetInspectMode()
        return
    end

    self:HandlePauseInput()

    if not self.InspectMode then
        return
    end

    local selectedSlot = self:GetSelectedSlot()

    if selectedSlot then
        self.Renderer:Render(selectedSlot)
    end

    PauseMenu.SetSelectedElement(self.SavedPauseSelection)
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
