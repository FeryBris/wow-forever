-- Shadowflare: its page in the game's Options window (AddOns tab). Since 0.22.0 the settings
-- have their own window (Settings.lua); this page only opens it.
local _, ns = ...
local L = ns.L

local O = {}
ns.Options = O

-- The page is built the first time it opens
function O:Build()
    if self.built then return end
    self.built = true
    local c = self.canvas
    local icon = c:CreateTexture(nil, "ARTWORK")
    icon:SetSize(44, 44)
    icon:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -14)
    icon:SetTexture("Interface\\Icons\\Spell_Fire_Fireball02")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    title:SetText("Shadowflare")
    local sub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetTextColor(0.75, 0.75, 0.75)
    sub:SetText(L.ENTRY_SUB:format(ns.version))
    local text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -18)
    text:SetPoint("RIGHT", c, "RIGHT", -24, 0)
    text:SetJustifyH("LEFT")
    text:SetText(L.ENTRY_TEXT)
    local b = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    b:SetSize(280, 34)
    b:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
    b:SetText(L.OPEN_SETTINGS)
    b:SetScript("OnClick", function()
        -- The game's Options window closes so nothing covers the settings
        pcall(function()
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        end)
        ns.Settings:Open()
    end)
    self.openButton = b
    local tip = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tip:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -14)
    tip:SetText(L.ENTRY_TIP)
end

function O:Init()
    local canvas = CreateFrame("Frame")
    canvas.name = "Shadowflare"
    -- Hidden until the game's Options window shows it (it calls Show when you open the page)
    canvas:Hide()
    self.canvas = canvas
    canvas:SetScript("OnShow", function() O:Build() end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, canvas, canvas.name)
        if ok and cat then
            pcall(Settings.RegisterAddOnCategory, cat)
            self.category = cat
        end
    end
    if not self.category and InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, canvas)
    end
end

-- Everything else talks to the settings window
function O:Refresh() if ns.Settings then ns.Settings.Refresh() end end
function O:Open() if ns.Settings then ns.Settings:Open() end end
