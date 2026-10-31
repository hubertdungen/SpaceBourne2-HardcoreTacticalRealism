--[[
  Load-crash fix (0.4.6): your bullets end right after they hit something.

  SpaceBourne 2 bug, also without mods (verified in game, 2026-10-31): a bullet from your hand
  weapon often does not end after its hit. The projectile object (XProjectile plugin,
  XProjectileSBC) stays alive, frozen, for over a minute. If you load while many of them are
  around (typically: you die in a long firefight and the death screen loads your last save),
  the old map can stay stuck in memory without its WorldSettings, and loading the same map
  again crashes the game ("Fatal error", EXCEPTION_ACCESS_VIOLATION reading 0x268).

  Fix: after the game has fully handled the hit (damage, effects; this is a post-hook on the
  weapon's OnProjectileHit events), HTR ends that projectile with the plugin's own Destroy().
  A frozen bullet does nothing more, so nothing changes in play. Destroying them later (seconds
  after the hit) does NOT prevent the crash; it has to happen at the hit.
]]

local BL = { ended = 0 }

-- projP: the OutProjectileObject parameter of the hit event.
function BL.endAfterHit(projP)
    local fixes = HTR.cfg.Fixes or {}
    if fixes.EndBulletsAfterHit == false then return end
    local ok, p = pcall(function() return projP:get() end)
    if ok and p and p:IsValid() and pcall(function() p:Destroy() end) then
        BL.ended = BL.ended + 1
    end
end

return BL
