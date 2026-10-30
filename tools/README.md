# Tools (for maintainers)

Used to check HTR's game-internal names after a SpaceBourne 2 update. None of this is
needed to play.

- `sb2dump/` — C# console app (CUE4Parse). Dumps Blueprint packages, including their Kismet
  bytecode, to JSON:
  `sb2dump <...\SB2\Content\Paks> <oo2core_*_win64.dll> <outDir> <regex>...`
  The game pak is Oodle-compressed; point it at an `oo2core` DLL you already have from
  another installed game.
- `kis.py` — renders those JSON dumps as readable pseudo-code:
  `python kis.py --all <dumpDir> <codeDir>`
- `curves.py` — prints curve tables (stats per level).
- `bt.py` — prints a behaviour tree from a dump as an outline (decorators, tasks, EQS queries):
  `python bt.py <dumpDir>\SB2\Content\1Data\11_AI\1_VAL_ShootCover.uasset.json`

After an update: dump `1Data/11_AI/Q1_Shooter_AI`, `1Data/Q1_Character` and
`1Data/Weapons/Hand_Weapons/Weapons/Master_Hand_Weapon`, check that every name in
`mod/HardcoreTacticalRealism/scripts/htr/gamedefs.lua` still exists, and fix that file.
Decompiled game data must not be committed or published.
