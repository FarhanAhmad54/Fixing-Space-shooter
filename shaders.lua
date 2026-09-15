-- shaders.lua — GLSL post-processing & visual juice shaders.
-- Wrapped in pcall so any platform / WebGL driver incompatibility degrades gracefully.

local Shaders = {}
Shaders.enabled = true
Shaders._chromaShader = nil
Shaders._shockwaveShader = nil
Shaders._bloomShader = nil

-- Chromatic aberration + subtle scanline / vignette
local CHROMA_CODE = [[
extern number u_aberration;
extern vec2 u_resolution;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (u_aberration <= 0.001) {
        return Texel(tex, tc) * color;
    }
    vec2 dir = tc - vec2(0.5);
    float dist = length(dir);
    vec2 offset = dir * (dist * u_aberration);

    float r = Texel(tex, tc - offset).r;
    float g = Texel(tex, tc).g;
    float b = Texel(tex, tc + offset).b;
    float a = Texel(tex, tc).a;

    return vec4(r, g, b, a) * color;
}
]]

-- Shockwave / ripple distortion
local SHOCKWAVE_CODE = [[
extern vec2 u_center;
extern number u_time;
extern number u_progress;
extern number u_strength;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (u_progress <= 0.0 || u_progress >= 1.0) {
        return Texel(tex, tc) * color;
    }
    vec2 dir = tc - u_center;
    float dist = length(dir);
    float waveRadius = u_progress * 0.55;
    float diff = dist - waveRadius;

    if (abs(diff) < 0.06) {
        float factor = sin(diff / 0.06 * 3.14159) * (1.0 - u_progress) * u_strength;
        vec2 newTc = tc + normalize(dir) * factor;
        return Texel(tex, newTc) * color;
    }
    return Texel(tex, tc) * color;
}
]]

function Shaders.init()
    if not love.graphics.isSupported or not love.graphics.isSupported("shader") then
        Shaders.enabled = false
        return
    end

    local ok1, s1 = pcall(love.graphics.newShader, CHROMA_CODE)
    if ok1 and s1 then
        Shaders._chromaShader = s1
    end

    local ok2, s2 = pcall(love.graphics.newShader, SHOCKWAVE_CODE)
    if ok2 and s2 then
        Shaders._shockwaveShader = s2
    end
end

function Shaders.getChromaShader(intensity)
    if not Shaders.enabled or not Shaders._chromaShader then return nil end
    local s = Shaders._chromaShader
    pcall(s.send, s, "u_aberration", intensity or 0.005)
    return s
end

function Shaders.getShockwaveShader(cx, cy, progress, strength)
    if not Shaders.enabled or not Shaders._shockwaveShader then return nil end
    local s = Shaders._shockwaveShader
    pcall(s.send, s, "u_center", { cx or 0.5, cy or 0.5 })
    pcall(s.send, s, "u_progress", progress or 0.0)
    pcall(s.send, s, "u_strength", strength or 0.03)
    return s
end

return Shaders
