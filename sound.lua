-- sound.lua — SFX manager pointed at sounds/.
-- Variant selection: three laser variants rotate to avoid audio fatigue.
-- Every load is wrapped in pcall; a missing file is silently skipped.

local Sound = {}
Sound.enabled = true
Sound.musicEnabled = true
Sound.volume = 0.8
Sound._sfx = {}
Sound._music = nil
Sound._variantCursor = 0

local SFX_REGISTRY = {
    shoot     = { "sounds/laser-1.ogg", "sounds/laser-2.ogg", "sounds/laser-3.ogg" },
    hit       = { "sounds/hit.ogg" },
    explosion = { "sounds/explosion.ogg" },
    powerup   = { "sounds/powerup.ogg" },
    levelup   = { "sounds/levelup.ogg" },
    dash      = { "sounds/dash.ogg" },
    playerhit = { "sounds/playerhit.ogg" },
    boss      = { "sounds/boss.ogg" },
}

function Sound.new()
    for name, list in pairs(SFX_REGISTRY) do
        local sources = {}
        for _, path in ipairs(list) do
            local ok, src = pcall(love.audio.newSource, path, "static")
            if ok and src then
                src:setVolume(Sound.volume)
                table.insert(sources, src)
            end
        end
        Sound._sfx[name] = sources
    end
    Sound._tryLoadMusic()
end

function Sound._tryLoadMusic()
    local candidates = { "sounds/music.ogg", "sounds/theme.ogg", "sounds/bg.ogg" }
    for _, path in ipairs(candidates) do
        local ok, src = pcall(love.audio.newSource, path, "stream")
        if ok and src then
            src:setLooping(true)
            src:setVolume(Sound.volume * 0.5)
            Sound._music = src
            return
        end
    end
end

function Sound.play(name, pitch)
    if not Sound.enabled then return end
    local list = Sound._sfx[name]
    if not list or #list == 0 then return end

    -- Round-robin through variants, then randomise pitch slightly.
    local idx
    if #list > 1 then
        Sound._variantCursor = (Sound._variantCursor + 1) % #list
        idx = Sound._variantCursor + 1
    else
        idx = 1
    end

    local src = list[idx]
    local ok, clone = pcall(src.clone, src)
    local playable = (ok and clone) and clone or src
    if clone then
        clone:setPitch(pitch or (0.95 + love.math.random() * 0.1))
        clone:setVolume(Sound.volume)
        clone:play()
    else
        src:setPitch(pitch or 1)
        src:stop()
        src:play()
    end
end

function Sound.startMusic()
    if Sound._music and Sound.musicEnabled and not Sound._music:isPlaying() then
        Sound._music:play()
    end
end

function Sound.stopMusic()
    if Sound._music then Sound._music:stop() end
end

function Sound.setVolume(v)
    Sound.setSfxVolume(v)
    Sound.setMusicVolume(v)
end

function Sound.setMusicVolume(v)
    v = math.max(0, math.min(1, v or 0.8))
    if Sound._music then
        Sound._music:setVolume(v * 0.6)
    end
end

function Sound.setMusicEnabled(on)
    Sound.musicEnabled = on == true
    if not Sound.musicEnabled then
        Sound.stopMusic()
    else
        Sound.startMusic()
    end
end

function Sound.setSfxVolume(v)
    Sound.volume = math.max(0, math.min(1, v or 1.0))
    for _, list in pairs(Sound._sfx) do
        for _, src in ipairs(list) do src:setVolume(Sound.volume) end
    end
end

function Sound.setSfxEnabled(on)
    Sound.enabled = on == true
    if not Sound.enabled then
        for _, list in pairs(Sound._sfx) do
            for _, src in ipairs(list) do src:stop() end
        end
    end
end

function Sound.setEnabled(on)
    Sound.setSfxEnabled(on)
end

return Sound
