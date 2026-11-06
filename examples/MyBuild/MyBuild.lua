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
