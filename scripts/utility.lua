local Utility = {}

function Utility.Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Utility.ConvertToU32(value)
    return value & 0xFFFFFFFF
end

function Utility.ConvertToKColor(color)
    if color == nil then
        return KColor(1, 1, 1, 1)
    end

    return KColor(
        color.R or 1,
        color.G or 1,
        color.B or 1,
        color.A or 1
    )
end

function Utility.GetItemCount()
    return Isaac.GetItemConfig():GetCollectibles().Size
end

return Utility
