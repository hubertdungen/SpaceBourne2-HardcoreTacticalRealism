--[[
  Wounds: bleeding and fractures (pure bookkeeping, no game calls).
  State is keyed by actor address and holds plain numbers only.

  A penetrating hit (most of the round got through the armor) can open a wound
  that bleeds a % of max HP per second for a while; nanotech clotting stops it
  on its own. Heavy limb hits can break an arm or leg.
]]

local W = { list = {} }

local ZONE = {
    torso   = { rate = 0.8, time = 20 },
    head    = { rate = 1.0, time = 15 },
    arm     = { rate = 0.5, time = 15 },
    leg     = { rate = 0.5, time = 15 },
    unknown = { rate = 0.6, time = 15 },
}
local MAX_WOUNDS = 3

-- Called for every hit. Returns "bleed" / "fracture" / nil (what is new).
-- noBleed: machines (robots) never bleed, but a heavy limb hit still wrecks the arm or leg.
function W.onHit(key, zone, hpPct, pass, t, scale, freq, noBleed)
    freq = freq or 1
    if not key or hpPct <= 0 then return nil end
    local s = W.list[key]
    if not s then s = { wounds = {} }; W.list[key] = s end
    local new = nil
    if (zone == "arm" or zone == "leg") and hpPct >= 25 and not W.fracture(key, t) and math.random() < freq then
        s.fracture, s.fractureUntil = zone, t + 60 -- nanites fuse the bone in about a minute
        new = "fracture"
    end
    if not noBleed and pass >= 0.5 and hpPct >= 12 then
        local chance = math.min(0.8, math.max(0.25, hpPct / 100)) * freq
        if math.random() < chance then
            local z = ZONE[zone] or ZONE.unknown
            local heavy = hpPct >= 40 and 1.6 or 1.0
            if #s.wounds >= MAX_WOUNDS then table.remove(s.wounds, 1) end
            s.wounds[#s.wounds + 1] = { rate = z.rate * heavy * (scale or 1), untilT = t + z.time }
            new = new or "bleed"
        end
    end
    return new
end

-- % of max HP lost over dt seconds; drops expired wounds.
function W.bleed(key, t, dt)
    local s = W.list[key]
    if not s or #s.wounds == 0 then return 0 end
    local total, keep = 0, {}
    for _, w in ipairs(s.wounds) do
        if t < w.untilT then
            total = total + w.rate * dt
            keep[#keep + 1] = w
        end
    end
    s.wounds = keep
    return total
end

-- Current bleeding rate: % of max HP per second (0 = not bleeding).
function W.rate(key, t)
    local s = W.list[key]
    if not s then return 0 end
    local r = 0
    for _, w in ipairs(s.wounds) do if t < w.untilT then r = r + w.rate end end
    return r
end

function W.isBleeding(key, t)
    local s = W.list[key]
    if not s then return false end
    for _, w in ipairs(s.wounds) do if t < w.untilT then return true end end
    return false
end

function W.fracture(key, t)
    local s = W.list[key]
    if not (s and s.fracture) then return nil end
    if t and s.fractureUntil and t > s.fractureUntil then s.fracture = nil; return nil end
    return s.fracture
end
function W.heal(key) W.list[key] = nil end

return W
