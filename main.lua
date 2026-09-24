local MSD4R = RegisterMod(
    "My Stuff Descriptions for Repentogon",
    1
)
local EID_MOD_ID = "836319872"
local ModConfig = include("scripts/mod_config")
local ModSave = include("scripts/mod_save")
local PauseMenuController = include("scripts/pause_menu_controller")
local ProceduralSeedTracker = include("scripts/procedural_seed_tracker")
local Renderer = include("scripts/renderer")
local game = Game()

MSD4R.Enabled = false
MSD4R.EID = nil
MSD4R.ModSave = ModSave

function MSD4R:OnModsLoaded()
    if PauseMenu == nil
        or XMLData == nil
        or Isaac.RenderCollectionItem == nil
        or ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER == nil
        or ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER == nil
    then
        self.Enabled = false
        Isaac.ConsoleOutput("[MSD4R] REPENTOGON API is unavailable.\n")

        return
    end

    local eidMetadata = XMLData.GetModById(EID_MOD_ID)

    if eidMetadata == nil or EID == nil then
        self.Enabled = false
        Isaac.ConsoleOutput("[MSD4R] EID API is unavailable.\n")

        return
    end

    self.EID = EID
    self.Enabled = true

    ModSave:Initialize(self)
    ModConfig:Initialize(ModSave)
    Renderer:Initialize(self)
    ProceduralSeedTracker:Initialize(self)
    PauseMenuController:Initialize(self, Renderer, ProceduralSeedTracker)

    Isaac.ConsoleOutput("[MSD4R] Initialized successfully.\n")
end

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

function MSD4R:OnPostRender()
    if not self.Enabled then
        return
    end

    PauseMenuController:OnPostRender()
end

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

function MSD4R:OnPostPickupUpdate(pickup)
    ProceduralSeedTracker:OnPostPickupUpdate(pickup)
end

function MSD4R:OnPostGetCollectible(
    selectedCollectible,
    itemPoolType,
    decrease,
    seed
)
    if not self.Enabled then
        return
    end

    ProceduralSeedTracker:OnPostGetCollectible(
        selectedCollectible,
        itemPoolType,
        decrease,
        seed
    )
end

function MSD4R:OnPostGameStarted(isContinued)
    ProceduralSeedTracker:OnPostGameStarted(isContinued)
end

function MSD4R:OnExecuteCommand(
    command,
    params
)
    if not self.Enabled then
        return
    end

    PauseMenuController:OnExecuteCommand(
        command,
        params
    )
end

MSD4R:AddCallback(
    ModCallbacks.MC_POST_MODS_LOADED,
    MSD4R.OnModsLoaded
)

MSD4R:AddCallback(
    ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER,
    MSD4R.OnPrePauseScreenRender
)

MSD4R:AddCallback(
    ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER,
    MSD4R.OnPostPauseScreenRender
)

MSD4R:AddCallback(
    ModCallbacks.MC_POST_RENDER,
    MSD4R.OnPostRender
)

MSD4R:AddCallback(
    ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER,
    MSD4R.OnPrePlayerHUDTrinketRender
)

MSD4R:AddCallback(
    ModCallbacks.MC_POST_PICKUP_UPDATE,
    MSD4R.OnPostPickupUpdate,
    PickupVariant.PICKUP_COLLECTIBLE
)

MSD4R:AddCallback(
    ModCallbacks.MC_POST_GET_COLLECTIBLE,
    MSD4R.OnPostGetCollectible
)

MSD4R:AddCallback(
    ModCallbacks.MC_POST_GAME_STARTED,
    MSD4R.OnPostGameStarted
)

MSD4R:AddCallback(
    ModCallbacks.MC_EXECUTE_CMD,
    MSD4R.OnExecuteCommand
)

return MSD4R
