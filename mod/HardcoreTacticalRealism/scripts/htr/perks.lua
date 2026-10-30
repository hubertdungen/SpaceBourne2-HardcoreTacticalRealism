--[[
  Slow perks (on foot). With realistic damage, perks such as turrets, barricades, ground
  slam, shields or slow-time turn into super powers. This makes the suit's perk energy
  refill and the turret / barricade / ground-slam / auto-revive cooldowns run slower, so
  perks stay a tactical tool. Ship energy is separate and untouched.

  The game refills on-foot perk energy (CurrentEnergy += EnergyRegenRate) and advances
  those cooldowns (+0.25 s) in the player's ALS_Base:Regenerators timer, every 0.25 s.
  HTR scales the regen rate the game computed from your stats (it recomputes it when your
  gear changes; any value HTR did not write itself is taken as the new base) and trims
  each cooldown step.
]]

local U = require("htr.util")
local G = require("htr.gamedefs")

local PK = { addr = nil, base = nil, written = nil, cd = {}, other = {}, nOther = 0 }

local function settings() return HTR.cfg.Perks end
local function slow() return HTR.perksSlow == true end

-- Is `p` the player? Cached per address (other ALS_Base actors are rare, but cheap to skip).
local function isPlayer(p, a)
    if a == PK.addr then return true end
    if PK.other[a] then return false end
    if G.PlayerClassNames[U.className(p) or ""] then
        PK.addr, PK.base, PK.written, PK.cd = a, nil, nil, {} -- new pawn (level load, respawn)
        return true
    end
    if PK.nOther > 200 then PK.other, PK.nOther = {}, 0 end
    PK.other[a], PK.nOther = true, PK.nOther + 1
    return false
end

-- Hook: ALS_Base:Regenerators (player perk timer, 0.25 s)
function PK.onRegen(self)
    local p = self:get()
    local a = U.addr(p)
    if not (a and isPlayer(p, a)) then return end
    local s = settings()
    local fe = slow() and s.EnergyRegen or 1.0
    local fc = slow() and s.Cooldown or 1.0

    local r = U.get(p, G.P.EnergyRegen, nil)
    if type(r) == "number" then
        if PK.written == nil or math.abs(r - PK.written) > 1e-5 then PK.base = r end
        local want = PK.base * fe
        if math.abs(r - want) > 1e-5 then U.set(p, G.P.EnergyRegen, want) end
        PK.written = want
    end

    for _, name in ipairs(G.CooldownPerks) do
        local ok, v = pcall(function() return p[name][G.P.PerkCooldown] end)
        if ok and type(v) == "number" then
            local last = PK.cd[name]
            -- one timer step is +0.25 s; a reset to 0 (perk used) or a jump is left alone
            if fc < 1 and last and v > last and v - last <= 0.3 then
                v = last + (v - last) * fc
                pcall(function() p[name][G.P.PerkCooldown] = v end)
            end
            PK.cd[name] = v
        end
    end
end

return PK
