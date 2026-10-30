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

    if realism and caliber and not entry.radial then
        local integrity = (maxArmor > 0) and (armor / maxArmor) or 0
        local hpPct, ablation = B.compute({ caliber = caliber, zone = zone, ratings = playerArmorRatings(p), hasHelmet = true,
            integrity = integrity, vitality = c.Realism.PlayerVitality, minPct = c.Damage.MinPercentPerHit, rnd = math.random() })
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
            U.log(string.format("PLAYER <- %s %s zone=%s raw=%.1f mode=%s => hp %.1f armor %.1f", tostring(side), tostring(caliber),
                tostring(zone), e.raw, HTR.mode, hp, armor))
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

-- Hook: ALS_Base_C:ReceiveTick - leftovers and absorb upkeep.
function Pl.onTick(self)
    local p = self:get()
    Pl.tick = Pl.tick + 1
    if #Pl.pending > 0 then
        if G.PlayerClassNames[U.className(p) or ""] then Pl.resolve(p, nil, nil) end
        return
    end
    local t = os.clock()
    if t > Pl.nextAbsorb then
        Pl.nextAbsorb = t + 1.0
        if G.PlayerClassNames[U.className(p) or ""] then Pl.enforceAbsorb(p) end
    end
end

return Pl
