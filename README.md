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

In battlegrounds, MountGear pauses all automatic and Retry-triggered gear
swaps. Any pending restore snapshot is preserved, and Reset is unavailable
until you leave. After leaving, it resumes using your current mount state:
mounted gear if mounted, or the saved original gear if dismounted. It does not
swap to normal gear on entry, so change gear beforehand if needed. Other
instance types are unaffected.

During a flight-path ride, MountGear pauses gear swaps and checks for landing
once per second. It keeps the original gear snapshot and starts with fresh swap
attempts after landing, even if no further mount-change event arrives.
If combat or a busy cursor prevents a swap, MountGear waits. If a swap still
fails (for example, an item is missing, two trinkets cannot be worn together,
or a bag slot is needed to restore an empty slot), the window reports which
slots are affected without posting swap failures to chat. Fix the issue and
click **Retry** in the window. Saved-data and initialization warnings are
still reported in chat.

Temporary equipment and bag-item locks are checked every half-second, for up
to 20 checks per operation, without using the failed-swap retry budget.
Restoration resumes automatically if they unlock during this window. If they
stay locked, MountGear reports that specifically; wait and click **Retry**.

Saved settings are validated before use. Invalid mount picks are cleared with
a warning. An invalid restore snapshot is kept intact and automatic swaps are
stopped with a recovery message, rather than risking the wrong equipment.
Use **Reset** only when ready to abandon that snapshot.

If a pending restore is stuck or its saved items are no longer available,
dismount and click **Reset**, then confirm. This forgets the pending restore
without moving any equipment or clearing your mount picks. Equip your normal
gear manually before mounting again so it becomes the next restore snapshot.
Reset is blocked while mounted or on a flight path. **Clear** only changes a
slot's mount preset; it does not discard a pending restore.

## Local checks

The standalone regression checks mock equipment, timers, and flight-path state;
they do not verify WoW Forever API behavior. With Node.js available, run from
this folder:

```powershell
npx --yes --package=fengari-node-cli fengari tests\test.lua
```

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
