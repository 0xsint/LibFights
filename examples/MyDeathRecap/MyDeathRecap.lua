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
