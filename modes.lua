-- modes.lua — exactly three player-facing mode definitions.
-- qa.py asserts: sorted(set(ids)) == ["campaign","endless","gauntlet"].

local Modes = {}

local definitions = {
    campaign = {
        id = "campaign",
        name = "CAMPAIGN",
        subtitle = "30 waves. Boss every 5. Full completion goal.",
        maxWaves = 30,
        bossEvery = 5,
        baseEnemyCount = 6,
        enemyGrowth = 1.6,
        timeLimit = nil,
        color = { 0.4, 0.7, 1.0 },
    },
    endless = {
        id = "endless",
        name = "ENDLESS",
        subtitle = "Infinite adaptive pressure. How long can you last?",
        maxWaves = math.huge,
        bossEvery = 8,
        baseEnemyCount = 5,
        enemyGrowth = 2.0,
        adaptive = true,
        timeLimit = nil,
        color = { 1.0, 0.6, 0.3 },
    },
    gauntlet = {
        id = "gauntlet",
        name = "GAUNTLET",
        subtitle = "8 timed trials. Rotating combat mutators.",
        maxWaves = 8,
        bossEvery = 8,
        baseEnemyCount = 10,
        enemyGrowth = 2.5,
        timeLimit = 45,
        mutators = {
            { id = "swarm",      name = "SWARM",           enemies = { "drone", "scout" } },
            { id = "snipers",    name = "MARKSMEN",        enemies = { "sniper", "scout" } },
            { id = "bombers",    name = "BOMBARDMENT",     enemies = { "bomber", "tank" } },
            { id = "flankers",   name = "INTERCEPTORS",    enemies = { "interceptor", "fighter" } },
            { id = "supported",  name = "SUPPORTED ARMS",  enemies = { "tank", "support", "fighter" } },
            { id = "elites",     name = "ELITES",          enemies = { "elite", "interceptor", "sniper" } },
            { id = "pressure",   name = "CHAOS INVASION",  enemies = { "tank", "bomber", "interceptor", "support" } },
            { id = "finalBoss",  name = "FINAL TITAN",     enemies = { "elite" }, boss = true, bossType = "boss_starDevourer" },
        },
        color = { 1.0, 0.3, 0.6 },
    },
}

function Modes.all()
    return { definitions.campaign, definitions.endless, definitions.gauntlet }
end

function Modes.get(id)
    return definitions[id]
end

function Modes.count()
    return 3
end

-- Wave rules: returns { count, hpMul, speedMul, types, boss, bossType }.
function Modes.waveRules(run)
    local def = definitions[run.modeId]
    if not def then return { count = 5, hpMul = 1, speedMul = 1, types = { "fighter" }, boss = false } end

    local wave = run.wave or 1
    local count, hpMul, speedMul = 6, 1, 1
    local types = { "fighter" }
    local boss = false
    local bossType = nil

    if run.modeId == "campaign" then
        count = math.floor(def.baseEnemyCount + wave * def.enemyGrowth)
        hpMul = 1 + (wave - 1) * 0.12
        speedMul = 1 + (wave - 1) * 0.05

        -- Progressive escalation of the 9 enemy archetypes
        if wave <= 4 then
            types = { "scout", "fighter", "drone" }
        elseif wave <= 9 then
            types = { "scout", "fighter", "drone", "interceptor", "sniper" }
        elseif wave <= 14 then
            types = { "fighter", "interceptor", "sniper", "tank", "bomber" }
        elseif wave <= 19 then
            types = { "fighter", "interceptor", "sniper", "tank", "bomber", "support" }
        elseif wave <= 24 then
            types = { "interceptor", "sniper", "tank", "bomber", "support", "elite" }
        else
            types = { "interceptor", "tank", "sniper", "support", "bomber", "elite" }
        end

        -- Boss every 5 waves with distinct multi-phase flagship bosses
        if wave % def.bossEvery == 0 then
            boss = true
            if wave == 5 then bossType = "boss_voidHunter"
            elseif wave == 10 then bossType = "boss_ironColossus"
            elseif wave == 15 then bossType = "boss_swarmQueen"
            elseif wave == 20 then bossType = "boss_phantom"
            elseif wave == 25 then bossType = "boss_ironColossus"
            elseif wave >= 30 then bossType = "boss_starDevourer" end
        end

    elseif run.modeId == "endless" then
        local pressure = 1 + (run.elapsed or 0) / 90
        if pressure > 4 then pressure = 4 end
        count = math.floor(def.baseEnemyCount + wave * def.enemyGrowth * pressure)
        if count > 50 then count = 50 end
        hpMul = 1 + (wave - 1) * 0.14
        speedMul = 1 + (wave - 1) * 0.06

        if wave <= 3 then
            types = { "drone", "scout", "fighter" }
        elseif wave <= 7 then
            types = { "scout", "fighter", "interceptor", "sniper" }
        elseif wave <= 15 then
            types = { "fighter", "interceptor", "sniper", "tank", "bomber" }
        else
            types = { "scout", "fighter", "interceptor", "tank", "sniper", "support", "bomber", "drone", "elite" }
        end

        if wave % def.bossEvery == 0 then
            boss = true
            local bossCycle = { "boss_voidHunter", "boss_ironColossus", "boss_swarmQueen", "boss_phantom", "boss_starDevourer" }
            local bIdx = ((math.floor(wave / def.bossEvery) - 1) % #bossCycle) + 1
            bossType = bossCycle[bIdx]
        end

    elseif run.modeId == "gauntlet" then
        local mut = def.mutators[math.min(wave, #def.mutators)]
        types = mut.enemies
        boss = mut.boss or false
        bossType = mut.bossType
        count = def.baseEnemyCount + wave * 2
        hpMul = 1.3 + (wave - 1) * 0.10
        speedMul = 1.15
    end

    return { count = count, hpMul = hpMul, speedMul = speedMul, types = types, boss = boss, bossType = bossType }
end

return Modes
