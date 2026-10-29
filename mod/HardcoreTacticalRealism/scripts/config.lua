--[[
  Hardcore Tactical Realism (HTR) - Combat & AI Overhaul for SpaceBourne 2
  ======================================================================
  USER SETTINGS. Edit this file with any text editor, then restart the game.
  Everything here is optional: delete a line and the default is used.
]]

return {
    -- "Tactical": enemies die fast; damage YOU take is at most +50% of vanilla.
    -- "Hardcore": you and your allies take damage with exactly the same
    --             caliber/armor/hit-zone rules as enemies. Very lethal.
    Mode = "Tactical",

    -- Key that switches Tactical <-> Hardcore in game (remembered in state.txt).
    -- Any UE4SS key name: F1..F12, NUM_ZERO.. etc. Set to "" to disable.
    ToggleModeKey = "F7",

    Features = {
        RealisticDamageToNPCs   = true,  -- caliber vs armor + hit zones, no level scaling
        RealisticDamageToPlayer = true,  -- Tactical/Hardcore rules for damage you take
        FriendlyFireRules       = true,  -- see FriendlyFire below
        SmarterAI               = true,  -- reactions, retreat, alerts, cover, suppression
        FactionDoctrines        = true,  -- pirates fight differently from elite troops
        RealisticNPCBallistics  = true,  -- fast NPC projectiles + human aim spread
        CompanionFixes          = true,  -- companions' projectiles work and hit hard
        Suppression             = true,  -- your near misses pin enemies down
        NPCGrenades             = false, -- EXPERIMENTAL: elite troops flush you out of cover
    },

    Damage = {
        GlobalToNPCs      = 1.0,  -- multiply all damage NPCs take (0.8 = tougher NPCs)
        MinPercentPerHit  = 10,   -- any bullet removes at least this % of HP (caps hits-to-kill at ~10)
        BossVitality      = 1.8,  -- bosses have 1.8x the "body" of a soldier
        TankVitality      = 2.0,  -- heavy robot tanks
        RobotVitality     = 1.2,
        PirateArmorShift  = -1,   -- pirates/raiders wear one armor class less
    },

    Tactical = {
        MaxIncomingVsVanilla = 1.5, -- enemy damage to you is capped at +50% of vanilla
        MinIncomingVsVanilla = 0.6,
        HeadMultiplier       = 1.5, -- extra damage when you are hit in the head (still capped)
    },

    Hardcore = {
        PlayerVitality       = 1.0, -- 1.2 = you can take 20% more punishment
        UnattributedMultiplier = 2.0, -- explosions/DoT/unknown sources vs vanilla
        UnattributedMaxPercent = 60,  -- ...but never more than this % of max HP at once
    },

    FriendlyFire = {
        -- Damage factor between you and allied NPCs (companions, squad, crew).
        PlayerToAlly = { Tactical = 0.35, Hardcore = 1.0 },
        AllyToPlayer = { Tactical = 0.35, Hardcore = 1.0 },
        -- Allied NPCs / allied turrets hitting each other: vanilla damage,
        -- but never more than this % of the victim's max HP per hit.
        AllyToAllyCapPercent = 10,
        -- Enemies hitting other enemies: 1.0 = fully realistic.
        EnemyToEnemy = 1.0,
    },

    Debug = {
        Log     = false,  -- write HardcoreTacticalRealism\htr.log (errors are always written)
        LogHits = false,  -- log every hit (verbose; for tuning)
    },
}
