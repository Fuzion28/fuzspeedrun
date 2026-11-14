# ⏱️ FuzSpeedrun v1.5

Speedrun mod for BO7 Zombies on Kronos: a timer and automatic splits for every map, and nothing that changes a run.

## 📊 Split panel
- LiveSplit-style panel on the right side of the screen
- Big timer, current split highlighted, deltas against your PB, best segments
- The timer starts when you start moving and counts real time: it keeps running while the game is paused
- Personal bests and best segments are saved per map

## 🗺️ Splits

| Map | Splits |
|---|---|
| **Ashes of the Damned** | Gauntlet, Lockdown end, Keys, Challenges, Veytarion |
| **Astra Malorum** | LGM-1, Brain, Mars, Ritual, Caltheris |
| **Kowakujo** | Cat, Mask, Noble, Poisons, Locations, Boss, End |
| **Totenreich** | JOTUNN Star, Atomkraft core, Boss enter, End |
| **Paradox Junction** | Chalk, Sundergat, Symbols, Soulbox, Boss enter, End |
| **Rex Infernus** | Pap, House, Vey Finish, Boss Enter, End |

## ⏸️ Pause menu options (ESC)
- **Timer**: off, timer + splits, or timer only
- **Infinite gums**
- **Mode**: Easter Egg, Pack-a-Punch, or Round 5 / 15 / 30 / 50 / 70 / 100 (splits every round for R5, every 5 rounds for R15 and R30, every 10 rounds after; the time stops when round N starts)
- **Start speedrun**: restarts the map for a fresh run

## ⌨️ Keys
- **F8**: fast restart
- On a map without splits: **F6** to split, **F7** to undo the last split

## 📈 LiveSplit autosplitter
`livesplit/fuzspeedrun.asl` starts and splits LiveSplit automatically. It only reads a file written by the mod, never the game's memory.

## 📦 Install
Kronos launcher → **Workshop** → **FuzSpeedrun** → Install.

Or download the latest release and put the `fuzspeedrun` folder in your Kronos `mods` folder.

Use FuzSpeedrun **or** FuzMenu, not both at once: keep only one enabled.

## 🔧 Change the panel
Each map has its own `lua/zm_split_<map>_post.lua` for the title and split names. See `lua/zm_split_TEMPLATE.txt`.
