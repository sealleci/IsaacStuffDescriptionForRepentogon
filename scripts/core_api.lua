-- Required API surface for the ordinary My Stuff UI. Glitched icons, mod
-- graphics and Mod Config Menu are deliberately not requirements here.
local CoreAPI = {}
local function member(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
end
local function methods(missing, label, object, names)
    local valid = true
    for _, name in ipairs(names) do
        if type(member(object, name)) ~= 'function' then
            missing[#missing + 1] = label .. '.' .. name
            valid = false
        end
    end
    return valid
end
local function constants(missing, label, object, names)
    for _, name in ipairs(names) do
        if type(member(object, name)) ~= 'number' then
            missing[#missing + 1] = label .. '.' .. name
        end
    end
end
local spriteMethods = {
    'Load', 'Play', 'SetFrame', 'GetAnimation', 'GetLayer', 'GetAllLayers',
    'GetAnimationData', 'GetLayerFrameData', 'ReplaceSpritesheet',
    'LoadGraphics', 'RenderLayer'
}
function CoreAPI:Check(mod, game)
    self.Checked = {}
    local missing = {}
    methods(missing, 'PauseMenu', PauseMenu, {
        'GetState', 'GetSelectedElement', 'SetSelectedElement',
        'GetSprite', 'GetStatsSprite', 'GetMyStuffSprite'
    })
    methods(missing, 'XMLData', XMLData, { 'GetModById' })
    methods(missing, 'Isaac', Isaac, {
        'ConsoleOutput', 'RenderCollectionItem', 'GetScreenWidth',
        'GetScreenHeight', 'DrawQuad', 'GetPlayer'
    })
    methods(missing, 'Input', Input, { 'IsActionTriggered' })
    methods(missing, 'Game', game, { 'IsPauseMenuOpen', 'GetNumPlayers' })
    methods(missing, 'Mod', mod, { 'HasData', 'LoadData', 'SaveData' })
    local ok, json = pcall(require, 'json')
    methods(missing, 'json', ok and json or nil, { 'encode', 'decode' })
    -- Inspect an empty, private Sprite. No player or pause-screen state changes.
    local constructed, sprite = pcall(function() return Sprite() end)
    methods(missing, 'Sprite', constructed and sprite or nil, spriteMethods)
    constants(missing, 'ModCallbacks', ModCallbacks, {
        'MC_POST_MODS_LOADED', 'MC_PRE_PAUSE_SCREEN_RENDER',
        'MC_POST_PAUSE_SCREEN_RENDER', 'MC_POST_RENDER',
        'MC_PRE_PLAYERHUD_TRINKET_RENDER', 'MC_POST_GAME_STARTED'
    })
    constants(missing, 'PauseMenuStates', PauseMenuStates, { 'OPTIONS' })
    constants(missing, 'ButtonAction', ButtonAction, {
        'ACTION_MENULEFT', 'ACTION_MENURIGHT', 'ACTION_MENUUP', 'ACTION_MENUDOWN'
    })
    constants(missing, 'TrinketType', TrinketType, {
        'TRINKET_NULL', 'TRINKET_ID_MASK', 'NUM_TRINKETS'
    })
    return #missing == 0, missing
end

-- Engine instances may not exist at POST_MODS_LOADED. Check their method
-- surfaces, read-only, before the UI first accesses them. Empty history is valid.
function CoreAPI:CheckRuntime(game, body, stats)
    local missing = {}
    local checked = self.Checked or {}; self.Checked = checked
    local function check(label, object, names)
        if object == nil then return false end
        if checked[label] then return true end
        local valid = methods(missing, label, object, names)
        if valid then checked[label] = true end
        return valid
    end
    if not checked.HistoryItem then
        for i = 0, game:GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i)
            if check('EntityPlayer', player, {
                    'GetHistory', 'GetMaxTrinkets', 'GetTrinket', 'GetPlayerType'
                }) then
                local history = player:GetHistory()
                if check('History', history, { 'GetCollectiblesHistory' }) then
                    local entries = history:GetCollectiblesHistory()
                    if entries and entries[1] then
                        check('HistoryItem', entries[1], { 'GetItemID', 'IsTrinket' })
                        break
                    end
                end
            end
        end
    end
    if not checked.SpriteLayer or not checked.AnimationFrame
        or not checked.LayerFrameData then
        local sprites = { body, stats, PauseMenu.GetMyStuffSprite() }
        -- pairs, since body/stats can be absent during a transition.
        for _, sprite in pairs(sprites) do
            if check('Sprite', sprite, spriteMethods) then
                for _, layer in ipairs(sprite:GetAllLayers()) do
                    if check('SpriteLayer', layer, {
                            'GetName', 'GetLayerID', 'GetSpritesheetPath', 'IsVisible', 'SetVisible'
                        }) then
                        local id = layer:GetLayerID()
                        check('LayerFrameData', sprite:GetLayerFrameData(id), { 'IsVisible' })
                        local animation = sprite:GetAnimationData('Idle')
                        if check('AnimationData', animation, { 'GetLayer' }) then
                            local animationLayer = animation:GetLayer(id)
                            if check('AnimationLayer', animationLayer, { 'IsVisible', 'GetFrame' }) then
                                check('AnimationFrame', animationLayer:GetFrame(0), {
                                    'GetPos', 'GetPivot', 'GetScale', 'GetWidth', 'GetHeight'
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    return #missing == 0, missing
end

function CoreAPI:Report(missing)
    local message = '[MSD4R] Required UI/save APIs unavailable: '
        .. table.concat(missing, ', ') .. '\n'
    if type(member(Isaac, 'ConsoleOutput')) == 'function' then
        Isaac.ConsoleOutput(message)
    else
        print(message)
    end
end

return CoreAPI
