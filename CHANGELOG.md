# Changelog

## 0.3.0 — 2026-10-30

- Tactical now keeps the damage you and your allies take between 100 % and 150 % of vanilla
  (never less than vanilla).
- Wounds: penetrating hits can cause bleeding; heavy limb hits break bones (NPCs with a broken
  arm aim badly; your healing is halved). Enemies in every mode; your side rarely in Tactical,
  more in Tactical Hardcore, fully in Realism.
- Healing: the suit's own HP healing is slowed per mode (70/50/25/12 %), starts 8–15 s after
  your last hit and pauses while bleeding; armor nanites slowly repair the suit.
- Explosions and grenades now do realistic, distance-based damage to NPCs (vanilla NPCs ignored
  every explosion that wasn't yours).
- NPC grenades on by default: regular and elite troops flush you out of cover.
- Squad soldiers take realistic damage (injured first, as in vanilla).
- Ships vs infantry (F9): your ship's and AI ships' guns hit people on foot.
- Experimental gamepad toggles: 4 quick presses of "switch camera" (crouched: ships).
- Clearer install guide.

## 0.2.0 — 2026-10-30

- Four modes, cycled with F7 and announced on the HUD: Tactical, Tactical Hardcore, Realism,
  Realism Hardcore. "Realism" is the former "Hardcore" mode; the new "Hardcore" variants double
  all damage (you, allies and enemies) on top of their base rules. Old configs/state still load.
- New options: `HardcoreDamageMultiplier` (2.0) and `HardcoreAlsoForEnemies` (true).
- Headshots are always dangerous: no helmet stops more than 60% of a headshot (`HelmetMinPass` 0.4), so any firearm kills in 1-2 headshots, in every mode.
- Ground turrets now fight for their team (allied turrets count as allies, enemy turrets as
  enemies) with their own caliber; turret and battle-drone hits on the player are attributed.
- Planned: ships hitting NPCs and the player on foot (toggleable).

## 0.1.0 — 2026-10-30

First public release.

- Realistic on-foot damage: caliber vs armor + hit zones (head, torso, arms, legs); NPC level,
  weapon level and rarity removed from the damage maths; armor that wears down; vanilla
  armor-overflow bug fixed.
- Tactical mode (incoming damage capped at +50 % of vanilla) and Hardcore mode (same rules
  for you and your allies as for enemies); F7 switches modes.
- Friendly-fire rules for player ↔ allies, allies ↔ allies/turrets and enemies ↔ enemies.
- NPC ballistics: fast projectiles, human aim spread, centre-mass aiming, settle time.
- Tactical AI: fixed hit reactions, retreat when badly hurt, area alerts, morale breaks,
  faster cover peeks, suppression from near misses.
- Doctrines: pirate, militia, regular, elite, machine, companion.
- Companion fix (projectiles no longer vanish instantly).
- Installer that reuses or installs UE4SS 3.0.1 and keeps your settings on update.
