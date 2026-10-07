---@meta
--[[
Shared project types for LuaLS (LuaCATS). Do not include this file at runtime.
Engine types (Vector, Sprite, Image, RNG, etc.) come from the Isaac / REPENTOGON annotation extension.
Project types use an MSD4R prefix to avoid collisions.
]]

---@alias MSD4RSeedMap table<integer, integer[]>
---@alias MSD4RSeedSourceMap table<integer, table<string, string[]>>
---@alias MSD4RSaveKey "OffsetX"|"OffsetY"|"IconBrightness"|"IconOutline"|"OutlineColor"|"RunSeed"|"ProceduralSeeds"
---@alias MSD4RIconQuad [SourceQuad, DestinationQuad, Color, Image]

---@class MSD4RSaveData
---@field OffsetX integer
---@field OffsetY integer
---@field IconBrightness integer
---@field IconOutline 1|2|3
---@field OutlineColor 1|2
---@field RunSeed integer
---@field ProceduralSeeds table<string, integer[]|integer>

---@class MSD4RJsonCodec
---@field encode fun(value: any): string
---@field decode fun(text: string): any

---@class MSD4RCollectibleSlot
---@field ID integer
---@field IsTrinket false
---@field Index integer
---@field ProceduralSeed integer[]?

---@class MSD4RTrinketSlot
---@field ID integer
---@field IsTrinket true
---@field Index integer
---@field ProceduralSeed integer[]|integer|nil

---@alias MSD4RItemSlot MSD4RCollectibleSlot|MSD4RTrinketSlot

---@class MSD4RHiddenLayer
---@field SpriteName "PauseMenu"|"PauseStats"
---@field LayerID integer

---@class MSD4RFrameInfo
---@field Layer LayerState?
---@field Frame AnimationFrame?
---@field Position Vector
---@field Pivot Vector
---@field Scale Vector
---@field Width number
---@field Height number
---@field Size Vector
---@field TopLeft Vector

---@class MSD4RLayout
---@field Mode "fixed"|"auto"
---@field ItemOrigin Vector
---@field ItemScale Vector
---@field ItemStep Vector
---@field MyStuffFrame MSD4RFrameInfo

---@class MSD4RDescription
---@field Name string?
---@field Description string?
---@field Quality integer?
---@field IgnoreBulletPointIconConfig boolean?

---@class MSD4REIDConfig
---@field TextboxWidth number

---@class MSD4REID
---@field Scale number
---@field lineHeight number
---@field Config MSD4REIDConfig
---@field InsideItemReminder boolean?
---@field CheckGlitchedItemConfig fun(self: MSD4REID, itemID: integer): string
---@field getDescriptionObj fun(self: MSD4REID, entityType: integer, variant: integer, subtype: integer, entity: Entity?, ignoreVisibility: boolean): MSD4RDescription
---@field getNameColor fun(self: MSD4REID): KColor
---@field renderString fun(self: MSD4REID, text: string, position: Vector, scale: Vector, color: KColor)
---@field printBulletPoints fun(self: MSD4REID, text: string, position: Vector, ignoreBulletPointIconConfig: boolean?)

---@class MSD4RRerollWindow
---@field Seed integer
---@field Shift integer
---@field Count integer
---@field Run integer
---@field Frame integer
---@field Player EntityPlayer

---@class MSD4RMatchedSeed
---@field ID integer
---@field Seed integer

---@class MSD4RPendingItem
---@field ID integer
---@field Snapshot MSD4RSnapshot

---@class MSD4REntitySelection
---@field type integer
---@field variant integer

---@class MSD4REntityRecord: MSD4REntitySelection
---@field key integer
---@field subtype integer
---@field boss boolean

---@class MSD4RTrinketRecord
---@field ID integer
---@field CacheFlags integer

---@class MSD4RItemRecord: MSD4RTrinketRecord
---@field Type integer
---@field MaxCharges integer
---@field ChargeType integer
---@field Quality integer
---@field GfxFileName string

---@class MSD4REnvironment
---@field items table<integer, MSD4RItemRecord>
---@field trinkets table<integer, MSD4RTrinketRecord>
---@field active MSD4RItemRecord[]
---@field itemCount integer
---@field trinketCount integer
---@field entities MSD4REntityRecord[]
---@field baseEntities table<integer, MSD4REntityRecord>
---@field byType table<integer, MSD4REntityRecord[]>

---@class MSD4REffectProperties
---@field id integer?
---@field type integer?
---@field variant integer?
---@field fromType integer?
---@field fromVariant integer?
---@field toType integer?
---@field toVariant integer?
---@field radius number?
---@field damage number?
---@field scale number?
---@field flags1 integer?
---@field flags2 integer?

---@class MSD4RSnapshotEffect
---@field ConditionType integer
---@field ActionType integer
---@field ActionProperty MSD4REffectProperties
---@field ConditionProperty MSD4REffectProperties
---@field Score number

---@class MSD4RReplayEffect: MSD4RSnapshotEffect
---@field Seed integer
---@field EffectEndState integer

---@class MSD4RRecipeTile
---@field SourceTileIndex integer
---@field SourceImageIndex integer
---@field ColorIndex integer

---@class MSD4RPreEffects
---@field State integer
---@field Budget number
---@field Health integer[]
---@field Stats number[]
---@field TargetID integer
---@field TargetTrinket boolean
---@field ItemType integer
---@field MaxCharges integer
---@field ChargeType integer

---@class MSD4REffectAttempt
---@field Seed integer
---@field Score number
---@field Accepted boolean
---@field State integer

---@class MSD4RReplayResult
---@field ItemID integer?
---@field EffectiveSeed integer
---@field TextState integer
---@field PreEffects MSD4RPreEffects
---@field Effects MSD4RReplayEffect[]
---@field EffectsEndState integer
---@field Score number
---@field Attempts MSD4REffectAttempt[]
---@field GraphicsState integer
---@field DevilPrice integer
---@field ShopPrice integer
---@field Recipe MSD4RRecipeTile[]
---@field SourceItems table<integer, integer>
---@field Hue number
---@field IconImage Image?

---@class MSD4RSnapshotItem
---@field ID integer
---@field Type integer
---@field MaxCharges integer
---@field ChargeType integer
---@field DevilPrice integer
---@field ShopPrice integer
---@field CacheFlags integer
---@field AddMaxHearts integer
---@field AddHearts integer
---@field AddSoulHearts integer
---@field AddBlackHearts integer
---@field AddBombs integer
---@field AddKeys integer
---@field AddCoins integer

---@class MSD4RSnapshot
---@field Item MSD4RSnapshotItem
---@field Stats number[]
---@field Effects MSD4RSnapshotEffect[]
---@field TargetID integer?

---@class MSD4RFieldDifference
---@field Field string
---@field Actual number|string|boolean
---@field Expected number|string|boolean

---@class MSD4RCandidateConfig
---@field Seed integer?
---@field Flags integer?
---@field EffectiveSeed integer?
---@field PreEffects MSD4RPreEffects?
---@field Effects MSD4RReplayEffect[]?
---@field GraphicsState integer?
---@field DevilPrice integer?
---@field ShopPrice integer?

---@class MSD4RDifferenceReport
---@field ItemConfig MSD4RCandidateConfig
---@field Differences MSD4RFieldDifference[]
---@field Checks integer
---@field MatchedCount integer
---@field PrefixMatchedCount integer
---@field ArePreEffectsMatched boolean
---@field Valid boolean
---@field Summary string

---@class MSD4RDiagnostic
---@field ItemID integer
---@field Seeds integer[]
---@field KnownFlags integer[]
---@field DifferenceReports MSD4RDifferenceReport[]
---@field BestDifferenceReportIndex integer

---@class MSD4RProcessingResult
---@field ReplayResult MSD4RReplayResult?
---@field FailureReason string?
---@field Diagnostic MSD4RDiagnostic?

---@class MSD4RDiagnosticContext
---@field RunSeed integer?
---@field SeedSources table<string, string[]>?

---@class MSD4RMagicConstants
---@field GLITCHED_ITEM_MASK integer
---@field PROCEDURAL_ITEM_SURFACE_COUNT integer

---@class MSD4RUIConfig
---@field ITEMS_DISPLAY_ROW_COUNT integer
---@field ITEMS_DISPLAY_COLUMN_COUNT integer
---@field ITEMS_DISPLAY_STEP_X integer
---@field ITEMS_DISPLAY_STEP_Y integer
---@field GetColumnNumber fun(self: MSD4RUIConfig, index: integer): integer

---@class MSD4RMenuInfo
---@field CATEGORY string
---@field OUTLINE_MODES string[]
---@field OUTLINE_COLORS string[]

---@class MSD4RGlitchedConfig
---@field VANILLA_LAST_ITEM_ID integer

---@class MSD4RReplayConfig
---@field INITIAL_GLOBAL_COLOR integer
---@field EXCLUDED_ACTIVE table<integer, boolean>
---@field ITEM_FIELD_KEYS string[]
---@field HEALTH_METHODS string[]
---@field STAT_METHODS string[]
---@field ACTION_FIELDS string[]

---@class MSD4RRendererConfig
---@field PAUSE_MENU_RENDER_ORIGIN_OFFSET Vector
---@field PIVOT_AT_ITEMS_DISPLAY_ROW_NUMBER number
---@field PIVOT_AT_ITEMS_DISPLAY_COLUMN_NUMBER number
---@field CURSOR_SIZE Vector
---@field CURSOR_DISPLAY_OFFSET Vector
---@field DESCRIPTION_WIDTH integer
---@field DESCRIPTION_SCALE number
---@field DESCRIPTION_DISPLAY_OFFSET Vector
---@field FIXED_MY_STUFF_PAGE_TOP_LEFT Vector
---@field FIXED_MY_STUFF_PAGE_PIVOT Vector
---@field FIXED_MY_STUFF_PAGE_SIZE Vector
---@field MY_STUFF_FRAME_POSITION_LIMIT integer
---@field AUTO_LAYOUT_MIN_SCALE number
---@field AUTO_LAYOUT_MAX_SCALE number
---@field THIN_OUTLINE_OFFSETS Vector[]
---@field FULL_OUTLINE_OFFSETS Vector[]
---@field PLAYER_TYPE_TO_AVATAR_LAYER_ID table<integer, integer>
---@field PLACEHOLDER_AVATAR_LAYER_ID integer

---@class MSD4RCoreAPIConfig
---@field EID_MOD_ID string
---@field SPRITE_METHODS string[]

---@alias MSD4RSavedSeeds table<string, integer[]|integer>
---@alias MSD4RPlayerSlots table<integer, MSD4RItemSlot[]>
---@alias MSD4RSourceItems table<integer, integer>
