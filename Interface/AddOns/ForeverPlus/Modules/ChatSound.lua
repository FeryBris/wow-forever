-- A sound when somebody writes to you, and for a short fixed list of others.
--
-- Phase 6.5, asked for twice on CurseForge, grilled on 2026-09-27:
--
--   * **the client's own sounds**, a short list with a button to hear one;
--     nothing is bundled, so the provenance question never arises
--   * **whispers plus a fixed list**, against the recommendation of whispers
--     alone: officer chat, raid warnings, the party and the raid leader, each
--     with a switch and a sound of its own
--   * **one sound per person, then quiet** until that person has paused for
--     as long as the slider says, one minute by default. Somebody else's
--     message sounds at once. Nothing while you are set to Do Not Disturb,
--     which is you asking for exactly that; it still sounds while you are away
--     from the keyboard, since being called back is half the point
--   * **ours replaces the client's own whisper sound**: see the section on it
--     below for how, which depends on the sound picked
--
-- Your own messages never sound: an outgoing whisper has an event of its own
-- and is not listened to, and your own officer or leader line is recognised by
-- its guid.

local ADDON, FP = ...
local L = FP.L
local M = FP:GetModule("Chat")

local sound = { last = {}, lastCount = 0 }

-- The kinds of message, in the order the page lists them.
local KINDS = {
    { key = "WHISPER",      label = L["Whispers"],
      events = { "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" },
      default = true,  kit = "TELL_MESSAGE" },
    { key = "OFFICER",      label = L["Officer Chat"],
      events = { "CHAT_MSG_OFFICER" },      kit = "TELL_MESSAGE" },
    -- On by default like whispers, the owner's decision of 2026-09-27, and
    -- with a pause of its own, 0 by default, also his: a raid warning is
    -- worth hearing every time, however recently the same leader sent one.
    { key = "RAID_WARNING", label = L["Raid Warnings"],
      events = { "CHAT_MSG_RAID_WARNING" },
      default = true,  kit = "RAID_WARNING", pause = "raidWarningPause" },
    { key = "PARTY_LEADER", label = L["Party Leader"],
      events = { "CHAT_MSG_PARTY_LEADER" }, kit = "TELL_MESSAGE" },
    { key = "RAID_LEADER",  label = L["Raid Leader"],
      events = { "CHAT_MSG_RAID_LEADER" },  kit = "TELL_MESSAGE" },
}

-- The client's own sounds on offer live in Core/Util.lua, FP.SOUNDS, since the
-- ammunition warning picks from the same list.
local function KitId(name) return FP:SoundKitId(name) end
local function Offered() return FP:SoundChoices() end

--- One kind's settings, created on demand.
--
-- In the profile rather than declared one by one: five kinds with a switch and
-- a sound each would be ten keys for one table's worth of meaning, and a table
-- as a declared default would be shared by every profile by reference.
local function Setting(kind)
    M.db.sounds = M.db.sounds or {}
    local stored = M.db.sounds[kind.key]
    if type(stored) ~= "table" then
        stored = { on = kind.default and true or false, kit = kind.kit }
        M.db.sounds[kind.key] = stored
    end
    if stored.kit == nil then stored.kit = kind.kit end
    return stored
end

-- ---------------------------------------------------------------------------
-- The client's own whisper sound
--
-- The stock chat plays one for a whisper, only for the first after a quiet
-- spell of minutes, and it is this file. Found in the community listfile on
-- 2026-09-27: 567421 is sound/interface/itellmessage.ogg, which is what the
-- client's TELL_MESSAGE plays.
--
-- **Ours replaces it**, the owner's answer, in two ways depending on the sound
-- picked. Another sound: the client's file is muted while ours is on, so a
-- whisper makes exactly one sound. The same sound: muting the file would mute
-- ours with it, so nothing is muted, and ours stays quiet in the moment the
-- client has just played it. The file is left alone as well while any kind of
-- message is set to that sound, for the same reason.
-- ---------------------------------------------------------------------------

local TELL_KIT  = "TELL_MESSAGE"
local TELL_FILE = 567421

-- When something other than this module last played each sound, by id.
local clientPlayed = {}
local playing = false
local watchingSounds = false

local function WatchSounds()
    if watchingSounds or not (hooksecurefunc and PlaySound) then return end
    watchingSounds = true
    hooksecurefunc("PlaySound", function(id)
        if playing then return end
        local ok, plain = pcall(function() return tonumber(id) end)
        if ok and plain then clientPlayed[plain] = GetTime and GetTime() or 0 end
    end)
end

local function Play(name)
    local id = KitId(name)
    if not id or not PlaySound then return false end
    -- The master channel, so a notice is heard with sound effects turned off,
    -- which is how the client plays its own alerts.
    playing = true
    local ok = pcall(PlaySound, id, "Master")
    playing = false
    return ok
end

local muted = false

local function WantMute()
    if not M.enabled then return false end
    local whisper = Setting(KINDS[1])
    if not (whisper.on and whisper.kit ~= TELL_KIT) then return false end
    for _, kind in ipairs(KINDS) do
        local setting = Setting(kind)
        if setting.on and setting.kit == TELL_KIT then return false end
    end
    return true
end

local function UpdateMute()
    local want = WantMute()
    if want == muted then return end
    local call = want and rawget(_G, "MuteSoundFile") or rawget(_G, "UnmuteSoundFile")
    if type(call) == "function" and pcall(call, TELL_FILE) then muted = want end
end

--- The Play button: the sound picked, now, even the client's own whisper
--- sound while it is muted.
local function Preview(name)
    if name == TELL_KIT and muted and rawget(_G, "UnmuteSoundFile") then
        pcall(UnmuteSoundFile, TELL_FILE)
        muted = false
        local played = Play(name)
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function() UpdateMute() end)
        else
            UpdateMute()
        end
        return played
    end
    return Play(name)
end

local kindByEvent = {}
for _, kind in ipairs(KINDS) do
    for _, event in ipairs(kind.events) do kindByEvent[event] = kind end
end

local function DoNotDisturb()
    if not UnitIsDND then return false end
    local ok, dnd = pcall(UnitIsDND, "player")
    return ok and FP:Truth(dnd) == true
end

local function OnMessage(event, ...)
    if not M.enabled then return end
    local kind = kindByEvent[event]
    if not kind then return end
    local setting = Setting(kind)
    if not setting.on or DoNotDisturb() then return end

    -- The sender: the guid where the line carries one, the name otherwise.
    -- A Battle.net whisper carries neither in a usable form on some builds,
    -- and then all of them count as one person, which errs on the quiet side.
    local guid = FP:Plain((select(12, ...)))
    if guid and guid == FP.charKey then return end
    local who = guid or FP:Plain((select(2, ...))) or "?"

    local key = kind.key .. "/" .. who
    local now = GetTime and GetTime() or 0
    local previous = sound.last[key]
    if previous == nil then
        sound.lastCount = sound.lastCount + 1
        -- Bounded, and started again when full: a week of raids is a few
        -- hundred people, and forgetting one only costs a sound.
        if sound.lastCount > 500 then
            wipe(sound.last)
            sound.lastCount = 1
        end
    end
    sound.last[key] = now

    -- The kind's own pause where it has one, the shared one otherwise.
    local pause = tonumber(M.db[kind.pause or "soundPause"]) or 0
    if previous and now - previous < pause then return end

    -- A moment later rather than now: the client's chat frame handles the
    -- same event, in no particular order against this one, and may play the
    -- very same sound. If it did, in this frame, ours is not needed.
    local kit, at = setting.kit, now
    local function Decide()
        local id = KitId(kit)
        if id and clientPlayed[id] and clientPlayed[id] >= at then return end
        Play(kit)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Decide) else Decide() end
end

function sound:Apply()
    WatchSounds()
    UpdateMute()
    self.events = self.events or CreateFrame("Frame")
    self.events:UnregisterAllEvents()
    for _, kind in ipairs(KINDS) do
        if Setting(kind).on then
            for _, event in ipairs(kind.events) do
                -- One at a time and silently: Battle.net whispers do not
                -- exist on every build, and a missing event only means that
                -- kind of message never sounds.
                pcall(self.events.RegisterEvent, self.events, event)
            end
        end
    end
    self.events:SetScript("OnEvent", function(_, event, ...)
        FP:Safe("Chat:Sound", OnMessage, event, ...)
    end)
end

sound.Enable = sound.Apply

function sound:Disable()
    if self.events then self.events:UnregisterAllEvents() end
    -- M.enabled is already false here, so this gives the client its sound back.
    UpdateMute()
end

M:Part("sound", sound)

-- ---------------------------------------------------------------------------
-- The rows on the page: a switch, a sound, and a button to hear it
-- ---------------------------------------------------------------------------

local ROW_H  = 26
local PLAY_W = 22   -- square, the height of a button

local function BuildRow(holder, kind)
    local row = FP:CreateToggle(holder, kind.label,
        function() return Setting(kind).on end,
        function(value)
            Setting(kind).on = value and true or false
            sound:Apply()
        end)
    FP:ApplyLevel(row, "primary")
    row:SetHeight(ROW_H)

    -- A play arrow rather than a word, the owner's request of 2026-10-08:
    -- "Play" was cut short in Spanish and others, and the arrow reads in
    -- every language. The client's own submenu arrow, which this build's
    -- menus draw, so it is there without a file of ours; drained and tinted
    -- like a button's caption whenever it is shown, so it follows the color
    -- scheme. The hover says what it does.
    local play = FP:CreateButton(row, "", PLAY_W, function()
        if not Preview(Setting(kind).kit) then
            FP:Warn(L["Chat: this client has no sound called %s."],
                tostring(Setting(kind).kit))
        end
    end)
    play:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    local arrow = play:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER", 1, 0)
    local function Tint()
        arrow:SetDesaturated(true)
        arrow:SetVertexColor(play.label:GetTextColor())
    end
    play:HookScript("OnShow", Tint)
    Tint()

    -- A drop-down laid over the right half of the switch row. Its own frame
    -- takes no clicks, so the rest of the row still switches.
    local drop = FP:CreateDropdown(row, "", {
        values = Offered(),
        Get = function() return Setting(kind).kit end,
        Set = function(value)
            Setting(kind).kit = value
            UpdateMute()
        end,
    })
    drop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    drop:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(PLAY_W + 6), 0)
    -- The switch's label stops short of the drop-down's box.
    FP:FitLabel(row.text, row, drop.tooltipTargets and drop.tooltipTargets[1])

    local base = row.Refresh
    row.Refresh = function(self)
        if base then base(self) end
        drop:Refresh()
    end

    local explain = L["Plays the selected sound when a message of this type "
        .. "arrives."]
    FP:Tooltip(row, kind.label, explain)
    FP:Tooltip(drop.tooltipTargets, kind.label, L["Picks one of the game's own sounds."])
    FP:Tooltip(play, kind.label, L["Plays the selected sound now."])
    return row
end

--- The rows for one part of the list.
--
-- @param own  true for the kinds with a pause of their own, which the page
--             lists after the shared pause, each above its own stepper: raid
--             warnings, moved there by the owner on 2026-09-27 so the shared
--             pause reads as belonging to the rows above it
function M:BuildSounds(holder, width, own)
    holder:SetWidth(width)
    holder.rows = {}
    local y = 0
    for _, kind in ipairs(KINDS) do
        if (kind.pause ~= nil) == (own and true or false) then
            local row = BuildRow(holder, kind)
            row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -y)
            holder.rows[#holder.rows + 1] = row
            y = y + ROW_H
        end
    end
    return y
end

function M:RefreshSounds(holder)
    for _, row in ipairs(holder.rows or {}) do row:Refresh() end
end
