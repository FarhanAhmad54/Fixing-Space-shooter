-- portal.lua — Production runtime portal SDK bridge from Lua.
--
-- Supports:
-- 1. Direct standard stdout protocol ("[PORTAL]:<cmd>:<arg>") intercepted by
--    the browser host's Module.print handler for 100% reliable WebAssembly IPC.
-- 2. Emscripten virtual filesystem response tracking ("portal_reward.txt") for
--    immediate rewarded ad grant callbacks without relying on LuaJIT FFI.
-- 3. LuaJIT FFI fallback if available.
-- 4. Native desktop auto-simulation fallback.

local Portal = {}

local isWeb = (love.system and love.system.getOS and love.system.getOS() == "Web")
local emit = nil
local evalInt = nil

do
    local ok, ffi = pcall(require, "ffi")
    if ok and ffi then
        pcall(ffi.cdef, [[
            void emscripten_run_script(const char *script);
            int emscripten_run_script_int(const char *script);
        ]])
        local okSym, fn = pcall(function() return ffi.C.emscripten_run_script end)
        if okSym and fn then
            emit = function(code)
                pcall(fn, code)
            end
        end
        local okSymInt, fnInt = pcall(function() return ffi.C.emscripten_run_script_int end)
        if okSymInt and fnInt then
            evalInt = function(code)
                local ok_c, val = pcall(fnInt, code)
                return ok_c and val or 0
            end
        end
    end
end

Portal.available = true

local function jsString(s)
    if s == nil then return '""' end
    if type(s) == "number" then return tostring(s) end
    local t = tostring(s)
    t = t:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
    return '"' .. t .. '"'
end

local initialized = false

local function call(name, arg)
    local argStr = (arg == nil) and "" or tostring(arg)

    -- Primary: Emit structured print for web Module.print interception
    print(string.format("[PORTAL]:%s:%s", name, argStr))

    -- Secondary: FFI call if Emscripten C runtime is bound
    if emit then
        local code = string.format(
            "if(window.StarfallPlatform&&typeof window.StarfallPlatform.%s==='function'){window.StarfallPlatform.%s(%s);}",
            name, name, jsString(arg)
        )
        pcall(emit, code)
    end
end

function Portal.init()
    if initialized then return end
    initialized = true
    if love.filesystem and love.filesystem.getSaveDirectory then
        local saveDir = love.filesystem.getSaveDirectory()
        call("init", saveDir)
    else
        call("init", "")
    end
end

function Portal.loadingStart()
    Portal.init()
    call("loadingStart")
end

function Portal.loadingFinished()
    Portal.init()
    call("loadingFinished")
end

function Portal.gameplayStart()
    Portal.init()
    call("gameplayStart")
end

function Portal.gameplayStop()
    Portal.init()
    call("gameplayStop")
end

function Portal.happytime()
    Portal.init()
    call("happytime")
end

function Portal.commercialBreak()
    Portal.init()
    call("commercialBreak")
end

local activeRewardType = nil
local lastHandledNonce = 0
local desktopSimulateTimer = 0

function Portal.rewardedBreak(rewardType)
    Portal.init()
    activeRewardType = rewardType or "default"
    call("rewardedBreak", activeRewardType)
    if not isWeb and not evalInt then
        desktopSimulateTimer = 0.5 -- 0.5s simulated delay for desktop
    end
end

function Portal.pollReward(dt)
    -- 1. Check virtual filesystem signal written by JavaScript platform-bridge
    if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("portal_reward.txt") then
        local ok, content = pcall(love.filesystem.read, "portal_reward.txt")
        if ok and content and content ~= "" then
            local nonce, succ, rType = content:match("^(%d+):([01]):([%w_ -]+)")
            nonce = tonumber(nonce)
            if nonce and nonce > lastHandledNonce then
                lastHandledNonce = nonce
                pcall(love.filesystem.remove, "portal_reward.txt")
                local success = (succ == "1")
                activeRewardType = nil
                return success, rType
            end
        end
    end

    -- 2. Check FFI evalInt if present
    if evalInt then
        local currentNonce = evalInt("window.StarfallPlatform ? window.StarfallPlatform.lastRewardNonce : 0")
        if currentNonce > lastHandledNonce then
            lastHandledNonce = currentNonce
            local success = evalInt("window.StarfallPlatform.lastRewardSuccess ? 1 : 0") == 1
            local rType = activeRewardType
            activeRewardType = nil
            return success, rType
        end
    end

    -- 3. Native desktop fallback simulation
    if activeRewardType and not isWeb and not evalInt then
        desktopSimulateTimer = desktopSimulateTimer - (dt or 0.016)
        if desktopSimulateTimer <= 0 then
            local t = activeRewardType
            activeRewardType = nil
            return true, t
        end
    end

    return nil, nil
end

function Portal.ready()
    Portal.init()
    call("ready")
end

return Portal
