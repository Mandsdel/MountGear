local frames = {}
local methods = {}
function methods:SetPoint(...) self.point = { ... } end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetText(text) self.text = text end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetScript(event, handler) self.scripts[event] = handler end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:GetName() return self.name end
function methods:SetParent(parent) self.parent = parent end
function methods:GetFrameLevel() return 1 end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:CreateTexture() return CreateFrame("Texture", nil, self) end
function methods:CreateFontString() return CreateFrame("FontString", nil, self) end
setmetatable(methods, { __index = function() return function() end end })

function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ kind = kind, name = name, parent = parent,
        template = template, scripts = {} }, { __index = methods })
    frames[#frames + 1] = frame
    return frame
end
UIParent = CreateFrame("Frame")
UISpecialFrames = {}
SlashCmdList = {}
tinsert = table.insert

local addonEnabled
local addon = {
    slots = { 8, 10, 13, 14 },
    labels = { [8] = "Boots", [10] = "Gloves", [13] = "Trinket 1", [14] = "Trinket 2" },
    db = { picks = {}, battlegroundEnabled = false },
    available = true,
    setBattlegroundEnabled = function(enabled) addonEnabled = enabled end,
}
assert(loadfile("Options.lua"))("MountGear", addon)
addon.registerSlashCommand()
SlashCmdList.MOUNTGEAR()

local titles, toggle, label = 0
for _, frame in ipairs(frames) do
    if frame.kind == "FontString" and frame.point and frame.point[1] == "CENTER"
        and frame.point[2].texture == "Interface\\DialogFrame\\UI-DialogBox-Header" then
        assert(frame.point[3] == "TOP" and frame.point[4] == 0 and frame.point[5] == -15)
        titles = titles + 1
    elseif frame.template == "UICheckButtonTemplate" then
        toggle = frame
    elseif frame.text == "On/Off in Battlegrounds" then
        label = frame
    end
end
assert(titles == 3)
assert(toggle and toggle.width == 26 and toggle.height == 26 and toggle.checked == false)
assert(label and label.point[2] == toggle)
toggle:SetChecked(true)
toggle.scripts.OnClick(toggle)
assert(addonEnabled == true)
toggle:SetChecked(false)
toggle.scripts.OnClick(toggle)
assert(addonEnabled == false)

local category
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        assert(name == "MountGear")
        return panel
    end,
    RegisterAddOnCategory = function(panel) category = panel end,
}
addon.createOptions()
assert(category and category.scripts.OnShow and category.scripts.OnHide)
category.scripts.OnShow()
local window
for _, frame in ipairs(frames) do
    if frame.name == "MountGearOptions" then window = frame end
end
assert(window and window.parent == category and window:IsShown())
category.scripts.OnHide()
assert(window.parent == UIParent and not window:IsShown())
print("MountGear options checks passed.")
