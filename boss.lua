-- boss.lua — Reusable multi-phase BossController, visual telegraphs & 5 unique boss templates.
-- Triple laser beams, aggressive combat AI, support rally, vulnerability windows.

local Assets    = require("assets")
local Sound     = require("sound")
local Particles = require("particles")
local Effects   = require("effects")

local Boss = {}
Boss.active = nil

local atan2 = math.atan2 or math.atan

-- Helper: fire a properly formed bullet opts table
local function bossFireBullet(fireBullet, x, y, dirX, dirY, speed, damage)
    if not fireBullet then return end
    fireBullet({
        x = x, y = y,
        vx = dirX * speed,
        vy = dirY * speed,
        damage = damage or 1,
        friendly = false,
        size = 6,
        bulletKey = "plasm",
        color = { 0.9, 0.4, 1.0 },
        life = 3.2,
    })
end

Boss.TEMPLATES = {
    voidHunter = {
        name = "VOID HUNTER",
        title = "Apex Infiltrator Flagship",
        asset = "miniboss",
        radius = 50,
        maxHp = 420,
        shield = 100,
        speed = 110,
        color = { 0.95, 0.25, 0.45 },
        attacks = { "dash", "missiles", "tripleLaser", "laserSweep" },
        dashCooldown = 5.0,
    },
    ironColossus = {
        name = "IRON COLOSSUS",
        title = "Dreadnought Fortress",
        asset = "miniboss",
        radius = 64,
        maxHp = 680,
        shield = 180,
        speed = 45,
        color = { 1.0, 0.65, 0.20 },
        attacks = { "barrage", "shockwave", "radialBurst", "tripleLaser" },
        dashCooldown = 8.0,
    },
    swarmQueen = {
        name = "SWARM QUEEN",
        title = "Hive Mother Vessel",
        asset = "miniboss",
        radius = 54,
        maxHp = 460,
        shield = 80,
        speed = 70,
        color = { 0.35, 1.0, 0.45 },
        attacks = { "summonBrood", "acidPlasma", "ringVolley", "tripleLaser" },
        dashCooldown = 6.5,
    },
    phantom = {
        name = "PHANTOM",
        title = "Dimensional Ghost Class",
        asset = "miniboss",
        radius = 48,
        maxHp = 390,
        shield = 120,
        speed = 135,
        color = { 0.75, 0.35, 1.0 },
        attacks = { "phaseWarp", "feintDash", "tripleLaser", "laserCross" },
        dashCooldown = 4.5,
    },
    starDevourer = {
        name = "STAR DEVOURER",
        title = "Omega Orbital Leviathan",
        asset = "miniboss",
        radius = 72,
        maxHp = 950,
        shield = 250,
        speed = 50,
        color = { 1.0, 0.20, 0.25 },
        attacks = { "orbitalSweep", "bulletHelix", "enrageBarrage", "summonBrood", "tripleLaser" },
        dashCooldown = 6.0,
    },
}

function Boss.reset()
    Boss.active = nil
end

-- Spawn a boss instance from template
function Boss.spawn(templateKey, x, y)
    local tpl = Boss.TEMPLATES[templateKey] or Boss.TEMPLATES.voidHunter
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    local b = {
        key = templateKey,
        tpl = tpl,
        name = tpl.name,
        title = tpl.title,
        x = W / 2,
        y = -150,
        targetY = H * 0.24,
        vx = 0, vy = 0,
        radius = tpl.radius,
        hp = tpl.maxHp,
        maxHp = tpl.maxHp,
        shield = tpl.shield,
        maxShield = tpl.shield,
        speed = tpl.speed,
        color = tpl.color,
        alive = true,
        boss = true,

        -- 4-Phase System
        phase = 1,
        enraged = false,
        phaseTransitionTimer = 0,

        -- Combat State
        state = "INTRO", -- INTRO, COMBAT, TELEGRAPHING, ATTACKING, VULNERABLE, DEFEAT
        stateTimer = 2.0,
        attackCooldown = 2.0,
        currentAttack = nil,
        aggressionTimer = 0,
        rallyTriggered = false,

        -- Telegraph & Vulnerability Engine
        telegraphType = nil, -- "laser", "dash", "ring", "summon"
        telegraphTimer = 0,
        telegraphMax = 1.0,
        telegraphAimX = 0,
        telegraphAimY = 0,
        vulnerable = false,
        vulnerableTimer = 0,

        -- Attack Mechanics
        dashTargetX = 0, dashTargetY = 0,
        dashTimer = 0,
        laserCharging = false,
        laserFiring = false,
        laserTimer = 0,
        laserAngle = 0,
        -- Triple Laser System
        tripleActive = false,
        tripleTimer = 0,
        tripleAngles = { 0, 0, 0 },
        helixTimer = 0,
        summonTimer = 0,
        orbitAngle = love.math.random() * math.pi * 2,
        strafeDir = 1,
        hitFlash = 0,
    }

    Effects.showBanner("CRITICAL ALERT: " .. b.name, b.title, 3.0)
    Sound.play("boss")
    Boss.active = b
    return b
end

-- Update Boss Logic
function Boss.update(dt, player, fireBullet, spawnEnemy)
    local b = Boss.active
    if not b or not b.alive or not player then return end

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    if b.hitFlash > 0 then b.hitFlash = b.hitFlash - dt end
    if b.phaseTransitionTimer > 0 then b.phaseTransitionTimer = b.phaseTransitionTimer - dt end
    b.aggressionTimer = b.aggressionTimer + dt

    -- Phase Transition Checks: 75% -> Phase 2, 50% -> Phase 3, 20% -> Phase 4 (Enraged)
    local hpPct = b.hp / b.maxHp
    if hpPct <= 0.20 and b.phase < 4 then
        b.phase = 4
        b.enraged = true
        b.speed = b.tpl.speed * 1.55
        b.phaseTransitionTimer = 2.0
        Effects.shake(16, 0.6)
        Effects.showBanner("WARNING: " .. b.name .. " ENRAGED", "MAXIMUM COMBAT OVERDRIVE", 2.5)
        Sound.play("explosion")
        Sound.play("boss")
        -- Rally ALL alive enemies to support boss
        Boss.rallySupport(spawnEnemy, b)
    elseif hpPct <= 0.50 and b.phase < 3 then
        b.phase = 3
        b.speed = b.tpl.speed * 1.35
        b.phaseTransitionTimer = 1.6
        Effects.shake(12, 0.4)
        Effects.showBanner("PHASE 3: OVERCLOCK PROTOCOL", "SECONDARY WEAPON BATTERIES ENGAGED", 2.2)
        Sound.play("boss")
        Boss.rallySupport(spawnEnemy, b)
    elseif hpPct <= 0.75 and b.phase < 2 then
        b.phase = 2
        b.speed = b.tpl.speed * 1.2
        b.phaseTransitionTimer = 1.4
        Effects.shake(8, 0.3)
        Effects.showBanner("PHASE 2: BARRIER OVERCHARGE", "TACTICAL ESCALATION DETECTED", 2.0)
        Sound.play("boss")
    end

    -- 1. Intro State
    if b.state == "INTRO" then
        b.y = b.y + (b.targetY - b.y) * 2.5 * dt
        b.stateTimer = b.stateTimer - dt
        if b.stateTimer <= 0 then
            b.state = "COMBAT"
            b.attackCooldown = 1.2
            Boss.rallySupport(spawnEnemy, b)
        end
        return
    end

    -- 2. Vulnerable Window State
    if b.state == "VULNERABLE" then
        b.vulnerableTimer = b.vulnerableTimer - dt
        b.hitFlash = 0.05
        Particles.emit(b.x, b.y, 2, {
            speed = 80, life = 0.25, size = 3,
            r = 0.3, g = 0.9, b = 1.0
        })
        if b.vulnerableTimer <= 0 then
            b.vulnerable = false
            b.state = "COMBAT"
            b.attackCooldown = b.enraged and 0.8 or 1.5
        end
        return
    end

    -- 3. Telegraphing State
    if b.state == "TELEGRAPHING" then
        b.telegraphTimer = b.telegraphTimer - dt
        if b.telegraphType == "dash" then
            b.telegraphAimX = player.x
            b.telegraphAimY = player.y
        end

        if b.telegraphTimer <= 0 then
            b.state = "ATTACKING"
            Boss.executeAttackStart(b, player, fireBullet, spawnEnemy)
        end
        return
    end

    -- 4. Attacking Execution State
    if b.state == "ATTACKING" then
        Boss.executeAttackUpdate(b, dt, player, fireBullet, spawnEnemy)
        return
    end

    -- 5. Standard Combat — Aggressive Positioning & Attack Decision
    -- Phase-scaled aggression: higher phases = tighter orbit, faster attacks
    local aggroFactor = 1.0 + (b.phase - 1) * 0.25
    b.orbitAngle = b.orbitAngle + (0.8 + aggroFactor * 0.3) * dt * b.strafeDir
    local orbitRadius = W * (b.enraged and 0.38 or 0.32)
    local targetX = (W / 2) + math.cos(b.orbitAngle) * orbitRadius
    local targetY = (H * 0.24) + math.sin(b.orbitAngle * 1.5) * (30 + b.phase * 10)

    local moveSpeed = b.speed * 0.02 * dt * 60
    b.x = b.x + (targetX - b.x) * moveSpeed
    b.y = b.y + (targetY - b.y) * moveSpeed

    -- Aggressive: Fire at player during combat movement (phase-scaled rate)
    b.attackCooldown = b.attackCooldown - dt * aggroFactor
    if b.attackCooldown <= 0 then
        b.attackCooldown = (b.enraged and 1.2 or 2.2) + love.math.random() * 0.6
        Boss.chooseNextAttack(b, player)
    end

    -- Continuous harass fire during combat (boss constantly shoots)
    b.aggressionTimer = b.aggressionTimer + dt
    if b.aggressionTimer >= (b.enraged and 0.5 or 0.9) then
        b.aggressionTimer = 0
        local dx = player.x - b.x
        local dy = player.y - b.y
        local dl = math.sqrt(dx * dx + dy * dy)
        if dl > 0 then
            bossFireBullet(fireBullet, b.x, b.y, dx / dl, dy / dl, 280, 1)
            if b.phase >= 3 then
                -- Phase 3+: dual flanking shots
                local spread = 0.2
                local ang = atan2(dy, dx)
                bossFireBullet(fireBullet, b.x, b.y, math.cos(ang + spread), math.sin(ang + spread), 270, 1)
                bossFireBullet(fireBullet, b.x, b.y, math.cos(ang - spread), math.sin(ang - spread), 270, 1)
            end
        end
    end
end

-- Rally small enemies to support boss during phase transitions
function Boss.rallySupport(spawnEnemy, b)
    if not spawnEnemy or b.rallyTriggered then return end
    b.rallyTriggered = false -- allow re-rally each phase
    -- Spawn support wave around boss
    local count = math.min(b.phase + 1, 4)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2
        local rx = b.x + math.cos(ang) * 120
        local ry = b.y + math.sin(ang) * 80
        local typePool = { "drone", "scout", "fighter", "support" }
        spawnEnemy(typePool[love.math.random(1, #typePool)], rx, ry, 1.0, 1.2, 0.0)
    end
    Effects.showBanner("REINFORCEMENTS INBOUND!", "ENEMY SUPPORT DEPLOYED", 1.5)
    Sound.play("powerup", 1.1)
end

-- Choose Next Sequenced Attack based on Boss Phase
function Boss.chooseNextAttack(b, player)
    local attacks = b.tpl.attacks
    local chosen = attacks[love.math.random(1, #attacks)]

    b.currentAttack = chosen
    b.state = "TELEGRAPHING"
    b.telegraphMax = b.enraged and 0.55 or 0.85
    b.telegraphTimer = b.telegraphMax

    if chosen == "dash" or chosen == "feintDash" or chosen == "phaseWarp" then
        b.telegraphType = "dash"
        b.telegraphAimX = player.x
        b.telegraphAimY = player.y
        Sound.play("dash", 0.9)
    elseif chosen == "laserSweep" or chosen == "orbitalSweep" or chosen == "laserCross" or chosen == "tripleLaser" then
        b.telegraphType = "laser"
        b.telegraphAimX = player.x
        b.telegraphAimY = player.y
        Sound.play("laser-2", 0.9)
    elseif chosen == "summonBrood" then
        b.telegraphType = "summon"
        Sound.play("powerup", 0.8)
    else
        b.telegraphType = "ring"
        Sound.play("laser-1", 0.9)
    end
end

-- Attack Start Trigger
function Boss.executeAttackStart(b, player, fireBullet, spawnEnemy)
    local atk = b.currentAttack

    if atk == "dash" or atk == "feintDash" or atk == "phaseWarp" then
        local dx = b.telegraphAimX - b.x
        local dy = b.telegraphAimY - b.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then dx, dy = dx / len, dy / len else dx, dy = 0, 1 end
        b.dashTargetX = dx
        b.dashTargetY = dy
        b.dashTimer = (atk == "feintDash") and 0.28 or 0.55
        Sound.play("dash", 1.2)
        Effects.shake(6, 0.2)

    elseif atk == "missiles" or atk == "barrage" or atk == "enrageBarrage" or atk == "acidPlasma" then
        local count = (b.phase >= 3) and 18 or 12
        if b.enraged then count = count + 6 end
        for i = 1, count do
            local ang = (i / count) * math.pi * 2 + love.timer.getTime()
            bossFireBullet(fireBullet, b.x, b.y, math.cos(ang), math.sin(ang), 260, 1)
        end
        Sound.play("laser-3", 1.0)
        Boss.enterVulnerability(b, 1.6)

    elseif atk == "tripleLaser" then
        -- TRIPLE SIMULTANEOUS LASER BEAMS aimed at player
        b.tripleActive = true
        b.tripleTimer = 1.6
        local baseAng = atan2(player.y - b.y, player.x - b.x)
        b.tripleAngles = { baseAng - 0.35, baseAng, baseAng + 0.35 }
        Sound.play("laser-2", 1.4)
        Effects.shake(10, 0.3)

    elseif atk == "laserSweep" or atk == "orbitalSweep" or atk == "laserCross" then
        b.laserFiring = true
        b.laserTimer = 1.4
        b.laserAngle = atan2(player.y - b.y, player.x - b.x) - 0.6
        Sound.play("laser-2", 1.2)

    elseif atk == "summonBrood" then
        if spawnEnemy then
            spawnEnemy("drone", b.x - 60, b.y + 20, 1, 1.2, 0.0)
            spawnEnemy("drone", b.x + 60, b.y + 20, 1, 1.2, 0.0)
            if b.phase >= 2 then
                spawnEnemy("scout", b.x, b.y + 40, 1, 1.3, 0.0)
            end
            if b.phase >= 3 then
                spawnEnemy("interceptor", b.x - 40, b.y + 60, 1, 1.2, 0.0)
                spawnEnemy("support", b.x + 40, b.y + 60, 1, 1.0, 0.0)
            end
        end
        Sound.play("powerup", 1.1)
        Boss.enterVulnerability(b, 2.0)

    elseif atk == "shockwave" then
        Effects.shake(14, 0.45)
        local count = (b.phase >= 3) and 30 or 24
        for i = 1, count do
            local ang = (i / count) * math.pi * 2
            bossFireBullet(fireBullet, b.x, b.y, math.cos(ang), math.sin(ang), 220, 1)
        end
        Sound.play("explosion", 0.9)
        Boss.enterVulnerability(b, 1.8)

    elseif atk == "bulletHelix" then
        local count = 20
        for i = 1, count do
            local ang = (i / count) * math.pi * 2 + love.timer.getTime() * 2
            bossFireBullet(fireBullet, b.x, b.y, math.cos(ang), math.sin(ang), 200 + i * 8, 1)
        end
        Sound.play("laser-1", 1.0)
        Boss.enterVulnerability(b, 1.5)

    else
        -- Radial Ring Volley fallback
        local count = (b.phase >= 3) and 20 or 16
        for i = 1, count do
            local ang = (i / count) * math.pi * 2
            bossFireBullet(fireBullet, b.x, b.y, math.cos(ang), math.sin(ang), 240, 1)
        end
        Sound.play("laser-1", 1.0)
        Boss.enterVulnerability(b, 1.5)
    end
end

-- Attack In-Flight Update
function Boss.executeAttackUpdate(b, dt, player, fireBullet, spawnEnemy)
    local atk = b.currentAttack

    if atk == "dash" or atk == "feintDash" or atk == "phaseWarp" then
        b.dashTimer = b.dashTimer - dt
        local spd = (atk == "phaseWarp") and 850 or 650
        b.x = b.x + b.dashTargetX * spd * dt
        b.y = b.y + b.dashTargetY * spd * dt
        Particles.emit(b.x, b.y, 4, {
            speed = 90, life = 0.25, size = 4,
            r = b.color[1], g = b.color[2], b = b.color[3]
        })
        if b.dashTimer <= 0 then
            Boss.enterVulnerability(b, 1.6)
        end

    elseif atk == "tripleLaser" then
        -- Triple Laser Beams — 3 sweeping simultaneously
        b.tripleTimer = b.tripleTimer - dt
        for i = 1, 3 do
            -- Each beam sweeps slightly
            b.tripleAngles[i] = b.tripleAngles[i] + (i == 2 and 0.6 or (i == 1 and 0.4 or 0.8)) * dt

            -- Check beam damage against player
            local pdx = player.x - b.x
            local pdy = player.y - b.y
            local pdist = math.sqrt(pdx * pdx + pdy * pdy)
            if pdist > 0 then
                local dot = (pdx * math.cos(b.tripleAngles[i]) + pdy * math.sin(b.tripleAngles[i])) / pdist
                if dot > 0.982 and pdist < 900 then
                    player:hurt(1)
                end
            end
        end
        if b.tripleTimer <= 0 then
            b.tripleActive = false
            Boss.enterVulnerability(b, 2.2)
        end

    elseif atk == "laserSweep" or atk == "orbitalSweep" or atk == "laserCross" then
        b.laserTimer = b.laserTimer - dt
        b.laserAngle = b.laserAngle + 0.9 * dt

        -- Check beam damage against player
        local pdx = player.x - b.x
        local pdy = player.y - b.y
        local pdist = math.sqrt(pdx * pdx + pdy * pdy)
        if pdist > 0 then
            local dot = (pdx * math.cos(b.laserAngle) + pdy * math.sin(b.laserAngle)) / pdist
            if dot > 0.985 and pdist < 900 then
                player:hurt(1)
            end
        end

        if b.laserTimer <= 0 then
            b.laserFiring = false
            Boss.enterVulnerability(b, 1.8)
        end
    else
        -- For non-continuous attacks, immediately enter vulnerability
        Boss.enterVulnerability(b, 1.5)
    end
end

-- Trigger Vulnerability Window
function Boss.enterVulnerability(b, duration)
    b.state = "VULNERABLE"
    b.vulnerable = true
    b.vulnerableTimer = duration or 1.8
    Sound.play("powerup", 0.6)
end

-- Render Boss Telegraphs, Triple Lasers, Health Bar & Core Glows
function Boss.draw()
    local b = Boss.active
    if not b or not b.alive then return end

    local W = love.graphics.getWidth()

    -- 1. Telegraph Warning Lines & Aim Crosshairs
    if b.state == "TELEGRAPHING" then
        local progress = 1.0 - (b.telegraphTimer / b.telegraphMax)

        if b.telegraphType == "dash" then
            love.graphics.setColor(1.0, 0.2, 0.2, 0.35 + progress * 0.55)
            love.graphics.setLineWidth(2 + progress * 3)
            love.graphics.line(b.x, b.y, b.telegraphAimX, b.telegraphAimY)
            love.graphics.circle("line", b.telegraphAimX, b.telegraphAimY, 20 + (1 - progress) * 30)
            love.graphics.setLineWidth(1)

        elseif b.telegraphType == "laser" then
            -- Triple laser telegraph: show 3 warning sightlines
            love.graphics.setColor(1.0, 0.1, 0.3, 0.3 + progress * 0.6)
            love.graphics.setLineWidth(1.5 + progress * 2)
            local baseAng = atan2(b.telegraphAimY - b.y, b.telegraphAimX - b.x)
            for _, offset in ipairs({ -0.35, 0, 0.35 }) do
                local ang = baseAng + offset
                local tx = b.x + math.cos(ang) * 900
                local ty = b.y + math.sin(ang) * 900
                love.graphics.line(b.x, b.y, tx, ty)
            end
            love.graphics.setLineWidth(1)

        elseif b.telegraphType == "summon" then
            love.graphics.setColor(0.3, 0.9, 1.0, 0.4 + progress * 0.5)
            love.graphics.circle("line", b.x - 60, b.y + 20, 25 * progress)
            love.graphics.circle("line", b.x + 60, b.y + 20, 25 * progress)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 2. Triple Laser Beams Rendering
    if b.tripleActive then
        for i = 1, 3 do
            local ang = b.tripleAngles[i]
            local lx = b.x + math.cos(ang) * 900
            local ly = b.y + math.sin(ang) * 900
            -- Outer glow
            love.graphics.setColor(1.0, 0.15, 0.25, 0.75)
            love.graphics.setLineWidth(12)
            love.graphics.line(b.x, b.y, lx, ly)
            -- Core
            love.graphics.setColor(1.0, 0.9, 0.95, 1.0)
            love.graphics.setLineWidth(4)
            love.graphics.line(b.x, b.y, lx, ly)
        end
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 3. Single Sweeping Laser Beam
    if b.laserFiring then
        local lx = b.x + math.cos(b.laserAngle) * 900
        local ly = b.y + math.sin(b.laserAngle) * 900
        love.graphics.setColor(1.0, 0.2, 0.3, 0.85)
        love.graphics.setLineWidth(14)
        love.graphics.line(b.x, b.y, lx, ly)
        love.graphics.setColor(1.0, 0.9, 0.95, 1.0)
        love.graphics.setLineWidth(5)
        love.graphics.line(b.x, b.y, lx, ly)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 4. Vulnerable Exposed Core Glow
    if b.vulnerable then
        local glow = 0.6 + math.sin(love.timer.getTime() * 16) * 0.35
        love.graphics.setColor(0.3, 0.95, 1.0, glow)
        love.graphics.circle("fill", b.x, b.y, b.radius * 0.5)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
        love.graphics.circle("line", b.x, b.y, b.radius * 0.55)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 5. Top-of-Screen Boss Health Bar
    local barW = math.min(560, W - 120)
    local barH = 14
    local barX = (W - barW) / 2
    local barY = 48

    -- Background frame
    love.graphics.setColor(0.04, 0.08, 0.16, 0.85)
    love.graphics.rectangle("fill", barX - 4, barY - 4, barW + 8, barH + 8, 4)
    love.graphics.setColor(0.2, 0.5, 0.8, 0.7)
    love.graphics.rectangle("line", barX - 4, barY - 4, barW + 8, barH + 8, 4)

    -- Health fill with phase markers
    local hpPct = math.max(0, math.min(1, b.hp / b.maxHp))
    local hpCol = b.enraged and { 1.0, 0.2, 0.3, 0.95 } or { 0.95, 0.75, 0.2, 0.95 }
    love.graphics.setColor(hpCol[1], hpCol[2], hpCol[3], hpCol[4])
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 2)

    -- Phase Threshold Dividers (75%, 50%, 20%)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.line(barX + barW * 0.75, barY, barX + barW * 0.75, barY + barH)
    love.graphics.line(barX + barW * 0.50, barY, barX + barW * 0.50, barY + barH)
    love.graphics.line(barX + barW * 0.20, barY, barX + barW * 0.20, barY + barH)

    -- Boss Title Text
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    local titleStr = b.name .. "  [PHASE " .. b.phase .. (b.enraged and " - ENRAGED]" or "]")
    local tw = Assets.fonts.small:getWidth(titleStr)
    love.graphics.print(titleStr, barX + (barW - tw) / 2, barY - 18)
    love.graphics.setColor(1, 1, 1, 1)
end

return Boss
