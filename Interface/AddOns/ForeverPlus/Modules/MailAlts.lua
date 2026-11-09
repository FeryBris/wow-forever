-- Your own characters as mail recipients.
--
-- Asked for on CurseForge on 2026-09-27 and gated with the owner on 2026-09-29.
-- The client's recipient field already suggests the account's characters, the
-- owner checked, but among every stranger nearby, so the question he answered
-- was not whether but how: **a small button at the end of the field** opens a
-- list of this account's characters on the same realm and faction, with class
-- color and level, and a click writes the name in. The client's own
-- suggestions are left exactly as they are. On by default.
--
-- **The name is first name and surname**, "Sleepi Joe", the owner's answer to
-- what the mail window wants on WoW Forever, and exactly what UnitName hands
-- back as two values on build 70009.
--
-- Nothing on the client lists an account's characters, so the list is what
-- the addon has met: every character is recorded at login here, whether the
-- module is on or off, and the info bar's gold records fill in the ones that
-- have not logged in since, see Known below. FP:ForgetCharacter removes both,
-- and the X at the end of each row in the list asks for it.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("MailAlts", {
    title   = L["Alts in the Mail Window"],
    default = true,
    desc    = L["Adds a button to the mail window that lists your characters of "
           .. "this ruleset and faction, and fills in the one you pick."],
    group   = "npc",
    order   = 40,
})

-- ---------------------------------------------------------------------------
-- Who this account has
-- ---------------------------------------------------------------------------

local function Plain(value) return FP:Plain(value) end

--- The name the mail window wants: both values UnitName returns, joined.
local function FullName()
    if type(UnitName) ~= "function" then return nil end
    local ok, first, second = pcall(UnitName, "player")
    first  = ok and Plain(first)
    second = ok and Plain(second)
    if not first then return nil end
    return second and (first .. " " .. second) or first
end

local function Realm()
    if type(GetRealmName) ~= "function" then return nil end
    local ok, realm = pcall(GetRealmName)
    return ok and Plain(realm) or nil
end

--- "Horde" or "Alliance". A token, the same kind of word as a class token, so
--- comparing it is allowed.
local function Faction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    local ok, token = pcall(UnitFactionGroup, "player")
    return ok and Plain(token) or nil
end

--- The number of the ruleset this character plays, see FP:GoldCounts: mail
--- does not go between two of them.
local function Ruleset()
    return FP.Ruleset and FP:Ruleset() or nil
end

local function Level(value)
    local ok, level = pcall(function()
        return type(value) == "number" and value + 0 or nil
    end)
    return ok and level or nil
end

local function Store()
    if type(FP.global) ~= "table" then return nil end
    if type(FP.global.characters) ~= "table" then FP.global.characters = {} end
    return FP.global.characters
end

--- Writes this character down, or updates it. `level` overrides the read,
--- because PLAYER_LEVEL_UP arrives before UnitLevel has caught up.
local function Record(level)
    local key, store = FP:CharacterKey(), Store()
    if not (key and store) then return end

    local entry = type(store[key]) == "table" and store[key] or {}
    -- The token, the second value after pcall's own: the first is the display
    -- name, which the locale rule keeps out of anything compared or stored.
    local okClass, _, class = pcall(UnitClass, "player")
    local okLevel, current  = pcall(UnitLevel, "player")
    entry.name    = FullName() or entry.name
    entry.realm   = Realm() or entry.realm
    entry.faction = Faction() or entry.faction
    entry.mode    = Ruleset() or entry.mode
    entry.class   = (okClass and Plain(class)) or entry.class
    entry.level   = Level(level) or (okLevel and Level(current)) or entry.level
    store[key] = entry
end

-- Registered at load and never taken off: the record is kept whether the
-- module is on or not, see the head of this file. PLAYER_ENTERING_WORLD rather
-- than PLAYER_LOGIN because the faction of a brand new character can arrive a
-- moment late, and a loading screen costs one table write.
local recorder = CreateFrame("Frame")
recorder:RegisterEvent("PLAYER_ENTERING_WORLD")
recorder:RegisterEvent("PLAYER_LEVEL_UP")
recorder:SetScript("OnEvent", function(_, event, level)
    FP:Safe("MailAlts:Record", Record, event == "PLAYER_LEVEL_UP" and level or nil)
end)

-- ---------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------

local function ClassColored(text, token)
    local colors = _G.RAID_CLASS_COLORS
    local color = type(colors) == "table" and token and colors[token]
    local code = type(color) == "table" and Plain(color.colorStr)
    if code then return "|c" .. code .. text .. "|r" end
    return text
end

--- Every character this addon has met, by key: its own records first, and
--- the info bar's gold records for the rest.
--
-- The gold records are the older list, kept since 0.7.1 under the same guid,
-- and they already name most of an account. The owner's report on the day
-- this module arrived: a button that said nobody was known, next to a gold
-- list naming five characters. What they lack is the faction and the level,
-- which the character's next login fills in here.
local function Known()
    local all = {}
    local gold = type(FP.global) == "table" and FP.global.gold
    for key, entry in pairs(type(gold) == "table" and gold or {}) do
        if type(entry) == "table" and Plain(entry.name) then
            all[key] = { name = entry.name, realm = entry.realm, class = entry.class }
        end
    end
    for key, entry in pairs(Store() or {}) do
        if type(entry) == "table" and Plain(entry.name) then all[key] = entry end
    end
    return all
end

--- Every other character on this realm and faction, as list entries.
--
-- A character whose faction is not known yet, one only the gold list has
-- seen, is listed rather than hidden: the realm already matched, and leaving
-- it out would bring back the empty list this was written to end.
function M:Choices()
    local mine = FP:CharacterKey()
    local realm, faction, mode = Realm(), Faction(), Ruleset()
    local out = {}
    for key, entry in pairs(Known()) do
        -- And of the same ruleset since 2026-10-13, where both are known: the
        -- client refuses mail between two of them, see FP:GoldCounts.
        if key ~= mine and entry.realm == realm
           and (entry.faction == nil or faction == nil or entry.faction == faction)
           and (entry.mode == nil or mode == nil or entry.mode == mode) then
            out[#out + 1] = { key = key, entry = entry }
        end
    end
    table.sort(out, function(a, b) return a.entry.name < b.entry.name end)

    local values = {}
    for _, found in ipairs(out) do
        local key, entry = found.key, found.entry
        local label = ClassColored(entry.name, entry.class)
        if entry.level then
            label = label .. " |cff888888" .. entry.level .. "|r"
        end
        -- The X at the end of the row, asked for on CurseForge on 2026-10-03.
        -- The character being played is never in this list, so every row may
        -- carry one. The gold list deletes the same way, and a delete in
        -- either takes the character out of both.
        values[#values + 1] = { entry.name, label, onDelete = function()
            FP:AskToForgetCharacter(key, ClassColored(entry.name, entry.class))
        end }
    end
    return values
end

-- ---------------------------------------------------------------------------
-- The button
-- ---------------------------------------------------------------------------

local function Fill(name)
    local box = _G.SendMailNameEditBox
    if not box then return end
    box:SetText(name)
    -- On to the subject, the way a Tab from the name field would go.
    local subject = _G.SendMailSubjectEditBox
    if subject and subject.SetFocus then subject:SetFocus() end
end

--- Built the first time the mail window opens with the module on. The field
--- belongs to Blizzard_MailFrame, which loads with the interface on this
--- build, but asking at that moment rather than at load costs nothing and
--- survives it ever becoming load on demand.
function M:Build()
    if self.button then return self.button end
    local box = _G.SendMailNameEditBox
    if not box then return nil end

    -- Hand-built and without a template, like every widget of ours, in the
    -- addon's own look. Square, with the addon's icon, so it says whose it is
    -- without a word: the field leaves room for about twenty units before the
    -- postage label.
    local b = FP:CreateButton(box, "", 22)
    b:SetWidth(22)
    b:SetPoint("LEFT", box, "RIGHT", 2, 0)
    local path = FP:AddonIcon()
    if path then
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(path)
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
    else
        b.label:SetText("+")
    end

    b:SetScript("OnClick", function(button)
        local values = M:Choices()
        if #values == 0 then
            FP:Print(L["No other character of this ruleset and faction is known "
                .. "yet. Each one is added the next time it logs in."])
            return
        end
        FP:OpenList(button, values, Fill)
    end)
    FP:Tooltip(b, L["Your Characters"],
        L["Your characters of this ruleset and faction. A click fills in the "
        .. "name, the X at the end of a row deletes the character."])

    self.button = b
    return b
end

function M:OnEnable()
    self.watcher = self.watcher or CreateFrame("Frame")
    self.watcher:SetScript("OnEvent", function()
        local b = FP:Safe("MailAlts:Build", M.Build, M) and M.button
        if b then b:Show() end
    end)
    self.watcher:RegisterEvent("MAIL_SHOW")
    if self.button then self.button:Show() end
end

function M:OnDisable()
    if self.watcher then self.watcher:UnregisterAllEvents() end
    if self.button then self.button:Hide() end
end
