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

local VERSION = "0.3.0"

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
require("htr.ballistics").HeadMinPass = cfg.Damage.HelmetMinPass
cfg.Wounds = cfg.Wounds or {}
default(cfg.Wounds, "Bleeding", true)
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
default(cfg.Tactical, "MaxIncomingVsVanilla", 1.5); default(cfg.Tactical, "MinIncomingVsVanilla", 1.0)
default(cfg.Tactical, "HeadMultiplier", 1.5)
default(cfg.Realism, "PlayerVitality", 1.0); default(cfg.Realism, "UnattributedMultiplier", 2.0)
default(cfg.Realism, "UnattributedMaxPercent", 60)
default(cfg.FriendlyFire, "PlayerToAlly", { Tactical = 0.35, Realism = 1.0 })
default(cfg.FriendlyFire, "AllyToPlayer", { Tactical = 0.35, Realism = 1.0 })
default(cfg.FriendlyFire, "AllyToAllyCapPercent", 10); default(cfg.FriendlyFire, "EnemyToEnemy", 1.0)
default(cfg.Debug, "Log", false); default(cfg.Debug, "LogHits", false)

U.Verbose = cfg.Debug.Log
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

-- Ships vs infantry on/off (F9), remembered in state.txt.
do
    local f = io.open(STATE, "r")
    local s = f and f:read("a") or ""
    if f then f:close() end
    local v = s:match("ships=(%a+)")
    if v then HTR.shipsOn = (v == "on") else HTR.shipsOn = cfg.Ships.Enabled end
end

local function saveState()
    local f = io.open(STATE, "w")
    if f then f:write("mode=" .. HTR.mode .. "\nships=" .. (HTR.shipsOn and "on" or "off") .. "\n"); f:close() end
end

local H = require("htr.hooks")
local G = require("htr.gamedefs")
local N = require("htr.npc")
local Pl = require("htr.player")
local S = require("htr.ships")

U.log(string.format("=== HTR %s loaded, mode=%s ===", VERSION, HTR.mode))

-- Hooks ----------------------------------------------------------------------
H.add(G.Fn.NpcCalculateStats, N.onCalculateStats, "NPC stats")
H.add(G.Fn.NpcCalculateDamage, N.onCalculateDamage, "NPC damage")
H.add(G.Fn.NpcReceivePoint, N.onReceivePoint, "NPC hit reaction")
H.add(G.Fn.NpcOnDead, N.onDead, "NPC death")
H.add(G.Fn.NpcThink, N.onThink, "NPC think")
H.add(G.Fn.NpcRifleEyeUpdated, N.onRifleEye, "NPC aim (update)")
H.add(G.Fn.NpcRifleEyeDetected, N.onRifleEye, "NPC aim (detect)")
for i, path in ipairs(G.PlayerProjectileHits) do H.add(path, N.onPlayerProjectileHit, "suppression " .. i) end
H.add(G.Fn.PlayerIncome, Pl.onIncome, "player damage")
H.add(G.Fn.PlayerRadial, Pl.onRadial, "player radial")
H.add(G.Fn.PlayerTick, Pl.onTick, "player tick")
for i, path in ipairs(G.NpcProjectileHits) do H.add(path, Pl.onShooterProjectileHit, "shooter hit " .. i) end
H.add(G.Fn.NpcRadial, N.onRadial, "NPC blast")
H.add(G.Fn.SoldierHit, N.onSoldierHit, "squad soldier damage")
for i, path in ipairs(G.ShipGunHits) do
    H.add(path, function(...) S.onPlayerShipHit(N, Pl, ...) end, "ship gun " .. i)
end
for i, path in ipairs(G.AIShipImpacts) do
    H.add(path, function(...) S.onAIShipImpact(N, Pl, ...) end, "AI ship round " .. i)
end

-- Behaviour-tree template tweak (applies to every NPC using it).
local btTuned = false
local function tuneBehaviourTree()
    if btTuned or not cfg.Features.SmarterAI then return end
    local node = StaticFindObject(G.PeekCooldownNode)
    if node and node:IsValid() then
        local ok = pcall(function() node.CoolDownTime = 2.5 end) -- vanilla 5 s between peeks from cover
        btTuned = true
        U.log("cover peek cooldown 5 -> 2.5 s: " .. tostring(ok))
    end
end

local lastStatus = ""
LoopAsync(1000, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            H.poll()
            tuneBehaviourTree()
        end)
        if not ok then U.warn("poll: " .. tostring(err)) end
        local on, off = H.status()
        local s = string.format("hooks active %d, waiting %d", on, off)
        if s ~= lastStatus then lastStatus = s; U.log(s) end
    end)
    return false
end)

-- Mode hotkey ------------------------------------------------------------------
local MODE_TEXT = {
    ["Tactical"]          = "HTR mode: TACTICAL - damage you take is 100-150% of vanilla",
    ["Tactical Hardcore"] = "HTR mode: TACTICAL HARDCORE - Tactical, and all damage is doubled",
    ["Realism"]           = "HTR mode: REALISM - you and your allies follow the same rules as enemies",
    ["Realism Hardcore"]  = "HTR mode: REALISM HARDCORE - Realism, and all damage is doubled",
}

local function cycleMode() -- runs on the game thread
    local nextMode = MODES[1]
    for i, name in ipairs(MODES) do
        if name == HTR.mode then nextMode = MODES[i % #MODES + 1] end
    end
    HTR.setMode(nextMode)
    saveState()
    U.warn("mode is now " .. HTR.mode)
    pcall(U.notify, MODE_TEXT[HTR.mode] or ("HTR mode: " .. HTR.mode))
end

local function toggleShips()
    HTR.shipsOn = not HTR.shipsOn
    saveState()
    U.warn("ships vs infantry " .. (HTR.shipsOn and "ON" or "OFF"))
    pcall(U.notify, HTR.shipsOn and "HTR: SHIPS VS INFANTRY ON - ship guns now hit people on foot"
        or "HTR: SHIPS VS INFANTRY OFF - ship guns ignore people on foot (vanilla)")
end

local function bindKey(name, fn)
    if name and name ~= "" and Key and Key[name] then
        RegisterKeyBind(Key[name], function() ExecuteInGameThread(fn) end)
    end
end
bindKey(cfg.ToggleModeKey, cycleMode)
bindKey(cfg.Ships.ToggleKey, toggleShips)

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
            local crouched = U.get(self:get(), "Stance", 0) == 1
            if crouched then toggleShips() else cycleMode() end
        end
    end, "gamepad toggles")
end
