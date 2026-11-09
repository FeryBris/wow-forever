local _, FC = ...

local UI = FC.UI

local previousRefreshTravelView = UI.RefreshTravelView
function UI:RefreshTravelView(...)
    previousRefreshTravelView(self, ...)
    local frame = self.travelFrame
    if not frame or not frame.cacheText or not FC.Travel then return end

    local meeting = FC.Travel:GetMeetingPoint()
    if not meeting then return end
    local existing = frame.cacheText:GetText() or ""
    local mode = FC.DB and FC.DB.settings and FC.DB.settings.discoveryMode or "BALANCED"
    local anchorName = tostring(meeting.anchorName or FC:GetText("TRAVEL_CENTRAL_MEMBER"))
    local mapName = tostring(meeting.mapName or FC:GetText("MAP_FALLBACK", tostring(meeting.mapID)))
    local details = FC:GetText("TRAVEL_RENDEZVOUS", anchorName, mapName, tonumber(meeting.memberCount) or 0)
    if mode == "GUIDE" and meeting.x and meeting.y then
        details = details .. FC:GetText("TRAVEL_RENDEZVOUS_GUIDE", meeting.x * 100, meeting.y * 100)
    end
    frame.cacheText:SetText(existing .. "\n" .. details)
end
