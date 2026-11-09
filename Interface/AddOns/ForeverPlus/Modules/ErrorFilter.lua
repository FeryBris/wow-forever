-- Hides the red spam errors ("Not enough mana", "Ability is not ready yet",
-- "Out of range" and friends).
--
-- **Off until the player switches it on**, the owner's decision of 2026-10-05:
-- somebody who never chose it must not stand there wondering why their
-- character does nothing, with the one line that would have said why hidden.
-- A profile that already stored the switch keeps it, the owner's own among
-- them, as with every default changed before: ApplyDefaults fills only what
-- is missing.
--
-- Three design decisions worth knowing:
--
-- 1. We match against the client's own error strings (ERR_OUT_OF_MANA and
--    friends) rather than against numeric error IDs. The ID constants are
--    unverified on build 1.60.1, while the global strings are resolved from the
--    running client -- which also makes the filter locale-independent.
--
-- 2. Only red messages are touched. UIErrorsFrame carries errors *and*
--    information -- quest progress and "your inventory is full" go through
--    the same frame in yellow. An early version of this module hid those too,
--    because it never asked what kind of message it had.
--
-- 3. We replace UIErrorsFrame:AddMessage instead of unregistering
--    UI_ERROR_MESSAGE. Unregistering would kill every error including the
--    useful ones, and it would fight anything else that listens. Replacing the
--    method filters exactly what reaches the frame and is cleanly reversible.
--    It is not free of taint, which this note claimed until the audit of 7.2
--    on 2026-10-18: Blizzard code that writes to the frame itself runs our
--    method and goes on in our name for the rest of that call. Every such
--    call read in the client's code for build 70425 ends right after the
--    message, so nothing protected follows, and a hook cannot keep a message
--    out; so it stays, the module being off by default.

local ADDON, FP = ...
local L = FP.L

-- True while the module is told to hide every error, which makes each
-- individual choice meaningless.
local function Wholesale(mod)
    return mod.db and mod.db.hideEverything
end

local OVERRIDDEN = L["These settings are ignored while every error is "
                .. "hidden. Turn off the switch above to choose errors "
                .. "individually."]

local M = FP:RegisterModule("ErrorFilter", {
    title   = L["Error Filter"],
    -- Off, see the header.
    default = false,
    desc    = L["Hides the red spam errors."],
    group   = "display",
    order   = 10,
    options = {
        -- On by default, once the module is: the red text says almost nothing
        -- a player cannot already see on their own bars, and sorting through
        -- it error by error is work nobody asked for. The hover only says what
        -- the switch does, cut short at the owner's word on 2026-10-05.
        { key = "hideEverything", type = "toggle", default = true,
          label = L["Hide every error (not quest progress)"],
          desc  = L["Hides every red error. Quest progress and other yellow "
               .. "notices stay visible."] },

        -- Below the switch that overrides them, and not above it. An option
        -- grayed out by something further down the page is a puzzle.
        --
        -- A fixed heading rather than a block that folds, the owner's call of
        -- 2026-10-05: opening the module shows every category at once, with
        -- nothing left to open a second time.
        { type = "group", label = L["Or Choose Them Individually"],
          desc = L["Only used while the switch above is off."] },

        { key = "resourceErrors", type = "toggle", default = true,
          disabled = Wholesale, disabledText = OVERRIDDEN,
          label = L["Not enough mana / rage / energy"],
          desc  = L["Hides the errors about not enough mana, rage or energy."] },
        { key = "cooldownErrors", type = "toggle", default = true,
          disabled = Wholesale, disabledText = OVERRIDDEN,
          label = L["Ability is not ready yet"],
          desc  = L["Hides the errors about an ability that is not ready yet."] },
        { key = "rangeErrors", type = "toggle", default = true,
          disabled = Wholesale, disabledText = OVERRIDDEN,
          label = L["Out of range / too far away"],
          desc  = L["Hides the errors about being out of range or too far away."] },
        { key = "facingErrors", type = "toggle", default = true,
          disabled = Wholesale, disabledText = OVERRIDDEN,
          label = L["Facing the wrong way"],
          desc  = L["Hides the errors about facing the wrong way."] },
        -- Off by default when chosen individually: this one is usually worth
        -- knowing, because it tends to mean the wrong thing is being hit.
        { key = "targetErrors", type = "toggle", default = false,
          disabled = Wholesale, disabledText = OVERRIDDEN,
          label = L["Invalid target"],
          desc  = L["Hides the errors about an invalid target."] },

        { key = "logToChat", type = "toggle", default = false,
          label = L["Log hidden messages to chat (for tuning)"],
          desc  = L["Shows what was filtered, so you can tell whether something "
               .. "is being hidden that you wanted to see."] },
    },
})

-- Blizzard global strings per category. Names that this build does not have are
-- skipped, so an over-long list costs nothing.
local GROUPS = {
    resourceErrors = {
        "ERR_OUT_OF_MANA", "ERR_OUT_OF_RAGE", "ERR_OUT_OF_ENERGY",
        "ERR_OUT_OF_FOCUS", "ERR_OUT_OF_HEALTH", "ERR_OUT_OF_RUNES",
        "ERR_OUT_OF_RUNIC_POWER", "ERR_OUT_OF_POWER_DISPLAY",
        "SPELL_FAILED_NO_POWER", "ERR_NOT_ENOUGH_MANA",
    },
    cooldownErrors = {
        "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "ERR_ITEM_COOLDOWN",
        "SPELL_FAILED_NOT_READY", "ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS",
        "SPELL_FAILED_SPELL_IN_PROGRESS",
    },
    rangeErrors = {
        "ERR_OUT_OF_RANGE", "SPELL_FAILED_OUT_OF_RANGE", "ERR_BADATTACKPOS",
        "SPELL_FAILED_TOO_CLOSE", "ERR_SPELL_OUT_OF_RANGE",
    },
    facingErrors = {
        "ERR_BADATTACKFACING", "SPELL_FAILED_UNIT_NOT_INFRONT",
        "SPELL_FAILED_NOT_BEHIND", "SPELL_FAILED_NOT_INFRONT",
    },
    targetErrors = {
        "SPELL_FAILED_BAD_TARGETS", "SPELL_FAILED_BAD_IMPLICIT_TARGETS",
        "ERR_INVALID_ATTACK_TARGET", "ERR_NO_ATTACK_TARGET",
        "SPELL_FAILED_TARGET_NOT_IN_PARTY", "SPELL_FAILED_NO_VALID_TARGETS",
    },
}

-- The frames and methods we filter.
--
-- alwaysError marks a method that only ever carries errors, so its color does
-- not need checking.
local TARGETS = {
    { frame = "UIErrorsFrame", method = "AddMessage" },
    { frame = "UIErrorsFrame", method = "AddExternalErrorMessage", alwaysError = true },
}

local MARKER = "\1"

-- Error strings are format strings: "Out of range" is plain, but others carry
-- %s or %d. Turn them into Lua patterns with the specifiers as wildcards.
local function ToPattern(text)
    -- Mark the specifiers first. After escaping, a %s would be
    -- indistinguishable from an escaped literal percent sign.
    local out = text:gsub("%%%d?%$?[sdf]", MARKER)
    out = out:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    out = out:gsub(MARKER, ".-")
    return "^" .. out .. "$"
end

local patterns = {}
local hooked   = {}   -- [frame] = { [method] = original function }

local function BuildPatterns()
    wipe(patterns)
    local emptyGroups = {}

    for key, names in pairs(GROUPS) do
        if M.db[key] then
            local resolved = 0
            for _, name in ipairs(names) do
                local text = _G[name]
                if type(text) == "string" and text ~= "" then
                    patterns[#patterns + 1] = ToPattern(text)
                    resolved = resolved + 1
                end
            end
            if resolved == 0 then emptyGroups[#emptyGroups + 1] = key end
        end
    end
    return emptyGroups
end

-- UIErrorsFrame carries two kinds of message: red errors (UI_ERROR_MESSAGE)
-- and yellow information (UI_INFO_MESSAGE). Quest progress -- "Wolf slain:
-- 3/8" -- is one of the yellow ones, and so is "your inventory is full".
-- Only the red ones are this module's business.
--
-- The color handed to AddMessage is the distinction available at this point:
-- the error path passes the red font color, the info path passes yellow.
-- Returns nil when the color cannot be read at all.
local function IsError(r, g)
    if type(r) ~= "number" or type(g) ~= "number" then return nil end
    return r > 0.7 and g < 0.4
end

local warnedAboutColor = false

local function ShouldHide(message, r, g, alwaysError)
    local isError = alwaysError or IsError(r, g)

    -- Never touch an information message, whatever the settings say.
    if isError == false then return false end

    if M.db.hideEverything then
        -- Only blanket-hide what is known to be an error. Without a color we
        -- cannot tell quest progress from a spell failure, and hiding quest
        -- progress is the worse mistake.
        if isError then return true end
        if not warnedAboutColor then
            warnedAboutColor = true
            FP:Warn(L["ErrorFilter: this build reports no message color, so "
                .. "'hide all' stays off to avoid swallowing quest progress. "
                .. "The individual categories still work."])
        end
    end

    if type(message) ~= "string" then return false end

    -- Category patterns are built from error strings, so a match is an error
    -- by construction, color or no color.
    for i = 1, #patterns do
        if message:match(patterns[i]) then return true end
    end
    return false
end

local function Install(frameName, method, alwaysError)
    local frame = _G[frameName]
    if not (frame and type(frame[method]) == "function") then return false end

    hooked[frame] = hooked[frame] or {}
    if hooked[frame][method] then return true end   -- already installed

    local original = frame[method]
    hooked[frame][method] = original

    -- The color arrives as the next three arguments after the message.
    frame[method] = function(self, message, r, g, b, ...)
        if ShouldHide(message, r, g, alwaysError) then
            if M.db.logToChat then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff555555" .. L["[ForeverPlus hid]"] .. " " .. tostring(message) .. "|r")
            end
            return
        end
        return original(self, message, r, g, b, ...)
    end
    return true
end

--- Shows a red message the way the client shows its errors, past this filter.
--
-- For the addon's own answer to something the player just did, which "Hide
-- every error" must not swallow: the quest log's zone box saying the tracker
-- is full, the owner's report of 2026-10-13, when the message never showed.
-- The method from before this filter's hook where there is one, so the text
-- is not weighed at all.
function FP:ShowError(text)
    local frame = rawget(_G, "UIErrorsFrame")
    if type(text) ~= "string" or not frame then return end
    local add = (hooked[frame] and hooked[frame].AddMessage) or frame.AddMessage
    if type(add) == "function" then
        pcall(add, frame, text, 1.0, 0.1, 0.1, 1.0)
    end
end

local function Uninstall()
    for frame, methods in pairs(hooked) do
        for method, original in pairs(methods) do
            frame[method] = original
        end
    end
    wipe(hooked)
end

function M:OnEnable()
    local emptyGroups = BuildPatterns()

    warnedAboutColor = false

    local installed = false
    for _, target in ipairs(TARGETS) do
        if Install(target.frame, target.method, target.alwaysError) then
            installed = true
        end
    end

    -- Every early exit gets a message. A filter that silently filters nothing is
    -- worse than no filter, because you stop looking for the cause.
    if not installed then
        return FP:Warn(L["ErrorFilter: UIErrorsFrame has no filterable method on this build, nothing is hidden."])
    end
    if #emptyGroups > 0 then
        FP:Warn(L["ErrorFilter: this build knows none of the strings for %s, that category does nothing."],
            table.concat(emptyGroups, ", "))
    end
    if #patterns == 0 and not self.db.hideEverything then
        FP:Print(L["ErrorFilter is on, but every category is off. Nothing is "
              .. "being hidden."])
    end
end

function M:OnDisable()
    Uninstall()
    wipe(patterns)
end
