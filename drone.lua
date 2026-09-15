-- drone.lua — orbiting attack drones granted by XP upgrades, tech-tree, and carrier chassis.
-- Drones orbit the player, auto-target nearest enemies, and fire on a dt-scaled cooldown.

local Drone = {}
Drone.list = {}

local ORBIT_RADIUS = 72
local ORBIT_SPEED = 1.4
local BASE_FIRE_COOLDOWN = 0.55
local RANGE = 380

function Drone.reset()
    Drone.list = {}
end

function Drone.setCount(n)
    n = math.max(0, math.min(8, n or 0))
    while #Drone.list < n do
        Drone.list[#Drone.list + 1] = {
            angle = love.math.random() * math.pi * 2,
            cooldown = love.math.random() * BASE_FIRE_COOLDOWN,
            x = 0, y = 0,
        }
    end
    while #Drone.list > n do
        table.remove(Drone.list)
    end
end

function Drone.update(dt, player, enemies, fireCallback)
    local n = math.max(1, #Drone.list)
    local isOverclocked = (player.specialActiveTimer > 0 and player.chassis.id == "aegis")
    local fireRateMul = isOverclocked and 0.35 or 1.0

    for i, d in ipairs(Drone.list) do
        d.angle = d.angle + (ORBIT_SPEED * (isOverclocked and 2.2 or 1.0)) * dt
        local baseAngle = (i / n) * math.pi * 2
        d.x = player.x + math.cos(d.angle + baseAngle) * ORBIT_RADIUS
        d.y = player.y + math.sin(d.angle + baseAngle) * ORBIT_RADIUS

        d.cooldown = d.cooldown - dt
        if d.cooldown <= 0 then
            local best, bestDist = nil, RANGE * RANGE
            for _, e in ipairs(enemies) do
                if e.alive then
                    local dx, dy = e.x - d.x, e.y - d.y
                    local dist = dx*dx + dy*dy
                    if dist < bestDist then best = e; bestDist = dist end
                end
            end
            if best then
                local dx, dy = best.x - d.x, best.y - d.y
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    fireCallback(d.x, d.y, dx/len, dy/len, isOverclocked)
                    d.cooldown = BASE_FIRE_COOLDOWN * fireRateMul
                end
            else
                d.cooldown = 0.12
            end
        end
    end
end

function Drone.draw()
    local Assets = require("assets")
    local petSprites = { "pet1", "pet2", "pet3", "support" }

    for i, d in ipairs(Drone.list) do
        local spriteKey = petSprites[((i - 1) % #petSprites) + 1]
        local img = Assets.get(spriteKey)
        if img then
            -- Orbiting halo glow
            love.graphics.setColor(0.2, 0.9, 1.0, 0.35)
            love.graphics.circle("line", d.x, d.y, 16)

            -- Authentic Pet Drone Sprite
            love.graphics.setColor(1, 1, 1, 1)
            local targetSize = 28
            local sx = targetSize / img:getWidth()
            local sy = targetSize / img:getHeight()
            love.graphics.draw(img, d.x, d.y, d.angle + math.pi/2, sx, sy, img:getWidth()/2, img:getHeight()/2)
        else
            love.graphics.setColor(0.3, 0.9, 1, 0.4)
            love.graphics.circle("line", d.x, d.y, 13)
            love.graphics.setColor(0.4, 1, 0.9, 1)
            love.graphics.circle("fill", d.x, d.y, 5)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.circle("fill", d.x, d.y, 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Drone
