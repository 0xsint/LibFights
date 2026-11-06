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
