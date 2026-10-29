--[[
  NPC side: realistic damage intake, doctrine-driven tuning and tactical AI.
]]

local U = require("htr.util")
local G = require("htr.gamedefs")
local B = require("htr.ballistics")
local C = require("htr.classify")
local DOC = require("htr.doctrines")
local P, BB = G.P, G.BB

local N = { state = {}, count = 0, aimWrite = nil }

local function cfg() return HTR.cfg end
local function feat(name) return HTR.cfg.Features[name] end

-- Every live shooter NPC, including Blueprint subclasses (companions, guards, bosses...).
function N.allShooters()
    local out, seen = {}, {}
    for name in pairs(G.ShooterClassNames) do
        local list = FindAllOf(name)
        if list then
            for _, o in ipairs(list) do
                local a = U.addr(o)
                if a and not seen[a] then seen[a] = true; out[#out + 1] = o end
            end
        end
    end
    return out
end

local function doctrine(st)
    if not feat("FactionDoctrines") then return DOC.regular end
    return DOC[st.doctrine] or DOC.regular
end

-- Per-NPC state (plain values only), created on first sight of the NPC.
function N.ensure(npc)
    local a = U.addr(npc)
    if not a then return nil end
    local st = N.state[a]
    if st then return st end
    if N.count > 600 then N.state = {}; N.count = 0 end -- keep memory bounded
    local cn = U.className(npc)
    st = { side = (C.sideOf(npc)), doctrine = C.doctrineOf(npc, cn), cn = cn }
    st.armor, st.helmet, st.vitality = C.protectionOf(npc, cn, cfg())
    N.state[a] = st
    N.count = N.count + 1
    N.applyTuning(npc, st)
    U.log(string.format("NPC %s side=%s doctrine=%s armor=%s helmet=%s tier=%s lvl=%s", tostring(cn), st.side, st.doctrine,
        st.armor, tostring(st.helmet), tostring(U.get(npc, P.Tier, "?")), tostring(U.get(npc, P.Level, "?"))))
    return st
end

local function setExtent(eye, prop, dist)
    return pcall(function() eye[prop].Distance = dist end)
end

-- One-time per NPC: armor model handover, ballistics and doctrine values.
function N.applyTuning(npc, st)
    if feat("RealisticDamageToNPCs") then
        -- HTR handles armor itself; vanilla's flat armor pool (and its overflow bug) is switched off.
        -- CurrentArmor/MaxArmor stay as the armor *condition* shown on the HP bar.
        U.set(npc, P.HaveShield, false)
    end
    local d = doctrine(st)
    local sniper = U.get(npc, P.Sniper, false)
    if feat("RealisticNPCBallistics") then
        local speed = d.projSpeed
        if sniper then speed = speed * 1.8 end
        if U.get(npc, P.SubType, 0) == G.SubType.Tank then speed = speed * 0.8 end
        U.set(npc, P.ProjSpeed, speed)
    end
    if feat("CompanionFixes") and U.get(npc, P.ProjLife, 3.0) < 1.0 then
        U.set(npc, P.ProjLife, 3.0) -- vanilla companions shoot projectiles that live 0 s
    end
    if feat("SmarterAI") then
        if not sniper then U.set(npc, P.ShootRate, d.fireRate * (0.9 + math.random() * 0.2)) end
        U.set(npc, P.MaxAmmo, d.magazine)
        U.set(npc, "Ammo", d.magazine)
        local eye, rifle = U.get(npc, P.EyeSight, nil), U.get(npc, P.EyeRifle, nil)
        if U.valid(eye) then
            U.set(eye, "SensingInterval", d.sense)
            setExtent(eye, "DetectPyramidExtent", d.sight)
            setExtent(eye, "LostPyramidExtent", d.sight + 500)
        end
        if U.valid(rifle) then
            U.set(rifle, "SensingInterval", math.max(0.1, d.sense * 0.7))
            setExtent(rifle, "DetectPyramidExtent", d.sight)
            setExtent(rifle, "LostPyramidExtent", d.sight + 300)
        end
    end
end

-- Hook: Q1_Shooter_AI_C:CalculateStats (runs once when an NPC spawns).
function N.onCalculateStats(self)
    local npc = self:get()
    local a = U.addr(npc)
    if a then N.state[a] = nil end -- stats were (re)computed: rebuild state
    N.ensure(npc)
end

-- Hook: Q1_Shooter_AI_C:CalculateDamage(DamageOut, DamageCauser, out DMGOut)
-- Vanilla already wrote DMGOut; HTR replaces it before ImpactDamage uses it.
function N.onCalculateDamage(self, dmgIn, causerP, out)
    if not feat("RealisticDamageToNPCs") then return end
    local npc = self:get()
    if U.get(npc, P.Dead, false) then return end
    local maxHP = U.get(npc, P.MaxHP, 0)
    if maxHP <= 1.5 then return end -- civilians: one hit, as vanilla
    local st = N.ensure(npc)
    if not st then return end
    local c = cfg()
    local attacker = causerP:get()
    local aside, acn = C.sideOf(attacker)
    local vanilla = out:get()
    local ff = feat("FriendlyFireRules")

    -- Allied NPCs / turrets hitting allies: vanilla damage, capped.
    if ff and st.side == "ally" and (aside == "ally" or aside == "other") then
        out:set(math.min(vanilla, maxHP * c.FriendlyFire.AllyToAllyCapPercent / 100))
        return
    end

    local head = U.get(npc, P.HeadShot, false) and not U.get(npc, P.DisableHeadShot, false)
    local bone = U.fname(npc, P.BoneName)
    local zone = C.zoneOf(bone, head)
    local caliber = C.caliberOf(attacker, aside, acn, npc)
    if U.get(npc, "IsElecticated", false) and not head then caliber = "beam" end

    local armor, maxArmor = U.get(npc, P.Armor, 0), U.get(npc, P.MaxArmor, 0)
    local integrity = (maxArmor > 0) and (armor / maxArmor) or 1.0
    local hpPct, ablation = B.compute({
        caliber = caliber, zone = zone, armor = st.armor, hasHelmet = st.helmet, integrity = integrity,
        vitality = st.vitality, minPct = c.Damage.MinPercentPerHit, rnd = math.random(),
    })

    local f = c.Damage.GlobalToNPCs
    if ff then
        if aside == "player" and st.side == "ally" then f = f * (c.FriendlyFire.PlayerToAlly[HTR.mode] or 1) end
        if aside == "enemy" and st.side == "enemy" then f = f * c.FriendlyFire.EnemyToEnemy end
    end
    local dmg = hpPct / 100 * maxHP * f
    -- Tactical keeps your allies about as sturdy as vanilla (max +50%).
    if st.side == "ally" and aside == "enemy" and HTR.mode == "Tactical" then
        dmg = math.min(dmg, vanilla * c.Tactical.MaxIncomingVsVanilla)
    end
    if maxArmor > 0 and ablation > 0 then
        U.set(npc, P.Armor, math.max(0, armor - ablation / 100 * maxArmor))
    end
    out:set(dmg)
    if U.LogHits then
        U.log(string.format("HIT %s(%s) <- %s %s zone=%s bone=%s armor=%s cond=%.2f => %.1f%% (%.1f hp, vanilla %.1f)",
            tostring(st.cn), st.doctrine, aside, caliber, zone, bone, st.armor, integrity, hpPct * f, dmg, vanilla))
    end
end

-- Allies of `npc` (same side) inside radius start hunting `target`.
function N.alertAllies(npc, st, radius, target)
    if st.side ~= "enemy" or radius <= 0 or not U.valid(target) then return end
    local here = U.location(npc)
    local list = N.allShooters()
    for _, o in ipairs(list) do
        if U.valid(o) and not U.get(o, P.Dead, false) and U.dist(here, U.location(o)) < radius then
            local ost = N.ensure(o)
            if ost and ost.side == "enemy" and U.addr(o) ~= U.addr(npc) then
                pcall(function() o:CheckForFirstFocus(target) end)
            end
        end
    end
end

-- Hook: Q1_Shooter_AI_C:ReceivePointDamage (after vanilla processed the hit)
function N.onReceivePoint(self)
    if not feat("SmarterAI") then return end
    local npc = self:get()
    if U.get(npc, P.Dead, false) then return end
    local st = N.ensure(npc)
    if not st then return end
    local d = doctrine(st)
    local t = U.now(npc)
    if math.random() < d.reactToHits then
        -- re-enable the "hit -> break line of sight" branches of the behaviour tree
        U.bbSetBool(npc, BB.FirstInteract, false)
        U.bbSetBool(npc, BB.JustGotDamage, true)
        st.clearJGDAt = t + 2.5
    end
    local maxHP = U.get(npc, P.MaxHP, 1)
    if d.retreatHP > 0 and U.get(npc, P.HP, maxHP) / maxHP < d.retreatHP and (st.retreatAt or 0) < t then
        st.retreatAt = t + 15
        pcall(function() npc:RunAwayFromGranede() end) -- sprints to a spot hidden from the threat
    end
    if (st.alertAt or 0) < t then
        st.alertAt = t + 4
        N.alertAllies(npc, st, d.alertRadius, U.playerPawn())
    end
end

-- Hook: Q1_Shooter_AI_C:OnDeadEvent
function N.onDead(self)
    local npc = self:get()
    local a = U.addr(npc)
    local st = a and N.state[a]
    if st and feat("SmarterAI") then
        local d = doctrine(st)
        N.alertAllies(npc, st, d.alertRadius, U.playerPawn())
        -- morale: undisciplined troops may break when a mate drops next to them
        if st.side == "enemy" then
            local here = U.location(npc)
            for _, o in ipairs(N.allShooters()) do
                if U.valid(o) and not U.get(o, P.Dead, false) and U.dist(here, U.location(o)) < 1500 then
                    local ost = N.ensure(o)
                    local od = ost and doctrine(ost)
                    if od and ost.side == "enemy" and od.panic > 0 and math.random() < od.panic then
                        pcall(function() o:RunAwayFromGranede() end)
                    end
                end
            end
        end
    end
    if a then N.state[a] = nil; N.count = math.max(0, N.count - 1) end
end

-- Hook: Q1_Shooter_AI_C:CheckMeleeDistance (vanilla 1 Hz timer) - our "think" tick.
function N.onThink(self)
    local npc = self:get()
    if U.get(npc, P.Dead, false) then return end
    local st = N.ensure(npc)
    if not st then return end
    local t = U.now(npc)
    if st.clearJGDAt and t > st.clearJGDAt then
        U.bbSetBool(npc, BB.JustGotDamage, false)
        st.clearJGDAt = nil
    end
    local d = doctrine(st)
    if feat("NPCGrenades") and feat("SmarterAI") and d.grenades and st.side == "enemy" then
        if U.bbGetBool(npc, BB.InCombat) and not U.get(npc, P.CanSee, true) then
            st.blindSince = st.blindSince or t
            if t - st.blindSince > 5 and (st.nextNade or 0) < t and math.random() < 0.35 then
                st.nextNade = t + 25
                pcall(function() npc:ThrowGranede() end)
            end
        else
            st.blindSince = nil
        end
    end
end

-- Hook: RifleEye OnTargetDetected / OnTargetUpdated - human aim.
-- Vanilla aims almost perfectly at random body points (feet, above the head...).
-- HTR re-aims each point at centre mass or the point itself, plus doctrine spread.
function N.onRifleEye(self)
    if not feat("RealisticNPCBallistics") or N.aimWrite == false then return end
    local npc = self:get()
    local st = N.ensure(npc)
    if not st then return end
    local d = doctrine(st)
    local tgtStruct = U.get(npc, P.ShootTarget, nil)
    if not tgtStruct then return end
    local target = U.get(tgtStruct, "DetectedActor", nil)
    if not U.valid(target) then return end
    local t = U.now(npc)
    local ta = U.addr(target)
    if st.targetAddr ~= ta then st.targetAddr = ta; st.acquiredAt = t end
    local spread = d.spread
    if t - (st.acquiredAt or t) < d.settle then spread = spread * 2.2 end
    if st.suppressedUntil and t < st.suppressedUntil then spread = spread * 1.8 end
    if U.speed(npc) > 150 then spread = spread * 1.4 end
    if U.speed(target) > 350 then spread = spread * 1.25 end
    local from, tl = U.location(npc), U.location(target)
    if not (from and tl) then return end
    local radius = U.dist(from, tl) * math.tan(math.rad(spread))
    local centre = { X = tl.X, Y = tl.Y, Z = tl.Z + 25 }
    local pts = U.get(tgtStruct, "DetectedPoints", nil)
    if not pts then return end
    local ok, err = pcall(function()
        pts:ForEach(function(_, elem)
            local p = elem:get()
            local base = (math.random() < d.aimCenter) and centre or { X = p.X, Y = p.Y, Z = math.min(p.Z, tl.Z + 70) }
            local r = radius * (math.random() + math.random()) / 2 * 1.6
            local a1 = math.random() * 2 * math.pi
            local a2 = (math.random() - 0.5) * math.pi
            elem:set({ X = base.X + r * math.cos(a1) * math.cos(a2), Y = base.Y + r * math.sin(a1) * math.cos(a2),
                Z = base.Z + r * math.sin(a2) })
        end)
    end)
    if N.aimWrite == nil then
        N.aimWrite = ok and true or false
        if not ok then U.warn("NPC aim spread unavailable (" .. tostring(err) .. "); vanilla aim kept") end
    end
end

-- Hook: player weapon projectile hit (after damage) - suppression of nearby NPCs.
local lastSuppress = 0
function N.onPlayerProjectileHit(self, proj, hit, attach, ploc)
    if not (feat("Suppression") and feat("SmarterAI")) then return end
    local weapon = self:get()
    local t = U.now(weapon)
    if t - lastSuppress < 0.15 then return end
    lastSuppress = t
    local l = ploc:get()
    local impact = { X = l.X, Y = l.Y, Z = l.Z }
    for _, o in ipairs(N.allShooters()) do
        if U.valid(o) and not U.get(o, P.Dead, false) then
            local dist = U.dist(impact, U.location(o))
            if dist < 350 then
                local st = N.ensure(o)
                if st and st.side == "enemy" then
                    st.suppressedUntil = t + 2.5
                    local d = doctrine(st)
                    if (st.duckAt or 0) < t and math.random() < d.coverOnSuppress then
                        st.duckAt = t + 4
                        U.bbSetBool(o, BB.FirstInteract, false)
                        U.bbSetBool(o, BB.JustGotDamage, true)
                        st.clearJGDAt = t + 2.0
                    end
                end
            end
        end
    end
end

return N
