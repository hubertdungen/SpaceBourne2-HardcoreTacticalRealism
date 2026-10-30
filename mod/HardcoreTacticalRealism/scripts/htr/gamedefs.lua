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
    PerkRegen          = G.ALSBase .. ":Regenerators",             -- 0.25 s: perk energy + cooldowns
}
-- Perks with a cooldown counter (Perk_Learned_DAta structs on ALS_Base); the others only use energy
G.CooldownPerks = { "P_Turret", "P_Barricade", "P_GroundSlum", "P_AutoResurect" }
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

G.Fn.NpcRadial   = G.Shooter .. ":ReceiveRadialDamage"
G.Fn.SoldierHit  = G.Soldier .. ":ReceivePointDamage"
-- squad soldiers: 1.5 s update (no target -> SetWalkSpeed: walk gait, teleport to you beyond 30 m)
G.Fn.SoldierUpdate        = G.Soldier .. ":UpdateBattle"
G.Fn.SoldierWalkSpeed     = G.Soldier .. ":SetWalkSpeed"
G.Fn.SoldierWalkSpeedOrder= G.Soldier .. ":SetWalkSpeed_Guarded"
-- gamepad: the on-foot "switch camera" action (4 quick presses = HTR mode, crouched = ships toggle)
G.Fn.PadCamera   = G.ALSBase .. ":InpActEvt_GP_SwitchCamera1_K2Node_EnhancedInputActionEvent_22"

-- Ships vs infantry: your ship's guns and AI ship rounds
G.ShipGun = "/Game/1Data/Weapons/Turret_Mesh_Actor.Turret_Mesh_Actor_C"
G.ShipGunHits = {}
for _, guid in ipairs({ "44CEBFE94D5634B6FCFBF4985AF60A9B", "1D7F31224BA57FF5F279EDAFC609672C", "97ECA7354EDC78711071CF95F79CB4F4",
    "BD8415344C5BC892F719A28ABD306C47", "98B3A5FC4F97A74FED563FA3F7E5843A", "89D9A10041D68A9FCC09EB917EB9097D" }) do
    G.ShipGunHits[#G.ShipGunHits + 1] = G.ShipGun .. ":OnProjectileHit_" .. guid
end
-- Only classes that define their own OnImpact. S_AI_Railgun_Ally/Enemy inherit S_AI_Ammo's,
-- so the S_AI_Ammo hook already covers them (hooking a function that does not exist costs ~37 ms per look).
G.AIShipImpacts = {}
for _, n in ipairs({ "S_AI_Ammo", "S_AI_Ammo_Capital_Enemy", "S_AI_Ammo_Capital_Enemy1_Ally" }) do
    G.AIShipImpacts[#G.AIShipImpacts + 1] = "/Game/1Data/Weapons/N_New_Weapon_Ship/AI_Ammos/" .. n .. "." .. n .. "_C:OnImpact"
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
    RotationMode = "RotationMode", ThrowingGrenade = "ThrowingGranede", Injured = "InInjuredMode",
    -- player perks (ALS_Base)
    EnergyRegen = "EnergyRegenRate", PerkCooldown = "CD_11_004AEE844C3C3A073EF8EAAC2B628430",
    -- player
    PlayerAbsorb = "DamageAbsorbChance_0_0", PlayerLevel = "PlayerLevel", GodMode = "GodModeOn?",
    Mercenary = "IsMercinerySubClassSetted", Cyborg = "CyborgModeOn?", Weapon = "CurrentWeapon",
    MeleeOn = "MeleeAttackOn?", MeleeWeapon = "As Master Melee Weapon",
}
-- Item data (S_Item_Data) of the player's weapon and suit, read by the optional gear bonus
G.Item = {
    WeaponData    = "Weapon_Data",                                  -- Master_Hand_Weapon_C (S_Equiped_HandWeapon)
    WeaponItem    = "ItemData_2_DAF7632548C524437769A9884E99CE86",  -- S_Equiped_HandWeapon -> S_Item_Data
    CharacterData = "CharacterData",                                -- Q1_Character_C (S_Character_Data_1)
    SuitItem      = "ArmorData_48_7F9011B443DE8EDE80BF42ADE651F30B", -- S_Character_Data_1 -> equipped suit
    Level         = "ItemLevel_32_36C68C8841BC84733BDEE38AC9296BF6", -- 1..99
    Rarity        = "ItemTier_31_620BE1F64621359F21DE589574539BBB",  -- 1 common .. 4
}

-- Blackboard keys used by the shooter behaviour trees
G.BB = { JustGotDamage = "JustGotDamage", FirstInteract = "IsFirstInteract", InCover = "InCover?", InCombat = "InCombat?" }

-- Enums
G.AIType  = { Enemy = 0, Ally = 1, Civil = 2, Natural = 3, Guard = 4 }
G.SubType = { Shooter = 0, Tank = 1, Melee = 2, Mage = 3 }
G.Rotation = { Velocity = 0, Looking = 1, Aiming = 2 } -- ALS rotation mode; NPCs only fire while Aiming
G.Gait     = { Walk = 0, Run = 1, Sprint = 2 }

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
