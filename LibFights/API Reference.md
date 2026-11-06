# LibFights API Reference

Every public function in the LibFights library for Elder Scrolls Online (PC/Mac and console), what each one returns, including the `false` and `nil` cases, and every data structure it hands back.

> **Nothing is logged until you call `Start_Logging()`.** Lookups (abilities, sets, build, stats, search) work at any time.

Also available as a searchable page, [API.html](API.html), and as plain text, [API.txt](API.txt). The examples are ready to install in [LibFights-Examples](../LibFights-Examples/README.md).

## Contents

- **Start here**: [Quick start](#quick-start) · [How to read this](#how-to-read-this) · [Add-on examples](#add-on-examples)
- **Recording**: [Logging](#logging) · [Reading fights](#reading-fights) · [Callbacks](#callbacks)
- **Fight data**: [Fight methods](#fight-methods) · [Search and queries](#search-and-queries)
- **Game data**: [Abilities and IDs](#abilities-and-ids) · [Sets](#sets) · [Stats](#stats) · [Build reader](#build-reader)
- **Predictions**: [Models](#models)
- **Output**: [Saved data and settings](#saved-data-and-settings) · [Text reports](#text-reports) · [HUD and settings panel](#hud-and-settings-panel)
- **Helpers**: [Core and Util](#core-and-util) · [Constants](#constants)
- **Reference**: [Data structures](#data-structures) · [Internal functions](#internal-functions)

## Quick start

### 1. Record a fight

Nothing is logged until you start it.

```lua
Start_Logging()            -- events are registered from here on
-- ...fight something...
local ok, fight = Stop_Logging() -- ok = true, fight = the fight that ended
```

### 2. Read the numbers

GetSummary() has every metric in one table.

```lua
local f = LibFights.GetLastFight()
local s = f:GetSummary()
d(("DPS %.0f  HPS %.0f  SPS %.0f"):format(s.dps, s.hps, s.sps))
d(("Crit %.1f%%"):format(s.critRate * 100))  -- critRate is 0..1
```

### 3. React to fights

Callbacks fire while logging.

```lua
LibFights.RegisterCallback(LibFights.EVENTS.FIGHT_ENDED,
  function(fight, reason)
    LibFights.PrintLines(LibFights.Report.FightSummaryLines(fight))
  end)
```

### 4. Look things up

Abilities, sets and search work any time.

```lua
local info = LibFights.Abilities.GetInfo(46340)  -- nil if invalid
local sets = LibFights.Sets.Search("kinras")
local hits = LibFights.Search("in:set relequen")
```

[Back to contents](#contents)

## How to read this

| Notation | Meaning |
|---|---|
| `LF` | The global table `LibFights`. |
| `f` | A Fight object, e.g. `LibFights.GetLastFight()`. |
| `name?` | A parameter with a question mark is optional. |
| → value | What the function returns. Several values are returned in that order, Lua style: `local ok, fight = Stop_Logging()`. |
| ⚠ `false` / `nil` | Marked rows are the failure or "nothing found" cases. Check for them before using the result. |
| nothing | Returns no value (you get nil if you read it). |
| ms / sec | Milliseconds and seconds. Fight times are game time from `GetGameTimeMilliseconds()`. |
| 0..1 / 0..100 | 0..1 is a fraction (0.52 = 52%). 0..100 is already a percentage. Fight stats use 0..1; the models use 0..100. |

[Back to contents](#contents)

## Add-on examples

Complete add-ons you can copy into `AddOns/`. Each one needs LibFights installed and lists it in `## DependsOn`. The same examples are ready to install, one folder each, in [LibFights-Examples](../LibFights-Examples/README.md). Slash commands work on PC only; on console, use a settings page like the one in [Settings panel](#settings-panel).

### Auto-logger

*PC + console*. The smallest useful add-on. Starts logging when you enter combat, prints the fight summary when it ends, and stops logging again. It never stops logging that another add-on started.

Uses: `Start_Logging` `Stop_Logging` `Is_Logging` `RegisterCallback` `FIGHT_ENDED` `FightSummaryLines`

**`MyFightLog/MyFightLog.addon`**

```text
## Title: My Fight Log
## Author: you
## Version: 1.0.0
## APIVersion: 101047 101048
## DependsOn: LibFights

MyFightLog.lua
```

**`MyFightLog/MyFightLog.lua`**

```lua
local NAME = "MyFightLog"
local LF = LibFights
local weStarted = false   -- did this add-on turn logging on?

local function OnCombatState(_, inCombat)
  if inCombat and not Is_Logging() then
    weStarted = Start_Logging()   -- true, or false if already logging
  end
end

local function OnFightEnded(fight, reason)
  LF.PrintLines(LF.Report.FightSummaryLines(fight))

  -- stop shortly after, once LibFights has closed the fight
  zo_callLater(function()
    if weStarted and not IsUnitInCombat("player") and not LF.GetCurrentFight() then
      weStarted = false
      Stop_Logging()
    end
  end, 100)
end

local function OnLoaded(_, addonName)
  if addonName ~= NAME then return end
  EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
  EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
  LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, OnFightEnded)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnLoaded)
```

> The other examples are one Lua file each. Use this manifest for them too: change the title, the folder and the file name. Only one add-on needs to start logging; the rest just listen.

### Live DPS meter

*PC + console*. A small movable window that shows DPS, HPS and SPS twice a second while a fight runs, then the final DPS when it ends. It hides itself in menus.

Uses: `GetCurrentFight` `FIGHT_STARTED` `FIGHT_ENDED` `f:GetDPS` `f:GetHPS` `f:GetSPS` `f:GetDurationMs` `FormatNumber` `FormatDuration`

**`MyDpsMeter.lua`**

```lua
local LF = LibFights
local U = LF.Util
local UPDATE = "MyDpsMeter_Update"

local win = WINDOW_MANAGER:CreateTopLevelWindow("MyDpsMeter")
win:SetDimensions(260, 56)
win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -220)
win:SetMovable(true)
win:SetMouseEnabled(true)
win:SetClampedToScreen(true)

local label = WINDOW_MANAGER:CreateControl("MyDpsMeterText", win, CT_LABEL)
label:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
label:SetFont("ZoFontGameLargeBold")
label:SetText("Waiting for a fight")

-- only visible on the normal HUD
local fragment = ZO_HUDFadeSceneFragment:New(win)
HUD_SCENE:AddFragment(fragment)
HUD_UI_SCENE:AddFragment(fragment)

local function Refresh()
  local f = LF.GetCurrentFight()
  if not f then return end
  label:SetText(("%s  DPS %s  HPS %s  SPS %s"):format(
    U.FormatDuration(f:GetDurationMs()),
    U.FormatNumber(f:GetDPS()), U.FormatNumber(f:GetHPS()), U.FormatNumber(f:GetSPS())))
end

LF.RegisterCallback(LF.EVENTS.FIGHT_STARTED, function()
  EVENT_MANAGER:RegisterForUpdate(UPDATE, 500, Refresh)
end)

LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(fight)
  EVENT_MANAGER:UnregisterForUpdate(UPDATE)
  local s = fight:GetSummary()
  label:SetText(("Last fight: %s DPS over %s"):format(
    U.FormatNumber(s.dps), U.FormatDuration(s.durationMs)))
end)
```

> This only reads fights. Something has to call `Start_Logging()`, such as the auto-logger above.

### Personal bests

*PC + console*. Remembers your best DPS for every boss or target and tells you when you beat it. Bests are kept in your own SavedVariables, with LibFights' export string for each one.

Uses: `FIGHT_ENDED` `f:GetSummary` `Export` `CommaNumber` `LF.Print` `SavedVariables`

**`MyBests/MyBests.addon`**

```text
## Title: My Bests
## Author: you
## Version: 1.0.0
## APIVersion: 101047 101048
## DependsOn: LibFights
## SavedVariables: MyBestsSV
MyBests.lua
```

**`MyBests/MyBests.lua`**

```lua
local NAME = "MyBests"
local LF = LibFights
local U = LF.Util
local sv   -- loaded in OnLoaded

LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(fight)
  if not sv then return end
  local s = fight:GetSummary()
  if s.durationSec < 20 then return end   -- skip short trash pulls

  local best = sv.bests[s.title]
  if best and s.dps <= best.dps then return end

  sv.bests[s.title] = {
    dps = s.dps,
    seconds = s.durationSec,
    when = s.startTimestamp,
    export = LF.Report.Export(fight),
  }
  LF.Print("New best on %s: %s DPS%s", s.title, U.CommaNumber(math.floor(s.dps)),
    best and (" (was " .. U.CommaNumber(math.floor(best.dps)) .. ")") or "")
end)

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
  if addonName ~= NAME then return end
  EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
  sv = ZO_SavedVars:NewAccountWide("MyBestsSV", 1, nil, { bests = {} })
end)
```

### Top abilities with icons

*PC (slash command)*. Type /topdmg or /topheal to list the five biggest abilities of your last fight, with their icons, share of the total and crit rate.

Uses: `GetLastFight` `f:GetAbilityBreakdown` `f:GetTitle` `IconMarkup` `FormatPct` `AbilityRow`

**`MyTopAbilities.lua`**

```lua
local LF = LibFights
local U = LF.Util

local function PrintTop(kind)
  local f = LF.GetLastFight()
  if not f then
    LF.Print("No fight yet.")
    return
  end
  LF.Print("Top %s in %s (%s)", kind, f:GetTitle(), U.FormatDuration(f:GetDurationMs()))
  for i, row in ipairs(f:GetAbilityBreakdown(kind, "total", 5)) do
    d(("%d. %s %s  %s (%s)  crit %s"):format(i,
      U.IconMarkup(row.icon, 20), row.name,
      U.FormatNumber(row.total), U.FormatPct(row.pct), U.FormatPct(row.critRate)))
  end
end

SLASH_COMMANDS["/topdmg"] = function() PrintTop("damageOut") end
SLASH_COMMANDS["/topheal"] = function() PrintTop("healOut") end
```

> Other kinds: `"damageIn"`, `"healIn"`, `"shieldIn"`, `"shieldOut"`. Sort by any AbilityRow field, such as `"dps"` or `"max"`.

### Set and proc report

*PC + console*. After every fight, lists each set you wore with its share of your damage, uptime and procs per minute, then the proc sets whose cooldown LibFights could measure.

Uses: `FIGHT_ENDED` `f:GetSets` `f:GetProcs` `FightSet` `ProcEntry` `estimatedCooldownMs`

**`MySetReport.lua`**

```lua
local LF = LibFights
local U = LF.Util

LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(fight)
  local sets = fight:GetSets()
  if #sets == 0 then return end

  LF.Print("Sets in %s:", fight:GetTitle())
  for _, set in ipairs(sets) do
    d(("  %s %d/%d  %s of damage  uptime %s  %.1f procs/min"):format(
      set.name, set.equipped or 0, set.maxEquipped or 0,
      U.FormatPct(set.damageSharePct or 0), U.FormatPct(set.uptimePct or 0),
      set.activationsPerMinute or 0))
  end

  for _, proc in ipairs(fight:GetProcs()) do
    if proc.kind == "set" and proc.estimatedCooldownMs then
      d(("  %s procced %d times, cooldown about %.1fs"):format(
        proc.setName or proc.name, proc.activations, proc.estimatedCooldownMs / 1000))
    end
  end
end)
```

> Every set is logged while the `logAllSets` setting is on (the default). Use `LF.Sets.SetSetLogged(setId, true)` to log only some.

### Tank and shield report

*PC + console*. After a fight, prints how much damage you took, mitigated and absorbed with shields, how well your shields were used, your estimated damage reduction, and who hit you hardest.

Uses: `f:GetSummary` `shield` `sps` `shieldEfficiency` `mitigated` `GetIncomingDR` `f:GetSources`

**`MyTankReport.lua`**

```lua
local LF = LibFights
local U = LF.Util

LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(fight)
  local s = fight:GetSummary()
  if s.damageTaken == 0 and s.shield == 0 then return end

  LF.Print("Tank report: %s", s.title)
  d(("  Taken %s (%s DTPS)  Mitigated %s (%s)"):format(
    U.FormatNumber(s.damageTaken), U.FormatNumber(s.dtps),
    U.FormatNumber(s.mitigated), U.FormatPct(s.mitigationPct)))
  d(("  Shields absorbed %s (%s SPS), %s of incoming"):format(
    U.FormatNumber(s.shield), U.FormatNumber(s.sps), U.FormatPct(s.shieldPctOfIncoming)))
  d(("  Shield applied %s, used %s, wasted %s"):format(
    U.FormatNumber(s.shieldGained), U.FormatPct(s.shieldEfficiency), U.FormatNumber(s.shieldExpired)))

  local dr = LF.Models.GetIncomingDR()
  d(("  Estimated damage reduction %.1f%% (armor %.1f%%)"):format(dr.totalDRPct, dr.armorMitigationPct))

  for i, src in ipairs(fight:GetSources(3)) do
    d(("  %d. %s hit you for %s (%s)"):format(i, src.name, U.FormatNumber(src.damage), U.FormatPct(src.pct)))
  end
end)
```

### Penetration check

*PC (slash command)*. Type /pencheck after hitting a target. It reads the resistance model and tells you whether you are over or under the penetration you need.

Uses: `GetLastFight` `f:GetTargets` `GetTargetEstimate` `predictedResistance` `missingPenetration` `relativeToughnessPct`

**`MyPenCheck.lua`**

```lua
local LF = LibFights
local U = LF.Util

SLASH_COMMANDS["/pencheck"] = function()
  local f = LF.GetLastFight()
  local target = f and f:GetTargets(1)[1]
  if not target then
    LF.Print("Hit something first.")
    return
  end

  local est = LF.Models.GetTargetEstimate(target.name)
  if not est then
    LF.Print("No data on %s yet.", target.name)
  elseif (est.samples or 0) > 0 then
    LF.Print("%s: about %d resistance (%s confidence)",
      target.name, math.floor(est.predictedResistance), U.FormatPct(est.confidence))
    if est.status ~= "ok" then
      LF.Print("Note: %s", est.status)
    elseif (est.missingPenetration or 0) > 0 then
      LF.Print("You need about %d more penetration.", math.floor(est.missingPenetration))
    end
  else
    LF.Print("%s takes %.0f%% less damage than your average target. Hit a target dummy to calibrate.",
      target.name, est.relativeToughnessPct or 0)
  end
end
```

> Resistance in points needs calibration on a reference target (target dummies by default). Before that, only relative toughness is known.

### Death recap

*PC + console*. When you die, prints the last five hits you took: when, how much, what ability and who it came from.

Uses: `DEATH` `DeathEntry` `recap` `GetIconMarkup` `FormatDuration`

**`MyDeathRecap.lua`**

```lua
local LF = LibFights
local U = LF.Util

LF.RegisterCallback(LF.EVENTS.DEATH, function(fight, death)
  if death.unitTag ~= "player" or not death.recap then return end

  LF.Print("You died %s into %s. Last hits:", U.FormatDuration(death.tMs), fight:GetTitle())
  for i = math.max(1, #death.recap - 4), #death.recap do   -- recap is oldest first
    local hit = death.recap[i]
    d(("  %s %s %s from %s"):format(
      LF.Abilities.GetIconMarkup(hit.abilityId, 18), U.CommaNumber(hit.hit),
      hit.abilityName or "?", hit.source or "?"))
  end
end)
```

### Build reader and change alert

*PC (slash command)*. Type /mybuild to print your class, sets, front bar, mundus and key stats. It also tells you at the start of a fight what changed since your last one.

Uses: `LF.Build.Read` `Build` `GetSignature` `Compare` `f:GetBuild` `FIGHT_STARTED`

**`MyBuild.lua`**

```lua
local LF = LibFights
local U = LF.Util

SLASH_COMMANDS["/mybuild"] = function()
  local b = LF.Build.Read()
  local c = b.character
  LF.Print("%s, %s %s, CP %d", c.name, c.raceName, c.className, c.championPoints or 0)

  for _, set in pairs(b.sets) do
    d(("  %s %d/%d%s"):format(set.name, set.equipped, set.maxEquipped or 0,
      set.fullBonus and " (full bonus)" or ""))
  end
  for slot = 3, 8 do
    local skill = b.bars.front[slot]
    if skill then d(("  Front %d: %s %s"):format(slot - 2, U.IconMarkup(skill.icon, 18), skill.name)) end
  end
  for _, m in ipairs(b.mundus) do d("  Mundus: " .. m.name) end
  d(("  Spell pen %d  Physical pen %d  Weapon crit %.1f%%"):format(
    b.stats.spellPenetration or 0, b.stats.physicalPenetration or 0, b.stats.weaponCritPct or 0))
end

-- what changed between fights?
local lastBuild
LF.RegisterCallback(LF.EVENTS.FIGHT_STARTED, function(fight)
  local b = fight:GetBuild() or LF.Build.Read()
  if lastBuild and LF.Build.GetSignature(lastBuild) ~= LF.Build.GetSignature(b) then
    local diff = LF.Build.Compare(lastBuild, b)
    for name, v in pairs(diff.sets) do
      LF.Print("Set %s: %s -> %s pieces", name, tostring(v.old or 0), tostring(v.new or 0))
    end
    for _, v in ipairs(diff.bars) do
      LF.Print("%s bar slot %s: %s -> %s", tostring(v.bar), tostring(v.slot), v.old or "empty", v.new or "empty")
    end
  end
  lastBuild = b
end)
```

### Boss kill timer

*PC + console*. While a fight runs, checks the boss's time-to-kill every second and warns you once when it will die in under 10 seconds. At the end it prints the predicted and real fight length.

Uses: `GetTTK` `PredictFightOutcome` `FIGHT_STARTED` `FIGHT_ENDED` `RegisterForUpdate`

**`MyBossTimer.lua`**

```lua
local LF = LibFights
local TICK = "MyBossTimer_Tick"
local warned, predicted = false, nil

local function Tick()
  local seconds, health = LF.Models.GetTTK("boss1")
  if not seconds then return end   -- no boss, or health not falling yet

  local outcome = LF.Models.PredictFightOutcome()
  if outcome and outcome.predictedDurationSec then predicted = outcome.predictedDurationSec end

  if seconds < 10 and not warned then
    warned = true
    LF.Print("Boss dies in about %.0f seconds (%.0f%% health left)", seconds, health * 100)
  end
end

LF.RegisterCallback(LF.EVENTS.FIGHT_STARTED, function()
  warned, predicted = false, nil
  EVENT_MANAGER:RegisterForUpdate(TICK, 1000, Tick)
end)

LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(fight)
  EVENT_MANAGER:UnregisterForUpdate(TICK)
  if predicted then
    LF.Print("Fight took %.0fs; the last prediction was %.0fs", fight:GetDurationSec(), predicted)
  end
end)
```

### Settings panel

*PC + console*. A settings page with an auto-start switch and buttons to start, stop and print the last fight. It uses LibAddonMenu on PC and LibHarvensAddonSettings on console.

Uses: `LibAddonMenu` `LibHarvensAddonSettings` `Start_Logging` `Stop_Logging` `LF.IsConsole` `FightSummaryLines`

**`MyFightPanel/MyFightPanel.addon`**

```text
## Title: My Fight Panel
## Author: you
## Version: 1.0.0
## APIVersion: 101047 101048
## DependsOn: LibFights
## SavedVariables: MyFightPanelSV
## OptionalDependsOn: LibAddonMenu-2.0 LibHarvensAddonSettings
MyFightPanel.lua
```

**`MyFightPanel/MyFightPanel.lua`**

```lua
local NAME = "MyFightPanel"
local LF = LibFights
local DEFAULTS = { autoStart = true }
local sv

local function PrintLast()
  LF.PrintLines(LF.Report.FightSummaryLines(LF.GetLastFight()))
end

local function BuildLAM()
  local LAM = LibAddonMenu2
  LAM:RegisterAddonPanel("MyFightPanelPanel", { type = "panel", name = "My Fight Panel" })
  LAM:RegisterOptionControls("MyFightPanelPanel", {
    { type = "checkbox", name = "Start logging in combat",
      getFunc = function() return sv.autoStart end,
      setFunc = function(v) sv.autoStart = v end, default = DEFAULTS.autoStart },
    { type = "button", name = "Start logging", func = function() Start_Logging() end, width = "half" },
    { type = "button", name = "Stop logging", func = function() Stop_Logging() end, width = "half" },
    { type = "button", name = "Print last fight", func = PrintLast },
  })
end

local function BuildLHAS()
  local LHAS = LibHarvensAddonSettings
  local panel = LHAS:AddAddon("My Fight Panel", { allowDefaults = true })
  panel:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Start logging in combat", default = DEFAULTS.autoStart,
    getFunction = function() return sv.autoStart end,
    setFunction = function(v) sv.autoStart = v end })
  panel:AddSetting({ type = LHAS.ST_BUTTON, label = "Logging", buttonText = "Start",
    clickHandler = function() Start_Logging() end })
  panel:AddSetting({ type = LHAS.ST_BUTTON, label = "Logging", buttonText = "Stop",
    clickHandler = function() Stop_Logging() end })
  panel:AddSetting({ type = LHAS.ST_BUTTON, label = "Last fight", buttonText = "Print",
    clickHandler = PrintLast })
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
  if addonName ~= NAME then return end
  EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
  sv = ZO_SavedVars:NewAccountWide("MyFightPanelSV", 1, nil, DEFAULTS)

  if LF.IsConsole() and LibHarvensAddonSettings then BuildLHAS()
  elseif LibAddonMenu2 then BuildLAM()
  elseif LibHarvensAddonSettings then BuildLHAS() end

  EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
    if inCombat and sv.autoStart and not Is_Logging() then Start_Logging() end
  end)
end)
```

> Slash commands do not exist on console, so a settings page is how console players start and stop logging by hand.

### Search command

*PC (slash command)*. Type /lfs followed by anything: an ability or set name, an id, or filters. It prints the first ten matches.

Uses: `LF.Search` `SearchFormatResult` `in:set` `id:` `fight:`

**`MySearch.lua`**

```lua
local LF = LibFights

SLASH_COMMANDS["/lfs"] = function(text)
  if text == "" then
    LF.Print("Try: /lfs relequen   /lfs in:set kinras   /lfs id:46340   /lfs fight:3 crit")
    return
  end
  local results = LF.Search(text, { limit = 10 })
  if #results == 0 then
    LF.Print("Nothing found for %q", text)
    return
  end
  for _, r in ipairs(results) do
    d(LF.SearchFormatResult(r))
  end
end
```

### Big crit counter

*PC + console*. After a fight, counts your crits over 20,000 and names the biggest one, using the raw event query.

Uses: `NewQuery` `Direction` `Crit` `MinHit` `Count` `Max` `DecodedEvent`

**`MyBigCrits.lua`**

```lua
local LF = LibFights
local U = LF.Util

LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(fight)
  local query = LF.NewQuery(fight):Direction("out"):Crit(true):MinHit(20000)
  local count = query:Count()
  if count == 0 then return end

  local biggest = query:Max()
  LF.Print("%d crits over 20k. Biggest: %s from %s on %s",
    count, U.CommaNumber(biggest.hit), biggest.abilityName, biggest.target)
end)
```

> Queries read the raw event log, which is on by default (`rawEvents`). With it off, `Count()` is always 0.

[Back to contents](#contents)

## Logging

Namespace: `global`

Nothing is recorded until you call `Start_Logging()`. These are the only functions that turn recording on or off.

### `Start_Logging(options?)`

*Also LF.Start_Logging, LF.StartLogging*

Starts recording. Registers all combat events. If you are already in combat, a fight begins immediately.

- `options`: Optional table. Overrides your saved settings for this session only: `rawEvents`, `rawEventCap`, `groupMode`, `trackTargetEffects`, `trackPower`, `trackCasts`, `statSampleMs`, `combatEndGraceMs`, `fightTimeoutMs`, `minFightSeconds`, `modelsEnabled`, `saveFights`, `buildDetail`.

| Returns | When |
|---|---|
| `true` | Logging started. |
| ⚠ `false, "already logging"` | Logging was already running. |

### `Stop_Logging()`

*Also LF.Stop_Logging, LF.StopLogging*

Ends the current fight and unregisters every event.

| Returns | When |
|---|---|
| `true, fight` | Stopped. `fight` is the fight that just ended, or nil if there was none or it was too short to keep. |
| ⚠ `false, "not logging"` | Logging was not running. |

### `Is_Logging()`

*Also LF.Is_Logging, LF.IsLogging*

Tells you whether recording is on.

| Returns | When |
|---|---|
| `boolean` | true while logging. |

### `LF.SplitFight()`

*Also LF.Logger.SplitFight()*

Ends the current fight and starts a new one right away. Useful for boss phases.

| Returns | When |
|---|---|
| `true` | Split done. |
| ⚠ `false` | Not logging. |

### `LF.Logger.EndCurrentFight()`

Ends the running fight without stopping logging.

| Returns | When |
|---|---|
| `true` | A fight was ended and kept. |
| ⚠ `false` | No fight was running, or it was discarded (too short or empty). |

| Function | Returns | Notes |
|---|---|---|
| `LF.Logger.ClearFights()` | `nothing` | Forgets every fight held in memory this session. |
| `LF.Logger.GetRegisteredEvents()` | `array of strings` | Namespaces of the registered events. Empty when not logging. |

[Back to contents](#contents)

## Reading fights

Namespace: `LF.*`

Fights live in memory for the session and, if `saveFights` is on, in SavedVariables. Each one is a Fight object (see Fight methods).

### `LF.GetCurrentFight()`

*Also LF.Logger.GetCurrentFight()*

The fight that is running right now.

| Returns | When |
|---|---|
| `Fight` | A fight is running. |
| ⚠ `nil` | No fight is running. |

### `LF.GetLastFight()`

*Also LF.Logger.GetLastFight()*

The running fight, or if none, the newest finished one.

| Returns | When |
|---|---|
| `Fight` | Running or newest finished fight. |
| ⚠ `nil` | No fights yet. |

### `LF.Logger.GetLastFinishedFight()`

The newest finished fight in memory.

| Returns | When |
|---|---|
| `Fight` | Found. |
| ⚠ `nil` | None finished yet. |

### `LF.GetFights()`

*Also LF.Logger.GetFights()*

Every finished fight this session.

| Returns | When |
|---|---|
| `array of Fight` | Oldest first. Capped by the `maxFightsInMemory` setting. |

### `LF.GetFight(id)`

Finds one fight by its number. Looks in memory, then the running fight, then SavedVariables.

- `id`: number

| Returns | When |
|---|---|
| `Fight` | Found. |
| ⚠ `nil` | No fight with that id. |

### `LF.GetSavedFights()`

*Also LF.Storage.GetSavedFights()*

Fights restored from SavedVariables.

| Returns | When |
|---|---|
| `array of Fight` | Can be empty. |

### `LF.QueryFights(filter?)`

Finds fights by zone, title, DPS and more. See Search and queries.

| Returns | When |
|---|---|
| `array of Fight` | Matches, memory first then saved. |

[Back to contents](#contents)

## Callbacks

Namespace: `LF.*`

Get told when something happens instead of polling. Callbacks only fire while logging, and only when at least one listener is registered.

### `LF.RegisterCallback(eventName, callback, arg?)`

Adds a listener. Use the names in `LF.EVENTS`.

| Returns | When |
|---|---|
| `true` | Registered. |
| ⚠ `false` | eventName is not a string or callback is not a function. |

| Function | Returns | Notes |
|---|---|---|
| `LF.UnregisterCallback(eventName, callback)` | `nothing` | Removes a listener. |
| `LF.HasListeners(eventName)` | `boolean` | true if anything is listening. |
| `LF.FireCallback(eventName, ...)` | `nothing` | Fires an event. Does nothing when no one listens. |

#### Events

| Event (LF.EVENTS.*) | Your callback receives | Notes |
|---|---|---|
| INITIALIZED | () | The library finished loading. |
| LOGGING_STARTED | (options) | The options table passed to Start_Logging (may be empty). |
| LOGGING_STOPPED | () |  |
| FIGHT_STARTED | (fight) |  |
| FIGHT_ENDED | (fight, reason) | reason: "combatEnd", "timeout", "stopped", "split", "zone", "manual". Not fired for discarded fights. |
| COMBAT_EVENT | (fight, direction, category, result, abilityId, hitValue, overflow, sourceUnitId, targetUnitId, damageType) | direction: 1 out, 2 in, 3 self (LF.Fight.DIR). category: see Constants. |
| EFFECT_CHANGED | (fight, scope, changeType, abilityId, effectName, unitId, stackCount) | scope: "player" or "target". |
| PROC | (fight, procEntry) | See ProcEntry. |
| DEATH | (fight, deathEntry) | See DeathEntry. |
| CAST | (fight, slotIndex, abilityId, kind) | kind: "light", "heavy", "skill", "ultimate", "other". |
| BAR_SWAP | (fight, activeWeaponPair) | 1 = front bar, 2 = back bar. |
| STATS_SAMPLE | (fight, statSnapshot) | See StatSnapshot. |
| GEAR_CHANGED | (fight or nil, slotIndex) |  |
| SCAN_PROGRESS | (scanProgress) | See ScanProgress. |
| SCAN_DONE | (scanProgress) |  |

[Back to contents](#contents)

## Fight methods

Namespace: `f:Method()`

Call these on a Fight object, for example `local f = LibFights.GetLastFight()`. Rates divide by the fight duration. Pass `useActive = true` to divide by the time from your first to your last hit instead.

#### Duration

| Function | Returns | Notes |
|---|---|---|
| `f:GetDurationMs()` | `number` | Length in ms (at least 1). A live fight counts up to now. |
| `f:GetDurationSec()` | `number` | Length in seconds (at least 1). |
| `f:GetActiveSec()` | `number` | Seconds from your first to your last hit or heal. |
| `f:IsActive()` | `boolean` | true while the fight is running. |
| `f:GetTitle()` | `string` | Boss name, else the most-damaged target, else the zone, else "Fight <id>". |

#### Damage and healing

| Function | Returns | Notes |
|---|---|---|
| `f:GetDPS(useActive?)` | `number` | Damage done per second. |
| `f:GetDPM(useActive?)` | `number` | Damage done per minute. |
| `f:GetBossDPS(useActive?)` | `number` | Damage to bosses per second. |
| `f:GetHPS(useActive?)` | `number` | Effective healing per second (overheal excluded). |
| `f:GetHPM(useActive?)` | `number` | Effective healing per minute. |
| `f:GetRawHPS(useActive?)` | `number` | Healing including overheal, per second. |
| `f:GetDTPS()` | `number` | Damage taken per second. |
| `f:GetDTPM()` | `number` | Damage taken per minute. |
| `f:GetHTPS()` | `number` | Healing received per second. |
| `f:GetHTPM()` | `number` | Healing received per minute. |

#### Mitigation

| Function | Returns | Notes |
|---|---|---|
| `f:GetMPS()` | `number` | Damage mitigated per second. |
| `f:GetMPM()` | `number` | Damage mitigated per minute. |
| `f:GetTotalMitigated()` | `number` | Shield (exact) + block, armor and avoidance (estimates). |

#### Shields

| Function | Returns | Notes |
|---|---|---|
| `f:GetTotalShield()` | `number` | Damage absorbed by shields on you. Exact. |
| `f:GetSPS()` | `number` | Shield absorbed per second. |
| `f:GetSPM()` | `number` | Shield absorbed per minute. |
| `f:GetTotalShieldGained()` | `number` | Shield applied to you, from the game's shield bar. Includes shield that ran out unused. 0 if the client has no shield-bar events. |
| `f:GetShieldGainedPS()` | `number` | Shield applied per second. |
| `f:GetShieldGainedPM()` | `number` | Shield applied per minute. |
| `f:GetGroupShieldTotal()` | `number` | Group mode only: damage absorbed by shields on other group members. 0 in player mode. |
| `f:GetGroupSPS()` | `number` | Group shield absorbed per second. |
| `f:GetGroupSPM()` | `number` | Group shield absorbed per minute. |

The game reports a shield hit with the attacker as the source, so shields you cast on other players can't be credited to you. Group shields are counted per protected member (`f.group[unitId].shieldAbsorbed`), not per caster.

#### Summaries and breakdowns

### `f:GetSummary()`

Every metric in one table. The easiest way to read a fight.

| Returns | When |
|---|---|
| `FightSummary` | See FightSummary in Data structures. |

### `f:GetMaxHit(kind?)`

The biggest single hit.

- `kind`: Default "damageOut". Same kinds as GetAbilityBreakdown.

| Returns | When |
|---|---|
| `maxValue, aggregate` | aggregate is the ability's raw aggregate, or nil if there are no hits. |

### `f:GetAbilityBreakdown(kind?, sortBy?, limit?)`

Per-ability totals, like a damage meter.

- `kind`: "damageOut" (default), "healOut", "damageIn", "healIn", "shieldIn", "shieldOut"
- `sortBy`: Any AbilityRow field. Default "total".
- `limit`: Max rows.

| Returns | When |
|---|---|
| `array of AbilityRow` | Sorted descending. |

### `f:GetTargets(limit?)`

Enemies you damaged.

| Returns | When |
|---|---|
| `array of TargetRow` | Most damage first. |

### `f:GetSources(limit?)`

Enemies that damaged you.

| Returns | When |
|---|---|
| `array of SourceRow` | Most damage first. |

### `f:GetDamageTypes(incoming?)`

Damage split by type (fire, magic, ...).

- `incoming`: true for damage taken, otherwise damage done.

| Returns | When |
|---|---|
| `array of { damageType, name, total, pct }` | Largest first. pct is 0..1. |

### `f:GetTimeline(field?)`

A per-second graph of the fight.

- `field`: "dOut" damage done (default), "hOut" healing done, "dIn" damage taken, "hIn" healing taken, "mit" mitigated, "oh" overheal, "sIn" shield absorbed on you, "sGain" shield applied to you

| Returns | When |
|---|---|
| `array of numbers` | One value per second. Index 1 is the first second. Gaps are 0. |

### `f:GetRollingRate(field?, windowSec?)`

Rolling average per second, for a smoother graph.

- `windowSec`: Default 5.

| Returns | When |
|---|---|
| `array of numbers` | Same length as GetTimeline. |

### `f:GetEffectUptimes(scope?, onlyMine?)`

Buff and debuff uptimes.

- `scope`: "player" (default, buffs on you) or "target" (debuffs on enemies)
- `onlyMine`: true for only effects you cast.

| Returns | When |
|---|---|
| `array of EffectRow` | Highest uptime first. For targets, the unit with the best uptime is used. |

### `f:GetProcs()`

Procs seen this fight (set procs and other non-slotted abilities).

| Returns | When |
|---|---|
| `array of ProcEntry` | Most activations first. |

### `f:GetSets()`

Sets worn or proccing this fight.

| Returns | When |
|---|---|
| `array of FightSet` | Most damage first. |

### `f:GetCasts()`

What you cast and how often.

| Returns | When |
|---|---|
| `casts, rows` | casts is the Casts table. rows is an array of { id, name, icon, kind, count, firstMs, lastMs }, most casts first. |

### `f:GetPower(powerType?)`

Magicka, stamina, health and ultimate over the fight.

| Returns | When |
|---|---|
| `PowerEntry` | With a powerType. |
| ⚠ `nil` | With a powerType that has no data. |
| `map powerType → PowerEntry` | Without a powerType. |

| Function | Returns | Notes |
|---|---|---|
| `f:GetDeaths()` | `array of DeathEntry` | Every death, with a damage recap for yours. |
| `f:GetBuild()` | `Build or nil` | Your build when the fight began. |
| `f:GetStats()` | `FightStats or nil` | Stat averages, minimums and maximums over the fight. |
| `f:GetGroup()` | `array of GroupRow` | Group mode only. |

#### Raw events

### `f:GetEvents()`

Every raw combat event, if raw logging is on.

| Returns | When |
|---|---|
| `array of raw events` | Oldest first. Each event is an array; the indexes are listed below. |
| ⚠ `{}` | Raw logging was off. |

| Function | Returns | Notes |
|---|---|---|
| `f:GetEventCount()` | `number` | Number of raw events. |

### `f:DecodeEvent(rawEvent)`

Turns a raw event into a readable table.

| Returns | When |
|---|---|
| `DecodedEvent` | See Data structures. |

#### Raw event layout

| Index (LF.EVENT_FIELDS) | Meaning |
|---|---|
| [1] TIME | Game time in ms |
| [2] DIR | 1 out, 2 in, 3 self, 4 group |
| [3] RESULT | ACTION_RESULT value |
| [4] ABILITY | Ability id |
| [5] HIT | Hit value |
| [6] OVERFLOW | Overkill or overheal |
| [7] SOURCE | Source unitId |
| [8] TARGET | Target unitId |
| [9] DAMAGE_TYPE |  |
| [10] POWER_TYPE |  |
| [11] SLOT_TYPE |  |

#### Units and saving

| Function | Returns | Notes |
|---|---|---|
| `f:GetUnitName(unitId)` | `string` | "" if unknown. |
| `f:MarkBoss(name)` | `nothing` | Treats that unit as a boss. |

### `f:ToData(includeEvents?)`

A plain copy that can go into SavedVariables (no functions or metatables).

| Returns | When |
|---|---|
| `plain table` | Raw events are only included when includeEvents is true. |

### `LF.Fight.FromData(data)`

Turns saved data back into a Fight.

| Returns | When |
|---|---|
| `Fight` | Methods restored. |
| ⚠ `nil` | data was not a table. |

| Function | Returns | Notes |
|---|---|---|
| `LF.Fight.New(id)` | `Fight` | An empty fight. The logger normally does this. |

#### Raw fields you can read directly

`f.id` `f.startMs` `f.endMs` `f.startTimestamp` `f.character` `f.account` `f.zoneName` `f.zoneId` `f.mapName` `f.endReason` `f.totals` `f.abilities[kind][abilityId]` `f.targets` `f.sources` `f.healTargets` `f.healers` `f.units` `f.damageTypesOut` `f.damageTypesIn` `f.results.out` `f.results.inc` `f.timeline` `f.effects.player` `f.effects.target` `f.procs` `f.sets` `f.casts` `f.bars` `f.power` `f.deaths` `f.cc` `f.bosses` `f.bossHealth` `f.group` `f.gearChanges` `f.build` `f.stats` `f.models` `f.summary` `f.meta`

[Back to contents](#contents)

## Search and queries

Namespace: `LF.*`

One search box for everything: abilities, sets, fights, effects, procs, targets, stats, casts and raw events.

### `LF.Search(query, opts?)`

Searches everything at once.

- `query`: Free text plus optional filters: `in:ability` `in:set` `in:fight` `in:effect` `in:proc` `in:target` `in:stat` `in:cast` `in:event` (several allowed; events need `in:event`), `id:12345` for an exact id, `fight:7` to search inside fight 7.
- `opts.limit`: Default 50.
- `opts.fight`: Fight to search inside. Default: current or last fight.

| Returns | When |
|---|---|
| `array of SearchResult` | { kind, id, name, icon, detail, data }. kind is "ability", "set", "stat", "fight", "target", "fightAbility", "effect", "proc", "cast" or "event". data is the underlying table. |

| Function | Returns | Notes |
|---|---|---|
| `LF.SearchFormatResult(result)` | `string` | "[kind] icon name (id) detail". Also LF.Search_.FormatResult. |
| `LF.Search_.Parse(query)` | `table` | { terms, filters, kinds, text, ltext }: how a query string is understood. |

### `LF.FindEvents(fight?, filter?)`

Filters raw events.

- `fight`: Default: last fight.
- `filter`: All optional: `direction` ("out" "in" "self" "group"), `category`, `result`, `abilityId`, `abilityName`, `source`, `target` (substrings), `sourceUnitId`, `targetUnitId`, `damageType`, `crit` (true/false), `minHit`, `maxHit`, `fromMs`, `toMs` (from fight start), `limit` (default 200), `newestFirst`.

| Returns | When |
|---|---|
| `array of DecodedEvent` | Matches. |
| ⚠ `{}` | No fight, or raw logging was off. |

### `LF.NewQuery(fight?)`

A chainable query over raw events. Every setter returns the same query, so you can chain them.

- `Setters`: `:Direction(d)` `:Category(c)` `:Result(r)` `:Ability(id)` `:AbilityName(s)` `:Source(s)` `:Target(s)` `:DamageType(dt)` `:Crit(bool)` `:MinHit(n)` `:MaxHit(n)` `:From(ms)` `:To(ms)` `:Limit(n)` `:NewestFirst()`
- `:Run()`: array of DecodedEvent
- `:Count()`: number
- `:Sum()`: number, sum of hit values
- `:Max()`: DecodedEvent with the biggest hit, or nil

| Returns | When |
|---|---|
| `Query` | Chain setters, then finish with :Run(), :Count(), :Sum() or :Max(). |

### `LF.QueryFights(filter?)`

Finds fights in memory and SavedVariables.

- `filter`: `zone`, `title`, `target`, `character` (substrings), `minDurationSec`, `minDPS`, `minSPS`, `sinceTimestamp`

| Returns | When |
|---|---|
| `array of Fight` | Memory first, then saved. |

[Back to contents](#contents)

## Abilities and IDs

Namespace: `LF.Abilities.*`

Look up any ability's name, icon, cost, range and more, at any time. Logging is not needed.

| Function | Returns | Notes |
|---|---|---|
| `Exists(abilityId)` | `boolean` | Whether the ability id exists. |

### `GetInfo(abilityId, forceRefresh?)`

Everything about an ability. Cached after the first call.

- `abilityId`: number or numeric string

| Returns | When |
|---|---|
| `AbilityInfo` | See Data structures. |
| ⚠ `nil` | Invalid id or the ability does not exist. |

| Function | Returns | Notes |
|---|---|---|
| `GetName(abilityId)` | `string` | "" if unknown. |
| `GetIcon(abilityId)` | `string` | Texture path, "" if unknown. |
| `GetIconMarkup(abilityId, size?)` | `string` | "\|t24:24:path\|t" for chat, or "". size default 24. |

### `Search(text, maxResults?)`

Finds abilities by name or id.

- `maxResults`: Default 50.

| Returns | When |
|---|---|
| `array of AbilityInfo` | Numeric text gives 0 or 1 entries and works for any id. Names: exact match first, then shortest. Name search only finds abilities already indexed (seen in fights, looked up, IndexPlayerSkills or StartScan). |

| Function | Returns | Notes |
|---|---|---|
| `Index(abilityId, name)` | `nothing` | Adds one ability to the search index. |
| `GetIndexCount()` | `number` | Abilities in the search index. |
| `GetKnownAbilityIds()` | `array of numbers` | Every indexed id, ascending. |
| `GetCachedCount()` | `number` | Abilities with cached info. |
| `ClearCache()` | `nothing` |  |

### `StartScan(opts?)`

Indexes a range of ability ids over many frames, so name search can find them.

- `opts`: `fromId` (1), `toId` (260000), `perFrame` (1500 PC / 600 console), `reportEvery` (10000), `onProgress(progress)`, `onDone(progress)`

| Returns | When |
|---|---|
| `true` | Started. |
| ⚠ `false, "scan already running"` | A scan is already going. |

### `StopScan()`

Stops a running scan.

| Returns | When |
|---|---|
| `true` | A scan was stopped. |
| ⚠ `false` | Nothing was running. |

| Function | Returns | Notes |
|---|---|---|
| `IsScanRunning()` | `boolean` |  |
| `GetScanProgress()` | `ScanProgress` | See Data structures. |

### `GetPlayerSkillAbilities(includeUnpurchased?)`

Every skill on the character's skill lines.

| Returns | When |
|---|---|
| `array of SkillEntry` | Purchased skills only, unless includeUnpurchased is true. |

| Function | Returns | Notes |
|---|---|---|
| `IndexPlayerSkills()` | `number` | How many skills were added to the index (purchased and unpurchased). |

[Back to contents](#contents)

## Sets

Namespace: `LF.Sets.*`

Every item set in the game can be looked up and logged.

| Function | Returns | Notes |
|---|---|---|
| `GetAllSetIds(forceRefresh?)` | `array of numbers` | Every set id, ascending. Uses the collections API plus LibSets if installed. Cached. |
| `GetSetName(setId)` | `string` | "" if unknown. |

### `GetSampleLink(setId)`

An item link for one piece of the set.

| Returns | When |
|---|---|
| `string` | Item link. |
| ⚠ `nil` | No piece found. |

### `GetSetInfo(setId, forceRefresh?)`

Everything about a set, including its bonuses.

| Returns | When |
|---|---|
| `SetInfo` | See Data structures. |
| ⚠ `nil` | Unknown set. |

### `FindSetByName(name)`

Loose name match. Ignores case, punctuation and a leading "Perfected".

| Returns | When |
|---|---|
| `setId` | Found. |
| ⚠ `nil` | No match. |

### `Search(text, maxResults?)`

Finds sets by name fragment or id.

- `maxResults`: Default 50.

| Returns | When |
|---|---|
| `array of SetInfo` | In rare cases an entry is just { setId, name }. |

| Function | Returns | Notes |
|---|---|---|
| `GetEquippedSets()` | `map setId → EquippedSet` | What you are wearing right now. |
| `IsSetLogged(setId)` | `boolean` | Always true while logAllSets is on. |
| `SetSetLogged(setId, enabled)` | `nothing` | Pick sets to log by hand. |
| `SetLogAllSets(enabled)` | `nothing` |  |
| `GetLoggedSetIds()` | `array of numbers` | All set ids while logAllSets is on, otherwise your list. |
| `RegisterSetAbility(setId, abilityId)` | `nothing` | Links a proc ability id to a set. Saved in SavedVariables. |
| `UnregisterSetAbility(abilityId)` | `nothing` |  |
| `GetRegisteredAbilities(setId)` | `array of abilityIds` | Ascending. |

### `GetSetForAbility(abilityId, abilityName?, fight?)`

Which set an ability belongs to. Checks the registry, then the sets worn in the fight, then every set name.

| Returns | When |
|---|---|
| `setId` | Found. |
| ⚠ `nil` | Not linked to a set. |

[Back to contents](#contents)

## Stats

Namespace: `LF.Stats.*`

Your combat stats right now, and the game's armor formula. 660 resistance is 1% mitigation, capped at 50% (33,000 resistance).

| Function | Returns | Notes |
|---|---|---|
| `GetSnapshot()` | `StatSnapshot` | Every stat right now. Also stored in LF.Stats.current. |

### `GetStat(key)`

One stat, by key.

- `key`: For example "spellPower" or "maxStamina".

| Returns | When |
|---|---|
| `number` | The value. |
| ⚠ `nil` | Unknown key or not available on this client. |

| Function | Returns | Notes |
|---|---|---|
| `GetStatLabel(key)` | `string` | Display name, or the key itself. |
| `GetPenetrationFor(damageType, snapshot?)` | `number` | Spell pen for spell damage, physical pen for physical, the higher of the two otherwise. |
| `GetArmorMitigation(damageType, snapshot?)` | `number 0..0.5` | Your armor mitigation against that type. 0 for oblivion/generic or before the first snapshot. |
| `ArmorMitigationFromResist(resist, penetration?)` | `number 0..0.5` | (resist − pen) / 66000, clamped. |
| `CritPctFromRating(rating)` | `number 0..100` | Crit chance in percent. |

### `GetValuesAt(fight, ms)`

Your stats at a moment in the fight.

- `ms`: Milliseconds from fight start.

| Returns | When |
|---|---|
| `table key → value` | Every stat at that moment. |
| ⚠ `nil` | The fight has no stat data. |

[Back to contents](#contents)

## Build reader

Namespace: `LF.Build.*`

Reads your character, gear, bars, champion points, buffs and mundus.

### `Read(detail?)`

Your whole build in one table.

- `detail`: "basic" (default) or "full"

| Returns | When |
|---|---|
| `Build` | See Data structures. "full" also fills build.skills. |

| Function | Returns | Notes |
|---|---|---|
| `ReadCharacter()` | `Character` | Name, level, CP, class, race, alliance and more. |
| `ReadAttributes()` | `{ health, magicka, stamina, unspent }` | Attribute points. |

### `ReadItem(bagId, slotIndex)`

One item.

| Returns | When |
|---|---|
| `Item` | See Data structures. |
| ⚠ `nil` | Empty slot. |

### `ReadGear()`

Everything you are wearing.

| Returns | When |
|---|---|
| `gear, armorCounts` | gear: map equipSlot → Item. armorCounts: { light, medium, heavy } piece counts. |

| Function | Returns | Notes |
|---|---|---|
| `ReadBar(hotbarCategory)` | `map slot (3..8) → BarSlot` | Empty slots are absent. Scribed skills are resolved. |
| `ReadBars()` | `{ front, back }` | Both bars, each like ReadBar. |
| `ReadChampion()` | `{ slotted, totalEarned }` | slotted: array of { slot, championSkillId, name, points }. |
| `ReadBuffs(unitTag?)` | `array of Buff` | unitTag default "player". |
| `ReadMundus(buffs?)` | `array of { name, abilityId, icon }` | Your mundus stone(s). |
| `ReadLongBuffs(buffs?)` | `array of Buff` | Buffs with 10+ minutes left that are not mundus (food, drink, ...). |
| `GetSignature(build)` | `string` | Changes whenever gear, bars, CP or mundus change. |

### `GetSlottedLookup(build)`

Quick lookups of what is slotted.

| Returns | When |
|---|---|
| `ids, names` | ids: set abilityId → true. names: set lower-case name → true. |

### `Compare(oldBuild, newBuild)`

What changed between two builds.

| Returns | When |
|---|---|
| `{ stats, gear, bars, sets, champion }` | stats: key → { old, new, delta } (changed only). gear: slotName → { old, new }. bars: array of { bar, slot, old, new }. sets: setName → { old, new }. champion: reserved. All empty if either build is nil. |

[Back to contents](#contents)

## Models

Namespace: `LF.Models.*`

The models learn while you log. Target dummies (18,200 resistance) calibrate the resistance model; until then only relative toughness is known.

| Function | Returns | Notes |
|---|---|---|
| `GetReport()` | `ModelReport` | Everything the models know, in one table. |

### `GetTargetEstimate(targetName)`

Predicted resistance and damage reduction of a target.

| Returns | When |
|---|---|
| `TargetEstimate` | See Data structures. |
| ⚠ `nil` | Nothing learned about that target yet. |

| Function | Returns | Notes |
|---|---|---|
| `GetAllTargetEstimates()` | `array of TargetEstimate` | Most samples first. |

### `GetIncomingDR()`

Your own damage reduction against enemy hits.

| Returns | When |
|---|---|
| `{ armorMitigationPct, otherDRPct, totalDRPct, samples, otherStdPct }` | All percentages are 0..100. other = block, buffs and other DR. total = 1 − (1 − armor)(1 − other). |

### `GetCritEstimate(abilityId?)`

Your crit chance and crit damage, from your hits.

- `abilityId`: nil for all abilities.

| Returns | When |
|---|---|
| `{ critChance, critChanceStd, samples, critDamageMultiplier, critDamagePct, critDamageWeight }` | critChance is 0..1. Crit damage (e.g. 1.75 / 75) needs at least 3 crits and 3 non-crits on the same target; until then those fields are nil. If the ability has no data, crit chance falls back to the overall estimate. |

### `PredictHit(abilityId, targetName?)`

What the next hit of an ability should be.

| Returns | When |
|---|---|
| `{ nonCrit, crit, average, critChance, critMultiplier, rmse }` | rmse is the model error, in the same units as the hit. |
| ⚠ `nil` | Too little data for that ability. |

### `PredictIncomingHit(abilityId, damageType)`

How hard an enemy ability hits you with your current resistances.

| Returns | When |
|---|---|
| `meanHit, peakHit` | Expected and worst hit. |
| ⚠ `nil` | Ability never seen. |

### `GetTTK(unitTag?)`

Time to kill.

- `unitTag`: Default "boss1".

| Returns | When |
|---|---|
| `secondsRemaining, healthFraction` | Health is falling and there are enough samples. |
| ⚠ `nil, healthFraction` | Health is not falling, or fewer than 3 samples. |
| ⚠ `nil` | No data for that unit. |

| Function | Returns | Notes |
|---|---|---|
| `GetAllTTK()` | `array of { unitTag, name, secondsRemaining, healthFraction }` | secondsRemaining can be nil. |

### `GetDPSForecast(secondsAhead?)`

Forecast DPS.

- `secondsAhead`: Default 1.

| Returns | When |
|---|---|
| `number` | Forecast. |
| ⚠ `nil` | No data yet. |

### `PredictFightOutcome(fight?)`

How the fight will end if it continues like this.

| Returns | When |
|---|---|
| `{ currentDPS, elapsedSec, ttkSec, predictedDurationSec, predictedTotalDamage, predictedFinalDPS }` | The predicted fields and ttkSec are nil until TTK is known. |
| ⚠ `nil` | No fight. |

| Function | Returns | Notes |
|---|---|---|
| `IsReferenceTarget(targetName, targetType)` | `boolean` | Whether the target calibrates the resistance model. |
| `Reset()` | `nothing` | Forgets everything learned. |
| `Save() / Load()` | `nothing` | Only when persistModels is on. |
| `GetState()` | `table` | Internal state, for advanced use. |

#### Building blocks (usable on their own)

| Function | Returns | Notes |
|---|---|---|
| `Models.NewRLS(nFeatures, lambda?, delta?)` | `RLS` | Online linear regression. :Predict(x) → number, :Update(x, y) → error before the update, :GetRMSE() → number. |
| `Models.NewKalman(q, r)` | `Kalman` | :Update(z) → new estimate, :Std() → number or nil before the first update. |
| `Models.NewWelford()` | `Welford` | Running mean/variance. :Add(x), :Variance() (0 under 2 values), :Std(). |
| `Models.NewBeta(a?, b?)` | `Beta` | Defaults 1, 1. :Observe(success), :Mean() → 0..1, :Std(), :Count(). |
| `Models.NewTrend(halfLifeSec?)` | `Trend` | Default 30. :Add(time, value), :Fit() → slope, intercept (nil under 3 samples). |
| `Models.NewHolt(alpha?, beta?)` | `Holt` | Defaults 0.3, 0.1. :Update(y), :Forecast(steps?) → number or nil. |

[Back to contents](#contents)

## Saved data and settings

Namespace: `LF.Storage.*`

Settings and saved fights live in the account-wide SavedVariables `LibFightsSV`.

### `LF.GetSettings()`

The live settings table. Change fields directly.

| Returns | When |
|---|---|
| `settings table` | Defaults before the add-on has loaded. Keys and defaults: LF.Storage.DEFAULT_SETTINGS. |

### `SaveFight(fight)`

Saves a fight. The oldest are trimmed past maxSavedFights.

| Returns | When |
|---|---|
| `true` | Saved. |
| ⚠ `false` | SavedVariables not loaded yet. |

| Function | Returns | Notes |
|---|---|---|
| `GetSavedFights()` | `array of Fight` |  |
| `GetSavedFight(id)` | `Fight or nil` |  |
| `DeleteSavedFight(id)` | `boolean` | true if one was removed. |
| `ClearSavedFights()` | `nothing` |  |
| `GetSavedFightCount()` | `number` |  |
| `ResetSettings()` | `nothing` | Restores the defaults. |
| `Init()` | `nothing` | Called when the add-on loads. |

Also available as `LF.GetSavedFights`, `LF.DeleteSavedFight`, `LF.ClearSavedFights`. `LF.sv` is the whole SavedVariables table (settings, fights, nextFightId, setAbilityRegistry, models). `LF.settings` is `LF.sv.settings`, nil until the add-on has loaded.

[Back to contents](#contents)

## Text reports

Namespace: `LF.Report.*`

Every "…Lines" function returns an array of strings ready for chat, with colors and icons. Print them with `LF.PrintLines(lines)`. When the fight is nil you get a one-line message such as "No fight.".

| Function | Returns | Notes |
|---|---|---|
| `FightSummaryLines(fight)` | `lines` | All main metrics, including the shield line. |
| `AbilityLines(fight, kind?, limit?)` | `lines` | kind default "damageOut", limit default 10. |
| `TargetLines(fight, limit?)` | `lines` | limit default 8. |
| `EffectLines(fight, scope?, limit?)` | `lines` | scope default "player", limit default 15. |
| `ProcLines(fight, limit?)` | `lines` | limit default 15. |
| `SetLines(fight)` | `lines` |  |
| `StatLines(fight?)` | `lines` | Fight stats (avg/min/max), or the current snapshot when fight is nil. |
| `PowerLines(fight)` | `lines` |  |
| `DeathLines(fight)` | `lines` | Includes the last 5 hits before each death. |
| `BuildLines(build?)` | `lines` | Reads the build if nil. |
| `ModelLines(report?)` | `lines` | Uses GetReport() if nil. |
| `AbilityInfoLines(abilityId)` | `lines` |  |
| `SetInfoLines(setId)` | `lines` |  |
| `AllFightLines(fight)` | `lines` | Every report above, combined. |
| `ShortLiveText(fight)` | `string` | 4-line text for a small meter. Last line: SPS, crit, APM. "No fight." if nil. |

### `Export(fight)`

One line you can paste elsewhere.

| Returns | When |
|---|---|
| `string` | LF1\|id\|title\|durationSec\|damage\|dps\|healing\|hps\|taken\|mitigated\|critRate\|abilityId:damage;…\|shield\|sps |
| ⚠ `""` | fight is nil. |

> The ability list holds the top 10 damage abilities. shield and sps are fields 13 and 14, after the ability list, so readers of the first 12 fields keep working.

[Back to contents](#contents)

## HUD and settings panel

Namespace: `LF.HUD.*`

A fight rundown window: status and timer, DPS/HPS/DTPS/crit tiles, an actions line, boss health with time to kill, top abilities and a fight log. Showing it never starts logging.

| Function | Returns | Notes |
|---|---|---|
| `LF.HUD.Create()` | `window control` | Created once, then reused. |
| `LF.HUD.Show() / Hide()` | `nothing` |  |
| `LF.HUD.IsShown()` | `boolean` |  |
| `LF.HUD.SetShown(bool)` | `nothing` | Also saves the setting. |
| `LF.HUD.SetLocked(bool)` | `nothing` |  |
| `LF.HUD.ResetPosition()` | `nothing` |  |
| `LF.HUD.Update()` | `nothing` | Also LF.HUD.Refresh(). |
| `LF.HUD.Init()` | `nothing` |  |
| `LF.HUD.Log(kind, fmt, ...)` | `nothing` | Adds a fight-log line. kind sets the color: "info" "good" "warn" "bad" "proc" "hit". Other add-ons may use it. |
| `LF.HUD.GetLog(n?)` | `array of { clock, color, text }` | Newest last. |
| `LF.HUD.ClearLog()` | `nothing` |  |
| `LF.SettingsUI.Init()` | `nothing` | Builds the LibAddonMenu (PC) or LibHarvensAddonSettings (console) panel. |
| `LF.SettingsUI.Refresh()` | `nothing` | Redraws the panel's text fields. |
| `LF.SettingsUI.SetOutput(key, textOrLines, printToChat?)` | `nothing` | key: "live" "build" "models" "search" "ability" "scan" "set". |
| `LF.Slash.Init()` | `nothing` | Registers /libfights and /lfights. |

[Back to contents](#contents)

## Core and Util

Namespace: `LF.* · LF.Util.*`

Small helpers the library uses everywhere. They are safe to use in your own add-on.

#### Core (LF.*)

| Function | Returns | Notes |
|---|---|---|
| `LF.IsConsole()` | `boolean` | true on PS5 / Xbox. |
| `LF.IsGamepad()` | `boolean` | Console, or gamepad mode on PC. |
| `LF.Print(fmt, ...)` | `nothing` | Chat line with the [LibFights] prefix. |
| `LF.PrintLines(lines, header?)` | `nothing` |  |
| `LF.Debug(fmt, ...)` | `nothing` | Only prints when settings.debug is on. |

Fields: `LF.name` `LF.version` ("1.0.0") `LF.versionNum` (10000) `LF.isConsole` `LF.initialized` `LF.EVENTS` `LF.EVENT_FIELDS` `LF.fights`

#### Util (LF.Util.*)

| Function | Returns | Notes |
|---|---|---|
| `Now()` | `number` | Game time in ms. |
| `Timestamp()` | `number` | Unix time in seconds. |
| `Round(v, decimals?)` | `number` | 0 when v is nil. |
| `Clamp(v, lo, hi)` | `number` |  |
| `SafeDiv(a, b)` | `number` | 0 when b is 0 or nil. |
| `Try(fn, ...)` | `fn's returns` | Nothing if fn errors or is not a function. |
| `SafeCall(globalName, ...)` | `fn's returns` | Like Try, for the global function with that name. |
| `Global(name)` | `_G[name]` |  |
| `Lower(s) / Trim(s)` | `string` | "" for nil. |
| `Contains(haystack, needle)` | `boolean` | Case-insensitive, plain substring. |
| `Fmt(s)` | `string` | zo_strformat("<<1>>", s). |
| `CleanName(name) / CleanAbilityName(name)` | `string` | Without the game's grammar suffixes (^Mx and so on). |
| `NormalizeName(name)` | `string` | Lower case, no punctuation or leading "perfected". |
| `FormatNumber(n)` | `string` | "950", "12.3k", "1.25M", "2.00B". |
| `CommaNumber(n)` | `string` | "1,234,567". |
| `FormatPct(fraction, dec?)` | `string` | 0.523 → "52.3%". |
| `FormatDuration(ms)` | `string` | "m:ss.s", e.g. "1:05.3". |
| `IconMarkup(path, size?)` | `string` | "\|tN:N:path\|t", or "" with no path. |
| `Count(t)` | `number` | Number of keys. |
| `ShallowCopy(t)` | `table` |  |
| `ToPlain(v)` | `table` | Deep copy without functions, metatables or keys starting with "_". |
| `SortedValues(map, field, descending?, limit?)` | `array` | The map's values, sorted by a field. |
| `SortedKeys(map)` | `array` |  |
| `NewRing(capacity)` | `Ring` | Ring buffer. :Push(v), :Get(i) (1 = oldest), :Newest(), :Count(), :ToArray(), :Last(n), :Clear(). |
| `RestoreRing(data)` | `Ring or nil` | From saved data or a plain array. |
| `Throttle(key, ms, fn)` | `boolean` | true if fn ran, false if throttled. |

[Back to contents](#contents)

## Constants

Namespace: `LF.Const.*`

Game constants gathered in one place, with safe fallbacks when a client lacks one.

| Function | Returns | Notes |
|---|---|---|
| `GetResultCategory(result)` | `string` | "damage" "heal" "shield" "avoid" "cc" "death" "power" "cast" "effect" "other". |
| `GetResultName(result)` | `string` | e.g. "CRITICAL_DAMAGE", or the number as text if unknown. |
| `GetDamageTypeName(dt)` | `string` | Localized name, else e.g. "FIRE", else the number. "?" for nil. |
| `GetPowerName(powerType)` | `string` | "Health" "Magicka" "Stamina" "Ultimate", or the number. |
| `IsPlayerOrPet(unitType)` | `boolean` |  |

| Table | What it holds |
|---|---|
| RESULT / RESULT_NAME | ACTION_RESULT name → value and back |
| CATEGORY | result value → category string |
| DAMAGE_RESULTS, HEAL_RESULTS, CRIT_RESULTS, TICK_RESULTS, SHIELD_RESULTS, AVOID_RESULTS, CC_RESULTS, DEATH_RESULTS, POWER_RESULTS, CAST_RESULTS, EFFECT_RESULTS | sets: value → true |
| DAMAGE_TYPE / DAMAGE_TYPE_NAME | damage types; SPELL_DAMAGE_TYPES and PHYSICAL_DAMAGE_TYPES are sets |
| UNIT_TYPE / UNIT_TYPE_NAME | UT_PLAYER UT_PET UT_GROUP UT_DUMMY UT_COMPANION UT_OTHER UT_NONE |
| POWER_HEALTH, POWER_MAGICKA, POWER_STAMINA, POWER_ULTIMATE, POWER_NAME | power types |
| EFFECT_GAINED, EFFECT_FADED, EFFECT_UPDATED, EFFECT_FULL_REFRESH, EFFECT_TRANSFER, BUFF, DEBUFF | effect constants |
| LIGHT_ATTACK_SLOT (1), HEAVY_ATTACK_SLOT (2), FIRST_SKILL_SLOT (3), ULTIMATE_SLOT (8) | action bar slots |
| HOTBAR_PRIMARY, HOTBAR_BACKUP, HOTBAR_CHAMPION, WEAPON_PAIR_MAIN (1), WEAPON_PAIR_BACKUP (2) | bars |
| EQUIP_SLOTS, EQUIP_SLOT_NAME | array of { id, key, name, isBackup, isWeapon, isPoison } |
| SET_TYPE_NAME | set type → name |
| STATS, STAT_LABEL | array of { key, id, global, label } |
| VISUAL_SHIELD | the attribute visual used by the shield bar |
| RESIST_PER_PERCENT 660, RESIST_FOR_FULL 66000, MAX_ARMOR_MITIGATION 0.5 | armor formula |
| DEFAULT_TARGET_RESISTANCE 18200, CRIT_RATING_PER_PERCENT 219.12, BASE_CRIT_DAMAGE 0.5, MAX_BOSSES | other game numbers |
| LF.Fight.DIR / DIR_NAME | { OUT = 1, IN = 2, SELF = 3, GROUP = 4 } and their names |

[Back to contents](#contents)

## Data structures

The fields of every table the functions above return. Ranges are marked: 0..1 is a fraction, 0..100 is already a percentage.

### FightSummary

*f:GetSummary(), f.summary*

| Field | Meaning |
|---|---|
| **Identity** | |
| `id, title, zone, zoneId, character` |  |
| `startTimestamp` | Unix seconds |
| `durationMs, durationSec, activeSec` |  |
| `isActive` | boolean |
| **Damage done** | |
| `damage, dps, dpm, activeDPS` |  |
| `bossDamage, bossDPS` |  |
| `damageShielded` | Your damage absorbed by enemy shields |
| `damageIncludingShields` |  |
| `dotDamage, directDamage` |  |
| `dotShare` | 0..1 |
| `overkill` |  |
| **Healing done** | |
| `healing, hps, hpm` | Effective healing |
| `rawHealing, rawHPS, overheal` |  |
| `overhealPct` | 0..1 |
| `selfHealing` |  |
| **Taken** | |
| `damageTaken, dtps, dtpm` |  |
| `healingTaken, htps, htpm` |  |
| **Mitigation** | |
| `mitigated, mps, mpm` | Total mitigated |
| `mitigatedShield` | Exact |
| `mitigatedBlockEst, mitigatedArmorEst, mitigatedAvoidEst` | Estimates |
| `mitigationPct` | 0..1 of mitigated + taken |
| **Shields** | |
| `shield, sps, spm` | Damage absorbed by shields on you (exact) |
| `shieldHits` | Hits a shield absorbed |
| `shieldPctOfIncoming` | 0..1, shield / (shield + damage taken) |
| `shieldGained, shieldGainedPS, shieldGainedPM` | Shield applied to you (shield bar) |
| `shieldApplications` | New shields |
| `shieldPeak` | Largest shield seen on you |
| `shieldExpired` | Shield left over when it disappeared |
| `shieldEfficiency` | shield / shieldGained. Can pass 1 if a shield was already up at the start |
| `groupShield, groupSPS, groupSPM` | Group mode: absorbed on other members |
| **Hits** | |
| `hits, crits, ticks` |  |
| `critRate` | 0..1 |
| `avgHit, maxHit, maxHitAbilityId, maxHitAbility` |  |
| `healCritRate` | 0..1 |
| `maxHeal, maxHealAbility` |  |
| `incomingHits` |  |
| `incomingCritRate` | 0..1 |
| `blockedHits, dodges, misses, immune` |  |
| **Actions** | |
| `casts, skillCasts, lightAttacks, heavyAttacks, ultimates` |  |
| `apm, skillsPerMinute` | Per minute of active time |
| `weaves` |  |
| `weaveRatio` | 0..1 |
| `avgSkillGapMs` |  |
| `barSwaps` |  |
| `frontBarPct, backBarPct` | 0..1 |
| **Other** | |
| `killingBlows, deaths, interruptsOut, interruptsIn, ccOut, ccIn, powerGained` |  |
| `procActivations, numTargets, numAbilities` |  |

### f.totals

*raw running totals, all numbers*

| Field | Meaning |
|---|---|
| `damageOut, damageOutNormal, damageOutCrit, damageOutDot, damageOutDirect` | Damage done |
| `hitsOut, critsOut, ticksOut, overkill, damageOutShielded, damageOutBlocked, bossDamage` |  |
| `healOut, healOutNormal, healOutCrit, overheal, healHitsOut, healCritsOut, healTicksOut, selfHeal` | Healing done |
| `damageIn, hitsIn, critsIn, healIn, overhealIn, healHitsIn` | Incoming |
| `shieldAbsorbedIn, shieldHitsIn, shieldGained, shieldApplications, shieldPeak, shieldExpired, groupShieldAbsorbed` | Shields |
| `blockedHitsIn, blockedDamageIn, mitigatedShield, mitigatedBlockEst, mitigatedArmorEst, mitigatedAvoidEst` | Mitigation |
| `dodgesIn, missesIn, parriesIn, immuneIn, reflectsIn, absorbsIn, blockedFullIn` | Avoided |
| `avoidedOut, interruptsOut, interruptsIn, ccOut, ccIn, killingBlows, deaths, powerGained, powerDrained` | Other |

### AbilityRow

*f:GetAbilityBreakdown*

| Field | Meaning |
|---|---|
| `id, name, icon, graphic, damageType` | graphic is the ability graphic id sent by combat events |
| `total` |  |
| `pct` | 0..1 share of this kind |
| `dps, dpm` | Over the whole fight |
| `hits, crits` |  |
| `critRate` | 0..1 |
| `avg, avgNormal, avgCrit, min, max` |  |
| `ticks, tickTotal, directHits, directTotal` |  |
| `overflow` | Overkill (damage) or overheal (heals) |
| `results` | map ACTION_RESULT → count |

> The raw aggregate in f.abilities[kind][abilityId] has the same data plus slotType, powerType, normalTotal, critTotal, firstMs and lastMs.

### TargetRow / SourceRow

*f:GetTargets, f:GetSources*

| Field | Meaning |
|---|---|
| `unitId, name, damage, hits, crits` | Both |
| `isBoss, killed, dps, activeSec` | Targets only |
| `critRate` | 0..1, targets only |
| `pct` | 0..1 of your damage (targets) or of damage taken (sources) |
| `abilities` | map abilityId → damage |

### EffectRow

*f:GetEffectUptimes*

| Field | Meaning |
|---|---|
| `id, name, icon, effectType` |  |
| `castByPlayer` | boolean |
| `uptimeMs` |  |
| `uptimePct` | 0..1 |
| `gains, refreshes, fades, maxStacks` |  |
| `unitName` |  |

### ProcEntry

*f:GetProcs, PROC callback*

| Field | Meaning |
|---|---|
| `id, name, icon` |  |
| `kind` | "set" or "candidate" (not slotted, not linked to a set) |
| `setId, setName` | nil when not linked to a set |
| `sources, sourceList` | Where it was seen: damage, heal, effect |
| `external` | true if the buff came from another player |
| `activations, hits, damage, healing` |  |
| `firstMs, lastMs` | Game ms |
| `minGapMs, gapSum, gapCount` |  |
| `times` | ms from fight start (up to 120) |
| **Filled when the fight ends** | |
| `perMinute, avgGapMs` |  |
| `estimatedCooldownMs` | minGapMs once there are 3+ activations, else nil |
| `uptimeMs, uptimePct` | When the proc is also a buff/debuff |
| `damageSharePct` | 0..1 |

### FightSet

*f:GetSets, f.sets[setId]*

| Field | Meaning |
|---|---|
| `setId, name` |  |
| `equippedInFight, equipped, perfected, maxEquipped, fullBonus` | What you wore |
| `activeBonuses` |  |
| `damage, healing, hits, activations` | From the set's procs |
| `abilities` | set abilityId → true |
| **Filled when the fight ends** | |
| `uptimeMs` |  |
| `uptimePct, damageSharePct, healingSharePct` | 0..1 |
| `activationsPerMinute, abilityIds` |  |

### Casts

*f:GetCasts (first return), f.casts*

| Field | Meaning |
|---|---|
| `total, light, heavy, skills, ultimates, other, weaves` | Counts |
| `skillGapSum, skillGapCount` | For the average gap between skills |
| `abilities` | map abilityId → { id, name, icon, kind, count, firstMs, lastMs } |
| `server` | map abilityId → count of server "BEGIN" results |

### PowerEntry

*f:GetPower*

| Field | Meaning |
|---|---|
| `powerType, name` |  |
| `gained, spent` |  |
| `gainedBy` | map abilityId → amount |
| `min, max, sum, n, maxValue, last` |  |
| `timeAtZeroMs` |  |
| `samples` | array of { msFromStart, value, maxValue }, every 250 ms |

### DeathEntry

*f:GetDeaths, DEATH callback*

| Field | Meaning |
|---|---|
| `unitTag, name` |  |
| `tMs` | ms from fight start |
| `recap` | Your deaths only: array of { tMs, result, resultName, abilityId, abilityName, hit, overflow, source, damageType } |

### FightStats

*f:GetStats*

| Field | Meaning |
|---|---|
| `start` | StatSnapshot at fight start |
| `end` | Last snapshot |
| `min, max, avg, sum` | map statKey → number |
| `n` | Samples taken |
| `samples` | Changes only: { t = ms, statKey = value, ... } |

### GroupRow

*f:GetGroup (group mode)*

| Field | Meaning |
|---|---|
| `unitId, name, damage, healing, hits, crits` |  |
| `shieldAbsorbed` | Damage absorbed by shields on this member. nil in fights saved before shield tracking |
| `abilities` | map abilityId → { id, name, total, hits } |

### DecodedEvent

*FindEvents, f:DecodeEvent, Query:Run*

| Field | Meaning |
|---|---|
| `tMs, time` | ms from fight start, and game ms |
| `direction` | "out" "in" "self" "group" |
| `result, resultName, category, isCrit` |  |
| `abilityId, abilityName, icon` |  |
| `hit, overflow` |  |
| `sourceUnitId, source, targetUnitId, target` |  |
| `damageType, damageTypeName, powerType, slotType` |  |

### StatSnapshot

*LF.Stats.GetSnapshot*

| Field | Meaning |
|---|---|
| `maxHealth, maxMagicka, maxStamina` |  |
| `healthRegenCombat, magickaRegenCombat, staminaRegenCombat, …RegenIdle` |  |
| `spellPower, weaponPower, weaponAndSpellDamage` |  |
| `spellCritical, weaponCritical, criticalChance` | Ratings |
| `spellPenetration, physicalPenetration` |  |
| `spellResist, physicalResist, criticalResistance, armorRating` |  |
| `attackPower, mitigation, spellMitigation, block, dodge, miss, parry` |  |
| `healingTaken, healingDone, damageDone, damageTaken` |  |
| `healthCurrent, magickaCurrent, staminaCurrent, ultimateCurrent (+ …PowerMax)` | Resources |
| `spellCritPct, weaponCritPct` | Crit chance 0..100 |
| `spellResistPct, physicalResistPct` | Armor mitigation 0..100 |
| `timestampMs` |  |

> A key is missing if the game version does not have that stat.

### Build

*LF.Build.Read*

| Field | Meaning |
|---|---|
| `timestamp, apiVersion, libVersion, console` |  |
| `character` | { name, displayName, level, championPoints, classId, className, raceId, raceName, alliance, allianceName, gender, zoneName, zoneId, inGroup, groupSize, isVampire, isWerewolf } |
| `attributes` | { health, magicka, stamina, unspent } |
| `stats` | StatSnapshot |
| `gear` | map equipSlot → Item |
| `armorCounts` | { light, medium, heavy } |
| `sets` | map setId → EquippedSet |
| `activeWeaponPair` | 1 or 2 |
| `bars` | { front, back }: map slot → BarSlot |
| `champion` | { slotted, totalEarned } |
| `buffs, longBuffs` | array of Buff |
| `mundus` | array of { name, abilityId, icon } |
| `skills` | array of SkillEntry ("full" only) |
| `signature` | string |

### Item

*Build.ReadItem, build.gear*

| Field | Meaning |
|---|---|
| `link, name, itemId, icon` |  |
| `setId, setName` |  |
| `traitType, traitName, traitDescription` |  |
| `quality, displayQuality, armorType, weaponType, equipType` |  |
| `enchantHeader, enchantDescription` |  |
| `requiredLevel, requiredCP, armorRating, weaponPower, isMythic` |  |
| `slot, slotName, isBackup` | Inside build.gear only |

### BarSlot

*Build.ReadBar*

| Field | Meaning |
|---|---|
| `slot, abilityId, slotType, name, icon` |  |
| `crafted` | true for a scribed skill |
| `isUltimate` | boolean |

### Buff

*Build.ReadBuffs*

| Field | Meaning |
|---|---|
| `name, abilityId, icon, stacks` |  |
| `effectType, abilityType, statusEffectType, buffSlot` |  |
| `canClickOff, castByPlayer, permanent` | boolean |
| `remainingSec` | nil if permanent |

### AbilityInfo

*LF.Abilities.GetInfo*

| Field | Meaning |
|---|---|
| `id, name, rawName` |  |
| `icon, iconMarkup` | Texture path and \|t24:24:icon\|t |
| `description, descriptionHeader` |  |
| `durationMs, castTimeMs, channelTimeMs` |  |
| `isChanneled, isPassive, isPermanent` | boolean |
| `minRange, maxRange, radius` | Centimeters (divide by 100 for meters) |
| `angleDistance, targetDescription` |  |
| `cost, costMechanic, costIsPerTick` | costMechanic is the cost's power type, or nil |

### SkillEntry

*GetPlayerSkillAbilities*

| Field | Meaning |
|---|---|
| `abilityId, name, icon` |  |
| `passive, ultimate, purchased` | boolean |
| `rank, earnedRank, progressionIndex` |  |
| `skillType, skillLineIndex, skillLineId, skillLine` |  |

### ScanProgress

*GetScanProgress, SCAN_* callbacks*

| Field | Meaning |
|---|---|
| `running` | boolean |
| `fromId, toId, nextId, elapsedMs` | Absent if no scan was ever started |
| `found` | Found by this scan |
| `pct` | 0..1 |
| `indexed` | Total in the search index |

### SetInfo

*LF.Sets.GetSetInfo*

| Field | Meaning |
|---|---|
| `setId, name` |  |
| `setType, setTypeName` | e.g. "DUNGEON" |
| `numCollectionPieces` |  |
| `unperfectedSetId` | For perfected sets |
| `sampleLink` | string or nil |
| `numBonuses, maxEquipped` | maxEquipped = pieces for the full bonus |
| `bonuses` | array of { numRequired, description, isPerfected } |

### EquippedSet

*LF.Sets.GetEquippedSets, build.sets*

| Field | Meaning |
|---|---|
| `setId, name, numBonuses` |  |
| `equipped` | Pieces counted by the game (active bar only) |
| `perfected, maxEquipped` |  |
| `fullBonus` | boolean |
| `slots` | array of { slot, slotName, inactiveBar } |
| `activeBonuses, inactiveBonuses` | array of { numRequired, description, isPerfected } |
| `sampleLink` |  |

### ModelReport

*LF.Models.GetReport, f.models*

| Field | Meaning |
|---|---|
| `crit` | GetCritEstimate() result |
| `targets` | array of TargetEstimate |
| `incoming` | GetIncomingDR() result |
| `ttk` | GetAllTTK() result |
| `dpsForecast` | 5 seconds ahead, or nil |
| `referenceAbilitiesTrained, referenceSamples, trainedHits, abilitiesModeled` | Counts |

### TargetEstimate

*LF.Models.GetTargetEstimate*

| Field | Meaning |
|---|---|
| `name, samples, relativeSamples` |  |
| `confidence` | 0..1 |
| **When calibrated (samples > 0)** | |
| `predictedMitigation` | 0..1 total damage reduction |
| `predictedMitigationStd` |  |
| `predictedDRPct` | 0..100 |
| `predictedResistance, predictedResistanceStd` | Resistance points |
| `penetrationUsed` | Your penetration on the last sample |
| `penetrationToCap, missingPenetration` | Resistance minus penetration used / your current highest |
| `overPenetratedPct, cappedPct` | 0..1 share of samples |
| `status` | "ok", "over-penetrated (…)" or "capped / extra damage reduction" |
| **When only relative data exists** | |
| `relativeDamageTaken` | Ratio vs your average target (1 = same) |
| `relativeToughnessPct` | 0..100 |

[Back to contents](#contents)

## Internal functions

The logger calls these while logging. You normally never need them, but they are public if you want to feed data in yourself.

#### Fight recording (on a Fight object)

| Function | Returns | Notes |
|---|---|---|
| `f:RecordOutgoing(cat, result, abilityId, abilityName, graphic, slotType, targetUnitId, hit, overflow, damageType, powerType, now)` | `nothing` |  |
| `f:RecordIncoming(…same…, sourceUnitId, …, now, isSelf)` | `nothing` |  |
| `f:RecordGroup(cat, result, abilityId, abilityName, sourceUnitId, hit, now)` | `nothing` |  |
| `f:RecordGroupShield(targetUnitId, hit, now)` | `nothing` |  |
| `f:RecordShieldValue(kind, oldValue, newValue, now)` | `nothing` | kind: "added" "updated" "removed". For "removed", oldValue is what was left and counts as expired. |
| `f:RecordEffect(scope, changeType, abilityId, effectName, unitId, unitName, stackCount, iconName, effectType, sourceType, now)` | `effect entry` |  |
| `f:RecordPower(powerType, value, maxValue, now)` | `nothing` |  |
| `f:RecordBossHealth(unitTag, name, current, max, now)` | `nothing` |  |
| `f:RecordCast(slotIndex, abilityId, now)` | `kind string` |  |
| `f:RecordBarSwap(activePair, now)` | `nothing` |  |
| `f:RecordDeath(unitTag, unitName, now, recap)` | `DeathEntry` |  |
| `f:RecordGearChange(slotIndex, now)` | `nothing` |  |
| `f:NoteUnit(unitId, name, unitType)` | `{ name, type } or nil` |  |
| `f:PushEvent(rawEvent) / f:CloseOpenIntervals(now) / f:Finish(endMs?)` | `nothing` |  |

#### Per-fight trackers

| Function | Returns | Notes |
|---|---|---|
| `LF.Stats.BeginTracking(f) / FinishTracking(f)` | `nothing` |  |
| `LF.Stats.Sample(f, snap?)` | `StatSnapshot or nil` |  |
| `LF.Sets.BeginTracking(f) / FinishTracking(f)` | `nothing` |  |
| `LF.Sets.Attribute(f, abilityId, name, cat, amount, isActivation)` | `setId or nil` |  |
| `LF.Procs.BeginTracking / ObserveCombat / ObserveEffect / FinishTracking` | `nothing` |  |

#### Model feeding

| Function | Returns | Notes |
|---|---|---|
| `LF.Models.ObserveOutgoing(abilityId, result, hit, damageType, targetName, targetType, isCrit, isTick)` | `nothing` |  |
| `LF.Models.ObserveIncoming(abilityId, result, hit, damageType, sourceName, isCrit)` | `nothing` |  |
| `LF.Models.ObserveUnitHealth(key, name, current, max, tSec)` | `nothing` |  |
| `LF.Models.ObserveDPS(dps) / ResetFightTransient()` | `nothing` |  |

[Back to contents](#contents)
