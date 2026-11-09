-- A row of numbers the client does not show anywhere.
--
-- Phase 5.2. This is the largest genuinely empty space in the roadmap, because
-- there is no data text system on this build at all. What belongs in it was
-- settled by measurement on 2026-09-23 rather than by a list: free bag slots
-- came out and became a module of its own on the backpack, the experience bar
-- tooltip came out because that bar has no mouse and giving it one steals
-- clicks, and what is left is what nothing else says. Free bag slots came back
-- on 2026-10-09 as a figure beside the backpack's rather than instead of it,
-- off by default; see *Free bag slots* further down.
--
-- **One horizontal row with short labels**, by the owner's decision. Bare
-- numbers would be a row you have to learn to read, and a row you have to learn
-- to read does not get read.
--
-- Every number here is proved before it is used. Health and power turned out to
-- be secret on this client even out of combat, so nothing that comes back from
-- it is trusted until a comparison has survived: see `Number` below and
-- `FP:Truth` in `Core/Util.lua`.

local ADDON, FP = ...
local L, N = FP.L, FP.N

-- The fonts the bar can take, CF6.1: the addon's own, which follows the
-- Design page, and the family of each of these client fonts that differs
-- from every one before it. Read from the client's own font objects and its
-- own path for combat text, never named here, the locale rule: a Russian or
-- Korean client's objects name that client's files.
local FONT_SOURCES = {
    { key = "chat",    object = "ChatFontNormal",     label = L["Chat"] },
    { key = "numbers", object = "NumberFontNormal",   label = L["Numbers"] },
    { key = "quest",   object = "QuestTitleFont",     label = L["Quest titles"] },
    { key = "mail",    object = "MailTextFontNormal", label = L["Letters"] },
    { key = "combat",  global = "DAMAGE_TEXT_FONT",   label = L["Combat text"] },
}

--- The file a source's font is drawn from, as the client names it.
local function SourcePath(source)
    if source.global then
        local path = rawget(_G, source.global)
        return type(path) == "string" and path or nil
    end
    local object = rawget(_G, source.object)
    if type(object) ~= "table" or type(object.GetFont) ~= "function" then return nil end
    local ok, path = pcall(object.GetFont, object)
    return (ok and type(path) == "string") and path or nil
end

-- The list on the page, each family once. A path is ASCII and no game text,
-- so lowering it to compare is not the folding the locale rule forbids.
local FONT_VALUES = { { "addon", L["Default"] } }
do
    local seen = {}
    local base = rawget(_G, "GameFontNormal")
    local ok, path = pcall(function() return base:GetFont() end)
    if ok and type(path) == "string" then seen[path:lower()] = true end
    for _, source in ipairs(FONT_SOURCES) do
        local found = SourcePath(source)
        if found and not seen[found:lower()] then
            seen[found:lower()] = true
            FONT_VALUES[#FONT_VALUES + 1] = { source.key, source.label }
        end
    end
end

local M = FP:RegisterModule("InfoBar", {
    -- On by default, and for its own sake since 2026-09-26. It started off, on
    -- the argument that a row of numbers over the playfield is something you
    -- ask for rather than something you find, and went on two days later only
    -- because this client forgot every setting at a cold start, so off meant
    -- switching it on every session. When build 70009 fixed that, the
    -- recommendation was to go back to off; the owner kept it on.
    default = true,

    -- Its own page and off the module list, like BuffExpiry, Consumables and
    -- Tooltip. Seven items with their own switches plus placement do not fit
    -- under a row.
    page      = N["Info bar"],
    pageOrder = 50,
    hidden    = true,

    -- The switches on the page can be dragged into the bar's order while
    -- "Allow reordering" is on, the owner's wish of 2026-10-13, see the
    -- `block` of every entry below and M:Order.
    arrange = {
        allowed = function(mod) return mod.db and mod.db.reorder end,
        order   = function(mod) return mod:Order() end,
        set     = function(mod, order) mod:SetOrder(order) end,
    },

    -- What the bar shows, since 2026-10-06, the owner's choice: the text before
    -- said what the client does not, and placed the bar at the top of the
    -- screen, which stops being true the moment it is dragged. The same text
    -- words the switch on the tab below.
    desc = L["Shows an info bar with your gold, durability, coordinates, "
         .. "latency and more."],

    options = {
        -- The box on the Info bar tab since 2026-09-30; this entry only words
        -- it there. It was the only row under a General heading, which went
        -- with it: a heading over nothing says a part is there and shows a gap.
        { type = "module", labelOn  = L["The info bar is on"],
          labelOff = L["The info bar is off"],
          desc = L["Shows an info bar with your gold, durability, "
              .. "coordinates, latency and more."] },

        -- This list is in the order the figures appear on the bar, asked for on
        -- 2026-09-24. A page that lists them in one order while the row shows
        -- them in another makes you work out which switch you are looking for.
        -- Below is the default order; since 2026-10-13 the page lists the
        -- entries in whatever order the player dragged them into, see
        -- `arrange` above.
        { type = "group", label = L["What It Shows"] },

        -- Asked for on CurseForge on 2026-10-13 and gated with the owner the
        -- same day: off by default, and first on the bar once it is on, his
        -- place for it. The two settings under it are the game clock's own,
        -- the two ticks in its window, and they write the client's console
        -- variables rather than a copy, his word: see *The time* below. They
        -- start at local time and 24 hours, see ApplyClockDefaults.
        { key = "time", type = "toggle", default = false,
          block = "time",
          label = L["Time"],
          desc = L["The time of day, as the game's own clock shows it."] },

        { type = "select", label = L["Shows"], default = "1", sub = true,
          block = "time",
          values = {
              { "1", L["Local time"] },
              { "0", L["Realm time"] },
          },
          disabled = function(mod) return not mod.db.time end,
          get = function(mod) return mod:ClockSetting("timeMgrUseLocalTime") end,
          set = function(mod, value)
              mod:SetClockSetting("timeMgrUseLocalTime", value)
          end,
          desc = L["Choose local or realm time for both this bar and the "
              .. "minimap clock."] },

        { type = "select", label = L["Format"], default = "1", sub = true,
          block = "time",
          values = {
              { "1", L["24 hours"] },
              { "0", L["12 hours"] },
          },
          disabled = function(mod) return not mod.db.time end,
          get = function(mod) return mod:ClockSetting("timeMgrUseMilitaryTime") end,
          set = function(mod, value)
              mod:SetClockSetting("timeMgrUseMilitaryTime", value)
          end,
          desc = L["Choose a 12 or 24 hour format for both this bar and the "
              .. "minimap clock."] },

        -- CF6.13 on CurseForge, settled with the owner on 2026-10-17: a click
        -- opens the game's own stopwatch and a Shift click its calendar, both
        -- on by default, each with a switch. See *Clicks on the bar* below.
        { key = "timeStopwatch", type = "toggle", default = true, sub = true,
          block = "time",
          label = L["Open the stopwatch with a click"],
          disabled = function(mod) return not mod.db.time end,
          desc = L["A click on the display opens or closes the game's "
              .. "stopwatch."] },

        { key = "timeCalendar", type = "toggle", default = true, sub = true,
          block = "time",
          label = L["Open the calendar with a Shift click"],
          disabled = function(mod) return not mod.db.time end,
          desc = L["A Shift click on the display opens or closes the game's "
              .. "calendar."] },

        -- Asked for on CurseForge on 2026-10-13 and gated with the owner the
        -- same day: off by default, the zone and the area within it in the
        -- minimap's colors. See *The zone* below. Right after the time, with
        -- the coordinates behind it, the owner's place for both once he had
        -- seen the bar the same day.
        { key = "zone", type = "toggle", default = false,
          block = "zone",
          label = L["Zone"],
          desc = L["Shows your current zone and subzone in the minimap's "
              .. "colors."] },

        { key = "coords", type = "toggle", default = true,
          block = "coords",
          label = L["Coordinates"],
          desc = L["Where you are in the current zone."] },

        -- CF6.12 on CurseForge, settled with the owner on 2026-10-17: on by
        -- default, with a switch. See *Clicks on the bar* below.
        { key = "coordsMap", type = "toggle", default = true, sub = true,
          block = "coords",
          label = L["Open the world map with a click"],
          disabled = function(mod) return not mod.db.coords end,
          desc = L["A click on the display opens or closes the world map."] },

        -- Off by default, the owner's call on 2026-09-29: it is the one figure
        -- that is also a button, so it is something to ask for.
        { key = "hearth", type = "toggle", default = false,
          block = "hearth",
          label = L["Hearthstone"],
          desc = L["Where your Hearthstone takes you and how long until it is "
              .. "ready."] },

        -- Promised on CurseForge on 2026-10-07 to a player who hearthed twice
        -- by accident while trying to move the bar. On by default, the
        -- owner's word, so nothing changes for whoever uses the click.
        { key = "hearthClick", type = "toggle", default = true, sub = true,
          block = "hearth",
          label = L["Use it with a click"],
          disabled = function(mod) return not mod.db.hearth end,
          desc = L["A click on the display uses your Hearthstone."] },

        { key = "gold", type = "toggle", default = true,
          block = "gold",
          label = L["Gold"],
          desc = L["Adds up each selected character's gold as of their last "
              .. "login."] },

        -- Promised on CurseForge on 2026-10-08 and gated with the owner on
        -- 2026-10-09: the character being played alone, and between that and
        -- everybody the characters gold can be mailed between, which another
        -- player had asked for on 2026-09-27. Every character by default, so
        -- nothing changes for anybody who does not look here. The list behind
        -- the figure named exactly the characters it counts, his answer; since
        -- 2026-10-13 it names every character, the ones not counted dimmed,
        -- asked for on CurseForge and his answer that day. The middle choice
        -- is named for the ruleset since then, WoW Forever's and the client's
        -- word for Normal and PvP, his word: it has no realms to choose from.
        -- It compares the ruleset as well as the realm, see FP:GoldCounts.
        { key = "goldScope", type = "select", default = "all", sub = true,
          block = "gold",
          label = L["Characters"],
          disabled = function(mod) return not mod.db.gold end,
          -- The rulesets as an example, the owner's wish once the choice was
          -- named for them: the names the login screen gives them on the beta.
          desc = L["Whose gold the display adds up. Its list shows every "
              .. "character, the ones not counted grayed out. A ruleset is, "
              .. "for example, Normal or PvP."],
          values = {
              { "all",     L["All"] },
              { "ruleset", L["This ruleset"] },
              { "faction", L["This ruleset and faction"] },
              { "self",    L["Only this one"] },
          } },

        -- The owner's wish of 2026-10-13, once the list named every character:
        -- off by default, so it still does; on, the ones not counted are left
        -- out of it rather than grayed out. Grayed out itself under "All",
        -- which leaves nobody out.
        { key = "goldHideOthers", type = "toggle", default = false, sub = true,
          block = "gold",
          label = L["Hide characters not counted"],
          disabled = function(mod)
              return not mod.db.gold or (mod.db.goldScope or "all") == "all"
          end,
          desc = L["The list on hover leaves out the characters the display "
              .. "does not count."] },

        -- Promised on CurseForge on 2026-09-26 and again on 2026-10-08, gated
        -- with the owner on 2026-10-09. **Off by default**, since the backpack
        -- shows the same by default, and **right after gold**, both his
        -- answers; switched apart from the backpack's own number, which keeps
        -- its switch on the Gameplay page, so no setting moves another.
        { key = "bags", type = "toggle", default = false,
          block = "bags",
          label = L["Free Bag Slots"],
          desc = L["How many of your bag slots are free."] },

        -- The player's to choose, the owner's word: one figure for every bag,
        -- special bags included, which lists each kind when hovered, or a
        -- figure for each kind, named when hovered. The first by default.
        { key = "bagsLayout", type = "select", default = "one", sub = true,
          block = "bags",
          label = L["Shown as"],
          disabled = function(mod) return not mod.db.bags end,
          desc = L["Shows one display for all bags, with a breakdown by bag "
              .. "type on hover, or one display per bag type, with its name "
              .. "on hover."],
          values = {
              { "one",   L["One display"] },
              { "kinds", L["A display per kind of bag"] },
          } },

        -- CF6.4 on CurseForge, settled with the owner on 2026-10-17: the free
        -- slots alone, or with the total as before, which stays the default.
        -- For either layout, and the hover keeps both, see Slots.
        { key = "bagsFormat", type = "select", default = "total", sub = true,
          block = "bags",
          label = L["Format"],
          disabled = function(mod) return not mod.db.bags end,
          desc = L["Shows the free slots with the total, or the free slots "
              .. "alone. The hover always shows both."],
          values = {
              { "total", L["Free and total"] },
              { "free",  L["Free only"] },
          } },

        -- A1 of the 1.0.2 brief, the owner's own request of 2026-10-21: off by
        -- default, right after the bag slots, and nothing at all without a
        -- bow, a gun or a crossbow in hand. What it counts is the player's
        -- choice, every arrow or bullet by default as on the quiver. **The
        -- switch and the threshold it turns red by are Ammunition Warning's**
        -- on the Gameplay page, shared rather than copied, his answer, so
        -- they can be set here while that page is off. See *The ammunition*
        -- below.
        { key = "ammo", type = "toggle", default = false,
          block = "ammo",
          label = L["Ammunition"],
          desc = L["How much ammunition you carry for your bow, gun or "
              .. "crossbow. Not shown while none of them is equipped."] },

        { key = "ammoCount", type = "select", default = "all", sub = true,
          block = "ammo",
          label = L["What it counts"],
          disabled = function(mod) return not mod.db.ammo end,
          desc = L["Counts every arrow or every bullet in your bags that your "
              .. "weapon fires, or only the ammunition in your ammo slot."],
          values = {
              { "all",  L["All arrows or bullets"] },
              { "slot", L["Ammo slot only"] },
          } },

        { type = "toggle", id = "ammoWarn", default = true, sub = true,
          block = "ammo",
          label = L["Warn when it runs low"],
          disabled = function(mod) return not mod.db.ammo end,
          get = function(mod) return mod:AmmoSetting("warn") ~= false end,
          set = function(mod, value) mod:SetAmmoSetting("warn", value and true or false) end,
          desc = L["Turns the display red below the amount set under this "
              .. "switch. Shared with Ammunition Warning on the Gameplay page, "
              .. "where it also shows a red line and plays a sound for "
              .. "Hunters."] },

        { type = "number", id = "ammoThreshold", default = 500, sub = true,
          block = "ammo",
          label = L["Warn below"], min = 50, max = 3000, step = 50,
          disabled = function(mod)
              return not mod.db.ammo or mod:AmmoSetting("warn") == false
          end,
          causes = function(mod)
              local out = {}
              if not mod.db.ammo then out[#out + 1] = "ammo" end
              if mod:AmmoSetting("warn") == false then out[#out + 1] = "ammoWarn" end
              return out
          end,
          get = function(mod) return tonumber(mod:AmmoSetting("threshold")) end,
          set = function(mod, value) mod:SetAmmoSetting("threshold", value) end,
          desc = L["The amount below which the display turns red. Shared "
              .. "with Ammunition Warning on the Gameplay page."] },

        -- D1 of the 1.0.2 brief, reopened by the owner on 2026-10-21 for this
        -- release: the gray stack worth the least at a merchant, destroyed
        -- with a Shift click to free a bag slot away from one. Off by default,
        -- right after the ammunition, a question first unless the switch
        -- below says otherwise, and never in combat, all his answers. Named
        -- for what the click does, in the client's own verb for it, his word
        -- of 2026-10-22. See *The cheapest gray item* below.
        { key = "junk", type = "toggle", default = false,
          block = "junk",
          label = L["Destroy Cheapest Gray Item"],
          desc = L["Shows an icon for the gray stack in your bags that is worth "
              .. "the least at a merchant. Shift click it to destroy that stack "
              .. "and free a bag slot. Not in combat."] },

        -- Off by default, the owner's word of 2026-10-22: a second key is
        -- wanted, so that a click alone never destroys anything by accident.
        -- On, a click with or without Shift destroys.
        { key = "junkPlainClick", type = "toggle", default = false, sub = true,
          block = "junk",
          label = L["Destroy with a click, without Shift"],
          disabled = function(mod) return not mod.db.junk end,
          desc = L["A click on the display destroys the stack without holding "
              .. "Shift."] },

        { key = "junkNoAsk", type = "toggle", default = false, sub = true,
          block = "junk",
          label = L["Skip the confirmation"],
          disabled = function(mod) return not mod.db.junk end,
          desc = L["Destroys the stack at once, without the question, and "
              .. "reports it in chat."] },

        -- Off by default, the owner's call on 2026-10-05, like the Hearthstone:
        -- whoever wants them switches them on. Against the recommendation,
        -- which was on, with a figure appearing once the character holds some.
        { key = "favor", type = "toggle", default = false,
          block = "favor",
          label = L["Merchant's Favor"],
          desc = L["How much Merchant's Favor this character has. Red once it "
              .. "holds as much as the game allows."] },

        { key = "honor", type = "toggle", default = false,
          block = "honor",
          label = L["Honor Points"],
          desc = L["How many Honor Points this character has. Red once it holds "
              .. "as much as the game allows."] },

        { key = "durability", type = "toggle", default = true,
          block = "durability",
          label = L["Durability"],
          desc = L["Shows the lowest durability among your equipped items."] },

        -- D01 of the after launch plan, gated with the owner on 2026-11-06: two
        -- displays, each with a switch, sharing one measurement, see
        -- *Experience* below. Off by default, like the other figures somebody
        -- asks for, and off for every profile that stored the hidden `store`
        -- values these two were from 2026-09-24 on.
        { key = "xpRate", type = "toggle", default = false,
          block = "xpRate",
          label = L["Experience per hour"],
          desc = L["How much experience you gain per hour, measured since you "
              .. "logged in. Not shown at the maximum level."] },

        { key = "xpRateClick", type = "toggle", default = true, sub = true,
          block = "xpRate",
          label = L["Restart measurement with a click"],
          disabled = function(mod) return not mod.db.xpRate end,
          desc = L["A click on the display resets the measurement for both "
              .. "experience displays."] },

        { key = "timeToLevel", type = "toggle", default = false,
          block = "timeToLevel",
          label = L["Time to the next level"],
          desc = L["Estimated time to your next level at your current "
              .. "experience rate. Not shown at the maximum level."] },

        { key = "timeToLevelClick", type = "toggle", default = true, sub = true,
          block = "timeToLevel",
          label = L["Restart measurement with a click"],
          disabled = function(mod) return not mod.db.timeToLevel end,
          desc = L["A click on the display resets the measurement for both "
              .. "experience displays."] },

        { key = "latency", type = "toggle", default = true,
          block = "latency",
          label = L["Latency"] },

        { key = "framerate", type = "toggle", default = true,
          block = "framerate",
          label = L["Frames per second"] },

        -- CF6.14 on CurseForge, settled with the owner on 2026-10-17: off by
        -- default, a question before anything happens, and never in combat.
        -- See *Clicks on the bar* below.
        { key = "framerateReload", type = "toggle", default = false, sub = true,
          block = "framerate",
          label = L["Reload the interface with a click"],
          disabled = function(mod) return not mod.db.framerate end,
          desc = L["A click on the display asks whether to reload the "
              .. "interface. Not in combat."] },

        -- Asked for on CurseForge on 2026-10-13 and gated with the owner the
        -- same day: off by default, right before the cooldowns, and a slider
        -- that opens when it is hovered, his choice over the mouse wheel. See
        -- *The volume* below.
        { key = "volume", type = "toggle", default = false,
          block = "volume",
          label = L["Volume"],
          desc = L["Shows the game's master volume. Hover over the display "
              .. "to adjust it with a slider. The speaker is crossed out "
              .. "while sound is disabled or the volume is at 0%, and the "
              .. "figure turns red while sound is disabled."] },

        -- CF6.11 on CurseForge, settled with the owner on 2026-10-17: on by
        -- default, and the volume kept, so the second click brings back what
        -- was there. See *Clicks on the bar* below.
        { key = "volumeClick", type = "toggle", default = true, sub = true,
          block = "volume",
          label = L["Turn all sound off and on with a click"],
          disabled = function(mod) return not mod.db.volume end,
          desc = L["A click on the display turns all game sound off, and the "
              .. "next one turns it back on. The volume stays as it was."] },

        -- Gated with the owner on 2026-10-10: on by default, and the icon alone
        -- on the bar, his choice over a count or the time to the next one; the
        -- list behind it names every character and every cooldown. **Last on
        -- the bar**, his place for it once he had seen it. See *Cooldowns
        -- across characters* further down.
        { key = "cooldowns", type = "toggle", default = true,
          block = "cooldowns",
          label = L["Cooldowns"],
          -- Dedicated Study by the client's own name, as every spell in the
          -- addon is named: ChatGPT could not confirm its four translations
          -- on 2026-10-11, and the owner chose the client's name over them.
          -- The id is the line in Data/Cooldowns.lua.
          desc = function()
              return L["Shows the profession cooldowns and %s for all your "
                  .. "characters. Hover over the icon to see the time "
                  .. "remaining."]:format(FP:SpellName(1225469)
                      or "Dedicated Study")
          end },

        -- CF6.1 to CF6.3 on CurseForge, settled with the owner on 2026-10-17:
        -- the bar's own font, size and text color, its status colors with a
        -- switch, its own background and border with an opacity each, and its
        -- icons, on the whole and per display. The bar alone: its hovers keep
        -- the addon's look. Nothing set is the design's look, so nothing
        -- changes for anybody who does not look here. See *The look* below.
        { type = "group", label = L["Appearance"] },

        { key = "font", type = "select", default = "addon",
          label = L["Font"],
          values = FONT_VALUES,
          desc = L["The font of the info bar. Default is the font of the "
              .. "addon, the others are fonts the game uses elsewhere."] },

        { key = "fontSize", type = "number", default = 100,
          label = L["Text size"], min = 50, max = 200, step = 5,
          format = function(value) return value .. "%" end,
          desc = L["The size of the info bar's text, relative to the text "
              .. "size on the Design page."] },

        { key = "textColor", type = "color",
          label = L["Text color"],
          fallback = function(mod) return mod:LookColor("text") end,
          desc = L["The color of the info bar's text."] },

        { key = "statusColors", type = "toggle", default = true,
          label = L["Status colors"],
          desc = L["Colors displays by their state. Off, the whole bar is in "
              .. "its text color."] },

        { key = "bgColor", type = "color", opacity = true,
          label = L["Background color"],
          fallback = function(mod) return mod:LookColor("bg") end,
          desc = L["The color and opacity of the info bar's background."] },

        { key = "borderColor", type = "color", opacity = true,
          label = L["Border color"],
          fallback = function(mod) return mod:LookColor("border") end,
          desc = L["The color and opacity of the info bar's border."] },

        { key = "icons", type = "toggle", default = true,
          label = L["Show icons"],
          desc = L["The icons in front of the displays. A display that is "
              .. "only an icon shows its name instead."] },

        { type = "custom", sub = true,
          disabled = function(mod) return not mod.db.icons end,
          build = function(holder, width, mod) return mod:BuildIconPicker(holder, width) end,
          refresh = function(holder, mod) mod:RefreshIconPicker(holder) end },

        { type = "action", label = L["Restore default look"], width = 190,
          desc = L["Puts the info bar's font, colors and icons back as the "
              .. "design has them."],
          run = function(mod) mod:ResetLook() end },

        { type = "group", label = L["Placement"] },

        -- The one session that moves every bar and the info bar, with the
        -- info bar marked, the owner's word of 2026-10-15. See
        -- Modules/Mover.lua; the hover is bar management's own.
        { type = "action", label = L["Position on screen"], width = 150,
          desc  = L["Hides settings and lets you move all bars and the info "
               .. "bar, with this bar highlighted. Apply saves positions; "
               .. "Cancel discards changes."],
          run   = function() if FP.MoveBars then FP:MoveBars("info") end end },

        { type = "action", label = L["Reset position"], width = 150, sameRow = true,
          desc  = L["Back to the default near the top of the screen."],
          run   = function(mod) mod:ResetPosition() end },

        -- The way the bag window moves, the owner's choice of 2026-10-07, off
        -- by default. See ShiftHeld.
        { key = "shiftDrag", type = "toggle", default = false,
          label = L["Move it with Shift and drag"],
          desc  = L["While Shift is held, you can drag the bar by any "
               .. "display, and clicking the Hearthstone does not use it."] },

        -- Asked for by the owner on 2026-10-13 and gated the same day: the
        -- order of the bar set by dragging the entries under What It Shows,
        -- plain drag and drop while this is on, **off by default**, his
        -- answers; and a button that puts the default order back. Here under
        -- Placement, his word once he had seen them above the entries. The
        -- order is kept per profile, like the bar's position.
        { key = "reorder", type = "toggle", default = false,
          label = L["Allow reordering"],
          desc = L["Drag the entries above to change their order on the "
              .. "info bar."] },

        { type = "action", label = L["Restore default order"], width = 190,
          disabled = function(mod) return not mod.db.reorder end,
          desc = L["Puts the entries back in their default order, here and "
              .. "on the info bar."],
          run = function(mod) mod:ResetOrder() end },

        -- The bar's order, the keys of its entries, see M:Order. Nothing
        -- stored is the default order.
        { key = "order",      type = "store" },
        -- [display] = true for each display whose icon the picker hid.
        { key = "iconsOff",   type = "store" },
        { key = "positioned", type = "store" },
        { key = "point",      type = "store" },
        { key = "relPoint",   type = "store" },
        { key = "x",          type = "store" },
        { key = "y",          type = "store" },
    },
})

local REFRESH = 1      -- seconds; nothing here moves faster than the eye reads
local BAR_H   = 20     -- the floor; the real height follows the font, see Update
local PAD     = 10     -- room between the text and the border, left and right
-- Between two cells. It replaces a drawn divider that was a bug as well as
-- too tight: a single pipe is an escape introducer in this client, so the
-- old separator rendered as the literal text "|r" between every pair of
-- values. Wider spacing was asked for on 2026-09-24 and does the same job
-- without a character in it.
local GAP     = 14

-- One icon per figure, so the row can be read at a glance instead of decoded.
-- Gold has none: the client's own coin textures already say what it is, which
-- is the owner's line and the reason this table has a hole in it. The two
-- currencies have none here either: each brings the one the client gives it,
-- see *Two currencies* further down.
--
-- **All six confirmed drawing on build 69977**, checked by the owner on
-- 2026-09-24. They were written from memory and could not be verified from
-- outside the game, which is worth keeping in view rather than deleting: a path
-- this build does not have draws an empty square rather than raising, so the
-- next one added is a guess again until somebody looks.
local ICONS = {
    hearth      = "Interface\\Icons\\INV_Misc_Rune_01",
    coords      = "Interface\\Icons\\INV_Misc_Map_01",
    -- The owner's picks of 2026-11-06, since the book and the watch they wore
    -- while hidden were taken: the client's own experience icon, which its
    -- quest window shows beside a reward's experience, and an arrow pointing
    -- up. The arrow is out of the family of `Misc_ArrowLeft` and
    -- `Misc_ArrowRight`, which the client's gamepad bars use; that one exists
    -- is read in its code, this one wants a look in game.
    xpRate      = "Interface\\Icons\\XP_Icon",
    timeToLevel = "Interface\\Icons\\Misc_ArrowLUp",
    durability  = "Interface\\Icons\\Trade_BlackSmithing",
    latency     = "Interface\\Icons\\Spell_Nature_Lightning",
    framerate   = "Interface\\Icons\\INV_Misc_Gear_01",
    -- Dedicated Study's own book since 2026-10-13, asked of the client by the
    -- spell, see CooldownsFigure; this path is the same icon by Wowhead's data
    -- for WoW Forever, for a client that does not answer. The second pocket
    -- watch it wore first, seen drawing by the owner on 2026-10-10, looked
    -- too much like the time's, his word.
    cooldowns   = "Interface\\Icons\\INV_Misc_Book_08",
    -- Added on 2026-10-13 and seen drawing by the owner the same day. Both are
    -- the client's own in its interface code for build 70338: its clock
    -- window's stopwatch button wears the watch, and its voice chat's channel
    -- button the speaker.
    time        = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    volume      = "Interface\\Common\\VoiceChat-Speaker",
    -- The zone has none, like gold: a place name says what it is, and the
    -- coordinates' map follows right after it.
}

-- One icon per kind of bag, for the figures a kind each gets. **A fixed icon
-- per kind**, the owner's answer of 2026-10-09 over the icon of the bag being
-- worn, so a figure keeps its look whichever bag fills the slot.
--
-- **What the bag holds, in the client's own icon**, the owner's choices of the
-- same day once he had read the first set: an arrow for a quiver, a bullet for
-- an ammo pouch, a soul shard for a soul bag, and for a profession's bag that
-- profession's own icon, Skinning for the leatherworker's. Asked of the client
-- by spell or item id, so it is the icon the game itself shows for them; the
-- path is drawn when the client has no such id. **Checked against Wowhead's
-- Classic data the same day**: every spell and item gives the icon in its
-- path. Herbs take Herbalism's icon by path alone, since the spell behind the
-- profession, Herb Gathering, wears a green hand nobody knows it by. A bag of
-- no family in the reagent bag's slot holds crafting material, so a crate of
-- it, the owner leaving that one to me. Tackle boxes and cooking bags he has
-- not seen in WoW Forever; they are written down so they would look right.
local BAG_ICON = {
    ordinary    = { path = "Interface\\Icons\\INV_Misc_Bag_08" },
    reagent     = { path = "Interface\\Icons\\INV_Crate_02" },
    arrows      = { item = 2512, path = "Interface\\Icons\\INV_Ammo_Arrow_02" },          -- Rough Arrow
    bullets     = { item = 2516, path = "Interface\\Icons\\INV_Ammo_Bullet_02" },         -- Light Shot
    soulShards  = { item = 6265, path = "Interface\\Icons\\INV_Misc_Gem_Amethyst_02" },   -- Soul Shard
    skinning    = { spell = 8613, path = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    inscription = { path = "Interface\\Icons\\INV_Inscription_Tradeskill01" },
    herbalism   = { path = "Interface\\Icons\\Trade_Herbalism" },
    enchanting  = { spell = 7411, path = "Interface\\Icons\\Trade_Engraving" },
    engineering = { spell = 4036, path = "Interface\\Icons\\Trade_Engineering" },
    gems        = { path = "Interface\\Icons\\INV_Misc_Gem_01" },
    mining      = { spell = 2575, path = "Interface\\Icons\\Trade_Mining" },
    fishing     = { spell = 7620, path = "Interface\\Icons\\Trade_Fishing" },
    cooking     = { spell = 2550, path = "Interface\\Icons\\INV_Misc_Food_15" },
    other       = { path = "Interface\\Icons\\INV_Misc_Bag_10" },
}

-- **Picked by what the bag is**, its item class and subclass, numbers in every
-- language: class 1 is a container, 11 a quiver. The family did it first, and
-- the owner's Apprentice's Skinning Satchel, item 277114, a "4 Slot
-- Leatherworking Bag" by its tooltip, came out the same evening with the icon
-- for a family nobody had written down: WoW Forever's own bags do not keep
-- to the families the older ones use.
local TYPE_ICONS = {
    [1]  = { [0] = "ordinary", [1] = "soulShards", [2] = "herbalism",
             [3] = "enchanting", [4] = "engineering", [5] = "gems", [6] = "mining",
             [7] = "skinning", [8] = "inscription", [9] = "fishing",
             [10] = "cooking", [11] = "reagent" },
    [11] = { [2] = "arrows", [3] = "bullets" },
}

-- And by the bag family's bit, for a bag the client will not describe.
local FAMILY_ICONS = {
    ordinary = "ordinary", reagent = "reagent",
    [1] = "arrows", [2] = "bullets", [4] = "soulShards", [8] = "skinning",
    [16] = "inscription", [32] = "herbalism", [64] = "enchanting",
    [128] = "engineering", [512] = "gems", [1024] = "mining",
    [32768] = "fishing", [65536] = "cooking",
}

-- The single figure over every bag wears the ordinary bags' icon, and the
-- ammunition the arrow for the picker; on the bar it wears the arrow or the
-- bullet the weapon fires, see AmmoFigure.
ICONS.bags = BAG_ICON.ordinary.path
ICONS.ammo = BAG_ICON.arrows.path

-- Destroy Cheapest Gray Item wears the minus of the negative charge, the
-- owner's pick of 2026-10-22 out of the client's own icon list, found there
-- by him and seen fitting on the bar the same day. The two before it: the
-- client's junk coin looked tiny on the bar, and its housing icon for
-- removing something read as cancel.
ICONS.junk = "Interface\\Icons\\Spell_ChargeNegative"

--- A texture escape sized to the text beside it, for a path or a file id.
--
-- Sized rather than fixed, because the Design page scales every font in the
-- addon and an icon that stayed 14 units tall would drift out of line with
-- the digits the moment somebody moved that slider.
--- Whether a figure sits in the lower half of the screen. For the game's tooltip
--- on the gray stack alone, whose height is not known before it is filled: the
--- addon's own tooltips and lists measure, see FP:HangSteady.
local function SitsLow(owner)
    local _, cy = owner:GetCenter()
    return cy and cy < UIParent:GetHeight() / 2
end

local function Icon(path, size)
    if not path then return "" end
    return string.format("|T%s:%d:%d:0:0|t ", path, size, size)
end

-- ---------------------------------------------------------------------------
-- Reading numbers from a client that may refuse
-- ---------------------------------------------------------------------------

--- A number from the client, or nil when it cannot be handled.
--
-- Not defensive habit: `UnitHealth` and `UnitPower` came back **secret** on this
-- build even out of combat, and a secret survives the read and raises on the
-- first comparison. So everything that crosses this boundary is treated the same.
local function Number(value)
    if not pcall(function() return value == 0 end) then return nil end
    return (type(value) == "number") and value or nil
end

local function Call(fn, a, b)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, a, b)
    if not ok then return nil end
    return value
end

--- A color escape for text on the bar, in its lists and in its tooltips.
--
-- Every color the bar writes goes through here: the client's green, yellow
-- and red, the item qualities and the class colors. Made readable on the
-- scheme's background first, see FP:Readable, the owner's request of
-- 2026-10-06: the client's dark blue and purple, and its red on the lighter
-- schemes, sank into the ground.
-- The ground the bar's figures are made readable on while they are drawn, the
-- bar's own background when the page gives it one, see M:Update; nil, the
-- scheme's background, for everything else, the hovers among it.
local hexGround

local function Hex(r, g, b)
    r, g, b = FP:Readable(r, g, b, hexGround)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

--- One of the client's own named colors as an escape, GREEN_FONT_COLOR and
--- the like, or the fallback given when this build has no such color.
local function ClientColor(name, r, g, b)
    local color = _G[name]
    if type(color) == "table" then
        local ok, cr, cg, cb = pcall(function() return color:GetRGB() end)
        if ok and Number(cr) and Number(cg) and Number(cb) then
            return Hex(cr, cg, cb)
        end
        if Number(color.r) and Number(color.g) and Number(color.b) then
            return Hex(color.r, color.g, color.b)
        end
    end
    return Hex(r, g, b)
end

-- ---------------------------------------------------------------------------
-- Clicks on the bar
--
-- Asked for on CurseForge, CF6.11 to CF6.14, and settled with the owner on
-- 2026-10-17: a click on the coordinates opens the world map, on the time
-- the stopwatch and with Shift the calendar, on the volume turns all sound
-- off and on again, and on the frame rate asks whether to reload the
-- interface. Each has its own switch under its display, and a display's
-- hover names what its click does while it does it.
--
-- **The map, the stopwatch and the calendar are the client's own buttons,
-- clicked through a secure button**, `type` "click" of
-- SecureActionButtonTemplate: the zone name above the minimap, whose click
-- opens the map, the stopwatch box of the clock's window, and the calendar
-- button at the minimap, all read in the client's interface code for build
-- 70425. Called from here, ToggleWorldMap and ToggleCalendar would open a
-- window the client guards in combat, write Blizzard's state in our name and,
-- for the calendar, load the client's calendar code in our name, which is
-- the taint the rule in AGENTS.md about Blizzard functions that write is
-- about. Through the template the client's own code runs as if the player
-- had clicked its button. See *The secure buttons over two displays* below.
--
-- **The sound and the reload need nothing protected**, so their displays
-- take the click themselves, on the release, and a release that ends a drag
-- is no click.
-- ---------------------------------------------------------------------------

--- The client's buttons a click on a display is handed on to. Asked for
--- whenever a button is placed rather than once, since the clock's window
--- belongs to code the client loads by itself.
local function MapButton()
    local cluster = rawget(_G, "MinimapCluster")
    return type(cluster) == "table" and cluster.ZoneTextButton or nil
end

local function StopwatchButton() return rawget(_G, "TimeManagerStopwatchCheck") end
local function CalendarButton()  return rawget(_G, "GameTimeFrame") end

--- What a click hands on to on a display with a secure button, by the
--- modifier the template reads: "" for a plain click, "shift-" with Shift.
--- A click the player switched off, or whose button this client lacks, is
--- missing.
local function SecureClicks(key)
    local db = M.db
    if not db then return {} end
    if key == "coords" then
        return { [""] = db.coordsMap and MapButton() or nil }
    elseif key == "time" then
        return { [""]       = db.timeStopwatch and StopwatchButton() or nil,
                 ["shift-"] = db.timeCalendar and CalendarButton() or nil }
    end
    return {}
end

--- The lines a display's hover adds for what a click on it does, while it
--- does anything.
local function ClickHints(key)
    local db, lines = M.db, {}
    if not db then return lines end
    if key == "coords" or key == "time" then
        local clicks = SecureClicks(key)
        if clicks[""] then
            lines[#lines + 1] = (key == "coords") and L["Click to open the world map"]
                or L["Click to open the stopwatch"]
        end
        if clicks["shift-"] then
            lines[#lines + 1] = L["Shift click to open the calendar"]
        end
    elseif key == "framerate" and db.framerateReload then
        lines[#lines + 1] = L["Click to reload the interface"]
    elseif (key == "xpRate" or key == "timeToLevel") and db[key .. "Click"] then
        lines[#lines + 1] = L["Click to restart measurement"]
    end
    return lines
end

-- ---------------------------------------------------------------------------
-- The items
-- ---------------------------------------------------------------------------

local function Coords()
    local map = Number(Call(C_Map and C_Map.GetBestMapForUnit, "player"))
    if not map then return nil end
    local pos = Call(C_Map and C_Map.GetPlayerMapPosition, map, "player")
    if not pos then return nil end
    local ok, x, y = pcall(function() return pos:GetXY() end)
    x, y = Number(ok and x), Number(ok and y)
    if not (x and y) then return nil end
    -- "X : Y", asked for on CurseForge on 2026-09-26 and taken on by the
    -- owner: two bare numbers side by side read as one.
    -- The decimals the way the language in use writes them, see FP:Decimal.
    return FP:Decimal(x * 100, 1) .. " : " .. FP:Decimal(y * 100, 1)
end

-- Where latency turns yellow and then red. Asked for on CurseForge on
-- 2026-09-28, and the numbers are the owner's: from 100 ms a game already
-- feels slow, and from 250 ms it is plainly noticeable. Green below, in the
-- client's own green, yellow and red.
local LATENCY_YELLOW, LATENCY_RED = 100, 250

local function Latency()
    if type(GetNetStats) ~= "function" then return nil end
    local ok, _, _, home, world = pcall(GetNetStats)
    local ms = Number(ok and (world or home))
    if not ms then return nil end

    local color
    if ms >= LATENCY_RED then
        color = ClientColor("RED_FONT_COLOR", 1, 0.1, 0.1)
    elseif ms >= LATENCY_YELLOW then
        color = ClientColor("YELLOW_FONT_COLOR", 1, 1, 0)
    else
        color = ClientColor("GREEN_FONT_COLOR", 0.1, 1, 0.1)
    end
    return color .. L["%d ms"]:format(ms) .. "|r"
end

local function Framerate()
    local fps = Number(Call(GetFramerate))
    return fps and L["%d fps"]:format(fps) or nil
end

--- The question before a reload, on a click on the frame rate, see *Clicks
--- on the bar*. Never in combat, the owner's word, and a line in chat says
--- so rather than a click that does nothing.
local function AskReload()
    local fighting = InCombatLockdown and InCombatLockdown()
    if fighting then
        return FP:Print(L["The interface cannot be reloaded during combat."])
    end
    FP:Ask({
        title    = L["Reload UI"],
        question = L["Reload the interface now?"],
        yes      = L["Reload now"],
        no       = L["Cancel"],
        onYes    = function()
            if InCombatLockdown and InCombatLockdown() then
                return FP:Print(L["The interface cannot be reloaded during combat."])
            end
            ReloadUI()
        end,
    })
end

-- ---------------------------------------------------------------------------
-- The time
--
-- Asked for on CurseForge on 2026-10-13 and gated with the owner the same day:
-- the time **as the client's own clock shows it**, and on the page **the
-- clock's own two settings**, local or realm time and 24 or 12 hours, which
-- write the client's console variables rather than a copy of them, his word.
-- So the clock at the minimap and the figure here can never disagree, which is
-- the rule about options that live outside the profile in Core/Options.lua.
--
-- The text is the client's own as well: GameTime_GetTime and its two siblings
-- in Blizzard_FrameXMLUtil, read in its interface code for build 70338. They
-- read the two variables, the date and GetGameTime, format with the client's
-- own strings and write nothing, so calling them is within the rule in
-- AGENTS.md about Blizzard functions that write. On the bar without AM or PM,
-- the way the minimap's clock writes it; in the hover with, the way the
-- clock's own tooltip does.
--
-- **The clock's window keeps a copy of the two settings** from the moment it
-- loads, a local table in Blizzard_TimeManager, so after a change here it can
-- show the old ticks until the next reload; the minimap's clock reads the
-- variables every second and follows at once. The window's own toggles would
-- update its copy, but they write Blizzard's state and build its drop-down
-- menus in our name, which is the taint that rule is about.
-- ---------------------------------------------------------------------------

local function Clock()
    local text = FP:Plain(Call(_G.GameTime_GetTime, false))
    if text then return text end
    -- A build without the helper: the local time in 24 hours.
    return (type(date) == "function") and date("%H:%M") or nil
end

local function ShowClock(cell, label)
    local lines = { label }
    local localTime = FP:Plain(Call(_G.GameTime_GetLocalTime, true))
    local realmTime = FP:Plain(Call(_G.GameTime_GetGameTime, true))
    if localTime then lines[#lines + 1] = { L["Local time"], right = localTime } end
    if realmTime then lines[#lines + 1] = { L["Realm time"], right = realmTime } end
    for _, hint in ipairs(ClickHints("time")) do lines[#lines + 1] = hint end
    FP:ShowTip(cell, lines, "STEADY")
end

--- One of the clock's two settings, "1" or "0", for the page's two lists.
function M:ClockSetting(name)
    local value = FP:Plain(Call((C_CVar and C_CVar.GetCVar) or _G.GetCVar, name))
    return (value == "1") and "1" or "0"
end

--- The two settings start at local time and 24 hours, the owner's word of
--- 2026-10-13, set once on the account the first time the time is on.
--
-- They are the client's own, so they have no default of ours to fall back on:
-- the client starts both at 0, realm time in 12 hours. Set once rather than
-- every time, so that whatever the player picks afterwards stands, here or in
-- the clock's window; and only once the time is switched on, since writing
-- the game clock's settings for somebody who never asked for the figure would
-- be one setting silently moving another.
function M:ApplyClockDefaults()
    if not self.db.time or type(FP.global) ~= "table" then return end
    if FP.global.clockDefaults then return end
    local set = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if type(set) ~= "function" then return end
    pcall(set, "timeMgrUseLocalTime", "1")
    pcall(set, "timeMgrUseMilitaryTime", "1")
    FP.global.clockDefaults = true
end

--- Writes one of them, and shows the figure in its new form at once.
function M:SetClockSetting(name, value)
    local set = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if type(set) ~= "function" then return end
    pcall(set, name, (value == "1") and "1" or "0")
    FP:Safe("InfoBar:Update", M.Update, M)
end

-- ---------------------------------------------------------------------------
-- The zone
--
-- Asked for on CurseForge on 2026-10-13 and gated with the owner the same day:
-- **the zone and the area within it on one line**, "Durotar: Razor Hill", the
-- zone alone where there is no area, **in the minimap's colors** for the kind
-- of territory, made readable like every color here. The minimap itself shows
-- one name, the area or else the zone. Both names are the client's display
-- text, compared only with each other, as the minimap compares them.
-- ---------------------------------------------------------------------------

-- Out of Minimap_Update in the client's interface code for build 70338. None
-- for a zone of no kind, which the minimap writes in its normal gold and the
-- bar in its own color.
local ZONE_COLORS = {
    sanctuary = { 0.41, 0.8, 0.94 },
    arena     = { 1.0, 0.1, 0.1 },
    friendly  = { 0.1, 1.0, 0.1 },
    hostile   = { 1.0, 0.1, 0.1 },
    contested = { 1.0, 0.7, 0.0 },
}

-- The line the minimap's hover adds under the names, in the client's words.
-- Friendly and hostile name the faction, see ShowZone.
local TERRITORY = {
    sanctuary = "SANCTUARY_TERRITORY",
    arena     = "FREE_FOR_ALL_TERRITORY",
    contested = "CONTESTED_TERRITORY",
    combat    = "COMBAT_ZONE",
}

--- The kind of territory, a token like "contested", and the faction it
--- belongs to, or nil for either.
local function Territory()
    local get = (C_PvP and C_PvP.GetZonePVPInfo) or _G.GetZonePVPInfo
    if type(get) ~= "function" then return nil end
    local ok, kind, _, faction = pcall(get)
    if not ok then return nil end
    return FP:Plain(kind), FP:Plain(faction)
end

local function Zone()
    local zone = FP:Plain(Call(_G.GetZoneText))
    if not zone then return nil end
    local area = FP:Plain(Call(_G.GetSubZoneText))
    local text = zone
    if area and area ~= zone then text = L["%s: %s"]:format(zone, area) end
    local color = ZONE_COLORS[Territory() or ""]
    if color then text = Hex(color[1], color[2], color[3]) .. text .. "|r" end
    return text
end

--- The label, and under it what kind of territory this is, as the minimap's
--- hover says it.
local function ShowZone(cell, label)
    local lines = { label }
    local kind, faction = Territory()
    local text
    if (kind == "friendly" or kind == "hostile") and faction then
        local pattern = FP:Plain(_G.FACTION_CONTROLLED_TERRITORY)
        if pattern then text = pattern:format(faction) end
    elseif kind and TERRITORY[kind] then
        text = FP:Plain(_G[TERRITORY[kind]])
    end
    -- A combat zone's line in red, as the minimap's hover has it, although
    -- the minimap leaves the name itself in its normal color.
    if text then
        lines[2] = { text, color = ZONE_COLORS[kind]
            or (kind == "combat" and ZONE_COLORS.hostile) or nil }
    end
    FP:ShowTip(cell, lines, "STEADY")
end

-- ---------------------------------------------------------------------------
-- The Hearthstone
--
-- Asked for on CurseForge on 2026-09-28 and gated with the owner on
-- 2026-09-29: the destination and the time until it is ready, the destination
-- in green once it is, first on the bar, and **a click uses it**, see
-- *The Hearthstone button* further down. With no Hearthstone in the bags the
-- figure says so in red instead, his addition the same day.
--
-- By item id, never by name, as the locale rule wants. 6948 is the Hearthstone
-- in every Classic client, and confirmed on this one by the owner's screenshot
-- on 2026-09-29.
-- ---------------------------------------------------------------------------

local HEARTHSTONE = 6948

-- The longest cooldown taken to be the global one rather than the stone's.
local GLOBAL_COOLDOWN = 2

local function HearthCount()
    local count = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
    return Number(Call(count, HEARTHSTONE)) or 0
end

--- Seconds until the Hearthstone is ready, 0 when it is, nil when unknown.
local function HearthWait()
    local cooldown = (C_Container and C_Container.GetItemCooldown) or _G.GetItemCooldown
    if type(cooldown) ~= "function" then return nil end
    local ok, start, duration = pcall(cooldown, HEARTHSTONE)
    start, duration = Number(ok and start), Number(ok and duration)
    if not (start and duration) then return nil end
    -- The global cooldown counts too: every ability and every wand shot puts
    -- the Hearthstone on a cooldown of about a second and a half, which made the
    -- figure flicker to "0:00" all through a fight, reported by the owner on
    -- 2026-09-29. The stone's own cooldown is minutes long, so anything this
    -- short is the global one and the stone is ready.
    if start <= 0 or duration <= GLOBAL_COOLDOWN then return 0 end
    local now = Number(Call(GetTime))
    if not now then return nil end
    return math.max(0, start + duration - now)
end

local function Hearth()
    if HearthCount() <= 0 then
        return ClientColor("RED_FONT_COLOR", 1, 0.1, 0.1) .. L["No Hearthstone"] .. "|r"
    end
    local place = FP:Plain(Call(GetBindLocation)) or "?"
    local wait = HearthWait()
    if wait == 0 then
        return ClientColor("GREEN_FONT_COLOR", 0.1, 1, 0.1) .. place .. "|r"
    end
    if not wait then return place end
    return string.format("%s %d:%02d", place, math.floor(wait / 60),
        math.floor(wait % 60))
end

--- Every worn piece that can wear down, with its condition as a share.
local function Condition()
    return (FP:ReadWornPieces())
end

local function Percent(share)
    return string.format("%d%%", math.floor(share * 100 + 0.5))
end

-- The color Blizzard's armour figure gives a piece, asked of the client rather
-- than worked out here. Asked for by the owner on 2026-09-26: the damaged list
-- colors its pieces the way the game does.
--
-- GetInventoryAlertStatus answers 0, 1 or 2, for normal, damaged and broken,
-- and it counts the pieces of that figure rather than equipment slots. This
-- table is INVENTORY_ALERT_STATUS_SLOTS from Blizzard_DurabilityFrame, in its
-- order. The thresholds stay the client's: its documentation puts "damaged" at
-- five points or fewer rather than at a share, which is exactly the kind of
-- number that is better not written down here.
local ALERT_INDEX = { [1] = 1, [3] = 2, [5] = 3, [6] = 4, [7] = 5, [8] = 6,
                      [9] = 7, [10] = 8, [16] = 9, [17] = 10, [18] = 11 }

-- The client's own colors from the same file, for when INVENTORY_ALERT_COLORS
-- has not been published by the time this is asked.
local ALERT_COLORS = {
    { r = 1,    g = 0.82, b = 0.18 },
    { r = 0.93, g = 0.07, b = 0.07 },
}

local function AlertColor(slot)
    local index = ALERT_INDEX[slot]
    if not index or type(GetInventoryAlertStatus) ~= "function" then return nil end
    local ok, status = pcall(GetInventoryAlertStatus, index)
    status = Number(ok and status)
    if not status or status < 1 then return nil end
    local published = _G.INVENTORY_ALERT_COLORS
    return (type(published) == "table" and published[status]) or ALERT_COLORS[status]
end

--- The worst color the game's armour figure shows on any piece, or nil while
--- it shows none.
local function WorstAlertColor()
    if type(GetInventoryAlertStatus) ~= "function" then return nil end
    local worst, color = 0, nil
    for slot, index in pairs(ALERT_INDEX) do
        local ok, status = pcall(GetInventoryAlertStatus, index)
        status = Number(ok and status)
        if status and status > worst then
            worst, color = status, AlertColor(slot)
        end
    end
    return color
end

--- The worst condition anything worn is in, as a percentage.
--
-- The lowest rather than the average, because the average stays comfortable
-- while one piece is about to break, and the piece about to break is the whole
-- reason to look.
--
-- **In the game's own colors since 2026-09-28**, asked for on CurseForge and
-- decided by the owner: yellow once the game marks a piece damaged, red once
-- one is broken, the colors the list behind the figure already uses. The game
-- marks late, a few points before a piece breaks, which is its threshold and
-- not one this file writes down.
--
-- **White while it marks nothing**, the owner's call the same evening after
-- seeing all three: the bar's own gold could not be told from the damaged
-- yellow, so the figure has to leave the theme's color to say "fine".
local function Durability()
    local worst
    for _, piece in ipairs(Condition()) do
        if not worst or piece.share < worst then worst = piece.share end
    end
    if not worst then return nil end
    local color = WorstAlertColor()
    local text = Percent(worst)
    if color then return Hex(color.r, color.g, color.b) .. text .. "|r" end
    return ClientColor("HIGHLIGHT_FONT_COLOR", 1, 1, 1) .. text .. "|r"
end

--- Gold, added up across every character this account has been seen on.
--
-- Kept in `FP.global` rather than in the profile, because it is a fact about
-- the account rather than a setting, and a profile travels between characters
-- through export.
--
-- Built on 2026-09-23 while this client handed nothing back, by the owner's
-- decision and on the reasoning that the code was right and would start
-- working the day saved variables did. **That day was 2026-09-26**, build
-- 70009, and the first thing it showed was one character counted twice: the
-- table was keyed by name, and the name had changed between builds. Keyed by
-- `FP:CharacterKey` since, like every other record about a character.
--
-- One entry per character, `{ copper, name, realm, class }`. The name is kept
-- for reading rather than for finding: the overview on hover has to say whose
-- gold it is, and the key cannot.

--- This character as the overview names it.
--
-- Both parts of the name, the way the client writes it over the character's
-- head. On this build UnitName answers with the first name and the surname as
-- two values, where a stock client answers with name and realm.
local function Identity()
    local ok, first, second = pcall(UnitName, "player")
    first  = ok and FP:Plain(first)
    second = ok and FP:Plain(second)
    if not first then return nil end

    local okClass, _, token = pcall(UnitClass, "player")
    return {
        name    = second and (first .. " " .. second) or first,
        realm   = FP:Plain(Call(GetRealmName)),
        -- The ruleset's number, see FP:GoldCounts.
        mode    = FP:Ruleset(),
        class   = okClass and FP:Plain(token) or nil,
        -- A token, "Alliance" or "Horde", in every language, which is what
        -- makes it fit to compare. See FP:GoldCounts.
        faction = FP:Plain(Call(UnitFactionGroup, "player")),
    }
end

--- The saved gold records, or nil while there is no saved file to hold them.
local function GoldStore()
    if type(FP.global) ~= "table" then return nil end
    if type(FP.global.gold) ~= "table" then FP.global.gold = {} end
    return FP.global.gold
end

--- The faction a gold record carries, or the one the mail list learned.
--
-- Gold records carry it only since 2026-10-09. MailAlts has written one for
-- every character logging in since 0.8.2, so a record from before is mostly
-- answered there.
local function FactionOf(key, entry)
    if entry.faction then return entry.faction end
    local known = type(FP.global) == "table" and type(FP.global.characters) == "table"
        and FP.global.characters[key]
    return type(known) == "table" and FP:Plain(known.faction) or nil
end

--- The ruleset a gold record carries, or the one the mail list learned.
--
-- Both are written since 2026-10-13, at a character's next login.
local function RulesetOf(key, entry)
    if entry.mode then return entry.mode end
    local known = type(FP.global) == "table" and type(FP.global.characters) == "table"
        and FP.global.characters[key]
    return type(known) == "table" and FP:PlainNumber(known.mode) or nil
end

--- The character being played, as FP:GoldCounts compares it.
local function Me()
    return { key = FP:CharacterKey(), realm = FP:Plain(Call(GetRealmName)),
             faction = FP:Plain(Call(UnitFactionGroup, "player")),
             mode = FP:Ruleset() }
end

--- Every record that holds a readable amount and counts under the choice on
--- the page, and their sum.
local function GoldRecords()
    local scope, me = M.db.goldScope or "all", Me()
    local list, total = {}, 0
    for key, entry in pairs(GoldStore() or {}) do
        local amount = type(entry) == "table" and Number(entry.copper)
        local record = amount and { key = key, copper = amount, name = entry.name,
            realm = entry.realm, class = entry.class, faction = FactionOf(key, entry),
            mode = RulesetOf(key, entry) }
        -- Every record, marked whether it counts: the figure adds up those,
        -- and the list names them all.
        if record then
            record.counted = FP:GoldCounts(record, scope, me) and true or false
            list[#list + 1] = record
            if record.counted then total = total + amount end
        end
    end
    return list, total
end

-- Whether this session has written the name yet. Once per session rather than
-- once ever, because the name is exactly the thing this client has changed
-- under us before, and a stale one would label the right gold wrongly.
local identified = false

local function Gold()
    local copper = Number(Call(GetMoney))
    if not copper then return nil end

    -- Without a key there is no telling which entry is this character, so the
    -- honest figure is this character's alone rather than a sum that may hold
    -- it twice.
    local key   = FP:CharacterKey()
    local store = key and GoldStore()
    if not store then return FP:Money(copper) end

    local entry = store[key]
    if type(entry) ~= "table" then
        entry = {}
        store[key] = entry
    end
    entry.copper = copper
    -- Asked again while the faction is missing: a brand new character's can
    -- arrive a moment after the first second of play.
    if not identified or not entry.name or not entry.faction then
        local me = Identity()
        if me then
            entry.name, entry.realm, entry.class = me.name, me.realm, me.class
            entry.faction = me.faction or entry.faction
            entry.mode = me.mode or entry.mode
            identified = true
        end
    end

    -- The sum alone, of the characters the page chose. It carried the number
    -- of characters in brackets until the overview arrived; the owner took it
    -- off the same day, since the overview names every one of them.
    local _, total = GoldRecords()
    return FP:Money(total)
end

-- ---------------------------------------------------------------------------
-- Gold this session
--
-- Asked for on CurseForge on 2026-09-28 and taken on by the owner: the gold list
-- says what was won or lost since the character logged in. **A session is a
-- login**, his call: a /reload goes on counting, and only logging in again
-- starts from nought. PLAYER_ENTERING_WORLD says which of the two the interface
-- has just been through, and the amount at the start lives in the character's
-- gold record, where a /reload finds it again.
-- ---------------------------------------------------------------------------

local function StartSession(initial)
    local key   = FP:CharacterKey()
    local store = key and GoldStore()
    local copper = Number(Call(GetMoney))
    if not (store and copper) then return end

    local entry = store[key]
    if type(entry) ~= "table" then
        entry = {}
        store[key] = entry
    end
    -- A record from before this existed has no start yet, whichever way the
    -- interface came up; counting begins now for that one.
    if initial or not Number(entry.sessionStart) then
        entry.sessionStart = copper
    end
end

-- Built when the file loads rather than when the bar is switched on, so the
-- start is right even for a bar switched on halfway through a session. Only the
-- first PLAYER_ENTERING_WORLD after the interface came up tells login from
-- reload; the later ones are loading screens.
local sessionWatch = CreateFrame("Frame")
sessionWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
sessionWatch:SetScript("OnEvent", function(self, _, isInitialLogin)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    FP:Safe("InfoBar:StartSession", StartSession, FP:Truth(isInitialLogin) == true)
end)

--- What this character has won or lost since logging in, in copper, or nil.
local function SessionChange()
    local key   = FP:CharacterKey()
    local store = key and GoldStore()
    local entry = store and store[key]
    local start = type(entry) == "table" and Number(entry.sessionStart)
    local copper = Number(Call(GetMoney))
    if not (start and copper) then return nil end
    return copper - start
end

--- What repairing everything worn would cost, in copper, or nil when the
--- client will not say.
--
-- Asked for on CurseForge on 2026-09-28 and taken on by the owner. Read from
-- the data the client builds for a worn item's tooltip, which carries the cost
-- in the modern API without a tooltip being shown or a merchant being near.
-- **Measured the same evening**: the owner's damaged leathers came to 29
-- copper, away from any merchant. A field a later build stops filling simply
-- leaves the line out.
local function RepairCost()
    local get = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    if type(get) ~= "function" then return nil end
    local total, seen = 0, false
    for slot = 1, 18 do
        local ok, data = pcall(get, "player", slot)
        local cost = ok and type(data) == "table" and Number(data.repairCost)
        if cost then
            seen, total = true, total + cost
        end
    end
    return seen and total or nil
end

-- ---------------------------------------------------------------------------
-- Two currencies: Merchant's Favor and Honor Points
--
-- Asked for by the owner on 2026-10-05 and gated in the dialog the same day:
-- **what the character being played holds**, since honor cannot move between
-- characters, and **red once nothing more can come in**, with the limit under
-- the name on hover. Both figures are off until switched on.
--
-- By currency id, never by name, as the locale rule wants. Both ids are out of
-- the Wowhead Forever database: 3402 is WoW Forever's own currency for the
-- Waylaid Crates, and 1792 is also the client's own HONOR_CURRENCY_ID in
-- Constants.CurrencyConsts. Name and icon are the client's, so hovering a
-- figure names whatever its id resolves to on this build, which is how a wrong
-- id would show.
--
-- C_CurrencyInfo.GetCurrencyInfo answers with one table, and this build's API
-- documentation marks none of it secret, where it does mark UnitHealth. Every
-- value still goes through Number before anything is done with it.
-- ---------------------------------------------------------------------------

local MERCHANTS_FAVOR = 3402
local HONOR_POINTS    = 1792

-- Refreshes in a row that a currency which is switched on may stay unknown
-- before it is named in chat, once. Some seconds rather than at once, so a
-- client still loading its data at login is not taken for one without it.
local UNKNOWN_AFTER = 10

local unknownCurrency = {}

--- What the client knows about a currency: its table, false when it answered
--- and knows no such currency, nil when it would not answer.
--
-- Two answers kept apart on purpose: a refusal says nothing about the id, and
-- reading one as the other is the pitfall in AGENTS.md about a refused read
-- and an absent value.
local function CurrencyInfo(id)
    local get = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
    if type(get) ~= "function" then return nil end
    local ok, info = pcall(get, id)
    if not ok then return nil end
    return type(info) == "table" and info or false
end

--- A whole number as the client writes one: "25,000" here, "25.000" on a
--- German client.
local function Count(number)
    return FP:Plain(Call(BreakUpLargeNumbers, number)) or tostring(number)
end

--- Whether nothing more of a currency can come in.
--
-- The client's own rule, from CurrencyContainer.lua in its interface code for
-- this build: a currency whose limit counts everything ever earned compares
-- that, any other compares what is held now. A currency without a limit is
-- never red.
local function AtLimit(info)
    local limit = Number(info.maxQuantity)
    if not limit or limit <= 0 then return false end
    local held = FP:Truth(info.useTotalEarnedForMaxQty) and Number(info.totalEarned)
        or Number(info.quantity)
    return held ~= nil and held >= limit
end

--- The figure for a currency, and the icon the client gives it.
local function Currency(id, label)
    local info = CurrencyInfo(id)
    if info == false then
        unknownCurrency[id] = (unknownCurrency[id] or 0) + 1
        if unknownCurrency[id] == UNKNOWN_AFTER then
            FP:Warn(L["Info bar: this client build does not recognize "
                .. "currency %d, so %s stays empty."], id, label)
        end
        return nil
    end
    if not info then return nil end
    unknownCurrency[id] = nil

    local held = Number(info.quantity)
    if not held then return nil end
    local text = Count(held)
    if AtLimit(info) then
        text = ClientColor("RED_FONT_COLOR", 1, 0.1, 0.1) .. text .. "|r"
    end
    return text, Number(info.iconFileID)
end

--- What hovering a currency says: its name, and its limit when it has one.
local function ShowCurrency(cell, id, label)
    local info = CurrencyInfo(id)
    local lines = { info and FP:Plain(info.name) or label }
    local limit = info and Number(info.maxQuantity)
    if limit and limit > 0 then
        lines[2] = { L["Maximum"], right = Count(limit) }
    end
    FP:ShowTip(cell, lines, "STEADY")
end

--- The entry in ITEMS for one currency.
local function CurrencyItem(key, id, label)
    return {
        key   = key,
        label = label,
        get   = function() return Currency(id, label) end,
        hover = function(cell) return ShowCurrency(cell, id, label) end,
    }
end

-- ---------------------------------------------------------------------------
-- Free bag slots
--
-- Promised on CurseForge on 2026-09-26 and again on 2026-10-08, and gated with
-- the owner on 2026-10-09. The count left the bar on 2026-09-23 for the
-- backpack, which stays its home; this puts it on the bar as well, for whoever
-- reads the bar rather than the bags, with a switch apart from the backpack's.
--
-- **Two layouts, the player's choice**, the owner's word: one figure for every
-- bag, special bags included, whose hover lists each kind of bag, or a figure
-- for each kind, whose hover names the kind. **No color**, his answer as well:
-- a full quiver or soul bag is what its owner wants, so red would mislead.
-- ---------------------------------------------------------------------------

-- The most kinds a character can carry at once: the backpack's, one for each
-- of four bags and the reagent bag's. One cell is built for each.
local MAX_KINDS = 6

-- The kinds read once per refresh rather than once per figure, which with a
-- figure per kind would be seven cells asking the same thing every second.
-- Emptied at the start of every Update.
local refreshKinds

local function CurrentKinds()
    if not refreshKinds then refreshKinds = FP:BagKinds(FP:ReadBags()) end
    return refreshKinds
end

local function Slots(free, total)
    return string.format("%d/%d", free, total)
end

--- A figure on the bar: the free slots with the total, or alone while the
--- page asks for that, CF6.4. Every hover shows both, through Slots.
local function BarSlots(free, total)
    if M.db.bagsFormat == "free" then return string.format("%d", free) end
    return Slots(free, total)
end

-- [entry of BAG_ICON] = the icon the client gave for it. Kept, since a
-- spell's or an item's icon does not change; an entry the client had no
-- answer for is asked again next time.
local resolvedIcons = {}

--- An entry of BAG_ICON as an icon: the client's own for the spell or item
--- written down, else the path beside them.
local function IconOf(spec)
    if resolvedIcons[spec] then return resolvedIcons[spec] end
    local icon = spec.spell and Number(FP:SpellIcon(spec.spell))
    if not icon and spec.item then
        local get = (C_Item and C_Item.GetItemIconByID) or rawget(_G, "GetItemIconByID")
        icon = Number(Call(get, spec.item))
    end
    if icon then resolvedIcons[spec] = icon end
    return icon or spec.path
end

--- What the client says the bag worn in a place is: the name of its subtype,
--- "Quiver" or "Soul Bag", its item class and its subclass.
--
-- The name is display text in the client's language and compared with
-- nothing, so the locale rule is kept; class and subclass are numbers. All of
-- it comes without a server query.
local function BagItem(bag)
    local toSlot = (C_Container and C_Container.ContainerIDToInventoryID)
        or rawget(_G, "ContainerIDToInventoryID")
    local slot = Number(Call(toSlot, bag))
    local id = slot and Number(Call(GetInventoryItemID, "player", slot))
    local instant = (C_Item and C_Item.GetItemInfoInstant)
        or rawget(_G, "GetItemInfoInstant")
    if not (id and type(instant) == "function") then return nil end
    local ok, _, _, subType, _, _, classID, subClassID = pcall(instant, id)
    if not ok then return nil end
    return FP:Plain(subType), Number(classID), Number(subClassID)
end

--- The icon for a kind of bag: by what its first bag is, else by its family.
local function KindIcon(kind)
    local name
    if kind.kind ~= "ordinary" then
        local _, classID, subClassID = BagItem(kind.bags[1])
        name = classID and TYPE_ICONS[classID] and TYPE_ICONS[classID][subClassID]
    end
    return IconOf(BAG_ICON[name or FAMILY_ICONS[kind.kind] or "other"])
end

--- What a kind of bag is called on the bar and in its lists.
local function KindName(kind)
    if kind.kind == "ordinary" then return L["Ordinary bags"] end
    return (BagItem(kind.bags[1])) or L["Special bag"]
end

--- The one figure over every bag, unless the page asks for one per kind.
local function BagsFigure()
    if M.db.bagsLayout == "kinds" then return nil end
    local kinds = CurrentKinds()
    if #kinds == 0 then return nil end
    local free, total = 0, 0
    for _, kind in ipairs(kinds) do
        free, total = free + kind.free, total + kind.total
    end
    return BarSlots(free, total)
end

--- What hovering the one figure says: every kind of bag and its slots.
local function ShowBagKinds(cell, label)
    local lines = { label }
    for _, kind in ipairs(FP:BagKinds(FP:ReadBags())) do
        lines[#lines + 1] = { KindName(kind), right = Slots(kind.free, kind.total) }
    end
    FP:ShowTip(cell, lines, "STEADY")
end

--- The figure for the kind in a given place, with its icon, while the page
--- asks for one per kind.
local function KindFigure(index)
    if M.db.bagsLayout ~= "kinds" then return nil end
    local kind = CurrentKinds()[index]
    if not kind then return nil end
    return BarSlots(kind.free, kind.total), KindIcon(kind)
end

--- What hovering a kind's figure says: which kind it is, and its total too
--- while the bar shows the free slots alone, so the hover keeps both.
local function ShowKindName(cell, index, label)
    local kind = FP:BagKinds(FP:ReadBags())[index]
    local line = kind and KindName(kind) or label
    if kind and M.db.bagsFormat == "free" then
        line = { line, right = Slots(kind.free, kind.total) }
    end
    FP:ShowTip(cell, { line }, "STEADY")
end

--- The entry in ITEMS for the kind in a given place. All of them answer to the
--- one switch on the page, which `option` names.
local function BagKindItem(index)
    return {
        key    = "bagKind" .. index,
        option = "bags",
        label  = L["Free Bag Slots"],
        get    = function() return KindFigure(index) end,
        hover  = function(cell, label) return ShowKindName(cell, index, label) end,
    }
end

-- ---------------------------------------------------------------------------
-- The ammunition
--
-- A1 of the 1.0.2 brief. Counted by Ammunition Warning, whose count the
-- quiver shows, see *The count on the info bar* in Modules/Ammunition.lua,
-- and red by its switch and threshold, which the page's two rows under the
-- display set there. Nothing while no bow, gun or crossbow is in hand, and
-- nothing either while the bags cannot be read, so a zero is always one the
-- bags said. In the arrow or the bullet of the bag kinds, by what the weapon
-- fires; without status colors the bar's text color, like everything else.
-- ---------------------------------------------------------------------------

local function AmmoModule()
    local ammo = FP:GetModule("Ammunition")
    return (type(ammo) == "table" and ammo.BarCount) and ammo or nil
end

--- One of Ammunition Warning's settings, for the page's shared rows.
function M:AmmoSetting(key)
    local ammo = AmmoModule()
    return ammo and type(ammo.db) == "table" and ammo.db[key] or nil
end

--- Sets one of them, and lets both displays look again: the bar here, and
--- the quiver's count while that module runs.
function M:SetAmmoSetting(key, value)
    local ammo = AmmoModule()
    if not (ammo and type(ammo.db) == "table") then return end
    ammo.db[key] = value
    if ammo.enabled and ammo.Reapply then FP:Safe("Ammunition:Reapply", ammo.Reapply, ammo) end
    FP:NotifyOptionChanged(ammo)
    FP:Safe("InfoBar:Update", M.Update, M)
end

local function AmmoMode()
    return (M.db and M.db.ammoCount == "slot") and "slot" or "all"
end

local function AmmoFigure()
    local ammo = AmmoModule()
    if not ammo then return nil end
    local count, fires = ammo:BarCount(AmmoMode())
    if not (fires and count) then return nil end
    local text = tostring(count)
    if ammo:IsLow(count) then text = Hex(1, 0.25, 0.25) .. text .. "|r" end
    return text, IconOf(fires == ammo.BULLET and BAG_ICON.bullets or BAG_ICON.arrows)
end

--- What hovering it says: which ammunition the figure counts.
local function ShowAmmo(cell, label)
    local lines = { label }
    local ammo = AmmoModule()
    local count, fires, slot = nil, nil, nil
    if ammo then count, fires, slot = ammo:BarCount(AmmoMode()) end
    if fires and AmmoMode() == "slot" then
        if slot then
            local name = FP:Plain(Call((C_Item and C_Item.GetItemNameByID)
                or rawget(_G, "GetItemInfo"), slot))
            lines[#lines + 1] = L["Counts %s, the ammunition in your ammo slot"]
                :format(name or "?")
        else
            lines[#lines + 1] = L["Your ammo slot is empty"]
        end
    elseif fires then
        lines[#lines + 1] = (fires == ammo.BULLET) and L["Counts every bullet in your bags"]
            or L["Counts every arrow in your bags"]
    end
    if count and M:AmmoSetting("warn") ~= false then
        lines[#lines + 1] = L["Red below %d"]:format(tonumber(M:AmmoSetting("threshold")) or 500)
    end
    FP:ShowTip(cell, lines, "STEADY")
end

-- ---------------------------------------------------------------------------
-- The cheapest gray item
--
-- D1 of the 1.0.2 brief, the owner's answers of 2026-10-21: an icon of its
-- own, off by default; the whole gray stack of the lowest total vendor value,
-- FP:CheapestGray, shown in the game's item tooltip on hover with how many
-- and what a merchant would pay; destroyed by a Shift click, or by a plain
-- click as well once "Destroy with a click, without Shift" is on, off by
-- default, his word of 2026-10-22; after a question unless "Skip the
-- confirmation" is on, and that question's "Do not ask again" switches it on
-- with Destroy alone. Dimmed and doing nothing while no stack qualifies.
-- **Never in combat**, and nothing waits for the fight's end.
--
-- **Destroyed the way the client's own hand does it**: the stack picked up
-- and DeleteCursorItem, from the player's click on the display or on
-- Destroy, so from a hardware event. Both calls carry HasRestrictions in the
-- client's API documentation for build 70450, which its own CreateFrame does
-- as well, and its own question before destroying an item calls them;
-- **an addon may, confirmed in game by the owner on 2026-10-22**, and a
-- refusal would be reported rather than worked around. Before
-- the pick up the stack is read again in its slot, with its guid where the
-- client gives one, and nothing happens while the cursor holds anything;
-- after it, the cursor must hold that very item, or it is put back. One
-- click destroys one stack at most.
-- ---------------------------------------------------------------------------

local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

--- The bags to look in: the ordinary ones and the reagent bag's slot, where
--- any bag can sit on WoW Forever.
local function JunkBags()
    local bags = {}
    for bag = 0, (rawget(_G, "NUM_BAG_SLOTS") or 4) do bags[#bags + 1] = bag end
    local index = Enum and Enum.BagIndex
    if type(index) == "table" and type(index.ReagentBag) == "number" then
        bags[#bags + 1] = index.ReagentBag
    end
    return bags
end

--- What a slot holds, for the gray stacks and for the look before deleting:
--- item, count, quality, whether it is locked, and its guid where the
--- client gives one. nil for an empty slot or one the client will not read.
local function ReadSlot(bag, slot, withGuid)
    local container = C_Container
    local ok, info = pcall(container.GetContainerItemInfo, bag, slot)
    if not (ok and type(info) == "table") then return nil end
    local out = {
        itemID  = FP:PlainNumber(info.itemID),
        count   = FP:PlainNumber(info.stackCount) or 1,
        quality = FP:PlainNumber(info.quality),
        locked  = info.isLocked == true,
        noValue = info.hasNoValue == true,
        link    = FP:Plain(info.hyperlink),
    }
    if withGuid and C_Item and C_Item.GetItemGUID and rawget(_G, "ItemLocation") then
        local okGuid, guid = pcall(function()
            return C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
        end)
        out.guid = okGuid and FP:Plain(guid) or nil
    end
    return out
end

--- Every gray stack in the bags as FP:CheapestGray takes them, or nil while
--- the client gives no bags.
local function GrayStacks()
    local container = C_Container
    if not (container and container.GetContainerNumSlots
            and container.GetContainerItemInfo) then
        return nil
    end
    local getInfo = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
    local instant = (C_Item and C_Item.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
    local questInfo = container.GetContainerItemQuestInfo

    local out = {}
    for _, bag in ipairs(JunkBags()) do
        local slots = FP:PlainNumber(Call(container.GetContainerNumSlots, bag)) or 0
        for slot = 1, slots do
            local s = ReadSlot(bag, slot)
            if s and s.quality == 0 and s.itemID then
                -- No value says the client; else the price of one, nil while
                -- it is not known, which keeps the stack out.
                local price
                if s.noValue then
                    price = 0
                elseif getInfo then
                    local okPrice, value = pcall(function()
                        return select(11, getInfo(s.itemID))
                    end)
                    price = okPrice and FP:PlainNumber(value) or nil
                end
                local quest = false
                if questInfo then
                    local okQuest, q = pcall(questInfo, bag, slot)
                    quest = okQuest and type(q) == "table"
                        and (q.isQuestItem == true or FP:PlainNumber(q.questID) ~= nil) or false
                end
                if not quest and instant then
                    local okClass, _, _, _, _, _, classID = pcall(instant, s.itemID)
                    quest = okClass and FP:PlainNumber(classID) == QUEST_CLASS
                end
                out[#out + 1] = { bag = bag, slot = slot, itemID = s.itemID,
                                  count = s.count, quality = 0, price = price,
                                  quest = quest, locked = s.locked, link = s.link }
            end
        end
    end
    return out
end

local function FindJunk()
    return FP:CheapestGray(GrayStacks())
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

--- Whether the cursor holds anything at all: an item, a spell, money.
local function CursorBusy()
    if CursorHasItem and CursorHasItem() then return true end
    local ok, kind = pcall(rawget(_G, "GetCursorInfo") or function() end)
    return ok and kind ~= nil
end


-- **What the tooltip over the display shows, and what a click acts on**: the
-- stack, false while it says there is none, nil while no tooltip of it is
-- up. The owner's report of 2026-10-22: after a stack was destroyed the
-- tooltip went on showing it, which invites a second click that would have
-- destroyed another stack nobody had looked at. So the tooltip follows the
-- bags while it is up, at once after a stack is destroyed and within a
-- second of any other change, see M:Update; and a click destroys exactly
-- the stack it shows, never a fresh pick.
local junkTip
local junkLabel   -- the display's name, for showing the tooltip again

local ShowJunk    -- below; DestroyJunk shows the tooltip again through it

--- Whether two of FP:CheapestGray's stacks are the same one in the same
--- state; false and nil, no stack, are the same as each other.
local function SameStack(a, b)
    if not (a and b) then return not a == not b end
    return a.bag == b.bag and a.slot == b.slot and a.itemID == b.itemID
        and a.count == b.count
end

--- The tooltip shown again while the pointer is still on the display.
local function RefreshJunkTip(cell)
    if not (cell and cell:IsVisible() and cell:IsMouseOver()) then return end
    FP:Safe("InfoBar:hover", ShowJunk, cell, junkLabel)
end

--- Destroys exactly this stack, after looking at it once more.
local function DestroyJunk(stack, cell)
    if InCombat() then return FP:Warn(L["Nothing is destroyed in combat."]) end
    if CursorBusy() then
        return FP:Warn(L["Nothing was destroyed: something is on your cursor."])
    end
    local now = ReadSlot(stack.bag, stack.slot, true)
    if not (now and now.itemID == stack.itemID and now.count == stack.count
            and now.quality == 0 and not now.locked
            and (not stack.guid or now.guid == stack.guid)) then
        return FP:Warn(L["Nothing was destroyed: your bags changed."])
    end
    local pickup = C_Container and C_Container.PickupContainerItem
    local delete = rawget(_G, "DeleteCursorItem")
    if type(pickup) ~= "function" or type(delete) ~= "function" then
        return FP:Warn(L["Nothing was destroyed: this client cannot destroy items "
            .. "for an addon."])
    end

    pcall(pickup, stack.bag, stack.slot)
    local okCursor, kind, id = pcall(rawget(_G, "GetCursorInfo") or function() end)
    if not (okCursor and kind == "item" and FP:PlainNumber(id) == stack.itemID) then
        if CursorHasItem and CursorHasItem() then pcall(ClearCursor) end
        return FP:Warn(L["Nothing was destroyed: your bags changed."])
    end
    pcall(delete)
    if CursorHasItem and CursorHasItem() then
        -- Refused: back where it came from.
        pcall(ClearCursor)
        return FP:Warn(L["The game did not destroy %s."], stack.link or "?")
    end
    if (stack.total or 0) > 0 then
        FP:Print(L["Destroyed %d %s, worth %s at a merchant."], stack.count,
            stack.link or "?", FP:Money(stack.total))
    else
        FP:Print(L["Destroyed %d %s, worth nothing at a merchant."], stack.count,
            stack.link or "?")
    end
    FP:Safe("InfoBar:Update", M.Update, M)
    -- The next stack in the tooltip at once, the destroyed one locked and so
    -- left out, and once more when the bags have caught up.
    RefreshJunkTip(cell)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function() RefreshJunkTip(cell) end)
    end
end

--- A click on the display: the stack its tooltip shows, asked about first
--- unless the page says not to.
local function JunkClick(cell)
    -- Shift is wanted unless the page lets a plain click destroy as well.
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    if not (shift or M.db.junkPlainClick) then return end
    if InCombat() then return FP:Warn(L["Nothing is destroyed in combat."]) end
    local best = junkTip
    if best == nil then
        -- No tooltip up, which a click from the mouse always brings: the
        -- stack it would show.
        best = FindJunk()
        local now = best and ReadSlot(best.bag, best.slot, true)
        if best then best.guid = now and now.guid end
    end
    if not best then return end
    if M.db.junkNoAsk then return DestroyJunk(best, cell) end

    FP:Ask({
        title    = L["Destroy Gray Item"],
        question = L["Do you really want to destroy %d %s?"]:format(best.count,
            best.link or "?"),
        detail   = (best.total > 0)
            and L["A merchant would pay %s for it. This cannot be undone."]
                :format(FP:Money(best.total))
            or L["A merchant would pay nothing for it. This cannot be undone."],
        yes      = L["Destroy"],
        no       = L["Cancel"],
        skipTip  = L["Turns on \"Skip the confirmation\" on the Info bar page "
            .. "when you click Destroy."],
        onYes    = function(skip)
            if skip then
                M.db.junkNoAsk = true
                FP:NotifyOptionChanged(M)
            end
            DestroyJunk(best, cell)
        end,
    })
end

-- The stack the bar showed last, for its dimming; nil while none qualifies.
local junkShown

local function JunkFigure()
    junkShown = FindJunk()
    return "", ICONS.junk
end

--- Hovering it: the stack in the game's own item tooltip, the owner's rule
--- for one of the game's objects, with how many and what a merchant pays;
--- or why nothing is offered. Shown again over itself when the stack
--- changes, so either kind of tooltip takes the other's place.
ShowJunk = function(cell, label)
    junkLabel = label
    local best = FindJunk()
    if best then
        local now = ReadSlot(best.bag, best.slot, true)
        best.guid = now and now.guid
    end
    junkTip = best or false
    if not (best and GameTooltip) then
        junkTip = false
        if GameTooltip and GameTooltip:IsOwned(cell) then GameTooltip:Hide() end
        cell.gameTip = nil
        return FP:ShowTip(cell, { label, L["No gray item to destroy"] }, "STEADY")
    end
    FP:HideTip(cell)
    GameTooltip:SetOwner(cell, SitsLow(cell) and "ANCHOR_TOP" or "ANCHOR_BOTTOM")
    pcall(GameTooltip.SetBagItem, GameTooltip, best.bag, best.slot)
    GameTooltip:AddLine(" ")
    local worth = (best.total > 0)
        and L["Stack of %d, worth %s at a merchant"]:format(best.count, FP:Money(best.total))
        or L["Stack of %d, worth nothing at a merchant"]:format(best.count)
    GameTooltip:AddLine(worth, 1, 1, 1)
    if InCombat() then
        GameTooltip:AddLine(L["Not in combat"], 1, 0.25, 0.25)
    else
        GameTooltip:AddLine(M.db.junkPlainClick and L["Click to destroy this stack"]
            or L["Shift click to destroy this stack"], 0.1, 1, 0.1)
    end
    GameTooltip:Show()
    cell.gameTip = true
end

-- ---------------------------------------------------------------------------
-- The lists behind two figures: gold and durability
--
-- Asked for on 2026-09-26, the day the client started keeping the gold records
-- at all: hovering the gold figure lists every character with its gold, and a
-- character's records can be deleted from there after a question that names
-- it. Hovering durability lists the damaged pieces, which a CurseForge user
-- asked for the same day.
--
-- **The list and nothing else**, by the owner's instruction: no heading and no
-- total. The total is the figure being hovered, right beside the list, which
-- is the same reason the other figures say nothing but their label.
--
-- **Not the GameTooltip, for either.** A tooltip cannot be clicked, and the
-- gold list has something to click. The durability list went through the
-- GameTooltip first and showed why it is wrong there too: the tooltip styles
-- its first line as a title, so the worst piece came out in larger type than
-- the rest. One frame of our own serves both. It opens like a tooltip, stays
-- while the pointer is on the figure or on the frame with a moment's grace for
-- the way between them, and only takes the mouse while it is open, so nothing
-- is left standing over the playfield to swallow clicks.
-- ---------------------------------------------------------------------------

local LIST_PAD   = 10
local LIST_ROW   = 18    -- the floor; a larger text size makes rows taller
local LIST_GAP   = 24    -- between the longest name and the values
local LEAD_GAP   = 10    -- between the slot column and the names
local DELETE_W   = 20    -- the delete control, reserved when any row has one
local LIST_GRACE = 0.3   -- seconds the pointer may be on neither

local hoverList
local volumePanel    -- the volume's slider, see *The volume* below

local function ClassColor(token)
    local colors = _G.RAID_CLASS_COLORS
    local color  = token and colors and colors[token]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

local function Colored(text, token)
    return Hex(ClassColor(token)) .. text .. "|r"
end

--- The color escape for the quality of what is worn in a slot, or nil.
--
-- Asked of the client rather than read out of the item link. The first version
-- took the `|cffRRGGBB` out of the link, and on this client every name came
-- out white: a modern link can carry its color in another form, and the
-- quality itself is one call away and means the same in every language.
local function QualityHex(slot)
    if type(GetInventoryItemQuality) ~= "function" then return nil end
    local ok, quality = pcall(GetInventoryItemQuality, "player", slot)
    quality = Number(ok and quality)
    if not quality then return nil end

    local get = C_Item and C_Item.GetItemQualityColor
    if get then
        local okColor, r, g, b = pcall(get, quality)
        if okColor and Number(r) and Number(g) and Number(b) then
            return Hex(r, g, b)
        end
    end
    local colors = _G.ITEM_QUALITY_COLORS
    local color = type(colors) == "table" and colors[quality]
    if type(color) == "table" and Number(color.r) then
        return Hex(color.r, color.g, color.b)
    end
    return nil
end

--- The question before a character is forgotten, shared with the mail list's
--- since 2026-10-03, see FP:AskToForgetCharacter.
local function AskToForget(record)
    FP:AskToForgetCharacter(record.key,
        Colored(record.name or "?", record.class),
        function() FP:Safe("InfoBar:Update", M.Update, M) end)
end

local function ListRow(f, index)
    local row = f.rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, f)
    -- The slot, in the faint role: orientation rather than content.
    row.lead = FP:FontString(row, "OVERLAY", "faint")
    row.lead:SetPoint("LEFT")
    row.lead:SetJustifyH("LEFT")

    row.name = FP:FontString(row, "OVERLAY", "body")
    row.name:SetPoint("LEFT")
    row.name:SetJustifyH("LEFT")

    row.value = FP:FontString(row, "OVERLAY", "body")
    row.value:SetPoint("RIGHT")
    row.value:SetJustifyH("RIGHT")

    local delete = CreateFrame("Button", nil, row)
    delete:SetPoint("TOPRIGHT")
    delete:SetPoint("BOTTOMRIGHT")
    delete:SetWidth(DELETE_W - 4)
    local hl = FP:Texture(delete, "HIGHLIGHT", FP.colors.hover)
    hl:SetAllPoints()
    local x = FP:FontString(delete, "OVERLAY", "body")
    x:SetPoint("CENTER")
    -- Red, the owner's wish: it deletes something. In the text rather than set
    -- on the string, so a change of design that repaints the fonts keeps it.
    x:SetText(ClientColor("RED_FONT_COLOR", 1, 0.1, 0.1) .. "X|r")
    delete:SetScript("OnClick", function()
        if row.onDelete then row.onDelete() end
    end)
    row.delete = delete

    f.rows[index] = row
    return row
end

local function ListFrame()
    if hoverList then return hoverList end

    local f = CreateFrame("Frame", "ForeverPlusInfoBarList", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()

    local bg = FP:Texture(f, "BACKGROUND", FP.colors.bg)
    bg:SetAllPoints()
    FP:AddBorder(f)

    f.rows = {}

    -- Closes itself once the pointer has been on neither the figure nor this
    -- frame for a moment. Checked rather than driven by OnLeave, because
    -- leaving the figure to reach this frame is the whole point of it.
    f:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        if self:IsMouseOver() or (owner and owner:IsVisible() and owner:IsMouseOver()) then
            self.away = 0
            return
        end
        self.away = (self.away or 0) + elapsed
        if self.away > LIST_GRACE then self:Hide() end
    end)

    hoverList = f
    return f
end

--- Opens a list centered under a figure, or above it when the screen leaves no
--- room under it, see FP:HangSteady.
--
-- Centered since 2026-10-13, the owner's wish once he saw the cooldowns' list
-- stand off to the right of its icon: whatever opens on the bar opens under
-- the middle of what was hovered. At the screen's edge the frame's clamp slides
-- it back in, which is what the tooltips rely on as well.
--
-- Each entry is { lead, name, value, onDelete, dim }; only the name is
-- required. `dim` draws the row faint, for a character the gold leaves out.
-- The slot column and the delete column take room only when some entry uses
-- them, so the gold list has no empty column on its left.
local function ShowList(cell, entries)
    local f = ListFrame()
    f.owner, f.away = cell, 0
    -- One open at a time: a list closes the volume's slider.
    if volumePanel then volumePanel:Hide() end

    local hasLead, hasDelete = false, false
    for _, entry in ipairs(entries) do
        if entry.lead then hasLead = true end
        if entry.onDelete then hasDelete = true end
    end
    local deleteW = hasDelete and DELETE_W or 0

    -- Placed and shown before anything is measured, which is two pitfalls in
    -- AGENTS.md at once: a frame without a point has no position to measure
    -- from, and string widths are only reliable on a visible frame. The side is
    -- settled at the end, once its height is known.
    f:SetSize(200, LIST_ROW * #entries + 2 * LIST_PAD)
    FP:HangSteady(f, cell)
    f:Show()

    -- Rows are placed at the floor height first, so that every string is
    -- measured inside something anchored, and placed again once the text
    -- size has said how tall a row really is.
    local function Place(rowH)
        local y = LIST_PAD
        for index = 1, #entries do
            local row = f.rows[index]
            row:SetHeight(rowH)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", LIST_PAD, -y)
            row:SetPoint("TOPRIGHT", -LIST_PAD, -y)
            y = y + rowH
        end
        return y
    end

    for index, entry in ipairs(entries) do
        local row = ListRow(f, index)
        row.onDelete = entry.onDelete
        row.lead:SetText(entry.lead or "")
        row.name:SetText(entry.name or "")
        row.value:SetText(entry.value or "")
        row.value:ClearAllPoints()
        row.value:SetPoint("RIGHT", row, "RIGHT", -deleteW, 0)
        row.delete:SetShown(entry.onDelete ~= nil)
        row:SetAlpha(entry.dim and 0.45 or 1)
        row:Show()
    end
    for index = #entries + 1, #f.rows do f.rows[index]:Hide() end
    Place(LIST_ROW)

    local leadW, nameW, valueW = 0, 0, 0
    for index = 1, #entries do
        local row = f.rows[index]
        leadW  = math.max(leadW, row.lead:GetStringWidth())
        nameW  = math.max(nameW, row.name:GetStringWidth())
        valueW = math.max(valueW, row.value:GetStringWidth())
    end

    -- The names line up after the widest slot, so the slots read as a column.
    local leadSpace = hasLead and (leadW + LEAD_GAP) or 0
    for index = 1, #entries do
        local row = f.rows[index]
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row, "LEFT", leadSpace, 0)
    end

    local rowH = math.max(LIST_ROW,
        math.ceil(f.rows[1].name:GetStringHeight() + 4))
    local height = Place(rowH) + LIST_PAD
    f:SetSize(leadSpace + nameW + LIST_GAP + valueW + deleteW + 2 * LIST_PAD, height)
    FP:HangSteady(f, cell)
end

-- A faction's badge behind a name in the gold list, asked for by the owner on
-- 2026-10-13 for a character of the other faction, as high as the list's
-- text. **The garrison missions' faction icon**, 55 by 49 in the atlas of
-- build 70338, the third of three he looked at in game, "for now": the crest
-- of the client's character list came first and drew gray, and tinted it
-- still had too little contrast; a crest with a ground of its own was his
-- idea, and the garrison's round minimap badge the second he saw.
local FACTION_CREST = {
    Alliance = { atlas = "GarrMission_ClassIcon-Alliance", ratio = 55 / 49 },
    Horde    = { atlas = "GarrMission_ClassIcon-Horde",    ratio = 55 / 49 },
}
local crestKnown = {}

local function HasAtlas(name)
    if crestKnown[name] == nil then
        local get = C_Texture and C_Texture.GetAtlasInfo
        local ok, info = false, nil
        if type(get) == "function" then ok, info = pcall(get, name) end
        crestKnown[name] = (ok and type(info) == "table") and true or false
    end
    return crestKnown[name]
end

--- The badge of another faction than this character's, as an escape behind a
--- name, or "" for this faction, for one not known and for a missing atlas.
local function OtherCrest(faction, mine)
    local crest = faction and mine and faction ~= mine and FACTION_CREST[faction]
    if not crest or not HasAtlas(crest.atlas) then return "" end
    local size = 12
    local font = FP:Font("body")
    if font and font.GetFont then
        local _, height = font:GetFont()
        size = math.max(10, math.floor((tonumber(height) or 12) + 0.5))
    end
    return string.format(" |A:%s:%d:%d|a", crest.atlas, size,
        math.max(1, math.floor(size * crest.ratio + 0.5)))
end

-- ---------------------------------------------------------------------------
-- The ruleset behind a name
--
-- The realm's whole name behind a character, "(Classic Beta PvP 2)", made the
-- gold list so wide that the names stood far from their gold, the owner's
-- report of 2026-10-13: **the ruleset instead, PvE or PvP**, his words for
-- Normal and PvP, and RP and Hardcore beside them once WoW Forever has them.
-- By the ruleset's number, measured on the beta the same day: 15 for Normal,
-- 14 for PvP; whether the launch keeps the numbers is to be seen there. A
-- number not known here falls back to the realm's name.
-- ---------------------------------------------------------------------------

local function RulesetName(mode)
    if mode == 15 then return L["PvE"] end
    if mode == 14 then return L["PvP"] end
    return nil
end

--- Each realm's ruleset, where every character known on it plays the same
--- one: so a character that has not logged in since the numbers were kept is
--- named by the others on its realm. A realm holding two rulesets names none.
local function RealmRulesets()
    local seen = {}
    local function Note(entry)
        if type(entry) ~= "table" then return end
        local realm, mode = FP:Plain(entry.realm), FP:PlainNumber(entry.mode)
        if not (realm and mode) then return end
        if seen[realm] == nil then
            seen[realm] = mode
        elseif seen[realm] ~= mode then
            seen[realm] = false
        end
    end
    for _, entry in pairs(GoldStore() or {}) do Note(entry) end
    local characters = type(FP.global) == "table" and FP.global.characters
    for _, entry in pairs(type(characters) == "table" and characters or {}) do
        Note(entry)
    end
    return seen
end

--- A character's ruleset number by its key, from its gold record or from the
--- mail list's, for the cooldowns' records, which keep none.
local function RulesetOfKey(key)
    local gold = GoldStore()
    local entry = gold and gold[key]
    if type(entry) == "table" and entry.mode then return FP:PlainNumber(entry.mode) end
    local characters = type(FP.global) == "table" and FP.global.characters
    local known = type(characters) == "table" and characters[key]
    return type(known) == "table" and FP:PlainNumber(known.mode) or nil
end

--- What follows a name in the gold and the cooldowns list: the ruleset where
--- it is another than this character's, and the realm only where the ruleset
--- cannot be named and the realm differs.
local function CharacterTag(realm, mode, me, realms)
    mode = mode or (realm and realms[realm]) or nil
    if mode and me.mode and mode ~= me.mode then
        local name = RulesetName(mode)
        if name then return " |cff888888(" .. name .. ")|r" end
    end
    if realm and me.realm and realm ~= me.realm then
        return " |cff888888(" .. realm .. ")|r"
    end
    return ""
end

--- Every character with its gold, richest first, each but this one deletable.
local function ShowOverview(cell)
    local records = GoldRecords()
    -- Only the characters counted, while the page asks for that.
    if M.db.goldHideOthers then
        local counted = {}
        for _, record in ipairs(records) do
            if record.counted then counted[#counted + 1] = record end
        end
        records = counted
    end
    -- Nothing to list yet, which happens only while the client will not name
    -- the character. The figure itself says what little there is to say.
    if #records == 0 then return end

    local current = FP:CharacterKey()
    local myFaction = FP:Plain(Call(UnitFactionGroup, "player"))
    local me, realms = Me(), RealmRulesets()
    -- The characters the figure counts first, then the rest, dimmed, each
    -- group richest first, so the top of the list adds up to the figure.
    table.sort(records, function(a, b)
        if a.counted ~= b.counted then return a.counted end
        if a.copper ~= b.copper then return a.copper > b.copper end
        return tostring(a.name) < tostring(b.name)
    end)

    local entries = {}
    for _, record in ipairs(records) do
        local text = Colored(record.name or "?", record.class)
            .. OtherCrest(record.faction, myFaction)
            .. CharacterTag(record.realm, record.mode, me, realms)
        entries[#entries + 1] = {
            name  = text,
            value = FP:Money(record.copper),
            dim   = not record.counted,
            -- The character being played has no delete: every record about
            -- it is written again within a second, see FP:ForgetCharacter.
            onDelete = (record.key ~= current)
                and function() AskToForget(record) end or nil,
        }
    end

    -- Last, under the characters and a blank line apart from them, the owner's
    -- wish: what this one has won or lost since logging in, green for a gain
    -- and red for a loss, in the client's own colors.
    local change = SessionChange()
    if change then
        entries[#entries + 1] = { name = "" }
        local value
        if change > 0 then
            value = ClientColor("GREEN_FONT_COLOR", 0.1, 1, 0.1) .. "+"
                .. FP:Money(change) .. "|r"
        elseif change < 0 then
            value = ClientColor("RED_FONT_COLOR", 1, 0.1, 0.1) .. "-"
                .. FP:Money(-change) .. "|r"
        else
            value = FP:Money(0)
        end
        entries[#entries + 1] = { name = L["This session"], value = value }
    end
    ShowList(cell, entries)
end

--- What hovering the durability figure says: every damaged piece, worst first.
--
-- Asked for on CurseForge on 2026-09-26 and taken on by the owner the same
-- day, who then asked for the slot as orientation and for the colors of the
-- game's own armour figure. The figure on the bar is the worst piece; this
-- names the pieces behind it.
--
-- Undamaged pieces are left out, since a list of everything at a hundred
-- percent answers nothing, and with nothing damaged the hover says only its
-- label, as every other figure does. The item's name comes out of its link,
-- which is structure rather than words.
local function ShowDamaged(cell, label)
    local damaged = {}
    for _, piece in ipairs(Condition()) do
        if piece.share < 1 then damaged[#damaged + 1] = piece end
    end
    if #damaged == 0 then
        return FP:ShowTip(cell, { label }, "STEADY")
    end
    table.sort(damaged, function(a, b)
        if a.share ~= b.share then return a.share < b.share end
        return a.slot < b.slot
    end)

    local entries = {}
    for _, piece in ipairs(damaged) do
        local ok, link = pcall(GetInventoryItemLink, "player", piece.slot)
        local name = ok and FP:Plain(link) and link:match("%[(.-)%]") or "?"
        -- The name in its item quality color and the condition in the
        -- color of the game's armour figure, white while that figure would
        -- not light the piece up at all. Split that way by the owner the same
        -- day: which piece it is and how bad it is are two questions.
        local quality = QualityHex(piece.slot)
        local color = AlertColor(piece.slot)
        local hex = color and Hex(color.r, color.g, color.b) or "|cffffffff"
        entries[#entries + 1] = {
            lead  = FP:SlotName(piece.slot),
            name  = quality and (quality .. name .. "|r") or name,
            value = hex .. Percent(piece.share) .. "|r",
        }
    end

    -- Last, under the pieces and a blank line apart from them, like the
    -- session line under the characters: what repairing everything worn would
    -- cost, when the client says. See RepairCost.
    local cost = RepairCost()
    if cost and cost > 0 then
        entries[#entries + 1] = { name = "" }
        entries[#entries + 1] = { name = L["Repair cost"], value = FP:Money(cost) }
    end
    ShowList(cell, entries)
end

-- ---------------------------------------------------------------------------
-- The volume
--
-- Asked for on CurseForge on 2026-10-13 and gated with the owner the same day:
-- the master volume as a figure, and **a slider that opens when the figure is
-- hovered**, the player's own description and the owner's choice over the
-- mouse wheel. It writes the client's own console variable, so the game's
-- sound options and its key bindings for the volume move it too. From 0 to 100
-- percent in steps of five, the steps of the client's own slider, read in its
-- sound options for build 70338. **Red while all sound is off**, which the
-- slider leaves alone: a figure saying 70 percent while nothing can be heard
-- explains nothing.
--
-- The slider's frame works like the lists above: it opens like a tooltip,
-- stays while the pointer is on the figure or on it, and takes the mouse only
-- while it is open. It also stays while its thumb is held, since a drag may
-- well leave both.
-- ---------------------------------------------------------------------------

local VOLUME_STEP = 0.05
local SLIDER_W    = 160
local SLIDER_H    = 14
local TRACK_H     = 4
local THUMB_W     = 8
local SLIDER_GAP  = 8     -- between the heading and the slider

local function CVarText(name)
    return FP:Plain(Call((C_CVar and C_CVar.GetCVar) or _G.GetCVar, name))
end

--- The master volume from 0 to 1, or nil when the client does not say.
local function MasterVolume()
    local value = tonumber(CVarText("Sound_MasterVolume") or "")
    if not value then return nil end
    return math.max(0, math.min(1, value))
end

-- **The speaker crossed out while nothing can be heard**, S1 of the 1.0.2
-- brief, silhouetteone's request on CurseForge of 2026-10-20: while all sound
-- is off, and at a master volume of 0, the owner's addition of 2026-10-21. The
-- client's own mark for it, which its voice chat's speaker button lays over
-- the same speaker, VoiceChatSpeakerTemplate in its interface code for build
-- 70450; laid over the icon the same way, see M:Update. A click still only
-- switches all sound and never raises a volume of 0.
local MUTED_MARK = "Interface\\Common\\VoiceChat-Muted"

local function Muted()
    if CVarText("Sound_EnableAllSound") == "0" then return true end
    local volume = MasterVolume()
    return volume ~= nil and volume < 0.005
end

local function Volume()
    local volume = MasterVolume()
    if not volume then return nil end
    local text = Percent(volume)
    if CVarText("Sound_EnableAllSound") == "0" then
        text = ClientColor("RED_FONT_COLOR", 1, 0.1, 0.1) .. text .. "|r"
    end
    return text
end

local function SetMasterVolume(value)
    local set = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if type(set) ~= "function" then return end
    pcall(set, "Sound_MasterVolume", string.format("%.2f", value))
end

--- All of the game's sound off, or on again, on a click on the display,
--- CF6.11. The client's own switch for it, Enable Sound in its settings,
--- which leaves the volume as it was; read anew every time, so a change
--- made there is what the next click starts from.
local function ToggleSound()
    local set = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if type(set) ~= "function" then return end
    local off = CVarText("Sound_EnableAllSound") == "0"
    pcall(set, "Sound_EnableAllSound", off and "1" or "0")
    FP:Safe("InfoBar:Update", M.Update, M)
end

local function VolumePanel()
    if volumePanel then return volumePanel end

    local f = CreateFrame("Frame", "ForeverPlusInfoBarVolume", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()

    local bg = FP:Texture(f, "BACKGROUND", FP.colors.bg)
    bg:SetAllPoints()
    FP:AddBorder(f)

    f.title = FP:FontString(f, "OVERLAY", "normal")
    f.title:SetPoint("TOPLEFT", LIST_PAD, -LIST_PAD)
    f.title:SetJustifyH("LEFT")

    f.value = FP:FontString(f, "OVERLAY", "body")
    f.value:SetPoint("TOPRIGHT", -LIST_PAD, -LIST_PAD)
    f.value:SetJustifyH("RIGHT")

    -- What a click on the display does, under the slider while it does it.
    f.hint = FP:FontString(f, "OVERLAY", "body")
    f.hint:SetJustifyH("LEFT")

    -- A plain Slider, without a template like every frame here but the
    -- secure buttons. Track, filled part and thumb are the scheme's switch
    -- colors, so a change of design and the class color reach them.
    local slider = CreateFrame("Slider", nil, f)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(VOLUME_STEP)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetSize(SLIDER_W, SLIDER_H)
    slider:EnableMouse(true)

    local track = FP:Texture(slider, "BACKGROUND", FP.colors.off)
    track:SetHeight(TRACK_H)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    -- Given as a path and recolored, since this build documents the thumb as
    -- a texture asset rather than a texture of ours.
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(THUMB_W, SLIDER_H)
    thumb:SetColorTexture(unpack(FP.colors.textOn))
    FP:TrackTexture(thumb, FP.colors.textOn)

    local fill = FP:Texture(slider, "ARTWORK", FP.colors.on)
    fill:SetHeight(TRACK_H)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")

    slider:SetScript("OnValueChanged", function(_, value)
        -- Set from the client's value when the frame opens, not by the player.
        if f.setting then return end
        SetMasterVolume(value)
        f.value:SetText(Percent(value))
        FP:Safe("InfoBar:Update", M.Update, M)
    end)
    slider:SetScript("OnMouseDown", function() f.dragging = true end)
    slider:SetScript("OnMouseUp", function() f.dragging = false end)
    f.slider = slider

    -- Closes itself once the pointer has been on neither the figure nor this
    -- frame for a moment, as the lists do, but never while the thumb is held.
    f:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        local held = self.slider.IsDraggingThumb and self.slider:IsDraggingThumb()
        if self.dragging or held or self:IsMouseOver()
            or (owner and owner:IsVisible() and owner:IsMouseOver()) then
            self.away = 0
            return
        end
        self.away = (self.away or 0) + elapsed
        if self.away > LIST_GRACE then self:Hide() end
    end)
    f:SetScript("OnHide", function(self) self.dragging = false end)

    volumePanel = f
    return f
end

--- Opens the slider under the figure, or above it when the bar sits low.
local function ShowVolume(cell)
    local f = VolumePanel()
    if hoverList then hoverList:Hide() end
    f.owner, f.away, f.dragging = cell, 0, false

    -- Placed and shown before anything is measured, as ShowList is.
    f:SetSize(SLIDER_W + 2 * LIST_PAD, SLIDER_H + 2 * LIST_PAD)
    FP:HangSteady(f, cell)
    f:Show()

    -- Wide enough for the heading beside the widest value, so the value never
    -- runs into the heading while the thumb moves.
    f.title:SetText(L["Master Volume"])
    f.value:SetText(Percent(1))
    local width = math.max(SLIDER_W,
        f.title:GetStringWidth() + LIST_GAP + f.value:GetStringWidth())
    local titleH = math.ceil(f.title:GetStringHeight())

    local volume = MasterVolume() or 0
    f.value:SetText(Percent(volume))
    f.setting = true
    f.slider:SetValue(volume)
    f.setting = false

    local hintH = 0
    if M.db.volumeClick then
        f.hint:SetText(L["Click the display to turn all sound off or on"])
        f.hint:Show()
        width = math.max(width, f.hint:GetStringWidth())
        hintH = SLIDER_GAP + math.ceil(f.hint:GetStringHeight())
    else
        f.hint:SetText("")
        f.hint:Hide()
    end

    f.slider:ClearAllPoints()
    f.slider:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_PAD, -(LIST_PAD + titleH + SLIDER_GAP))
    f.slider:SetWidth(width)
    f.hint:ClearAllPoints()
    f.hint:SetPoint("TOPLEFT", f.slider, "BOTTOMLEFT", 0, -SLIDER_GAP)
    f:SetSize(width + 2 * LIST_PAD,
        LIST_PAD + titleH + SLIDER_GAP + SLIDER_H + hintH + LIST_PAD)
    FP:HangSteady(f, cell)
end

--- Takes down whatever hangs from the bar, as a drag begins: all of it is fixed
--- to the screen and would stay behind while the bar moves.
function M:CloseHovers()
    FP:HideTip()
    if hoverList then hoverList:Hide() end
    if volumePanel then volumePanel:Hide() end
end

-- ---------------------------------------------------------------------------
-- Cooldowns across characters
--
-- Asked for by the owner on 2026-10-10 and gated the same day: the long
-- cooldowns of every character on the account in one list, behind an icon on
-- the bar that is there by default and says nothing until hovered. What is
-- kept is FP.COOLDOWNS in Data/Cooldowns.lua, Dedicated Study and the
-- profession cooldowns of twenty hours or more.
--
-- One record per character in FP.global.cooldowns, keyed by FP:CharacterKey
-- like every other record about a character: `{ name, realm, class, readyAt }`,
-- where `readyAt` holds, per line, the server's clock when it is ready, 0 when
-- it is ready now and -1 while the client has not said. The server's clock
-- rather than GetTime, which starts again with every session, so a time kept
-- by one character means the same to every other and after a restart.
--
-- **A line the character no longer has leaves its record** the next time the
-- character is looked at, the owner's condition: a profession unlearned, or
-- Dedicated Study given back in the Legacy tree, takes its line along. A
-- character is only looked at while it is played, so what another one changed
-- shows at its next login. Never in a fight: nothing here can be renewed in
-- one, and what the client answers there is not to be trusted.
--
-- **Not seen in game yet**, and only Dedicated Study can be before the launch:
-- whether the client reports a recipe's cooldown outside the profession's
-- window is the first thing `/fplus cooldowns` will tell.
-- ---------------------------------------------------------------------------

local COOLDOWN_EVERY = 5      -- seconds between two looks at this character
local UNREAD = -1             -- known, but the client has not said when

local cooldownsAt

-- Lines this session acts as if the character did not have, keyed by the
-- line's key or "all": `/fplus cooldowns unlearn`, until the next reload. For
-- trying out what unlearning does, the owner's case of 2026-10-10, when the
-- Legacy tree would not let Dedicated Study go.
local pretendUnlearned = {}

local function CooldownStore()
    if type(FP.global) ~= "table" then return nil end
    if type(FP.global.cooldowns) ~= "table" then FP.global.cooldowns = {} end
    return FP.global.cooldowns
end

--- The server's clock in seconds, the same for every character.
local function ServerNow()
    return Number(Call(_G.GetServerTime)) or Number(Call(_G.time))
end

--- Start and duration of a spell's cooldown, or nil, nil.
--
-- C_Spell's table first, the shape of this engine, then the older call with
-- loose values should the first refuse. Every value through Number, since a
-- cooldown is one of the things C_Secrets can withhold.
local function SpellCooldown(spell)
    local get = C_Spell and C_Spell.GetSpellCooldown
    if type(get) == "function" then
        local ok, info = pcall(get, spell)
        if ok and type(info) == "table" then
            local read, start, duration = pcall(function()
                return info.startTime, info.duration
            end)
            start, duration = Number(read and start), Number(read and duration)
            if start and duration then return start, duration end
        end
    end
    if type(_G.GetSpellCooldown) == "function" then
        local ok, start, duration = pcall(_G.GetSpellCooldown, spell)
        start, duration = Number(ok and start), Number(ok and duration)
        if start and duration then return start, duration end
    end
    return nil, nil
end

local function ItemCooldown(item)
    local get = (C_Container and C_Container.GetItemCooldown) or _G.GetItemCooldown
    if type(get) ~= "function" then return nil, nil end
    local ok, start, duration = pcall(get, item)
    return Number(ok and start), Number(ok and duration)
end

--- Seconds until a cooldown ends, 0 once it has, nil when the client will not
--- say.
local function Left(start, duration)
    if not (start and duration) then return nil end
    -- The global cooldown is not the line's own, as with the Hearthstone.
    if start <= 0 or duration <= GLOBAL_COOLDOWN then return 0 end
    local now = Number(Call(GetTime))
    if not now then return nil end
    return math.max(0, start + duration - now)
end

--- Whether this character has a line at all.
local function Has(entry)
    if pretendUnlearned.all or pretendUnlearned[entry.key] then return false end
    if entry.item then
        -- The profession first: a tool kept after it was unlearned cannot be
        -- used, so its cooldown means nothing any more.
        local skilled = not entry.requires
        for _, spell in ipairs(entry.requires or {}) do
            if FP:KnowsSpell(spell) then
                skilled = true
                break
            end
        end
        if not skilled then return false end
        local count = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
        -- With the bank, where a tool between two uses may well be kept.
        return (Number(Call(count, entry.item, true)) or 0) > 0
    end
    for _, spell in ipairs(entry.spells or {}) do
        if FP:KnowsSpell(spell) then return true end
    end
    return false
end

--- Seconds until a line is ready: the earliest of the spells the character
--- knows, so a group reads ready as soon as one of them is.
local function LineLeft(entry)
    if entry.item then return Left(ItemCooldown(entry.item)) end
    local earliest
    for _, spell in ipairs(entry.spells or {}) do
        if FP:KnowsSpell(spell) then
            local left = Left(SpellCooldown(spell))
            if left and (not earliest or left < earliest) then earliest = left end
        end
    end
    return earliest
end

--- Looks at this character's lines and keeps what it finds, at most every
--- COOLDOWN_EVERY seconds unless forced.
local function RecordCooldowns(force)
    local now = Number(Call(GetTime)) or 0
    if not force and cooldownsAt and now - cooldownsAt < COOLDOWN_EVERY then return end
    cooldownsAt = now
    if InCombatLockdown and InCombatLockdown() then return end

    local key, store, clock = FP:CharacterKey(), CooldownStore(), ServerNow()
    if not (key and store and clock) then return end

    local record = type(store[key]) == "table" and store[key] or {}
    local readyAt = type(record.readyAt) == "table" and record.readyAt or {}
    for _, entry in ipairs(FP.COOLDOWNS or {}) do
        if not Has(entry) then
            readyAt[entry.key] = nil
        else
            local left = LineLeft(entry)
            if left then
                readyAt[entry.key] = (left > 0) and math.floor(clock + left + 0.5) or 0
            elseif readyAt[entry.key] == nil then
                readyAt[entry.key] = UNREAD
            end
        end
    end

    -- A character with no line left has no record either, so it leaves the
    -- list rather than standing in it with nothing under its name.
    if next(readyAt) == nil then
        store[key] = nil
        return
    end
    record.readyAt = readyAt
    local me = Identity()
    if me then record.name, record.realm, record.class = me.name, me.realm, me.class end
    store[key] = record
end

--- A line's name: its label, or the client's own name in the player's
--- language.
local function LineName(entry)
    if entry.label then return entry.label end
    local name
    if entry.item then
        if C_Item and C_Item.GetItemNameByID then
            name = FP:Plain(Call(C_Item.GetItemNameByID, entry.item))
        end
        if not name and _G.GetItemInfo then
            name = FP:Plain(Call(_G.GetItemInfo, entry.item))
        end
        return name or tostring(entry.item)
    end
    local spell = entry.spells and entry.spells[1]
    if C_Spell and C_Spell.GetSpellName then
        name = FP:Plain(Call(C_Spell.GetSpellName, spell))
    end
    if not name and _G.GetSpellInfo then name = FP:Plain(Call(_G.GetSpellInfo, spell)) end
    return name or tostring(spell)
end

--- How long until a line is ready, in days and hours down to minutes.
local function Remaining(seconds)
    if seconds >= 86400 then
        return string.format(L["%d d %d h"], math.floor(seconds / 86400),
            math.floor(seconds % 86400 / 3600))
    elseif seconds >= 3600 then
        return string.format(L["%d h %d min"], math.floor(seconds / 3600),
            math.floor(seconds % 3600 / 60))
    end
    -- Up rather than down, so a line never reads "0 min" while it runs.
    return string.format(L["%d min"], math.max(1, math.ceil(seconds / 60)))
end

--- The figure: the icon alone, the owner's choice. The looking happens here,
--- so the record stays fresh for as long as the figure is on.
-- The icon for the whole list, Dedicated Study's, see ICONS.
local COOLDOWNS_ICON = { spell = 1225469, path = ICONS.cooldowns }

local function CooldownsFigure()
    RecordCooldowns()
    return "", IconOf(COOLDOWNS_ICON)
end

--- Every character with its lines, the one being played first and the lines
--- that are ready first under each name.
local function ShowCooldowns(cell, label)
    RecordCooldowns(true)
    local clock = ServerNow() or 0
    local records = {}
    for key, record in pairs(CooldownStore() or {}) do
        if type(record) == "table" and type(record.readyAt) == "table"
           and next(record.readyAt) ~= nil then
            records[#records + 1] = { key = key, record = record }
        end
    end

    local current = FP:CharacterKey()
    local me, realms = Me(), RealmRulesets()
    table.sort(records, function(a, b)
        if (a.key == current) ~= (b.key == current) then return a.key == current end
        return tostring(a.record.name) < tostring(b.record.name)
    end)

    local entries = {}
    for _, item in ipairs(records) do
        local record = item.record
        local lines = {}
        for _, entry in ipairs(FP.COOLDOWNS or {}) do
            local readyAt = tonumber(record.readyAt[entry.key])
            if readyAt then lines[#lines + 1] = { entry = entry, readyAt = readyAt } end
        end
        table.sort(lines, function(a, b) return a.readyAt < b.readyAt end)

        -- The character's name once, in the slot column, so the lines under it
        -- read as its own.
        local who = Colored(record.name or "?", record.class)
            .. CharacterTag(record.realm, RulesetOfKey(item.key), me, realms)
        for index, line in ipairs(lines) do
            local value
            if line.readyAt == UNREAD then
                value = "|cff888888?|r"
            elseif line.readyAt - clock <= 0 then
                value = ClientColor("GREEN_FONT_COLOR", 0.1, 1, 0.1) .. L["Ready"] .. "|r"
            else
                value = Remaining(line.readyAt - clock)
            end
            entries[#entries + 1] = { lead = (index == 1) and who or nil,
                name = LineName(line.entry), value = value }
        end
    end

    -- Nobody has a line yet, or only lines the table no longer holds, which a
    -- record kept from an older list can: the label and a sentence instead of
    -- a list with no rows, which ShowList cannot lay out.
    if #entries == 0 then
        return FP:ShowTip(cell, { label,
            { L["None of your characters has one yet."], wrap = true } }, "STEADY")
    end
    ShowList(cell, entries)
end

--- Acts as if this character did not have a line, until the next reload, so
--- that it can be seen leaving the list: `/fplus cooldowns unlearn <line>`,
--- "all" for every line, "off" to stop. English, like every answer to a typed
--- command.
function M:CooldownPretend(arg)
    local wanted = (arg or ""):lower():gsub("%s+", "")
    if wanted == "off" then
        wipe(pretendUnlearned)
        FP:Print("Every cooldown line counts as it really is again.")
    elseif wanted == "all" then
        pretendUnlearned.all = true
        FP:Print("Acting as if this character had no cooldown line, until the "
            .. "next reload. /fplus cooldowns unlearn off stops it.")
    else
        local found
        for _, entry in ipairs(FP.COOLDOWNS or {}) do
            if entry.key:lower() == wanted then found = entry end
        end
        if not found then
            local keys = {}
            for _, entry in ipairs(FP.COOLDOWNS or {}) do keys[#keys + 1] = entry.key end
            FP:Print("/fplus cooldowns unlearn <line>, where the line is one of: %s, "
                .. "all, off.", table.concat(keys, ", "))
            return
        end
        pretendUnlearned[found.key] = true
        FP:Print("Acting as if this character did not have %s, until the next "
            .. "reload. /fplus cooldowns unlearn off stops it.", LineName(found))
    end
    RecordCooldowns(true)
    FP:Safe("InfoBar:Update", M.Update, M)
end

--- What the client says about each line on this character, and what is kept
--- for every character: `/fplus cooldowns`, in English like every answer to a
--- typed command.
function M:CooldownStatus()
    RecordCooldowns(true)
    local clock = ServerNow()
    local function Shown(...)
        local out = {}
        for i = 1, math.max(select("#", ...), 1) do
            local v = select(i, ...)
            local ok, text = pcall(function() return tostring(v) .. "" end)
            out[#out + 1] = ok and text or "secret"
        end
        return table.concat(out, ", ")
    end
    FP:Print("Cooldowns on this character, server clock %s:", tostring(clock))
    for _, entry in ipairs(FP.COOLDOWNS or {}) do
        FP:Print("  %s (%s): has %s, seconds left %s", LineName(entry), entry.key,
            tostring(Has(entry)), tostring(LineLeft(entry)))
        if entry.item then
            local count = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
            FP:Print("    item %d: carried %s, cooldown %s", entry.item,
                Shown(Call(count, entry.item, true)), Shown(ItemCooldown(entry.item)))
        else
            for _, spell in ipairs(entry.spells or {}) do
                if FP:KnowsSpell(spell) then
                    FP:Print("    spell %d known, cooldown %s", spell,
                        Shown(SpellCooldown(spell)))
                end
            end
        end
    end
    FP:Print("Kept for every character:")
    for key, record in pairs(CooldownStore() or {}) do
        local parts = {}
        for line, readyAt in pairs(type(record) == "table"
                and type(record.readyAt) == "table" and record.readyAt or {}) do
            parts[#parts + 1] = string.format("%s %s", line,
                (readyAt > 0 and clock) and string.format("in %d s", readyAt - clock)
                or tostring(readyAt))
        end
        FP:Print("  %s: %s", tostring(type(record) == "table" and record.name or key),
            table.concat(parts, ", "))
    end
end

-- ---------------------------------------------------------------------------
-- Experience
--
-- Experience per hour and the time to the next level, D01 of the after launch
-- plan, gated with the owner on 2026-11-06. Built on 2026-09-23 and hidden from
-- the next day on, since neither figure had ever appeared. **Nothing in the
-- client kept them from it**: `UnitXP` and `UnitXPMax` read plainly in combat
-- and out of it, measured on 2026-09-27. The code drew nothing for the first
-- minute or before any experience came in, and threw the measurement away at
-- every level up, so a player switching them on saw a bar without them.
--
-- So **both stand from the first moment**, and the arithmetic is in
-- Core/Util.lua, where the harness reaches it. One measurement serves both:
--
--   **A session is a login**, the rule the gold list set on 2026-09-28: a
--   /reload goes on counting, and only logging in again starts from nothing.
--   The first PLAYER_ENTERING_WORLD says which of the two it was. The owner's
--   answer of 2026-11-06, over the last thirty minutes, which would forget a
--   break by itself but jumps at every large quest reward.
--
--   **A click on either display starts anew**, for the break the rate would
--   otherwise carry along for the rest of the evening, the same answer. Each
--   has a switch under its display, like every click on this bar.
--
-- The measurement lies in `FP.global.xpSession`, one record rather than one per
-- character, since it is good for one session anyway, and it names the character
-- it belongs to. FP:ForgetCharacter has nothing to do for it: the record names
-- the character being played, which cannot be forgotten.
-- ---------------------------------------------------------------------------

-- In a block of its own, like the section after it, with one name outside it:
-- Lua allows a function 200 local names and this file's main chunk ran into that
-- the day these two were built. It holds about 193 now, so a new section goes
-- the same way.
local Experience = {}
do
    local function PlayerXP()
        return Number(Call(UnitXP, "player")), Number(Call(UnitXPMax, "player"))
    end

    --- Whether experience can come in at all, by the rules the client's own
    --- experience bar follows: GameRulesUtil.CanShowExperienceBar, read in its
    --- interface code for build 70790, here through the C functions it asks.
    --- Without an answer to the level the figures stay.
    local function GainsXP()
        if FP:Truth(Call(_G.IsXPUserDisabled)) then return false end
        local rules = rawget(_G, "C_GameRules")
        local rule = Enum and Enum.GameRule and Enum.GameRule.ExperienceBarDisabled
        if type(rules) == "table" and rule and FP:Truth(Call(rules.IsGameRuleActive, rule)) then
            return false
        end
        local level = Number(Call(UnitLevel, "player"))
        local cap = Number(Call(_G.GetMaxPlayerLevel))
        local forExpansion = Number(Call(_G.GetMaxLevelForPlayerExpansion))
        if forExpansion and (not cap or forExpansion < cap) then cap = forExpansion end
        return not (level and cap and level >= cap)
    end

    --- Starts a measurement, or with `keep` goes on with the one in the saved file
    --- if it is this character's and belongs to this run of the client.
    local function BeginXP(keep)
        local global, key = FP.global, FP:CharacterKey()
        if type(global) ~= "table" or not key then return end
        local now = GetTime()
        local stored = global.xpSession
        if keep and type(stored) == "table" and stored.key == key
           and Number(stored.started) and stored.started <= now then
            return
        end
        local xp, maximum = PlayerXP()
        local session = FP:NewXPSession(now, xp, maximum)
        session.key = key
        global.xpSession = session
    end

    --- The measurement, brought up to date, with what it was brought up to date
    --- with and its rate. Nothing before the world is there, whose first
    --- PLAYER_ENTERING_WORLD has not said yet whether this is a login.
    local function ReadXP()
        local global = FP.global
        local session = type(global) == "table" and global.xpSession
        if type(session) ~= "table" or session.key ~= FP:CharacterKey() then return nil end
        local xp, maximum = PlayerXP()
        FP:NoteXP(session, xp, maximum)
        return session, xp, maximum, FP:XPPerHour(session, GetTime())
    end

    -- Built when the file loads rather than when a display is switched on, so the
    -- figures are right for a display switched on halfway through a session, the
    -- reason the gold list's session does it the same way. The displays read the
    -- same numbers every second while they are on, and a second look adds nothing.
    local xpWatch = CreateFrame("Frame")
    xpWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
    xpWatch:RegisterEvent("PLAYER_XP_UPDATE")
    xpWatch:SetScript("OnEvent", function(self, event, isInitialLogin)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent(event)
            FP:Safe("InfoBar:BeginXP", BeginXP, FP:Truth(isInitialLogin) ~= true)
        else
            FP:Safe("InfoBar:ReadXP", ReadXP)
        end
    end)

    function Experience.Rate()
        if not GainsXP() then return nil end
        local _, _, _, rate = ReadXP()
        if not rate then return nil end
        if rate >= 1000 then return L["%sk xp/h"]:format(FP:Decimal(rate / 1000, 1)) end
        return L["%d xp/h"]:format(math.floor(rate + 0.5))
    end

    --- Whole minutes up to an hour and the hours with one decimal above, with a
    --- question mark for as long as no experience has come in to go by.
    function Experience.ToLevel()
        if not GainsXP() then return nil end
        local session, xp, maximum, rate = ReadXP()
        if not session then return nil end
        local seconds = FP:SecondsToLevel(rate, xp, maximum)
        if not seconds then return L["%s h to level"]:format("?") end
        if seconds >= 3600 then
            return L["%s h to level"]:format(FP:Decimal(seconds / 3600, 1))
        end
        return L["%d min to level"]:format(math.max(1, math.ceil(seconds / 60)))
    end

    --- The percentage the hover writes after an amount: never 100 before the level
    --- is there, the way the bar never looks full before it is.
    local function ShareOf(part, whole)
        return math.floor(part / whole * 100)
    end

    --- What hovering either display says, every value there is, the owner's answer.
    --- It follows the figures while it is up, see `live` on the item.
    function Experience.Show(cell, label, key)
        local lines = { label }
        local session, xp, maximum, rate = ReadXP()
        local hasRoom = maximum and maximum > 0

        local level = Number(Call(UnitLevel, "player"))
        if level and xp and hasRoom then
            lines[#lines + 1] = { L["Level %d"]:format(level),
                right = string.format("%s / %s (%d%%)", Count(xp), Count(maximum),
                    ShareOf(xp, maximum)) }
        end

        local rested = Number(Call(_G.GetXPExhaustion))
        if rested and rested > 0 and hasRoom then
            lines[#lines + 1] = { L["Rested"],
                right = string.format("%s (%d%%)", Count(rested), ShareOf(rested, maximum)) }
        end

        if session then
            lines[#lines + 1] = { L["This session"],
                right = L["%s in %s"]:format(Count(session.gained),
                    Remaining(math.max(GetTime() - session.started, 0))) }
        end
        if rate then
            lines[#lines + 1] = { L["Per hour"], right = Count(math.floor(rate + 0.5)) }
            local seconds = FP:SecondsToLevel(rate, xp, maximum)
            lines[#lines + 1] = { L["To the next level"],
                right = seconds and Remaining(seconds) or "?" }
        end

        for _, hint in ipairs(ClickHints(key)) do lines[#lines + 1] = hint end
        FP:ShowTip(cell, lines, "STEADY")
    end

    --- A click on either display, see *Clicks on the bar*: the figures and a hover
    --- that is up follow at once.
    function Experience.Restart(key)
        if not M.db[key .. "Click"] then return end
        BeginXP(false)
        FP:Safe("InfoBar:Update", M.Update, M)
    end
end

-- ---------------------------------------------------------------------------
-- The addons' CPU usage
--
-- F12 of the after launch plan, CF6.15 on CurseForge, settled with the owner on
-- 2026-11-04: in the hover of the frame rate, with the total and the five
-- busiest addons, highest first, and no switch beyond the frame rate's own. Only
-- if it was quick to build, his condition, and it was, since the client has done
-- the measuring all along: its own performance tooltip reads the same functions
-- of C_AddOnProfiler, read in its interface code for build 70790.
--
-- **In percent since 2026-11-06, the figure the client's addon list calls Current
-- CPU**: the recent average, over the last 60 ticks, of the addons' time against
-- the time the whole game takes. It first showed that time in milliseconds, and
-- the owner took that out before the release, since it says little to a player.
-- See FP:ShareOfAllAddOns. Asked for only while the hover is up, and a client that
-- will not say gets a line that says so, which is not the same thing as an addon
-- taking no time.
-- ---------------------------------------------------------------------------

local ShowFramerate
do
    local BUSIEST_ADDONS = 5
    -- Room for a long addon's name beside its figure from the start, since the
    -- names on the list change while it is up, and it should hold still. A
    -- longer one still fits: the tooltip grows once, see FP:ShowTip.
    local TIP_MIN_WIDTH = 240

    function ShowFramerate(cell, label)
        local lines = { label, minWidth = TIP_MIN_WIDTH }
        local profiler = rawget(_G, "C_AddOnProfiler")
        local metrics = Enum and Enum.AddOnProfilerMetric
        local metric = metrics and metrics.RecentAverageTime
        local overall, application, busiest
        if type(profiler) == "table" and metric and FP:Truth(Call(profiler.IsEnabled)) then
            overall = Number(Call(profiler.GetOverallMetric, metric))
            application = Number(Call(profiler.GetApplicationMetric, metric))
            busiest = FP:BusiestAddOns(
                Call(profiler.GetTopKAddOnsForMetric, metric, BUSIEST_ADDONS), BUSIEST_ADDONS)
        end

        local total = FP:ShareOfAllAddOns(overall, application)
        if total then
            lines[#lines + 1] = L["Addon CPU usage"]
            lines[#lines + 1] = { L["Total"], right = FP:ShareText(total) }
            -- The same order as by time, since a larger time is a larger share.
            -- An addon that would read 0% earns no line, like one taking no time.
            for _, addon in ipairs(busiest) do
                local share = FP:ShareOfAddOn(addon.value, overall, application)
                local text = share and FP:ShareText(share)
                if text and text ~= "0%" then
                    lines[#lines + 1] = { addon.name, right = text }
                end
            end
        else
            lines[#lines + 1] = { L["Addon CPU usage"], right = L["unavailable"] }
        end

        for _, hint in ipairs(ClickHints("framerate")) do lines[#lines + 1] = hint end
        FP:ShowTip(cell, lines, "STEADY")
    end
end

-- The default order on the row, which the player can change since 2026-10-13,
-- see *The order* below. It was fixed until then: what changes fastest sits
-- on the right, so the left half stays still and stays readable.
-- The order on the bar, and the order the page lists its switches in. The label
-- is what hovering a figure says, and nothing more: the figure itself is right
-- there under the cursor, so a description would be explaining what is already
-- on screen.
-- `hover` replaces the plain label for an item that has more to say than its
-- name: gold lists the characters, durability the damaged pieces, both in the
-- list above, which closes itself, and a currency adds its limit in the
-- addon's own tooltip. Everything else shows its label in that tooltip.
--
-- The currencies sit right after gold: money of a kind, and slow to change,
-- so they belong on the still left half. The bag slots come between, right
-- after gold, the owner's place for them on 2026-10-09: the one figure, or a
-- figure per kind, whichever the page asks for, the other standing empty.
--
-- `option` names the switch an item answers to when it is not its own key,
-- which is how the six kinds share the one switch for bag slots.
local ITEMS = {
    -- First, the owner's place for it on 2026-10-13, although it changes
    -- every minute: where a clock is looked for.
    { key = "time",        label = L["Time"],                        get = Clock,
      hover = ShowClock },
    -- Then where you are, the owner's place for both on 2026-10-13, once he
    -- had seen the bar: the coordinates change fastest of everything here and
    -- stand on the left all the same, against the rule above, by his word.
    { key = "zone",        label = L["Zone"],                        get = Zone,
      hover = ShowZone },
    { key = "coords",      label = L["Coordinates"],                 get = Coords },
    { key = "hearth",      label = L["Hearthstone"],                 get = Hearth },
    { key = "gold",        label = L["Gold"],                        get = Gold,
      hover = ShowOverview },
    { key = "bags",        label = L["Free Bag Slots"],              get = BagsFigure,
      hover = ShowBagKinds },
}
for index = 1, MAX_KINDS do ITEMS[#ITEMS + 1] = BagKindItem(index) end
for _, item in ipairs({
    -- Right after the bag slots, both 1.0.2's, the owner's places for them.
    -- `dim`, a display drawn faint while it has nothing to act on.
    { key = "ammo",        label = L["Ammunition"],                  get = AmmoFigure,
      hover = ShowAmmo },
    -- `leave`, run when the pointer leaves the display.
    { key = "junk",        label = L["Destroy Cheapest Gray Item"],  get = JunkFigure,
      hover = ShowJunk,
      leave = function() junkTip = nil end,
      dim = function() return junkShown == nil end,
      click = JunkClick },
    CurrencyItem("favor", MERCHANTS_FAVOR, L["Merchant's Favor"]),
    CurrencyItem("honor", HONOR_POINTS,    L["Honor Points"]),
    { key = "durability",  label = L["Durability"],                  get = Durability,
      hover = ShowDamaged },
    -- `live`, a hover drawn anew every second while the pointer stays on it.
    { key = "xpRate",      label = L["Experience per hour"],         get = Experience.Rate,
      hover = function(cell, label) Experience.Show(cell, label, "xpRate") end,
      live = true,
      click = function() Experience.Restart("xpRate") end },
    { key = "timeToLevel", label = L["Time to the next level"],      get = Experience.ToLevel,
      hover = function(cell, label) Experience.Show(cell, label, "timeToLevel") end,
      live = true,
      click = function() Experience.Restart("timeToLevel") end },
    { key = "latency",     label = L["Latency"],                     get = Latency },
    -- `click`, for a display that takes a click itself, see *Clicks on the
    -- bar*; the secure ones are SecureClicks.
    { key = "framerate",   label = L["Frames per second"],           get = Framerate,
      hover = ShowFramerate,
      live = true,
      click = function() if M.db.framerateReload then AskReload() end end },
    -- `mark`, a texture laid over a display's icon while it hands one back.
    { key = "volume",      label = L["Volume"],                      get = Volume,
      hover = ShowVolume,
      mark = function() return Muted() and MUTED_MARK or nil end,
      click = function() if M.db.volumeClick then ToggleSound() end end },
    -- Last, the owner's place for it on 2026-10-10: an icon with nothing beside
    -- it, which does not move the figures before it about.
    { key = "cooldowns",   label = L["Cooldowns"],                   get = CooldownsFigure,
      hover = ShowCooldowns },
}) do ITEMS[#ITEMS + 1] = item end

-- ---------------------------------------------------------------------------
-- The order
--
-- Each switch's items, in ITEMS' order: the six kinds of bag answer to the
-- one switch for bag slots and move with it. The switches in the order they
-- first appear in ITEMS are the default order on the bar.
-- ---------------------------------------------------------------------------

local ITEMS_OF, DEFAULT_ORDER = {}, {}
for _, item in ipairs(ITEMS) do
    local key = item.option or item.key
    if not ITEMS_OF[key] then
        ITEMS_OF[key] = {}
        DEFAULT_ORDER[#DEFAULT_ORDER + 1] = key
    end
    table.insert(ITEMS_OF[key], item)
end

--- The bar's order: the stored one, and every switch it does not name, one
--- added in a later release above all, at its default place, right after the
--- switch it follows by default.
function M:Order()
    local stored = self.db and self.db.order
    local out, seen = {}, {}
    if type(stored) == "table" then
        for _, key in ipairs(stored) do
            if ITEMS_OF[key] and not seen[key] then
                seen[key] = true
                out[#out + 1] = key
            end
        end
    end
    for index, key in ipairs(DEFAULT_ORDER) do
        if not seen[key] then
            seen[key] = true
            local at = 0
            for back = index - 1, 1, -1 do
                for position, have in ipairs(out) do
                    if have == DEFAULT_ORDER[back] then at = position break end
                end
                if at > 0 then break end
            end
            table.insert(out, at + 1, key)
        end
    end
    return out
end

--- Keeps a new order, from the page's drag, and shows it on the bar.
function M:SetOrder(order)
    if not self.db then return end
    local copy = {}
    for index, key in ipairs(order or {}) do copy[index] = key end
    self.db.order = copy
    FP:Safe("InfoBar:Update", M.Update, M)
end

--- The default order again, on the bar and on the page.
function M:ResetOrder()
    if not self.db then return end
    self.db.order = nil
    FP:Safe("InfoBar:Update", M.Update, M)
    FP:NotifyOptionChanged(self)
end

--- The items in the order the bar shows them.
local function OrderedItems()
    local out = {}
    for _, key in ipairs(M:Order()) do
        for _, item in ipairs(ITEMS_OF[key] or {}) do out[#out + 1] = item end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The bar
-- ---------------------------------------------------------------------------

function M:Build()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "ForeverPlusInfoBar", UIParent)
    frame:SetSize(200, BAR_H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    -- Off on the container. The cells below take the mouse instead, so what
    -- swallows a click is exactly what is drawn rather than a rectangle
    -- stretching past it. See AGENTS.md on a mouse-enabled frame over the
    -- playfield; this bar sits flush with the top edge, which is the cheapest
    -- strip of screen there is.
    frame:EnableMouse(false)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f) self:StopDrag(f) end)

    -- The addon's own look rather than an invented one, asked for on
    -- 2026-09-24 after the first version put bare text over the playfield and
    -- proved unreadable against bright terrain. FP:Texture registers itself
    -- with the theme, so both of these follow a change of scheme without this
    -- module knowing a scheme exists.
    local bg = FP:Texture(frame, "BACKGROUND", FP.colors.bg)
    bg:SetAllPoints()
    FP:AddBorder(frame)
    -- Kept for the page's own background color, see *The look*.
    self.bg = bg

    -- One cell per figure rather than one string for the row. It costs a frame
    -- each and buys the only thing a single string cannot give: somewhere to
    -- hover that means one figure instead of all of them.
    self.cells = {}
    for _, item in ipairs(ITEMS) do
        local cell = CreateFrame("Frame", nil, frame)
        cell:SetHeight(BAR_H)
        cell:EnableMouse(true)

        -- Shift and drag on any figure moves the whole bar, when switched on.
        -- Any drag marks the cell, so the release that ends it is no click.
        cell:RegisterForDrag("LeftButton")
        cell:SetScript("OnDragStart", function(c)
            c.dragged = true
            if self.db.shiftDrag and IsShiftKeyDown and IsShiftKeyDown() then
                self.shiftDragging = true
                self:CloseHovers()
                frame:StartMoving()
            end
        end)

        -- A click the display acts on itself, see *Clicks on the bar*: on the
        -- release, over the display, and never at the end of a drag.
        cell:SetScript("OnMouseDown", function(c) c.dragged = nil end)
        cell:SetScript("OnMouseUp", function(c, button)
            if button ~= "LeftButton" or c.dragged or not item.click then return end
            if not c:IsMouseOver() then return end
            FP:Safe("InfoBar:click", item.click, c)
        end)
        cell:SetScript("OnDragStop", function()
            if not self.shiftDragging then return end
            self.shiftDragging = nil
            self:StopDrag(frame)
        end)

        -- The primary role, which is what every setting standing on its own in
        -- the window uses. The color arrives with the role rather than being
        -- picked here: that is the rule in AGENTS.md under *How a page looks*,
        -- and it is what makes this row follow a restyle.
        local text = FP:FontString(cell, "OVERLAY", "normal")
        text:SetPoint("LEFT")
        cell.text = text

        -- The label alone, by the owner's instruction: a description here would
        -- explain a figure that is already on screen next to the cursor. An
        -- item with a list of its own opens that instead, and the list closes
        -- itself: see ShowList.
        cell:SetScript("OnEnter", function(c)
            if item.hover then
                return FP:Safe("InfoBar:hover", item.hover, c, item.label)
            end
            local lines = { item.label }
            for _, hint in ipairs(ClickHints(item.key)) do lines[#lines + 1] = hint end
            FP:ShowTip(c, lines, "STEADY")
        end)
        -- The addon's own tooltip, taken down by owner, so leaving one figure
        -- for the next never hides what the next one has just put up; and
        -- the game's, for the one display that shows a game object in it.
        cell:SetScript("OnLeave", function(c)
            FP:HideTip(c)
            if c.gameTip then
                c.gameTip = nil
                if GameTooltip and GameTooltip:IsOwned(c) then GameTooltip:Hide() end
            end
            if item.leave then FP:Safe("InfoBar:leave", item.leave, c) end
        end)

        self.cells[item.key] = cell
    end

    -- Assigned before anything places it. The other order is the bug that left
    -- BuffExpiry's icons without a point for weeks: ApplyPosition begins by
    -- returning quietly when the frame is nil.
    self.frame = frame
    self:Repaint()
    self:ApplyPosition()
    return frame
end

--- Puts the current font and its color back on every cell.
--
-- A font size change moves the icons as well, so the caller rebuilds the row
-- after this rather than only recoloring it.
function M:Repaint()
    if not self.cells then return end
    local font = self:BarFont() or FP:Font("normal") or _G.GameFontNormal
    if not font then return end
    for _, cell in pairs(self.cells) do
        cell.text:SetFontObject(font)
        if font.GetTextColor then
            local r, g, b = font:GetTextColor()
            if r then cell.text:SetTextColor(r, g, b) end
        end
    end
    self:PaintLook()
end

function M:ApplyPosition()
    local frame = self.frame
    if not frame then return end
    frame:ClearAllPoints()
    if self.db.positioned and self.db.point then
        frame:SetPoint(self.db.point, UIParent, self.db.relPoint or self.db.point,
            self.db.x or 0, self.db.y or 0)
    else
        -- Flush with the top edge, asked for on 2026-09-24: the first default
        -- sat a fourteenth of the screen down and read as numbers dropped in
        -- the middle of the view. Nothing of the client's lives up here, and a
        -- couple of units is a gap rather than a share of the screen, so this
        -- one constant does not need scaling.
        frame:SetPoint("TOP", UIParent, "TOP", 0, -2)
    end
end

function M:ResetPosition()
    self.db.positioned = nil
    self.db.point, self.db.relPoint, self.db.x, self.db.y = nil, nil, nil, nil
    self:ApplyPosition()
    FP:Print(L["Info bar is back at its default position."])
end

--- Makes the row draggable, and says so, because an invisible mode is a trap.
--
-- The cells give their mouse back while this is on, or the drag would never
-- reach the container underneath them.
--- Ends a drag and keeps where the bar was put.
function M:StopDrag(frame)
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint()
    self.db.point, self.db.relPoint = point, relPoint
    self.db.x, self.db.y = x, y
    self.db.positioned = true
end

function M:TogglePositioning()
    local frame = self:Build()
    self.moving = not self.moving
    frame:EnableMouse(self.moving)
    for _, cell in pairs(self.cells) do cell:EnableMouse(not self.moving) end

    -- The buttons would sit over the row and swallow the drag.
    FP:Safe("InfoBar:PlaceButtons", M.PlaceButtons, M)

    if self.moving then
        FP:Print(L["Info bar can be dragged. Press the button again when it is "
            .. "where you want it."])
        frame:Show()
    else
        FP:Print(L["Info bar is fixed again."])
        self:Update()
    end
end

function M:Update()
    if not self.enabled or not self.frame then return end

    -- While the bars are being moved, a stand in takes the bar's place, see
    -- Modules/Mover.lua, and the real one with its Hearthstone button stays
    -- out of the way. Out of combat only, which is the only time a session
    -- runs.
    if FP.movingBars then
        self.frame:Hide()
        self:PlaceButtons()
        return
    end

    -- The icons follow the font, so their size is read back rather than fixed.
    local _, fontHeight = self.cells[ITEMS[1].key].text:GetFont()
    local iconSize = math.max(10, math.floor((tonumber(fontHeight) or 12) + 0.5))
    local height   = math.max(BAR_H, iconSize + 8)

    local x, shown = PAD, 0
    refreshKinds = nil
    -- The figures' colors are made readable on the bar's own background
    -- while they are drawn, when the page gives it one.
    local ground = self.db.bgColor
    hexGround = (type(ground) == "table" and ground[1]) and ground or nil
    local hidden = type(self.db.iconsOff) == "table" and self.db.iconsOff or {}
    for _, item in ipairs(OrderedItems()) do
        local cell = self.cells[item.key]
        -- A figure may hand back its own icon after the text, which is how a
        -- currency brings the one the client gives it, and a kind of bag the
        -- one written down for it.
        local value, icon
        if self.db[item.option or item.key] then
            local ok, answer, texture = pcall(item.get)
            if ok then value, icon = answer, texture end
        end

        if value then
            -- CF6.3: the icon, unless hidden on the whole or for this
            -- display; a display that is only an icon then shows its name.
            local withIcon = self.db.icons ~= false and not hidden[item.option or item.key]
            if not withIcon and value == "" then value = item.label end
            -- CF6.1: without the colors that tell a state, the whole figure
            -- in the bar's text color. Textures, the coins of gold among
            -- them, stay.
            if self.db.statusColors == false then
                value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            end
            cell.text:SetText((withIcon and Icon(icon or ICONS[item.key], iconSize) or "")
                .. value)
            -- A mark over the icon, the volume's crossed out speaker: on the
            -- icon at the cell's left, as large as the icon, above the text.
            local mark = withIcon and item.mark and item.mark()
            if mark then
                if not cell.mark then
                    cell.mark = cell:CreateTexture(nil, "OVERLAY", nil, 7)
                end
                cell.mark:SetTexture(mark)
                cell.mark:SetSize(iconSize, iconSize)
                cell.mark:ClearAllPoints()
                cell.mark:SetPoint("LEFT", cell, "LEFT", 0, 0)
                cell.mark:Show()
            elseif cell.mark then
                cell.mark:Hide()
            end
            -- Faint while it has nothing to act on, the gray item's icon
            -- without a stack to offer, at the alpha of a grayed out row.
            cell:SetAlpha((item.dim and item.dim()) and 0.4 or 1)
            cell:SetSize(math.max(cell.text:GetStringWidth(), 1), height)
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", self.frame, "LEFT", x, 0)
            cell:Show()
            x = x + cell:GetWidth() + GAP
            shown = shown + 1
        else
            cell:Hide()
        end
    end
    hexGround = nil

    -- The gray item's tooltip follows the bags while it is up, so it shows
    -- what a click would destroy: within a second of a change, see junkTip.
    local junkCell = self.cells.junk
    if junkTip ~= nil and junkCell and junkCell:IsVisible() and junkCell:IsMouseOver()
       and not SameStack(junkTip, junkShown) then
        FP:Safe("InfoBar:hover", ShowJunk, junkCell, junkLabel)
    end

    -- A hover that follows its figures, for as long as the pointer is on it
    -- and not a moment beyond, and never while the bar itself is being moved.
    local settled = not (self.shiftDragging or self.moving or FP.movingBars)
    for _, item in ipairs(ITEMS) do
        if item.live and settled then
            local cell = self.cells[item.key]
            if cell and cell:IsVisible() and cell:IsMouseOver() then
                FP:Safe("InfoBar:hover", item.hover, cell, item.label)
            end
        end
    end

    if shown > 0 then
        -- One gap too many was added after the last cell.
        self.frame:SetSize(x - GAP + PAD, height)
        self.frame:Show()
    elseif self.moving then
        -- Nothing to show but something to grab hold of.
        self.frame:SetSize(120, height)
        self.frame:Show()
    else
        self.frame:Hide()
    end

    self:PlaceButtons()
end

-- ---------------------------------------------------------------------------
-- The Hearthstone button
--
-- **The first frame in this addon built on a Blizzard template**, and on
-- purpose. Using an item from a click is a protected action, and the only way
-- an addon may offer it is SecureActionButtonTemplate; the owner chose the
-- click on 2026-09-29 with that on the table. Two more followed for 1.0.0,
-- see *The secure buttons over two displays* below. The rule that every
-- frame passes nil as its template stands for everything else, and the
-- reason it exists, a template's OnLoad running inside our tainted code, is
-- why each is made once, out of combat, and given nothing but attributes.
--
-- **It is not part of the bar.** A protected frame cannot be moved, sized,
-- shown or hidden during a fight, and a frame it is anchored to inherits that
-- restriction, while the bar lays its cells out anew every second because
-- widths change. So the button hangs off UIParent and is laid over the
-- Hearthstone cell from outside, every second out of combat. During a fight it
-- stays where it was, a few units off at worst, which costs nothing: the game
-- does not let a Hearthstone be used in combat anyway.
--
-- **Taken away while Shift is held**, when the bar moves that way: the button
-- takes the press as well as the release, so the first touch of a drag over
-- it would use the stone, which is what happened to the player on CurseForge.
-- Out of combat only, like every change to it; in a fight the stone cannot be
-- used anyway.
-- ---------------------------------------------------------------------------

local hearthButton

local function ShiftHeld()
    return M.db and M.db.shiftDrag and IsShiftKeyDown and IsShiftKeyDown()
end

local function HearthButton()
    if hearthButton then return hearthButton end
    if InCombatLockdown and InCombatLockdown() then return nil end

    local b = CreateFrame("Button", "ForeverPlusHearthButton", UIParent,
        "SecureActionButtonTemplate")
    b:SetFrameStrata("MEDIUM")
    -- By id, the locale rule again: "item:6948" names the item on any client.
    b:SetAttribute("type", "item")
    b:SetAttribute("item", "item:" .. HEARTHSTONE)
    -- Both edges, so the template decides by the client's own setting whether
    -- the press or the release uses it, the way an action button does.
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:HookScript("OnEnter", function(self)
        FP:ShowTip(self, { L["Hearthstone"], L["Click to use it"] }, "STEADY")
    end)
    b:HookScript("OnLeave", function(self) FP:HideTip(self) end)
    b:Hide()

    hearthButton = b
    return b
end

--- Lays the button over the Hearthstone cell, or takes it away.
--
-- Only out of combat, and quietly otherwise: the next call after the fight
-- puts it right, since the bar calls this every second.
function M:PlaceHearth()
    if InCombatLockdown and InCombatLockdown() then return end

    local cell = self.cells and self.cells.hearth
    local wanted = self.enabled and self.db.hearth and self.db.hearthClick ~= false
        and not self.moving and not FP.movingBars and not ShiftHeld()
        and cell and cell:IsVisible() and HearthCount() > 0
    if not wanted then
        if hearthButton then hearthButton:Hide() end
        return
    end

    local b = HearthButton()
    local left, bottom, width, height = cell:GetRect()
    if not (b and left) then
        if b then b:Hide() end
        return
    end
    -- The cell's units into UIParent's, which are the same today; the ratio
    -- keeps it right if the bar is ever scaled.
    local scale = cell:GetEffectiveScale() / UIParent:GetEffectiveScale()
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, bottom * scale)
    b:SetSize(width * scale, height * scale)
    b:SetFrameLevel(self.frame:GetFrameLevel() + 10)
    b:Show()
end

-- After a fight, whatever changed during it: the bar switched off, the figure
-- switched off, or the button asked for while the lockdown was on. Registered
-- once at load, like the theme listener below.
local hearthWatch = CreateFrame("Frame")
hearthWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Shift pressed or let go, for the drag above. Asked rather than assumed, as
-- an event this build does not know raises when it is registered.
pcall(hearthWatch.RegisterEvent, hearthWatch, "MODIFIER_STATE_CHANGED")
hearthWatch:SetScript("OnEvent", function()
    FP:Safe("InfoBar:PlaceButtons", M.PlaceButtons, M)
end)

-- ---------------------------------------------------------------------------
-- The secure buttons over two displays
--
-- The coordinates and the time hand their clicks on to the client's own
-- buttons, see *Clicks on the bar*, through a SecureActionButtonTemplate
-- each, built and placed like the Hearthstone's: once, out of combat, off
-- UIParent, laid over the display every second while no fight is on.
--
-- **They take the release, never the press**, `useOnKeyDown` false, which
-- the template reads before the client's setting. And while a drag that
-- began on one runs, it hands on nothing at all, until the frame after the
-- drag ends, so the release that ends a drag cannot click either way. That
-- is how a Shift click on the time and a Shift drag of the bar share one
-- display. In combat the attributes cannot change, so there a drag is
-- relied on to be no click by itself.
--
-- They stay while Shift is held, unlike the Hearthstone's, which uses the
-- press: the calendar is a Shift click.
-- ---------------------------------------------------------------------------

local SECURE_KEYS = { "coords", "time" }
local MODIFIERS   = { "", "shift-" }

-- [display] = its button, built at the first moment one is wanted.
local overlays = {}

--- Hands a button's clicks on as asked, or nothing at all while `clicks` is
--- nil. Only what changed is written: a protected frame's attributes are
--- written only out of combat, and every second would be a waste.
local function SetClicks(b, clicks)
    local none = rawget(_G, "ATTRIBUTE_NOOP") or ""
    for _, prefix in ipairs(MODIFIERS) do
        local target = clicks and clicks[prefix]
        local kind   = target and "click" or none
        if b:GetAttribute(prefix .. "type1") ~= kind then
            b:SetAttribute(prefix .. "type1", kind)
        end
        if b:GetAttribute(prefix .. "clickbutton1") ~= target then
            b:SetAttribute(prefix .. "clickbutton1", target)
        end
    end
end

local function Overlay(key)
    if overlays[key] then return overlays[key] end
    if InCombatLockdown and InCombatLockdown() then return nil end

    local b = CreateFrame("Button", "ForeverPlusInfoBar_" .. key, UIParent,
        "SecureActionButtonTemplate")
    b:SetFrameStrata("MEDIUM")
    b:RegisterForClicks("LeftButtonUp")
    b:SetAttribute("useOnKeyDown", false)

    -- The bar moves with Shift and drag from here as from any display.
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        if not (InCombatLockdown and InCombatLockdown()) then SetClicks(self, nil) end
        if M.frame and ShiftHeld() then
            M.shiftDragging = true
            M:CloseHovers()
            M.frame:StartMoving()
        end
    end)
    b:SetScript("OnDragStop", function(self)
        if M.shiftDragging then
            M.shiftDragging = nil
            M:StopDrag(M.frame)
        end
        -- The frame after, once the release has gone past any click.
        C_Timer.After(0, function()
            self.dragging = nil
            FP:Safe("InfoBar:PlaceButtons", M.PlaceButtons, M)
        end)
    end)

    -- The display's own hover, which this button takes from it.
    b:HookScript("OnEnter", function()
        local cell = M.cells and M.cells[key]
        local enter = cell and cell:GetScript("OnEnter")
        if enter then enter(cell) end
    end)
    b:HookScript("OnLeave", function()
        local cell = M.cells and M.cells[key]
        if cell then FP:HideTip(cell) end
    end)
    b:Hide()

    overlays[key] = b
    return b
end

--- Lays each button over its display, or takes it away. Out of combat only,
--- like the Hearthstone's; the bar calls this every second.
function M:PlaceOverlays()
    if InCombatLockdown and InCombatLockdown() then return end
    for _, key in ipairs(SECURE_KEYS) do
        local cell = self.cells and self.cells[key]
        local clicks = SecureClicks(key)
        local wanted = self.enabled and self.db[key] and not self.moving
            and not FP.movingBars and cell and cell:IsVisible() and next(clicks)
        local b = overlays[key]
        if not wanted then
            if b then b:Hide() end
        elseif not (b and b.dragging) then
            b = Overlay(key)
            local left, bottom, width, height = cell:GetRect()
            if b and left then
                SetClicks(b, clicks)
                local scale = cell:GetEffectiveScale() / UIParent:GetEffectiveScale()
                b:ClearAllPoints()
                b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, bottom * scale)
                b:SetSize(width * scale, height * scale)
                b:SetFrameLevel(self.frame:GetFrameLevel() + 10)
                b:Show()
            elseif b then
                b:Hide()
            end
        end
    end
end

--- Every button over the bar: the Hearthstone's and the two above.
function M:PlaceButtons()
    self:PlaceHearth()
    self:PlaceOverlays()
end

-- ---------------------------------------------------------------------------
-- The look
--
-- CF6.1 to CF6.3 on CurseForge, settled with the owner on 2026-10-17: the
-- bar's own font, size and text color, a switch for the colors that tell a
-- state, its own background and border, each with an opacity, and its icons
-- on the whole and per display. **The bar alone**: the lists and tooltips it
-- opens keep the addon's look, his word.
--
-- **Nothing set is the design**: a color the page never set follows the
-- scheme, the Design page's opacity included, and the moment one is set it is
-- exactly what was picked, the opacity in it and nothing on top. The text
-- color is taken as picked as well, while the figures' own colors are made
-- readable on the bar's own background once it has one, see Hex.
-- ---------------------------------------------------------------------------

local barFont

--- The bar's own font object: the addon's normal text, in the family and
--- size the page asks for. Made once and changed in place, like the addon's
--- own, so every cell follows at once.
function M:BarFont()
    local base = FP:Font("normal") or _G.GameFontNormal
    if not base then return nil end
    if not barFont then
        barFont = CreateFont and CreateFont("ForeverPlusInfoBarFont")
        if not barFont then return base end
    end
    pcall(barFont.CopyFontObject, barFont, base)

    local ok, path, size, flags = pcall(base.GetFont, base)
    if not (ok and path and size) then return base end
    local family = self.db.font or "addon"
    for _, source in ipairs(FONT_SOURCES) do
        if source.key == family then path = SourcePath(source) or path end
    end
    local percent = math.max(50, math.min(200, tonumber(self.db.fontSize) or 100))
    pcall(barFont.SetFont, barFont, path, size * percent / 100, flags)

    local color = self.db.textColor
    if type(color) == "table" and color[1] then
        pcall(barFont.SetTextColor, barFont, color[1], color[2], color[3])
    end
    return barFont
end

--- The color a swatch shows while the page has set none: the addon's text
--- color, or the scheme's background or border as drawn now.
function M:LookColor(which)
    if which == "text" then
        local font = FP:Font("normal") or _G.GameFontNormal
        if font and font.GetTextColor then
            local r, g, b = font:GetTextColor()
            if r then return r, g, b, 1 end
        end
        return 1, 0.82, 0, 1
    end
    local color = FP.colors[which] or { 1, 1, 1, 1 }
    return color[1], color[2], color[3], color[4] or 1
end

--- The bar's background and border, its own where the page set them.
--
-- After the scheme has painted them, which the theme does before it calls
-- this file back, so a color set here survives a change of scheme.
function M:PaintLook()
    local frame = self.frame
    if not (frame and self.bg) then return end
    local bg = self.db.bgColor
    if type(bg) == "table" and bg[1] then
        self.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    else
        self.bg:SetColorTexture(self:LookColor("bg"))
    end
    local border = self.db.borderColor
    if frame.SetBorderColor then
        if type(border) == "table" and border[1] then
            frame:SetBorderColor(border[1], border[2], border[3], border[4] or 1)
        else
            frame:SetBorderColor(self:LookColor("border"))
        end
    end
end

--- Everything under Appearance back as the design has it.
function M:ResetLook()
    local db = self.db
    db.font, db.fontSize, db.statusColors, db.icons = "addon", 100, true, true
    db.textColor, db.bgColor, db.borderColor, db.iconsOff = nil, nil, nil, nil
    FP:RefreshModule(self.name)
    FP:NotifyOptionChanged(self)
end

-- The picker for the icons of single displays: each display with an icon,
-- in the bar's order, as that icon, dimmed while hidden.
local PICK, PICK_GAP = 22, 6

--- The icon a display wears, for the picker: the client's own for a
--- currency and for the cooldowns, else the one written down.
local function DisplayIcon(key)
    if key == "favor" or key == "honor" then
        local info = CurrencyInfo(key == "favor" and MERCHANTS_FAVOR or HONOR_POINTS)
        local icon = type(info) == "table" and Number(info.iconFileID)
        if icon then return icon end
    elseif key == "cooldowns" then
        return IconOf(COOLDOWNS_ICON)
    end
    return ICONS[key]
end

--- The displays the picker offers: the switches with an icon, as ordered.
local function PickerKeys()
    local out = {}
    for _, key in ipairs(M:Order()) do
        local item = ITEMS_OF[key] and ITEMS_OF[key][1]
        if item and DisplayIcon(key) then out[#out + 1] = key end
    end
    return out
end

local function LabelOf(key)
    local item = ITEMS_OF[key] and ITEMS_OF[key][1]
    return item and item.label or key
end

function M:BuildIconPicker(holder, width)
    holder.buttons = {}
    holder.width = width

    local caption = FP:FontString(holder, "OVERLAY", "body")
    caption:SetPoint("TOPLEFT", FP.ROW_TEXT_X, -4)
    caption:SetText(L["Click an icon to hide or show it on the bar."])
    FP:FitLabel(caption, holder)
    holder.caption = caption

    for _, key in ipairs(PickerKeys()) do
        local b = CreateFrame("Button", nil, holder)
        b:SetSize(PICK, PICK)
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        -- A file id or a path, both of which a texture takes.
        tex:SetTexture(DisplayIcon(key))
        b.tex = tex
        FP:Texture(b, "HIGHLIGHT", FP.colors.hover):SetAllPoints()
        b:SetScript("OnClick", function()
            if not self.db.icons then return end
            self.db.iconsOff = type(self.db.iconsOff) == "table" and self.db.iconsOff or {}
            self.db.iconsOff[key] = (not self.db.iconsOff[key]) or nil
            if not next(self.db.iconsOff) then self.db.iconsOff = nil end
            self:RefreshIconPicker(holder)
            FP:Safe("InfoBar:Update", M.Update, M)
        end)
        FP:Tooltip(b, LabelOf(key), L["Hides or shows this display's icon on the "
            .. "bar."])
        holder.buttons[key] = b
    end
    return self:RefreshIconPicker(holder)
end

--- Lays the picker out in the bar's order and dims the hidden icons.
function M:RefreshIconPicker(holder)
    if not holder.buttons then return 0 end
    local hidden = type(self.db.iconsOff) == "table" and self.db.iconsOff or {}
    local left = FP.ROW_TEXT_X
    local perRow = math.max(1, math.floor(((holder.width or 300) - left + PICK_GAP)
        / (PICK + PICK_GAP)))
    local top = 4 + math.ceil(holder.caption:GetStringHeight()) + 6
    local index = 0
    for _, key in ipairs(PickerKeys()) do
        local b = holder.buttons[key]
        if b then
            local column, row = index % perRow, math.floor(index / perRow)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", left + column * (PICK + PICK_GAP),
                -(top + row * (PICK + PICK_GAP)))
            b.tex:SetDesaturated(hidden[key] and true or false)
            b:SetAlpha(hidden[key] and 0.35 or 1)
            index = index + 1
        end
    end
    local rows = math.max(1, math.ceil(index / perRow))
    local height = top + rows * PICK + (rows - 1) * PICK_GAP + 4
    if holder.Resize then holder:Resize(height) end
    return height
end

-- What each item needs from the client, checked once so that an item which can
-- never work says so instead of simply never appearing. A row with a missing
-- figure in it looks exactly like a row whose figure is switched off, and this
-- project has twice shipped a feature that drew nothing and reported nothing.
local NEEDS = {
    coords      = { "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition" },
    xpRate      = { "UnitXP", "UnitXPMax" },
    timeToLevel = { "UnitXP", "UnitXPMax" },
    durability  = { "GetInventoryItemDurability" },
    latency     = { "GetNetStats" },
    framerate   = { "GetFramerate" },
    hearth      = { "GetBindLocation" },
    gold        = { "GetMoney" },
    bags        = { "C_Container.GetContainerNumSlots",
                    "C_Container.GetContainerNumFreeSlots" },
    favor       = { "C_CurrencyInfo.GetCurrencyInfo" },
    honor       = { "C_CurrencyInfo.GetCurrencyInfo" },
    time        = { "GetGameTime" },
    zone        = { "GetZoneText", "GetSubZoneText" },
    volume      = { "C_CVar.GetCVar", "C_CVar.SetCVar" },
    ammo        = { "GetInventoryItemID", "C_Container.GetContainerItemInfo" },
    junk        = { "C_Container.GetContainerItemInfo", "C_Container.PickupContainerItem",
                    "DeleteCursorItem", "GetCursorInfo" },
}

local function Resolve(path)
    local node = _G
    for part in path:gmatch("[^.]+") do
        if type(node) ~= "table" then return nil end
        node = rawget(node, part)
        if node == nil then return nil end
    end
    return node
end

function M:ReportMissing()
    local absent = {}
    for _, item in ipairs(ITEMS) do
        for _, name in ipairs(NEEDS[item.key] or {}) do
            if type(Resolve(name)) ~= "function" and not absent[item.key] then
                absent[item.key] = name
                absent[#absent + 1] = item.key .. " (" .. name .. ")"
            end
        end
    end
    if #absent == 0 then return end
    FP:Warn(L["Info bar: this client build cannot provide %s, so those "
        .. "entries stay empty regardless of their settings."], table.concat(absent, ", "))
end

-- Registered once at load rather than inside OnEnable, because a listener is
-- never removed and a module switched off and on again would stack them. The
-- row is rebuilt as well as recolored: a font size change moves the icons.
FP:OnThemeChanged(function()
    if not M.frame then return end
    FP:Safe("InfoBar:Repaint", M.Repaint, M)
    FP:Safe("InfoBar:Update",  M.Update,  M)
end)

function M:OnEnable()
    local frame = self:Build()
    frame:Show()
    FP:Safe("InfoBar:ApplyClockDefaults", M.ApplyClockDefaults, M)
    FP:Safe("InfoBar:ReportMissing", M.ReportMissing, M)

    self.elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        M.elapsed = M.elapsed + delta
        if M.elapsed < REFRESH then return end
        M.elapsed = 0
        FP:Safe("InfoBar:Update", M.Update, M)
    end)

    self:Update()
end

function M:OnDisable()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:EnableMouse(false)
        self.frame:Hide()
    end
    -- The list hangs off UIParent rather than off the bar, so hiding the
    -- bar does not take it along. The question stays if it is open: deleting a
    -- character's records does not need the bar.
    if hoverList then hoverList:Hide() end
    if volumePanel then volumePanel:Hide() end
    self.moving = nil
    self.shiftDragging = nil
    -- self.enabled is already false here, so this takes the button away, or
    -- leaves it to the end of the fight when the lockdown is on.
    FP:Safe("InfoBar:PlaceButtons", M.PlaceButtons, M)
end

--- Switching an item on or off should not tear the bar down and rebuild it.
function M:Reapply()
    FP:Safe("InfoBar:ApplyClockDefaults", M.ApplyClockDefaults, M)
    self:ApplyPosition()
    -- The font, its size and the colors may have changed on the page.
    FP:Safe("InfoBar:Repaint", M.Repaint, M)
    self:Update()
end
