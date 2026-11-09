local _, FC = ...

local Legacy = {}
FC.Legacy = Legacy

local SOURCE = "Legacy"

local function getStore()
    if not FC.DB or not FC.DB.account then return nil end
    FC.DB.account.legacy = FC.DB.account.legacy or {}
    return FC.DB.account.legacy
end

local function addSuggestions(snapshot)
    FC.Suggestions:ClearSource(SOURCE)
    if not snapshot or snapshot.total <= 0 then return end

    if snapshot.remaining > 0 then
        FC.Suggestions:Add({
            id = "legacy_progress",
            source = SOURCE,
            category = "Legacy",
            priority = 42,
            title = FC:GetText("SUGG_LEGACY_REMAINING_TITLE", snapshot.remaining),
            description = FC:GetText("SUGG_LEGACY_COMPLETE_DESC", snapshot.completed, snapshot.total),
        })
    end

    local added = 0
    for _, challenge in ipairs(snapshot.challenges or {}) do
        if not challenge.completed and challenge.progress and challenge.progress > 0 and added < 3 then
            local percent = math.floor((challenge.progress * 100) + 0.5)
            FC.Suggestions:Add({
                id = "legacy_" .. tostring(challenge.id),
                source = SOURCE,
                category = "Legacy",
                priority = 58 + math.floor(challenge.progress * 20),
                title = challenge.name,
                description = FC:GetText("SUGG_LEGACY_PROGRESS_DESC", percent),
                metadata = { challengeID = challenge.id },
            })
            added = added + 1
        end
    end
end

function Legacy:GetSnapshot()
    local store = getStore()
    return store and store.snapshot or nil
end

function Legacy:GetLastError()
    local store = getStore()
    return store and store.lastError or nil
end

function Legacy:Refresh(reason)
    if self.enabled == false then return end
    local store = getStore()
    if not store then return end

    local snapshot, err = FC.API:GetLegacySnapshot()
    store.lastScan = time and time() or 0
    store.lastReason = reason or "manual"

    if snapshot then
        store.snapshot = snapshot
        store.lastError = nil
        addSuggestions(snapshot)
        FC.Logger:Debug("LEGACY", "Scanned %d Legacy Challenges (%d complete)", snapshot.total, snapshot.completed)
    else
        store.lastError = err or "Legacy scan unavailable"
        FC.Suggestions:ClearSource(SOURCE)
        FC.Logger:Debug("LEGACY", "Legacy scan unavailable: %s", tostring(store.lastError))
    end
end

function Legacy:ScheduleRefresh(reason)
    if self.enabled == false then return end
    self.pendingReason = reason or "event"
    if self.refreshScheduled then return end

    self.refreshScheduled = true
    local callback = function()
        self.refreshScheduled = false
        if self.enabled == false then
            self.pendingReason = nil
            return
        end
        local pendingReason = self.pendingReason
        self.pendingReason = nil
        self:Refresh(pendingReason)

        if FC.UI and FC.UI.frame and FC.UI.frame:IsShown() then FC.UI:RefreshDashboard() end
        if FC.UI and FC.UI.RefreshLegacyView then FC.UI:RefreshLegacyView() end
    end

    if C_Timer and C_Timer.After then C_Timer.After(0.35, callback) else callback() end
end

function Legacy:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if self.enabled then self:ScheduleRefresh(event) end
    end)
end

function Legacy:OnEnable()
    if not FC.API.capabilities.legacy then
        FC.Logger:Debug("LEGACY", "Achievement capability is not available")
        return
    end

    pcall(self.eventFrame.RegisterEvent, self.eventFrame, "ACHIEVEMENT_EARNED")
    pcall(self.eventFrame.RegisterEvent, self.eventFrame, "CRITERIA_UPDATE")
    self:ScheduleRefresh("enable")
end

function Legacy:OnDisable()
    if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
    self.pendingReason = nil
    FC.Suggestions:ClearSource(SOURCE)
end

function Legacy:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then self:ScheduleRefresh(event) end
end

FC:RegisterModule("Legacy", Legacy)
