local addon, frame, timers, worn, bags, mounted, taxi, combat, cursor, blocked, swaps, warnings, clock
local originals = { [8] = "item:1", [13] = "item:2", [14] = "item:3" }
local picks = { [8] = "item:4", [13] = "item:5", [14] = "item:6" }
local output = print

local function copy(items)
    local result = {}
    for slot, link in pairs(items) do result[slot] = link end
    return result
end

local function loadAddon(saved)
    addon, timers, warnings = {}, {}, {}
    MountGearDB = saved
    addon.createOptions = function() end
    addon.registerSlashCommand = function() end
    assert(loadfile("Core.lua"))("MountGear", addon)
    frame.OnEvent(frame, "ADDON_LOADED", "MountGear")
    frame.OnEvent(frame, "PLAYER_LOGIN")
end

local function setup()
    worn, bags = copy(originals), { picks[8], picks[13], picks[14] }
    mounted, taxi, combat, cursor, blocked, swaps = false, false, false, nil, false, 0
    clock = 0
    IsInventoryItemLocked = nil
    C_Container, C_Item = nil, nil
    NUM_BAG_SLOTS = 0
    CreateFrame = function()
        frame = {
            RegisterEvent = function() end,
            SetScript = function(self, event, callback) self[event] = callback end,
        }
        return frame
    end
    GetItemInfoInstant = function() end
    GetContainerNumSlots = function() return 6 end
    GetContainerItemLink = function(_, slot) return bags[slot] end
    GetContainerItemInfo = function() return { isLocked = false } end
    GetContainerNumFreeSlots = function() return 3, 0 end
    GetInventoryItemLink = function(_, slot) return worn[slot] end
    PickupContainerItem = function(_, slot)
        if blocked or taxi or combat then return end
        bags[slot], cursor = cursor, bags[slot]
    end
    PickupInventoryItem = function(slot)
        swaps = swaps + 1
        if blocked or taxi or combat then return end
        worn[slot], cursor = cursor, worn[slot]
    end
    CursorHasItem = function() return cursor ~= nil end
    GetCursorInfo = function() return cursor and "item" end
    ClearCursor = function() assert(cursor == nil, "Unexpected item left on cursor") end
    IsMounted = function() return mounted end
    UnitOnTaxi = function(unit) assert(unit == "player"); return taxi end
    InCombatLockdown = function() return combat end
    GetTime = function() return clock end
    UnitAffectingCombat = function() return false end
    C_Timer = { After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
    end }
    print = function(message) warnings[#warnings + 1] = message end
    loadAddon({ picks = copy(picks) })
end

local function tick()
    assert(#timers > 0, "Expected a pending timer")
    table.remove(timers, 1).callback()
end

local function drain()
    local count = 0
    while #timers > 0 do
        count = count + 1
        assert(count < 30, "Unexpected polling loop")
        tick()
    end
end

local function mount()
    mounted = true
    frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
    drain()
    for slot, link in pairs(picks) do assert(worn[slot] == link) end
    assert(addon.db.ride)
end

local function assertRestored()
    for slot, link in pairs(originals) do assert(worn[slot] == link) end
    assert(addon.db.ride == nil)
end

setup()
mount()
mounted = false
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
drain()
assertRestored()

-- A taxi must neither swap gear nor consume retries, regardless of IsMounted.
for _, taxiMounted in ipairs({ false, true }) do
    setup()
    mount()
    local snapshot, before = addon.db.ride, swaps
    mounted, taxi = taxiMounted, true
    frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
    for _ = 1, 10 do tick() end
    assert(swaps == before and addon.db.ride == snapshot)
    assert(addon.status == "Waiting for the flight to end." and #warnings == 0)
    addon.retry()
    tick()
    assert(swaps == before)
    -- Landing deliberately sends no mount event.
    mounted, taxi = false, false
    drain()
    assertRestored()
end

-- Reloading during a flight keeps the saved snapshot until landing.
setup()
mount()
local saved = addon.db
mounted, taxi = false, true
loadAddon(saved)
tick()
assert(addon.db.ride and #warnings == 0)
taxi = false
drain()
assertRestored()

-- Failed attempts before takeoff do not exhaust restoration after landing.
setup()
mount()
mounted, blocked = false, true
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
for _ = 1, 9 do tick() end
taxi = true
tick()
taxi, blocked = false, false
drain()
assertRestored()

-- A flight without a pending ride must not capture taxi gear as normal gear.
setup()
mounted, taxi = true, true
tick()
assert(addon.db.ride == nil and swaps == 0)
mounted, taxi = false, false
drain()
assertRestored()

-- Landing in combat still waits for combat to end.
setup()
mount()
mounted, taxi = false, true
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
tick()
taxi, combat = false, true
drain()
assert(addon.status == "Waiting for combat to end.")
combat = false
frame.OnEvent(frame, "PLAYER_REGEN_ENABLED")
drain()
assertRestored()

-- Landing with a busy cursor preserves that cursor and resumes when cleared.
setup()
mount()
mounted, taxi = false, true
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
tick()
taxi, cursor = false, "item:99"
tick()
assert(addon.status == "Waiting for the cursor to clear." and cursor == "item:99")
cursor = nil
drain()
assertRestored()

-- Clear only edits picks; Reset abandons a stale restore without moving gear.
setup()
mount()
mounted, blocked = false, true
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
drain()
addon.db.picks[8] = nil
addon.retry()
drain()
assert(addon.db.ride and addon.status:find("Couldn't restore", 1, true))
local before = swaps
addon.resetRide()
assert(not addon.db.ride and swaps == before)
assert(addon.db.picks[8] == nil and addon.db.picks[13] == picks[13])
blocked = false
worn, bags = copy(originals), { picks[8], picks[13], picks[14] }
addon.db.picks[8] = picks[8]
mount()
mounted = false
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
drain()
assertRestored()

-- Repeated failures are rate-limited without hiding the status or losing the snapshot.
setup()
mount()
mounted, blocked = false, true
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
drain()
assert(#warnings == 1 and addon.status:find("Couldn't restore", 1, true) and addon.db.ride)
clock = 30
addon.retry()
drain()
assert(#warnings == 1 and addon.status:find("Couldn't restore", 1, true) and addon.db.ride)
clock = 300
addon.retry()
drain()
assert(#warnings == 2 and addon.db.ride)
blocked = false
addon.retry()
drain()
assertRestored()

-- A different failure category still gets a warning within the cooldown.
setup()
mount()
mounted, blocked = false, true
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
drain()
assert(#warnings == 1)
IsInventoryItemLocked = function() return true end
addon.retry()
drain()
assert(#warnings == 2 and addon.status:find("Items are still locked", 1, true))
IsInventoryItemLocked, blocked = nil, false
addon.retry()
drain()
assertRestored()

for _, onTaxi in ipairs({ false, true }) do
    setup()
    mount()
    local snapshot = addon.db.ride
    mounted, taxi = not onTaxi, onTaxi
    addon.resetRide()
    assert(addon.db.ride == snapshot)
end

-- Reset also wins over an already queued restore timer.
setup()
mount()
mounted = false
addon.retry()
addon.resetRide()
local before = swaps
drain()
assert(addon.db.ride == nil and swaps == before)

setup()
UnitOnTaxi = nil
loadAddon({ picks = copy(picks) })
assert(not addon.available and #timers == 0)
assert(addon.status == "Required gear, mount, or flight-path API unavailable in this client.")

-- A temporary lock gets its own wait budget and resumes without another event.
for _, location in ipairs({ "equipped", "bag-table", "bag-legacy", "other-trinket" }) do
    setup()
    mount()
    local locked = true
    if location == "equipped" then
        IsInventoryItemLocked = function() return locked end
    elseif location == "other-trinket" then
        worn[13], worn[14] = originals[14], originals[13]
        bags[2], bags[3] = picks[13], picks[14]
        IsInventoryItemLocked = function(slot) return locked and slot == 14 end
    else
        GetContainerItemInfo = function()
            if location == "bag-table" then return { isLocked = locked } end
            return nil, nil, locked
        end
        -- Core captures the bag API when loaded.
        loadAddon(addon.db)
    end
    mounted = false
    frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
    for _ = 1, 5 do tick() end
    assert(addon.status == "Waiting for equipment or bag items to unlock.")
    assert(#warnings == 0 and addon.db.ride)
    locked = false
    drain()
    assertRestored()
end

-- Permanent locks stop after exactly 20 half-second waits, and Retry can recover.
setup()
mount()
IsInventoryItemLocked = function() return true end
mounted = false
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
tick()
for _ = 1, 20 do
    assert(#timers == 1 and timers[1].delay == 0.5)
    tick()
end
assert(#timers == 0 and #warnings == 1 and addon.db.ride)
assert(addon.status:find("Items are still locked", 1, true))
IsInventoryItemLocked = nil
addon.retry()
drain()
assertRestored()

-- An originally empty slot can wait for an available bag position to unlock.
setup()
worn[8] = nil
mount()
IsInventoryItemLocked = function(slot) return slot == 13 or slot == 14 end
local locked = true
GetContainerItemInfo = function() return { isLocked = locked } end
loadAddon(addon.db)
mounted = false
frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
for _ = 1, 4 do tick() end
assert(addon.status == "Waiting for equipment or bag items to unlock.")
locked = false
IsInventoryItemLocked = nil
drain()
assert(worn[8] == nil and worn[13] == originals[13] and worn[14] == originals[14])
assert(addon.db.ride == nil)

-- Bad snapshots remain intact, block swaps, and can be abandoned using Reset.
for _, ride in ipairs({
    true, false, 42, "old-data", {},
    { mounted = true, original = {} },
    { mounted = {}, original = false },
    { mounted = { [8] = 123 }, original = { [8] = originals[8] } },
    { mounted = { [8] = picks[8] }, original = {} },
    { mounted = { [13] = picks[13] }, original = { [13] = originals[13] } },
    { mounted = {}, original = { [8] = true } },
    { mounted = {}, original = { [8] = "" } },
    { mounted = {}, original = { [8] = "not-an-item" } },
    { mounted = {}, original = { [99] = originals[8] } },
}) do
    setup()
    loadAddon({ picks = copy(picks), ride = ride })
    drain()
    assert(addon.db.ride == ride and swaps == 0)
    assert(addon.status:find("Saved restore data is invalid", 1, true))
    assert(#warnings == 1)
    addon.retry()
    drain()
    assert(#warnings == 1 and swaps == 0)
    addon.resetRide()
    assert(addon.db.ride == nil)
    mount()
    mounted = false
    frame.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
    drain()
    assertRestored()
end

-- Invalid picks are reported and cleared without discarding a good restore.
setup()
mount()
local savedRide = addon.db.ride
mounted = false
loadAddon({ picks = { [8] = true, [13] = {}, [14] = "bad", [99] = "item:7" },
    ride = savedRide })
assert(next(addon.db.picks) == nil and #warnings == 4)
drain()
assertRestored()

for _, invalid in ipairs({ true, 123, "bad" }) do
    setup()
    loadAddon(invalid)
    drain()
    assert(type(addon.db) == "table" and next(addon.db.picks) == nil and #warnings == 1)
    setup()
    loadAddon({ picks = invalid })
    drain()
    assert(next(addon.db.picks) == nil and #warnings == 1)
end

setup()
local link = "|cff00ff00|Hitem:4:0:0:0|h[Boots]|h|r"
loadAddon({ picks = { [8] = link } })
drain()
assert(addon.db.picks[8] == link and #warnings == 0)

print = output
print("MountGear flight-path, lock-wait, and saved-state recovery checks passed")
