local _, ns = ...

local Collector = {}
ns.Collector = Collector

-- Name patterns that usually mean "this is an addon's minimap button".
local INCLUDE_PATTERNS = {
  "^LibDBIcon10_",
  "MinimapButton",
  "MinimapIcon",
  "[_%-]Minimap[_%-]",
  "Minimap$",
}

-- Map pins and similar minimap children that aren't buttons.
local EXCLUDE_PATTERNS = {
  "^HandyNotes",
  "^TomTom",
  "^HereBeDragons",
  "^GatherMate",
  "^[Pp]in",
  "^ButtonBay",
}

local function matchesAny(name, patterns)
  for _, pattern in ipairs(patterns) do
    if name:find(pattern) then
      return true
    end
  end
  return false
end

local function isUsableFrame(frame)
  if type(frame) ~= "table" or type(frame.IsObjectType) ~= "function" then
    return false
  end
  local ok, usable = pcall(function()
    return not frame:IsForbidden() and not frame:IsProtected() and frame:IsObjectType("Frame")
  end)
  return ok and usable
end

local function frameName(frame)
  return frame.GetName and frame:GetName()
end

local function isBlacklisted(frame)
  local name = frameName(frame)
  return name ~= nil and ns.db.blacklist[name] == true
end

-- Real minimap buttons are small. Anything outside this range that matched by
-- name is some other frame (a panel, overlay or map layer).
local MIN_BUTTON_SIZE = 10
local MAX_BUTTON_SIZE = 64

local function hasButtonSize(frame)
  local width, height = frame:GetSize()
  return width and height
    and width >= MIN_BUTTON_SIZE and width <= MAX_BUTTON_SIZE
    and height >= MIN_BUTTON_SIZE and height <= MAX_BUTTON_SIZE
end

local function looksLikeMinimapButton(frame)
  local name = frameName(frame)
  if not name or not hasButtonSize(frame) then
    return false
  end
  -- Blizzard's own globals are "secure"; leave those alone.
  if issecurevariable(_G, name) then
    return false
  end
  -- Numbered children are almost always pins, not buttons.
  if name:find("%d$") and not name:find("^LibDBIcon10_") then
    return false
  end
  return matchesAny(name, INCLUDE_PATTERNS) and not matchesAny(name, EXCLUDE_PATTERNS)
end

local function tryAdopt(frame)
  if isUsableFrame(frame) and not ns.Dock:IsAdopted(frame) and not isBlacklisted(frame) then
    return ns.Dock:Adopt(frame)
  end
  return false
end

-- Resolves "Frame" or "Parent.Child.Grandchild" paths from the whitelist.
local function resolvePath(path)
  local node = _G
  for part in path:gmatch("[^.]+") do
    if type(node) ~= "table" then
      return nil
    end
    node = node[part]
  end
  return node
end

local function getLibDBIcon()
  return LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)
end

local function scanLibDBIcon()
  local lib = getLibDBIcon()
  if not lib or type(lib.GetButtonList) ~= "function" then
    return
  end
  for _, name in ipairs(lib:GetButtonList()) do
    tryAdopt(lib:GetMinimapButton(name))
  end
end

local function scanChildren(parent)
  if not parent or type(parent.GetChildren) ~= "function" then
    return
  end
  for _, child in ipairs({ parent:GetChildren() }) do
    if isUsableFrame(child) and looksLikeMinimapButton(child) then
      tryAdopt(child)
    end
  end
end

function Collector:Scan()
  if not ns.db then
    return
  end
  scanLibDBIcon()
  for path in pairs(ns.db.whitelist) do
    tryAdopt(resolvePath(path))
  end
  scanChildren(_G.Minimap)
  scanChildren(_G.MinimapBackdrop)
  scanChildren(_G.MinimapCluster)
end

Collector.ResolvePath = resolvePath

ns.Listen("LOGIN", function()
  local lib = getLibDBIcon()
  if lib and type(lib.RegisterCallback) == "function" then
    lib.RegisterCallback(Collector, "LibDBIcon_IconCreated", function(_, button)
      tryAdopt(button)
    end)
  end

  -- Many addons create their buttons during or just after login.
  Collector:Scan()
  C_Timer.After(0, function() Collector:Scan() end)
  C_Timer.After(2, function() Collector:Scan() end)
  C_Timer.After(5, function() Collector:Scan() end)
end)
