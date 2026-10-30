--[[
  Optional gear bonus (off by default, Ctrl+Insert / GearBonus in config.lua).
  For players who like a bit of RPG feel: weapon and armor level (and item rarity)
  give a SMALL bonus on top of the ballistic model. They never decide whether a
  weapon can kill - a level 5 rifle still drops a level 60 raider in a few hits.

    quality q (0..1) = log(level) / log(MaxLevel)
        level 1 = 0, level 10 = 0.56, level 30 = 0.83, MaxLevel = 1 (diminishing returns)
    weapon: +q * WeaponPen penetration points (armor ratings are 35..72), +q * WeaponDamage damage
    armor:  +q * ArmorRating protection points, -q * ArmorWear wear (only where there is armor)

  Levels: your weapon and suit items (rarity counts as RarityLevels extra levels per
  step above common); NPCs and ground turrets their own level; squad / battle soldiers your level.
  Symmetric for both sides, so it fits the Realism modes too (Modes can switch it off per mode).
]]

local U = require("htr.util")
local G = require("htr.gamedefs")
local C = require("htr.classify")
local P = G.P

local GB = { cache = {} }

local function cfg() return HTR.cfg.GearBonus end

function GB.active()
    return HTR.gearOn == true and (cfg().Modes or {})[HTR.mode] ~= false
end

function GB.quality(level, rarity)
    local c = cfg()
    local eff = (tonumber(level) or 1) + math.max(0, (tonumber(rarity) or 1) - 1) * c.RarityLevels
    return U.clamp(math.log(math.max(1, eff)) / math.log(math.max(2, c.MaxLevel)), 0, 1)
end

-- Your level (updated by the player tick); squad soldiers and turrets use it.
local function yourLevel() return HTR.playerLevel or 1 end

-- Quality of an S_Item_Data struct, cached for a few seconds per key (gear rarely changes).
local function itemQuality(key, getItem, fallbackLevel)
    local now = os.clock()
    local e = GB.cache[key]
    if e and now - e.t < 5 then return e.q end
    local lvl, tier
    pcall(function()
        local item = getItem()
        lvl, tier = item[G.Item.Level], item[G.Item.Rarity]
    end)
    -- the game leaves some item data empty (the suit reads level 0): then your level counts
    local L, R = tonumber(lvl), tonumber(tier)
    if not L or L < 1 then L, R = fallbackLevel, nil end
    local q = GB.quality(L, R)
    if not e then
        GB.n = (GB.n or 0) + 1
        if GB.n > 64 then GB.cache, GB.n = {}, 1 end -- old weapons: keep the cache small
    end
    GB.cache[key] = { q = q, t = now, level = lvl, rarity = tier }
    return q
end

-- Weapon quality of whoever fired (0 when the bonus is off or the attacker is unknown).
function GB.weapon(attacker)
    if not GB.active() or not U.valid(attacker) then return 0 end
    local fam = C.familyOf(attacker, U.className(attacker) or "")
    if fam == "player" then
        local lvl = U.get(attacker, P.PlayerLevel, 1)
        if U.get(attacker, P.MeleeOn, false) then return GB.quality(lvl) end
        local comp = U.get(attacker, P.Weapon, nil)
        local w = comp and U.get(comp, "ChildActor", nil)
        if not U.valid(w) then return GB.quality(lvl) end
        return itemQuality("w" .. tostring(U.addr(w)), function() return w[G.Item.WeaponData][G.Item.WeaponItem] end, lvl)
    elseif fam == "shooter" or fam == "turret" then -- NPCs and ground turrets have their own level
        return GB.quality(U.get(attacker, P.Level, yourLevel()))
    elseif fam == "soldier" then -- squad / battle soldiers have no level: issued kit at yours
        return GB.quality(yourLevel())
    end
    return 0
end

-- Armor quality of an NPC (st from npc.lua); unarmored NPCs get nothing.
function GB.npcArmor(st)
    if not GB.active() or not st or st.armor == "none" then return 0 end
    return GB.quality(st.level or 1)
end

-- Armor quality of your squad / battle soldiers (issued kit at your level).
function GB.soldierArmor()
    if not GB.active() then return 0 end
    return GB.quality(yourLevel())
end

-- Armor quality of your suit.
function GB.suit(p)
    if not GB.active() then return 0 end
    return itemQuality("suit" .. tostring(U.addr(p)), function() return p[G.Item.CharacterData][G.Item.SuitItem] end,
        U.get(p, P.PlayerLevel, 1))
end

-- Adds the bonus fields B.compute understands. wq/aq: weapon/armor quality 0..1.
function GB.apply(a, wq, aq)
    local c = cfg()
    wq, aq = wq or 0, aq or 0
    if wq > 0 then a.penBonus, a.dmgMult = wq * c.WeaponPen, 1 + wq * c.WeaponDamage end
    if aq > 0 then a.ratingBonus, a.wearMult = aq * c.ArmorRating, 1 - aq * c.ArmorWear end
    return a
end

-- For the log / HUD: what the bonus currently reads from your gear.
function GB.describe(p)
    local w, s = "?", "?"
    for k, e in pairs(GB.cache) do
        if k:sub(1, 1) == "w" then w = string.format("L%s R%s q%.2f", tostring(e.level), tostring(e.rarity), e.q) end
        if k:sub(1, 4) == "suit" then s = string.format("L%s R%s q%.2f", tostring(e.level), tostring(e.rarity), e.q) end
    end
    return "weapon " .. w .. ", suit " .. s
end

return GB
