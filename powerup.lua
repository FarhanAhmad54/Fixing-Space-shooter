-- powerup.lua — temporary pickups, scrap currency drops, dark matter cores, and magnetic attraction.

local Assets  = require("assets")
local Sound   = require("sound")
local Effects = require("effects")

local Powerup = {}
Powerup.list = {}
Powerup.timer = 8

Powerup.TYPES = {
    { id = "shield",    color = { 0.4, 0.8, 1 }, duration = 8, label = "SHIELD", asset = "bonusShield" },
    { id = "rapid",     color = { 1, 0.8, 0.2 }, duration = 6, label = "RAPID",  asset = "bonusTime" },
    { id = "homing",    color = { 0.8, 0.4, 1 }, duration = 7, label = "HOMING", asset = "bonusShield" },
    { id = "explosive", color = { 1, 0.5, 0.2 }, duration = 6, label = "EXPLOSIVE", asset = "bonusTime" },
    { id = "life",      color = { 1, 0.3, 0.5 }, duration = 0, label = "EXTRA LIFE", asset = "bonusLife" },
}

local SPAWN_INTERVAL = 9
local BASE_PICKUP_RADIUS_SQ = 900

function Powerup.reset()
    Powerup.list = {}
    Powerup.timer = SPAWN_INTERVAL
end

function Powerup.spawnRandom(x, y)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    if not x then
        x = 60 + love.math.random() * (W - 120)
        y = 80 + love.math.random() * (H - 160)
    end
    local t = Powerup.TYPES[love.math.random(1, #Powerup.TYPES)]
    Powerup.list[#Powerup.list + 1] = {
        x = x, y = y, type = t,
        asset = t.asset,
        life = 14, bob = love.math.random() * math.pi * 2,
        isCurrency = false,
    }
end

function Powerup.spawnCurrency(x, y, kind, amount)
    Powerup.list[#Powerup.list + 1] = {
        x = x + (love.math.random() - 0.5) * 20,
        y = y + (love.math.random() - 0.5) * 20,
        type = { id = kind, label = (kind == "core" and "CORE" or "SCRAP"), color = (kind == "core" and { 0.8, 0.3, 1.0 } or { 1.0, 0.85, 0.2 }) },
        asset = (kind == "core" and "core" or "scrap"),
        amount = amount or 10,
        life = 18,
        bob = love.math.random() * math.pi * 2,
        isCurrency = true,
    }
end

function Powerup.update(dt, player, onScrapCollected)
    Powerup.timer = (Powerup.timer or SPAWN_INTERVAL) - dt
    if Powerup.timer <= 0 then
        Powerup.timer = SPAWN_INTERVAL + love.math.random() * 4
        if #Powerup.list < 5 then Powerup.spawnRandom() end
    end

    local magnetRange = 85 + (player.upgrades and player.upgrades.magnet or 0) * 55
    local magnetRangeSq = magnetRange * magnetRange

    for i = #Powerup.list, 1, -1 do
        local p = Powerup.list[i]
        p.life = p.life - dt
        p.bob = p.bob + dt * 3.5

        local dx, dy = player.x - p.x, player.y - p.y
        local d2 = dx*dx + dy*dy

        -- Magnetic attraction towards player
        if d2 < magnetRangeSq then
            local dist = math.sqrt(d2)
            if dist > 0 then
                local pullSpeed = (1 - dist / magnetRange) * 450 + 120
                p.x = p.x + (dx / dist) * pullSpeed * dt
                p.y = p.y + (dy / dist) * pullSpeed * dt
            end
        end

        -- Collection
        if d2 < BASE_PICKUP_RADIUS_SQ then
            if p.isCurrency then
                if p.type.id == "core" then
                    Sound.play("powerup", 1.4)
                    Effects.flash(0.8, 0.3, 1.0, 0.3, 0.2)
                    Effects.spawnDamage(p.x, p.y, "+CORE", true, { 0.9, 0.4, 1.0 })
                    if onScrapCollected then onScrapCollected(p.amount or 100, 1) end
                else
                    Sound.play("hit", 1.8)
                    Effects.spawnDamage(p.x, p.y, "+" .. p.amount, false, { 1.0, 0.85, 0.2 })
                    if onScrapCollected then onScrapCollected(p.amount or 10, 0) end
                end
            else
                player:applyPowerup(p.type)
                Sound.play("powerup")
                Effects.flash(p.type.color[1], p.type.color[2], p.type.color[3], 0.25, 0.2)
                Effects.shake(4, 0.15)
            end
            table.remove(Powerup.list, i)
        elseif p.life <= 0 then
            table.remove(Powerup.list, i)
        end
    end
end

function Powerup.draw()
    for _, p in ipairs(Powerup.list) do
        local yOff = math.sin(p.bob) * 5
        local img = p.asset and Assets.get(p.asset)
        local rot = (p.isCurrency and (p.bob * 0.8) or 0)

        -- Pulsing aura ring
        if p.type and p.type.color then
            local pulse = 0.35 + math.sin(p.bob * 2.5) * 0.18
            love.graphics.setColor(p.type.color[1], p.type.color[2], p.type.color[3], pulse)
            love.graphics.circle("line", p.x, p.y + yOff, p.isCurrency and 18 or 24)
        end

        if img then
            love.graphics.setColor(1, 1, 1, 1)
            local sz = p.isCurrency and 32 or 38
            love.graphics.draw(img, p.x, p.y + yOff, rot, sz / img:getWidth(), sz / img:getHeight(), img:getWidth()/2, img:getHeight()/2)
        else
            love.graphics.setColor(p.type.color[1], p.type.color[2], p.type.color[3], 0.9)
            love.graphics.circle("fill", p.x, p.y + yOff, 14)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("line", p.x, p.y + yOff, 14)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Powerup
