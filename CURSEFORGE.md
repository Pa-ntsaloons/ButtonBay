# Button Bay

Too many addon buttons crowding your minimap? **Button Bay** gathers them into one small dock. Click the logo to show your buttons, click again to tuck them away.

You move and style the dock in **Blizzard's Edit Mode**, just like the rest of your UI.

## Features

- **Collects buttons automatically.** It picks up every LibDBIcon button plus anything that looks like a minimap button, including buttons that addons create after you log in.
- **Edit Mode support.** Select *Button Bay* in Edit Mode to drag the dock and open its settings. It snaps to other Edit Mode frames and the center of the screen (hold **Shift** to place it freely). Settings are saved per Edit Mode layout, so each layout can have its own dock.
- **Drag to reorder.** While the settings are open, drag icons in the dock to arrange them however you like. Each character keeps its own order, or you can share one order across all of them.
- **Your layout:** 8 growth directions, buttons per row, and separate sizes for the logo and the dock.
- **Your look:** border style, background and border colors, and opacity, down to fully transparent.
- **Button count (optional):** the logo can show how many buttons are in the dock.
- **Extras:** close automatically when the mouse leaves, hide the logo until you hover it, and hide Blizzard's addon compartment button.

## Opening the settings

- Open **Edit Mode** and click the dock, or
- **Ctrl-click** the dock's logo, or
- Type `/bb config` (or `/buttonbay`)

## Commands

| Command | What it does |
|---|---|
| `/bb list` | Lists collected, added and ignored buttons |
| `/bb add <FrameName>` | Collects a button the dock missed |
| `/bb remove <FrameName>` | Stops collecting a button you added |
| `/bb ignore <FrameName>` | Leaves a button on the minimap |
| `/bb unignore <FrameName>` | Collects an ignored button again |
| `/bb reset` | Moves the dock back to the center of the screen |

**Tip:** to find a button's frame name, hover over it and type `/fstack`.

## Missing a button?

Most buttons are found automatically. If one isn't, use `/bb add` with its frame name. If a button you'd rather keep on the minimap ends up in the dock, use `/bb ignore`.
