local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local Symbols = {
    -- Optional custom symbol font. The addon works without this file; critical UI states use textures.
    fontPath = "Interface\\AddOns\\ForeverCompanion\\Fonts\\ForeverCompanionSymbols.ttf",
    glyphs = {
        search = "\238\128\128",   -- U+E000 private-use glyph
        check = "\238\128\129",    -- U+E001
        empty = "\238\128\130",    -- U+E002
        warning = "\238\128\131",  -- U+E003
        pin = "\238\128\132",      -- U+E004
        snooze = "\238\128\133",   -- U+E005
    },
}
UI.Symbols = Symbols

function Symbols:TryApplyFont(fontString, size, flags)
    if not fontString or type(fontString.SetFont) ~= "function" then return false end
    local ok, result = pcall(fontString.SetFont, fontString, self.fontPath, tonumber(size) or 14, flags or "")
    return ok and result ~= false
end

function Symbols:CreateFontGlyph(parent, glyphName, size)
    if not parent then return nil end
    local glyph = self.glyphs[glyphName]
    if not glyph then return nil end
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if not self:TryApplyFont(fs, size or 14, "OUTLINE") then
        fs:Hide()
        return nil
    end
    fs:SetText(glyph)
    return fs
end

function Theme:CreateCheckboxIndicator(parent, size)
    size = tonumber(size) or 18
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)

    frame.box = frame:CreateTexture(nil, "ARTWORK")
    frame.box:SetAllPoints()
    frame.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")

    frame.check = frame:CreateTexture(nil, "OVERLAY")
    frame.check:SetAllPoints()
    frame.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    frame.check:Hide()

    frame.highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    frame.highlight:SetAllPoints()
    frame.highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    frame.highlight:SetBlendMode("ADD")

    function frame:SetChecked(checked)
        self.check:SetShown(checked == true)
    end

    function frame:SetAvailable(available)
        self:SetAlpha(available == false and 0.35 or 1)
    end

    return frame
end

local STATUS_TEXTURES = {
    ok = "Interface\\RaidFrame\\ReadyCheck-Ready",
    warn = "Interface\\RaidFrame\\ReadyCheck-Waiting",
    error = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    info = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

function Theme:CreateStatusIndicator(parent, size)
    -- The first UI version used a plain colored square here. It was readable but
    -- looked like an unfinished placeholder. Use Blizzard's native ready-check
    -- artwork instead so state is recognizable by both shape and color.
    size = math.max(13, tonumber(size) or 13)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)

    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetPoint("CENTER")
    frame.texture:SetSize(size, size)

    function frame:SetState(state)
        state = STATUS_TEXTURES[state] and state or "info"
        local texturePath = STATUS_TEXTURES[state]
        local ok, loaded = pcall(self.texture.SetTexture, self.texture, texturePath)

        if ok and loaded ~= false then
            if type(self.texture.SetRotation) == "function" then self.texture:SetRotation(0) end
            if state == "info" then
                self.texture:SetVertexColor(Theme.colors.blue[1], Theme.colors.blue[2], Theme.colors.blue[3], 1)
            elseif state == "warn" then
                self.texture:SetVertexColor(1, 1, 1, 1)
            elseif state == "error" then
                self.texture:SetVertexColor(1, 1, 1, 1)
            else
                self.texture:SetVertexColor(1, 1, 1, 1)
            end
            return
        end

        -- Extremely defensive fallback for alternate clients: a diamond is
        -- still visually distinct from the old placeholder rectangle.
        local color = Theme.colors.muted
        if state == "ok" then color = Theme.colors.green
        elseif state == "warn" then color = Theme.colors.yellow
        elseif state == "error" then color = Theme.colors.red
        elseif state == "info" then color = Theme.colors.blue end
        self.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        self.texture:SetVertexColor(1, 1, 1, 1)
        self.texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        if type(self.texture.SetRotation) == "function" then self.texture:SetRotation(math.rad(45)) end
    end

    frame:SetState("info")
    return frame
end

function Theme:CreateSearchIcon(parent, size)
    size = tonumber(size) or 15
    local texture = parent:CreateTexture(nil, "OVERLAY")
    texture:SetSize(size, size)
    texture:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    texture:SetVertexColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    return texture
end
