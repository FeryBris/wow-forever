local _, FC = ...

local Checklist = {}
FC.PreparationChecklist = Checklist

local SOURCE = "PreparationChecklist"
local DEFAULT_ITEMS = {
    { key = "PREP_CHECKLIST_DEFAULT_FOOD", legacy = "Food and drink" },
    { key = "PREP_CHECKLIST_DEFAULT_HEALING", legacy = "Bandages / healing supplies" },
    { key = "PREP_CHECKLIST_DEFAULT_CLASS", legacy = "Class reagents or utility items" },
    { key = "PREP_CHECKLIST_DEFAULT_WEAPON", legacy = "Weapon enhancements / temporary buffs" },
    { key = "PREP_CHECKLIST_DEFAULT_ACTIVITY", legacy = "Quest or activity-specific items" },
    { key = "PREP_CHECKLIST_DEFAULT_CAMP", legacy = "Camp supplies / profession tools" },
}

local LEGACY_DEFAULT_KEYS = {}
for _, definition in ipairs(DEFAULT_ITEMS) do
    LEGACY_DEFAULT_KEYS[definition.legacy] = definition.key
end

local function getStore()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.preparationChecklist = FC.DB.account.preparationChecklist or {
        items = {},
        nextID = 0,
        seeded = false,
    }
    local store = FC.DB.account.preparationChecklist
    store.items = store.items or {}
    store.nextID = tonumber(store.nextID) or 0
    return store
end

local function trim(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function Checklist:SeedDefaults()
    local store = getStore()
    if not store or store.seeded then return end
    store.seeded = true
    for _, definition in ipairs(DEFAULT_ITEMS) do
        self:Add(FC:GetText(definition.key), true, definition.key)
    end
end

function Checklist:Add(label, seeded, defaultKey)
    label = trim(label)
    if label == "" then return false, FC:GetText("CHECKLIST_ERROR_ITEM_REQUIRED") end
    local store = getStore()
    if not store then return false, FC:GetText("FORM_ERROR_DATABASE_NOT_READY") end

    store.nextID = store.nextID + 1
    local id = tostring(store.nextID)
    store.items[id] = {
        id = id,
        label = label,
        completed = false,
        createdAt = time and time() or 0,
        seeded = seeded == true,
        defaultKey = defaultKey and tostring(defaultKey) or nil,
    }
    self:Refresh()
    return true, store.items[id]
end

function Checklist:GetDisplayLabel(item)
    if type(item) ~= "table" then return "" end

    local key = item.defaultKey
    if not key and item.seeded then
        key = LEGACY_DEFAULT_KEYS[tostring(item.label or "")]
        if key then item.defaultKey = key end
    end

    if key then return FC:GetText(key) end
    return tostring(item.label or "")
end

function Checklist:SetCompleted(id, completed)
    local store = getStore()
    local item = store and store.items[tostring(id or "")]
    if not item then return false end
    item.completed = completed == true
    item.updatedAt = time and time() or 0
    self:Refresh()
    return true
end

function Checklist:Toggle(id)
    local store = getStore()
    local item = store and store.items[tostring(id or "")]
    if not item then return false end
    return self:SetCompleted(id, not item.completed)
end

function Checklist:Remove(id)
    local store = getStore()
    id = tostring(id or "")
    if not store or not store.items[id] then return false end
    store.items[id] = nil
    self:Refresh()
    return true
end

function Checklist:RemoveCompleted()
    local store = getStore()
    if not store then return 0 end
    local removed = 0
    for id, item in pairs(store.items) do
        if item.completed then
            store.items[id] = nil
            removed = removed + 1
        end
    end
    self:Refresh()
    return removed
end

function Checklist:Reset()
    local store = getStore()
    if not store then return end
    for _, item in pairs(store.items) do
        item.completed = false
        item.updatedAt = time and time() or 0
    end
    self:Refresh()
end

function Checklist:GetItems()
    self:SeedDefaults()
    local store = getStore()
    local result = {}
    for _, item in pairs(store and store.items or {}) do
        -- Attach a stable locale key to the original beta defaults without
        -- replacing user-entered text or resetting completion state.
        self:GetDisplayLabel(item)
        result[#result + 1] = item
    end
    table.sort(result, function(a, b)
        if a.completed ~= b.completed then return a.completed == false end
        return (tonumber(a.createdAt) or 0) < (tonumber(b.createdAt) or 0)
    end)
    return result
end

function Checklist:GetProgress()
    local items = self:GetItems()
    local completed = 0
    for _, item in ipairs(items) do if item.completed then completed = completed + 1 end end
    return completed, #items, math.max(0, #items - completed)
end

function Checklist:Refresh()
    FC.Suggestions:ClearSource(SOURCE)
    local completed, total, open = self:GetProgress()
    if total > 0 and open > 0 then
        FC.Suggestions:Add({
            id = "preparation_personal_checklist",
            source = SOURCE,
            category = "Preparation",
            priority = 36,
            title = FC:GetText("SUGG_PREP_CHECKLIST_TITLE", open),
            description = FC:GetText("SUGG_PREP_CHECKLIST_DESC", completed, total),
        })
    end
end

function Checklist:OnInitialize()
    self:SeedDefaults()
end

function Checklist:OnEnable()
    self:Refresh()
end

function Checklist:OnEvent(event)
    if event == "PLAYER_LOGIN" then self:Refresh() end
end

FC:RegisterModule("PreparationChecklist", Checklist)
