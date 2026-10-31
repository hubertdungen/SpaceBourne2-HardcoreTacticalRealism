--[[
  Hardcore Tactical Realism (HTR) - Combat & AI Overhaul for SpaceBourne 2
  UE4SS Lua mod. Entry point: loads settings, wires hooks, nothing else.

  Layout (see README for details):
    config.lua        user settings
    htr/gamedefs.lua  every game-internal name (the only file to fix after a game patch)
    htr/ballistics.lua calibers, armor classes, hit zones, damage formula (pure data/math)
    htr/doctrines.lua  how pirates, militia, regulars, elites, robots, companions fight
    htr/classify.lua   who is who (side, armor, doctrine, caliber)
    htr/npc.lua        NPC damage intake + tactical AI
    htr/player.lua     Tactical/Hardcore damage to the player
    htr/hooks.lua      safe lazy hook registration
]]

local VERSION = "0.4.6"

local U = require("htr.util")

-- Settings -------------------------------------------------------------------
local defaults = {
    Mode = "Tactical", ToggleModeKey = "F7", HardcoreDamageMultiplier = 2.0, HardcoreAlsoForEnemies = true,
    Features = {}, Damage = {}, Tactical = {}, Realism = {}, FriendlyFire = {}, Debug = {},
}
local okCfg, userCfg = pcall(require, "config")
if not okCfg or type(userCfg) ~= "table" then
    U.warn("config.lua could not be read (" .. tostring(userCfg) .. "); using defaults")
    userCfg = {}
end
local cfg = userCfg
-- 0.1.x configs called the Realism section "Hardcore"
if cfg.Realism == nil and type(cfg.Hardcore) == "table" then cfg.Realism = cfg.Hardcore end
for k, v in pairs(defaults) do if cfg[k] == nil then cfg[k] = v end end
local function default(tbl, key, val) if tbl[key] == nil then tbl[key] = val end end
for _, f in ipairs({ "RealisticDamageToNPCs", "RealisticDamageToPlayer", "FriendlyFireRules", "SmarterAI", "FactionDoctrines",
    "RealisticNPCBallistics", "CompanionFixes", "Suppression" }) do default(cfg.Features, f, true) end
default(cfg.Features, "NPCGrenades", true)
default(cfg.Damage, "GlobalToNPCs", 1.0); default(cfg.Damage, "MinPercentPerHit", 10)
default(cfg.Damage, "BossVitality", 1.8); default(cfg.Damage, "TankVitality", 2.0)
default(cfg.Damage, "RobotVitality", 1.2); default(cfg.Damage, "PirateArmorShift", -1)
default(cfg.Damage, "HelmetMinPass", 0.4); default(cfg.Damage, "ExplosionRadius", 600)
default(cfg.Damage, "SquadOutrightDeath", { ["Tactical"] = 0, ["Tactical Hardcore"] = 0, ["Realism"] = 0.8, ["Realism Hardcore"] = 0.95 })
require("htr.ballistics").HeadMinPass = cfg.Damage.HelmetMinPass
cfg.Wounds = cfg.Wounds or {}
default(cfg.Wounds, "Bleeding", true)
default(cfg.Wounds, "LegSpeed", 0.5); default(cfg.Wounds, "ArmSway", 6); default(cfg.Wounds, "NpcArmSpread", 3.0)
default(cfg.Wounds, "Frequency", { ["Tactical"] = 0.4, ["Tactical Hardcore"] = 0.6, ["Realism"] = 1.0, ["Realism Hardcore"] = 1.0 })
cfg.Regen = cfg.Regen or {}
default(cfg.Regen, "Enabled", true)
default(cfg.Regen, "Tactical", { Delay = 8, HP = 0.7, Armor = 1.5 })
default(cfg.Regen, "Tactical Hardcore", { Delay = 10, HP = 0.5, Armor = 1.0 })
default(cfg.Regen, "Realism", { Delay = 12, HP = 0.25, Armor = 0.5 })
default(cfg.Regen, "Realism Hardcore", { Delay = 15, HP = 0.12, Armor = 0.3 })
cfg.Ships = cfg.Ships or {}
default(cfg.Ships, "Enabled", true); default(cfg.Ships, "ToggleKey", "F9")
default(cfg.Ships, "DirectHitDamage", 300); default(cfg.Ships, "SplashDamage", 150); default(cfg.Ships, "SplashRadius", 500)
default(cfg, "GamepadToggles", true)
cfg.Arrival = cfg.Arrival or {}
default(cfg.Arrival, "GraceSeconds", 4); default(cfg.Arrival, "SpawnGraceSeconds", 3)
default(cfg.Tactical, "MaxIncomingVsVanilla", 1.5); default(cfg.Tactical, "MinIncomingVsVanilla", 1.0)
default(cfg.Tactical, "HeadMultiplier", 1.5)
default(cfg.Realism, "PlayerVitality", 1.0); default(cfg.Realism, "UnattributedMultiplier", 2.0)
default(cfg.Realism, "UnattributedMaxPercent", 60)
default(cfg.FriendlyFire, "PlayerToAlly", { Tactical = 0.35, Realism = 1.0 })
default(cfg.FriendlyFire, "AllyToPlayer", { Tactical = 0.35, Realism = 1.0 })
default(cfg.FriendlyFire, "AllyToAllyCapPercent", 10); default(cfg.FriendlyFire, "EnemyToEnemy", 1.0)
default(cfg.Debug, "Log", false); default(cfg.Debug, "LogHits", false); default(cfg.Debug, "SlowHookMs", 8)
cfg.GearBonus = cfg.GearBonus or {}
default(cfg.GearBonus, "Enabled", false); default(cfg.GearBonus, "ToggleKey", "Shift+F7")
default(cfg.GearBonus, "MaxLevel", 60); default(cfg.GearBonus, "RarityLevels", 5)
default(cfg.GearBonus, "WeaponPen", 8); default(cfg.GearBonus, "WeaponDamage", 0.15)
default(cfg.GearBonus, "ArmorRating", 8); default(cfg.GearBonus, "ArmorWear", 0.25)
default(cfg.GearBonus, "Modes", { ["Tactical"] = true, ["Tactical Hardcore"] = true, ["Realism"] = true, ["Realism Hardcore"] = true })
cfg.Perks = cfg.Perks or {}
default(cfg.Perks, "SlowOnFoot", true); default(cfg.Perks, "ToggleKey", "F11")
default(cfg.Perks, "EnergyRegen", 0.25); default(cfg.Perks, "Cooldown", 0.25)
cfg.Awareness = cfg.Awareness or {}
default(cfg.Awareness, "Enabled", true); default(cfg.Awareness, "RelaxedSight", 0.55); default(cfg.Awareness, "AlertSight", 1.25)
cfg.Squad = cfg.Squad or {}
default(cfg.Squad, "KeepUp", true); default(cfg.Squad, "RunBeyond", 600); default(cfg.Squad, "SprintBeyond", 1500)
cfg.Fixes = cfg.Fixes or {}
default(cfg.Fixes, "EndBulletsAfterHit", true)
cfg.Messages = cfg.Messages or {}
default(cfg.Messages, "Quiet", true)

U.Verbose = cfg.Debug.Log
U.Quiet = cfg.Messages.Quiet ~= false
U.LogHits = cfg.Debug.LogHits

-- Modes ----------------------------------------------------------------------
-- Base rules: Tactical (incoming damage capped vs vanilla) or Realism (you and your
-- allies follow exactly the enemies' rules). "Hardcore" doubles all damage
-- (HardcoreDamageMultiplier). F7 cycles in this order:
local MODES = { "Tactical", "Tactical Hardcore", "Realism", "Realism Hardcore" }

local function normalizeMode(m)
    m = tostring(m or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if m == "hardcore" then return "Realism" end -- 0.1.x name of Realism
    for _, name in ipairs(MODES) do if name:lower() == m then return name end end
    return nil
end

-- Mode persisted between sessions when changed with the hotkey.
local STATE = U.Dir .. "state.txt"
local function loadMode()
    local f = io.open(STATE, "r")
    if f then
        local m = normalizeMode((f:read("a") or ""):match("mode=([^\r\n]+)"))
        f:close()
        if m then return m end
    end
    return normalizeMode(cfg.Mode) or "Tactical"
end

HTR = { version = VERSION, cfg = cfg }

function HTR.setMode(m)
    HTR.mode = normalizeMode(m) or "Tactical"
    HTR.base = HTR.mode:find("^Realism") and "Realism" or "Tactical"
    HTR.hardcore = HTR.mode:find("Hardcore$") ~= nil
end

-- Damage multiplier for a victim on `side` ("player", "ally", "enemy").
function HTR.sideMultiplier(side)
    if not HTR.hardcore then return 1.0 end
    if side == "player" or side == "ally" or cfg.HardcoreAlsoForEnemies then return cfg.HardcoreDamageMultiplier end
    return 1.0
end

-- Wound frequency: enemies always 1.0; you and your allies per mode (Wounds.Frequency).
function HTR.woundFreq(side)
    if side ~= "player" and side ~= "ally" then return 1.0 end
    return (cfg.Wounds.Frequency or {})[HTR.mode] or 1.0
end

-- Friendly-fire factor for the current base mode (accepts 0.1.x "Hardcore" keys).
function HTR.ff(tbl)
    if type(tbl) ~= "table" then return tonumber(tbl) or 1.0 end
    return tbl[HTR.base] or (HTR.base == "Realism" and tbl.Hardcore) or 1.0
end

HTR.setMode(loadMode())

-- Ships vs infantry (F9) and gear bonus (Shift+F7) on/off, remembered in state.txt.
do
    local f = io.open(STATE, "r")
    local s = f and f:read("a") or ""
    if f then f:close() end
    local v = s:match("ships=(%a+)")
    if v then HTR.shipsOn = (v == "on") else HTR.shipsOn = cfg.Ships.Enabled end
    local g = s:match("gear=(%a+)")
    if g then HTR.gearOn = (g == "on") else HTR.gearOn = cfg.GearBonus.Enabled == true end
    local pk = s:match("perks=(%a+)")
    if pk then HTR.perksSlow = (pk == "slow") else HTR.perksSlow = cfg.Perks.SlowOnFoot ~= false end
end

local function saveState()
    local f = io.open(STATE, "w")
    if f then
        f:write("mode=" .. HTR.mode .. "\nships=" .. (HTR.shipsOn and "on" or "off") .. "\ngear=" .. (HTR.gearOn and "on" or "off")
            .. "\nperks=" .. (HTR.perksSlow and "slow" or "vanilla") .. "\n")
        f:close()
    end
end

local H = require("htr.hooks")
H.SLOW = cfg.Debug.SlowHookMs / 1000
local G = require("htr.gamedefs")
local N = require("htr.npc")
local Pl = require("htr.player")
local S = require("htr.ships")
local PK = require("htr.perks")
local BL = require("htr.bullets")

U.log(string.format("=== HTR %s loaded, mode=%s, ships=%s, gear bonus=%s, slow perks=%s ===", VERSION, HTR.mode,
    tostring(HTR.shipsOn), tostring(HTR.gearOn), tostring(HTR.perksSlow)))

-- Hooks ----------------------------------------------------------------------
H.add(G.Fn.NpcCalculateStats, N.onCalculateStats, "NPC stats")
H.add(G.Fn.NpcCalculateDamage, N.onCalculateDamage, "NPC damage")
H.add(G.Fn.NpcReceivePoint, N.onReceivePoint, "NPC hit reaction")
H.add(G.Fn.NpcOnDead, N.onDead, "NPC death")
H.add(G.Fn.NpcThink, N.onThink, "NPC think")
H.add(G.Fn.NpcRifleEyeUpdated, N.onRifleEye, "NPC aim (update)")
H.add(G.Fn.NpcRifleEyeDetected, N.onRifleEye, "NPC aim (detect)")
-- your bullets: suppression, then the load-crash fix (see htr/bullets.lua), which always runs
for i, path in ipairs(G.PlayerProjectileHits) do
    H.add(path, function(self, proj, ...)
        local ok, err = pcall(N.onPlayerProjectileHit, self, proj, ...)
        BL.endAfterHit(proj)
        if not ok then error(err, 0) end
    end, "player bullet " .. i)
end
H.add(G.Fn.PlayerIncome, Pl.onIncome, "player damage")
H.add(G.Fn.PlayerRadial, Pl.onRadial, "player radial")
H.add(G.Fn.PlayerTick, Pl.onTick, "player tick")
H.add(G.Fn.PerkRegen, PK.onRegen, "slow perks")
for i, path in ipairs(G.NpcProjectileHits) do H.add(path, Pl.onShooterProjectileHit, "shooter hit " .. i) end
H.add(G.Fn.NpcRadial, N.onRadial, "NPC blast")
H.add(G.Fn.SoldierHit, N.onSoldierHit, "squad soldier damage")
H.add(G.Fn.SoldierUpdate, N.onSoldierUpdate, "squad soldier bleeding")
H.add(G.Fn.SoldierWalkSpeed, N.onSoldierMove, "squad keeps up")
H.add(G.Fn.SoldierWalkSpeedOrder, N.onSoldierMove, "squad keeps up (orders)")
for i, path in ipairs(G.ShipGunHits) do
    H.add(path, function(...) S.onPlayerShipHit(N, Pl, ...) end, "ship gun " .. i)
end
for i, path in ipairs(G.AIShipImpacts) do
    H.add(path, function(...) S.onAIShipImpact(N, Pl, ...) end, "AI ship round " .. i)
end

-- Behaviour-tree template tweak (applies to every NPC using it). A failed lookup costs
-- ~37 ms, so while the tree is not loaded it is looked for with a growing pause.
local btTuned, btNext, btRetry = false, 0, 1
local function tuneBehaviourTree(now)
    if btTuned or not cfg.Features.SmarterAI or now < btNext then return end
    local node = StaticFindObject(G.PeekCooldownNode)
    if node and node:IsValid() then
        local ok = pcall(function() node.CoolDownTime = 2.5 end) -- vanilla 5 s between peeks from cover
        btTuned = true
        U.log("cover peek cooldown 5 -> 2.5 s: " .. tostring(ok))
    else
        btNext, btRetry = now + btRetry, math.min(btRetry * 2, 30)
    end
end

local lastStatus, pollSlowAt, profileAt, lastArrival = "", -1e9, os.clock() + 30, nil
LoopAsync(1000, function()
    ExecuteInGameThread(function()
        local t0 = os.clock()
        local registered = 0
        local ok, err = pcall(function()
            -- arrived somewhere new (level load, elevator, new floor): look for new classes now
            if HTR.arrivalUntil ~= lastArrival or HTR.wakeHooks then
                lastArrival, HTR.wakeHooks = HTR.arrivalUntil, false
                H.wake()
                btNext, btRetry = 0, 1
            end
            registered = H.poll(t0)
            tuneBehaviourTree(t0)
        end)
        if not ok then U.warn("poll: " .. tostring(err)) end
        local dt = os.clock() - t0
        if registered == 0 and dt > H.SLOW and t0 - pollSlowAt > 30 then
            pollSlowAt = t0
            U.warn(string.format("slow hook poll: %.0f ms", dt * 1000))
        end
        if t0 > profileAt then
            profileAt = t0 + 30
            local prof = H.profile()
            if U.Verbose and prof ~= "" then U.log("profile 30 s: " .. prof) end
        end
        local on, off = H.status()
        local s = string.format("hooks active %d, waiting %d", on, off)
        if s ~= lastStatus then lastStatus = s; U.log(s) end
    end)
    return false
end)

-- Mode hotkey ------------------------------------------------------------------
local MODE_TEXT = {
    ["Tactical"]          = "HTR: TACTICAL - you take 100-150% of vanilla damage",
    ["Tactical Hardcore"] = "HTR: TACTICAL HARDCORE - Tactical, all damage x2",
    ["Realism"]           = "HTR: REALISM - same rules for you and enemies",
    ["Realism Hardcore"]  = "HTR: REALISM HARDCORE - Realism, all damage x2",
}

-- ctx: a live object if the caller has one (gamepad), else nil (keyboard: one slower lookup).
local function cycleMode(ctx) -- runs on the game thread
    local nextMode = MODES[1]
    for i, name in ipairs(MODES) do
        if name == HTR.mode then nextMode = MODES[i % #MODES + 1] end
    end
    HTR.setMode(nextMode)
    saveState()
    U.warn("mode is now " .. HTR.mode)
    pcall(U.notify, MODE_TEXT[HTR.mode] or ("HTR mode: " .. HTR.mode), ctx)
end

local function toggleShips(ctx)
    HTR.shipsOn = not HTR.shipsOn
    saveState()
    U.warn("ships vs infantry " .. (HTR.shipsOn and "ON" or "OFF"))
    pcall(U.notify, HTR.shipsOn and "HTR: ships vs infantry ON - ship guns hit people on foot"
        or "HTR: ships vs infantry OFF (vanilla)", ctx)
end

local function toggleGear(ctx)
    HTR.gearOn = not HTR.gearOn
    saveState()
    U.warn("gear bonus " .. (HTR.gearOn and "ON" or "OFF"))
    pcall(U.notify, HTR.gearOn and "HTR: gear bonus ON - weapon/armor level give a small extra"
        or "HTR: gear bonus OFF - only caliber, armor and hit zone count", ctx)
end

local function togglePerks(ctx)
    HTR.perksSlow = not HTR.perksSlow
    saveState()
    U.warn("slow perks " .. (HTR.perksSlow and "ON" or "OFF"))
    pcall(U.notify, HTR.perksSlow and "HTR: slow perks ON - perk energy and cooldowns recover 4x slower on foot"
        or "HTR: slow perks OFF - vanilla perk energy", ctx)
end

-- Keys: a UE4SS key name ("F7", "DEL"...), optionally with modifiers: "Shift+F7", "Ctrl+F9".
-- The game itself uses F1-F6, F8 (quick load), F10 and F12 (Steam screenshot): a plain bind on
-- one of those would fire the game's action too, so HTR refuses it and falls back to its default
-- (0.4.0-0.4.2 shipped F8 for the gear bonus, which also quick-loaded). Only F7, F9 and F11 are
-- free F-keys, and many laptops have no Insert/Home/End, so the gear bonus is Shift+F7.
-- On foot, Shift alone only runs while moving; Ctrl opens the map and Alt crouches.
local GAME_KEYS = { F1 = 1, F2 = 1, F3 = 1, F4 = 1, F5 = 1, F6 = 1, F8 = 1, F10 = 1, F12 = 1 }
local OLD_GEAR_KEYS = { ["F8"] = true, ["CTRL+INSERT"] = true } -- 0.4.0-0.4.2 and 0.4.3 defaults
local KEY_ALIAS = { INSERT = "INS", DELETE = "DEL", PAGEDOWN = "PAGE_DOWN", PAGEUP = "PAGE_UP", ESC = "ESCAPE" }
local MODS = { CTRL = "CONTROL", CONTROL = "CONTROL", SHIFT = "SHIFT", ALT = "ALT" }
local function parseKey(spec)
    if type(spec) ~= "string" or spec == "" then return nil end
    local mods, key = {}, nil
    for part in spec:upper():gsub("%s", ""):gmatch("[^+]+") do
        if MODS[part] then mods[#mods + 1] = MODS[part] else key = KEY_ALIAS[part] or part end
    end
    if not (key and Key and Key[key]) then return nil end
    if #mods == 0 and GAME_KEYS[key] then return nil, "the game uses " .. key end
    return key, mods
end
local function bindKey(spec, fn, fallback, what)
    local key, mods = parseKey(spec)
    if not key and fallback and spec ~= "" then
        U.warn(string.format("%s key '%s' not usable (%s); using %s", what, tostring(spec), tostring(mods or "unknown key"), fallback))
        key, mods = parseKey(fallback)
    end
    if not key then return nil end
    if #mods > 0 and ModifierKey then
        local list = {}
        for _, m in ipairs(mods) do list[#list + 1] = ModifierKey[m] end
        RegisterKeyBind(Key[key], list, function() ExecuteInGameThread(fn) end)
    else
        -- belt and braces: a plain key stays quiet while a modifier is held
        RegisterKeyBind(Key[key], function()
            ExecuteInGameThread(function() if not U.modifierDown() then fn() end end)
        end)
    end
    return key
end
local gearKey = cfg.GearBonus.ToggleKey
if type(gearKey) == "string" and OLD_GEAR_KEYS[gearKey:upper():gsub("%s", "")] then
    if gearKey:upper() == "F8" then U.warn("gear bonus key F8 is the game's quick load; using Shift+F7") end
    gearKey = "Shift+F7"
end
bindKey(cfg.ToggleModeKey, cycleMode, "F7", "mode")
bindKey(cfg.Ships.ToggleKey, toggleShips, "F9", "ships")
bindKey(gearKey, toggleGear, "Shift+F7", "gear bonus")
bindKey(cfg.Perks.ToggleKey, togglePerks, "F11", "slow perks")

-- Gamepad: 4 quick presses of "switch camera" cycle the mode (crouched: ships toggle).
-- Four presses leave the camera where it was.
if cfg.GamepadToggles then
    local taps, first = 0, 0
    H.add(G.Fn.PadCamera, function(self)
        local now = os.clock()
        if now - first > 1.5 then taps, first = 0, now end
        taps = taps + 1
        if taps >= 4 then
            taps = 0
            local pawn = self:get()
            if U.get(pawn, "Stance", 0) == 1 then toggleShips(pawn) else cycleMode(pawn) end
        end
    end, "gamepad toggles")
end
