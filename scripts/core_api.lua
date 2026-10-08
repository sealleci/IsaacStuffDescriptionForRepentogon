---@class MSD4RCoreAPI
---@field CheckedCoreInstances table<string, boolean>
---@field ReportedMissingAPIs table<string, boolean>
---@field Initialized boolean?
local CoreAPI = {}

---@type MSD4RUtility
local Utility = include("scripts/utility")

---@type MSD4RCoreAPIConfig
local CONFIG = {
    EID_MOD_ID = "836319872",
    SPRITE_METHODS = {
        "Load",
        "Play",
        "SetFrame",
        "GetAnimation",
        "GetLayer",
        "GetAllLayers",
        "GetAnimationData",
        "GetLayerFrameData",
        "ReplaceSpritesheet",
        "LoadGraphics",
        "RenderLayer"
    }
}

---@return nil # No return value.
function CoreAPI:Initialize()
    if self.Initialized then
        return
    end

    self.CheckedCoreInstances = {}
    self.ReportedMissingAPIs = {}
    self.Initialized = true
end

---@param object any
---@param memberName string
---@return any result1
function CoreAPI:GetMember(object, memberName)
    if object == nil then
        return nil
    end

    local successful, memberValue = pcall(
    ---@return any result1
        function()
            return object[memberName]
        end
    )

    if successful then
        return memberValue
    end

    return nil
end

---@param missingAPIs string[]
---@param objectName string
---@param object any
---@param methodNames string[]
---@return boolean result1
function CoreAPI:CheckMethods(
    missingAPIs,
    objectName,
    object,
    methodNames
)
    local allMethodsAvailable = true

    for _, methodName in ipairs(methodNames) do
        if type(self:GetMember(object, methodName)) ~= "function" then
            missingAPIs[#missingAPIs + 1] = string.format(
                "%s.%s",
                objectName,
                methodName
            )
            allMethodsAvailable = false
        end
    end

    return allMethodsAvailable
end

---@param missingAPIs string[]
---@param objectName string
---@param object any
---@param constantNames string[]
---@return nil # No return value.
function CoreAPI:CheckConstants(
    missingAPIs,
    objectName,
    object,
    constantNames
)
    for _, constantName in ipairs(constantNames) do
        if type(self:GetMember(object, constantName)) ~= "number" then
            missingAPIs[#missingAPIs + 1] = string.format(
                "%s.%s",
                objectName,
                constantName
            )
        end
    end
end

---@param featureName string
---@param missingAPIs string[]
---@return nil # No return value.
function CoreAPI:ReportUnavailable(featureName, missingAPIs)
    if self.ReportedMissingAPIs[featureName] then
        return
    end

    Utility.Log(string.format(
        "%s APIs are unavailable: %s.",
        featureName,
        table.concat(missingAPIs, ", ")
    ))
    self.ReportedMissingAPIs[featureName] = true
end

---@param mod MSD4RMod
---@param game Game
---@param eid? MSD4REID
---@return boolean available
---@return string[] missingAPIs
function CoreAPI:CheckCore(mod, game, eid)
    local missingAPIs = {}

    self:CheckMethods(
        missingAPIs,
        "Mod",
        mod,
        { "AddCallback" }
    )
    self:CheckMethods(
        missingAPIs,
        "PauseMenu",
        PauseMenu,
        {
            "GetState",
            "GetSelectedElement",
            "SetSelectedElement",
            "GetSprite",
            "GetStatsSprite",
            "GetMyStuffSprite"
        }
    )

    if self:CheckMethods(
            missingAPIs,
            "XMLData",
            XMLData,
            { "GetModById" }
        ) then
        local eidMetadata = XMLData.GetModById(CONFIG.EID_MOD_ID)

        if not eidMetadata then
            missingAPIs[#missingAPIs + 1] = "EID mod metadata"
        end
    end

    self:CheckMethods(
        missingAPIs,
        "Isaac",
        Isaac,
        {
            "RenderCollectionItem",
            "GetScreenWidth",
            "GetScreenHeight",
            "DrawQuad",
            "GetPlayer"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "Input",
        Input,
        { "IsActionTriggered" }
    )
    self:CheckMethods(
        missingAPIs,
        "Game",
        game,
        {
            "IsPauseMenuOpen",
            "GetNumPlayers"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "EID",
        eid,
        {
            "getDescriptionObj",
            "getNameColor",
            "renderString",
            "printBulletPoints"
        }
    )

    for _, fieldName in ipairs({ "Scale", "lineHeight" }) do
        if type(self:GetMember(eid, fieldName)) ~= "number" then
            missingAPIs[#missingAPIs + 1] = "EID." .. fieldName
        end
    end

    if type(self:GetMember(eid, "Config")) ~= "table" then
        missingAPIs[#missingAPIs + 1] = "EID.Config"
    end

    local spriteCreated, sprite = pcall(
    ---@return Sprite result1
        function()
            return Sprite()
        end
    )

    self:CheckMethods(
        missingAPIs,
        "Sprite",
        spriteCreated and sprite or nil,
        CONFIG.SPRITE_METHODS
    )

    for _, constructorName in ipairs({ "Color", "KColor" }) do
        local constructorAvailable = pcall(
        ---@return Color|KColor result1
            function()
                return _G[constructorName](1, 1, 1, 1)
            end
        )

        if not constructorAvailable then
            missingAPIs[#missingAPIs + 1] = constructorName
        end
    end

    self:CheckConstants(
        missingAPIs,
        "ModCallbacks",
        ModCallbacks,
        {
            "MC_POST_MODS_LOADED",
            "MC_PRE_PAUSE_SCREEN_RENDER",
            "MC_POST_PAUSE_SCREEN_RENDER",
            "MC_POST_RENDER",
            "MC_PRE_PLAYERHUD_TRINKET_RENDER"
        }
    )
    self:CheckConstants(
        missingAPIs,
        "PauseMenuStates",
        PauseMenuStates,
        { "OPTIONS" }
    )
    self:CheckConstants(
        missingAPIs,
        "ButtonAction",
        ButtonAction,
        {
            "ACTION_MENULEFT",
            "ACTION_MENURIGHT",
            "ACTION_MENUUP",
            "ACTION_MENUDOWN"
        }
    )
    self:CheckConstants(
        missingAPIs,
        "TrinketType",
        TrinketType,
        {
            "TRINKET_NULL",
            "TRINKET_ID_MASK",
            "NUM_TRINKETS"
        }
    )
    self:CheckConstants(
        missingAPIs,
        "PickupVariant",
        PickupVariant,
        {
            "PICKUP_COLLECTIBLE",
            "PICKUP_TRINKET"
        }
    )
    self:CheckConstants(
        missingAPIs,
        "EntityType",
        EntityType,
        { "ENTITY_PICKUP" }
    )

    return #missingAPIs == 0, missingAPIs
end

---@param missingAPIs string[]
---@param objectName string
---@param object any
---@param methodNames string[]
---@return boolean result1
function CoreAPI:CheckCoreInstance(
    missingAPIs,
    objectName,
    object,
    methodNames
)
    if object == nil then
        return false
    end

    if self.CheckedCoreInstances[objectName] then
        return true
    end

    if self:CheckMethods(
            missingAPIs,
            objectName,
            object,
            methodNames
        ) then
        self.CheckedCoreInstances[objectName] = true

        return true
    end

    return false
end

---@param missingAPIs string[]
---@param game Game
---@param pauseBody? Sprite
---@param pauseStats? Sprite
---@return nil # No return value.
function CoreAPI:InspectCoreRuntime(
    missingAPIs,
    game,
    pauseBody,
    pauseStats
)
    for playerIndex = 0, game:GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(playerIndex)

        if self:CheckCoreInstance(
                missingAPIs,
                "EntityPlayer",
                player,
                {
                    "GetHistory",
                    "GetMaxTrinkets",
                    "GetTrinket",
                    "GetPlayerType"
                }
            ) then
            if type(player.ControllerIndex) ~= "number" then
                missingAPIs[#missingAPIs + 1] = "EntityPlayer.ControllerIndex"
            end

            local history = player:GetHistory()

            if self:CheckCoreInstance(
                    missingAPIs,
                    "History",
                    history,
                    { "GetCollectiblesHistory" }
                ) then
                local historyItems = history:GetCollectiblesHistory()

                if type(historyItems) ~= "table" then
                    missingAPIs[#missingAPIs + 1] = "History.GetCollectiblesHistory result"
                elseif historyItems[1] then
                    self:CheckCoreInstance(
                        missingAPIs,
                        "HistoryItem",
                        historyItems[1],
                        {
                            "GetItemID",
                            "IsTrinket"
                        }
                    )
                end
            elseif history == nil then
                missingAPIs[#missingAPIs + 1] = "EntityPlayer.GetHistory result"
            end
        end
    end

    local pauseSprites = {
        pauseBody,
        pauseStats,
        PauseMenu.GetMyStuffSprite()
    }

    for _, sprite in pairs(pauseSprites) do
        if self:CheckCoreInstance(
                missingAPIs,
                "Sprite",
                sprite,
                CONFIG.SPRITE_METHODS
            ) then
            for _, layer in ipairs(sprite:GetAllLayers()) do
                if self:CheckCoreInstance(
                        missingAPIs,
                        "LayerState",
                        layer,
                        {
                            "GetName",
                            "GetLayerID",
                            "GetSpritesheetPath",
                            "IsVisible",
                            "SetVisible"
                        }
                    ) then
                    local layerID = layer:GetLayerID()

                    self:CheckCoreInstance(
                        missingAPIs,
                        "LayerFrameData",
                        sprite:GetLayerFrameData(layerID),
                        { "IsVisible" }
                    )

                    local animation = sprite:GetAnimationData("Idle")

                    if animation
                        and self:CheckCoreInstance(
                            missingAPIs,
                            "AnimationData",
                            animation,
                            { "GetLayer" }
                        )
                    then
                        local animationLayer = animation:GetLayer(layerID)

                        if self:CheckCoreInstance(
                                missingAPIs,
                                "AnimationLayer",
                                animationLayer,
                                {
                                    "IsVisible",
                                    "GetFrame"
                                }
                            ) then
                            self:CheckCoreInstance(
                                missingAPIs,
                                "AnimationFrame",
                                animationLayer:GetFrame(0),
                                {
                                    "GetPos",
                                    "GetPivot",
                                    "GetScale",
                                    "GetWidth",
                                    "GetHeight"
                                }
                            )
                        end
                    end
                end
            end
        end
    end
end

---@param game Game
---@param pauseBody? Sprite
---@param pauseStats? Sprite
---@return boolean available
---@return string[] missingAPIs
function CoreAPI:CheckCoreRuntime(game, pauseBody, pauseStats)
    local missingAPIs = {}
    local successful, failureReason = pcall(
        self.InspectCoreRuntime,
        self,
        missingAPIs,
        game,
        pauseBody,
        pauseStats
    )

    if not successful then
        missingAPIs[#missingAPIs + 1] = "Runtime inspection: " .. tostring(failureReason)
    end

    return #missingAPIs == 0, missingAPIs
end

---@param mod MSD4RMod
---@return boolean available
---@return string[] missingAPIs
---@return MSD4RJsonCodec? jsonCodec
function CoreAPI:CheckSave(mod)
    local missingAPIs = {}

    self:CheckMethods(
        missingAPIs,
        "Mod",
        mod,
        {
            "HasData",
            "LoadData",
            "SaveData"
        }
    )

    local jsonLoaded, jsonCodec = pcall(require, "json")

    self:CheckMethods(
        missingAPIs,
        "json",
        jsonLoaded and jsonCodec or nil,
        {
            "encode",
            "decode"
        }
    )

    if #missingAPIs > 0 then
        return false, missingAPIs, nil
    end

    return true, missingAPIs, jsonCodec
end

---@param game Game
---@return boolean available
---@return string[] missingAPIs
function CoreAPI:CheckGlitchedRendering(game)
    local missingAPIs = {}
    self:CheckMethods(
        missingAPIs,
        "Renderer",
        _G.Renderer,
        {
            "LoadImage",
            "CreateImage",
            "RenderToImage"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "SourceQuad",
        SourceQuad,
        { "NewFromRectangle" }
    )
    self:CheckMethods(
        missingAPIs,
        "DestinationQuad",
        DestinationQuad,
        { "NewFromRectangle" }
    )
    self:CheckMethods(
        missingAPIs,
        "ProceduralItemManager",
        ProceduralItemManager,
        {
            "GetProceduralItem",
            "GetProceduralItemCount"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "Isaac",
        Isaac,
        {
            "GetItemConfig",
            "GetPlayer",
            "RenderCollectionItem"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "XMLData",
        XMLData,
        {
            "GetNumEntries",
            "GetEntryByOrder"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "EntityConfig",
        EntityConfig,
        { "GetEntity" }
    )
    self:CheckMethods(
        missingAPIs,
        "string",
        string,
        {
            "pack",
            "unpack"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "Game",
        game,
        {
            "GetSeeds",
            "GetFrameCount",
            "GetNumPlayers"
        }
    )
    self:CheckMethods(
        missingAPIs,
        "Global",
        _G,
        { "GetPtrHash" }
    )
    self:CheckConstants(
        missingAPIs,
        "XMLNode",
        XMLNode,
        { "ENTITY" }
    )
    self:CheckConstants(
        missingAPIs,
        "CollectibleType",
        CollectibleType,
        { "COLLECTIBLE_D4" }
    )
    self:CheckConstants(
        missingAPIs,
        "ModCallbacks",
        ModCallbacks,
        {
            "MC_POST_PICKUP_INIT",
            "MC_POST_PICKUP_UPDATE",
            "MC_PRE_PICKUP_MORPH",
            "MC_POST_PICKUP_MORPH",
            "MC_PRE_UPDATE",
            "MC_POST_UPDATE",
            "MC_POST_GET_COLLECTIBLE",
            "MC_PRE_USE_ITEM",
            "MC_POST_GAME_STARTED",
            "MC_PRE_GAME_EXIT"
        }
    )

    local rngCreated, rng = pcall(
    ---@return RNG result1
        function()
            return RNG()
        end
    )

    self:CheckMethods(
        missingAPIs,
        "RNG",
        rngCreated and rng or nil,
        {
            "GetSeed",
            "GetShiftIdx",
            "SetSeed",
            "Next"
        }
    )

    local colorCreated, color = pcall(
    ---@return Color result1
        function()
            return Color(1, 1, 1, 1)
        end
    )

    self:CheckMethods(
        missingAPIs,
        "Color",
        colorCreated and color or nil,
        { "SetColorize" }
    )

    if #missingAPIs == 0 then
        local inspected, inspectionError = pcall(
        ---@return nil # No return value.
            function()
                local itemConfig = Isaac.GetItemConfig()

                self:CheckMethods(
                    missingAPIs,
                    "ItemConfig",
                    itemConfig,
                    {
                        "GetCollectibles",
                        "GetTrinkets",
                        "GetCollectible",
                        "GetTrinket"
                    }
                )
                self:CheckMethods(
                    missingAPIs,
                    "Seeds",
                    game:GetSeeds(),
                    { "GetStartSeed" }
                )
            end
        )

        if not inspected then
            missingAPIs[#missingAPIs + 1] =
                "Glitched API inspection: " .. tostring(inspectionError)
        end
    end

    return #missingAPIs == 0, missingAPIs
end

---@param player EntityPlayer
---@return boolean available
---@return string[] missingAPIs
function CoreAPI:CheckSeedTrackingPlayer(player)
    local missingAPIs = {}
    self:CheckMethods(
        missingAPIs,
        "EntityPlayer",
        player,
        {
            "Exists",
            "GetCollectibleRNG"
        }
    )
    return #missingAPIs == 0, missingAPIs
end

---@param pickup EntityPickup
---@return boolean available
---@return string[] missingAPIs
function CoreAPI:CheckPickup(pickup)
    local missingAPIs = {}
    self:CheckMethods(
        missingAPIs,
        "EntityPickup",
        pickup,
        {
            "Exists",
            "GetDropRNG"
        }
    )
    return #missingAPIs == 0, missingAPIs
end

---@param image? Image
---@return boolean available
---@return string[] missingAPIs
function CoreAPI:CheckGlitchedImage(image)
    local missingAPIs = {}

    self:CheckMethods(
        missingAPIs,
        "Image",
        image,
        {
            "GetWidth",
            "GetHeight",
            "Render"
        }
    )

    return #missingAPIs == 0, missingAPIs
end

---@param proceduralItem? ProceduralItem
---@return boolean available
---@return string[] missingAPIs
function CoreAPI:CheckProceduralItem(proceduralItem)
    local missingAPIs = {}

    if not self:CheckMethods(
            missingAPIs,
            "ProceduralItem",
            proceduralItem,
            {
                "GetItem",
                "GetTargetItem",
                "GetEffectCount",
                "GetEffect",
                "GetDamage",
                "GetFireDelay",
                "GetSpeed",
                "GetRange",
                "GetShotSpeed",
                "GetLuck"
            }
        ) then
        return false, missingAPIs
    end

    ---@cast proceduralItem ProceduralItem
    local inspected, inspectionError = pcall(
    ---@return nil # No return value.
        function()
            for effectIndex = 0, proceduralItem:GetEffectCount() - 1 do
                self:CheckMethods(
                    missingAPIs,
                    "ProceduralEffect",
                    proceduralItem:GetEffect(effectIndex),
                    {
                        "GetConditionType",
                        "GetActionType",
                        "GetScore",
                        "GetConditionProperty",
                        "GetActionProperty"
                    }
                )
            end
        end
    )

    if not inspected then
        missingAPIs[#missingAPIs + 1] =
            "Procedural item inspection: " .. tostring(inspectionError)
    end

    return #missingAPIs == 0, missingAPIs
end

---@type MSD4RCoreAPI
return CoreAPI
