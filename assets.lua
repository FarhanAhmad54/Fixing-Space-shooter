-- assets.lua — centralized image + font registry.
-- Every load is wrapped in pcall so a missing PNG degrades to a coloured
-- rectangle instead of crashing the game.

local Assets = {}
Assets.images = {}
Assets.fonts = {}
Assets._loaded = false

local IMAGE_REGISTRY = {
    ship          = "assets/SpaceShip.png",
    bg            = "assets/bg.png",
    starsA        = "assets/Stars-A.png",
    starsB        = "assets/Stars-B.png",
    swarmer       = "assets/SWARMERS.png",
    sniper        = "assets/SNIPERS.png",
    bomber        = "assets/BOMBERS.png",
    turret        = "assets/TURRET DRONES.png",
    miniboss      = "assets/MINI-BOSSES.png",
    bulletPistol  = "assets/bullet.png",
    bulletMg      = "assets/bullet-1.png",
    bulletSniper  = "assets/bullet-2.png",
    laser1        = "assets/laser-1.png",
    laser2        = "assets/laser-2.png",
    laser3        = "assets/laser-3.png",
    plasm         = "assets/plasm.png",
    rocket        = "assets/rocket.png",
    shield        = "assets/shield.png",
    fire          = "assets/fire.png",
    bonusLife     = "assets/bonus_life.png",
    bonusShield   = "assets/bonus_shield.png",
    bonusTime     = "assets/bonus_time.png",
    shipViper     = "assets/SpaceShip.png",
    shipTitan     = "assets/SpaceShip.png",
    shipSpectre   = "assets/ship.png",
    shipAegis     = "assets/support.png",
    lightGlow     = "assets/light0.png",
    sphereCore    = "assets/sphere0.png",
    superPlasma   = "assets/super_plasma.png",
    superArc      = "assets/super_arc.png",
    superVortex   = "assets/super_vortex.png",
    superSwarm    = "assets/super_swarm.png",
    scrap         = "assets/scrap.png",
    core          = "assets/core.png",

    -- Planets (Kenney high-res celestial bodies)
    planet00      = "assets/planet00.png",
    planet01      = "assets/planet01.png",
    planet02      = "assets/planet02.png",
    planet03      = "assets/planet03.png",
    planet04      = "assets/planet04.png",
    planet05      = "assets/planet05.png",
    planet06      = "assets/planet06.png",
    planet07      = "assets/planet07.png",
    planet08      = "assets/planet08.png",
    planet09      = "assets/planet09.png",

    -- Asteroid Debris Variations
    asteroidSmallA = "assets/small-A.png",
    asteroidSmallB = "assets/small-B.png",
    asteroidMedA   = "assets/medium-A.png",
    asteroidMedB   = "assets/medium-B.png",
    asteroidLargeA = "assets/large-A.png",
    asteroidLargeB = "assets/large-B.png",

    -- Drones & Companion Pets
    pet1          = "assets/pet 1.png",
    pet2          = "assets/pet 2.png",
    pet3          = "assets/pet 3.png",
    support       = "assets/support.png",
}

function Assets.load()
    if Assets._loaded then return end

    for key, path in pairs(IMAGE_REGISTRY) do
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("linear", "linear")
            Assets.images[key] = img
        else
            Assets.images[key] = nil
        end
    end

    local fontPath = "assets/font.ttf"
    local okSmall, fSmall = pcall(love.graphics.newFont, fontPath, 13)
    local okMed, fMed = pcall(love.graphics.newFont, fontPath, 18)
    local okLarge, fLarge = pcall(love.graphics.newFont, fontPath, 24)
    local okHuge, fHuge = pcall(love.graphics.newFont, fontPath, 42)

    Assets.fonts.small  = (okSmall and fSmall) or love.graphics.newFont(13)
    Assets.fonts.medium = (okMed and fMed) or love.graphics.newFont(18)
    Assets.fonts.large  = (okLarge and fLarge) or love.graphics.newFont(24)
    Assets.fonts.huge   = (okHuge and fHuge) or love.graphics.newFont(42)

    Assets._loaded = true
end

function Assets.get(key)
    return Assets.images[key]
end

function Assets.draw(key, x, y, w, h, rot)
    local img = Assets.images[key]
    if img then
        local sx = (w or img:getWidth()) / img:getWidth()
        local sy = (h or img:getHeight()) / img:getHeight()
        love.graphics.draw(img, x, y, rot or 0, sx, sy, img:getWidth()/2, img:getHeight()/2)
    else
        love.graphics.rectangle("fill", x - (w or 16)/2, y - (h or 16)/2, w or 16, h or 16)
    end
end

return Assets
