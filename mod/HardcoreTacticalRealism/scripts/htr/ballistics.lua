--[[
  Ballistics: calibers, armor classes, hit zones and the damage formula.
  Pure Lua, no game calls - safe to tune and to test outside the game.

  Damage is expressed in "% of a body" (100 = one unarmored person dead),
  so it is independent of NPC level, weapon level and rarity.

  Penetration vs armor:  x = pen / rating
     x >= 1.5  -> full damage goes through
     x <= 0.5  -> armor stops the round; only blunt trauma (Floor) gets through
     between   -> linear blend
]]

local B = {}

B.Floor = 0.18    -- fraction of damage that always gets through as trauma
B.Ablation = 0.28 -- how fast stopped rounds wear the armor down (condition % per stopped damage)
B.HeadMinPass = 0.4 -- no helmet fully stops a headshot: at least this fraction always gets through

-- dmg: % of an unarmored body for a centre-mass hit. pen: armor penetration.
B.Calibers = {
    -- player weapons
    pistol        = { dmg = 52,  pen = 30 },
    pistol_laser  = { dmg = 55,  pen = 38 },
    smg           = { dmg = 50,  pen = 30 },
    rifle         = { dmg = 55,  pen = 42 },
    rifle_pulse   = { dmg = 50,  pen = 46 },
    dmr           = { dmg = 85,  pen = 58 },
    dmr_laser     = { dmg = 85,  pen = 62 },
    sniper        = { dmg = 125, pen = 82 },
    sniper_laser  = { dmg = 120, pen = 86 },
    shotgun       = { dmg = 20,  pen = 22, pellet = true },
    shotgun_laser = { dmg = 18,  pen = 26, pellet = true },
    beam          = { dmg = 6,   pen = 60, tick = true },
    knife         = { dmg = 120, pen = 48, melee = true },
    sword         = { dmg = 150, pen = 56, melee = true },
    hammer        = { dmg = 160, pen = 70, melee = true },
    -- NPC weapons
    npc_rifle     = { dmg = 50,  pen = 42 },
    npc_sniper    = { dmg = 120, pen = 82 },
    npc_heavy     = { dmg = 60,  pen = 58 },
    npc_boss      = { dmg = 55,  pen = 50 },
    npc_melee     = { dmg = 65,  pen = 50, melee = true },
    squad_rifle   = { dmg = 52,  pen = 42 },
    turret        = { dmg = 100, pen = 72 }, -- ground turrets: heavy emplaced gun, one round every ~1.5 s
    explosion     = { dmg = 150, pen = 60, tick = true }, -- grenades/rockets at the blast centre
    ship          = { dmg = 300, pen = 95, tick = true }, -- ship guns hitting infantry
    generic       = { dmg = 50,  pen = 40 },
}

-- Armor classes. body/helmet = protection rating, limbs get LimbFactor of body.
B.Armor = {
    none   = { body = 0,  helmet = 0 },
    light  = { body = 35, helmet = 30 },
    medium = { body = 50, helmet = 45 },
    heavy  = { body = 64, helmet = 60 },
    power  = { body = 72, helmet = 68 },
}
B.ArmorOrder = { "none", "light", "medium", "heavy", "power" }
B.LimbFactor = 0.7

-- Hit zone multipliers on raw damage.
B.Zones = { head = 4.0, torso = 1.0, arm = 0.55, leg = 0.65, unknown = 0.9 }

function B.shiftArmor(class, steps)
    local idx = 1
    for i, k in ipairs(B.ArmorOrder) do if k == class then idx = i end end
    idx = math.max(1, math.min(#B.ArmorOrder, idx + (steps or 0)))
    return B.ArmorOrder[idx]
end

-- Fraction of damage that passes armor with rating r.
function B.passFraction(pen, r)
    if r <= 0 then return 1.0 end
    local x = pen / r
    if x >= 1.5 then return 1.0 end
    if x <= 0.5 then return B.Floor end
    return B.Floor + (x - 0.5) * (1.0 - B.Floor)
end

--[[
  args: caliber (key), zone, armor (class key), hasHelmet (bool),
        integrity (0..1 armor condition), vitality (body multiplier),
        minPct (floor per hit, % of body), rnd (0..1 random)
        optional gear bonus (gear.lua): penBonus, dmgMult, ratingBonus, wearMult
  returns hpPct (% of max HP to remove), ablationPct (% of armor condition lost), pass
]]
function B.compute(a)
    local cal = B.Calibers[a.caliber] or B.Calibers.generic
    local cls = a.ratings or B.Armor[a.armor] or B.Armor.none
    local zone = a.zone or "unknown"
    local zm = B.Zones[zone] or B.Zones.unknown
    local limb = (zone == "arm" or zone == "leg")
    local rating
    if zone == "head" then
        rating = a.hasHelmet and cls.helmet or 0
    elseif limb then
        rating = cls.body * B.LimbFactor
    else
        rating = cls.body
    end
    if rating > 0 and a.ratingBonus then -- better-made armor, only where there is armor
        rating = rating + a.ratingBonus * (limb and B.LimbFactor or 1)
    end
    local integrity = math.max(0, math.min(1, a.integrity or 1))
    rating = rating * (0.35 + 0.65 * integrity) -- damaged armor protects less
    local raw = cal.dmg * zm * (0.9 + 0.2 * (a.rnd or 0.5)) * (a.dmgMult or 1)
    local pass = B.passFraction(cal.pen + (a.penBonus or 0), rating)
    if zone == "head" and not cal.tick and pass < B.HeadMinPass then pass = B.HeadMinPass end
    local eff = raw * pass
    local minPct = a.minPct or 10
    if cal.melee or cal.tick then minPct = 0 end
    if cal.pellet then minPct = minPct / 6 end
    if eff < minPct then eff = minPct end
    local hpPct = eff / math.max(0.1, a.vitality or 1)
    local ablation = 0
    if rating > 0 then ablation = raw * (1 - pass) * B.Ablation * (a.wearMult or 1) end
    return hpPct, ablation, pass
end

-- Shots needed to kill (for documentation / self-test).
function B.shotsToKill(caliber, zone, armor, hasHelmet, vitality)
    local hp, integ, shots = 100, 1.0, 0
    while hp > 0 and shots < 99 do
        local d, abl = B.compute({ caliber = caliber, zone = zone, armor = armor, hasHelmet = hasHelmet,
            integrity = integ, vitality = vitality or 1, minPct = 10, rnd = 0.5 })
        hp = hp - d
        integ = math.max(0, integ - abl / 100)
        shots = shots + 1
    end
    return shots
end

return B
