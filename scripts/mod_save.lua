local ModSave = {}
local json = require("json")
local Utility = include("scripts/utility")
local DEFAULTS = {
    OffsetX = 0,
    OffsetY = 0,
    IconBrightness = 10, -- [5..20] => [0.5x..2.0x]
    IconOutline = 1,     -- 1 = Off, 2 = Thin, 3 = Full
    OutlineColor = 2,    -- 1 = Black, 2 = White
    RunSeed = 0,
    Seeds = {},
    ExtraRNG = 0
}

function ModSave:CopyDefaults()
    local defaults = {}

    for key, value in pairs(DEFAULTS) do
        defaults[key] = value
    end

    return defaults
end

function ModSave:Normalize()
    self.Data.OffsetX = Utility.Clamp(
        math.floor(tonumber(self.Data.OffsetX)
            or DEFAULTS.OffsetX),
        -200,
        200
    )
    self.Data.OffsetY = Utility.Clamp(
        math.floor(tonumber(self.Data.OffsetY)
            or DEFAULTS.OffsetY),
        -200,
        200
    )
    self.Data.IconBrightness = Utility.Clamp(
        math.floor(tonumber(self.Data.IconBrightness)
            or DEFAULTS.IconBrightness),
        5,
        20
    )
    self.Data.IconOutline = Utility.Clamp(
        math.floor(tonumber(self.Data.IconOutline)
            or DEFAULTS.IconOutline),
        1,
        3
    )
    self.Data.OutlineColor = Utility.Clamp(
        math.floor(tonumber(self.Data.OutlineColor)
            or DEFAULTS.OutlineColor),
        1,
        2
    )
    self.Data.ExtraRNG = Utility.Clamp(
        math.floor(tonumber(self.Data.ExtraRNG)
            or DEFAULTS.ExtraRNG),
        0,
        500
    )
end

function ModSave:Load()
    if not self.Mod
        or not self.Mod:HasData()
    then
        return
    end

    local rawData = self.Mod:LoadData()
    if not rawData
        or rawData == ""
    then
        return
    end

    local successful, decodedData = pcall(json.decode, rawData)
    if not successful
        or type(decodedData) ~= "table"
    then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to load save, "
            .. "default values will be applied.\n"
        )
        return
    end

    for key, defaultValue in pairs(DEFAULTS) do
        local newValue = decodedData[key]
        if type(newValue) == type(defaultValue) then
            self.Data[key] = newValue
        end
    end

    self:Normalize()
end

function ModSave:Initialize(mod)
    self.Mod = mod
    self.Data = self:CopyDefaults()
    self:Load()
end

function ModSave:Save()
    if not self.Mod then
        return
    end

    self:Normalize()

    local successful, encodedData = pcall(json.encode, self.Data)
    if not successful then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to encode save: "
            .. tostring(encodedData)
            .. "\n"
        )
        return
    end

    self.Mod:SaveData(encodedData)
end

function ModSave:Set(key, value)
    if DEFAULTS[key] == nil
        or type(DEFAULTS[key]) ~= type(value)
    then
        return
    end

    self.Data[key] = value
    self:Save()
end

function ModSave:GetOffset()
    return Vector(self.Data.OffsetX, self.Data.OffsetY)
end

function ModSave:GetOutlineMode()
    if self.Data.IconOutline == 2 then
        return "thin"
    elseif self.Data.IconOutline == 3 then
        return "full"
    end

    return "off"
end

function ModSave:GetOutlineColor()
    if self.Data.OutlineColor == 2 then
        return Color(1, 1, 1, 1)
    end

    return Color(0, 0, 0, 1)
end

function ModSave:GetIconColor()
    local brightness = self.Data.IconBrightness / 10
    if brightness <= 1 then
        return Color(
            brightness,
            brightness,
            brightness,
            1
        )
    end

    local colorOffset = brightness - 1
    return Color(
        1 - colorOffset,
        1 - colorOffset,
        1 - colorOffset,
        1,
        colorOffset,
        colorOffset,
        colorOffset
    )
end

function ModSave:GetRunSeed()
    return self.Data.RunSeed
end

function ModSave:GetSeeds()
    return self.Data.Seeds
end

function ModSave:GetExtraRNG()
    return self.Data.ExtraRNG
end

return ModSave
