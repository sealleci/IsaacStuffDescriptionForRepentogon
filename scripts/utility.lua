local Utility = {}

function Utility.Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Utility.ConvertToU32(value)
    return value & 0xFFFFFFFF
end

function Utility.GetItemCount()
    return Isaac.GetItemConfig():GetCollectibles().Size
end

return Utility
