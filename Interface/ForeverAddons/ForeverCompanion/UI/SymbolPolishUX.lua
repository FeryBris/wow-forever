local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme

local function findAndHideSearchGlyph(searchBox)
    if not searchBox or not searchBox.GetRegions then return end
    for _, region in ipairs({ searchBox:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("FontString") and region.GetText then
            if region:GetText() == "⌕" then region:Hide() end
        end
    end
end

local function ensureSearchTexture(frame)
    if not frame or not frame.fcSearchBox or frame.fcSearchTextureIcon then return end
    findAndHideSearchGlyph(frame.fcSearchBox)
    local icon = Theme:CreateSearchIcon(frame.fcSearchBox, 15)
    icon:SetPoint("LEFT", frame.fcSearchBox, "LEFT", 8, 0)
    frame.fcSearchTextureIcon = icon
end

local function ensureChecklistIndicators(frame)
    if not frame or frame.fcTextureCheckboxes then return end
    frame.fcTextureCheckboxes = true
    for _, controls in ipairs(frame.rows or {}) do
        local row = controls.toggle
        if row then
            local indicator = Theme:CreateCheckboxIndicator(row, 18)
            indicator:SetPoint("LEFT", row, "LEFT", 7, 0)
            controls.stateIndicator = indicator
            if row.label then
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row, "LEFT", 30, 0)
                row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                row.label:SetJustifyH("LEFT")
            end
        end
    end
end

local previousCreateMainFrame = UI.CreateMainFrame
if type(previousCreateMainFrame) == "function" then
    function UI:CreateMainFrame(...)
        local frame = previousCreateMainFrame(self, ...)
        ensureSearchTexture(frame)
        return frame
    end
end

local previousCreatePreparationChecklistFrame = UI.CreatePreparationChecklistFrame
if type(previousCreatePreparationChecklistFrame) == "function" then
    function UI:CreatePreparationChecklistFrame(...)
        local frame = previousCreatePreparationChecklistFrame(self, ...)
        ensureChecklistIndicators(frame)
        return frame
    end
end

local previousRefreshPreparationChecklistView = UI.RefreshPreparationChecklistView
if type(previousRefreshPreparationChecklistView) == "function" then
    function UI:RefreshPreparationChecklistView(...)
        previousRefreshPreparationChecklistView(self, ...)
        local frame = self.preparationChecklistFrame
        local checklist = FC.PreparationChecklist
        if not frame or not checklist then return end
        ensureChecklistIndicators(frame)

        local items = checklist:GetItems() or {}
        local pageSize = 10
        local page = math.max(1, tonumber(frame.checklistPage) or 1)
        local startIndex = ((page - 1) * pageSize) + 1
        for index, controls in ipairs(frame.rows or {}) do
            local item = items[startIndex + index - 1]
            if item then
                local label = type(checklist.GetDisplayLabel) == "function"
                    and checklist:GetDisplayLabel(item) or tostring(item.label or "")
                if controls.stateIndicator then
                    controls.stateIndicator:SetChecked(item.completed == true)
                    controls.stateIndicator:Show()
                end
                controls.toggle:SetFCText(label)
            elseif controls.stateIndicator then
                controls.stateIndicator:Hide()
            end
        end
    end
end
