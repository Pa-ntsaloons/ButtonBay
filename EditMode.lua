local _, ns = ...

local EditMode = { active = false, selected = false }
ns.EditMode = EditMode

local SYSTEM_NAME = "Button Bay"
local main = ns.Dock.main

local function hasEditMode()
  return EventRegistry ~= nil
    and EditModeManagerFrame ~= nil
    and EditModeSystemSelectionMixin ~= nil
end

--------------------------------------------------------------------------------
-- Settings dialog (shown while the dock is selected in Edit Mode)
--------------------------------------------------------------------------------

local Dialog = CreateFrame("Frame", "ButtonBayEditModeDialog", UIParent, "BackdropTemplate")
EditMode.Dialog = Dialog
Dialog:SetSize(370, 10)
Dialog:SetFrameStrata("DIALOG")
Dialog:SetClampedToScreen(true)
Dialog:SetMovable(true)
Dialog:EnableMouse(true)
Dialog:RegisterForDrag("LeftButton")
Dialog:SetScript("OnDragStart", Dialog.StartMoving)
Dialog:SetScript("OnDragStop", Dialog.StopMovingOrSizing)
Dialog:SetPoint("LEFT", UIParent, "CENTER", 200, 0)
Dialog:Hide()

-- Use Blizzard's Edit Mode dialog border when this client has it.
local hasBorder, border = pcall(CreateFrame, "Frame", nil, Dialog, "DialogBorderTranslucentTemplate")
if hasBorder and border then
  border:SetAllPoints()
else
  Dialog:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end

local title = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
title:SetPoint("TOP", 0, -16)
title:SetText(SYSTEM_NAME)

local layoutLabel = Dialog:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
layoutLabel:SetPoint("TOP", title, "BOTTOM", 0, -4)

local close = CreateFrame("Button", nil, Dialog, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)
close:SetScript("OnClick", function()
  if EditMode.active then
    EditMode:Deselect()
  else
    Dialog:Hide()
  end
end)

local ROW_HEIGHT = 34
local LABEL_WIDTH = 140
local rows = {}
local nextRowY = -56
local updating = false

local function addRow(labelText, control, height)
  local label = Dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  label:SetPoint("TOPLEFT", 20, nextRowY - 8)
  label:SetWidth(LABEL_WIDTH)
  label:SetJustifyH("LEFT")
  label:SetText(labelText)

  control:SetPoint("LEFT", label, "RIGHT", 8, 0)
  nextRowY = nextRowY - (height or ROW_HEIGHT)
  table.insert(rows, control)
  return control
end

local function setLayoutValue(key, value)
  if updating then
    return
  end
  ns.layout[key] = value
  ns.Dock:Refresh()
end

local function roundTo(value, step)
  return math.floor(value / step + 0.5) * step
end

-- Slider: Blizzard's stepper slider when available, a plain one otherwise.
local function createSlider(minValue, maxValue, step, format, onChange)
  local ok, slider = false, nil
  if MinimalSliderWithSteppersMixin then
    ok, slider = pcall(CreateFrame, "Frame", nil, Dialog, "MinimalSliderWithSteppersTemplate")
  end

  if ok and slider then
    slider:SetWidth(150)
    local formatters = {}
    if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin.Label then
      local right = MinimalSliderWithSteppersMixin.Label.Right
      formatters[right] = CreateMinimalSliderFormatter(right, format)
    end
    slider:Init(minValue, minValue, maxValue, (maxValue - minValue) / step, formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
      onChange(roundTo(value, step))
    end, slider)
    slider.Refresh = function(self, value)
      updating = true
      self:SetValue(value)
      updating = false
    end
    return slider
  end

  slider = CreateFrame("Slider", nil, Dialog, "BackdropTemplate")
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(140, 16)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
  })
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local text = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  text:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  slider:SetScript("OnValueChanged", function(_, value)
    value = roundTo(value, step)
    text:SetText(format(value))
    onChange(value)
  end)
  slider.Refresh = function(self, value)
    updating = true
    self:SetValue(value)
    text:SetText(format(value))
    updating = false
  end
  return slider
end

local function addTooltip(frame, text)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function createCheckbox(onChange)
  local check = CreateFrame("CheckButton", nil, Dialog, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetScript("OnClick", function(self)
    onChange(self:GetChecked() and true or false)
  end)
  check.Refresh = function(self, value)
    self:SetChecked(value)
  end
  return check
end

-- Choice picker: Blizzard's dropdown menu when available, otherwise a button
-- that cycles through the options (right-click goes backwards).
-- options: list of { key, label }; getKey/setKey read and write the choice.
local function createChoicePicker(options, getKey, setKey)
  local function labelFor(key)
    for _, option in ipairs(options) do
      if option.key == key then
        return option.label
      end
    end
    return tostring(key)
  end

  local ok, dropdown = false, nil
  if MenuUtil then
    ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, Dialog, "WowStyle1DropdownTemplate")
  end

  if ok and dropdown then
    dropdown:SetWidth(160)
    dropdown:SetupMenu(function(_, root)
      for _, option in ipairs(options) do
        root:CreateRadio(option.label,
          function() return ns.layout ~= nil and getKey() == option.key end,
          function() setKey(option.key) end)
      end
    end)
    dropdown.Refresh = function(self)
      self:GenerateMenu()
    end
    return dropdown
  end

  local button = CreateFrame("Button", nil, Dialog, "UIPanelButtonTemplate")
  button:SetSize(160, 22)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, mouseButton)
    local count = #options
    local index = 1
    for i, option in ipairs(options) do
      if option.key == getKey() then
        index = i
      end
    end
    index = mouseButton == "RightButton" and index - 2 or index
    local nextOption = options[(index % count) + 1]
    setKey(nextOption.key)
    button:SetText(nextOption.label)
  end)
  button.Refresh = function(self)
    self:SetText(labelFor(getKey()))
  end
  return button
end

-- Opens Blizzard's color picker (with opacity) for a {r, g, b, a} table.
-- Cancel restores the color you started with.
local function openColorPicker(color, onChange)
  local original = { r = color.r, g = color.g, b = color.b, a = color.a }
  local picker = ColorPickerFrame

  local function currentAlpha()
    if picker.GetColorAlpha then
      return picker:GetColorAlpha()
    end
    if OpacitySliderFrame then
      return 1 - OpacitySliderFrame:GetValue()
    end
    return original.a
  end

  local function apply()
    local r, g, b = picker:GetColorRGB()
    onChange(r, g, b, currentAlpha())
  end

  local function cancel()
    onChange(original.r, original.g, original.b, original.a)
  end

  if picker.SetupColorPickerAndShow then
    picker:SetupColorPickerAndShow({
      r = color.r, g = color.g, b = color.b,
      opacity = color.a,
      hasOpacity = true,
      swatchFunc = apply,
      opacityFunc = apply,
      cancelFunc = cancel,
    })
  else
    picker.hasOpacity = true
    picker.opacity = 1 - color.a
    picker.func = apply
    picker.opacityFunc = apply
    picker.cancelFunc = cancel
    picker:SetColorRGB(color.r, color.g, color.b)
    ShowUIPanel(picker)
  end
end

-- A color swatch for one of the layout's color settings.
local function createColorSwatch(key)
  local swatch = CreateFrame("Button", nil, Dialog, "BackdropTemplate")
  swatch:SetSize(40, 20)
  swatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  swatch:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)

  -- A checkerboard behind the color makes transparency visible.
  local checker = swatch:CreateTexture(nil, "BACKGROUND")
  checker:SetPoint("TOPLEFT", 1, -1)
  checker:SetPoint("BOTTOMRIGHT", -1, 1)
  checker:SetColorTexture(0.5, 0.5, 0.5, 1)

  local fill = swatch:CreateTexture(nil, "ARTWORK")
  fill:SetAllPoints(checker)

  swatch.Refresh = function()
    local c = ns.layout[key]
    fill:SetColorTexture(c.r, c.g, c.b, c.a)
  end

  swatch:SetScript("OnClick", function()
    openColorPicker(ns.layout[key], function(r, g, b, a)
      local c = ns.layout[key]
      c.r, c.g, c.b, c.a = r, g, b, a
      ns.Dock:ApplyAppearance()
      Dialog:Refresh()  -- keeps the opacity slider in step with the picker
    end)
  end)
  return swatch
end

local percent = function(value) return string.format("%d%%", value) end
local plain = function(value) return tostring(value) end
local seconds = function(value) return string.format("%.2fs", value) end

local directionPicker = addRow("Direction", createChoicePicker(ns.DIRECTIONS,
  function() return ns.layout.direction end,
  function(key) setLayoutValue("direction", key) end))
addTooltip(directionPicker, "Which way the dock opens from the logo.")
local fillOrderPicker = addRow("Button order", createChoicePicker(ns.FILL_ORDERS,
  function() return ns.layout.fillOrder end,
  function(key) setLayoutValue("fillOrder", key) end))
addTooltip(fillOrderPicker,
  "How the icons fill the dock. \"Match direction\" starts next to the logo and fills away from it.")
local perRowSlider = addRow("Buttons per row",
  createSlider(1, 12, 1, plain, function(v) setLayoutValue("perRow", v) end))
addTooltip(perRowSlider, "When the button order goes top to bottom first, this is buttons per column.")
local logoScaleSlider = addRow("Logo size",
  createSlider(50, 200, 5, percent, function(v) setLayoutValue("logoScale", v) end))
local hideLogoCheck = addRow("Hide logo until hovered",
  createCheckbox(function(v) ns.db.hideLogoUntilHover = v end), 30)
local logoColorSwatch = addRow("Logo color", createColorSwatch("logoColor"))
addTooltip(logoColorSwatch, "Color of the logo's tiles while the dock is closed.")
local logoOpenColorSwatch = addRow("Logo color (open)", createColorSwatch("logoOpenColor"))
addTooltip(logoOpenColorSwatch, "Color of the logo's tiles while the dock is open.")
addTooltip(hideLogoCheck,
  "The logo fades away until you mouse over it. It stays visible while the dock or these settings are open, and in Edit Mode.")
local buttonCountCheck = addRow("Show button count",
  createCheckbox(function(v)
    ns.db.showButtonCount = v
    ns.Dock:UpdateLayout()
  end), 30)
addTooltip(buttonCountCheck, "Shows how many buttons are in the dock in the logo's bottom-right tile.")
local dockScaleSlider = addRow("Dock size",
  createSlider(50, 200, 5, percent, function(v) setLayoutValue("dockScale", v) end))
local borderPicker = addRow("Border", createChoicePicker(ns.BORDER_STYLES,
  function() return ns.layout.borderStyle end,
  function(key) setLayoutValue("borderStyle", key) end))
local backgroundSwatch = addRow("Background color", createColorSwatch("backgroundColor"))
local backgroundOpacitySlider = addRow("Background opacity",
  createSlider(0, 100, 5, percent, function(v)
    if updating then
      return
    end
    ns.layout.backgroundColor.a = v / 100
    backgroundSwatch:Refresh()
    ns.Dock:ApplyAppearance()
  end))
addTooltip(backgroundOpacitySlider, "Set to 0% for a fully transparent background. Pick \"None\" under Border to hide the edge too.")
local borderSwatch = addRow("Border color", createColorSwatch("borderColor"))
local autoCloseCheck = addRow("Close on mouse-out",
  createCheckbox(function(v) ns.db.autoClose = v end), 30)
addTooltip(autoCloseCheck, "Close the dock automatically when the mouse leaves it.")
local closeDelaySlider = addRow("Close delay",
  createSlider(0, 5, 0.25, seconds, function(v) ns.db.autoCloseDelay = v end))

local perCharacterCheck = addRow("Order per character",
  createCheckbox(function(v)
    ns.db.perCharacterOrder = v
    ns.Dock:ApplyOrder()
  end), 30)
addTooltip(perCharacterCheck,
  "Each character keeps its own icon order. Turn off to share one order across all characters.")

local compartmentCheck
if _G.AddonCompartmentFrame then
  compartmentCheck = addRow("Hide Blizzard addon menu",
    createCheckbox(function(v)
      ns.db.hideCompartment = v
      ns.Dock:ApplyCompartmentVisibility()
    end), 30)
  addTooltip(compartmentCheck,
    "Hides Blizzard's addon compartment: the small button by the minimap that lists your addons in a menu.")
end

local resetPositionButton = CreateFrame("Button", nil, Dialog, "UIPanelButtonTemplate")
resetPositionButton:SetSize(130, 22)
resetPositionButton:SetPoint("TOPRIGHT", Dialog, "TOP", -4, nextRowY - 10)
resetPositionButton:SetText("Reset Position")
resetPositionButton:SetScript("OnClick", function()
  ns.Dock:ResetPosition()
end)

local resetOrderButton = CreateFrame("Button", nil, Dialog, "UIPanelButtonTemplate")
resetOrderButton:SetSize(130, 22)
resetOrderButton:SetPoint("TOPLEFT", Dialog, "TOP", 4, nextRowY - 10)
resetOrderButton:SetText("Reset Order")
resetOrderButton:SetScript("OnClick", function()
  ns.Dock:ResetOrder()
end)
addTooltip(resetOrderButton, "Put the icons back in alphabetical order.")

local hint = Dialog:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hint:SetPoint("TOP", Dialog, "TOP", 0, nextRowY - 42)
hint:SetText("Drag icons in the dock to change their order.")

Dialog:SetHeight(-nextRowY + 80)

function Dialog:Refresh()
  if not ns.layout then
    return
  end
  layoutLabel:SetText("Layout: " .. tostring(ns.layoutName))
  directionPicker:Refresh()
  fillOrderPicker:Refresh()
  perRowSlider:Refresh(ns.layout.perRow)
  logoScaleSlider:Refresh(ns.layout.logoScale)
  logoColorSwatch:Refresh()
  logoOpenColorSwatch:Refresh()
  hideLogoCheck:Refresh(ns.db.hideLogoUntilHover)
  buttonCountCheck:Refresh(ns.db.showButtonCount)
  perCharacterCheck:Refresh(ns.db.perCharacterOrder)
  dockScaleSlider:Refresh(ns.layout.dockScale)
  borderPicker:Refresh()
  backgroundSwatch:Refresh()
  backgroundOpacitySlider:Refresh(math.floor(ns.layout.backgroundColor.a * 100 / 5 + 0.5) * 5)
  borderSwatch:Refresh()
  autoCloseCheck:Refresh(ns.db.autoClose)
  closeDelaySlider:Refresh(ns.db.autoCloseDelay)
  if compartmentCheck then
    compartmentCheck:Refresh(ns.db.hideCompartment)
  end
end

function Dialog:Open()
  self:Refresh()
  self:Show()
end

Dialog:SetScript("OnShow", function()
  ns.Dock:SetPreview(true)
  ns.Dock:SetArranging(true)
end)
Dialog:SetScript("OnHide", function()
  ns.Dock:SetArranging(false)
  ns.Dock:SetPreview(false)
end)

ns.Listen("LAYOUT_CHANGED", function()
  if Dialog:IsShown() then
    Dialog:Refresh()
  end
end)

--------------------------------------------------------------------------------
-- Selection overlay and dragging
--------------------------------------------------------------------------------

local selection

function EditMode:Select()
  if not self.active then
    return
  end
  self.selected = true
  selection:ShowSelected()
  Dialog:Open()
end

function EditMode:Deselect()
  if not self.selected then
    return
  end
  self.selected = false
  if selection and selection:IsShown() then
    selection:ShowHighlighted()
  end
  Dialog:Hide()
end

function EditMode:ToggleSettings()
  if self.active then
    if self.selected then
      self:Deselect()
    else
      self:Select()
    end
  elseif Dialog:IsShown() then
    Dialog:Hide()
  else
    Dialog:Open()
  end
end

--------------------------------------------------------------------------------
-- Dragging with snapping
--
-- Blizzard's magnetism only knows about Blizzard's systems, and calling into
-- it from an addon risks taint, so the dock does its own: while dragging, its
-- edges and center snap to the edges/centers of other Edit Mode frames and to
-- the screen's center lines, with red guide lines like Blizzard's.
-- Follows Edit Mode's "Snap" checkbox; hold Shift to drag freely.
--------------------------------------------------------------------------------

local SNAP_RANGE = 10

local function isPlainNumber(value)
  if issecretvalue and issecretvalue(value) then
    return false
  end
  return type(value) == "number"
end

local function cursorPosition()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  return x / scale, y / scale
end

-- A frame's rectangle in UIParent coordinates, or nil if it can't be read.
local function rectOf(frame)
  local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
  if not ok or not (isPlainNumber(left) and isPlainNumber(bottom)
      and isPlainNumber(width) and isPlainNumber(height)) then
    return nil
  end
  local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return {
    left = left * scale,
    right = (left + width) * scale,
    bottom = bottom * scale,
    top = (bottom + height) * scale,
  }
end

local function isSnapEnabled()
  local manager = EditModeManagerFrame
  if not EditMode.active or not manager then
    return false
  end
  if type(manager.IsSnapEnabled) == "function" then
    local ok, enabled = pcall(manager.IsSnapEnabled, manager)
    return ok and enabled == true
  end
  return true
end

-- Every visible Edit Mode frame, read once when a drag starts.
local function collectSnapTargets()
  local targets = {}
  local frames = EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames
  if type(frames) ~= "table" then
    return targets
  end
  for _, frame in pairs(frames) do
    local box = type(frame) == "table" and (frame.Selection or frame)
    local visible = box and box ~= main and pcall(box.IsVisible, box) and box:IsVisible()
    if visible then
      local rect = rectOf(box)
      if rect then
        table.insert(targets, rect)
      end
    end
  end
  return targets
end

local function closer(best, ours, theirs)
  local delta = theirs - ours
  if math.abs(delta) <= SNAP_RANGE and (not best or math.abs(delta) < math.abs(best.delta)) then
    return { delta = delta, line = theirs }
  end
  return best
end

-- Returns the best horizontal and vertical snap ({delta, line}) or nil.
local function findSnap(centerX, centerY, halfWidth, halfHeight, targets)
  local left, right = centerX - halfWidth, centerX + halfWidth
  local bottom, top = centerY - halfHeight, centerY + halfHeight

  local snapX = closer(nil, centerX, UIParent:GetWidth() / 2)
  local snapY = closer(nil, centerY, UIParent:GetHeight() / 2)

  for _, t in ipairs(targets) do
    local midX, midY = (t.left + t.right) / 2, (t.top + t.bottom) / 2

    -- Side by side (or level with each other): snap horizontally.
    if top >= t.bottom - SNAP_RANGE and bottom <= t.top + SNAP_RANGE then
      snapX = closer(snapX, left, t.right)
      snapX = closer(snapX, right, t.left)
      snapX = closer(snapX, left, t.left)
      snapX = closer(snapX, right, t.right)
      snapX = closer(snapX, centerX, midX)
    end

    -- Above or below each other: snap vertically.
    if right >= t.left - SNAP_RANGE and left <= t.right + SNAP_RANGE then
      snapY = closer(snapY, bottom, t.top)
      snapY = closer(snapY, top, t.bottom)
      snapY = closer(snapY, top, t.top)
      snapY = closer(snapY, bottom, t.bottom)
      snapY = closer(snapY, centerY, midY)
    end
  end

  return snapX, snapY
end

local guides = CreateFrame("Frame", nil, UIParent)
guides:SetAllPoints(UIParent)
guides:SetFrameStrata("FULLSCREEN_DIALOG")
guides:Hide()
guides.vertical = guides:CreateTexture(nil, "OVERLAY")
guides.vertical:SetColorTexture(1, 0, 0, 0.9)
guides.vertical:SetWidth(2)
guides.horizontal = guides:CreateTexture(nil, "OVERLAY")
guides.horizontal:SetColorTexture(1, 0, 0, 0.9)
guides.horizontal:SetHeight(2)

local function showGuides(snapX, snapY)
  guides.vertical:SetShown(snapX ~= nil)
  guides.horizontal:SetShown(snapY ~= nil)
  if snapX then
    guides.vertical:ClearAllPoints()
    guides.vertical:SetPoint("TOP", UIParent, "TOPLEFT", snapX.line, 0)
    guides.vertical:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", snapX.line, 0)
  end
  if snapY then
    guides.horizontal:ClearAllPoints()
    guides.horizontal:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, snapY.line)
    guides.horizontal:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, snapY.line)
  end
  guides:SetShown(snapX ~= nil or snapY ~= nil)
end

local drag
local dragDriver = CreateFrame("Frame")

local function stopDragging()
  if not drag then
    return
  end
  drag = nil
  dragDriver:SetScript("OnUpdate", nil)
  guides:Hide()
  ns.Dock:SavePosition()
end

local function updateDrag()
  if not IsMouseButtonDown("LeftButton") then
    stopDragging()
    return
  end

  local scale = main:GetScale()
  local halfWidth = main:GetWidth() * scale / 2
  local halfHeight = main:GetHeight() * scale / 2
  local cursorX, cursorY = cursorPosition()
  local x = math.min(math.max(cursorX + drag.offsetX, halfWidth), UIParent:GetWidth() - halfWidth)
  local y = math.min(math.max(cursorY + drag.offsetY, halfHeight), UIParent:GetHeight() - halfHeight)

  local snapX, snapY
  if drag.targets and not IsShiftKeyDown() then
    snapX, snapY = findSnap(x, y, halfWidth, halfHeight, drag.targets)
  end
  if snapX then x = x + snapX.delta end
  if snapY then y = y + snapY.delta end
  showGuides(snapX, snapY)

  main:ClearAllPoints()
  main:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function startDragging()
  if drag or InCombatLockdown() then
    return
  end
  local scale = main:GetScale()
  local centerX, centerY = main:GetCenter()
  local cursorX, cursorY = cursorPosition()
  drag = {
    offsetX = centerX * scale - cursorX,
    offsetY = centerY * scale - cursorY,
    targets = isSnapEnabled() and collectSnapTargets() or nil,
  }
  dragDriver:SetScript("OnUpdate", updateDrag)
end

-- Called by Blizzard's selection template.
function main.GetSystemName()
  return SYSTEM_NAME
end

function main.OnDragStart()
  if not EditMode.active then
    return
  end
  EditMode:Select()
  startDragging()
end

function main.OnDragStop()
  stopDragging()
end

local function onEditModeEnter()
  EditMode.active = true
  selection:Show()
  selection:ShowHighlighted()
end

local function onEditModeExit()
  stopDragging()
  EditMode:Deselect()
  EditMode.active = false
  selection:Hide()
end

--------------------------------------------------------------------------------
-- Following the active Edit Mode layout
--------------------------------------------------------------------------------

local function activeLayoutName()
  local manager = EditModeManagerFrame
  if manager and manager.layoutInfo and type(manager.GetActiveLayoutInfo) == "function" then
    local ok, info = pcall(manager.GetActiveLayoutInfo, manager)
    if ok and type(info) == "table" and info.layoutName then
      return info.layoutName
    end
  end

  -- C_EditMode.GetLayouts() leaves out the preset layouts (Modern / Classic),
  -- but activeLayout counts them.
  if C_EditMode and C_EditMode.GetLayouts then
    local info = C_EditMode.GetLayouts()
    if type(info) == "table" and info.activeLayout then
      local presets = {}
      if EditModePresetLayoutManager and EditModePresetLayoutManager.GetCopyOfPresetLayouts then
        presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts() or {}
      end
      local index = info.activeLayout
      if index <= #presets then
        return presets[index].layoutName
      end
      local layout = info.layouts and info.layouts[index - #presets]
      return layout and layout.layoutName
    end
  end
end

local function syncLayout()
  local name = activeLayoutName()
  if name then
    ns.SetActiveLayout(name)
  end
end

local function deferredSync()
  C_Timer.After(0, syncLayout)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

-- Without Edit Mode the dock is moved with Alt-drag and set up with /bb config.
local function setupFallback()
  main:RegisterForDrag("LeftButton")
  main:SetScript("OnDragStart", function()
    if IsAltKeyDown() then
      startDragging()
    end
  end)
  main:SetScript("OnDragStop", stopDragging)
end

ns.Listen("LOGIN", function()
  if not hasEditMode() then
    setupFallback()
    return
  end

  local ok, frame = pcall(CreateFrame, "Frame", nil, main, "EditModeSystemSelectionTemplate")
  if not ok or not frame then
    setupFallback()
    return
  end

  EditMode.supported = true
  selection = frame
  selection:SetAllPoints(main)
  selection:SetFrameLevel(main:GetFrameLevel() + 20)
  if selection.SetSystem then
    selection:SetSystem(main)
  else
    selection.system = main
  end
  selection:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      EditMode:Select()
    end
  end)
  selection:Hide()

  EventRegistry:RegisterCallback("EditMode.Enter", onEditModeEnter, EditMode)
  EventRegistry:RegisterCallback("EditMode.Exit", onEditModeExit, EditMode)

  -- Only ever *listen* to Blizzard's Edit Mode; calling into it from an addon
  -- risks tainting it.
  if type(EditModeManagerFrame.SelectSystem) == "function" then
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function()
      EditMode:Deselect()
    end)
  end
  if type(EditModeManagerFrame.SelectLayout) == "function" then
    hooksecurefunc(EditModeManagerFrame, "SelectLayout", deferredSync)
  end
  ns.On("EDIT_MODE_LAYOUTS_UPDATED", deferredSync)

  syncLayout()

  if EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
    onEditModeEnter()
  end
end)
