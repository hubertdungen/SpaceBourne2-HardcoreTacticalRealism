--[[
  Who is who: side (player / ally / enemy), armor class, doctrine and caliber.
]]

local U = require("htr.util")
local G = require("htr.gamedefs")
local B = require("htr.ballistics")
local P = G.P

local C = {}

-- Class name -> "family" (player / shooter / soldier / nil), resolved once per
-- class by walking the parent chain, so Blueprint subclasses are recognised.
local family = {}
local function familyOf(actor, cn)
    local f = family[cn]
    if f ~= nil then return f or nil end
    f = false
    local ok = pcall(function()
        local cls = actor:GetClass()
        for _ = 1, 10 do
            if not (cls and cls:IsValid()) then break end
            local n = cls:GetFName():ToString()
            if G.PlayerClassNames[n] then f = "player" break end
            if G.ShooterClassNames[n] then f = "shooter" break end
            if G.SoldierClassNames[n] then f = "soldier" break end
            if G.TurretClassNames[n] then f = "turret" break end
            cls = cls:GetSuperStruct()
        end
    end)
    if not ok then f = false end
    family[cn] = f
    return f or nil
end
C.familyOf = familyOf

-- side: "player", "ally", "enemy", "other"
function C.sideOf(actor)
    local cn = U.className(actor)
    if not cn then return "other", cn end
    local fam = familyOf(actor, cn)
    if fam == "player" then return "player", cn end
    if fam == "shooter" then
        if U.get(actor, P.IsCompanion, false) or U.get(actor, P.CivilCompanion, false)
            or U.get(actor, P.AIType, 0) == G.AIType.Ally then
            return "ally", cn
        end
        return "enemy", cn
    end
    if fam == "soldier" or fam == "turret" then
        -- Master_Soldier family and ground turrets: AI_Type 1 = player's side
        local t = U.get(actor, "AI_Type", 1)
        return (t == 1) and "ally" or "enemy", cn
    end
    return "other", cn
end

-- Doctrine key for a shooter NPC.
function C.doctrineOf(npc, cn)
    if U.get(npc, P.IsCompanion, false) or U.get(npc, P.AIType, 0) == G.AIType.Ally then return "companion" end
    if U.get(npc, P.Robot, false) or U.get(npc, P.SubType, 0) == G.SubType.Tank then return "machine" end
    if U.get(npc, P.IsBoss, false) then return "elite" end
    if U.get(npc, P.Raider, false) or G.PirateClassNames[cn or ""] then return "pirate" end
    if G.GuardClassNames[cn or ""] or U.get(npc, P.AIType, 0) == G.AIType.Guard then return "elite" end
    local tier = U.get(npc, P.Tier, 2)
    if tier >= 3 then return "elite" end
    if tier <= 1 then return "militia" end
    return "regular"
end

-- Armor class, helmet and vitality for a shooter NPC.
function C.protectionOf(npc, cn, cfg)
    if U.get(npc, P.IsCitizen, false) then return "none", false, 1.0 end
    local tier = U.get(npc, P.Tier, 2)
    local cls = ({ [0] = "none", [1] = "light", [2] = "medium", [3] = "heavy", [4] = "heavy" })[tier] or "medium"
    local helmet = U.get(npc, P.Helmet, false)
    local vit = 1.0
    if U.get(npc, P.Raider, false) or G.PirateClassNames[cn or ""] then
        cls = B.shiftArmor(cls, cfg.Damage.PirateArmorShift or -1)
    end
    if U.get(npc, P.Robot, false) then
        cls = B.shiftArmor(cls, 1); if cls == "none" or cls == "light" then cls = "heavy" end
        helmet = true; vit = cfg.Damage.RobotVitality or 1.2
    end
    if U.get(npc, P.IsBoss, false) then cls = "power"; helmet = true; vit = cfg.Damage.BossVitality or 1.6 end
    if U.get(npc, P.SubType, 0) == G.SubType.Tank then cls = "power"; helmet = true; vit = cfg.Damage.TankVitality or 2.0 end
    return cls, helmet, vit
end

-- Caliber used by an attacker right now.
function C.caliberOf(attacker, side, cn, victim)
    if side == "player" then
        if U.get(attacker, P.MeleeOn, false) then
            local mw = U.get(attacker, P.MeleeWeapon, nil)
            return G.MeleeCaliber[U.className(mw) or ""] or "sword"
        end
        local comp = U.get(attacker, P.Weapon, nil)
        local weapon = comp and U.get(comp, "ChildActor", nil)
        return G.WeaponCaliber[U.className(weapon) or ""] or "rifle"
    end
    local fam = cn and familyOf(attacker, cn)
    if fam == "shooter" then
        if U.get(attacker, P.SwordAttack, false) then return "npc_melee" end
        if victim then
            local d = U.dist(U.location(attacker), U.location(victim))
            if d < 260 then return "npc_melee" end
        end
        if U.get(attacker, P.Sniper, false) then return "npc_sniper" end
        if U.get(attacker, P.SubType, 0) == G.SubType.Tank or cn == "EBP_SisterTween_C" then return "npc_heavy" end
        if U.get(attacker, P.IsBoss, false) then return "npc_boss" end
        return "npc_rifle"
    end
    if fam == "soldier" then return "squad_rifle" end
    if fam == "turret" then return "turret" end
    return "generic"
end

function C.zoneOf(boneName, headShot)
    if headShot then return "head" end
    if not boneName or boneName == "None" then return "unknown" end
    return G.BoneZone[string.lower(boneName)] or "torso"
end

return C
