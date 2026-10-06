---@class MSD4RUtility
local Utility = {}

---@type MSD4RMagicConstants
local MAGIC_CONST = include("scripts/magic_const")

---@param value number
---@param minValue number
---@param maxValue number
---@return number result1
function Utility.Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

---@param value integer
---@return integer result1
function Utility.ConvertToU16(value)
    return value & 0xFFFF
end

---@param value integer
---@return integer result1
function Utility.ConvertToU32(value)
    return value & 0xFFFFFFFF
end

---@param value number|string
---@return integer result1
function Utility.ConvertToID32(value)
    value = Utility.ConvertToU32(
        math.floor(value)
    )

    if value >= 0x80000000 then
        return value - 0x100000000
    end

    return value
end

---@param value number
---@return number result1
function Utility.ConvertToF32(value)
    return (string.unpack('<f', string.pack('<f', value)))
end

---@param value1 any
---@param value2 any
---@return boolean result1
function Utility.SameFloat(value1, value2)
    return type(value1) == 'number'
        and type(value2) == 'number'
        and (Utility.ConvertToF32(value1)
            == Utility.ConvertToF32(value2))
end

---@return integer result1
function Utility.GetItemCount()
    return Isaac.GetItemConfig():GetCollectibles().Size
end

---@param id integer
---@return ProceduralItem? result1
function Utility.GetRawProceduralItem(id)
    id = Utility.ConvertToID32(id)
    local index = -id - 1

    if id >= 0
        or id < -MAGIC_CONST.PROCEDURAL_ITEM_SURFACE_COUNT
        or index >= ProceduralItemManager.GetProceduralItemCount()
    then
        return nil
    end

    return ProceduralItemManager.GetProceduralItem(index)
end

---@param text string
---@return nil # No return value.
function Utility.Log(text)
    local formattedText = string.format("[MSD4R] %s\n", text)

    if Isaac and type(Isaac.ConsoleOutput) == "function" then
        Isaac.ConsoleOutput(formattedText)
    else
        print(formattedText)
    end
end

---@type MSD4RUtility
return Utility
