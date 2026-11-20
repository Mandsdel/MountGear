local _, addon = ...
local window, statusText, picker, pickerTitle, pickerHint, scroll, content, emptyText
local itemButtons, choicesButtons = {}, {}
local choosing, choices = nil, {}
local cellSize, maxColumns, maxRows = 42, 8, 6
local emptyIcons = {
    [8] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",
    [13] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
    [14] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
}

local function makeButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    return button
end

local function itemTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.link then
        GameTooltip:SetHyperlink(button.link)
    else
        GameTooltip:SetText("Click to choose " .. addon.labels[button.slot])
    end
    GameTooltip:Show()
end

local function background(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    else
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        texture:SetPoint("TOPLEFT", 4, -4)
        texture:SetPoint("BOTTOMRIGHT", -4, 4)
        texture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    end
    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(220, 48)
    header:SetPoint("TOP", 0, 12)
end

local function titleText(frame, text)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -3)
    title:SetText(text)
    return title
end

local function iconButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(36, 36)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon = icon
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:SetScript("OnEnter", itemTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function addon.updateStatus()
    if statusText then statusText:SetText(addon.status or "Picks are saved per character.") end
end

local function drawPicks()
    for _, slot in ipairs(addon.slots) do
        local button = itemButtons[slot]
        local link = addon.db.picks[slot]
        button.link = link
        local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        local icon
        if link and info then
            local _, _, _, _, texture = info(link)
            icon = texture
        end
        button.icon:SetTexture(icon or (link and "Interface\\Icons\\INV_Misc_QuestionMark") or emptyIcons[slot])
    end
end

local function drawPicker()
    local columns = math.min(maxColumns, math.max(5, #choices))
    local rows = math.max(1, math.ceil(#choices / columns))
    local visibleRows = math.min(maxRows, rows)
    picker:SetSize(columns * cellSize + 40, visibleRows * cellSize + 88)
    scroll:SetSize(columns * cellSize, visibleRows * cellSize)
    content:SetSize(columns * cellSize, rows * cellSize)
    scroll:SetVerticalScroll(0)
    pickerTitle:SetText("Choose " .. addon.labels[choosing])
    pickerHint:SetText(rows > maxRows and "Hover for details. Scroll for more." or "Hover for details. Click to select.")
    if #choices == 0 then emptyText:Show() else emptyText:Hide() end

    for i, choice in ipairs(choices) do
        local button = choicesButtons[i]
        if not button then
            button = iconButton(content)
            button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            button.count:SetPoint("BOTTOMRIGHT", -1, 1)
            button:SetScript("OnClick", function(self)
                local item = self.choice
                local other = choosing == 13 and 14 or 13
                if choosing ~= 8 and item.count == 1
                    and addon.itemKey(addon.db.picks[other]) == addon.itemKey(item.link) then
                    statusText:SetText("You only have one copy of that trinket.")
                    return
                end
                addon.db.picks[choosing] = item.link
                GameTooltip:Hide()
                drawPicks()
                picker:Hide()
                statusText:SetText("Saved for your next mount.")
            end)
            choicesButtons[i] = button
        end
        button.choice, button.link = choice, choice.link
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", ((i - 1) % columns) * cellSize + 3,
            -math.floor((i - 1) / columns) * cellSize - 3)
        button.icon:SetTexture(choice.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        button.count:SetText(choice.count > 1 and choice.count or "")
        button:Show()
    end
    for i = #choices + 1, #choicesButtons do
        choicesButtons[i].link, choicesButtons[i].choice = nil, nil
        choicesButtons[i]:Hide()
    end
end

local function choose(slot)
    choosing = slot
    choices = addon.itemsFor(slot)
    GameTooltip:Hide()
    drawPicker()
    picker:Show()
end

local function createWindow()
    window = CreateFrame("Frame", "MountGearOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    window:SetSize(280, 300)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    tinsert(UISpecialFrames, window:GetName())

    background(window)

    titleText(window, "MountGear")

    local subtitle = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", 0, -35)
    subtitle:SetText("Riding Equipment")

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT")
    close:SetScript("OnClick", function() window:Hide() end)

    for i, slot in ipairs(addon.slots) do
        local y = -58 - (i - 1) * 46
        local label = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 24, y - 12)
        label:SetText(addon.labels[slot])

        local button = iconButton(window)
        button.slot = slot
        button:SetPoint("TOPLEFT", 110, y)
        button:SetEnabled(addon.available)
        button:SetScript("OnClick", function() choose(slot) end)
        itemButtons[slot] = button

        local clear = makeButton(window, 54, 22, "Clear")
        clear:SetPoint("LEFT", button, "RIGHT", 18, 0)
        clear:SetScript("OnClick", function()
            addon.db.picks[slot] = nil
            drawPicks()
            addon.updateStatus()
        end)
    end

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", 0, -202)
    hint:SetText("Click a slot icon to choose gear.")
    local retry = makeButton(window, 56, 20, "Retry")
    retry:SetPoint("TOPLEFT", 24, -224)
    retry:SetEnabled(addon.available)
    retry:SetScript("OnClick", addon.retry)
    statusText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 24, -254)
    statusText:SetWidth(232)
    statusText:SetJustifyH("LEFT")

    picker = CreateFrame("Frame", "MountGearItemPicker", window, BackdropTemplateMixin and "BackdropTemplate" or nil)
    picker:SetPoint("TOPLEFT", window, "TOPRIGHT", 8, 0)
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel(window:GetFrameLevel() + 10)
    picker:EnableMouse(true)
    picker:SetClampedToScreen(true)
    picker:Hide()
    background(picker)
    tinsert(UISpecialFrames, picker:GetName())
    local pickerClose = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
    pickerClose:SetPoint("TOPRIGHT")
    pickerClose:SetScript("OnClick", function() picker:Hide() end)
    picker:SetScript("OnHide", function()
        choosing = nil
        GameTooltip:Hide()
    end)
    window:SetScript("OnHide", function() picker:Hide(); GameTooltip:Hide() end)
    pickerTitle = titleText(picker, "")
    pickerHint = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pickerHint:SetPoint("BOTTOMLEFT", 20, 20)
    scroll = CreateFrame("ScrollFrame", nil, picker)
    scroll:SetPoint("TOPLEFT", 20, -38)
    content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local limit = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * cellSize)))
    end)
    emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("TOPLEFT", 3, -12)
    emptyText:SetText("No matching items found.")

    window:RegisterEvent("BAG_UPDATE_DELAYED")
    window:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    window:SetScript("OnEvent", function(self)
        if self:IsShown() and picker:IsShown() and choosing then
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
        addon.updateStatus()
        window:Show()
    end
end

function addon.registerSlashCommand()
    SLASH_MOUNTGEAR1 = "/mountgear"
    SlashCmdList.MOUNTGEAR = toggleWindow
end

function addon.createOptions()
    local minimap = Minimap or (MinimapCluster and MinimapCluster.Minimap)
    if not minimap then
        print("|cff80cfffMountGear:|r Minimap unavailable; use /mountgear.")
        return
    end
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
        local angle = addon.db.angle or math.rad(135)
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
    button:Show()
end
