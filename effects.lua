-- effects.lua — AA game feel: screen shake, hit flash, hitstop, damage numbers, shockwaves, and banners.
-- All timers are dt-scaled so behaviour is identical at any refresh rate.

local Shaders = require("shaders")

local Effects = {}
Effects.shakeAmount = 0
Effects.shakeDuration = 0.01
Effects.shakeTime = 0
Effects.flashColor = { 1, 1, 1, 0 }
Effects.flashDuration = 0.01
Effects.flashTime = 0
Effects.hitstop = 0
Effects.chroma = 0
Effects.shockwaves = {}
Effects.damageNumbers = {}
Effects.banner = { text = nil, subtext = nil, time = 0, maxTime = 1.8 }

function Effects.reset()
    Effects.shakeAmount = 0
    Effects.shakeTime = 0
    Effects.flashColor = { 1, 1, 1, 0 }
    Effects.flashTime = 0
    Effects.hitstop = 0
    Effects.chroma = 0
    Effects.shockwaves = {}
    Effects.damageNumbers = {}
    Effects.banner = { text = nil, subtext = nil, time = 0, maxTime = 1.8 }
end

function Effects.shake(amount, duration)
    if amount > Effects.shakeAmount then
        Effects.shakeAmount = amount
        Effects.shakeDuration = math.max(0.01, duration or 0.25)
        Effects.shakeTime = Effects.shakeDuration
    end
end

function Effects.flash(r, g, b, a, duration)
    Effects.flashColor = { r or 1, g or 1, b or 1, a or 0.5 }
    Effects.flashDuration = math.max(0.01, duration or 0.15)
    Effects.flashTime = Effects.flashDuration
end

function Effects.freeze(seconds)
    Effects.hitstop = math.max(Effects.hitstop, seconds or 0.05)
end

function Effects.chromaBurst(intensity)
    Effects.chroma = math.max(Effects.chroma, intensity or 0.015)
end

function Effects.spawnShockwave(x, y, strength)
    Effects.shockwaves[#Effects.shockwaves + 1] = {
        x = x, y = y,
        progress = 0.0,
        strength = strength or 0.04,
        speed = 2.4,
    }
end

function Effects.showBanner(text, subtext, duration)
    Effects.banner.text = text
    Effects.banner.subtext = subtext
    Effects.banner.maxTime = duration or 2.0
    Effects.banner.time = Effects.banner.maxTime
end

function Effects.spawnDamage(x, y, amount, isCrit, customColor)
    local text = (type(amount) == "number") and tostring(amount) or tostring(amount)
    Effects.damageNumbers[#Effects.damageNumbers + 1] = {
        x = x + (love.math.random() - 0.5) * 12,
        y = y,
        vy = isCrit and -110 or -70,
        life = isCrit and 1.1 or 0.75,
        maxLife = isCrit and 1.1 or 0.75,
        text = text,
        crit = isCrit or false,
        color = customColor,
        scale = isCrit and 1.3 or 1.0,
    }
end

function Effects.update(dt)
    if Effects.hitstop > 0 then
        Effects.hitstop = Effects.hitstop - dt
    end

    if Effects.shakeTime > 0 then
        Effects.shakeTime = Effects.shakeTime - dt
        if Effects.shakeTime <= 0 then
            Effects.shakeAmount = 0
        end
    end

    if Effects.chroma > 0 then
        Effects.chroma = math.max(0, Effects.chroma - dt * 0.04)
    end

    if Effects.flashTime > 0 then
        Effects.flashTime = Effects.flashTime - dt
        local t = math.max(0, Effects.flashTime / Effects.flashDuration)
        Effects.flashColor[4] = (Effects.flashColor[4] or 0.5) * t
    else
        Effects.flashColor[4] = 0
    end

    -- Shockwaves
    for i = #Effects.shockwaves, 1, -1 do
        local sw = Effects.shockwaves[i]
        sw.progress = sw.progress + dt * sw.speed
        if sw.progress >= 1.0 then
            table.remove(Effects.shockwaves, i)
        end
    end

    -- Banner
    if Effects.banner.time > 0 then
        Effects.banner.time = Effects.banner.time - dt
        if Effects.banner.time <= 0 then
            Effects.banner.text = nil
        end
    end

    -- Floating text
    for i = #Effects.damageNumbers, 1, -1 do
        local d = Effects.damageNumbers[i]
        d.life = d.life - dt
        d.y = d.y + d.vy * dt
        d.vy = d.vy * math.pow(0.88, dt * 60)
        if d.life <= 0 then
            table.remove(Effects.damageNumbers, i)
        end
    end
end

function Effects.getShakeOffset()
    if Effects.shakeTime <= 0 then return 0, 0 end
    local t = Effects.shakeTime / Effects.shakeDuration
    local mag = Effects.shakeAmount * t
    return (love.math.random() - 0.5) * 2 * mag,
           (love.math.random() - 0.5) * 2 * mag
end

function Effects.drawOverlay()
    if Effects.flashColor[4] and Effects.flashColor[4] > 0.01 then
        love.graphics.setColor(Effects.flashColor[1], Effects.flashColor[2], Effects.flashColor[3], Effects.flashColor[4])
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Effects.drawBanner(hugeFont, medFont)
    if not Effects.banner.text or Effects.banner.time <= 0 then return end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local t = Effects.banner.time / Effects.banner.maxTime
    local alpha = math.min(1.0, math.sin(t * math.pi) * 1.5)

    love.graphics.setColor(0, 0, 0, 0.7 * alpha)
    love.graphics.rectangle("fill", 0, H * 0.32, W, 84)
    love.graphics.setColor(1, 0.2, 0.4, 0.8 * alpha)
    love.graphics.rectangle("fill", 0, H * 0.32, W, 3)
    love.graphics.rectangle("fill", 0, H * 0.32 + 81, W, 3)

    if hugeFont then love.graphics.setFont(hugeFont) end
    local tw = hugeFont and hugeFont:getWidth(Effects.banner.text) or 200
    love.graphics.setColor(1, 0.9, 0.3, alpha)
    love.graphics.print(Effects.banner.text, (W - tw) / 2, H * 0.33)

    if Effects.banner.subtext and medFont then
        love.graphics.setFont(medFont)
        local sw = medFont:getWidth(Effects.banner.subtext)
        love.graphics.setColor(1, 1, 1, 0.9 * alpha)
        love.graphics.print(Effects.banner.subtext, (W - sw) / 2, H * 0.39)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Effects.drawDamageNumbers(font)
    if #Effects.damageNumbers == 0 then return end
    local prevFont = love.graphics.getFont()
    if font then love.graphics.setFont(font) end
    for _, d in ipairs(Effects.damageNumbers) do
        local a = math.max(0, d.life / d.maxLife)
        if d.color then
            love.graphics.setColor(d.color[1], d.color[2], d.color[3], a)
        elseif d.crit then
            love.graphics.setColor(1, 0.85, 0.2, a)
        else
            love.graphics.setColor(1, 1, 1, a)
        end
        love.graphics.print(d.text, d.x - 8, d.y)
    end
    if prevFont then love.graphics.setFont(prevFont) end
    love.graphics.setColor(1, 1, 1, 1)
end

return Effects
