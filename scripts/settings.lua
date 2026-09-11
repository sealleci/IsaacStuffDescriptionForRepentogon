local json = require("json")
local Settings = {}
local DEFAULTS = {
    OffsetX = 0,
    OffsetY = 0,
    IconBrightness = 10, -- [5..20] => [0.5x..2.0x]
    IconOutline = 1,     -- 1 = Off, 2 = Thin, 3 = Full
    OutlineColor = 2     -- 1 = Black, 2 = White
}

function Settings:CopyDefaults()
    local defaults = {}

    for key, value in pairs(DEFAULTS) do
        defaults[key] = value
    end

    return defaults
end

function Settings:Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Settings:Normalize()
    self.Data.OffsetX = self:Clamp(
        math.floor(tonumber(self.Data.OffsetX)
            or DEFAULTS.OffsetX),
        -200,
        200
    )
    self.Data.OffsetY = self:Clamp(
        math.floor(tonumber(self.Data.OffsetY)
            or DEFAULTS.OffsetY),
        -200,
        200
    )
    self.Data.IconBrightness = self:Clamp(
        math.floor(tonumber(self.Data.IconBrightness)
            or DEFAULTS.IconBrightness),
        5,
        20
    )
    self.Data.IconOutline = self:Clamp(
        math.floor(tonumber(self.Data.IconOutline)
            or DEFAULTS.IconOutline),
        1,
        3
    )
    self.Data.OutlineColor = self:Clamp(
        math.floor(tonumber(self.Data.OutlineColor)
            or DEFAULTS.OutlineColor),
        1,
        2
    )
end

function Settings:Load()
    if not self.Mod
        or not self.Mod:HasData()
    then
        return
    end

    local rawData = self.Mod:LoadData()
    if not rawData or rawData == "" then
        return
    end

    local successful, decodedData = pcall(json.decode, rawData)
    if not successful
        or type(decodedData) ~= "table" then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to load settings, default values will be applied.\n"
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

function Settings:Initialize(mod)
    self.Mod = mod
    self.Data = self:CopyDefaults()
    self:Load()
end

function Settings:Save()
    if not self.Mod then
        return
    end

    self:Normalize()

    local successful, encodedData = pcall(json.encode, self.Data)
    if not successful then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to encode settings: "
            .. tostring(encodedData)
            .. "\n"
        )
        return
    end

    self.Mod:SaveData(encodedData)
end

function Settings:Set(key, value)
    if DEFAULTS[key] == nil
        or type(DEFAULTS[key]) ~= type(value)
    then
        return
    end

    self.Data[key] = value
    self:Normalize()
    self:Save()
end

function Settings:GetOffset()
    return Vector(self.Data.OffsetX, self.Data.OffsetY)
end

function Settings:GetOutlineMode()
    if self.Data.IconOutline == 2 then
        return "thin"
    elseif self.Data.IconOutline == 3 then
        return "full"
    end

    return "off"
end

function Settings:GetOutlineColor()
    if self.Data.OutlineColor == 2 then
        return Color(1, 1, 1, 1)
    end

    return Color(0, 0, 0, 1)
end

function Settings:GetIconColor()
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

return Settings
