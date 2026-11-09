-- Moving every bar and the info bar at once.
--
-- Planned with the owner on 2026-10-14 and 15, rounds 5 to 7, see
-- planning/1.0.0/PLANNING-BUFFS-AND-LAYOUT.md under *Shared positioning*. A
-- button in the settings window's footer starts it, from every page; so does
-- "Position on screen" in bar management, with that bar marked. The settings
-- disappear, every bar shows a labelled stand in, inactive and empty ones
-- included, the info bar shows one too, and a small window asks to confirm the
-- changes.
--
-- **Nothing is saved until Apply.** The stand ins are frames of their own, so
-- the bars on screen, their saved places and the info bar's Hearthstone button
-- are not touched while somebody drags. Cancel, Escape, combat starting, a
-- profile switch or the window closing by any other route throw the draft
-- away. Combat keeps the settings closed until it ends, and the draft does not
-- come back.
local ADDON, FP = ...
local L = FP.L
local Bars = FP.Bars

local session          -- the running session, or nil
local pool = {}        -- stand ins, reused: [index] = { frame, icons, label }
local dialog

-- Two icons per stand in, the way every display's preview always looked: one
-- running out, one missing, both the question mark so nobody takes them for a
-- warning.
local function Samples()
    return {
        { icon = FP.PREVIEW_ICON, kind = "expiring", remaining = 125, rid = "1" },
        { icon = FP.PREVIEW_ICON, kind = "missing", rid = "2" },
    }
end

local function StopDragging()
    if not session then return end
    for _, holder in ipairs(session.holders) do
        holder.frame:StopMovingOrSizing()
    end
end

--- A stand in, made the first time it is needed and kept for the next session.
local function Holder(index)
    local holder = pool[index]
    if holder then return holder end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    local label = FP:FontString(frame, "OVERLAY", "heading")
    label:SetPoint("BOTTOM", frame, "TOP", 0, 4)

    holder = { frame = frame, icons = {}, label = label }

    local function Start()
        if not session then return end
        frame:StartMoving()
    end
    local function Stop()
        frame:StopMovingOrSizing()
        if not session then return end
        holder.moved = true
        -- Drawn again where it now is, so a bar near the edge wraps the way
        -- it will when it is used.
        if holder.Redraw then holder.Redraw() end
    end
    frame:SetScript("OnDragStart", Start)
    frame:SetScript("OnDragStop", Stop)
    holder.Start, holder.Stop = Start, Stop

    pool[index] = holder
    return holder
end

--- Every icon of a stand in moves the whole bar, not only the first.
local function GrabbableIcons(holder)
    for _, icon in ipairs(holder.icons) do
        if not icon.grabbable then
            icon:EnableMouse(true)
            icon:RegisterForDrag("LeftButton")
            icon:SetScript("OnDragStart", function() holder.Start() end)
            icon:SetScript("OnDragStop", function() holder.Stop() end)
            icon.grabbable = true
        end
    end
end

-- ---------------------------------------------------------------------------
-- The info bar's stand in
--
-- Of its own rather than the bar itself, the plan's proposal: the bar carries
-- the Hearthstone's secure button, which cannot move during a fight, and a
-- session that combat cancels must never have to move it back.
-- ---------------------------------------------------------------------------

local infoHolder

local function InfoStandIn(selected)
    local info = FP:GetModule("InfoBar")
    if not (info and info.db) then return nil end

    if not infoHolder then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("HIGH")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        local bg = FP:Texture(frame, "BACKGROUND", FP.colors.bg)
        bg:SetAllPoints()
        FP:AddBorder(frame)
        local text = FP:FontString(frame, "OVERLAY", "normal")
        text:SetPoint("CENTER")
        infoHolder = { frame = frame, text = text }
        frame:SetScript("OnDragStart", function()
            if session then frame:StartMoving() end
        end)
        frame:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            if session then infoHolder.moved = true end
        end)
    end

    local frame, real = infoHolder.frame, info.frame
    local width, height = 200, 22
    if real and real:GetWidth() > 1 then width, height = real:GetWidth(), real:GetHeight() end
    frame:SetSize(width, height)
    frame:ClearAllPoints()
    local db = info.db
    if db.positioned and db.point then
        frame:SetPoint(db.point, UIParent, db.relPoint or db.point, db.x or 0, db.y or 0)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -2)
    end
    infoHolder.text:SetText(FP:T(L["Info bar"]))
    infoHolder.text:SetTextColor(unpack(selected and FP.colors.on or FP.colors.textOn))
    infoHolder.moved = false
    frame:Show()
    return infoHolder
end

-- ---------------------------------------------------------------------------
-- The session
-- ---------------------------------------------------------------------------

local function Context()
    local menu = _G.ForeverPlusMenu
    local menuModule = FP:GetModule("Menu")
    local managerShown, managerSelected = FP:BarManagerState()
    return {
        menu = menu and menu:IsShown() or false,
        scroll = menuModule and menuModule.scroll and menuModule.scroll:GetVerticalScroll() or 0,
        manager = managerShown,
        selected = managerSelected,
    }
end

local function HideWindows()
    for _, name in ipairs({ "ForeverPlusMenu", "ForeverPlusBarsRestore",
                            "ForeverPlusQuestion" }) do
        local f = _G[name]
        if f and f:IsShown() then f:Hide() end
    end
    FP:HideBarManager()
end

local function RestoreWindows(context)
    if not context then return end
    if context.menu then
        local menuModule = FP:GetModule("Menu")
        if menuModule and menuModule.Toggle and not (_G.ForeverPlusMenu
           and _G.ForeverPlusMenu:IsShown()) then
            menuModule:Toggle()
            if menuModule.scroll then
                menuModule.scroll:SetVerticalScroll(context.scroll or 0)
                if menuModule.ClampScroll then menuModule:ClampScroll() end
                if menuModule.UpdateScrollIndicator then menuModule:UpdateScrollIndicator() end
            end
        end
    end
    if context.manager then FP:OpenBarManager(context.selected) end
end

local function TakeDown()
    StopDragging()
    for _, holder in ipairs(pool) do holder.frame:Hide() end
    if infoHolder then
        infoHolder.frame:StopMovingOrSizing()
        infoHolder.frame:Hide()
    end
    FP.movingBars = false
    FP:RedrawBars()
    -- The info bar comes back on its next tick; this is sooner.
    local info = FP:GetModule("InfoBar")
    if info and info.Update then FP:Safe("InfoBar:Update", info.Update, info) end
end

--- Ends a session. `apply` keeps what was moved, and only then.
local function Finish(apply, waitForCombat)
    local current = session
    if not current then return end
    session = nil
    if dialog and dialog:IsShown() then
        dialog.finishing = true
        dialog:Hide()
        dialog.finishing = nil
    end

    -- Never into another profile: a profile switched during the session
    -- throws the draft away, whatever was pressed.
    if apply and FP.db == current.profile then
        local store = Bars.Store()
        for _, holder in ipairs(current.holders) do
            local bar = store and Bars.Get(store, holder.id)
            if bar and holder.moved then
                local point, _, relPoint, x, y = holder.frame:GetPoint()
                bar.positioned = true
                bar.point, bar.relPoint, bar.x, bar.y = point, relPoint, x, y
            end
        end
        local info = FP:GetModule("InfoBar")
        if infoHolder and infoHolder.moved and info and info.db then
            local point, _, relPoint, x, y = infoHolder.frame:GetPoint()
            info.db.positioned = true
            info.db.point, info.db.relPoint, info.db.x, info.db.y = point, relPoint, x, y
            if info.ApplyPosition then FP:Safe("InfoBar:ApplyPosition", info.ApplyPosition, info) end
        end
    end

    TakeDown()

    current.watcher:UnregisterAllEvents()
    if waitForCombat then
        -- The settings stay closed while the fight lasts, and open again when
        -- it ends, without the draft.
        current.watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        current.watcher:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            RestoreWindows(current.context)
        end)
    else
        RestoreWindows(current.context)
    end
end

local function Dialog()
    if dialog then return dialog end
    local PAD, HEADER = FP.PANEL_PAD, FP.PANEL_HEADER
    local width = 320
    local f = FP:CreatePanel("ForeverPlusMover", width, L["Confirm changes?"], "")
    f:SetFrameStrata("FULLSCREEN")

    local text = FP:FontString(f, "OVERLAY", "body")
    text:SetWidth(width - 2 * PAD)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetPoint("TOPLEFT", PAD, -(HEADER + 4))
    f.text = text

    local apply = FP:CreateButton(f, L["Apply"], 120, function() Finish(true) end)
    apply:SetPoint("BOTTOMLEFT", PAD, PAD)
    local cancel = FP:CreateButton(f, L["Cancel"], 120, function() Finish(false) end)
    cancel:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    -- Escape, the close button, or anything else that hides this window ends
    -- the session without keeping anything.
    f:SetScript("OnHide", function(self)
        if not self.finishing and session then Finish(false) end
    end)

    -- A profile switched while the window is up ends it too.
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.25 then return end
        elapsed = 0
        if session and FP.db ~= session.profile then Finish(false) end
    end)

    dialog = f
    return f
end

--- Starts moving the bars and the info bar.
--
-- @param selected  a bar's id, or "info", to mark one among them; nil for none
function FP:MoveBars(selected)
    if session then return end
    if InCombatLockdown and InCombatLockdown() then
        return FP:Print(L["The bars cannot be moved during combat."])
    end
    local store = Bars.Store()
    if not store then return end

    session = {
        profile = FP.db, holders = {}, context = Context(),
        watcher = CreateFrame("Frame"),
    }
    session.watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    session.watcher:SetScript("OnEvent", function() Finish(false, true) end)

    HideWindows()
    FP.movingBars = true
    FP:HideBars()

    for index, id in ipairs(Bars.Ids(store)) do
        local bar = Bars.Get(store, id)
        local holder = Holder(index)
        holder.id, holder.moved = id, false
        FP:PlaceAsBar(holder.frame, id, bar, store)
        holder.Redraw = function()
            local current = Bars.Get(Bars.Store(), id)
            if current then
                FP:DrawBar(holder, current, Samples())
                GrabbableIcons(holder)
            end
        end
        holder.Redraw()
        holder.label:SetText(Bars.NameOf(store, id))
        holder.label:SetTextColor(unpack(id == selected and FP.colors.on or FP.colors.textOn))
        session.holders[#session.holders + 1] = holder
    end
    for index = #session.holders + 1, #pool do pool[index].frame:Hide() end

    InfoStandIn(selected == "info")
    local info = FP:GetModule("InfoBar")
    if info and info.Update then FP:Safe("InfoBar:Update", info.Update, info) end

    local f = Dialog()
    f.text:SetText(FP:T(L["Drag the bars and the info bar into place. Apply "
        .. "saves positions; Cancel discards changes."]))
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:Show()
    f:SetHeight(FP.PANEL_HEADER + 4 + f.text:GetStringHeight() + 16 + 22 + FP.PANEL_PAD)
end

--- Whether a session is running, for the info bar to stand aside.
function FP:MovingBars()
    return session ~= nil
end
