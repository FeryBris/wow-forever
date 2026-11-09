-- Measures what this client actually offers and stores the result in the
-- SavedVariables. Build 1.60.1 is Vanilla content on a modern engine -- which
-- parts of that API really exist is something we measure, not guess.
--
-- Collect() checks a list of names. Discover() goes the other way and lets the
-- client name its own frames, which is the more reliable of the two.

local ADDON, FP = ...
local L = FP.L

-- Phase 5's probe, the one that watches units go past. Everything else in this
-- file answers at login or on a typed command; this one records by itself, so
-- it is the part that must not reach a stranger's client.
--
-- The name is deliberate and not a style choice: step 7 of *Releasing* greps
-- for COLLECTING rather than reading a list, because the list was one item long
-- until somebody added a second and did not come back to it.
local COLLECTING = false   -- set true while measuring, see AGENTS.md step 7

local M = FP:RegisterModule("Diagnostics", {
    title   = L["Diagnostics"],
    default = true,
    desc    = L["Measures what this client's API offers. Use it to diagnose "
           .. "problems: the report lists what exists and what does not, for "
           .. "whoever fixes the addon."],
    group   = "tools",
    order   = 10,
    options = {
        { key = "persist", type = "toggle", default = false,
          label = L["Keep the report in the saved settings"],
          desc  = L["Saves the report, about nine hundred lines, in your "
               .. "saved settings. /fplus diag print reads the current one "
               .. "without saving it."] },
    },
})

-- ---------------------------------------------------------------------------
-- Part 1: probe a list of names.
-- Nothing here is called; these are pure existence checks, so a missing name
-- produces a "missing" entry instead of an error.
-- ---------------------------------------------------------------------------

-- Resolve paths like "C_UnitAuras.GetAuraDataByIndex" step by step.
local function Resolve(path)
    local node = _G
    for part in path:gmatch("[^.]+") do
        if type(node) ~= "table" then return nil end
        node = rawget(node, part)
        if node == nil then return nil end
    end
    return node
end

-- Grouped by the UI area each name matters for.
local PROBES = {
    ["Core"] = {
        "C_AddOns", "C_Timer", "C_CVar", "C_Container", "C_Item", "C_Spell",
        "hooksecurefunc", "issecurevariable", "InCombatLockdown", "CreateFrame",
    },
    ["EditMode"] = {
        "EditModeManagerFrame", "EditModeManagerFrameMixin", "EditModeSystemMixin",
        "C_EditMode", "EditModeSystemSettingDisplayInfoManager",
    },
    ["UnitFrames"] = {
        "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "TargetFrameToT",
        "PartyFrame", "CompactRaidFrameContainer", "CompactPartyFrame",
        "PlayerFrame_ToPlayerArt", "UnitFrameHealthBar_Update",
    },
    ["ActionBars"] = {
        "MainActionBar", "MainActionBarButtonContainer1", "MainMenuBar",
        "ActionButton1", "MultiBarBottomLeft", "MultiBarBottomRight",
        "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7",
        "StatusTrackingBarManager", "ActionBarActionEventsFrame",
    },
    ["Minimap"] = {
        "Minimap", "MinimapCluster", "MinimapBackdrop", "MinimapZoomIn",
        "MiniMapTracking", "MinimapNorthTag", "C_Minimap", "GameTimeFrame",
    },
    ["Tooltip"] = {
        "GameTooltip", "TooltipDataProcessor", "C_TooltipInfo",
        "GameTooltip_SetDefaultAnchor", "SharedTooltip_SetBackdropStyle",
    },
    ["Chat"] = {
        "ChatFrame1", "ChatFrame1EditBox", "NUM_CHAT_WINDOWS", "C_ChatInfo",
        "FCF_OpenNewWindow", "ChatFrame_AddMessageEventFilter",
    },
    ["Auras"] = {
        "BuffFrame", "DebuffFrame", "C_UnitAuras",
        "C_UnitAuras.GetAuraDataByIndex", "UnitAura", "UnitBuff",
    },
    ["Bags"] = {
        "ContainerFrame1", "ContainerFrameCombinedBags",
        "C_Container.GetContainerNumSlots", "GetContainerNumSlots",
    },
    ["Merchant"] = {
        "MerchantFrame", "C_Container.UseContainerItem", "UseContainerItem",
        "C_Container.GetContainerItemInfo", "GetMerchantNumItems", "GetMoney",
        "GetCoinTextureString", "C_CurrencyInfo.GetCoinTextureString",
        "NUM_BAG_SLOTS",
        "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems",
        "CanGuildBankRepair", "GetGuildBankWithdrawMoney",
    },
    ["StatusBars"] = {
        "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer", "StatusTrackingBarMixin",
        "ExpBarMixin", "ReputationStatusBarMixin",
    },
    ["Errors"] = {
        "UIErrorsFrame", "ERR_OUT_OF_MANA", "ERR_SPELL_COOLDOWN",
        "ERR_OUT_OF_RANGE", "ERR_BADATTACKFACING", "SPELL_FAILED_BAD_TARGETS",
    },
    -- Phase 1 needs a stable per-character key for the profile pointer.
    -- GetNormalizedRealmName is the one in doubt: it is a later addition than
    -- GetRealmName, and connected realms are what it exists for.
    ["Profiles"] = {
        "UnitName", "UnitFullName", "UnitGUID", "UnitClass", "UnitRace",
        "UnitFactionGroup", "GetRealmName", "GetNormalizedRealmName",
    },
    -- The theme layer scales the client's own font objects instead of naming
    -- font files, which the locale rule forbids. CreateFont is how a derived
    -- font comes into being; the methods it needs are in METHODS below.
    ["Theme"] = {
        "CreateFont", "GameFontNormal", "GameFontNormalLarge",
        "GameFontHighlightSmall", "GameFontDisableSmall", "NumberFontNormal",
        "CHAT_FONT_HEIGHTS",
    },
    -- Build 69913 can withhold data from tainted code -- every addon, always --
    -- and raises rather than returning nil. Auras were where it surfaced; the
    -- namespace covers far more than that.
    ["Secrets"] = {
        "C_Secrets",
        "C_Secrets.ShouldUnitAuraIndexBeSecret",
        "C_Secrets.ShouldUnitAuraInstanceBeSecret",
        "C_Secrets.ShouldSpellAuraBeSecret",
        "C_Secrets.ShouldUnitPowerBeSecret",
        "C_Secrets.ShouldUnitHealthMaxBeSecret",
        "C_Secrets.ShouldUnitSpellCastingBeSecret",
        "C_Secrets.ShouldUnitThreatStateBeSecret",
        "C_Secrets.GetSpellAuraSecrecy",
        "C_Secrets.CanCompareUnitTokens",
        "issecretvalue", "issecrettable", "canaccesssecrets", "scrubsecretvalues",
    },
    -- Weapon imbues and poisons are not auras: they live on the weapon and are
    -- read with a call of their own. A Shaman reported them not working at all
    -- on 2026-09-20, and whether this function even exists here had never been
    -- asked, which is how a feature comes to fail for three possible reasons
    -- at once.
    ["WeaponEnchants"] = {
        "C_Item.GetWeaponEnchantInfo", "C_PaperDollInfo.GetTemporaryEnchantmentInfo",
        "GetWeaponEnchantInfo", "GetInventoryItemLink", "GetInventoryItemID",
        "C_Item.GetItemLink", "INVSLOT_MAINHAND", "INVSLOT_OFFHAND",
        "GetInventoryItemTexture", "C_Item.GetItemInfoInstant",
    },

    -- Phase 1.5 asks whether the player has *learned* a better rank of a buff,
    -- which is not the same question as whether they have reached its level.
    -- If none of these answer, that part of the block is dropped rather than
    -- guessed at from the character level.
    ["Spellbook"] = {
        "IsSpellKnown", "IsPlayerSpell", "GetSpellInfo",
        "C_Spell", "C_Spell.GetSpellInfo", "C_Spell.IsSpellKnown",
        "C_SpellBook", "C_SpellBook.GetSpellBookItemInfo",
        "C_SpellBook.GetNumSpellBookSkillLines", "C_SpellBook.HasPetSpells",
        "GetSpellBookItemInfo", "GetNumSpellTabs",
    },
    ["Map/Quests"] = {
        "C_Map", "C_Map.GetBestMapForUnit", "C_QuestLog", "QuestLogFrame",
        "WorldMapFrame", "C_SuperTrack",
    },

    -- Phase 2 measures before it builds, by the owner's decision. Each group
    -- below carries exactly one feature, and a feature whose names come back
    -- missing is dropped rather than worked around. See ROADMAP.md phase 2.

    -- Fast loot. It only accelerates what the client already decided, so the
    -- CVar below matters as much as the functions: without a readable
    -- autoLootDefault there is nothing to follow and the feature is pointless.
    ["Loot"] = {
        "LootSlot", "LootSlotHasItem", "GetNumLootItems", "GetLootSlotInfo",
        "GetLootSlotLink", "GetLootSlotType", "CloseLoot", "LootFrame",
        "C_Loot", "LOOT_SLOT_ITEM",
        -- Fast loot follows autoLootDefault rather than setting it, with one
        -- exception on request: a button that turns it on once.
        "C_CVar.SetCVar", "SetCVar", "C_CVar.GetCVarBool", "GetCVarBool",
    },

    -- Greed on greens. RollOnLoot is the one in doubt: the name changed more
    -- than once over the years and the modern client hides the roll behind
    -- GroupLootFrame.
    ["LootRolls"] = {
        "GetLootRollItemInfo", "GetLootRollItemLink", "RollOnLoot",
        "GetLootRollTimeLeft", "ConfirmLootRoll", "GroupLootFrame1",
        "GroupLootContainer", "GroupLootHistoryFrame",
    },

    -- Declining duels and releasing in a battleground. The battleground half
    -- needs two answers rather than one: are we dead, and are we somewhere
    -- releasing is the right move.
    ["Interruptions"] = {
        "CancelDuel", "AcceptDuel", "StaticPopup_Hide", "StaticPopup_Visible",
        "RepopMe", "UnitIsDeadOrGhost", "IsInInstance", "GetBattlefieldStatus",
        "C_PvP", "C_PvP.IsBattleground", "C_PvP.IsPvPMap", "C_DeathInfo",
        "HasSoulstone", "GetReleaseTimeRemaining", "C_Map.GetBestMapForUnit",
        -- Whether this build has battlegrounds at all. The battleground half
        -- of Interruptions is pointless if it does not, and the owner's report
        -- that battlemasters do nothing here is a reason to ask rather than an
        -- answer on its own.
        "GetNumBattlegroundTypes", "GetBattlegroundInfo", "C_PvP.GetActiveMatchState",
    },

    -- The gossip window. Existence is the small half of this question: what
    -- GetOptions *returns* is what the feature stands on, and only an NPC can
    -- answer that. See /fplus gossip further down this file.
    ["Gossip"] = {
        "C_GossipInfo", "C_GossipInfo.GetOptions", "C_GossipInfo.SelectOption",
        "C_GossipInfo.GetNumOptions", "C_GossipInfo.GetNumActiveQuests",
        "C_GossipInfo.GetNumAvailableQuests", "C_GossipInfo.GetActiveQuests",
        "C_GossipInfo.GetAvailableQuests", "C_GossipInfo.GetText",
        "C_GossipInfo.CloseGossip", "GossipFrame",
        "GetGossipOptions", "SelectGossipOption", "GetNumGossipOptions",
    },

    -- The vendor value beside each quest reward. The buttons are Blizzard's
    -- and we only hang a font string on them, so their names have to be right:
    -- the modern build renames them and the old names are probed alongside.
    ["QuestRewards"] = {
        "GetNumQuestChoices", "GetQuestItemLink", "GetQuestItemInfo",
        "GetQuestReward", "QuestInfoFrame", "QuestInfoRewardsFrame",
        "QuestFrameRewardPanel", "QuestInfoItem1",
        "QuestInfoRewardsFrameQuestInfoItem1", "QuestInfoRewardsFrameQuestInfoItem2",
    },
}

-- CVars that matter for UI work.
local CVARS = {
    "useUiScale", "uiScale", "combinedBags", "showPartyPets",
    "nameplateShowAll", "cameraDistanceMaxZoomFactor", "chatStyle",
    "floatingCombatTextCombatDamage", "lockActionBars", "alwaysShowActionBars",
    -- Experience bar text, and its neighbors in case the name differs here.
    "xpBarText", "statusText", "statusTextPercentage", "showStatusText",
    -- Phase 2. autoLootDefault is what fast loot follows rather than replaces,
    -- and autoQuestWatch decides whether tracking a quest on accept is native
    -- here, in which case that idea stays cut.
    "autoLootDefault", "autoLootRate", "autoQuestWatch", "autoQuestProgress",
}

-- Methods sit on an object's metatable, where Resolve() deliberately cannot
-- reach them: it walks with rawget so that probing never triggers a metamethod.
-- These are looked up the ordinary way instead.
local METHODS = {
    GameFontNormal = {
        "GetFont", "SetFont", "CopyFontObject", "GetTextColor", "SetTextColor",
    },
}

-- No template probe here, and that is a finding rather than an omission.
--
-- A Blizzard template is XML, not a global, so the only way to test one is to
-- build a frame with it -- and building one runs Blizzard's own OnLoad inside
-- our tainted execution, which spreads taint into the shared tables those
-- handlers touch. UIDropDownMenuTemplate is the worst of them and the most
-- famous taint vector in the game, so this is a rule worth keeping even though
-- nothing has yet been traced to it -- the secret-aura errors it was first
-- blamed for turned out to be C_Secrets and not taint at all.
--
-- The answer it gave on 2026-09-19 is kept in ROADMAP.md: BackdropTemplate,
-- UIPanelButtonTemplate, UICheckButtonTemplate, InputBoxTemplate,
-- UIDropDownMenuTemplate, OptionsSliderTemplate and UIPanelScrollFrameTemplate
-- all exist on build 69913. We still hand-build every widget, so the question
-- was never load-bearing -- and it is now answered once, at a price not worth
-- paying twice.

--- Collects the report into ForeverPlusDB.diagnostics.
--
-- FP.global, not FP.db: a measurement of the client is not a setting, so it
-- belongs beside the profiles rather than inside one. Copying an API report
-- from one character to another would be meaningless.
function M:Collect()
    local r = {
        stamp  = date("%Y-%m-%d %H:%M:%S"),
        locale = GetLocale(),
        found = {}, missing = {}, cvars = {}, addons = {},
    }

    local version, build, buildDate, toc = GetBuildInfo()
    r.build = { version = version, build = build, date = buildDate, toc = toc }

    for group, names in pairs(PROBES) do
        r.found[group]   = {}
        r.missing[group] = {}
        for _, path in ipairs(names) do
            local obj = Resolve(path)
            if obj == nil then
                table.insert(r.missing[group], path)
            else
                local kind = type(obj)
                -- For frames the concrete widget type is the useful detail.
                if kind == "table" and type(obj.GetObjectType) == "function" then
                    local ok, objType = pcall(obj.GetObjectType, obj)
                    if ok then kind = "Frame:" .. tostring(objType) end
                end
                r.found[group][path] = kind
            end
        end
        table.sort(r.missing[group])
    end

    -- Screen metrics: what the virtual coordinate space actually looks like
    -- here. Panel sizes are only resolution-safe relative to these numbers.
    r.screen = {}
    if UIParent then
        r.screen.uiParentWidth   = UIParent:GetWidth()
        r.screen.uiParentHeight  = UIParent:GetHeight()
        r.screen.effectiveScale  = UIParent:GetEffectiveScale()
    end
    if GetScreenWidth  then r.screen.screenWidth  = GetScreenWidth()  end
    if GetScreenHeight then r.screen.screenHeight = GetScreenHeight() end
    if GetPhysicalScreenSize then
        local ok, physicalW, physicalH = pcall(GetPhysicalScreenSize)
        if ok then
            r.screen.physicalWidth, r.screen.physicalHeight = physicalW, physicalH
        end
    end

    r.methods = {}
    for objectName, names in pairs(METHODS) do
        local object = Resolve(objectName)
        local out = {}
        for _, method in ipairs(names) do
            local ok, value = pcall(function() return object and object[method] end)
            out[method] = (ok and type(value) == "function") or false
        end
        r.methods[objectName] = out
    end

    for _, name in ipairs(CVARS) do
        local ok, value = pcall(GetCVar, name)
        r.cvars[name] = ok and value or nil
    end

    -- Which addons are running alongside -- explains conflicts later on.
    local api = C_AddOns or _G
    local count = (api.GetNumAddOns and api.GetNumAddOns()) or 0
    for i = 1, count do
        local name = api.GetAddOnInfo and api.GetAddOnInfo(i)
        local loaded = api.IsAddOnLoaded and api.IsAddOnLoaded(i)
        if name and loaded then table.insert(r.addons, name) end
    end
    table.sort(r.addons)

    self.report = r
    -- Kept in memory, not in the saved file, unless somebody asks for it. A
    -- probe report is nine hundred lines of what this client offers -- useful
    -- while measuring, and no business of a player's saved settings, which it
    -- was dwarfing by a factor of ten. /fplus diag writes it out deliberately.
    if self.db and self.db.persist then FP.global.diagnostics = r end
    return r
end

--- Prints a summary to chat. The detail lives in the SavedVariables file.
function M:Report()
    local r = self.report or FP.global.diagnostics
    if not r then return FP:Warn("no report yet: run /fplus diag") end

    FP:Print("Client %s (build %s), TOC %s, locale %s",
        tostring(r.build.version), tostring(r.build.build),
        tostring(r.build.toc), tostring(r.locale))

    for group in pairs(PROBES) do
        local found, missing = 0, 0
        for _ in pairs(r.found[group] or {}) do found = found + 1 end
        for _ in ipairs(r.missing[group] or {}) do missing = missing + 1 end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffffff%-14s|r |cff44ff44%d present|r / |cffff5555%d missing|r%s",
            group, found, missing,
            missing > 0 and ("  |cff888888" .. table.concat(r.missing[group], ", ") .. "|r") or ""
        ))
    end
    -- Two probes that do not fit the found/missing shape above. Both are
    -- skipped rather than guessed at when an older report is being read: an
    -- empty table and an absent one would otherwise both print "all present".
    local function Line(label, absent)
        table.sort(absent)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffffff%-14s|r %s", label,
            #absent == 0 and "|cff44ff44all present|r"
                or ("|cffff5555" .. table.concat(absent, ", ") .. " missing|r")))
    end

    for objectName, methods in pairs(r.methods or {}) do
        local absent = {}
        for method, present in pairs(methods) do
            if not present then absent[#absent + 1] = method end
        end
        Line(objectName .. " methods", absent)
    end

    -- The CVars in chat as well, not only in the file. A measurement round is
    -- answered by reading this summary, and a value that exists only on disk
    -- is a value nobody actually looks at: the file is a session behind and
    -- has to be dug out of an account folder whose name changes.
    FP:Print("CVars:")
    local cvars = {}
    for _, name in ipairs(CVARS) do
        local value = (r.cvars or {})[name]
        cvars[#cvars + 1] = string.format("%s=%s", name,
            value == nil and "|cff888888absent|r" or tostring(value))
    end
    for i = 1, #cvars, 3 do
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" ..
            table.concat(cvars, "   ", i, math.min(i + 2, #cvars)) .. "|r")
    end

    -- Worth spelling out: this is the live in-memory report. The file on disk
    -- is always one session behind, because the client writes SavedVariables
    -- *during* a reload, using the state from before it.
    FP:Print("Live data. The file on disk still holds the previous session's report until the next /reload or /logout.")
end

-- ---------------------------------------------------------------------------
-- Part 2: enumerate instead of guessing.
--
-- Collect() only finds names somebody thought of in advance. Discover() lets
-- the client name its own structure: which frame is the parent of
-- ActionButton1? Which systems does Edit Mode manage?
-- ---------------------------------------------------------------------------

local function FrameName(f)
    if not f then return nil end
    local name = f.GetName and f:GetName()
    if name then return name end
    local ok, objType = pcall(f.GetObjectType, f)
    return "<anonymous:" .. (ok and tostring(objType) or "?") .. ">"
end

-- Walk up the parent chain. Reveals the real container.
local function Lineage(name, maxDepth)
    local f = _G[name]
    if not f or not f.GetParent then return nil end
    local chain, node = {}, f
    for _ = 1, (maxDepth or 8) do
        if not node then break end
        chain[#chain + 1] = FrameName(node)
        node = node.GetParent and node:GetParent() or nil
    end
    return table.concat(chain, "  <  ")
end

local function NamedChildren(frame)
    local out = {}
    if not frame or not frame.GetChildren then return out end

    local ok, kids = pcall(function() return { frame:GetChildren() } end)
    if not ok then return out end

    for i = 1, #kids do
        local child = kids[i]
        -- Modern clients have "forbidden frames": on those, even GetName()
        -- raises an error. That is exactly what killed the first pass --
        -- UIParent has some among its children.
        local isForbidden = false
        if child.IsForbidden then
            local okF, forbidden = pcall(child.IsForbidden, child)
            isForbidden = okF and forbidden
        end
        if not isForbidden and child.GetName then
            local okN, name = pcall(child.GetName, child)
            if okN and name then out[#out + 1] = name end
        end
    end
    table.sort(out)
    return out
end

local function StringKeys(t)
    local out = {}
    if type(t) ~= "table" then return out end
    for k, v in pairs(t) do
        if type(k) == "string" then
            out[#out + 1] = (type(v) == "number") and (k .. "=" .. v) or k
        end
    end
    table.sort(out)
    return out
end

--- Enumerates the real UI structure into ForeverPlusDB.discovery.
--
-- Each section sets d.step first, and the table is in the DB from the start,
-- so a crash leaves its exact location in the SavedVariables instead of
-- leaving nothing behind at all.
function M:Discover()
    local d = { stamp = date("%Y-%m-%d %H:%M:%S"), step = "start" }
    self.discovery = d
    if M.db and M.db.persist then FP.global.discovery = d end

    -- 1. Where do the interesting frames actually live?
    d.step = "lineage"
    d.lineage = {}
    for _, name in ipairs({
        "ActionButton1", "MultiBarBottomLeft", "MultiBar5", "StatusTrackingBarManager",
        "PlayerFrame", "TargetFrame", "PartyFrame", "Minimap", "BuffFrame", "ChatFrame1",
        "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
    }) do
        d.lineage[name] = Lineage(name) or "<not present>"
    end

    -- 2. Named children of the containers we care about.
    d.step = "children"
    d.children = {}
    for _, name in ipairs({ "UIParent", "MinimapCluster", "MainActionBar", "PlayerFrame",
                            "BuffFrame", "StatusTrackingBarManager",
                            "MainStatusTrackingBarContainer" }) do
        local kids = NamedChildren(_G[name])
        if #kids > 0 then d.children[name] = kids end
    end

    -- 3. What does Edit Mode manage? That is the list we have to work with.
    d.step = "editMode"
    local manager = EditModeManagerFrame
    if manager then
        local systems = {}
        local list = rawget(manager, "registeredSystemFrames")
        if type(list) == "table" then
            for i = 1, #list do
                local sys = list[i]
                systems[#systems + 1] = string.format("%s  system=%s index=%s",
                    FrameName(sys), tostring(rawget(sys, "system")), tostring(rawget(sys, "systemIndex")))
            end
            table.sort(systems)
        else
            systems[1] = "registeredSystemFrames: " .. type(list)
        end
        d.editMode = { systems = systems, managerKeys = StringKeys(manager) }
    else
        d.editMode = { systems = { "EditModeManagerFrame is missing" } }
    end

    d.step = "enums"
    d.cEditMode = StringKeys(C_EditMode)
    d.enums = {}
    for _, name in ipairs({ "EditModeSystem", "EditModeActionBarSetting",
                            "EditModeUnitFrameSetting", "EditModeMinimapSetting" }) do
        local enum = Enum and rawget(Enum, name)
        if enum then d.enums[name] = StringKeys(enum) end
    end

    d.step = "done"
    return d
end

-- ---------------------------------------------------------------------------
-- Part 3: dump the open gossip window.
--
-- Part 1 can say whether C_GossipInfo.GetOptions exists. It cannot say what
-- that function returns while an NPC is actually talking, and the phase 2
-- gossip feature stands on one field of that answer: the option's *type*. A
-- plain gossip line can start an escort or pull a boss, a vendor line only
-- opens a window, and telling those apart is the entire feature. If the type
-- is not readable here, the feature is dropped rather than guessed at.
--
-- Retail replaced the old type string with an icon and a set of flags at some
-- point, and this build sits between the two worlds. So nothing is assumed:
-- every key of every option is printed, whatever it turns out to be.
-- ---------------------------------------------------------------------------

--- Turns any value from the client into something safe to print.
--
-- This client can hand back a value that is *secret*: it survives the read, it
-- survives tostring, and it raises on the first comparison. Printing one would
-- take the dump down at exactly the moment we least want that, so every value
-- is proved comparable before it is used. See FP:Truth in Core/Util.lua.
local function Describe(value)
    local ok, text = pcall(function()
        if type(value) == "string" then return '"' .. value .. '"' end
        return tostring(value)
    end)
    if not ok then return "|cffff5555<unreadable>|r" end
    if not pcall(function() return text == "" end) then return "|cffff5555<secret>|r" end
    return text
end

-- How many dumps to keep. They are small, but they sit in a player's saved
-- file next to the settings, and the diagnostics report was thrown out of that
-- file for being ten times the size of what it sat beside.
local MAX_DUMPS = 10

-- While a dump is running, every printed line is collected here as well.
local lines

-- Color escapes are for the chat window. In the file they are noise around
-- the only thing that matters, which is the text.
local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Say(fmt, ...)
    local text = string.format(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffffff" .. text .. "|r")
    -- Chat scrolls away and cannot be pasted back whole. The file can simply
    -- be read, which is the difference between a measurement that survives the
    -- session and one that has to be retyped.
    if lines then lines[#lines + 1] = Plain(text) end
end

--- Length of a list the client handed over, or nil when it will not say.
--
-- Not paranoia: taking the length of the one list UNIT_AURA carries raises on
-- this build. A field that exists and cannot be measured is not a field.
local function Count(list)
    local ok, n = pcall(function() return #list end)
    return ok and n or nil
end

--- Prints a list of tables the client returned, key by key.
local function DumpList(label, fn)
    if type(fn) ~= "function" then
        return Say("%-36s |cff888888absent|r", label)
    end

    local ok, list = pcall(fn)
    if not ok then return Say("%-36s |cffff5555raised|r", label) end
    if type(list) ~= "table" then
        return Say("%-36s %s", label, Describe(list))
    end

    local count = Count(list)
    if not count then
        return Say("%-36s |cffff5555length not readable|r", label)
    end
    Say("%-36s %d entr%s", label, count, count == 1 and "y" or "ies")

    for i = 1, count do
        local entry = list[i]
        if type(entry) ~= "table" then
            Say("    [%d] %s", i, Describe(entry))
        else
            local keys = {}
            local readable = pcall(function()
                for key in pairs(entry) do
                    if type(key) == "string" then keys[#keys + 1] = key end
                end
            end)
            if not readable then
                Say("    [%d] |cffff5555keys not readable|r", i)
            else
                table.sort(keys)
                Say("    [%d]", i)
                for _, key in ipairs(keys) do
                    Say("        %-24s %s", key, Describe(rawget(entry, key)))
                end
            end
        end
    end
end

--- Every known spell whose name contains `text`, with its id.
--
-- The question this answers comes up in every session that touches
-- `Data/Buffs.lua`: what id does this spell have **on this build**. It has
-- been answered by hand each time, and the header of that file records what
-- guessing cost once already, thirty four wrong ids inferred from neighbours.
--
-- **Case sensitive, deliberately.** The obvious way to match would lowercase
-- both sides, and `string.lower` is byte based in this Lua: it mangles
-- anything outside ASCII, which is exactly the rule the locale section forbids
-- breaking. Matching the client's own names against what the player just typed
-- needs no folding at all, and a missed match costs a retry rather than a
-- wrong id.
function M:Spells(text)
    if not text or text == "" then
        return FP:Warn("Usage: /fplus spells <part of a spell name>")
    end

    local found, route = {}, "none"

    -- The modern route first.
    local book = C_SpellBook
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        local okLines, lines = pcall(book.GetNumSpellBookSkillLines)
        for line = 1, (okLines and tonumber(lines) or 0) do
            local okLine, info = pcall(book.GetSpellBookSkillLineInfo, line)
            if okLine and type(info) == "table" then
                local from = (tonumber(info.itemIndexOffset) or 0) + 1
                local upto = from + (tonumber(info.numSpellBookItems) or 0) - 1
                for index = from, upto do
                    local okItem, item = pcall(book.GetSpellBookItemInfo, index, bank)
                    if okItem and type(item) == "table" and item.spellID then
                        found[#found + 1] = item.spellID
                        route = "C_SpellBook"
                    end
                end
            end
        end
    end

    -- The route that preceded it, for a build that kept the old one instead.
    if #found == 0 and _G.GetNumSpellTabs and _G.GetSpellBookItemInfo then
        for tab = 1, (select(2, pcall(GetNumSpellTabs)) or 0) do
            local okTab, _, _, offset, count = pcall(GetSpellTabInfo, tab)
            if okTab then
                for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
                    local okItem, _, id = pcall(GetSpellBookItemInfo, index, "spell")
                    if okItem and id then
                        found[#found + 1] = id
                        route = "GetSpellBookItemInfo"
                    end
                end
            end
        end
    end

    FP:Print("Spells matching \"%s\", read through %s:", text, route)

    local hits = 0
    for _, id in ipairs(found) do
        local name = FP:SpellName(id)
        if name and name:find(text, 1, true) then
            hits = hits + 1
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  |cffffffff%-8d|r %s", id, name))
        end
    end

    if hits == 0 then
        FP:Print("Nothing matched. The search is case sensitive, and it only "
            .. "sees spells this character has actually learned.")
    end
end

--- Prints the open gossip window exactly as the client describes it.
--
-- Run it twice: once at an NPC whose window is a single "Browse your wares"
-- line, and once at a quest giver. The first says whether the feature can be
-- built at all, the second says whether the guard that keeps it away from
-- quests can see what it needs to see.
function M:Gossip()
    FP:Print("Gossip window, raw:")

    lines = {}
    local g = C_GossipInfo
    if not g then FP:Warn("C_GossipInfo does not exist on this build.") end

    -- 1. Context, so a dump kept for later still says where it came from.
    for _, entry in ipairs({
        { "UnitName(\"npc\")",   function() return UnitName("npc") end },
        { "UnitExists(\"npc\")", function() return UnitExists("npc") end },
        { "GossipFrame shown",   function() return GossipFrame and GossipFrame:IsShown() end },
    }) do
        local ok, value = pcall(entry[2])
        Say("%-36s %s", entry[1], ok and Describe(value) or "|cffff5555raised|r")
    end

    -- 2. The counts, from both generations of the API. A build that answers on
    --    one route and not on the other is the interesting case, and it is the
    --    one we would otherwise have assumed away.
    for _, entry in ipairs({
        { "C_GossipInfo.GetNumOptions",         g and g.GetNumOptions },
        { "C_GossipInfo.GetNumActiveQuests",    g and g.GetNumActiveQuests },
        { "C_GossipInfo.GetNumAvailableQuests", g and g.GetNumAvailableQuests },
        { "GetNumGossipOptions",                _G.GetNumGossipOptions },
        { "GetNumGossipActiveQuests",           _G.GetNumGossipActiveQuests },
        { "GetNumGossipAvailableQuests",        _G.GetNumGossipAvailableQuests },
    }) do
        if type(entry[2]) == "function" then
            local ok, value = pcall(entry[2])
            Say("%-36s %s", entry[1], ok and Describe(value) or "|cffff5555raised|r")
        else
            Say("%-36s |cff888888absent|r", entry[1])
        end
    end

    -- 3. Every option and every quest, key by key, nothing filtered. A field
    --    that is not printed is a field nobody can reason about afterwards.
    DumpList("C_GossipInfo.GetOptions",           g and g.GetOptions)
    DumpList("C_GossipInfo.GetAvailableQuests",   g and g.GetAvailableQuests)
    DumpList("C_GossipInfo.GetActiveQuests",      g and g.GetActiveQuests)

    -- 4. The route that came before C_GossipInfo. It returned text and type as
    --    alternating values rather than in a table, so the type we need may
    --    still be reachable here even if the modern route has stopped carrying
    --    it. Worth knowing before the feature is written off.
    if type(_G.GetGossipOptions) == "function" then
        local ok, packed = pcall(function() return { GetGossipOptions() } end)
        if not ok then
            Say("%-36s |cffff5555raised|r", "GetGossipOptions")
        else
            Say("%-36s %d value(s)", "GetGossipOptions", #packed)
            for i = 1, #packed do Say("    [%d] %s", i, Describe(packed[i])) end
        end
    else
        Say("%-36s |cff888888absent|r", "GetGossipOptions")
    end

    -- 5. Which gossip enums this build carries. If the type has moved out of a
    --    string and into an enum, this is where its name turns up.
    local enums = {}
    pcall(function()
        for key in pairs(_G.Enum or {}) do
            if type(key) == "string" and key:find("Gossip") then
                enums[#enums + 1] = key
            end
        end
    end)
    table.sort(enums)
    Say("%-36s %s", "Enum entries naming gossip",
        #enums > 0 and table.concat(enums, ", ") or "|cff888888none|r")

    for _, name in ipairs(enums) do
        local values = {}
        pcall(function()
            for key, value in pairs(_G.Enum[name]) do
                values[#values + 1] = tostring(key) .. "=" .. tostring(value)
            end
        end)
        table.sort(values)
        Say("    %s: %s", name, table.concat(values, ", "))
    end

    -- Stored rather than only shown. Which NPC it was is worth more than the
    -- time, so it is read once here and kept beside the dump: three dumps in a
    -- row are otherwise impossible to tell apart afterwards.
    local okName, npc = pcall(UnitName, "npc")
    local store = FP.global.gossip
    if type(store) ~= "table" then
        store = {}
        FP.global.gossip = store
    end
    store[#store + 1] = {
        stamp = date("%Y-%m-%d %H:%M:%S"),
        npc   = (okName and type(npc) == "string") and npc or "<none>",
        lines = lines,
    }
    while #store > MAX_DUMPS do table.remove(store, 1) end
    lines = nil

    FP:Print("Kept as dump %d of %d. It reaches the file on the next /reload. "
        .. "|cff888888/fplus gossip forget|r clears them.", #store, MAX_DUMPS)
    FP:Print("Do this at a vendor whose window is a single line, and again at a "
        .. "quest giver. What matters is whether an option says which kind it is.")
end

--- Throws the stored dumps away again.
function M:ForgetGossip()
    local count = #(FP.global.gossip or {})
    FP.global.gossip = nil
    return count
end

-- ---------------------------------------------------------------------------
-- Part 4: what this client will say about a unit, and when.
--
-- Phase 5's measurement. Two questions at once, and phase 4 stands on the
-- second: what could a tooltip say about the people around you, and how much of
-- C_Secrets shuts in combat the way auras did.
--
-- It measures **behaviour**, not existence. The existence question is already
-- answered in the Secrets group above and is worthless on its own, because
-- ShouldUnitAuraIndexBeSecret exists here and reports everything as secret. The
-- only thing trusted is the read itself, and what comes back from it.
-- ---------------------------------------------------------------------------

-- How many distinct pictures to keep. Not how many passes: see Record.
local MAX_SAMPLES = 24

-- At most one recorded pass a second. Mouseover fires far faster than that
-- while the cursor crosses a crowd, and a probe that costs frames during the
-- fight it is measuring changes the thing it measures.
local SAMPLE_GAP = 1

--- Every return a call made, as text, with nothing compared along the way.
--
-- A call's *later* returns can be secret where the first was not, and a bare
-- `v ~= nil` on one of those raises. Describe is the only guarded route to
-- text, so the skip test is made on the text rather than on the value.
local function Values(...)
    local out = {}
    for i = 1, select("#", ...) do
        local text = Describe((select(i, ...)))
        if text ~= "nil" then out[#out + 1] = text end
    end
    return table.concat(out, ", ")
end

--- Asks the client something and says which of four things happened.
--
-- Four answers and not two, which is the whole point of the function. A refusal
-- and an absence look identical from the caller's side, and shipping them as
-- the same thing has already cost a real bug: see AGENTS.md on nil against
-- refused. A **secret** is the third: it arrives intact, survives tostring, and
-- raises on the first comparison made with it, including a comparison against
-- nil. So the guard goes around the comparison and not around the read.
--
-- Four returns are captured rather than one, because the answer this phase
-- needs is sometimes not the first of them: GetGuildInfo hands the rank back
-- second, behind the guild name.
local function Ask(fn, a, b)
    if type(fn) ~= "function" then return "missing", "" end
    local ok, v1, v2, v3, v4 = pcall(fn, a, b)
    if not ok then return "refused", "" end
    if not pcall(function() return v1 == nil end) then return "secret", "" end
    if v1 == nil then return "absent", "" end

    -- Two proofs, because one turned out not to be enough. Read back off the
    -- 2026-09-23 pass: every health and power line said `ok` in the verdict with
    -- `<secret>` printed beside it. A secret **number** survives a comparison
    -- against nil and only raises once its text is compared, so the nil test
    -- clears it and Describe catches it one step later. Nothing was fooled,
    -- because the text is what gets stored, but the verdict is the part somebody
    -- skims and it was lying. A secret is not an ok.
    local text = Values(v1, v2, v3, v4)
    if text:find("<secret>", 1, true) then return "secret", text end

    return "ok", text, v1
end

--- Is this function the client's own C API, or Lua somebody wrote?
--
-- Not a safety guarantee and not used as one. It is the one fact worth having
-- about a name in the inventory below: the real unit API is C, and the Lua ones
-- are FrameXML helpers that do things. See the inventory's own note.
local function Kind(fn)
    local getinfo = debug and debug.getinfo
    if type(getinfo) ~= "function" then return "?" end
    local ok, info = pcall(getinfo, fn, "S")
    if not ok or type(info) ~= "table" then return "?" end
    return (info.what == "C") and "C" or "Lua"
end

--- Every global whose name begins with Unit or GetUnit. **Nothing here is
--- called.**
--
-- It used to call all of them with the unit as the only argument, and that was
-- wrong in a way that took a real error to show. `Blizzard_UnitPopupShared`
-- carries a function with that prefix which **opens a context menu**, so the
-- probe handed it "mouseover" as a menu type and Blizzard's menu code died
-- inside on a nil, once per mouseover, in the player's error log.
--
-- The lesson is bigger than the one name, and a blocklist would have missed it:
-- **a name is not a signature and a prefix is not a promise.** Anything called
-- blind can turn out to do rather than to answer, and this one did it inside
-- Blizzard's menu system out of tainted code, which is the risk AGENTS.md
-- records for templates, reached by a new route.
--
-- So the inventory says what exists and the curated list says what is asked.
-- Every call this probe makes is a name somebody wrote down on purpose.
--
-- Also worth knowing, and a second reason the old shape was wrong: the list is
-- built once per session, and several of these addons load on demand. What the
-- old sweep called therefore depended on what had happened to be loaded first,
-- so the same measurement gave different answers on different evenings.
local inventory
local function UnitInventory()
    if inventory then return inventory end
    inventory = {}
    pcall(function()
        for name, value in pairs(_G) do
            if type(name) == "string" and type(value) == "function"
               and (name:find("^Unit") or name:find("^GetUnit")) then
                inventory[#inventory + 1] = name .. " [" .. Kind(value) .. "]"
            end
        end
    end)
    table.sort(inventory)
    return inventory
end

-- **The only things this probe calls.** Each one is here because it answers a
-- question the tooltip or phase 4 might ask, with the arguments it actually
-- takes, so a nil means nil rather than "called with one argument when it
-- wanted two".
--
-- Widening it is a desk job rather than a guess: the inventory above lists what
-- this build has and marks which names are C and which are Lua, and a line moves
-- from there to here once somebody has decided it reads something worth having.
--
-- Resolved by name at call time rather than held as a value, so a name this
-- build does not have reports itself as missing instead of leaving a hole in
-- the list.
local function Targeted(unit)
    local other = unit .. "target"
    return {
        -- Phase 5.1, the tooltip.
        { "UnitName",             "UnitName",            unit },
        { "UnitClass",            "UnitClass",           unit },
        { "UnitRace",             "UnitRace",            unit },
        { "UnitLevel",            "UnitLevel",           unit },
        { "UnitIsPlayer",         "UnitIsPlayer",        unit },
        { "UnitReaction",         "UnitReaction",        "player", unit },
        { "GetGuildInfo",         "GetGuildInfo",        unit },
        -- Target of target. This is unit identity, which C_Secrets covers, and
        -- it is the one requested line that may not exist at all.
        { "UnitExists(tot)",      "UnitExists",          other },
        { "UnitName(tot)",        "UnitName",            other },
        { "UnitIsUnit(tot,me)",   "UnitIsUnit",          other, "player" },
        -- Phase 4 stands on the rest. Measured here because the reload is
        -- running anyway, not because this phase needs any of it.
        { "UnitHealth",           "UnitHealth",          unit },
        { "UnitHealthMax",        "UnitHealthMax",       unit },
        { "UnitPower",            "UnitPower",           unit },
        { "UnitPowerMax",         "UnitPowerMax",        unit },
        { "UnitThreatSituation",  "UnitThreatSituation", "player", unit },
        { "UnitCastingInfo",      "UnitCastingInfo",     unit },
        { "UnitChannelInfo",      "UnitChannelInfo",     unit },
        { "UnitAffectingCombat",  "UnitAffectingCombat", unit },
        { "UnitGUID",             "UnitGUID",            unit },
        -- Added when the sweep was removed, to keep the pass worth a reload.
        -- Each one is a line somebody might actually want in a tooltip, and
        -- each is a question rather than an instruction.
        { "UnitIsDead",           "UnitIsDead",          unit },
        { "UnitIsConnected",      "UnitIsConnected",     unit },
        { "UnitClassification",   "UnitClassification",  unit },
        { "UnitCreatureType",     "UnitCreatureType",    unit },
        { "UnitCreatureFamily",   "UnitCreatureFamily",  unit },
        { "UnitPVPName",          "UnitPVPName",         unit },
        { "UnitFactionGroup",     "UnitFactionGroup",    unit },
        { "UnitSex",              "UnitSex",             unit },
        { "UnitPlayerControlled", "UnitPlayerControlled",unit },
        { "UnitPowerType",        "UnitPowerType",       unit },
        { "UnitCanAttack",        "UnitCanAttack",       "player", unit },
        { "UnitIsFriend",         "UnitIsFriend",        "player", unit },
        { "UnitIsAFK",            "UnitIsAFK",           unit },
        { "UnitIsTapDenied",      "UnitIsTapDenied",     unit },
    }
end

--- One pass over the curated list: a verdict each, and the value where there
--- was one.
local function Sample(unit)
    local verdicts, values = {}, {}
    for _, e in ipairs(Targeted(unit)) do
        local verdict, text = Ask(Resolve(e[2]), e[3], e[4])
        verdicts[#verdicts + 1] = e[1] .. "=" .. verdict
        if verdict == "ok" then
            values[#values + 1] = e[1] .. " -> " .. text
        end
    end
    return verdicts, values
end

local lastSample = 0

--- Records a pass, but only when it says something the file does not hold yet.
--
-- The owner asked for this to run by itself rather than on a typed command, and
-- the objection was the file growing without limit. The answer is in the shape
-- rather than in the argument: **one entry per distinct picture**, so twenty
-- passes over the same target are one line with a counter on it. What is being
-- measured is which answers are possible, not how often each one came up.
local function Record(unit, force)
    if not COLLECTING then return end
    local now = GetTime and GetTime() or 0
    if not force and now - lastSample < SAMPLE_GAP then return end
    lastSample = now

    -- Both flags, deliberately. InCombatLockdown is the client's own gate and
    -- the player's combat flag is the fight: they disagree for a moment at each
    -- end, and that window is exactly where a refusal turned up while the gate
    -- still said quiet. Recording both makes the window visible instead of
    -- hiding it behind whichever one was picked.
    local locked   = select(3, Ask(Resolve("InCombatLockdown")))
    local fighting = select(3, Ask(Resolve("UnitAffectingCombat"), "player"))
    local state = string.format("lock=%s fight=%s",
        tostring(FP:Truth(locked)), tostring(FP:Truth(fighting)))

    local verdicts, values = Sample(unit)
    local key = state .. "|" .. table.concat(verdicts, ",")

    local store = FP.global.unitProbe
    if type(store) ~= "table" then
        store = { samples = {} }
        FP.global.unitProbe = store
    end
    for _, s in ipairs(store.samples) do
        if s.key == key then s.seen = s.seen + 1 return end
    end

    local okName, name = pcall(UnitName, unit)
    store.samples[#store.samples + 1] = {
        key      = key,
        seen     = 1,
        stamp    = date("%Y-%m-%d %H:%M:%S"),
        state    = state,
        unit     = (okName and type(name) == "string") and name or "<unreadable>",
        verdicts = verdicts,
        values   = values,
    }
    while #store.samples > MAX_SAMPLES do table.remove(store.samples, 1) end
end

--- The one shot questions, asked once rather than per unit.
--
-- Everything here is either a fact about the client's own furniture or a
-- question about whether it already does something the info bar was going to
-- do. Nothing depends on a unit being under the cursor.
function M:ProbeStatic()
    local s = {}

    -- 1. Edit Mode system 11. It is registered; whether it offers anything is
    -- the open question, and the owner reports the tooltip cannot be moved
    -- there at all. Opened key by key rather than guessed at, which is the
    -- rule this file has been bitten by three times.
    local found = {}
    pcall(function()
        local list = rawget(EditModeManagerFrame or {}, "registeredSystemFrames")
        for i = 1, (type(list) == "table" and #list or 0) do
            local sys = list[i]
            if tostring(rawget(sys, "system")) == "11" then
                found[#found + 1] = FrameName(sys)
                for _, k in ipairs(StringKeys(sys)) do
                    found[#found + 1] = "  " .. k
                end
            end
        end
    end)
    s.hudTooltipSystem = #found > 0 and found or { "no frame reports system 11" }

    -- 2. Where the client puts the tooltip by itself. The fourth anchor entry
    -- is called the default rather than a corner because of these offsets:
    -- they keep the bags and action bars clear, so it is not simply the bottom
    -- right of the screen.
    local anchor = {}
    pcall(function()
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        local point, rel, relPoint, x, y = GameTooltip:GetPoint(1)
        anchor[1] = string.format("point=%s relativeTo=%s relPoint=%s x=%s y=%s",
            tostring(point), FrameName(rel), tostring(relPoint),
            tostring(x), tostring(y))
        GameTooltip:Hide()
    end)
    s.defaultAnchor = anchor[1] or "GameTooltip_SetDefaultAnchor did not answer"

    -- 3. Does this client already show what the info bar was going to show?
    -- Whatever it does show drops out of 5.2 under the rule that we do not
    -- answer a question the client answers.
    local native = {}
    local function note(label, value) native[#native + 1] = label .. ": " .. value end

    local map = select(3, Ask(Resolve("C_Map.GetBestMapForUnit"), "player"))
    local verdict, _, pos = Ask(Resolve("C_Map.GetPlayerMapPosition"), map, "player")
    note("coordinate data", verdict)
    if verdict == "ok" then
        local okXY, x, y = pcall(function() return pos:GetXY() end)
        note("coordinates", okXY and string.format("%.2f %.2f", x, y) or "no GetXY")
    end
    note("WorldMapFrame coord display", _G.WorldMapFrameCoordinates and "present"
        or (rawget(_G.WorldMapFrame or {}, "Coordinates") and "present" or "absent"))

    note("backpack free slot text",
        rawget(_G.MainMenuBarBackpackButton or {}, "freeSlots") and "present" or "absent")
    note("DurabilityFrame", _G.DurabilityFrame and "present" or "absent")
    local netVerdict, netText = Ask(Resolve("GetNetStats"))
    note("GetNetStats", netVerdict .. " " .. netText)
    local fpsVerdict, fpsText = Ask(Resolve("GetFramerate"))
    note("GetFramerate", fpsVerdict .. " " .. fpsText)
    note("ShowFramerate global", _G.ShowFramerate and "present" or "absent")

    -- 4. Does the experience bar already answer on hover? If it does, the
    -- owner's request is extra lines on it rather than a second tooltip beside
    -- it. Checked on both the container and the bar the manager holds.
    local xp = {}
    pcall(function()
        for _, name in ipairs({ "MainStatusTrackingBarContainer",
                                "StatusTrackingBarManager", "MainMenuExpBar" }) do
            local f = _G[name]
            if f then
                xp[#xp + 1] = name .. ": OnEnter=" ..
                    (f.GetScript and f:GetScript("OnEnter") and "yes" or "no") ..
                    " mouse=" .. tostring(f.IsMouseEnabled and f:IsMouseEnabled())
            end
        end
    end)
    s.xpBar = #xp > 0 and xp or { "no experience bar frame found" }
    s.native = native

    -- 5. The chat frame. The owner went through the client's own chat options
    -- on 2026-09-21 and found timestamps, the edit box, and a few filters. That
    -- is a short list beside what this engine carries, so the question for 5.3
    -- is not what the client **can** do but what it offers a switch for. Those
    -- are different gaps and only the second one is ours to fill.
    local chat = {}
    local function chatNote(label, value) chat[#chat + 1] = label .. ": " .. value end

    -- The frame's own levers, documented for build 69594 and therefore near
    -- enough this one to be worth checking rather than assuming. The first four
    -- are the interesting ones: this engine appears to select and copy chat
    -- text by itself, which is the feature every chat addon builds a window
    -- for.
    local cf = _G.ChatFrame1
    for _, name in ipairs({ "SetTextCopyable", "IsTextCopyable", "GatherSelectedText",
                            "SetOnTextCopiedCallback", "SetSpacing", "SetIndentedWordWrap",
                            "SetMaxLines", "GetMaxLines", "SetShadowOffset", "SetJustifyH",
                            "TransformMessages", "AdjustMessageColors",
                            "RemoveMessagesByPredicate", "GetMessageInfo",
                            "ForEachMessage", "SetOnLineRightClickedCallback",
                            "SetFadePower", "SetFont", "SetFontObject" }) do
        -- Looked up through the frame rather than in _G: these are methods on
        -- the widget, and a missing one resolves to nil rather than raising.
        local okLook, method = pcall(function() return cf and cf[name] end)
        chatNote("ChatFrame1:" .. name,
            (okLook and type(method) == "function") and "present" or "absent")
    end
    if cf and cf.GetMaxLines then
        local _, text = Ask(cf.GetMaxLines, cf)
        chatNote("current maxLines", text)
    end
    if cf and cf.IsTextCopyable then
        local _, text = Ask(cf.IsTextCopyable, cf)
        chatNote("text copyable right now", text)
    end

    -- The CVars this engine documents for chat. A name that answers here but
    -- has no switch in the client's options is the gap 5.3 would fill, and
    -- filling it is not a second switch over the client's: it is the only one.
    local get = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
    for _, name in ipairs({ "showTimestamps", "chatStyle", "colorChatNamesByClass",
                            "chatClassColorOverride", "wholeChatWindowClickable",
                            "chatMouseScroll", "chatBubbles", "chatBubblesParty",
                            "chatBubblesRaid", "whisperMode", "showPingsInChat",
                            "blockChannelInvites", "autoClearAFK",
                            "synchronizeChatFrames", "displayFreeBagSlots",
                            -- Not for setting. This one names the machinery
                            -- that has shaped three phases of this addon, and
                            -- reading it says whether the refusals are a switch
                            -- or the engine's nature. Phase 4 wants the answer.
                            "addonChatRestrictionsForced" }) do
        local verdict, text = Ask(get, name)
        chatNote("cvar " .. name, verdict == "ok" and text or verdict)
    end

    for _, name in ipairs({ "ChatTypeInfo", "CHAT_TIMESTAMP_FORMAT",
                            "ChatFrame_AddMessageEventFilter", "FCF_OpenNewWindow",
                            "FCF_SetWindowName", "ChatEdit_ActivateChat",
                            "ChatFrame1EditBox", "ChatFrameMenuButton",
                            "CHAT_FONT_HEIGHTS" }) do
        chatNote(name, Resolve(name) ~= nil and "present" or "absent")
    end
    s.chat = chat

    -- 6. The inventory of Unit names, listed once rather than per sample:
    -- nothing in it is called, so it cannot change between passes. It is the
    -- desk input for widening the curated list in Targeted.
    s.unitNames = UnitInventory()

    local store = FP.global.unitProbe
    if type(store) ~= "table" then
        store = { samples = {} }
        FP.global.unitProbe = store
    end
    store.static = s
    store.stamp  = date("%Y-%m-%d %H:%M:%S")
    return s
end

--- Prints what has been gathered, and says what is still missing.
function M:ProbeReport()
    local store = FP.global.unitProbe
    if type(store) ~= "table" then
        return FP:Warn("nothing measured yet. %s", COLLECTING
            and "Hover a unit, then fight one." or "COLLECTING is off.")
    end

    FP:Print("Unit probe, collected %s:", tostring(store.stamp))
    local s = store.static
    if s then
        Say("Edit Mode system 11 (HudTooltip):")
        for _, line in ipairs(s.hudTooltipSystem) do Say("  %s", line) end
        Say("Default tooltip anchor: %s", s.defaultAnchor)
        Say("Already in the client:")
        for _, line in ipairs(s.native) do Say("  %s", line) end
        Say("Experience bar:")
        for _, line in ipairs(s.xpBar) do Say("  %s", line) end
        if s.chat then
            Say("Chat:")
            for _, line in ipairs(s.chat) do Say("  %s", line) end
        end
        if s.unitNames then
            -- The names go to the file rather than to chat. There are dozens,
            -- and the count is the only part worth reading here.
            Say("Unit names found: %d (in the file, none of them called)",
                #s.unitNames)
        end
    else
        Say("static pass has not run")
    end

    local quiet, fight = 0, 0
    for _, sample in ipairs(store.samples or {}) do
        if sample.state:find("fight=true") then fight = fight + 1 else quiet = quiet + 1 end
    end
    Say("%d distinct picture%s: %d out of combat, %d in it.",
        #(store.samples or {}), #(store.samples or {}) == 1 and "" or "s", quiet, fight)
    for i, sample in ipairs(store.samples or {}) do
        Say("|cffffd200[%d]|r %s  %s  seen %d", i, sample.unit, sample.state, sample.seen)
        Say("    %s", table.concat(sample.verdicts, "  "))
    end
    if fight == 0 then
        FP:Warn("nothing recorded in combat yet, which is the half that matters. "
            .. "Hover your target while fighting it.")
    end
    FP:Print("The read values and the inventory of Unit names are in the file, "
        .. "not here. |cff888888/fplus probe forget|r clears it.")
end

--- Throws the samples away again, the chat probe's along with the units'.
function M:ForgetProbe()
    local n = #((FP.global.unitProbe or {}).samples or {})
    FP.global.unitProbe = nil
    FP.global.chatProbe = nil
    return n
end

-- ---------------------------------------------------------------------------
-- Part 5: what the chat hands an addon.
--
-- Phase 6's measurement, and the same shape as Part 4: it records by itself
-- while COLLECTING is on, one entry per distinct picture under a cap, and says
-- nothing in chat unless asked.
--
-- Two questions decide features rather than details, and ROADMAP.md names
-- both. **Who is speaking**: race and class icons need the speaker's class and
-- race per message, which means a guid in the chat event and an answer from
-- GetPlayerInfoByGUID, and identity is exactly what C_Secrets covers here.
-- **Who may start a copy**: the engine copies selected chat text by itself, and
-- whether an addon may trigger a copy decides what shift clicking a timestamp
-- can do. That one needs a typed command, see ChatProbeCopy.
--
-- The rest is what building the phase needs and nobody has looked at: how a
-- sender's name arrives on build 70009, where the name moved into two values;
-- how a finished chat line is built, link by link; which end of a frame's
-- history is the newest and what TransformMessages hands its predicate; the
-- buttons and tabs around the frame; the formats the client builds a group
-- label from; which sounds the client carries and whether it plays one of its
-- own for a whisper.
--
-- Three questions from the backlog ride along because the reload is running
-- anyway: whether the player's own power, health and experience are readable
-- when every other unit's are secret, and whether UNIT_COMBAT reaches an addon
-- for the player during a fight, which decides Earth Shield. Phase 4 gets a
-- nudge as well: a target that starts casting is sampled at that moment,
-- because the cast is the one unit reading never caught.
-- ---------------------------------------------------------------------------

local MAX_CHAT_EVENTS = 40
local MAX_CHAT_LINES  = 30
local MAX_CHAT_LINKS  = 12
local MAX_PLAYER      = 12
local MAX_UNIT_COMBAT = 16
local MAX_SOUND_LOOKS = 8

-- Every event a chat line comes from that phase 6 touches. Registered one at a
-- time: RegisterEvent raises on a name this build does not know, and a name
-- that is missing is a finding rather than a failure.
local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_AFK", "CHAT_MSG_DND",
}

local function ChatStore()
    local store = FP.global.chatProbe
    if type(store) ~= "table" then
        store = {}
        FP.global.chatProbe = store
    end
    for _, key in ipairs({ "events", "lines", "links", "player", "unitCombat",
                           "whisperSounds", "errors" }) do
        if type(store[key]) ~= "table" then store[key] = {} end
    end
    return store
end

--- Runs a recorder without a word in chat when it fails.
--
-- A recorder that raised used to announce itself through FP:Safe, which is
-- right for a feature and wrong here: this one runs on every chat line, and a
-- fault in it would print once per line. The first error per place is kept in
-- the file instead, where it is read with everything else.
local function Quietly(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local store = ChatStore()
        if store.errors[what] == nil then store.errors[what] = tostring(err) end
    end
end

local function CombatState()
    local locked   = select(3, Ask(Resolve("InCombatLockdown")))
    local fighting = select(3, Ask(Resolve("UnitAffectingCombat"), "player"))
    return string.format("lock=%s fight=%s",
        tostring(FP:Truth(locked)), tostring(FP:Truth(fighting)))
end

--- nil, the Lua type of a readable value, or secret.
local function ValueKind(value)
    if not pcall(function() return value == nil end) then return "secret" end
    if value == nil then return "nil" end
    if Describe(value):find("<secret>", 1, true) then return "secret" end
    return type(value)
end

--- The outline of a name rather than the name: "Sleepi Joe" is "A A".
--
-- What the recording is keyed by, so that a busy channel with a hundred
-- different speakers is still one entry, and the entry still says whether a
-- name arrives as one word, two words, or two words joined to a realm.
local function Shape(text)
    local plain = FP:Plain(text)
    if not plain then return ValueKind(text) end
    return (plain:gsub("%a+", "A"):gsub("%d+", "9"))
end

local function Keep(list, key, cap, make)
    for _, entry in ipairs(list) do
        if entry.key == key then
            entry.seen = (entry.seen or 1) + 1
            return
        end
    end
    if #list >= cap then return end
    local entry = make()
    entry.key, entry.seen = key, 1
    entry.stamp = date("%Y-%m-%d %H:%M:%S")
    list[#list + 1] = entry
end

--- One chat event: which of its values can be read, and what the speaker's
--- guid says about them.
local function RecordChatEvent(event, ...)
    local store = ChatStore()
    local count = select("#", ...)
    local args = { ... }

    local kinds = {}
    for i = 1, math.max(count, 14) do kinds[i] = ValueKind(args[i]) end

    local author = FP:Plain(args[2])
    local guid   = FP:Plain(args[12])

    -- All seven returns, where Ask keeps four: race and the name come last.
    local verdict, info = "no guid", {}
    if guid then
        local getInfo = Resolve("GetPlayerInfoByGUID")
        if type(getInfo) ~= "function" then
            verdict = "GetPlayerInfoByGUID is missing"
        else
            local ok, packed = pcall(function() return { getInfo(guid) } end)
            if not ok then
                verdict = "refused"
            else
                for i = 1, 7 do info[i] = Describe(packed[i]) end
                verdict = table.concat(info, " "):find("<secret>", 1, true)
                          and "secret" or "ok"
            end
        end
    end

    local state = CombatState()
    local key = table.concat({ event, state, table.concat(kinds, ","),
        Shape(args[2]), verdict }, "|")

    Keep(store.events, key, MAX_CHAT_EVENTS, function()
        local values = {}
        for i = 2, math.max(count, 14) do
            values[#values + 1] = i .. "=" .. Describe(args[i])
        end
        local okLength, length = pcall(function() return #args[1] end)
        return {
            event = event, state = state, kinds = kinds, values = values,
            messageLength = okLength and length or "unreadable",
            playerInfo = table.concat(info, ", "), playerInfoVerdict = verdict,
            unitToken = guid and select(2, Ask(Resolve("UnitTokenFromGUID"), guid)) or nil,
            ambiguateShort = author and select(2, Ask(Resolve("Ambiguate"), author, "short")) or nil,
            ambiguateNone  = author and select(2, Ask(Resolve("Ambiguate"), author, "none")) or nil,
        }
    end)
end

--- The link types a finished line carries, in order: "channel,player".
local function LinkTypes(text)
    local types = {}
    for kind in text:gmatch("|H([^:|]+)") do types[#types + 1] = kind end
    return (#types > 0) and table.concat(types, ",") or "no links"
end

--- One finished chat line, as a chat frame received it.
local function RecordLine(frame, text, ...)
    local store = ChatStore()
    local plain = FP:Plain(text)

    -- Once: which end of the history is the newest. Asked right after a line
    -- went in, when the line just added is known, rather than guessed from
    -- the retail source.
    if plain and not store.historyOrder
       and frame.GetNumMessages and frame.GetMessageInfo then
        local okN, n = pcall(frame.GetNumMessages, frame)
        local _, first = pcall(frame.GetMessageInfo, frame, 1)
        local last
        if okN then last = select(2, pcall(frame.GetMessageInfo, frame, n)) end
        local function Same(value)
            local ok, same = pcall(function() return value == plain end)
            return ok and same
        end
        store.historyOrder = string.format("messages=%s index1=%s indexLast=%s",
            tostring(n), Same(first) and "newest" or "older",
            Same(last) and "newest" or "older")
    end

    -- Once: what TransformMessages hands its predicate. Line rewriting stands
    -- on it, and a predicate that returns false changes nothing.
    if not store.transformShape and frame.TransformMessages then
        local shape = "predicate never called"
        pcall(frame.TransformMessages, frame, function(entry)
            if shape == "predicate never called" then
                if type(entry) == "table" then
                    local keys = {}
                    for k, v in pairs(entry) do
                        keys[#keys + 1] = tostring(k) .. ":" .. type(v)
                    end
                    table.sort(keys)
                    shape = "table " .. table.concat(keys, " ")
                else
                    shape = type(entry)
                end
            end
            return false
        end, function() end)
        store.transformShape = shape
    end

    local key
    if plain then
        key = (plain:match("^%d%d?:%d%d") and "stamp+" or "") .. LinkTypes(plain)
    else
        key = "unreadable " .. ValueKind(text)
    end

    local extra = { ... }
    local count = select("#", ...)
    Keep(store.lines, key, MAX_CHAT_LINES, function()
        local described = {}
        for i = 1, math.min(count, 8) do described[i] = Describe(extra[i]) end
        return {
            frame = FrameName(frame),
            example = plain and plain:sub(1, 220) or nil,
            extra = table.concat(described, ", "),
        }
    end)
end

--- A link somebody clicked, as the chat frame passed it on.
local function RecordLink(source, link, text, button)
    local store = ChatStore()
    local plainLink = FP:Plain(link)
    local kind = plainLink and (plainLink:match("^([^:]+)") or "?") or ValueKind(link)
    Keep(store.links, source .. ":" .. kind, MAX_CHAT_LINKS, function()
        return { link = plainLink, text = FP:Plain(text), button = Describe(button) }
    end)
end

-- The last few sounds the client played, so a whisper can be asked afterwards
-- what was heard with it.
local recentSounds = {}

local function NoteSound(kind, sound, channel)
    recentSounds[#recentSounds + 1] = {
        at = GetTime and GetTime() or 0,
        what = kind .. " " .. Describe(sound) .. " " .. Describe(channel),
    }
    if #recentSounds > 20 then table.remove(recentSounds, 1) end
end

--- Half a second after a whisper: did the client play anything for it?
--
-- The answer decides whether ours replaces a sound or is the only one. GetTime
-- does not move during one frame's events, so a sound played by the chat
-- frame's own handler carries the same time as the whisper, whichever of the
-- two handlers ran first.
local function WatchSoundsAfter(event)
    local at = GetTime and GetTime() or 0
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(0.5, function()
        Quietly("whisper sounds", function()
            local heard = {}
            for _, sound in ipairs(recentSounds) do
                if sound.at >= at then heard[#heard + 1] = sound.what end
            end
            local store = ChatStore()
            if #store.whisperSounds >= MAX_SOUND_LOOKS then return end
            store.whisperSounds[#store.whisperSounds + 1] = {
                stamp = date("%Y-%m-%d %H:%M:%S"), event = event,
                sounds = #heard > 0 and table.concat(heard, "; ") or "nothing",
            }
        end)
    end)
end

-- What the player's own values look like, against the secret answers every
-- other unit gave on 2026-09-23. Health and power of a target were secret out
-- of combat as well, and whether your own are is what a condition like "only
-- when I have the rage" would stand on.
local PLAYER_READS = { "UnitPower", "UnitPowerMax", "UnitHealth",
                       "UnitHealthMax", "UnitXP", "UnitXPMax" }

local function SamplePlayer(reason)
    local store = ChatStore()
    local state = CombatState()
    local verdicts, values = {}, {}
    for _, name in ipairs(PLAYER_READS) do
        local verdict, text = Ask(Resolve(name), "player")
        verdicts[#verdicts + 1] = name .. "=" .. verdict
        if verdict == "ok" then values[#values + 1] = name .. " -> " .. text end
    end
    Keep(store.player, state .. "|" .. table.concat(verdicts, ","), MAX_PLAYER,
        function()
            return { state = state, reason = reason, verdicts = verdicts,
                     values = values }
        end)
end

--- UNIT_COMBAT for the player: the event the portrait's hit numbers come from,
--- and the only trace a spent Earth Shield charge could leave.
local function RecordUnitCombat(unit, action, descriptor, amount, school)
    if FP:Plain(unit) ~= "player" then return end
    local store = ChatStore()
    local state = CombatState()
    local kinds = { ValueKind(action), ValueKind(descriptor),
                    ValueKind(amount), ValueKind(school) }
    Keep(store.unitCombat,
        state .. "|" .. Describe(action) .. "|" .. table.concat(kinds, ","),
        MAX_UNIT_COMBAT, function()
            return {
                state = state, kinds = kinds,
                example = table.concat({ Describe(action), Describe(descriptor),
                    Describe(amount), Describe(school) }, " "),
            }
        end)
end

-- Frames already carrying the line hook. The hook cannot be taken off again,
-- which is why it asks COLLECTING on every call rather than being removed.
local hookedFrames = {}

local function HookChatFrames()
    if not hooksecurefunc then return end
    local names = {}
    if type(CHAT_FRAMES) == "table" then
        for _, name in ipairs(CHAT_FRAMES) do names[#names + 1] = name end
    end
    for i = 1, (NUM_CHAT_WINDOWS or 10) do names[#names + 1] = "ChatFrame" .. i end

    for _, name in ipairs(names) do
        local frame = _G[name]
        if type(frame) == "table" and type(frame.AddMessage) == "function"
           and not hookedFrames[frame] then
            hookedFrames[frame] = true
            hooksecurefunc(frame, "AddMessage", function(self, text, ...)
                if COLLECTING then Quietly("line", RecordLine, self, text, ...) end
            end)
        end
    end
end

local lastPowerSample = 0

local function OnChatProbeEvent(event, ...)
    if not COLLECTING then return end

    if event:find("^CHAT_MSG_") then
        RecordChatEvent(event, ...)
        if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
            WatchSoundsAfter(event)
        end
    elseif event == "UNIT_COMBAT" then
        RecordUnitCombat(...)
    elseif event == "PLAYER_REGEN_DISABLED" then
        SamplePlayer("combat started")
        -- And once more a moment later, inside the lockdown proper, which is
        -- where a refusal would begin.
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, function() Quietly("player", SamplePlayer, "in combat") end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        SamplePlayer("combat ended")
    elseif event == "PLAYER_XP_UPDATE" then
        SamplePlayer("experience")
    elseif event == "UNIT_POWER_UPDATE" then
        if FP:Plain((...)) ~= "player" then return end
        local now = GetTime and GetTime() or 0
        if now - lastPowerSample < 2 then return end
        lastPowerSample = now
        SamplePlayer("power")
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = FP:Plain((...))
        if unit == "target" or unit == "mouseover" then Record(unit, true) end
    elseif event == "UPDATE_CHAT_WINDOWS" then
        HookChatFrames()
    end
end

local chatHooked = false

--- Starts recording. Only ever called while COLLECTING is on.
function M:StartChatProbe()
    self.chatProbe = self.chatProbe or CreateFrame("Frame")
    local frame = self.chatProbe
    local store = ChatStore()

    store.missingEvents = {}
    local wanted = {}
    for _, event in ipairs(CHAT_EVENTS) do wanted[#wanted + 1] = event end
    for _, event in ipairs({ "UNIT_COMBAT", "PLAYER_REGEN_DISABLED",
                             "PLAYER_REGEN_ENABLED", "PLAYER_XP_UPDATE",
                             "UNIT_POWER_UPDATE", "UNIT_SPELLCAST_START",
                             "UNIT_SPELLCAST_CHANNEL_START",
                             "UPDATE_CHAT_WINDOWS" }) do
        wanted[#wanted + 1] = event
    end
    for _, event in ipairs(wanted) do
        if not pcall(frame.RegisterEvent, frame, event) then
            store.missingEvents[#store.missingEvents + 1] = event
        end
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        Quietly(event, OnChatProbeEvent, event, ...)
    end)

    -- Hooks cannot be undone, so they go in once and each asks COLLECTING.
    if chatHooked or not hooksecurefunc then return end
    chatHooked = true

    HookChatFrames()
    -- A whisper opens a window of its own on this client (whisperMode reads
    -- "popout"), and a window that did not exist at login has no hook yet.
    if type(_G.FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            if COLLECTING then Quietly("hook frames", HookChatFrames) end
        end)
    end
    if type(_G.PlaySound) == "function" then
        hooksecurefunc("PlaySound", function(sound, channel)
            if COLLECTING then Quietly("sound", NoteSound, "kit", sound, channel) end
        end)
    end
    if type(_G.PlaySoundFile) == "function" then
        hooksecurefunc("PlaySoundFile", function(file, channel)
            if COLLECTING then Quietly("sound", NoteSound, "file", file, channel) end
        end)
    end
    if type(_G.ChatFrame_OnHyperlinkShow) == "function" then
        hooksecurefunc("ChatFrame_OnHyperlinkShow", function(_, link, text, button)
            if COLLECTING then Quietly("link", RecordLink, "chat frame", link, text, button) end
        end)
    end
    if type(_G.SetItemRef) == "function" then
        hooksecurefunc("SetItemRef", function(link, text, button)
            if COLLECTING then Quietly("link", RecordLink, "SetItemRef", link, text, button) end
        end)
    end
end

--- The one shot questions about the chat, asked once per login.
function M:ProbeChatStatic()
    local store = ChatStore()
    local s = {}

    -- 1. Names, none of them called.
    s.names = {}
    for _, name in ipairs({
        "ChatFrame_MessageEventHandler", "ChatFrame_OnHyperlinkShow", "SetItemRef",
        "ItemRefTooltip", "EventRegistry", "LinkUtil", "ExtractLinkData",
        "ChatEdit_InsertLink", "ChatEdit_GetActiveWindow", "ChatEdit_ChooseBoxForSend",
        "ChatEdit_SetLastTellTarget", "ChatEdit_GetLastTellTarget",
        "ChatEdit_ActivateChat", "ChatEdit_SendText", "ChatEdit_OnEnterPressed",
        "ChatEdit_UpdateHeader", "ChatFrame_OpenChat", "ChatFrame_SendTell",
        "ChatFrame_ReplyTell", "ChatFrame_GetMessageEventFilters",
        "ChatFrame_AddMessageEventFilter", "ChatFrame_RemoveMessageEventFilter",
        "GetPlayerInfoByGUID", "C_PlayerInfo", "UnitTokenFromGUID", "Ambiguate",
        "GetChannelList", "GetChannelName", "EnumerateServerChannels",
        "C_ChatInfo.GetChannelInfoFromIdentifier", "C_ChatInfo.GetChannelShortcut",
        "ChatTypeInfo", "ChatTypeGroup", "ChangeChatColor", "GetChatWindowInfo",
        "FCF_OpenTemporaryWindow", "FCF_GetCurrentChatFrame",
        "FCF_SetChatWindowFontSize", "FCF_FadeInChatFrame", "FCF_FadeOutChatFrame",
        "FCFTab_UpdateAlpha", "FCF_StartAlertFlash", "FCFDock_GetSelectedWindow",
        "GENERAL_CHAT_DOCK", "GeneralDockManager", "CHAT_FRAMES",
        "ChatFrame1ButtonFrame", "ChatFrameMenuButton", "ChatFrameChannelButton",
        "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton",
        "QuickJoinToastButton", "FriendsMicroButton", "TextToSpeechButtonFrame",
        "ChatFrame1Tab", "ChatFrame1EditBox", "ChatAlertFrame",
        "SOUNDKIT", "PlaySound", "PlaySoundFile", "StopSound", "MuteSoundFile",
        "UnmuteSoundFile", "C_Sound", "CopyToClipboard", "C_Clipboard",
        "BetterDate", "GetChatTimestampFormat", "C_FriendList",
        "GetGuildRosterInfo", "C_GuildInfo", "IsInGuild", "CLASS_ICON_TCOORDS",
        "RAID_CLASS_COLORS", "GetClassAtlas", "C_Texture.GetAtlasInfo",
        "C_CreatureInfo.GetRaceInfo", "C_CreatureInfo.GetClassInfo",
        "UnitIsDND", "UnitIsAFK", "IsChatDND", "IsChatAFK",
    }) do
        local obj = Resolve(name)
        s.names[#s.names + 1] = name .. ": " .. (obj == nil and "absent" or type(obj))
    end

    -- 2. The chat frame's own fields, and its methods by name. The methods are
    -- looked for on the frame and on its metatable both, because a mixin puts
    -- them on the first and the engine on the second.
    local cf = _G.ChatFrame1
    s.frameFields, s.frameMethods = {}, {}
    if cf then
        for _, key in ipairs({ "historyBuffer", "ScrollToBottomButton", "ScrollBar",
                               "buttonFrame", "editBox", "channelList",
                               "zoneChannelList", "messageTypeList",
                               "FontStringContainer", "fontStringPool",
                               "isDocked", "isTemporary" }) do
            local ok, value = pcall(function() return cf[key] end)
            s.frameFields[#s.frameFields + 1] = key .. ": " .. (ok and type(value) or "raised")
        end

        local seen = {}
        local function Consider(key, value)
            if type(key) ~= "string" or type(value) ~= "function" or seen[key] then return end
            for _, word in ipairs({ "Copy", "Select", "Text", "Line", "Message",
                                    "Hyperlink", "Clipboard", "History", "Fad",
                                    "Scroll", "Font", "Spacing", "Callback" }) do
                if key:find(word, 1, true) then
                    seen[key] = true
                    s.frameMethods[#s.frameMethods + 1] = key
                    return
                end
            end
        end
        pcall(function() for k, v in pairs(cf) do Consider(k, v) end end)
        pcall(function()
            local meta = getmetatable(cf)
            local index = type(meta) == "table" and meta.__index
            if type(index) == "table" then
                for k, v in pairs(index) do Consider(k, v) end
            end
        end)
        table.sort(s.frameMethods)
    end

    -- 3. The input line: recall of sent messages stands on these.
    s.editBox = {}
    local eb = _G.ChatFrame1EditBox
    if eb then
        for _, name in ipairs({ "SetAltArrowKeyMode", "GetAltArrowKeyMode",
                                "AddHistoryLine", "SetHistoryLines",
                                "GetHistoryLines", "ClearHistory", "Insert" }) do
            local ok, method = pcall(function() return eb[name] end)
            s.editBox[#s.editBox + 1] = name .. ": "
                .. ((ok and type(method) == "function") and "present" or "absent")
        end
        if eb.GetAltArrowKeyMode then
            s.editBox[#s.editBox + 1] = "alt arrow mode now: "
                .. select(2, Ask(eb.GetAltArrowKeyMode, eb))
        end
        if eb.GetHistoryLines then
            s.editBox[#s.editBox + 1] = "history lines now: "
                .. select(2, Ask(eb.GetHistoryLines, eb))
        end
    end

    -- 4. What sits around the frame, which is what "hide the chat buttons"
    -- has to find. Named children, and the usual suspects one by one with
    -- whether they are shown and what they hang from.
    s.around = {}
    for _, parent in ipairs({ "ChatFrame1ButtonFrame", "ChatFrame1",
                              "GeneralDockManager" }) do
        local kids = NamedChildren(_G[parent])
        s.around[#s.around + 1] = parent .. ": "
            .. (#kids > 0 and table.concat(kids, ", ") or "no named children")
    end
    local function NoteFrame(label, frame)
        if type(frame) ~= "table" then
            s.around[#s.around + 1] = label .. ": absent"
            return
        end
        local okShown, shown = pcall(frame.IsShown, frame)
        local okParent, parent = pcall(frame.GetParent, frame)
        s.around[#s.around + 1] = string.format("%s: shown=%s parent=%s",
            label, okShown and tostring(shown) or "?",
            okParent and tostring(FrameName(parent)) or "?")
    end
    for _, name in ipairs({ "ChatFrame1ButtonFrame", "ChatFrame1ButtonFrameUpButton",
                            "ChatFrame1ButtonFrameDownButton",
                            "ChatFrame1ButtonFrameBottomButton",
                            "ChatFrame1ButtonFrameMinimizeButton",
                            "ChatFrameMenuButton", "ChatFrameChannelButton",
                            "ChatFrameToggleVoiceDeafenButton",
                            "ChatFrameToggleVoiceMuteButton", "QuickJoinToastButton",
                            "TextToSpeechButtonFrame", "ChatFrame1Tab" }) do
        NoteFrame(name, _G[name])
    end
    if cf then
        for _, key in ipairs({ "ScrollToBottomButton", "ScrollBar", "buttonFrame" }) do
            NoteFrame("ChatFrame1." .. key, rawget(cf, key))
        end
    end

    -- 5. Values the chat's own code reads: the tab alphas that decide whether
    -- a tab can be made to show only under the mouse, and the whisper timer.
    s.values = {}
    for _, name in ipairs({ "CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA",
                            "CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA",
                            "CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA",
                            "CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA",
                            "CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA",
                            "CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA",
                            "CHAT_TELL_ALERT_TIME", "CHAT_FRAME_FADE_OUT_TIME",
                            "CHAT_TAB_HIDE_DELAY", "DEFAULT_CHATFRAME_ALPHA",
                            "NUM_CHAT_WINDOWS" }) do
        s.values[#s.values + 1] = name .. " = " .. Describe(Resolve(name))
    end

    -- 6. The client's own format strings. A group label is built from these,
    -- so reading the bracket text out of them is what keeps a label field
    -- locale safe, the way ErrorFilter reads ERR_OUT_OF_MANA.
    s.formats = {}
    for _, name in ipairs({ "CHAT_GUILD_GET", "CHAT_OFFICER_GET", "CHAT_PARTY_GET",
                            "CHAT_PARTY_LEADER_GET", "CHAT_PARTY_GUIDE_GET",
                            "CHAT_RAID_GET", "CHAT_RAID_LEADER_GET",
                            "CHAT_RAID_WARNING_GET", "CHAT_INSTANCE_CHAT_GET",
                            "CHAT_INSTANCE_CHAT_LEADER_GET", "CHAT_BATTLEGROUND_GET",
                            "CHAT_BATTLEGROUND_LEADER_GET", "CHAT_WHISPER_GET",
                            "CHAT_WHISPER_INFORM_GET", "CHAT_BN_WHISPER_GET",
                            "CHAT_BN_WHISPER_INFORM_GET", "CHAT_SAY_GET",
                            "CHAT_YELL_GET", "CHAT_EMOTE_GET", "CHAT_FLAG_AFK",
                            "CHAT_FLAG_DND", "CHAT_FLAG_GM",
                            "TIMESTAMP_FORMAT_HHMM", "TIMESTAMP_FORMAT_HHMMSS",
                            "TIMESTAMP_FORMAT_HHMM_AMPM", "TIMESTAMP_FORMAT_HHMMSS_AMPM",
                            "TIMESTAMP_FORMAT_HHMM_24HR", "TIMESTAMP_FORMAT_HHMMSS_24HR" }) do
        s.formats[#s.formats + 1] = name .. " = " .. Describe(rawget(_G, name))
    end

    -- 7. The console variables the phase would switch, read.
    s.cvars = {}
    local get = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
    for _, name in ipairs({ "showTimestamps", "chatStyle", "whisperMode",
                            "chatMouseScroll", "colorChatNamesByClass",
                            "chatClassColorOverride", "profanityFilter",
                            "removeChatDelay", "Sound_EnableAllSound",
                            "Sound_EnableSFX", "Sound_SFXVolume" }) do
        local verdict, text = Ask(get, name)
        s.cvars[#s.cvars + 1] = name .. " = " .. (verdict == "ok" and text or verdict)
    end

    -- 8. The channels this character is in, which is what one label field per
    -- channel number is drawn from.
    local okChannels, channels = pcall(function() return { GetChannelList() } end)
    if okChannels then
        local described = {}
        for i = 1, #channels do described[i] = Describe(channels[i]) end
        s.channels = table.concat(described, ", ")
    else
        s.channels = "GetChannelList raised"
    end

    -- 9. Sounds. Only the keys whose names suggest a notice, with their ids:
    -- a list of the client's own sounds to choose from is what the whisper
    -- sound was decided to offer.
    s.sounds = {}
    local kit = rawget(_G, "SOUNDKIT")
    if type(kit) == "table" then
        local count = 0
        pcall(function()
            for key, value in pairs(kit) do
                count = count + 1
                if type(key) == "string" then
                    for _, word in ipairs({ "TELL", "WHISPER", "WARNING", "ALARM",
                                            "CHECK", "INVITE", "TOAST", "PING",
                                            "CHAT", "BELL", "ALERT", "QUEUE",
                                            "READY", "NOTIF", "RAID", "FRIEND",
                                            "BNET", "MAIL", "GUILD" }) do
                        if key:find(word, 1, true) then
                            s.sounds[#s.sounds + 1] = key .. "=" .. tostring(value)
                            break
                        end
                    end
                end
            end
        end)
        table.sort(s.sounds)
        s.soundCount = count
    end

    -- 10. A few namespaces by their keys, names only.
    s.namespaces = {}
    for _, name in ipairs({ "C_Sound", "C_Clipboard", "C_PlayerInfo", "C_ChatInfo",
                            "LinkUtil" }) do
        local keys = StringKeys(Resolve(name))
        s.namespaces[#s.namespaces + 1] = name .. ": "
            .. (#keys > 0 and table.concat(keys, ", ") or "nothing")
    end

    store.static = s
    store.stamp  = date("%Y-%m-%d %H:%M:%S")
    SamplePlayer("login")
    return s
end

-- Whether this build measures at all, for the help text: the typed chat probe
-- commands go with the probe when it is switched off, AGENTS.md step 7.
M.collecting = COLLECTING

--- The three typed chat probe commands do nothing in a released build.
local function ChatProbeOff()
    if COLLECTING then return false end
    FP:Warn("the chat probe is off in this build.")
    return true
end

--- Can an addon start a copy? Typed, because it overwrites the clipboard.
function M:ChatProbeCopy()
    if ChatProbeOff() then return end
    local store = ChatStore()
    local out, stamp = {}, date("%H:%M:%S")

    local copy = rawget(_G, "CopyToClipboard")
    if type(copy) == "function" then
        local ok, err = pcall(copy, "ForeverPlus probe " .. stamp)
        out[#out + 1] = "CopyToClipboard: "
            .. (ok and "returned without an error" or ("raised " .. tostring(err):sub(1, 120)))
    else
        out[#out + 1] = "CopyToClipboard: absent"
    end
    local clip = rawget(_G, "C_Clipboard")
    out[#out + 1] = "C_Clipboard: " .. (type(clip) == "table"
        and table.concat(StringKeys(clip), ", ") or "absent")

    store.copy = out
    for _, line in ipairs(out) do Say("%s", line) end
    FP:Print("Now open the chat input and press Ctrl+V. If \"ForeverPlus probe %s\" "
        .. "appears, an addon may copy. Then type |cff888888/fplus probe copied yes|r "
        .. "or |cff888888no|r.", stamp)
end

--- What the player saw after ChatProbeCopy.
function M:ChatProbeCopied(answer)
    if ChatProbeOff() then return end
    local store = ChatStore()
    store.copyResult = (answer == "yes" or answer == "no") and answer or nil
    if not store.copyResult then
        return FP:Warn("Type /fplus probe copied yes, or /fplus probe copied no.")
    end
    FP:Print("Noted: the paste %s.", answer == "yes" and "worked" or "did not work")
end

--- How the client handles a link type of our own. Typed, because it runs the
--- client's link code, which may put up a tooltip for a moment.
--
-- Shift clicking a timestamp needs a link the addon owns, and a link the
-- client does not know usually ends in an error or an empty tooltip. Three
-- candidates, and for each: did it raise, did the client announce it through
-- EventRegistry, did a tooltip open.
function M:ChatProbeLinks()
    if ChatProbeOff() then return end
    local store = ChatStore()
    local results, fired = {}, {}

    local registry = rawget(_G, "EventRegistry")
    local owner = {}
    if type(registry) == "table" and type(registry.RegisterCallback) == "function" then
        pcall(registry.RegisterCallback, registry, "SetItemRef",
            function(_, link) fired[#fired + 1] = tostring(link) end, owner)
    end

    local setItemRef = rawget(_G, "SetItemRef")
    for _, link in ipairs({ "addon:ForeverPlus:probe", "garrmission:foreverplus",
                            "fplus:probe" }) do
        if type(setItemRef) ~= "function" then
            results[#results + 1] = "SetItemRef is missing"
            break
        end
        local before = #fired
        local ok, err = pcall(setItemRef, link, "[ForeverPlus probe]", "LeftButton",
            _G.ChatFrame1)
        local tip = rawget(_G, "ItemRefTooltip")
        local shown = type(tip) == "table" and tip.IsShown and select(2, pcall(tip.IsShown, tip))
        if shown then pcall(tip.Hide, tip) end
        results[#results + 1] = string.format("%s: %s, callback %s, tooltip %s", link,
            ok and "no error" or ("raised " .. tostring(err):sub(1, 100)),
            (#fired > before) and "fired" or "silent",
            shown and "shown" or "not shown")
    end

    if type(registry) == "table" and type(registry.UnregisterCallback) == "function" then
        pcall(registry.UnregisterCallback, registry, "SetItemRef", owner)
    end

    store.linkTests = results
    for _, line in ipairs(results) do Say("%s", line) end
end

--- What the chat probe has gathered, briefly. The file holds the detail.
function M:ChatProbeReport()
    local store = FP.global.chatProbe
    if type(store) ~= "table" then
        return FP:Warn("nothing measured yet. %s", COLLECTING
            and "Chat a little, whisper somebody, fight something, then look again."
            or "COLLECTING is off.")
    end

    FP:Print("Chat probe, collected %s:", tostring(store.stamp))

    local speakers, readable = 0, 0
    for _, e in ipairs(store.events or {}) do
        if e.playerInfoVerdict ~= "no guid" then
            speakers = speakers + 1
            if e.playerInfoVerdict == "ok" then readable = readable + 1 end
        end
    end
    Say("%d kinds of chat event, %d with a speaker, %d of those readable",
        #(store.events or {}), speakers, readable)
    Say("%d kinds of chat line, %d kinds of link clicked",
        #(store.lines or {}), #(store.links or {}))
    Say("history order: %s", tostring(store.historyOrder or "not seen yet"))
    Say("TransformMessages hands: %s", tostring(store.transformShape or "not seen yet"))
    for _, look in ipairs(store.whisperSounds or {}) do
        Say("after a whisper: %s", look.sounds)
    end
    Say("own values: %d picture(s), UNIT_COMBAT: %d picture(s)",
        #(store.player or {}), #(store.unitCombat or {}))
    if store.copy then Say("copy: %s", table.concat(store.copy, "; ")) end
    if store.copyResult then Say("paste after the copy: %s", store.copyResult) end
    if store.linkTests then Say("links: %s", table.concat(store.linkTests, "; ")) end
    if next(store.errors or {}) then
        FP:Warn("the probe itself failed somewhere; the file says where.")
    end
    FP:Print("The rest is in the file. |cff888888/fplus probe forget|r clears it.")
end

function M:OnEnable()
    -- Wait a moment: some Blizzard frames only come into being after
    -- PLAYER_LOGIN.
    local runBoth = function()
        FP:Safe("Diagnostics:Collect",  M.Collect,  M)
        FP:Safe("Diagnostics:Discover", M.Discover, M)
        -- Phase 5's one shot questions ride along, and only while measuring.
        -- Phase 6's too.
        if COLLECTING then
            FP:Safe("Diagnostics:ProbeStatic", M.ProbeStatic, M)
            FP:Safe("Diagnostics:ProbeChatStatic", M.ProbeChatStatic, M)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(2, runBoth) else runBoth() end

    -- The unit probe. Scaffolding, and it comes down before the building is
    -- handed over: nothing below this is registered once COLLECTING is false,
    -- so a stranger's client neither watches nor writes.
    if COLLECTING then
        self.probe = self.probe or CreateFrame("Frame")
        self.probe:SetScript("OnEvent", function(_, event)
            -- Only the mouseover event says anything about the mouse. The
            -- others are about the target, and the two regen ones are the
            -- combat boundary, which is where the lock flag and the fight flag
            -- disagree: those are worth a pass even inside the throttle.
            local unit  = (event == "UPDATE_MOUSEOVER_UNIT") and "mouseover" or "target"
            local force = (event == "PLAYER_REGEN_DISABLED")
                       or (event == "PLAYER_REGEN_ENABLED")
            if not FP:Truth(select(3, Ask(Resolve("UnitExists"), unit))) then return end
            FP:Safe("Diagnostics:Record", Record, unit, force)
        end)
        self.probe:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        -- The target as well as the mouseover: during a fight the cursor is
        -- usually nowhere near the thing being hit, and the fight is the half
        -- of this measurement that matters.
        self.probe:RegisterEvent("PLAYER_TARGET_CHANGED")
        self.probe:RegisterEvent("PLAYER_REGEN_DISABLED")
        self.probe:RegisterEvent("PLAYER_REGEN_ENABLED")

        -- Phase 6's chat probe, under the same flag and for the same reason.
        FP:Safe("Diagnostics:StartChatProbe", M.StartChatProbe, M)
    end

    -- When the client puts up "blocked from an action only available to the
    -- Blizzard UI", it also fires an event naming the function. Recording that
    -- is the difference between knowing which call did it and guessing at a
    -- list of candidates.
    --
    -- Permanent rather than part of the throwaway probe: an addon being told
    -- off by the client is worth knowing about at any point, and it costs
    -- nothing until it happens.
    self.blocked = self.blocked or CreateFrame("Frame")
    self.blocked:SetScript("OnEvent", function(_, event, addon, func)
        if addon ~= ADDON then return end
        M.blockedCalls = M.blockedCalls or {}
        local key = event .. " " .. tostring(func)
        local first = M.blockedCalls[key] == nil
        M.blockedCalls[key] = (M.blockedCalls[key] or 0) + 1
        if FP.global then FP.global.blockedCalls = M.blockedCalls end
        -- Once per distinct call. The dialog already repeats itself; chat
        -- does not need to as well.
        if first then FP:Warn("blocked action: %s", key) end
    end)
    self.blocked:RegisterEvent("ADDON_ACTION_BLOCKED")
    self.blocked:RegisterEvent("ADDON_ACTION_FORBIDDEN")
end

function M:OnDisable()
    FP.global.diagnostics = nil
    FP.global.discovery   = nil
    -- FP.global.gossip deliberately survives. The report and the discovery are
    -- collected by themselves at every login, so throwing them away costs
    -- nothing; a gossip dump exists because somebody walked to an NPC and
    -- asked for it. Losing that to a toggled switch is not a tidy-up, it is a
    -- measurement thrown away. /fplus gossip forget is the way out.
    --
    -- FP.global.unitProbe survives for the same reason: somebody had to walk
    -- into a fight for it.
    if self.blocked   then self.blocked:UnregisterAllEvents()   end
    if self.probe     then self.probe:UnregisterAllEvents()     end
    if self.chatProbe then self.chatProbe:UnregisterAllEvents() end
end

--- Writes the live report into the saved settings, on request.
function M:Persist()
    FP.global.diagnostics = self.report
    FP.global.discovery   = self.discovery
end

--- Takes it back out again.
function M:Forget()
    FP.global.diagnostics = nil
    FP.global.discovery   = nil
end

-- ---------------------------------------------------------------------------
-- What is behind a link
--
-- Shift clicking a spell, a talent or an item drops a link into the chat box,
-- and inside that link is the id. The player sees "[Water Shield]"; the
-- command sees the escape sequence it is made of, and the id is the one thing
-- in there worth having.
--
-- This is how a number that only exists on this build gets written down.
-- Research proposes ids, the client confirms them, and for something that no
-- database knows, this is the only route there is: Water Shield is not in
-- Classic at all, and a Shaman who cannot learn it yet for another ten levels
-- still has it sitting in the talent tree, linkable.
--
-- An item prints the spell it casts as well, because that is the number
-- Data/Consumables.lua is keyed by and the one nobody can read off a tooltip.
-- ---------------------------------------------------------------------------

local function Describe(kind, id)
    id = tonumber(id)
    if not id then return end

    if kind == "spell" or kind == "talent" or kind == "enchant" then
        local name = FP:SpellName(id)
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffffff%-7s %-8d|r %s", kind, id, name or "the client does not know it"))
        if name then
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "  |cff888888%s|r", "{ " .. id .. ", -- " .. name .. " }"))
        end
        return
    end

    if kind == "item" then
        local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
        local out = get and { pcall(get, id) } or {}
        local name, reqLevel = out[2], out[6]

        local spellId
        local spell = C_Item and C_Item.GetItemSpell
        if spell then
            local ok, _, found = pcall(spell, id)
            if ok then spellId = found end
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "  |cffffffffitem    %-8d|r %s, level %s, casts %s",
            id, name or "not cached yet", tostring(reqLevel or "?"),
            tostring(spellId or "nothing")))

        -- The line as the table wants it, so it can be read straight across.
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cff888888%s|r",
            string.format('{ item = %d,%s name = "%s" },', id,
                spellId and (" spell = " .. spellId .. ",") or "",
                name or "?")))
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "  |cffffffff%-7s %-8d|r no idea what that is, tell the assistant", kind, id))
end

--- Reads every link in what was typed, and any bare numbers beside them.
function M:Identify(text)
    text = text or ""

    local hits = 0
    for kind, id in text:gmatch("|H(%a+):(%d+)") do
        hits = hits + 1
        Describe(kind, id)
    end

    if hits == 0 then
        -- No link, so a number typed by hand. It could be either, and saying
        -- so is cheaper than guessing.
        for id in text:gmatch("%d+") do
            hits = hits + 1
            Describe("spell", id)
            Describe("item", id)
        end
    end

    if hits == 0 then
        FP:Print("Type /fplus id and then shift click a spell, a talent or an "
              .. "item into the chat box.")
    end
end
