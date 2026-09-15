-- player.lua — player ship chassis, movement, dash, special abilities, and weapons.
-- All velocities and timers are strictly dt-scaled.

local Assets   = require("assets")
local Sound    = require("sound")
local Effects  = require("effects")
local Particles = require("particles")

local Player = {}
Player.__index = Player

local atan2 = math.atan2 or math.atan

Player.CHASSIS = {
    basic = {
        id = "basic", name = "BASIC FIGHTER",
        asset = "shipViper",
        baseSpeed = 360, radius = 18, baseHp = 3,
        stats = { speed = 3, fireRate = 3, health = 2 },
        critBonus = 0.05, pierceBonus = 0,
        specialName = "Tachyon Warp", specialCd = 7.0,
        color = { 1.0, 1.0, 1.0 },
    },
    cobalt = {
        id = "cobalt", name = "COBALT SCOUT",
        asset = "shipViper",
        baseSpeed = 420, radius = 17, baseHp = 3,
        stats = { speed = 5, fireRate = 4, health = 2 },
        critBonus = 0.15, pierceBonus = 0,
        specialName = "Afterburner", specialCd = 6.0,
        color = { 0.25, 0.70, 1.0 },
    },
    solar = {
        id = "solar", name = "SOLAR TITAN",
        asset = "shipTitan",
        baseSpeed = 290, radius = 22, baseHp = 6,
        stats = { speed = 2, fireRate = 3, health = 5 },
        critBonus = 0.0, pierceBonus = 0, armorReduction = 0.35,
        specialName = "Kinetic Barrier", specialCd = 11.0,
        color = { 1.0, 0.62, 0.20 },
    },
    phantom = {
        id = "phantom", name = "PHANTOM GHOST",
        asset = "shipSpectre",
        baseSpeed = 350, radius = 18, baseHp = 3,
        stats = { speed = 4, fireRate = 4, health = 2 },
        critBonus = 0.08, pierceBonus = 1, firerateBonus = 0.15,
        specialName = "EMP Shockwave", specialCd = 9.0,
        color = { 0.75, 0.35, 1.0 },
    },
    emerald = {
        id = "emerald", name = "EMERALD CARRIER",
        asset = "shipAegis",
        baseSpeed = 320, radius = 20, baseHp = 4,
        stats = { speed = 3, fireRate = 3, health = 4 },
        critBonus = 0.0, pierceBonus = 0, startingDrones = 2,
        specialName = "Overclock Swarm", specialCd = 10.0,
        color = { 0.25, 1.0, 0.55 },
    },
    void = {
        id = "void", name = "VOID REAPER",
        asset = "shipSpectre",
        baseSpeed = 390, radius = 18, baseHp = 3,
        stats = { speed = 4, fireRate = 5, health = 2 },
        critBonus = 0.25, pierceBonus = 1,
        specialName = "Annihilation Wave", specialCd = 8.0,
        color = { 0.95, 0.20, 0.30 },
    },
}

-- Aliases for existing save states
Player.CHASSIS.viper   = Player.CHASSIS.basic
Player.CHASSIS.titan   = Player.CHASSIS.solar
Player.CHASSIS.spectre = Player.CHASSIS.phantom
Player.CHASSIS.aegis   = Player.CHASSIS.emerald

function Player.new(profileUpgrades, chassisId)
    local p = setmetatable({}, Player)
    chassisId = chassisId or "viper"
    local chassis = Player.CHASSIS[chassisId] or Player.CHASSIS.viper
    p.chassis = chassis

    p.x = love.graphics.getWidth() / 2
    p.y = love.graphics.getHeight() / 2
    p.radius = chassis.radius
    p.baseSpeed = chassis.baseSpeed
    p.weaponIndex = 1
    p.cooldown = 0
    p.dashCooldown = 0
    p.dashTimer = 0
    p.dashDirX, p.dashDirY = 0, 0
    p.invuln = 1.5
    p.hitFlash = 0
    p.vx = 0
    p.vy = 0
    p.aimX, p.aimY = p.x + 1, p.y
    p.powerups = {}

    -- Tech-Tree permanent upgrades
    p.upgrades = { damage = 0, firerate = 0, speed = 0, health = 0, pierce = 0, drones = 0, magnet = 0, crit = 0 }
    if profileUpgrades then
        for k, v in pairs(profileUpgrades) do
            p.upgrades[k] = v
        end
    end

    p.lives = chassis.baseHp + (p.upgrades.health or 0)
    p.maxLives = p.lives

    -- Special Ability
    p.specialCooldown = 0
    p.specialActiveTimer = 0

    -- Apply initial starting drone bonus
    if chassis.startingDrones then
        p.upgrades.drones = math.max(p.upgrades.drones or 0, chassis.startingDrones)
    end

    return p
end

function Player:applyPowerup(t)
    if not t then return end
    if t.id == "life" then
        self.lives = math.min(self.maxLives, self.lives + 1)
        return
    end
    if t.duration and t.duration > 0 then
        self.powerups[t.id] = t.duration
    end
end

function Player:hasPowerup(id)
    return (self.powerups[id] or 0) > 0
end

function Player:update(dt, input)
    local speedMul = (1 + (self.upgrades.speed or 0) * 0.08)
    local baseSpeed = self.baseSpeed * speedMul

    if self.dashTimer > 0 then
        self.dashTimer = self.dashTimer - dt
        self.vx = self.dashDirX * 1400
        self.vy = self.dashDirY * 1400
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt
        Particles.emit(self.x, self.y, 2, {
            speed = 40, life = 0.25, size = 3,
            r = self.chassis.color[1], g = self.chassis.color[2], b = self.chassis.color[3],
        })
    else
        local mx, my = input.moveX or 0, input.moveY or 0
        local len = math.sqrt(mx*mx + my*my)
        if len > 1 then mx, my = mx/len, my/len end
        self.vx = mx * baseSpeed
        self.vy = my * baseSpeed
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt

        -- Engine thruster particle trail
        if len > 0.1 then
            local ang = atan2(my, mx) + math.pi
            Particles.emit(self.x - mx * 18, self.y - my * 18, 1, {
                dir = ang, spread = 0.4, speed = 80, life = 0.18, size = 3,
                r = self.chassis.color[1], g = self.chassis.color[2], b = self.chassis.color[3],
            })
        end
    end

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    self.x = math.max(self.radius, math.min(W - self.radius, self.x))
    self.y = math.max(self.radius, math.min(H - self.radius, self.y))

    self.aimX = input.aimX or (self.x + 1)
    self.aimY = input.aimY or self.y

    self.cooldown = self.cooldown - dt
    if self.dashCooldown > 0 then self.dashCooldown = self.dashCooldown - dt end
    if self.invuln > 0 then self.invuln = self.invuln - dt end
    if self.hitFlash > 0 then self.hitFlash = self.hitFlash - dt end

    if self.specialCooldown > 0 then self.specialCooldown = self.specialCooldown - dt end
    if self.specialActiveTimer > 0 then self.specialActiveTimer = self.specialActiveTimer - dt end

    for id, t in pairs(self.powerups) do
        self.powerups[id] = t - dt
        if self.powerups[id] <= 0 then self.powerups[id] = nil end
    end
end

function Player:tryDash(dx, dy)
    if self.dashCooldown > 0 then return false end
    local len = math.sqrt(dx*dx + dy*dy)
    if len == 0 then return false end
    self.dashDirX, self.dashDirY = dx/len, dy/len
    self.dashTimer = 0.14
    self.dashCooldown = 1.6
    self.invuln = math.max(self.invuln, 0.30)
    Sound.play("dash")
    Effects.shake(4, 0.12)
    return true
end

-- Trigger Chassis Active Special Ability
function Player:triggerSpecial(enemies, bullets)
    if self.specialCooldown > 0 then return false end
    self.specialCooldown = self.chassis.specialCd

    if self.chassis.id == "viper" or self.chassis.id == "basic" or self.chassis.id == "cobalt" then
        -- Tachyon Warp Dash / Afterburner
        local dx = self.aimX - self.x
        local dy = self.aimY - self.y
        local len = math.sqrt(dx*dx + dy*dy)
        if len > 0 then dx, dy = dx/len, dy/len else dx, dy = 1, 0 end
        self.invuln = 1.2
        self.x = math.max(self.radius, math.min(love.graphics.getWidth() - self.radius, self.x + dx * 280))
        self.y = math.max(self.radius, math.min(love.graphics.getHeight() - self.radius, self.y + dy * 280))
        Sound.play("dash", 1.4)
        Effects.chromaBurst(0.02)
        Effects.shake(8, 0.25)
        Effects.spawnShockwave(self.x / love.graphics.getWidth(), self.y / love.graphics.getHeight(), 0.05)
        Particles.emit(self.x, self.y, 30, {
            speed = 260, life = 0.5, size = 4,
            r = 0.2, g = 0.9, b = 1.0,
        })
        return true

    elseif self.chassis.id == "titan" then
        -- Kinetic Barrier
        self.specialActiveTimer = 4.5
        self.invuln = 4.5
        Sound.play("powerup", 0.7)
        Effects.flash(1.0, 0.6, 0.2, 0.3, 0.2)
        Effects.shake(6, 0.2)
        return true

    elseif self.chassis.id == "spectre" then
        -- EMP Shockwave: Destroys all enemy bullets and stuns enemies
        Sound.play("boss", 1.8)
        Effects.chromaBurst(0.03)
        Effects.shake(10, 0.3)
        Effects.flash(0.8, 0.4, 1.0, 0.4, 0.3)
        Effects.spawnShockwave(self.x / love.graphics.getWidth(), self.y / love.graphics.getHeight(), 0.08)
        Particles.emit(self.x, self.y, 45, {
            speed = 340, life = 0.6, size = 4,
            r = 0.8, g = 0.3, b = 1.0,
        })

        if bullets then
            for i = #bullets.list, 1, -1 do
                local b = bullets.list[i]
                if not b.friendly then
                    b.active = false
                    bullets.free[#bullets.free + 1] = b._idx
                    table.remove(bullets.list, i)
                end
            end
        end

        if enemies then
            for _, e in ipairs(enemies.list) do
                if e.alive then
                    e.fireTimer = (e.fireTimer or 1.0) + 2.5
                    e.hitFlash = 0.4
                    e.hp = e.hp - 15
                end
            end
        end
        return true

    elseif self.chassis.id == "aegis" then
        -- Overclock Swarm
        self.specialActiveTimer = 5.0
        Sound.play("powerup", 1.3)
        Effects.flash(0.2, 1.0, 0.7, 0.3, 0.25)
        Effects.shake(5, 0.15)
        return true

    elseif self.chassis.id == "void" then
        -- Annihilation Wave: Massive ring of destructive piercing plasma
        Sound.play("explosion", 1.5)
        Effects.chromaBurst(0.04)
        Effects.shake(15, 0.4)
        Effects.flash(1.0, 0.2, 0.3, 0.5, 0.4)
        Effects.spawnShockwave(self.x / love.graphics.getWidth(), self.y / love.graphics.getHeight(), 0.12)
        Particles.emit(self.x, self.y, 60, {
            speed = 400, life = 0.8, size = 5,
            r = 0.95, g = 0.2, b = 0.3,
        })
        if bullets and bullets.fire then
            local count = 36
            for i = 1, count do
                local ang = (i / count) * math.pi * 2
                bullets.fire({
                    x = self.x, y = self.y,
                    vx = math.cos(ang) * 500, vy = math.sin(ang) * 500,
                    damage = 25, friendly = true, size = 8,
                    bulletKey = "laser3", color = {1.0, 0.2, 0.3},
                    life = 1.5, pierce = 99
                })
            end
        end
        return true
    end

    return false
end

-- Returns true if the hit consumed a life, false otherwise.
function Player:hurt(damage)
    if self.invuln > 0 then return false end

    -- Titan kinetic barrier active
    if self.specialActiveTimer > 0 and self.chassis.id == "titan" then
        Sound.play("hit", 1.6)
        Effects.flash(1.0, 0.7, 0.2, 0.3, 0.15)
        return false
    end

    if self:hasPowerup("shield") then
        self.powerups.shield = nil
        self.invuln = 0.9
        Sound.play("hit")
        Effects.flash(0.4, 0.8, 1, 0.35, 0.2)
        Effects.shake(6, 0.2)
        return false
    end

    local actualDmg = damage or 1
    if self.chassis.armorReduction and love.math.random() < self.chassis.armorReduction then
        actualDmg = math.max(1, actualDmg - 1)
    end

    self.lives = self.lives - actualDmg
    self.invuln = 1.6
    self.hitFlash = 0.3
    Sound.play("playerhit")
    Effects.shake(14, 0.4)
    Effects.chromaBurst(0.02)
    Effects.flash(1, 0.2, 0.2, 0.5, 0.3)
    return true
end

function Player:draw()
    local ang = atan2(self.aimY - self.y, self.aimX - self.x) + math.pi/2

    -- 1. Animated Thruster Fire Plume
    local fireImg = Assets.get("fire")
    if fireImg then
        local vx = self.vx or 0
        local vy = self.vy or 0
        local speed = math.sqrt(vx * vx + vy * vy)
        local thrustIntensity = (self.dashTimer > 0) and 1.8 or (speed > 25 and 1.05 or 0.45)
        local flicker = 0.85 + 0.3 * math.sin(love.timer.getTime() * 30)
        local fScaleX = (30 / fireImg:getWidth()) * thrustIntensity * flicker
        local fScaleY = (38 / fireImg:getHeight()) * thrustIntensity * flicker
        -- Position nozzle behind ship
        local backDist = 28
        local fx = self.x - math.sin(ang) * backDist
        local fy = self.y + math.cos(ang) * backDist

        love.graphics.setColor(1, 0.9, 0.7, 0.9)
        love.graphics.draw(fireImg, fx, fy, ang, fScaleX, fScaleY, fireImg:getWidth()/2, 0)
    end

    -- 2. Player Hull Sprite
    local img = Assets.get(self.chassis.asset) or Assets.get("ship")
    if img then
        local targetSize = (self.chassis.id == "solar" or self.chassis.id == "titan") and 76 or 68
        local sx = targetSize / img:getWidth()
        local sy = targetSize / img:getHeight()

        if self.hitFlash > 0 then
            love.graphics.setColor(1, 0.3, 0.3, 1)
        elseif self.invuln > 0 and math.floor(self.invuln * 14) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.35)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end

        love.graphics.draw(img, self.x, self.y, ang, sx, sy, img:getWidth()/2, img:getHeight()/2)
    else
        love.graphics.circle("fill", self.x, self.y, self.radius)
        love.graphics.line(self.x, self.y, self.x + (self.aimX - self.x) * 0.3, self.y + (self.aimY - self.y) * 0.3)
    end

    -- 3. Energy Shield Overlay (shield.png)
    if self:hasPowerup("shield") or (self.specialActiveTimer > 0 and self.chassis.id == "titan") then
        local sImg = Assets.get("shield")
        local sz = 88 + math.sin(love.timer.getTime() * 7) * 4
        local sRot = love.timer.getTime() * 1.8
        if sImg then
            love.graphics.setColor(0.35, 0.85, 1.0, 0.75)
            love.graphics.draw(sImg, self.x, self.y, sRot, sz / sImg:getWidth(), sz / sImg:getHeight(), sImg:getWidth()/2, sImg:getHeight()/2)
        else
            love.graphics.setColor(0.35, 0.85, 1.0, 0.6)
            love.graphics.circle("line", self.x, self.y, sz / 2)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)

    -- 4. Dash cooldown bar under ship
    if self.dashCooldown > 0 then
        local W = 36
        love.graphics.setColor(0.15, 0.18, 0.25, 0.75)
        love.graphics.rectangle("fill", self.x - W/2, self.y + 36, W, 4)
        love.graphics.setColor(0.4, 0.9, 1.0, 1)
        love.graphics.rectangle("fill", self.x - W/2, self.y + 36, W * (1 - self.dashCooldown / 1.6), 4)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Player
