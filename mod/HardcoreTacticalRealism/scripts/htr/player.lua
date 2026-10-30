--[[
  Player side: incoming damage for the four modes
  (Tactical / Tactical Hardcore / Realism / Realism Hardcore).

  How it works (all verified in game):
   1. The player's DamageAbsorbChance is held at 100 %, so vanilla
      CalculateIncomeDamage skips its own HP/armor math but still plays the
      hit sound, HUD flash, damage indicator and camera shake.
   2. Our post-hook on CalculateIncomeDamage queues the vanilla damage value.
   3. The same call stack then returns into the shooter's OnProjectileHit
      event, whose post-hook knows the shooter and the bone that was hit:
      the queued hit is resolved there with full context.
      Anything not resolved that way (explosions, DoT, melee) is resolved on
      the player's next tick with "unattributed" rules.
   4. Lethal hits are handed back to vanilla (absorb 0 + a lethal ApplyDamage)
      so auto-resurrect perks, death screen and game-over logic stay intact.
]]

local U = require("htr.util")
local G = require("htr.gamedefs")
local B = require("htr.ballistics")
local C = require("htr.classify")
local W = require("htr.wounds")
local GB = require("htr.gear")
local P = G.P

local Pl = { pending = {}, passthrough = false, radialTick = -1, tick = 0, nextAbsorb = 0, owned = false }

local function cfg() return HTR.cfg end
local function enabled() return HTR.cfg.Features.RealisticDamageToPlayer end

function Pl.enforceAbsorb(p)
    if enabled() then
        if U.get(p, P.PlayerAbsorb, 0) < 100 then U.set(p, P.PlayerAbsorb, 100.0) end
        Pl.owned = true
    elseif Pl.owned then
        U.set(p, P.PlayerAbsorb, 0.0)
        Pl.owned = false
    end
end

-- Hook: Q1_Character_C:CalculateIncomeDamage(Damage, out Dead?, out ArmorDamage?)
function Pl.onIncome(self, dmgP, deadP, armorP)
    if Pl.passthrough or not enabled() then return end
    local p = self:get()
    if U.get(p, P.PlayerAbsorb, 0) < 100 then
        Pl.enforceAbsorb(p) -- first hit of the session went through vanilla; from now on HTR owns it
        return
    end
    deadP:set(false)
    armorP:set(false)
    Pl.pending[#Pl.pending + 1] = { raw = dmgP:get(), radial = (Pl.radialTick == Pl.tick) }
    Pl.radialTick = -1
end

-- Hook: Q1_Character_C:ReceiveRadialDamage (runs right before the generic damage event,
-- in the same frame). Only the hit in this same frame counts as an explosion.
function Pl.onRadial()
    Pl.radialTick = Pl.tick
end

local function playerArmorRatings(p)
    local maxHP, maxArmor = U.get(p, P.MaxHP, 100), U.get(p, P.MaxArmor, 0)
    local ratio = (maxHP > 0) and (maxArmor / maxHP) or 0
    local body = U.clamp(15 + 45 * ratio, 0, 66)
    if maxArmor <= 0 then body = 0 end
    return { body = body, helmet = body * 0.85 }
end

-- Damage for one queued hit. Returns hpDamage, armorDamage (absolute units).
local function computeHit(p, entry, shooter, bone)
    local c = cfg()
    local realism = (HTR.base == "Realism")
    local side, cn, caliber = "other", nil, nil
    if U.valid(shooter) then
        side, cn = C.sideOf(shooter)
        caliber = C.caliberOf(shooter, side, cn, p)
    end
    -- friendly fire factor x "Hardcore" double damage
    local ff = HTR.sideMultiplier("player")
    if side == "ally" and c.Features.FriendlyFireRules then ff = ff * HTR.ff(c.FriendlyFire.AllyToPlayer) end
    local zone = C.zoneOf(bone, false)
    local maxHP, armor, maxArmor = U.get(p, P.MaxHP, 100), U.get(p, P.Armor, 0), U.get(p, P.MaxArmor, 0)
    -- optional gear bonus: the shooter's weapon level vs your suit's level (0 when off)
    local wq, aq = 0, 0
    if caliber and GB.active() then wq, aq = GB.weapon(shooter), GB.suit(p) end
    Pl.lastGear = string.format("gear w%.2f a%.2f", wq, aq)

    -- Wounds in every mode (less often in the Tactical modes, see Wounds.Frequency).
    local freq = HTR.woundFreq("player")
    if c.Wounds.Bleeding and caliber and not entry.radial and freq > 0 then
        local integ = (maxArmor > 0) and (armor / maxArmor) or 0
        local wPct, _, wPass = B.compute(GB.apply({ caliber = caliber, zone = zone, ratings = playerArmorRatings(p), hasHelmet = true,
            integrity = integ, vitality = c.Realism.PlayerVitality, minPct = 0, rnd = 0.5 }, wq, aq))
        local t = os.clock()
        local new = W.onHit(U.addr(p), zone, wPct * ff, wPass, t, HTR.sideMultiplier("player") * freq, freq)
        if new and t > (Pl.woundMsgAt or 0) then
            Pl.woundMsgAt = t + 8
            local msg = "You are bleeding - get to cover"
            if new == "fracture" then
                msg = zone == "leg" and "Broken leg - you limp; healing halved until it fuses"
                    or "Broken arm - your aim shakes; healing halved until it fuses"
            end
            pcall(U.notify, msg, p)
        end
    end

    if realism and caliber and not entry.radial then
        local integrity = (maxArmor > 0) and (armor / maxArmor) or 0
        local hpPct, ablation, pass = B.compute(GB.apply({ caliber = caliber, zone = zone, ratings = playerArmorRatings(p), hasHelmet = true,
            integrity = integrity, vitality = c.Realism.PlayerVitality, minPct = c.Damage.MinPercentPerHit, rnd = math.random() }, wq, aq))
        return hpPct / 100 * maxHP * ff, ablation / 100 * maxArmor * ff, "realism", caliber, zone, side
    end
    local d
    if realism then
        d = math.min(entry.raw * c.Realism.UnattributedMultiplier, maxHP * c.Realism.UnattributedMaxPercent / 100)
    else
        local f = 1.25
        if caliber then
            local cal = B.Calibers[caliber] or B.Calibers.generic
            f = cal.dmg / 50
            if zone == "head" then f = f * c.Tactical.HeadMultiplier
            elseif zone == "arm" or zone == "leg" then f = f * 0.75 end
        end
        d = entry.raw * U.clamp(f, c.Tactical.MinIncomingVsVanilla, c.Tactical.MaxIncomingVsVanilla)
    end
    return d * ff, nil, "pool", caliber or (entry.radial and "explosion" or "unattributed"), zone, side
end

local function kill(p)
    U.set(p, P.Armor, 0.0)
    U.set(p, P.HP, 1.0)
    U.set(p, P.PlayerAbsorb, 0.0)
    Pl.passthrough = true
    local ok, err = pcall(function() U.gameplayStatics():ApplyDamage(p, 1.0e7, nil, p, nil) end)
    Pl.passthrough = false
    U.set(p, P.PlayerAbsorb, 100.0)
    if not ok then U.warn("lethal hand-off failed: " .. tostring(err)) end
end

function Pl.resolve(p, shooter, bone)
    if #Pl.pending == 0 then return end
    local list = Pl.pending
    Pl.pending = {}
    local hp, armor = U.get(p, P.HP, 0), U.get(p, P.Armor, 0)
    Pl.lastHurt = os.clock()
    for _, e in ipairs(list) do
        local d, abl, kind, caliber, zone, side = computeHit(p, e, shooter, bone)
        if kind == "pool" then
            -- armor soaks first, the rest goes to HP (vanilla's overflow bug fixed)
            if armor > 0 then
                local soak = math.min(armor, d)
                armor = armor - soak
                d = d - soak
            end
            hp = hp - d
        else
            hp = hp - d
            armor = math.max(0, armor - (abl or 0))
        end
        if U.LogHits then
            U.log(string.format("PLAYER <- %s %s zone=%s raw=%.1f mode=%s %s => hp %.1f armor %.1f", tostring(side), tostring(caliber),
                tostring(zone), e.raw, HTR.mode, tostring(Pl.lastGear), hp, armor))
        end
        shooter, bone = nil, nil -- only the first queued hit belongs to this projectile
    end
    if hp <= 0 then
        if U.get(p, P.GodMode, false) then
            hp = 1
        else
            kill(p)
            return
        end
    end
    U.set(p, P.HP, hp)
    U.set(p, P.Armor, armor)
    pcall(function() p:RefreshWidgetHP() end)
end

-- Hook: any NPC/soldier OnProjectileHit (after it applied damage).
function Pl.onShooterProjectileHit(self, proj, hitP)
    if #Pl.pending == 0 then return end
    local shooter = self:get()
    local h = hitP:get()
    local victim = nil
    pcall(function() victim = h.Actor:Get() end)
    if not (U.valid(victim) and G.PlayerClassNames[U.className(victim) or ""]) then return end
    local bone = "None"
    pcall(function() bone = h.BoneName:ToString() end)
    Pl.resolve(victim, shooter, bone)
end

-- Damage from outside the normal hit path (ship blasts, bleeding). Absolute HP.
function Pl.applyExternal(p, amount, label)
    if amount <= 0 or not enabled() then return end
    local hp, armor = U.get(p, P.HP, 0) - amount, U.get(p, P.Armor, 0)
    if label ~= "bleeding" then
        armor = math.max(0, armor - amount * 0.3)
        Pl.lastHurt = os.clock()
    end
    if U.LogHits then U.log(string.format("PLAYER <- %s %.1f => hp %.1f", label, amount, hp)) end
    if hp <= 0 then
        if U.get(p, P.GodMode, false) then hp = 1 else kill(p); return end
    end
    U.set(p, P.HP, hp)
    U.set(p, P.Armor, armor)
    pcall(function() p:RefreshWidgetHP() end)
end

-- Slow nanotech healing between fights; bleeding blocks it.
local function regenStep(p, t, dt)
    local c = cfg()
    local addr = U.addr(p)
    if c.Wounds.Bleeding then
        local pct = W.bleed(addr, t, dt)
        if pct > 0 then Pl.applyExternal(p, pct / 100 * U.get(p, P.MaxHP, 100), "bleeding") end
    end
    local r = c.Regen.Enabled and c.Regen[HTR.mode]
    if not r then return end
    local resting = not W.isBleeding(addr, t) and t - (Pl.lastHurt or -1e9) >= r.Delay
    -- The game heals the player with its own suit stat (HPRecoverRate). HTR scales it per
    -- mode and pauses it while bleeding or shortly after a hit.
    local cur = U.get(p, "HPRecoverRate", 0)
    if Pl.baseRegen == nil or (cur > 0 and math.abs(cur - (Pl.setRegen or -1)) > 1e-4) then
        Pl.baseRegen = cur -- first look, or the game recomputed the stat (new suit)
    end
    local want = resting and Pl.baseRegen * r.HP or 0
    if W.fracture(addr, t) then want = want * 0.5 end -- broken bone: half healing
    if math.abs(cur - want) > 1e-4 then U.set(p, "HPRecoverRate", want); Pl.setRegen = want end
    if not resting then return end
    local armor, maxArmor = U.get(p, P.Armor, 0), U.get(p, P.MaxArmor, 0)
    local changed = false
    if maxArmor > 0 and armor < maxArmor and r.Armor > 0 then
        U.set(p, P.Armor, math.min(maxArmor, armor + maxArmor * r.Armor / 100 * dt)); changed = true
    end
    if changed then pcall(function() p:RefreshWidgetHP() end) end
end

--[[ Broken bones, every frame while one is broken (nothing otherwise).
     Leg: the game sets the walk/run/sprint speed each frame (ALS UpdateDynamicMovementSettings,
     run from this tick); HTR scales the value it just set, so you limp at every gait.
     Arm: with a gun drawn, the aim drifts and trembles (two slow waves plus a faster tremor). ]]
local function injuryFrame(p)
    local w = cfg().Wounds
    if Pl.legBroken then
        local ok, cmc = pcall(function() return p.CharacterMovement end)
        if ok and U.valid(cmc) then
            local v = U.get(cmc, "MaxWalkSpeed", 0)
            if v > 0 and v ~= Pl.limpWritten then -- the game set a fresh value this frame
                local nv = v * (w.LegSpeed or 0.5)
                U.set(cmc, "MaxWalkSpeed", nv); U.set(cmc, "MaxWalkSpeedCrouched", nv)
                Pl.limpWritten = nv
            end
        end
    end
    if Pl.armBroken then
        local now = os.clock()
        local dt = math.min(0.05, now - (Pl.swayT or now))
        Pl.swayT = now
        local okW, gun = pcall(function() return p.CurrentWeapon.ChildActor end)
        if dt > 0 and okW and U.valid(gun) then
            local a = (w.ArmSway or 6) * dt / 2.5 -- deg/s, divided by the controller's input scale
            local yaw = a * (math.sin(now * 1.7) + 0.6 * math.sin(now * 4.9) + 0.25 * math.sin(now * 11.0))
            local pitch = a * 0.7 * (math.sin(now * 1.3 + 1.1) + 0.6 * math.sin(now * 5.7) + 0.25 * math.sin(now * 13.0))
            pcall(function() p:AddControllerYawInput(yaw); p:AddControllerPitchInput(pitch) end)
        end
    end
end

-- Hook: ALS_Base_C:ReceiveTick - leftovers, absorb upkeep, bleeding, healing, broken bones.
function Pl.onTick(self)
    local p = self:get()
    Pl.tick = Pl.tick + 1
    if (Pl.legBroken or Pl.armBroken) and U.addr(p) == Pl.addr then injuryFrame(p) end
    if #Pl.pending > 0 then
        if G.PlayerClassNames[U.className(p) or ""] then Pl.resolve(p, nil, nil) end
        return
    end
    local clock = os.clock()
    if clock < Pl.nextAbsorb then return end
    Pl.nextAbsorb = clock + 0.25
    if not G.PlayerClassNames[U.className(p) or ""] then return end
    Pl.enforceAbsorb(p)
    local pos = U.location(p)
    -- A jump of more than 15 m between steps = elevator / new floor / loaded level:
    -- start the arrival grace (see Arrival in config.lua).
    if pos and Pl.lastPos and U.dist(pos, Pl.lastPos) > 1500 then
        HTR.arrivalUntil = os.clock() + cfg().Arrival.GraceSeconds
    end
    if pos and not Pl.lastPos then HTR.wakeHooks = true end -- first step on foot: register the rest quickly
    Pl.lastPos = pos
    HTR.playerLevel = U.get(p, P.PlayerLevel, HTR.playerLevel or 1) -- squad / turret gear level (gear bonus)
    if not enabled() then return end
    local t = os.clock() -- one clock for wounds, healing and hit times
    local dt = math.min(1.0, t - (Pl.lastStep or t))
    Pl.lastStep = t
    if dt > 0 then regenStep(p, t, dt) end
    Pl.addr = U.addr(p)
    local frac = W.fracture(Pl.addr, t)
    Pl.legBroken, Pl.armBroken = frac == "leg", frac == "arm"
    if not Pl.legBroken then Pl.limpWritten = nil end
end

return Pl
