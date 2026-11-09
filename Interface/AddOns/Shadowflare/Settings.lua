-- Shadowflare: its own settings window (0.22.0, asked by Ben: the game's Options page was too
-- narrow, and players could not see what they were building).
--   left  : the classes, then the alerts of the chosen class, each with its on/off box
--   middle: the chosen alert, with four tabs (Style, Look, Stacks, Timer and sound)
--   right : a live preview of the alert as it will be, then its size and "Place on screen"
-- Built with the game's own templates (window, insets, buttons, boxes, sliders, menus, tabs),
-- each with a plain fallback, so it looks like the rest of the game's interface.
-- Nothing is made before the window first opens; nothing runs while it is closed.
local _, ns = ...
local L = ns.L

local S = {}
ns.Settings = S

local W, H = 1180, 720
local LEFT_W, MID_W = 252, 528
local RIGHT_W = W - 16 - LEFT_W - MID_W - 12
local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
local floor, min, max, abs = math.floor, math.min, math.max, math.abs

local win
local refreshers = {}       -- run on every refresh (a setting or the chosen alert changed)
local function OnRefresh(fn) refreshers[#refreshers + 1] = fn end
local function D() return ns.Display end

----------------------------------------------------------------------
-- Small builders, all on the game's templates
----------------------------------------------------------------------
local function Tip(owner, title, text)
    owner:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function Text(parent, font, text, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

-- A dark panel of the game (the same as in the character and collection windows)
local function Inset(parent, x, y, w, h)
    local ok, f = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
    if not (ok and f) then
        f = CreateFrame("Frame", nil, parent, BACKDROP)
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            f:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
            f:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        end
    end
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetSize(w, h)
    return f
end

-- A gold title with the thin gold line under it (as the old Options page)
local function Section(parent, x, y, w, text)
    local fs = Text(parent, "GameFontNormal", text)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
    line:SetWidth(w)
    line:SetColorTexture(1, 0.82, 0, 0.28)
    return fs, line
end

local function Button(parent, text, w, h, onClick, tipTitle, tipText)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    if tipTitle then Tip(b, tipTitle, tipText) end
    return b
end

-- The chosen button of a row (0.23.11, asked by Ben: the chosen one was hard to see). The
-- chosen button: full colour, its glow kept on (the game's LockHighlight), white text and a
-- thin gold frame around it, like the chosen style card. The others: the same red button,
-- darker, with gold text. Nothing else changes (sizes, sounds, clicks).
local MARK_GOLD = { 1, 0.82, 0 }
local function ButtonParts(b)
    local t = {}
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do
        local r = b[k]
        if type(r) == "table" and r.SetVertexColor then t[#t + 1] = r end
    end
    if b.GetNormalTexture then
        local ok, nt = pcall(b.GetNormalTexture, b)
        if ok and type(nt) == "table" and nt.SetVertexColor then t[#t + 1] = nt end
    end
    return t
end
local function MarkFrame(b)
    if b.markFrame then return b.markFrame end
    local f = CreateFrame("Frame", nil, b)
    f:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)       -- 1 px out: clear of the next button
    f:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    pcall(f.SetFrameLevel, f, b:GetFrameLevel() + 2)
    local function edge(p1, p2, w, h)
        local e = f:CreateTexture(nil, "OVERLAY")
        e:SetColorTexture(MARK_GOLD[1], MARK_GOLD[2], MARK_GOLD[3], 1)
        e:SetPoint(p1); e:SetPoint(p2)
        if w then e:SetWidth(w) end
        if h then e:SetHeight(h) end
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 2)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
    edge("TOPLEFT", "BOTTOMLEFT", 2, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 2, nil)
    f:Hide()
    b.markFrame = f
    return f
end
local function Mark(b, on)
    b.marked = on and true or false
    if on then
        if b.LockHighlight then b:LockHighlight() end
        if b.SetNormalFontObject then pcall(b.SetNormalFontObject, b, "GameFontHighlight") end
    else
        if b.UnlockHighlight then b:UnlockHighlight() end
        if b.SetNormalFontObject then pcall(b.SetNormalFontObject, b, "GameFontNormal") end
    end
    local k = on and 1 or 0.55
    for _, r in ipairs(ButtonParts(b)) do pcall(r.SetVertexColor, r, k, k, k) end
    MarkFrame(b):SetShown(on and true or false)
end
S.Mark = Mark

-- A row of buttons where one is chosen (Mark above)
local function Segments(parent, x, y, list, get, set, w, h)
    local made = {}
    local cx = x
    for i, o in ipairs(list) do
        local b = Button(parent, o.text, o.w or w, h or 22, function() set(o.value) end, o.tip and o.text, o.tip)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, y)
        b.value = o.value
        cx = cx + (o.w or w) + 2
        made[i] = b
    end
    local function paint()
        local v = get()
        for _, b in ipairs(made) do
            Mark(b, b.value == v)
        end
    end
    OnRefresh(paint)
    made.paint = paint
    return made
end

local function Check(parent, x, y, label, tip, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local fs = Text(parent, "GameFontHighlight", label)
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.label = fs
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    if tip then Tip(cb, label, tip) end
    OnRefresh(function() cb:SetChecked(get() and true or false) end)
    return cb
end

-- Slider (the game's current one with its arrows, the older one as a fallback)
local function Slider(parent, x, y, label, tip, minV, maxV, step, key, show, width)
    local lab = Text(parent, "GameFontHighlight", label)
    lab:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
    if tip then
        local hit = CreateFrame("Frame", nil, parent)
        hit:SetPoint("TOPLEFT", lab, "TOPLEFT", -2, 2)
        hit:SetSize(120, 18)
        hit:EnableMouse(true)
        Tip(hit, label, tip)
    end
    width = width or 220
    local value = Text(parent, "GameFontHighlightSmall")
    local function cur() return ns.Cur()[key] or minV end
    local function fmt(v) return show and show(v) or ("%d%%"):format(floor(v * 100 + 0.5)) end
    local busy = false
    local function change(v)
        if busy then return end
        v = floor(v / step + 0.5) * step
        if abs(cur() - v) < 0.001 then return end
        value:SetText(fmt(v))
        ns.SetOption(key, v)
    end
    local ok, sl = pcall(CreateFrame, "Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    if ok and sl and sl.Init then
        sl:SetSize(width, 20)
        sl:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 130, y)
        sl:Init(cur(), minV, maxV, (maxV - minV) / step)
        if sl.RegisterCallback and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
            sl:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v) change(v) end, sl)
        end
        OnRefresh(function()
            busy = true
            if sl.SetValue then pcall(sl.SetValue, sl, cur()) end
            busy = false
            value:SetText(fmt(cur()))
        end)
    else
        sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        sl:SetSize(width - 20, 16)
        sl:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 140, y - 2)
        sl:SetMinMaxValues(minV, maxV)
        sl:SetValueStep(step)
        if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
        for _, part in ipairs({ "Low", "High", "Text" }) do
            local fs = sl[part] or _G[(sl:GetName() or "") .. part]
            if fs then fs:SetText("") end
        end
        sl:SetScript("OnValueChanged", function(_, v) change(v) end)
        OnRefresh(function() busy = true; sl:SetValue(cur()); busy = false; value:SetText(fmt(cur())) end)
    end
    value:SetPoint("LEFT", sl, "RIGHT", 10, 0)
    return sl, lab, value
end

-- Menu (the game's current dropdown). Falls back to a button that goes through the choices.
local function Menu(parent, w, options, get, set)
    local ok, dd = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dd and dd.SetupMenu then
        dd:SetWidth(w)
        dd:SetupMenu(function(_, root)
            local list = options()
            -- a long list (fonts from other addons) scrolls instead of leaving the screen
            if #list > 20 and root.SetScrollMode then pcall(root.SetScrollMode, root, 20 * 20) end
            for _, o in ipairs(list) do
                root:CreateRadio(o.text, function(v) return get() == v end, function(v) set(v) end, o.value)
            end
        end)
        OnRefresh(function() if dd.GenerateMenu then pcall(dd.GenerateMenu, dd) end end)
        return dd
    end
    local b = Button(parent, "", w, 22)
    local function show()
        for _, o in ipairs(options()) do if o.value == get() then b:SetText(o.text) end end
    end
    b:SetScript("OnClick", function()
        local list, cur = options(), 1
        for i, o in ipairs(list) do if o.value == get() then cur = i end end
        local nxt = list[cur % #list + 1]
        if nxt then set(nxt.value) end
        show()
    end)
    OnRefresh(show)
    return b
end

local function ClassName(c, plain)
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or L["CL_" .. c] or c
    if plain then return name end
    local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    if col and col.colorStr then name = "|c" .. col.colorStr .. name .. "|r" end
    return name
end
S.ClassName = ClassName

-- The icon of a class (the game's class icons), or of the weapons and enchants sections
local GEAR_ICONS = { WEAPONS = "Interface\\Icons\\INV_Mace_04", ENCHANTS = "Interface\\Icons\\Trade_Engraving" }
local function ClassIcon(tex, c)
    if GEAR_ICONS[c] then
        tex:SetTexture(GEAR_ICONS[c]); tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        return
    end
    local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c]
    if tc then
        tex:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        tex:SetTexCoord(tc[1] + 0.008, tc[2] - 0.008, tc[3] + 0.008, tc[4] - 0.008)
    else
        local n = c:sub(1, 1) .. c:sub(2):lower()
        tex:SetTexture("Interface\\Icons\\ClassIcon_" .. n)
    end
end

-- The procs of a class, in the order of the list
local function ProcsOf(class)
    local t = {}
    for _, p in ipairs(ns.PROCS) do if p.class == class then t[#t + 1] = p end end
    return t
end
S.ProcsOf = ProcsOf

local function SpecText(p)
    local t = L["SPEC_" .. p.spec] or p.spec
    if p.stacks then t = t .. " - " .. L.STACKS_N:format(p.stacks) end
    if p.mode == "aura" then t = t .. " - " .. L.BY_GAME end
    return t
end

----------------------------------------------------------------------
-- Drawing an alert the way it is on screen, for the preview and its thumbnails.
-- A "set" is one style built for one proc: { box, s (the style), P, clip, copy, dots }.
----------------------------------------------------------------------
local function NewSet(parent, key, style, scale)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(260, 220)
    box:SetPoint("CENTER", parent, "CENTER", 0, 0)
    if scale then box:SetScale(scale) end
    local f = CreateFrame("Frame", nil, box)
    f:SetAllPoints()
    local P = ns.Info(key)
    local ok, s = pcall(D().Build, f, style, P)
    if not ok then box:Hide() return nil end
    return { box = box, s = s, P = P }
end

local function Blank(s)
    if s.SetTime then s.SetTime("") elseif s.timer then s.timer:SetText("") end
end

-- Colors, turn, shadow and names of a set from the proc's settings
local function Dress(h, cfg)
    local s = h.s
    if s.Refresh then pcall(s.Refresh) end
    local r, g, b = D().Color(cfg)
    pcall(s.SetColor, r, g, b, cfg.tintClassic)
    D().Rotate(s, cfg.rotation, D().SpacingOf(cfg))
    D().ApplySides(s, cfg)
    pcall(D().ApplyFont, s, cfg.font)
end

-- The look below the maximum at k stacks out of m (the same rules as the alert itself)
local function PaintLook(h, look, k, m, p, cfg)
    local Dx, s = D(), h.s
    local partial = k < m
    local fill = partial and (look == "fillup" or look == "fillleft")
    local base = 1
    if look == "dim" and partial and not Dx.NoArt(cfg) then base = Dx.StackK(k, m, p.noDim)
    elseif fill then base = Dx.FaintOf(cfg) end
    s.frame:SetAlpha(base)
    h.base = base
    Dx.ApplySides(s, cfg)
    if fill then
        local clip = Dx.Clip(h, h.box, h.box:GetFrameLevel() + 6)
        local c = Dx.FillCopy(h, h.box, s, cfg, h.P)
        Dx.Preview(c, 1); Blank(c)
        Dx.PlaceClip(clip, h.box, s, look, 0, k / m)
        clip:Show()
        h.copy = c
    else
        if h.clip then h.clip:Hide() end
        h.copy = nil
    end
    if look == "dots" and p.stacks then
        local d = Dx.Dots(h, h.box)
        pcall(d.SetFrameLevel, d, h.box:GetFrameLevel() + 40)
        Dx.SetDots(d, h.box, s, m, 1, k, true, cfg)
    elseif h.dots then
        h.dots:Hide()
    end
end
S.PaintLook = PaintLook

----------------------------------------------------------------------
-- The window
----------------------------------------------------------------------
local function MakeWindow()
    local ok, f = pcall(CreateFrame, "Frame", "ShadowflareSettingsFrame", UIParent, "ButtonFrameTemplate")
    local modern = ok and f
    if not modern then
        ok, f = pcall(CreateFrame, "Frame", "ShadowflareSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
        if not (ok and f) then
            f = CreateFrame("Frame", "ShadowflareSettingsFrame", UIParent, BACKDROP)
            if f.SetBackdrop then
                f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 } })
            end
            local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -6, -6)
        end
    end
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true); f:EnableMouse(true)
    f:SetClampedToScreen(true)
    table.insert(UISpecialFrames, "ShadowflareSettingsFrame")   -- Escape closes it
    local function part(o, k) local v = o[k]; if type(v) == "table" then return v end end
    local inset = part(f, "Inset")
    if inset and inset.Hide then inset:Hide() end
    -- Title and portrait
    -- 0.23.1: the character these settings are for, by full name (first name and surname)
    local title = "Shadowflare"
    local me = ns.CharFullName and ns.CharFullName()
    if me then title = title .. " - " .. me end
    f.sfTitle = title
    local tc = part(f, "TitleContainer")
    if type(f.SetTitle) == "function" then pcall(f.SetTitle, f, title)
    elseif tc and part(tc, "TitleText") then tc.TitleText:SetText(title)
    elseif part(f, "TitleText") then f.TitleText:SetText(title)
    else local fs = Text(f, "GameFontNormal", title); fs:SetPoint("TOP", 0, -14) end
    local icon = "Interface\\Icons\\Spell_Fire_Fireball02"
    local pc = part(f, "PortraitContainer")
    if type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, icon)
    elseif pc and part(pc, "portrait") then
        if SetPortraitToTexture then pcall(SetPortraitToTexture, pc.portrait, icon) end
    elseif part(f, "portrait") and SetPortraitToTexture then pcall(SetPortraitToTexture, f.portrait, icon) end
    -- Dragged by its title bar
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", 60, 0)
    drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, 0)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:Hide()
    return f
end

----------------------------------------------------------------------
-- Top bar: the profile and its buttons, what's new, the version
----------------------------------------------------------------------
local function TopBar(f)
    local y = -32
    local lab = Text(f, "GameFontNormal", L.PROFILE)
    lab:SetPoint("TOPLEFT", f, "TOPLEFT", 68, y - 4)
    local dd = Menu(f, 170, function()
        local list = {}
        for _, n in ipairs(ns.ProfileNames()) do list[#list + 1] = { value = n, text = n } end
        return list
    end, function() return ns.profileName end, function(n)
        if n ~= ns.profileName then ns.SwitchProfile(n) end
    end)
    dd:SetPoint("TOPLEFT", f, "TOPLEFT", 68 + 60, y)
    -- The tooltip names the characters on this profile: full name, realm, class (0.23.1)
    dd:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.PROFILE, 1, 1, 1)
        GameTooltip:AddLine(L.PROFILE_TIP .. "\n" .. L.PROFILE_NOTE, nil, nil, nil, true)
        local chars = ns.ProfileChars(ns.profileName)
        if #chars > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.PROFILE_CHARS:format(ns.profileName))
            local mine = ns.CharKey()
            for _, c in ipairs(chars) do
                local line = c.label
                if c.class then line = line .. " (" .. ClassName(c.class) .. ")" end
                if c.key == mine then line = line .. " " .. L.PROFILE_YOU end
                GameTooltip:AddLine(line, 1, 1, 1)
            end
        end
        GameTooltip:Show()
    end)
    dd:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    local x = 68 + 60 + 178
    local del
    for _, o in ipairs({
        { L.SAVE_AS_BTN, 132, function() ns.ProfileSaveAs() end, L.SAVE_AS_TIP },
        { L.RENAME_BTN, 84, function() ns.ProfileRename() end },
        { L.DELETE_BTN, 84, function() ns.ProfileDelete() end },
        { L.EXPORT_BTN, 84, function() ns.ProfileExport() end, L.SHARE_TIP },
        { L.IMPORT_BTN, 84, function() ns.ProfileImport() end, L.SHARE_TIP },
    }) do
        local b = Button(f, o[1], o[2], 22, o[3], o[4] and o[1], o[4])
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
        x = x + o[2] + 4
        if o[1] == L.DELETE_BTN then del = b end
    end
    OnRefresh(function() del:SetEnabled(#ns.ProfileNames() > 1) end)
    local ver = Text(f, "GameFontDisableSmall", L.VERSION:format(ns.version))
    ver:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, y - 6)
    local notes = Button(f, L.NOTES_BTN, 110, 22, function() ns.ShowNotes(nil) end)
    notes:SetPoint("RIGHT", ver, "LEFT", -10, 0)
end

----------------------------------------------------------------------
-- Left: classes and the list of alerts
----------------------------------------------------------------------
local function LeftColumn(f)
    local col = Inset(f, 8, -62, LEFT_W, H - 62 - 8)
    S.left = col
    Section(col, 12, -10, LEFT_W - 24, L.H_ALERTS)
    -- Class icons, two rows of six
    local icons = {}
    for i, c in ipairs(ns.CLASSES) do
        local b = CreateFrame("Button", nil, col)
        b:SetSize(32, 32)
        local cx, cy = (i - 1) % 6, floor((i - 1) / 6)
        b:SetPoint("TOPLEFT", col, "TOPLEFT", 12 + cx * 38, -34 - cy * 38)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        ClassIcon(t, c)
        b.icon = t
        local ring = b:CreateTexture(nil, "OVERLAY")
        ring:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        ring:SetBlendMode("ADD")
        ring:SetPoint("TOPLEFT", -3, 3); ring:SetPoint("BOTTOMRIGHT", 3, -3)
        b.ring = ring
        local edge = b:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(1, 0.82, 0, 1)
        edge:SetPoint("TOPLEFT", -2, 2); edge:SetPoint("BOTTOMRIGHT", 2, -2)
        b.edge = edge
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetBlendMode("ADD"); hl:SetAllPoints()
        -- The player's own class: a small green dot
        local dot = b:CreateTexture(nil, "OVERLAY", nil, 7)
        dot:SetColorTexture(0.25, 0.85, 0.4, 1)
        dot:SetSize(7, 7)
        dot:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        b.dot = dot
        b.class = c
        b:SetScript("OnClick", function()
            local list = ProcsOf(c)
            if list[1] then ns.Select(list[1].key) end
        end)
        Tip(b, ClassName(c, true), c == ns.playerClass and L.YOUR_CLASS or nil)
        icons[i] = b
    end
    S.classIcons = icons
    local line = Text(col, "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", col, "TOPLEFT", 12, -112)
    line:SetWidth(LEFT_W - 24)
    -- The alerts of the class: up to 8 rows
    local rows = {}
    for i = 1, 7 do
        local r = CreateFrame("Button", nil, col)
        r:SetSize(LEFT_W - 16, 46)
        r:SetPoint("TOPLEFT", col, "TOPLEFT", 8, -132 - (i - 1) * 48)
        local sel = r:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(1, 0.82, 0, 0.13)
        local bar = r:CreateTexture(nil, "BORDER")
        bar:SetColorTexture(1, 0.82, 0, 0.9)
        bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
        r.sel, r.bar = sel, bar
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD"); hl:SetAllPoints(); hl:SetAlpha(0.5)
        local ic = r:CreateTexture(nil, "ARTWORK")
        ic:SetSize(32, 32)
        ic:SetPoint("LEFT", r, "LEFT", 8, 0)
        ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.icon = ic
        local name = Text(r, "GameFontHighlight")
        name:SetPoint("TOPLEFT", ic, "TOPRIGHT", 8, -1)
        name:SetPoint("RIGHT", r, "RIGHT", -34, 0)
        name:SetWordWrap(false)
        r.name = name
        local sub = Text(r, "GameFontDisableSmall")
        sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        sub:SetPoint("RIGHT", r, "RIGHT", -34, 0)
        sub:SetWordWrap(false)
        r.sub = sub
        local cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("RIGHT", r, "RIGHT", -4, 0)
        cb:SetScript("OnClick", function(self) if r.key then ns.SetEnabled(r.key, self:GetChecked()) end end)
        Tip(cb, L.ENABLED, L.ENABLED_TIP)
        r.cb = cb
        r:SetScript("OnClick", function() if r.key then ns.Select(r.key) end end)
        rows[i] = r
    end
    S.rows = rows
    local hint = Text(col, "GameFontDisableSmall", L.LIST_HINT)
    hint:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 12, 44)
    hint:SetWidth(LEFT_W - 24)
    -- What's new after an update (for the whole addon)
    local nb = CreateFrame("CheckButton", nil, col, "UICheckButtonTemplate")
    nb:SetSize(24, 24)
    nb:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 8, 76)
    local nl = Text(col, "GameFontHighlightSmall", L.OPT_NOTES)
    nl:SetPoint("LEFT", nb, "RIGHT", 2, 1)
    nl:SetWidth(LEFT_W - 50)
    nb:SetScript("OnClick", function(self) ns.db.showNotes = self:GetChecked() and true or false end)
    OnRefresh(function() nb:SetChecked(ns.db.showNotes and true or false) end)
    S.notesBox = nb
    -- The selected alert's look for the whole class (0.23.25)
    local same = Button(col, "", LEFT_W - 24, 24)
    same:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 12, 108)
    same:SetScript("OnClick", function()
        local key = ns.Selected()
        local mates = ns.ClassMates(key)
        if #mates == 0 then return end
        local class = ClassName(ns.PROC_BY[key].class, true)
        ns.Ask({ title = L.SAME_LOOK_TITLE, text = L.SAME_LOOK_ASK:format(ns.Info(key).name, #mates, class),
            okText = L.SAME_LOOK_OK, onOk = function() ns.ApplyLookToClass(key) end })
    end)
    same:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        local key = ns.Selected()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.SAME_LOOK_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.SAME_LOOK_TIP:format(ns.Info(key).name, ClassName(ns.PROC_BY[key].class, true)), nil, nil, nil, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.SAME_LOOK_COPIED, 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L.SAME_LOOK_KEPT, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    same:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    S.sameLook = same
    OnRefresh(function()
        local key = ns.Selected()
        same:SetText(L.SAME_LOOK_BTN:format(ClassName(ns.PROC_BY[key].class, true)))
        same:SetEnabled(#ns.ClassMates(key) > 0)
    end)
    local all = Button(col, "", LEFT_W - 24, 24)
    all:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 12, 12)
    all:SetScript("OnClick", function()
        local class = ns.PROC_BY[ns.Selected()].class
        local keys = {}
        for _, p in ipairs(ProcsOf(class)) do if ns.Cfg(p.key).enabled then keys[#keys + 1] = p.key end end
        if #keys == 0 then keys[1] = ns.Selected() end
        ns.Display:StartPlacing(true, keys, L.PLACING_ALL_TITLE:format(ClassName(class, true)))
    end)
    Tip(all, L.PLACE_ALL_TIPT, L.PLACE_ALL_TIP)
    S.placeAll = all
    OnRefresh(function()
        local key = ns.Selected()
        local class = ns.PROC_BY[key].class
        for _, b in ipairs(icons) do
            local on = b.class == class
            b.edge:SetShown(on)
            b.ring:SetShown(on)
            b.icon:SetDesaturated(not on)
            b.icon:SetAlpha(on and 1 or 0.75)
            b.dot:SetShown(b.class == ns.playerClass)
        end
        local list = ProcsOf(class)
        local nOn = 0
        for i, r in ipairs(rows) do
            local p = list[i]
            r:SetShown(p ~= nil)
            r.key = p and p.key
            if p then
                local cfg = ns.Cfg(p.key)
                local info = ns.Info(p.key)
                r.icon:SetTexture(info.icon or p.icon)
                r.name:SetText(info.name)
                r.sub:SetText(SpecText(p))
                r.cb:SetChecked(cfg.enabled and true or false)
                r.icon:SetDesaturated(not cfg.enabled)
                if cfg.enabled then r.name:SetTextColor(1, 1, 1); nOn = nOn + 1 else r.name:SetTextColor(0.55, 0.55, 0.55) end
                local s = p.key == key
                r.sel:SetShown(s); r.bar:SetShown(s)
            end
        end
        local mineTxt = (class == ns.playerClass) and L.CLASS_LINE_MINE or L.CLASS_LINE
        line:SetText(mineTxt:format(ClassName(class), #list))
        all:SetText(L.PLACE_ALL:format(ClassName(class, true)))
        all:SetEnabled(nOn > 0)
    end)
end

----------------------------------------------------------------------
-- Middle: the chosen alert, its tabs
----------------------------------------------------------------------
local TABS = { "style", "look", "stacks", "timer" }
local pages, tabs = {}, {}
local current = "style"

local function ShowTab(name)
    local p = ns.PROC_BY[ns.Selected()]
    if name == "stacks" and not (p and p.stacks) then name = "style" end
    current = name
    for i, t in ipairs(TABS) do
        local on = t == name
        pages[t]:SetShown(on)
        local b = tabs[i]
        if b.real then
            if on and PanelTemplates_SelectTab then pcall(PanelTemplates_SelectTab, b)
            elseif PanelTemplates_DeselectTab then pcall(PanelTemplates_DeselectTab, b) end
        else
            Mark(b, on)
        end
    end
    if S.OnTab then S.OnTab(name) end
end
S.ShowTab = ShowTab
function S.CurrentTab() return current end

local function MakeTab(parent, i, text)
    for _, tpl in ipairs({ "PanelTopTabButtonTemplate", "TabButtonTemplate" }) do
        local ok, b = pcall(CreateFrame, "Button", "ShadowflareSettingsTab" .. i, parent, tpl)
        if ok and b then
            b:SetText(text)
            b.real = true
            if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 14) end
            -- Never narrower than its text (if the template did not size it)
            local fs = b.GetFontString and b:GetFontString()
            local tw = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
            if (b:GetWidth() or 0) < 40 then b:SetWidth(max(90, (tw or 0) + 32)) end
            if (b:GetHeight() or 0) < 10 then b:SetHeight(32) end
            return b
        end
    end
    local b = Button(parent, text, 120, 24)
    return b
end

local function Middle(f)
    local col = Inset(f, 8 + LEFT_W + 6, -62, MID_W, H - 62 - 8)
    S.mid = col
    -- The alert: icon, name, details, description
    local icon = col:CreateTexture(nil, "ARTWORK")
    icon:SetSize(42, 42)
    icon:SetPoint("TOPLEFT", col, "TOPLEFT", 12, -12)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local name = Text(col, "GameFontNormalHuge")
    name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    name:SetPoint("RIGHT", col, "RIGHT", -240, 0)
    name:SetWordWrap(false)
    local sub = Text(col, "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    sub:SetPoint("RIGHT", col, "RIGHT", -240, 0)
    sub:SetWordWrap(false)
    sub:SetTextColor(0.75, 0.75, 0.75)
    local desc = Text(col, "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", col, "RIGHT", -14, 0)
    desc:SetTextColor(0.8, 0.8, 0.8)
    desc:SetSpacing(2)
    S.desc = desc
    -- Copy from (a menu of the other procs) and Reset
    local reset = Button(col, L.RESET_BTN, 96, 22, function()
        local key = ns.Selected()
        ns.Ask({ title = L.RESET_BTN, text = L.RESET_ASK:format(ns.Info(key).name), okText = L.RESET_BTN,
            onOk = function() ns.ResetLook(key) end })
    end, L.RESET_BTN, L.RESET_TIP)
    reset:SetPoint("TOPRIGHT", col, "TOPRIGHT", -12, -12)
    S.resetBtn = reset
    local okC, copy = pcall(CreateFrame, "DropdownButton", nil, col, "WowStyle1DropdownTemplate")
    if okC and copy and copy.SetupMenu then
        copy:SetWidth(124)
        copy:SetPoint("RIGHT", reset, "LEFT", -6, 0)
        if copy.SetDefaultText then pcall(copy.SetDefaultText, copy, L.COPY_BTN) end
        copy:SetupMenu(function(_, root)
            local cur = ns.Selected()
            local class = ns.PROC_BY[cur].class
            for _, p in ipairs(ns.PROCS) do
                if p.key ~= cur then
                    local extra = p.class == class and (L["SPEC_" .. p.spec] or p.spec) or ClassName(p.class)
                    root:CreateButton(ns.Info(p.key).name .. " (" .. extra .. ")", function() ns.CopyLook(p.key) end)
                end
            end
        end)
        local function label()
            local t = copy.Text
            if type(t) == "table" and t.SetText then t:SetText(L.COPY_BTN) end
        end
        label()
        OnRefresh(function() if copy.GenerateMenu then pcall(copy.GenerateMenu, copy) end label() end)
        Tip(copy, L.COPY_FROM, L.COPY_TIP)
    end
    OnRefresh(function()
        local key = ns.Selected()
        local p, info = ns.PROC_BY[key], ns.Info(key)
        icon:SetTexture(info.icon or p.icon)
        name:SetText(info.name)
        local t = SpecText(p)
        if info.label and info.label ~= "" then t = t .. " - " .. info.label end
        sub:SetText(t)
        local text = L["D_" .. key] or ""
        if p.mode == "aura" and ns.AuraShow then
            text = text .. "\n" .. (ns.AuraShow.Owns(key) and L.AURA_READY or L.AURA_WAIT)
        end
        desc:SetText(text)
    end)
    -- Tabs, under the description (room for four lines)
    local tabY = -126
    for i, t in ipairs(TABS) do
        local b = MakeTab(col, i, L["TAB_" .. t])
        if i == 1 then b:SetPoint("TOPLEFT", col, "TOPLEFT", 10, tabY)
        else b:SetPoint("LEFT", tabs[i - 1], "RIGHT", b.real and -2 or 4, 0) end
        b:SetScript("OnClick", function() ShowTab(t) end)
        tabs[i] = b
        local pg = CreateFrame("Frame", nil, col)
        pg:SetPoint("TOPLEFT", col, "TOPLEFT", 4, tabY - 34)
        pg:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", -4, 4)
        pg:Hide()
        pages[t] = pg
    end
    local tabLine = col:CreateTexture(nil, "ARTWORK")
    tabLine:SetColorTexture(1, 0.82, 0, 0.25)
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT", col, "TOPLEFT", 8, tabY - 30)
    tabLine:SetPoint("RIGHT", col, "RIGHT", -8, 0)
    S.tabs, S.pages = tabs, pages
    OnRefresh(function()
        local p = ns.PROC_BY[ns.Selected()]
        local has = p.stacks ~= nil
        tabs[3]:SetShown(has)
        -- The last tab follows the one before it that shows
        tabs[4]:ClearAllPoints()
        tabs[4]:SetPoint("LEFT", has and tabs[3] or tabs[2], "RIGHT", tabs[4].real and -2 or 4, 0)
        if current == "stacks" and not has then ShowTab("style") end
    end)
end

----------------------------------------------------------------------
-- Tab: Style (the gallery: every style with a live preview of this proc)
----------------------------------------------------------------------
local CARD_W, CARD_H, GAP, COLS, CARD_SCALE = 92, 84, 6, 5, 0.3
-- Styles that draw the proc's icon or name: one preview per proc. The others look the same for
-- every proc, so their card keeps one preview for all (fewer frames when browsing many procs).
local USES_PROC = { ring = true, icon = true, bar = true, text = true, brackets = true, procglow = true }
local cards, queue = {}, {}

local function Drain(self)
    for _ = 1, 6 do
        local job = table.remove(queue, 1)
        if not job then self:SetScript("OnUpdate", nil) return end
        pcall(job)
    end
end

local function Card(page, def, x, y)
    local b = CreateFrame("Button", nil, page, BACKDROP)
    b:SetSize(CARD_W, CARD_H)
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    if b.SetBackdrop then
        b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
        b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    pcall(b.SetClipsChildren, b, true)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); hl:SetBlendMode("ADD"); hl:SetAllPoints(); hl:SetAlpha(0.35)
    local nm = Text(b, "GameFontHighlightSmall", D().StyleName(def))
    nm:SetPoint("BOTTOMLEFT", 3, 4); nm:SetPoint("BOTTOMRIGHT", -3, 4)
    nm:SetJustifyH("CENTER")
    nm:SetWordWrap(false)
    local sets, pending = {}, {}
    local s, hovered, t0
    local function move()
        local now = GetTime()
        local anim = ns.Cur().anim
        local move = D().InOut(ns.Cur(), ns.Selected())   -- 0.23.13: Still's way in and out with the box
        local t = (now - (t0 or now)) % 2.8
        -- its way in, then its way out (run out), as on screen (0.23.0)
        local show, mk
        if t < 2.2 then show, mk = D().Enter(move, t)
        else local hot, done; show, mk, hot, done = D().Exit(move, t - 2.2, false); if done then show = 0 end end
        local p, k, fa = D().AnimLook(anim, t, now, nil)
        s.box:SetScale(CARD_SCALE * k * mk)
        s.box:SetAlpha(show * fa)
        D().Preview(s.s, p, now)
    end
    local function still()
        s.box:SetScale(CARD_SCALE); s.box:SetAlpha(1)
        D().Preview(s.s, 1)
    end
    local function animate()
        local on = s and (hovered or D().EffectiveStyle(ns.Cur()) == def.key)
        if on and not b:GetScript("OnUpdate") then t0 = GetTime() end
        b:SetScript("OnUpdate", on and move or nil)
        if s and not on then still() end
    end
    b:SetScript("OnEnter", function() hovered = true; animate() end)
    b:SetScript("OnLeave", function() hovered = false; animate() end)
    b:SetScript("OnClick", function()
        if def.key == "none" and not D().NoneFits(ns.Selected()) then return end   -- 0.23.30
        ns.SetOption("style", def.key)
    end)
    if def.key == "none" then
        b:HookScript("OnEnter", function()
            if D().NoneFits(ns.Selected()) or not GameTooltip then return end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(D().StyleName(def), 1, 0.82, 0)
            GameTooltip:AddLine(L.NONE_NOTHING, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    b.refresh = function()
        local key, cfg = ns.Selected(), ns.Cur()
        local id = USES_PROC[def.key] and key or "*"
        s = sets[id]
        for k, o in pairs(sets) do o.box:SetShown(k == id) end
        if not s and not pending[id] then
            pending[id] = true
            table.insert(queue, function()
                local h = NewSet(b, key, def.key, CARD_SCALE)
                if h then
                    h.box:ClearAllPoints()
                    h.box:SetPoint("CENTER", b, "CENTER", 0, 7 / CARD_SCALE)
                    sets[id] = h
                end
                b.refresh()
            end)
            if win then win:SetScript("OnUpdate", Drain) end
        end
        if s then
            Dress(s, cfg)
            Blank(s.s)
            D().Preview(s.s, 1); Blank(s.s)
            -- None (0.23.30): its card shows a time left, as it will look
            if def.key == "none" and s.s.timer then s.s.timer:SetText("12") end
        end
        if def.key == "none" then b:SetAlpha(D().NoneFits(key) and 1 or 0.35) end
        if b.SetBackdropBorderColor then
            if D().EffectiveStyle(cfg) == def.key then b:SetBackdropBorderColor(1, 0.82, 0, 1)
            else b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end
        end
        animate()
    end
    b.restart = function() t0 = GetTime() end
    cards[#cards + 1] = b
    return b
end

local function StyleTab(pg)
    local scroll = CreateFrame("ScrollFrame", nil, pg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pg, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", pg, "BOTTOMRIGHT", -26, 4)
    local page = CreateFrame("Frame", nil, scroll)
    page:SetSize(MID_W - 40, 400)
    scroll:SetScrollChild(page)
    -- 0.23.30: with the None style, what it shows, right here (the same settings as in the
    -- Stacks and Timer and sound tabs). The gallery moves down to make room.
    local row = CreateFrame("Frame", nil, page)
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    row:SetSize(MID_W - 40, 34)
    local tBox = Check(row, 4, -4, L.NONE_TIME, L.NONE_TIME_TIP, function() return ns.Cur().noneTime ~= false end, function(v)
        ns.SetOption("noneTime", v)
    end)
    local dBox = Check(row, 160, -4, L.NONE_DOTS, L.NONE_DOTS_TIP, function() return ns.Cur().noneDots ~= false end, function(v)
        ns.SetOption("noneDots", v)
        if S.RestartPreview then S.RestartPreview() end
    end)
    local nothing = Text(row, "GameFontRedSmall", L.NONE_EMPTY)
    nothing:SetPoint("TOPLEFT", row, "TOPLEFT", 320, -10)
    nothing:SetWidth(MID_W - 40 - 330)
    nothing:SetJustifyH("LEFT")
    S.noneRow, S.noneTime, S.noneDots, S.noneEmpty = row, tBox, dBox, nothing
    local holder = CreateFrame("Frame", nil, page)
    holder:SetSize(MID_W - 40, 400)
    page = holder
    local y = -4
    for _, fam in ipairs({ { "modern", L.MODERN }, { "classic", L.CLASSIC }, { "retail", L.RETAIL } }) do
        local list = {}
        for _, def in ipairs(ns.CATALOG) do
            if def.family == fam[1] and D().Available(def) then list[#list + 1] = def end
        end
        if #list == 0 and fam[1] == "retail" then fam = nil end   -- none in this client: no group
        if fam then
        local fs = Text(page, "GameFontNormal", fam[2])
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", 4, y)
        y = y - 20
        if #list == 0 then
            local none = Text(page, "GameFontDisableSmall", L.CLASSIC_NONE)
            none:SetPoint("TOPLEFT", page, "TOPLEFT", 4, y)
            y = y - 22
        end
        for i, def in ipairs(list) do
            local cx, cy = (i - 1) % COLS, floor((i - 1) / COLS)
            Card(page, def, 4 + cx * (CARD_W + GAP), y - cy * (CARD_H + GAP))
        end
        y = y - math.ceil(#list / COLS) * (CARD_H + GAP) - 8
        end
    end
    local galleryH = -y + 8
    holder:SetHeight(galleryH)
    local pageFrame = holder:GetParent()
    OnRefresh(function()
        local key, cfg = ns.Selected(), ns.Cur()
        local p = ns.PROC_BY[key]
        local none = D().NoArt(cfg)
        row:SetShown(none)
        dBox:SetShown(none and p and p.stacks and true or false)
        dBox.label:SetShown(dBox:IsShown())
        local showsTime = D().TimeOnAlert(cfg) and not (p and p.noTimer)
        local showsDots = p and p.stacks and D().StackLook(key) == "dots"
        nothing:SetShown(none and not showsTime and not showsDots and not (p and p.stacks and cfg.stackNum))
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", pageFrame, "TOPLEFT", 0, none and -34 or 0)
        pageFrame:SetHeight(galleryH + (none and 34 or 0))
    end)
    OnRefresh(function()
        if current ~= "style" then return end
        for _, c in ipairs(cards) do c.refresh() end
    end)
    S.cards = cards
end

----------------------------------------------------------------------
-- Tab: Look (color, animation, brightness)
----------------------------------------------------------------------
local function OpenPicker()
    local cfg = ns.Cur()
    local r0, g0, b0 = D().Color(cfg)
    local prevKey, prevCustom = cfg.color, cfg.custom
    local function now()
        local cr, cg, cb = ColorPickerFrame:GetColorRGB()
        cfg.custom = { cr, cg, cb }
        ns.SetOption("color", "custom")
    end
    local function cancel()
        cfg.custom = prevCustom
        ns.SetOption("color", prevKey)
    end
    if not ColorPickerFrame then return end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = r0, g = g0, b = b0, hasOpacity = false,
            swatchFunc = now, cancelFunc = cancel })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc = now, cancel
        ColorPickerFrame.previousValues = { r0, g0, b0 }
        ColorPickerFrame:SetColorRGB(r0, g0, b0)
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
    end
    if ColorPickerFrame.SetFrameStrata then pcall(ColorPickerFrame.SetFrameStrata, ColorPickerFrame, "FULLSCREEN_DIALOG") end
end

local function LookTab(pg)
    local x, w = 12, MID_W - 32
    Section(pg, x, -6, w, L.COLOR)
    local sw = {}
    local list = {}
    for _, c in ipairs(ns.COLORS) do list[#list + 1] = c end
    list[#list + 1] = { key = "custom" }
    for i, c in ipairs(list) do
        local b = CreateFrame("Button", nil, pg)
        b:SetSize(30, 30)
        b:SetPoint("TOPLEFT", pg, "TOPLEFT", x + (i - 1) * 62 + 14, -32)
        local frame = b:CreateTexture(nil, "BACKGROUND")
        frame:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
        frame:SetAllPoints()
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", 5, -5); t:SetPoint("BOTTOMRIGHT", -5, 5)
        b.swatch = t
        local edge = b:CreateTexture(nil, "OVERLAY")
        edge:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        edge:SetBlendMode("ADD")
        edge:SetPoint("TOPLEFT", -6, 6); edge:SetPoint("BOTTOMRIGHT", 6, -6)
        b.edge = edge
        local nm = Text(pg, "GameFontHighlightSmall", L["C_" .. c.key])
        nm:SetPoint("TOP", b, "BOTTOM", 0, -3)
        nm:SetJustifyH("CENTER")
        b.key = c.key
        if c.key == "custom" then
            b:SetScript("OnClick", OpenPicker)
        else
            t:SetColorTexture(c.r, c.g, c.b)
            b:SetScript("OnClick", function() ns.SetOption("color", c.key) end)
        end
        sw[i] = b
    end
    S.swatches = sw
    OnRefresh(function()
        local cfg = ns.Cur()
        for _, b in ipairs(sw) do
            b.edge:SetShown(cfg.color == b.key)
            if b.key == "custom" then
                local r, g, bl = D().Color(cfg)
                if cfg.color == "custom" then b.swatch:SetColorTexture(r, g, bl) else b.swatch:SetColorTexture(0.5, 0.5, 0.5) end
            end
        end
    end)
    Check(pg, x, -92, L.TINT, L.TINT_TIP, function() return ns.Cur().tintClassic end,
        function(v) ns.SetOption("tintClassic", v) end)

    Section(pg, x, -132, w, L.ANIM)
    local anims = {}
    -- Six animations in the column: each button as wide as its name needs (0.23.2)
    local AW = { breath = 84, classic = 96, impact = 70, impactpulse = 100, flash = 66, still = 64 }
    for _, k in ipairs(ns.ANIMS) do anims[#anims + 1] = { value = k, text = L["ANIMS_" .. k], w = AW[k] } end
    S.animSegs = Segments(pg, x, -156, anims, function() return ns.Cur().anim end, function(v)
        ns.SetOption("anim", v)
        if S.RestartPreview then S.RestartPreview() end
        for _, c in ipairs(cards) do c.restart() end
    end, 96, 24)
    -- 0.23.13: no way in or out for this alert, its animation keeps moving
    Check(pg, x, -184, L.NOMOVES, L.NOMOVES_TIP, function() return ns.Cur().noEntrance end, function(v)
        ns.SetOption("noEntrance", v and true or false)
        if S.RestartPreview then S.RestartPreview() end
        for _, c in ipairs(cards) do c.restart() end
    end)
    local ah = Text(pg, "GameFontDisableSmall")
    ah:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -214)
    ah:SetWidth(w)
    OnRefresh(function()
        -- 0.23.10: an alert the game shows itself appears at once and holds still
        local game = ns.AuraShow and ns.AuraShow.Owns(ns.Selected())
        local onT = ns.PROC_BY[ns.Selected()].onTarget
        local second = (game and L.ANIM_GAME) or (onT and L.ANIM_TARGET) or (ns.Cur().noEntrance and L.ANIM_NOMOVES) or L.ANIM_EXIT
        ah:SetText((L["ANIMD_" .. (ns.Cur().anim or "breath")] or "") .. "\n" .. second)
    end)

    Section(pg, x, -258, w, L.H_BRIGHT)
    Slider(pg, x, -282, L.OPACITY, nil, 0.2, 1, 0.05, "alpha")
    Slider(pg, x, -312, L.SHADOW, L.SHADOW_TIP, 0, 1, 0.05, "shadow")
    Slider(pg, x, -342, L.ROTATION, L.ROTATION_TIP, 0, 345, 15, "rotation", function(v) return ("%d°"):format(v) end)
    -- 0.23.15 (asked on CurseForge): two-sided styles, one side only and the space between
    Section(pg, x, -378, w, L.H_SIDES)
    local sides = {}
    for _, v in ipairs(D().SIDES) do sides[#sides + 1] = { value = v, text = L["SIDE_" .. v], w = 128 } end
    local segs = Segments(pg, x, -400, sides, function() return D().SideOf(ns.Cur(), D().EffectiveStyle(ns.Cur())) end,
        function(v) ns.SetOption("side", v) end, 128, 24)
    local sl = Slider(pg, x, -432, L.SPACING, L.SPACING_TIP, D().SPACING_MIN, D().SPACING_MAX, 5, "spacing",
        function(v) v = floor(v + 0.5); return v > 0 and ("+" .. v) or tostring(v) end)
    local sh = Text(pg, "GameFontDisableSmall")
    sh:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -462)
    sh:SetWidth(w)
    OnRefresh(function()
        local two = D().TwoSided(D().EffectiveStyle(ns.Cur()))
        for _, b in ipairs(segs) do pcall(b.SetEnabled, b, two) end
        if sl and sl.SetEnabled then pcall(sl.SetEnabled, sl, two) end
        sh:SetText(two and L.SIZE_MOVED or L.SIDES_NONE)
    end)
end

----------------------------------------------------------------------
-- Tab: Stacks (show from, the look below the maximum, the number)
----------------------------------------------------------------------
local lookCards = {}
-- 0.23.32: with the None style, these settings are for the other styles (a line says so)
local function NoneNote(pg, y)
    local t = Text(pg, "GameFontDisableSmall", L.NONE_ELSEWHERE)
    t:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -14, y)
    t:SetWidth(330)
    t:SetJustifyH("RIGHT")
    OnRefresh(function() t:SetShown(D().NoArt(ns.Cur())) end)
    return t
end

local function StacksTab(pg)
    local x, w = 12, MID_W - 32
    Section(pg, x, -6, w, L.STACKS_FROM)
    -- One button per count, made for up to 5 stacks; only the proc's own show
    local from = {}
    for i = 1, 5 do
        local b = Button(pg, "", i == 5 and 112 or 92, 24)
        b:SetPoint("TOPLEFT", pg, "TOPLEFT", x + (i - 1) * 94, -30)
        b:SetScript("OnClick", function() ns.SetOption("fromStacks", i); ns.Refresh() end)
        b.n = i
        from[i] = b
    end
    local fh = Text(pg, "GameFontDisableSmall", L.STACKS_FROM_TIP)
    fh:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -60)
    fh:SetWidth(w)
    OnRefresh(function()
        local p = ns.PROC_BY[ns.Selected()]
        local m = p.stacks or 1
        local cur = ns.FromStacks(ns.Selected())
        local bw = floor((w - (m - 1) * 2) / m)
        for i, b in ipairs(from) do
            b:SetShown(i <= m)
            b:SetWidth(bw)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", pg, "TOPLEFT", x + (i - 1) * (bw + 2), -30)
            b:SetText((i == m and L.STACKS_MAXS:format(i)) or (i == 1 and L.STACKS_ONE) or L.STACKS_N:format(i))
            Mark(b, i == cur)
        end
    end)

    Section(pg, x, -90, w, L.STACK_LOOK)
    S.noneNoteLook = NoneNote(pg, -94)
    local LW, LH = 92, 92
    for i, v in ipairs(D().STACK_LOOKS) do
        local b = CreateFrame("Button", nil, pg, BACKDROP)
        b:SetSize(LW, LH)
        b.look, b.sets = v, {}
        if b.SetBackdrop then
            b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            b:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
            b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        pcall(b.SetClipsChildren, b, true)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); hl:SetBlendMode("ADD"); hl:SetAllPoints(); hl:SetAlpha(0.35)
        local nm = Text(b, "GameFontHighlightSmall", L["LOOKC_" .. v])
        nm:SetPoint("BOTTOMLEFT", 3, 4); nm:SetPoint("BOTTOMRIGHT", -3, 4)
        nm:SetJustifyH("CENTER"); nm:SetWordWrap(false)
        b:SetScript("OnClick", function()
            if not D().LookFits(ns.Selected(), v) then return end   -- greyed out (0.23.19)
            ns.SetOption("stackLook", v); ns.Refresh()
        end)
        Tip(b, L["LOOK_" .. v], L["LOOKD_" .. v])
        lookCards[i] = b
    end
    local ld = Text(pg, "GameFontHighlightSmall")
    ld:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -114 - LH - 8)
    ld:SetWidth(w)
    ld:SetTextColor(0.8, 0.8, 0.8)
    S.lookDesc, S.lookCards = ld, lookCards
    OnRefresh(function()
        local key = ns.Selected()
        local p = ns.PROC_BY[key]
        if not p.stacks then return end
        local cur = D().StackLook(key)
        local n = 0
        local oneSide = D().OneSide(key)
        for _, b in ipairs(lookCards) do
            local fits = D().LookFits(key, b.look)
            -- 0.23.19: Fills from the left stays in place, greyed out, with one side only
            local greyed = (not fits) and b.look == "fillleft" and oneSide
            b:SetShown(fits or greyed)
            if fits or greyed then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", pg, "TOPLEFT", x + n * (LW + 6), -114)
                n = n + 1
                b:SetAlpha(greyed and 0.35 or 1)
                if b.SetBackdropBorderColor then
                    if b.look == cur then b:SetBackdropBorderColor(1, 0.82, 0, 1) else b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end
                end
            end
        end
        local line = "|cffffd100" .. L["LOOK_" .. cur] .. "|r - " .. L["LOOKD_" .. cur]
        if oneSide then line = line .. "\n" .. L.LOOK_ONE_SIDE end
        ld:SetText(line)
    end)

    -- 0.23.15 (Ben): the part not reached yet fully hidden (Fills up, Fills from the left)
    local hideBox = Check(pg, x, -264, L.FILL_HIDE, L.FILL_HIDE_TIP, function() return ns.Cur().fillHide end,
        function(v) ns.SetOption("fillHide", v and true or false); ns.Refresh() end)
    OnRefresh(function()
        local key = ns.Selected()
        local look = ns.PROC_BY[key].stacks and D().StackLook(key)
        local fill = look == "fillup" or look == "fillleft"
        pcall(hideBox.SetEnabled, hideBox, fill)
        hideBox.label:SetFontObject(fill and "GameFontHighlight" or "GameFontDisable")
    end)

    Section(pg, x, -302, w, L.H_NUMBER)
    Check(pg, x, -324, L.STACK_NUM, L.STACK_NUM_TIP, function() return ns.Cur().stackNum end,
        function(v) ns.SetOption("stackNum", v) end)
    Slider(pg, x, -356, L.STACK_SIZE, L.STACK_SIZE_TIP, 10, 60, 1, "stackSize", function(v) return ("%d"):format(v) end)
end

----------------------------------------------------------------------
-- Tab: Timer and sound (time left, cooldown reset, screen edges, sound, when to show)
----------------------------------------------------------------------
local function TimerTab(pg)
    local x, w = 12, MID_W - 32
    Section(pg, x, -6, w, L.H_TIME)
    S.noneNoteTime = NoneNote(pg, -10)
    S.timeSegs = Segments(pg, x, -30, {
        { value = "on", text = L.TIME_ON, w = 150 },
        { value = "apart", text = L.TIME_APART, w = 180, tip = L.TIMER_FREE_TIP },
        { value = "off", text = L.TIME_OFF, w = 150 },
    }, function()
        local c = ns.Cur()
        if not c.timer then return "off" end
        return c.timerFree and "apart" or "on"
    end, function(v)
        local c = ns.Cur()
        c.timer = v ~= "off"
        c.timerFree = v == "apart"
        ns.SetOption("timer", c.timer)
    end, 150, 24)
    local _, tl, tv = Slider(pg, x, -62, L.TIME_SIZE, L.TIME_SIZE_TIP, 10, 60, 1, "timerSize", function(v) return ("%d"):format(v) end)
    -- Alignment of the time placed apart (0.23.23, Soothx): the left edge stays still
    local al = Text(pg, "GameFontHighlight", L.TIME_ALIGN)
    al:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -96)
    local alHit = CreateFrame("Frame", nil, pg)
    alHit:SetPoint("TOPLEFT", al, "TOPLEFT", -2, 2)
    alHit:SetSize(120, 18)
    alHit:EnableMouse(true)
    Tip(alHit, L.TIME_ALIGN, L.TIME_ALIGN_TIP)
    local alSegs = Segments(pg, x + 130, -92, {
        { value = "left", text = L.ALIGN_LEFT, w = 90, tip = L.TIME_ALIGN_TIP },
        { value = "center", text = L.ALIGN_CENTER, w = 90, tip = L.TIME_ALIGN_TIP },
        { value = "right", text = L.ALIGN_RIGHT, w = 90, tip = L.TIME_ALIGN_TIP },
    }, function() return ns.Cur().timerAlign or "center" end, function(v) ns.SetOption("timerAlign", v) end, 90, 22)
    S.alignSegs = alSegs
    -- Font (0.23.24): every text of the alert (time left, the style's words, the stacks)
    local fl = Text(pg, "GameFontHighlight", L.FONT)
    fl:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -126)
    local flHit = CreateFrame("Frame", nil, pg)
    flHit:SetPoint("TOPLEFT", fl, "TOPLEFT", -2, 2)
    flHit:SetSize(120, 18)
    flHit:EnableMouse(true)
    Tip(flHit, L.FONT, L.FONT_TIP)
    local fdd = Menu(pg, 274, function() return D().FontList() end,
        function() return ns.Cur().font or "game" end, function(v) ns.SetOption("font", v) end)
    fdd:SetPoint("TOPLEFT", pg, "TOPLEFT", x + 130, -122)
    Tip(fdd, L.FONT, L.FONT_TIP)
    S.fontMenu = fdd
    -- Cooldown reset (Improved Stormstrike): how long the alert stays
    local rs = CreateFrame("Frame", nil, pg)
    rs:SetPoint("TOPLEFT", pg, "TOPLEFT", 0, -152)
    rs:SetSize(w + 24, 30)
    Slider(rs, x, 0, L.SHOW_FOR, L.SHOW_FOR_TIP, 2, 10, 1, "showFor", function(v) return L.SECONDS:format(v) end)
    OnRefresh(function()
        local p = ns.PROC_BY[ns.Selected()]
        rs:SetShown(p.mode == "reset")
        local free = D().TimeApart(ns.Cur())
        tl:SetTextColor(free and 1 or 0.5, free and 1 or 0.5, free and 1 or 0.5)
        al:SetTextColor(free and 1 or 0.5, free and 1 or 0.5, free and 1 or 0.5)
        for _, b in ipairs(alSegs) do b:SetEnabled(free and true or false) end
    end)

    Section(pg, x, -192, w, L.H_EDGES)
    Check(pg, x, -214, L.EDGES, L.EDGES_TIP, function() return ns.Cur().edges end,
        function(v) ns.SetOption("edges", v) end)
    Check(pg, x, -240, L.EDGES_ONLY, L.EDGES_ONLY_TIP, function() return ns.Cur().edgesOnly end, function(v)
        if v and not ns.Cur().edges then ns.Cur().edges = true end
        ns.SetOption("edgesOnly", v)
    end)

    Section(pg, x, -280, w, L.SOUND)
    local dd = Menu(pg, 260, function()
        local list = {}
        local sp = ns.PROC_BY[ns.Selected()]
        if sp.gameSoundOnly then return { { value = "game", text = L.SND_gameonly } } end
        if sp.mode == "aura" then return { { value = "none", text = L.SND_auraonly } } end
        if sp.gameAlert then list[1] = { value = "game", text = L.SND_game } end
        for _, s in ipairs(ns.SOUNDS) do
            list[#list + 1] = { value = s.key, text = "Shadowflare - " .. L["SND_" .. s.key] }
        end
        list[#list + 1] = { value = "none", text = L.SND_none }
        return list
    end, function() return ns.Cur().soundChoice end, function(v) ns.SetSound(v) end)
    dd:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -304)
    Tip(dd, L.SOUND, L.SOUND_TIP)
    local play = Button(pg, L.PLAY, 90, 22, function() ns.PlayChoice(ns.Selected()) end, L.PLAY, L.PLAY_TIP)
    play:SetPoint("LEFT", dd, "RIGHT", 8, 0)
    S.playBtn = play
    local sh = Text(pg, "GameFontDisableSmall", L.SOUND_WHEN)
    sh:SetPoint("TOPLEFT", pg, "TOPLEFT", x, -334)
    sh:SetWidth(w)
    OnRefresh(function()
        local c = ns.Cur()
        play:SetEnabled(c.soundChoice ~= "none" and ns.PROC_BY[ns.Selected()].mode ~= "aura")
    end)

    Section(pg, x, -364, w, L.H_WHEN)
    S.combatBox = Check(pg, x, -386, L.ONLY_COMBAT, L.ONLY_COMBAT_TIP, function() return ns.Cur().onlyCombat end,
        function(v) ns.SetOption("onlyCombat", v); ns.Refresh() end)
    local wh = Text(pg, "GameFontDisableSmall", L.ONLY_COMBAT_HINT)
    wh:SetPoint("TOPLEFT", pg, "TOPLEFT", x + 4, -414)
    wh:SetWidth(w)
    -- 0.23.27: Overpower and Revenge also in another stance (off by default, these two only)
    S.stanceBox = Check(pg, x, -444, L.OTHER_STANCES, L.OTHER_STANCES_TIP, function() return ns.Cur().otherStances end,
        function(v) ns.SetOption("otherStances", v); ns.Refresh() end)
    local sth = Text(pg, "GameFontDisableSmall", L.OTHER_STANCES_HINT)
    sth:SetPoint("TOPLEFT", pg, "TOPLEFT", x + 4, -472)
    sth:SetWidth(w)
    OnRefresh(function()
        local p = ns.PROC_BY[ns.Selected()]
        local on = p and p.stanceTrack and true or false
        S.stanceBox:SetShown(on)
        S.stanceBox.label:SetShown(on)   -- 0.23.32: its text too (it showed on every alert)
        sth:SetShown(on)
    end)
end

----------------------------------------------------------------------
-- Right: the live preview
----------------------------------------------------------------------
-- 0.23.15 (Ben): the preview holds still (anim = false) until Play; Stop holds it again.
-- play: the stacks go from 1 to the maximum (only while it plays)
local PV = { sets = {}, thumbs = {}, n = 1, play = false, anim = false, endsSoon = false, bright = false, t0 = 0 }
S.preview = PV
local SW, SH = RIGHT_W - 20, 290
local CYCLE, SOON, GAP_T, STEP, EXIT_T = 8, 3, 0.6, 1.0, 0.45

local function CurSet()
    local key, cfg = ns.Selected(), ns.Cur()
    local style = D().EffectiveStyle(cfg)
    local id = key .. "|" .. style
    local h = PV.sets[id]
    if h == nil then
        h = NewSet(PV.holder, key, style) or false
        PV.sets[id] = h
    end
    for k, o in pairs(PV.sets) do if o then o.box:SetShown(k == id) end end
    return h or nil
end

-- How big the preview draws the alert: its real size on screen, smaller if it can't fit
local function PreviewScale(cfg, h)
    local stageScale = PV.stage:GetEffectiveScale() or 1
    local ui = UIParent and UIParent:GetEffectiveScale() or 1
    local real = (cfg.scale or 1) * ui / max(0.01, stageScale)
    -- What must fit is the drawn part of the style (its glow can go past the edges)
    local x0, y0, x1, y1 = -130, -110, 130, 110
    if h then x0, y0, x1, y1 = D().InkBox(h.s) end
    local hw = max(abs(x0), abs(x1), 40) + 10
    local hh = max(abs(y0), abs(y1), 40) + 10
    local fit = min((SW / 2 - 4) / hw, (SH / 2 - 16) / hh)
    if real <= fit then return real, true end
    return fit, false, fit / real
end

-- The stack count shown now (playing 1 to the maximum, or held on one)
local function StackNow(p, t)
    local m = p.stacks
    if not m then return nil end
    if not PV.play then return min(PV.n or m, m) end
    local i = floor(t / STEP) % (m + 1) + 1
    return min(i, m)
end

local function PaintPreview()
    local key, cfg = ns.Selected(), ns.Cur()
    local p = ns.PROC_BY[key]
    local h = CurSet()
    PV.cur = h
    if not h then return end
    Dress(h, cfg)
    local m = p.stacks or 1
    local k = p.stacks and (PV.shownN or m) or 1
    PaintLook(h, p.stacks and D().StackLook(key) or "dim", k, m, p, cfg)
    local scale, real, pct = PreviewScale(cfg, h)
    PV.baseScale = scale
    PV.tag:SetText(real and L.REAL_SIZE or L.SHOWN_AT:format(floor((pct or 1) * 100 + 0.5)))
    -- The number of stacks and the time left placed apart, where the player put them
    local r, g, b = D().Color(cfg)
    local lr, lg, lb = D().Light(r, g, b)
    -- In game they keep their own place and size whatever the alert's size: only the
    -- preview's own shrinking applies to them
    local u = scale / max(0.01, cfg.scale or 1)
    local ns_ = PV.num
    if p.stacks and cfg.stackNum then
        ns_:ClearAllPoints()
        ns_:SetPoint("CENTER", PV.stage, "CENTER", (cfg.sox or 0) * u, 10 + (cfg.soy or 55) * u)
        pcall(D().SetFontSafe, ns_, D().FontFile(cfg.font), max(8, (cfg.stackSize or 24) * u), "OUTLINE")
        ns_:SetTextColor(lr, lg, lb)
        ns_:SetText(tostring(k))
        ns_:Show()
    else
        ns_:Hide()
    end
    local tf = PV.timer
    if D().TimeApart(cfg) then
        tf:ClearAllPoints()
        -- aligned in its box like on screen (0.23.23)
        local P = D().AlignPoint(cfg.timerAlign)
        local half = D().TimerBoxW(cfg.timerSize or 22) / 2 * u
        local dx = (P == "LEFT" and -half) or (P == "RIGHT" and half) or 0
        tf:SetPoint(P, PV.stage, "CENTER", (cfg.tox or 0) * u + dx, 10 + (cfg.toy or -80) * u)
        if tf.SetJustifyH then tf:SetJustifyH(P) end
        pcall(D().SetFontSafe, tf, D().FontFile(cfg.font), max(8, (cfg.timerSize or 22) * u), "OUTLINE")
        tf:SetTextColor(lr, lg, lb)
        tf:Show()
    else
        tf:Hide()
    end
    PV.edgeL:SetVertexColor(r, g, b); PV.edgeR:SetVertexColor(r, g, b)
    PV.edgeL:SetShown(cfg.edges and true or false); PV.edgeR:SetShown(cfg.edges and true or false)
    h.box:SetShown(not (cfg.edges and cfg.edgesOnly))
    PV.timeKey = nil
end

local function PaintThumbs()
    local key, cfg = ns.Selected(), ns.Cur()
    local p = ns.PROC_BY[key]
    local m = p.stacks
    local style = D().EffectiveStyle(cfg)
    for i, t in ipairs(PV.thumbs) do
        local on = m and i <= m
        t:SetShown(on and true or false)
        if on then
            local tw = floor((SW - (m - 1) * 4) / m)
            t:SetWidth(tw)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", PV.thumbRow, "TOPLEFT", (i - 1) * (tw + 4), 0)
            local id = key .. "|" .. style
            local h = t.sets[id]
            if h == nil then
                h = NewSet(t, key, style, 0.26) or false
                if h then h.box:ClearAllPoints(); h.box:SetPoint("CENTER", t, "CENTER", 0, 6 / 0.26) end
                t.sets[id] = h
            end
            for k2, o in pairs(t.sets) do if o then o.box:SetShown(k2 == id) end end
            if h then
                Dress(h, cfg)
                D().Preview(h.s, 1); Blank(h.s)
                PaintLook(h, D().StackLook(key), i, m, p, cfg)
            end
            t.label:SetText(L.LOOK_AT:format(i, m))
            if t.SetBackdropBorderColor then
                if PV.shownN == i then t:SetBackdropBorderColor(1, 0.82, 0, 1) else t:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end
            end
        end
    end
    -- The look cards of the Stacks tab show the same count
    if current == "stacks" and m then
        for _, b in ipairs(lookCards) do
            if b:IsShown() then
                local h = b.sets[key .. "|" .. style]
                if h == nil then
                    h = NewSet(b, key, style, 0.3) or false
                    if h then h.box:ClearAllPoints(); h.box:SetPoint("CENTER", b, "CENTER", 0, 6 / 0.3) end
                    b.sets[key .. "|" .. style] = h
                end
                for k2, o in pairs(b.sets) do if o then o.box:SetShown(k2 == key .. "|" .. style) end end
                if h then
                    Dress(h, cfg)
                    D().Preview(h.s, 1); Blank(h.s)
                    PaintLook(h, b.look, PV.shownN or m, m, p, cfg)
                end
            end
        end
    end
end

local function SetStackButtons()
    local p = ns.PROC_BY[ns.Selected()]
    local m = p.stacks
    for i, b in ipairs(PV.stackBtns) do
        b:SetShown(m ~= nil and i <= m)
        Mark(b, (not PV.play) and PV.n == i)
    end
    PV.stackLabel:SetShown(m ~= nil)
    local state = Mark
    PV.playBtn:Hide()
    state(PV.animBtn, PV.anim)
    state(PV.stopBtn, not PV.anim)
    state(PV.soonBtn, PV.endsSoon)
    state(PV.darkBtn, not PV.bright)
    state(PV.brightBtn, PV.bright)
end

-- Every frame while the window is open: the alert breathes, the time counts down,
-- the stacks go up
local function Tick()
    local key, cfg = ns.Selected(), ns.Cur()
    local p = ns.PROC_BY[key]
    local h = PV.cur
    if not h then return end
    local now = GetTime()
    local t = now - PV.t0
    -- Stacks
    local n = StackNow(p, t)
    if n ~= PV.shownN then
        -- reaching the maximum: the accent of its animation (0.23.0)
        if n and p.stacks and n == p.stacks and PV.shownN and PV.shownN < n then PV.accentAt = now end
        PV.shownN = n
        local m = p.stacks or 1
        PaintLook(h, p.stacks and D().StackLook(key) or "dim", n or m, m, p, cfg)
        PV.timeKey = nil   -- a new color part (fill) gets the time left at once
        if p.stacks and cfg.stackNum then PV.num:SetText(tostring(n)) end
        PaintThumbs()
    end
    -- The alert: comes in, holds while its time runs, goes, again (0.23.0: with its own way
    -- in and out; every other time it is used before the end, to show the burst)
    local len = PV.endsSoon and SOON or CYCLE
    -- Held still (0.23.15): shown in full, its time stopped (about three quarters left, or a
    -- moment before the end with Ends soon), nothing moving
    if not PV.anim then
        local rem = PV.endsSoon and 2 or len * 0.75
        if h.hotOn then h.hotOn.frame:SetAlpha(0); h.hotOn = nil end
        PV.exitTag:SetText("")
        PV.accentAt = nil
        if PV.baseScale ~= PV.sc or h ~= PV.sch then PV.sc, PV.sch = PV.baseScale, h; h.box:SetScale(PV.baseScale) end
        h.box:SetAlpha(cfg.alpha)
        local s, c = h.s, h.copy
        -- the swipe of Ring, Icon and Bar set again each frame: it stays where it is
        if s.SetExpiry then pcall(s.SetExpiry, now + rem, len) end
        if c and c.SetExpiry then pcall(c.SetExpiry, now + rem, len) end
        PV.cyc = nil
        local still = PV.stillAt or now
        PV.stillAt = still
        if s.pulse then s.pulse:SetAlpha(s.pA + s.pB) end
        if s.Animate then pcall(s.Animate, still, rem, 1, len) end
        if c then
            if c.pulse then c.pulse:SetAlpha(c.pA + c.pB) end
            if c.Animate then pcall(c.Animate, still, rem, 1, len) end
        end
        local tk = D().TimeKey(rem)
        if tk ~= PV.timeKey then
            PV.timeKey = tk
            local text = D().TimeText(tk)
            local shownText = D().TimeOnAlert(cfg) and text or ""
            if s.SetTime then s.SetTime(shownText) elseif s.timer then s.timer:SetText(shownText) end
            if c then if c.SetTime then c.SetTime(shownText) elseif c.timer then c.timer:SetText(shownText) end end
            PV.timer:SetText(text)
        end
        PV.timer:SetAlpha(cfg.alpha)
        PV.num:SetAlpha(cfg.alpha)
        PV.edgeL:SetAlpha(cfg.alpha * 0.8); PV.edgeR:SetAlpha(cfg.alpha * 0.8)
        return
    end
    PV.stillAt = nil
    local cycle = len + EXIT_T + GAP_T
    local ct = t % cycle
    local used = floor(t / cycle) % 2 == 1
    local useAt = used and len * 0.6 or len
    local fade, mk, mh, rem = 0, 1, 0, nil
    if ct < useAt then
        rem = len - ct
        fade, mk, mh = D().Enter(D().InOut(cfg, key), ct)
        local at = PV.accentAt
        if at then
            local aa, ak, ah, over = D().AccentLook(D().InOut(cfg, key), now - at)
            if over then PV.accentAt = nil else fade, mk = fade * aa, mk * ak; if ah > mh then mh = ah end end
        end
        PV.exitTag:SetText("")
    elseif ct < useAt + EXIT_T then
        rem = len - useAt
        local done
        fade, mk, mh, done = D().Exit(D().InOut(cfg, key), ct - useAt, used)
        if done then fade, mh = 0, 0 end
        PV.exitTag:SetText(used and L.EXIT_USED or L.EXIT_RANOUT)
    else
        rem = 0
        PV.exitTag:SetText("")
    end
    local pp, k, fa = D().AnimLook(cfg.anim, ct, now, rem)
    k = k * mk
    -- the white-hot flare (Impact, Flash, a burst)
    if mh > 0 then
        local hc = D().HotCopy(h, h.box, h.s, h.P)
        hc.frame:SetAlpha(mh)
        h.hotOn = hc
    elseif h.hotOn then
        h.hotOn.frame:SetAlpha(0)
        h.hotOn = nil
    end
    local sc = PV.baseScale * k
    if sc ~= PV.sc or h ~= PV.sch then PV.sc, PV.sch = sc, h; h.box:SetScale(sc) end
    h.box:SetAlpha(cfg.alpha * fade * fa)
    local s = h.s
    local c = h.copy
    -- Each time it comes in: its time starts again (the Ring and Icon swipes, the Bar)
    local cyc = floor(t / cycle)
    if cyc ~= PV.cyc or h ~= PV.cych or c ~= PV.cycc then
        PV.cyc, PV.cych, PV.cycc = cyc, h, c
        local exp = now + rem
        if s.SetExpiry then pcall(s.SetExpiry, exp, len) end
        if c and c.SetExpiry then pcall(c.SetExpiry, exp, len) end
        PV.timeKey = nil
    end
    if s.pulse then s.pulse:SetAlpha(s.pA + s.pB * pp) end
    if s.Animate then pcall(s.Animate, now, rem, pp, len) end
    if c then
        if c.pulse then c.pulse:SetAlpha(c.pA + c.pB * pp) end
        if c.Animate then pcall(c.Animate, now, rem, pp, len) end
    end
    local tk = D().TimeKey(rem)
    if tk ~= PV.timeKey then
        PV.timeKey = tk
        local text = D().TimeText(tk)
        local onAlert = D().TimeOnAlert(cfg)
        local shownText = onAlert and text or ""
        if s.SetTime then s.SetTime(shownText) elseif s.timer then s.timer:SetText(shownText) end
        -- the color part of a filling alert writes it too (bright inside the filled part, as in game)
        if c then if c.SetTime then c.SetTime(shownText) elseif c.timer then c.timer:SetText(shownText) end end
        PV.timer:SetText(text)
    end
    PV.timer:SetAlpha(cfg.alpha * fade)
    PV.num:SetAlpha(cfg.alpha * fade)
    local ea = cfg.alpha * fade * pp * 0.8
    PV.edgeL:SetAlpha(ea); PV.edgeR:SetAlpha(ea)
end
S.Tick = Tick

-- 0.23.9 (seen by Ben): a restart in the first round kept the round number, so the Ring and
-- Icon swipes were not started again and stayed empty: the round is forgotten too
function S.RestartPreview() PV.t0 = GetTime(); PV.timeKey = nil; PV.cyc = nil end

local function Right(f)
    local col = Inset(f, 8 + LEFT_W + 6 + MID_W + 6, -62, RIGHT_W, H - 62 - 8)
    S.right = col
    Section(col, 10, -10, RIGHT_W - 20, L.PREVIEW)
    -- Background of the preview only: dark or bright ground
    PV.brightBtn = Button(col, L.BG_BRIGHT, 70, 20, function() PV.bright = true; S.Refresh() end, L.BG_LABEL, L.BG_TIP)
    PV.brightBtn:SetPoint("TOPRIGHT", col, "TOPRIGHT", -10, -6)
    PV.darkBtn = Button(col, L.BG_DARK, 70, 20, function() PV.bright = false; S.Refresh() end, L.BG_LABEL, L.BG_TIP)
    PV.darkBtn:SetPoint("RIGHT", PV.brightBtn, "LEFT", -2, 0)
    -- 0.23.15 (Ben): the preview holds still; Play runs the animation (way in, time, way out,
    -- the stacks going up), Stop holds it still again
    PV.stopBtn = Button(col, L.PV_STOP, 66, 20, function()
        PV.anim, PV.play = false, false
        PV.n = PV.shownN or PV.n
        PV.timeKey = nil
        S.Refresh()
    end, L.PV_STOP, L.PV_STOP_TIP)
    PV.stopBtn:SetPoint("RIGHT", PV.darkBtn, "LEFT", -10, 0)
    PV.animBtn = Button(col, L.PV_PLAY, 66, 20, function()
        PV.anim = true
        PV.play = ns.PROC_BY[ns.Selected()].stacks ~= nil
        S.RestartPreview()
        S.Refresh()
    end, L.PV_PLAY, L.PV_PLAY_TIP)
    PV.animBtn:SetPoint("RIGHT", PV.stopBtn, "LEFT", -2, 0)
    -- The stage
    local stage = CreateFrame("Frame", nil, col, BACKDROP)
    stage:SetSize(SW, SH)
    stage:SetPoint("TOPLEFT", col, "TOPLEFT", 10, -34)
    pcall(stage.SetClipsChildren, stage, true)
    if stage.SetBackdrop then
        stage:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        stage:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    local bg = stage:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1); bg:SetPoint("BOTTOMRIGHT", -1, 1)
    PV.bg = bg
    local holder = CreateFrame("Frame", nil, stage)
    holder:SetSize(SW, SH)
    holder:SetPoint("CENTER", stage, "CENTER", 0, 10)
    PV.stage, PV.holder = stage, holder
    local over = CreateFrame("Frame", nil, stage)
    over:SetAllPoints()
    pcall(over.SetFrameLevel, over, stage:GetFrameLevel() + 60)
    PV.num = over:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PV.timer = over:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- The glow on the screen edges, on the edges of the preview
    local el = stage:CreateTexture(nil, "ARTWORK")
    el:SetTexture("Interface\\AddOns\\Shadowflare\\Art\\edge"); el:SetBlendMode("ADD")
    el:SetPoint("TOPLEFT", 1, -1); el:SetPoint("BOTTOMLEFT", 1, 1); el:SetWidth(46)
    local er = stage:CreateTexture(nil, "ARTWORK")
    er:SetTexture("Interface\\AddOns\\Shadowflare\\Art\\edge"); er:SetBlendMode("ADD"); er:SetTexCoord(1, 0, 0, 1)
    er:SetPoint("TOPRIGHT", -1, -1); er:SetPoint("BOTTOMRIGHT", -1, 1); er:SetWidth(46)
    PV.edgeL, PV.edgeR = el, er
    PV.tag = over:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    PV.tag:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -6, 5)
    -- How it went: used (its spell cast) or ran out (0.23.0)
    PV.exitTag = over:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    PV.exitTag:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", 6, 5)
    -- Stacks: 1 to the maximum, play, ends soon
    local y = -34 - SH - 10
    PV.stackLabel = Text(col, "GameFontHighlightSmall", L.STACKS_LABEL)
    PV.stackLabel:SetPoint("TOPLEFT", col, "TOPLEFT", 10, y - 5)
    PV.stackBtns = {}
    for i = 1, 5 do
        local b = Button(col, tostring(i), 26, 22, function()
            PV.play, PV.n = false, i
            PV.timeKey = nil
            S.Refresh()
        end)
        b:SetPoint("TOPLEFT", col, "TOPLEFT", 52 + (i - 1) * 28, y)
        PV.stackBtns[i] = b
    end
    PV.playBtn = Button(col, L.PLAY_STACKS, 62, 22, function()
        PV.play = not PV.play
        if PV.play then S.RestartPreview() end
        S.Refresh()
    end, L.PLAY_STACKS, L.PLAY_STACKS_TIP)
    PV.playBtn:SetPoint("TOPLEFT", col, "TOPLEFT", 52 + 5 * 28 + 4, y)
    PV.playBtn:Hide()   -- 0.23.15: Play at the top does the stacks too
    PV.soonBtn = Button(col, L.ENDS_SOON, 92, 22, function()
        PV.endsSoon = not PV.endsSoon
        S.RestartPreview()
        S.Refresh()
    end, L.ENDS_SOON, L.ENDS_SOON_TIP)
    PV.soonBtn:SetPoint("TOPRIGHT", col, "TOPRIGHT", -10, y)
    -- Thumbnails: the look at each count (click one to hold it)
    local row = CreateFrame("Frame", nil, col)
    row:SetPoint("TOPLEFT", col, "TOPLEFT", 10, y - 30)
    row:SetSize(SW, 86)
    PV.thumbRow = row
    for i = 1, 5 do
        local t = CreateFrame("Button", nil, row, BACKDROP)
        t:SetSize(60, 86)
        t.sets = {}
        if t.SetBackdrop then
            t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            t:SetBackdropColor(0.04, 0.04, 0.06, 0.9)
            t:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        pcall(t.SetClipsChildren, t, true)
        local lb = Text(t, "GameFontHighlightSmall")
        lb:SetPoint("BOTTOM", t, "BOTTOM", 0, 4)
        lb:SetJustifyH("CENTER")
        t.label = lb
        t:SetScript("OnClick", function() PV.play, PV.n = false, i; S.Refresh() end)
        PV.thumbs[i] = t
    end
    -- Size and placing
    local place = CreateFrame("Frame", nil, col)
    place:SetPoint("BOTTOMLEFT", col, "BOTTOMLEFT", 0, 0)
    place:SetSize(RIGHT_W, 136)
    local line = place:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.2)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", place, "TOPLEFT", 10, -2); line:SetPoint("TOPRIGHT", place, "TOPRIGHT", -10, -2)
    Slider(place, 10, -10, L.SIZE, L.SIZE_TIP, 0.4, 3, 0.05, "scale", nil, 170)
    -- 0.23.17: Sharp size (the game's pictures at their own size, one picture pixel per screen pixel)
    local sharp = Button(place, L.SHARP, 140, 22, function()
        local v = D().SharpScale(ns.Cur())
        if v then ns.SetOption("scale", v); S.Refresh() end
    end, L.SHARP, L.SHARP_TIP)
    sharp:SetPoint("TOPLEFT", place, "TOPLEFT", 140, -36)
    S.sharpBtn = sharp
    local sharpNote = Text(place, "GameFontDisableSmall")
    sharpNote:SetPoint("LEFT", sharp, "RIGHT", 8, 0)
    sharpNote:SetPoint("RIGHT", place, "RIGHT", -10, 0)
    sharpNote:SetJustifyH("LEFT")
    OnRefresh(function()
        local v = D().SharpScale(ns.Cur())
        pcall(sharp.SetEnabled, sharp, v ~= nil)
        if v then sharpNote:SetText(("%d%%"):format(floor(v * 100 + 0.5)))
        else sharpNote:SetText(L.SHARP_NONE) end
    end)
    local pb = Button(place, L.PLACE_ON_SCREEN, RIGHT_W - 20 - 96, 28, function() ns.Display:StartPlacing(true) end,
        L.PLACE_ON_SCREEN, L.MOVE_TIP)
    pb:SetPoint("TOPLEFT", place, "TOPLEFT", 10, -66)
    S.placeBtn = pb
    local cb = Button(place, L.CENTER, 90, 28, function() ns.Display:Center() end)
    cb:SetPoint("LEFT", pb, "RIGHT", 6, 0)
    local hint = Text(place, "GameFontDisableSmall", L.PLACE_HINT)
    hint:SetPoint("TOPLEFT", place, "TOPLEFT", 10, -100)
    hint:SetWidth(RIGHT_W - 20)
    OnRefresh(function()
        -- A gradient multiplies the texture's color: white under it, the flat color if there is none
        local lo, hi, flat
        if PV.bright then lo, hi, flat = { 0.70, 0.52, 0.28 }, { 0.92, 0.76, 0.50 }, { 0.80, 0.62, 0.36 }
        else lo, hi, flat = { 0.03, 0.035, 0.05 }, { 0.10, 0.11, 0.14 }, { 0.06, 0.07, 0.09 } end
        local done = false
        if PV.bg.SetGradient and CreateColor then
            PV.bg:SetColorTexture(1, 1, 1, 1)
            done = pcall(PV.bg.SetGradient, PV.bg, "VERTICAL", CreateColor(lo[1], lo[2], lo[3], 1), CreateColor(hi[1], hi[2], hi[3], 1))
        end
        if not done then PV.bg:SetColorTexture(flat[1], flat[2], flat[3], 1) end
        local p = ns.PROC_BY[ns.Selected()]
        if PV.key ~= ns.Selected() then   -- another alert: its stacks from the start if it plays,
            PV.key = ns.Selected()          -- else held still at the maximum (0.23.15)
            PV.play = PV.anim and p.stacks ~= nil
            PV.n = p.stacks
            S.RestartPreview()
        end
        if not p.stacks then PV.shownN = nil
        else PV.shownN = StackNow(p, GetTime() - PV.t0) end
        SetStackButtons()
        PaintPreview()
        PaintThumbs()
    end)
end

----------------------------------------------------------------------
-- Open, close, refresh
----------------------------------------------------------------------
function S.Refresh()
    if not (win and win:IsShown()) then return end
    for _, fn in ipairs(refreshers) do
        local ok, err = pcall(fn)
        if not ok and ns.debug then ns.Print("settings: " .. tostring(err)) end
    end
end

local function Build()
    if win then return end
    win = MakeWindow()
    S.win = win
    TopBar(win)
    LeftColumn(win)
    Middle(win)
    StyleTab(pages.style)
    LookTab(pages.look)
    StacksTab(pages.stacks)
    TimerTab(pages.timer)
    Right(win)
    S.OnTab = function(name)
        S.Refresh()
    end
    -- The preview runs only while the window is open
    local ticker = CreateFrame("Frame", nil, win)
    ticker:SetScript("OnUpdate", function() pcall(Tick) end)

    win:SetScript("OnHide", function() if GameTooltip then GameTooltip:Hide() end end)
end
S.Build = Build

-- Opens the window (it can open in combat: nothing in it is protected; placing can't)
function S:Open()
    Build()
    local was = win:IsShown()
    -- Fits the screen: smaller on a small screen, never bigger
    local uw, uh = UIParent:GetWidth() or W, UIParent:GetHeight() or H
    local k = min(1, (uw - 20) / W, (uh - 20) / H)
    if k > 0 then win:SetScale(k) end
    win:Show()
    win:Raise()
    if not was then S.RestartPreview() end
    ShowTab(current)
    S.Refresh()
end
function S:Hide() if win then win:Hide() end end
function S:IsShown() return win and win:IsShown() or false end
function S:Toggle() if S:IsShown() then S:Hide() else S:Open() end end
