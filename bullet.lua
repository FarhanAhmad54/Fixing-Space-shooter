-- bullet.lua — pooled projectile with homing, chain-lightning, and vortex effects.
-- Velocity is units/second and integrated with dt.

local Bullet = {}
Bullet.list = {}
Bullet.pool = {}
Bullet.free = {}
Bullet.MAX = 900

function Bullet.load()
    Bullet.pool = {}
    Bullet.list = {}
    Bullet.free = {}
    for i = 1, Bullet.MAX do
        Bullet.pool[i] = {
            _idx = i, active = false,
            x = 0, y = 0, vx = 0, vy = 0,
            damage = 0, life = 0, radius = 4, pierce = 0,
            friendly = true, color = { 1, 1, 1 },
            size = 4, bulletKey = nil,
            homing = false, explosive = false,
            chainLightning = false, vortex = false,
            hitList = nil,
        }
        Bullet.free[i] = i
    end
end

local function acquire()
    local n = #Bullet.free
    if n == 0 then return nil end
    local idx = Bullet.free[n]
    Bullet.free[n] = nil
    local b = Bullet.pool[idx]
    b.active = true
    Bullet.list[#Bullet.list + 1] = b
    return b
end

local function release(b)
    b.active = false
    b.hitList = nil
    b.homing = false
    b.explosive = false
    b.chainLightning = false
    b.vortex = false
    Bullet.free[#Bullet.free + 1] = b._idx
end

function Bullet.fire(opts)
    local b = acquire()
    if not b then return nil end
    b.x, b.y = opts.x, opts.y
    b.vx, b.vy = opts.vx, opts.vy
    b.damage = opts.damage or 1
    b.life = opts.life or 1.5
    b.radius = opts.radius or 4
    b.pierce = opts.pierce or 0
    b.friendly = opts.friendly ~= false
    b.color = opts.color or (b.friendly and { 0.6, 0.9, 1 } or { 1, 0.4, 0.4 })
    b.size = opts.size or 4
    b.bulletKey = opts.bulletKey
    b.homing = opts.homing or false
    b.explosive = opts.explosive or false
    b.chainLightning = opts.chainLightning or false
    b.vortex = opts.vortex or false
    b.hitList = (b.pierce > 0) and {} or nil
    return b
end

function Bullet.update(dt, enemies)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    for i = #Bullet.list, 1, -1 do
        local b = Bullet.list[i]
        b.life = b.life - dt

        -- Homing steering
        if b.homing and b.friendly and enemies then
            local nearest, bestDist = nil, 450 * 450
            for _, e in ipairs(enemies) do
                if e.alive then
                    local dx, dy = e.x - b.x, e.y - b.y
                    local d2 = dx*dx + dy*dy
                    if d2 < bestDist then nearest = e; bestDist = d2 end
                end
            end
            if nearest then
                local dx, dy = nearest.x - b.x, nearest.y - b.y
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    local speed = math.sqrt(b.vx*b.vx + b.vy*b.vy)
                    local tvx = (dx / len) * speed
                    local tvy = (dy / len) * speed
                    local turn = math.min(1, 8 * dt)
                    b.vx = b.vx + (tvx - b.vx) * turn
                    b.vy = b.vy + (tvy - b.vy) * turn
                end
            end
        end

        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt

        if b.life <= 0 or b.x < -70 or b.x > W + 70 or b.y < -70 or b.y > H + 70 then
            release(b)
            table.remove(Bullet.list, i)
        end
    end
end

function Bullet.draw()
    local Assets = require("assets")
    local atan2 = math.atan2 or math.atan

    for _, b in ipairs(Bullet.list) do
        local key = b.bulletKey
        if not key then
            key = b.friendly and "laser1" or "laser2"
        end
        local img = Assets.get(key)
        local ang = atan2(b.vy, b.vx) + math.pi/2

        -- 1. Trailing Light Streak
        love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.45)
        love.graphics.setLineWidth(math.max(1, b.size * 0.6))
        love.graphics.line(b.x, b.y, b.x - b.vx * 0.024, b.y - b.vy * 0.024)
        love.graphics.setLineWidth(1)

        -- 2. Projectile Sprite
        if img then
            love.graphics.setColor(1, 1, 1, 1)
            local mult = (key == "rocket" or key == "superSwarm") and 3.5 or 2.8
            local targetSize = b.size * mult
            local sx = targetSize / img:getWidth()
            local sy = targetSize / img:getHeight()
            love.graphics.draw(img, b.x, b.y, ang, sx, sy, img:getWidth()/2, img:getHeight()/2)
        else
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.circle("fill", b.x, b.y, b.size)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Bullet.clear()
    for _, b in ipairs(Bullet.list) do
        release(b)
    end
    Bullet.list = {}
end

function Bullet.count()
    return #Bullet.list
end

return Bullet
