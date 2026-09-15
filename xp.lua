-- xp.lua — run-local XP curve, level-up upgrade pool, and super-weapon synergies.

local Weapons = require("weapons")

local XP = {}

XP.UPGRADE_POOL = {
    -- Stat passives
    { id = "damage",   name = "Damage +15%",     category = "stat", max = 8,  apply = function(r) r.upgrades.damage = (r.upgrades.damage or 0) + 1 end },
    { id = "firerate", name = "Fire Rate +10%",  category = "stat", max = 8,  apply = function(r) r.upgrades.firerate = (r.upgrades.firerate or 0) + 1 end },
    { id = "speed",    name = "Move Speed +8%",  category = "stat", max = 6,  apply = function(r) r.upgrades.speed = (r.upgrades.speed or 0) + 1 end },
    { id = "health",   name = "Max HP +1",       category = "stat", max = 5,  apply = function(r) r.upgrades.health = (r.upgrades.health or 0) + 1 end },
    { id = "pierce",   name = "Pierce +1",       category = "stat", max = 4,  apply = function(r) r.upgrades.pierce = (r.upgrades.pierce or 0) + 1 end },
    { id = "drones",   name = "Attack Drone +1", category = "stat", max = 4,  apply = function(r) r.upgrades.drones = (r.upgrades.drones or 0) + 1 end },

    -- Weapon levels
    { id = "w_pistol",     name = "Pulse Cannon Lv+",   category = "weapon", wIdx = 1, max = 8, apply = function(r) r.weaponLevels[1] = (r.weaponLevels[1] or 1) + 1 end },
    { id = "w_shotgun",    name = "Scatter Flak Lv+",   category = "weapon", wIdx = 2, max = 8, apply = function(r) r.weaponLevels[2] = (r.weaponLevels[2] or 1) + 1 end },
    { id = "w_machinegun", name = "Vulcan Gatling Lv+", category = "weapon", wIdx = 3, max = 8, apply = function(r) r.weaponLevels[3] = (r.weaponLevels[3] or 1) + 1 end },
    { id = "w_sniper",     name = "Mag Railgun Lv+",    category = "weapon", wIdx = 4, max = 8, apply = function(r) r.weaponLevels[4] = (r.weaponLevels[4] or 1) + 1 end },
    { id = "w_laser1",     name = "Laser Repeater Lv+", category = "weapon", wIdx = 5, max = 8, apply = function(r) r.weaponLevels[5] = (r.weaponLevels[5] or 1) + 1 end },
    { id = "w_laser2",     name = "Plasma Laser Lv+",   category = "weapon", wIdx = 6, max = 8, apply = function(r) r.weaponLevels[6] = (r.weaponLevels[6] or 1) + 1 end },
    { id = "w_laser3",     name = "Heavy Laser Lv+",    category = "weapon", wIdx = 7, max = 8, apply = function(r) r.weaponLevels[7] = (r.weaponLevels[7] or 1) + 1 end },


    -- Synergy modules that unlock Super Weapons
    { id = "homing",     name = "Quantum Module (Swarm Synergy)",      category = "synergy", max = 1, apply = function(r) r.upgrades.homing = 1 end },
    { id = "tesla",      name = "Tesla Induction (Arc Synergy)",       category = "synergy", max = 1, apply = function(r) r.upgrades.tesla = 1 end },
    { id = "overcharge", name = "Antimatter Battery (Nova Synergy)",   category = "synergy", max = 1, apply = function(r) r.upgrades.overcharge = 1 end },
    { id = "vortex",     name = "Singularity Coil (Vortex Synergy)",   category = "synergy", max = 1, apply = function(r) r.upgrades.vortex = 1 end },
}

function XP.xpForLevel(level)
    return 18 + (level - 1) * 14 + math.floor(math.pow(level, 1.5))
end

-- Returns true if the XP amount caused a level-up.
function XP.addXP(run, amount)
    if not run then return false end
    run.xp = (run.xp or 0) + amount
    local needed = XP.xpForLevel(run.level or 1)
    if run.xp >= needed then
        run.xp = run.xp - needed
        run.level = (run.level or 1) + 1
        return true
    end
    return false
end

function XP.rollChoices(run, count)
    count = count or 3
    run.weaponLevels = run.weaponLevels or { 1, 1, 1, 1, 1, 1, 1 }
    run.upgrades = run.upgrades or {}

    local available = {}
    for _, up in ipairs(XP.UPGRADE_POOL) do
        local cur = 0
        if up.category == "weapon" then
            cur = run.weaponLevels[up.wIdx] or 1
        else
            cur = run.upgrades[up.id] or 0
        end
        if cur < up.max then
            available[#available + 1] = up
        end
    end

    -- Shuffle
    for i = #available, 2, -1 do
        local j = love.math.random(1, i)
        available[i], available[j] = available[j], available[i]
    end

    local out = {}
    for i = 1, math.min(count, #available) do
        out[i] = available[i]
    end
    return out
end

function XP.apply(run, upgrade)
    if not upgrade or not run then return end
    upgrade.apply(run)

    if upgrade.id == "drones" then
        require("drone").setCount(run.upgrades.drones or 0)
    end
end

return XP
