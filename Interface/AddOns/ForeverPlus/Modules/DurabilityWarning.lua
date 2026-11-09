-- A short warning when worn equipment runs low on durability.
--
-- N06 of the plan for after the launch, settled with the owner on 2026-11-01,
-- and shaped after the ammunition's warning, which he likes because it stays
-- visible with every error hidden:
--
--   * **Off by default**, with the sound on inside it, and a sound of its own
--     to pick, so the two warnings can sound apart.
--   * **The lowest equipped piece decides**, at or below a threshold that
--     starts at 20 percent, and the line names it with its percentage.
--   * **Told once per low condition**: another piece dropping, or the same one
--     reaching zero, says nothing more. Armed again only by a reading that
--     shows every piece above the threshold, so a partial repair does not, and
--     neither does a reading with a gap in it.
--   * **After a login and after a /reload as well**, when something is already
--     low: a reload counts as a login, the owner's word of 2026-11-05. A
--     change of zone says nothing. Nothing is stored, so both come for free.
--   * **At once in a fight**, as far as the client answers there. Not measured
--     yet: a piece it will not answer about is a gap, never zero, and
--     PLAYER_REGEN_ENABLED looks again once the fight is over.
--
-- UPDATE_INVENTORY_DURABILITY and UPDATE_INVENTORY_ALERTS are read in the
-- client's API documentation for build 70790, the second also in its own
-- durability figure. Whether they fire at every loss is not measured.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("DurabilityWarning", {
    title   = L["Durability Warning"],
    default = false,
    desc    = L["Shows a short warning when an equipped item reaches the "
           .. "selected durability or lower. Also warns after login if an "
           .. "item is already low."],
    group   = "display",
    order   = 33,
    options = {
        -- 99 at most: at 100 a piece in perfect condition would be low.
        { key = "threshold", type = "number", default = 20,
          label = L["Warn at or below"], min = 0, max = 99, step = 1, bigStep = 10,
          format = function(value) return value .. "%" end,
          desc  = L["Uses the lowest durability among your equipped items. "
               .. "At 0%, it warns only about broken equipment."] },

        { key = "sound", type = "toggle", default = true,
          label = L["Play a sound with it"],
          desc  = L["Plays the sound selected below along with the red "
               .. "warning."] },

        { key = "soundKit", type = "select", default = "ALARM_CLOCK_WARNING_2", sub = true,
          label = L["Sound"], values = FP:SoundChoices(),
          disabled = function(mod) return not mod.db.sound end,
          desc  = L["Picks one of the game's own sounds."] },

        { type = "action", label = L["Play the sound"], width = 150,
          desc  = L["Plays the selected sound now."],
          run   = function(mod) mod:PlayPicked() end },

        { type = "action", label = L["Show the warning"], width = 150, sameRow = true,
          desc  = L["Shows the warning once, with its sound when that is on."],
          run   = function(mod) mod:Preview() end },
    },
})

-- Its line among the short red ones, see FP:FlashLine.
local ALERT_LINE = 2

-- How long after entering the world nothing is warned about, as with the
-- ammunition: what is worn may still be arriving.
local QUIET = 5

--- The name of what is worn in a slot: the item's, or else the slot's. The name
--- may not be readable yet, which must not hold a warning back.
local function PieceName(slot)
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    local name = ok and FP:Plain(link) and link:match("%[(.-)%]")
    return name or FP:SlotName(slot) or L["Durability"]
end

local function Warn(name, percent)
    FP:FlashLine(ALERT_LINE, L["Low durability: %s (%d%%)"]:format(name, percent))
    if M.db.sound then M:PlayPicked(true) end
end

--- The sound picked, now, on the master channel like the ammunition's.
--
-- @param quiet  say nothing when the sound is missing; the warning itself
--               should not add a chat line to a moment that already has one
function M:PlayPicked(quiet)
    local id = FP:SoundKitId(self.db.soundKit)
    if id and PlaySound and pcall(PlaySound, id, "Master") then return true end
    if not quiet then
        FP:Warn(L["Durability Warning: this client has no sound called %s."],
            tostring(self.db.soundKit))
    end
    return false
end

M.armed      = true   -- whether the next low reading is told
M.quietUntil = 0

function M:Update()
    if not self.enabled then return end
    local pieces, complete = FP:ReadWornPieces()
    local verdict, lowest = FP:DurabilityVerdict(pieces, complete, self.db.threshold)
    if verdict == "fine" then
        self.armed = true
    elseif verdict == "low" and self.armed and GetTime() >= self.quietUntil then
        self.armed = false
        Warn(PieceName(lowest.slot), FP:DurabilityPercent(lowest))
    end
end

--- Holds the warning back for a moment and looks again once it is over.
local function Settle()
    M.quietUntil = GetTime() + QUIET
    if C_Timer and C_Timer.After then
        C_Timer.After(QUIET + 0.1, function()
            FP:Safe("DurabilityWarning:Update", M.Update, M)
        end)
    end
end

--- The warning as it would come, for the page's button. It answers about the
--- lowest piece whatever the threshold, and neither uses the real warning up
--- nor arms it again.
function M:Preview()
    local pieces, complete = FP:ReadWornPieces()
    local _, lowest = FP:DurabilityVerdict(pieces, complete, 100)
    if lowest then
        Warn(PieceName(lowest.slot), FP:DurabilityPercent(lowest))
    else
        Warn(L["Durability"], tonumber(self.db.threshold) or 20)
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, isLogin, isReload)
        if event == "PLAYER_ENTERING_WORLD" and (isLogin or isReload) then Settle() end
        FP:Safe("DurabilityWarning:Update", M.Update, M)
    end)

    -- Asked rather than assumed, because an event this build does not know
    -- raises when it is registered.
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
                             "PLAYER_REGEN_ENABLED", "UPDATE_INVENTORY_ALERTS",
                             "UPDATE_INVENTORY_DURABILITY" }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end

    self.armed = true
    Settle()
    self:Update()
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    FP:HideFlashLine(ALERT_LINE)
end

--- A new threshold is judged at once, against what is worn.
function M:Reapply()
    self:Update()
end
