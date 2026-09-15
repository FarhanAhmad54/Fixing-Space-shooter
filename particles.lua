-- particles.lua — pooled particle system with a free-list for O(1) acquire.
-- The pool is preallocated; no allocations occur during gameplay.

local Particles = {}
Particles.pool = {}
Particles.active = {}
Particles.free = {}
Particles.MAX = 900

function Particles.load()
    Particles.pool = {}
    Particles.active = {}
    Particles.free = {}
    for i = 1, Particles.MAX do
        Particles.pool[i] = {
            x = 0, y = 0, vx = 0, vy = 0,
            life = 0, maxLife = 1,
            size = 2, r = 1, g = 1, b = 1,
            active = false, drag = 0.92, gravity = 0,
        }
        Particles.free[i] = i
    end
end

local function acquire()
    local n = #Particles.free
    if n == 0 then return nil end
    local idx = Particles.free[n]
    Particles.free[n] = nil
    local p = Particles.pool[idx]
    p._idx = idx
    p.active = true
    Particles.active[#Particles.active + 1] = p
    return p
end

local function release(p)
    p.active = false
    Particles.free[#Particles.free + 1] = p._idx
end

function Particles.emit(x, y, count, opts)
    opts = opts or {}
    local speed = opts.speed or 180
    local life = opts.life or 0.5
    local size = opts.size or 3
    local r, g, b = opts.r or 1, opts.g or 0.7, opts.b or 0.3
    local spread = opts.spread or (math.pi * 2)
    local dir = opts.dir or 0
    local drag = opts.drag or 0.92
    local gravity = opts.gravity or 0

    for _ = 1, count do
        local p = acquire()
        if not p then return end
        local ang = dir + (love.math.random() - 0.5) * spread
        local spd = speed * (0.5 + love.math.random() * 0.8)
        p.x, p.y = x, y
        p.vx = math.cos(ang) * spd
        p.vy = math.sin(ang) * spd
        p.life = life * (0.6 + love.math.random() * 0.6)
        p.maxLife = p.life
        p.size = size * (0.6 + love.math.random() * 0.8)
        p.r, p.g, p.b = r, g, b
        p.drag = drag
        p.gravity = gravity
    end
end

function Particles.update(dt)
    for i = #Particles.active, 1, -1 do
        local p = Particles.active[i]
        p.life = p.life - dt
        if p.life <= 0 then
            release(p)
            table.remove(Particles.active, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + p.gravity * dt
            local d = math.pow(p.drag, dt * 60)
            p.vx = p.vx * d
            p.vy = p.vy * d
        end
    end
end

function Particles.draw()
    for _, p in ipairs(Particles.active) do
        local a = math.max(0, math.min(1, p.life / p.maxLife))
        love.graphics.setColor(p.r, p.g, p.b, a)
        love.graphics.circle("fill", p.x, p.y, p.size * a)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles.clear()
    for _, p in ipairs(Particles.active) do
        p.active = false
        Particles.free[#Particles.free + 1] = p._idx
    end
    Particles.active = {}
end

return Particles
