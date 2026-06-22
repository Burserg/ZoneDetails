## ZoneDetails
First I want to give credit where credit is due. This project is based off of Cartographer_ZoneInfo by ckknight. Also shout out to phyber for Cromulent.

This addon is designed for WoW Classic.

# TODO
* [x] Instance levels
* [x] Raid info
* [x] Colorize Zones based on level vs player level
* [x] Colorize Instances based on player level
* [x] Add Battleground information where applicable
* [x] Add Localization support
* [x] Nodes available in given zone for Herbalism and Mining 
* [x] Add Profile support
* [x] Add options page
    * [x] Toggles for pins
    * [x] Profession Toggles
    * [x] Text size selector
* [x] Entrance pins on map
* [x] Account for Complex maps such as Scarlet Monastery, Ahn'Qiraj, and Dire Maul.
* [x] Add support for map details on continent/world maps on hover.
* [x] Season of Discovery: dungeon→raid conversions, flexible raid sizes, Demon Fall Canyon, Scarlet Enclave, Karazhan Crypts, and pin stacking for co-located entrances.
* [ ] Add SoD incursion world bosses (Tainted Scar, Storm Cliffs, Crystal Vale, Nightmare Grove) — needs a representation for instanced world-boss / multi-portal raids.

# Building from source

The embedded libraries under `Libs/` are **not** committed to this repository — released builds
pull them via the externals declared in `.pkgmeta` (the CurseForge packager fetches the current
versions at build time). A fresh checkout therefore won't load in-game until `Libs/` is populated.

To populate `Libs/` for local testing, run the helper from the repo root:

* **Windows:** `powershell -ExecutionPolicy Bypass -File .\fetch-libs.ps1`
* **macOS / Linux / WSL:** `./fetch-libs.sh`

Both download the Ace3 library bundle and copy the libraries this addon uses into `Libs/`
(gitignored, so they're never committed). The Windows script needs nothing beyond PowerShell;
the shell script needs `curl` and `unzip`.
