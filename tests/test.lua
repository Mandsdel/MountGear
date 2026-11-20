local addon, frame, timers, worn, bags, mounted, taxi, combat, cursor, blocked, swaps, warnings
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

print = output
print("MountGear flight-path and recovery checks passed")
