--[[
  What your wounds feel like (0.4.7). Nothing runs while you are unhurt.

  Bleeding: a dark-red pulse on the screen, like a heartbeat - the harder you bleed, the
  stronger and faster it beats. It uses the engine's own camera fade (PlayerCameraManager:
  StartCameraFade, starting tinted and fading back to clear), so it can never stay stuck.
  Dizzy: bleeding hard or below a quarter of your HP, the view lurches now and then (the game's
  own "Nudge" camera shake).
]]

local U = require("htr.util")

local FB = { nextPulse = 0, nextSway = 0, shakeMissAt = -1e9 }
local RED = { R = 0.35, G = 0.0, B = 0.0, A = 1.0 }
local NUDGE = "/Game/1Data/1Subdata/Nudge_Shake.Nudge_Shake_C"

local function cameraManager(p)
    local ok, m = pcall(function() return U.gameplayStatics():GetPlayerCameraManager(p, 0) end)
    if ok and U.valid(m) then return m end
end

-- p: the player; t: os.clock(); rate: bleeding, % of max HP per second; hpFrac: HP / max HP.
function FB.step(p, t, rate, hpFrac)
    local w = HTR.cfg.Wounds
    if w.ScreenEffects == false then return end
    if rate > 0 and t >= FB.nextPulse then
        local strength = math.min(1, rate / 2.0)          -- 2 % of max HP per second = full
        FB.nextPulse = t + 2.6 - 1.4 * strength           -- every 2.6 s .. 1.2 s
        local alpha = 0.12 + 0.23 * strength
        local m = cameraManager(p)
        -- never over one of the game's own fades when the build exposes that flag (ours lasts
        -- 0.9 s, less than the shortest gap between pulses, so a fade in progress is never ours)
        if m and U.get(m, "bEnableFading", false) ~= true then
            pcall(function() m:StartCameraFade(alpha, 0.0, 0.9, RED, false, false) end)
        end
    end
    if (rate >= 1.5 or (hpFrac > 0 and hpFrac < 0.25)) and t >= FB.nextSway then
        FB.nextSway = t + 3.5 + math.random() * 2.5
        if t - FB.shakeMissAt < 30 then return end         -- class not loaded: look again later
        local cls = StaticFindObject(NUDGE)
        if not U.valid(cls) then FB.shakeMissAt = t; return end
        local ok, pc = pcall(function() return U.gameplayStatics():GetPlayerController(p, 0) end)
        if ok and U.valid(pc) then
            pcall(function() pc:ClientStartCameraShake(cls, 0.6, 0, { Pitch = 0, Yaw = 0, Roll = 0 }) end)
        end
    end
end

return FB
