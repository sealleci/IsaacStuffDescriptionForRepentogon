---@class MSD4RModSave
---@field Mod MSD4RMod
---@field Data MSD4RSaveData
---@field SaveAvailable boolean
---@field JsonCodec MSD4RJsonCodec?
local ModSave = {}

---@type MSD4RCoreAPI
local CoreAPI = include("scripts/core_api")
---@type MSD4RUtility
local Utility = include("scripts/utility")

---@type MSD4RSaveData
local DEFAULTS = {
    OffsetX = 0,
    OffsetY = 0,
    IconBrightness = 10, -- [5..20] => [0.5x..2.0x]
    IconOutline = 1,     -- 1 = Off, 2 = Thin, 3 = Full
    OutlineColor = 2,    -- 1 = Black, 2 = White
    RunSeed = 0,
    ProceduralSeeds = {}
}

---@return MSD4RSaveData result1
function ModSave:CopyDefaults()
    local defaults = {}

    for key, value in pairs(DEFAULTS) do
        if type(value) == "table" then
            defaults[key] = {}
        else
            defaults[key] = value
        end
    end

    return defaults
end

---@return nil # No return value.
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
end

---@return nil # No return value.
function ModSave:Load()
    if not self.SaveAvailable or not self.Mod or not self.JsonCodec then
        return
    end

    local loadedSuccessfully, rawData = pcall(
    ---@return string? result1
        function()
            if not self.Mod:HasData() then
                return nil
            end

            return self.Mod:LoadData()
        end
    )

    if not loadedSuccessfully then
        self.Data = self:CopyDefaults()
        Utility.Log("Failed to read save data; default values will be applied.")
        return
    end
    if not rawData
        or rawData == ""
    then
        return
    end

    local successful, decodedData = pcall(self.JsonCodec.decode, rawData)
    if not successful
        or type(decodedData) ~= "table"
    then
        Utility.Log(
            "Failed to load save, "
            .. "default values will be applied."
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

---@param mod MSD4RMod
---@return nil # No return value.
function ModSave:Initialize(mod)
    self.Mod = mod
    self.Data = self:CopyDefaults()

    local saveAvailable, missingAPIs, jsonCodec =
        CoreAPI:CheckSave(mod)

    self.SaveAvailable = saveAvailable
    self.JsonCodec = jsonCodec

    if not saveAvailable then
        CoreAPI:ReportUnavailable("Save", missingAPIs)
        Utility.Log("Default settings will be used.")

        return
    end

    self:Load()
end

---@return nil # No return value.
function ModSave:Save()
    if not self.SaveAvailable or
        not self.Mod or
        not self.JsonCodec
    then
        return
    end

    self:Normalize()

    local successful, encodedData = pcall(self.JsonCodec.encode, self.Data)
    if not successful then
        Utility.Log(
            "Failed to encode save: "
            .. tostring(encodedData)
            .. "."
        )
        return
    end

    local savedSuccessfully, failureReason = pcall(self.Mod.SaveData, self.Mod, encodedData)

    if not savedSuccessfully then
        Utility.Log("Failed to write save data: " .. tostring(failureReason) .. ".")
    end
end

---@param key MSD4RSaveKey
---@param value integer|table
---@return nil # No return value.
function ModSave:Set(key, value)
    if not self.SaveAvailable then
        return
    end

    if DEFAULTS[key] == nil
        or type(DEFAULTS[key]) ~= type(value)
    then
        return
    end

    self.Data[key] = value
    self:Save()
end

---@return Vector result1
function ModSave:GetOffset()
    return Vector(self.Data.OffsetX, self.Data.OffsetY)
end

---@return "off"|"thin"|"full" result1
function ModSave:GetOutlineMode()
    if self.Data.IconOutline == 2 then
        return "thin"
    elseif self.Data.IconOutline == 3 then
        return "full"
    end

    return "off"
end

---@return Color result1
function ModSave:GetOutlineColor()
    if self.Data.OutlineColor == 2 then
        return Color(1, 1, 1, 1)
    end

    return Color(0, 0, 0, 1)
end

---@return Color result1
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

---@return integer result1
function ModSave:GetRunSeed()
    return self.Data.RunSeed
end

---@return MSD4RSavedSeeds result1
function ModSave:GetProceduralSeeds()
    return self.Data.ProceduralSeeds
end

---@type MSD4RModSave
return ModSave
