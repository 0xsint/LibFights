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
