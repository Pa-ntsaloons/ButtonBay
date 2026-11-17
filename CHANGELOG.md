# Changelog

## Unreleased

- Logo colors: pick the tile color for the closed and open dock in Edit Mode (per layout).
- Button order: choose how icons fill the dock (e.g. left to right, top to bottom) separately from which way the dock opens. "Match direction" keeps the old behavior.
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
