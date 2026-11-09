local _, FC = ...

local Theme = {}
FC.UI.Theme = Theme

Theme.colors = {
    navy = {0.025, 0.075, 0.12, 0.97},
    navySoft = {0.045, 0.115, 0.18, 0.94},
    panel = {0.035, 0.045, 0.06, 0.96},
    panelSoft = {0.07, 0.075, 0.085, 0.94},
    parchment = {0.34, 0.25, 0.13, 0.94},
    gold = {0.92, 0.64, 0.18, 1},
    goldSoft = {0.62, 0.42, 0.12, 1},
    blue = {0.08, 0.58, 0.95, 1},
    blueSoft = {0.05, 0.28, 0.48, 1},
    text = {0.94, 0.93, 0.88, 1},
    muted = {0.62, 0.68, 0.72, 1},
    green = {0.28, 0.92, 0.44, 1},
    yellow = {1.0, 0.78, 0.18, 1},
    red = {1.0, 0.28, 0.18, 1},
}

local function setTextureColor(texture, color)
    texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

function Theme:CreatePanel(parent, backgroundColor, borderColor)
    local frame = CreateFrame("Frame", nil, parent)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    setTextureColor(frame.bg, backgroundColor or self.colors.panel)

    local border = borderColor or self.colors.goldSoft
    frame.borders = {}

    local top = frame:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(1)
    setTextureColor(top, border)
    frame.borders[#frame.borders + 1] = top

    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    setTextureColor(bottom, border)
    frame.borders[#frame.borders + 1] = bottom

    local left = frame:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    setTextureColor(left, border)
    frame.borders[#frame.borders + 1] = left

    local right = frame:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
    setTextureColor(right, border)
    frame.borders[#frame.borders + 1] = right

    return frame
end

function Theme:SetPanelColor(frame, color)
    if frame and frame.bg then
        setTextureColor(frame.bg, color)
    end
end

function Theme:CreateText(parent, template, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetText(text or "")
    return fs
end

function Theme:CreateSectionTitle(parent, text)
    local title = self:CreateText(parent, "GameFontNormalLarge", text)
    title:SetTextColor(self.colors.gold[1], self.colors.gold[2], self.colors.gold[3])
    return title
end

function Theme:CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, height or 28)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    setTextureColor(button.bg, self.colors.navySoft)

    button.highlight = button:CreateTexture(nil, "BORDER")
    button.highlight:SetAllPoints()
    setTextureColor(button.highlight, {self.colors.blue[1], self.colors.blue[2], self.colors.blue[3], 0})

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("CENTER")
    button.label:SetText(text or "")
    button.label:SetTextColor(self.colors.text[1], self.colors.text[2], self.colors.text[3])

    local edge = button:CreateTexture(nil, "ARTWORK")
    edge:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    edge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    edge:SetHeight(2)
    setTextureColor(edge, self.colors.goldSoft)

    button:SetScript("OnEnter", function(self)
        self.highlight:SetColorTexture(Theme.colors.blue[1], Theme.colors.blue[2], Theme.colors.blue[3], 0.18)
    end)
    button:SetScript("OnLeave", function(self)
        local alpha = self.fcActive and 0.22 or 0
        self.highlight:SetColorTexture(Theme.colors.blue[1], Theme.colors.blue[2], Theme.colors.blue[3], alpha)
    end)

    function button:SetFCText(value)
        self.label:SetText(value or "")
    end

    function button:SetFCActive(active)
        self.fcActive = active == true
        if self.fcActive then
            self.bg:SetColorTexture(Theme.colors.blueSoft[1], Theme.colors.blueSoft[2], Theme.colors.blueSoft[3], 1)
            self.label:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])
            self.highlight:SetColorTexture(Theme.colors.blue[1], Theme.colors.blue[2], Theme.colors.blue[3], 0.22)
        else
            self.bg:SetColorTexture(Theme.colors.navySoft[1], Theme.colors.navySoft[2], Theme.colors.navySoft[3], 1)
            self.label:SetTextColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3])
            self.highlight:SetColorTexture(Theme.colors.blue[1], Theme.colors.blue[2], Theme.colors.blue[3], 0)
        end
    end

    return button
end

function Theme:CreateProgressBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width or 200, height or 12)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(self.colors.blue[1], self.colors.blue[2], self.colors.blue[3], 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.01, 0.02, 0.03, 0.9)

    local line = bar:CreateTexture(nil, "OVERLAY")
    line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, -1)
    line:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -1)
    line:SetHeight(1)
    setTextureColor(line, self.colors.goldSoft)
    return bar
end
