local LF = LibFights

SLASH_COMMANDS["/lfs"] = function(text)
  if text == "" then
    LF.Print("Try: /lfs relequen   /lfs in:set kinras   /lfs id:46340   /lfs fight:3 crit")
    return
  end
  local results = LF.Search(text, { limit = 10 })
  if #results == 0 then
    LF.Print("Nothing found for %q", text)
    return
  end
  for _, r in ipairs(results) do
    d(LF.SearchFormatResult(r))
  end
end
