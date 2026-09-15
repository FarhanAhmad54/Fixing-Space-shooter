-- Starfall Vengeance — LÖVE 11.5 configuration.
-- Portal-safe defaults: 16:9, resizable, minimal modules, DPR 1.

function love.conf(t)
    print("[STARFALL] conf.lua executed")
    t.identity = "starfall_vengeance"
    t.version = (love._version_major and love._version_minor) and (love._version_major .. "." .. love._version_minor) or nil
    t.console = false

    t.window.title = "Starfall Vengeance"
    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.resizable = true
    t.window.vsync = 1
    t.window.highdpi = false
    t.window.borderless = false

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = true
    t.modules.video = false
    t.modules.window = true
end
