--[[
  Lazy, fault-isolated hook registration.
  Game classes load only when first needed (e.g. NPCs when you land), so every
  hook waits until its UFunction exists, then registers. If the function object
  is replaced (class reloaded), the hook is registered again.
  A callback that keeps throwing Lua errors is switched off instead of
  spamming or breaking gameplay; the rest of the mod keeps working.

  UE4SS 3.0 facts for Blueprint functions (verified in game):
    - the callback runs AFTER the Blueprint body;
    - writing an OUT parameter with :set() changes what the caller receives.
]]

local U = require("htr.util")

local H = { list = {}, missing = {} }
local MAX_ERRORS = 25

function H.add(path, fn, tag)
    local h = { path = path, fn = fn, tag = tag or path, errors = 0, disabled = false, addr = nil }
    h.cb = function(...)
        if h.disabled or HTR_DISABLED then return end
        local ok, err = pcall(h.fn, ...)
        if not ok then
            h.errors = h.errors + 1
            if h.errors <= 3 then U.warn("error in " .. h.tag .. ": " .. tostring(err)) end
            if h.errors >= MAX_ERRORS then
                h.disabled = true
                U.warn("hook " .. h.tag .. " disabled after repeated errors")
            end
        end
    end
    H.list[#H.list + 1] = h
end

-- Call on the game thread.
function H.poll()
    for _, h in ipairs(H.list) do
        local fnObj = StaticFindObject(h.path)
        if fnObj and fnObj:IsValid() then
            local a = fnObj:GetAddress()
            if h.addr ~= a then
                local ok, err = pcall(RegisterHook, h.path, h.cb)
                if ok then
                    h.addr = a
                    U.log("hooked " .. h.tag)
                elseif not H.missing[h.path] then
                    H.missing[h.path] = true
                    U.warn("could not hook " .. h.path .. ": " .. tostring(err))
                end
            end
        end
    end
end

function H.status()
    local on, off = 0, 0
    for _, h in ipairs(H.list) do if h.addr and not h.disabled then on = on + 1 else off = off + 1 end end
    return on, off
end

return H
