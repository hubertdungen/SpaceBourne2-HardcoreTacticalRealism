--[[
  Combat doctrines: how different kinds of NPC fight. Pure data - tune freely.

  sense       XVision check interval in s (lower = reacts faster)        vanilla 0.3 / 0.2
  sight       detection range in cm                                       vanilla 3500
  projSpeed   bullet speed in cm/s                                        vanilla 10000 (100 m/s!)
  fireRate    seconds between shots while firing                          vanilla 0.1
  magazine    rounds before a 3-5 s reload                                vanilla 20
  spread      aim error in degrees (human hand + nerves)
  settle      seconds of extra-wide spread after acquiring a target
  aimCenter   chance a shot is aimed at centre mass instead of a random body point
  reactToHits chance to break for cover when hit
  coverOnSuppress chance to duck when your rounds land close
  retreatHP   below this HP fraction, fall back to a hidden position (0 = never)
  panic       chance to run when a nearby ally dies
  alertRadius cm; allies inside it are alerted when this NPC is hit or dies
  grenades    uses grenades to flush targets out of cover (if NPCGrenades on)
]]

return {
    pirate = {
        label = "Pirate / raider", sense = 0.45, sight = 3500, projSpeed = 36000, fireRate = 0.085, magazine = 30,
        spread = 2.6, settle = 1.0, aimCenter = 0.55, reactToHits = 0.5, coverOnSuppress = 0.25,
        retreatHP = 0.45, panic = 0.35, alertRadius = 1200, grenades = false,
    },
    militia = {
        label = "Militia / low-tier troops", sense = 0.38, sight = 4000, projSpeed = 38000, fireRate = 0.11, magazine = 30,
        spread = 2.0, settle = 0.9, aimCenter = 0.7, reactToHits = 0.7, coverOnSuppress = 0.45,
        retreatHP = 0.35, panic = 0.2, alertRadius = 1800, grenades = false,
    },
    regular = {
        label = "Faction regulars", sense = 0.30, sight = 4500, projSpeed = 42000, fireRate = 0.13, magazine = 30,
        spread = 1.5, settle = 0.7, aimCenter = 0.85, reactToHits = 0.85, coverOnSuppress = 0.6,
        retreatHP = 0.3, panic = 0.1, alertRadius = 2500, grenades = true,
    },
    elite = {
        label = "Elite faction troops", sense = 0.20, sight = 5500, projSpeed = 46000, fireRate = 0.15, magazine = 30,
        spread = 0.9, settle = 0.5, aimCenter = 0.95, reactToHits = 1.0, coverOnSuppress = 0.75,
        retreatHP = 0.25, panic = 0.0, alertRadius = 3500, grenades = true,
    },
    machine = {
        label = "Robots", sense = 0.25, sight = 5000, projSpeed = 50000, fireRate = 0.12, magazine = 40,
        spread = 1.1, settle = 0.4, aimCenter = 1.0, reactToHits = 0.0, coverOnSuppress = 0.0,
        retreatHP = 0.0, panic = 0.0, alertRadius = 2500, grenades = false,
    },
    companion = {
        label = "Companions & allies", sense = 0.22, sight = 5000, projSpeed = 46000, fireRate = 0.14, magazine = 30,
        spread = 1.0, settle = 0.5, aimCenter = 0.9, reactToHits = 0.9, coverOnSuppress = 0.6,
        retreatHP = 0.25, panic = 0.0, alertRadius = 3000, grenades = false,
    },
}
