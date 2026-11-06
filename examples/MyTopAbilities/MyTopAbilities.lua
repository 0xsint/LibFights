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
