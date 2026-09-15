-- touchcontrols.lua — mobile dual virtual joysticks + Dash and Special Ability buttons.
-- Left stick moves, right stick aims and auto-fires when pushed outward.

local Touch = {}
Touch.enabled = true

Touch.left  = { id = nil, ox = 0, oy = 0, x = 0, y = 0, active = false }
Touch.right = { id = nil, ox = 0, oy = 0, x = 0, y = 0, active = false }

Touch.RADIUS = 80
Touch.DEADZONE = 12
Touch.FIRE_THRESHOLD = 24

Touch.dashRequested = false
Touch.specialRequested = false
Touch.hasTouched = false

function Touch.reset()
    Touch.left.id = nil;  Touch.left.active = false
    Touch.right.id = nil; Touch.right.active = false
    Touch.dashRequested = false
    Touch.specialRequested = false
    Touch.hasTouched = false
end

local function assignStick(stick, id, x, y)
    stick.id = id
    stick.ox, stick.oy = x, y
    stick.x, stick.y = x, y
    stick.active = true
end

function Touch.touchpressed(id, x, y)
    if not Touch.enabled then return end
    Touch.hasTouched = true
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Check virtual action buttons (on right side above joystick)
    -- Dash button at (W - 70, H - 220, r=32)
    local ddx, ddy = x - (W - 70), y - (H - 220)
    if ddx*ddx + ddy*ddy < 36*36 then
        Touch.dashRequested = true
        return
    end

    -- Special button at (W - 145, H - 200, r=32)
    local sdx, sdy = x - (W - 145), y - (H - 200)
    if sdx*sdx + sdy*sdy < 36*36 then
        Touch.specialRequested = true
        return
    end

    if x < W * 0.48 then
        if not Touch.left.active then assignStick(Touch.left, id, x, y) end
    else
        if not Touch.right.active then assignStick(Touch.right, id, x, y) end
    end
end

function Touch.touchmoved(id, x, y)
    if Touch.left.id == id then Touch.left.x, Touch.left.y = x, y end
    if Touch.right.id == id then Touch.right.x, Touch.right.y = x, y end
end

function Touch.touchreleased(id)
    if Touch.left.id == id then Touch.left.active = false; Touch.left.id = nil end
    if Touch.right.id == id then Touch.right.active = false; Touch.right.id = nil end
end

function Touch.consumeDash()
    local r = Touch.dashRequested
    Touch.dashRequested = false
    return r
end

function Touch.consumeSpecial()
    local r = Touch.specialRequested
    Touch.specialRequested = false
    return r
end

-- Returns moveX, moveY, aimDirX, aimDirY, firing
function Touch.getInput()
    local mx, my = 0, 0
    if Touch.left.active then
        local dx = Touch.left.x - Touch.left.ox
        local dy = Touch.left.y - Touch.left.oy
        local len = math.sqrt(dx*dx + dy*dy)
        if len > Touch.DEADZONE then
            local range = Touch.RADIUS - Touch.DEADZONE
            local scale = math.min(1, (len - Touch.DEADZONE) / range)
            mx = (dx / len) * scale
            my = (dy / len) * scale
        end
    end

    local aimX, aimY = nil, nil
    local firing = false
    if Touch.right.active then
        local dx = Touch.right.x - Touch.right.ox
        local dy = Touch.right.y - Touch.right.oy
        local len = math.sqrt(dx*dx + dy*dy)
        if len > Touch.FIRE_THRESHOLD then
            aimX = dx / len
            aimY = dy / len
            firing = true
        end
    end

    return mx, my, aimX, aimY, firing
end

function Touch.draw()
    if not Touch.enabled or not Touch.hasTouched then return end
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Virtual buttons
    love.graphics.setColor(0.1, 0.4, 0.8, 0.35)
    love.graphics.circle("fill", W - 70, H - 220, 34)
    love.graphics.setColor(0.3, 0.8, 1.0, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", W - 70, H - 220, 34)
    love.graphics.print("DASH", W - 84, H - 227)

    love.graphics.setColor(0.5, 0.2, 0.7, 0.35)
    love.graphics.circle("fill", W - 145, H - 200, 34)
    love.graphics.setColor(0.8, 0.4, 1.0, 0.9)
    love.graphics.circle("line", W - 145, H - 200, 34)
    love.graphics.setLineWidth(1)
    love.graphics.print("SPEC", W - 160, H - 207)

    local function stick(s)
        if not s.active then return end
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.circle("fill", s.ox, s.oy, Touch.RADIUS)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.circle("line", s.ox, s.oy, Touch.RADIUS)

        local dx = s.x - s.ox
        local dy = s.y - s.oy
        local len = math.sqrt(dx*dx + dy*dy)
        if len > Touch.RADIUS then
            dx, dy = dx/len * Touch.RADIUS, dy/len * Touch.RADIUS
        end
        love.graphics.setColor(0.5, 0.8, 1, 0.6)
        love.graphics.circle("fill", s.ox + dx, s.oy + dy, 26)
        love.graphics.setColor(1, 1, 1, 1)
    end
    stick(Touch.left)
    stick(Touch.right)
    love.graphics.setColor(1, 1, 1, 1)
end

return Touch
