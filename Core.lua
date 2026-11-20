local _, addon = ...
local frame = CreateFrame("Frame")
local slots = { 8, 13, 14 }
addon.slots = slots
addon.labels = { [8] = "Boots", [13] = "Trinket 1", [14] = "Trinket 2" }

local container = C_Container or _G
local itemInfo = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local bagSize = container.GetContainerNumSlots or GetContainerNumSlots
local bagLink = container.GetContainerItemLink or GetContainerItemLink
local bagInfo = container.GetContainerItemInfo or GetContainerItemInfo
local bagFree = container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
local pickupBag = container.PickupContainerItem or PickupContainerItem
local db, timerSet, waitingFor, attempts
local function key(link)
    if link then return link:match("item:[^|]+") or link end
    return false
end
addon.itemKey = key

local function wornLink(slot)
    return GetInventoryItemLink("player", slot)
end

local function scanBags(visit)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for index = 1, bagSize(bag) do
            if visit(bag, index, bagLink(bag, index)) then return true end
        end
    end
end

function addon.itemsFor(slot)
    local choices, seen = {}, {}
    if not addon.available then return choices end
    local function add(link)
        if not link then return end
        local _, _, _, equipLoc, icon = itemInfo(link)
        if equipLoc ~= (slot == 8 and "INVTYPE_FEET" or "INVTYPE_TRINKET") then return end
        local id = key(link)
        if seen[id] then
            seen[id].count = seen[id].count + 1
        else
            local choice = { link = link, icon = icon, count = 1,
                name = link:match("|h%[(.-)%]|h") or link }
            seen[id] = choice
            choices[#choices + 1] = choice
        end
    end
    for _, inventorySlot in ipairs(slots) do add(wornLink(inventorySlot)) end
    scanBags(function(_, _, link) add(link) end)
    table.sort(choices, function(a, b)
        if a.name == b.name then return a.link < b.link end
        return a.name < b.name
    end)
    return choices
end

local function status(text, warn)
    addon.status = text
    if addon.updateStatus then addon.updateStatus() end
    if warn then print("|cff80cfffMountGear:|r " .. text) end
end

local function bagLocked(bag, index)
    if not bagInfo then return false end
    local info, _, locked = bagInfo(bag, index)
    if type(info) == "table" then return info.isLocked end
    return locked
end

local function wornLocked(slot)
    return IsInventoryItemLocked and IsInventoryItemLocked(slot)
end

local function swap(slot, wanted, targets)
    if wornLocked(slot) then return false end
    if wanted == false then
        return scanBags(function(bag, index, link)
            local _, family = bagFree(bag)
            if link or family ~= 0 or bagLocked(bag, index) then return end
            PickupInventoryItem(slot)
            if CursorHasItem() then pickupBag(bag, index) end
            ClearCursor()
            return true
        end)
    end

    if scanBags(function(bag, index, link)
        if key(link) ~= wanted or bagLocked(bag, index) then return end
        pickupBag(bag, index)
        if CursorHasItem() then PickupInventoryItem(slot) end
        if CursorHasItem() and not bagLink(bag, index) then pickupBag(bag, index) end
        ClearCursor()
        return true
    end) then return true end

    if slot ~= 8 then
        local other = slot == 13 and 14 or 13
        if targets[other] ~= wanted and key(wornLink(other)) == wanted and not wornLocked(other) then
            PickupInventoryItem(other)
            if CursorHasItem() then PickupInventoryItem(slot) end
            if CursorHasItem() and not wornLink(other) then PickupInventoryItem(other) end
            ClearCursor()
            return true
        end
    end
    return false
end

local advance
local function schedule(delay)
    if timerSet then return end
    timerSet = true
    C_Timer.After(delay or 0.2, function()
        timerSet = false
        advance()
    end)
end

local function selection()
    local targets = {}
    for _, slot in ipairs(slots) do
        if db.picks[slot] then targets[slot] = key(db.picks[slot]) end
    end
    return targets
end

advance = function()
    local mounted = IsMounted()
    local ride = db.ride
    local targets = ride and (mounted and ride.mounted or ride.original) or (mounted and selection())
    waitingFor = nil
    if not targets then
        status("Ready for the next mount.")
        return
    end

    local missing = {}
    for _, slot in ipairs(slots) do
        if targets[slot] ~= nil and key(wornLink(slot)) ~= targets[slot] then
            missing[#missing + 1] = slot
        end
    end
    if #missing == 0 then
        if not mounted then db.ride = nil end
        status(mounted and (next(targets) and "Mount gear equipped." or "Pick gear for your next mount.")
            or "Original gear restored.")
        return
    end

    if InCombatLockdown() or UnitAffectingCombat("player") then
        waitingFor = "combat"
        status("Waiting for combat to end.")
        return
    end
    if GetCursorInfo() then
        waitingFor = "cursor"
        status("Waiting for the cursor to clear.")
        schedule(0.5)
        return
    end

    if not ride then
        local original = {}
        if targets[8] then original[8] = key(wornLink(8)) end
        -- Either trinket can supply the other slot, so save both.
        if targets[13] or targets[14] then
            original[13], original[14] = key(wornLink(13)), key(wornLink(14))
        end
        db.ride = { mounted = targets, original = original }
    end

    -- Restore filled slots first so their swaps can make room for an empty slot.
    for _, empty in ipairs({ false, true }) do
        for _, slot in ipairs(missing) do
            if (targets[slot] == false) == empty and (attempts[slot] or 0) < 3 then
                if swap(slot, targets[slot], targets) then
                    attempts[slot] = (attempts[slot] or 0) + 1
                    schedule()
                    return
                end
            end
        end
    end
    if (attempts.waits or 0) < 2 then
        attempts.waits = (attempts.waits or 0) + 1
        schedule()
        return
    end
    local names = {}
    for _, slot in ipairs(missing) do names[#names + 1] = addon.labels[slot] end
    status((mounted and "Couldn't equip " or "Couldn't restore ") .. table.concat(names, ", ")
        .. ". Check your bags and use Retry.", true)
end

function addon.retry()
    if not addon.available then return end
    attempts = {}
    schedule()
end

local function initialize()
    if addon.initialized then return end
    addon.initialized = true
    addon.available = not not (itemInfo and bagSize and bagLink and bagFree and pickupBag
        and PickupInventoryItem and IsMounted and C_Timer and C_Timer.After)
    addon.createOptions()
    if addon.available then
        for _, name in ipairs({ "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_REGEN_ENABLED" }) do
            local ok, err = pcall(frame.RegisterEvent, frame, name)
            if not ok then
                addon.available = false
                status("Unable to register " .. name .. "; gear swapping is disabled: " .. tostring(err), true)
                return
            end
        end
        addon.retry()
    else
        status("Required gear or mount API unavailable in this client.", true)
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == "MountGear" then
        if type(MountGearDB) ~= "table" then MountGearDB = {} end
        db = MountGearDB
        if type(db.picks) ~= "table" then db.picks = {} end
        addon.db = db
        addon.registerSlashCommand()
        if IsLoggedIn and IsLoggedIn() then initialize() end
    elseif event == "PLAYER_LOGIN" then
        if db then initialize() end
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        addon.retry()
    elseif event == "PLAYER_REGEN_ENABLED" and waitingFor == "combat" then
        schedule()
    end
end)
