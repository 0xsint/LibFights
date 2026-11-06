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
