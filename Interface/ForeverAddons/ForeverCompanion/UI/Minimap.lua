local _, FC = ...

local UI = FC.UI
local MinimapButton = {}
UI.Minimap = MinimapButton

local ICON_TEXTURE = "Interface\\AddOns\\ForeverCompanion\\Images\\Minimap\\minimapIcon.png"
local DEFAULT_ANGLE = 225
local EDGE_PADDING = 8

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local function getSettings()
    if not FC.DB or not FC.DB.settings then
        return nil
    end

    local settings = FC.DB.settings
    if settings.minimapButton == nil then
        settings.minimapButton = true
    end
    if type(settings.minimapAngle) ~= "number" then
        settings.minimapAngle = DEFAULT_ANGLE
    end
    return settings
end

local function getMinimapRadius()
    if not Minimap then return 80 end
    local width = type(Minimap.GetWidth) == "function" and tonumber(Minimap:GetWidth()) or 0
    local height = type(Minimap.GetHeight) == "function" and tonumber(Minimap:GetHeight()) or 0
    local diameter = math.max(width or 0, height or 0)
    if diameter <= 0 then diameter = 160 end
    return (diameter * 0.5) + EDGE_PADDING
end

function MinimapButton:SetPosition(angle)
    if not self.button or not Minimap then
        return
    end

    angle = tonumber(angle) or DEFAULT_ANGLE
    local radians = math.rad(angle)
    local radius = getMinimapRadius()
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:UpdatePositionFromCursor()
    if not self.button or not Minimap then
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then
        return
    end

    local angle = math.deg(atan2(cursorY - centerY, cursorX - centerX))
    local settings = getSettings()
    if settings then
        settings.minimapAngle = angle
    end
    self:SetPosition(angle)
end

function MinimapButton:OpenTab(tabName)
    if not FC.ready then
        return
    end

    FC:RefreshModules("minimap-" .. string.lower(tostring(tabName or "overview")))
    local frame = UI:CreateMainFrame()
    UI:SwitchTab(tabName or "Overview")
    frame:Show()
end

function MinimapButton:SetShown(visible)
    local settings = getSettings()
    if settings then
        settings.minimapButton = visible and true or false
    end

    if self.button then
        self.button:SetShown(visible and true or false)
    end
end

function MinimapButton:Create()
    if self.button or not Minimap then
        return self.button
    end

    -- Parent to MinimapCluster/UIParent instead of Minimap itself so a button
    -- positioned outside the map edge cannot be clipped by modern minimap layouts.
    local parent = MinimapCluster or UIParent or Minimap
    local button = CreateFrame("Button", "ForeverCompanionMinimapButton", parent)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Blizzard's tracking border is designed around a small centered icon.
    -- Keeping the artwork at 20x20 prevents square artwork from escaping the ring.
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON_TEXTURE)
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.border = border

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forever Companion", 1.00, 0.82, 0.28)
        GameTooltip:AddLine("Explore • Prepare • Progress Together", 0.45, 0.82, 1.00)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Left Click", "Dashboard", 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:AddDoubleLine("Right Click", "Preparation", 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:AddDoubleLine("Middle Click", "Professions", 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:AddDoubleLine("Drag", "Move around minimap", 1, 1, 1, 0.70, 0.90, 1.00)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if self.ignoreNextClick then
            self.ignoreNextClick = nil
            return
        end

        if mouseButton == "LeftButton" then
            UI:Toggle()
        elseif mouseButton == "RightButton" then
            MinimapButton:OpenTab("Preparation")
        elseif mouseButton == "MiddleButton" then
            MinimapButton:OpenTab("Professions")
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self.dragMoved = false
        self:SetScript("OnUpdate", function(dragButton)
            dragButton.dragMoved = true
            MinimapButton:UpdatePositionFromCursor()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.dragMoved then
            self.ignoreNextClick = true
        end
        self.dragMoved = nil
    end)

    self.button = button

    local settings = getSettings()
    self:SetPosition(settings and settings.minimapAngle or DEFAULT_ANGLE)
    button:SetShown(not settings or settings.minimapButton ~= false)
    return button
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    MinimapButton:Create()
end)
