# LibFights examples

Small, complete add-ons built on [LibFights](../LibFights/README.md). Each folder is one add-on:
copy the folder into `Documents/Elder Scrolls Online/live/AddOns/` next to `LibFights`, then `/reloadui`.

Keep this folder **outside** the `LibFights` folder. ESO loads add-ons nested up to three folders deep,
so examples inside LibFights would load and run for everyone who installs the library.

Only one installed add-on needs to start logging. **MyFightLog** (or LibFights Rundown) does that;
the others only listen, so pair them with one of those.

| Folder | Example | What it does |
|---|---|---|
| `MyFightLog` | Auto-logger | The smallest useful add-on. Starts logging when you enter combat, prints the fight summary when it ends, and stops logging again. It never stops logging that another add-on started. |
| `MyDpsMeter` | Live DPS meter | A small movable window that shows DPS, HPS and SPS twice a second while a fight runs, then the final DPS when it ends. It hides itself in menus. |
| `MyBests` | Personal bests | Remembers your best DPS for every boss or target and tells you when you beat it. Bests are kept in your own SavedVariables, with LibFights' export string for each one. |
| `MyTopAbilities` | Top abilities with icons | Type /topdmg or /topheal to list the five biggest abilities of your last fight, with their icons, share of the total and crit rate. |
| `MySetReport` | Set and proc report | After every fight, lists each set you wore with its share of your damage, uptime and procs per minute, then the proc sets whose cooldown LibFights could measure. |
| `MyTankReport` | Tank and shield report | After a fight, prints how much damage you took, mitigated and absorbed with shields, how well your shields were used, your estimated damage reduction, and who hit you hardest. |
| `MyPenCheck` | Penetration check | Type /pencheck after hitting a target. It reads the resistance model and tells you whether you are over or under the penetration you need. |
| `MyDeathRecap` | Death recap | When you die, prints the last five hits you took: when, how much, what ability and who it came from. |
| `MyBuild` | Build reader and change alert | Type /mybuild to print your class, sets, front bar, mundus and key stats. It also tells you at the start of a fight what changed since your last one. |
| `MyBossTimer` | Boss kill timer | While a fight runs, checks the boss's time-to-kill every second and warns you once when it will die in under 10 seconds. At the end it prints the predicted and real fight length. |
| `MyFightPanel` | Settings panel | A settings page with an auto-start switch and buttons to start, stop and print the last fight. It uses LibAddonMenu on PC and LibHarvensAddonSettings on console. |
| `MySearch` | Search command | Type /lfs followed by anything: an ability or set name, an id, or filters. It prints the first ten matches. |
| `MyBigCrits` | Big crit counter | After a fight, counts your crits over 20,000 and names the biggest one, using the raw event query. |

Slash commands work on PC only. On console, use a settings page like `MyFightPanel`.
The same examples, with explanations, are in the `Add-on examples` section of `LibFights/API.html`.
