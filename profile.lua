-- profile.lua — persistent meta-progression, scrap currency, tech-tree, ship unlocks, and save data.

local Profile = {}
Profile.data = {
    totalGames = 0,
    totalScore = 0,
    totalStars = 0,
    playerLevel = 1,
    playerXp = 0,
    scrap = 150, -- starting scrap for new recruits
    cores = 2,
    selectedShip = "basic",
    unlockedShips = { basic = true, cobalt = false, solar = false, phantom = false, emerald = false, void = false, viper = true },
    settings = {
        musicVolume = 0.8,
        musicEnabled = true,
        sfxVolume = 1.0,
        sfxEnabled = true,
        fullscreen = false,
        showFps = false,
    },
    bestScore = { campaign = 0, endless = 0, gauntlet = 0 },
    bestWave  = { campaign = 0, endless = 0, gauntlet = 0 },
    -- techTree & upgrades (synced)
    upgrades = { damage = 0, firerate = 0, speed = 0, health = 0, pierce = 0, drones = 0, magnet = 0, crit = 0 },
}

local FILE = "starfall_profile.lua"

Profile.TECH_TREE = {
    { id = "health",   name = "Reinforced Hull",    desc = "+1 Starting Max HP",       baseCost = 150, costMul = 2.2, max = 5 },
    { id = "damage",   name = "Antimatter Rounds",  desc = "+12% Base Damage",         baseCost = 200, costMul = 2.2, max = 5 },
    { id = "firerate", name = "Hyper Coils",        desc = "+8% Weapon Fire Rate",     baseCost = 180, costMul = 2.2, max = 5 },
    { id = "speed",    name = "Ion Thrusters",      desc = "+8% Ship Agility",         baseCost = 120, costMul = 2.0, max = 5 },
    { id = "magnet",   name = "Magnetic Tractor",   desc = "+35% Scrap/XP Grab Range", baseCost = 100, costMul = 1.9, max = 5 },
    { id = "crit",     name = "Targeting Matrix",   desc = "+5% Critical Hit Chance",  baseCost = 250, costMul = 2.4, max = 5 },
    { id = "drones",   name = "Drone Fabricator",   desc = "Start with +1 Attack Drone", baseCost = 450, costMul = 2.8, max = 3 },
}

Profile.SHIP_COSTS = {
    basic   = 0,
    cobalt  = 500,
    solar   = 1000,
    phantom = 1500,
    emerald = 2000,
    void    = 2500,
    -- backward compatibility aliases
    viper   = 0,
    titan   = 1000,
    spectre = 1500,
    aegis   = 2000,
}

local function serialize(t)
    local parts = { "{" }
    for k, v in pairs(t) do
        local key = (type(k) == "string") and string.format("[%q]", k) or ("[" .. tostring(k) .. "]")
        local val
        if type(v) == "table" then
            val = serialize(v)
        elseif type(v) == "string" then
            val = string.format("%q", v)
        elseif type(v) == "number" or type(v) == "boolean" then
            val = tostring(v)
        else
            val = "nil"
        end
        table.insert(parts, key .. "=" .. val .. ",")
    end
    table.insert(parts, "}")
    return table.concat(parts)
end

function Profile.init()
    if not love.filesystem.getInfo(FILE) then return end
    local chunk = love.filesystem.load(FILE)
    if not chunk then return end
    local ok, loaded = pcall(chunk)
    if not ok or type(loaded) ~= "table" then return end
    for k, v in pairs(loaded) do
        if type(v) == "table" and type(Profile.data[k]) == "table" then
            for kk, vv in pairs(v) do Profile.data[k][kk] = vv end
        else
            Profile.data[k] = v
        end
    end
    Profile.data.unlockedShips = Profile.data.unlockedShips or { basic = true }
    Profile.data.unlockedShips.basic = true
    if Profile.data.unlockedShips.viper then Profile.data.unlockedShips.basic = true end
    Profile.data.selectedShip = Profile.data.selectedShip or "basic"
    if Profile.data.selectedShip == "viper" then Profile.data.selectedShip = "basic" end
    Profile.data.scrap = Profile.data.scrap or 150
    Profile.data.cores = Profile.data.cores or 2
    Profile.data.playerLevel = Profile.data.playerLevel or 1
    Profile.data.playerXp = Profile.data.playerXp or 0
    Profile.data.settings = Profile.data.settings or {
        musicVolume = 0.8,
        musicEnabled = true,
        sfxVolume = 1.0,
        sfxEnabled = true,
        fullscreen = false,
        showFps = false,
    }
end

function Profile.save()
    pcall(function()
        love.filesystem.write(FILE, "return " .. serialize(Profile.data))
    end)
end

function Profile.recordRun(modeId, score, wave, scrapEarned, coresEarned)
    Profile.data.totalGames = (Profile.data.totalGames or 0) + 1
    Profile.data.totalScore = (Profile.data.totalScore or 0) + score
    Profile.data.totalStars = (Profile.data.totalStars or 0) + math.floor(score / 1000)
    Profile.data.scrap = (Profile.data.scrap or 0) + (scrapEarned or 0)
    Profile.data.cores = (Profile.data.cores or 0) + (coresEarned or 0)

    Profile.data.bestScore = Profile.data.bestScore or {}
    Profile.data.bestWave = Profile.data.bestWave or {}

    if score > (Profile.data.bestScore[modeId] or 0) then
        Profile.data.bestScore[modeId] = score
    end
    if wave > (Profile.data.bestWave[modeId] or 0) then
        Profile.data.bestWave[modeId] = wave
    end
    Profile.save()
end

function Profile.getTechCost(tech)
    local curLevel = (Profile.data.upgrades and Profile.data.upgrades[tech.id]) or 0
    if curLevel >= tech.max then return nil end
    return math.floor(tech.baseCost * math.pow(tech.costMul, curLevel))
end

function Profile.buyTech(techId)
    local tech = nil
    for _, t in ipairs(Profile.TECH_TREE) do
        if t.id == techId then tech = t break end
    end
    if not tech then return false end
    local cost = Profile.getTechCost(tech)
    if not cost or (Profile.data.scrap or 0) < cost then return false end

    Profile.data.scrap = Profile.data.scrap - cost
    Profile.data.upgrades[techId] = (Profile.data.upgrades[techId] or 0) + 1
    Profile.save()
    return true
end

function Profile.unlockShip(shipId)
    if Profile.data.unlockedShips[shipId] then return true end
    local cost = Profile.SHIP_COSTS[shipId] or 9999
    if (Profile.data.scrap or 0) < cost then return false end

    Profile.data.scrap = Profile.data.scrap - cost
    Profile.data.unlockedShips[shipId] = true
    Profile.data.selectedShip = shipId
    Profile.save()
    return true
end

function Profile.selectShip(shipId)
    if Profile.data.unlockedShips[shipId] then
        Profile.data.selectedShip = shipId
        Profile.save()
        return true
    end
    return false
end

return Profile
