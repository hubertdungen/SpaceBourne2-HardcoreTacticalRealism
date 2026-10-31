--[[
  NPC side: realistic damage intake, doctrine-driven tuning and tactical AI.
]]

local U = require("htr.util")
local G = require("htr.gamedefs")
local B = require("htr.ballistics")
local C = require("htr.classify")
local DOC = require("htr.doctrines")
local W = require("htr.wounds")
local S = require("htr.ships")
local GB = require("htr.gear")
local KO = require("htr.knockout")
local P, BB = G.P, G.BB

local N = { state = {}, count = 0, aimWrite = nil, pos = {} }

local function cfg() return HTR.cfg end
local function feat(name) return HTR.cfg.Features[name] end

--[[ Position registry. Every NPC reports where it is from its own hooks (its 1 Hz
     think, its aim updates). Anything that affects other NPCs (alerts, suppression,
     morale, ship splash) looks them up here and queues the effect in their state;
     each NPC applies its queue on its next hook, within a second. HTR never searches
     the world for NPCs: 0.3.1 did (FindAllOf, ~630 ms) and froze the game on every shot. ]]
local FRESH = 3.0 -- s; a live NPC reports at least once a second

function N.track(npc)
    local a, l = U.addr(npc), U.location(npc)
    if a and l then N.pos[a] = { X = l.X, Y = l.Y, Z = l.Z, t = os.clock() } end
end

-- Tracked NPCs within radius of center: list of { a = address, st = state, d = distance }.
function N.near(center, radius)
    local out, now = {}, os.clock()
    if not center then return out end
    for a, p in pairs(N.pos) do
        if now - p.t > FRESH then
            N.pos[a] = nil -- dead, despawned or unloaded
        else
            local st = N.state[a]
            local d = U.dist(center, p)
            if st and d < radius then out[#out + 1] = { a = a, st = st, d = d } end
        end
    end
    return out
end

local function doctrine(st)
    if not feat("FactionDoctrines") then return DOC.regular end
    return DOC[st.doctrine] or DOC.regular
end

-- Effects queued by other NPCs or by your shots, applied by this NPC's own hook.
local function applyPending(npc, st, t)
    if st.duckReq then
        st.duckReq = nil
        U.bbSetBool(npc, BB.FirstInteract, false)
        U.bbSetBool(npc, BB.JustGotDamage, true)
        st.clearJGDAt = t + 2.0
    end
    if st.alertReq then
        st.alertReq = nil
        local target = U.playerPawn(npc)
        if target then pcall(function() npc:CheckForFirstFocus(target) end) end
        if U.Verbose then U.log("alerted by a mate: " .. tostring(st.cn)) end
    end
    if st.panicReq then
        st.panicReq = nil
        pcall(function() npc:RunAwayFromGranede() end)
        if U.Verbose then U.log("panics after a mate died: " .. tostring(st.cn)) end
    end
    if st.crippleReq then
        -- a crippled leg breaks the nerve of anyone but elites, robots and companions: they
        -- either try to get away (chance by doctrine) or break line of sight and fight from cover
        st.crippleReq = nil
        local d = doctrine(st)
        if (d.crippleFlee or 0) > 0 and feat("SmarterAI") then
            if math.random() < d.crippleFlee then
                pcall(function() npc:RunAwayFromGranede() end)
                if U.Verbose then U.log("crippled, falls back: " .. tostring(st.cn)) end
            else
                U.bbSetBool(npc, BB.FirstInteract, false)
                U.bbSetBool(npc, BB.JustGotDamage, true)
                st.clearJGDAt = t + 4.0
                st.reactAt = t + (d.reactEvery or 6)
            end
        end
    end
    if st.blastPct then
        local pct, side = st.blastPct, st.blastSide
        st.blastPct, st.blastSide = nil, nil
        S.hurtShooter(N, npc, pct, side)
    end
end

-- Per-NPC state (plain values only), created on first sight of the NPC.
function N.ensure(npc)
    local a = U.addr(npc)
    if not a then return nil end
    local st = N.state[a]
    if st then return st end
    if N.count > 600 then N.state = {}; N.count = 0 end -- keep memory bounded
    local cn = U.className(npc)
    st = { side = (C.sideOf(npc)), doctrine = C.doctrineOf(npc, cn), cn = cn, level = U.get(npc, P.Level, 1),
        robot = U.get(npc, P.Robot, false) or cn == "Q1_Shooter_Robot_C", boss = U.get(npc, P.IsBoss, false) == true }
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

--[[ Situational awareness. A relaxed enemy (no fight yet) notices you only up close;
     once alert (blackboard InCombat?, set by the game when it spots you, gets hit or is
     warned by a mate) it scans, spots and shoots much farther. Allies stay alert.
     Switched from the 1 Hz think, only when the state changes. ]]
local function setAwareness(npc, st, alert)
    st.alert = alert
    local aw, d = cfg().Awareness, doctrine(st)
    local sight = d.sight * (alert and aw.AlertSight or aw.RelaxedSight)
    if U.get(npc, P.Sniper, false) and alert then sight = math.max(sight, d.sight * 2) end
    local eye, rifle = U.get(npc, P.EyeSight, nil), U.get(npc, P.EyeRifle, nil)
    if U.valid(eye) then
        setExtent(eye, "DetectPyramidExtent", sight)
        setExtent(eye, "LostPyramidExtent", sight + 500)
    end
    if U.valid(rifle) then
        setExtent(rifle, "DetectPyramidExtent", sight)
        setExtent(rifle, "LostPyramidExtent", sight + 300)
    end
    if U.Verbose then U.log(string.format("%s %s: sight %.0f m", tostring(st.cn), alert and "alert" or "relaxed", sight / 100)) end
end

local function awarenessOn(st)
    return feat("SmarterAI") and cfg().Awareness.Enabled and st.side == "enemy"
end

-- One-time per NPC: armor model handover, ballistics and doctrine values.
function N.applyTuning(npc, st)
    st.spawnT = os.clock()
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
        if awarenessOn(st) then setAwareness(npc, st, U.bbGetBool(npc, BB.InCombat) == true) end
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
    if not st or st.down then return end -- knocked out: the next hit kills (vanilla damage)
    local c = cfg()
    local attacker = causerP:get()
    local aside, acn = C.sideOf(attacker)
    local vanilla = out:get()
    local ff = feat("FriendlyFireRules")

    -- Allied NPCs / turrets hitting allies: vanilla damage, capped.
    if ff and st.side == "ally" and (aside == "ally" or aside == "other") then
        out:set(math.min(vanilla, maxHP * c.FriendlyFire.AllyToAllyCapPercent / 100) * HTR.sideMultiplier("ally"))
        return
    end

    local head = U.get(npc, P.HeadShot, false) and not U.get(npc, P.DisableHeadShot, false)
    local bone = U.fname(npc, P.BoneName)
    local zone = C.zoneOf(bone, head)
    local caliber = C.caliberOf(attacker, aside, acn, npc)
    if U.get(npc, "IsElecticated", false) and not head then caliber = "beam" end

    local armor, maxArmor = U.get(npc, P.Armor, 0), U.get(npc, P.MaxArmor, 0)
    local integrity = (maxArmor > 0) and (armor / maxArmor) or 1.0
    local wq, aq = GB.weapon(attacker), GB.npcArmor(st) -- optional gear bonus (0 when off)
    local args = GB.apply({
        caliber = caliber, zone = zone, armor = st.armor, hasHelmet = st.helmet, integrity = integrity,
        vitality = st.vitality, minPct = c.Damage.MinPercentPerHit, rnd = math.random(),
    }, wq, aq)
    if st.boss then -- bosses: better-made armor that also wears slower (0.4.7)
        args.ratingBonus = (args.ratingBonus or 0) + (c.Damage.BossArmorBonus or 0)
        args.wearMult = (args.wearMult or 1) * (c.Damage.BossArmorWear or 1)
    end
    local hpPct, ablation, pass = B.compute(args)
    if c.Wounds.Bleeding and not (B.Calibers[caliber] or {}).tick then
        local new = W.onHit(U.addr(npc), zone, hpPct, pass, os.clock(), HTR.sideMultiplier(st.side) * HTR.woundFreq(st.side),
            HTR.woundFreq(st.side), st.robot)
        if new == "fracture" and zone == "leg" then st.crippleReq = true end -- morale hit, applied on its next hook
    end

    local f = c.Damage.GlobalToNPCs
    if ff then
        if aside == "player" and st.side == "ally" then f = f * HTR.ff(c.FriendlyFire.PlayerToAlly) end
        if aside == "enemy" and st.side == "enemy" then f = f * c.FriendlyFire.EnemyToEnemy end
    end
    local dmg = hpPct / 100 * maxHP * f
    -- Tactical: your allies take 100-150% of what vanilla would do.
    if st.side == "ally" and aside == "enemy" and HTR.base == "Tactical" then
        dmg = U.clamp(dmg, vanilla * c.Tactical.MinIncomingVsVanilla, vanilla * c.Tactical.MaxIncomingVsVanilla)
    end
    -- "Hardcore" modes: your side (and optionally enemies) takes double damage.
    local sideMult = HTR.sideMultiplier(st.side)
    dmg = dmg * sideMult
    f = f * sideMult
    if maxArmor > 0 and ablation > 0 then
        U.set(npc, P.Armor, math.max(0, armor - ablation / 100 * maxArmor))
    end
    -- not always dead (0.4.9): a lethal hit may leave it knocked out at 1 HP
    local hpNow = U.get(npc, P.HP, 0)
    if dmg >= hpNow and hpNow > 1 and not st.robot and not st.boss and st.doctrine ~= "machine"
        and KO.roll(zone, (dmg - hpNow) / maxHP, false) then
        dmg = hpNow - 1
        out:set(dmg)
        KO.downShooter(npc, st, os.clock())
        if U.LogHits then U.log("KNOCKED OUT " .. tostring(st.cn) .. " (" .. st.side .. ")") end
        return
    end
    out:set(dmg)
    if U.LogHits then
        U.log(string.format("HIT %s(%s L%s) <- %s %s zone=%s bone=%s armor=%s cond=%.2f gear w%.2f a%.2f => %.1f%% (%.1f hp, vanilla %.1f)",
            tostring(st.cn), st.doctrine, tostring(st.level), aside, caliber, zone, bone, st.armor, integrity, wq, aq, hpPct * f, dmg, vanilla))
    end
end

-- Enemies near `npc` start hunting the player (applied on their next hook).
function N.alertAllies(npc, st, radius)
    if st.side ~= "enemy" or radius <= 0 then return end
    local me = U.addr(npc)
    for _, e in ipairs(N.near(U.location(npc), radius)) do
        if e.a ~= me and e.st.side == "enemy" then e.st.alertReq = true end
    end
end

-- Hook: Q1_Shooter_AI_C:ReceivePointDamage (after vanilla processed the hit)
function N.onReceivePoint(self)
    if not feat("SmarterAI") then return end
    local npc = self:get()
    if U.get(npc, P.Dead, false) then return end
    local st = N.ensure(npc)
    if not st then return end
    st.hitT = os.clock() -- a reviver under fire stops (knockout.lua)
    local d = doctrine(st)
    local t = U.now(npc)
    -- One "break line of sight" at a time: after diving for cover an NPC fights from there for
    -- a while. Without this, sustained fire re-triggered it on every hit and NPCs (pirates most)
    -- spent the whole fight sprinting instead of shooting back.
    if (st.reactAt or 0) < t and math.random() < d.reactToHits then
        st.reactAt = t + (d.reactEvery or 6)
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
        N.alertAllies(npc, st, d.alertRadius)
    end
end

-- Hook: Q1_Shooter_AI_C:OnDeadEvent
function N.onDead(self)
    local npc = self:get()
    local a = U.addr(npc)
    local st = a and N.state[a]
    if st and feat("SmarterAI") then
        local d = doctrine(st)
        N.alertAllies(npc, st, d.alertRadius)
        -- morale: undisciplined troops may break when a mate drops next to them
        if st.side == "enemy" then
            for _, e in ipairs(N.near(U.location(npc), 1500)) do
                local od = doctrine(e.st)
                if e.a ~= a and e.st.side == "enemy" and od.panic > 0 and math.random() < od.panic then
                    e.st.panicReq = true
                end
            end
        end
    end
    if a then N.state[a] = nil; N.pos[a] = nil; N.count = math.max(0, N.count - 1); W.heal(a); KO.down[a] = nil end
end

-- Damage factor for victim side `vs` hit by attacker side `as` (friendly fire + Hardcore).
local function sideFactor(as, vs)
    local c, f = cfg(), cfg().Damage.GlobalToNPCs
    if feat("FriendlyFireRules") then
        if as == "player" and vs == "ally" then f = f * HTR.ff(c.FriendlyFire.PlayerToAlly) end
        if as == "enemy" and vs == "enemy" then f = f * c.FriendlyFire.EnemyToEnemy end
    end
    return f * HTR.sideMultiplier(vs)
end

-- Hook: Q1_Shooter_AI_C:ReceiveRadialDamage(DamageReceived, DamageType, Origin, HitInfo, InstigatedBy, DamageCauser)
-- Vanilla only lets the player's blasts through (raw, level-scaled) and ignores
-- every other explosion. HTR replaces both with a distance-based blast.
function N.onRadial(self, dmgP, dtypeP, originP, hitP, instigP, causerP)
    if not feat("RealisticDamageToNPCs") then return end
    local npc = self:get()
    if not U.get(npc, P.Ready, false) or U.get(npc, P.Dead, false) then return end
    local maxHP = U.get(npc, P.MaxHP, 0)
    if maxHP <= 1.5 then return end
    local st = N.ensure(npc)
    if not st then return end
    local aside = C.sideOf(causerP:get())
    local raw = dmgP:get()
    if aside == "player" and raw <= 2 then return end -- ability shockwaves: knock-down only, as vanilla
    local hp = U.get(npc, P.HP, 0)
    if aside == "player" then hp = hp + raw end -- undo vanilla's raw hit
    local o = originP:get()
    local d = U.dist({ X = o.X, Y = o.Y, Z = o.Z }, U.location(npc))
    local falloff = math.max(0, 1 - d / cfg().Damage.ExplosionRadius)
    local pct = B.compute(GB.apply({ caliber = "explosion", zone = "torso", armor = st.armor, hasHelmet = st.helmet,
        integrity = 1, vitality = st.vitality, minPct = 0, rnd = math.random() }, 0, GB.npcArmor(st))) * falloff
    hp = hp - pct / 100 * maxHP * sideFactor(aside, st.side)
    U.set(npc, P.HP, math.max(0, hp))
    if U.LogHits then U.log(string.format("BLAST %s <- %s d=%.0f => %.1f%%", tostring(st.cn), aside, d, pct)) end
    if hp <= 0 then
        U.set(npc, "Shotgun", true)
        pcall(function() npc:ForceToDead() end)
    end
end

-- Hook: Master_Soldier_C:ReceivePointDamage (your ground squad / team-battle soldiers).
-- Vanilla already subtracted self.Damage from armor or HP; HTR swaps it for the realistic value.
-- Squad soldiers are issued military kit: at least medium armor and a helmet, and a slightly
-- tougher body, so they can hold a firefight instead of dropping as soon as they show up.
local SOLDIER_ARMOR = { [0] = "medium", [1] = "medium", [2] = "medium", [3] = "heavy", [4] = "heavy" }
local SOLDIER_VITALITY = 1.2
function N.onSoldierHit(self, dmgP, dtypeP, hitLocP, hitNormalP, compP, boneP, dirP, instigP, causerP)
    if not feat("RealisticDamageToNPCs") then return end
    local sol = self:get()
    if U.get(sol, P.Dead, false) then return end
    local applied = U.get(sol, "Damage", 0)
    if applied <= 0 then return end
    local attacker = causerP:get()
    local aside, acn = C.sideOf(attacker)
    local vside = C.sideOf(sol)
    if aside == vside and aside ~= "other" then return end -- vanilla ignores own-team soldiers
    local hp, armor = U.get(sol, P.HP, 0), U.get(sol, P.Armor, 0)
    if armor > 0 then
        U.set(sol, P.Armor, 0.0) -- HTR models their armor itself; the vanilla pool goes away
    else
        hp = hp + applied
    end
    local zone = C.zoneOf((function() local ok, s = pcall(function() return boneP:get():ToString() end); return ok and s or "None" end)(), false)
    local caliber = C.caliberOf(attacker, aside, acn, sol)
    local hpPct, _, pass = B.compute(GB.apply({ caliber = caliber, zone = zone, armor = SOLDIER_ARMOR[U.get(sol, P.Tier, 2)] or "medium",
        hasHelmet = true, integrity = 1, vitality = SOLDIER_VITALITY, minPct = cfg().Damage.MinPercentPerHit, rnd = math.random() },
        GB.weapon(attacker), GB.soldierArmor()))
    if cfg().Wounds.Bleeding and not (B.Calibers[caliber] or {}).tick then
        W.onHit(U.addr(sol), zone, hpPct, pass, os.clock(), HTR.sideMultiplier(vside) * HTR.woundFreq(vside), HTR.woundFreq(vside))
    end
    local dmg = hpPct / 100 * U.get(sol, P.MaxHP, 100) * sideFactor(aside, vside) / HTR.sideMultiplier(vside)
    if vside == "ally" and aside == "enemy" and HTR.base == "Tactical" then
        dmg = U.clamp(dmg, applied * cfg().Tactical.MinIncomingVsVanilla, applied * cfg().Tactical.MaxIncomingVsVanilla)
    end
    dmg = dmg * HTR.sideMultiplier(vside)
    hp = hp - dmg
    U.set(sol, P.HP, hp)
    if U.LogHits then U.log(string.format("SQUAD %s(%s) <- %s %s zone=%s => %.1f hp (vanilla %.1f)", tostring(U.className(sol)), vside, aside, caliber, zone, dmg, applied)) end
    if hp < 0 then
        -- Tactical: injured first, as vanilla. Realism: headshots and heavy overkill kill
        -- outright, other lethal hits by chance (Damage.SquadOutrightDeath).
        local outright = (cfg().Damage.SquadOutrightDeath or {})[HTR.mode] or 0
        local fatal = HTR.base == "Realism" and (zone == "head" or hp < -0.5 * U.get(sol, P.MaxHP, 100))
        local dies
        if U.get(sol, "InInjuredMode", false) then dies = true
        elseif KO.enabled() then dies = not KO.roll(zone, -hp / U.get(sol, P.MaxHP, 100), false) -- 0.4.9: chance per mode
        else dies = fatal or math.random() < outright end
        if dies then
            pcall(function() sol:Deaded() end)
        else
            pcall(function() sol:EnterInjuredMode() end)
        end
    end
end

-- Hook: Master_Soldier_C:UpdateBattle (vanilla 1.5 s timer) - squad soldiers bleed.
-- Only wounded soldiers cost anything. Once down (injured mode) the vanilla bleed-out
-- timer takes over: a medic or you can still revive them.
local soldierBleedT = {}
function N.onSoldierUpdate(self)
    local sol = self:get()
    local a = U.addr(sol)
    if a and not U.get(sol, P.Dead, false) and not U.get(sol, P.Injured, false) then
        KO.soldier(sol, a, os.clock(), C.sideOf(sol)) -- position for revives (knockout.lua)
    end
    if not (a and W.list[a]) then return end
    if U.get(sol, P.Dead, false) or U.get(sol, P.Injured, false) then W.heal(a); soldierBleedT[a] = nil; return end
    local t = os.clock()
    local dt = math.min(3.0, t - (soldierBleedT[a] or t))
    soldierBleedT[a] = t
    local pct = W.bleed(a, t, dt)
    if pct <= 0 then return end
    local hp = U.get(sol, P.HP, 0) - pct / 100 * U.get(sol, P.MaxHP, 100)
    U.set(sol, P.HP, hp)
    if hp < 0 then
        W.heal(a); soldierBleedT[a] = nil
        pcall(function() sol:EnterInjuredMode() end)
    end
end

-- Hook: Master_Soldier_C:InjuredTime (1 s while down) - longer bleed-out (knockout.lua).
function N.onSoldierInjured(self)
    if not KO.enabled() then return end
    local sol = self:get()
    local a = U.addr(sol)
    if a then KO.soldierInjured(sol, a, os.clock()) end
end

-- Hook: Master_Soldier_C:SetWalkSpeed(_Guarded) - squad soldiers following you.
-- Vanilla always sets the walk gait, so soldiers fall behind and then teleport next to
-- you once 30 m away ("spawning out of nowhere"). HTR makes them run or sprint to keep up,
-- so the teleport only rescues a soldier that is really stuck.
function N.onSoldierMove(self)
    local sq = cfg().Squad
    if not (sq and sq.KeepUp) then return end
    local sol = self:get()
    if U.get(sol, "AI_Type", 1) ~= 1 then return end -- only your side follows you
    if U.get(sol, P.Dead, false) or U.get(sol, P.Injured, false) then return end
    local d = U.dist(U.location(sol), U.location(U.playerPawn(sol)))
    if d >= 1e9 then return end
    local gait = (d > sq.SprintBeyond) and G.Gait.Sprint or ((d > sq.RunBeyond) and G.Gait.Run or G.Gait.Walk)
    if W.fracture(U.addr(sol), os.clock()) == "leg" then gait = G.Gait.Walk end -- broken leg: limps after you
    pcall(function() sol:SetDesiredGait(gait) end)
    pcall(function() sol:SetGait(gait) end)
end

-- Hook: Q1_Shooter_AI_C:CheckMeleeDistance (vanilla 1 Hz timer) - our "think" tick.
function N.onThink(self)
    local npc = self:get()
    if U.get(npc, P.Dead, false) then return end
    local st = N.ensure(npc)
    if not st then return end
    if st.down then return end -- knocked out: lies still (knockout.lua runs bleed-out and revive)
    local t = U.now(npc)
    N.track(npc)
    if st.reviving or st.reviveMoving then KO.drive(npc, st) end
    applyPending(npc, st, t)
    if U.get(npc, P.Dead, false) then return end -- a queued ship blast may have killed it
    -- bleeding (1 Hz)
    local ct = os.clock()
    local dt = math.min(2.0, ct - (st.lastThink or ct))
    st.lastThink = ct
    if dt > 0 and cfg().Wounds.Bleeding then
        local pct = W.bleed(U.addr(npc), ct, dt)
        if pct > 0 then
            local left = U.get(npc, P.HP, 0) - pct / 100 * U.get(npc, P.MaxHP, 100)
            U.set(npc, P.HP, math.max(0, left))
            if left <= 0 then pcall(function() npc:ForceToDead() end); return end
        end
    end
    if W.fracture(U.addr(npc), ct) == "leg" then pcall(function() npc:SetDesiredGait(G.Gait.Walk) end) end
    if st.clearJGDAt and t > st.clearJGDAt then
        U.bbSetBool(npc, BB.JustGotDamage, false)
        st.clearJGDAt = nil
    end
    if awarenessOn(st) then
        local alert = U.bbGetBool(npc, BB.InCombat) == true
        if alert ~= st.alert then setAwareness(npc, st, alert) end
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

--[[ Resume fire. Vanilla starts an NPC's firing only at the moment its rifle eye first
     spots a target while the NPC is aiming, and every shot stops the firing for good once
     it is not aiming (sprinting to cover, fleeing, repositioning). Vanilla NPCs almost never
     left aiming mid-fight; HTR's hit, suppression and morale reactions make them do it often,
     so without this they ran around and never fired again while they could still see you.
     StartShoot is guarded in the Blueprint: calling it while already firing does nothing. ]]
local function resumeFire(npc, st, t)
    if (st.fireCheckAt or 0) > t then return end
    st.fireCheckAt = t + 0.5
    if U.get(npc, P.RotationMode, 0) ~= G.Rotation.Aiming then return end
    if U.get(npc, P.ThrowingGrenade, false) or U.get(npc, P.SwordAttack, false) then return end
    pcall(function() npc:StartShoot() end)
end

-- Hook: RifleEye OnTargetDetected / OnTargetUpdated (the NPC's gun sees a target) - human aim.
-- Vanilla aims almost perfectly at random body points (feet, above the head...).
-- HTR re-aims each point at centre mass or the point itself, plus doctrine spread.
function N.onRifleEye(self)
    local npc = self:get()
    local st = N.ensure(npc)
    if not st then return end
    if st.down then return end
    local t = U.now(npc)
    N.track(npc)
    if st.reviving or st.reviveMoving then KO.drive(npc, st); return end -- busy reviving: no aiming
    applyPending(npc, st, t) -- NPCs in a fight react to queued effects within ~0.3 s
    if feat("SmarterAI") and not U.get(npc, P.Dead, false) then resumeFire(npc, st, t) end
    if not feat("RealisticNPCBallistics") or N.aimWrite == false then return end
    local d = doctrine(st)
    local tgtStruct = U.get(npc, P.ShootTarget, nil)
    if not tgtStruct then return end
    local target = U.get(tgtStruct, "DetectedActor", nil)
    if not U.valid(target) then return end
    local ta = U.addr(target)
    if st.targetAddr ~= ta then st.targetAddr = ta; st.acquiredAt = t end
    local spread = d.spread
    if t - (st.acquiredAt or t) < d.settle then spread = spread * 2.2 end
    if st.suppressedUntil and t < st.suppressedUntil then spread = spread * 1.8 end
    local frac = W.fracture(U.addr(npc), os.clock())
    if frac == "arm" then spread = spread * (cfg().Wounds.NpcArmSpread or 3.0) end -- broken arm: wild aim
    if frac == "leg" and (st.limpAt or 0) < t then -- broken leg: walks (BT tasks keep asking for a sprint)
        st.limpAt = t + 0.5
        pcall(function() npc:SetDesiredGait(G.Gait.Walk) end)
    end
    -- Arrival grace (elevators, new floors, fresh spawns): nobody aims well for a few seconds.
    local now = os.clock()
    if now < (HTR.arrivalUntil or 0) or now - (st.spawnT or 0) < cfg().Arrival.SpawnGraceSeconds then
        spread = spread * 6
    end
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
    local n = 0
    for _, e in ipairs(N.near({ X = l.X, Y = l.Y, Z = l.Z }, 350)) do
        local st = e.st
        if st.side == "enemy" then
            n = n + 1
            st.suppressedUntil = t + 2.5 -- worse aim right away
            local d = doctrine(st)
            if (st.duckAt or 0) < t and (st.reactAt or 0) < t and math.random() < d.coverOnSuppress then
                st.duckAt = t + 4
                st.reactAt = t + (d.reactEvery or 6)
                st.duckReq = true -- breaks line of sight on its next hook
            end
        end
    end
    if n > 0 and U.Verbose then U.log("suppression: " .. n .. " enemies near the impact") end
end

return N
