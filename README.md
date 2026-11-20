# MountGear

A standalone World of Warcraft Forever addon (interface `16001`). Click the
horse icon on the minimap or type `/mountgear`. Drag the icon around the
minimap to move it.

Both windows use classic WoW dialog textures, framed title banners, gold
headings, and action-bar-style item slots without bundled UI libraries.

Pick boots, up to two trinkets, or both. The picker shows items in your bags
or already equipped. Click a slot icon in the main window to open a separate,
automatically sized bag-style grid. Hover over an item icon to see its in-game
tooltip, then click it to save your choice. Large collections can be scrolled
with the mouse wheel. The main window also uses icons, so long item names do
not overlap controls. **Clear** leaves that slot out of the mount preset.
Picks and the icon position are saved per character.
MountGear equips the selected items when you mount and restores the gear you
were wearing when you dismount. Changes to your picks take effect on the next
ride.

If combat or a busy cursor prevents a swap, MountGear waits. If a swap still
fails (for example, an item is missing, two trinkets cannot be worn together,
or a bag slot is needed to restore an empty slot), the addon reports which
slots are affected. Fix the issue and click **Retry** in the window.

## Install

Run `Install-MountGear.ps1` from this folder on the computer with WoW Forever
installed. By default it installs to
`D:\World of Warcraft\_forever_\Interface\AddOns\MountGear`. To use another
AddOns folder:

```powershell
.\Install-MountGear.ps1 -AddOnsPath 'X:\World of Warcraft\_forever_\Interface\AddOns'
```

Enable the addon at character select or use `/reload` if it is already enabled.
In-client behavior has not yet been verified.
