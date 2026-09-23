local ProceduralSeedTracker = {}
local MAGIC_CONST = include("scripts/magic_const")
local Utility = include("scripts/utility")
local game = Game()

function ProceduralSeedTracker:NormalizeSeed(seed)
    seed = tonumber(seed)
    if not seed then
        return 0
    end

    seed = math.floor(seed)
    if seed < 0 then
        seed = seed + 0x100000000
    end

    return Utility.ConvertToU32(seed)
end

function ProceduralSeedTracker:Initialize(mod)
    self.Mod = mod
    self.ModSave = mod.ModSave
    self.ItemIDToSeed = {}
    self.RunSeed = self:NormalizeSeed(self.ModSave:GetRunSeed())

    local savedSeeds = self.ModSave:GetSeeds()
    if type(savedSeeds) ~= "table" then
        return
    end

    for rawItemID, rawSeed in pairs(savedSeeds) do
        local itemID = tonumber(rawItemID)
        local seed = self:NormalizeSeed(rawSeed)

        if itemID
            and itemID < 0
            and seed
        then
            self.ItemIDToSeed[itemID] = seed
        end
    end
end

function ProceduralSeedTracker:GetCurrentRunSeed()
    local seeds = game:GetSeeds()

    if not seeds then
        return 0
    end

    return self:NormalizeSeed(seeds:GetStartSeed())
end

function ProceduralSeedTracker:Save()
    local seeds = {}
    for itemID, seed in pairs(self.ItemIDToSeed) do
        seeds[tostring(itemID)] = seed
    end

    self.ModSave:Set("RunSeed", self.RunSeed)
    self.ModSave:Set("Seeds", seeds)
end

function ProceduralSeedTracker:GetSeed(itemID)
    if itemID >= 0 then
        return self.RunSeed
    end

    local seed = self.ItemIDToSeed[itemID]

    if not seed then
        return self.RunSeed
    end

    return seed
end

function ProceduralSeedTracker:SetSeed(itemID, seed)
    if itemID >= 0 then
        return
    end

    seed = self:NormalizeSeed(seed)

    if not seed
        or seed == 0
        or self.ItemIDToSeed[itemID] == seed
    then
        return
    end

    self.ItemIDToSeed[itemID] = seed
    self:Save()
end

function ProceduralSeedTracker:Clear()
    self.ItemIDToSeed = {}
end

function ProceduralSeedTracker:OnPostPickupUpdate(pickup)
    if not pickup
        or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE
        or (MAGIC_CONST.GLITCHED_ITEM_MASK - pickup.SubType)
        > 1024
    then
        return
    end

    local itemID = pickup.SubType - MAGIC_CONST.GLITCHED_ITEM_MASK
    local seed = pickup.DropSeed
    if not seed then
        local rng = pickup:GetDropRNG()
        if rng then
            seed = rng:GetSeed()
        end
    end

    self:SetSeed(itemID, seed)

    Isaac.ConsoleOutput(string.format(
        "[MSD4R] pickup: %d, seed: %d\n",
        itemID,
        seed
    ))
end

function ProceduralSeedTracker:OnPostGameStarted(isContinued)
    local runSeed = self:GetCurrentRunSeed()

    if not isContinued
        or self.RunSeed ~= runSeed
    then
        self:Clear()
    end

    self.RunSeed = runSeed
    self:Save()
end

return ProceduralSeedTracker
