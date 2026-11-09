-- SoTRaidLootSync
--
-- Bridges HeadCount (raid attendance/bosskills/looter log) and
-- RCLootCouncil (loot council decisions) into one SavedVariable the SoT
-- Launcher reads directly, replacing the "run each addon's own export,
-- copy the text, paste it into the web admin" workflow with an automatic
-- capture.
--
-- Both addons already build the exact JSON strings the website expects
-- (HeadCount:exportJSON, RCLootHistoryExport:BuildJSON) — this addon calls
-- those directly rather than re-deriving the same data from their raw
-- SavedVariables, so it stays correct even if either addon's internal
-- storage changes. The one piece it does rebuild itself is
-- RCLootHistoryExport:BuildJSON's `data` input — LootHistory.lua keeps
-- that grouped-by-date table as a file-local upvalue (not global, not
-- exposed on the module), so it can't be read from outside that file.
-- The raw award records it's built from (RCLootCouncilLootDB) ARE a real
-- global SavedVariable, so this addon groups them by date itself — the
-- same handful of fields lootHistory.lua's own BuildData() copies — and
-- only hands off to RCLootCouncil's own code for the actual JSON string.

SoTRaidLootSyncDB = SoTRaidLootSyncDB or { raids = {} }
if not SoTRaidLootSyncDB.raids then
    SoTRaidLootSyncDB.raids = {}
end

local frame = CreateFrame("Frame")

-- Only raids from at most this many days ago are worth keeping around —
-- old enough that it's almost certainly already been synced (or imported
-- the old manual way before this addon existed), and comfortably covers
-- any raid week that hasn't been synced yet without accumulating forever.
local MAX_RAID_AGE_DAYS = 10

local function isRecentEnough(epochSeconds)
    return (time() - epochSeconds) <= (MAX_RAID_AGE_DAYS * 86400)
end

-- Matches RCLootCouncil's own date format ("21/01/26" == "%d/%m/%y"), so a
-- HeadCount raid's start time can look up that day's loot awards.
local function toRCDateFormat(epochSeconds)
    return date("%d/%m/%y", epochSeconds)
end

local function getFactionRealmKey()
    local faction = UnitFactionGroup("player")
    local realm = GetRealmName()
    if not faction or not realm then return nil end
    return faction .. " - " .. realm
end

-- The raw award list this character's RCLootCouncil install has synced:
-- playerName -> array of {itemId via lootWon link, response, responseID,
-- boss, date, time, votes, class, ...}. Shared across the whole
-- faction+realm (not per-character), same table the in-game Loot History
-- frame reads from.
local function getRawLootAwards()
    if type(RCLootCouncilLootDB) ~= "table" then return nil end
    local factionRealm = RCLootCouncilLootDB.factionrealm
    if type(factionRealm) ~= "table" then return nil end

    local key = getFactionRealmKey()
    if not key then return nil end

    return factionRealm[key]
end

-- Reproduces lootHistory.lua's own BuildData() grouping (date ->
-- playerName -> numbered award record, with `class` hoisted a level up)
-- from the raw award list, since that grouped table isn't reachable any
-- other way (see file header). This is pure regrouping — the fields
-- themselves are copied verbatim, no reinterpretation of what they mean.
local function groupAwardsByDate(rawAwards)
    local data = {}

    for playerName, entries in pairs(rawAwards) do
        if type(entries) == "table" then
            for i, record in ipairs(entries) do
                local recordDate = record.date
                if recordDate then
                    data[recordDate] = data[recordDate] or {}
                    data[recordDate][playerName] = data[recordDate][playerName] or {}
                    data[recordDate][playerName][i] = {}

                    for key, value in pairs(record) do
                        if key == "class" then
                            data[recordDate][playerName].class = value
                        elseif key ~= "date" then
                            data[recordDate][playerName][i][key] = value
                        end
                    end
                end
            end
        end
    end

    return data
end

-- Builds RCLootCouncil's own export JSON for one date (its exact format,
-- since it's RCLootCouncil's own function doing the encoding) — or nil if
-- there's nothing logged for that date yet, or RCLootCouncil isn't
-- loaded.
local function buildLootJSON(dateStr)
    local rawAwards = getRawLootAwards()
    if not rawAwards then return nil end

    local data = groupAwardsByDate(rawAwards)
    if not data[dateStr] then return nil end

    if not LibStub then return nil end
    local rcAddon = LibStub("AceAddon-3.0", true) and LibStub("AceAddon-3.0"):GetAddon("RCLootCouncil", true)
    if not rcAddon then return nil end

    local export = rcAddon:GetModule("RCLootHistoryExport", true)
    if not export then return nil end

    local ok, jsonOrErr = pcall(function() return export:BuildJSON(dateStr, data) end)
    if not ok then return nil end

    return jsonOrErr
end

-- Captures every HeadCount raid marked finalized that isn't already
-- recorded (keyed by raid start time, so re-running this is always safe),
-- pairing each with that day's RCLootCouncil export. lootJson can come
-- back nil (e.g. a raid with no loot council awards logged yet, or
-- RCLootCouncil not installed) — the launcher/website side should treat
-- that as "no loot data yet", not an error.
local function captureFinalizedRaids()
    if type(HeadCount) ~= "table" or type(HeadCount.getRaidTracker) ~= "function" then
        return 0
    end

    local ok, tracker = pcall(function() return HeadCount:getRaidTracker() end)
    if not ok or not tracker then return 0 end

    local ok2, raids = pcall(function() return tracker:retrieveOrderedRaidList(true) end)
    if not ok2 or type(raids) ~= "table" then return 0 end

    local captured = 0

    for _, raid in ipairs(raids) do
        local isFinalized = false
        pcall(function() isFinalized = raid:getIsFinalized() end)

        if isFinalized then
            local okStart, startingTime = pcall(function() return raid:retrieveStartingTime() end)
            local raidId = okStart and startingTime and startingTime:getUTCDateTimeInSeconds()

            -- HeadCount can retain months of raid history — without this,
            -- every raid it ever tracked (most already imported the old
            -- manual way, long before this addon existed) gets pulled in
            -- the first time this runs.
            if raidId and isRecentEnough(raidId) and not SoTRaidLootSyncDB.raids[tostring(raidId)] then
                local okExport, raidJson = pcall(function() return HeadCount:exportJSON(raid) end)

                if okExport and raidJson then
                    SoTRaidLootSyncDB.raids[tostring(raidId)] = {
                        capturedAt = time(),
                        raidJson = raidJson,
                        lootJson = buildLootJSON(toRCDateFormat(raidId)),
                    }
                    captured = captured + 1
                end
            end
        end
    end

    return captured
end

-- Drops entries for raids older than this — same window used to decide
-- whether to capture a raid in the first place (see isRecentEnough), so a
-- raid that ages out simply disappears next login instead of sitting
-- around forever once it's presumably already been synced or is no
-- longer relevant.
local function pruneOldRaids()
    for raidIdStr in pairs(SoTRaidLootSyncDB.raids) do
        local raidId = tonumber(raidIdStr)
        if not raidId or not isRecentEnough(raidId) then
            SoTRaidLootSyncDB.raids[raidIdStr] = nil
        end
    end
end

-- PLAYER_ENTERING_WORLD fires very early during login/reload — confirmed
-- live that calling captureFinalizedRaids() synchronously right then finds
-- nothing (HeadCount's own raid tracker isn't done initializing yet),
-- while running /sotraidsync moments later (after things settle) captures
-- fine. No C_Timer in this client version, so a plain OnUpdate elapsed-time
-- accumulator stands in for a one-shot delayed call.
local CAPTURE_DELAY_SECONDS = 5
local delayFrame = CreateFrame("Frame")
local delayElapsed = 0

local function scheduleDelayedCapture()
    delayElapsed = 0
    delayFrame:SetScript("OnUpdate", function(self, elapsed)
        delayElapsed = delayElapsed + elapsed
        if delayElapsed >= CAPTURE_DELAY_SECONDS then
            self:SetScript("OnUpdate", nil)
            captureFinalizedRaids()
            pruneOldRaids()
        end
    end)
end

frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        -- No time to wait around at logout — capture with whatever state
        -- HeadCount already has right now.
        captureFinalizedRaids()
        pruneOldRaids()
    else
        scheduleDelayedCapture()
    end
end)

SLASH_SOTRAIDLOOTSYNC1 = "/sotraidsync"
SlashCmdList["SOTRAIDLOOTSYNC"] = function()
    local count = captureFinalizedRaids()
    if count > 0 then
        print(string.format("|cff33ff99SoTRaidLootSync|r: captured %d new raid(s).", count))
    else
        print("|cff33ff99SoTRaidLootSync|r: nothing new to capture (raid not finalized yet, or already captured).")
    end
end
