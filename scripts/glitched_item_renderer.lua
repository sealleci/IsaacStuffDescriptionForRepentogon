local GlitchedItemRenderer = {}
local UI_CONFIG = include("scripts/ui_config")
local Utility = include("scripts/utility")
local CONFIG = {
    ICON_SIZE = 16,
    TILE_SIZE = 2,
    MAX_SOURCE_ITEM_RETRIES = 10,
    MAX_EFFECT_ATTEMPTS = 100,
    MAX_EFFECT_SEARCH_NODES = 192,
    MAX_EFFECT_FINGERPRINT_SCAN = 600,
    LOW3_TO_ACTION_TYPE = {
        [0] = 0,
        [1] = 0,
        [2] = 1,
        [3] = 1,
        [4] = 2,
        [5] = 3,
        [6] = 4,
        [7] = 5
    },
    C000_EFFECT_BUDGET_VALUES = {
        [0] = 0,
        [1] = 1,
        [2] = 2,
        [3] = 2,
        [4] = 3,
        [5] = 3,
        [6] = 3,
        [7] = 4,
        [8] = 4,
        [9] = 4,
        [10] = 6,
        [11] = 6,
        [12] = 6,
        [13] = 12,
        [14] = 300,
        [15] = 600
    }
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

function GlitchedItemRenderer:GetRandomFloat(state)
    return Utility.ConvertToU32(state) / 0x100000000
end

function GlitchedItemRenderer:GetNextRNG(state)
    state = Utility.ConvertToU32(state)
    state = Utility.ConvertToU32(state ~ (state >> 4))
    state = Utility.ConvertToU32(state ~ (state << 3))
    state = Utility.ConvertToU32(state ~ (state >> 27))

    return state
end

function GlitchedItemRenderer:AdvanceRNG(state, count)
    if count < 1 then
        return state
    end

    for _ = 1, count do
        state = self:GetNextRNG(state)
    end

    return state
end

function GlitchedItemRenderer:GetEffectNextRNG(state)
    state = Utility.ConvertToU32(state)
    state = Utility.ConvertToU32(state ~ (state >> 13))
    state = Utility.ConvertToU32(state ~ (state << 3))
    state = Utility.ConvertToU32(state ~ (state >> 17))

    return state
end

function GlitchedItemRenderer:GetEffectRandomInt(state, maxValue)
    state = self:GetEffectNextRNG(state)

    if not maxValue or maxValue <= 0 then
        return state, 0
    end

    return state, state % maxValue
end

function GlitchedItemRenderer:GetEffectRandomFloat(state)
    state = self:GetEffectNextRNG(state)

    return state, Utility.ConvertToU32(state) / 0x100000000
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

function GlitchedItemRenderer:GetProceduralItem(itemID)
    if not itemID
        or itemID >= 0
        or not ProceduralItemManager
        or not ProceduralItemManager.GetProceduralItem
        or not ProceduralItemManager.GetProceduralItemCount
    then
        return nil
    end

    local index = -itemID - 1
    if index < 0 then
        return nil
    end

    local itemCount = ProceduralItemManager.GetProceduralItemCount()
    if index >= itemCount
    then
        return nil
    end

    local successful, proceduralItem = pcall(
        ProceduralItemManager.GetProceduralItem,
        index
    )
    if not successful then
        return nil
    end

    return proceduralItem
end

function GlitchedItemRenderer:GetProceduralSnapshot(itemID)
    local proceduralItem = self:GetProceduralItem(itemID)
    if not proceduralItem then
        return nil
    end

    local snapshot = {
        ProceduralItem = proceduralItem,
        Effects = {},
        NonZeroStatCount = 0,
        ItemType = 0,
        MaxCharges = nil,
        MaxCooldown = nil
    }

    local getItemConfigSuccessfully, itemConfig = pcall(
        proceduralItem.GetItem,
        proceduralItem
    )
    if getItemConfigSuccessfully
        and itemConfig
    then
        snapshot.ItemConfig = itemConfig
        snapshot.ItemType = itemConfig.Type
        snapshot.MaxCharges = itemConfig.MaxCharges
        snapshot.MaxCooldown = itemConfig.MaxCooldown
    end

    local statGetters = {
        "GetDamage",
        "GetFireDelay",
        "GetLuck",
        "GetRange",
        "GetShotSpeed",
        "GetSpeed"
    }
    for _, getterName in ipairs(statGetters) do
        local getter = proceduralItem[getterName]
        if getter then
            local invokeGetterSuccessfully, value = pcall(
                getter,
                proceduralItem
            )
            if invokeGetterSuccessfully
                and value
                and math.abs(tonumber(value) or 0) > 0.000001
            then
                snapshot.NonZeroStatCount = snapshot.NonZeroStatCount + 1
            end
        end
    end

    local itemEffectCount = 0
    if proceduralItem.GetEffectCount then
        itemEffectCount = math.max(
            0,
            math.floor(proceduralItem:GetEffectCount())
        )
    end

    local snapshotEffectIndex = 1
    for itemEffectIndex = 0, itemEffectCount - 1 do
        local getEffectSuccessfully, effect = pcall(
            proceduralItem.GetEffect,
            proceduralItem,
            itemEffectIndex
        )
        if getEffectSuccessfully
            and effect
        then
            local conditionType = nil
            local actionType = nil
            local score = nil

            if effect.GetConditionType then
                conditionType = effect:GetConditionType()
            end
            if effect.GetActionType then
                actionType = effect:GetActionType()
            end
            if effect.GetScore then
                score = effect:GetScore()
            end

            snapshot.Effects[snapshotEffectIndex] = {
                ConditionType = conditionType,
                ActionType = actionType,
                Score = score
            }
            snapshotEffectIndex = snapshotEffectIndex + 1
        end
    end

    return snapshot
end

function GlitchedItemRenderer:ReplayGlitchedTextPhase(state)
    for _ = 1, 2 do
        -- Three rolls determine the target string length.
        state = self:AdvanceRNG(state, 3)

        -- One roll with 1/80 chance to extend the generated string.
        state = self:GetNextRNG(state)
        if state % 0x50 == 0 then
            state = self:GetNextRNG(state)
        end

        --[[
        3 rolls for selecting the source ItemConfig,
        creating the secondary text RNG seed,
        and the main state used by the next pass.
        ]]
        state = self:AdvanceRNG(state, 3)
    end

    return state
end

function GlitchedItemRenderer:ReplayPreEffectPhase(
    state,
    proceduralSeed,
    snapshot
)
    --[[
    One roll initializes stat switch,
    then 0 to 4 more bounded rolls depending on (state % 14),
    where state cases in [6..13] consume no extra roll.
    ]]
    state = self:GetNextRNG(state)
    local statCase = state % 14
    local switchExtraRolls = {
        [0] = 4,
        [1] = 1,
        [2] = 1,
        [3] = 2,
        [4] = 2,
        [5] = 4
    }
    state = self:AdvanceRNG(
        state,
        switchExtraRolls[statCase] or 0
    )

    -- One roll selects the branch, one bounded roll selects the item.
    state = self:AdvanceRNG(state, 2)

    -- 7 rolls selects independent stat-modifier with 1/40 chance.
    for _ = 1, 7 do
        state = self:GetNextRNG(state)
        if state % 0x28 == 0 then
            state = self:GetNextRNG(state)
        end
    end

    -- One bounded roll decides whether the 6 procedural stat fields are generated.
    state = self:GetNextRNG(state)

    if snapshot
        and snapshot.NonZeroStatCount > 0
    then
        -- Fisher-Yates-like permutation of the 6 stat slots.
        state = self:AdvanceRNG(state, 5)

        -- Fill all 6 stat slots using 2 random floats each with 1/40 chance.
        state = self:GetNextRNG(state)
        if state % 0x28 == 0 then
            state = self:AdvanceRNG(state, 12)
        else
            -- First selected stat is always written.
            state = self:GetNextRNG(state)
            local firstRoll = self:GetRandomFloat(state)

            -- The second stat has a 2-stage branch.
            if firstRoll < 0.25 then
                state = self:GetNextRNG(state)
            else
                state = self:GetNextRNG(state)
                if (state & 7) == 0 then
                    state = self:GetNextRNG(state)
                end
            end

            -- One bounded roll optionally enables a third stat.
            state = self:GetNextRNG(state)
            if snapshot.NonZeroStatCount >= 3 then
                state = self:GetNextRNG(state)
            end
        end
    end

    local effectBudget
    local hasC000 = (
        (Utility.ConvertToU32(proceduralSeed) & 0xC000) == 0xC000
    )
    if not hasC000 then
        local value1
        local value2
        local value3

        state = self:GetNextRNG(state)
        value1 = self:GetRandomFloat(state)
        state = self:GetNextRNG(state)
        value2 = self:GetRandomFloat(state)
        state = self:GetNextRNG(state)
        value3 = self:GetRandomFloat(state)

        effectBudget = value1 + value2 + value3
    else
        state = self:GetNextRNG(state)
        local budgetBase = CONFIG.C000_EFFECT_BUDGET_VALUES[state & 0xF] or 0

        if budgetBase < 13 then
            state = self:GetNextRNG(state)
            local value = self:GetRandomFloat(state) * budgetBase
            effectBudget = value + value + 1
        else
            state = self:GetNextRNG(state)
            local value4 = self:GetRandomFloat(state)
            state = self:GetNextRNG(state)
            local value5 = self:GetRandomFloat(state)

            effectBudget = value4 + value5
        end
    end

    return state, effectBudget
end

function GlitchedItemRenderer:GetEffectCandidateScore(
    seed,
    conditionType,
    actionType
)
    if conditionType == 6 then
        return nil
    end

    local state = Utility.ConvertToU32(seed)
    local score = nil

    if actionType == 1 then
        local itemConfig = Isaac.GetItemConfig()
        local itemCount = Utility.GetItemCount()
        score = 0

        for _ = 1, CONFIG.MAX_SOURCE_ITEM_RETRIES do
            local itemID
            state, itemID = self:GetEffectRandomInt(state, itemCount)

            if itemConfig:GetCollectible(itemID) then
                score = 1
                break
            end
        end
    elseif actionType == 3 then
        local value1
        local value2
        local value3
        local value4
        local value5

        state, value1 = self:GetEffectRandomFloat(state)
        state, value2 = self:GetEffectRandomFloat(state)
        state, value3 = self:GetEffectRandomFloat(state)
        state, value4 = self:GetEffectRandomFloat(state)
        state, value5 = self:GetEffectRandomFloat(state)

        -- radius
        local _ = value1 * value2 * value3 * 8000 + 30
        local damage = math.max((value4 - 0.2) * value5 * 80, 0)
        score = damage * 0.1

        local rollFlag
        state, rollFlag = self:GetEffectRandomInt(state, 3)
        if rollFlag == 0 then
            local divisor = damage < 5 and 20 or 100

            for _ = 1, 128 do
                state = self:GetEffectNextRNG(state)
                if state % divisor == 0 then
                    score = score + 0.4
                end
            end
        end
    elseif actionType == 5 then
        score = 1
    else
        return nil
    end

    if conditionType == 1 then
        score = score * 10
    end

    return score
end

function GlitchedItemRenderer:GetEffectCandidate(
    state,
    itemType,
    acceptedEffectCount
)
    local conditionType

    if itemType == 3 then
        conditionType = 0
    else
        state = self:GetNextRNG(state)
        conditionType = (state % 7) + 1
    end

    if acceptedEffectCount > 0 then
        state = self:GetNextRNG(state)
        if (state & 3) ~= 0 then
            conditionType = 8
        end
    end

    state = self:GetNextRNG(state)
    local actionType = CONFIG.LOW3_TO_ACTION_TYPE[state & 7]

    -- One seed handed to helper function FUN_009b5da0.
    state = self:GetNextRNG(state)

    return {
        State = state,
        ConditionType = conditionType,
        ActionType = actionType,
        Score = self:GetEffectCandidateScore(
            state,
            conditionType,
            actionType
        )
    }
end

function GlitchedItemRenderer:ScoresEqualApproximately(left, right)
    if left == nil
        or right == nil
    then
        return true
    end

    local scale = math.max(
        1,
        math.abs(left),
        math.abs(right)
    )

    return math.abs(left - right) <= 0.001 * scale
end

function GlitchedItemRenderer:EffectMatches(candidate, effect)
    if not effect then
        return false
    end

    if effect.ConditionType
        and effect.ConditionType ~= candidate.ConditionType
    then
        return false
    end

    if effect.ActionType
        and effect.ActionType ~= candidate.ActionType
    then
        return false
    end

    if candidate.Score ~= nil
        and effect.Score ~= nil
        and not self:ScoresApproximatelyEqual(
            candidate.Score,
            effect.Score
        )
    then
        return false
    end

    return true
end

function GlitchedItemRenderer:HasGraphicsFingerprint(snapshot)
    if not snapshot then
        return false
    end

    local maxCharges = snapshot.MaxCharges
    local maxCooldown = snapshot.MaxCooldown

    return maxCharges
        and maxCooldown
        and maxCharges >= 1
        and maxCharges <= 2
        and maxCooldown >= 1
        and maxCooldown <= 99
end

function GlitchedItemRenderer:GraphicsFingerprintMatches(state, snapshot)
    if not self:HasGraphicsFingerprint(snapshot) then
        return false
    end

    local nextState = self:GetNextRNG(state)
    if ((nextState & 1) + 1) ~= snapshot.MaxCharges then
        return false
    end

    nextState = self:GetNextRNG(nextState)

    return (nextState % 99) + 1 == snapshot.MaxCooldown
end

function GlitchedItemRenderer:ProcessGraphicsPrelude(state)
    --[[
    2 rolls for ItemConfig +0x7C and +0x7E from decompiled function.
    One roll determines whether the optional voiceover selection runs.
    ]]
    state = self:AdvanceRNG(state, 3)

    if (state & 1) == 0 then
        -- One roll chooses voiceover entry.
        state = self:GetNextRNG(state)
    end

    return state
end

function GlitchedItemRenderer:PruneEffectSearchNodes(nodes)
    table.sort(
        nodes,
        function(left, right)
            if left.Rejections ~= right.Rejections then
                return left.Rejections < right.Rejections
            end

            if left.Attempt ~= right.Attempt then
                return left.Attempt < right.Attempt
            end

            return left.EffectIndex > right.EffectIndex
        end
    )

    while #nodes > CONFIG.MAX_EFFECT_SEARCH_NODES do
        table.remove(nodes)
    end
end

function GlitchedItemRenderer:ReplayEffects(
    initialState,
    effectBudget,
    snapshot
)
    local function appendAcceptedNode(
        target,
        node,
        state,
        score
    )
        target[#target + 1] = {
            State = state,
            Attempt = node.Attempt + 1,
            EffectIndex = node.EffectIndex + 1,
            AcceptedCount = node.AcceptedCount + 1,
            AccumulatedScore = node.AccumulatedScore + score,
            Rejections = node.Rejections
        }
    end

    local function appendRejectedNode(
        target,
        node,
        state
    )
        target[#target + 1] = {
            State = state,
            Attempt = node.Attempt + 1,
            EffectIndex = node.EffectIndex,
            AcceptedCount = node.AcceptedCount,
            AccumulatedScore = node.AccumulatedScore,
            Rejections = node.Rejections + 1
        }
    end

    if not snapshot then
        return nil
    end

    local effects = snapshot.Effects or {}
    local effectCount = #effects
    local nodes = {
        {
            State = initialState,
            Attempt = 0,
            EffectIndex = 1,
            AcceptedCount = 0,
            AccumulatedScore = 0,
            Rejections = 0
        }
    }
    local finishedNodes = {}
    local finishedNodeIndex = 1

    for _ = 1, CONFIG.MAX_EFFECT_ATTEMPTS + 1 do
        if #nodes == 0 then
            break
        end

        local nextNodes = {}
        local nextNodeIndex = 1

        for _, node in ipairs(nodes) do
            local allObservedEffectsAccepted = node.EffectIndex > effectCount
            local finished = (
                node.AccumulatedScore >= effectBudget
                or node.AcceptedCount >= 8
                or node.Attempt >= CONFIG.MAX_EFFECT_ATTEMPTS
            )

            if allObservedEffectsAccepted
                and finished
            then
                finishedNodes[finishedNodeIndex] = node
                finishedNodeIndex = finishedNodeIndex + 1
            elseif node.Attempt < CONFIG.MAX_EFFECT_ATTEMPTS then
                local candidate = self:GetEffectCandidate(
                    node.State,
                    snapshot.ItemType,
                    node.AcceptedCount
                )
                local targetEffect = effects[node.EffectIndex]

                if targetEffect
                    and self:EffectMatches(candidate, targetEffect)
                then
                    local score = targetEffect.Score
                    if score == nil then
                        score = candidate.Score or 0
                    end

                    if node.Attempt == CONFIG.MAX_EFFECT_ATTEMPTS - 1
                        or node.AccumulatedScore + score < effectBudget
                    then
                        appendAcceptedNode(
                            nextNodes,
                            node,
                            candidate.State,
                            score
                        )
                    else
                        --[[
                        Over-budget candidates consume one forced-accept roll,
                        where candidate is accepted with 1/20 chance.
                        ]]
                        local rollState = self:GetNextProceduralRNG(candidate.State)
                        if rollState % 20 == 0 then
                            appendAcceptedNode(
                                nextNodes,
                                node,
                                rollState,
                                score
                            )
                        elseif node.Attempt < CONFIG.MAX_EFFECT_ATTEMPTS - 1 then
                            appendRejectedNode(
                                nextNodes,
                                node,
                                rollState
                            )
                        end
                    end
                elseif node.Attempt < CONFIG.MAX_EFFECT_ATTEMPTS - 1 then
                    local rejectionReached = true

                    if candidate.Score then
                        rejectionReached = (
                            node.AccumulatedScore
                            + candidate.Score
                        ) >= effectBudget
                    end

                    if rejectionReached then
                        local rollState = self:GetNextRNG(candidate.State)
                        if rollState % 20 ~= 0 then
                            appendRejectedNode(nextNodes, node, rollState)
                        end
                    end
                end
            end
        end

        self:PruneEffectSearchNodes(nextNodes)
        nodes = nextNodes
    end

    table.sort(
        finishedNodes,
        function(left, right)
            if left.Rejections ~= right.Rejections then
                return left.Rejections < right.Rejections
            end

            return left.Attempt < right.Attempt
        end
    )

    if self:HasGraphicsFingerprint(snapshot) then
        for _, node in ipairs(finishedNodes) do
            if self:GraphicsFingerprintMatches(
                    node.State,
                    snapshot
                )
            then
                return node.State
            end
        end
    end

    if finishedNodes[1] then
        return finishedNodes[1].State
    end

    return nil
end

function GlitchedItemRenderer:ProcessFallbackEffects(
    initialState,
    snapshot
)
    if not self:HasGraphicsFingerprint(snapshot) then
        return nil
    end

    local effectCount = #(snapshot.Effects or {})
    local minAdvance = 0

    if effectCount > 0 then
        if snapshot.ItemType == 3 then
            minAdvance = 2
                + math.max(0, effectCount - 1) * 3
        else
            minAdvance = 3
                + math.max(0, effectCount - 1) * 4
        end
    end

    local state = initialState
    for advanceCount = 0, CONFIG.MAX_EFFECT_FINGERPRINT_SCAN do
        if advanceCount >= minAdvance
            and self:GraphicsFingerprintMatches(state, snapshot)
        then
            return state
        end

        state = self:GetNextRNG(state)
    end

    return nil
end

function GlitchedItemRenderer:GetGraphicsState(
    itemID,
    proceduralSeed
)
    if not proceduralSeed
        or proceduralSeed == 0
    then
        return nil
    end

    local snapshot = self:GetProceduralSnapshot(itemID)
    local state = self:ReplayGlitchedTextPhase(
        Utility.ConvertToU32(proceduralSeed)
    )

    if not snapshot then
        return Utility.ConvertToU32(proceduralSeed)
    end

    local beforeEffectsState, effectBudget = self:ReplayPreEffectPhase(
        state,
        proceduralSeed,
        snapshot
    )

    local effectEndState = self:ReplayEffects(
        beforeEffectsState,
        effectBudget,
        snapshot
    )

    if not effectEndState then
        effectEndState = self:ProcessFallbackEffects(
            beforeEffectsState,
            snapshot
        )
    end

    if not effectEndState then
        return Utility.ConvertToU32(proceduralSeed)
    end

    return self:ProcessGraphicsPrelude(effectEndState)
end

function GlitchedItemRenderer:GetRandomSourceItemID(state)
    local itemCount = Utility.GetItemCount()
    if itemCount <= 1 then
        return nil, state
    end

    state = self:GetNextRNG(state)

    local itemID = (state % (itemCount - 1)) + 1
    local config = Isaac.GetItemConfig():GetCollectible(itemID)

    if not config
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
        for _ = 1, CONFIG.MAX_SOURCE_ITEM_RETRIES do
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
    local recipe = {}

    --[[
    One roll chooses tile 0 as initial source tile with 80% chance,
    otherwise another roll chooses from tile 0 to tile 63.
    ]]
    local sourceTileIndex = 0
    local sourceImageIndex = 0

    state = self:GetNextRNG(
        Utility.ConvertToU32(state)
    )
    if state % 5 == 0 then
        state = self:GetNextRNG(state)
        sourceTileIndex = state & 0x3F
    end

    -- Initial color branch.
    state = self:GetNextRNG(state)

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

            -- Mutate color with 1/12 chance.
            state = self:GetNextRNG(state)
            if state % 12 == 0 then
                state = self:GetNextRNG(state)
            end

            local changeSource = false
            if sourceTileIndex >= 64 then
                changeSource = true
            else
                state = self:GetNextRNG(state)
                changeSource = state % 12 == 0
            end

            if changeSource then
                sourceImageIndex = (sourceImageIndex + 1) & 3
                sourceTileIndex = destinationTileIndex

                state = self:GetNextRNG(state)
                if state % 20 == 0 then
                    sourceTileIndex = destinationTileIndex + 1
                end

                -- Reset color to zero, then choose [1..3] with 1/5 chance.
                state = self:GetNextRNG(state)
                if state % 5 == 0 then
                    state = self:GetNextRNG(state)
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
    itemID,
    proceduralSeed,
    position,
    scale,
    color
)
    local graphicsState = self:GetGraphicsState(
        itemID,
        proceduralSeed
    )
    if not graphicsState then
        return false
    end

    local recipe, nextState = self:GenerateRecipe(graphicsState)
    local sourceItemIDs, _ = self:GenerateSourceItemIDs(nextState)
    local renderedAnyTile = false

    for destinationTileIndex = 0, 63 do
        local tile = recipe[destinationTileIndex + 1]
        if tile
            and tile.SourceImageIndex ~= 0xFF
        then
            local sourceItemID = sourceItemIDs[tile.SourceImageIndex + 1]
            if sourceItemID then
                local renderedTile = self:RenderItemIconTile(
                    sourceItemID,
                    tile.SourceTileIndex,
                    destinationTileIndex,
                    position,
                    scale,
                    color
                )

                if renderedTile then
                    renderedAnyTile = true
                end
            end
        end
    end

    return renderedAnyTile
end

return GlitchedItemRenderer
