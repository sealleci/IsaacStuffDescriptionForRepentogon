local MSD4R = RegisterMod(
    "My Stuff Descriptions for Repentogon",
    1
)

local EID_MOD_ID = "836319872"
local Renderer = include("scripts/renderer")
local PauseMenuController = include("scripts/pause_menu_controller")
local Settings = include("scripts/settings")
local ModConfig = include("scripts/mod_config")

MSD4R.Enabled = false
MSD4R.EID = nil
MSD4R.Settings = Settings

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

    Settings:Initialize(self)
    Renderer:Initialize(self)
    PauseMenuController:Initialize(self, Renderer)
    ModConfig:Initialize(Settings)

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
    if not Game():IsPauseMenuOpen() then
        return false
    end

    return true
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
    ModCallbacks.MC_EXECUTE_CMD,
    MSD4R.OnExecuteCommand
)

return MSD4R
