-- weapons.lua — four base weapons, level scaling (Lv 1-8), and Super-Weapon evolutions.

local Weapons = {}

Weapons.defs = {
    {
        id = "pistol", name = "Pulse Cannon",
        cooldown = 0.16, damage = 12, speed = 760, spread = 0.02,
        pellets = 1, pierce = 0, life = 1.2,
        bulletKey = "bulletPistol", size = 5,
        soundPitch = 1.10, recoil = 1.5,
        color = { 0.4, 0.8, 1.0 },
        evolution = "super_swarm",
    },
    {
        id = "shotgun", name = "Scatter Flak",
        cooldown = 0.50, damage = 7, speed = 660, spread = 0.40,
        pellets = 6, pierce = 0, life = 0.55,
        bulletKey = "bulletPistol", size = 5,
        soundPitch = 0.85, recoil = 6,
        color = { 1.0, 0.7, 0.2 },
        evolution = "super_arc",
    },
    {
        id = "machinegun", name = "Vulcan Gatling",
        cooldown = 0.068, damage = 5, speed = 940, spread = 0.08,
        pellets = 1, pierce = 0, life = 1.0,
        bulletKey = "bulletMg", size = 4,
        soundPitch = 1.35, recoil = 1,
        color = { 1.0, 0.9, 0.3 },
        evolution = "super_plasma",
    },
    {
        id = "sniper", name = "Mag Railgun",
        cooldown = 0.80, damage = 55, speed = 1600, spread = 0.0,
        pellets = 1, pierce = 5, life = 1.6,
        bulletKey = "bulletSniper", size = 6,
        soundPitch = 0.70, recoil = 8,
        color = { 0.3, 1.0, 0.5 },
        evolution = "super_vortex",
    },
    {
        id = "laser_repeater", name = "Laser Repeater",
        cooldown = 0.12, damage = 14, speed = 1200, spread = 0.0,
        pellets = 1, pierce = 1, life = 1.0,
        bulletKey = "laser1", size = 6,
        soundPitch = 1.40, recoil = 1.2,
        color = { 1.0, 0.2, 0.2 },
        evolution = "super_swarm",
    },
    {
        id = "plasma_laser", name = "Plasma Laser",
        cooldown = 0.45, damage = 22, speed = 800, spread = 0.05,
        pellets = 2, pierce = 2, life = 1.2,
        bulletKey = "laser2", size = 7,
        soundPitch = 0.90, recoil = 3.0,
        color = { 0.2, 1.0, 0.2 },
        evolution = "super_plasma",
    },
    {
        id = "heavy_laser", name = "Heavy Laser",
        cooldown = 0.90, damage = 70, speed = 1500, spread = 0.0,
        pellets = 1, pierce = 8, life = 1.5,
        bulletKey = "laser3", size = 8,
        soundPitch = 0.60, recoil = 7.0,
        color = { 0.2, 0.5, 1.0 },
        evolution = "super_vortex",
    },
}

Weapons.EVOLUTIONS = {
    super_swarm = {
        id = "super_swarm", name = "Swarm Barrage Matrix",
        cooldown = 0.22, damage = 16, speed = 600, spread = 0.30,
        pellets = 4, pierce = 1, life = 2.0,
        bulletKey = "superSwarm", size = 6,
        soundPitch = 1.25, recoil = 2.0,
        homing = true, explosive = true,
        color = { 0.2, 0.9, 1.0 },
    },
    super_arc = {
        id = "super_arc", name = "Arc-Chain Tempest",
        cooldown = 0.42, damage = 10, speed = 720, spread = 0.45,
        pellets = 8, pierce = 2, life = 0.65,
        bulletKey = "superArc", size = 6,
        soundPitch = 1.05, recoil = 5.0,
        chainLightning = true,
        color = { 0.3, 0.8, 1.0 },
    },
    super_plasma = {
        id = "super_plasma", name = "Hyper-Nova Disintegrator",
        cooldown = 0.08, damage = 12, speed = 980, spread = 0.12,
        pellets = 2, pierce = 1, life = 1.2,
        bulletKey = "superPlasma", size = 7,
        soundPitch = 0.95, recoil = 2.5,
        explosive = true,
        color = { 1.0, 0.3, 0.9 },
    },
    super_vortex = {
        id = "super_vortex", name = "Vortex Rail-Cannon",
        cooldown = 0.70, damage = 110, speed = 1800, spread = 0.0,
        pellets = 1, pierce = 12, life = 1.8,
        bulletKey = "superVortex", size = 9,
        soundPitch = 0.60, recoil = 10.0,
        vortex = true,
        color = { 0.7, 0.2, 1.0 },
    },
}

function Weapons.get(index)
    return Weapons.defs[index] or Weapons.defs[1]
end

function Weapons.count()
    return #Weapons.defs
end

-- Check if weapon has evolved into a Super Weapon
function Weapons.isEvolved(weaponIndex, run)
    if not run or not run.weaponLevels then return false end
    local lvl = run.weaponLevels[weaponIndex] or 1
    if lvl < 5 then return false end

    -- Synergy conditions
    local hasSynergy = false
    if weaponIndex == 1 and (run.upgrades.homing or 0) > 0 then hasSynergy = true
    elseif weaponIndex == 2 and (run.upgrades.drones or 0) >= 2 then hasSynergy = true
    elseif weaponIndex == 3 and (run.upgrades.firerate or 0) >= 3 then hasSynergy = true
    elseif weaponIndex == 4 and (run.upgrades.damage or 0) >= 3 then hasSynergy = true end

    return hasSynergy
end

-- Get active definition (handles base, levels, and super-weapon evolutions)
function Weapons.getActiveDef(weaponIndex, run, playerUpgrades)
    local base = Weapons.get(weaponIndex)
    local evolved = Weapons.isEvolved(weaponIndex, run)

    local def = evolved and Weapons.EVOLUTIONS[base.evolution] or base
    local d = {}
    for k, v in pairs(def) do d[k] = v end

    local lvl = (run and run.weaponLevels and run.weaponLevels[weaponIndex]) or 1
    -- Per-level weapon bonuses
    d.damage = d.damage * (1 + (lvl - 1) * 0.15)
    d.cooldown = math.max(0.02, d.cooldown * math.pow(0.95, lvl - 1))
    if lvl >= 4 then d.pellets = d.pellets + 1 end
    if lvl >= 7 then d.pierce = d.pierce + 1 end

    -- Apply player tech-tree/run upgrades
    local dmgMul = 1 + (playerUpgrades.damage or 0) * 0.12
    local fireMul = math.pow(0.92, playerUpgrades.firerate or 0)
    d.damage = d.damage * dmgMul
    d.cooldown = math.max(0.02, d.cooldown * fireMul)
    d.pierce = d.pierce + (playerUpgrades.pierce or 0)

    d.isEvolved = evolved
    d.level = lvl
    return d
end

-- Backward compatibility helper
function Weapons.applyUpgrades(def, upgrades)
    local d = {}
    for k, v in pairs(def) do d[k] = v end
    local dmgMul = 1 + (upgrades.damage or 0) * 0.12
    local fireMul = math.pow(0.92, upgrades.firerate or 0)
    d.damage = d.damage * dmgMul
    d.cooldown = math.max(0.02, d.cooldown * fireMul)
    d.pierce = d.pierce + (upgrades.pierce or 0)
    return d
end

return Weapons
