-- ui.lua — procedural sci-fi UI library matching Starfall Vengeance reference aesthetics.
-- Features: 45-degree chamfered glowing panels, gold/blue/green bevel buttons,
-- audio sliders, toggle switches, stat gauges, top-bar player/currency pills, and 3D hangar pedestal.

local Assets = require("assets")

local UI = {}

-- Cached geometry helpers
local function drawChamferedPolygon(x, y, w, h, cut, mode)
    cut = cut or 10
    local points = {
        x + cut,     y,
        x + w - cut, y,
        x + w,       y + cut,
        x + w,       y + h - cut,
        x + w - cut, y + h,
        x + cut,     y + h,
        x,           y + h - cut,
        x,           y + cut,
    }
    love.graphics.polygon(mode, points)
end

-- 1. Sci-Fi Glass Panel with Chamfered Corners and Glowing Borders
function UI.drawPanel(x, y, w, h, opts)
    opts = opts or {}
    local cut = opts.cut or 12
    local borderColor = opts.borderColor or { 0.15, 0.55, 0.95, 0.85 }
    local fillColor   = opts.fillColor   or { 0.03, 0.07, 0.15, 0.88 }
    local glowColor   = opts.glowColor   or { 0.10, 0.45, 0.90, 0.25 }

    -- Soft outer glow
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] or 0.2)
    drawChamferedPolygon(x - 3, y - 3, w + 6, h + 6, cut + 2, "line")

    -- Inner background fill
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] or 0.9)
    drawChamferedPolygon(x, y, w, h, cut, "fill")

    -- Main border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.9)
    love.graphics.setLineWidth(2)
    drawChamferedPolygon(x, y, w, h, cut, "line")
    love.graphics.setLineWidth(1)

    -- Top & Bottom Tech Accent Notches
    love.graphics.setColor(0.3, 0.85, 1.0, 0.9)
    love.graphics.line(x + cut + 10, y, x + cut + 30, y)
    love.graphics.line(x + w - cut - 30, y, x + w - cut - 10, y)
    love.graphics.line(x + cut + 10, y + h, x + cut + 30, y + h)
    love.graphics.line(x + w - cut - 30, y + h, x + w - cut - 10, y + h)

    love.graphics.setColor(1, 1, 1, 1)
end

-- Vector sci-fi icons (no missing unicode font dependencies)
function UI.drawIcon(icon, cx, cy, size, color)
    size = size or 20
    color = color or { 1, 1, 1, 1 }
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)

    if icon == "back" or icon == "<" or icon == "chevron_left" or icon == "◀" then
        love.graphics.setLineWidth(3)
        love.graphics.line(cx + size * 0.25, cy - size * 0.5, cx - size * 0.25, cy, cx + size * 0.25, cy + size * 0.5)
        love.graphics.setLineWidth(1)
    elseif icon == "forward" or icon == ">" or icon == "chevron_right" or icon == "▶" then
        love.graphics.setLineWidth(3)
        love.graphics.line(cx - size * 0.25, cy - size * 0.5, cx + size * 0.25, cy, cx - size * 0.25, cy + size * 0.5)
        love.graphics.setLineWidth(1)
    elseif icon == "gear" or icon == "settings" or icon == "⚙" then
        local r = size * 0.46
        for i = 1, 8 do
            local a = (i - 1) * (math.pi / 4)
            local tx = cx + math.cos(a) * r
            local ty = cy + math.sin(a) * r
            love.graphics.push()
            love.graphics.translate(tx, ty)
            love.graphics.rotate(a)
            love.graphics.rectangle("fill", -size * 0.10, -size * 0.12, size * 0.20, size * 0.24, 2)
            love.graphics.pop()
        end
        love.graphics.circle("fill", cx, cy, r * 0.85)
        love.graphics.setColor(0.04, 0.10, 0.24, 1.0)
        love.graphics.circle("fill", cx, cy, r * 0.38)
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    elseif icon == "trophy" or icon == "🏆" then
        love.graphics.polygon("fill", {
            cx - size * 0.42, cy - size * 0.45,
            cx + size * 0.42, cy - size * 0.45,
            cx + size * 0.24, cy + size * 0.08,
            cx - size * 0.24, cy + size * 0.08
        })
        love.graphics.rectangle("fill", cx - size * 0.08, cy + size * 0.08, size * 0.16, size * 0.22)
        love.graphics.rectangle("fill", cx - size * 0.32, cy + size * 0.30, size * 0.64, size * 0.15, 2)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx - size * 0.35, cy - size * 0.18, size * 0.22, math.pi * 0.5, math.pi * 1.5)
        love.graphics.arc("line", "open", cx + size * 0.35, cy - size * 0.18, size * 0.22, -math.pi * 0.5, math.pi * 0.5)
        love.graphics.setLineWidth(1)
    elseif icon == "stats" or icon == "chart" or icon == "📊" then
        local bw = size * 0.20
        local bgap = size * 0.08
        love.graphics.rectangle("fill", cx - bw*1.5 - bgap, cy + size * 0.08, bw, size * 0.42, 2)
        love.graphics.rectangle("fill", cx - bw*0.5, cy - size * 0.45, bw, size * 0.95, 2)
        love.graphics.rectangle("fill", cx + bw*0.5 + bgap, cy - size * 0.18, bw, size * 0.68, 2)
    elseif icon == "help" or icon == "?" then
        love.graphics.setFont(Assets.fonts.large)
        local tw = Assets.fonts.large:getWidth("?")
        local th = Assets.fonts.large:getHeight()
        love.graphics.print("?", cx - tw/2, cy - th/2)
    elseif icon == "play" then
        local s = size * 0.5
        love.graphics.polygon("fill", {
            cx - s * 0.6, cy - s,
            cx + s * 0.9, cy,
            cx - s * 0.6, cy + s
        })
    elseif icon == "rocket" or icon == "hangar" then
        love.graphics.polygon("fill", {
            cx, cy - size * 0.50,
            cx + size * 0.22, cy + size * 0.18,
            cx - size * 0.22, cy + size * 0.18
        })
        love.graphics.polygon("fill", {
            cx - size * 0.20, cy + size * 0.05,
            cx - size * 0.42, cy + size * 0.40,
            cx - size * 0.18, cy + size * 0.30
        })
        love.graphics.polygon("fill", {
            cx + size * 0.20, cy + size * 0.05,
            cx + size * 0.42, cy + size * 0.40,
            cx + size * 0.18, cy + size * 0.30
        })
        love.graphics.setColor(0.3, 0.85, 1.0, 1.0)
        love.graphics.circle("fill", cx, cy - size * 0.10, size * 0.09)
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    elseif icon == "tech" or icon == "techtree" then
        love.graphics.setLineWidth(2)
        love.graphics.line(cx, cy - size * 0.35, cx - size * 0.35, cy + size * 0.30)
        love.graphics.line(cx, cy - size * 0.35, cx + size * 0.35, cy + size * 0.30)
        love.graphics.setLineWidth(1)
        love.graphics.circle("fill", cx, cy - size * 0.35, size * 0.16)
        love.graphics.circle("fill", cx - size * 0.35, cy + size * 0.30, size * 0.16)
        love.graphics.circle("fill", cx + size * 0.35, cy + size * 0.30, size * 0.16)
    elseif icon == "music" then
        love.graphics.circle("fill", cx - size * 0.26, cy + size * 0.25, size * 0.18)
        love.graphics.circle("fill", cx + size * 0.26, cy + size * 0.14, size * 0.18)
        love.graphics.rectangle("fill", cx - size * 0.12, cy - size * 0.40, size * 0.10, size * 0.68)
        love.graphics.rectangle("fill", cx + size * 0.40, cy - size * 0.52, size * 0.10, size * 0.68)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(cx - size * 0.10, cy - size * 0.36, cx + size * 0.45, cy - size * 0.48)
        love.graphics.setLineWidth(1)
    elseif icon == "sound" or icon == "sfx" then
        love.graphics.polygon("fill", {
            cx - size * 0.40, cy - size * 0.18,
            cx - size * 0.12, cy - size * 0.18,
            cx + size * 0.15, cy - size * 0.40,
            cx + size * 0.15, cy + size * 0.40,
            cx - size * 0.12, cy + size * 0.18,
            cx - size * 0.40, cy + size * 0.18
        })
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx + size * 0.08, cy, size * 0.30, -math.pi * 0.32, math.pi * 0.32)
        love.graphics.arc("line", "open", cx + size * 0.08, cy, size * 0.52, -math.pi * 0.36, math.pi * 0.36)
        love.graphics.setLineWidth(1)
    elseif icon == "monitor" or icon == "fullscreen" then
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cx - size * 0.45, cy - size * 0.36, size * 0.90, size * 0.56, 2)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("fill", cx - size * 0.10, cy + size * 0.20, size * 0.20, size * 0.14)
        love.graphics.rectangle("fill", cx - size * 0.30, cy + size * 0.34, size * 0.60, size * 0.08, 1)
    elseif icon == "check" then
        love.graphics.setLineWidth(3)
        love.graphics.line(cx - size * 0.35, cy, cx - size * 0.08, cy + size * 0.30, cx + size * 0.40, cy - size * 0.35)
        love.graphics.setLineWidth(1)
    elseif icon == "lock" then
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", cx, cy - size * 0.15, size * 0.20, math.pi, 2 * math.pi)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("fill", cx - size * 0.28, cy - size * 0.10, size * 0.56, size * 0.46, 3)
        love.graphics.setColor(0.04, 0.10, 0.20, 1.0)
        love.graphics.circle("fill", cx, cy + size * 0.08, size * 0.07)
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    elseif icon == "video" then
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", cx - size * 0.40, cy - size * 0.25, size * 0.60, size * 0.50, 2)
        love.graphics.polygon("fill", {
            cx + size * 0.20, cy - size * 0.15,
            cx + size * 0.45, cy - size * 0.30,
            cx + size * 0.45, cy + size * 0.30,
            cx + size * 0.20, cy + size * 0.15
        })
        love.graphics.polygon("fill", {
            cx - size * 0.20, cy - size * 0.12,
            cx, cy,
            cx - size * 0.20, cy + size * 0.12
        })
        love.graphics.setLineWidth(1)
    elseif icon == "cart" then
        love.graphics.setLineWidth(2)
        love.graphics.line(cx - size * 0.45, cy - size * 0.35, cx - size * 0.25, cy - size * 0.35, cx - size * 0.10, cy + size * 0.15, cx + size * 0.35, cy + size * 0.15, cx + size * 0.45, cy - size * 0.15, cx - size * 0.18, cy - size * 0.15)
        love.graphics.setLineWidth(1)
        love.graphics.circle("fill", cx - size * 0.05, cy + size * 0.35, size * 0.12)
        love.graphics.circle("fill", cx + size * 0.25, cy + size * 0.35, size * 0.12)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 2. Sci-Fi Buttons: Gold primary, Blue secondary, Green equipped, Icon buttons
function UI.drawButton(x, y, w, h, text, style, isHovered, icon)
    style = style or "blue"
    text = text or ""
    local cut = 8

    -- Auto-detect icon if style is "icon" or text is a symbol
    if style == "icon" or text == "" then
        if not icon or icon == "" then
            if text == "◀" or text == "<" then icon = "back"
            elseif text == "▶" or text == ">" then icon = "forward"
            elseif text == "⚙" or text == "gear" then icon = "gear"
            elseif text == "🏆" or text == "trophy" then icon = "trophy"
            elseif text == "📊" or text == "stats" then icon = "stats"
            elseif text == "?" or text == "help" then icon = "help"
            end
        end
    end

    if style == "icon" then
        -- Hexagonal Icon Button
        local baseFill = isHovered and { 0.12, 0.28, 0.55, 0.95 } or { 0.06, 0.14, 0.30, 0.85 }
        love.graphics.setColor(baseFill[1], baseFill[2], baseFill[3], baseFill[4])
        drawChamferedPolygon(x, y, w, h, 8, "fill")

        love.graphics.setColor(0.25, 0.70, 1.0, isHovered and 1.0 or 0.7)
        love.graphics.setLineWidth(2)
        drawChamferedPolygon(x, y, w, h, 8, "line")
        love.graphics.setLineWidth(1)

        local iconColor = isHovered and { 0.4, 0.95, 1.0, 1.0 } or { 1.0, 1.0, 1.0, 0.95 }
        if icon then
            UI.drawIcon(icon, x + w/2, y + h/2, math.min(w, h) * 0.55, iconColor)
        elseif text and text ~= "" then
            love.graphics.setFont(Assets.fonts.medium)
            local tw = Assets.fonts.medium:getWidth(text)
            love.graphics.setColor(iconColor[1], iconColor[2], iconColor[3], 1)
            love.graphics.print(text, x + (w - tw)/2, y + (h - Assets.fonts.medium:getHeight())/2)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Unified button typography: Assets.fonts.medium (18px) for all standard action buttons.
    local font = Assets.fonts.medium
    local iconSize = (icon and icon ~= "") and math.min(18, h * 0.46) or 0
    local spacing = (iconSize > 0 and text and text ~= "") and 8 or 0

    -- Only massive hero action buttons (e.g. LAUNCH MISSION 380x60) use large font
    if w >= 360 and h >= 58 and (Assets.fonts.large:getWidth(text) + iconSize + spacing) <= (w - 40) then
        font = Assets.fonts.large
    elseif (font:getWidth(text) + iconSize + spacing) > (w - 24) or h < 34 or w < 130 then
        -- Graceful fallback to small font if text + icon would touch edges or button is compact
        font = Assets.fonts.small
    end

    local fontH = font:getHeight()
    local textW = font:getWidth(text)
    local totalContentW = iconSize + spacing + textW
    
    local scale = 1.0
    if totalContentW > (w - 16) then
        scale = (w - 16) / totalContentW
        totalContentW = totalContentW * scale
        iconSize = iconSize * scale
        spacing = spacing * scale
        textW = textW * scale
        fontH = fontH * scale
    end

    local startX = x + (w - totalContentW) / 2
    local textX = startX + iconSize + spacing
    local textY = y + (h - fontH) / 2

    if style == "gold" then
        -- Gold / Yellow Primary Action
        local baseFill = isHovered and { 1.0, 0.82, 0.22, 1.0 } or { 0.95, 0.72, 0.15, 0.95 }
        local borderCol = isHovered and { 1.0, 0.95, 0.6, 1.0 } or { 1.0, 0.85, 0.3, 0.9 }

        -- Outer glow
        love.graphics.setColor(1.0, 0.75, 0.1, isHovered and 0.45 or 0.25)
        drawChamferedPolygon(x - 3, y - 3, w + 6, h + 6, cut + 2, "line")

        -- Bevel fill
        love.graphics.setColor(baseFill[1], baseFill[2], baseFill[3], baseFill[4])
        drawChamferedPolygon(x, y, w, h, cut, "fill")

        -- Inner highlight band
        love.graphics.setColor(1, 0.95, 0.6, 0.4)
        love.graphics.rectangle("fill", x + cut, y + 2, w - cut*2, h * 0.35)

        -- Border
        love.graphics.setColor(borderCol[1], borderCol[2], borderCol[3], borderCol[4])
        love.graphics.setLineWidth(2)
        drawChamferedPolygon(x, y, w, h, cut, "line")
        love.graphics.setLineWidth(1)

        -- Draw Icon if provided
        if iconSize > 0 then
            UI.drawIcon(icon, startX + iconSize/2, y + h/2, iconSize, { 0.12, 0.10, 0.05, 1.0 })
        end

        -- Embossed text
        love.graphics.setFont(font)
        love.graphics.setColor(0.12, 0.10, 0.05, 1.0)
        love.graphics.print(text, textX, textY)

    elseif style == "green" then
        -- Green Equipped / Success Button
        local baseFill = isHovered and { 0.18, 0.82, 0.38, 0.95 } or { 0.12, 0.68, 0.30, 0.90 }
        love.graphics.setColor(0.2, 0.9, 0.4, isHovered and 0.4 or 0.2)
        drawChamferedPolygon(x - 2, y - 2, w + 4, h + 4, cut + 2, "line")

        love.graphics.setColor(baseFill[1], baseFill[2], baseFill[3], baseFill[4])
        drawChamferedPolygon(x, y, w, h, cut, "fill")

        love.graphics.setColor(0.4, 1.0, 0.6, 0.95)
        love.graphics.setLineWidth(2)
        drawChamferedPolygon(x, y, w, h, cut, "line")
        love.graphics.setLineWidth(1)

        if iconSize > 0 then
            UI.drawIcon(icon, startX + iconSize/2, y + h/2, iconSize, { 1, 1, 1, 1 })
        end

        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, textX, textY)

    else
        -- Blue Secondary Button
        local baseFill = isHovered and { 0.14, 0.32, 0.68, 0.95 } or { 0.08, 0.18, 0.42, 0.88 }
        local borderCol = isHovered and { 0.40, 0.85, 1.0, 1.0 } or { 0.22, 0.62, 0.98, 0.85 }

        love.graphics.setColor(0.2, 0.6, 1.0, isHovered and 0.4 or 0.18)
        drawChamferedPolygon(x - 2, y - 2, w + 4, h + 4, cut + 1, "line")

        love.graphics.setColor(baseFill[1], baseFill[2], baseFill[3], baseFill[4])
        drawChamferedPolygon(x, y, w, h, cut, "fill")

        -- Subtle top glossy highlight
        love.graphics.setColor(0.5, 0.8, 1.0, 0.25)
        love.graphics.rectangle("fill", x + cut, y + 2, w - cut*2, h * 0.35)

        love.graphics.setColor(borderCol[1], borderCol[2], borderCol[3], borderCol[4])
        love.graphics.setLineWidth(2)
        drawChamferedPolygon(x, y, w, h, cut, "line")
        love.graphics.setLineWidth(1)

        if iconSize > 0 then
            UI.drawIcon(icon, startX + iconSize/2, y + h/2, iconSize, { 1, 1, 1, 1 })
        end

        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, textX, textY)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 3. Top-Bar Player Profile Card
function UI.drawPlayerCard(name, level, xpFrac, x, y, isHovered)
    local w, h = 210, 48
    local cut = 10

    -- Panel background
    love.graphics.setColor(0.04, 0.10, 0.22, 0.92)
    drawChamferedPolygon(x, y, w, h, cut, "fill")

    love.graphics.setColor(0.2, 0.65, 1.0, isHovered and 1.0 or 0.75)
    love.graphics.setLineWidth(2)
    drawChamferedPolygon(x, y, w, h, cut, "line")
    love.graphics.setLineWidth(1)

    -- Circular avatar preview with planet icon
    local ax, ay, ar = x + 24, y + 24, 18
    love.graphics.setColor(0.08, 0.20, 0.40, 1.0)
    love.graphics.circle("fill", ax, ay, ar)

    local pImg = Assets.get("planet00")
    if pImg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(pImg, ax, ay, 0, (ar * 2) / pImg:getWidth(), (ar * 2) / pImg:getHeight(), pImg:getWidth()/2, pImg:getHeight()/2)
    end
    love.graphics.setColor(0.3, 0.8, 1.0, 0.9)
    love.graphics.circle("line", ax, ay, ar)

    -- Callsign & Level
    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(name or "Player001", x + 50, y + 6)

    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.35, 0.85, 1.0, 1)
    love.graphics.print("Lv. " .. (level or 1), x + 50, y + 26)

    -- Mini XP Bar
    local bx, by, bw, bh = x + 88, y + 30, 110, 8
    love.graphics.setColor(0.08, 0.16, 0.28, 0.9)
    love.graphics.rectangle("fill", bx, by, bw, bh, 3)
    love.graphics.setColor(0.25, 0.85, 1.0, 1.0)
    love.graphics.rectangle("fill", bx, by, bw * math.max(0, math.min(1, xpFrac or 0)), bh, 3)
    love.graphics.setColor(0.4, 0.9, 1.0, 0.6)
    love.graphics.rectangle("line", bx, by, bw, bh, 3)

    love.graphics.setColor(1, 1, 1, 1)
    return { x = x, y = y, w = w, h = h }
end

-- 4. Currency Pills (Purple Mineral Scrap & Orange Core) with Golden '+' Button
function UI.drawCurrencyPill(kind, amount, x, y, isHoveredPlus)
    local w, h = 135, 38
    local cut = 8

    -- Background
    love.graphics.setColor(0.04, 0.08, 0.18, 0.92)
    drawChamferedPolygon(x, y, w, h, cut, "fill")

    local borderCol = (kind == "core") and { 0.95, 0.60, 0.20, 0.85 } or { 0.70, 0.40, 1.0, 0.85 }
    love.graphics.setColor(borderCol[1], borderCol[2], borderCol[3], borderCol[4])
    love.graphics.setLineWidth(2)
    drawChamferedPolygon(x, y, w, h, cut, "line")
    love.graphics.setLineWidth(1)

    -- Currency Icon
    local iconKey = (kind == "core") and "core" or "scrap"
    local iconImg = Assets.get(iconKey)
    if iconImg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(iconImg, x + 18, y + h/2, 0, 24/iconImg:getWidth(), 24/iconImg:getHeight(), iconImg:getWidth()/2, iconImg:getHeight()/2)
    else
        love.graphics.setColor(borderCol[1], borderCol[2], borderCol[3], 1)
        love.graphics.circle("fill", x + 18, y + h/2, 10)
    end

    -- Amount Text
    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    local amtStr = tostring(amount or 0)
    love.graphics.print(amtStr, x + 34, y + 9)

    -- Gold '+' Rewarded Ad Button on Right
    local pw, ph = 26, 26
    local px = x + w - pw - 6
    local py = y + (h - ph)/2

    local pFill = isHoveredPlus and { 1.0, 0.88, 0.3, 1.0 } or { 0.95, 0.75, 0.18, 0.95 }
    love.graphics.setColor(pFill[1], pFill[2], pFill[3], pFill[4])
    drawChamferedPolygon(px, py, pw, ph, 4, "fill")

    love.graphics.setColor(1, 0.95, 0.5, 1)
    love.graphics.setLineWidth(1.5)
    drawChamferedPolygon(px, py, pw, ph, 4, "line")
    love.graphics.setLineWidth(1)

    -- Plus symbol
    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(0.12, 0.10, 0.05, 1.0)
    love.graphics.print("+", px + 8, py + 3)

    love.graphics.setColor(1, 1, 1, 1)
    return {
        pill = { x = x, y = y, w = w, h = h },
        plus = { x = px, y = py, w = pw, h = ph },
    }
end

-- 5. Audio Sliders with Illuminated Track and Circular Knob
function UI.drawSlider(x, y, w, val, isHovered)
    val = math.max(0, math.min(1, val or 0))
    local trackH = 10
    local ty = y - trackH / 2

    -- Track Background
    love.graphics.setColor(0.06, 0.14, 0.26, 0.95)
    love.graphics.rectangle("fill", x, ty, w, trackH, 5)

    -- Active Track Fill
    love.graphics.setColor(0.15, 0.65, 1.0, 0.95)
    love.graphics.rectangle("fill", x, ty, w * val, trackH, 5)

    -- Track Border
    love.graphics.setColor(0.3, 0.8, 1.0, 0.7)
    love.graphics.rectangle("line", x, ty, w, trackH, 5)

    -- Circular Knob
    local kx = x + w * val
    local kr = isHovered and 11 or 9

    -- Knob outer glow
    love.graphics.setColor(0.3, 0.85, 1.0, 0.4)
    love.graphics.circle("fill", kx, y, kr + 4)

    -- Knob body
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", kx, y, kr)

    -- Knob inner blue ring
    love.graphics.setColor(0.15, 0.60, 1.0, 1)
    love.graphics.circle("line", kx, y, kr - 2)

    love.graphics.setColor(1, 1, 1, 1)
    return { x = x, y = ty, w = w, h = trackH }
end

-- 6. Animated ON / OFF Pill Toggle Switch
function UI.drawToggle(x, y, state, isHovered)
    local w, h = 64, 30
    local cut = 12

    local bgCol = state and { 0.15, 0.65, 1.0, 0.95 } or { 0.10, 0.18, 0.28, 0.90 }
    love.graphics.setColor(bgCol[1], bgCol[2], bgCol[3], bgCol[4])
    drawChamferedPolygon(x, y, w, h, cut, "fill")

    love.graphics.setColor(0.35, 0.85, 1.0, isHovered and 1.0 or 0.65)
    love.graphics.setLineWidth(2)
    drawChamferedPolygon(x, y, w, h, cut, "line")
    love.graphics.setLineWidth(1)

    -- Text
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    local txt = state and "ON" or "OFF"
    local tx = state and (x + 10) or (x + w - 30)
    love.graphics.print(txt, tx, y + 8)

    -- Sliding Circular Knob
    local kr = 10
    local kx = state and (x + w - kr - 5) or (x + kr + 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", kx, y + h/2, kr)
    love.graphics.setColor(0.2, 0.6, 1.0, 0.8)
    love.graphics.circle("line", kx, y + h/2, kr)

    love.graphics.setColor(1, 1, 1, 1)
    return { x = x, y = y, w = w, h = h }
end

-- 7. Segmented Stat Bars (SPEED, FIRE RATE, HEALTH)
function UI.drawStatBar(label, current, maxVal, x, y, w)
    maxVal = maxVal or 5
    current = math.max(0, math.min(maxVal, current or 1))

    -- Label
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.55, 0.75, 1.0, 1.0)
    love.graphics.print(label, x, y)

    -- Segmented Bar
    local barX = x + 110
    local barH = 12
    local totalW = w or 160
    local gap = 4
    local segW = (totalW - (maxVal - 1) * gap) / maxVal

    for i = 1, maxVal do
        local sx = barX + (i - 1) * (segW + gap)
        local filled = (i <= current)

        if filled then
            love.graphics.setColor(0.2, 0.75, 1.0, 0.95)
            love.graphics.rectangle("fill", sx, y + 2, segW, barH, 2)
            love.graphics.setColor(0.5, 0.9, 1.0, 1.0)
            love.graphics.rectangle("line", sx, y + 2, segW, barH, 2)
        else
            love.graphics.setColor(0.08, 0.16, 0.28, 0.6)
            love.graphics.rectangle("fill", sx, y + 2, segW, barH, 2)
            love.graphics.setColor(0.2, 0.4, 0.6, 0.4)
            love.graphics.rectangle("line", sx, y + 2, segW, barH, 2)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 8. 3D Illuminated Showcase Pedestal with Overhead Spotlight
function UI.drawPedestal(cx, cy, rx, ry, time)
    time = time or 0
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    -- 1. Overhead Spotlight Cone shining from hangar ceiling
    local topSpotW = 80
    local botSpotW = rx * 1.8
    local spotPoints = {
        cx - topSpotW / 2, 0,
        cx + topSpotW / 2, 0,
        cx + botSpotW / 2, cy - 10,
        cx - botSpotW / 2, cy - 10,
    }
    love.graphics.setColor(0.2, 0.6, 1.0, 0.08 + 0.02 * math.sin(time * 2))
    love.graphics.polygon("fill", spotPoints)

    -- Spotlight source glow emitter at ceiling
    love.graphics.setColor(0.4, 0.85, 1.0, 0.35)
    love.graphics.ellipse("fill", cx, 15, topSpotW / 2, 8)

    -- 2. Concentric Sci-Fi Platform Rings
    -- Outer Base Bevel
    love.graphics.setColor(0.04, 0.09, 0.20, 0.9)
    love.graphics.ellipse("fill", cx, cy + 8, rx * 1.15, ry * 1.15)
    love.graphics.setColor(0.12, 0.30, 0.60, 0.7)
    love.graphics.ellipse("line", cx, cy + 8, rx * 1.15, ry * 1.15)

    -- Main Raised Platform
    love.graphics.setColor(0.07, 0.16, 0.34, 0.95)
    love.graphics.ellipse("fill", cx, cy, rx, ry)

    -- Inner Glowing Core Ring
    local pulse = 0.65 + 0.25 * math.sin(time * 3)
    love.graphics.setColor(0.15, 0.75, 1.0, pulse)
    love.graphics.setLineWidth(3)
    love.graphics.ellipse("line", cx, cy, rx * 0.78, ry * 0.78)
    love.graphics.setLineWidth(1)

    -- Radial Neon Segment Markers around edge
    for i = 0, 7 do
        local a = (i / 8) * math.pi * 2 + (time * 0.4)
        local px1 = cx + math.cos(a) * (rx * 0.82)
        local py1 = cy + math.sin(a) * (ry * 0.82)
        local px2 = cx + math.cos(a) * (rx * 0.96)
        local py2 = cy + math.sin(a) * (ry * 0.96)
        love.graphics.setColor(0.3, 0.9, 1.0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.line(px1, py1, px2, py2)
    end
    love.graphics.setLineWidth(1)

    -- Soft Pedestal Upward Ambient Glow
    love.graphics.setColor(0.2, 0.7, 1.0, 0.16)
    love.graphics.ellipse("fill", cx, cy - 4, rx * 0.6, ry * 0.6)

    love.graphics.setColor(1, 1, 1, 1)
end

return UI
