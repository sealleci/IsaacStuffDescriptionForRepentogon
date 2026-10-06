---@class MSD4RReplayController
---@field CachedEnvironment MSD4REnvironment?
local ReplayController = {}

---@type MSD4RUtility
local Utility = include("scripts/utility")

---@type MSD4RReplayConfig
local CONFIG = {
    INITIAL_GLOBAL_COLOR = 1,
    EXCLUDED_ACTIVE = {
        [475] = true,
        [482] = true,
        [297] = true,
        [515] = true,
        [127] = true,
        [483] = true,
        [347] = true,
        [585] = true,
        [490] = true,
        [636] = true,
        [628] = true,
    },
    ITEM_FIELD_KEYS = {
        "ID",
        "Type",
        "MaxCharges",
        "ChargeType",
        "DevilPrice",
        "ShopPrice",
        "CacheFlags"
    },
    HEALTH_METHODS = {
        "AddMaxHearts",
        "AddHearts",
        "AddSoulHearts",
        "AddBlackHearts",
        "AddBombs",
        "AddKeys",
        "AddCoins"
    },
    STAT_METHODS = {
        "GetDamage",
        "GetFireDelay",
        "GetSpeed",
        "GetRange",
        "GetShotSpeed",
        "GetLuck"
    },
    ACTION_FIELDS = {
        'id',
        'type',
        'variant',
        'fromType',
        'fromVariant',
        'toType',
        'toVariant',
        'radius',
        'damage'
    }
}

---@class MSD4RReplayRNG
---@field __index MSD4RReplayRNG
---@field state integer
---@field effect boolean?
---@field draws integer
local ReplayRNG = {}
ReplayRNG.__index = ReplayRNG

---@param seed integer
---@param effect? boolean
---@return nil # No return value.
function ReplayRNG:Initialize(seed, effect)
    self.state = Utility.ConvertToU32(seed)
    self.effect = effect
    self.draws = 0
end

---@param seed integer
---@param effect? boolean
---@return MSD4RReplayRNG result1
function ReplayRNG.New(seed, effect)
    local instance = setmetatable({}, ReplayRNG)
    instance:Initialize(seed, effect)
    return instance
end

---@return integer result1
function ReplayRNG:Next()
    self.state = Utility.ConvertToU32(
        self.state ~ (
            self.state >> (
                self.effect and 13 or 4
            )
        )
    )
    self.state = Utility.ConvertToU32(
        self.state ~ (self.state << 3)
    )
    self.state = Utility.ConvertToU32(
        self.state ~ (
            self.state >> (
                self.effect and 17 or 27
            )
        )
    )
    self.draws = self.draws + 1

    return self.state
end

---@param maxValue integer
---@return integer result1
function ReplayRNG:GetNextInt(maxValue)
    local state = self:Next()

    return maxValue > 0
        and state % maxValue
        or 0
end

---@return number value
function ReplayRNG:GetNextFloat()
    return Utility.ConvertToF32(
        Utility.ConvertToF32(self:Next())
        * 2.3283061589829401e-10
    )
end

---@param n integer
---@return nil # No return value.
function ReplayRNG:Skip(n)
    for _ = 1, n do
        self:Next()
    end
end

---@return nil # No return value.
function ReplayController:Reset()
    self.CachedEnvironment = nil
end

---@param rng MSD4RReplayRNG
---@param env MSD4REnvironment
---@param kind integer
---@return integer result1
function ReplayController:ChooseVariant(rng, env, kind)
    local variants = env.byType[kind]

    if not variants
        or #variants < 1
    then
        return 0xFFFF
    end

    return Utility.ConvertToU16(
        variants[rng:GetNextInt(#variants) + 1].variant
    )
end

---@param rng MSD4RReplayRNG
---@param env MSD4REnvironment
---@return MSD4REntitySelection result1
---@return number result2
function ReplayController:GetEntityA(rng, env)
    local kind = 0
    local variant = 0xFFFF
    local weight = 0
    local action = rng:GetNextInt(6)

    if action == 0
        or action == 1
    then
        if action == 0 then
            kind = 2
        else
            kind = 9
        end

        weight = Utility.ConvertToF32(0.01)


        if rng:GetNextInt(3) == 0 then
            variant = self:ChooseVariant(rng, env, kind)
        end
    elseif action == 2 then
        kind = 5
        weight = 1

        if rng:GetNextInt(4) ~= 0 then
            variant = self:ChooseVariant(rng, env, 5)
        end
    elseif action == 3 then
        kind = 4
        weight = Utility.ConvertToF32(0.02)
    elseif action == 4 then
        kind = 999
        weight = Utility.ConvertToF32(0.02)

        if rng:GetNextInt(4) == 0 then
            for _ = 1, 100 do
                local newKind = rng:GetNextInt(990) + 10
                local entity = env.baseEntities[newKind]

                if entity
                    and not entity.boss
                then
                    kind = newKind
                    break
                end
            end
        end
    else
        kind = 1000
        weight = Utility.ConvertToF32(0.02)
        variant = self:ChooseVariant(rng, env, 1000)
    end

    return {
        type = kind,
        variant = variant
    }, weight
end

---@param rng MSD4RReplayRNG
---@param env MSD4REnvironment
---@return MSD4REntitySelection result1
---@return number result2
function ReplayController:GetEntityB(rng, env)
    local kind, variant, weight = 0, 0, 0

    if rng:GetNextInt(8) == 0 then
        if #env.entities > 0 then
            for _ = 1, 10 do
                local entity = env.entities[
                rng:GetNextInt(#env.entities) + 1
                ]

                if entity.type ~= 1
                    and not entity.boss
                then
                    kind = Utility.ConvertToU16(entity.type)
                    variant = Utility.ConvertToU16(entity.variant)
                    weight = Utility.ConvertToF32(
                        rng:GetNextFloat()
                        + Utility.ConvertToF32(0.1)
                    )
                end
            end
        end
    else
        local action = rng:GetNextInt(4)

        if action == 0 then
            kind = 2
            variant = self:ChooseVariant(rng, env, 2)
            weight = Utility.ConvertToF32(0.01)
        elseif action == 1 then
            kind = 5
            weight = 1

            if rng:GetNextInt(4) ~= 0 then
                variant = self:ChooseVariant(rng, env, 5)
            end
        elseif action == 2 then
            kind = 4
            variant = self:ChooseVariant(rng, env, 4)
            weight = Utility.ConvertToF32(0.02)
        else
            kind = 10
            weight = Utility.ConvertToF32(0.02)

            for _ = 1, 10 do
                local newKind = rng:GetNextInt(990) + 10
                local entity = env.baseEntities[newKind]

                if entity and
                    not entity.boss
                then
                    kind = newKind
                    break
                end
            end
        end
    end

    return {
        type = kind,
        variant = variant
    }, weight
end

---@param seed integer
---@param condition integer
---@param action integer
---@param env MSD4REnvironment
---@return MSD4RReplayEffect result1
function ReplayController:Effect(
    seed,
    condition,
    action,
    env
)
    local rng = ReplayRNG.New(seed, true)
    local score = 0
    local property = {}
    local conditionProperty = {}

    if action == 0 then
        if #env.active > 0 then
            local activeItem = env.active[
            rng:GetNextInt(#env.active) + 1
            ]
            property.id = activeItem.ID

            if activeItem.ChargeType == 1 then
                score = Utility.ConvertToF32(activeItem.Quality)
            elseif activeItem.ChargeType == 0 then
                score = Utility.ConvertToF32(
                    Utility.ConvertToF32(activeItem.MaxCharges * 0.5)
                    + 1
                )
            end

            if activeItem.ID == 704 then
                score = Utility.ConvertToF32(score + 6)
            end
        end
    elseif action == 1 then
        property.id = 0

        for _ = 1, 10 do
            local id = rng:GetNextInt(env.itemCount)

            if env.items[id] then
                property.id = id
                score = 1
                break
            end
        end
    elseif action == 2 then
        local entityA, entityAWeight = self:GetEntityA(rng, env)
        local entityB, entityBWeight = self:GetEntityB(rng, env)

        property = {
            fromType = entityA.type,
            fromVariant = entityA.variant,
            toType = entityB.type,
            toVariant = entityB.variant
        }

        if entityAWeight > 0 then
            score = Utility.ConvertToF32(entityBWeight / entityAWeight)
        else
            score = 10000
        end
    elseif action == 3 then
        local f1 = rng:GetNextFloat()
        local f2 = rng:GetNextFloat()
        local f3 = rng:GetNextFloat()

        property.radius = Utility.ConvertToF32(
            Utility.ConvertToF32(
                Utility.ConvertToF32(
                    Utility.ConvertToF32(f1 * f2)
                    * f3
                )
                * 8000
            )
            + 30
        )

        local f4 = rng:GetNextFloat()
        local f5 = rng:GetNextFloat()

        property.damage = math.max(
            Utility.ConvertToF32(
                Utility.ConvertToF32(
                    f4 - Utility.ConvertToF32(0.2)
                )
                * f5 * 80
            ),
            0
        )
        score = Utility.ConvertToF32(
            property.damage
            * Utility.ConvertToF32(0.1)
        )
        property.flags1 = 0
        property.flags2 = 0

        if rng:GetNextInt(3) == 0 then
            local divisor = 100
            if property.damage < 5 then
                divisor = 20
            end

            for i = 0, 127 do
                if rng:GetNextInt(divisor) == 0 then
                    score = Utility.ConvertToF32(
                        score
                        + Utility.ConvertToF32(0.4)
                    )

                    local key = "flags2"
                    if i < 64 then
                        key = "flags1"
                    end

                    property[key] = property[key]| (1 << (i % 64))
                end
            end
        end

        property.flags2 = property.flags2 & 0x7FFFFFFFFFFFFFFF
    elseif action == 4 then
        local weight
        property, weight = self:GetEntityB(rng, env)
        score = Utility.ConvertToF32(weight * 100)
    elseif action == 5 then
        local f1 = rng:GetNextFloat()
        local f2 = rng:GetNextFloat()
        local nativeRadius = Utility.ConvertToF32(
            f2 * 10
            + Utility.ConvertToF32(
                f1 * 10 + 5
            )
        )

        property.radius = Utility.ConvertToF32(
            Utility.ConvertToF32(nativeRadius * 6)
            / 85
        )
        property.scale = Utility.ConvertToF32(
            string.unpack(
                "<f",
                string.pack(
                    "<I4",
                    rng:GetNextInt(10)
                )
            )
            * 6
        )

        if rng:GetNextInt(4) == 0 then
            rng:Skip(10)
        end

        score = 1
    else
        error("invalid effect action")
    end

    if condition == 6 then
        local weight
        conditionProperty, weight = self:GetEntityA(rng, env)

        if weight > 0 then
            score = Utility.ConvertToF32(score / weight)
        end
    elseif condition == 1 then
        score = Utility.ConvertToF32(score * 10)
    end

    return {
        ConditionType = condition,
        ActionType = action,
        ActionProperty = property,
        ConditionProperty = conditionProperty,
        Score = score,
        Seed = seed,
        EffectEndState = rng.state
    }
end

---@param state integer
---@return MSD4RRecipeTile[] result1
---@return integer result2
function ReplayController:GetRecipe(state)
    local rng = ReplayRNG.New(state, false)
    local sourceTileIndex = 0
    local sourceImageIndex = 0
    local color = 0
    local recipe = {}

    if rng:GetNextInt(5) == 0 then
        sourceTileIndex = rng:GetNextInt(64)
    end

    if rng:GetNextInt(5) == 0 then
        color = CONFIG.INITIAL_GLOBAL_COLOR
    end

    for i = 0, 63 do
        recipe[i + 1] = {
            SourceTileIndex = sourceTileIndex,
            SourceImageIndex = sourceImageIndex,
            ColorIndex = color
        }
        sourceTileIndex = sourceTileIndex + 1

        if rng:GetNextInt(12) == 0 then
            color = rng:GetNextInt(4)
        end

        if sourceTileIndex >= 64
            or rng:GetNextInt(12) == 0
        then
            sourceImageIndex = (sourceImageIndex + 1) % 4
            sourceTileIndex = i

            if rng:GetNextInt(20) == 0 then
                sourceTileIndex = i + 1
            end

            color = 0

            if rng:GetNextInt(5) == 0 then
                color = rng:GetNextInt(3) + 1
            end
        end
    end

    return recipe, rng.state
end

---@param state integer
---@param env MSD4REnvironment
---@return MSD4RSourceItems result1
---@return integer result2
function ReplayController:GetSourceItems(state, env)
    local rng = ReplayRNG.New(state, false)
    local result = {}

    if env.itemCount > 1 then
        for slot = 1, 4 do
            for _ = 1, 10 do
                local id = rng:GetNextInt(env.itemCount - 1) + 1
                local item = env.items[id]

                if item
                    and item.GfxFileName
                    and item.GfxFileName ~= ""
                then
                    result[slot] = id
                    break
                end
            end
        end
    end

    return result, rng.state
end

---@param seed integer
---@return integer result1
function ReplayController:GetTextState(seed)
    local rng = ReplayRNG.New(seed, false)

    for _ = 1, 2 do
        rng:Skip(3)

        if rng:GetNextInt(80) == 0 then
            rng:Next()
        end

        rng:Skip(3)
    end

    return rng.state
end

---@param seed integer
---@param flags? integer
---@return integer result1
function ReplayController:GetEffectiveSeed(seed, flags)
    seed = Utility.ConvertToU32(seed)

    if not flags then
        flags = 0
    end

    if seed & 0xc000 == 0xc000 then
        if flags & 2 ~= 0 then
            seed = seed & 0xffff3fff
        end
    elseif flags & 8 ~= 0 then
        seed = seed | 0xc000
    end

    return seed
end

---@param state integer
---@param active boolean
---@param env MSD4REnvironment
---@return MSD4RPreEffects result1
function ReplayController:GetPreEffects(state, active, env)
    local rng = ReplayRNG.New(state, false)
    local randoms = { 0, 0, 0, 0, 0, 0, 0 }
    local stats = { 0, 0, 0, 0, 0, 0 }
    local action = rng:GetNextInt(14)

    if action == 0 then
        randoms[1] = rng:GetNextInt(6) - rng:GetNextInt(3)
        randoms[2] = rng:GetNextInt(6) - rng:GetNextInt(3)
    elseif action == 1 then
        randoms[3] = rng:GetNextInt(6)
    elseif action == 2 then
        randoms[4] = rng:GetNextInt(6)
    elseif action == 3 then
        randoms[5] = rng:GetNextInt(6) - rng:GetNextInt(3)
    elseif action == 4 then
        randoms[6] = rng:GetNextInt(6) - rng:GetNextInt(3)
    elseif action == 5 then
        randoms[7] = rng:GetNextInt(6)
            - rng:GetNextInt(6)
            + rng:GetNextInt(6)
            + rng:GetNextInt(6)
    end

    local targetItem
    local targetID
    local targetTrinket

    if rng:GetNextInt(2) == 0 then
        targetID = rng:GetNextInt(env.itemCount)
        targetItem = env.items[targetID]
        targetTrinket = false
    else
        targetID = rng:GetNextInt(env.trinketCount) & 0x7fff
        targetItem = env.trinkets[targetID]
        targetTrinket = true
    end

    for i = 1, 7 do
        if rng:GetNextInt(40) == 0 then
            randoms[i] = randoms[i] + rng:GetNextInt(6)
        end
    end

    randoms[1] = randoms[1] & ~1

    local rngRange1 = 5
    if (targetItem
            and targetItem.CacheFlags ~= 0)
        or randoms[1] > 0
    then
        rngRange1 = 20
    end

    if rng:GetNextInt(rngRange1) == 0 then
        local order = { 1, 2, 3, 4, 5, 6 }

        for i = 1, 5 do
            local j = i + rng:GetNextInt(7 - i)

            order[i], order[j] = order[j], order[i]
        end

        if rng:GetNextInt(40) == 0 then
            for i = 1, 6 do
                stats[i] = Utility.ConvertToF32(
                    rng:GetNextFloat()
                    + rng:GetNextFloat()
                )
            end
        else
            local f1 = Utility.ConvertToF32(
                rng:GetNextFloat()
                + 0.25
            )
            local f2 = 0

            stats[order[1]] = f1

            if f1 < 0.5
                or rng:GetNextInt(8) == 0
            then
                f2 = Utility.ConvertToF32(
                    rng:GetNextFloat()
                    + 0.25
                )
                stats[order[2]] = f2
            end

            local rngRange2 = 5
            if Utility.ConvertToF32(f1 + f2) > 1 then
                rngRange2 = 2
            end

            if rng:GetNextInt(rngRange2) == 0 then
                stats[order[3]] = Utility.ConvertToF32(
                    Utility.ConvertToF32(0.1) -
                    Utility.ConvertToF32(
                        rng:GetNextFloat()
                        * 0.5
                    )
                )
            end
        end
    end

    local budget = 0
    local charges = 0
    local chargeType = 0

    if active then
        local chargeNumbers = {
            0, 1, 2, 2, 3, 3, 3, 4, 4, 4,
            6, 6, 6, 12, 300, 600
        }

        charges = chargeNumbers[rng:GetNextInt(16) + 1]

        if charges > 12 then
            chargeType = 1
            budget = Utility.ConvertToF32(
                rng:GetNextFloat()
                + rng:GetNextFloat()
            )
        else
            local f3 = Utility.ConvertToF32(
                rng:GetNextFloat()
                * charges
            )

            budget = Utility.ConvertToF32(
                Utility.ConvertToF32(f3 + f3)
                + 1
            )
        end
    else
        local f4 = rng:GetNextFloat()
        local f5 = rng:GetNextFloat()
        local f6 = rng:GetNextFloat()

        budget = Utility.ConvertToF32(
            Utility.ConvertToF32(f5 + f4)
            + f6
        )
    end

    return {
        State = rng.state,
        Budget = budget,
        Health = randoms,
        Stats = stats,
        TargetID = targetID,
        TargetTrinket = targetTrinket,
        ItemType = active and 3 or 1,
        MaxCharges = charges,
        ChargeType = chargeType
    }
end

---@param state integer
---@param preEffects MSD4RPreEffects
---@param env MSD4REnvironment
---@return MSD4RReplayEffect[] result1
---@return integer result2
---@return number result3
---@return MSD4REffectAttempt[] result4
function ReplayController:GetEffects(state, preEffects, env)
    local rng = ReplayRNG.New(state, false)
    local totalScore = 0
    local effects = {}
    local attempts = {}
    local actions = { 0, 0, 1, 1, 2, 3, 4, 5 }

    for attemptIndex = 0, 99 do
        if totalScore >= preEffects.Budget
            or #effects >= 8
        then
            break
        end

        local condition = 0
        if preEffects.ItemType ~= 3 then
            condition = rng:GetNextInt(7) + 1
        end

        if #effects > 0
            and rng:GetNextInt(4) ~= 0
        then
            condition = 8
        end

        local action = actions[rng:GetNextInt(8) + 1]
        local effect = self:Effect(
            rng:Next(),
            condition,
            action,
            env
        )
        local nextTotalScore = Utility.ConvertToF32(
            totalScore
            + effect.Score
        )
        local accepted = attemptIndex == 99
            or nextTotalScore < preEffects.Budget
            or rng:GetNextInt(20) == 0

        attempts[#attempts + 1] = {
            Seed = effect.Seed,
            Score = effect.Score,
            Accepted = accepted,
            State = rng.state
        }

        if accepted then
            effects[#effects + 1] = effect
            totalScore = nextTotalScore
        end
    end

    return effects, rng.state, totalScore, attempts
end

---@param state integer
---@return integer result1
---@return integer result2
---@return integer result3
function ReplayController:ProcessGraphicsPrelude(state)
    local rng = ReplayRNG.New(state, false)
    local devilPrice = rng:GetNextInt(2) + 1
    local shopPrice = rng:GetNextInt(99) + 1

    if rng:GetNextInt(2) == 0 then
        rng:Next()
    end

    return rng.state, devilPrice, shopPrice
end

---@param seed integer
---@param env MSD4REnvironment
---@param flags? integer
---@return MSD4RReplayResult result1
function ReplayController:Replay(
    seed,
    env,
    flags
)
    local effectiveSeed = self:GetEffectiveSeed(seed, flags)
    local textState = self:GetTextState(effectiveSeed)
    local preEffects = self:GetPreEffects(
        textState,
        effectiveSeed & 0xc000 == 0xc000,
        env
    )
    local effects, state, totalScore, attempts = self:GetEffects(
        preEffects.State,
        preEffects,
        env
    )
    local graphics, devilPrice, shopPrice =
        self:ProcessGraphicsPrelude(state)
    local recipe, nextSeed1 = self:GetRecipe(graphics)
    local sourceItems, nextSeed2 = self:GetSourceItems(nextSeed1, env)

    local hueRng = ReplayRNG.New(nextSeed2, false)
    local hue = Utility.ConvertToF32(
        hueRng:GetNextFloat()
        * 360
    )

    return {
        ItemID = nil,
        EffectiveSeed = effectiveSeed,
        TextState = textState,
        PreEffects = preEffects,
        Effects = effects,
        EffectsEndState = state,
        Score = totalScore,
        Attempts = attempts,
        GraphicsState = graphics,
        DevilPrice = devilPrice,
        ShopPrice = shopPrice,
        Recipe = recipe,
        SourceItems = sourceItems,
        Hue = hue
    }
end

---@return MSD4REnvironment result1
function ReplayController:BuildEnvironment()
    if self.CachedEnvironment then
        return self.CachedEnvironment
    end

    local config = Isaac.GetItemConfig()
    local env = {
        items = {},
        trinkets = {},
        active = {},
        itemCount = config:GetCollectibles().Size,
        trinketCount = config:GetTrinkets().Size,
        entities = {},
        baseEntities = {},
        byType = {},
    }

    for id = 0, env.itemCount - 1 do
        local itemConfig = config:GetCollectible(id)
        if itemConfig then
            local newItemConfig = {
                ID = itemConfig.ID,
                Type = itemConfig.Type,
                CacheFlags = itemConfig.CacheFlags,
                MaxCharges = itemConfig.MaxCharges,
                ChargeType = itemConfig.ChargeType,
                Quality = itemConfig.Quality,
                GfxFileName = itemConfig.GfxFileName
            }

            env.items[id] = newItemConfig

            if itemConfig.Type == 3 and
                not CONFIG.EXCLUDED_ACTIVE[itemConfig.ID]
            then
                env.active[#env.active + 1] = newItemConfig
            end
        end
    end

    for id = 0, env.trinketCount - 1 do
        local trinketConfig = config:GetTrinket(id)

        if trinketConfig then
            env.trinkets[id] = {
                ID = trinketConfig.ID,
                CacheFlags = trinketConfig.CacheFlags
            }
        end
    end

    local entities = {}

    for i = 1, XMLData.GetNumEntries(XMLNode.ENTITY) do
        local entry = XMLData.GetEntryByOrder(XMLNode.ENTITY, i)
        local itemType = entry and tonumber(entry.type or entry.id)

        if itemType then
            local variant = tonumber(entry.variant) or 0
            local subtype = tonumber(entry.subtype) or 0
            local entity = EntityConfig.GetEntity(
                itemType,
                variant,
                subtype
            )

            if entity
                and entity:GetType() == itemType
                and entity:GetVariant() == variant
                and entity:GetSubType() == subtype
            then
                local key = Utility.ConvertToU32(
                    (itemType << 12 | variant) << 8 | subtype
                )

                entities[key] = {
                    key = key,
                    type = itemType,
                    variant = variant,
                    subtype = subtype,
                    boss = entity:IsBoss()
                }
            end
        end
    end

    for _, entity in pairs(entities) do
        env.entities[#env.entities + 1] = entity
    end

    table.sort(
        env.entities,
        ---@param entity1 MSD4REntityRecord
        ---@param entity2 MSD4REntityRecord
        ---@return boolean result1
        function(entity1, entity2)
            return entity1.key < entity2.key
        end
    )

    for _, entity in ipairs(env.entities) do
        if not env.byType[entity.type] then
            env.byType[entity.type] = {}
        end

        env.byType[entity.type][#env.byType[entity.type] + 1] = entity

        if entity.key == Utility.ConvertToU32(entity.type << 20) then
            env.baseEntities[entity.type] = entity
        end
    end

    if #env.entities > 0
        and #env.active > 0
    then
        self.CachedEnvironment = env
    end

    return env
end

---@param instance ProceduralEffect
---@param method string
---@return MSD4REffectProperties result1
function ReplayController:GetProperties(instance, method)
    if not instance[method] then
        return {}
    end

    local obj = instance[method](instance) or {}
    local properties = {}

    for _, key in ipairs(CONFIG.ACTION_FIELDS) do
        if type(obj[key]) == 'number' then
            properties[key] = obj[key]
        end
    end

    return properties
end

---@param proceduralItem ProceduralItem
---@return MSD4RSnapshot result1
function ReplayController:GetSnapshot(proceduralItem)
    local itemConfig = proceduralItem:GetItem()
    local snapshot = {
        Item = {},
        Stats = {},
        Effects = {},
        TargetID = nil
    }

    for _, key in ipairs(CONFIG.ITEM_FIELD_KEYS) do
        snapshot.Item[key] = itemConfig[key]
    end

    for _, key in ipairs(CONFIG.HEALTH_METHODS) do
        snapshot.Item[key] = itemConfig[key]
    end

    for i, key in ipairs(CONFIG.STAT_METHODS) do
        snapshot.Stats[i] = proceduralItem[key](proceduralItem)
    end

    local targetItem = proceduralItem:GetTargetItem()

    if targetItem then
        snapshot.TargetID = targetItem.ID
    end

    for i = 0, proceduralItem:GetEffectCount() - 1 do
        local effect = proceduralItem:GetEffect(i)
        local newEffect = {
            ConditionType = 1,
            ActionType = 1,
            Score = 0,
            ConditionProperty = {},
            ActionProperty = {}
        }

        if effect then
            newEffect = {
                ConditionType = effect:GetConditionType(),
                ActionType = effect:GetActionType(),
                Score = effect:GetScore(),
                ConditionProperty = self:GetProperties(
                    effect,
                    "GetConditionProperty"
                ),
                ActionProperty = self:GetProperties(
                    effect,
                    "GetActionProperty"
                )
            }
        end

        snapshot.Effects[#snapshot.Effects + 1] = newEffect
    end

    return snapshot
end

---@param replayResult MSD4RReplayResult
---@param snapshot MSD4RSnapshot
---@return boolean result1
---@return string result2
---@return MSD4RDifferenceReport result3
function ReplayController:ValidateSnapshot(replayResult, snapshot)
    local differenceReport = {
        ItemConfig = {},
        Differences = {},
        Checks = 0,
        MatchedCount = 0,
        PrefixMatchedCount = 0,
        IsPreEffectsMatched = false,
        Valid = false,
        Summary = ""
    }

    ---@param field string
    ---@param actualValue any
    ---@param expectedValue any
    ---@param isFloat? boolean
    ---@param isEntity boolean|integer|nil
    ---@return nil # No return value.
    local function checkField(
        field,
        actualValue,
        expectedValue,
        isFloat,
        isEntity
    )
        if isEntity
            and type(actualValue) == "number"
        then
            actualValue = Utility.ConvertToU16(actualValue)
        end

        if (isFloat
                and Utility.SameFloat(actualValue, expectedValue))
            or (not isFloat
                and actualValue == expectedValue)
        then
            differenceReport.MatchedCount = differenceReport.MatchedCount + 1

            if #differenceReport.Differences == 0 then
                differenceReport.PrefixMatchedCount =
                    differenceReport.PrefixMatchedCount + 1
            end
        else
            differenceReport.Differences[
            #differenceReport.Differences + 1
            ] = {
                Field = field,
                Actual = (
                    actualValue == nil
                    and "<nil>"
                    or actualValue
                ),
                Expected = (
                    expectedValue == nil
                    and "<nil>"
                    or expectedValue
                )
            }
        end

        differenceReport.Checks = differenceReport.Checks + 1
    end

    ---@param value any
    ---@return string result1
    local function formatValue(value)
        if type(value) == 'number' then
            return string.format('%.10g', value)
        end

        return tostring(value)
    end

    local snapshotItem = snapshot.Item

    checkField(
        "Type",
        snapshotItem.Type,
        replayResult.PreEffects.ItemType,
        false,
        false
    )
    checkField(
        "MaxCharges",
        snapshotItem.MaxCharges,
        replayResult.PreEffects.MaxCharges,
        false,
        false
    )
    checkField(
        "ChargeType",
        snapshotItem.ChargeType,
        replayResult.PreEffects.ChargeType,
        false,
        false
    )

    for i, k in ipairs(CONFIG.HEALTH_METHODS) do
        checkField(
            k,
            snapshotItem[k],
            replayResult.PreEffects.Health[i],
            false,
            false
        )
    end

    if snapshot.TargetID then
        checkField(
            "TargetID",
            snapshot.TargetID,
            replayResult.PreEffects.TargetID,
            false,
            false
        )
    end

    for i, key in ipairs(CONFIG.STAT_METHODS) do
        checkField(
            key,
            snapshot.Stats[i],
            replayResult.PreEffects.Stats[i],
            true,
            false
        )
    end

    differenceReport.IsPreEffectsMatched =
        #differenceReport.Differences == 0
    checkField(
        "EffectCount",
        #snapshot.Effects,
        #replayResult.Effects,
        false,
        false
    )

    for i, replayEffect in ipairs(replayResult.Effects) do
        local snapshotEffect = snapshot.Effects[i]
        local prefix = string.format(
            "Effect[%d].",
            i - 1
        )

        if snapshotEffect then
            checkField(
                prefix .. "ConditionType",
                snapshotEffect.ConditionType,
                replayEffect.ConditionType,
                false,
                false
            )
            checkField(
                prefix .. "ActionType",
                snapshotEffect.ActionType,
                replayEffect.ActionType,
                false,
                false
            )
            checkField(
                prefix .. "Score",
                snapshotEffect.Score,
                replayEffect.Score,
                true,
                false
            )
            if replayEffect.ConditionType == 6
                and snapshotEffect.ConditionType == 6
            then
                for _, key in ipairs({ "type", "variant" }) do
                    checkField(
                        prefix .. "Condition." .. key,
                        snapshotEffect.ConditionProperty[key],
                        replayEffect.ConditionProperty[key],
                        false,
                        true
                    )
                end
            end

            if snapshotEffect.ActionType == replayEffect.ActionType then
                for _, key in ipairs(CONFIG.ACTION_FIELDS) do
                    local property = replayEffect.ActionProperty[key]

                    if property then
                        checkField(
                            prefix .. "Action." .. key,
                            snapshotEffect.ActionProperty[key],
                            property,
                            (key == "radius"
                                or key == "damage"),
                            (key:lower():find("type")
                                or key:lower():find("variant"))
                        )
                    end
                end
            end
        end
    end

    checkField(
        "DevilPrice",
        snapshotItem.DevilPrice,
        replayResult.DevilPrice
    )
    checkField(
        "ShopPrice",
        snapshotItem.ShopPrice,
        replayResult.ShopPrice
    )
    differenceReport.Valid =
        #differenceReport.Differences == 0
    differenceReport.Summary = "MATCHED"

    if #differenceReport.Differences > 0 then
        differenceReport.Summary = ""

        for _, differenceItem in ipairs(differenceReport.Differences) do
            differenceReport.Summary = differenceReport.Summary
                .. string.format(
                    "%s mismatch: expected=%s actual=%s;",
                    differenceItem.Field,
                    formatValue(differenceItem.Expected),
                    formatValue(differenceItem.Actual)
                )
        end
    end

    return differenceReport.Valid, differenceReport.Summary, differenceReport
end

---@type MSD4RReplayController
return ReplayController
