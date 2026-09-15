-- background.lua — cinematic parallax space environment.
-- Multi-layer rendering: deep nebula (bg.png) + 2 seamless star layers (Stars-A & Stars-B)
-- + drifting rotating celestial planets (planet00..planet09).

local Assets = require("assets")

local Background = {}
Background.__index = Background

local PLANET_KEYS = {
    "planet00", "planet01", "planet02", "planet03", "planet04",
    "planet05", "planet06", "planet07", "planet08", "planet09"
}

function Background.new()
    local self = setmetatable({}, Background)
    self.time = 0
    self.nebulaOffset = 0
    self.starAOffset = 0
    self.starBOffset = 0
    self.bossMode = false
    self.planets = {}

    local W = math.max(640, love.graphics.getWidth() or 1280)
    local H = math.max(360, love.graphics.getHeight() or 720)

    -- Spawn 3 initial celestial planets distributed across vertical space
    for i = 1, 3 do
        local key = PLANET_KEYS[love.math.random(1, #PLANET_KEYS)]
        local size = love.math.random(90, 200)
        self.planets[i] = {
            key = key,
            x = love.math.random(40, W - 40),
            y = (H / 3) * (i - 1) + love.math.random(20, 80),
            size = size,
            speed = love.math.random(14, 26),
            rot = love.math.random() * math.pi * 2,
            rotSpeed = (love.math.random() - 0.5) * 0.08,
            alpha = love.math.random(35, 75) / 100,
            color = { 0.7 + love.math.random() * 0.3, 0.8 + love.math.random() * 0.2, 1.0 },
        }
    end

    -- Organic twinkling micro-stars
    self.microStars = {}
    for i = 1, 90 do
        self.microStars[i] = {
            x = love.math.random() * W,
            y = love.math.random() * H,
            speed = love.math.random(20, 70),
            size = love.math.random(1, 2),
            twinkle = love.math.random() * math.pi * 2,
            baseAlpha = 0.2 + love.math.random() * 0.6,
        }
    end

    return self
end

function Background:setBossMode(enabled)
    self.bossMode = enabled == true
end

function Background:update(dt)
    self.time = self.time + dt
    local W = math.max(640, love.graphics.getWidth() or 1280)
    local H = math.max(360, love.graphics.getHeight() or 720)

    -- Scroll speeds
    if H > 0 then
        self.nebulaOffset = (self.nebulaOffset + dt * 12) % H
        self.starAOffset  = (self.starAOffset  + dt * 32) % H
        self.starBOffset  = (self.starBOffset  + dt * 55) % H
    end

    -- Update planets
    for _, p in ipairs(self.planets) do
        p.y = p.y + p.speed * dt
        p.rot = p.rot + p.rotSpeed * dt
        if p.y > H + p.size then
            p.y = -p.size - love.math.random(40, 150)
            p.x = love.math.random(50, W - 50)
            p.key = PLANET_KEYS[love.math.random(1, #PLANET_KEYS)]
            p.size = love.math.random(90, 220)
            p.speed = love.math.random(14, 26)
            p.alpha = love.math.random(40, 80) / 100
        end
    end

    -- Update micro-stars
    for _, s in ipairs(self.microStars) do
        s.y = s.y + s.speed * dt
        if s.y > H + 4 then
            s.y = -4
            s.x = love.math.random() * W
        end
    end
end

local function drawTiledVertical(img, yOffset, alpha, col)
    if not img then return end
    local W = love.graphics.getWidth() or 1280
    local H = love.graphics.getHeight() or 720
    if W <= 0 or H <= 0 then return end
    local iw = img:getWidth()
    local ih = img:getHeight()
    if iw <= 0 or ih <= 0 then return end
    local sx = W / iw
    local sy = sx

    local r, g, b = col and col[1] or 1, col and col[2] or 1, col and col[3] or 1
    love.graphics.setColor(r, g, b, alpha)

    local scaledH = ih * sy
    if scaledH <= 1 then return end
    local yOffsetSafe = (type(yOffset) == "number" and yOffset == yOffset) and yOffset or 0
    local y = (yOffsetSafe % scaledH) - scaledH
    local maxTiles = 25
    local tileCount = 0
    while y < H and tileCount < maxTiles do
        love.graphics.draw(img, 0, y, 0, sx, sy)
        y = y + scaledH
        tileCount = tileCount + 1
    end
end

function Background:draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- 1. Base Cosmic Void
    love.graphics.setColor(0.015, 0.02, 0.045, 1.0)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- 2. Deep Nebula Cloud Layer (bg.png)
    local bgImg = Assets.get("bg")
    if bgImg then
        local nebulaTint = self.bossMode and { 1.0, 0.35, 0.45 } or { 0.75, 0.85, 1.0 }
        drawTiledVertical(bgImg, self.nebulaOffset, 0.45, nebulaTint)
    end

    -- 3. Drifting Celestial Planets (planet00..planet09)
    for _, p in ipairs(self.planets) do
        local pImg = Assets.get(p.key)
        if pImg then
            -- Soft atmospheric glow halo behind planet
            local haloSize = p.size * 1.18
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.alpha * 0.22)
            love.graphics.circle("fill", p.x, p.y, haloSize / 2)

            -- Detailed Planet Sprite
            love.graphics.setColor(1, 1, 1, p.alpha)
            local scale = p.size / pImg:getWidth()
            love.graphics.draw(pImg, p.x, p.y, p.rot, scale, scale, pImg:getWidth()/2, pImg:getHeight()/2)
        else
            -- Fallback
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.alpha * 0.5)
            love.graphics.circle("fill", p.x, p.y, p.size / 2)
        end
    end

    -- 4. Mid-depth Parallax Starfield (Stars-A.png)
    local starsA = Assets.get("starsA")
    if starsA then
        drawTiledVertical(starsA, self.starAOffset, 0.50, { 0.8, 0.9, 1.0 })
    end

    -- 5. Foreground Parallax Starfield (Stars-B.png)
    local starsB = Assets.get("starsB")
    if starsB then
        drawTiledVertical(starsB, self.starBOffset, 0.75, { 0.9, 0.95, 1.0 })
    end

    -- 6. Dynamic Twinkling Micro-Stars
    for _, s in ipairs(self.microStars) do
        local tw = 0.8 + 0.2 * math.sin(self.time * 3 + s.twinkle)
        love.graphics.setColor(0.9, 0.95, 1.0, s.baseAlpha * tw)
        love.graphics.circle("fill", s.x, s.y, s.size)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Background
