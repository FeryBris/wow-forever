local _, FC = ...

local UI = FC.UI
local Theme = UI.Theme
local PAGE_SIZE = 10

local function setText(fontString, text, color)
    if not fontString then return end
    color = color or Theme.colors.text
    fontString:SetText(text or "")
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local previousRefreshPreparationChecklistView = UI.RefreshPreparationChecklistView
function UI:RefreshPreparationChecklistView(...)
    previousRefreshPreparationChecklistView(self, ...)

    local frame = self.preparationChecklistFrame
    local checklist = FC.PreparationChecklist
    if not frame or not checklist then return end

    local items = checklist:GetItems() or {}
    local completed, total, open = checklist:GetProgress()
    local summary = FC:GetText("SUGG_PREP_CHECKLIST_DESC", completed, total)
        .. "  •  " .. FC:GetText("SUGG_PREP_CHECKLIST_TITLE", open)
    setText(frame.summary, summary, open == 0 and total > 0 and Theme.colors.green or Theme.colors.text)

    local page = tonumber(frame.checklistPage) or 1
    local startIndex = ((math.max(1, page) - 1) * PAGE_SIZE) + 1
    for index, controls in ipairs(frame.rows or {}) do
        local item = items[startIndex + index - 1]
        if item then
            local label = type(checklist.GetDisplayLabel) == "function"
                and checklist:GetDisplayLabel(item) or tostring(item.label or "")
            controls.toggle:SetFCText((item.completed and "✓  " or "□  ") .. label)
        end
    end
end
