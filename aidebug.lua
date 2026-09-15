-- aidebug.lua — Real-time developer AI & Boss debug telemetry overlay.
-- Toggled with the F3 key (disabled by default in production).

local Assets = require("assets")
local Squad  = require("squad")
local Boss   = require("boss")

local AIDebug = {
    enabled = false
}

function AIDebug.toggle()
    AIDebug.enabled = not AIDebug.enabled
end

function AIDebug.draw(enemies, player)
    if not AIDebug.enabled then return end

    local font = Assets.fonts.small
    love.graphics.setFont(font)

    -- 1. Squad Links & Formation Centers
    for _, s in ipairs(Squad.squads or {}) do
        if s.leader and s.leader.alive then
            love.graphics.setColor(0.3, 0.8, 1.0, 0.4)
            for _, m in ipairs(s.members) do
                if m ~= s.leader and m.alive then
                    love.graphics.line(s.leader.x, s.leader.y, m.x, m.y)
                end
            end
            -- Leader Star Badge
            love.graphics.setColor(1.0, 0.85, 0.2, 0.9)
            love.graphics.circle("line", s.leader.x, s.leader.y, s.leader.radius + 6)
        end
    end

    -- 2. Enemy AI State Badges & Aim Rays
    for _, e in ipairs(enemies or {}) do
        if e.alive and e.ai then
            local ai = e.ai
            -- State Badge
            local stateCol = (ai.state == "DODGE") and { 0.2, 1.0, 0.4 }
                or ((ai.state == "ATTACK") and { 1.0, 0.3, 0.3 }
                or ((ai.state == "RETREAT") and { 1.0, 0.8, 0.2 }
                or { 0.4, 0.8, 1.0 }))

            love.graphics.setColor(stateCol[1], stateCol[2], stateCol[3], 0.9)
            local badge = string.format("[%s:%s]", ai.archetype:upper(), ai.state)
            if ai.hasAttackToken then badge = badge .. " *" end
            local tw = font:getWidth(badge)
            love.graphics.print(badge, e.x - tw / 2, e.y - e.radius - 16)

            -- Aim ray
            if ai.aimTargetX and ai.aimTargetY then
                love.graphics.setColor(1, 0.2, 0.2, 0.25)
                love.graphics.line(e.x, e.y, ai.aimTargetX, ai.aimTargetY)
            end
        end
    end

    -- 3. Boss Telemetry HUD
    local b = Boss.active
    if b and b.alive then
        love.graphics.setColor(1, 0.9, 0.2, 0.95)
        local bInfo = string.format("BOSS: %s | STATE: %s | PHASE: %d | HP: %d/%d", b.name, b.state, b.phase, math.floor(b.hp), b.maxHp)
        love.graphics.print(bInfo, 40, 80)
    end

    -- Overlay indicator
    love.graphics.setColor(0.3, 0.9, 1.0, 0.8)
    love.graphics.print("[F3: AI DEV DEBUG ACTIVE]", 40, love.graphics.getHeight() - 25)
    love.graphics.setColor(1, 1, 1, 1)
end

return AIDebug
