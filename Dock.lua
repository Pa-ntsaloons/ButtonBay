local _, ns = ...

local Dock = {}
ns.Dock = Dock

-- Original widget methods. Collected buttons get their own SetPoint/SetParent
-- replaced with no-ops (so their addons can't drag them back onto the
-- minimap), so the dock calls these originals directly.
local FrameAPI = getmetatable(UIParent).__index
local ClearAllPoints = FrameAPI.ClearAllPoints
local SetPoint = FrameAPI.SetPoint
local SetParent = FrameAPI.SetParent
local SetScale = FrameAPI.SetScale
local SetAlpha = FrameAPI.SetAlpha

local GAP = 2
local FALLBACK_CELL = 32

local VECTORS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, 1 }, down = { 0, -1 } }
local OPPOSITE = { left = "right", right = "left", up = "down", down = "up" }

-- primary = the direction buttons fill first; secondary = where new rows go.
ns.DIRECTIONS = {
  { key = "leftdown",  primary = "left",  secondary = "down",  label = "Left, then down" },
  { key = "leftup",    primary = "left",  secondary = "up",    label = "Left, then up" },
  { key = "rightdown", primary = "right", secondary = "down",  label = "Right, then down" },
  { key = "rightup",   primary = "right", secondary = "up",    label = "Right, then up" },
  { key = "downleft",  primary = "down",  secondary = "left",  label = "Down, then left" },
  { key = "downright", primary = "down",  secondary = "right", label = "Down, then right" },
  { key = "upleft",    primary = "up",    secondary = "left",  label = "Up, then left" },
  { key = "upright",   primary = "up",    secondary = "right", label = "Up, then right" },
}

local DIRECTION_BY_KEY = {}
for _, direction in ipairs(ns.DIRECTIONS) do
  DIRECTION_BY_KEY[direction.key] = direction
end

-- inset = how far the border reaches inward; icons are padded past it.
ns.BORDER_STYLES = {
  { key = "tooltip", label = "Tooltip", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, inset = 3 },
  { key = "thin",    label = "Thin line", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, inset = 1 },
  { key = "thick",   label = "Thick line", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2, inset = 2 },
  { key = "none",    label = "None", edgeFile = nil, edgeSize = 0, inset = 0 },
}

local BORDER_BY_KEY = {}
for _, style in ipairs(ns.BORDER_STYLES) do
  BORDER_BY_KEY[style.key] = style
end

local function currentBorder()
  return BORDER_BY_KEY[ns.layout and ns.layout.borderStyle] or BORDER_BY_KEY.tooltip
end

-- Combines one vertical and one horizontal direction into an anchor point.
local function corner(a, b)
  local vertical, horizontal
  for _, d in ipairs({ a, b }) do
    if d == "up" then vertical = "TOP"
    elseif d == "down" then vertical = "BOTTOM"
    elseif d == "left" then horizontal = "LEFT"
    else horizontal = "RIGHT" end
  end
  return vertical .. horizontal
end

--------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------

local main = CreateFrame("Button", "ButtonBayMain", UIParent, "BackdropTemplate")
main:SetSize(32, 32)
main:SetFrameStrata("MEDIUM")
main:SetFrameLevel(10)
main:SetClampedToScreen(true)
main:SetMovable(true)
main:RegisterForClicks("LeftButtonUp")
main:SetPoint("CENTER")

-- Logo: a 2x2 grid of tiles ("a bunch of buttons"), drawn in code so it
-- stays crisp at any scale and needs no image file. With the button count
-- on, the bottom-right tile is replaced by the count, so the number is part
-- of the logo instead of sitting on top of it.
local LOGO_TILE = 9
local LOGO_GAP = 3
local LOGO_COLOR_CLOSED = { 1, 0.82, 0, 1 }
local LOGO_COLOR_OPEN = { 1, 1, 1, 1 }

local logo = CreateFrame("Frame", nil, main)
logo:SetSize(LOGO_TILE * 2 + LOGO_GAP, LOGO_TILE * 2 + LOGO_GAP)
logo:SetPoint("CENTER")
local logoTiles = {}
for row = 0, 1 do
  for column = 0, 1 do
    local tile = logo:CreateTexture(nil, "ARTWORK")
    tile:SetSize(LOGO_TILE, LOGO_TILE)
    tile:SetPoint("TOPLEFT", column * (LOGO_TILE + LOGO_GAP), -row * (LOGO_TILE + LOGO_GAP))
    table.insert(logoTiles, tile)
  end
end
local countTile = logoTiles[4]

local countText = logo:CreateFontString(nil, "OVERLAY")
countText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
countText:SetPoint("CENTER", countTile, "CENTER", 0.5, 0)
countText:Hide()

local function setLogoCount(count)
  countTile:SetShown(not count)
  countText:SetShown(count ~= nil)
  if count then
    countText:SetText(tostring(count))
  end
end

local function colorLogo(open)
  local color = open and LOGO_COLOR_OPEN or LOGO_COLOR_CLOSED
  for _, tile in ipairs(logoTiles) do
    tile:SetColorTexture(unpack(color))
  end
  countText:SetTextColor(unpack(color))
end
colorLogo(false)

local highlight = main:CreateTexture(nil, "HIGHLIGHT")
highlight:SetPoint("TOPLEFT", 4, -4)
highlight:SetPoint("BOTTOMRIGHT", -4, 4)
highlight:SetColorTexture(1, 1, 1, 0.15)

-- The panel is parented to UIParent (not the dock button) so the logo and
-- the panel can be scaled independently. It is still anchored to the button.
local container = CreateFrame("Frame", "ButtonBayPanel", UIParent, "BackdropTemplate")
container:SetFrameStrata("MEDIUM")
container:SetFrameLevel(main:GetFrameLevel() + 1)
container:SetClampedToScreen(true)
container:EnableMouse(true)
container:Hide()
container:SetScript("OnShow", function() colorLogo(true) end)
container:SetScript("OnHide", function() colorLogo(false) end)

Dock.main = main
Dock.container = container

--------------------------------------------------------------------------------
-- Appearance (per Edit Mode layout)
--------------------------------------------------------------------------------

function Dock:ApplyAppearance()
  local settings = ns.layout
  local border = currentBorder()
  local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = border.edgeFile,
    edgeSize = border.edgeSize,
    insets = { left = border.inset, right = border.inset, top = border.inset, bottom = border.inset },
  }
  local bg, edge = settings.backgroundColor, settings.borderColor
  for _, frame in ipairs({ main, container }) do
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    if border.edgeFile then
      frame:SetBackdropBorderColor(edge.r, edge.g, edge.b, edge.a)
    end
  end
end

--------------------------------------------------------------------------------
-- Collected buttons and their order
--------------------------------------------------------------------------------

local collected = {}
local adopted = {}
local shownButtons = {}
Dock.collected = collected

local function noop() end

local layoutQueued = false
local function queueLayout()
  if layoutQueued then
    return
  end
  layoutQueued = true
  C_Timer.After(0, function()
    layoutQueued = false
    Dock:UpdateLayout()
  end)
end

local function displayName(button)
  local name = button:GetName() or ""
  return (name:gsub("^LibDBIcon10_", ""))
end

-- Arranged buttons come first, in your order; anything new goes after them,
-- alphabetically.
local function sortCollected()
  local rank = {}
  for index, name in ipairs(ns.GetOrder()) do
    rank[name] = index
  end
  table.sort(collected, function(a, b)
    local ra = rank[a:GetName() or ""] or math.huge
    local rb = rank[b:GetName() or ""] or math.huge
    if ra ~= rb then
      return ra < rb
    end
    return displayName(a):lower() < displayName(b):lower()
  end)
end

local function saveOrder()
  local order = {}
  for _, button in ipairs(collected) do
    local name = button:GetName()
    if name then
      table.insert(order, name)
    end
  end
  ns.SetOrder(order)
end

function Dock:ResetOrder()
  ns.SetOrder({})
  sortCollected()
  self:UpdateLayout()
end

-- Re-sorts after switching between per-character and shared order.
function Dock:ApplyOrder()
  sortCollected()
  self:UpdateLayout()
end

-- LibDBIcon pins its buttons' level with SetFixedFrameLevel; unlock, change,
-- and lock again so nothing else can move them under the dock's background.
local function setButtonLevel(button, level)
  if button.SetFixedFrameStrata then
    button:SetFixedFrameStrata(false)
  end
  if button.SetFixedFrameLevel then
    button:SetFixedFrameLevel(false)
  end
  button:SetFrameStrata(container:GetFrameStrata())
  button:SetFrameLevel(level)
  if button.SetFixedFrameStrata then
    button:SetFixedFrameStrata(true)
  end
  if button.SetFixedFrameLevel then
    button:SetFixedFrameLevel(true)
  end
end

local BUTTON_LEVEL_OFFSET = 2
local DRAGGED_LEVEL_OFFSET = 20

function Dock:IsAdopted(button)
  return adopted[button] == true
end

function Dock:Adopt(button)
  if adopted[button] then
    return false
  end
  adopted[button] = true
  table.insert(collected, button)

  SetParent(button, container)
  setButtonLevel(button, container:GetFrameLevel() + BUTTON_LEVEL_OFFSET)
  if button.SetIgnoreParentScale then
    button:SetIgnoreParentScale(false)
  end
  -- Icons sit at their natural size; the panel's scale sizes them.
  SetScale(button, 1)

  -- LibDBIcon-style buttons drag around the minimap edge; that makes no sense
  -- inside the dock.
  button:SetScript("OnDragStart", nil)
  button:SetScript("OnDragStop", nil)

  -- Keep other addons from moving the button back out of the dock.
  button.ClearAllPoints = noop
  button.SetPoint = noop
  button.SetAllPoints = noop
  button.SetParent = noop

  -- LibDBIcon can fade buttons out until you hover the minimap. In the dock
  -- they should always be visible.
  SetAlpha(button, 1)
  hooksecurefunc(button, "SetAlpha", function(self, alpha)
    if alpha and alpha < 1 then
      SetAlpha(self, 1)
    end
  end)
  if type(button.fadeOut) == "table" and type(button.fadeOut.Play) == "function" then
    hooksecurefunc(button.fadeOut, "Play", function(animation)
      animation:Stop()
      SetAlpha(button, 1)
    end)
  end

  hooksecurefunc(button, "Show", queueLayout)
  hooksecurefunc(button, "Hide", queueLayout)
  if button.SetShown then
    hooksecurefunc(button, "SetShown", queueLayout)
  end

  sortCollected()
  queueLayout()
  return true
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

local arranging = false
local draggedButton
local handles = {}

function Dock:UpdateLayout()
  local settings = ns.layout
  if not settings then
    return
  end

  local direction = DIRECTION_BY_KEY[settings.direction] or DIRECTION_BY_KEY.leftdown
  local p = VECTORS[direction.primary]
  local q = VECTORS[direction.secondary]
  local perRow = math.max(1, settings.perRow)
  local padding = currentBorder().inset + 3

  wipe(shownButtons)
  local cell = 0
  for _, button in ipairs(collected) do
    if button:IsShown() then
      table.insert(shownButtons, button)
      cell = math.max(cell, button:GetWidth(), button:GetHeight())
    end
  end
  if cell == 0 then
    cell = FALLBACK_CELL
  end

  setLogoCount(ns.db.showButtonCount and #shownButtons > 0 and #shownButtons or nil)

  local count = math.max(1, #shownButtons)
  local columns = math.min(count, perRow)
  local rows = math.ceil(count / perRow)
  local alongPrimary = padding * 2 + columns * cell + (columns - 1) * GAP
  local alongSecondary = padding * 2 + rows * cell + (rows - 1) * GAP

  if p[1] ~= 0 then
    container:SetSize(alongPrimary, alongSecondary)
  else
    container:SetSize(alongSecondary, alongPrimary)
  end

  -- The panel corner touching the dock button; icons are laid out from there,
  -- moving away from the dock button.
  local origin = corner(OPPOSITE[direction.primary], OPPOSITE[direction.secondary])
  local mainPoint = corner(direction.primary, OPPOSITE[direction.secondary])
  container:ClearAllPoints()
  container:SetPoint(origin, main, mainPoint, p[1] * GAP, p[2] * GAP)

  for index, button in ipairs(shownButtons) do
    -- The icon being dragged follows the cursor instead of its slot.
    if button ~= draggedButton then
      local column = (index - 1) % perRow
      local row = math.floor((index - 1) / perRow)
      local a = padding + column * (cell + GAP) + cell / 2
      local b = padding + row * (cell + GAP) + cell / 2
      ClearAllPoints(button)
      SetPoint(button, "CENTER", container, origin,
        p[1] * a + q[1] * b, p[2] * a + q[2] * b)
    end
  end

  if arranging then
    Dock:UpdateHandles()
  end
end

--------------------------------------------------------------------------------
-- Drag to reorder
--
-- While the settings dialog is open, an invisible handle sits on top of every
-- icon. Dragging a handle moves its icon; the other icons slide out of the way.
-- The handles also keep clicks from reaching the real buttons, so arranging
-- never triggers an addon by accident.
--------------------------------------------------------------------------------

local reorderDriver = CreateFrame("Frame")
local reorderSlots

local function cursorOnScreen()
  return GetCursorPosition()
end

local function nearestSlot(x, y)
  local best, bestDistance
  for index, slot in ipairs(reorderSlots) do
    local dx, dy = slot[1] - x, slot[2] - y
    local distance = dx * dx + dy * dy
    if not bestDistance or distance < bestDistance then
      best, bestDistance = index, distance
    end
  end
  return best
end

local function indexOf(list, value)
  for index, item in ipairs(list) do
    if item == value then
      return index
    end
  end
end

local function updateReorder()
  if not IsMouseButtonDown("LeftButton") then
    Dock:StopReorder()
    return
  end

  local x, y = cursorOnScreen()
  local scale = draggedButton:GetEffectiveScale()
  ClearAllPoints(draggedButton)
  SetPoint(draggedButton, "CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

  local target = shownButtons[nearestSlot(x, y)]
  if target and target ~= draggedButton then
    local from = indexOf(collected, draggedButton)
    local to = indexOf(collected, target)
    table.remove(collected, from)
    table.insert(collected, to, draggedButton)
    Dock:UpdateLayout()
  end
end

function Dock:StartReorder(button)
  if draggedButton then
    return
  end
  -- Remember where every slot is on screen; the grid shape doesn't change
  -- while dragging, only which icon sits in which slot.
  reorderSlots = {}
  for index, shown in ipairs(shownButtons) do
    local x, y = shown:GetCenter()
    local scale = shown:GetEffectiveScale()
    reorderSlots[index] = { x * scale, y * scale }
  end
  draggedButton = button
  setButtonLevel(button, container:GetFrameLevel() + DRAGGED_LEVEL_OFFSET)
  reorderDriver:SetScript("OnUpdate", updateReorder)
end

function Dock:StopReorder()
  if not draggedButton then
    return
  end
  local button = draggedButton
  draggedButton = nil
  reorderDriver:SetScript("OnUpdate", nil)
  setButtonLevel(button, container:GetFrameLevel() + BUTTON_LEVEL_OFFSET)
  saveOrder()
  self:UpdateLayout()
end

local function getHandle(button)
  local handle = handles[button]
  if handle then
    return handle
  end
  handle = CreateFrame("Frame", nil, container)
  handle:SetAllPoints(button)
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetFrameStrata(container:GetFrameStrata())
  handle:SetFrameLevel(container:GetFrameLevel() + DRAGGED_LEVEL_OFFSET + 5)

  local glow = handle:CreateTexture(nil, "OVERLAY")
  glow:SetAllPoints()
  glow:SetColorTexture(1, 0.82, 0, 0.25)
  glow:Hide()

  handle:SetScript("OnEnter", function(self)
    glow:Show()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(displayName(button))
    GameTooltip:AddLine("Drag to change the order.", 1, 1, 1)
    GameTooltip:Show()
  end)
  handle:SetScript("OnLeave", function()
    glow:Hide()
    GameTooltip:Hide()
  end)
  handle:SetScript("OnDragStart", function()
    GameTooltip:Hide()
    Dock:StartReorder(button)
  end)
  handle:SetScript("OnDragStop", function()
    Dock:StopReorder()
  end)

  handles[button] = handle
  return handle
end

function Dock:UpdateHandles()
  for _, button in ipairs(collected) do
    local show = arranging and button:IsShown()
    if show then
      getHandle(button):Show()
    elseif handles[button] then
      handles[button]:Hide()
    end
  end
end

function Dock:SetArranging(enabled)
  arranging = enabled and true or false
  if not arranging then
    self:StopReorder()
  end
  self:UpdateHandles()
end

--------------------------------------------------------------------------------
-- Position and scale (per Edit Mode layout)
--------------------------------------------------------------------------------

function Dock:ApplyPosition()
  local settings = ns.layout
  local scale = settings.logoScale / 100
  main:SetScale(scale)
  container:SetScale(settings.dockScale / 100)
  main:ClearAllPoints()
  if settings.x and settings.y then
    main:SetPoint("CENTER", UIParent, "BOTTOMLEFT", settings.x / scale, settings.y / scale)
  else
    main:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

-- Stores the dock button's center, in UIParent coordinates, so changing the
-- scale later grows/shrinks the dock around the same spot.
function Dock:SavePosition()
  local x, y = main:GetCenter()
  if not x then
    return
  end
  local scale = main:GetScale()
  ns.layout.x = x * scale
  ns.layout.y = y * scale
  self:ApplyPosition()
end

function Dock:ResetPosition()
  ns.layout.x = nil
  ns.layout.y = nil
  self:ApplyPosition()
end

function Dock:Refresh()
  self:ApplyAppearance()
  self:ApplyPosition()
  self:UpdateLayout()
end

ns.Listen("LAYOUT_CHANGED", function()
  Dock:Refresh()
end)

--------------------------------------------------------------------------------
-- Opening and closing
--------------------------------------------------------------------------------

local previewing = false

local function updateVisibility()
  container:SetShown(main:IsShown() and (previewing or ns.db.isOpen))
end

function Dock:SetOpen(open)
  ns.db.isOpen = open and true or false
  updateVisibility()
end

function Dock:Toggle()
  ns.Collector:Scan()
  self:SetOpen(not container:IsShown())
end

-- While the settings dialog is open the dock stays open, so you can see what
-- the settings do and drag icons around.
function Dock:SetPreview(enabled)
  previewing = enabled and true or false
  updateVisibility()
end

main:HookScript("OnShow", updateVisibility)
main:HookScript("OnHide", updateVisibility)

-- Optional: fade the logo out unless the mouse is over it. It stays visible
-- whenever it's in use (dock open, settings open, Edit Mode) so you can
-- always find it. It's still clickable while invisible.
local LOGO_FADE_PER_SECOND = 5

local function logoWanted()
  if not ns.db or not ns.db.hideLogoUntilHover then
    return true
  end
  return main:IsMouseOver()
    or container:IsShown()
    or previewing
    or (ns.EditMode ~= nil and ns.EditMode.active)
end

main:SetScript("OnUpdate", function(self, elapsed)
  local target = logoWanted() and 1 or 0
  local alpha = self:GetAlpha()
  if alpha ~= target then
    local step = LOGO_FADE_PER_SECOND * elapsed
    if alpha < target then
      self:SetAlpha(math.min(target, alpha + step))
    else
      self:SetAlpha(math.max(target, alpha - step))
    end
  end
end)

main:SetScript("OnClick", function()
  if IsControlKeyDown() then
    ns.EditMode:ToggleSettings()
  else
    Dock:Toggle()
  end
end)

main:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(ns.TITLE)
  GameTooltip:AddLine("Click to show or hide your minimap buttons.", 1, 1, 1)
  GameTooltip:AddLine("Ctrl-click to open settings.", 1, 1, 1)
  if ns.EditMode and ns.EditMode.supported then
    GameTooltip:AddLine("Move the dock in Edit Mode.", 0.7, 0.7, 0.7)
  else
    GameTooltip:AddLine("Alt-drag to move.", 0.7, 0.7, 0.7)
  end
  GameTooltip:Show()
end)

main:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

container:SetScript("OnUpdate", function(self, elapsed)
  if not ns.db.autoClose or previewing then
    self.away = 0
    return
  end
  if self:IsMouseOver() or main:IsMouseOver() then
    self.away = 0
  else
    self.away = (self.away or 0) + elapsed
    if self.away >= ns.db.autoCloseDelay then
      self.away = 0
      Dock:SetOpen(false)
    end
  end
end)

--------------------------------------------------------------------------------
-- Small extras
--------------------------------------------------------------------------------

function Dock:ApplyCompartmentVisibility()
  local compartment = _G.AddonCompartmentFrame
  if not compartment then
    return
  end
  if ns.db.hideCompartment then
    compartment:Hide()
  else
    compartment:Show()
  end
end

ns.Listen("DB_READY", function()
  local compartment = _G.AddonCompartmentFrame
  if compartment then
    compartment:HookScript("OnShow", function(self)
      if ns.db.hideCompartment then
        self:Hide()
      end
    end)
  end
end)

ns.Listen("LOGIN", function()
  Dock:Refresh()
  Dock:SetOpen(ns.db.isOpen)
  if ns.db.hideCompartment then
    Dock:ApplyCompartmentVisibility()
  end
end)

-- Pet battles take over the whole screen; get out of the way.
ns.On("PET_BATTLE_OPENING_START", function() main:Hide() end)
ns.On("PET_BATTLE_CLOSE", function() main:Show() end)
