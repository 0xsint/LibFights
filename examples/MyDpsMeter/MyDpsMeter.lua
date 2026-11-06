local LF = LibFights
local U = LF.Util
local UPDATE = "MyDpsMeter_Update"

local win = WINDOW_MANAGER:CreateTopLevelWindow("MyDpsMeter")
win:SetDimensions(260, 56)
win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -220)
win:SetMovable(true)
win:SetMouseEnabled(true)
win:SetClampedToScreen(true)

local label = WINDOW_MANAGER:CreateControl("MyDpsMeterText", win, CT_LABEL)
label:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
label:SetFont("ZoFontGameLargeBold")
label:SetText("Waiting for a fight")

-- only visible on the normal HUD
local fragment = ZO_HUDFadeSceneFragment:New(win)
HUD_SCENE:AddFragment(fragment)
HUD_UI_SCENE:AddFragment(fragment)

local function Refresh()
  local f = LF.GetCurrentFight()
  if not f then return end
  label:SetText(("%s  DPS %s  HPS %s  SPS %s"):format(
    U.FormatDuration(f:GetDurationMs()),
    U.FormatNumber(f:GetDPS()), U.FormatNumber(f:GetHPS()), U.FormatNumber(f:GetSPS())))
end

LF.RegisterCallback(LF.EVENTS.FIGHT_STARTED, function()
  EVENT_MANAGER:RegisterForUpdate(UPDATE, 500, Refresh)
end)

LF.RegisterCallback(LF.EVENTS.FIGHT_ENDED, function(fight)
  EVENT_MANAGER:UnregisterForUpdate(UPDATE)
  local s = fight:GetSummary()
  label:SetText(("Last fight: %s DPS over %s"):format(
    U.FormatNumber(s.dps), U.FormatDuration(s.durationMs)))
end)
