local MSD4R = RegisterMod("My Stuff Descriptions for Repentogon", 1)

local ModSave = include("scripts/mod_save")
local PauseMenuController = include("scripts/pause_menu_controller")
local ProceduralSeedTracker = include("scripts/procedural_seed_tracker")
local Renderer = include("scripts/renderer")

local EID_MOD_ID = "836319872"
local ModConfig = include("scripts/mod_config")
local game = Game()

function MSD4R:OnModsLoaded()
    if not PauseMenu
        or not XMLData
        or not Isaac.RenderCollectionItem
        or not ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER
        or not ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER
    then
        self.Enabled = false
        Isaac.ConsoleOutput("[MSD4R] REPENTOGON API is unavailable.\n")

        return
    end

    local eidMetadata = XMLData.GetModById(EID_MOD_ID)
    if not eidMetadata
        or not EID
    then
        self.Enabled = false
        Isaac.ConsoleOutput("[MSD4R] EID API is unavailable.\n")

        return
    end

    self.EID = EID
    self.Enabled = true
    self.ModSave = ModSave

    ModSave:Initialize(self)
    ModConfig:Initialize(ModSave)
    Renderer:Initialize(self)
    ProceduralSeedTracker:Initialize(self)
    PauseMenuController:Initialize(self, Renderer, ProceduralSeedTracker)

    Isaac.ConsoleOutput("[MSD4R] Initialized successfully.\n")
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_MODS_LOADED,
    MSD4R.OnModsLoaded
)

function MSD4R:OnPrePauseScreenRender(
    pauseBody,
    pauseStats
)
    if not self.Enabled then
        return
    end

    PauseMenuController:OnPrePauseScreenRender(
        pauseBody,
        pauseStats
    )
end

MSD4R:AddCallback(
    ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER,
    MSD4R.OnPrePauseScreenRender
)

function MSD4R:OnPostPauseScreenRender(
    pauseBody,
    pauseStats
)
    if not self.Enabled then
        return
    end

    PauseMenuController:OnPostPauseScreenRender(
        pauseBody,
        pauseStats
    )
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER,
    MSD4R.OnPostPauseScreenRender
)

function MSD4R:OnPostRender()
    if not self.Enabled then
        return
    end

    PauseMenuController:OnPostRender()
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_RENDER,
    MSD4R.OnPostRender
)

function MSD4R:OnPrePlayerHUDTrinketRender(
    slot,
    position,
    scale,
    player,
    cropOffset
)
    --[[
    Smelted trinkets are rendered in My Stuff page through this function.
    Returns true to cancel rendering.
    ]]
    if not game:IsPauseMenuOpen() then
        return false
    end

    return true
end

MSD4R:AddCallback(
    ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER,
    MSD4R.OnPrePlayerHUDTrinketRender
)

function MSD4R:OnPostPickupInit(pickup)
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPostPickupUpdate(pickup, 'init')
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_PICKUP_INIT,
    MSD4R.OnPostPickupInit,
    PickupVariant.PICKUP_COLLECTIBLE
)

function MSD4R:OnPostPickupUpdate(pickup)
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPostPickupUpdate(pickup)
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_PICKUP_UPDATE,
    MSD4R.OnPostPickupUpdate,
    PickupVariant.PICKUP_COLLECTIBLE
)

function MSD4R:OnPostGetCollectible(
    selected,
    pool,
    decrease,
    seed
)
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPostGetCollectible(
        selected,
        pool,
        decrease,
        seed
    )
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_GET_COLLECTIBLE,
    MSD4R.OnPostGetCollectible
)

function MSD4R:OnPreUseItem(item, rng, player)
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPreUseD4(rng, player)
end

MSD4R:AddCallback(
    ModCallbacks.MC_PRE_USE_ITEM,
    MSD4R.OnPreUseItem,
    CollectibleType.COLLECTIBLE_D4
)

function MSD4R:OnPostUseItem(item, rng, player)
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPostUseD4(rng, player)
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_USE_ITEM,
    MSD4R.OnPostUseItem,
    CollectibleType.COLLECTIBLE_D4
)

function MSD4R:OnPostUpdate()
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnRerollUpdate()
end

if not ModCallbacks.MC_POST_USE_ITEM then
    MSD4R:AddCallback(
        ModCallbacks.MC_POST_UPDATE,
        MSD4R.OnPostUpdate
    )
end

function MSD4R:OnPostGameStarted(isContinued)
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPostGameStarted(isContinued)
    Renderer.GlitchedItemRenderer:Reset()
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_GAME_STARTED,
    MSD4R.OnPostGameStarted
)

function MSD4R:OnPreGameExit()
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPreGameExit()
end

MSD4R:AddCallback(
    ModCallbacks.MC_PRE_GAME_EXIT,
    MSD4R.OnPreGameExit
)

function MSD4R:OnExecuteCommand(command, params)
    if not self.Enabled then
        return
    end

    local function diagnostic(id, seeds, flags, kind)
        local r = Renderer.GlitchedItemRenderer
        r:Reset()
        local context = {
            Kind = kind,
            RunSeed = ProceduralSeedTracker:GetCurrentRunSeed(),
            SeedSources = ProceduralSeedTracker.SoSeedSourcesurces
                and ProceduralSeedTracker.SeedSources[id]
                or {}
        }

        Isaac.ConsoleOutput(r:Describe(id, seeds, flags, context) .. "\n")
    end

    if command == "msd_tm_probe" then
        local seed = tonumber(params:match("^%s*(%d+)%s*$"))
        if not seed or seed < 2 or seed > 0xffffffff or seed % 1 ~= 0 then
            Isaac.ConsoleOutput("Usage: msd_tm_probe 123456789 (creates one diagnostic item config, flags=0)\n")
            return
        end
        if not ProceduralItemManager or ProceduralItemManager.GetProceduralItemCount() >= 1024 then
            Isaac.ConsoleOutput("Procedural item manager unavailable or at capacity.\n")
            return
        end
        local ok, id = pcall(ProceduralItemManager.CreateProceduralItem, seed, 0)
        if not ok then
            Isaac.ConsoleOutput("Native probe failed: " .. tostring(id) .. "\n"); return
        end
        if id >= 0x80000000 then id = id - 0x100000000 end
        if id >= 0 then
            Isaac.ConsoleOutput("Native probe did not return a procedural item ID.\n"); return
        end
        ProceduralSeedTracker:SetSeed(id, seed, 'probe.CreateProceduralItem(seed,0)')
        diagnostic(id, { seed }, 0, 'fixed-seed-native-probe')
        return
    end

    if command == "msd_tm" then
        local id, seed = params:match("^%s*(-?%d+)%s*(%d*)%s*$")
        id = tonumber(id)
        seed = tonumber(seed)
        if not id or id >= 0 then
            Isaac.ConsoleOutput("Usage: msd_tm -1 [known_creation_seed]\n")
            return
        end
        if seed then ProceduralSeedTracker:SetSeed(id, seed, 'msd_tm.explicit') end
        diagnostic(id, seed and { seed } or ProceduralSeedTracker:GetSeed(id), nil, 'existing-item')
        return
    end

    PauseMenuController:OnExecuteCommand(command, params)
end

MSD4R:AddCallback(
    ModCallbacks.MC_EXECUTE_CMD,
    MSD4R.OnExecuteCommand
)

return MSD4R
