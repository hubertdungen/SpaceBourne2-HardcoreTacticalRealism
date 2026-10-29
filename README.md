<p align="center"><img src="docs/banner.png" alt="Hardcore Tactical Realism - Combat & AI Overhaul" width="100%"></p>

# Hardcore Tactical Realism (HTR) — Combat & AI Overhaul for SpaceBourne 2

On-foot combat in SpaceBourne 2 is an MMO bullet-sponge: a level 30 raider soaks up
15 000 HP plus 15 000 armor, your damage depends on weapon level, and headshots barely
matter. **HTR replaces that with ballistics**: what kills is the round, where it hits and
what armor it hits. Enemies go down fast — and so can you. Fight from cover.

Inspired by Cyberpunk 2077 *Hardcore Realism*, Fallout: New Vegas *Realistic Combat
Overhaul* and *NPC AI Improvement*. No code from those mods is used.

## What changes

**Damage model (all on-foot fights)**
- Damage = **caliber vs armor + hit zone**. NPC level, weapon level and rarity no longer matter.
- Unarmored targets drop in **1–2 rifle hits**; heavy armor takes **5–6**, power armor/robots
  **6–8**. Any firearm headshot on a bare head kills. Snipers kill almost anything in one hit.
- Melee is lethal: knives, swords and hammers kill most targets with one or two blows.
- Armor **wears down** as it stops rounds (the armor bar shows its condition): worn armor
  protects less. Vanilla's armor-overflow bug is gone.
- Limb hits cripple: destroyed arms and legs use the game's own dismemberment, and lethal
  hits blow off the limb or head that was hit (needs *Gore* on in Gameplay settings).

| Hits to kill (centre mass / head) | none | light | medium | heavy | power |
|---|---|---|---|---|---|
| Pistol | 2 / 1 | 4 / 1 | 6 / 2 | 7 / 2 | 8 / 3 |
| SMG | 2 / 1 | 4 / 1 | 6 / 2 | 8 / 2 | 8 / 3 |
| Rifle | 2 / 1 | 3 / 1 | 4 / 1 | 5 / 2 | 6 / 2 |
| Hunter (DMR) | 2 / 1 | 2 / 1 | 2 / 1 | 3 / 1 | 3 / 1 |
| Sniper | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 | 2 / 1 |
| Knife / Sword / Hammer | 1 | 1 | 2 / 1 / 1 | 2 / 2 / 1 | 3 / 2 / 2 |

Shotgun pellets are counted individually: one close blast kills an unarmored target.
Bosses have a tougher body (about 8–9 rifle hits, 3 to the head).

**Two modes** — switch with **F7** in game (remembered between sessions)
- **Tactical** (default): enemies die fast; damage *you* take is capped at **+50 %** of vanilla.
  Your allies are just as sturdy.
- **Hardcore**: you and your allies take damage under **exactly the same rules** as enemies.
  Your suit's armor rating and condition protect you; a few rifle hits kill.

**Friendly fire**
- You ↔ allies (companions, squad, crew): reduced in Tactical (35 %), fully real in Hardcore.
- Allies ↔ allies and allied turrets: vanilla damage, capped at 10 % of HP per hit.
- Enemies ↔ enemies: fully realistic. Allies ↔ enemies: fully realistic, so your squad
  and companions now actually kill things.

**Smarter, deadlier AI**
- NPC bullets fly at 360–500 m/s instead of 100 m/s, so they hit what they aim at...
- ...but they aim like people: spread that depends on training, a settle-in time after
  spotting you, worse aim while moving or being shot at, and mostly centre-mass aim
  instead of vanilla's random feet/above-the-head points.
- Fixed vanilla behaviour that never triggered: NPCs break line of sight when hit,
  fall back when badly hurt, call nearby allies when hit or killed, peek from cover
  more often (2.5 s instead of 5 s).
- **Suppression**: your rounds landing next to an enemy make it duck and shoot worse.
- Companions' bullets work (vanilla gave them a 0-second projectile life) and they see further.

**Doctrines — not every enemy fights the same**
| Doctrine | Who | How they fight |
|---|---|---|
| Pirate | raiders, salvagers | slow to react, spray long bursts, wide spread, panic when mates die, flee early |
| Militia | low-tier troops | better than pirates, still sloppy |
| Regular | standard faction troops | quick, accurate, use cover, coordinate |
| Elite | high-tier faction troops, guards, bosses | fastest reactions, tight aim, short controlled fire, alert the whole area |
| Machine | robots | fearless, steady aim, never retreat |
| Companion | your allies | elite-level aim, cover, no panic |

All numbers live in plain data files (see *Tuning*), so you can make pirates dumber or
elites deadlier.

## Install

1. Download `HardcoreTacticalRealism-x.y.z.zip` from [Releases](../../releases/latest) and extract it.
2. Double-click **`Install.cmd`**. It finds the Steam copy by itself.
   GOG / other folder: drag your `SpaceBourne 2` folder onto `Install.cmd`.
3. Start the game. Damage and AI change as soon as you land.

The installer reuses UE4SS if you already have it (for example from **SB2 HOTAS** — both
mods work together), otherwise it installs the bundled UE4SS 3.0.1. The game executable
is never modified. Updating: run the new `Install.cmd`; your `config.lua` is kept.

**Manual install:** copy `ue4ss\dwmapi.dll`, `ue4ss\UE4SS.dll` and `ue4ss\UE4SS-settings.ini`
into `SpaceBourne 2\SB2\Binaries\Win64\` (skip if UE4SS is already there), copy
`mod\HardcoreTacticalRealism` into `...\Win64\Mods\`, and add the line
`HardcoreTacticalRealism : 1` to `...\Win64\Mods\mods.txt`.

**Uninstall:** double-click `Uninstall.cmd`. Saves are not changed by the mod, so you can
remove it at any time.

## Tuning

Open `SB2\Binaries\Win64\Mods\HardcoreTacticalRealism\scripts\config.lua` in Notepad:
mode, every feature on/off, friendly-fire factors, boss toughness, Tactical cap, logging.
For deeper changes:
- `htr\ballistics.lua` — caliber damage/penetration, armor ratings, hit-zone multipliers.
- `htr\doctrines.lua` — reaction time, sight range, bullet speed, fire rate, spread, morale.

## Known limitations (v0.1)

- Ship combat is untouched (on-foot only).
- Beam weapons, grenades and explosions hitting NPCs use vanilla damage.
- NPC grenades are off by default (`NPCGrenades`, experimental).
- The game has no faction field on soldiers, so doctrines use the game's raider flag,
  troop tier, guard/robot/boss flags and companion status.
- The squad soldiers you command take vanilla damage (their attacks are realistic).
- Tested on the Steam build of 26 Oct 2026. Feedback and logs (`htr.log`) are welcome.

## After a game update

All game-internal names are in one file, `htr\gamedefs.lua`. If an update renames
something, HTR switches the affected feature off (logged in `htr.log` and `UE4SS.log`)
instead of crashing, and only that file needs fixing. `tools\` holds the scripts used to
inspect the game's Blueprints.

## Credits & license

MIT licensed — see `LICENSE`. Uses [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT).
Unofficial fan mod, not affiliated with the developer of SpaceBourne 2.
