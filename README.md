# Button Bay (WoW Forever)

Gathers your addons' minimap buttons into one small dock. Click the dock's logo to show or hide them. You move and style the dock in Blizzard's Edit Mode, like any other part of your UI.

## Features
- **Collects buttons automatically.** That includes every LibDBIcon button plus anything named like a minimap button. Buttons created later (after login, or when an addon loads late) are picked up too.
- **Edit Mode integration.** Select "Button Bay" in Edit Mode to drag the dock and open its settings. It snaps to other Edit Mode frames and to the screen's center lines (hold Shift to place it freely). Settings are saved per Edit Mode layout.
- **Drag to reorder.** While the settings are open, drag icons in the dock to rearrange them. The order is saved per character, or shared across all characters if you prefer.
- **Layout:** 8 growth directions, buttons per row, separate sizes for the logo and the dock.
- **Look:** border style, background and border colors (with opacity, down to fully transparent).
- **Button count** (optional): the logo's bottom-right tile shows how many buttons are in the dock.
- **Extras:** close when the mouse leaves (with a delay), hide the logo until hovered, hide Blizzard's addon compartment button.

## Settings
- Open Edit Mode and click the dock, or
- Ctrl-click the dock's logo, or
- `/bb config` (also `/buttonbay`)

## Commands
- `/bb list`: collected, manually added and ignored buttons
- `/bb add <FrameName>`: collect a button the dock missed
- `/bb remove <FrameName>`: stop collecting a manually added button
- `/bb ignore <FrameName>`: leave a button on the minimap
- `/bb unignore <FrameName>`: collect it again
- `/bb reset`: move the dock back to the screen center

To find a button's frame name, hover it and type `/fstack`.

## Install / update
Copy this folder to `World of Warcraft\_forever_\Interface\AddOns\ButtonBay`.
If a client patch changes the interface version, update `## Interface:` in the .toc (`/dump select(4, GetBuildInfo())` in game).
