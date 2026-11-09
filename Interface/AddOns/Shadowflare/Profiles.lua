-- Shadowflare: profiles (save as, rename, delete, export, import) and copying one proc's
-- look onto another. Nothing is ever replaced without asking.
local _, ns = ...
local L = ns.L

local floor, min, max, type, pairs = math.floor, math.min, math.max, type, pairs
local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil

local function deep(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = deep(x) end
    return t
end

local function refreshOptions()
    if ns.Options and ns.Options.Refresh then ns.Options:Refresh() end
end

----------------------------------------------------------------------
-- Switching profile: settings, then everything on screen
----------------------------------------------------------------------
function ns.SwitchProfile(name)
    if ns.moving then ns.Display:SetMoving(false) end
    ns.UseProfile(name)
    ns.FirstSight()
    ns.SyncGameAlert()   -- the game's alert follows this profile (player's own class)
    for _, a in pairs(ns.Display.alerts) do
        pcall(a.ApplyPosition, a)
        pcall(a.ApplyLook, a)
    end
    if ns.playerClass then ns.Display:Prepare(ns.playerClass) end
    if ns.AuraShow then ns.AuraShow.ApplyAll() end   -- alerts the game shows itself
    ns.Refresh()
    refreshOptions()
end

-- One proc's look (style, color, size, angle, sound, place, time left) onto the chosen one
function ns.CopyLook(from)
    local to = ns.Selected()
    if from == to or not ns.PROC_BY[from] then return end
    local src, dst = ns.Cfg(from), ns.Cfg(to)
    for k, v in pairs(src) do
        -- "Show from N stacks" is how the proc works, not its look: it stays as it was
        if k ~= "enabled" and k ~= "enabledByUser" and k ~= "fromStacks" then dst[k] = deep(v) end
    end
    dst.custom = deep(src.custom)
    local gameAlert = ns.PROC_BY[to].gameAlert
    if dst.soundChoice == "game" and not gameAlert then dst.soundChoice = "power" end
    if ns.PROC_BY[to].gameSoundOnly then dst.soundChoice = "game" end
    if gameAlert then ns.SyncGameAlert() end
    local a = ns.Display:Get(to)
    a:ApplyPosition()
    a:ApplyLook()
    ns.Print(L.COPIED:format(ns.Info(from).name, ns.Info(to).name))
    refreshOptions()
end

-- The selected alert's look given to every other alert of its class (0.23.25, Ben). Only that
-- class (or group: weapons, enchants). Each alert keeps where it is and how it works: its place
-- on screen (and its time left's and stack number's), whether it is on, its sound, "Only in
-- combat", "Show from" and how long it stays. The stack look goes only between procs with stacks.
local KEEP_OWN = { enabled = true, enabledByUser = true, x = true, y = true, tox = true, toy = true, sox = true, soy = true,
    soundChoice = true, onlyCombat = true, fromStacks = true, showFor = true, otherStances = true }
local STACK_LOOK = { stackLook = true, stackNum = true, stackSize = true, fillHide = true }
function ns.ClassMates(key)
    local p0 = ns.PROC_BY[key]
    local t = {}
    if not p0 then return t end
    for _, p in ipairs(ns.PROCS) do
        if p.class == p0.class and p.key ~= key then t[#t + 1] = p.key end
    end
    return t
end
function ns.ApplyLookToClass(from)
    local p0 = ns.PROC_BY[from]
    if not p0 then return 0 end
    local src = ns.Cfg(from)
    local n = 0
    for _, to in ipairs(ns.ClassMates(from)) do
        local p, dst = ns.PROC_BY[to], ns.Cfg(to)
        for k, v in pairs(src) do
            if not KEEP_OWN[k] and (not STACK_LOOK[k] or (p0.stacks and p.stacks)) then dst[k] = deep(v) end
        end
        if src.custom then dst.custom = deep(src.custom) end
        local a = ns.Display:Get(to)
        a:ApplyPosition()
        a:ApplyLook()
        n = n + 1
    end
    ns.Print(L.SAME_LOOK_DONE:format(ns.Info(from).name, n))
    refreshOptions()
    return n
end

----------------------------------------------------------------------
-- Profile text: a small table written as text, then base64 so it pastes anywhere.
-- Read back by hand (never run as code), and every value is checked before use.
----------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_AT = {}
for i = 1, 64 do B64_AT[B64:byte(i)] = i - 1 end

local function encode64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = floor(n / 262144) % 64, floor(n / 4096) % 64, floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function decode64(s)
    s = s:gsub("[^%w%+/]", "")
    local out, char = {}, string.char
    for i = 1, #s, 4 do
        local v1, v2, v3, v4 = B64_AT[s:byte(i)], B64_AT[s:byte(i + 1) or 0], B64_AT[s:byte(i + 2) or 0], B64_AT[s:byte(i + 3) or 0]
        if not (v1 and v2) then break end
        local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
        out[#out + 1] = char(floor(n / 65536) % 256)
        if v3 then out[#out + 1] = char(floor(n / 256) % 256) end
        if v4 then out[#out + 1] = char(n % 256) end
    end
    return table.concat(out)
end

local function write(v, out)
    local t = type(v)
    if t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "number" then out[#out + 1] = "n" .. ("%.6g"):format(v) .. ";"
    elseif t == "boolean" then out[#out + 1] = v and "t" or "f"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local kt, xt = type(k), type(x)
            if (kt == "string" or kt == "number") and (xt == "string" or xt == "number" or xt == "boolean" or xt == "table") then
                write(k, out); write(x, out)
            end
        end
        out[#out + 1] = "}"
    end
end

local function read(s, i, depth)
    local c = s:sub(i, i)
    if c == "s" then
        local colon = s:find(":", i + 1, true)
        local len = colon and tonumber(s:sub(i + 1, colon - 1))
        if not len or len < 0 or colon + len > #s then error("bad string") end
        return s:sub(colon + 1, colon + len), colon + len + 1
    elseif c == "n" then
        local semi = s:find(";", i + 1, true)
        local v = semi and tonumber(s:sub(i + 1, semi - 1))
        if not v or v ~= v then error("bad number") end
        return v, semi + 1
    elseif c == "t" then return true, i + 1
    elseif c == "f" then return false, i + 1
    elseif c == "{" then
        if depth > 4 then error("too deep") end
        local t, n = {}, 0
        i = i + 1
        while s:sub(i, i) ~= "}" do
            if i > #s then error("cut short") end
            local k, v
            k, i = read(s, i, depth + 1)
            if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
            v, i = read(s, i, depth + 1)
            t[k] = v
            n = n + 1
            if n > 200 then error("too long") end
        end
        return t, i + 1
    end
    error("bad text")
end

-- What a proc's settings may hold, and the range of each number
local FIELDS = {
    enabled = "boolean", enabledByUser = "boolean", style = "string", color = "string", custom = "color",
    scale = { 0.4, 3 }, alpha = { 0.2, 1 }, shadow = { 0, 1 }, onlyCombat = "boolean", rotation = { 0, 345 }, timerSize = { 10, 60 },
    x = { -4000, 4000 }, y = { -4000, 4000 }, tox = { -4000, 4000 }, toy = { -4000, 4000 },
    timer = "boolean", timerFree = "boolean", timerAlign = "string", font = "font", edges = "boolean", edgesOnly = "boolean", tintClassic = "boolean",
    anim = "string", noEntrance = "boolean", spacing = { -30, 200 }, side = "string", otherStances = "boolean", noneTime = "boolean", noneDots = "boolean",
    soundChoice = "sound",
    -- procs with stacks (0.18.0)
    fromStacks = { 1, 5 }, stackLook = "string", showFor = { 2, 10 }, stackNum = "boolean", fillHide = "boolean", stackSize = { 10, 60 }, sox = { -4000, 4000 }, soy = { -4000, 4000 },
}
local function validSound(v)
    if v == "none" or v == "game" then return true end
    for _, s in ipairs(ns.SOUNDS) do if s.key == v then return true end end
end
local function validColor(v)
    if v == "custom" then return true end
    for _, c in ipairs(ns.COLORS) do if c.key == v then return true end end
end

local function cleanProc(t, key)
    local c = {}
    for k, kind in pairs(FIELDS) do
        local v = t[k]
        if kind == "boolean" then
            if type(v) == "boolean" then c[k] = v end
        elseif kind == "string" then
            if type(v) == "string" and #v <= 40 and v:match("^[%w_]+$") then c[k] = v end
        elseif kind == "font" then
            -- "game", a game font, or a font shared by another addon (its name, 60 letters at most)
            if type(v) == "string" and #v <= 64 and not v:find("[|\n\r]") then c[k] = v end
        elseif kind == "sound" then
            if type(v) == "string" and validSound(v) then c[k] = v end
        elseif kind == "color" then
            if type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number" then
                c[k] = { min(1, max(0, v[1])), min(1, max(0, v[2])), min(1, max(0, v[3])) }
            end
        elseif type(kind) == "table" then
            if type(v) == "number" then c[k] = min(kind[2], max(kind[1], v)) end
        end
    end
    if c.color and not validColor(c.color) then c.color = nil end
    if c.timerAlign and c.timerAlign ~= "left" and c.timerAlign ~= "right" and c.timerAlign ~= "center" then c.timerAlign = nil end
    if c.color == "custom" and not c.custom then c.color = nil end
    if c.soundChoice == "game" and not ns.PROC_BY[key].gameAlert then c.soundChoice = "power" end
    return c
end

local PREFIX = "SF1:"

function ns.ExportProfile()
    for _, p in ipairs(ns.PROCS) do ns.Cfg(p.key) end   -- every proc, with its defaults
    local out = {}
    write({ v = 1, name = ns.profileName, procs = ns.procs }, out)
    return PREFIX .. encode64(table.concat(out))
end

-- Returns name, procs; or nil when the text is not a Shadowflare profile
function ns.ReadProfile(text)
    if type(text) ~= "string" then return end
    text = text:gsub("%s", "")
    if text:sub(1, #PREFIX) ~= PREFIX or #text > 60000 then return end
    local ok, data = pcall(function()
        local raw = decode64(text:sub(#PREFIX + 1))
        local t, nxt = read(raw, 1, 0)
        if nxt ~= #raw + 1 then error("extra") end
        return t
    end)
    if not ok or type(data) ~= "table" or type(data.procs) ~= "table" then return end
    local procs, any = {}, false
    for key, t in pairs(data.procs) do
        if ns.PROC_BY[key] and type(t) == "table" then
            procs[key] = cleanProc(t, key)
            any = true
        end
    end
    if not any then return end
    local name = type(data.name) == "string" and data.name or nil
    return name, procs
end

----------------------------------------------------------------------
-- The dialog: looks like the game's own pop-ups, with an optional text box
----------------------------------------------------------------------
local dlg

local function buildDialog()
    local f = CreateFrame("Frame", "ShadowflareProfileDialog", UIParent, BACKDROP)
    f:SetSize(420, 150)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(110)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -20)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    f.text:SetWidth(370)
    local eb = CreateFrame("EditBox", "ShadowflareProfileDialogEdit", f, "InputBoxTemplate")
    eb:SetSize(340, 20)
    eb:SetAutoFocus(false)
    eb:SetPoint("TOP", f.text, "BOTTOM", 0, -10)
    f.edit = eb
    f.err = f:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    f.err:SetWidth(370)
    f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.ok:SetSize(120, 22)
    f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancel:SetSize(120, 22)
    f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 18)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    f.ok:SetScript("OnClick", function()
        local req = f.req
        if not req then f:Hide() return end
        local err = req.onOk and req.onOk(eb:GetText())
        if err then f.err:SetText(err); f.err:Show() return end
        if f.req == req then f:Hide() end   -- unless it went on to another question
    end)
    eb:SetScript("OnEnterPressed", function() f.ok:Click() end)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnTextChanged", function(self, user)
        local req = f.req
        if user and req and req.readOnly then self:SetText(req.value or ""); self:HighlightText() end
        if user and f.err:IsShown() then f.err:Hide() end
    end)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f:SetScript("OnHide", function() f.req = nil; eb:ClearFocus() end)
    table.insert(UISpecialFrames, "ShadowflareProfileDialog") -- Escape closes it
    f:Hide()
    return f
end

-- o: title, text, edit (true for a text box), value, readOnly, maxLetters,
--    okText, cancelText (false: one button only), onOk(text) -> an error to show, or nil
function ns.Ask(o)
    dlg = dlg or buildDialog()
    local f, eb = dlg, dlg.edit
    f.req = o
    f.title:SetText(o.title or "Shadowflare")
    f.text:SetText(o.text or "")
    f.err:Hide()
    local h = 20 + 14 + 8 + f.text:GetStringHeight()
    f.err:ClearAllPoints()
    if o.edit then
        eb:Show()
        eb:SetMaxLetters(o.maxLetters or 0)
        eb:SetText(o.value or "")
        f.err:SetPoint("TOP", eb, "BOTTOM", 0, -6)
        h = h + 10 + 20
    else
        eb:Hide()
        f.err:SetPoint("TOP", f.text, "BOTTOM", 0, -8)
    end
    h = h + 22 + 22 + 18 + 8
    f:SetHeight(h)
    f.ok:SetText(o.okText or OKAY or "OK")
    f.ok:ClearAllPoints()
    if o.cancelText == false then
        f.cancel:Hide()
        f.ok:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
    else
        f.cancel:Show()
        f.cancel:SetText(o.cancelText or CANCEL or L.CANCEL)
        f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18)
    end
    f:Show()
    f:Raise()
    if o.edit then
        eb:SetFocus()
        eb:HighlightText()
        if eb.SetCursorPosition and not o.readOnly then eb:SetCursorPosition(#(o.value or "")) eb:HighlightText() end
    end
end

----------------------------------------------------------------------
-- Profile actions (the buttons of the options page)
----------------------------------------------------------------------
local function cleanName(t)
    t = (t or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if t == "" then return nil end
    if #t > 32 then t = t:sub(1, 32) end
    return t
end

local function freeName(base)
    base = cleanName(base) or L.PROFILE_DEFAULT
    if not ns.db.profiles[base] then return base end
    for i = 2, 99 do
        local n = base .. " " .. i
        if not ns.db.profiles[n] then return n end
    end
    return base
end

-- Saves settings under a name and switches to it; asks before replacing another profile
local function saveNamed(name, procs)
    local function go()
        ns.db.profiles[name] = { procs = procs, anim023 = true, anim0232 = true, ab0234 = true }
        ns.SwitchProfile(name)
    end
    if ns.db.profiles[name] then
        ns.Ask({ title = L.REPLACE_TITLE, text = L.REPLACE_TEXT:format(name),
            okText = L.OK_REPLACE, onOk = function() go() end })
        return
    end
    go()
end

function ns.ProfileSaveAs()
    local cur = ns.profileName
    ns.Ask({ title = L.SAVE_AS_TITLE, text = L.SAVE_AS_TEXT:format(cur, cur), edit = true,
        value = freeName(cur), maxLetters = 32, okText = L.OK_SAVE,
        onOk = function(t)
            local n = cleanName(t)
            if not n then return L.NAME_EMPTY end
            saveNamed(n, deep(ns.procs))
        end })
end

function ns.ProfileRename()
    local cur = ns.profileName
    ns.Ask({ title = L.RENAME_TITLE, text = L.RENAME_TEXT:format(cur), edit = true, value = cur,
        maxLetters = 32, okText = L.OK_RENAME,
        onOk = function(t)
            local n = cleanName(t)
            if not n then return L.NAME_EMPTY end
            if n == cur then return end
            if ns.db.profiles[n] then return L.NAME_TAKEN end
            local db = ns.db
            db.profiles[n], db.profiles[cur] = db.profiles[cur], nil
            for ck, pn in pairs(db.chars) do if pn == cur then db.chars[ck] = n end end
            if db.defaultProfile == cur then db.defaultProfile = n end
            ns.UseProfile(n)
            refreshOptions()
        end })
end

function ns.ProfileDelete()
    local cur, db = ns.profileName, ns.db
    local names = ns.ProfileNames()
    if #names < 2 then
        ns.Ask({ title = L.DELETE_TITLE, text = L.DELETE_LAST, okText = OKAY or "OK", cancelText = false })
        return
    end
    local nxt = (db.defaultProfile ~= cur and db.profiles[db.defaultProfile or ""]) and db.defaultProfile
    if not nxt then for _, n in ipairs(names) do if n ~= cur then nxt = n break end end end
    ns.Ask({ title = L.DELETE_TITLE, text = L.DELETE_TEXT:format(cur, nxt), okText = L.OK_DELETE,
        onOk = function()
            db.profiles[cur] = nil
            for ck, pn in pairs(db.chars) do if pn == cur then db.chars[ck] = nil end end
            if db.defaultProfile == cur then db.defaultProfile = nxt end
            ns.SwitchProfile(nxt)
        end })
end

function ns.ProfileExport()
    local text = ns.ExportProfile()
    ns.Ask({ title = L.EXPORT_TITLE:format(ns.profileName), text = L.EXPORT_TEXT, edit = true,
        value = text, readOnly = true, okText = CLOSE or L.CLOSE, cancelText = false })
end

function ns.ProfileImport()
    ns.Ask({ title = L.IMPORT_TITLE, text = L.IMPORT_TEXT, edit = true, value = "", okText = L.OK_IMPORT,
        onOk = function(t)
            local name, procs = ns.ReadProfile(t)
            if not procs then return L.IMPORT_BAD end
            ns.Ask({ title = L.IMPORT_NAME_TITLE, text = L.IMPORT_NAME_TEXT, edit = true,
                value = freeName(name or L.IMPORTED), maxLetters = 32, okText = L.OK_SAVE,
                onOk = function(t2)
                    local n = cleanName(t2)
                    if not n then return L.NAME_EMPTY end
                    saveNamed(n, procs)
                end })
        end })
end
