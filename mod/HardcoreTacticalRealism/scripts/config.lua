--[[
  Hardcore Tactical Realism (HTR) - Combat & AI Overhaul for SpaceBourne 2
  ======================================================================
  USER SETTINGS. Edit this file with any text editor, then restart the game.
  Everything here is optional: delete a line and the default is used.
]]

return {
    -- Enemies always use the realistic model. The mode decides what happens to YOUR side:
    --   "Tactical"          damage you take follows weapon and hit zone, kept at 100-150% of vanilla
    --   "Tactical Hardcore" Tactical, with ALL damage doubled (you, allies and enemies)
    --   "Realism"           you and your allies follow exactly the same caliber/armor/hit-zone
    --                       rules as enemies
    --   "Realism Hardcore"  Realism, with ALL damage doubled (you, allies and enemies)
    Mode = "Tactical",

    -- Key that cycles the four modes in game (shown on screen, remembered in state.txt).
    -- Any UE4SS key name (F7, NUM_ZERO, DEL...), optionally with Ctrl/Shift/Alt: "Shift+F7".
    -- Set to "" to disable. Keys the game uses itself (F1-F6, F8 quick load, F10, F12) are
    -- refused without a modifier. (On foot, Ctrl alone opens the map and Alt crouches.)
    ToggleModeKey = "F7",

    -- What the "Hardcore" modes multiply damage by.
    HardcoreDamageMultiplier = 2.0,
    HardcoreAlsoForEnemies   = true, -- false = only you and your allies take the extra damage

    Features = {
        RealisticDamageToNPCs   = true,  -- caliber vs armor + hit zones, no level scaling
        RealisticDamageToPlayer = true,  -- the Mode rules for damage you take
        FriendlyFireRules       = true,  -- see FriendlyFire below
        SmarterAI               = true,  -- reactions, retreat, alerts, cover, suppression
        FactionDoctrines        = true,  -- pirates fight differently from elite troops
        RealisticNPCBallistics  = true,  -- fast NPC projectiles + human aim spread
        CompanionFixes          = true,  -- companions' projectiles work and hit hard
        Suppression             = true,  -- your near misses pin enemies down
        NPCGrenades             = true,  -- regulars and elites throw grenades when you hide too long
    },

    Damage = {
        GlobalToNPCs      = 1.0,  -- multiply all damage NPCs take (0.8 = tougher NPCs)
        MinPercentPerHit  = 10,   -- any bullet removes at least this % of HP (caps hits-to-kill at ~10)
        BossVitality      = 1.8,  -- bosses have 1.8x the "body" of a soldier
        TankVitality      = 2.0,  -- heavy robot tanks
        RobotVitality     = 1.2,
        PirateArmorShift  = -1,   -- pirates/raiders wear one armor class less
        ExplosionRadius   = 600,  -- cm; grenade/rocket damage fades to 0 at this distance
        -- Squad soldiers: chance a lethal hit kills outright instead of "injured first".
        -- In the Realism modes headshots and heavy overkill always kill outright.
        SquadOutrightDeath = { ["Tactical"] = 0, ["Tactical Hardcore"] = 0, ["Realism"] = 0.8, ["Realism Hardcore"] = 0.95 },
        HelmetMinPass     = 0.4,  -- no helmet fully stops a headshot: at least 40% gets through
                                  -- (any firearm kills in 1-2 headshots); applies in every mode
    },

    -- Arrival grace: after an elevator ride / new floor / level load, and for freshly spawned
    -- NPCs, everyone (enemies and allies) aims very badly for a few seconds, so dungeon floors
    -- don't start with an instant massacre.
    Arrival = { GraceSeconds = 4, SpawnGraceSeconds = 3 },

    -- Gamepad: press "switch camera" 4 times quickly = next mode; crouched = ships toggle.
    GamepadToggles = true,

    Wounds = {
        Bleeding        = true, -- penetrating hits can open bleeding wounds (nanites clot them in 15-25 s);
                                -- heavy limb hits can break an arm (shaky aim) or leg.
                                -- Robots never bleed, but their arms and legs can still be wrecked.
        -- Broken bones (about a minute until the nanites fuse them):
        LegSpeed     = 0.5, -- broken leg: you move at this fraction of the speed; NPCs and squad can only walk
        ArmSway      = 6,   -- broken arm: your aim drifts and trembles (deg/s) while a gun is drawn
        NpcArmSpread = 3.0, -- broken arm: NPC aim spread multiplier
        -- how often you and your allies get wounded (enemies always 1.0)
        Frequency = { ["Tactical"] = 0.4, ["Tactical Hardcore"] = 0.6, ["Realism"] = 1.0, ["Realism Hardcore"] = 1.0 },
    },

    -- Nanotech healing between fights. HP: multiplier on the game's own suit healing
    -- (1.0 = vanilla speed). Armor: nanite repair, % of max armor per second.
    -- Healing starts Delay seconds after your last hit and pauses while you bleed.
    Regen = {
        Enabled = true,
        ["Tactical"]          = { Delay = 8,  HP = 0.7,  Armor = 1.5 },
        ["Tactical Hardcore"] = { Delay = 10, HP = 0.5,  Armor = 1.0 },
        ["Realism"]           = { Delay = 12, HP = 0.25, Armor = 0.5 },
        ["Realism Hardcore"]  = { Delay = 15, HP = 0.12, Armor = 0.3 },
    },

    -- Gear bonus (OFF by default; Shift+F7 toggles in game, remembered). For a light RPG feel:
    -- weapon and armor level (and item rarity) add a SMALL extra on top of the ballistics.
    -- They never decide whether a weapon works: a level 5 rifle still drops a level 60
    -- raider in a few hits, just one more than a level 60 rifle would need.
    --   quality = log(level) / log(MaxLevel): level 1 = 0, 10 = 56 %, 30 = 83 %, MaxLevel = 100 %
    --   weapon: up to +WeaponPen penetration points and +WeaponDamage damage
    --   armor:  up to +ArmorRating protection points and ArmorWear less wear (only where there is armor)
    -- Levels: your weapon and suit items (each rarity step above common counts as RarityLevels
    -- levels), NPCs and turrets their own level, squad soldiers your level. Works the same for
    -- both sides, so it also fits the Realism modes; switch it off per mode in Modes.
    GearBonus = {
        Enabled      = false,
        ToggleKey    = "Shift+F7", -- not F8: that is the game's quick load
        MaxLevel     = 60,
        RarityLevels = 5,
        WeaponPen    = 8,     -- armor ratings are light 35, medium 50, heavy 64, power 72
        WeaponDamage = 0.15,  -- +15 %
        ArmorRating  = 8,
        ArmorWear    = 0.25,  -- 25 % less wear
        Modes = { ["Tactical"] = true, ["Tactical Hardcore"] = true, ["Realism"] = true, ["Realism Hardcore"] = true },
    },

    -- Slow perks (ON by default; F11 toggles in game, remembered). With realistic damage,
    -- perks (turret, barricade, ground slam, shield, slow time...) become super powers.
    -- On foot, the suit's perk energy refills EnergyRegen times as fast as vanilla and the
    -- turret / barricade / ground-slam / auto-revive cooldowns run Cooldown times as fast.
    -- Ship energy is not affected. 1.0 = vanilla.
    Perks = { SlowOnFoot = true, ToggleKey = "F11", EnergyRegen = 0.25, Cooldown = 0.25 },

    -- Situational awareness of enemies: relaxed (they haven't noticed a fight yet) they only
    -- notice you up close; once alert (they spotted you, got hit or were warned) they scan,
    -- spot and shoot much farther. Multipliers on each doctrine's sight range.
    Awareness = { Enabled = true, RelaxedSight = 0.55, AlertSight = 1.25 },

    -- Your ground squad following you. Vanilla makes them walk, so they fall behind and
    -- teleport next to you once 30 m away. KeepUp makes them run (beyond RunBeyond cm)
    -- and sprint (beyond SprintBeyond cm), so only a stuck soldier still teleports.
    Squad = { KeepUp = true, RunBeyond = 600, SprintBeyond = 1500 },

    -- Ships vs infantry: ship guns (yours and AI ships') hit people on foot.
    Ships = {
        Enabled         = true,  -- starting state; F9 toggles in game (remembered)
        ToggleKey       = "F9",
        DirectHitDamage = 300,   -- % of a body for a direct hit (kills almost anything)
        SplashDamage    = 150,   -- % at the impact point, fading to 0 at SplashRadius
        SplashRadius    = 500,   -- cm
    },

    Tactical = {
        MaxIncomingVsVanilla = 1.5, -- damage to you (and your allies) is 100% to 150% of vanilla
        MinIncomingVsVanilla = 1.0,
        HeadMultiplier       = 1.5, -- extra damage when you are hit in the head (still capped)
    },

    Realism = {
        PlayerVitality       = 1.0, -- 1.2 = you can take 20% more punishment
        UnattributedMultiplier = 2.0, -- explosions/DoT/unknown sources vs vanilla
        UnattributedMaxPercent = 60,  -- ...but never more than this % of max HP at once
    },

    FriendlyFire = {
        -- Damage factor between you and allied NPCs (companions, squad, crew).
        -- "Tactical" applies to both Tactical modes, "Realism" to both Realism modes.
        PlayerToAlly = { Tactical = 0.35, Realism = 1.0 },
        AllyToPlayer = { Tactical = 0.35, Realism = 1.0 },
        -- Allied NPCs / allied turrets hitting each other: vanilla damage,
        -- but never more than this % of the victim's max HP per hit.
        AllyToAllyCapPercent = 10,
        -- Enemies hitting other enemies: 1.0 = fully realistic.
        EnemyToEnemy = 1.0,
    },

    Debug = {
        Log     = false,  -- write HardcoreTacticalRealism\htr.log (errors are always written)
        LogHits = false,  -- log every hit (verbose; for tuning)
        SlowHookMs = 8,   -- performance watchdog: HTR code slower than this is reported in htr.log
    },
}
