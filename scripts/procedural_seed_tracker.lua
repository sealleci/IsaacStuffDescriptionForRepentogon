local ProceduralSeedTracker = {}

local ReplayController = include("scripts/replay_controller")
local Utility = include("scripts/utility")

local game = Game()

function ProceduralSeedTracker:NormalizeSeed(seed)
    seed = tonumber(seed)
    if not seed then
        return 0
    end

    return Utility.ConvertToU32(math.floor(seed))
end

function ProceduralSeedTracker:UpdateProceduralSeeds()
    local savedSeeds = self.ModSave:GetProceduralSeeds()
    if type(savedSeeds) == "table" then
        for rawID, seeds in pairs(savedSeeds) do
            local itemId = Utility.ConvertToID32(rawID)
            if itemId
                and itemId < 0
                and itemId >= -1024
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

                self.ItemIDToSeeds[itemId] = itemSeeds
            end
        end
    end
end

function ProceduralSeedTracker:Initialize(mod)
    self.ModSave = mod.ModSave
    self.RunSeed = self:NormalizeSeed(self.ModSave:GetRunSeed())
    self.ItemIDToSeeds = {}
    self.SeedSources = {}
    self.PendingSeeds = {}
    self.RerollWindows = {}

    self:UpdateProceduralSeeds()
end

function ProceduralSeedTracker:GetCurrentRunSeed()
    return self:NormalizeSeed(game:GetSeeds():GetStartSeed())
end

function ProceduralSeedTracker:GetNextSelectionSeed(seed)
    seed = Utility.ConvertToU32(seed)
    seed = Utility.ConvertToU32(seed ~ (seed >> 5))
    seed = Utility.ConvertToU32(seed ~ (seed << 9))
    return Utility.ConvertToU32(seed ~ (seed >> 7))
end

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

function ProceduralSeedTracker:GetSeed(id)
    id = Utility.ConvertToID32(id)

    local itemProceduralSeeds = self.ItemIDToSeeds[id]
    if not itemProceduralSeeds
        or #itemProceduralSeeds < 1
    then
        return nil
    end

    local candidateSeeds = {}
    local visitedSeeds = {}
    for _, seed in ipairs(itemProceduralSeeds) do
        if not visitedSeeds[seed] then
            candidateSeeds[#candidateSeeds + 1] = seed
            visitedSeeds[seed] = true
        end
    end

    if not self.SeedSources[id] then
        self.SeedSources[id] = {}
    end

    for steps = 1, 2 do
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

function ProceduralSeedTracker:SetSeed(id, seed, source)
    local function appendSeed(seedMap)
        if not seedMap[id] then
            seedMap[id] = {}
        end

        local length = seedMap[id]
        if length >= 8 then
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
        or id < -1024
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
        self.PendingSeeds = {}
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

    appendSeed(self.PendingSeeds)
    if appendSeed(self.ItemIDToSeeds) then
        self:Save()
    end
end

function ProceduralSeedTracker:OnPostGetCollectible(
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

function ProceduralSeedTracker:OnPostPickupUpdate(pickup, phase)
    if not pickup
        or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE
    then
        return
    end

    local id = Utility.ConvertToID32(pickup.SubType)
    if id >= 0
        or id < -1024
    then
        return
    end

    if not phase then
        phase = "update"
    end

    local data = pickup:GetData()
    local key = "MSD4RTMObservedID_" .. phase
    if data[key] == id then
        return
    end

    data[key] = id
    self:SetSeed(
        id,
        pickup.DropSeed,
        phase .. ".DropSeed"
    )

    local rng = pickup:GetDropRNG()
    if rng then
        self:SetSeed(
            id,
            rng:GetSeed(),
            phase .. ".GetDropRNG"
        )
    end
end

-- Only read the engine RNG. Next/SetSeed below are called on a fresh copy.
-- Key by player pointer; stacks keep nested uses and co-op players separate.
function ProceduralSeedTracker:OnPreUseD4(rng, player)
    if not ProceduralItemManager
        or not player
        or not rng
    then
        return
    end

    local shift = rng:GetShiftIdx()
    if not shift then
        Isaac.DebugString("[MSD4R] D4 RNG shift index is unavailable.\n")
        return
    end

    local window = {
        Seed = rng:GetSeed(),
        Shift = shift,
        Count = ProceduralItemManager.GetProceduralItemCount(),
        Run = self:GetCurrentRunSeed(),
        Frame = game:GetFrameCount(),
        Player = player
    }
    local key = GetPtrHash(player)

    if not self.RerollWindows[key]
        or (self.RerollWindows[key][1]
            and self.RerollWindows[key][1].Frame ~= window.Frame)
    then
        self.RerollWindows[key] = {}
    end

    self.RerollWindows[key][#self.RerollWindows[key] + 1] = window
end

function ProceduralSeedTracker:MatchCreationSeeds(
    firstIndex,
    lastIndex,
    seeds
)
    local pendingItems = {}
    local matchedSeeds = {}

    for index = firstIndex, lastIndex - 1 do
        local id = -index - 1
        local item = Utility.GetRawProceduralItem(id)
        if item then
            pendingItems[#pendingItems + 1] = {
                ID = id,
                Snapshot = ReplayController:GetSnapshot(item)
            }
        end
    end

    if #pendingItems == 0 then
        return matchedSeeds
    end

    local env = ReplayController:BuildEnvironment()

    for _, seed in ipairs(seeds) do
        local replayResult = ReplayController:Replay(
            seed,
            env,
            0
        )

        for i, entry in ipairs(pendingItems) do
            local valid, _, _ = ReplayController:ValidateSnapshot(
                replayResult,
                entry.Snapshot
            )

            if valid then
                matchedSeeds[#matchedSeeds + 1] = {
                    ID = entry.ID,
                    Seed = seed
                }
                table.remove(pendingItems, i)

                break
            end
        end

        if #pendingItems == 0 then
            break
        end
    end

    return matchedSeeds
end

function ProceduralSeedTracker:FinishD4(window, rng)
    if window.Run ~= self:GetCurrentRunSeed() then
        return
    end

    local count = ProceduralItemManager.GetProceduralItemCount()
    if count <= window.Count then
        return
    end

    local seeds = {}
    local terminalSeed = rng:GetSeed()
    local replicatedRNG = RNG()
    replicatedRNG:SetSeed(window.Seed, window.Shift)

    while replicatedRNG:GetSeed() ~= terminalSeed
        and #seeds < 16384
    do
        seeds[#seeds + 1] = replicatedRNG:Next()
    end

    if replicatedRNG:GetSeed() ~= terminalSeed then
        Isaac.DebugString("D4 RNG window exceeded limit or was reset.")
        return
    end

    local matchResult = self:MatchCreationSeeds(
        window.Count,
        count,
        seeds
    )
    for _, matchItem in ipairs(matchResult) do
        self:SetSeed(
            matchItem.ID,
            matchItem.Seed,
            "D4.RNGWindow.validated"
        )
    end

    Isaac.DebugString(string.format(
        "D4 captured=%d/%d rngSteps=%d ids=%d..%d",
        #matchResult,
        count - window.Count,
        #seeds,
        -window.Count - 1,
        -count
    ))
end

function ProceduralSeedTracker:OnPostUseD4(rng, player)
    local key = GetPtrHash(player)

    if not self.RerollWindows[key]
        or #self.RerollWindows[key] == 0
    then
        return
    end

    local window = table.remove(self.RerollWindows[key])

    self:FinishD4(window, rng)
end

function ProceduralSeedTracker:OnRerollUpdate()
    local windows = self.RerollWindows

    self.RerollWindows = {}

    for _, stack in pairs(windows) do
        for i = #stack, 1, -1 do
            local window = stack[i]
            if window.Run == self:GetCurrentRunSeed()
                and window.Player:Exists()
            then
                self:FinishD4(
                    window,
                    window.Player:GetCollectibleRNG(
                        CollectibleType.COLLECTIBLE_D4
                    )
                )
            end
        end
    end
end

function ProceduralSeedTracker:Clear()
    self.ItemIDToSeeds = {}
    self.SeedSources = {}
    self.PendingSeeds = {}
    self.RerollWindows = {}
end

function ProceduralSeedTracker:OnPostGameStarted(isContinued)
    local run = self:GetCurrentRunSeed()
    self.RerollWindows = {}

    if not isContinued
        or self.RunSeed ~= run
    then
        self.ItemIDToSeeds = self.PendingSeeds
    end

    self.RunSeed = run
    self.PendingSeeds = {}
    self:Save()
end

function ProceduralSeedTracker:OnPreGameExit()
    self:Save()
    self.PendingSeeds = {}
    self.RerollWindows = {}
end

return ProceduralSeedTracker
