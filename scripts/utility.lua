local Utility = {}

function Utility.Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Utility.ConvertToU16(value)
    return value & 0xFFFF
end

function Utility.ConvertToU32(value)
    return value & 0xFFFFFFFF
end

function Utility.ConvertToID32(value)
    value = Utility.ConvertToU32(
        math.floor(value)
    )

    if value >= 0x80000000 then
        return value - 0x100000000
    end

    return value
end

function Utility.ConvertToF32(value)
    return string.unpack('<f', string.pack('<f', value))
end

function Utility.SameFloat(value1, value2)
    return type(value1) == 'number'
        and type(value2) == 'number'
        and (Utility.ConvertToF32(value1)
            == Utility.ConvertToF32(value2))
end

function Utility.GetItemCount()
    return Isaac.GetItemConfig():GetCollectibles().Size
end

function Utility.GetRawProceduralItem(id)
    id = Utility.ConvertToID32(id)
    local index = -id - 1

    if id >= 0
        or id < -1024
        or index >= ProceduralItemManager.GetProceduralItemCount()
    then
        return nil
    end

    return ProceduralItemManager.GetProceduralItem(index)
end

return Utility
