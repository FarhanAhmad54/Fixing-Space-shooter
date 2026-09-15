-- main.lua — Starfall Vengeance entry point and core game state machine.
-- States: menu -> hangar -> modeselect -> play -> upgrade -> revive_prompt -> gameover -> paused.

print("[STARFALL] main.lua found")
local Assets     = require("assets")
local Sound      = require("sound")
local Profile    = require("profile")
local Particles  = require("particles")
local Effects    = require("effects")
local Weapons    = require("weapons")
local Bullet     = require("bullet")
local Enemy      = require("enemy")
local Player     = require("player")
local Powerup    = require("powerup")
local XP         = require("xp")
local Drone      = require("drone")
local Modes      = require("modes")
local Touch      = require("touchcontrols")
local Portal     = require("portal")
local Shaders    = require("shaders")
local Background = require("background")
local UI         = require("ui")
local EnemyAI    = require("enemyai")
local Squad      = require("squad")
local Boss       = require("boss")
local AIDebug    = require("aidebug")

print("[STARFALL] main.lua executed")

local SHIP_LIST = { "basic", "cobalt", "solar", "phantom", "emerald", "void" }

local GAME = {
    state = "menu",
    activeModal = nil, -- nil, "settings", "profile", "stats", "help"
    background = nil,
    run = nil,
    player = nil,
    input = { moveX = 0, moveY = 0, aimX = 0, aimY = 0, firing = false },
    menuIndex = 1,
    hangarTab = "ships", -- "ships" or "tech"
    hangarShipIndex = 1,
    hangarTechIndex = 1,
    upgradeChoices = nil,
    upgradeIndex = 1,
    stars = {},
    starOffset = 0,
    lastDeath = nil,

    -- Monetization & Revive
    canRevive = true,
    reviveTimer = 0,
    hasDoubledScrap = false,

    -- UI Dragging State
    draggingSlider = nil,
}

local atan2 = math.atan2 or math.atan

-- ============================================================
-- Lifecycle
-- ============================================================

function love.load()
    print("[STARFALL] love.load started")
    love.graphics.setDefaultFilter("linear", "linear")
    love.graphics.setBackgroundColor(0.012, 0.02, 0.05)

    Assets.load()
    Sound.new()
    Profile.init()
    if Profile.data.settings then
        Sound.setMusicVolume(Profile.data.settings.musicVolume or 0.8)
        Sound.setMusicEnabled(Profile.data.settings.musicEnabled ~= false)
        Sound.setSfxVolume(Profile.data.settings.sfxVolume or 1.0)
        Sound.setSfxEnabled(Profile.data.settings.sfxEnabled ~= false)
        if Profile.data.settings.fullscreen then
            pcall(love.window.setFullscreen, true)
        end
    end
    Particles.load()
    Bullet.load()
    Effects.reset()
    Touch.reset()
    Shaders.init()
    GAME.background = Background.new()

    GAME.stars = {}
    local W = math.max(640, love.graphics.getWidth() or 1280)
    local H = math.max(360, love.graphics.getHeight() or 720)
    for i = 1, 160 do
        GAME.stars[i] = {
            x = love.math.random() * W,
            y = love.math.random() * H,
            z = love.math.random() * 0.9 + 0.1,
        }
    end

    Sound.startMusic()
    Portal.ready()
    Portal.loadingFinished()
    print("[STARFALL] love.load completed")
end

function love.focus(focused)
    if not focused and GAME.state == "play" then
        GAME.state = "paused"
        Portal.gameplayStop()
        Sound.stopMusic()
    elseif focused and GAME.state == "play" then
        Sound.startMusic()
    end
end

-- ============================================================
-- Run Management
-- ============================================================

local function startRun(modeId)
    local selectedShipId = Profile.data.selectedShip or "viper"
    GAME.run = {
        modeId = modeId,
        wave = 1,
        spawnQueue = {},
        spawnTimer = 0,
        score = 0,
        elapsed = 0,
        combo = 1,
        comboTimer = 0,
        xp = 0,
        level = 1,
        scrapEarned = 0,
        coresEarned = 0,
        weaponLevels = { 1, 1, 1, 1 },
        upgrades = { damage = 0, firerate = 0, speed = 0, health = 0, pierce = 0, drones = 0, homing = 0, tesla = 0, overcharge = 0, vortex = 0 },
        timeLeft = nil,
        asteroidTimer = 6.0,
    }

    GAME.player = Player.new(Profile.data.upgrades, selectedShipId)
    Enemy.reset()
    Bullet.clear()
    Powerup.reset()
    Drone.reset()
    Effects.reset()
    Particles.clear()
    Touch.reset()

    GAME.canRevive = true
    GAME.hasDoubledScrap = false
    GAME.state = "play"

    Portal.gameplayStart()
    Sound.startMusic()
end

local function beginWave()
    local run = GAME.run
    local rules = Modes.waveRules(run)
    run.spawnQueue = {}

    for _ = 1, rules.count do
        run.spawnQueue[#run.spawnQueue + 1] = {
            type = rules.types[love.math.random(1, #rules.types)],
            hpMul = rules.hpMul,
            speedMul = rules.speedMul,
        }
    end

    if rules.boss then
        run.spawnQueue[#run.spawnQueue + 1] = {
            type = rules.bossType or "miniboss",
            hpMul = rules.hpMul,
            speedMul = rules.speedMul,
        }
    end

    run.spawnTimer = 0.5
    run.timeLeft = Modes.get(run.modeId).timeLimit
end

local function triggerDeathOrRevive()
    local run = GAME.run
    if GAME.canRevive then
        GAME.canRevive = false
        GAME.reviveTimer = 8.0
        GAME.state = "revive_prompt"
        Portal.gameplayStop()
        Sound.play("playerhit", 0.7)
    else
        if run then
            Profile.recordRun(run.modeId, run.score, run.wave, run.scrapEarned, run.coresEarned)
            GAME.lastDeath = { score = run.score, wave = run.wave, scrap = run.scrapEarned, cores = run.coresEarned }
        end
        Portal.gameplayStop()
        Portal.commercialBreak()
        GAME.state = "gameover"
    end
end

-- ============================================================
-- Shooting & Combat
-- ============================================================

local function playerShoot()
    local p = GAME.player
    local run = GAME.run
    if not p or p.cooldown > 0 or not run then return end

    local def = Weapons.getActiveDef(p.weaponIndex, run, p.upgrades)

    local aimDX = GAME.input.aimX - p.x
    local aimDY = GAME.input.aimY - p.y
    local len = math.sqrt(aimDX*aimDX + aimDY*aimDY)
    if len < 1 then return end
    aimDX, aimDY = aimDX/len, aimDY/len

    local rapid = p:hasPowerup("rapid")
    p.cooldown = def.cooldown * (rapid and 0.45 or 1)

    local homing = p:hasPowerup("homing") or def.homing
    local explosive = p:hasPowerup("explosive") or def.explosive
    local baseAng = atan2(aimDY, aimDX)

    for _ = 1, def.pellets do
        local ang = baseAng + (love.math.random() - 0.5) * def.spread * 2
        local b = Bullet.fire({
            x = p.x, y = p.y,
            vx = math.cos(ang) * def.speed,
            vy = math.sin(ang) * def.speed,
            damage = def.damage, life = def.life,
            pierce = def.pierce + (p.chassis.pierceBonus or 0),
            friendly = true, bulletKey = def.bulletKey, size = def.size,
            color = def.color,
            homing = homing,
            explosive = explosive,
            chainLightning = def.chainLightning,
            vortex = def.vortex,
        })
    end

    -- Recoil
    p.x = p.x - aimDX * def.recoil
    p.y = p.y - aimDY * def.recoil

    Sound.play("shoot", def.soundPitch)
    Effects.shake(def.isEvolved and 3.5 or 1.5, 0.08)
    Particles.emit(p.x + aimDX * 24, p.y + aimDY * 24, def.isEvolved and 8 or 3, {
        dir = baseAng, spread = 0.5, speed = 140, life = 0.22, size = 3,
        r = def.color[1], g = def.color[2], b = def.color[3],
    })
end

local function enemyFire(opts)
    Bullet.fire(opts)
end

local function advanceWaveOrEnd()
    local run = GAME.run
    local def = Modes.get(run.modeId)

    run.wave = run.wave + 1

    if def.maxWaves and run.wave > def.maxWaves then
        Profile.recordRun(run.modeId, run.score, run.wave - 1, run.scrapEarned, run.coresEarned)
        GAME.lastDeath = { score = run.score, wave = run.wave - 1, scrap = run.scrapEarned, cores = run.coresEarned }
        Portal.gameplayStop()
        Portal.commercialBreak()
        GAME.state = "gameover"
        return
    end

    -- Wave clear bonus
    run.score = run.score + run.wave * 30
    run.scrapEarned = run.scrapEarned + run.wave * 15
    Effects.showBanner("WAVE " .. run.wave, "SYSTEMS CLEARED +BONUS SCRAP", 1.8)
    Sound.play("levelup", 1.2)
    Portal.happytime()
    beginWave()
end

-- ============================================================
-- Play Update Loop
-- ============================================================

local function updatePlay(dt)
    if GAME.state ~= "play" then return end
    local run = GAME.run
    local p = GAME.player
    if not run or not p then return end

    -- ---- Input ----------------------------------------------------------
    local mx, my = 0, 0
    if love.keyboard.isDown("a") or love.keyboard.isDown("left")  then mx = mx - 1 end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then mx = mx + 1 end
    if love.keyboard.isDown("w") or love.keyboard.isDown("up")    then my = my - 1 end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down")  then my = my + 1 end

    local tmx, tmy, taimX, taimY, tfiring = Touch.getInput()
    if tmx ~= 0 or tmy ~= 0 then mx, my = tmx, tmy end

    GAME.input.moveX = mx
    GAME.input.moveY = my

    if taimX and tfiring then
        GAME.input.aimX = p.x + taimX * 240
        GAME.input.aimY = p.y + taimY * 240
        GAME.input.firing = true
    else
        local mX, mY = love.mouse.getPosition()
        GAME.input.aimX = mX
        GAME.input.aimY = mY
        GAME.input.firing = love.mouse.isDown(1)
    end

    -- Mobile Virtual Dash & Special buttons
    if Touch.consumeDash() then p:tryDash(mx, my) end
    if Touch.consumeSpecial() then p:triggerSpecial(Enemy, Bullet) end

    -- Right Click special ability on Desktop
    if love.mouse.isDown(2) then
        p:triggerSpecial(Enemy, Bullet)
    end

    -- ---- Player update --------------------------------------------------
    p:update(dt, GAME.input)
    if GAME.input.firing then playerShoot() end

    run.elapsed = run.elapsed + dt

    -- ---- Asteroid Hazard Spawns -----------------------------------------
    run.asteroidTimer = run.asteroidTimer - dt
    if run.asteroidTimer <= 0 then
        run.asteroidTimer = 6.0 + love.math.random() * 6.0
        Enemy.spawnAsteroid()
    end

    -- ---- Enemy Spawning -------------------------------------------------
    if #run.spawnQueue > 0 then
        run.spawnTimer = run.spawnTimer - dt
        if run.spawnTimer <= 0 then
            run.spawnTimer = 0.35 + love.math.random() * 0.35
            local s = table.remove(run.spawnQueue, 1)
            Enemy.spawn(s.type, nil, nil, s.hpMul, s.speedMul)
        end
    end

    -- ---- Tactical Squad & Enemy AI Coordination ------------------------
    EnemyAI.updatePlayerTracker(dt, p)
    Squad.update(dt, p, Enemy.list)

    -- ---- Enemies & Bullets ----------------------------------------------
    Enemy.update(dt, p, enemyFire)
    Bullet.update(dt, Enemy.list)

    -- ---- Collisions: Player Bullets vs Enemies --------------------------
    for i = #Bullet.list, 1, -1 do
        local b = Bullet.list[i]
        if b.friendly then
            local consumed = false
            for _, e in ipairs(Enemy.list) do
                if e.alive and (not b.hitList or not b.hitList[e]) then
                    local dx, dy = e.x - b.x, e.y - b.y
                    local r = e.radius + b.radius
                    if dx*dx + dy*dy < r*r then
                        -- Check critical strike
                        local isCrit = love.math.random() < (0.05 + (p.chassis.critBonus or 0) + (p.upgrades.crit or 0) * 0.05)
                        local dmg = b.damage * (isCrit and 2.2 or 1.0)

                        if e.invulnerable then
                            Sound.play("hit", 2.0)
                            Effects.spawnDamage(e.x, e.y - e.radius, "IMMUNE", false, { 0.4, 0.8, 1.0 })
                        else
                            if e.shield and e.shield > 0 then
                                e.shield = math.max(0, e.shield - dmg)
                                Sound.play("hit", 1.8)
                            else
                                e.hp = e.hp - dmg
                                e.hitFlash = 0.08
                                Effects.spawnDamage(e.x, e.y - e.radius, math.floor(dmg), isCrit)
                                Sound.play("hit", isCrit and 0.9 or 1.4)
                            end
                        end

                        Particles.emit(b.x, b.y, 4, {
                            speed = 170, life = 0.3, size = 2,
                            r = b.color[1], g = b.color[2], b = b.color[3],
                        })

                        -- Chain Lightning Super Weapon
                        if b.chainLightning then
                            for _, e2 in ipairs(Enemy.list) do
                                if e2 ~= e and e2.alive then
                                    local cdx, cdy = e2.x - e.x, e2.y - e.y
                                    if cdx*cdx + cdy*cdy < 160*160 then
                                        e2.hp = e2.hp - dmg * 0.75
                                        e2.hitFlash = 0.08
                                        Particles.emit((e.x + e2.x)/2, (e.y + e2.y)/2, 6, {
                                            speed = 100, life = 0.2, size = 2,
                                            r = 0.3, g = 0.9, b = 1.0,
                                        })
                                    end
                                end
                            end
                        end

                        -- Explosive AoE
                        if b.explosive then
                            Effects.shake(5, 0.15)
                            Effects.spawnShockwave(b.x / love.graphics.getWidth(), b.y / love.graphics.getHeight(), 0.04)
                            Particles.emit(b.x, b.y, 14, {
                                speed = 250, life = 0.4, size = 4,
                                r = 1, g = 0.5, b = 0.2,
                            })
                            for _, e2 in ipairs(Enemy.list) do
                                if e2 ~= e and e2.alive then
                                    local dx2, dy2 = e2.x - b.x, e2.y - b.y
                                    if dx2*dx2 + dy2*dy2 < 100*100 then
                                        e2.hp = e2.hp - dmg * 0.6
                                        e2.hitFlash = 0.06
                                    end
                                end
                            end
                        end

                        -- Enemy Death
                        if e.hp <= 0 and e.alive then
                            e.alive = false
                            local gained = math.floor(e.score * run.combo)
                            run.score = run.score + gained
                            run.combo = math.min(9.9, run.combo + 0.15)
                            run.comboTimer = 3.2
                            Effects.spawnDamage(e.x, e.y, gained, true)
                            Sound.play("explosion")
                            Effects.shake(e.boss and 16 or 6, e.boss and 0.5 or 0.2)
                            Effects.chromaBurst(e.boss and 0.03 or 0.01)

                            -- Drop Scrap and Cores
                            run.scrapEarned = run.scrapEarned + e.scrap
                            Powerup.spawnCurrency(e.x, e.y, "scrap", e.scrap)
                            if e.cores and e.cores > 0 then
                                run.coresEarned = run.coresEarned + e.cores
                                Powerup.spawnCurrency(e.x, e.y, "core", e.cores)
                            end

                            -- Splitter Champion affix
                            if e.affix and e.affix.name == "Splitter" then
                                for _ = 1, 3 do
                                    Enemy.spawn("swarmer", e.x + (love.math.random() - 0.5) * 30, e.y + (love.math.random() - 0.5) * 30, 0.6, 1.2, 0.0)
                                end
                            end

                            Particles.emit(e.x, e.y, e.boss and 50 or 20, {
                                speed = e.boss and 320 or 220, life = 0.6, size = 4,
                                r = e.def.color[1], g = e.def.color[2], b = e.def.color[3],
                            })

                            if XP.addXP(run, e.xp) and GAME.state == "play" then
                                GAME.upgradeChoices = XP.rollChoices(run, 3)
                                GAME.upgradeIndex = 1
                                GAME.state = "upgrade"
                                Sound.play("levelup")
                                Effects.flash(1, 1, 0.5, 0.35, 0.3)
                                Portal.gameplayStop()
                                return
                            end
                        end

                        if b.pierce > 0 then
                            b.pierce = b.pierce - 1
                            if not b.hitList then b.hitList = {} end
                            b.hitList[e] = true
                        else
                            b.active = false
                            Bullet.free[#Bullet.free + 1] = b._idx
                            table.remove(Bullet.list, i)
                            consumed = true
                            break
                        end
                    end
                end
            end
        end
    end

    -- ---- Collisions: Player Bullets vs Space Asteroids -------------------
    if Enemy.hazards then
        for i = #Bullet.list, 1, -1 do
            local b = Bullet.list[i]
            if b and b.friendly then
                for j = #Enemy.hazards, 1, -1 do
                    local h = Enemy.hazards[j]
                    local dx, dy = h.x - b.x, h.y - b.y
                    local r = h.radius + b.radius
                    if dx*dx + dy*dy < r*r then
                        h.hp = h.hp - b.damage
                        Particles.emit(b.x, b.y, 4, { speed = 80, life = 0.2, size = 2, r = 0.6, g = 0.5, b = 0.4 })
                        if h.hp <= 0 then
                            Sound.play("explosion", 0.5)
                            Effects.shake(4, 0.12)
                            Particles.emit(h.x, h.y, 12, { speed = 120, life = 0.35, size = 3, r = 0.7, g = 0.6, b = 0.5 })
                            Powerup.spawnCurrency(h.x, h.y, "scrap", h.size == 2 and 2 or 1)
                            table.remove(Enemy.hazards, j)
                        end
                        if b.pierce > 0 then
                            b.pierce = b.pierce - 1
                        else
                            b.active = false
                            Bullet.free[#Bullet.free + 1] = b._idx
                            table.remove(Bullet.list, i)
                            break
                        end
                    end
                end
            end
        end

        -- ---- Collisions: Space Asteroids vs Player -----------------------
        for j = #Enemy.hazards, 1, -1 do
            local h = Enemy.hazards[j]
            local dx, dy = p.x - h.x, p.y - h.y
            local r = p.radius + h.radius
            if dx*dx + dy*dy < r*r then
                local lost = p:hurt(1)
                h.hp = h.hp - 10
                if h.hp <= 0 then
                    table.remove(Enemy.hazards, j)
                end
                if lost and p.lives <= 0 then
                    triggerDeathOrRevive()
                    return
                end
            end
        end
    end

    -- ---- Collisions: Enemy Bullets vs Player -----------------------------
    for i = #Bullet.list, 1, -1 do
        local b = Bullet.list[i]
        if not b.friendly then
            local dx, dy = p.x - b.x, p.y - b.y
            local r = p.radius + b.radius
            if dx*dx + dy*dy < r*r then
                local lost = p:hurt(b.damage)
                b.active = false
                Bullet.free[#Bullet.free + 1] = b._idx
                table.remove(Bullet.list, i)
                if lost and p.lives <= 0 then
                    triggerDeathOrRevive()
                    return
                end
            end
        end
    end

    -- ---- Collisions: Enemies vs Player -----------------------------------
    for _, e in ipairs(Enemy.list) do
        if e.alive then
            local dx, dy = p.x - e.x, p.y - e.y
            local r = p.radius + e.radius
            if dx*dx + dy*dy < r*r then
                local lost = p:hurt(e.damage)
                if lost and p.lives <= 0 then
                    triggerDeathOrRevive()
                    return
                end
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    e.x = e.x - dx/len * 15
                    e.y = e.y - dy/len * 15
                end
            end
        end
    end

    -- ---- Wave Progression -----------------------------------------------
    if Modes.get(run.modeId).timeLimit and run.timeLeft then
        run.timeLeft = run.timeLeft - dt
        if run.timeLeft <= 0 then
            run.score = run.score + 250
            advanceWaveOrEnd()
            if GAME.state ~= "play" then return end
        end
    end

    if #run.spawnQueue == 0 and Enemy.aliveCount() == 0 then
        advanceWaveOrEnd()
        if GAME.state ~= "play" then return end
    end

    -- ---- Combo Decay ----------------------------------------------------
    if run.comboTimer > 0 then
        run.comboTimer = run.comboTimer - dt
        if run.comboTimer <= 0 then
            run.combo = 1.0
        end
    end

    -- ---- Powerups, Drones, Currency -------------------------------------
    Powerup.update(dt, p, function(amount, cores)
        run.scrapEarned = run.scrapEarned + amount
        if cores and cores > 0 then run.coresEarned = run.coresEarned + cores end
    end)

    local totalDrones = (run.upgrades.drones or 0) + (p.upgrades.drones or 0)
    Drone.setCount(totalDrones)
    if #Drone.list > 0 then
        Drone.update(dt, p, Enemy.list, function(x, y, dx, dy, isOverclocked)
            Bullet.fire({
                x = x, y = y,
                vx = dx * (isOverclocked and 850 or 720),
                vy = dy * (isOverclocked and 850 or 720),
                damage = (isOverclocked and 10 or 6) * (1 + (run.upgrades.damage or 0) * 0.12),
                life = 0.9, friendly = true, size = isOverclocked and 5 or 4,
                homing = isOverclocked,
                color = isOverclocked and { 0.2, 1.0, 0.8 } or { 0.4, 1, 1 },
            })
        end)
    end
end

local _starfallDiagUpdateLogged = false
function love.update(dt)
    if not _starfallDiagUpdateLogged then
        _starfallDiagUpdateLogged = true
        print("[STARFALL] love.update running")
    end
    if dt > 0.1 then dt = 0.1 end

    local rewardSuccess, rewardType = Portal.pollReward(dt)
    if rewardSuccess ~= nil then
        if rewardSuccess then
            if rewardType == "scrap_crate" then
                Profile.data.scrap = (Profile.data.scrap or 0) + 150
                Profile.save()
                Sound.play("powerup", 1.2)
                Effects.flash(0.8, 0.3, 1.0, 0.35, 0.35)
                Effects.showBanner("SUPPLY CRATE OPENED", "+150 REFINED SCRAP", 2.0)
            elseif rewardType == "core_crate" then
                Profile.data.cores = (Profile.data.cores or 0) + 1
                Profile.save()
                Sound.play("levelup", 1.3)
                Effects.flash(1.0, 0.7, 0.2, 0.35, 0.35)
                Effects.showBanner("QUANTUM MATRIX UNLOCKED", "+1 ENERGY CORE", 2.0)
            elseif rewardType == "revive" then
                GAME.state = "play"
                GAME.reviveTimer = 0
                if GAME.player then
                    GAME.player.lives = GAME.player.maxLives
                    GAME.player.invuln = 3.5
                    GAME.player:triggerSpecial(Enemy, Bullet)
                end
                Effects.flash(0.2, 0.8, 1.0, 0.4, 0.4)
                Effects.showBanner("SYSTEMS RESTORED", "SHIELDS OVERCHARGED", 1.8)
                Portal.gameplayStart()
            elseif rewardType == "doubler" then
                if GAME.lastDeath then
                    Profile.data.scrap = (Profile.data.scrap or 0) + GAME.lastDeath.scrap
                    Profile.save()
                    Sound.play("powerup", 1.3)
                    Effects.flash(1.0, 0.8, 0.2, 0.3, 0.3)
                end
            end
        else
            Effects.showBanner("AD CANCELED", "REWARD NOT GRANTED", 2.0)
        end
    end

    Effects.update(dt)

    if GAME.state == "play" then
        updatePlay(dt)
        Particles.update(dt)
    elseif GAME.state == "revive_prompt" then
        GAME.reviveTimer = GAME.reviveTimer - dt
        if GAME.reviveTimer <= 0 then
            local run = GAME.run
            if run then
                Profile.recordRun(run.modeId, run.score, run.wave, run.scrapEarned, run.coresEarned)
                GAME.lastDeath = { score = run.score, wave = run.wave, scrap = run.scrapEarned, cores = run.coresEarned }
            end
            Portal.commercialBreak()
            GAME.state = "gameover"
        end
    elseif GAME.state ~= "play" then
        Particles.update(dt)
    end

    if GAME.background then
        local hasBoss = false
        if Enemy and Enemy.list then
            for _, e in ipairs(Enemy.list) do
                if e.alive and e.boss then
                    hasBoss = true
                    break
                end
            end
        end
        GAME.background:setBossMode(hasBoss)
        GAME.background:update(dt)
    end

    GAME.starOffset = (GAME.starOffset + dt * 26) % love.graphics.getHeight()
end

-- ============================================================
-- Rendering
-- ============================================================

local function drawStars()
    if GAME.background then
        GAME.background:draw()
    else
        local H = math.max(360, love.graphics.getHeight() or 720)
        local bgImg = Assets.get("bg")
        if bgImg then
            love.graphics.setColor(1, 1, 1, 0.45)
            love.graphics.draw(bgImg, 0, 0, 0, (love.graphics.getWidth() or 1280) / bgImg:getWidth(), H / bgImg:getHeight())
        end

        for _, s in ipairs(GAME.stars) do
            local y = (s.y + (GAME.starOffset or 0) * (s.z or 1)) % H
            love.graphics.setColor(1, 1, 1, 0.15 + (s.z or 1) * 0.6)
            love.graphics.circle("fill", s.x, y, (s.z or 1) * 1.6)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function drawPlayScene()
    local ox, oy = Effects.getShakeOffset()
    love.graphics.push()
    love.graphics.translate(ox, oy)
    drawStars()
    Enemy.draw()
    Boss.draw()
    Bullet.draw()
    if GAME.player then GAME.player:draw() end
    Drone.draw()
    Powerup.draw()
    Particles.draw()
    Effects.drawDamageNumbers(Assets.fonts.small)
    AIDebug.draw(Enemy.list, GAME.player)
    love.graphics.pop()
end

local function isHover(x, y, w, h)
    local mx, my = love.mouse.getPosition()
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Top-Bar Component across Menus and Hangar
local function drawTopBar(showBack, backTitle)
    local W = love.graphics.getWidth()

    -- 1. Left side: Back button or Player Profile Card
    if showBack then
        local bHover = isHover(30, 20, 48, 40)
        UI.drawButton(30, 20, 48, 40, "<", "icon", bHover, "back")
        love.graphics.setFont(Assets.fonts.large)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(backTitle or "BACK", 92, 26)
    else
        local xpFrac = (Profile.data.playerXp or 0) / math.max(100, (Profile.data.playerLevel or 1) * 500)
        UI.drawPlayerCard("Player001", Profile.data.playerLevel or 1, xpFrac, 30, 18, isHover(30, 18, 210, 48))
    end

    -- 2. Right side: Scrap Pill, Core Pill, Settings Button
    local scrapHover = isHover(W - 410 + 135 - 32, 26, 26, 26)
    UI.drawCurrencyPill("scrap", Profile.data.scrap or 0, W - 410, 22, scrapHover)

    local coreHover = isHover(W - 260 + 135 - 32, 26, 26, 26)
    UI.drawCurrencyPill("core", Profile.data.cores or 0, W - 260, 22, coreHover)

    local gearHover = isHover(W - 70, 22, 42, 38)
    UI.drawButton(W - 70, 22, 42, 38, "", "icon", gearHover, "gear")
end

local function drawHUD()
    local p, run = GAME.player, GAME.run
    if not p or not run then return end

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- 1. Top-Left Combat Telemetry Panel
    UI.drawPanel(18, 16, 215, 96, { cut = 10 })
    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SCORE " .. run.score, 32, 24)

    love.graphics.setColor(1.0, 0.85, 0.2, 1)
    love.graphics.print("SCRAP +" .. run.scrapEarned, 32, 48)

    local modeDef = Modes.get(run.modeId)
    local waveText = modeDef.name .. "  WAVE " .. run.wave .. (modeDef.maxWaves == math.huge and "" or ("/" .. modeDef.maxWaves))
    love.graphics.setColor(modeDef.color[1], modeDef.color[2], modeDef.color[3], 1)
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.print(waveText, 32, 74)

    if run.combo > 1.05 then
        love.graphics.setColor(1, 0.85, 0.25, 1)
        love.graphics.print(string.format("COMBO x%.2f", run.combo), 138, 48)
    end

    -- 2. Top-Right Hull HP & Tactical Special Meter Panel
    UI.drawPanel(W - 245, 16, 228, 96, { cut = 10 })

    -- Hull HP Segmented Armor Cells
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.5, 0.8, 1.0, 1)
    love.graphics.print("HULL INTEGRITY", W - 230, 24)

    local cellW = (200 - (p.maxLives - 1) * 3) / math.max(1, p.maxLives)
    for i = 1, p.maxLives do
        local cx = (W - 230) + (i - 1) * (cellW + 3)
        if i <= p.lives then
            love.graphics.setColor(0.2, 0.85, 1.0, 0.95)
            love.graphics.rectangle("fill", cx, 42, cellW, 12, 2)
            love.graphics.setColor(0.5, 1.0, 1.0, 1)
            love.graphics.rectangle("line", cx, 42, cellW, 12, 2)
        else
            love.graphics.setColor(0.2, 0.08, 0.12, 0.7)
            love.graphics.rectangle("fill", cx, 42, cellW, 12, 2)
            love.graphics.setColor(0.6, 0.15, 0.2, 0.5)
            love.graphics.rectangle("line", cx, 42, cellW, 12, 2)
        end
    end

    -- Special Ability Gauge
    local specialReady = (p.specialCooldown <= 0)
    local specFrac = specialReady and 1.0 or (1.0 - p.specialCooldown / p.chassis.specialCd)
    love.graphics.setColor(0.08, 0.16, 0.28, 0.9)
    love.graphics.rectangle("fill", W - 230, 64, 200, 18, 4)
    love.graphics.setColor(specialReady and { 0.2, 0.9, 1.0, 1.0 } or { 0.8, 0.4, 0.15, 0.9 })
    love.graphics.rectangle("fill", W - 230, 64, 200 * specFrac, 18, 4)
    love.graphics.setColor(specialReady and { 0.5, 1.0, 1.0, 1.0 } or { 0.9, 0.6, 0.3, 0.7 })
    love.graphics.rectangle("line", W - 230, 64, 200, 18, 4)

    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    if specialReady then
        love.graphics.print("[R-CLICK] " .. p.chassis.specialName, W - 222, 66)
    else
        love.graphics.print(string.format("CHARGING (%.1fs)", p.specialCooldown), W - 222, 66)
    end

    -- 3. Bottom XP Level Bar
    local needed = XP.xpForLevel(run.level)
    local frac = math.min(1, run.xp / needed)
    local barW = 340
    local barX = (W - barW) / 2
    local barY = H - 30

    UI.drawPanel(barX - 10, barY - 6, barW + 80, 26, { cut = 6 })
    love.graphics.setColor(0.06, 0.12, 0.22, 0.95)
    love.graphics.rectangle("fill", barX, barY, barW, 14, 3)
    love.graphics.setColor(0.2, 0.75, 1.0, 1.0)
    love.graphics.rectangle("fill", barX, barY, barW * frac, 14, 3)
    love.graphics.setColor(0.4, 0.9, 1.0, 0.8)
    love.graphics.rectangle("line", barX, barY, barW, 14, 3)

    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("LV " .. run.level, barX + barW + 10, barY - 1)

    -- 4. Active Weapon & Evolution Status
    local activeW = Weapons.getActiveDef(p.weaponIndex, run, p.upgrades)
    love.graphics.setFont(Assets.fonts.medium)
    if activeW.isEvolved then
        love.graphics.setColor(1.0, 0.85, 0.2, 1)
        love.graphics.print("[SUPER] " .. activeW.name, W - 320, H - 32)
    else
        love.graphics.setColor(0.7, 0.9, 1.0, 1)
        love.graphics.print("WEAPON HEAT", W - 225, 65)
    end
    UI.drawStatBar("", (run.weaponHeat or 0)/100, 5, W - 225, 90, 200, {1.0, 0.3, 0.1})

    -- 3. HUD Controls: Pause & Weapon Cycle
    local pauseHover = isHover(W - 65, 120, 45, 45)
    UI.drawButton(W - 65, 120, 45, 45, "||", "blue", pauseHover)

    local cycleHover = isHover(W - 245, 120, 165, 45)
    local activeWName = Weapons.getActiveDef(p.weaponIndex, run, p.upgrades).name
    UI.drawButton(W - 245, 120, 165, 45, "CYCLE WPN", "icon", cycleHover)
    
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.5, 0.9, 1.0, 0.8)
    love.graphics.print("Active: " .. activeWName, W - 240, 175)

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Menus & Modals
-- ============================================================

local function drawMenu()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    drawTopBar(false)

    -- Floating Glowing Purple Planet Orb (Top of title)
    local cx, cy = W/2, H * 0.18
    love.graphics.setColor(0.55, 0.25, 0.95, 0.35 + 0.15 * math.sin(love.timer.getTime() * 3))
    love.graphics.circle("fill", cx, cy, 32)

    local orbImg = Assets.get("planet02") or Assets.get("planet00")
    if orbImg then
        love.graphics.setColor(0.85, 0.60, 1.0, 1.0)
        love.graphics.draw(orbImg, cx, cy, love.timer.getTime() * 0.25, 54 / orbImg:getWidth(), 54 / orbImg:getHeight(), orbImg:getWidth()/2, orbImg:getHeight()/2)
    end
    love.graphics.setColor(0.4, 0.8, 1.0, 0.9)
    love.graphics.circle("line", cx, cy, 27)

    -- Stylized "STARFALL VENGEANCE" Title Logo
    love.graphics.setFont(Assets.fonts.huge)
    local title = "STARFALL VENGEANCE"
    local tw = Assets.fonts.huge:getWidth(title)
    local tx = (W - tw) / 2
    local ty = H * 0.22

    -- Drop shadow
    love.graphics.setColor(0.01, 0.03, 0.08, 0.95)
    love.graphics.print(title, tx + 4, ty + 4)

    -- Chrome blue / cyan title
    love.graphics.setColor(0.45, 0.85, 1.0, 1.0)
    love.graphics.print(title, tx, ty)

    -- Metallic gold accent underline
    love.graphics.setColor(1.0, 0.75, 0.2, 0.95)
    love.graphics.rectangle("fill", tx + 30, ty + 64, tw - 60, 4, 2)
    love.graphics.setColor(1.0, 0.95, 0.6, 1.0)
    love.graphics.rectangle("fill", tx + tw/2 - 20, ty + 63, 40, 6, 2)

    -- Menu Buttons
    local bLaunchHover = isHover(W/2 - 190, H * 0.43, 380, 60)
    UI.drawButton(W/2 - 190, H * 0.43, 380, 60, "LAUNCH MISSION", "gold", bLaunchHover, "play")

    local bHangarHover = isHover(W/2 - 160, H * 0.43 + 76, 320, 50)
    UI.drawButton(W/2 - 160, H * 0.43 + 76, 320, 50, "HANGAR", "blue", bHangarHover, "rocket")

    local bTechHover = isHover(W/2 - 160, H * 0.43 + 138, 320, 50)
    UI.drawButton(W/2 - 160, H * 0.43 + 138, 320, 50, "TECH TREE", "blue", bTechHover, "tech")

    -- Bottom Bar: Trophy, Stats, Help
    local bTrophyHover = isHover(40, H - 68, 50, 46)
    UI.drawButton(40, H - 68, 50, 46, "", "icon", bTrophyHover, "trophy")

    local bStatsHover = isHover(W - 120, H - 68, 50, 46)
    UI.drawButton(W - 120, H - 68, 50, 46, "", "icon", bStatsHover, "stats")

    local bHelpHover = isHover(W - 62, H - 68, 50, 46)
    UI.drawButton(W - 62, H - 68, 50, 46, "?", "icon", bHelpHover, "help")

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHangar()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    drawTopBar(true, "HANGAR")

    local sid = SHIP_LIST[GAME.hangarShipIndex] or "basic"
    local ch = Player.CHASSIS[sid] or Player.CHASSIS.basic

    -- 1. Center 3D Showcase Pedestal
    local pedX = W/2 - 80
    local pedY = H * 0.47
    UI.drawPedestal(pedX, pedY, 175, 52, love.timer.getTime())

    -- Floating Selected Ship on Pedestal
    local shipBob = math.sin(love.timer.getTime() * 2.8) * 8
    local shipY = pedY - 32 + shipBob
    local shipImg = Assets.get(ch.asset) or Assets.get("ship")

    -- Engine nozzle flame on pedestal
    local fireImg = Assets.get("fire")
    if fireImg then
        local flicker = 0.85 + 0.3 * math.sin(love.timer.getTime() * 28)
        love.graphics.setColor(1, 0.9, 0.7, 0.9)
        love.graphics.draw(fireImg, pedX, shipY + 46, -math.pi/2, (36/fireImg:getWidth()) * flicker, (46/fireImg:getHeight()) * flicker, fireImg:getWidth()/2, 0)
    end

    if shipImg then
        local targetSize = (sid == "solar" or sid == "titan") and 125 or 110
        local sx = targetSize / shipImg:getWidth()
        local sy = targetSize / shipImg:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(shipImg, pedX, shipY, -math.pi/2, sx, sy, shipImg:getWidth()/2, shipImg:getHeight()/2)
    end

    -- Carousel Arrow Buttons
    local leftArrowHover = isHover(pedX - 220, pedY - 26, 46, 46)
    UI.drawButton(pedX - 220, pedY - 26, 46, 46, "<", "icon", leftArrowHover, "back")

    local rightArrowHover = isHover(pedX + 174, pedY - 26, 46, 46)
    UI.drawButton(pedX + 174, pedY - 26, 46, 46, ">", "icon", rightArrowHover, "forward")

    -- 2. Right Stat Panel
    local panelW, panelH = 340, 260
    local panelX, panelY = W - panelW - 35, H * 0.22
    UI.drawPanel(panelX, panelY, panelW, panelH, { cut = 14 })

    local nameFont = Assets.fonts.large
    if nameFont:getWidth(ch.name) > (panelW - 36) then
        nameFont = Assets.fonts.medium
    end
    love.graphics.setFont(nameFont)
    love.graphics.setColor(ch.color[1], ch.color[2], ch.color[3], 1)
    love.graphics.print(ch.name, panelX + 18, panelY + 16)

    -- Stat Gauges
    UI.drawStatBar("SPEED", ch.stats.speed, 5, panelX + 18, panelY + 56, 160)
    UI.drawStatBar("FIRE RATE", ch.stats.fireRate, 5, panelX + 18, panelY + 90, 160)
    UI.drawStatBar("HEALTH", ch.stats.health, 5, panelX + 18, panelY + 124, 160)

    -- Special Ability info
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.35, 0.85, 1.0, 0.95)
    love.graphics.print("SPEC: " .. ch.specialName, panelX + 18, panelY + 158)

    -- Action Button
    local isEquipped = (Profile.data.selectedShip == sid)
    local isUnlocked = Profile.data.unlockedShips and Profile.data.unlockedShips[sid]
    local btnW = panelW - 36
    local btnH = 44
    local btnX = panelX + 18
    local btnY = panelY + panelH - btnH - 14
    local btnHover = isHover(btnX, btnY, btnW, btnH)

    if isEquipped then
        UI.drawButton(btnX, btnY, btnW, btnH, "EQUIPPED", "green", btnHover, "check")
    elseif isUnlocked then
        UI.drawButton(btnX, btnY, btnW, btnH, "SELECT", "blue", btnHover, "check")
    else
        local cost = Profile.SHIP_COSTS[sid] or 1000
        UI.drawButton(btnX, btnY, btnW, btnH, "UNLOCK " .. cost .. " SCRAP", "gold", btnHover, "cart")
    end

    -- 3. Bottom Ship Dock (6 Ship Cards)
    local dockX, dockY, dockW, dockH = 40, H - 150, W - 80, 132
    UI.drawPanel(dockX, dockY, dockW, dockH, { cut = 14 })

    local cardW = (dockW - 36 - 5 * 10) / 6
    local cardH = dockH - 24

    for i, shipId in ipairs(SHIP_LIST) do
        local sc = Player.CHASSIS[shipId]
        local cx = dockX + 18 + (i - 1) * (cardW + 10)
        local cy = dockY + 12
        local cardHover = isHover(cx, cy, cardW, cardH)
        local isSelected = (i == GAME.hangarShipIndex)
        local unlocked = Profile.data.unlockedShips and Profile.data.unlockedShips[shipId]
        local equipped = (Profile.data.selectedShip == shipId)

        -- Card Frame
        local cardFill = isSelected and { 0.12, 0.28, 0.55, 0.95 } or (cardHover and { 0.08, 0.18, 0.38, 0.9 } or { 0.04, 0.10, 0.22, 0.85 })
        love.graphics.setColor(cardFill[1], cardFill[2], cardFill[3], cardFill[4])
        love.graphics.rectangle("fill", cx, cy, cardW, cardH, 6)

        love.graphics.setColor(isSelected and { 0.35, 0.85, 1.0, 1.0 } or (cardHover and { 0.25, 0.65, 0.95, 0.8 } or { 0.15, 0.35, 0.65, 0.6 }))
        love.graphics.setLineWidth(isSelected and 2.5 or 1.5)
        love.graphics.rectangle("line", cx, cy, cardW, cardH, 6)
        love.graphics.setLineWidth(1)

        -- Ship Preview Icon
        local sImg = Assets.get(sc.asset) or Assets.get("ship")
        if sImg then
            local iconSz = 44
            local isx = iconSz / sImg:getWidth()
            local isy = iconSz / sImg:getHeight()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sImg, cx + cardW/2, cy + 34, -math.pi/2, isx, isy, sImg:getWidth()/2, sImg:getHeight()/2)
        end

        -- Ship Name Label
        love.graphics.setFont(Assets.fonts.small)
        love.graphics.setColor(1, 1, 1, 1)
        local nameShort = sc.name:gsub(" FIGHTER", ""):gsub(" SCOUT", ""):gsub(" TITAN", ""):gsub(" GHOST", ""):gsub(" CARRIER", ""):gsub(" REAPER", "")
        local nw = Assets.fonts.small:getWidth(nameShort)
        love.graphics.print(nameShort, cx + (cardW - nw)/2, cy + 62)

        -- Badge: Equipped Checkmark or Lock with cost
        if equipped then
            love.graphics.setColor(0.2, 0.9, 0.4, 1.0)
            love.graphics.circle("fill", cx + cardW/2, cy + 88, 11)
            UI.drawIcon("check", cx + cardW/2, cy + 88, 14, { 1, 1, 1, 1 })
        elseif unlocked then
            love.graphics.setFont(Assets.fonts.small)
            love.graphics.setColor(0.3, 0.75, 1.0, 1.0)
            love.graphics.print("READY", cx + (cardW - Assets.fonts.small:getWidth("READY"))/2, cy + 82)
        else
            local cost = Profile.SHIP_COSTS[shipId] or 1000
            local costStr = tostring(cost)
            love.graphics.setFont(Assets.fonts.small)
            local cw = Assets.fonts.small:getWidth(costStr)
            UI.drawIcon("lock", cx + cardW/2 - cw/2 - 8, cy + 89, 13, { 1.0, 0.75, 0.2, 1.0 })
            love.graphics.setColor(1.0, 0.75, 0.2, 1.0)
            love.graphics.print(costStr, cx + cardW/2 - cw/2 + 6, cy + 82)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawTechTree()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    drawTopBar(true, "TECH TREE")

    local colW = (W - 100) / 2
    local col1X = 40
    local col2X = col1X + colW + 20
    local startY = 82
    local cardH = 92
    local cardGap = 12

    for i, tech in ipairs(Profile.TECH_TREE) do
        local col = (i <= 4) and 1 or 2
        local row = (i <= 4) and i or (i - 4)
        local cx = (col == 1) and col1X or col2X
        local cy = startY + (row - 1) * (cardH + cardGap)

        local isFocus = (i == GAME.hangarTechIndex)
        local curLvl = Profile.data.upgrades[tech.id] or 0
        local cost = Profile.getTechCost(tech)
        local canBuy = cost and ((Profile.data.scrap or 0) >= cost)

        local cardHover = isHover(cx, cy, colW, cardH)
        UI.drawPanel(cx, cy, colW, cardH, { cut = 10, borderColor = isFocus and { 0.4, 0.9, 1.0, 1.0 } or { 0.18, 0.45, 0.85, 0.75 } })

        -- Tech Node Icon
        UI.drawIcon("tech", cx + 22, cy + 24, 22, isFocus and { 0.4, 0.95, 1.0, 1 } or { 0.25, 0.65, 0.95, 0.85 })

        -- Tech Title
        love.graphics.setFont(Assets.fonts.medium)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tech.name, cx + 46, cy + 14)

        -- Level Pips / Text
        love.graphics.setFont(Assets.fonts.small)
        love.graphics.setColor(0.35, 0.85, 1.0, 1)
        love.graphics.print("LEVEL " .. curLvl .. " / " .. tech.max, cx + 46, cy + 39)

        -- Description
        love.graphics.setColor(0.75, 0.88, 1.0, 0.9)
        love.graphics.print(tech.desc, cx + 46, cy + 61)

        -- Buy Button
        local btnW = math.min(145, colW * 0.35)
        local btnH = 38
        local btnX = cx + colW - btnW - 14
        local btnY = cy + (cardH - btnH) / 2
        local btnHover = isHover(btnX, btnY, btnW, btnH)

        if cost then
            local btnStyle = canBuy and "gold" or "blue"
            UI.drawButton(btnX, btnY, btnW, btnH, "BUY " .. cost, btnStyle, btnHover, "cart")
        else
            UI.drawButton(btnX, btnY, btnW, btnH, "MAXED", "green", btnHover, "check")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Settings Modal matching Image 3
local function drawSettingsModal()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local s = Profile.data.settings or {}

    -- Modal background dimming
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Centered Sci-Fi Panel
    local modalW, modalH = 560, 410
    local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
    UI.drawPanel(modalX, modalY, modalW, modalH, { cut = 16 })

    -- Header
    local backHover = isHover(modalX + 20, modalY + 18, 44, 38)
    UI.drawButton(modalX + 20, modalY + 18, 44, 38, "<", "icon", backHover, "back")

    love.graphics.setFont(Assets.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SETTINGS", modalX + 78, modalY + 24)

    -- Row 1: MUSIC
    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    UI.drawIcon("music", modalX + 54, modalY + 107, 22, { 0.4, 0.85, 1.0, 1.0 })
    love.graphics.print("MUSIC", modalX + 76, modalY + 97)
    UI.drawSlider(modalX + 225, modalY + 107, 160, s.musicVolume or 0.8, isHover(modalX + 225, modalY + 100, 160, 14))
    UI.drawToggle(modalX + 430, modalY + 92, s.musicEnabled ~= false, isHover(modalX + 430, modalY + 92, 64, 30))

    -- Row 2: SOUND EFFECTS
    love.graphics.setColor(1, 1, 1, 1)
    UI.drawIcon("sound", modalX + 54, modalY + 172, 22, { 0.4, 0.85, 1.0, 1.0 })
    love.graphics.print("SOUND EFFECTS", modalX + 76, modalY + 162)
    UI.drawSlider(modalX + 225, modalY + 172, 160, s.sfxVolume or 1.0, isHover(modalX + 225, modalY + 165, 160, 14))
    UI.drawToggle(modalX + 430, modalY + 157, s.sfxEnabled ~= false, isHover(modalX + 430, modalY + 157, 64, 30))

    -- Row 3: FULLSCREEN
    love.graphics.setColor(1, 1, 1, 1)
    UI.drawIcon("monitor", modalX + 54, modalY + 237, 22, { 0.4, 0.85, 1.0, 1.0 })
    love.graphics.print("FULLSCREEN", modalX + 76, modalY + 227)
    UI.drawToggle(modalX + 430, modalY + 222, s.fullscreen == true, isHover(modalX + 430, modalY + 222, 64, 30))

    -- Row 4: SHOW FPS
    love.graphics.setColor(1, 1, 1, 1)
    UI.drawIcon("gear", modalX + 54, modalY + 297, 22, { 0.4, 0.85, 1.0, 1.0 })
    love.graphics.print("SHOW FPS", modalX + 76, modalY + 287)
    UI.drawToggle(modalX + 430, modalY + 282, s.showFps == true, isHover(modalX + 430, modalY + 282, 64, 30))

    -- Footer APPLY Button
    local applyHover = isHover(modalX + 180, modalY + 345, 200, 46)
    UI.drawButton(modalX + 180, modalY + 345, 200, 46, "APPLY", "blue", applyHover, "check")

    love.graphics.setColor(1, 1, 1, 1)
end

-- Pilot Profile Modal
local function drawProfileModal()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local modalW, modalH = 520, 360
    local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
    UI.drawPanel(modalX, modalY, modalW, modalH, { cut = 16 })

    local backHover = isHover(modalX + 20, modalY + 18, 44, 38)
    UI.drawButton(modalX + 20, modalY + 18, 44, 38, "<", "icon", backHover, "back")

    love.graphics.setFont(Assets.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("PILOT DOSSIER", modalX + 78, modalY + 24)

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(0.4, 0.85, 1.0, 1)
    love.graphics.print("CALLSIGN: Player001", modalX + 50, modalY + 90)
    love.graphics.print("PILOT RANK: Commander (Level " .. (Profile.data.playerLevel or 1) .. ")", modalX + 50, modalY + 125)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("COMBAT MISSIONS FLOWN: " .. (Profile.data.totalGames or 0), modalX + 50, modalY + 165)
    love.graphics.print("LIFETIME ENEMY SCORE: " .. (Profile.data.totalScore or 0), modalX + 50, modalY + 200)
    love.graphics.print("TOTAL STAR MEDALS: " .. (Profile.data.totalStars or 0), modalX + 50, modalY + 235)

    local closeHover = isHover(modalX + 160, modalY + 295, 200, 44)
    UI.drawButton(modalX + 160, modalY + 295, 200, 44, "CONFIRM", "blue", closeHover, "check")
    love.graphics.setColor(1, 1, 1, 1)
end

-- Stats / Leaderboard Records Modal
local function drawStatsModal()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local modalW, modalH = 560, 390
    local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
    UI.drawPanel(modalX, modalY, modalW, modalH, { cut = 16 })

    local backHover = isHover(modalX + 20, modalY + 18, 44, 38)
    UI.drawButton(modalX + 20, modalY + 18, 44, 38, "<", "icon", backHover, "back")

    love.graphics.setFont(Assets.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("MISSION RECORDS", modalX + 78, modalY + 24)

    local bs = Profile.data.bestScore or {}
    local bw = Profile.data.bestWave or {}

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(0.3, 0.9, 1.0, 1)
    love.graphics.print("CAMPAIGN MODE", modalX + 50, modalY + 90)
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Highest Wave Reached: " .. (bw.campaign or 1) .. "   |   Personal Best Score: " .. (bs.campaign or 0), modalX + 50, modalY + 115)

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(1.0, 0.75, 0.2, 1)
    love.graphics.print("ENDLESS PROTOCOL", modalX + 50, modalY + 155)
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Highest Wave Reached: " .. (bw.endless or 1) .. "   |   Personal Best Score: " .. (bs.endless or 0), modalX + 50, modalY + 180)

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(0.9, 0.35, 1.0, 1)
    love.graphics.print("GAUNTLET BOSS TRIALS", modalX + 50, modalY + 220)
    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Trials Cleared: " .. (bw.gauntlet or 0) .. " / 8   |   Personal Best Score: " .. (bs.gauntlet or 0), modalX + 50, modalY + 245)

    local closeHover = isHover(modalX + 180, modalY + 315, 200, 44)
    UI.drawButton(modalX + 180, modalY + 315, 200, 44, "CLOSE", "blue", closeHover, "check")
    love.graphics.setColor(1, 1, 1, 1)
end

-- Help / Flight Academy Guide Modal
local function drawHelpModal()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local modalW, modalH = 580, 420
    local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
    UI.drawPanel(modalX, modalY, modalW, modalH, { cut = 16 })

    local backHover = isHover(modalX + 20, modalY + 18, 44, 38)
    UI.drawButton(modalX + 20, modalY + 18, 44, 38, "<", "icon", backHover, "back")

    love.graphics.setFont(Assets.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FLIGHT ACADEMY", modalX + 78, modalY + 24)

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(0.3, 0.9, 1.0, 1)
    love.graphics.print("COMBAT FLIGHT CONTROLS", modalX + 46, modalY + 80)

    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("> W, A, S, D or Arrows: Thruster navigation", modalX + 46, modalY + 110)
    love.graphics.print("> Mouse Cursor: Aim targeting reticle", modalX + 46, modalY + 132)
    love.graphics.print("> Left Mouse Button / Space: Fire primary energy battery", modalX + 46, modalY + 154)
    love.graphics.print("> Spacebar: Tactical high-speed dash (invulnerability frames)", modalX + 46, modalY + 176)
    love.graphics.print("> Right Mouse Button or E / Shift: Deploy ship special ability", modalX + 46, modalY + 198)

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(1.0, 0.85, 0.25, 1)
    love.graphics.print("SUPER WEAPON EVOLUTIONS", modalX + 46, modalY + 235)

    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.8, 0.9, 1.0, 1)
    love.graphics.print("> Pulse Cannon Lv 5 + Homing Synergy -> Swarm Barrage Matrix", modalX + 46, modalY + 265)
    love.graphics.print("> Scatter Flak Lv 5 + 2 Drones -> Arc-Chain Tempest Lightning", modalX + 46, modalY + 287)
    love.graphics.print("> Vulcan Gatling Lv 5 + Overcharge -> Hyper-Nova Disintegrator", modalX + 46, modalY + 309)
    love.graphics.print("> Mag Railgun Lv 5 + Vortex -> Vortex Rail-Cannon Graviton", modalX + 46, modalY + 331)

    local closeHover = isHover(modalX + 190, modalY + 360, 200, 42)
    UI.drawButton(modalX + 190, modalY + 360, 200, 42, "DISMISS", "blue", closeHover, "check")
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawModeSelect()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    drawTopBar(true, "SELECT MISSION")

    local modes = Modes.all()
    local cardH = 92
    local cardGap = 16
    local startY = 88

    for i, m in ipairs(modes) do
        local y = startY + (i - 1) * (cardH + cardGap)
        local selected = (i == GAME.menuIndex)
        local col = m.color

        local rowHover = isHover(60, y, W - 120, cardH)
        UI.drawPanel(60, y, W - 120, cardH, {
            cut = 12,
            borderColor = selected and { 0.4, 0.95, 1.0, 1.0 } or (rowHover and { col[1], col[2], col[3], 0.85 } or { col[1], col[2], col[3], 0.5 })
        })

        if selected then
            UI.drawIcon(">", 84, y + cardH/2, 16, { col[1], col[2], col[3], 1 })
        end

        love.graphics.setFont(Assets.fonts.large)
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.print(m.name, 108, y + 16)

        love.graphics.setFont(Assets.fonts.small)
        love.graphics.setColor(0.8, 0.88, 0.98, 0.95)
        love.graphics.print(m.subtitle, 108, y + 52)
    end

    love.graphics.setColor(0.5, 0.7, 0.9, 0.8)
    love.graphics.setFont(Assets.fonts.small)
    local hint = "UP/DOWN or TAP to select, ENTER to launch, ESC to return to menu"
    love.graphics.print(hint, (W - Assets.fonts.small:getWidth(hint))/2, H - 32)
end

local function drawUpgrade()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(Assets.fonts.huge)
    love.graphics.setColor(1, 0.85, 0.25, 1)
    local t = "SYSTEM UPGRADE"
    love.graphics.print(t, (W - Assets.fonts.huge:getWidth(t))/2, 80)

    love.graphics.setFont(Assets.fonts.medium)
    if GAME.upgradeChoices then
        for i, up in ipairs(GAME.upgradeChoices) do
            local y = 200 + (i - 1) * 110
            local selected = (i == GAME.upgradeIndex)
            local cardHover = isHover(W/2 - 280, y, 560, 85)

            UI.drawPanel(W/2 - 280, y, 560, 85, {
                cut = 10,
                borderColor = (up.category == "synergy") and { 1.0, 0.8, 0.2, 1.0 } or (selected and { 0.4, 0.9, 1.0, 1.0 } or { 0.2, 0.5, 0.8, 0.7 })
            })

            love.graphics.setFont(Assets.fonts.large)
            love.graphics.setColor(up.category == "synergy" and {1, 0.85, 0.2, 1} or {1, 1, 1, 1})
            love.graphics.print((selected and "> " or "  ") .. up.name, W/2 - 250, y + 26)
        end
    end

    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.8, 0.8, 0.9, 1)
    local hint = "UP/DOWN or TAP to choose, ENTER to confirm"
    love.graphics.print(hint, (W - Assets.fonts.small:getWidth(hint))/2, H - 70)
end

local function drawRevivePrompt()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(Assets.fonts.huge)
    love.graphics.setColor(1, 0.25, 0.4, 1)
    local title = "CRITICAL DAMAGE DETECTED"
    love.graphics.print(title, (W - Assets.fonts.huge:getWidth(title))/2, H * 0.22)

    local revBtn = string.format("WATCH AD TO REVIVE (%.1fs)", math.max(0, GAME.reviveTimer))
    local revHover = isHover(W/2 - 220, H * 0.44, 440, 64)
    UI.drawButton(W/2 - 220, H * 0.44, 440, 64, revBtn, "gold", revHover, "play")

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    local skipText = "PRESS ESC OR TAP TO GIVE UP"
    love.graphics.print(skipText, (W - Assets.fonts.medium:getWidth(skipText))/2, H * 0.62)
end

local function drawGameOver()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(Assets.fonts.huge)
    love.graphics.setColor(1, 0.35, 0.45, 1)
    local t = "MISSION TERMINATED"
    love.graphics.print(t, (W - Assets.fonts.huge:getWidth(t))/2, H * 0.18)

    if GAME.lastDeath then
        love.graphics.setFont(Assets.fonts.large)
        love.graphics.setColor(1, 1, 1, 1)
        local s = "SCORE  " .. GAME.lastDeath.score
        love.graphics.print(s, (W - Assets.fonts.large:getWidth(s))/2, H * 0.32)

        local w = "WAVE REACHED  " .. GAME.lastDeath.wave
        love.graphics.print(w, (W - Assets.fonts.large:getWidth(w))/2, H * 0.39)

        love.graphics.setColor(1.0, 0.85, 0.2, 1)
        local sc = "SCRAP EARNED  +" .. GAME.lastDeath.scrap .. (GAME.lastDeath.cores > 0 and ("  |  CORES +" .. GAME.lastDeath.cores) or "")
        love.graphics.print(sc, (W - Assets.fonts.large:getWidth(sc))/2, H * 0.47)
    end

    -- 2x Scrap Rewarded Ad Button
    if not GAME.hasDoubledScrap then
        local dblHover = isHover(W/2 - 180, H * 0.58, 360, 50)
        UI.drawButton(W/2 - 180, H * 0.58, 360, 50, "WATCH AD: 2X SCRAP!", "gold", dblHover, "video")
    else
        love.graphics.setFont(Assets.fonts.medium)
        love.graphics.setColor(0.3, 1.0, 0.5, 1)
        local done = "SCRAP DOUBLED (2X BONUS APPLIED)"
        love.graphics.print(done, (W - Assets.fonts.medium:getWidth(done))/2, H * 0.60)
    end

    love.graphics.setFont(Assets.fonts.small)
    love.graphics.setColor(0.7, 0.9, 1, 1)
    local prompt = "PRESS ENTER OR TAP TO RETURN TO HANGAR"
    love.graphics.print(prompt, (W - Assets.fonts.small:getWidth(prompt))/2, H * 0.78)
end

local function drawPaused()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(Assets.fonts.huge)
    love.graphics.setColor(1, 1, 1, 1)
    local t = "TACTICAL PAUSE"
    love.graphics.print(t, (W - Assets.fonts.huge:getWidth(t))/2, H * 0.25)

    local btnW, btnH = 240, 50
    local startY = H * 0.45
    
    local resumeHover = isHover(W/2 - btnW/2, startY, btnW, btnH)
    UI.drawButton(W/2 - btnW/2, startY, btnW, btnH, "RESUME", "blue", resumeHover)

    local settingsHover = isHover(W/2 - btnW/2, startY + 70, btnW, btnH)
    UI.drawButton(W/2 - btnW/2, startY + 70, btnW, btnH, "SETTINGS", "blue", settingsHover)

    local quitHover = isHover(W/2 - btnW/2, startY + 140, btnW, btnH)
    UI.drawButton(W/2 - btnW/2, startY + 140, btnW, btnH, "QUIT TO HOME", "red", quitHover)
end

local function drawAdPromptModal()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local modalW, modalH = 460, 260
    local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
    UI.drawPanel(modalX, modalY, modalW, modalH, { cut = 16 })

    love.graphics.setFont(Assets.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("INCOMING TRANSMISSION", modalX + 45, modalY + 30)

    love.graphics.setFont(Assets.fonts.medium)
    love.graphics.setColor(0.7, 0.9, 1.0, 1)
    love.graphics.print("Establish Commlink (Watch Ad)", modalX + 60, modalY + 90)
    love.graphics.print("to receive this supply drop?", modalX + 75, modalY + 120)

    local watchHover = isHover(modalX + 40, modalY + 180, 160, 44)
    UI.drawButton(modalX + 40, modalY + 180, 160, 44, "WATCH", "green", watchHover, "video")

    local cancelHover = isHover(modalX + 260, modalY + 180, 160, 44)
    UI.drawButton(modalX + 260, modalY + 180, 160, 44, "CANCEL", "red", cancelHover)
end

local _starfallDiagDrawLogged = false
local _starfallDiagFirstFrameLogged = false
function love.draw()
    if not _starfallDiagDrawLogged then
        _starfallDiagDrawLogged = true
        print("[STARFALL] love.draw running")
    end
    love.graphics.clear(0.012, 0.02, 0.05)

    if GAME.state == "menu" then
        drawStars()
        drawMenu()
    elseif GAME.state == "hangar" then
        drawStars()
        drawHangar()
    elseif GAME.state == "techtree" then
        drawStars()
        drawTechTree()
    elseif GAME.state == "modeselect" then
        drawStars()
        drawModeSelect()
    elseif GAME.state == "play" then
        drawPlayScene()
        Effects.drawOverlay()
        Effects.drawBanner(Assets.fonts.huge, Assets.fonts.medium)
        drawHUD()
        Touch.draw()
    elseif GAME.state == "paused" then
        drawPlayScene()
        Effects.drawOverlay()
        drawHUD()
        drawPaused()
        if GAME.activeModal == "settings" then
            drawSettingsModal()
        end
    elseif GAME.state == "upgrade" then
        drawPlayScene()
        drawHUD()
        drawUpgrade()
    elseif GAME.state == "revive_prompt" then
        drawPlayScene()
        Effects.drawOverlay()
        drawRevivePrompt()
        Touch.draw()
    elseif GAME.state == "gameover" then
        drawPlayScene()
        Effects.drawOverlay()
        drawGameOver()
    end

    if GAME.activeModal == "ad_prompt" then
        drawAdPromptModal()
    end

    -- Active Modals
    if GAME.activeModal == "settings" then
        drawSettingsModal()
    elseif GAME.activeModal == "profile" then
        drawProfileModal()
    elseif GAME.activeModal == "stats" then
        drawStatsModal()
    elseif GAME.activeModal == "help" then
        drawHelpModal()
    end

    -- FPS Counter Overlay
    if Profile.data.settings and Profile.data.settings.showFps then
        love.graphics.setFont(Assets.fonts.small)
        love.graphics.setColor(0.3, 1.0, 0.5, 0.9)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 16, love.graphics.getHeight() - 24)
    end

    love.graphics.setColor(1, 1, 1, 1)

    if not _starfallDiagFirstFrameLogged then
        _starfallDiagFirstFrameLogged = true
        print("[STARFALL] first frame rendered")
        print("[PORTAL]:firstFrameRendered:")
    end
end

-- ============================================================
-- Input Handling
-- ============================================================

function love.keypressed(key)
    -- Developer AI & Boss Debug Telemetry Toggle
    if key == "f3" then
        AIDebug.toggle()
        return
    end

    -- 1. Modals Intercept Keyboard Input
    if GAME.activeModal then
        if key == "escape" or key == "return" or key == "space" then
            GAME.activeModal = nil
            Sound.play("dash", 0.6)
            return
        end
        return
    end

    if GAME.state == "menu" then
        if key == "up" then
            GAME.menuIndex = math.max(1, GAME.menuIndex - 1)
            Sound.play("dash", 0.6)
        elseif key == "down" then
            GAME.menuIndex = math.min(3, GAME.menuIndex + 1)
            Sound.play("dash", 0.6)
        elseif key == "return" or key == "space" then
            if GAME.menuIndex == 1 then
                GAME.state = "modeselect"
                GAME.menuIndex = 1
                Sound.play("powerup", 1.0)
            elseif GAME.menuIndex == 2 then
                GAME.state = "hangar"
                GAME.hangarShipIndex = 1
                Sound.play("dash", 0.8)
            else
                GAME.state = "techtree"
                GAME.hangarTechIndex = 1
                Sound.play("dash", 0.8)
            end
        end
    elseif GAME.state == "hangar" then
        if key == "left" or key == "a" or key == "up" then
            GAME.hangarShipIndex = (GAME.hangarShipIndex - 2) % #SHIP_LIST + 1
            Sound.play("dash", 0.7)
        elseif key == "right" or key == "d" or key == "down" then
            GAME.hangarShipIndex = (GAME.hangarShipIndex % #SHIP_LIST) + 1
            Sound.play("dash", 0.7)
        elseif key == "return" or key == "space" then
            local sid = SHIP_LIST[GAME.hangarShipIndex]
            if Profile.data.unlockedShips and Profile.data.unlockedShips[sid] then
                Profile.selectShip(sid)
                Sound.play("powerup", 1.2)
            else
                local cost = Profile.SHIP_COSTS[sid] or 1000
                if (Profile.data.scrap or 0) >= cost then
                    Profile.unlockShip(sid)
                    Sound.play("levelup", 1.2)
                    Effects.flash(0.3, 0.9, 1.0, 0.4, 0.4)
                else
                    Sound.play("playerhit", 0.8)
                end
            end
        elseif key == "escape" then
            GAME.state = "menu"
            GAME.menuIndex = 1
            Sound.play("dash", 0.6)
        end
    elseif GAME.state == "techtree" then
        if key == "up" or key == "w" then
            GAME.hangarTechIndex = math.max(1, GAME.hangarTechIndex - 1)
            Sound.play("dash", 0.6)
        elseif key == "down" or key == "s" then
            GAME.hangarTechIndex = math.min(#Profile.TECH_TREE, GAME.hangarTechIndex + 1)
            Sound.play("dash", 0.6)
        elseif key == "return" or key == "space" then
            local tech = Profile.TECH_TREE[GAME.hangarTechIndex]
            if tech then
                local cost = Profile.getTechCost(tech)
                if cost and (Profile.data.scrap or 0) >= cost then
                    Profile.buyTech(tech.id)
                    Sound.play("levelup", 1.2)
                    Effects.flash(0.3, 0.9, 1.0, 0.3, 0.3)
                else
                    Sound.play("playerhit", 0.8)
                end
            end
        elseif key == "escape" then
            GAME.state = "menu"
            GAME.menuIndex = 1
            Sound.play("dash", 0.6)
        end
    elseif GAME.state == "modeselect" then
        if key == "up" or key == "w" then
            GAME.menuIndex = math.max(1, GAME.menuIndex - 1)
            Sound.play("dash", 0.6)
        elseif key == "down" or key == "s" then
            GAME.menuIndex = math.min(3, GAME.menuIndex + 1)
            Sound.play("dash", 0.6)
        elseif key == "return" or key == "space" then
            local m = Modes.all()[GAME.menuIndex]
            startRun(m.id)
            beginWave()
        elseif key == "escape" then
            GAME.state = "menu"
            Sound.play("dash", 0.6)
        end
    elseif GAME.state == "play" then
        if key == "escape" then
            GAME.state = "paused"
            Portal.gameplayStop()
        elseif key == "1" and GAME.player then GAME.player.weaponIndex = 1
        elseif key == "2" and GAME.player then GAME.player.weaponIndex = 2
        elseif key == "3" and GAME.player then GAME.player.weaponIndex = 3
        elseif key == "4" and GAME.player then GAME.player.weaponIndex = 4
        elseif key == "5" and GAME.player then GAME.player.weaponIndex = 5
        elseif key == "6" and GAME.player then GAME.player.weaponIndex = 6
        elseif key == "7" and GAME.player then GAME.player.weaponIndex = 7
        elseif key == "e" or key == "lshift" or key == "rshift" then
            if GAME.player then GAME.player:triggerSpecial(Enemy, Bullet) end
        elseif key == "space" and GAME.player then
            local mx, my = GAME.input.moveX, GAME.input.moveY
            if mx == 0 and my == 0 then
                mx = GAME.input.aimX - GAME.player.x
                my = GAME.input.aimY - GAME.player.y
            end
            GAME.player:tryDash(mx, my)
        end
    elseif GAME.state == "paused" then
        if key == "escape" then
            GAME.state = "play"
            Portal.gameplayStart()
            Sound.startMusic()
        end
    elseif GAME.state == "upgrade" then
        if key == "up" and GAME.upgradeChoices then
            GAME.upgradeIndex = math.max(1, GAME.upgradeIndex - 1)
            Sound.play("dash", 0.6)
        elseif key == "down" and GAME.upgradeChoices then
            GAME.upgradeIndex = math.min(#GAME.upgradeChoices, GAME.upgradeIndex + 1)
            Sound.play("dash", 0.6)
        elseif (key == "return" or key == "space") and GAME.upgradeChoices then
            local up = GAME.upgradeChoices[GAME.upgradeIndex]
            if up then XP.apply(GAME.run, up) end
            GAME.upgradeChoices = nil
            GAME.state = "play"
            Portal.gameplayStart()
        end
    elseif GAME.state == "revive_prompt" then
        if key == "return" or key == "space" then
            Portal.rewardedBreak("revive")

        elseif key == "escape" then
            local run = GAME.run
            if run then
                Profile.recordRun(run.modeId, run.score, run.wave, run.scrapEarned, run.coresEarned)
                GAME.lastDeath = { score = run.score, wave = run.wave, scrap = run.scrapEarned, cores = run.coresEarned }
            end
            Portal.commercialBreak()
            GAME.state = "gameover"
        end
    elseif GAME.state == "gameover" then
        if key == "return" or key == "space" or key == "escape" then
            GAME.state = "hangar"
        end
    end
end

function love.mousepressed(x, y, button)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    -- 1. Active Modals Intercept All Mouse Input
    if GAME.activeModal == "ad_prompt" then
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local modalW, modalH = 460, 260
        local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
        if x >= modalX + 40 and x <= modalX + 200 and y >= modalY + 180 and y <= modalY + 224 then
            if GAME.pendingReward then
                Portal.rewardedBreak(GAME.pendingReward)
            end
            GAME.activeModal = nil
            GAME.pendingReward = nil
            return
        elseif x >= modalX + 260 and x <= modalX + 420 and y >= modalY + 180 and y <= modalY + 224 then
            GAME.activeModal = nil
            GAME.pendingReward = nil
            return
        end
        return
    end

    if GAME.activeModal == "settings" then
        if button == 1 then
            local modalW, modalH = 560, 410
            local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2

            -- Back button
            if x >= modalX + 20 and x <= modalX + 64 and y >= modalY + 18 and y <= modalY + 56 then
                GAME.activeModal = nil
                Sound.play("dash", 0.6)
                return
            end

            -- Music Volume Slider Track
            if x >= modalX + 225 and x <= modalX + 385 and y >= modalY + 98 and y <= modalY + 122 then
                local frac = math.max(0, math.min(1, (x - (modalX + 225)) / 160))
                Profile.data.settings = Profile.data.settings or {}
                Profile.data.settings.musicVolume = frac
                Sound.setMusicVolume(frac)
                GAME.draggingSlider = "music"
                return
            end

            -- Music ON/OFF Toggle
            if x >= modalX + 430 and x <= modalX + 494 and y >= modalY + 92 and y <= modalY + 122 then
                Profile.data.settings = Profile.data.settings or {}
                Profile.data.settings.musicEnabled = not (Profile.data.settings.musicEnabled ~= false)
                Sound.setMusicEnabled(Profile.data.settings.musicEnabled)
                Sound.play("dash", 0.6)
                return
            end

            -- SFX Volume Slider Track
            if x >= modalX + 225 and x <= modalX + 385 and y >= modalY + 163 and y <= modalY + 187 then
                local frac = math.max(0, math.min(1, (x - (modalX + 225)) / 160))
                Profile.data.settings = Profile.data.settings or {}
                Profile.data.settings.sfxVolume = frac
                Sound.setSfxVolume(frac)
                GAME.draggingSlider = "sfx"
                return
            end

            -- SFX ON/OFF Toggle
            if x >= modalX + 430 and x <= modalX + 494 and y >= modalY + 157 and y <= modalY + 187 then
                Profile.data.settings = Profile.data.settings or {}
                Profile.data.settings.sfxEnabled = not (Profile.data.settings.sfxEnabled ~= false)
                Sound.setSfxEnabled(Profile.data.settings.sfxEnabled)
                Sound.play("dash", 0.6)
                return
            end

            -- Fullscreen Toggle
            if x >= modalX + 430 and x <= modalX + 494 and y >= modalY + 222 and y <= modalY + 252 then
                Profile.data.settings = Profile.data.settings or {}
                Profile.data.settings.fullscreen = not (Profile.data.settings.fullscreen == true)
                pcall(love.window.setFullscreen, Profile.data.settings.fullscreen)
                Sound.play("dash", 0.6)
                return
            end

            -- Show FPS Toggle
            if x >= modalX + 430 and x <= modalX + 494 and y >= modalY + 282 and y <= modalY + 312 then
                Profile.data.settings = Profile.data.settings or {}
                Profile.data.settings.showFps = not (Profile.data.settings.showFps == true)
                Sound.play("dash", 0.6)
                return
            end

            -- APPLY Button
            if x >= modalX + 180 and x <= modalX + 380 and y >= modalY + 345 and y <= modalY + 391 then
                Profile.save()
                GAME.activeModal = nil
                Sound.play("powerup", 1.2)
                return
            end

            -- Click outside panel dismisses modal
            if x < modalX or x > modalX + modalW or y < modalY or y > modalY + modalH then
                GAME.activeModal = nil
                Sound.play("dash", 0.6)
                return
            end
        end
        return
    elseif GAME.activeModal == "profile" then
        if button == 1 then
            local modalW, modalH = 520, 360
            local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
            if (x >= modalX + 20 and x <= modalX + 64 and y >= modalY + 18 and y <= modalY + 56)
                or (x >= modalX + 160 and x <= modalX + 360 and y >= modalY + 295 and y <= modalY + 339)
                or (x < modalX or x > modalX + modalW or y < modalY or y > modalY + modalH) then
                GAME.activeModal = nil
                Sound.play("dash", 0.6)
                return
            end
        end
        return
    elseif GAME.activeModal == "stats" then
        if button == 1 then
            local modalW, modalH = 560, 390
            local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
            if (x >= modalX + 20 and x <= modalX + 64 and y >= modalY + 18 and y <= modalY + 56)
                or (x >= modalX + 180 and x <= modalX + 380 and y >= modalY + 315 and y <= modalY + 359)
                or (x < modalX or x > modalX + modalW or y < modalY or y > modalY + modalH) then
                GAME.activeModal = nil
                Sound.play("dash", 0.6)
                return
            end
        end
        return
    elseif GAME.activeModal == "help" then
        if button == 1 then
            local modalW, modalH = 580, 420
            local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
            if (x >= modalX + 20 and x <= modalX + 64 and y >= modalY + 18 and y <= modalY + 56)
                or (x >= modalX + 190 and x <= modalX + 390 and y >= modalY + 360 and y <= modalY + 402)
                or (x < modalX or x > modalX + modalW or y < modalY or y > modalY + modalH) then
                GAME.activeModal = nil
                Sound.play("dash", 0.6)
                return
            end
        end
        return
    end

    -- 2. Top-Bar Component Interaction (Menu, Hangar, TechTree, ModeSelect)
    if GAME.state == "menu" or GAME.state == "hangar" or GAME.state == "techtree" or GAME.state == "modeselect" then
        if button == 1 then
            -- Back Button (when in sub-screens)
            if GAME.state ~= "menu" and x >= 30 and x <= 78 and y >= 20 and y <= 60 then
                GAME.state = "menu"
                GAME.menuIndex = 1
                Sound.play("dash", 0.6)
                return
            end

            -- Player Profile Card (when on Main Menu)
            if GAME.state == "menu" and x >= 30 and x <= 240 and y >= 18 and y <= 66 then
                GAME.activeModal = "profile"
                Sound.play("dash", 0.7)
                return
            end

            -- Scrap Pill (+) Rewarded Ad Crate
            if x >= (W - 410 + 135 - 34) and x <= (W - 410 + 135) and y >= 22 and y <= 52 then
                GAME.activeModal = "ad_prompt"
                GAME.pendingReward = "scrap_crate"
                return
            end

            -- Core Pill (+) Rewarded Ad Crate
            if x >= (W - 260 + 135 - 34) and x <= (W - 260 + 135) and y >= 22 and y <= 52 then
                GAME.activeModal = "ad_prompt"
                GAME.pendingReward = "core_crate"
                return
            end

            -- Settings Gear Button
            if x >= W - 70 and x <= W - 28 and y >= 22 and y <= 60 then
                GAME.activeModal = "settings"
                Sound.play("dash", 0.7)
                return
            end
        end
    end

    -- 3. Screen Specific Handlers
    if GAME.state == "menu" then
        if button == 1 then
            -- LAUNCH MISSION
            if x >= W/2 - 190 and x <= W/2 + 190 and y >= H * 0.43 and y <= H * 0.43 + 60 then
                GAME.state = "modeselect"
                GAME.menuIndex = 1
                Sound.play("powerup", 1.0)
                return
            end
            -- HANGAR
            if x >= W/2 - 160 and x <= W/2 + 160 and y >= H * 0.43 + 76 and y <= H * 0.43 + 126 then
                GAME.state = "hangar"
                GAME.hangarShipIndex = 1
                Sound.play("dash", 0.8)
                return
            end
            -- TECH TREE
            if x >= W/2 - 160 and x <= W/2 + 160 and y >= H * 0.43 + 138 and y <= H * 0.43 + 188 then
                GAME.state = "techtree"
                GAME.hangarTechIndex = 1
                Sound.play("dash", 0.8)
                return
            end
            -- Bottom Trophy Button
            if x >= 40 and x <= 90 and y >= H - 68 and y <= H - 22 then
                GAME.activeModal = "stats"
                Sound.play("dash", 0.7)
                return
            end
            -- Bottom Stats Button
            if x >= W - 120 and x <= W - 70 and y >= H - 68 and y <= H - 22 then
                GAME.activeModal = "stats"
                Sound.play("dash", 0.7)
                return
            end
            -- Bottom Help Button
            if x >= W - 62 and x <= W - 12 and y >= H - 68 and y <= H - 22 then
                GAME.activeModal = "help"
                Sound.play("dash", 0.7)
                return
            end
        end

    elseif GAME.state == "hangar" then
        if button == 1 then
            local pedX, pedY = W/2 - 80, H * 0.47

            -- Left Carousel Arrow
            if x >= pedX - 220 and x <= pedX - 174 and y >= pedY - 26 and y <= pedY + 20 then
                GAME.hangarShipIndex = (GAME.hangarShipIndex - 2) % #SHIP_LIST + 1
                Sound.play("dash", 0.7)
                return
            end

            -- Right Carousel Arrow
            if x >= pedX + 174 and x <= pedX + 220 and y >= pedY - 26 and y <= pedY + 20 then
                GAME.hangarShipIndex = (GAME.hangarShipIndex % #SHIP_LIST) + 1
                Sound.play("dash", 0.7)
                return
            end

            -- Right Stat Panel Action Button (Equip / Unlock)
            local panelW, panelH = 340, 260
            local panelX, panelY = W - panelW - 35, H * 0.22
            local btnW = panelW - 36
            local btnH = 44
            local btnX = panelX + 18
            local btnY = panelY + panelH - btnH - 14
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                local sid = SHIP_LIST[GAME.hangarShipIndex]
                if Profile.data.unlockedShips and Profile.data.unlockedShips[sid] then
                    Profile.selectShip(sid)
                    Sound.play("powerup", 1.2)
                else
                    local cost = Profile.SHIP_COSTS[sid] or 1000
                    if (Profile.data.scrap or 0) >= cost then
                        Profile.unlockShip(sid)
                        Sound.play("levelup", 1.2)
                        Effects.flash(0.3, 0.9, 1.0, 0.4, 0.4)
                    else
                        Sound.play("playerhit", 0.8)
                    end
                end
                return
            end

            -- Bottom 6-Ship Dock Cards
            local dockX, dockY, dockW, dockH = 40, H - 150, W - 80, 132
            local cardW = (dockW - 36 - 5 * 10) / 6
            local cardH = dockH - 24
            for i = 1, #SHIP_LIST do
                local cx = dockX + 18 + (i - 1) * (cardW + 10)
                local cy = dockY + 12
                if x >= cx and x <= cx + cardW and y >= cy and y <= cy + cardH then
                    local sid = SHIP_LIST[i]
                    if GAME.hangarShipIndex == i then
                        if Profile.data.unlockedShips and Profile.data.unlockedShips[sid] then
                            Profile.selectShip(sid)
                            Sound.play("powerup", 1.2)
                        else
                            local cost = Profile.SHIP_COSTS[sid] or 1000
                            if (Profile.data.scrap or 0) >= cost then
                                Profile.unlockShip(sid)
                                Sound.play("levelup", 1.2)
                                Effects.flash(0.3, 0.9, 1.0, 0.4, 0.4)
                            else
                                Sound.play("playerhit", 0.8)
                            end
                        end
                    else
                        GAME.hangarShipIndex = i
                        Sound.play("dash", 0.7)
                    end
                    return
                end
            end
        end

    elseif GAME.state == "techtree" then
        if button == 1 then
            local colW = (W - 100) / 2
            local col1X = 40
            local col2X = col1X + colW + 20
            local startY = 82
            local cardH = 92
            local cardGap = 12

            for i, tech in ipairs(Profile.TECH_TREE) do
                local col = (i <= 4) and 1 or 2
                local row = (i <= 4) and i or (i - 4)
                local cx = (col == 1) and col1X or col2X
                local cy = startY + (row - 1) * (cardH + cardGap)
                if x >= cx and x <= cx + colW and y >= cy and y <= cy + cardH then
                    GAME.hangarTechIndex = i
                    local cost = Profile.getTechCost(tech)
                    if cost and (Profile.data.scrap or 0) >= cost then
                        Profile.buyTech(tech.id)
                        Sound.play("levelup", 1.2)
                        Effects.flash(0.3, 0.9, 1.0, 0.3, 0.3)
                    else
                        Sound.play("playerhit", 0.8)
                    end
                    return
                end
            end
        end

    elseif GAME.state == "modeselect" then
        if button == 1 then
            for i = 1, 3 do
                local ry = 88 + (i - 1) * 108
                if x >= 60 and x <= W - 60 and y >= ry and y <= ry + 92 then
                    GAME.menuIndex = i
                    local m = Modes.all()[i]
                    startRun(m.id)
                    beginWave()
                    return
                end
            end
        end

    elseif GAME.state == "upgrade" and GAME.upgradeChoices then
        if button == 1 then
            for i = 1, #GAME.upgradeChoices do
                local ry = 200 + (i - 1) * 110
                if x >= W/2 - 280 and x <= W/2 + 280 and y >= ry and y <= ry + 85 then
                    GAME.upgradeIndex = i
                    love.keypressed("return")
                    return
                end
            end
        end

    elseif GAME.state == "revive_prompt" then
        if button == 1 then
            if x >= W/2 - 220 and x <= W/2 + 220 and y >= H * 0.44 and y <= H * 0.44 + 64 then
                love.keypressed("return")
            else
                love.keypressed("escape")
            end
        end

    elseif GAME.state == "gameover" then
        if button == 1 then
            if not GAME.hasDoubledScrap and x >= W/2 - 180 and x <= W/2 + 180 and y >= H * 0.58 and y <= H * 0.58 + 50 then
                GAME.hasDoubledScrap = true
                Portal.rewardedBreak("doubler")

            else
                GAME.state = "hangar"
            end
        end

    elseif GAME.state == "paused" then
        if GAME.activeModal == "settings" then
            local W, H = love.graphics.getWidth(), love.graphics.getHeight()
            local modalW, modalH = 560, 480
            local modalX, modalY = (W - modalW) / 2, (H - modalH) / 2
            if x >= modalX + 20 and x <= modalX + 64 and y >= modalY + 18 and y <= modalY + 56 then
                GAME.activeModal = nil
                Sound.play("ui_click", 1.0)
            end
            return
        end

        if button == 1 then
            local W, H = love.graphics.getWidth(), love.graphics.getHeight()
            local btnW, btnH = 240, 50
            local startY = H * 0.45
            if x >= W/2 - btnW/2 and x <= W/2 + btnW/2 then
                if y >= startY and y <= startY + btnH then
                    -- RESUME
                    GAME.state = "play"
                    Portal.gameplayStart()
                    Sound.startMusic()
                elseif y >= startY + 70 and y <= startY + 70 + btnH then
                    -- SETTINGS
                    GAME.activeModal = "settings"
                elseif y >= startY + 140 and y <= startY + 140 + btnH then
                    -- QUIT
                    GAME.state = "hangar"
                end
            end
        end

    elseif GAME.state == "play" then
        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        -- Check HUD buttons
        if button == 1 then
            if x >= W - 65 and x <= W - 20 and y >= 120 and y <= 165 then
                GAME.state = "paused"
                Portal.gameplayStop()
                return
            elseif x >= W - 245 and x <= W - 80 and y >= 120 and y <= 165 then
                -- Cycle Weapon
                if GAME.player then
                    local count = 7
                    GAME.player.weaponIndex = GAME.player.weaponIndex + 1
                    if GAME.player.weaponIndex > count then GAME.player.weaponIndex = 1 end
                    Sound.play("dash", 0.7)
                end
                return
            end
        end

        if button == 2 and GAME.player then
            GAME.player:triggerSpecial(Enemy, Bullet)
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if GAME.draggingSlider == "music" then
        local W = love.graphics.getWidth()
        local modalW = 560
        local modalX = (W - modalW) / 2
        local frac = math.max(0, math.min(1, (x - (modalX + 225)) / 160))
        Profile.data.settings = Profile.data.settings or {}
        Profile.data.settings.musicVolume = frac
        Sound.setMusicVolume(frac)
    elseif GAME.draggingSlider == "sfx" then
        local W = love.graphics.getWidth()
        local modalW = 560
        local modalX = (W - modalW) / 2
        local frac = math.max(0, math.min(1, (x - (modalX + 225)) / 160))
        Profile.data.settings = Profile.data.settings or {}
        Profile.data.settings.sfxVolume = frac
        Sound.setSfxVolume(frac)
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and GAME.draggingSlider then
        GAME.draggingSlider = nil
        Profile.save()
    end
end

function love.touchpressed(id, x, y)
    Touch.touchpressed(id, x, y)
    love.mousepressed(x, y, 1)
end

function love.touchmoved(id, x, y, dx, dy)
    Touch.touchmoved(id, x, y)
    love.mousemoved(x, y, dx, dy)
end

function love.touchreleased(id, x, y)
    Touch.touchreleased(id)
    love.mousereleased(x or 0, y or 0, 1)
end

function love.errorhandler(msg)
    msg = tostring(msg)
    local trace = debug.traceback("Error: " .. msg, 2)
    print("[PORTAL]:engineError:" .. msg)
    print("[PORTAL]:loadingFinished") -- Ensure loading overlay hides so error is visible
    print("[LUA ERROR]: " .. trace)

    if not love.window or not love.graphics or not love.event then
        return
    end

    if not love.graphics.isCreated() or not love.window.isOpen() then
        local ok, _ = pcall(love.window.setMode, 800, 600)
        if not ok then return end
    end

    love.audio.stop()
    love.graphics.reset()
    local font = love.graphics.setNewFont(14)
    love.graphics.setColor(1, 1, 1, 1)

    local function draw()
        love.graphics.clear(0.08, 0.02, 0.04)
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.print("STARFALL VENGEANCE — SYSTEM ALERT", 30, 30)
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.printf(trace, 30, 70, love.graphics.getWidth() - 60)
        love.graphics.present()
    end

    return function()
        love.event.pump()
        for e in love.event.poll() do
            if e == "quit" then return 1 end
        end
        draw()
        love.timer.sleep(0.1)
    end
end
