---@type MSD4RUtility
local Utility = include("scripts/utility")

---@class MSD4RMod: ModReference
---@field Enabled boolean
---@field GlitchedRenderingAvailable boolean
---@field EID MSD4REID
---@field ModSave MSD4RModSave
local MSD4R = RegisterMod("My Stuff Descriptions for Repentogon", 1)

---@type MSD4RCoreAPI
local CoreAPI = include("scripts/core_api")
---@type MSD4RModSave
local ModSave = include("scripts/mod_save")
---@type MSD4RPauseMenuController
local PauseMenuController = include("scripts/pause_menu_controller")
---@type MSD4RProceduralSeedTracker
local ProceduralSeedTracker = include("scripts/procedural_seed_tracker")
---@type MSD4RRenderer
local Renderer = include("scripts/renderer")

---@type string
local EID_MOD_ID = "836319872"
---@type MSD4RModConfig
local ModConfig = include("scripts/mod_config")
---@type Game
local game = Game()

MSD4R.Enabled = false
MSD4R.GlitchedRenderingAvailable = false

---@param callbackID? integer
---@param callback function
---@param filter? integer
---@return nil # No return value.
function MSD4R:RegisterAvailableCallback(
    callbackID,
    callback,
    filter
)
    if type(callbackID) ~= "number" then
        return
    end

    self:AddCallback(callbackID, callback, filter)
end

---@param pauseBody? Sprite
---@param pauseStats? Sprite
---@return boolean result1
function MSD4R:CheckRuntimeAPIs(pauseBody, pauseStats)
    local coreAvailable, missingAPIs = CoreAPI:CheckCoreRuntime(
        game,
        pauseBody,
        pauseStats
    )

    if not coreAvailable then
        self.Enabled = false
        CoreAPI:ReportUnavailable("Core", missingAPIs)
    end

    return coreAvailable
end

---@return nil # No return value.
function MSD4R:OnModsLoaded()
    self.Enabled = false
    self.GlitchedRenderingAvailable = false

    CoreAPI:Initialize()

    local coreAvailable, missingAPIs = CoreAPI:CheckCore(
        self,
        game,
        EID
    )

    if not coreAvailable then
        CoreAPI:ReportUnavailable("Core", missingAPIs)

        return
    end

    local eidMetadata = XMLData.GetModById(EID_MOD_ID)

    if not eidMetadata
        or not EID
    then
        self.Enabled = false
        Utility.Log("EID API is unavailable.")

        return
    end

    self.EID = EID
    self.ModSave = ModSave

    ModSave:Initialize(self)
    ModConfig:Initialize(ModSave)
    Renderer:Initialize(self)
    self.GlitchedRenderingAvailable =
        Renderer.GlitchedItemRenderer.Initialized == true

    if self.GlitchedRenderingAvailable then
        ProceduralSeedTracker:Initialize(self)
    else
        ProceduralSeedTracker:Clear()
    end

    PauseMenuController:Initialize(
        self,
        Renderer,
        ProceduralSeedTracker
    )

    self.Enabled = true
    Utility.Log("Initialized successfully.")
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_MODS_LOADED,
    MSD4R.OnModsLoaded
)

---@param pauseBody? Sprite
---@param pauseStats? Sprite
---@return nil # No return value.
function MSD4R:OnPrePauseScreenRender(
    pauseBody,
    pauseStats
)
    if not self.Enabled
        or not self:CheckRuntimeAPIs(pauseBody, pauseStats)
    then
        return
    end

    PauseMenuController:OnPrePauseScreenRender(
        pauseBody,
        pauseStats
    )
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER,
    MSD4R.OnPrePauseScreenRender
)

---@param pauseBody? Sprite
---@param pauseStats? Sprite
---@return nil # No return value.
function MSD4R:OnPostPauseScreenRender(
    pauseBody,
    pauseStats
)
    if not self.Enabled or
        not self:CheckRuntimeAPIs(pauseBody, pauseStats)
    then
        return
    end

    PauseMenuController:OnPostPauseScreenRender(
        pauseBody,
        pauseStats
    )
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER,
    MSD4R.OnPostPauseScreenRender
)

---@return nil # No return value.
function MSD4R:OnPostRender()
    if not self.Enabled then
        return
    end

    PauseMenuController:OnPostRender()
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_RENDER,
    MSD4R.OnPostRender
)

---@param slot integer
---@param position Vector
---@param scale Vector
---@param player EntityPlayer
---@param cropOffset Vector
---@return boolean result1
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
    if not self.Enabled or
        not game:IsPauseMenuOpen()
    then
        return false
    end

    return true
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_PRE_PLAYERHUD_TRINKET_RENDER,
    MSD4R.OnPrePlayerHUDTrinketRender
)

---@param pickup EntityPickup
---@return nil # No return value.
function MSD4R:OnPostPickupInit(pickup)
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnPostPickupUpdate(pickup, 'init')
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_PICKUP_INIT,
    MSD4R.OnPostPickupInit,
    PickupVariant.PICKUP_COLLECTIBLE
)

---@param pickup EntityPickup
---@return nil # No return value.
function MSD4R:OnPostPickupUpdate(pickup)
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnPostPickupUpdate(pickup)
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_PICKUP_UPDATE,
    MSD4R.OnPostPickupUpdate,
    PickupVariant.PICKUP_COLLECTIBLE
)

---@param selected integer
---@param pool integer
---@param decrease boolean
---@param seed integer
---@return nil # No return value.
function MSD4R:OnPostGetCollectible(
    selected,
    pool,
    decrease,
    seed
)
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnPostGetCollectible(
        selected,
        pool,
        decrease,
        seed
    )
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_GET_COLLECTIBLE,
    MSD4R.OnPostGetCollectible
)

---@param item integer
---@param rng RNG
---@param player EntityPlayer
---@return nil # No return value.
function MSD4R:OnPreUseItem(item, rng, player)
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnPreUseD4(rng, player)
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_PRE_USE_ITEM,
    MSD4R.OnPreUseItem,
    CollectibleType.COLLECTIBLE_D4
)

---@param item integer
---@param rng RNG
---@param player EntityPlayer
---@return nil # No return value.
function MSD4R:OnPostUseItem(item, rng, player)
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnPostUseD4(rng, player)
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_USE_ITEM,
    MSD4R.OnPostUseItem,
    CollectibleType.COLLECTIBLE_D4
)

---@return nil # No return value.
function MSD4R:OnPostUpdate()
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnRerollUpdate()
end

if not ModCallbacks.MC_POST_USE_ITEM then
    MSD4R:RegisterAvailableCallback(
        ModCallbacks.MC_POST_UPDATE,
        MSD4R.OnPostUpdate
    )
end

---@param isContinued boolean
---@return nil # No return value.
function MSD4R:OnPostGameStarted(isContinued)
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnPostGameStarted(isContinued)
    Renderer.GlitchedItemRenderer:Reset()
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_POST_GAME_STARTED,
    MSD4R.OnPostGameStarted
)

---@return nil # No return value.
function MSD4R:OnPreGameExit()
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    ProceduralSeedTracker:OnPreGameExit()
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_PRE_GAME_EXIT,
    MSD4R.OnPreGameExit
)

---@param command string
---@param params string
---@return nil # No return value.
function MSD4R:OnExecuteCommand(command, params)
    if not self.Enabled or
        not self.GlitchedRenderingAvailable
    then
        return
    end

    if command == "msd4r_tm" then
        local itemID = params:match("^%s*(-?%d+)%s*$")
        itemID = tonumber(itemID)

        if not itemID
            or itemID >= 0
        then
            Utility.Log("Usage: msd4r_tm <glitched item id>.")

            return
        end

        local seedSources = {}

        if ProceduralSeedTracker.SeedSources
            and ProceduralSeedTracker.SeedSources[itemID]
        then
            seedSources = ProceduralSeedTracker.SeedSources[itemID]
        end

        Renderer.GlitchedItemRenderer:Reset()
        Utility.Log(
            Renderer.GlitchedItemRenderer:WriteLog(
                itemID,
                ProceduralSeedTracker:GetSeed(itemID),
                nil,
                {
                    Kind = 'existing-item',
                    RunSeed = ProceduralSeedTracker:GetCurrentRunSeed(),
                    SeedSources = seedSources
                }
            )
        )

        return
    end
end

MSD4R:RegisterAvailableCallback(
    ModCallbacks.MC_EXECUTE_CMD,
    MSD4R.OnExecuteCommand
)

if type(ModCallbacks.MC_POST_MODS_LOADED) ~= "number" then
    CoreAPI:ReportUnavailable(
        "Core",
        { "ModCallbacks.MC_POST_MODS_LOADED" }
    )
end

---@type MSD4RMod
return MSD4R
