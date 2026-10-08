---@class MSD4RProceduralSeedTracker
---@field ModSave MSD4RModSave
---@field RunSeed integer
---@field ItemIDToSeeds MSD4RSeedMap
---@field SeedSources MSD4RSeedSourceMap
---@field RerollWindows table<integer, MSD4RItemRNGObservation>
---@field PickupWindows table<integer, MSD4RPickupRNGObservation>
---@field ValidatedSeeds table<integer, integer>
---@field ObservedProceduralItemCount integer?
---@field Initialized boolean?
local ProceduralSeedTracker = {}

---@type MSD4RMagicConstants
local MAGIC_CONST = include("scripts/magic_const")
---@type MSD4RReplayController
local ReplayController = include("scripts/replay_controller")
---@type MSD4RUtility
local Utility = include("scripts/utility")

---@type MSD4RCoreAPI
local CoreAPI = include("scripts/core_api")

---@type MSD4RSeedTrackerConfig
local CONFIG = {
    MAX_RNG_STEPS = 16384,
    MAX_SEEDS_PER_ITEM = 8,
    CANDIDATE_FLAGS = { 0, 8 },
    SELECTION_SEED_STEPS = 2
}

---@type Game
local game = Game()

---@param seed any
---@return integer result1
function ProceduralSeedTracker:NormalizeSeed(seed)
    seed = tonumber(seed)
    if not seed then
        return 0
    end

    return Utility.ConvertToU32(math.floor(seed))
end

---@return nil # No return value.
function ProceduralSeedTracker:UpdateProceduralSeeds()
    local savedSeeds = self.ModSave:GetProceduralSeeds()
    if type(savedSeeds) == "table" then
        for rawID, seeds in pairs(savedSeeds) do
            local itemID = Utility.ConvertToID32(rawID)
            if itemID
                and itemID < 0
                and itemID >= -MAGIC_CONST.PROCEDURAL_ITEM_SURFACE_COUNT
            then
                if type(seeds) ~= "table" then
                    seeds = { seeds }
                end

                local itemSeeds = {}
                for _, seed in ipairs(seeds) do
                    seed = self:NormalizeSeed(seed)
                    if seed
                        and seed ~= 0
                    then
                        itemSeeds[#itemSeeds + 1] = seed
                    end
                end

                self.ItemIDToSeeds[itemID] = itemSeeds
            end
        end
    end
end

---@param mod MSD4RMod
---@return nil # No return value.
function ProceduralSeedTracker:Initialize(mod)
    if self.Initialized then
        return
    end

    self.ModSave = mod.ModSave
    self.RunSeed = self:NormalizeSeed(self.ModSave:GetRunSeed())
    self.ItemIDToSeeds = {}
    self.SeedSources = {}

    self.RerollWindows = {}
    self.PickupWindows = {}
    self.ValidatedSeeds = {}
    self.ObservedProceduralItemCount = nil

    self:UpdateProceduralSeeds()
    self.Initialized = true
end

---@return nil # No return value.
function ProceduralSeedTracker:ResetObservations()
    self.RerollWindows = {}
    self.PickupWindows = {}
    self.ValidatedSeeds = {}
    self.ObservedProceduralItemCount = nil
end

---@return nil # No return value.
function ProceduralSeedTracker:Clear()
    self.ItemIDToSeeds = {}
    self.SeedSources = {}

    self:ResetObservations()
end

---@return integer result1
function ProceduralSeedTracker:GetCurrentRunSeed()
    return self:NormalizeSeed(game:GetSeeds():GetStartSeed())
end

---@param seed integer
---@return integer result1
function ProceduralSeedTracker:GetNextSelectionSeed(seed)
    seed = Utility.ConvertToU32(seed)
    seed = Utility.ConvertToU32(seed ~ (seed >> 5))
    seed = Utility.ConvertToU32(seed ~ (seed << 9))
    return Utility.ConvertToU32(seed ~ (seed >> 7))
end

---@return nil # No return value.
function ProceduralSeedTracker:Save()
    if not self.ModSave then
        return
    end

    local proceduralSeeds = {}
    for itemID, seeds in pairs(self.ItemIDToSeeds) do
        proceduralSeeds[tostring(itemID)] = seeds
    end

    self.ModSave:Set("RunSeed", self.RunSeed)
    self.ModSave:Set("ProceduralSeeds", proceduralSeeds)
end

---@param id integer
---@return integer[] result1
function ProceduralSeedTracker:GetSeeds(id)
    if not self.Initialized then
        return {}
    end

    id = Utility.ConvertToID32(id)

    local candidateSeeds = {}
    local visitedSeeds = {}

    local itemProceduralSeeds = self.ItemIDToSeeds[id]
    if not itemProceduralSeeds
        or #itemProceduralSeeds < 1
    then
        return candidateSeeds
    end

    for _, seed in ipairs(itemProceduralSeeds) do
        if not visitedSeeds[seed] then
            candidateSeeds[#candidateSeeds + 1] = seed
            visitedSeeds[seed] = true
        end
    end

    if not self.SeedSources[id] then
        self.SeedSources[id] = {}
    end

    for steps = 1, CONFIG.SELECTION_SEED_STEPS do
        for _, seed in ipairs(itemProceduralSeeds) do
            local curSeed = seed
            for _ = 1, steps do
                curSeed = self:GetNextSelectionSeed(curSeed)
            end

            if not visitedSeeds[curSeed] then
                candidateSeeds[#candidateSeeds + 1] = curSeed
                visitedSeeds[curSeed] = true

                local key = tostring(curSeed)
                if not self.SeedSources[id][key] then
                    local label = steps == 1
                        and "Next35"
                        or "Next35x2"

                    self.SeedSources[id][key] = { string.format(
                        "candidate.%s(%s)",
                        label,
                        tostring(seed)
                    ) }
                end
            end
        end
    end

    return candidateSeeds
end

---@param id integer
---@param seed integer
---@param source? string
---@param deferSave? boolean
---@return nil # No return value.
function ProceduralSeedTracker:SetSeed(
    id,
    seed,
    source,
    deferSave
)
    ---@param seedMap MSD4RSeedMap
    ---@return boolean result1
    local function appendSeed(seedMap)
        if not seedMap[id] then
            seedMap[id] = {}
        end

        local length = #seedMap[id]
        if length >= CONFIG.MAX_SEEDS_PER_ITEM then
            return false
        end

        for _, value in ipairs(seedMap[id]) do
            if value == seed then
                return false
            end
        end

        seedMap[id][length + 1] = seed

        return true
    end

    id = Utility.ConvertToID32(id)
    seed = self:NormalizeSeed(seed)

    if id >= 0
        or id < -MAGIC_CONST.PROCEDURAL_ITEM_SURFACE_COUNT
        or seed == 0
    then
        return
    end

    if not source then
        source = "explicit"
    end

    local runSeed = self:GetCurrentRunSeed()
    if self.RunSeed ~= runSeed then
        self.RunSeed = runSeed
        self.ItemIDToSeeds = {}
        self.SeedSources = {}
    end

    if not self.SeedSources[id] then
        self.SeedSources[id] = {}
    end

    local key = tostring(seed)
    if not self.SeedSources[id][key] then
        self.SeedSources[id][key] = {}
    end

    local visitedSource = false
    for _, value in ipairs(self.SeedSources[id][key]) do
        if value == source then
            visitedSource = true
        end
    end

    if not visitedSource then
        self.SeedSources[id][key][#self.SeedSources[id][key] + 1] = source
    end

    if appendSeed(self.ItemIDToSeeds) and
        not deferSave
    then
        self:Save()
    end
end

---@param label string
---@param missingAPIs string[]
---@return nil # No return value.
function ProceduralSeedTracker:ReportMissingAPIs(
    label,
    missingAPIs
)
    CoreAPI:ReportUnavailable(label, missingAPIs)
end

---@param rng RNG
---@param count integer
---@return MSD4RSeedRNGSnapshot snapshot
function ProceduralSeedTracker:GetRNGSnapshot(rng, count)
    return {
        Seed = self:NormalizeSeed(rng:GetSeed()),
        Shift = rng:GetShiftIdx(),
        Count = count,
        RunSeed = self:GetCurrentRunSeed()
    }
end

---@param seeds integer[]
---@return integer[] candidates
function ProceduralSeedTracker:ExpandCandidateSeeds(seeds)
    local candidates = {}
    local visitedSeeds = {}

    -- Try the native seed first, then try some next rng.
    for steps = 0, CONFIG.SELECTION_SEED_STEPS do
        for _, seed in ipairs(seeds) do
            local candidate = self:NormalizeSeed(seed)
            if candidate ~= 0 then
                for _ = 1, steps do
                    candidate = self:GetNextSelectionSeed(candidate)
                end

                if not visitedSeeds[candidate] then
                    visitedSeeds[candidate] = true
                    candidates[#candidates + 1] = candidate
                end
            end
        end
    end

    return candidates
end

---@param firstIndex integer
---@param lastIndex integer
---@param seeds integer[]
---@return MSD4RMatchedSeed[] matchedSeeds
function ProceduralSeedTracker:MatchCreationSeeds(
    firstIndex,
    lastIndex,
    seeds
)
    ---@type MSD4RPendingItem[]
    local pendingItems = {}
    ---@type MSD4RMatchedSeed[]
    local matchedSeeds = {}

    for index = firstIndex, lastIndex - 1 do
        local itemID = -index - 1
        if not self.ValidatedSeeds[itemID] then
            local item = Utility.GetRawProceduralItem(itemID)
            if item then
                pendingItems[#pendingItems + 1] = {
                    ID = itemID,
                    Snapshot = ReplayController:GetSnapshot(item)
                }
            end
        end
    end

    if #pendingItems == 0
        or #seeds == 0
    then
        return matchedSeeds
    end

    local env = ReplayController:BuildEnvironment()
    for _, seed in ipairs(self:ExpandCandidateSeeds(seeds)) do
        for _, flags in ipairs(CONFIG.CANDIDATE_FLAGS) do
            local replayResult = ReplayController:Replay(
                seed,
                env,
                flags
            )

            for index = #pendingItems, 1, -1 do
                local pendingItem = pendingItems[index]
                local valid = ReplayController:ValidateSnapshot(
                    replayResult,
                    pendingItem.Snapshot
                )

                if valid then
                    matchedSeeds[#matchedSeeds + 1] = {
                        ID = pendingItem.ID,
                        Seed = seed
                    }
                    table.remove(pendingItems, index)
                end
            end

            if #pendingItems == 0 then
                return matchedSeeds
            end
        end
    end

    return matchedSeeds
end

---@param firstIndex integer
---@param lastIndex integer
---@param seeds integer[]
---@param source string
---@return integer matchedCount
function ProceduralSeedTracker:ValidateSeeds(
    firstIndex,
    lastIndex,
    seeds,
    source
)
    local successful, matchedSeedsOrError = pcall(
        self.MatchCreationSeeds,
        self,
        firstIndex,
        lastIndex,
        seeds
    )

    if not successful then
        Utility.Log(
            "Seed replay failed: "
            .. tostring(matchedSeedsOrError)
            .. "."
        )

        return 0
    end

    for _, matchedSeed in ipairs(matchedSeedsOrError) do
        self.ItemIDToSeeds[matchedSeed.ID] = {}
        self.ValidatedSeeds[matchedSeed.ID] = matchedSeed.Seed
        self:SetSeed(
            matchedSeed.ID,
            matchedSeed.Seed,
            source .. ".validated",
            true
        )
    end

    if #matchedSeedsOrError > 0 then
        self:Save()
    end

    return #matchedSeedsOrError
end

---@param previousSnapshot MSD4RSeedRNGSnapshot
---@param currentSnapshot MSD4RSeedRNGSnapshot
---@param source string
---@return nil # No return value.
function ProceduralSeedTracker:RecurRNGChange(
    previousSnapshot,
    currentSnapshot,
    source
)
    if previousSnapshot.RunSeed ~= currentSnapshot.RunSeed
        or currentSnapshot.Count <= previousSnapshot.Count
        or previousSnapshot.Seed == currentSnapshot.Seed
        or previousSnapshot.Shift ~= currentSnapshot.Shift
        or previousSnapshot.Seed == 0
        or currentSnapshot.Seed == 0
    then
        return
    end

    local replicatedRNG = RNG()
    local seeds = {}

    replicatedRNG:SetSeed(
        previousSnapshot.Seed,
        previousSnapshot.Shift
    )

    while replicatedRNG:GetSeed() ~= currentSnapshot.Seed
        and #seeds < CONFIG.MAX_RNG_STEPS
    do
        seeds[#seeds + 1] = replicatedRNG:Next()
    end

    if replicatedRNG:GetSeed() ~= currentSnapshot.Seed then
        Utility.Log("Seed tracker RNG was reset or exceeded the observation limit.")

        return
    end

    self:ValidateSeeds(
        previousSnapshot.Count,
        currentSnapshot.Count,
        seeds,
        source
    )
end

---@return integer proceduralItemCount
function ProceduralSeedTracker:PrepareObservation()
    local runSeed = self:GetCurrentRunSeed()
    local count = ProceduralItemManager.GetProceduralItemCount()

    if self.RunSeed ~= runSeed then
        self:Clear()
        self.RunSeed = runSeed
    end

    if self.ObservedProceduralItemCount
        and count < self.ObservedProceduralItemCount
    then
        for itemID in pairs(self.ItemIDToSeeds) do
            if -itemID - 1 >= count then
                self.ItemIDToSeeds[itemID] = nil
                self.SeedSources[itemID] = nil
            end
        end

        self:ResetObservations()
        self:Save()
    end

    self.ObservedProceduralItemCount = count

    return count
end

---@param player EntityPlayer
---@param itemID integer
---@param suppliedRNG? RNG
---@return nil # No return value.
function ProceduralSeedTracker:ObserveItemRNG(
    player,
    itemID,
    suppliedRNG
)
    local proceduralItemCount = self:PrepareObservation()
    local playerKey = GetPtrHash(player)
    local observation = self.RerollWindows[playerKey]

    if not observation then
        local available, missingAPIs = CoreAPI:CheckSeedTrackingPlayer(player)
        if not available then
            self:ReportMissingAPIs("Player seed tracking", missingAPIs)

            return
        end

        observation = {
            Player = player,
            Snapshots = {},
            LastUsedFrames = {}
        }
        self.RerollWindows[playerKey] = observation
    end

    local rng = suppliedRNG or player:GetCollectibleRNG(itemID)
    if not rng then
        return
    end

    local currentSnapshot = self:GetRNGSnapshot(rng, proceduralItemCount)
    local previousSnapshot = observation.Snapshots[itemID]

    observation.Snapshots[itemID] = currentSnapshot

    if previousSnapshot then
        self:RecurRNGChange(
            previousSnapshot,
            currentSnapshot,
            string.format(
                "Player[%s].Collectible[%d].RNGWindow",
                tostring(playerKey),
                itemID
            )
        )
    end
end

---@param player EntityPlayer
---@return nil # No return value.
function ProceduralSeedTracker:ObserveD4RNG(player)
    self:ObserveItemRNG(
        player,
        CollectibleType.COLLECTIBLE_D4
    )
end

---@param pickup EntityPickup
---@return MSD4RPickupRNGObservation? observation
function ProceduralSeedTracker:ObservePickupRNG(pickup)
    local count = self:PrepareObservation()
    local pickupKey = GetPtrHash(pickup)
    local observation = self.PickupWindows[pickupKey]

    if not observation then
        local available, missingAPIs = CoreAPI:CheckPickup(pickup)
        if not available then
            self:ReportMissingAPIs("Pickup seed tracking", missingAPIs)

            return nil
        end

        observation = { Pickup = pickup }
        self.PickupWindows[pickupKey] = observation
    end

    local rng = pickup:GetDropRNG()
    if rng then
        local currentSnapshot = self:GetRNGSnapshot(rng, count)
        local previousSnapshot = observation.Snapshot

        observation.Snapshot = currentSnapshot

        if previousSnapshot then
            self:RecurRNGChange(
                previousSnapshot,
                currentSnapshot,
                "Pickup.DropRNGWindow"
            )
        end
    end

    return observation
end

---@param pickup? EntityPickup
---@param phase? string
---@return nil # No return value.
function ProceduralSeedTracker:OnPostPickupUpdate(
    pickup,
    phase
)
    if not pickup
        or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE
    then
        return
    end

    local observation = self:ObservePickupRNG(pickup)
    if not observation then
        return
    end

    local itemID = Utility.ConvertToID32(pickup.SubType)
    local dropSeed = self:NormalizeSeed(pickup.DropSeed)
    local rngSeed = observation.Snapshot
        and observation.Snapshot.Seed
        or 0

    if itemID >= 0
        or itemID < -MAGIC_CONST.PROCEDURAL_ITEM_SURFACE_COUNT
    then
        return
    end

    if observation.ItemID == itemID
        and observation.DropSeed == dropSeed
        and observation.RNGSeed == rngSeed
    then
        return
    end

    observation.ItemID = itemID
    observation.DropSeed = dropSeed
    observation.RNGSeed = rngSeed

    local source = phase or "update"

    self:SetSeed(itemID, dropSeed, source .. ".DropSeed")
    self:SetSeed(itemID, rngSeed, source .. ".GetDropRNG")

    local index = -itemID - 1
    self:ValidateSeeds(
        index,
        index + 1,
        { dropSeed, rngSeed },
        source
    )
end

---@param selected integer
---@param pool integer
---@param decrease boolean
---@param seed integer
---@return nil # No return value.
function ProceduralSeedTracker:OnPostGetItem(
    selected,
    pool,
    decrease,
    seed
)
    self:SetSeed(
        selected,
        seed,
        "MC_POST_GET_COLLECTIBLE"
    )
end

---@param itemID integer
---@param rng RNG
---@param player EntityPlayer
---@return nil # No return value.
function ProceduralSeedTracker:OnPreUseItem(
    itemID,
    rng,
    player
)
    -- Other active items may call D4 function to re-roll.
    if itemID ~= CollectibleType.COLLECTIBLE_D4 then
        self:ObserveD4RNG(player)
    end

    self:ObserveItemRNG(
        player,
        itemID,
        rng
    )

    local observation = self.RerollWindows[GetPtrHash(player)]
    if observation then
        observation.LastUsedFrames[itemID] = game:GetFrameCount()
    end
end

---@param itemID integer
---@param rng RNG
---@param player EntityPlayer
---@return nil # No return value.
function ProceduralSeedTracker:OnPostUseItem(
    itemID,
    rng,
    player
)
    if itemID ~= CollectibleType.COLLECTIBLE_D4 then
        self:ObserveD4RNG(player)
    end

    self:ObserveItemRNG(
        player,
        itemID,
        rng
    )
end

---@param pickup EntityPickup
---@param entityType integer
---@param variant integer
---@return nil # No return value.
function ProceduralSeedTracker:OnPrePickupMorph(
    pickup,
    entityType,
    variant
)
    if pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE
        or (entityType == EntityType.ENTITY_PICKUP
            and variant == PickupVariant.PICKUP_COLLECTIBLE)
    then
        self:ObservePickupRNG(pickup)
    end
end

---@param pickup EntityPickup
---@return nil # No return value.
function ProceduralSeedTracker:OnPostPickupMorph(pickup)
    self:OnPostPickupUpdate(pickup, "morph")
end

---@param isContinued boolean
---@return nil # No return value.
function ProceduralSeedTracker:OnPostGameStarted(isContinued)
    local runSeed = self:GetCurrentRunSeed()

    if self.RunSeed ~= runSeed
        or not isContinued
    then
        self:Clear()
    end

    self.RunSeed = runSeed
    self:Save()
end

---@return nil # No return value.
function ProceduralSeedTracker:OnPreGameExit()
    self:Save()
    self:ResetObservations()
end

---@type MSD4RProceduralSeedTracker
return ProceduralSeedTracker
