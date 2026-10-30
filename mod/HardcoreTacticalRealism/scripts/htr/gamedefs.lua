--[[
  Every SpaceBourne 2 internal name HTR depends on lives in this file.
  When a game update renames something, this is the only file to fix.
  Names come from the game's Blueprints (UE 4.27, verified on build 2026-10-26).
]]

local G = {}

-- Classes -------------------------------------------------------------------
G.Shooter    = "/Game/1Data/11_AI/Q1_Shooter_AI.Q1_Shooter_AI_C"           -- every on-foot NPC with a gun
G.Player     = "/Game/1Data/Q1_Character.Q1_Character_C"
G.ALSBase    = "/Game/Locomotion/Blueprints/CharacterLogic/ALS_Base.ALS_Base_C"
G.Soldier    = "/Game/1Data/11_AI/BattleAI/Master_Soldier.Master_Soldier_C" -- player squad / ground battles
G.BattleAI   = "/Game/1Data/11_AI/TeamBattle/Q1_Battle_AI.Q1_Battle_AI_C"
G.HandWeapon = "/Game/1Data/Weapons/Hand_Weapons/Weapons/Master_Hand_Weapon.Master_Hand_Weapon_C"
G.Turret     = "/Game/1Data/11_AI/TeamBattle/BattleObjects/RTS_Turret.RTS_Turret_C"   -- ground turrets (AI_Type = team)
G.Drone      = "/Game/1Data/11_AI/TeamBattle/Battle_Drone.Battle_Drone_C"
G.ShootCoverBT = "/Game/1Data/11_AI/1_VAL_ShootCover.1_VAL_ShootCover"

-- Short class names (GetClass():GetFName()) -----------------------------------
G.ShooterClassNames = {
    Q1_Shooter_AI_C = true, Q1_GuardShooter_C = true, Q1_Shooter_Robot_C = true, Q1_Boss_C = true,
    Q1_MasterMiniBoss_C = true, SneakyMiniBoss_C = true, Q1_Companin_AI_C = true, Q1_Civil_Follower_C = true,
    CargoShooter_C = true, SalvageDungeonEnemy_C = true, EBP_Sister_C = true, EBP_SisterTween_C = true,
}
G.PirateClassNames  = { CargoShooter_C = true, SalvageDungeonEnemy_C = true }
G.GuardClassNames   = { Q1_GuardShooter_C = true }
G.PlayerClassNames  = { Q1_Character_C = true }
G.SoldierClassNames = { Master_Soldier_C = true }
G.TurretClassNames  = { RTS_Turret_C = true }

-- Player hand weapon class -> HTR caliber (see ballistics.lua)
G.WeaponCaliber = {
    Bullet_Pistol_C      = "pistol",
    Laser_Pistol_C       = "pistol_laser",
    Bullet_Rifle_C       = "rifle",
    Pulse_Rifle_C        = "rifle_pulse",
    SubmarineRifle_C     = "smg",
    Submachine_Laser_C   = "beam",
    MiscBeam_C           = "beam",
    Shotgun_Rifle_C      = "shotgun",
    Shotgun_Laser_C      = "shotgun_laser",
    Sniper_Rifle_C       = "sniper",
    Sniper_Laser_C       = "sniper_laser",
    Hunter_BulletRifle_C = "dmr",
    Hunter_LaserRifle_C  = "dmr_laser",
}
G.MeleeCaliber = { KnifeType_C = "knife", KatanaType_C = "sword", HeavyType_C = "hammer" }

-- Hooked functions ------------------------------------------------------------
G.Fn = {
    NpcCalculateStats  = G.Shooter .. ":CalculateStats",
    NpcCalculateDamage = G.Shooter .. ":CalculateDamage",          -- (DamageOut, DamageCauser, out DMGOut)
    NpcReceivePoint    = G.Shooter .. ":ReceivePointDamage",
    NpcOnDead          = G.Shooter .. ":OnDeadEvent",
    NpcThink           = G.Shooter .. ":CheckMeleeDistance",       -- runs every 1 s on every shooter
    NpcRifleEyeUpdated = G.Shooter .. ":BndEvt__Q1_Shooter_AI_RifleEye_K2Node_ComponentBoundEvent_5_OnTargetUpdated__DelegateSignature",
    NpcRifleEyeDetected= G.Shooter .. ":BndEvt__Q1_Shooter_AI_RifleEye_K2Node_ComponentBoundEvent_3_OnTargetDetected__DelegateSignature",
    PlayerIncome       = G.Player .. ":CalculateIncomeDamage",     -- (Damage, out Dead?, out ArmorDamage?)
    PlayerRadial       = G.Player .. ":ReceiveRadialDamage",
    PlayerTick         = G.ALSBase .. ":ReceiveTick",
}
-- Projectile-hit events: (OutProjectileObject, OutHitResult, OutAttachComponents, OutProjectileLocation, OutProjectileDirection)
G.NpcProjectileHits = {
    G.Shooter .. ":OnProjectileHit_03F94406443931C1DCEDC2920A189A84",
    G.Shooter .. ":OnProjectileHit_EA71D2CB4AF2DDD1487199994F37FD32",
    G.Soldier .. ":OnProjectileHit_7BDC272F4B923FF09908358E50762F8D",
    G.BattleAI .. ":OnProjectileHit_9835CF3447B6AF136D21F992D0240016",
    G.Turret .. ":OnProjectileHit_C3F8D03949DD49D1E6C65EA11C41015D",
    G.Drone .. ":OnProjectileHit_D0A49B3840F72CF10A2487AC824BB302",
}
G.PlayerProjectileHits = {}
for _, guid in ipairs({ "C6643AF84D4AB4342E72C7AF57715CE6", "9DAC8CC648A8DCFEE1BE598B9C94CA79", "52750BFC4CD152D861F06D9309C7FA39",
    "EFC583864537553C5A543D852264593A", "AEEB3FF9468D66E105DB4892C03A6C07", "C17D4B8141472A906D873E9C2C08887D",
    "808BFD2441DD8B73192818A6FB4C2BD5" }) do
    G.PlayerProjectileHits[#G.PlayerProjectileHits + 1] = G.HandWeapon .. ":OnProjectileHit_" .. guid
end

-- Properties (names exactly as in the Blueprints; some contain spaces or '?') --
G.P = {
    -- shooter NPC
    Ready = "Ready?", Dead = "NPCDead", HP = "CurrentHP", MaxHP = "MaxHP", Armor = "CurrentArmor", MaxArmor = "MaxArmor",
    HaveShield = "HaveShield", Tier = "Tier", Level = "Level", IsBoss = "IsBoss", SubType = "SubType", AIType = "AIType",
    IsCompanion = "IsCompanian", CivilCompanion = "CivilCompanian?", IsCitizen = "IsCitizen", Robot = "Robot?",
    Raider = "Raider?", Sniper = "IsSniper?", Helmet = "HelmetModeOn?", DisableHeadShot = "DisableHeadShot",
    HeadShot = "Head Shot", BoneName = "Bone Name", ProjSpeed = "In Projectile Speed", ProjLife = "In Projectile Life Time",
    ShootRate = "ShootRate", MaxAmmo = "MaxAmmo", SwordAttack = "SwordAttackOn", CanSee = "CanSeeTheTarget",
    ShootTarget = "ShooTarget", EyeSight = "XVisionEye", EyeRifle = "RifleEye", LastDetected = "LastDetectedActor",
    -- player
    PlayerAbsorb = "DamageAbsorbChance_0_0", PlayerLevel = "PlayerLevel", GodMode = "GodModeOn?",
    Mercenary = "IsMercinerySubClassSetted", Cyborg = "CyborgModeOn?", Weapon = "CurrentWeapon",
    MeleeOn = "MeleeAttackOn?", MeleeWeapon = "As Master Melee Weapon",
}
-- Blackboard keys used by the shooter behaviour trees
G.BB = { JustGotDamage = "JustGotDamage", FirstInteract = "IsFirstInteract", InCover = "InCover?", InCombat = "InCombat?" }

-- Enums
G.AIType  = { Enemy = 0, Ally = 1, Civil = 2, Natural = 3, Guard = 4 }
G.SubType = { Shooter = 0, Tank = 1, Melee = 2, Mage = 3 }

-- Skeleton bone name -> hit zone (lower case)
G.BoneZone = {
    head = "head", neck_01 = "head", neck_02 = "head",
    pelvis = "torso", spine_01 = "torso", spine_02 = "torso", spine_03 = "torso", spine_04 = "torso", spine_05 = "torso",
    clavicle_l = "torso", clavicle_r = "torso",
    upperarm_l = "arm", upperarm_r = "arm", lowerarm_l = "arm", lowerarm_r = "arm", hand_l = "arm", hand_r = "arm",
    upperarm_twist_01_l = "arm", upperarm_twist_01_r = "arm", lowerarm_twist_01_l = "arm", lowerarm_twist_01_r = "arm",
    thigh_l = "leg", thigh_r = "leg", calf_l = "leg", calf_r = "leg", foot_l = "leg", foot_r = "leg", ball_l = "leg", ball_r = "leg",
    thigh_twist_01_l = "leg", thigh_twist_01_r = "leg", calf_twist_01_l = "leg", calf_twist_01_r = "leg",
}

-- Behaviour tree node tuned once at start: seconds an NPC waits in cover between peeks (vanilla 5)
G.PeekCooldownNode = G.ShootCoverBT .. ":BTDecorator_Cooldown_6"

return G
