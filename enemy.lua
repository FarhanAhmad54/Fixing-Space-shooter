-- enemy.lua — enemy types, champion affixes, multi-phase bosses, shield pylons, and asteroids.
-- All velocities and physics are strictly dt-scaled.

local Assets    = require("assets")
local Sound     = require("sound")
local Effects   = require("effects")
local Particles = require("particles")
local EnemyAI   = require("enemyai")
local Squad     = require("squad")
local Boss      = require("boss")
local Bullet    = require("bullet")

local Enemy = {}
Enemy.list = {}
Enemy.hazards = {}

-- 9 Core Enemy Archetypes + Legacy Mappings + 5 Multi-Phase Bosses
Enemy.TYPES = {
    -- 1. Scout: Fast hit-and-run, high evasion
    scout = {
        asset = "swarmer", hp = 14, speed = 160, damage = 1, score = 20, xp = 8, scrap = 10,
        radius = 16, color = { 0.3, 0.85, 1.0 }, archetype = "scout",
        fireCooldown = 1.6, bulletSpeed = 300,
    },
    -- 2. Fighter: Balanced frontline skirmisher
    fighter = {
        asset = "swarmer", hp = 24, speed = 125, damage = 1, score = 30, xp = 12, scrap = 14,
        radius = 18, color = { 1.0, 0.35, 0.35 }, archetype = "fighter",
        fireCooldown = 1.4, bulletSpeed = 320,
    },
    -- 3. Interceptor: High speed flanker, predictive lead targeting
    interceptor = {
        asset = "swarmer", hp = 18, speed = 175, damage = 1, score = 35, xp = 14, scrap = 16,
        radius = 16, color = { 1.0, 0.55, 0.2 }, archetype = "interceptor",
        fireCooldown = 1.3, bulletSpeed = 340,
    },
    -- 4. Tank: Heavy armor, slow advance, absorbs damage
    tank = {
        asset = "bomber", hp = 70, speed = 65, damage = 2, score = 70, xp = 25, scrap = 32,
        radius = 26, color = { 0.85, 0.35, 0.25 }, archetype = "tank",
        fireCooldown = 2.2, bulletSpeed = 260,
    },
    -- 5. Sniper: Extreme range, telegraphed high-damage laser beam
    sniper = {
        asset = "sniper", hp = 18, speed = 80, damage = 2, score = 45, xp = 16, scrap = 20,
        radius = 18, color = { 0.4, 1.0, 0.5 }, archetype = "sniper",
        fireCooldown = 2.4, bulletSpeed = 420,
    },
    -- 6. Support: Rearguard unit that repairs/shields nearby allies
    support = {
        asset = "shield", hp = 30, speed = 100, damage = 1, score = 60, xp = 22, scrap = 28,
        radius = 20, color = { 0.3, 0.9, 0.95 }, archetype = "support",
        fireCooldown = 2.0, bulletSpeed = 280,
    },
    -- 7. Bomber: High durability, explosive area-denial strikes
    bomber = {
        asset = "bomber", hp = 44, speed = 75, damage = 3, score = 55, xp = 18, scrap = 24,
        radius = 22, color = { 1.0, 0.70, 0.2 }, archetype = "bomber",
        fireCooldown = 2.5, bulletSpeed = 240,
    },
    -- 8. Drone: Small swarm unit, dangerous in coordinated groups
    drone = {
        asset = "swarmer", hp = 9, speed = 150, damage = 1, score = 15, xp = 6, scrap = 8,
        radius = 13, color = { 0.9, 0.85, 0.2 }, archetype = "drone",
        fireCooldown = 1.8, bulletSpeed = 290,
    },
    -- 9. Elite: Enhanced champion with high agility and predictive aim
    elite = {
        asset = "sniper", hp = 60, speed = 145, damage = 2, score = 110, xp = 45, scrap = 55,
        radius = 22, color = { 0.95, 0.25, 0.85 }, archetype = "elite",
        fireCooldown = 1.2, bulletSpeed = 380,
    },

    -- Backward Compatibility Aliases
    swarmer = {
        asset = "swarmer", hp = 14, speed = 150, damage = 1, score = 15, xp = 6, scrap = 8,
        radius = 16, color = { 1, 0.35, 0.35 }, archetype = "fighter",
        fireCooldown = 1.5, bulletSpeed = 300,
    },
    turret = {
        asset = "turret", hp = 32, speed = 0, damage = 1, score = 45, xp = 14, scrap = 18,
        radius = 20, color = { 0.85, 0.4, 1.0 }, archetype = "tank",
        fireCooldown = 1.5, bulletSpeed = 280,
    },
    miniboss = {
        asset = "miniboss", hp = 420, speed = 55, damage = 3, score = 500, xp = 120, scrap = 250, cores = 2,
        radius = 54, color = { 1, 0.25, 0.55 }, boss = true, template = "voidHunter",
    },
    pylon = {
        asset = "shield", hp = 60, speed = 30, damage = 1, score = 80, xp = 25, scrap = 35,
        radius = 22, color = { 0.3, 0.8, 1.0 }, archetype = "support",
    },

    -- 5 Boss Templates
    boss_voidHunter = {
        asset = "miniboss", hp = 420, speed = 110, damage = 2, score = 600, xp = 150, scrap = 300, cores = 3,
        radius = 50, color = { 0.95, 0.25, 0.45 }, boss = true, template = "voidHunter",
    },
    boss_ironColossus = {
        asset = "miniboss", hp = 680, speed = 45, damage = 3, score = 800, xp = 200, scrap = 400, cores = 4,
        radius = 64, color = { 1.0, 0.65, 0.20 }, boss = true, template = "ironColossus",
    },
    boss_swarmQueen = {
        asset = "miniboss", hp = 460, speed = 70, damage = 2, score = 700, xp = 180, scrap = 350, cores = 3,
        radius = 54, color = { 0.35, 1.0, 0.45 }, boss = true, template = "swarmQueen",
    },
    boss_phantom = {
        asset = "miniboss", hp = 390, speed = 135, damage = 2, score = 750, xp = 190, scrap = 380, cores = 3,
        radius = 48, color = { 0.75, 0.35, 1.0 }, boss = true, template = "phantom",
    },
    boss_starDevourer = {
        asset = "miniboss", hp = 950, speed = 50, damage = 3, score = 1200, xp = 300, scrap = 600, cores = 5,
        radius = 72, color = { 1.0, 0.20, 0.25 }, boss = true, template = "starDevourer",
    },
}

Enemy.AFFIXES = {
    shielded = { name = "Shielded", color = { 0.3, 0.7, 1.0 }, hpMul = 1.5, shield = 25 },
    overcharged = { name = "Overcharged", color = { 1.0, 0.9, 0.2 }, speedMul = 1.35, fireMul = 0.6 },
    splitter = { name = "Splitter", color = { 0.9, 0.3, 1.0 }, hpMul = 1.2 },
}

function Enemy.reset()
    Enemy.list = {}
    Enemy.hazards = {}
    Squad.reset()
    Boss.reset()
end

function Enemy.spawn(typeId, x, y, hpMul, speedMul, championChance)
    local def = Enemy.TYPES[typeId]
    if not def then return nil end
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    hpMul = hpMul or 1
    speedMul = speedMul or 1

    if not x then
        local side = love.math.random(1, 4)
        if side == 1 then x, y = -40, love.math.random(0, H)
        elseif side == 2 then x, y = W + 40, love.math.random(0, H)
        elseif side == 3 then x, y = love.math.random(0, W), -40
        else x, y = love.math.random(0, W), H + 40 end
    end

    -- Boss Spawning Branch
    local isBoss = def.boss or (typeId == "miniboss") or (typeId:sub(1, 5) == "boss_")
    if isBoss then
        local templateKey = "voidHunter"
        if typeId:sub(1, 5) == "boss_" then
            templateKey = typeId:sub(6)
        elseif def.template then
            templateKey = def.template
        end

        local b = Boss.spawn(templateKey, x, y)
        b.type = typeId
        b.def = def
        b.radius = def.radius or b.radius
        b.hp = b.hp * hpMul
        b.maxHp = b.maxHp * hpMul
        b.speed = b.speed * speedMul
        b.damage = def.damage or 2
        b.score = def.score or 600
        b.xp = def.xp or 150
        b.scrap = def.scrap or 300
        b.cores = def.cores or 3
        b.hitFlash = 0
        b.angle = math.pi
        Enemy.list[#Enemy.list + 1] = b
        return b
    end

    -- Regular Enemies: Check for Champion Elite mutation
    local affix = nil
    championChance = championChance or 0.12
    if typeId ~= "pylon" and love.math.random() < championChance then
        local keys = { "shielded", "overcharged", "splitter" }
        local key = keys[love.math.random(1, #keys)]
        affix = Enemy.AFFIXES[key]
        if affix.hpMul then hpMul = hpMul * affix.hpMul end
        if affix.speedMul then speedMul = speedMul * affix.speedMul end
    end

    local e = {
        type = typeId, def = def,
        x = x, y = y,
        hp = def.hp * hpMul, maxHp = def.hp * hpMul,
        shield = affix and affix.shield or (def.shield or 0),
        maxShield = affix and affix.shield or (def.shield or 0),
        radius = def.radius,
        speed = def.speed * speedMul,
        damage = def.damage,
        score = def.score * (affix and 2 or 1),
        xp = def.xp * (affix and 2 or 1),
        scrap = (def.scrap or 5) * (affix and 2.5 or 1),
        cores = def.cores or (affix and 1 or 0),
        fireTimer = love.math.random() * (def.fireCooldown or 1.5),
        hitFlash = 0,
        alive = true,
        behavior = def.archetype or "fighter",
        boss = false,
        affix = affix,
        angle = 0,
    }

    -- Initialize Advanced Tactical AI & Squad Registration
    local arch = def.archetype or typeId
    EnemyAI.init(e, arch)
    Squad.registerEnemy(e)

    Enemy.list[#Enemy.list + 1] = e
    return e
end

-- Spawn a destructible space asteroid
function Enemy.spawnAsteroid(x, y, size)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    size = size or 2 -- 2: large, 1: small
    if not x then
        x = love.math.random() < 0.5 and -30 or W + 30
        y = love.math.random(40, H - 40)
    end
    local targetX = W / 2 + (love.math.random() - 0.5) * 300
    local targetY = H / 2 + (love.math.random() - 0.5) * 300
    local dx, dy = targetX - x, targetY - y
    local len = math.sqrt(dx*dx + dy*dy)
    if len > 0 then dx, dy = dx/len, dy/len else dx, dy = 1, 0 end
    local rockKeys = size == 2 and { "asteroidLargeA", "asteroidLargeB", "asteroidMedA", "asteroidMedB" } or { "asteroidSmallA", "asteroidSmallB" }
    local rockKey = rockKeys[love.math.random(1, #rockKeys)]
    local spd = (size == 2) and love.math.random(45, 80) or love.math.random(75, 125)

    Enemy.hazards[#Enemy.hazards + 1] = {
        x = x, y = y,
        vx = dx * spd, vy = dy * spd,
        rot = love.math.random() * math.pi * 2,
        vrot = (love.math.random() - 0.5) * 1.5,
        radius = size == 2 and 26 or 14,
        size = size,
        rockKey = rockKey,
        hp = size == 2 and 24 or 10,
        maxHp = size == 2 and 24 or 10,
        alive = true,
    }
end

function Enemy.update(dt, player, fireBullet)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- 1. Boss Controller Update
    if Boss.active and Boss.active.alive then
        Boss.update(dt, player, fireBullet, Enemy.spawn)
    end

    -- 2. Update Enemies & Multi-Phase Bosses
    for i = #Enemy.list, 1, -1 do
        local e = Enemy.list[i]
        if not e.alive then
            table.remove(Enemy.list, i)
        else
            if e.boss then
                if e.hitFlash > 0 then e.hitFlash = e.hitFlash - dt end
                if e.hp <= 0 then
                    e.alive = false
                    if Boss.active == e then Boss.active = nil end
                end
            else
                -- Run tactical FSM, perception, dodging, steering, and combat
                EnemyAI.update(e, dt, player, Enemy.list, Bullet.list, fireBullet)
                if e.hp <= 0 then
                    e.alive = false
                end
            end
        end
    end

    -- 3. Update Space Asteroids
    for i = #Enemy.hazards, 1, -1 do
        local h = Enemy.hazards[i]
        h.x = h.x + h.vx * dt
        h.y = h.y + h.vy * dt
        h.rot = h.rot + h.vrot * dt
        if h.x < -60 or h.x > W + 60 or h.y < -60 or h.y > H + 60 or h.hp <= 0 then
            table.remove(Enemy.hazards, i)
        end
    end
end

function Enemy.draw()
    -- 1. Draw Textured Rock Asteroids
    for _, h in ipairs(Enemy.hazards) do
        local rImg = h.rockKey and Assets.get(h.rockKey)
        if rImg then
            love.graphics.setColor(1, 1, 1, 1)
            local sz = h.radius * 2.6
            love.graphics.draw(rImg, h.x, h.y, h.rot, sz / rImg:getWidth(), sz / rImg:getHeight(), rImg:getWidth()/2, rImg:getHeight()/2)
        else
            love.graphics.setColor(0.55, 0.50, 0.45, 1.0)
            love.graphics.circle("fill", h.x, h.y, h.radius)
            love.graphics.setColor(0.8, 0.75, 0.65, 0.6)
            love.graphics.circle("line", h.x, h.y, h.radius)
        end
    end

    -- 2. Draw Enemies & Bosses
    for _, e in ipairs(Enemy.list) do
        -- Champion Aura Ring
        if e.affix then
            love.graphics.setColor(e.affix.color[1], e.affix.color[2], e.affix.color[3], 0.5 + math.sin(love.timer.getTime() * 8) * 0.25)
            love.graphics.circle("line", e.x, e.y, e.radius + 8)
            love.graphics.circle("line", e.x, e.y, e.radius + 10)
        end

        -- Authentic Sprite Drawing (clean 1,1,1,1 so true metallic sprite artwork renders)
        if e.hitFlash > 0 then
            love.graphics.setColor(1, 1, 1, 1)
        elseif e.invulnerable then
            love.graphics.setColor(0.4, 0.85, 1.0, 0.85 + math.sin(love.timer.getTime() * 10) * 0.15)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        local img = e.def and e.def.asset and Assets.get(e.def.asset)
        local ang = e.angle or 0
        if img then
            local scaleMult = e.boss and 3.4 or 2.8
            local targetW = e.radius * scaleMult
            local targetH = e.radius * scaleMult
            local sx = targetW / img:getWidth()
            local sy = targetH / img:getHeight()
            love.graphics.draw(img, e.x, e.y, ang, sx, sy, img:getWidth()/2, img:getHeight()/2)
        else
            love.graphics.circle("fill", e.x, e.y, e.radius)
        end

        -- Tactical AI Visual Feedback (Telegraphs, charging rings, support rays)
        if not e.boss then
            EnemyAI.draw(e)
        end

        -- Health / Shield Bars for Bosses and Elites
        if (e.maxHp and e.maxHp > 30) or e.boss or e.affix then
            local bw = e.radius * 2.2
            local by = e.y - e.radius - 12
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", e.x - bw/2, by, bw, 5)

            -- Shield segment
            if e.shield and e.shield > 0 and e.maxShield and e.maxShield > 0 then
                love.graphics.setColor(0.3, 0.8, 1.0, 1.0)
                love.graphics.rectangle("fill", e.x - bw/2, by, bw * (e.shield / e.maxShield), 5)
            elseif e.maxHp and e.maxHp > 0 then
                love.graphics.setColor(e.boss and 1.0 or 0.3, e.boss and 0.2 or 1.0, 0.4, 1.0)
                love.graphics.rectangle("fill", e.x - bw/2, by, bw * math.max(0, math.min(1, e.hp / e.maxHp)), 5)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Enemy.aliveCount()
    local n = 0
    for _, e in ipairs(Enemy.list) do
        if e.alive then n = n + 1 end
    end
    return n
end

return Enemy
