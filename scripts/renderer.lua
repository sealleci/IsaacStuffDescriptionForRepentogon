local Renderer = {}

local CONFIG = {
    DESCRIPTION_OFFSET = Vector(0, -65),
    DESCRIPTION_SCALE = 1.0,
    DESCRIPTION_WIDTH = 140,
    CURSOR_SIZE = Vector(8, 8)
}

function Renderer:Initialize(mod)
    self.Mod = mod
    self.EID = mod.EID
end

function Renderer:GetScreenCenter()
    return self.EID:getScreenSize() / 2
end

function Renderer:GetDescription(itemID)
    local success, result = pcall(
        self.EID.getDescriptionObj,
        self.EID,
        EntityType.ENTITY_PICKUP,
        PickupVariant.PICKUP_COLLECTIBLE,
        itemID,
        nil,
        true
    )

    if not success then
        Isaac.ConsoleOutput(
            "[MSD4R] Failed to get EID description "
            .. "for collectible "
            .. tostring(itemID)
            .. ": "
            .. tostring(result)
            .. "\n"
        )

        return nil
    end

    return result
end

function Renderer:RenderCursor(slot)
    local position = slot.Position

    Isaac.DrawQuad(
        position - CONFIG.CURSOR_SIZE,
        position + Vector(CONFIG.CURSOR_SIZE.X, -CONFIG.CURSOR_SIZE.Y),
        position + Vector(-CONFIG.CURSOR_SIZE.X, CONFIG.CURSOR_SIZE.Y),
        position + CONFIG.CURSOR_SIZE,
        KColor(1, 1, 1, 1),
        1
    )
end

function Renderer:RenderDescription(slot)
    local desc = self:GetDescription(slot.ID)

    if not desc then
        return
    end

    local renderPosition = self:GetScreenCenter() + CONFIG.DESCRIPTION_OFFSET
    local prevScale = self.EID.Scale
    local prevTextboxWidth = self.EID.Config["TextboxWidth"]
    local prevInsideItemReminder = self.EID.InsideItemReminder

    self.EID.Scale = CONFIG.DESCRIPTION_SCALE
    self.EID.Config["TextboxWidth"] = CONFIG.DESCRIPTION_WIDTH
    self.EID.InsideItemReminder = true

    local success, err = pcall(
        function()
            local textScale = Vector(
                self.EID.Scale,
                self.EID.Scale
            )

            if desc.Name and desc.Name ~= "" then
                local nameColor = self.EID:getNameColor()

                self.EID:renderString(
                    desc.Name,
                    renderPosition,
                    textScale,
                    nameColor
                )
                renderPosition.Y = renderPosition.Y + self.EID.lineHeight * self.EID.Scale
            end

            if desc.Description and desc.Description ~= "" then
                self.EID:printBulletPoints(
                    desc.Description,
                    renderPosition,
                    desc.IgnoreBulletPointIconConfig
                )
            end
        end
    )

    self.EID.Scale = prevScale
    self.EID.Config["TextboxWidth"] = prevTextboxWidth
    self.EID.InsideItemReminder = prevInsideItemReminder

    if not success then
        Isaac.ConsoleOutput(
            "[MSD4R] EID rendering error: "
            .. tostring(err)
            .. "\n"
        )
    end
end

function Renderer:Render(slot)
    self:RenderCursor(slot)
    self:RenderDescription(slot)
end

return Renderer
