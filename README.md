<p align="center"><img src="docs/banner.png" alt="Hardcore Tactical Realism - Combat & AI Overhaul" width="100%"></p>

# Hardcore Tactical Realism (HTR) — Combat & AI Overhaul for SpaceBourne 2

On-foot combat in SpaceBourne 2 is an MMO bullet-sponge: a level 30 raider soaks up
15 000 HP plus 15 000 armor, your damage depends on weapon level, and headshots barely
matter. **HTR replaces that with ballistics**: what kills is the round, where it hits and
what armor it hits. Enemies go down fast, fight smarter, bleed, break bones and throw
grenades — and so can you. Fight from cover.

Inspired by Cyberpunk 2077 *Hardcore Realism*, Fallout: New Vegas *Realistic Combat
Overhaul* and *NPC AI Improvement* (no code from those mods is used). Works together with
my [SB2 HOTAS](https://github.com/hubertdungen/SpaceBourne2-HOTAS) mod ([Nexus](https://www.nexusmods.com/spacebourne2/mods/8)).

**Links:** [GitHub](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism) ·
[Nexus Mods](https://www.nexusmods.com/spacebourne2/mods/4) ·
[Steam discussion](https://steamcommunity.com/app/1646850/discussions/0/573805072991123580/) ·
[SB2 HOTAS](https://github.com/hubertdungen/SpaceBourne2-HOTAS) ([Nexus](https://www.nexusmods.com/spacebourne2/mods/8)).
**HTR is the core of the realism set.** The other mods were designed as extras on top of it, but none of them needs HTR,
and HTR needs none of them: every mod works on its own, in any combination. We tested all the extras together without HTR, in game,
with no errors.
**Install the whole set in one go:** the [SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)) lets you tick the mods you want, switches them on and
updates them all with one click.
**Realism set:** [Split Controls](https://github.com/hubertdungen/SpaceBourne2-SplitControls)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/5)) separates the vertical invert for ship
and on foot, per device. [Silent Ops](https://github.com/hubertdungen/SpaceBourne2-SilentOps)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/6)) adds stealth, takedowns and suppressors on
top of HTR's awareness. [Gear Without Levels](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/7)) lets you use gear above your level with small
handling penalties. [Faction Power](https://github.com/hubertdungen/SpaceBourne2-FactionPower)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/9)) lets dungeons, strategic sales and missions earn
your faction power, and the galaxy's factions react. [Tactical Engineering](https://github.com/hubertdungen/SpaceBourne2-TacticalEngineering)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/10)) makes deployable turrets realistic. [SB2 HOTAS](https://github.com/hubertdungen/SpaceBourne2-HOTAS)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/8)) adds HOTAS, triple screens and head tracking.
[Ammo Discipline](https://github.com/hubertdungen/SpaceBourne2-AmmoDiscipline) ([Nexus](https://www.nexusmods.com/spacebourne2/mods/12))
limits carried ammo and scavenging, so every magazine counts. [Ground Waypoints](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/13)) shows planet waypoints on foot and on the hoverbike.
[Get Out of the Way](https://github.com/hubertdungen/SpaceBourne2-GetOutOfTheWay) ([Nexus](https://www.nexusmods.com/spacebourne2/mods/14))
makes NPCs step aside naturally when you walk through them.
[Tactical First Person](https://github.com/hubertdungen/SpaceBourne2-TacticalFirstPerson) ([Nexus](https://www.nexusmods.com/spacebourne2/mods/15))
adds first person on foot, with weapons held up and aiming down the sights.

## Install (2 minutes)

HTR is a Lua mod for **UE4SS**, a free script loader for Unreal Engine games. Pick one:

**A. SpaceBourne 2 Realism installer (recommended)**
Get it on [Nexus](https://www.nexusmods.com/spacebourne2/mods/11) or
[GitHub](https://github.com/hubertdungen/SpaceBourne2-Realism/releases/latest). Tick HTR and any
other mods of the set: it installs UE4SS if you don't have it, switches the mods on and keeps them
updated.

**B. Manual** (Nexus file, or `-lite.zip` on GitHub)
1. Extract the zip into your game folder (`...\SpaceBourne 2`, the one with `SpaceBourne2.exe`).
   It creates `SB2\Binaries\Win64\Mods\HardcoreTacticalRealism` and switches itself on.
2. No UE4SS yet? Get [RE-UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1)
   and copy `dwmapi.dll`, `UE4SS.dll` and `UE4SS-settings.ini` into
   `SpaceBourne 2\SB2\Binaries\Win64\`.

**Update:** the installer does it for you, or extract the new zip the same way (your `config.lua`
is kept when you use the installer). **Uninstall:** untick HTR in the installer or delete the
`HardcoreTacticalRealism` folder. HTR never writes to your saves, so you can add or remove it at
any time.

## Controls

| Key | What it does |
|---|---|
| **F7** | Next mode: Tactical → Tactical Hardcore → Realism → Realism Hardcore (shown on the HUD) |
| **Shift+F7** | Gear bonus on/off (off by default; see below). Was F8 before 0.4.3, which is also the game's quick load |
| **F9** | Ships vs infantry on/off (shown on the HUD) |
| **Shift+F3** | Slow perks on/off, on foot (on by default; see below). Was F11 before 0.4.8, which is the game's fullscreen toggle |
| Gamepad (experimental) | press **Switch camera** 4 times quickly = next mode; crouched = ships toggle |

All choices are remembered between sessions. Keys can be changed in `config.lua`. HTR's
messages appear on the HUD without the game's red-alert sound (`Messages.Quiet`).

## Perks (Shift+F3 — slow by default)

With realistic damage, perks such as the turret, barricade, ground slam, shield or slow time
turn into super powers. HTR makes the suit's perk energy refill **4x slower on foot** and the
turret / barricade / ground-slam / auto-revive cooldowns run 4x slower, so a perk is a tactical
tool you save for the right moment. Ship energy is not affected. Shift+F3 (on foot) switches back to vanilla.

## Modes

| Mode | Damage you and your allies take | Wounds on your side |
|---|---|---|
| **Tactical** (default) | follows weapon and hit zone, always **100–150 %** of vanilla | rare |
| **Tactical Hardcore** | Tactical, then **all damage x2** (both sides) | occasional |
| **Realism** | **exactly the same rules as enemies**; your suit is your armor | full |
| **Realism Hardcore** | Realism, then **all damage x2** (both sides) | full, bleeding x2 |

Enemies always use the realistic model.

## Damage model

- Damage = **caliber vs armor + hit zone**. NPC level, weapon level and rarity no longer matter
  (unless you switch on the small optional gear bonus, Shift+F7).
- Unarmored targets drop in **1–2 rifle hits**, heavy armor in **5–6**, power armor and
  robots in **6–8**. Snipers kill almost anything in one hit; melee kills in one or two blows.
- **Headshots** kill a bare head with any firearm, and **no helmet stops a headshot
  completely** (at least 40 % always gets through): 1–2 headshots kill through any helmet.
  This applies to everyone — NPCs shooting NPCs included (vanilla has no NPC headshots).
- Armor **wears down** as it stops rounds (the armor bar shows its condition); worn armor
  protects less. Vanilla's armor-overflow bug is gone.
- Destroyed limbs use the game's own dismemberment; lethal hits blow off the part that was
  hit (needs *Gore* on in Gameplay settings).

| Hits to kill (centre mass / head) | none | light | medium | heavy | power |
|---|---|---|---|---|---|
| Pistol | 2 / 1 | 4 / 1 | 6 / 2 | 7 / 2 | 8 / 2 |
| SMG | 2 / 1 | 4 / 1 | 6 / 2 | 8 / 2 | 8 / 2 |
| Rifle | 2 / 1 | 3 / 1 | 4 / 1 | 5 / 2 | 6 / 2 |
| Hunter (DMR) | 2 / 1 | 2 / 1 | 2 / 1 | 3 / 1 | 3 / 1 |
| Sniper | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 | 2 / 1 |
| Knife / Sword / Hammer | 1 | 1 | 2 / 1 / 1 | 2 / 2 / 1 | 3 / 2 / 2 |

Shotgun pellets count individually (one close blast kills an unarmored target). Bosses have
a tougher body and better-made power armor that wears half as fast (about 12 rifle hits, 3 to
the head; a DMR needs 6, a sniper 3). Ground turrets (team battles, bases) are
heavy emplaced guns: one round every 1.5 s, one hit kills an unarmored target, two kill through
any armor. Your turret perk and the mini-bosses' mini-turrets are light rapid-fire guns with
rifle-class rounds.

## Gear bonus (optional, Shift+F7 — off by default)

For players who still like a bit of RPG feel. With the gear bonus on, weapon and armor **level**
(and item rarity) add a **small extra** on top of the ballistics — they never decide whether a
weapon works. A level 5 rifle still drops a level 60 raider in a few hits; a level 60 rifle just
needs one hit fewer.

- **Weapon:** up to +8 penetration points and +15 % damage.
- **Armor:** up to +8 protection points and 25 % less wear (only where there is armor).
- **Scale:** diminishing returns — level 1 gives nothing, level 10 gives 56 % of the bonus,
  level 30 gives 83 %, level 60 the full bonus. Each rarity step above common counts as 5 levels.
- **Whose level:** your weapon item and your level for your suit; NPCs and turrets their own
  level; squad soldiers your level. It works the same for both sides, so it also fits the
  Realism modes (you can switch it off per mode in `config.lua`). In the Tactical modes the damage
  you and your allies take stays at 100–150 % of vanilla, so there the bonus mostly changes the
  damage your side deals.

| Rifle vs heavy armor, hits to kill | armor L1 | armor L10 | armor L30 | armor L60 |
|---|---|---|---|---|
| Rifle L1 | 5 | 6 | 6 | 6 |
| Rifle L10 | 4 | 5 | 5 | 5 |
| Rifle L30 | 4 | 4 | 5 | 5 |
| Rifle L60 | 4 | 4 | 4 | 5 |

Gear bonus off (the default) = the tables above, for every level.

## Wounds and healing

- **Bleeding:** a round that gets through the armor can open a wound that drains HP for
  15–25 s until the suit's nanites clot it (up to 3 wounds at once). Bleeding stops healing.
- **Broken bones:** a heavy hit to an arm or leg can break it until the nanites fuse it (about a
  minute). Broken leg: you limp at half speed and cannot sprint (below 30 % HP you can only walk);
  NPCs and squad soldiers can only walk, and most enemies lose their nerve: pirates and militia
  often try to get away, the others break off and fight from cover (elites and robots don't
  flinch). Broken arm:
  your aim drifts and trembles; NPCs spray with 3x their spread. Your healing is halved meanwhile.
- **You feel it:** while you bleed, the screen pulses dark red like a heartbeat — stronger and
  faster the more you bleed; bleeding hard or below a quarter of your HP, the view lurches now and
  then. Nothing shows while you are unhurt (`Wounds.ScreenEffects`).
- **Robots** never bleed, but a heavy hit can still wreck an arm (shaky aim) or a leg.
- **Squad soldiers** bleed too; once they go down, the game's own bleed-out timer takes over
  and a medic (or you) can still bring them back.
- Enemies get wounded in every mode. You and your allies get wounded rarely in Tactical,
  more in Tactical Hardcore, and fully in Realism; Hardcore modes bleed twice as fast.
- **Healing:** your suit's own healing is kept but slowed by mode — Tactical 70 %, Tactical
  Hardcore 50 %, Realism 25 %, Realism Hardcore 12 % of vanilla — and it starts 8–15 s after
  your last hit. Armor nanites slowly repair the suit too.

## Not always dead (knockouts)

A lethal hit sometimes knocks the victim out instead of killing: you, your allies and enemies
(Tactical 18 %, Tactical Hardcore 12 %, Realism 10 %, Realism Hardcore 5 %). Never on a headshot,
a big explosion or heavy overkill; robots and bosses are never knocked out.

- Someone can bring the downed back: a squad medic fastest, otherwise a squad soldier or a
  companion. Enemies revive their own by training: elites fast and reliably, regulars slower,
  militia and pirates rarely, and they often give up under fire.
- Nobody goes in under fire: the area round the body must be clear. The reviver has to stay with
  the body for a few seconds, and it can fail.
- Nobody comes within 45 s: the downed one bleeds out. While you are down you take no damage.
- `Knockout` in config: on/off, chance per mode, bleed-out time.

**Getting medics.** Your ground soldiers are members of your faction. In your faction's member
list (the screen where you give members a role such as Soldier, Pilot or Researcher, with
**Train Soldiers** and **Upgrade Soldier**), each soldier has a type: **Blitzkrieg** (rifle),
**Tank**, **Medic** or **Reaper**. Pick **Medic** there. You can't change a type while the squad
is on the field. With HTR, medics come for downed squadmates and for you, and they are the fastest.
Ordinary soldiers and companions help too, more slowly. Tip: keep at least one medic in the squad.

## Explosions, grenades and ships

- **Explosions** (your grenades, NPC grenades, rockets) do realistic damage that fades with
  distance and gibs at close range. In vanilla, NPCs ignore every explosion that isn't yours.
- **NPC grenades:** regular and elite troops throw grenades when you hide behind cover too long.
- **Ships vs infantry (F9):** ship guns — yours and AI ships' — now hit people on foot. A direct
  hit kills almost anyone and the blast hurts everyone nearby, friends included.

## Friendly fire

| Attacker → victim | Tactical modes | Realism modes |
|---|---|---|
| You → companions / squad | 35 % | 100 % |
| Companions / squad → you | 35 % | 100 % |
| Ally → ally, allied turrets | vanilla, max 10 % HP per hit | same |
| Enemy → enemy, ally ↔ enemy | 100 % (realistic) | same |

Ground turrets fight for their own team. Your squad soldiers now take realistic damage too:
in the Tactical modes they go down injured first (as vanilla); in the Realism modes headshots
and heavy overkill kill outright and other lethal hits almost always do (80 % / 95 %), so both
sides follow the same lethal rules. They wear at least medium armor and a helmet, so they
can hold a firefight instead of dropping as soon as they show up.

## AI and doctrines

- NPC bullets fly at 360–500 m/s instead of 100 m/s, but NPCs aim like people: spread by
  training, a settle-in time after spotting you, worse aim while moving, hurt or suppressed,
  and centre-mass aim instead of vanilla's random feet/above-the-head points.
- Vanilla behaviour that never triggered now works: breaking line of sight when hit, falling
  back when badly hurt, calling allies, peeking from cover every 2.5 s instead of 5 s.
- **NPCs keep fighting:** an NPC that dives for cover fights from there for a few seconds
  before your fire can send it running again (no more enemies that only run under fire), and it
  resumes firing as soon as it aims at you again.
- **Your squad keeps up:** vanilla squad soldiers walk, fall behind and then teleport next to
  you. HTR makes them run and sprint after you, so only a stuck soldier still teleports.
- **Suppression:** your rounds landing close make enemies duck and shoot worse.
- **Situational awareness:** relaxed enemies (no fight yet) only notice you up close; once
  alert (they spotted you, got hit or were warned) they spot and shoot much farther.
- **Arrival grace:** after an elevator ride, a new dungeon floor or a level load, and for
  freshly spawned NPCs, everyone (enemies and allies) aims very badly for 3-4 s, so nobody
  gets massacred the moment a floor loads.
- Companions' bullets work (vanilla gave them a 0-second projectile life).

| Doctrine | Who | How they fight |
|---|---|---|
| Pirate | raiders, salvagers | slow, spray, wide spread, may panic when mates die or flee when badly hurt |
| Militia | low-tier troops | better than pirates, still sloppy |
| Regular | standard faction troops | quick, accurate, cover, grenades |
| Elite | high-tier troops, guards, bosses | fastest reactions, tight aim, grenades, alert the area |
| Machine | robots | fearless, steady, never retreat |
| Companion | your allies | elite-level aim, no panic |

## Game bugs HTR fixes

- **Crash when loading after you die in a long firefight** ("Fatal error", also without mods):
  your bullets often stay alive, frozen, after hitting something, and a load with many of them
  around can crash the game. HTR ends each of your bullets right after its hit (0.4.6).
- **Armor overflow:** the hit that empties vanilla armor also takes the armor's value from your HP.
- **Companions' bullets** had a 0-second life and did nothing.

## Settings

`SB2\Binaries\Win64\Mods\HardcoreTacticalRealism\scripts\config.lua` (open with Notepad,
restart the game after saving): mode and keys, every feature on/off, Hardcore multiplier,
helmet rule, wounds and healing per mode, gear bonus strength, ships vs infantry strength,
perk speed, enemy awareness ranges, squad pace, friendly fire, boss toughness, quiet messages,
game-bug fixes, logging. Deeper tuning: `htr\ballistics.lua` (calibers, armor, hit zones)
and `htr\doctrines.lua` (how each kind of NPC fights).

## Known limitations

- On-foot combat only; ship-vs-ship combat is unchanged.
- The game has no faction field on soldiers, so doctrines use its raider flag, troop tier,
  guard/robot/boss flags and companion status.
- Gamepad toggles are experimental (untested without a controller).
- Tested on the Steam build of 26 Oct 2026. Bug reports with `htr.log` (set `Debug.Log = true`)
  are very welcome (for a crash, please add `UE4SS.log` and the newest folder in
  `%LOCALAPPDATA%\SB2\Saved\Crashes`); if you ever notice stutter, `htr.log` names any HTR code that took longer
  than 8 ms.
- **Versions before 0.3.2 froze the game for a moment on every shot** — fixed in 0.3.2; please update.
  In-game tests while firing now show the same frame times as the game without mods.

## After a game update

Every game-internal name lives in one file, `htr\gamedefs.lua`. If an update renames
something, HTR switches that feature off (logged in `UE4SS.log`) instead of crashing.
`tools\` holds the scripts used to inspect the game's Blueprints.

## Credits & license

MIT licensed — see `LICENSE`. Uses [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT).
Code written with AI assistance; banner images are AI-generated. Unofficial fan mod, not
affiliated with the developer of SpaceBourne 2.
