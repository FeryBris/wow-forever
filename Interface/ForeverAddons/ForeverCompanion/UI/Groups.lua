local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function UI:CreateGroupsFrame()
    if self.groupsFrame then return self.groupsFrame end

    local frame = Theme:CreatePanel(UIParent, Theme.colors.navy, Theme.colors.gold)
    frame:SetSize(760, 560)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.title = Theme:CreateText(frame, "GameFontNormalHuge", "GROUP PREPARATION")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
    frame.title:SetTextColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3])

    frame.closeButton = Theme:CreateButton(frame, "X", 32, 30)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

    frame.refreshButton = Theme:CreateButton(frame, "Refresh", 90, 30)
    frame.refreshButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -8, 0)
    frame.refreshButton:SetScript("OnClick", function()
        if FC.Groups then FC.Groups:Refresh("group-window") end
        UI:RefreshGroupsView()
    end)

    frame.summary = Theme:CreateText(frame, "GameFontHighlight", "")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -64)
    frame.summary:SetWidth(716)
    frame.summary:SetJustifyH("LEFT")

    frame.memberTitle = Theme:CreateSectionTitle(frame, "Members & Travel Context")
    frame.memberTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -106)

    frame.memberLines = {}
    for i = 1, 10 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -138 - ((i - 1) * 34))
        line:SetWidth(430)
        line:SetJustifyH("LEFT")
        frame.memberLines[i] = line
    end

    frame.playerTitle = Theme:CreateSectionTitle(frame, "Your Preparation")
    frame.playerTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 480, -106)

    frame.playerLines = {}
    for i = 1, 7 do
        local line = Theme:CreateText(frame, "GameFontHighlightSmall", "")
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", 482, -138 - ((i - 1) * 38))
        line:SetWidth(250)
        line:SetJustifyH("LEFT")
        frame.playerLines[i] = line
    end

    frame.note = Theme:CreateText(frame, "GameFontDisableSmall",
        "Forever Companion does not inspect other players' bags, durability, consumables or hidden combat state. Group preparation only summarizes information legitimately exposed by the client.")
    frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 18)
    frame.note:SetWidth(716)
    frame.note:SetJustifyH("LEFT")

    self.groupsFrame = frame
    return frame
end

function UI:RefreshGroupsView()
    local frame = self.groupsFrame
    if not frame then return end
    local snapshot = FC.Groups and FC.Groups:GetSnapshot() or nil
    if not snapshot then
        setText(frame.summary, "Group context has not been scanned yet.", Theme.colors.muted)
        return
    end

    setText(frame.summary, snapshot.grouped
        and string.format("%d member(s) • %d map context(s)", #(snapshot.members or {}), tonumber(snapshot.mapCount) or 0)
        or "You are not currently in a group. Your own preparation is still shown.", Theme.colors.text)

    for i = 1, #frame.memberLines do
        local member = snapshot.members and snapshot.members[i]
        if member then
            local state = not member.connected and "OFFLINE" or (member.deadOrGhost and "DEAD/GHOST" or "READY TO TRAVEL")
            local map = member.mapName or (member.mapID and ("Map " .. member.mapID) or "map unavailable")
            setText(frame.memberLines[i], string.format("%s — L%s %s\n   %s • %s", tostring(member.name), tostring(member.level or "?"), tostring(member.className or ""), map, state),
                member.connected and (member.deadOrGhost and Theme.colors.yellow or Theme.colors.text) or Theme.colors.red)
        else
            setText(frame.memberLines[i], "")
        end
    end

    local prep = snapshot.playerPreparation or {}
    local lines = {
        prep.freeBagSlots ~= nil and string.format("Free bag slots: %d", prep.freeBagSlots) or "Bag space: unavailable",
        prep.lowestDurability ~= nil and string.format("Lowest durability: %.0f%%", prep.lowestDurability) or "Durability: unavailable",
        prep.hearthstoneCount ~= nil and string.format("Hearthstone: x%d", prep.hearthstoneCount) or "Hearthstone: unavailable",
        prep.projectileCount ~= nil and string.format("Hunter projectiles: %d", prep.projectileCount) or "Class ammo: not applicable/unavailable",
    }
    for i = 1, #frame.playerLines do
        setText(frame.playerLines[i], lines[i] or "", Theme.colors.muted)
    end
end

function UI:ShowGroups()
    local frame = self:CreateGroupsFrame()
    if FC.Groups then FC.Groups:Refresh("group-window-open") end
    self:RefreshGroupsView()
    frame:Show()
end

local previousCreateMainFrame = UI.CreateMainFrame
function UI:CreateMainFrame(...)
    local frame = previousCreateMainFrame(self, ...)
    if frame and not frame.fcGroupsButton and frame.header then
        local button = Theme:CreateButton(frame.header, "Group", 80, 30)
        local anchor = frame.fcSettingsButton or frame.fcGoalsButton or frame.refreshButton
        button:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
        button:SetScript("OnClick", function() UI:ShowGroups() end)
        frame.fcGroupsButton = button
    end
    return frame
end
