-- Hands in finished quests without clicking.
--
-- The vendor prices beside each reward used to live here and are now their own
-- module, `QuestRewardValue`. They were moved because they appear on the
-- accept window too, which belongs to the other quest module entirely, and
-- because a display that only tells you something should not switch off with
-- an automation that acts for you.
--
-- The one rule this module will not bend: **it never picks a reward.** When a
-- quest offers a choice, it stops and leaves the window open. A reward chosen
-- by mistake cannot be undone, and no amount of convenience is worth that.
-- Quests with a single reward, or none, are handed in.
--
-- Deliberately a separate module from QuestAutoAccept rather than an option on
-- it: handing in is the riskier half, and it should be possible to run one
-- without the other.
--
-- Every handler runs through FP:Safe. The exact C_GossipInfo signatures on
-- build 1.60.1 are unverified, and an error at a quest giver must not take the
-- rest of the addon with it.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("QuestAutoTurnIn", {
    title    = L["Auto Turn In Quests"],
    default  = true,
    desc     = L["Hands in each completed quest at most once per "
            .. "conversation with the quest giver. Never picks a reward for "
            .. "you."],
    group    = "npc",
    order    = 20,
    options = {
        { key = "fromGossip", type = "toggle", default = true,
          label = L["Also from gossip windows"],
          desc  = L["Hands quests in from inside a conversation as well as from "
               .. "the plain quest window."] },
        { key = "holdShiftStop", type = "toggle", default = true,
          label = L["Hold Shift to pause"],
          desc  = L["While Shift is down, nothing is handed in. Reward "
               .. "values are still shown because they belong to a separate "
               .. "module."] },
    },
})

-- Without an escape hatch you could never hold a finished quest back -- for a
-- chain, or to hand it in at a better level. Holding Shift means "hands off".
local function Paused()
    return M.db.holdShiftStop and IsShiftKeyDown()
end

--- A finished quest on the greeting window's list, and its id where the
--- client gives one.
local function Active(index)
    local _, isComplete = GetActiveTitle(index)
    local id
    if GetActiveQuestID then
        local ok, value = pcall(GetActiveQuestID, index)
        id = ok and FP:PlainNumber(value) or nil
    end
    return FP:Truth(isComplete) == true, id
end

--- Is there a finished quest this module would hand in at this gossip or
--- greeting window?
--
-- Shared with QuestAutoAccept, which yields when this returns true so the two
-- modules do not both grab the same window. Reading the same game state keeps
-- them independent: neither has to know the other is running. A quest the
-- guard holds back, handed in already in this conversation or left to the
-- player for its rewards, does not count, or it would keep every other quest
-- of the NPC from being accepted.
function FP.HasCompletedQuestHere()
    local guard = FP:QuestGuard()
    local gossip = C_GossipInfo
    if gossip and gossip.GetActiveQuests then
        for _, quest in ipairs(gossip.GetActiveQuests() or {}) do
            if quest.isComplete and guard:MayTurnIn(FP:PlainNumber(quest.questID)) then
                return true
            end
        end
    end

    if GetNumActiveQuests and GetActiveTitle then
        for i = 1, GetNumActiveQuests() do
            local complete, id = Active(i)
            if complete and guard:MayTurnIn(id) then return true end
        end
    end

    return false
end

local handlers = {}

--- The guard every window of a conversation is told about first, see
--- QuestAutoAccept.
local function Guard()
    local guard = FP:QuestGuard()
    if guard:Touch(GetTime(), FP:QuestNpc()) then guard:Note("a new conversation") end
    return guard
end

--- May this quest be handed in now, or did it go through in this
--- conversation already?
local function MayTurnIn(guard, id)
    if guard:MayTurnIn(id) then return true end
    guard:Note("turn-in held: " .. tostring(id))
    return false
end

function handlers.QUEST_PROGRESS()
    local guard = Guard()
    if Paused() then return end
    if not MayTurnIn(guard, FP:OpenQuestID()) then return end
    -- The quest giver asks whether to continue. Only proceed when the
    -- objectives are actually done; otherwise this is just the "come back
    -- later" text.
    if IsQuestCompletable and IsQuestCompletable() then
        CompleteQuest()
    end
end

function handlers.QUEST_COMPLETE()
    local guard = Guard()
    if Paused() then return end
    local id = FP:OpenQuestID()
    if not MayTurnIn(guard, id) then return end

    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if choices > 1 then
        -- More than one reward on offer. The player picks, not us, and the
        -- quest stays the player's for this conversation.
        guard:Hold(id)
        guard:Note("turn-in left to the player: " .. tostring(id) .. ", a choice of rewards")
        return
    end

    -- Index 1 is the convention here: with no choice rewards the client
    -- ignores it, with exactly one it is that one.
    if GetQuestReward then
        GetQuestReward(1)
        guard:TurnedIn(id)
        guard:Note("handed in " .. tostring(id))
    end
end

function handlers.QUEST_GREETING()
    local guard = Guard()
    if Paused() then return end
    if not (GetNumActiveQuests and GetActiveTitle and SelectActiveQuest) then return end

    -- One at a time: selecting a quest replaces the greeting with the detail
    -- window, so a loop would grab at nothing.
    for i = 1, GetNumActiveQuests() do
        local complete, id = Active(i)
        if complete and MayTurnIn(guard, id) then
            SelectActiveQuest(i)
            return
        end
    end
end

function handlers.GOSSIP_SHOW()
    local guard = Guard()
    if Paused() or not M.db.fromGossip then return end

    local gossip = C_GossipInfo
    if not (gossip and gossip.GetActiveQuests and gossip.SelectActiveQuest) then
        return
    end

    for index, quest in ipairs(gossip.GetActiveQuests() or {}) do
        local id = FP:PlainNumber(quest.questID)
        if quest.isComplete and MayTurnIn(guard, id) then
            -- The signature moved from an index to a questID over the years.
            -- Which one this build wants is unverified, so prefer questID and
            -- fall back to the index.
            gossip.SelectActiveQuest(id or index)
            return
        end
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then
            FP:Safe("QuestAutoTurnIn:" .. event, handler, ...)
        end
    end)
    FP:RegisterEvents(self.frame, handlers, "QuestAutoTurnIn")
end

function M:OnDisable()
    if self.frame then
        self.frame:UnregisterAllEvents()
    end
end
