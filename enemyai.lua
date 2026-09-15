-- enemyai.lua — Advanced tactical AI state machine, perception, steering, dodging & prediction.
-- Fully optimized for 60 FPS WebAssembly execution via distance-based time-slicing.

local Sound     = require("sound")
local Particles = require("particles")
local Effects   = require("effects")

local EnemyAI = {}

local atan2 = math.atan2 or math.atan

-- 14 Tactical States
EnemyAI.STATES = {
    IDLE      = "IDLE",
    PATROL    = "PATROL",
    SEARCH    = "SEARCH",
    CHASE     = "CHASE",
    POSITION  = "POSITION",
    ATTACK    = "ATTACK",
    DODGE     = "DODGE",
    RETREAT   = "RETREAT",
    FLANK     = "FLANK",
    DEFEND    = "DEFEND",
    SUPPORT   = "SUPPORT",
    STUNNED   = "STUNNED",
    FLEE      = "FLEE",
    DEAD      = "DEAD",
}

-- Archetype Tuning Parameters & Personalities
EnemyAI.ARCHETYPES = {
    scout = {
        name = "Scout",
        preferredDist = 220,
        detectionRadius = 550,
        aggression = 0.5,
        bravery = 0.4,
        accuracy = 0.75,
        aimError = 0.22,
        reactionDelay = 0.18,
        dodgeChance = 0.65,
        dodgeCooldown = 1.4,
        strafeSpeed = 160,
        retreatThreshold = 0.35,
        fireDelay = 1.4,
        color = { 0.3, 0.85, 1.0 },
    },
    fighter = {
        name = "Fighter",
        preferredDist = 260,
        detectionRadius = 600,
        aggression = 0.85,
        bravery = 0.75,
        accuracy = 0.82,
        aimError = 0.16,
        reactionDelay = 0.10,
        dodgeChance = 0.45,
        dodgeCooldown = 1.8,
        strafeSpeed = 150,
        retreatThreshold = 0.25,
        fireDelay = 0.8,
        color = { 1.0, 0.4, 0.4 },
    },
    interceptor = {
        name = "Interceptor",
        preferredDist = 180,
        detectionRadius = 650,
        aggression = 0.95,
        bravery = 0.9,
        accuracy = 0.88,
        aimError = 0.12,
        reactionDelay = 0.08,
        dodgeChance = 0.65,
        dodgeCooldown = 1.4,
        strafeSpeed = 240,
        retreatThreshold = 0.15,
        fireDelay = 0.5,
        color = { 0.9, 0.3, 1.0 },
    },
    tank = {
        name = "Tank",
        preferredDist = 190,
        detectionRadius = 700,
        aggression = 0.9,
        bravery = 1.0,
        accuracy = 0.75,
        aimError = 0.15,
        reactionDelay = 0.18,
        dodgeChance = 0.20,
        dodgeCooldown = 3.0,
        strafeSpeed = 80,
        retreatThreshold = 0.0,
        fireDelay = 1.2,
        color = { 1.0, 0.7, 0.2 },
    },
    sniper = {
        name = "Sniper",
        preferredDist = 420,
        detectionRadius = 800,
        aggression = 0.6,
        bravery = 0.4,
        accuracy = 0.96,
        aimError = 0.04,
        reactionDelay = 0.15,
        dodgeChance = 0.55,
        dodgeCooldown = 1.6,
        strafeSpeed = 110,
        retreatThreshold = 0.40,
        fireDelay = 1.6,
        color = { 0.4, 1.0, 0.5 },
    },
    support = {
        name = "Support",
        preferredDist = 340,
        detectionRadius = 650,
        aggression = 0.4,
        bravery = 0.4,
        accuracy = 0.65,
        aimError = 0.24,
        reactionDelay = 0.15,
        dodgeChance = 0.65,
        dodgeCooldown = 1.4,
        strafeSpeed = 130,
        retreatThreshold = 0.40,
        fireDelay = 1.4,
        color = { 0.3, 0.9, 0.6 },
    },
    bomber = {
        name = "Bomber",
        preferredDist = 120,
        detectionRadius = 600,
        aggression = 1.0,
        bravery = 1.0,
        accuracy = 0.70,
        aimError = 0.20,
        reactionDelay = 0.12,
        dodgeChance = 0.25,
        dodgeCooldown = 2.5,
        strafeSpeed = 90,
        retreatThreshold = 0.0,
        fireDelay = 1.4,
        color = { 1.0, 0.5, 0.1 },
    },
    drone = {
        name = "Drone",
        preferredDist = 150,
        detectionRadius = 500,
        aggression = 0.90,
        bravery = 0.8,
        accuracy = 0.75,
        aimError = 0.20,
        reactionDelay = 0.10,
        dodgeChance = 0.40,
        dodgeCooldown = 1.5,
        strafeSpeed = 160,
        retreatThreshold = 0.10,
        fireDelay = 0.9,
        color = { 0.8, 0.8, 0.9 },
    },
    elite = {
        name = "Elite",
        preferredDist = 240,
        detectionRadius = 750,
        aggression = 1.0,
        bravery = 1.0,
        accuracy = 0.95,
        aimError = 0.05,
        reactionDelay = 0.05,
        dodgeChance = 0.75,
        dodgeCooldown = 0.9,
        strafeSpeed = 200,
        retreatThreshold = 0.15,
        fireDelay = 0.4,
        color = { 1.0, 0.85, 0.2 },
    },
}

-- Adaptive Player Profile Tracker
EnemyAI.playerTracker = {
    lastX = 0, lastY = 0,
    vx = 0, vy = 0,
    recentDirections = {},
    closeTime = 0,
    dodgeCount = 0,
    dashCount = 0,
    abilityCount = 0,
    updateTimer = 0,
}

function EnemyAI.updatePlayerTracker(dt, player)
    if not player then return end
    local tracker = EnemyAI.playerTracker
    tracker.updateTimer = tracker.updateTimer + dt

    if tracker.updateTimer >= 0.05 then
        local pvx = (player.x - tracker.lastX) / tracker.updateTimer
        local pvy = (player.y - tracker.lastY) / tracker.updateTimer
        tracker.vx = tracker.vx * 0.7 + pvx * 0.3
        tracker.vy = tracker.vy * 0.7 + pvy * 0.3
        tracker.lastX = player.x
        tracker.lastY = player.y
        tracker.updateTimer = 0

        -- Track recent heading
        local spd = math.sqrt(tracker.vx * tracker.vx + tracker.vy * tracker.vy)
        if spd > 30 then
            table.insert(tracker.recentDirections, 1, { x = tracker.vx / spd, y = tracker.vy / spd })
            if #tracker.recentDirections > 10 then
                table.remove(tracker.recentDirections)
            end
        end
    end
end

-- Initialize AI context on an enemy instance
function EnemyAI.init(e, archetypeKey)
    archetypeKey = archetypeKey or "fighter"
    local cfg = EnemyAI.ARCHETYPES[archetypeKey] or EnemyAI.ARCHETYPES.fighter

    e.ai = {
        archetype = archetypeKey,
        cfg = cfg,
        state = EnemyAI.STATES.CHASE,
        stateTimer = 0,
        perceptionTimer = love.math.random() * 0.1,
        dodgeTimer = 0,
        dodgeCooldown = love.math.random() * cfg.dodgeCooldown,
        dodgeDirX = 0, dodgeDirY = 0,
        aimTargetX = 0, aimTargetY = 0,
        strafeDir = (love.math.random() < 0.5) and 1 or -1,
        strafeTimer = love.math.random(1.5, 3.5),
        flankSide = (love.math.random() < 0.5) and 1 or -1,
        orbitAngle = love.math.random() * math.pi * 2,
        hasAttackToken = false,
        attackTicketTimer = 0,
        reactionDelayTimer = 0,
        supportPulseTimer = 0,
        telegraphTimer = 0,
        telegraphing = false,
        lastThreatDist = 9999,
        targetPlayer = true,
        stuckTimer = 0,
        lastX = e.x, lastY = e.y,
    }
end

-- Update Enemy AI Logic
function EnemyAI.update(e, dt, player, enemies, bullets, fireCallback)
    if not e.alive or not e.ai then return end
    local ai = e.ai
    local cfg = ai.cfg

    ai.stateTimer = ai.stateTimer + dt
    ai.strafeTimer = ai.strafeTimer - dt
    if ai.strafeTimer <= 0 then
        ai.strafeDir = -ai.strafeDir
        ai.strafeTimer = love.math.random(1.8, 3.8)
    end

    if ai.dodgeCooldown > 0 then ai.dodgeCooldown = ai.dodgeCooldown - dt end
    if ai.reactionDelayTimer > 0 then ai.reactionDelayTimer = ai.reactionDelayTimer - dt end

    local dx = player.x - e.x
    local dy = player.y - e.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local nx, ny = 0, 0
    if dist > 0 then nx, ny = dx / dist, dy / dist end

    ai.lastThreatDist = dist

    -- 1. Perception & Danger Scanning (Distance-based time-slicing)
    ai.perceptionTimer = ai.perceptionTimer + dt
    local checkInterval = (dist < 400) and 0.05 or 0.15
    if ai.perceptionTimer >= checkInterval then
        ai.perceptionTimer = 0
        EnemyAI.perceive(e, player, dist, nx, ny, bullets, enemies)
    end

    -- 2. State Machine Transitions & Steering Execution
    if ai.state == EnemyAI.STATES.DODGE then
        EnemyAI.executeDodge(e, dt)
    elseif ai.state == EnemyAI.STATES.RETREAT then
        EnemyAI.executeRetreat(e, dt, nx, ny, cfg)
    elseif ai.state == EnemyAI.STATES.FLANK then
        EnemyAI.executeFlank(e, dt, player, dist, nx, ny, cfg)
    elseif ai.state == EnemyAI.STATES.POSITION then
        EnemyAI.executePosition(e, dt, player, dist, nx, ny, cfg)
    elseif ai.state == EnemyAI.STATES.SUPPORT then
        EnemyAI.executeSupport(e, dt, player, enemies, dist, nx, ny, cfg)
    elseif ai.state == EnemyAI.STATES.ATTACK then
        EnemyAI.executeAttack(e, dt, player, dist, nx, ny, cfg, fireCallback)
    else -- CHASE / PATROL / IDLE
        EnemyAI.executeChase(e, dt, player, dist, nx, ny, cfg)
    end

    -- 3. Soft Local Separation force to avoid enemy clumping
    EnemyAI.applySeparation(e, enemies, dt)

    -- 4. Screen clamping
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local pad = e.radius or 20
    e.x = math.max(pad, math.min(W - pad, e.x))
    e.y = math.max(pad, math.min(H - pad, e.y))
end

-- Perception: Evaluate threats, incoming bullets, and health thresholds
function EnemyAI.perceive(e, player, dist, nx, ny, bullets, enemies)
    local ai = e.ai
    local cfg = ai.cfg

    -- Check health retreat threshold
    local hpFrac = e.hp / (e.maxHp or 1)
    if hpFrac <= cfg.retreatThreshold and ai.state ~= EnemyAI.STATES.RETREAT and ai.state ~= EnemyAI.STATES.DODGE then
        ai.state = EnemyAI.STATES.RETREAT
        ai.stateTimer = 0
        return
    end

    -- Check for incoming dangerous projectiles to trigger DODGE
    if ai.dodgeCooldown <= 0 and bullets and love.math.random() < cfg.dodgeChance then
        for _, b in ipairs(bullets) do
            if b.friendly and b.active then
                local bdx = b.x - e.x
                local bdy = b.y - e.y
                local bdist = math.sqrt(bdx * bdx + bdy * bdy)
                if bdist < 200 then
                    -- Bullet is heading toward enemy
                    local bvx = b.vx or 0
                    local bvy = b.vy or 0
                    local bspd = math.sqrt(bvx * bvx + bvy * bvy)
                    if bspd > 0 then
                        local dot = (bdx * bvx + bdy * bvy) / (bdist * bspd)
                        if dot < -0.65 then
                            -- High threat! Calculate perpendicular dodge vector
                            local perpX = -bvy / bspd
                            local perpY = bvx / bspd
                            if love.math.random() < 0.5 then
                                perpX, perpY = -perpX, -perpY
                            end
                            ai.dodgeDirX = perpX
                            ai.dodgeDirY = perpY
                            ai.dodgeTimer = 0.28
                            ai.dodgeCooldown = cfg.dodgeCooldown + love.math.random() * 0.4
                            ai.state = EnemyAI.STATES.DODGE
                            ai.stateTimer = 0

                            Particles.emit(e.x, e.y, 4, {
                                speed = 60, life = 0.2, size = 2,
                                r = cfg.color[1], g = cfg.color[2], b = cfg.color[3]
                            })
                            return
                        end
                    end
                end
            end
        end
    end

    -- Tactical Role State Allocation
    if ai.state ~= EnemyAI.STATES.DODGE and ai.state ~= EnemyAI.STATES.RETREAT then
        if ai.archetype == "support" then
            ai.state = EnemyAI.STATES.SUPPORT
        elseif ai.archetype == "sniper" then
            if dist < cfg.preferredDist * 0.75 then
                ai.state = EnemyAI.STATES.RETREAT
            else
                ai.state = EnemyAI.STATES.ATTACK
            end
        elseif ai.archetype == "interceptor" or (ai.archetype == "scout" and love.math.random() < 0.45) then
            if dist < cfg.preferredDist * 1.5 and dist > cfg.preferredDist * 0.6 then
                ai.state = EnemyAI.STATES.FLANK
            else
                ai.state = ai.hasAttackToken and EnemyAI.STATES.ATTACK or EnemyAI.STATES.POSITION
            end
        else
            if dist <= cfg.preferredDist * 1.3 then
                ai.state = ai.hasAttackToken and EnemyAI.STATES.ATTACK or EnemyAI.STATES.POSITION
            else
                ai.state = EnemyAI.STATES.CHASE
            end
        end
    end
end

-- Dodge execution: Rapid burst evasive maneuver
function EnemyAI.executeDodge(e, dt)
    local ai = e.ai
    ai.dodgeTimer = ai.dodgeTimer - dt
    local dodgeSpd = (e.speed or 120) * 2.2
    e.x = e.x + ai.dodgeDirX * dodgeSpd * dt
    e.y = e.y + ai.dodgeDirY * dodgeSpd * dt

    if ai.dodgeTimer <= 0 then
        ai.state = EnemyAI.STATES.POSITION
        ai.stateTimer = 0
    end
end

-- Retreat execution: Back away to recover distance or safety
function EnemyAI.executeRetreat(e, dt, nx, ny, cfg)
    local retreatSpd = (e.speed or 100) * 1.1
    local rx = -nx + (e.ai.strafeDir * 0.4)
    local ry = -ny
    local len = math.sqrt(rx * rx + ry * ry)
    if len > 0 then rx, ry = rx / len, ry / len end

    e.x = e.x + rx * retreatSpd * dt
    e.y = e.y + ry * retreatSpd * dt

    if e.ai.lastThreatDist > cfg.preferredDist * 1.6 or e.ai.stateTimer > 3.0 then
        e.ai.state = EnemyAI.STATES.POSITION
        e.ai.stateTimer = 0
    end
end

-- Flank execution: Arc around player flank/rear
function EnemyAI.executeFlank(e, dt, player, dist, nx, ny, cfg)
    local ai = e.ai
    local fx = -ny * ai.flankSide
    local fy = nx * ai.flankSide
    local radDiff = dist - cfg.preferredDist
    local radNorm = math.max(-1, math.min(1, radDiff / 100))

    local mx = fx * 0.85 + nx * radNorm * 0.5
    local my = fy * 0.85 + ny * radNorm * 0.5
    local len = math.sqrt(mx * mx + my * my)
    if len > 0 then mx, my = mx / len, my / len end

    local flankSpd = cfg.strafeSpeed or 140
    e.x = e.x + mx * flankSpd * dt
    e.y = e.y + my * flankSpd * dt
end

-- Position execution: Orbit and maintain combat range while waiting for attack opening
function EnemyAI.executePosition(e, dt, player, dist, nx, ny, cfg)
    local ai = e.ai
    local targetDist = cfg.preferredDist
    local diff = dist - targetDist

    local approachSpd = math.max(-1, math.min(1, diff / 80))
    local sx = -ny * ai.strafeDir
    local sy = nx * ai.strafeDir

    local vx = nx * approachSpd * 0.6 + sx * 0.7
    local vy = ny * approachSpd * 0.6 + sy * 0.7
    local len = math.sqrt(vx * vx + vy * vy)
    if len > 0 then vx, vy = vx / len, vy / len end

    local spd = cfg.strafeSpeed or (e.speed or 100)
    e.x = e.x + vx * spd * dt
    e.y = e.y + vy * spd * dt
end

-- Chase execution: Close distance aggressively
function EnemyAI.executeChase(e, dt, player, dist, nx, ny, cfg)
    local spd = e.speed or 120
    e.x = e.x + nx * spd * dt
    e.y = e.y + ny * spd * dt
end

-- Support execution: Stay behind frontline allies and emit nanite healing/buff pulses
function EnemyAI.executeSupport(e, dt, player, enemies, dist, nx, ny, cfg)
    local ai = e.ai
    local sx = -nx
    local sy = -ny
    local spd = e.speed or 90
    e.x = e.x + sx * spd * dt
    e.y = e.y + sy * spd * dt

    ai.supportPulseTimer = (ai.supportPulseTimer or 0) + dt
    if ai.supportPulseTimer >= 2.5 then
        ai.supportPulseTimer = 0
        for _, ally in ipairs(enemies) do
            if ally ~= e and ally.alive then
                local adx = ally.x - e.x
                local ady = ally.y - e.y
                if adx * adx + ady * ady < 180 * 180 then
                    ally.hp = math.min(ally.maxHp or ally.hp, ally.hp + 6)
                    ally.hitFlash = 0.12
                    Particles.emit(ally.x, ally.y, 4, {
                        speed = 50, life = 0.3, size = 2.5,
                        r = 0.2, g = 1.0, b = 0.6
                    })
                end
            end
        end
        Effects.spawnShockwave(e.x / love.graphics.getWidth(), e.y / love.graphics.getHeight(), 0.03)
        Sound.play("powerup", 0.6)
    end
end

-- Attack execution: Aim with predictive lead + aim error, charge shot, and fire
function EnemyAI.executeAttack(e, dt, player, dist, nx, ny, cfg, fireCallback)
    local ai = e.ai

    local bspeed = e.def.bulletSpeed or 320
    local travelTime = dist / bspeed
    local tracker = EnemyAI.playerTracker

    local predX = player.x + (tracker.vx or 0) * travelTime * (cfg.accuracy or 0.8)
    local predY = player.y + (tracker.vy or 0) * travelTime * (cfg.accuracy or 0.8)

    local errorAngle = (love.math.random() - 0.5) * (cfg.aimError or 0.15) * 2
    local aimDx = predX - e.x
    local aimDy = predY - e.y
    local aimAng = atan2(aimDy, aimDx) + errorAngle
    local aimNx = math.cos(aimAng)
    local aimNy = math.sin(aimAng)

    ai.aimTargetX = e.x + aimNx * 200
    ai.aimTargetY = e.y + aimNy * 200

    if ai.archetype == "sniper" then
        if not ai.telegraphing and e.fireTimer <= 0.6 then
            ai.telegraphing = true
            ai.telegraphTimer = 0.6
            Sound.play("laser-1", 0.5)
        end
        if ai.telegraphing then
            ai.telegraphTimer = ai.telegraphTimer - dt
            if ai.telegraphTimer <= 0 then
                ai.telegraphing = false
            end
        end
    end

    e.fireTimer = (e.fireTimer or 0) - dt
    if e.fireTimer <= 0 then
        e.fireTimer = cfg.fireDelay or (e.def.fireCooldown or 1.5)
        if fireCallback then
            local bspd = e.def.bulletSpeed or 320
            fireCallback({
                x = e.x, y = e.y,
                vx = aimNx * bspd,
                vy = aimNy * bspd,
                damage = e.damage or 1,
                friendly = false,
                size = (ai.archetype == "sniper") and 7 or 5,
                bulletKey = (ai.archetype == "sniper") and "laser3" or "laser2",
                color = (ai.archetype == "sniper") and { 0.4, 1.0, 0.5 } or { 1.0, 0.3, 0.3 },
                life = 2.8,
            })
        end
    end

    EnemyAI.executePosition(e, dt, player, dist, nx, ny, cfg)
end

-- Apply soft separation force between enemy units
function EnemyAI.applySeparation(e, enemies, dt)
    if not enemies then return end
    local sepX, sepY = 0, 0
    local radius = (e.radius or 20) * 2.2
    local r2 = radius * radius

    for _, other in ipairs(enemies) do
        if other ~= e and other.alive then
            local dx = e.x - other.x
            local dy = e.y - other.y
            local d2 = dx * dx + dy * dy
            if d2 > 0 and d2 < r2 then
                local d = math.sqrt(d2)
                local force = (radius - d) / radius
                sepX = sepX + (dx / d) * force * 110
                sepY = sepY + (dy / d) * force * 110
            end
        end
    end

    e.x = e.x + sepX * dt
    e.y = e.y + sepY * dt
end

-- Render visual feedback
function EnemyAI.draw(e)
    if not e.alive or not e.ai then return end
    local ai = e.ai

    if ai.telegraphing and ai.archetype == "sniper" then
        local progress = 1.0 - (ai.telegraphTimer / 0.6)
        love.graphics.setColor(1.0, 0.2, 0.2, 0.25 + progress * 0.5)
        love.graphics.setLineWidth(1 + progress * 2)
        love.graphics.line(e.x, e.y, ai.aimTargetX, ai.aimTargetY)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return EnemyAI
