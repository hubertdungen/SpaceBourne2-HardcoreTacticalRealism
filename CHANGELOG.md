# Changelog

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
