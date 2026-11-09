-- The chat: how it reads, what surrounds it, what it remembers. Phase 6.
--
-- Replaces ChatTweaks, by the owner's decision on 2026-09-23 and against the
-- recommendation to grow it instead. Its three settings keep their keys and
-- are carried over by migration 6 to 7 in Core/Config.lua.
--
-- **One module in several files.** This one declares the page, which has to be
-- a single ordered list, and runs the parts; each feature lives in a file of
-- its own and registers itself with M:Part. The files load after this one and
-- before Boot, and nothing in them runs until the module is switched on.
--
--   Chat.lua         the page, the parts, the chat windows
--   ChatWindow.lua   wheel, fading, appearance, buttons, tabs, input
--   ChatLines.lua    labels, names, icons and the full name on hover
--   ChatSearch.lua   the search bar
--   ChatSound.lua    a sound for a whisper and for a short list of others
--   ChatHistory.lua  the chat, kept across sessions
--
-- **Hooks, never replacements, on anything the client's own chat code runs.**
-- The chat input carries secure slash commands, and an addon that runs the
-- client's chat functions from its own code, or writes the values they read,
-- can leave that input tainted: the next /cast typed into it is refused.
-- hooksecurefunc and HookScript run after the client's code and leave it
-- clean, so that is the only way in here. The one old exception is the mouse
-- wheel, which ChatTweaks replaced in 0.1.0 and which has never been reported;
-- it is written up in ChatWindow.lua and belongs to phase 7's taint audit.
--
-- **Where the client already has a switch, this page shows the client's.** The
-- timestamp format, the style of the input line, the text size and the colors
-- are the client's own settings; the rows for them read and write the client's
-- value and store nothing, so there are never two switches for one thing. See
-- `get` and `set` in Core/Options.lua.

local ADDON, FP = ...
local L, N = FP.L, FP.N

-- Values read from the client, with a fallback for a build that lacks them.
-- The client's own list of chat text sizes is what its tab menu offers.
local SIZES = {}
for _, height in ipairs(type(CHAT_FONT_HEIGHTS) == "table" and CHAT_FONT_HEIGHTS
                        or { 12, 14, 16, 18 }) do
    SIZES[#SIZES + 1] = { height, tostring(height) }
end

--- A console variable, or nil when the client will not say.
local function CVar(name)
    local get = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
    if not get then return nil end
    local ok, value = pcall(get, name)
    return ok and FP:Plain(value) or nil
end

--- Sets a console variable. The client's own options read the same value.
local function SetCVar(name, value)
    local set = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if not set then return false end
    return (pcall(set, name, value))
end

--- Seconds as a short reading: "45 s", "2 min", "1 min 30 s".
local function Seconds(value)
    value = math.floor(tonumber(value) or 0)
    if value < 60 then return L["%d s"]:format(value) end
    local minutes, rest = math.floor(value / 60), value % 60
    if rest == 0 then return L["%d min"]:format(minutes) end
    return L["%d min %d s"]:format(minutes, rest)
end

local M = FP:RegisterModule("Chat", {
    default = true,

    -- Its own page, and off the module list, the way BuffExpiry, Consumables
    -- and Tooltip left it: twelve features do not fit under a row. A module
    -- that leaves the list carries its own switch on its page.
    page      = N["Chat"],
    pageOrder = 60,
    hidden    = true,
    group     = "chat",

    desc = L["Controls the chat's appearance, its surrounding buttons, and "
        .. "notification sounds."],

    options = {
        -- The box on the Chat tab since 2026-09-30; this entry only words it
        -- there. It was the only row under a General heading, which went with
        -- it: a heading over nothing says a part is there and shows a gap.
        { type = "module", labelOn = L["Chat changes are on"],
          labelOff = L["Chat changes are off"],
          desc = L["Off leaves the chat as the client has it. The settings "
              .. "are kept."] },

        { type = "group", label = L["Names"] },

        { key = "nameStyle", type = "select", default = "full",
          label = L["How names are written"],
          values = {
              { "full",     L["Full name"] },
              { "initial",  L["Initial and surname"] },
              { "first",    L["First name only"] },
              { "surname",  L["Surname only"] },
              { "initials", L["Initials"] },
          },
          desc = L["Shortens the name of the sender of each line. Hover over "
              .. "a shortened name to see the full name. Whispers are always "
              .. "addressed to the full name."] },

        -- One switch each and a size, by the owner's decision at the gate:
        -- not per chat type, channel or tab. See ChatLines.lua. **Both on by
        -- default**, his decision of 2026-09-27, the first of phase 6's
        -- defaults to be settled.
        { key = "raceIcons", type = "toggle", default = true,
          label = L["Race icon before the name"],
          desc = L["The race of whoever wrote a line, as an icon in front of "
              .. "the name."] },

        -- CF5 on CurseForge, settled with the owner on 2026-10-17: the
        -- client's own SD art beside the HD art drawn so far, which stays the
        -- default, so the switch above keeps meaning on or off. See IconsFor
        -- in ChatLines.lua.
        { key = "raceStyle", type = "select", default = "hd", sub = true,
          label = L["Portrait style"],
          values = {
              { "hd", L["HD"] },
              { "sd", L["SD"] },
          },
          disabled = function(mod) return not mod.db.raceIcons end,
          disabledText = L["Not in use until you switch on the race icon."],
          desc = L["HD shows the newer race portraits, SD the older ones. A "
              .. "race without an SD portrait keeps its HD one. Lines already "
              .. "in the chat keep theirs."] },

        { key = "classIcons", type = "toggle", default = true,
          label = L["Class icon before the name"],
          desc = L["The class of whoever wrote a line, as an icon in front of "
              .. "the name."] },

        { key = "iconSize", type = "number", default = 14,
          label = L["Icon size"], min = 8, max = 24, step = 1, sub = true,
          format = function(value) return L["%d px"]:format(value) end,
          disabled = function(mod) return not (mod.db.raceIcons or mod.db.classIcons) end,
          disabledText = L["Not in use until you switch on a race or class "
                      .. "icon."],
          desc = L["Sets the size of both icons. Lines already in the chat "
              .. "keep the size they had when they arrived."] },

        { type = "group", label = L["Channel Labels"] },

        -- The whole block on one switch, on by default, asked for by the owner
        -- on 2026-09-27 for anybody who wants the client's labels back in one
        -- click. What was typed below is kept while it is off.
        { key = "channelLabels", type = "toggle", default = true,
          label = L["Use the labels below"],
          desc = L["Off: channels and groups appear in chat as the game "
              .. "writes them. Your labels below are kept."] },

        -- One field per channel and per group chat, filled from what the
        -- character is in rather than from a fixed list: see ChatLines.lua.
        { type = "custom", label = L["Channel labels"],
          build   = function(holder, width, mod) return mod:BuildLabels(holder, width) end,
          refresh = function(holder, mod) mod:RefreshLabels(holder) end,
          disabled = function(mod) return not mod.db.channelLabels end,
          disabledText = L["Not in use until you switch the labels on."],
          desc = L["A numbered channel uses its number as its label unless "
              .. "you enter a different one. Labels move with their channels "
              .. "when you reorder them. A number entered in a field always "
              .. "refers to that channel's number. An empty field leaves the "
              .. "label as the client writes it. The square beside each "
              .. "field shows that chat's color."] },

        { type = "group", label = L["Timestamps"] },

        -- No formats with brackets of their own since 2026-09-27: the chat
        -- writes every timestamp in square brackets, so the owner struck the
        -- two that only differed by them. A client still set to one of those
        -- is shown as its plain twin, which is what it looks like on screen.
        -- `id` names the row for the two below it whose cause it can be.
        { type = "select", label = L["Timestamp format"], default = "none",
          id = "timestamps",
          values = {
              { "none",          L["None"] },
              { "%H:%M ",        "15:27" },
              { "%H:%M:%S ",     "15:27:32" },
              { "%I:%M %p ",     L["03:27 PM"] },
              { "%I:%M:%S %p ",  L["03:27:32 PM"] },
          },
          get = function()
              local value = CVar("showTimestamps")
              local plain = value and value:match("^%[(.-)%](%s*)$")
              if plain then return plain .. " " end
              return value
          end,
          set = function(_, value) SetCVar("showTimestamps", value) end,
          desc = L["Uses the client's timestamp setting. Changing it here "
              .. "also changes it in the game's options, and vice versa. "
              .. "Timestamps appear in square brackets."] },

        { type = "group", label = L["Appearance"] },

        -- 16 for a window whose size nobody ever chose, the owner's default
        -- of 2026-09-27: see M:DefaultFontSize below.
        { type = "select", label = L["Text size"], default = 16, values = SIZES,
          get = function(mod) return mod:FontSize() end,
          set = function(mod, value) mod:SetFontSize(value) end,
          desc = L["Sets the text size for every chat window at once. Each "
              .. "window's tab menu can still set its size individually. "
              .. "Windows without a chosen size default to 16."] },

        { key = "spacing", type = "number", default = 0,
          label = L["Space between lines"], min = 0, max = 8, step = 1,
          format = function(value) return L["%d px"]:format(value) end,
          desc = L["Extra room between two lines of chat."] },

        -- Thin by default, the owner's decision of 2026-09-27.
        { key = "outline", type = "select", default = "OUTLINE",
          label = L["Outline"],
          values = {
              { "NONE",         L["None"] },
              { "OUTLINE",      L["Thin"] },
              { "THICKOUTLINE", L["Thick"] },
          },
          desc = L["Adds an outline around every letter, alongside the "
              .. "shadow."] },

        { type = "group", label = L["Chat Window"] },

        { key = "hideButtons", type = "toggle", default = false,
          label = L["Hide the chat buttons"],
          desc = L["Hides the buttons beside the chat window and the one "
              .. "that jumps to the newest line."] },

        -- Species's wish on CurseForge, the owner's decision of 2026-10-15:
        -- only the left, and only while the buttons that room is kept for
        -- are hidden. See the edges in ChatWindow.lua.
        { key = "leftEdge", type = "toggle", default = false, sub = true,
          label = L["Let the window reach the left edge"],
          disabled = function(mod) return not mod.db.hideButtons end,
          disabledText = L["Not in use until you hide the chat buttons."],
          desc = L["Removes the room kept free for the buttons on the left "
              .. "of the main chat window, so it can be moved up to the left "
              .. "edge of the screen."] },

        { key = "tabsOnHover", type = "toggle", default = false,
          label = L["Show tabs only under the mouse"],
          desc = L["The window tabs disappear while the mouse is elsewhere. A "
              .. "tab with a new message still lights up."] },

        -- CF6.7 on CurseForge, settled with the owner on 2026-10-18: one
        -- opacity for the background of every tab, the client's own look at
        -- 100 by default. See the tabs in ChatWindow.lua.
        { key = "tabAlpha", type = "number", default = 100,
          label = L["Tab background opacity"], min = 0, max = 100, step = 10,
          format = function(value) return value .. "%" end,
          desc = L["Sets the opacity of every chat tab's background. The tab "
              .. "names stay fully visible."] },

        -- Fading, under Chat Window since 2026-10-20 rather than under
        -- Appearance, the owner's word: it reaches the window's background
        -- and its tabs as well as the lines.
        { key = "noFade", type = "toggle", default = true,
          label = L["Never fade chat out"],
          desc = L["Old lines stay on screen rather than dimming and vanishing."] },

        -- 10 for a profile that starts from nothing since 2026-10-20, the
        -- owner's word, where it was 120; a profile from before keeps its
        -- stored value, since the defaults are written into every profile.
        { key = "fadeAfter", type = "number", default = 10,
          label = L["Fade after"], min = 10, max = 600, step = 10, sub = true,
          format = Seconds,
          disabled = function(mod) return mod.db.noFade end,
          disabledText = L["Not in use until you let the chat fade."],
          desc = L["How long a line stays before it fades."] },

        -- The owner's wish of 2026-10-20, on by default at his word. See the
        -- reveal part in ChatWindow.lua.
        { key = "revealChat", type = "toggle", default = true, sub = true,
          label = L["Show chat on hover or while typing"],
          disabled = function(mod) return mod.db.noFade end,
          disabledText = L["Not in use until you let the chat fade."],
          desc = L["Shows faded lines while the mouse is over the chat "
              .. "window or the input line is open. Afterward, they stay for "
              .. "the time set under \"Fade after\"."] },

        -- Gematriah's request of 2026-10-19, off by default, the owner's word
        -- of 2026-10-20. See the backdrop part in ChatWindow.lua.
        { key = "fadeBackground", type = "toggle", default = false, sub = true,
          label = L["Fade the background with the messages"],
          disabled = function(mod) return mod.db.noFade end,
          disabledText = L["Not in use until you let the chat fade."],
          desc = L["Fades the window's background and tabs out with the last "
              .. "line. They return at your chosen opacity with a new message, "
              .. "when you scroll, while the mouse is over the window, or "
              .. "while you type."] },

        { type = "toggle", label = L["Show the input line only after Enter"],
          default = false,
          get = function() return CVar("chatStyle") == "classic" end,
          set = function(_, on) SetCVar("chatStyle", on and "classic" or "im") end,
          desc = L["Uses the client's chat style: the input line appears "
              .. "when you press Enter and disappears when the message is "
              .. "sent. Takes effect the next time the input line closes."] },

        { type = "group", label = L["Input"] },

        -- The same wish's second half, for every chat window, and a third
        -- place since 1.0.2, silhouetteone's request of 2026-10-20: the
        -- switch "Show the input line above the window" put it between the
        -- window and its tabs, and migration 9 to 10 keeps that for whoever
        -- had it on. See the edges in ChatWindow.lua.
        { key = "inputPlace", type = "select", default = "below",
          label = L["Input line position"],
          values = {
              { "below",   L["Below the window"] },
              { "between", L["Between window and tabs"] },
              { "above",   L["Above the tabs"] },
          },
          desc = L["Places the input line of every chat window below the "
              .. "window, between the window and its tabs, or above the tabs."] },

        -- Caught by the addon since 2026-09-27, against the recommendation:
        -- the client's input ignores plain arrows. See ChatWindow.lua.
        { key = "arrowHistory", type = "toggle", default = true,
          label = L["Arrow keys bring back what you sent"],
          desc = L["Use the Up and Down arrows in the input line to browse "
              .. "messages you sent during this session without holding Alt. "
              .. "Protected commands like /target and /cast still need Alt. "
              .. "In combat, keys without a modifier that the input does not use "
              .. "have no effect while it is open."] },

        { type = "group", label = L["Mouse Wheel"] },

        { key = "fastScroll", type = "toggle", default = true,
          label = L["Shift and the wheel jump to the top or bottom"],
          desc = L["Hold Shift and move the wheel one notch to jump straight "
              .. "to the top or bottom."] },

        { key = "scrollStep", type = "number", default = 3,
          label = L["Lines per wheel notch"], min = 1, max = 10, step = 1,
          desc = L["How far one notch of the wheel moves."] },

        { type = "group", label = L["Copy and Search"] },

        -- On by default, the owner's decision of 2026-10-30. See ChatLines.lua.
        { key = "webAddresses", type = "toggle", default = true,
          label = L["Copy web addresses"],
          desc = L["Makes web addresses in chat clickable for copying."] },

        -- Into an input that is open, and the switch under it opens a closed
        -- one: see ChatLines.lua for what that risks. On by default, the
        -- owner's decision of 2026-09-27; the label was cut to fit the row
        -- the same day, when the first one ran past the window.
        { key = "stampClick", type = "toggle", default = true,
          label = L["Shift click a timestamp to quote its line"],
          disabled = function() return (CVar("showTimestamps") or "none") == "none" end,
          causes = function() return { "timestamps" } end,
          disabledText = L["Not in use until you choose a timestamp format."],
          desc = L["A Shift click on a timestamp copies the whole line into "
              .. "the chat input, including the timestamp and sender, "
              .. "without sending it. Lines that arrived before this was "
              .. "enabled stay unchanged."] },

        -- The owner's choice of 2026-09-27, taken against the recommendation
        -- once the risk was put to him: see ChatLines.lua before touching it.
        { key = "stampOpen", type = "toggle", default = true, sub = true,
          label = L["Open the chat input when it is closed"],
          disabled = function(mod)
              return not mod.db.stampClick
                  or (CVar("showTimestamps") or "none") == "none"
          end,
          causes = function(mod)
              local out = {}
              if not mod.db.stampClick then out[#out + 1] = "stampClick" end
              if (CVar("showTimestamps") or "none") == "none" then
                  out[#out + 1] = "timestamps"
              end
              return out
          end,
          disabledText = L["Not in use until you switch on Shift clicking a "
                      .. "timestamp."],
          desc = L["A Shift click on a timestamp opens the chat input with "
              .. "the line already entered, so you do not need to press "
              .. "Enter first."] },

        -- On by default, the owner's decision of 2026-09-27.
        { key = "search", type = "toggle", default = true,
          label = L["Search bar on the chat window"],
          desc = L["Appears in the chat window's top right corner while the "
              .. "mouse is over the window or the input line is open, unless "
              .. "it is set to be always visible. Press Enter to display every "
              .. "matching line again. The X at the end clears the search."] },

        -- The owner's wish of 2026-10-18: the bar standing all the time, off
        -- by default. It grays the fading below out, which has nothing to do
        -- while the bar never comes or goes. See ChatSearch.lua.
        { key = "searchAlways", type = "toggle", default = false, sub = true,
          label = L["Always visible"],
          disabled = function(mod) return not mod.db.search end,
          disabledText = L["Not in use until you switch the search bar on."],
          desc = L["Shows the search bar all the time, instead of only while "
              .. "the mouse is over the chat window or the input line is "
              .. "open."] },

        -- Under the bar, both the owner's additions of 2026-09-27: it fades
        -- rather than popping, and is drawn at 70 percent by default.
        { key = "searchFade", type = "toggle", default = true, sub = true,
          label = L["Fade in and out"],
          disabled = function(mod) return not mod.db.search or mod.db.searchAlways end,
          disabledText = function(mod)
              if not mod.db.search then
                  return L["Not in use until you switch the search bar on."]
              end
              return L["Not in use until you switch off Always visible."]
          end,
          desc = L["The bar fades in when the mouse comes over the chat and out "
              .. "when it leaves, rather than appearing at once."] },

        -- Never below 20 percent, the owner's floor of 2026-09-27: a bar
        -- that can hardly be seen is a bar nobody finds.
        { key = "searchAlpha", type = "number", default = 70, sub = true,
          label = L["Opacity"], min = 20, max = 100, step = 10,
          format = function(value) return value .. "%" end,
          disabled = function(mod) return not mod.db.search end,
          disabledText = L["Not in use until you switch the search bar on."],
          desc = L["Sets the search bar's opacity."] },

        -- CF6.8 on CurseForge, settled with the owner on 2026-10-18: one
        -- offset for every chat window, from the corner the bar has always
        -- sat in, none by default. See ChatSearch.lua.
        { key = "searchX", type = "number", default = 0, sub = true,
          label = L["Horizontal offset"], min = -600, max = 600, step = 5,
          bigStep = 50,
          disabled = function(mod) return not mod.db.search end,
          disabledText = L["Not in use until you switch the search bar on."],
          desc = L["Moves the search bar to the right of its place in the chat "
              .. "window's top right corner, or to the left below zero. Hold "
              .. "Shift for steps of 50."] },

        { key = "searchY", type = "number", default = 0, sub = true,
          label = L["Vertical offset"], min = -600, max = 600, step = 5,
          bigStep = 50,
          disabled = function(mod) return not mod.db.search end,
          disabledText = L["Not in use until you switch the search bar on."],
          desc = L["Moves the search bar up from its place in the chat "
              .. "window's top right corner, or down below zero. Hold Shift "
              .. "for steps of 50."] },

        { type = "action", label = L["Reset position"], width = 150,
          disabled = function(mod) return not mod.db.search end,
          desc = L["Puts the search bar back in the chat window's top right "
              .. "corner."],
          run = function(mod)
              mod.db.searchX, mod.db.searchY = 0, 0
              FP:RefreshModule(mod.name)
              FP:NotifyOptionChanged(mod)
          end },

        { type = "group", label = L["History"] },

        { key = "history", type = "toggle", default = true,
          label = L["Keep the chat across sessions"],
          desc = L["Saves every chat window when you log out or reload and "
              .. "restores them when this character logs in again."] },

        -- Capped by what a window holds, 128 lines on this client: a line
        -- that would not fit when it came back is not worth writing down.
        { key = "historyLines", type = "number", default = 100,
          label = L["Lines kept per window"], min = 25, step = 25, sub = true,
          max = function(mod) return mod:WindowCapacity() end,
          disabled = function(mod) return not mod.db.history end,
          disabledText = L["Not in use until you keep the chat across "
                      .. "sessions."],
          desc = L["Keeps the newest lines in each window, up to the number "
              .. "of lines that window can hold."] },

        { type = "group", label = L["Sounds"] },

        { type = "custom", label = L["Sounds"],
          build   = function(holder, width, mod) return mod:BuildSounds(holder, width) end,
          refresh = function(holder, mod) mod:RefreshSounds(holder) end,
          desc = L["Plays a selected sound for each enabled message type. "
              .. "The button beside it plays the selected sound."] },

        -- 10 seconds by default since 2026-09-27, the owner's number, and
        -- raid warnings have their own below it. Named "Pause per person"
        -- for an evening, until the owner asked whether it reached officer
        -- chat as well: it reaches every row above it, per person and per kind
        -- of message, so the name says what it pauses rather than for whom.
        -- In steps of one second since 2026-10-06, both pauses, the owner's
        -- request: ten were too coarse.
        { key = "soundPause", type = "number", default = 10,
          label = L["Pause between sounds"],
          min = 0, max = 600, step = 1, format = Seconds,
          desc = L["After a sound plays, further messages of the same type "
              .. "from the same person are silent until this much time has "
              .. "passed. Applies to whispers, officer chat and messages "
              .. "from the party and raid leader. Messages from other people "
              .. "play a sound immediately."] },

        -- Raid warnings below the shared pause, above their own: the owner's
        -- order of 2026-09-27, so each pause sits under the rows it governs.
        { type = "custom", label = L["Raid Warnings"],
          build   = function(holder, width, mod) return mod:BuildSounds(holder, width, true) end,
          refresh = function(holder, mod) mod:RefreshSounds(holder) end,
          desc = L["Plays a selected sound for raid warnings. The button "
              .. "beside it plays the selected sound."] },

        { key = "raidWarningPause", type = "number", default = 0,
          label = L["Pause between raid warnings"],
          min = 0, max = 600, step = 1, format = Seconds,
          desc = L["After a raid warning's sound plays, further raid "
              .. "warnings from the same person are silent until this much "
              .. "time has passed. At 0, every raid warning plays a sound."] },

        -- Filled by the sound and label parts, created on demand: a table as
        -- a default would be shared by every profile by reference.
        { key = "labels", type = "store" },
        { key = "sounds", type = "store" },
    },
})

M.CVar, M.SetCVar, M.Seconds = CVar, SetCVar, Seconds

-- ---------------------------------------------------------------------------
-- Parts
--
-- Each feature file registers one. A part has Enable, Disable and optionally
-- Apply, which brings it in line with changed settings without being torn
-- down, and Frames, which is told about chat windows that appeared since.
-- ---------------------------------------------------------------------------

M.parts = {}

function M:Part(name, part)
    part.name = name
    self.parts[#self.parts + 1] = part
    return part
end

local function Each(method, ...)
    for _, part in ipairs(M.parts) do
        if part[method] then
            FP:Safe("Chat " .. part.name .. ":" .. method, part[method], part, M, ...)
        end
    end
end

--- Every chat window there is, once each: the ten numbered ones and any the
--- client opened since, a whisper window above all.
--
-- **whisperMode reads "popout" on this client**, so a whisper opens a window
-- of its own, and that window did not exist when the module started.
function M:EachFrame(fn)
    local seen, names = {}, {}
    if type(CHAT_FRAMES) == "table" then
        for _, name in ipairs(CHAT_FRAMES) do names[#names + 1] = name end
    end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do names[#names + 1] = "ChatFrame" .. i end

    for _, name in ipairs(names) do
        local frame = _G[name]
        if type(frame) == "table" and not seen[frame]
           and type(frame.AddMessage) == "function" then
            seen[frame] = true
            fn(frame, name)
        end
    end
end

--- The input line that belongs to a chat window.
function M:EditBoxOf(frame, name)
    local box = rawget(frame, "editBox")
    if type(box) ~= "table" then box = _G[(name or frame:GetName() or "") .. "EditBox"] end
    return type(box) == "table" and box or nil
end

-- ---------------------------------------------------------------------------
-- Reading what a window holds
--
-- The search and the history both read a window's lines, and both need them
-- in order. **GetMessageInfo(1) is the oldest line**, read in the client's
-- source on 2026-09-27: a window adds at the front of its buffer and counts
-- its messages from the back. Until then the order was not assumed and every
-- line added was tracked to find out, which cost a second hook per line.
-- ---------------------------------------------------------------------------

-- In front of every line this module prints back into a window, the search's
-- results for one, so that nothing reads them as new and neither the search
-- nor the history takes them for lines of their own.
M.REPRINT = "|cff808080>|r "

--- Every line a window holds, oldest first, as { text, r, g, b }. A line the
--- client will not hand over, a secret one, is left out.
function M:LinesOf(frame)
    local out = {}
    if not (frame.GetNumMessages and frame.GetMessageInfo) then return out end
    local ok, count = pcall(frame.GetNumMessages, frame)
    if not ok or type(count) ~= "number" then return out end

    for index = 1, count do
        local okLine, text, r, g, b = pcall(frame.GetMessageInfo, frame, index)
        text = okLine and FP:Plain(text)
        if text then out[#out + 1] = { text = text, r = r, g = g, b = b } end
    end
    return out
end

--- How many lines a chat window holds: 128 on this client, set by the
--- client's own chat code when a window is made. Read rather than assumed.
function M:WindowCapacity()
    local frame = _G.ChatFrame1
    local ok, count = pcall(frame and frame.GetMaxLines or function() end, frame)
    count = ok and tonumber(count)
    return (count and count > 0) and count or 128
end

--- Settings changed while the module keeps running.
function M:ApplyParts()
    if not self.enabled then return end
    for _, part in ipairs(self.parts) do
        if part.Apply then
            FP:Safe("Chat " .. part.name .. ":Apply", part.Apply, part, self)
        elseif part.Disable and part.Enable then
            FP:Safe("Chat " .. part.name .. ":Disable", part.Disable, part, self)
            FP:Safe("Chat " .. part.name .. ":Enable", part.Enable, part, self)
        end
    end
end

-- The windows can change under a running module. Hooked once, and asked
-- whether the module is running every time.
local watching = false

local function FramesChanged()
    if not M.enabled then return end
    Each("Frames")
end

local function Watch()
    if watching then return end
    watching = true

    M.watcher = M.watcher or CreateFrame("Frame")
    FP:RegisterEvents(M.watcher, {
        UPDATE_CHAT_WINDOWS = true, UPDATE_FLOATING_CHAT_WINDOWS = true,
    }, "Chat")
    M.watcher:SetScript("OnEvent", function(_, event)
        FP:Safe("Chat:FramesChanged", FramesChanged)
        -- The moment the client has read its chat windows, which is when a
        -- size that was never chosen can be told apart from one that was.
        if event == "UPDATE_CHAT_WINDOWS" and M.enabled then
            FP:Safe("Chat:DefaultFontSize", M.DefaultFontSize, M)
        end
    end)

    if hooksecurefunc and type(_G.FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            FP:Safe("Chat:FramesChanged", FramesChanged)
        end)
    end
end

function M:OnEnable()
    Watch()
    Each("Enable")
    FP:Safe("Chat:DefaultFontSize", M.DefaultFontSize, M)
end

function M:OnDisable()
    for index = #self.parts, 1, -1 do
        local part = self.parts[index]
        if part.Disable then
            FP:Safe("Chat " .. part.name .. ":Disable", part.Disable, part, self)
        end
    end
end

--- A profile switch, or an option without an apply of its own.
function M:Reapply()
    self:ApplyParts()
end

-- ---------------------------------------------------------------------------
-- The text size, which is the client's own setting
--
-- Read from the first window and written to every one, through the call the
-- client's tab menu stores it with. Not through that menu's own function: it
-- is the client's Lua, and running it from here is how an addon ends up
-- inside the client's chat code.
-- ---------------------------------------------------------------------------

function M:FontSize()
    local frame = _G.ChatFrame1
    if not (frame and frame.GetFont) then return nil end
    local ok, _, size = pcall(frame.GetFont, frame)
    if not ok or type(size) ~= "number" then return nil end
    return math.floor(size + 0.5)
end

function M:SetFontSize(size)
    size = tonumber(size)
    if not size then return end
    self:EachFrame(function(frame)
        local ok, path, _, flags = pcall(frame.GetFont, frame)
        if ok and path then pcall(frame.SetFont, frame, path, size, flags) end
        local okId, id = pcall(frame.GetID, frame)
        if okId and type(id) == "number" and id >= 1 and id <= (NUM_CHAT_WINDOWS or 10)
           and _G.SetChatWindowSize then
            pcall(_G.SetChatWindowSize, id, size)
        end
    end)
end

-- The addon's default, decided by the owner on 2026-09-27.
local DEFAULT_TEXT_SIZE = 16

--- Gives every chat window whose size was never chosen the addon's default.
--
-- **The client says which those are.** GetChatWindowInfo answers a size of 0
-- for a window nobody ever picked a size for, and the client itself then draws
-- it at its CHAT_FRAME_DEFAULT_FONT_SIZE, 18 on this build: read in its
-- FloatingChatFrame.lua the same day, and seen in the saved chat caches, where
-- the characters the owner never touched read SIZE 0 on every window. So a
-- player who chose a size keeps it, and once a window has the 16 it is no
-- longer 0 and is never touched again. Nothing is stored for it.
--
-- Only once the client has read its windows: the first always has a name by
-- then, and asking before that could read a chosen size as never chosen.
function M:DefaultFontSize()
    local info, set = _G.GetChatWindowInfo, _G.SetChatWindowSize
    if not (info and set) then return end
    local okFirst, firstName = pcall(info, 1)
    if not (okFirst and FP:Plain(firstName)) then return end

    for id = 1, (NUM_CHAT_WINDOWS or 10) do
        local ok, _, size = pcall(info, id)
        local unset = ok and pcall(function() return size == 0 end) and size == 0
        if unset then
            pcall(set, id, DEFAULT_TEXT_SIZE)
            local frame = _G["ChatFrame" .. id]
            if type(frame) == "table" and frame.GetFont then
                local okFont, path, _, flags = pcall(frame.GetFont, frame)
                if okFont and path then
                    pcall(frame.SetFont, frame, path, DEFAULT_TEXT_SIZE, flags)
                end
            end
        end
    end
end
