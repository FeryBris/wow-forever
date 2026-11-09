local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateTravelRoutesFrame()
    if self.travelRoutesFrame then return self.travelRoutesFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(900, 650)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "TRAVEL ROUTE LIBRARY")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -64)
    frame.summary:SetWidth(856)
    frame.summary:SetJustifyH("LEFT")

    frame.origin = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.origin:SetSize(190, 28)
    frame.origin:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -100)
    frame.origin:SetAutoFocus(false)
    frame.origin:SetTextInsets(8, 8, 0, 0)

    frame.destination = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.destination:SetSize(190, 28)
    frame.destination:SetPoint("LEFT", frame.origin, "RIGHT", 10, 0)
    frame.destination:SetAutoFocus(false)
    frame.destination:SetTextInsets(8, 8, 0, 0)

    frame.routeType = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.routeType:SetSize(120, 28)
    frame.routeType:SetPoint("LEFT", frame.destination, "RIGHT", 10, 0)
    frame.routeType:SetAutoFocus(false)
    frame.routeType:SetTextInsets(8, 8, 0, 0)
    frame.routeType:SetText("Custom")

    frame.notes = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.notes:SetSize(205, 28)
    frame.notes:SetPoint("LEFT", frame.routeType, "RIGHT", 10, 0)
    frame.notes:SetAutoFocus(false)
    frame.notes:SetTextInsets(8, 8, 0, 0)

    frame.addButton = Theme:CreateButton(frame, "Add Route", 100, 28)
    frame.addButton:SetPoint("LEFT", frame.notes, "RIGHT", 10, 0)

    frame.hints = Theme:CreateText(frame, "GameFontDisableSmall", "From                         To                            Type                 Notes")
    frame.hints:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -134)
    frame.hints:SetWidth(820)
    frame.hints:SetJustifyH("LEFT")

    frame.rows = {}
    for i = 1, 10 do
        local card = Theme:CreatePanel(frame, Theme.colors.panel, Theme.colors.blueSoft)
        card:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -160 - ((i - 1) * 43))
        card:SetSize(856, 39)

        card.text = Theme:CreateText(card, "GameFontHighlightSmall", "")
        card.text:SetPoint("LEFT", card, "LEFT", 10, 0)
        card.text:SetWidth(630)
        card.text:SetJustifyH("LEFT")

        card.toggle = Theme:CreateButton(card, "Pause", 85, 28)
        card.toggle:SetPoint("RIGHT", card, "RIGHT", -98, 0)
        card.toggle:SetScript("OnClick", function(self)
            if not self.routeID or not FC.TravelRoutes then return end
            FC.TravelRoutes:SetEnabled(self.routeID, not self.routeEnabled)
            UI:RefreshTravelRoutesView()
        end)

        card.remove = Theme:CreateButton(card, "Remove", 85, 28)
        card.remove:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        card.remove:SetScript("OnClick", function(self)
            if not self.routeID or not FC.TravelRoutes then return end
            FC.TravelRoutes:Remove(self.routeID)
            UI:RefreshTravelRoutesView()
        end)
        frame.rows[i] = card
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Forever Companion does not ship unverified Classic transport tables as Forever truth. User routes are account-wide. Provider routes are read-only and may be supplied by addons/datapacks through ForeverCompanionAPI.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(856)
    frame.note:SetJustifyH("LEFT")

    local function addRoute()
        if not FC.TravelRoutes then return end
        local ok, result = FC.TravelRoutes:Create(nil, frame.origin:GetText(), frame.destination:GetText(), frame.notes:GetText(), frame.routeType:GetText())
        if ok then
            frame.origin:SetText("")
            frame.destination:SetText("")
            frame.notes:SetText("")
            UI:RefreshTravelRoutesView()
        else
            FC:Print(result)
        end
    end
    frame.addButton:SetScript("OnClick", addRoute)
    frame.notes:SetScript("OnEnterPressed", addRoute)

    self.travelRoutesFrame = frame
    return frame
end

function UI:RefreshTravelRoutesView()
    local frame = self:CreateTravelRoutesFrame()
    local module = FC.TravelRoutes
    local routes = module and module:GetAllRoutes(true) or {}
    local providerCount = module and module:GetProviderCount() or 0
    local userCount = module and #module:GetUserRoutes(true) or 0

    setText(frame.summary, string.format("%d user route(s) • %d provider(s) • %d route record(s) currently available", userCount, providerCount, #routes), Theme.colors.text)

    for i, card in ipairs(frame.rows) do
        local route = routes[i]
        if route then
            card:Show()
            local endpoints = route.origin and route.destination and (route.origin .. " → " .. route.destination) or tostring(route.name)
            local source = route.source or "User"
            local detail = route.notes and (" • " .. route.notes) or ""
            setText(card.text, string.format("[%s] %s • %s%s", tostring(route.routeType or "Route"), tostring(endpoints), tostring(source), detail),
                route.enabled == false and Theme.colors.muted or Theme.colors.text)

            local isUser = source == "User"
            card.toggle.routeID = isUser and route.id or nil
            card.toggle.routeEnabled = route.enabled ~= false
            card.remove.routeID = isUser and route.id or nil
            card.toggle:SetFCText(route.enabled == false and "Enable" or "Pause")
            card.toggle:SetAlpha(isUser and 1 or 0)
            card.remove:SetAlpha(isUser and 1 or 0)
        else
            card:Hide()
        end
    end

    if #routes == 0 then
        frame.rows[1]:Show()
        frame.rows[1].toggle:SetAlpha(0)
        frame.rows[1].remove:SetAlpha(0)
        setText(frame.rows[1].text, "No routes stored yet. Add a route above or install a provider/datapack that supplies verified Forever transport data.", Theme.colors.muted)
    end
end

function UI:ShowTravelRoutes()
    local frame = self:CreateTravelRoutesFrame()
    self:RefreshTravelRoutesView()
    frame:Show()
end

local previousCreateTravelFrame = UI.CreateTravelFrame
function UI:CreateTravelFrame(...)
    local frame = previousCreateTravelFrame(self, ...)
    if frame and not frame.routesButton then
        local button = Theme:CreateButton(frame, "Route Library", 115, 30)
        button:SetPoint("RIGHT", frame.refreshButton, "LEFT", -8, 0)
        button:SetScript("OnClick", function() UI:ShowTravelRoutes() end)
        frame.routesButton = button
    end
    return frame
end
