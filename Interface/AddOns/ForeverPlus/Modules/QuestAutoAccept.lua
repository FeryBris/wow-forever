-- Accepts quests automatically.
--
-- Quest functions are not protected, so there is no taint and no combat
-- lockdown to worry about. Every handler still runs through FP:Safe: the exact
-- signature C_GossipInfo uses on build 1.60.1 is unverified, and an error at a
-- quest giver must not take the rest of the addon with it.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("QuestAutoAccept", {
    title    = L["Auto Accept Quests"],
    default  = true,
    desc     = L["Accepts each quest automatically at most once per "
            .. "conversation with the quest giver."],
    group    = "npc",
    order    = 10,
    options = {
        -- CF8 on CurseForge, the owner's word of 2026-10-18: gray left out
        -- by default, judged for the character by the client itself. See
        -- FP:QuestWanted in Core/Util.lua.
        { key = "difficulty", type = "select", default = "noGray",
          label = L["Quest difficulty"],
          values = {
              { "all",     L["Accept all"] },
              { "noGray",  L["Skip gray quests"] },
              { "noGreen", L["Skip gray and green quests"] },
          },
          desc  = L["Which quests are left for you to accept, by their color "
               .. "for your character. Handing quests in is not affected."] },

        { key = "fromGossip", type = "toggle", default = true,
          label = L["Also from gossip windows"],
          desc  = L["Accepts quests offered inside a conversation, not just "
               .. "through the regular quest window."] },
        { key = "confirmShared", type = "toggle", default = false,
          label = L["Confirm shared quests and escorts"],
          desc  = L["Also accepts quests other players share with you and "
               .. "escort quests. An escort begins the moment it is "
               .. "accepted."] },
        { key = "holdShiftStop", type = "toggle", default = true,
          label = L["Hold Shift to pause"],
          desc  = L["While Shift is down, nothing is accepted, so you can "
               .. "read the text first."] },
    },
})

-- Without an escape hatch you could never read a quest text again. Holding
-- Shift means "hands on the wheel, keep out".
local function Paused()
    return M.db.holdShiftStop and IsShiftKeyDown()
end

--- Should this module keep its hands off the current gossip window?
--
-- QuestAutoTurnIn reacts to the same window, and which handler runs first is
-- not defined -- both grabbing at once would have them fight over it. Handing
-- in comes first, so this module stands aside when there is a finished quest
-- here and the turn-in module is actually running to take it.
--
-- The check reads game state rather than talking to the other module, so
-- neither depends on the other being loaded.
local function YieldToTurnIn()
    return FP:IsEnabled("QuestAutoTurnIn")
       and type(FP.HasCompletedQuestHere) == "function"
       and FP.HasCompletedQuestHere()
end

local handlers = {}

--- The guard every window of a conversation is told about first, so a
--- conversation begun just now is known before anything is decided.
local function Guard()
    local guard = FP:QuestGuard()
    if guard:Touch(GetTime(), FP:QuestNpc()) then guard:Note("a new conversation") end
    return guard
end

--- May this quest be accepted now: not yet in this conversation, and of a
--- color the player wants taken. Checked when it is picked from a list and
--- again on its own window, where the list may have been skipped.
local function Eligible(guard, id, trivial)
    if not guard:MayAccept(id) then
        guard:Note("accept held: " .. tostring(id) .. " already went through")
        return false
    end
    local difficulty = FP:QuestDifficulty(id)
    if not FP:QuestWanted(M.db.difficulty, difficulty, trivial) then
        guard:Note("accept skipped: " .. tostring(id) .. " difficulty "
            .. tostring(difficulty) .. ", trivial " .. tostring(trivial))
        return false
    end
    return true
end

function handlers.QUEST_DETAIL()
    local guard = Guard()
    if Paused() then return end
    -- The client accepts some quests by itself (quest items, auto quests).
    -- AcceptQuest would be wrong there; the window just needs to go away.
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if CloseQuest then CloseQuest() end
        return
    end
    local id = FP:OpenQuestID()
    -- Not for this module: the window stays open for the player.
    if not Eligible(guard, id, nil) then return end
    AcceptQuest()
    guard:Accepted(id)
    guard:Note("accepted " .. tostring(id))
end

function handlers.QUEST_ACCEPT_CONFIRM()
    if Paused() or not M.db.confirmShared then return end
    ConfirmAcceptQuest()
end

--- A quest on the greeting window: whether the client calls it gray, and its id.
local function Offered(index)
    if not GetAvailableQuestInfo then return nil, nil end
    local ok, trivial, _, _, _, id = pcall(GetAvailableQuestInfo, index)
    if not ok then return nil, nil end
    return FP:Truth(trivial), FP:PlainNumber(id)
end

function handlers.QUEST_GREETING()
    local guard = Guard()
    if Paused() or YieldToTurnIn() then return end
    -- The first quest that may be taken, not merely the first one: the quest
    -- giver then switches to the detail window and QUEST_DETAIL takes over.
    local available = GetNumAvailableQuests and GetNumAvailableQuests() or 0
    if not SelectAvailableQuest then return end
    for index = 1, available do
        local trivial, id = Offered(index)
        if Eligible(guard, id, trivial) then
            SelectAvailableQuest(index)
            return
        end
    end
end

function handlers.GOSSIP_SHOW()
    local guard = Guard()
    if Paused() or not M.db.fromGossip or YieldToTurnIn() then return end

    local gossip = C_GossipInfo
    if not (gossip and gossip.GetAvailableQuests and gossip.SelectAvailableQuest) then
        return
    end

    for index, quest in ipairs(gossip.GetAvailableQuests() or {}) do
        local id = FP:PlainNumber(quest.questID)
        if Eligible(guard, id, FP:Truth(quest.isTrivial)) then
            -- The signature moved from an index to a questID over the years.
            -- Which one this build wants is unverified, so prefer questID and
            -- fall back to the index.
            gossip.SelectAvailableQuest(id or index)
            return
        end
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then
            FP:Safe("QuestAutoAccept:" .. event, handler, ...)
        end
    end)
    for event in pairs(handlers) do
        self.frame:RegisterEvent(event)
    end
end

function M:OnDisable()
    if self.frame then
        self.frame:UnregisterAllEvents()
    end
end
