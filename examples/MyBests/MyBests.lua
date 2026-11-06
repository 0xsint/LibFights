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
