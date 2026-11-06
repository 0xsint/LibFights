local NAME = "MyFightPanel"
local LF = LibFights
local DEFAULTS = { autoStart = true }
local sv

local function PrintLast()
  LF.PrintLines(LF.Report.FightSummaryLines(LF.GetLastFight()))
end

local function BuildLAM()
  local LAM = LibAddonMenu2
  LAM:RegisterAddonPanel("MyFightPanelPanel", { type = "panel", name = "My Fight Panel" })
  LAM:RegisterOptionControls("MyFightPanelPanel", {
    { type = "checkbox", name = "Start logging in combat",
      getFunc = function() return sv.autoStart end,
      setFunc = function(v) sv.autoStart = v end, default = DEFAULTS.autoStart },
    { type = "button", name = "Start logging", func = function() Start_Logging() end, width = "half" },
    { type = "button", name = "Stop logging", func = function() Stop_Logging() end, width = "half" },
    { type = "button", name = "Print last fight", func = PrintLast },
  })
end

local function BuildLHAS()
  local LHAS = LibHarvensAddonSettings
  local panel = LHAS:AddAddon("My Fight Panel", { allowDefaults = true })
  panel:AddSetting({ type = LHAS.ST_CHECKBOX, label = "Start logging in combat", default = DEFAULTS.autoStart,
    getFunction = function() return sv.autoStart end,
    setFunction = function(v) sv.autoStart = v end })
  panel:AddSetting({ type = LHAS.ST_BUTTON, label = "Logging", buttonText = "Start",
    clickHandler = function() Start_Logging() end })
  panel:AddSetting({ type = LHAS.ST_BUTTON, label = "Logging", buttonText = "Stop",
    clickHandler = function() Stop_Logging() end })
  panel:AddSetting({ type = LHAS.ST_BUTTON, label = "Last fight", buttonText = "Print",
    clickHandler = PrintLast })
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
  if addonName ~= NAME then return end
  EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
  sv = ZO_SavedVars:NewAccountWide("MyFightPanelSV", 1, nil, DEFAULTS)

  if LF.IsConsole() and LibHarvensAddonSettings then BuildLHAS()
  elseif LibAddonMenu2 then BuildLAM()
  elseif LibHarvensAddonSettings then BuildLHAS() end

  EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
    if inCombat and sv.autoStart and not Is_Logging() then Start_Logging() end
  end)
end)
