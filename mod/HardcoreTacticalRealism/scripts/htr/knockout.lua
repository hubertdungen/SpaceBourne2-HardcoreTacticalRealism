--[[
  Not always dead (0.4.9). A lethal hit sometimes knocks the victim out instead (chance per
  mode, Knockout in config); never on a headshot, a big explosion or heavy overkill. Someone
  can reach the body and bring them back; if nobody does in time, they bleed out.
  Blood loss (0.4.15): bleeding to zero always knocks out instead of killing - you, squad
  soldiers, companions and enemies; robots never bleed and bosses still die.

  - Squad soldiers: the game's own injured state (its medics and your "hold to revive" work as
    before); HTR sets the chance per mode and lengthens the bleed-out.
  - Gun NPCs (enemies, companions): kept alive at 1 HP, ragdolled, AI stopped. Who comes depends
    on training: elites fast and reliably, regulars slower, militia and pirates rarely and may
    give up under fire; robots are never knocked out. You revive a downed companion by
    crouching next to it.
  - You: HP stays at 1, you lie on the ground; the nearest squad medic, else any squad soldier
    or companion comes for you (medics fastest).
  - While down only you, pirates and explosions can kill: pirates walk up and finish off anyone
    of your side who is down; the big factions' troops leave the downed on the ground.
  - A revive stops the bleeding and brings the person back at RevivedHP; broken bones stay.

  Downed NPCs are kept by address; their object is checked (IsValid + same address) before use.
]]

local U = require("htr.util")
local W = require("htr.wounds")
local KO = { down = {}, soldiers = {}, injured = {} }

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
local REVIVE_WALK = 15 -- s of clear ground: a reviver not at the body by then gives up (its AI comes back on)
-- pirates within 15 m stop, turn to the body and fire after 1 s, from where they stand (walking
-- them over was tried in 0.4.15 tests: NPCs did not follow a move order); after 8 s the body dies
-- regardless (in case the pirate's own hook never runs)
local EXEC_SEE, EXEC_AIM, EXEC_GIVE = 1500, 1.0, 8
local YOU_REACH = 250 -- cm: you revive a companion this close, crouched

local function cfg() return HTR.cfg.Knockout end
function KO.enabled() return cfg().Enabled ~= false end
function KO.bleedOut() return cfg().BleedOutSeconds or 45 end
local function revivedHP() return cfg().RevivedHP or 0.25 end

-- Does this lethal hit knock out instead of kill? overkill = damage beyond the HP left / max HP.
function KO.roll(zone, overkill, explosion)
    if not KO.enabled() or zone == "head" or explosion then return false end
    if overkill > (cfg().OverkillPercent or 50) / 100 then return false end
    return math.random() < ((cfg().Chance or {})[HTR.mode] or 0)
end

-- Blood loss knocks out instead of killing (0.4.15). st = npc.lua state (nil for you).
function KO.bleedOutKnocksOut(st)
    if not KO.enabled() or cfg().BleedOut == false then return false end
    return not (st and (st.robot or st.boss or st.doctrine == "machine"))
end

-- May this hit kill someone who is down? You decide for yourself; pirates always finish off;
-- the big factions' troops leave the downed on the ground. Explosions are handled by the caller.
function KO.killsDowned(aside, pirate)
    if not KO.enabled() then return true end
    return aside == "player" or (pirate == true and cfg().PiratesFinishOff ~= false)
end

local function same(o, a) return U.valid(o) and U.addr(o) == a end
local function brain(npc, on)
    pcall(function()
        local b = npc.Controller.BrainComponent
        if on then b:RestartLogic() else b:StopLogic("HTR knocked out") end
    end)
end
-- Walk an AI pawn to pos. 0.4.16: AIBlueprintHelperLibrary.SimpleMoveToLocation first (no class
-- parameter); 0.4.9-0.4.15 only called MoveToLocation with a nil filter class inside pcall, and NPCs
-- never moved in the 0.4.15 tests.
local AIBL
local function moveTo(pawn, pos)
    local dest = { X = pos.X, Y = pos.Y, Z = pos.Z }
    local ok = pcall(function()
        if not (AIBL and AIBL:IsValid()) then AIBL = StaticFindObject("/Script/AIModule.Default__AIBlueprintHelperLibrary") end
        AIBL:SimpleMoveToLocation(pawn.Controller, dest)
    end)
    if not ok then pcall(function() pawn.Controller:MoveToLocation(dest, 60.0, true, true, true, true, nil, true) end) end
end
local function underFire(st, now) return st and now - (st.hitT or -1e9) < 2 end

-- Nobody goes in under fire: the area round the body must be clear of live hostiles (15 m; round
-- you 8 m, 0.4.16). Still unsafe 10 s after you went down: your rescue becomes urgent and the
-- reviver comes anyway, a medic first (user's choice, 2026-11-12).
local CLEAR, CLEAR_YOU, BRAVE_AFTER = 1500, 800, 10
local function safe(pos, side, near, now, radius)
    for _, e in ipairs(near(pos, radius or CLEAR)) do
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
local function clear(body) return body.safe or body.brave end -- a reviver may go in

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
        body.rev, body.revSt, body.r, body.at, body.walk = best.a, best.st, best.r, 0, 0
        if best.st then best.st.reviving = body.key end
    end
end

-- Progress of a body's reviver; returns true when the revive succeeded. dist = reviver distance or nil.
local function progress(body, dist, now, dt)
    if not dist then body.rev = nil; return false end -- reviver gone
    if not clear(body) then return false end
    if dist > REACH then -- on its way; one that can't get there gives up (never a stalled NPC)
        body.walk = (body.walk or 0) + dt
        if body.walk > REVIVE_WALK then
            if body.revSt then body.revSt.reviving = nil end
            body.rev = nil
        end
        return false
    end
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
        if not st.down and not st.robot and not st.executing then
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

-- Pirates finish off the downed of your side (sides are relative to you). One pirate per body;
-- it walks over with its AI paused (KO.drive) and fires; returns true once it has fired.
local function bodyOf(key)
    if KO.player and KO.player.key == key then return KO.player end
    return KO.down[key] or KO.injured[key]
end
local function executed(body, near)
    if body.side ~= "ally" or cfg().PiratesFinishOff == false then return false end
    if body.execDone then return true end
    if body.exec then
        for _, e in ipairs(near(body.pos, EXEC_SEE)) do
            if e.a == body.exec and not e.st.down then -- still on its way (KO.drive fires)
                if os.clock() - (body.execT or 0) < EXEC_GIVE then return false end
                body.execDone = true -- its own hook never fired: the body dies anyway
                return true
            end
        end
        body.exec = nil -- gone, down or dead
    end
    local best
    for _, e in ipairs(near(body.pos, EXEC_SEE)) do
        local st = e.st
        if st.doctrine == "pirate" and st.side == "enemy" and not st.down and not st.executing and not st.reviving
            and (not best or e.d < best.d) then best = e end
    end
    if best then body.exec, body.execT = best.a, os.clock(); best.st.executing = body.key end
    return false
end
local function releaseExec(body)
    body.exec, body.execDone, body.execT = nil, nil, nil -- the pirate's own hook (KO.drive) restarts its AI
end

-- Gun NPC back on its feet (by an NPC reviver or by you).
local function reviveNPC(b)
    local npc = b.obj
    if b.revSt then b.revSt.reviving = nil end
    releaseExec(b)
    pcall(function() npc:RagdollEnd() end)
    brain(npc, true)
    U.set(npc, "CurrentHP", U.get(npc, "MaxHP", 100) * revivedHP())
    W.stanch(b.key) -- the revive stops the bleeding; broken bones stay
    if b.st then b.st.down = nil end
end

-- Gun NPC knocked out (from its CalculateDamage hook, or its think hook on blood loss; HP is 1).
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

-- Arrival somewhere new (elevator, new floor, level load): drop every downed NPC without touching
-- it - their objects may already be destroyed (calling into a freed object can crash the game).
-- They stay down and bleed out through their own hook (npc.lua onThink, koUntil): before 0.4.13
-- they kept their AI switched off and never got up again ("scarecrows").
function KO.forget(keepPlayer)
    for _, b in pairs(KO.down) do if b.st then b.st.koUntil = b.untilT end end
    KO.down, KO.soldiers, KO.injured, KO.you = {}, {}, {}, nil
    if KO.player then releaseExec(KO.player) end
    if not keepPlayer then KO.player = nil end -- a new pawn is never down
end

-- Once a second on the game thread. near = npc.lua's registry lookup.
function KO.update(now, dt, near)
    for a, b in pairs(KO.down) do
        local npc = b.obj
        if not same(npc, a) or U.get(npc, "NPCDead", false) then
            KO.down[a] = nil -- died for good or gone
        elseif now >= b.untilT or executed(b, near) then
            KO.down[a] = nil
            if b.revSt then b.revSt.reviving = nil end
            releaseExec(b)
            pcall(function() npc:ForceToDead() end) -- bled out, or a pirate finished it off
        else
            b.safe = safe(b.pos, b.side, near, now)
            if not b.rev then assign(b, candidates(b.pos, near, now, b.side == "ally")) end
            if b.rev and progress(b, distOf(b.rev, b.pos, near), now, dt) then
                KO.down[a] = nil
                reviveNPC(b)
            end
        end
    end
    -- your squad soldiers lying in the game's injured state: pirates finish them off too
    for a, s in pairs(KO.injured) do
        if now - s.t > 3 or not same(s.obj, a) or not U.get(s.obj, "InInjuredMode", false) then
            KO.injured[a] = nil; releaseExec(s) -- revived, dead or gone
        elseif executed(s, near) then
            KO.injured[a] = nil; releaseExec(s)
            pcall(function() s.obj:Deaded() end)
        end
    end
end
function KO.busy() return next(KO.down) ~= nil or next(KO.injured) ~= nil end

-- From a living gun NPC's own hook: a reviver walks to its body with its AI paused; a pirate
-- going to finish someone off walks over too, turns to the body and fires.
function KO.drive(npc, st)
    if st.executing then
        local b = bodyOf(st.executing)
        if b and b.exec == U.addr(npc) and not b.execDone then
            if not st.reviveMoving then -- stop where it is (AI paused, no move order of its own)
                st.reviveMoving = true; brain(npc, false)
                pcall(function() npc.Controller:StopMovement() end)
            end
            local here = U.location(npc)
            local now = os.clock()
            st.execAt = st.execAt or now + EXEC_AIM
            if here then
                pcall(function()
                    local yaw = math.deg(math.atan(b.pos.Y - here.Y, b.pos.X - here.X))
                    npc:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, false)
                end)
            end
            if now >= st.execAt then
                pcall(function() npc:StartShoot() end)
                b.execDone = true
            end
            return
        end
        st.executing, st.execAt = nil, nil -- done, or the body is gone
        if st.reviveMoving and not st.reviving then st.reviveMoving = nil; brain(npc, true) end
        return
    end
    local b = st.reviving and (KO.down[st.reviving] or (KO.player and KO.player.key == st.reviving and KO.player))
    if b and b.rev and clear(b) then
        if not st.reviveMoving then st.reviveMoving = true; brain(npc, false) end
        moveTo(npc, b.pos)
    elseif b and b.rev then -- not clear yet: keep fighting from where it is
        if st.reviveMoving then st.reviveMoving = nil; brain(npc, true) end
    else
        st.reviving = nil
        if st.reviveMoving then st.reviveMoving = nil; brain(npc, true) end
    end
end

-- Squad soldiers report themselves (their 1.5 s update); a reviver walks to its body: you or a
-- downed companion (0.4.15: before, a soldier picked for a companion never came and blocked others).
function KO.soldier(sol, a, now, side)
    local s = KO.soldiers[a] or {}
    KO.soldiers[a] = s
    s.pos, s.t, s.side = U.location(sol), now, side
    s.medic = U.get(sol, "SoldierType", 0) == 2
    local b = KO.player and KO.player.rev == a and KO.player or nil
    if not b then
        for _, d in pairs(KO.down) do if d.rev == a then b = d; break end end
    end
    if b then s.reviving = true; if clear(b) then moveTo(sol, b.pos) end else s.reviving = nil end
end

-- Squad soldier down (its 1 s InjuredTime timer): the game's bleed-out is ~21 s; HTR holds it until BleedOutSeconds.
function KO.soldierInjured(sol, a, now, side)
    local s = KO.soldiers[a] or {}
    KO.soldiers[a] = s
    s.downAt = (s.downAt and now - s.downAt < KO.bleedOut() + 5) and s.downAt or now
    if now - s.downAt < KO.bleedOut() and U.get(sol, "InjuredSec", 0) > 15 then U.set(sol, "InjuredSec", 15) end
    local i = KO.injured[a] or { key = a, tried = {} }
    KO.injured[a] = i
    i.obj, i.side, i.t, i.pos = sol, side, now, U.location(sol) or i.pos
end

-- You: knocked out (from HTR's lethal hand-off). Returns true when knocked out.
function KO.downPlayer(p, now)
    U.set(p, "CurrentHP", 1.0)
    U.set(p, "ResurectUsed", true) -- the game ignores damage while this is set
    U.set(p, "DisableMove", true); U.set(p, "DisableJump?", true); U.set(p, "Injured?", true)
    pcall(function() p:RagdollStart() end)
    KO.player = { key = "player", side = "ally", pos = U.location(p), untilT = now + KO.bleedOut(), at = 0, tried = {}, downT = now }
    return true
end

-- "Rescue me" (0.4.16): another mod (Squad Tactics) asks for it by creating HTR's rescue.request
-- file (main.lua polls it); the rescue becomes urgent at once. You down = the pawn's Injured? flag.
function KO.requestRescue()
    local b = KO.player
    if not b then return false end
    b.brave, b.tried = true, {}
    return true
end

-- An explosion reached you while you are down (player.lua's radial hook): it kills.
function KO.blastPlayer() if KO.player then KO.player.blasted = true end end

-- Your downed state, from the player tick (0.25 s).
-- Returns "revived", "bledout", "finished" (a pirate), "blast", "medic", "help" or nil.
function KO.updatePlayer(p, now, dt, near)
    local b = KO.player
    if not b then return nil end
    U.set(p, "ResurectUsed", true)
    U.set(p, "CurrentHP", 1.0); U.set(p, "HPRecoverRate", 0.0) -- no healing while down (HTR's regen resumes after)
    b.pos = U.location(p) or b.pos
    local why = (now >= b.untilT and "bledout") or (b.blasted and "blast") or (executed(b, near) and "finished")
    if why then
        KO.player = nil
        if b.revSt then b.revSt.reviving = nil end
        releaseExec(b)
        KO.standUp(p, false) -- player.lua kills you on the next tick (0x268)
        return why
    end
    if now >= (b.safeAt or 0) then b.safeAt = now + 1; b.safe = safe(b.pos, "ally", near, now, CLEAR_YOU) end
    if not b.safe and not b.brave and now - (b.downT or now) >= BRAVE_AFTER then b.brave = true end
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
        releaseExec(b)
        KO.standUp(p, true)
        return "revived"
    end
    return nil
end

-- Also before any death while down: you never die while HTR still holds you ragdolled (a load
-- right after such a death crashed the game, 0x268; player.lua kills you on the next tick instead).
function KO.standUp(p, revived)
    U.set(p, "DisableMove", false); U.set(p, "DisableJump?", false); U.set(p, "Injured?", false)
    pcall(function() p:RagdollEnd() end)
    if revived then
        U.set(p, "CurrentHP", U.get(p, "MaxHP", 100) * revivedHP())
        W.stanch(U.addr(p))
    end
    U.set(p, "ResurectUsed", false)
end

-- You revive a downed companion: crouch next to it for PlayerReviveSeconds (a hit on you starts
-- over). From the player tick (0.25 s) while you are up. Returns "start", "done" or nil.
function KO.youRevive(p, pos, now, dt, hurtAt)
    if cfg().PlayerRevive == false or not next(KO.down) or not pos then KO.you = nil; return nil end
    local body
    if U.get(p, "Stance", 0) == 1 then -- crouched
        for _, b in pairs(KO.down) do
            if b.side == "ally" and b.pos and U.dist(pos, b.pos) < YOU_REACH then body = b; break end
        end
    end
    if not body then KO.you = nil; return nil end
    if not KO.you or KO.you.key ~= body.key then KO.you = { key = body.key, at = 0 }; return "start" end
    if now - (hurtAt or -1e9) < 1 then KO.you.at = 0; return nil end
    KO.you.at = KO.you.at + dt
    if KO.you.at < (cfg().PlayerReviveSeconds or 8) then return nil end
    KO.you = nil
    if not same(body.obj, body.key) or U.get(body.obj, "NPCDead", false) then KO.down[body.key] = nil; return nil end
    KO.down[body.key] = nil
    reviveNPC(body)
    return "done"
end

return KO
