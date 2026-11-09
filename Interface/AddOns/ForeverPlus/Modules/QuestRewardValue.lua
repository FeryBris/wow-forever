-- What every quest reward sells for, written into the corner of its button.
--
-- A module of its own rather than an option on one of the quest modules, and
-- the reason is the owner's: a display that only tells you something has no
-- business hanging off a switch that makes the addon act for you. Somebody who
-- turns off automatic handing in because they would rather do it themselves
-- should not lose the numbers as well.
--
-- It also covers both windows now, which is what made the old home untenable:
-- the values used to live in `QuestAutoTurnIn` and appear only when handing a
-- quest in, so the accept window, which belongs to the other module entirely,
-- showed nothing. Reported by a player on 2026-09-20.
--
-- **The addon still never picks a reward.** That is `QuestAutoTurnIn`'s hard
-- rule and this module exists in the shape it does because of it: the whole
-- point is to answer the question without taking it away.
--
-- ---------------------------------------------------------------------------
-- One hook instead of three events
-- ---------------------------------------------------------------------------
--
-- Blizzard fills the accept window, the reward window and the quest log's own
-- detail pane through a single function, `QuestInfo_Display`, into a single
-- shared frame. Hooking that covers every quest window there is, including any
-- this build has that nobody here has thought of, which is the better bargain
-- on a client newer than the model's knowledge.
--
-- `hooksecurefunc` rather than a replacement, so nothing of Blizzard's is
-- taken away, and the events stay as a fallback for a build without that
-- function. Running twice draws the same numbers twice, which costs nothing.
--
-- Drawing beside a Blizzard frame is allowed where restyling one is not: a
-- number laid on a button is an addition, and a patch can take the number away
-- without taking the quest window with it. See `AGENTS.md`.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("QuestRewardValue", {
    title   = L["Quest Reward Value"],
    default = true,
    desc    = L["Shows what each quest reward sells for, on every quest window."],
    group   = "npc",
    order   = 25,
    options = {
        { key = "fixedRewards", type = "toggle", default = true,
          label = L["Also on rewards you get anyway"],
          desc  = L["Not only the ones you choose between. Off, and only a real "
               .. "choice carries a price."] },
    },
})

local MAX_BUTTONS = 10
local RETRIES     = 6      -- an uncached item needs a round trip to the server
local RETRY_WAIT  = 0.3

local labels      = {}     -- [button] = FontString
local retriesLeft = 0

-- Declared before its own body so the retry can call it: a local declared
-- further down is a different name.
local Decorate

local function Label(button)
    local label = labels[button]
    if label then return label end

    -- nil as the template, always. Instantiating a Blizzard template runs
    -- their OnLoad inside our tainted execution; see AGENTS.md.
    label = button:CreateFontString(nil, "OVERLAY")
    -- A font object, never a font file: a path renders as blank boxes on the
    -- Korean, Chinese and Russian clients.
    label:SetFontObject(GameFontHighlightSmall)
    label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 3)
    label:SetJustifyH("RIGHT")
    labels[button] = label
    return label
end

local function ClearLabels()
    for _, label in pairs(labels) do label:SetText("") end
    retriesLeft = 0
end

--- Vendor price of one reward, or nil while the client is still asking.
--
-- nil and zero are different answers and conflating them is a lie that settles
-- itself half a second later: zero means no merchant wants it, nil means the
-- item is not cached yet.
local function RewardValue(kind, index)
    if not GetQuestItemLink then return nil end
    local ok, link = pcall(GetQuestItemLink, kind, index)
    if not ok or not link then return nil end

    local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not getInfo then return nil end

    -- Position 11 is the sell price, per item rather than per stack.
    local okInfo, price = pcall(function() return select(11, getInfo(link)) end)
    return okInfo and price or nil
end

--- How many rewards of each kind this quest has.
local function Counts()
    local choices, fixed = 0, 0
    if GetNumQuestChoices then
        local ok, n = pcall(GetNumQuestChoices)
        choices = (ok and tonumber(n)) or 0
    end
    if GetNumQuestRewards then
        local ok, n = pcall(GetNumQuestRewards)
        fixed = (ok and tonumber(n)) or 0
    end
    return choices, fixed
end

function Decorate()
    local choices, fixed = Counts()
    if choices + fixed == 0 then return ClearLabels() end

    local unknown = false
    for i = 1, MAX_BUTTONS do
        local button = _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
        if button then
            local shown = button.IsShown and button:IsShown()
            -- Blizzard's own fields on the button. Where they are absent the
            -- buttons stand in choice order, which holds whenever a quest
            -- offers nothing but choices.
            local kind  = rawget(button, "type") or "choice"
            local index = tonumber(rawget(button, "index")) or i

            local wanted = shown
                and (kind == "choice" or (kind == "reward" and M.db.fixedRewards))
                and index <= ((kind == "choice") and choices or fixed)

            if wanted then
                local price = RewardValue(kind, index)
                if price == nil then
                    unknown = true
                    Label(button):SetText("")
                else
                    Label(button):SetText(price > 0 and FP:Money(price) or "")
                end
            elseif labels[button] then
                labels[button]:SetText("")
            end
        end
    end

    if unknown and retriesLeft > 0 and C_Timer and C_Timer.After then
        retriesLeft = retriesLeft - 1
        C_Timer.After(RETRY_WAIT, function()
            FP:Safe("QuestRewardValue:retry", Decorate)
        end)
    end
end

--- Puts the numbers up for a window that is opening.
--
-- Twice on purpose: once now, and once on the next frame, because the buttons
-- are laid out by Blizzard's own handler and the order the two run in is not
-- defined. The call is idempotent, so the second costs nothing.
local function Refresh()
    if not M.enabled then return end
    retriesLeft = RETRIES
    Decorate()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() FP:Safe("QuestRewardValue:frame", Decorate) end)
    end
end

local handlers = {}
function handlers.QUEST_DETAIL()   Refresh() end
function handlers.QUEST_COMPLETE() Refresh() end
function handlers.QUEST_FINISHED() ClearLabels() end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = handlers[event]
        if handler then FP:Safe("QuestRewardValue:" .. event, handler, ...) end
    end)
    FP:RegisterEvents(self.frame, handlers, "QuestRewardValue")

    -- Once for the life of the session. A second hook would draw the same
    -- numbers a second time, and there is no way to take one back.
    if not self.hooked and _G.QuestInfo_Display and _G.hooksecurefunc then
        self.hooked = pcall(hooksecurefunc, "QuestInfo_Display", function()
            if M.enabled then FP:Safe("QuestRewardValue:hook", Refresh) end
        end)
        if not self.hooked then
            FP:Warn(L["QuestRewardValue: could not hook QuestInfo_Display, "
                .. "falling back to the quest events alone."])
        end
    end
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    ClearLabels()
end

--- Called when an option changed or the profile switched.
function M:Reapply()
    Decorate()
end
