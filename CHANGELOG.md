# Changelog

## 0.4.1 — 2026-10-30

- **Fixed: no on-screen message when pressing F7 / F8 / F9** (and for bleeding / broken bones).
  The game's "system message" HTR used shows nothing on foot; HTR now uses the HUD warning the
  game itself shows on foot (right side, warning icon), or the red warning line elsewhere.
  Verified with screenshots in game. Thanks to TheCalcMan for the report.

## 0.4.0 — 2026-10-30

- **Optional gear bonus (F8, off by default).** For a light RPG feel: weapon and armor level and
  item rarity add a small extra on top of the ballistics — up to +8 penetration and +15 % damage
  for weapons, up to +8 protection and 25 % less wear for armor, with diminishing returns
  (level 10 ≈ half, level 60 = full). Your weapon item, NPC and turret levels, your level for your
  suit and squad. Same rules for both sides; can be switched off per mode (`GearBonus` in config).
- **Ground turrets** now hit like heavy emplaced guns (one round every 1.5 s; one hit kills an
  unarmored target, two through armor). Before, each turret round did less than a rifle bullet.
- Measured in game with the gear bonus on: same frame times as without mods.

## 0.3.2 — 2026-10-30 (performance fix — please update)

- **Fixed the freezes when shooting.** Every hit of yours (suppression), every hit on an enemy
  (alerting nearby enemies) and every death searched the whole game for NPCs, which took about
  0.6 s each time. HTR now keeps a light registry of where NPCs are, filled by their own hooks, and
  hands alerts, suppression, panic and ship-blast splash to each NPC on its next update (< 1 s).
  Measured in game while firing: worst frame 1.5 s → under 0.1 s, same as without the mod.
- **Fixed a small stutter every second** since 0.3.0: two railgun hooks pointed at functions that
  do not exist, and each failed lookup cost ~37 ms every second. Hooks are now looked up per class
  with a growing pause for classes that are not loaded yet.
- Player lookups use an instant engine call instead of a full search (affected alerts, wound
  messages and ship blasts).
- New performance watchdog: any HTR code slower than `Debug.SlowHookMs` (8 ms) is reported in
  `htr.log`, so stutter reports come with the culprit.

## 0.3.1 — 2026-10-30

- Squad soldiers in the Realism modes no longer always go down injured first: headshots and heavy
  overkill kill outright, other lethal hits by chance (80 % Realism, 95 % Realism Hardcore;
  `Damage.SquadOutrightDeath`). Tactical modes keep the vanilla injured-first rule.
- Squad soldiers wear at least medium armor and a helmet and have a 20 % tougher body, so they
  can hold a firefight (in the Tactical modes they stay as sturdy as vanilla).
- Arrival grace for dungeons: after an elevator ride, a new floor or a level load, and for freshly
  spawned NPCs, everyone aims very badly for a few seconds (Arrival in config.lua), so floors no
  longer start with an instant massacre on either side.

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
