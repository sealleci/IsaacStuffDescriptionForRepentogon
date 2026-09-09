local PauseMenuController = {}
local game = Game()
local SHARED_CONFIG = include("scripts/shared_config")

function PauseMenuController:Initialize(mod, renderer)
    self.Mod = mod
    self.Renderer = renderer
    self.PlayerIndex = 0
    self.PlayerInputIndex = 0
    self.AllPlayersItemSlots = {}
    self.InspectMode = false
    self.PauseSessionActive = false
    self.SelectedItemSlotIndex = 1
    self.FirstColumnNumber = 1
    self.SavedPauseMenuSelection = 0
end

function PauseMenuController:ClampSelectedIndex()
    self.SelectedItemSlotIndex = math.max(
        1,
        math.min(
            self.SelectedItemSlotIndex,
            #(self.AllPlayersItemSlots[self.PlayerIndex] or {})
        )
    )
end

function PauseMenuController:ClampFirstColumnNumber()
    self.FirstColumnNumber = math.max(
        1,
        math.min(
            self.FirstColumnNumber,
            SHARED_CONFIG:GetColumnNumber(#(self.AllPlayersItemSlots[self.PlayerIndex] or {}))
        )
    )
end

function PauseMenuController:GetPlayerType()
    local player = Isaac.GetPlayer(self.PlayerIndex)

    if not player then
        return 0
    end

    return player:GetPlayerType()
end

function PauseMenuController:GetControllerIndex()
    local player = Isaac.GetPlayer(self.PlayerInputIndex)

    if not player then
        return 0
    end

    return player.ControllerIndex
end

function PauseMenuController:GetSelectedItemSlot()
    local itemSlots = self.AllPlayersItemSlots[self.PlayerIndex]

    if itemSlots then
        return itemSlots[self.SelectedItemSlotIndex]
    else
        return nil
    end
end

function PauseMenuController:GetSinglePlayerItemSlots(playerIndex)
    local itemSlots = {}
    local player = Isaac.GetPlayer(playerIndex)

    if not player then
        return {}
    end

    local history = player:GetHistory():GetCollectiblesHistory()
    local itemIndex = 1

    for i = #history, 1, -1 do
        local historyItem = history[i]
        table.insert(
            itemSlots,
            {
                ID = historyItem:GetItemID(),
                IsTrinket = historyItem:IsTrinket(),
                Index = itemIndex
            }
        )
        itemIndex = itemIndex + 1
    end

    return itemSlots
end

function PauseMenuController:GetAllPlayersItemSlots()
    local allPlayersItemSlots = {}

    for playerIndex = 0, game:GetNumPlayers() - 1 do
        allPlayersItemSlots[playerIndex] = self:GetSinglePlayerItemSlots(playerIndex)
    end

    return allPlayersItemSlots
end

function PauseMenuController:GetCurPlayerItemSlots()
    return self.AllPlayersItemSlots[self.PlayerIndex] or {}
end

function PauseMenuController:GetPlayerCountWithItems()
    local count = 0

    for _, itemSlots in pairs(self.AllPlayersItemSlots) do
        if #(itemSlots or {}) > 0 then
            count = count + 1
        end
    end

    return count
end

function PauseMenuController:RefreshItemSlots()
    self.AllPlayersItemSlots = self:GetAllPlayersItemSlots()

    if #(self.AllPlayersItemSlots[self.PlayerIndex] or {}) == 0 then
        self.SelectedItemSlotIndex = 1
        self.FirstColumnNumber = 1
        return
    end

    self:ClampSelectedIndex()
    self:ClampFirstColumnNumber()
end

function PauseMenuController:PickPlayerWithItems()
    if #(self.AllPlayersItemSlots[self.PlayerIndex] or {}) < 1 then
        local availablePlayerIndices = {}
        for playerIndex, _ in pairs(self.AllPlayersItemSlots) do
            table.insert(availablePlayerIndices, playerIndex)
        end
        table.sort(availablePlayerIndices)

        for _, playerIndex in ipairs(availablePlayerIndices) do
            if playerIndex ~= self.PlayerIndex
                and self.AllPlayersItemSlots[playerIndex]
                and #self.AllPlayersItemSlots[playerIndex] > 0
            then
                self.PlayerIndex = playerIndex
                self.SelectedItemSlotIndex = 1
                self.FirstColumnNumber = 1
                break
            end
        end
    end
end

function PauseMenuController:EnterInspectMode()
    self:RefreshItemSlots()
    self:PickPlayerWithItems()

    if #(self.AllPlayersItemSlots[self.PlayerIndex] or {}) < 1 then
        return
    end

    self.SavedPauseMenuSelection = PauseMenu.GetSelectedElement()
    self.InspectMode = true
end

function PauseMenuController:ExitInspectMode()
    self.InspectMode = false
    self.Renderer:RestorePauseMenuSpritesheet()
    self.Renderer:RestorePauseMenuLayers()

    if game:IsPauseMenuOpen()
        and PauseMenu.GetState() ~= PauseMenuStates.OPTIONS
    then
        PauseMenu.SetSelectedElement(self.SavedPauseMenuSelection)
    end
end

function PauseMenuController:SwitchPlayerItemsDisplay(offset)
    local direction = offset > 0 and 1 or -1
    local availableIndices = {}
    for _playerIndex in pairs(self.AllPlayersItemSlots) do
        table.insert(availableIndices, _playerIndex)
    end
    table.sort(availableIndices)

    local availableCount = #availableIndices
    if availableCount < 1 then
        self.SelectedItemSlotIndex = 1
        self.FirstColumnNumber = 1
        return
    end

    local curAvailablePosition = 1
    for i = 1, #availableIndices do
        if availableIndices[i] == self.PlayerIndex then
            curAvailablePosition = i
            break
        end
    end

    --[[
    Normalize the next index after applying the offset
    so that it stays within range
    ]]
    local nextAvailablePosition = curAvailablePosition + offset
    if nextAvailablePosition < 1 then
        nextAvailablePosition = nextAvailablePosition
            + math.ceil(
                math.abs(nextAvailablePosition - 1)
                / availableCount
            )
            * availableCount
    end
    nextAvailablePosition = (
        (nextAvailablePosition - 1)
        % availableCount
    ) + 1

    --[[
    Treat the list as circular:
    traverse it once starting from the initial index
    without returning to the initial index
    ]]
    for _ = 1, availableCount do
        local playerIndex = availableIndices[nextAvailablePosition]
        local itemSlots = self.AllPlayersItemSlots[playerIndex]

        if playerIndex ~= self.PlayerIndex
            and itemSlots
            and #itemSlots > 0
        then
            self.PlayerIndex = playerIndex
            self.SelectedItemSlotIndex = 1
            self.FirstColumnNumber = 1
            self:RefreshItemSlots()

            return
        end

        nextAvailablePosition = (
            (nextAvailablePosition - 1 + direction)
            % availableCount
        ) + 1
    end
end

function PauseMenuController:MoveCursor(offset, horizontal)
    local itemSlotsLength = #(self.AllPlayersItemSlots[self.PlayerIndex] or {})
    if itemSlotsLength < 1 then
        self:ExitInspectMode()
        return
    end

    if horizontal then
        offset = offset * SHARED_CONFIG.ITEMS_DISPLAY_ROW_COUNT
    end

    local nextIndex = self.SelectedItemSlotIndex + offset
    local prevColumnNumber = SHARED_CONFIG:GetColumnNumber(self.SelectedItemSlotIndex)
    local curColumnNumber = SHARED_CONFIG:GetColumnNumber(nextIndex)
    local maxColumnNumber = SHARED_CONFIG:GetColumnNumber(itemSlotsLength)

    -- Exit inspect mode when the cursor reaches the right edge
    if horizontal
        and nextIndex > itemSlotsLength
        and prevColumnNumber >= maxColumnNumber
    then
        self:ExitInspectMode()
        return
    end

    --[[
    Switch to another character's item list
    when the cursor reaches the top or bottom edge
    ]]
    if not horizontal
        and (
            nextIndex > itemSlotsLength
            or nextIndex < 1
            or prevColumnNumber ~= curColumnNumber
        )
    then
        local switchOffset = offset > 0 and 1 or -1
        self:SwitchPlayerItemsDisplay(switchOffset)

        return
    end

    -- Do nothing when the cursor reaches the left edge
    if nextIndex < 1 then
        return
    end

    self.SelectedItemSlotIndex = nextIndex
    self:ClampSelectedIndex()

    if horizontal and prevColumnNumber ~= curColumnNumber then
        local columnNumberDiff = curColumnNumber - self.FirstColumnNumber

        if columnNumberDiff >= SHARED_CONFIG.ITEMS_DISPLAY_COLUMN_COUNT then
            self.FirstColumnNumber = curColumnNumber
                - (SHARED_CONFIG.ITEMS_DISPLAY_COLUMN_COUNT - 1)
        elseif columnNumberDiff < 0 then
            self.FirstColumnNumber = curColumnNumber
        end
        self:ClampFirstColumnNumber()
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
        self:MoveCursor(-1, false)
    elseif Input.IsActionTriggered(
            ButtonAction.ACTION_MENUDOWN,
            controller
        )
    then
        self:MoveCursor(1, false)
    elseif Input.IsActionTriggered(
            ButtonAction.ACTION_MENULEFT,
            controller
        )
    then
        self:MoveCursor(-1, true)
    elseif Input.IsActionTriggered(
            ButtonAction.ACTION_MENURIGHT,
            controller
        )
    then
        self:MoveCursor(1, true)
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

    self.Renderer:HideOriginalMyStuffPage(pauseBody)

    if not self.InspectMode then
        return
    end

    self.Renderer:HidePartialPauseMenu(pauseBody, pauseStats)
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
        self.Renderer:RenderEmptyMyStuffPage(pauseBody)
        return
    end

    if not self.PauseSessionActive then
        self.PauseSessionActive = true
        self:RefreshItemSlots()
        self:PickPlayerWithItems()
    end

    self:HandlePauseMenuInput()
    self.Renderer:RenderMyStuffPage(
        pauseBody,
        self:GetPlayerType(),
        self:GetCurPlayerItemSlots(),
        self.FirstColumnNumber,
        self:GetPlayerCountWithItems()
    )

    if self.InspectMode then
        local selectedSlot = self:GetSelectedItemSlot()

        if selectedSlot then
            self.Renderer:RenderInspect(
                pauseBody,
                selectedSlot,
                self.SelectedItemSlotIndex,
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
    self.Renderer:DumpLayoutInfo(
        PauseMenu.GetSprite()
    )
end

return PauseMenuController
