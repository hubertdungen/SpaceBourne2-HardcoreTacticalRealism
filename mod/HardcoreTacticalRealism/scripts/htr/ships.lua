--[[
  Ships vs infantry (toggle: F9 / ShipsVsInfantry).
  In vanilla, ship weapons do nothing to people on foot. With this on, every
  ship round that lands (your ship's guns and AI ships' guns) hits infantry:
  a direct hit kills almost anyone, and the blast hurts everyone close by,
  friends included.
]]

local U = require("htr.util")
local G = require("htr.gamedefs")
local B = require("htr.ballistics")
local C = require("htr.classify")
local P = G.P

local S = { positions = {} } -- infantry positions (numbers only), refreshed by NPC hooks

local function cfg() return HTR.cfg.Ships end

function S.track(npc)
    local a, l = U.addr(npc), U.location(npc)
    if a and l then S.positions[a] = { X = l.X, Y = l.Y, Z = l.Z, t = os.clock() } end
end

local function anyoneNear(center, radius)
    local now = os.clock()
    for a, p in pairs(S.positions) do
        if now - p.t > 10 then S.positions[a] = nil
        elseif U.dist(center, p) < radius + 600 then return true end
    end
    return false
end

-- Damage (% of body) for a target at distance d from the impact.
local function blastPct(d, direct, radius)
    local c = cfg()
    if direct then return c.DirectHitDamage end
    if d >= radius then return 0 end
    return c.SplashDamage * (1 - d / radius)
end

local function hurtShooter(N, npc, pct, impact, side)
    local st = N.ensure(npc)
    if not st then return end
    local f = HTR.sideMultiplier(st.side)
    if side == "ally" and st.side == "ally" and HTR.cfg.Features.FriendlyFireRules then
        f = f * HTR.ff(HTR.cfg.FriendlyFire.PlayerToAlly)
    end
    local hp = B.compute({ caliber = "ship", zone = "torso", armor = st.armor, hasHelmet = st.helmet,
        integrity = 1, vitality = st.vitality, minPct = 0, rnd = 0.5 })
    local loss = hp * (pct / B.Calibers.ship.dmg) / 100 * U.get(npc, P.MaxHP, 100) * f
    local left = U.get(npc, P.HP, 0) - loss
    U.set(npc, P.HP, math.max(0, left))
    if left <= 0 then
        U.set(npc, "Shotgun", true) -- gib
        U.set(npc, P.HeadShot, false)
        pcall(function() npc:ForceToDead() end)
    end
end

-- center: impact point; direct: actor hit (may be nil); side: "ally" (your ship / allied ships) or "enemy".
function S.blast(N, Pl, center, direct, side)
    if not (HTR.shipsOn and center) then return end
    local radius = cfg().SplashRadius
    local player = Pl.lastPos and U.dist(center, Pl.lastPos) < radius + 600
    if not (anyoneNear(center, radius) or player or direct) then return end
    local directAddr = direct and U.addr(direct)
    for _, npc in ipairs(N.allShooters()) do
        if U.valid(npc) and not U.get(npc, P.Dead, false) then
            local isDirect = (U.addr(npc) == directAddr)
            local d = U.dist(center, U.location(npc))
            local pct = blastPct(d, isDirect, radius)
            if pct > 0 then hurtShooter(N, npc, pct, center, side) end
        end
    end
    -- the player on foot (a direct hit already goes through the normal damage path)
    if player then
        local p = U.playerPawn()
        if U.valid(p) and G.PlayerClassNames[U.className(p) or ""] and U.addr(p) ~= directAddr then
            local pct = blastPct(U.dist(center, U.location(p)), false, radius)
            if pct > 0 then
                local f = HTR.sideMultiplier("player")
                if side == "ally" and HTR.cfg.Features.FriendlyFireRules then f = f * HTR.ff(HTR.cfg.FriendlyFire.AllyToPlayer) end
                Pl.applyExternal(p, pct / 100 * U.get(p, P.MaxHP, 100) * f, "ship blast")
            end
        end
    end
end

-- Hook: your ship's guns, Turret_Mesh_Actor:OnProjectileHit_* (OutProjectileObject, OutHitResult, OutAttachComponents, OutProjectileLocation, ...)
function S.onPlayerShipHit(N, Pl, self, proj, hitP, attach, plocP)
    if not HTR.shipsOn then return end
    local l = plocP:get()
    local direct
    pcall(function() direct = hitP:get().Actor:Get() end)
    S.blast(N, Pl, { X = l.X, Y = l.Y, Z = l.Z }, U.valid(direct) and direct or nil, "ally")
end

-- Hook: AI ship ammo S_AI_Ammo*:OnImpact(Ricochet, PassedThrough, Location, ..., Actor, ...)
function S.onAIShipImpact(N, Pl, self, ricochet, passed, locP, vel, normal, exitLoc, exitVel, impulse, depth, actorP)
    if not HTR.shipsOn then return end
    local l = locP:get()
    local direct = actorP and actorP:get()
    local side = (U.className(self:get()) or ""):find("Ally") and "ally" or "enemy"
    S.blast(N, Pl, { X = l.X, Y = l.Y, Z = l.Z }, U.valid(direct) and direct or nil, side)
end

return S
