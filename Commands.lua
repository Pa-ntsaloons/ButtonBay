local _, ns = ...

local function sortedKeys(map)
  local keys = {}
  for key in pairs(map) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

local function printHelp()
  ns.Print("commands:")
  print("  /bb list - show collected, added and ignored buttons")
  print("  /bb add <FrameName> - collect a button the dock missed")
  print("  /bb remove <FrameName> - stop collecting an added button")
  print("  /bb ignore <FrameName> - never collect this button")
  print("  /bb unignore <FrameName> - collect this button again")
  print("  /bb reset - move the dock back to the screen center")
  print("  /bb config - open settings (Edit Mode does this too)")
end

local commands = {}

function commands.list()
  ns.Print("collected buttons:")
  for _, button in ipairs(ns.Dock.collected) do
    print("  " .. (button:GetName() or "<unnamed>"))
  end
  if next(ns.db.whitelist) then
    ns.Print("added manually:")
    for _, name in ipairs(sortedKeys(ns.db.whitelist)) do
      print("  " .. name)
    end
  end
  if next(ns.db.blacklist) then
    ns.Print("ignored:")
    for _, name in ipairs(sortedKeys(ns.db.blacklist)) do
      print("  " .. name)
    end
  end
end

function commands.add(name)
  if not name then
    return printHelp()
  end
  ns.db.whitelist[name] = true
  ns.db.blacklist[name] = nil
  ns.Collector:Scan()
  if ns.Collector.ResolvePath(name) then
    ns.Print(name .. " is now collected.")
  else
    ns.Print(name .. " was added, but no frame by that name exists yet.")
  end
end

function commands.remove(name)
  if not name or not ns.db.whitelist[name] then
    return ns.Print("That button wasn't added manually.")
  end
  ns.db.whitelist[name] = nil
  ns.Print(name .. " removed. /reload to put it back on the minimap.")
end

function commands.ignore(name)
  if not name then
    return printHelp()
  end
  ns.db.blacklist[name] = true
  ns.db.whitelist[name] = nil
  ns.Print(name .. " will be ignored. /reload to put it back on the minimap.")
end

function commands.unignore(name)
  if not name or not ns.db.blacklist[name] then
    return ns.Print("That button isn't being ignored.")
  end
  ns.db.blacklist[name] = nil
  ns.Collector:Scan()
  ns.Print(name .. " will be collected again.")
end

function commands.reset()
  ns.Dock:ResetPosition()
  ns.Print("Dock moved back to the center of the screen.")
end

function commands.config()
  local dialog = ns.EditMode.Dialog
  if dialog:IsShown() then
    dialog:Hide()
  else
    dialog:Open()
  end
end

SLASH_BUTTONBAY1 = "/bb"
SLASH_BUTTONBAY2 = "/buttonbay"
SlashCmdList.BUTTONBAY = function(input)
  local command, argument = strtrim(input or ""):match("^(%S*)%s*(.-)$")
  local handler = commands[(command or ""):lower()]
  if handler then
    handler(argument ~= "" and argument or nil)
  else
    printHelp()
  end
end
