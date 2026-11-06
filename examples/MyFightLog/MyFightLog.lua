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
