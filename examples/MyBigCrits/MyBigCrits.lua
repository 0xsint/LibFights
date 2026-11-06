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
