-- squad.lua — Squad coordination, tactical formations & dynamic attack tokens.
-- Coordinates groups of enemies into cohesive squads with distinct roles.

local Squad = {}
Squad.squads = {}
Squad.maxAttackTokens = 3
Squad.activeTokens = 0

local FORMATIONS = {
    WEDGE = {
        { x = 0, y = -60 },
        { x = -70, y = 30 },
        { x = 70, y = 30 },
        { x = -130, y = 90 },
        { x = 130, y = 90 },
    },
    V = {
        { x = 0, y = 0 },
        { x = -80, y = -60 },
        { x = 80, y = -60 },
        { x = -160, y = -120 },
        { x = 160, y = -120 },
    },
    LINE = {
        { x = -140, y = 0 },
        { x = -70, y = 0 },
        { x = 0, y = 0 },
        { x = 70, y = 0 },
        { x = 140, y = 0 },
    },
    CIRCLE = {
        { x = 0, y = -90 },
        { x = 85, y = -30 },
        { x = 55, y = 75 },
        { x = -55, y = 75 },
        { x = -85, y = -30 },
    },
    SURROUND = {
        { x = 0, y = -160 },
        { x = 150, y = -50 },
        { x = 90, y = 130 },
        { x = -90, y = 130 },
        { x = -150, y = -50 },
    },
}

function Squad.reset()
    Squad.squads = {}
    Squad.activeTokens = 0
end

-- Create a new squad with an assigned formation and leader
function Squad.createSquad(formationType)
    local fNames = { "WEDGE", "V", "LINE", "CIRCLE", "SURROUND" }
    formationType = formationType or fNames[love.math.random(1, #fNames)]

    local s = {
        id = #Squad.squads + 1,
        formation = formationType,
        offsets = FORMATIONS[formationType] or FORMATIONS.WEDGE,
        members = {},
        leader = nil,
        attackTokens = 2,
        coordTimer = 0,
        center = { x = 0, y = 0 },
    }
    Squad.squads[#Squad.squads + 1] = s
    return s
end

-- Add enemy to most suitable squad or create a new squad
function Squad.registerEnemy(e)
    if not e or not e.ai or e.boss then return end

    -- Find an open squad with room (< 5 members)
    local targetSquad = nil
    for _, s in ipairs(Squad.squads) do
        if #s.members < 5 then
            targetSquad = s
            break
        end
    end

    if not targetSquad then
        targetSquad = Squad.createSquad()
    end

    table.insert(targetSquad.members, e)
    e.squad = targetSquad
    e.squadIndex = #targetSquad.members

    if not targetSquad.leader or not targetSquad.leader.alive then
        targetSquad.leader = e
        e.squadRole = "LEADER"
    else
        local roles = { "ATTACKER", "FLANKER", "DISTRACTOR", "SUPPORT" }
        e.squadRole = roles[math.min(#roles, #targetSquad.members)]
    end
end

-- Update all squads, lease attack tokens, and coordinate formations
function Squad.update(dt, player, enemies)
    if not player then return end

    for sIdx = #Squad.squads, 1, -1 do
        local s = Squad.squads[sIdx]

        -- 1. Clean dead squad members
        for mIdx = #s.members, 1, -1 do
            local m = s.members[mIdx]
            if not m.alive then
                table.remove(s.members, mIdx)
            end
        end

        -- If squad is empty, remove it
        if #s.members == 0 then
            table.remove(Squad.squads, sIdx)
        else
            -- 2. Validate/Promote new leader if leader died
            if not s.leader or not s.leader.alive then
                s.leader = s.members[1]
                if s.leader then
                    s.leader.squadRole = "LEADER"
                end
            end

            -- 3. Calculate squad center
            local cx, cy = 0, 0
            for _, m in ipairs(s.members) do
                cx = cx + m.x
                cy = cy + m.y
            end
            s.center.x = cx / #s.members
            s.center.y = cy / #s.members

            -- 4. Dynamic Attack Token Allocation (Max 2 simultaneous attackers per squad)
            s.coordTimer = s.coordTimer + dt
            if s.coordTimer >= 1.2 then
                s.coordTimer = 0
                local tokenCount = 0
                for _, m in ipairs(s.members) do
                    if m.ai then
                        if tokenCount < s.attackTokens and (m.squadRole == "ATTACKER" or m.squadRole == "LEADER") then
                            m.ai.hasAttackToken = true
                            tokenCount = tokenCount + 1
                        else
                            m.ai.hasAttackToken = false
                        end
                    end
                end
            end

            -- 5. Formation Slot Steering Offset
            for i, m in ipairs(s.members) do
                m.squadIndex = i
                local offset = s.offsets[i] or { x = (i - 1) * 40 - 80, y = 0 }
                if s.leader and m ~= s.leader and m.ai and not m.ai.hasAttackToken then
                    -- Guide non-attacking members gently toward their formation slot
                    local targetSlotX = s.leader.x + offset.x
                    local targetSlotY = s.leader.y + offset.y
                    local slotDx = targetSlotX - m.x
                    local slotDy = targetSlotY - m.y
                    local slotDist = math.sqrt(slotDx * slotDx + slotDy * slotDy)
                    if slotDist > 40 then
                        local pull = math.min(1, slotDist / 120)
                        m.x = m.x + (slotDx / slotDist) * (m.speed or 100) * pull * 0.45 * dt
                        m.y = m.y + (slotDy / slotDist) * (m.speed or 100) * pull * 0.45 * dt
                    end
                end
            end
        end
    end
end

return Squad
