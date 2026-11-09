-- /fplus -- command line access. The settings window lives in Modules/Menu.lua.
--
-- **What only the commands say stays English**: the help list and every
-- answer to a typed command. The owner's decision of 2026-10-07, during the
-- French review: the commands are for developers and named nowhere a player
-- looks, so no language pays for them. Do not mark these texts with L; the
-- translation check refuses a build that does. A text that also appears
-- anywhere else in the addon keeps its L, since it is translated there
-- anyway: "Import failed: %s" and the other seven below.

local ADDON, FP = ...
local L = FP.L

--- A module's state, as the sentence that reports it, with %s for its title.
--- On and waiting is a third state since the Gameplay page got a switch of its
--- own on 2026-09-30: the module is switched on and its page is not.
local function StateSentence(name)
    if not FP:IsEnabled(name) then return "%s is now off." end
    if FP:IsWanted(name) then return "%s is now on." end
    return "%s is now on, and starts when the Gameplay page is switched on."
end

local function ReportState(name)
    return FP:Print(StateSentence(name), FP:ModuleTitle(FP:GetModule(name)))
end

-- The list names a module the way the commands take it, since this is where a
-- player looks it up for typing; the description beside it is translated.
local function ListModules()
    FP:Print("Modules (v%s):", FP.version)
    for _, name in ipairs(FP.order) do
        local mod = FP.modules[name]
        local on  = FP:IsEnabled(name)
        local tag = on and "|cff44ff44" .. "[on]" .. "|r" or "|cff888888" .. "[off]" .. "|r"
        if on and not FP:IsWanted(name) then tag = "|cffffcc00" .. "[page off]" .. "|r" end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  %s |cffffffff%s|r  |cff888888%s|r",
            tag,
            name,
            FP:T(mod.desc or "")
        ))
    end
end

--- What /fplus with nothing after it does: opens or closes the settings
--- window, or lists the modules while the window is switched off.
--
-- One function, because the minimap button does the same thing, and two copies
-- of "what opening the addon means" would be two things to keep in step.
function FP:ToggleSettings()
    local menu = self:GetModule("Menu")
    if menu and self:IsEnabled("Menu") then return menu:Toggle() end
    return ListModules()
end

-- ---------------------------------------------------------------------------
-- Profiles
--
-- The Profiles page does all of this with buttons; these are the same calls
-- from the command line. Export and import need a window either way: the chat
-- command line stops at 255 characters and an export string is several
-- hundred, so it can be neither shown nor pasted here.
-- ---------------------------------------------------------------------------

local function ListProfiles()
    FP:Print("Profiles:")
    for _, name in ipairs(FP:ListProfiles()) do
        local active = (name == FP.profileName)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s |cffffffff%s|r%s",
            active and "|cff44ff44>|r" or " ", name,
            active and "  |cff888888" .. "(this character)" .. "|r" or ""))
    end
end

local function Skipped(list)
    if not list or #list == 0 then return end
    FP:Warn(FP:Plural(#list, "%d setting could not be brought over:",
        "%d settings could not be brought over:"), #list)
    for index = 1, math.min(#list, 10) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cff888888" .. tostring(list[index]) .. "|r")
    end
    if #list > 10 then
        DEFAULT_CHAT_FRAME:AddMessage("  |cff888888" .. L["... and %d more"]:format(#list - 10) .. "|r")
    end
end

local function ProfileCommand(rest)
    local verb, arg = rest:match("^(%S*)%s*(.-)%s*$")
    verb = (verb or ""):lower()

    if verb == "" or verb == "list" then
        return ListProfiles()

    elseif verb == "use" then
        local name, why = FP:SetProfile(arg)
        if not name then return FP:Warn("%s.", why) end
        return

    elseif verb == "new" then
        local name, why = FP:CreateProfile(arg)
        if not name then return FP:Warn("%s.", why) end
        return FP:Print("Profile %s created. |cff888888/fplus profile use %s|r to switch to it.",
            name, name)

    elseif verb == "copy" then
        -- Copies the *active* profile: copying some other pair of profiles is
        -- a thing nobody has wanted yet, and it would need two names on one
        -- command line with no way to tell where the first one ends.
        local name, why = FP:CreateProfile(arg, FP.profileName)
        if not name then return FP:Warn("%s.", why) end
        return FP:Print("Profile %s created as a copy of %s.", name, FP.profileName)

    elseif verb == "rename" then
        local from = FP.profileName
        local name, why = FP:RenameProfile(from, arg)
        if not name then return FP:Warn("%s.", why) end
        return FP:Print("Profile %s is now called %s.", from, name)

    elseif verb == "reset" then
        local target = (arg ~= "" and arg) or FP.profileName
        local name, why = FP:ResetProfile(target)
        if not name then return FP:Warn("%s.", why) end
        return FP:Print("Profile %s is back to its defaults.", name)

    elseif verb == "delete" then
        local name, why = FP:DeleteProfile(arg)
        if not name then return FP:Warn("%s.", why) end
        return FP:Print("Profile %s deleted.", name)

    elseif verb == "export" then
        local target = (arg ~= "" and arg) or FP.profileName
        local text, why = FP:ExportProfile(target)
        if not text then return FP:Warn("%s.", why) end
        -- No chat confirmation. The window is the answer to the command, and
        -- the line that used to say so was what hid the window's absence.
        return FP:TextWindow(L["Export profile"],
            L["%s, %d characters"]:format(target, #text), text)

    elseif verb == "import" then
        FP:TextWindow(L["Import profile"],
            L["Paste a string, then press Import"], "",
            function(text)
                local name, skipped, total = FP:ImportProfile(text)
                if not name then
                    -- On failure the second return is the reason, not a list.
                    return FP:Warn(L["Import failed: %s"], tostring(skipped))
                end
                if FP.textWindow then FP.textWindow:Hide() end
                -- An import adds a profile to the one there always is, so
                -- the count is two or more and needs no singular.
                FP:Print("Imported as |cffffffff%s|r, %d profiles now. "
                    .. "|cff888888/fplus profile use %s|r to switch to it.",
                    name, total or 0, name)
                Skipped(skipped)
            end, L["Import"])
        return
    end

    FP:Warn("unknown profile command: %s", verb)
    FP:Print("Try: list, use, new, copy, rename, reset, delete, export, import.")
end

-- Where the description starts, counted in letters. The chat font is not
-- monospaced, so this lines the column up roughly rather than exactly.
local USAGE_COLUMN = 23

local function Usage()
    FP:Print("Commands:")
    local lines = {
        { "/fplus",                 "settings window" },
        { "/fplus list",            "modules as a text list" },
        { "/fplus on <module>",     "enable" },
        { "/fplus off <module>",    "disable" },
        { "/fplus <module>",        "toggle" },
        { "/fplus profile",         "list profiles, active one marked" },
        { "/fplus profile use|new|copy|rename <name>" },
        { "/fplus profile reset|delete [<name>]" },
        { "/fplus profile export|import" },
        { "/fplus diag",            "collect the API report again" },
        { "/fplus diag print",      "print a summary to chat" },
        { "/fplus probe",           "what can be read about the unit you are on" },
        { "/fplus probe forget",    "throw those readings away" },
        { "/fplus gossip",          "dump the open gossip window" },
        { "/fplus gossip forget",   "throw those dumps away" },
        { "/fplus gossip seen",     "services it met and left alone" },
        { "/fplus gossip unlearn",  "forget that list" },
        { "/fplus test <module>",   "run that module's self-test" },
        { "/fplus discover",        "enumerate the UI structure again" },
        { "/fplus buffs verify",    "check the buff tables against this client" },
        { "/fplus buffs weapon",    "why the weapon imbues are doing nothing" },
        { "/fplus buffs tracking",  "what this build says about minimap tracking" },
        { "/fplus buffs range",     "what the range check reads for each group member" },
        { "/fplus buffs camp",      "what Camp Benefits lists and where each ticked bonus stands" },
        { "/fplus tooltip node",    "what the client says about the object under the cursor" },
        { "/fplus tooltip ilvl",    "the item levels the client gives for you and your target" },
        { "/fplus chat edges",      "where the main chat window is held and what moved it since the login" },
        { "/fplus reagents",        "the reagents and poison recipes this character sees" },
        { "/fplus reagents as <class> [level]", "act as another class until reload, for testing; as off to stop" },
        { "/fplus reagents have <poison or id> <n>", "act as if the bags held that many until reload; have off to stop" },
        { "/fplus reagents economy on|off|auto", "act as if Reagent Economy were active or not until reload" },
        { "/fplus cooldowns",       "what the client says about the cooldowns the info bar keeps" },
        { "/fplus quests",          "what the quest modules decided in this conversation and before" },
        { "/fplus cooldowns unlearn <line>", "act as if this character did not have that cooldown until reload; unlearn off to stop" },
        { "/fplus cons",            "place the consumable warnings on screen" },
        { "/fplus cons status",     "why a consumable warning is or is not there" },
        { "/fplus spells <text>",   "find a spell id on this build, case sensitive" },
        { "/fplus id <link>",       "shift click something in: what id is behind it" },
        { "/fplus sell",            "sell gray items now" },
        { "/fplus selltest",        "self-test of the vendor module" },
        { "/fplus reload",          "/reload" },
    }
    -- The chat probe's own commands only while it measures: they go with it,
    -- AGENTS.md step 7, and one of them overwrites the clipboard. English like
    -- everything the probes say, since only the owner ever sees them.
    local diag = FP:GetModule("Diagnostics")
    if diag and diag.collecting then
        table.insert(lines, 13, { "/fplus probe chat", "what the chat probe has gathered" })
        table.insert(lines, 14, { "/fplus probe links", "how this client treats a link of ours" })
        table.insert(lines, 15, { "/fplus probe copy", "whether an addon may copy (overwrites the clipboard)" })
    end
    if FP.ShieldProbe and FP.ShieldProbe.collecting then
        table.insert(lines, 13, { "/fplus probe shield [water]", "Lightning or Water Shield charges against the hits" })
    end
    for i = 1, #lines do
        local command, what = lines[i][1], lines[i][2]
        if what then
            command = command .. string.rep(" ", math.max(1, USAGE_COLUMN - #command)) .. what
        end
        DEFAULT_CHAT_FRAME:AddMessage("  |cff888888" .. command .. "|r")
    end
end

-- Resolve module names case-insensitively, so "/fplus chat" is enough.
local function Resolve(input)
    if not input or input == "" then return nil end
    local lower = input:lower()
    for _, name in ipairs(FP.order) do
        if name:lower() == lower then return name end
    end
    return nil
end

local function Missing(name)
    return FP:Warn("module %s is missing.", name)
end

SLASH_FOREVERPLUS1 = "/fplus"
SLASH_FOREVERPLUS2 = "/foreverplus"

SlashCmdList.FOREVERPLUS = function(msg)
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "menu" then
        return FP:ToggleSettings()

    elseif cmd == "list" then
        return ListModules()

    elseif cmd == "help" or cmd == "?" then
        return Usage()

    elseif cmd == "reload" then
        return ReloadUI()

    elseif cmd == "profile" or cmd == "profiles" then
        return ProfileCommand(rest)

    elseif cmd == "sell" or cmd == "selltest" then
        local sell = FP:GetModule("AutoSellGray")
        if not sell then return Missing("AutoSellGray") end
        if cmd == "selltest" then return sell:SelfTest() end
        return sell:Run(true)

    elseif cmd == "repair" or cmd == "repairtest" then
        local repair = FP:GetModule("AutoRepair")
        if not repair then return Missing("AutoRepair") end
        if cmd == "repairtest" then return repair:SelfTest() end
        return repair:Run(true)

    elseif cmd == "buffs" then
        local buffs = FP:GetModule("BuffExpiry")
        if not buffs then return Missing("BuffExpiry") end
        local what = rest:lower()
        if what == "status" then return buffs:Status() end
        if what == "weapon" then return buffs:WeaponStatus() end
        if what == "verify" then return buffs:VerifyTables() end
        if what == "tracking" then return buffs:TrackingStatus() end
        if what == "range" then return buffs:RangeStatus() end
        if what == "camp" then return buffs:CampStatus() end
        return buffs:TogglePreview()

    -- Only with "node" after it: "/fplus tooltip" alone stays the module's
    -- toggle, which the branch at the end has always answered.
    elseif cmd == "tooltip" and rest:lower() == "node" then
        local tip = FP:GetModule("Tooltip")
        if not tip then return Missing("Tooltip") end
        return tip:NodeStatus()

    elseif cmd == "tooltip" and rest:lower() == "ilvl" then
        local tip = FP:GetModule("Tooltip")
        if not tip then return Missing("Tooltip") end
        return tip:ItemLevelStatus()

    -- Only with "edges" after it, like the tooltip's: "/fplus chat" alone
    -- stays the module's toggle. S5 of the 1.0.2 brief, the main chat
    -- window off the edge after a logout.
    elseif cmd == "chat" and rest:lower() == "edges" then
        local chat = FP:GetModule("Chat")
        if not chat then return Missing("Chat") end
        return chat:EdgeStatus()

    -- What the guard of the two quest modules saw and decided, CF8 of
    -- 2026-10-18: for a look at a repeatable quest, since nobody had measured
    -- where one conversation with a quest giver ends and the next begins.
    elseif cmd == "quests" then
        local guard = FP:QuestGuard()
        FP:Print("Quest guard: %s, NPC %s, conversation since %s, gap %ss.",
            guard.open and "a window is open" or "every window closed",
            tostring(guard.npc), tostring(guard.started), tostring(guard.gap))
        local function List(set)
            local out = {}
            for id in pairs(set) do out[#out + 1] = tostring(id) end
            table.sort(out)
            return #out > 0 and table.concat(out, ", ") or "none"
        end
        DEFAULT_CHAT_FRAME:AddMessage("  accepted: " .. List(guard.accepted))
        DEFAULT_CHAT_FRAME:AddMessage("  handed in: " .. List(guard.turnedIn))
        DEFAULT_CHAT_FRAME:AddMessage("  left to you: " .. List(guard.held))
        for _, line in ipairs(guard.log or {}) do
            DEFAULT_CHAT_FRAME:AddMessage("  |cff888888" .. line .. "|r")
        end
        return

    elseif cmd == "cooldowns" then
        local bar = FP:GetModule("InfoBar")
        if not bar then return Missing("InfoBar") end
        local what, arg = rest:match("^(%S*)%s*(.-)$")
        if (what or ""):lower() == "unlearn" then return bar:CooldownPretend(arg) end
        return bar:CooldownStatus()

    -- With "as", the module acts as another class until the next reload, so
    -- the column can be tried without a character of every class, the
    -- owner's request of 2026-10-09. Alone, it says what the module sees.
    elseif cmd == "reagents" then
        local reagents = FP:GetModule("Reagents")
        if not reagents then return Missing("Reagents") end
        local what, arg = rest:match("^(%S*)%s*(.-)$")
        if (what or ""):lower() == "as" then return reagents:Simulate(arg) end
        if (what or ""):lower() == "have" then return reagents:Pretend(arg) end
        if (what or ""):lower() == "economy" then return reagents:EconomyTest(arg) end
        return reagents:Status()

    elseif cmd == "cons" or cmd == "consumables" then
        local cons = FP:GetModule("Consumables")
        if not cons then return Missing("Consumables") end
        if rest:lower() == "status" then return cons:Status() end
        return cons:TogglePreview()

    elseif cmd == "discover" then
        local diag = FP:GetModule("Diagnostics")
        if not diag then return Missing("Diagnostics") end
        local d = diag:Discover()
        -- l10n: english, like everything the commands that measure say
        return FP:Print("UI structure enumerated (%d Edit Mode systems). Written to SavedVariables on /reload.",
            d.editMode and #d.editMode.systems or 0)

    elseif cmd == "diag" then
        local diag = FP:GetModule("Diagnostics")
        if not diag then return Missing("Diagnostics") end
        local what = rest:lower()
        if what == "print" then return diag:Report() end
        if what == "forget" then
            diag:Forget()
            -- l10n: english
            return FP:Print("Diagnostics report removed from the saved settings.")
        end

        diag:Discover()
        diag:Collect()
        -- Asking for it explicitly is what puts it in the file. A login
        -- collects it into memory and leaves the saved settings alone.
        diag:Persist()
        -- l10n: english
        return FP:Print("API report refreshed and stored. It is written to disk "
            .. "on the next /reload. |cff888888/fplus diag forget|r takes it out again.")

    elseif cmd == "id" then
        local diag = FP:GetModule("Diagnostics")
        if not diag then return Missing("Diagnostics") end
        return diag:Identify(rest)

    elseif cmd == "probe" then
        -- Phase 5's unit probe. Its own command for the same reason gossip has
        -- one: it reports on something that only exists while somebody is
        -- standing in front of it, which is never true at login.
        local diag = FP:GetModule("Diagnostics")
        if not diag then return Missing("Diagnostics") end
        local what, arg = rest:lower():match("^(%S*)%s*(.-)$")
        if what == "forget" then
            local gone = diag:ForgetProbe()
            -- l10n: english
            return FP:Print("%d recorded unit picture%s cleared, and the chat "
                .. "probe with them.", gone, gone == 1 and "" or "s")
        end
        -- Phase 6's chat probe. The last three are typed on purpose: one
        -- overwrites the clipboard and one runs the client's link code.
        if what == "chat"   then return diag:ChatProbeReport() end
        if what == "copy"   then return diag:ChatProbeCopy() end
        if what == "copied" then return diag:ChatProbeCopied(arg) end
        if what == "links"  then return diag:ChatProbeLinks() end
        -- The Lightning Shield probe, in a file of its own.
        if what == "shield" and FP.ShieldProbe then return FP.ShieldProbe:Report(arg) end
        return diag:ProbeReport()

    elseif cmd == "spells" then
        -- Not folded into /fplus diag: that runs at login and reports on the
        -- client, this answers a question somebody asks while writing a table.
        local diag = FP:GetModule("Diagnostics")
        if not diag then return Missing("Diagnostics") end
        return diag:Spells(rest)

    elseif cmd == "gossip" then
        -- Deliberately its own command rather than part of /fplus diag: it
        -- only says anything while an NPC is talking, and the report is
        -- collected at login when nobody is.
        local what = rest:lower()

        -- "seen" and "unlearn" belong to GossipAuto rather than to the probe.
        -- One is the raw window as the client describes it, the other is the
        -- list of services the module met and deliberately did not click.
        if what == "seen" or what == "unlearn" then
            local auto = FP:GetModule("GossipAuto")
            if not auto then return Missing("GossipAuto") end
            if what == "seen" then return auto:Seen() end
            local gone = auto:ForgetSeen()
            -- l10n: english
            return FP:Print("%d remembered gossip service%s cleared.",
                gone, gone == 1 and "" or "s")
        end

        local diag = FP:GetModule("Diagnostics")
        if not diag then return Missing("Diagnostics") end
        if what == "forget" then
            local gone = diag:ForgetGossip()
            -- l10n: english
            return FP:Print("%d stored gossip dump%s removed.",
                gone, gone == 1 and "" or "s")
        end
        return diag:Gossip()

    elseif cmd == "test" then
        -- One command for every module that has a self-test, rather than a new
        -- verb per module: selltest and repairtest predate it and still work.
        -- Phase 6.4 wants a /fplus check that runs all of them, and this is
        -- the half of it that already has a use.
        local name = Resolve(rest)
        if not name then return FP:Warn(L["Unknown module: %s"], rest) end
        local mod = FP:GetModule(name)
        if type(mod.SelfTest) ~= "function" then
            -- l10n: english, like the self-tests themselves
            return FP:Print("%s has no self-test.", name)
        end
        return FP:Safe(name .. ":SelfTest", mod.SelfTest, mod)

    elseif cmd == "on" or cmd == "off" then
        local name = Resolve(rest)
        if not name then return FP:Warn(L["Unknown module: %s"], rest) end
        if cmd == "on" then FP:EnableModule(name) else FP:DisableModule(name) end
        return ReportState(name)

    else
        local name = Resolve(cmd)
        if name then
            FP:ToggleModule(name)
            return ReportState(name)
        end
        FP:Warn("unknown command: %s", cmd)
        return Usage()
    end
end
