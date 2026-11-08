# Changelog

## 0.4.15 — 2026-11-07

- **Blood loss knocks out instead of killing.** Whoever bleeds to zero passes out for 45 s and can
  be revived: you, squad soldiers, companions and enemies (robots never bleed; bosses still die).
  Before, enemies and companions died at once and you were knocked out only by the per-mode chance.
- **Pirates finish off the downed.** A pirate within 15 m stops, turns to anyone of your side who
  is down (you, squad soldiers, companions) and fires from where it stands. The other factions' rounds no longer kill
  someone who is down; your own shots and explosions still do (you included, while you are down).
- **You revive companions:** crouch next to a downed companion for 8 s.
- **Revives stop the bleeding** and bring anyone back at 25 % health (NPCs had 20 %); broken
  bones stay broken.
- While you are down, HTR no longer resolves hits on you itself: any death while down goes through
  the safe path that ends the ragdoll first (the 0x268 load crash of 0.4.11).
- **Fixed: a squad soldier picked to revive a downed companion never came** (only revives of you
  made soldiers move) and kept everyone else from helping until the companion died.
- **No stalled revivers.** A reviver walks with its AI paused; one that has not reached the body
  after 15 s on clear ground gives up and fights again (another may try). A pirate finishing
  someone off gives up after 8 s.
- Tested in game (scripted, 7 launches, HTR alone): enemies and you are knocked out by blood loss;
  a squad soldier revived you at 25 % (381/1526); the downed die when the time runs out; your death
  while down and the game's reload after it were clean in all 7 launches (no crash dumps); regular
  enemy fire did not kill you while down. Not yet seen in game: a pirate finishing someone off and
  a completed crouched revive (the test enemies kept hitting the player, which restarts it).
- New `Knockout` settings: `BleedOut`, `PiratesFinishOff`, `PlayerRevive`, `PlayerReviveSeconds`,
  `RevivedHP`.
- **Allies no longer outclass everyone.** Companions fought at near-elite level whatever their
  tier; now each fights by its own tier (0-4), from a faction regular (tier 0) to an elite
  (tier 4, the rare best). Squad
  soldiers had at least medium armor, always a helmet and 20 % tougher bodies; now they wear the
  kit of an enemy of the same tier and have normal bodies. Pirates stay the sloppiest.

## 0.4.14 — 2026-11-06

- **Fixed: a UE4SS crash with many mods** ("Fatal error" in UE4SS.dll+0x87c104, at the main menu
  or in play; 7 crash dumps since 30/10). Mods' background loops (LoopAsync, ExecuteWithDelay)
  run on their own threads without UE4SS's lock; each ExecuteInGameThread from there adds an
  entry to a map that all mods share, and two at the same moment broke it. HTR no longer uses
  them: its once-a-second work and the alarm unmute run on the game thread, from the player's
  tick and the HUD's drawing (new `htr\gametick.lua`, the same file in every mod of the set). The
  crash needs every mod of the set changed; the others follow.
- Tested in game (HTR alone, 5 launches): on foot the work runs from the player tick, in space
  from the HUD (no character ticks there), and it carries on after a second load. Timed work
  costs about 1-2 ms every 5 s; with 20 enemies around the ticks used still fire once a frame. Nothing runs at the main menu (HTR needs nothing there).

## 0.4.13 — 2026-11-06

- **Fixed: NPCs left standing with their AI switched off ("scarecrows").** A knocked-out NPC has
  its AI paused while it lies there. If you moved on (elevator, new floor, a long jump), HTR
  forgot it without switching its AI back on, so it never got up or moved again. Now it stays
  down and bleeds out on its own after the usual 45 s. The knocked-out NPCs and revivers are also
  kept when HTR trims its NPC memory (after 600 NPCs).
- Tested in game: an NPC killed in front of two unaware mates put the one in reach into combat,
  with you as its target, within 2 s (0.4.12's "mates react", now tested on its own). The
  scarecrow fix itself was not seen in game (the test saves have no allied soldiers nearby).

## 0.4.12 — 2026-11-06

- **Hit means fight.** An NPC hit before it noticed anyone now goes straight into combat against
  whoever shot it: that shooter as its target, its position as where to go. Vanilla only walked
  off to another spot and stayed out of combat. Tested in game: in combat, with you as the
  target, 1 s after the hit.
- **Mates react to hits and deaths.** When an NPC is hit or dies, its mates within its doctrine's
  alert radius go into combat toward where the shots came from, with the same alert as above.
  Allied NPCs now do this too (never against you for friendly fire). Not tested separately in game.
- **Allies take real damage from enemy fire.** When the game passes a weapon or projectile as the
  damage causer, HTR now finds the shooter behind it. Before, such hits on allies could count as
  friendly fire (capped at 10 % of their HP per hit), which made allies very hard to kill.
- **Perk energy recovers in minutes.** A full refill on foot now takes ~80 s in Tactical, ~2 min
  in Tactical Hardcore, ~3.5 min in Realism and ~4.5 min in Realism Hardcore (vanilla ~16 s;
  0.4.11: ~64 s in every mode). `Perks.EnergyRegen` takes one number or one per mode; configs
  that still carry the old 0.25 move to the new values. Tested in game: Realism Hardcore
  0.42 -> 0.10 energy per 0.25 s.
- Not done yet: allies that stand still without patrolling (needs a place with allies to watch).

## 0.4.11 — 2026-11-05

- **Fixed: "Fatal error" (EXCEPTION_ACCESS_VIOLATION reading 0x268) when the game loads after you
  die.** It came back with the knockouts: in tests with HTR 0.4.10 alone it crashed twice, both
  times on the load after a knockout ended in a bleed-out (once with enemies close by).
  - When you bleed out, HTR first ends your ragdoll and your knocked-out state; you die a moment
    later, like a normal death.
  - Bullets of NPCs, squad soldiers, turrets and drones now also end right after their hit (0.4.6
    did this for your bullets). Frozen bullets can keep the old map in memory, which is what the
    load then trips over.
- Tested in game: 4 knockouts in a row, each with enemies spawned close by, a 45 s bleed-out and
  the load: no crash, no bullets left over (before the fix it crashed on the 2nd).

## 0.4.10 — 2026-11-01

- **Knockouts are safe across floors, dungeons and loads.** When you arrive somewhere new (elevator,
  new floor, dungeon, level load) HTR forgets every knocked-out NPC of the old area without touching
  it again; their objects may already be gone, and calling into a freed object can close the game
  without a dialog. Your own knockout stays when you only change floors.
- Knocked-out NPCs are only updated while you are in the world on foot (not during loads or menus).
- Tested in game: reloading the area with two knocked-out NPCs down kept the game running and
  responsive; you were back on foot after the load.

## 0.4.9 — 2026-10-31

- **Not always dead.** A lethal hit sometimes knocks the victim out instead: you, your allies and
  enemies. Chance per mode: Tactical 18 %, Tactical Hardcore 12 %, Realism 10 %, Realism Hardcore 5 %.
  Never on a headshot, a big explosion or heavy overkill. Robots and bosses are never knocked out.
- **Someone comes for the downed.** A squad medic comes fastest; otherwise a squad soldier or a
  companion comes, more slowly. Among enemies, elites revive quickly and reliably, regulars more
  slowly, and militia and pirates rarely, often giving up under fire.
  - Nobody goes in under fire: the area round the body must be clear (15 m).
  - The reviver has to reach the body and stay there for 6–15 s. A revive can fail.
  - Nobody comes within 45 s: the downed one bleeds out. Your squad's own injured state now lasts
    as long, and its medics and your "hold to revive" work as before.
  - You see "Knocked out - a medic is coming" / "help is coming" / "Back on your feet".
  - Settings: `Knockout` in config (on by default; chance per mode, bleed-out time, overkill limit).
- Tested in game: an enemy knocked out at 1 HP was revived by a comrade 4 m away after 12 s; you
  knocked out next to your squad were revived by a soldier who came over (12 s); frame times as in
  0.4.8 (firefight median 10 ms, 99 % under 24 ms).

## 0.4.8 — 2026-10-31

- **Slow perks key is now Shift+F3 (on foot).** F11 is the game's fullscreen toggle. Configs that
  still say F11 switch over by themselves (logged in `htr.log`), and HTR now refuses F11 with or
  without a modifier. In a ship Shift+F3 does nothing for HTR (F3 is the fleet's order 3 there).
- **Turrets:** your turret perk (also used by Tactical Engineering) now counts as yours and fires
  rifle-class rounds (`turret_light`, 55 / 50) instead of unknown "generic" rounds; the
  mini-bosses' mini-turrets are hostile with the same light caliber. Team-battle turrets stay heavy.
- Fixed: a setting HTR reads from a game object that does not have it (e.g. the turret perk's team)
  now falls back to HTR's default; before, the turret perk's rounds counted as enemy fire.
- Tested in game: the keys bind as F7 / Shift+F7 / F9 / Shift+F3; a spawned turret-perk turret's
  hits on enemies count as yours with the light caliber; the alarm volume is restored after messages.
  Frame times (about 90 fps machine state): firefight with sustained fire, without HTR median 9 ms,
  99 % under 20 ms; HTR 0.4.5 10 / 24 ms; HTR 0.4.8 10 / 27 ms (a few 25–48 ms frames while bodies
  drop, as in 0.4.5). Five enemies shooting at you: 0.4.8 median 9 ms, 99 % under 20 ms, worst 39 ms.
- Quiet messages work together with Silent Ops 0.2, which mutes the same alarm: the real volume is
  shared between the two mods, so the alarm can't end up silent for good.
- Links to the whole realism set: Split Controls, Silent Ops, Gear Without Levels, Faction Power,
  Tactical Engineering and SB2 HOTAS (now on Nexus).

## 0.4.7 — 2026-10-31

- **You feel your wounds.** While you bleed, the screen pulses dark red like a heartbeat — stronger
  and faster the more you bleed. Bleeding hard or below a quarter of your HP, the view lurches now
  and then. Nothing shows while you are unhurt (`Wounds.ScreenEffects`).
- **Broken leg: no sprinting.** On top of the limp, you cannot sprint; below 30 % HP you can only
  walk (`Wounds.LegWalkOnlyBelowHP`).
- **Crippled enemies lose their nerve.** An enemy whose leg breaks either tries to get away
  (pirates 60 %, militia 45 %, regulars 25 %) or breaks off and fights from cover. Elites, robots and
  companions don't flinch (`crippleFlee` in `htr\doctrines.lua`).
- **Bosses wear better armor:** +10 protection and half the wear (`Damage.BossArmorBonus`,
  `Damage.BossArmorWear`). A rifle now needs about 12 body hits (was 8) and 3 to the head, a DMR 6,
  a sniper 3.
- Tested in game: in a firefight aimed at you, the heartbeat pulse and the lurches showed while
  you bled (game screenshot), "You are bleeding" appeared without the alarm, and with a broken leg
  under 30 % HP the game's own gait stayed at walking. Frame times: firefight with sustained fire
  median 17 ms, 99 % under 33 ms; five enemies shooting at you (bleeding, pulses, broken leg) median
  19 ms, 99 % under 32 ms, worst 49 ms.

## 0.4.6 — 2026-10-31

- **"Fatal error" when loading after you die.** Found a SpaceBourne 2 bug behind it (it also
  happens with no mods at all): bullets from your hand weapon often do not end after they hit
  something; the projectile stays alive, frozen, for over a minute. Loading while such bullets are
  around can leave the old map stuck in memory without its WorldSettings, and loading that same
  map again — which is what the death screen does with your last save — crashes the game
  (`EXCEPTION_ACCESS_VIOLATION reading 0x268`). HTR now ends each of your bullets right after the
  game has handled its hit. A frozen bullet did nothing anyway, so nothing changes in play
  (`Fixes.EndBulletsAfterHit` in config).
  - Tested in game: a firing burst that crashed the next load 7 times out of 7 (with and without
    mods) no longer crashes; after a real firefight no bullet is left behind.
  - Honest note: I could trigger the crash with a scripted burst, not yet with normal play, so
    there may be other causes. If it happens again, please send `UE4SS.log` and the newest folder
    in `%LOCALAPPDATA%\SB2\Saved\Crashes`.
- **HUD messages without the alarm.** HTR's messages (F7 / Shift+F7 / F9 / F11, bleeding, broken
  bones) no longer play the game's red-alert "tu-tu-tu"; the game's own warnings keep their sound
  (`Messages.Quiet`).
- Fixed: after a level load, the check that keeps F7 / F9 / F11 quiet while Shift, Ctrl or Alt is
  held used the destroyed old controller, which could crash the game on a key press.
- Tested in game with real key presses: F7 shows its message with the alarm muted (volume back
  2 s later), Shift+F7 toggles the gear bonus without changing the mode. Frame times in a firefight
  (5 enemies, your squad, sustained fire), all realism-set mods on: with HTR 0.4.6 median 18.0 ms,
  99 % under 33 ms, worst 68 ms; without HTR 18.0 / 33 / 67 ms.
- Thanks to TheCalcMan for his reports (HUD messages, a crash when shooting a raid boss, the ammo
  idea). The boss crash is still under investigation.

## 0.4.5 — 2026-10-30

- **Broken bones matter now.** A broken leg makes you limp at half speed at every gait; NPCs and
  squad soldiers with a broken leg can only walk. A broken arm makes your aim drift and tremble
  while a gun is drawn, and gives NPCs 3x their aim spread (was 1.8x). Robots get the same
  (a wrecked leg or arm), still without bleeding. Bones fuse in about a minute (`Wounds` in config:
  `LegSpeed`, `ArmSway`, `NpcArmSpread`).
- Verified in game: your speed 375 → 187 cm/s with a broken leg, an NPC's 375 → 165 cm/s, about 8°
  of aim drift with a broken arm. Nothing runs while no bone is broken.

## 0.4.4 — 2026-10-30

- **Gear bonus key is now Shift+F7**, because many laptops have no Insert key (Ctrl+Insert in
  0.4.3). Configs that still say F8 or Ctrl+Insert switch over automatically. Shift was chosen
  because, on foot, Shift alone only runs while moving; Ctrl opens the map and Alt crouches.
- HTR's plain keys (F7, F9, F11) stay quiet while Shift, Ctrl or Alt is held, so Shift+F7 does
  not also cycle the mode.
- Verified in game with real key presses: F7 cycles the mode, Shift+F7 toggles the gear bonus
  (mode unchanged), F11 toggles slow perks; an old `F8` config moves to Shift+F7 by itself.

## 0.4.3 — 2026-10-30 (please update)

- **Fixed: F8 also quick-loaded your game.** F8 is SpaceBourne 2's quick load, so toggling the gear
  bonus with F8 (0.4.0–0.4.2) also loaded your last quick save. The gear bonus is now on
  **Ctrl+Insert**. Configs that still say F8 are switched over automatically (logged in
  `htr.log`), and HTR now refuses any plain key the game itself uses (F1–F6, F8, F10, F12).
- Keys in `config.lua` accept modifiers, e.g. `"Ctrl+Insert"`, `"Shift+Home"`.

## 0.4.2 — 2026-10-30

- **Enemies (pirates most of all) spent fights running instead of shooting back.** Every hit
  could send an NPC sprinting for cover again (50–100 % chance by doctrine, plus near misses),
  with no pause between reactions, so under sustained fire it was always on the move. Now an
  NPC that broke for cover fights from there for a while (5–8 s by doctrine) before it can be
  sent running again.
- NPCs also resume firing as soon as they aim at you again: vanilla only starts an NPC's fire
  at the moment it first spots you while aiming. Same for companions.
- Pirates break less easily: retreat below 30 % HP (was 45 %), panic chance 25 % (was 35 %).
- **Robots never bleed**, but heavy hits can still wreck an arm (shaky aim) or a leg.
- **Squad soldiers bleed** like everyone else; once down, the game's bleed-out timer and medics
  take over as before.
- **Squad keeps up:** vanilla squad soldiers walk after you and teleport next to you once 30 m
  behind ("spawning out of nowhere"). They now run beyond 6 m and sprint beyond 15 m, so only a
  stuck soldier still teleports (`Squad` in config).
- **Slow perks (new, on by default, F11):** on foot, perk energy refills 4x slower and the
  turret / barricade / ground-slam / auto-revive cooldowns run 4x slower (`Perks` in config).
- **Situational awareness (new):** relaxed enemies notice you only up close (55 % of their
  sight range); alert ones spot and shoot farther (125 %) (`Awareness` in config).
- Tested in game: enemies kept firing back after diving for cover and under 20 s of sustained
  fire; perk energy regen 4x slower on foot; detection 45 m → 56 m once alert. Frame times with
  HTR 0.4.2: on foot 105 fps, 99 % of frames under 20 ms, worst 29 ms; in space 120 fps, worst
  38 ms; no periodic stutter. (A stutter every 1 s found during testing comes from SB2 HOTAS
  0.3.0's triple-monitor HUD option, not HTR; reported to that mod.)

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
