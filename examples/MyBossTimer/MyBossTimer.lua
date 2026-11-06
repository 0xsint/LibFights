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
