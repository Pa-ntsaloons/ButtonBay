# Changelog

## 1.1.0 – 2026-11-17

- **Logo color:** pick the color of the logo's tiles in Edit Mode (saved per layout). The logo keeps that color while the dock is open instead of turning white.
- **Button order:** choose how icons fill the dock (left to right, top to bottom, and so on), separately from the direction the dock opens. "Match direction" keeps the 1.0.0 layout.
- When the button order fills top to bottom first, "Buttons per row" sets buttons per column.
- The dock now always starts closed after a login or `/reload`.

## 1.0.0 – 2026-11-17

First release.

- Collects LibDBIcon buttons and other minimap buttons into a dock you open from its logo.
- Move and configure the dock in Blizzard's Edit Mode; settings are saved per Edit Mode layout. Snaps to other Edit Mode frames and the screen center (Shift to place freely).
- Drag icons to reorder them while settings are open. The order is saved per character by default (each character starts from the shared order), or shared across characters.
- Optional button count, shown in the logo's corner tile (off by default).
- 8 growth directions, buttons per row, separate logo and dock sizes, border style, background/border colors and opacity.
- Optional: close on mouse-out, hide the logo until hovered, hide Blizzard's addon compartment.
- `/bb` commands to add, ignore and list buttons.
