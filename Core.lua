local ADDON, ns = ...

ns.ADDON = ADDON
ns.TITLE = "Button Bay"

--------------------------------------------------------------------------------
-- Messaging
--------------------------------------------------------------------------------

function ns.Print(...)
  print("|cff33ccff" .. ns.TITLE .. ":|r", ...)
end

--------------------------------------------------------------------------------
-- Game events
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

-- Returns false when the client doesn't know the event, so optional features
-- (pet battles, edit mode layouts) can degrade quietly on older clients.
function ns.On(event, handler)
  if not eventHandlers[event] then
    if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
      return false
    end
    eventHandlers[event] = {}
  end
  table.insert(eventHandlers[event], handler)
  return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  for _, handler in ipairs(eventHandlers[event]) do
    handler(...)
  end
end)

--------------------------------------------------------------------------------
-- Internal messages between modules
--------------------------------------------------------------------------------

local listeners = {}

function ns.Listen(message, handler)
  listeners[message] = listeners[message] or {}
  table.insert(listeners[message], handler)
end

function ns.Fire(message, ...)
  for _, handler in ipairs(listeners[message] or {}) do
    handler(...)
  end
end

--------------------------------------------------------------------------------
-- Saved variables
--
-- Everything you can change in the Edit Mode dialog is stored per Edit Mode
-- layout, just like Blizzard's own frames. The rest is account-wide.
--------------------------------------------------------------------------------

local ACCOUNT_DEFAULTS = {
  autoClose = false,
  autoCloseDelay = 0.75,  -- seconds the mouse must be away before closing
  hideLogoUntilHover = false,
  showButtonCount = false,
  perCharacterOrder = true,
  hideCompartment = false,
  lastLayout = "Default",
  whitelist = {},
  blacklist = {},
  layouts = {},
  -- Button names in the order you arranged them. Buttons not listed here
  -- (e.g. from newly installed addons) go after these, alphabetically.
  -- Used when perCharacterOrder is off; otherwise each character has its own
  -- copy in ButtonBayCharDB.
  order = {},
}

-- x / y are the dock button's center in UIParent coordinates; nil means
-- "never moved", which puts it in the middle of the screen.
ns.LAYOUT_DEFAULTS = {
  direction = "leftdown",
  fillOrder = "auto",  -- see ns.FILL_ORDERS; "auto" follows direction
  perRow = 5,
  logoScale = 100,  -- the dock button you click
  dockScale = 100,  -- the panel and the icons in it
  borderStyle = "tooltip",
  backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 },
  borderColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
  logoColor = { r = 1, g = 0.82, b = 0, a = 1 },
}

-- Older versions stored the sizes under different names, and had a separate
-- icon size. Fold everything into the current settings so nothing jumps.
local function migrateLayout(entry)
  if entry.scale ~= nil then
    entry.logoScale = entry.logoScale or entry.scale
    entry.scale = nil
  end
  local iconScale = entry.iconScale or entry.buttonScale
  if iconScale ~= nil then
    local combined = (entry.dockScale or 100) * iconScale / 100
    entry.dockScale = math.max(50, math.min(200, math.floor(combined / 5 + 0.5) * 5))
    entry.iconScale = nil
    entry.buttonScale = nil
  end
end

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for k, v in pairs(value) do
    copy[k] = deepCopy(v)
  end
  return copy
end

local function fillDefaults(target, defaults)
  for key, default in pairs(defaults) do
    if type(target[key]) ~= type(default) then
      target[key] = deepCopy(default)
    end
  end
end

-- Returns the settings table for an Edit Mode layout, creating it on first use.
-- A brand-new layout (new, copied or renamed in Edit Mode) inherits the
-- current settings so the dock doesn't jump when you switch to it.
function ns.GetLayoutSettings(name)
  local entry = ns.db.layouts[name]
  if not entry then
    entry = deepCopy(ns.layout or {})
    ns.db.layouts[name] = entry
  end
  migrateLayout(entry)
  fillDefaults(entry, ns.LAYOUT_DEFAULTS)
  return entry
end

-- The button order in use: this character's, or the shared one.
function ns.GetOrder()
  return ns.db.perCharacterOrder and ns.charDB.order or ns.db.order
end

function ns.SetOrder(order)
  if ns.db.perCharacterOrder then
    ns.charDB.order = order
  else
    ns.db.order = order
  end
end

function ns.SetActiveLayout(name)
  if name == ns.layoutName and ns.layout then
    return
  end
  ns.layoutName = name
  ns.layout = ns.GetLayoutSettings(name)
  ns.db.lastLayout = name
  ns.Fire("LAYOUT_CHANGED")
end

ns.On("ADDON_LOADED", function(loaded)
  if loaded ~= ADDON then
    return
  end
  if type(ButtonBayDB) ~= "table" then
    ButtonBayDB = {}
  end
  ns.db = ButtonBayDB
  fillDefaults(ns.db, ACCOUNT_DEFAULTS)
  ns.db.isOpen = nil  -- older versions reopened the dock after a reload

  if type(ButtonBayCharDB) ~= "table" then
    ButtonBayCharDB = {}
  end
  ns.charDB = ButtonBayCharDB
  -- A character's first order is the shared one, so switching to
  -- per-character order (or logging in a new character) changes nothing.
  if type(ns.charDB.order) ~= "table" then
    ns.charDB.order = deepCopy(ns.db.order)
  end

  ns.SetActiveLayout(ns.db.lastLayout)
  ns.Fire("DB_READY")
end)

ns.On("PLAYER_LOGIN", function()
  ns.Fire("LOGIN")
end)
