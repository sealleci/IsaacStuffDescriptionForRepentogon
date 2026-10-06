---@class MSD4RGlitchedItemRenderer
---@field Initialized boolean?
---@field UseNativePalette boolean
---@field ModItemImages table<integer, Image>
---@field CachedReplayResult table<string, MSD4RReplayResult>
---@field CachedReplayFailureReason table<string, string>
---@field Diagnostics table<string, MSD4RDiagnostic>
---@field ReportSerial integer
---@field ItemIconsImage Image
---@field AtlasColumnCount integer
---@field AtlasRowCount integer
local GlitchedItemRenderer = {}

---@type MSD4RCoreAPI
local CoreAPI = include("scripts/core_api")
---@type MSD4RReplayController
local ReplayController = include("scripts/replay_controller")
---@type MSD4RUIConfig
local UI_CONFIG = include("scripts/ui_config")
---@type MSD4RUtility
local Utility = include("scripts/utility")

---@type MSD4RGlitchedConfig
local CONFIG = {
    VANILLA_LAST_ITEM_ID = 732
}

---@return boolean result1
function GlitchedItemRenderer:Initialize()
    if self.Initialized then
        return true
    end

    local renderingAvailable, missingAPIs =
        CoreAPI:CheckGlitchedRendering(Game())

    if not renderingAvailable then
        CoreAPI:ReportUnavailable("Glitched rendering", missingAPIs)

        return false
    end

    self.UseNativePalette = false
    self.ModItemImages = {}
    self.CachedReplayResult = {}
    self.CachedReplayFailureReason = {}
    self.Diagnostics = {}
    self.ReportSerial = 0

    local successful, image = pcall(
        _G.Renderer.LoadImage,
        "gfx/ui/death items.png"
    )

    if not successful
        or not image
    then
        Utility.Log(
            "Cannot load \"gfx/ui/death items.png\"."
        )

        return false
    end

    local imageAvailable, missingImageAPIs =
        CoreAPI:CheckGlitchedImage(image)

    if not imageAvailable then
        CoreAPI:ReportUnavailable("Glitched image", missingImageAPIs)

        return false
    end

    self.ItemIconsImage = image
    self.AtlasColumnCount = math.floor(
        image:GetWidth() / 16
    )
    self.AtlasRowCount = math.floor(
        image:GetHeight() / 16
    )
    self.Initialized = true

    return true
end

---@return nil # No return value.
function GlitchedItemRenderer:Reset()
    self.CachedReplayResult = {}
    self.CachedReplayFailureReason = {}
    self.ModItemImages = {}
    self.Diagnostics = {}

    ReplayController:Reset()
end

---@param itemID integer
---@param seeds integer[]
---@param knownFlags? integer[]
---@return MSD4RProcessingResult result1
function GlitchedItemRenderer:ProcessReplay(
    itemID,
    seeds,
    knownFlags
)
    local processingResult = {
        ReplayResult = nil,
        FailureReason = nil,
        Diagnostic = nil
    }

    itemID = Utility.ConvertToID32(itemID)

    if not knownFlags then
        knownFlags = { 0, 2, 8 }
    end

    local proceduralItem = Utility.GetRawProceduralItem(itemID)
    local validSeeds = {}

    if not proceduralItem then
        processingResult.FailureReason = "procedural item unavailable"

        return processingResult
    end

    if not CoreAPI:CheckProceduralItem(proceduralItem) then
        processingResult.FailureReason = "Procedural item APIs are unavailable"

        return processingResult
    end

    for _, seed in ipairs(seeds) do
        seed = Utility.ConvertToU32(seed)

        if seed ~= 0 then
            validSeeds[#validSeeds + 1] = seed
        end
    end

    if #validSeeds == 0 then
        processingResult.FailureReason = "creation seed has not been captured"

        return processingResult
    end

    local replayKey = string.format(
        "%d:%s:%s:%s",
        itemID,
        table.concat(validSeeds, ","),
        tostring(self.UseNativePalette),
        table.concat(knownFlags, ",")
    )

    if self.CachedReplayResult[replayKey] then
        processingResult.ReplayResult = self.CachedReplayResult[replayKey]
        processingResult.Diagnostic = self.Diagnostics[replayKey]

        return processingResult
    end

    if self.CachedReplayFailureReason[replayKey] then
        processingResult.FailureReason = self.CachedReplayFailureReason[replayKey]
        processingResult.Diagnostic = self.Diagnostics[replayKey]

        return processingResult
    end

    local env = ReplayController:BuildEnvironment()
    local snapshot = ReplayController:GetSnapshot(proceduralItem)
    local diagnostic = {
        ItemID = itemID,
        Seeds = validSeeds,
        KnownFlags = knownFlags,
        Candidates = {},
        BestTryIndex = 0
    }
    local bestTryReport
    local visitedSeeds = {}

    self.Diagnostics[replayKey] = diagnostic

    for _, seed in ipairs(validSeeds) do
        for _, flags in ipairs(knownFlags) do
            local effectiveSeed = ReplayController:GetEffectiveSeed(
                seed,
                flags
            )

            if effectiveSeed ~= 0
                and not visitedSeeds[effectiveSeed]
            then
                visitedSeeds[effectiveSeed] = true

                local replayResult = ReplayController:Replay(
                    seed,
                    env,
                    flags
                )
                local valid, _, report = ReplayController:ValidateSnapshot(
                    replayResult,
                    snapshot
                )

                report.ItemConfig.Seed = seed
                report.ItemConfig.Flags = flags
                report.ItemConfig.EffectiveSeed = effectiveSeed
                report.ItemConfig.PreEffects = replayResult.PreEffects
                report.ItemConfig.Effects = replayResult.Effects
                report.ItemConfig.GraphicsState = replayResult.GraphicsState
                report.ItemConfig.DevilPrice = replayResult.DevilPrice
                report.ItemConfig.ShopPrice = replayResult.ShopPrice
                diagnostic.Candidates[#diagnostic.Candidates + 1] = report

                if not bestTryReport
                    or report.PrefixMatchedCount > bestTryReport.PrefixMatchedCount
                    or (report.PrefixMatchedCount == bestTryReport.PrefixMatchedCount
                        and #report.Differences < #bestTryReport.Differences)
                then
                    bestTryReport = report
                end

                if valid then
                    replayResult.ItemID = itemID

                    self.CachedReplayResult[replayKey] = replayResult
                    processingResult.ReplayResult = replayResult
                    processingResult.Diagnostic = diagnostic

                    diagnostic.BestTryIndex = #diagnostic.Candidates

                    return processingResult
                end
            end
        end
    end

    local noValidSeedReason = "no seed matched"

    if bestTryReport then
        for i, diagnosticItem in ipairs(diagnostic.Candidates) do
            if diagnosticItem == bestTryReport then
                diagnostic.BestTryIndex = i
            end
        end

        noValidSeedReason = string.format(
            "seed=%u flags=%d pre=%s: %s",
            bestTryReport.ItemConfig.Seed,
            bestTryReport.ItemConfig.Flags,
            bestTryReport.IsPreEffectsMatched and "MATCH" or "DIFF",
            bestTryReport.Summary
        )
    end

    self.CachedReplayFailureReason[replayKey] = noValidSeedReason
    processingResult.FailureReason = noValidSeedReason
    processingResult.Diagnostic = diagnostic

    Utility.Log(string.format(
        "Failed to process replay for item %d: %s.",
        itemID,
        noValidSeedReason
    ))

    return processingResult
end

---@param itemID integer
---@return integer result1
function GlitchedItemRenderer:AdjustItemID(itemID)
    -- There are placeholders in "death items.png".
    local adjustedItemID = itemID

    if itemID > 360 then
        adjustedItemID = adjustedItemID + 1
    end

    if itemID > 396 then
        adjustedItemID = adjustedItemID + 3
    end

    if itemID > 552 then
        adjustedItemID = adjustedItemID + 4
    end

    return adjustedItemID
end

---@param itemID integer
---@return Vector? result1
function GlitchedItemRenderer:GetItemIconCellPosition(itemID)
    if itemID <= 0
        or itemID > CONFIG.VANILLA_LAST_ITEM_ID
    then
        return nil
    end

    local index = self:AdjustItemID(itemID) - 1

    if index >= self.AtlasColumnCount * self.AtlasRowCount then
        return nil
    end

    return Vector(
        (index % self.AtlasColumnCount)
        * UI_CONFIG.ITEMS_DISPLAY_STEP_X,
        (index // self.AtlasColumnCount)
        * UI_CONFIG.ITEMS_DISPLAY_STEP_Y
    )
end

---@param itemID integer
---@return Image? result1
function GlitchedItemRenderer:GetModItemIconImage(itemID)
    if self.ModItemImages[itemID] then
        return self.ModItemImages[itemID]
    end

    local successful, imageOrError = pcall(
    ---@return Image result1
        function()
            assert(
                Isaac.GetItemConfig():GetCollectible(itemID),
                "invalid mod item " .. itemID
            )

            local modItemIconImageName = "msd4r_mod_item_" .. itemID
            local surface = assert(
                _G.Renderer.CreateImage(
                    16,
                    16,
                    modItemIconImageName
                ),
                "failed to create image " .. modItemIconImageName
            )


            _G.Renderer.RenderToImage(
                surface,
                ---@param controller SurfaceRenderController
                ---@return nil # No return value.
                function(controller)
                    controller:Clear()
                    Isaac.RenderCollectionItem(
                        itemID,
                        Vector(8, 8),
                        Vector(1, 1),
                        Color(1, 1, 1, 1)
                    )
                end
            )

            return surface
        end
    )

    if not successful then
        Utility.Log(string.format(
            "Source item %d error: %s.",
            itemID,
            tostring(imageOrError)
        ))

        return nil
    end

    self.ModItemImages[itemID] = imageOrError

    return imageOrError
end

---@param itemID integer
---@return Image? result1
---@return Vector? result2
function GlitchedItemRenderer:GetSourceItemIconRegion(itemID)
    if itemID > 0
        and itemID <= CONFIG.VANILLA_LAST_ITEM_ID
    then
        local cellPosition = self:GetItemIconCellPosition(itemID)

        if not cellPosition then
            Utility.Log(string.format(
                "Source item %d has no cell position.",
                itemID
            ))

            return nil, nil
        end

        return self.ItemIconsImage, cellPosition
    end

    if itemID > CONFIG.VANILLA_LAST_ITEM_ID then
        local modItemIconImage = self:GetModItemIconImage(itemID)

        if not modItemIconImage then
            Utility.Log(string.format(
                "Invalid source mod item %d.",
                itemID
            ))

            return nil, nil
        end

        return modItemIconImage, Vector(0, 0)
    end

    Utility.Log(string.format(
        "Invalid source item %d.",
        itemID
    ))

    return nil, nil
end

---@param hue number
---@return Color[] result1
function GlitchedItemRenderer:GetPalette(hue)
    hue = Utility.ConvertToF32(hue / 60)

    local x = Utility.ConvertToF32(
        1
        - math.abs(
            Utility.ConvertToF32(hue % 2 - 1)
        )
    )
    local sector = math.floor(hue) % 6
    local rgb = ({
        { 1, x, 0 },
        { x, 1, 0 },
        { 0, 1, x },
        { 0, x, 1 },
        { x, 0, 1 },
        { 1, 0, x }
    })[sector + 1]
    local white = Color(1, 1, 1, 1)
    local hueColor = Color(1, 1, 1, 1)

    white:SetColorize(1, 1, 1, 2)
    hueColor:SetColorize(
        rgb[1],
        rgb[2],
        rgb[3],
        1
    )

    return {
        Color(1, 1, 1, 1),
        Color(-1, -1, -1, 1, 1, 1, 1),
        hueColor,
        white
    }
end

---@param replayResult MSD4RReplayResult
---@return Image? result1
function GlitchedItemRenderer:BakeGlitchedItemIcon(replayResult)
    if replayResult.Image then
        return replayResult.Image
    end

    local quads = {}
    local palette = self:GetPalette(replayResult.Hue)
    local quadsFailureReason = ""

    for i = 0, 63 do
        local tile = replayResult.Recipe[i + 1]
        local sourceItemIndex = tile.SourceImageIndex + 1
        local sourceItem = replayResult.SourceItems[sourceItemIndex]
        local sourceItemIconImage
        local originPosition

        if not sourceItem then
            quadsFailureReason = string.format(
                "%s;%s",
                quadsFailureReason,
                "invalid source item index " .. sourceItemIndex
            )

            goto continue
        end

        sourceItemIconImage, originPosition =
            self:GetSourceItemIconRegion(sourceItem)

        if not sourceItemIconImage
            or not originPosition
        then
            quadsFailureReason = string.format(
                "%s;%s",
                quadsFailureReason,
                "no icon region"
            )

            goto continue
        end

        if tile.SourceTileIndex < 0
            or tile.SourceTileIndex > 63
        then
            quadsFailureReason = string.format(
                "%s;%s",
                quadsFailureReason,
                "invalid source tile " .. tile.SourceTileIndex
            )

            goto continue
        end

        local createQuadSuccessfully, newQuadOrError = pcall(
        ---@return MSD4RIconQuad result1
            function()
                local newQuad = assert(
                    {
                        SourceQuad.NewFromRectangle(
                            originPosition + Vector(
                                (tile.SourceTileIndex >> 3) * 2,
                                (tile.SourceTileIndex & 7) * 2
                            ),
                            2,
                            2,
                            false
                        ),
                        DestinationQuad.NewFromRectangle(
                            Vector(
                                (i >> 3) * 2,
                                (i & 7) * 2
                            ),
                            2,
                            2
                        ),
                        (self.UseNativePalette
                            and palette[tile.ColorIndex + 1]
                            or palette[1]),
                        sourceItemIconImage,
                    },
                    "failed to create quad for source tile "
                    .. tile.SourceTileIndex
                )

                return newQuad
            end
        )

        if createQuadSuccessfully then
            quads[#quads + 1] = newQuadOrError
        else
            quadsFailureReason = string.format(
                "%s;%s",
                quadsFailureReason,
                newQuadOrError
            )
        end

        ::continue::
    end

    if #quads == 0 then
        Utility.Log(string.format(
            "Failed to create icon quads: %s.",
            quadsFailureReason
        ))

        return nil
    end

    local renderSuccessfully, imageOrError = pcall(
    ---@return Image result1
        function()
            local imageName = string.format(
                "msd4r_tmtrainer_%d_%d",
                replayResult.ItemID,
                replayResult.EffectiveSeed
            )
            local image = assert(
                _G.Renderer.CreateImage(
                    16,
                    16,
                    imageName
                ),
                "failed to create image " .. imageName
            )


            _G.Renderer.RenderToImage(
                image,
                ---@param controller SurfaceRenderController
                ---@return nil # No return value.
                function(controller)
                    controller:Clear()

                    for _, quad in ipairs(quads) do
                        quad[4]:Render(
                            quad[1],
                            quad[2],
                            KColor(1, 1, 1, 1),
                            quad[3]
                        )
                    end
                end
            )

            return image
        end
    )

    if renderSuccessfully then
        replayResult.Image = imageOrError

        return imageOrError
    end

    Utility.Log("Failed to bake glitched icon: " .. tostring(imageOrError) .. ".")

    return nil
end

---@param itemID integer
---@param seeds? integer[]
---@param position Vector
---@param scale? Vector
---@param color? Color
---@return boolean result1
function GlitchedItemRenderer:RenderItemIcon(
    itemID,
    seeds,
    position,
    scale,
    color
)
    if not self.Initialized
        or not seeds
        or not CoreAPI:CheckGlitchedImage(self.ItemIconsImage)
    then
        return false
    end

    if not scale then
        scale = Vector(1, 1)
    end

    if not color then
        color = Color(1, 1, 1, 1)
    end

    local resolveSuccessfully, resultOrError = pcall(
        self.ProcessReplay,
        self,
        itemID,
        seeds
    )

    if not resolveSuccessfully
        or not resultOrError
        or not resultOrError.ReplayResult
    then
        return false
    end

    local bakeSuccessfully, glitchedItemIcon = pcall(
        self.BakeGlitchedItemIcon,
        self,
        resultOrError.ReplayResult
    )

    if not bakeSuccessfully
        or not glitchedItemIcon
    then
        return false
    end

    local renderedSuccessfully = pcall(
    ---@return nil # No return value.
        function()
            glitchedItemIcon:Render(
                SourceQuad.NewFromRectangle(
                    Vector(0, 0),
                    UI_CONFIG.ITEMS_DISPLAY_STEP_X,
                    UI_CONFIG.ITEMS_DISPLAY_STEP_Y,
                    false
                ),
                DestinationQuad.NewFromRectangle(
                    position - Vector(
                        (UI_CONFIG.ITEMS_DISPLAY_STEP_X // 2)
                        * scale.X,
                        (UI_CONFIG.ITEMS_DISPLAY_STEP_Y // 2)
                        * scale.Y
                    ),
                    UI_CONFIG.ITEMS_DISPLAY_STEP_X * scale.X,
                    UI_CONFIG.ITEMS_DISPLAY_STEP_Y * scale.Y
                ),
                KColor(1, 1, 1, 1),
                color
            )
        end
    )

    return renderedSuccessfully
end

---@param diagnostic? MSD4RDiagnostic
---@param context? MSD4RDiagnosticContext
---@return boolean result1
function GlitchedItemRenderer:WriteDiagnostic(diagnostic, context)
    if not diagnostic then
        return false
    end

    local successful, _ = pcall(
    ---@return nil # No return value.
        function()
            local encodedReport = require("json").encode({
                Schema = 2,
                Diagnostic = diagnostic,
                Context = context or {},
                Environment = ReplayController:BuildEnvironment()
            })

            self.ReportSerial = self.ReportSerial + 1

            local diagnosticID = string.format(
                "%d_%d",
                diagnostic.ItemID,
                self.ReportSerial
            )
            local reportChunkSize = 1000
            local reportChunkCount = math.ceil(#encodedReport / reportChunkSize)

            for i = 1, reportChunkCount do
                Isaac.DebugString(string.format(
                    "[MSD4R] %s %d/%d %s",
                    diagnosticID,
                    i,
                    reportChunkCount,
                    encodedReport:sub(
                        (i - 1) * reportChunkSize + 1,
                        i * reportChunkSize
                    )
                ))
            end
        end
    )

    return successful
end

---@param itemID integer
---@param seeds? integer[]
---@param knownFlags? integer[]
---@param context? MSD4RDiagnosticContext
---@return string result1
function GlitchedItemRenderer:WriteLog(
    itemID,
    seeds,
    knownFlags,
    context
)
    local replaySuccessfully, resultOrError = pcall(
        self.ProcessReplay,
        self,
        itemID,
        seeds,
        knownFlags
    )

    if not replaySuccessfully
        or not resultOrError
    then
        return "Failed to process replay."
    end

    local writeSuccessfully = false

    if not resultOrError.ReplayResult then
        local lines = {
            "TM-TRAINER Diagnostic: " .. tostring(
                resultOrError.FailureReason or "unknown failure reason"
            ) .. "."
        }

        if resultOrError.Diagnostic then
            for i, diagnosticItem in ipairs(resultOrError.Diagnostic.Candidates) do
                lines[#lines + 1] = string.format(
                    "%s seed=%u flags=%d effective-seed=%u pre-effects=%s matches=%d/%d: %s.",
                    (i == resultOrError.Diagnostic.BestTryIndex) and "BEST" or "Candidate",
                    diagnosticItem.ItemConfig.Seed,
                    diagnosticItem.ItemConfig.Flags,
                    diagnosticItem.ItemConfig.EffectiveSeed,
                    diagnosticItem.IsPreEffectsMatched and "MATCH" or "DIFF",
                    diagnosticItem.MatchedCount,
                    diagnosticItem.Checks,
                    diagnosticItem.Summary
                )
            end
            writeSuccessfully = self:WriteDiagnostic(
                resultOrError.Diagnostic,
                context
            )
            lines[#lines + 1] = "Write diagnostic to \"log.txt\": " .. tostring(writeSuccessfully) .. "."
        end

        return table.concat(lines, "\n")
    end

    local sourceItems = {}

    for i = 1, 4 do
        sourceItems[i] = tostring(
            resultOrError.ReplayResult.SourceItems[i] or "nil"
        )
    end

    writeSuccessfully = self:WriteDiagnostic(
        resultOrError.Diagnostic,
        context
    )

    return string.format(
        "MATCH id=%d effectiveSeed=%u graphics=0x%08X attempts=%d effects=%d source-items=[%s].\n%s",
        itemID,
        resultOrError.ReplayResult.EffectiveSeed,
        resultOrError.ReplayResult.GraphicsState,
        #resultOrError.ReplayResult.Attempts,
        #resultOrError.ReplayResult.Effects,
        table.concat(sourceItems, ","),
        "Write diagnostic to \"log.txt\": " .. tostring(writeSuccessfully) .. "."
    )
end

---@type MSD4RGlitchedItemRenderer
return GlitchedItemRenderer
