local GlitchedItemRenderer = {}

local ReplayController = include("scripts/replay_controller")
local UI_CONFIG = include("scripts/ui_config")
local Utility = include("scripts/utility")

local function log(message)
    Isaac.ConsoleOutput("[MSD4R/TMTRAINER] " .. tostring(message) .. "\n")
end

function GlitchedItemRenderer:Initialize()
    self.DiagnosticVersion = "2026-10-01-d6"
    self.UseNativePalette = false
    self.Cache = {}
    self.Failed = {}
    self.Diagnostics = {}
    self.VanillaAtlasLastID = 732
    self.ModCollectionImages = {}
    self.ModCollectionErrors = {}

    if self.Initialized then
        return true
    end

    local ok, img = pcall(
        _G.Renderer.LoadImage,
        "gfx/ui/death items.png"
    )
    if not ok or not img then
        log("Cannot load gfx/ui/death items.png"); return false
    end

    self.ItemIconsImage = img
    self.AtlasColumnCount = math.floor(img:GetWidth() / 16)
    self.AtlasRowCount = math.floor(img:GetHeight() / 16)
    self.Initialized = true

    return true
end

function GlitchedItemRenderer:Reset()
    self.Cache = {}
    self.Failed = {}
    self.Diagnostics = {}
    self.Environment = nil
    self.ModCollectionImages = {}
    self.ModCollectionErrors = {}
end

function GlitchedItemRenderer:Resolve(itemID, seeds, knownFlags)
    itemID = Utility.ConvertToID32(itemID)

    local proc = Utility.GetRawProceduralItem(itemID)
    if not proc then return nil, "procedural item unavailable" end
    if type(seeds) ~= "table" then seeds = { seeds } end
    local values = {}
    for _, seed in ipairs(seeds) do
        seed = tonumber(seed)
        if seed and (seed & 0xffffffff) ~= 0 then values[#values + 1] = seed & 0xffffffff end
    end
    if #values == 0 then return nil, "creation seed has not been captured" end
    local key = string.format(
        "%d:%s:%s:%s",
        itemID,
        table.concat(values, ","),
        tostring(self.UseNativePalette),
        tostring(knownFlags)
    )
    if self.Cache[key] then return self.Cache[key] end
    if self.Failed[key] then return nil, self.Failed[key], self.Diagnostics[key] end
    local env = self:BuildEnvironment()
    local snapshot = self:Snapshot(proc)
    local diag = {
        Version = self.DiagnosticVersion,
        ItemID = itemID,
        Seeds = values,
        KnownFlags = knownFlags,
        Actual = snapshot,
        Candidates = {}
    }
    self.Diagnostics[key] = diag
    local best; local tried = {}
    for _, seed in ipairs(values) do
        for _, flags in ipairs(knownFlags ~= nil and { knownFlags } or { 0, 2, 8 }) do
            local effective = Replay.EffectiveSeed(seed, flags)
            if effective ~= 0 and not tried[effective] then
                tried[effective] = true
                local result = Replay.Replay(seed, env, flags)
                local valid, why, d = self:ValidateSnapshot(result, snapshot)
                d.Seed, d.Flags, d.EffectiveSeed = seed, flags, effective
                d.PreEffects = result.PreEffects; d.Effects = result.Effects; d.GraphicsState = result.GraphicsState
                d.DevilPrice, d.ShopPrice = result.DevilPrice, result.ShopPrice
                diag.Candidates[#diag.Candidates + 1] = d
                if not best or d.PrefixMatched > best.PrefixMatched
                    or (d.PrefixMatched == best.PrefixMatched and #d.Differences < #best.Differences) then
                    best = d
                end
                if valid then
                    result.ItemID = itemID; result.CacheKey = key
                    diag.Best = #diag.Candidates
                    result.Diagnostic = diag
                    self.Cache[key] = result
                    return result
                end
            end
        end
    end
    local reason = "no seed matched"
    if best then
        for i, d in ipairs(diag.Candidates) do if d == best then diag.Best = i end end
        reason = string.format("seed=%u flags=%d pre=%s: %s", best.Seed, best.Flags,
            best.PreMatched and "MATCH" or "DIFF", best.Summary)
    end
    self.Failed[key] = reason
    log("Item " .. itemID .. ": " .. reason .. "; keeping fallback icon")
    return nil, reason, diag
end

function GlitchedItemRenderer:GetGraphicsState(itemID, seeds)
    local r = self:Resolve(itemID, seeds)
    return r and r.GraphicsState
end

function GlitchedItemRenderer:GetItemIconCellPosition(id)
    if not id or id <= 0 or id > self.VanillaAtlasLastID then return nil end
    -- Same discontinuities as the supplied My Stuff renderer.
    local adjusted = id + (id > 360 and 1 or 0) + (id > 396 and 3 or 0) + (id > 552 and 4 or 0)
    local i = adjusted - 1
    if i >= self.AtlasColumnCount * self.AtlasRowCount then return nil end
    return Vector(i % self.AtlasColumnCount * 16, i // self.AtlasColumnCount * 16)
end

-- Render the game"s collection icon, including a mod"s deathanm2 mapping or
-- native placeholder, instead of treating its runtime ID as a vanilla atlas cell.
-- Called while building the quad list, BEFORE the final RenderToImage pass.
function GlitchedItemRenderer:GetModCollectionImage(itemID)
    if self.ModCollectionImages[itemID] then return self.ModCollectionImages[itemID] end
    if self.ModCollectionErrors[itemID] then return nil, self.ModCollectionErrors[itemID] end
    local ok, image = pcall(function()
        assert(type(Isaac.RenderCollectionItem) == "function", "RenderCollectionItem API unavailable")
        assert(Isaac.GetItemConfig():GetCollectible(itemID), "invalid collectible " .. itemID)
        local surface = assert(_G.Renderer.CreateImage(16, 16, "msd4r_mod_collection_" .. itemID),
            "cannot create mod collection surface")
        _G.Renderer.RenderToImage(surface, function(controller)
            controller:Clear()
            -- Standard collection icons are 16x16 with a centered origin.
            Isaac.RenderCollectionItem(itemID, Vector(8, 8), Vector(1, 1), Color(1, 1, 1, 1))
        end)
        return surface
    end)
    if not ok then
        local reason = "source " .. itemID .. " collection render failed: " .. tostring(image)
        self.ModCollectionErrors[itemID] = reason
        return nil, reason
    end
    self.ModCollectionImages[itemID] = image
    return image
end

function GlitchedItemRenderer:GetSourceItemRegion(itemID)
    if itemID <= self.VanillaAtlasLastID then
        local origin = self:GetItemIconCellPosition(itemID)
        if not origin then return nil, nil, "source " .. itemID .. " has no death-atlas cell" end
        return self.ItemIconsImage, origin
    end
    local image, reason = self:GetModCollectionImage(itemID)
    if not image then return nil, nil, reason end
    return image, Vector(0, 0)
end

local function palette(hue)
    local f = Replay.Float32
    local h = f(hue / 60)
    local x = f(1 - math.abs(f(h % 2 - 1)))
    local sector = math.floor(h) % 6
    local rgb = ({ { 1, x, 0 }, { x, 1, 0 }, { 0, 1, x }, { 0, x, 1 }, { x, 0, 1 }, { 1, 0, x } })[sector + 1]
    local white = Color(1, 1, 1, 1)
    white:SetColorize(1, 1, 1, 2)
    local hueColor = Color(1, 1, 1, 1)
    hueColor:SetColorize(rgb[1], rgb[2], rgb[3], 1)
    return { Color(1, 1, 1, 1), Color(-1, -1, -1, 1, 1, 1, 1), hueColor, white }
end
function GlitchedItemRenderer:Bake(result)
    if result.Image then return result.Image end
    local quads = {}; local colors = palette(result.Hue)
    for i = 0, 63 do
        local tile = result.Recipe[i + 1]
        local source = result.SourceItems[tile.SourceImageIndex + 1]
        local sourceImage, origin, reason
        if source then
            sourceImage, origin, reason = self:GetSourceItemRegion(source)
            if not sourceImage then return nil, reason end
        end
        if origin then
            local t = tile.SourceTileIndex
            -- Native permits source index 64 in its last unused transition only.
            if t < 0 or t > 63 then return nil, "invalid source tile " .. t end
            quads[#quads + 1] = {
                SourceQuad.NewFromRectangle(origin + Vector((t >> 3) * 2, (t & 7) * 2), 2, 2, false),
                DestinationQuad.NewFromRectangle(Vector((i >> 3) * 2, (i & 7) * 2), 2, 2),
                self.UseNativePalette and colors[tile.ColorIndex + 1] or colors[1],
                sourceImage,
            }
        end
    end
    if #quads == 0 then return nil, "no source tiles" end
    local img = _G.Renderer.CreateImage(16, 16, "msd4r_tm_" .. result.ItemID .. "_" .. result.EffectiveSeed)
    _G.Renderer.RenderToImage(img, function(controller)
        controller:Clear()
        for _, q in ipairs(quads) do q[4]:Render(q[1], q[2], KColor(1, 1, 1, 1), q[3]) end
    end)
    result.Image = img
    return img
end

function GlitchedItemRenderer:RenderItemIcon(itemID, seeds, position, scale, color)
    if not seeds then return false end
    if not self:Initialize() then return false end
    local ok, result, why = pcall(self.Resolve, self, itemID, seeds)
    if not ok then
        if not self.LastError or self.LastError ~= result then
            log(result); self.LastError = result
        end
        return false
    end
    if not result then return false end
    if result.BakeError then return false end
    local good, img, reason = pcall(self.Bake, self, result)
    if not good or not img then
        result.BakeError = reason or img; log(result.BakeError); return false
    end
    scale = scale or Vector(1, 1)
    local half = UI_CONFIG.ITEMS_DISPLAY_STEP_X // 2
    img:Render(SourceQuad.NewFromRectangle(Vector(0, 0), 16, 16, false),
        DestinationQuad.NewFromRectangle(position - Vector(half * scale.X, half * scale.Y), 16 * scale.X, 16 * scale.Y),
        KColor(1, 1, 1, 1), color or Color(1, 1, 1, 1))
    return true
end

-- This export contains configuration records, not texture bytes or executable data.
function GlitchedItemRenderer:ExportEnvironment()
    local e = self:BuildEnvironment()
    local out = {
        itemCount = e.itemCount,
        trinketCount = e.trinketCount,
        items = {},
        trinkets = {},
        active = {},
        entities =
            e.entities
    }
    for id = 0, e.itemCount - 1 do if e.items[id] then out.items[#out.items + 1] = e.items[id] end end
    for id = 0, e.trinketCount - 1 do if e.trinkets[id] then out.trinkets[#out.trinkets + 1] = e.trinkets[id] end end
    for _, item in ipairs(e.active) do out.active[#out.active + 1] = item.ID end
    return out
end

function GlitchedItemRenderer:WriteDiagnostic(diag, context)
    if not diag then return "No diagnostic snapshot available." end
    if not Isaac.DebugString then return "Isaac.DebugString unavailable; report not written." end
    local ok, err = pcall(function()
        local report = { Schema = 2, Diagnostic = diag, Context = context or {}, Environment = self:ExportEnvironment() }
        local encoded = require("json").encode(report)
        self.ReportSerial = (self.ReportSerial or 0) + 1
        local id = tostring(diag.ItemID) .. "_" .. self.ReportSerial
        local total = math.ceil(#encoded / 1000)
        for i = 1, total do
            Isaac.DebugString(string.format("[MSD4R/TM-DATA] %s %d/%d %s", id, i, total,
                encoded:sub((i - 1) * 1000 + 1, i * 1000)))
        end
    end)
    return ok and "Full TM-DATA report written to log.txt." or ("Report write failed: " .. tostring(err))
end

-- Read-only diagnostic; only the separately named probe command creates an item.
function GlitchedItemRenderer:Describe(itemID, seeds, knownFlags, context)
    local ok, r, reason, diag = pcall(self.Resolve, self, itemID, seeds, knownFlags)
    if not ok then return tostring(r) end
    if not r then
        local lines = { "TM diagnostic " .. self.DiagnosticVersion .. ": " .. tostring(reason) }
        if diag then
            for i, d in ipairs(diag.Candidates) do
                lines[#lines + 1] = string.format("%s seed=%u flags=%d effective=%u pre=%s matches=%d/%d: %s",
                    i == diag.Best and "BEST" or "candidate", d.Seed, d.Flags, d.EffectiveSeed,
                    d.PreMatched and "MATCH" or "DIFF", d.Matched, d.Checks, d.Summary)
            end
            lines[#lines + 1] = self:WriteDiagnostic(diag, context)
        end
        return table.concat(lines, "\n")
    end
    local sources = {}
    for i = 1, 4 do sources[i] = tostring(r.SourceItems[i] or "nil") end
    return string.format("MATCH [%s] id=%d effectiveSeed=%u graphics=0x%08X attempts=%d effects=%d sources=[%s]\n%s",
        self.DiagnosticVersion, Utility.ConvertToID32(itemID), r.EffectiveSeed, r.GraphicsState, #r.Attempts, #r.Effects,
        table.concat(sources, ","), self:WriteDiagnostic(r.Diagnostic, context))
end

return GlitchedItemRenderer
