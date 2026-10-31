--[[
  Not always dead (0.4.9). A lethal hit sometimes knocks the victim out instead (chance per
  mode, Knockout in config); never on a headshot, a big explosion or heavy overkill. Someone
  can reach the body and bring them back; if nobody does in time, they bleed out.

  - Squad soldiers: the game's own injured state (its medics and your "hold to revive" work as
    before); HTR sets the chance per mode and lengthens the bleed-out.
  - Gun NPCs (enemies, companions): kept alive at 1 HP, ragdolled, AI stopped. Who comes depends
    on training: elites fast and reliably, regulars slower, militia and pirates rarely and may
    give up under fire; robots are never knocked out.
  - You: HP stays at 1, you lie on the ground, no damage while down; the nearest squad medic,
    else any squad soldier or companion comes for you (medics fastest).

  Downed NPCs are kept by address; their object is checked (IsValid + same address) before use.
]]

local U = require("htr.util")
local KO = { down = {}, soldiers = {} }

-- try = chance to attempt, time = s at the body, success = chance it works, quit = gives up under fire
KO.REVIVE = {
    medic     = { try = 1.0,  time = 6,  success = 0.95 },
    soldier   = { try = 1.0,  time = 12, success = 0.75 },
    companion = { try = 1.0,  time = 8,  success = 0.9 },
    elite     = { try = 1.0,  time = 7,  success = 0.9 },
    regular   = { try = 0.7,  time = 11, success = 0.75 },
    militia   = { try = 0.35, time = 14, success = 0.55, quit = 0.3 },
    pirate    = { try = 0.3,  time = 15, success = 0.5,  quit = 0.35 },
}
local REACH, SEARCH = 300, 2500 -- cm: at the body (squad soldiers stop ~2-3 m short) / how far a reviver comes from

local function cfg() return HTR.cfg.Knockout end
function KO.enabled() return cfg().Enabled ~= false end
function KO.bleedOut() return cfg().BleedOutSeconds or 45 end

-- Does this lethal hit knock out instead of kill? overkill = damage beyond the HP left / max HP.
function KO.roll(zone, overkill, explosion)
    if not KO.enabled() or zone == "head" or explosion then return false end
    if overkill > (cfg().OverkillPercent or 50) / 100 then return false end
    return math.random() < ((cfg().Chance or {})[HTR.mode] or 0)
end

local function same(o, a) return U.valid(o) and U.addr(o) == a end
local function brain(npc, on)
    pcall(function()
        local b = npc.Controller.BrainComponent
        if on then b:RestartLogic() else b:StopLogic("HTR knocked out") end
    end)
end
local function moveTo(pawn, pos)
    pcall(function() pawn.Controller:MoveToLocation({ X = pos.X, Y = pos.Y, Z = pos.Z }, 60.0, true, true, true, true, nil, true) end)
end
local function underFire(st, now) return st and now - (st.hitT or -1e9) < 2 end

-- Nobody goes in under fire: the area round the body must be clear of live hostiles (15 m).
local CLEAR = 1500
local function safe(pos, side, near, now)
    for _, e in ipairs(near(pos, CLEAR)) do
        local s = e.st.side
        if s ~= side and s ~= "other" and not e.st.down then return false end
    end
    if side ~= "ally" then -- an enemy body: you and your squad count as hostiles
        if HTR.playerPos and U.dist(pos, HTR.playerPos) < CLEAR then return false end
        for _, s in pairs(KO.soldiers) do
            if now - s.t < 4 and s.side == "ally" and U.dist(pos, s.pos) < CLEAR then return false end
        end
    end
    return true
end

-- One reviver per body. A body: { pos, side, rev = addr, revSt, r = REVIVE row, at = s spent, tried = {} }
local function assign(body, cands)
    local best
    for _, c in ipairs(cands) do
        if not body.tried[c.a] and c.side == body.side and not c.busy then
            body.tried[c.a] = true
            if c.r and math.random() < c.r.try and (not best or c.d < best.d) then best = c end
        end
    end
    if best then
        body.rev, body.revSt, body.r, body.at = best.a, best.st, best.r, 0
        if best.st then best.st.reviving = body.key end
    end
end

-- Progress of a body's reviver; returns true when the revive succeeded. dist = reviver distance or nil.
local function progress(body, dist, now, dt)
    if not dist then body.rev = nil; return false end -- reviver gone
    if not body.safe or dist > REACH then return false end
    if underFire(body.revSt, now) then
        if body.r.quit and math.random() < body.r.quit then
            if body.revSt then body.revSt.reviving = nil end
            body.rev = nil
        end
        return false
    end
    body.at = body.at + dt
    if body.at < body.r.time then return false end
    if math.random() < body.r.success then return true end
    if body.revSt then body.revSt.reviving = nil end
    body.rev, body.at = nil, 0 -- failed: someone else may try
    return false
end

-- Candidates near pos from npc.lua's registry (gun NPCs) and the squad registry.
local function candidates(pos, near, now, withSoldiers)
    local out = {}
    for _, e in ipairs(near(pos, SEARCH)) do
        local st = e.st
        if not st.down and not st.robot then
            local r = KO.REVIVE[st.doctrine] or (st.side == "ally" and KO.REVIVE.companion)
            out[#out + 1] = { a = e.a, st = st, side = st.side, d = e.d, r = r, busy = st.reviving ~= nil }
        end
    end
    if withSoldiers then
        for a, s in pairs(KO.soldiers) do
            if now - s.t < 4 and s.side == "ally" then
                local d = U.dist(pos, s.pos)
                if d < SEARCH then
                    out[#out + 1] = { a = a, side = "ally", d = s.medic and d * 0.25 or d, -- medics first
                        r = s.medic and KO.REVIVE.medic or KO.REVIVE.soldier, busy = s.reviving ~= nil, soldier = s }
                end
            end
        end
    end
    return out
end
local function distOf(a, pos, near)
    local s = KO.soldiers[a]
    if s then return U.dist(pos, s.pos) end
    for _, e in ipairs(near(pos, SEARCH)) do if e.a == a then return e.d end end
    return nil
end

-- Gun NPC knocked out (from its CalculateDamage hook; HTR already set the hit to leave 1 HP).
function KO.downShooter(npc, st, now)
    local a = U.addr(npc)
    if not a then return end
    st.down = true
    pcall(function() npc:StopShoot() end)
    brain(npc, false)
    pcall(function() npc:RagdollStart() end)
    KO.down[a] = { key = a, obj = npc, st = st, side = st.side, pos = U.location(npc),
        untilT = now + KO.bleedOut(), at = 0, tried = {} }
end

-- Once a second on the game thread. near = npc.lua's registry lookup.
function KO.update(now, dt, near)
    for a, b in pairs(KO.down) do
        local npc = b.obj
        if not same(npc, a) or U.get(npc, "NPCDead", false) then
            KO.down[a] = nil -- died for good or gone
        elseif now >= b.untilT then
            KO.down[a] = nil
            pcall(function() npc:ForceToDead() end) -- bled out
        else
            b.safe = safe(b.pos, b.side, near, now)
            if not b.rev then assign(b, candidates(b.pos, near, now, b.side == "ally")) end
            if b.rev and progress(b, distOf(b.rev, b.pos, near), now, dt) then
                KO.down[a] = nil
                if b.revSt then b.revSt.reviving = nil end
                pcall(function() npc:RagdollEnd() end)
                brain(npc, true)
                U.set(npc, "CurrentHP", U.get(npc, "MaxHP", 100) * 0.2)
                if b.st then b.st.down = nil end
            end
        end
    end
end

-- From a living gun NPC's own hook: a reviver walks to its body with its AI paused.
function KO.drive(npc, st)
    local b = st.reviving and (KO.down[st.reviving] or (KO.player and KO.player.key == st.reviving and KO.player))
    if b and b.rev and b.safe then
        if not st.reviveMoving then st.reviveMoving = true; brain(npc, false) end
        moveTo(npc, b.pos)
    elseif b and b.rev then -- not clear yet: keep fighting from where it is
        if st.reviveMoving then st.reviveMoving = nil; brain(npc, true) end
    else
        st.reviving = nil
        if st.reviveMoving then st.reviveMoving = nil; brain(npc, true) end
    end
end

-- Squad soldiers report themselves (their 1.5 s update); a reviver walks to you.
function KO.soldier(sol, a, now, side)
    local s = KO.soldiers[a] or {}
    KO.soldiers[a] = s
    s.pos, s.t, s.side = U.location(sol), now, side
    s.medic = U.get(sol, "SoldierType", 0) == 2
    local b = KO.player
    if b and b.rev == a then s.reviving = true; if b.safe then moveTo(sol, b.pos) end else s.reviving = nil end
end

-- Squad soldier down (its 1 s InjuredTime timer): the game's bleed-out is ~21 s; HTR holds it until BleedOutSeconds.
function KO.soldierInjured(sol, a, now)
    local s = KO.soldiers[a] or {}
    KO.soldiers[a] = s
    s.downAt = (s.downAt and now - s.downAt < KO.bleedOut() + 5) and s.downAt or now
    if now - s.downAt < KO.bleedOut() and U.get(sol, "InjuredSec", 0) > 15 then U.set(sol, "InjuredSec", 15) end
end

-- You: knocked out (from HTR's lethal hand-off). Returns true when knocked out.
function KO.downPlayer(p, now)
    U.set(p, "CurrentHP", 1.0)
    U.set(p, "ResurectUsed", true) -- the game ignores damage while this is set
    U.set(p, "DisableMove", true); U.set(p, "DisableJump?", true); U.set(p, "Injured?", true)
    pcall(function() p:RagdollStart() end)
    KO.player = { key = "player", side = "ally", pos = U.location(p), untilT = now + KO.bleedOut(), at = 0, tried = {} }
    return true
end

-- Your downed state, from the player tick (0.25 s). Returns "revived", "bledout" or nil.
function KO.updatePlayer(p, now, dt, near)
    local b = KO.player
    if not b then return nil end
    U.set(p, "ResurectUsed", true)
    U.set(p, "CurrentHP", 1.0); U.set(p, "HPRecoverRate", 0.0) -- no healing while down (HTR's regen resumes after)
    b.pos = U.location(p) or b.pos
    if now >= b.untilT then KO.player = nil; KO.standUp(p, false); return "bledout" end
    if now >= (b.safeAt or 0) then b.safeAt = now + 1; b.safe = safe(b.pos, "ally", near, now) end
    if not b.rev then
        assign(b, candidates(b.pos, near, now, true))
        if b.rev and not b.announced then
            b.announced = true
            return b.r == KO.REVIVE.medic and "medic" or "help"
        end
    end
    if b.rev and progress(b, distOf(b.rev, b.pos, near), now, dt) then
        KO.player = nil
        if b.revSt then b.revSt.reviving = nil end
        KO.standUp(p, true)
        return "revived"
    end
    return nil
end

function KO.standUp(p, revived)
    U.set(p, "DisableMove", false); U.set(p, "DisableJump?", false); U.set(p, "Injured?", false)
    if revived then
        pcall(function() p:RagdollEnd() end)
        U.set(p, "CurrentHP", U.get(p, "MaxHP", 100) * 0.25)
    end
    U.set(p, "ResurectUsed", false)
end

return KO
