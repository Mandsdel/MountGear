local _, addon = ...
local window, statusText, pickerTitle, previous, following, pageText
local rows, itemButtons = {}, {}
local choosing, choices, page = nil, {}, 1
local pageSize = 5

local function makeButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    return button
end

local function nameOf(link)
    return link:match("|h%[(.-)%]|h") or link
end

local function itemTooltip(button)
    if not button.link then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(button.link)
    GameTooltip:Show()
end

function addon.updateStatus()
    if statusText then statusText:SetText(addon.status or "Picks are saved per character.") end
end

local function drawPicker()
    local pages = math.max(1, math.ceil(#choices / pageSize))
    page = math.max(1, math.min(page, pages))
    pickerTitle:SetText(choosing and ("Choose " .. addon.labels[choosing] ..
        (#choices == 0 and " - none found" or "")) or "Click a slot to choose an item.")
    for i, row in ipairs(rows) do
        local choice = choices[(page - 1) * pageSize + i]
        row.link = choice and choice.link
        if choice then
            row:SetText(choice.name .. (choice.count > 1 and (" x" .. choice.count) or ""))
            row.icon:SetTexture(choice.icon)
            row:Show()
        else
            row:Hide()
        end
    end
    previous:SetEnabled(page > 1)
    following:SetEnabled(page < pages)
    pageText:SetText(#choices > 0 and ("%d / %d"):format(page, pages) or "")
end

local function drawPicks()
    for _, slot in ipairs(addon.slots) do
        local button = itemButtons[slot]
        local link = addon.db.picks[slot]
        button.link = link
        button:SetText(link and nameOf(link) or "Not selected")
    end
end

local function choose(slot)
    choosing, page = slot, 1
    choices = slot and addon.itemsFor(slot) or {}
    drawPicker()
end

local function createWindow()
    window = CreateFrame("Frame", "MountGearOptions", UIParent)
    window:SetSize(304, 332)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    tinsert(UISpecialFrames, window:GetName())

    local background = window:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.055, 0.06, 0.075, 0.97)

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("MountGear")

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    close:SetScript("OnClick", function() window:Hide() end)

    for i, slot in ipairs(addon.slots) do
        local y = -38 - (i - 1) * 26
        local label = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 12, y - 5)
        label:SetText(addon.labels[slot])

        local button = makeButton(window, 155, 22, "")
        button:SetPoint("TOPLEFT", 78, y)
        button:SetEnabled(addon.available)
        button:SetScript("OnClick", function() choose(slot) end)
        button:SetScript("OnEnter", itemTooltip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        itemButtons[slot] = button

        local clear = makeButton(window, 54, 22, "Clear")
        clear:SetPoint("LEFT", button, "RIGHT", 4, 0)
        clear:SetScript("OnClick", function()
            addon.db.picks[slot] = nil
            drawPicks()
            addon.updateStatus()
        end)
    end

    pickerTitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pickerTitle:SetPoint("TOPLEFT", 12, -122)
    for i = 1, pageSize do
        local row = makeButton(window, 251, 20, "")
        row:SetPoint("TOPLEFT", 40, -140 - (i - 1) * 22)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("RIGHT", row, "LEFT", -5, 0)
        row.icon = icon
        row:SetScript("OnEnter", itemTooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function()
            local choice = choices[(page - 1) * pageSize + i]
            local other = choosing == 13 and 14 or 13
            if choosing ~= 8 and choice.count == 1
                and addon.itemKey(addon.db.picks[other]) == addon.itemKey(choice.link) then
                statusText:SetText("You only have one copy of that trinket.")
                return
            end
            addon.db.picks[choosing] = choice.link
            GameTooltip:Hide()
            drawPicks()
            choose(nil)
            statusText:SetText("Saved for your next mount.")
        end)
        rows[i] = row
    end

    previous = makeButton(window, 28, 20, "<")
    previous:SetPoint("TOPLEFT", 12, -254)
    previous:SetScript("OnClick", function() page = page - 1; drawPicker() end)
    following = makeButton(window, 28, 20, ">")
    following:SetPoint("TOPLEFT", 88, -254)
    following:SetScript("OnClick", function() page = page + 1; drawPicker() end)
    pageText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pageText:SetPoint("CENTER", previous, "CENTER", 38, 0)
    local retry = makeButton(window, 56, 20, "Retry")
    retry:SetPoint("TOPRIGHT", -12, -254)
    retry:SetEnabled(addon.available)
    retry:SetScript("OnClick", addon.retry)
    statusText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 12, -284)
    statusText:SetWidth(280)
    statusText:SetJustifyH("LEFT")

    window:RegisterEvent("BAG_UPDATE_DELAYED")
    window:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    window:SetScript("OnEvent", function(self)
        if self:IsShown() and choosing then
            choices = addon.itemsFor(choosing)
            drawPicker()
        end
    end)
end

local function toggleWindow()
    if not window then createWindow() end
    if window:IsShown() then
        window:Hide()
    else
        drawPicks()
        choose(nil)
        addon.updateStatus()
        window:Show()
    end
end

function addon.createOptions()
    SLASH_MOUNTGEAR1 = "/mountgear"
    SlashCmdList.MOUNTGEAR = toggleWindow

    local minimap = Minimap or (MinimapCluster and MinimapCluster.Minimap)
    if not minimap then return end
    local button = CreateFrame("Button", "MountGearMinimapButton", minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(minimap:GetFrameLevel() + 8)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function position()
        local angle = addon.db.angle or math.rad(225)
        button:ClearAllPoints()
        button:SetPoint("CENTER", minimap, "CENTER",
            math.cos(angle) * (minimap:GetWidth() / 2 + 5),
            math.sin(angle) * (minimap:GetHeight() / 2 + 5))
    end

    local dragged
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnMouseDown", function() dragged = false end)
    button:SetScript("OnDragStart", function(self)
        dragged = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local mx, my = minimap:GetCenter()
            if not mx then return end
            local scale = minimap:GetEffectiveScale()
            addon.db.angle = math.atan2(y / scale - my, x / scale - mx)
            position()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnClick", function()
        if not dragged then toggleWindow() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("MountGear")
        GameTooltip:AddLine("Click to configure. Drag to move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    position()
end
