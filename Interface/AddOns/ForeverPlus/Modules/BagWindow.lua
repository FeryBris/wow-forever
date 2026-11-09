-- The bag window, where you want it.
--
-- Asked for by the owner on 2026-09-26, and deliberately narrow: **only while
-- the bags are combined into one window**, which is how this client starts. A
-- player who switched to separate bags gets the game's own placement, exactly
-- as before; that case can follow once this one has been seen.
--
-- **How the game places it**, read in Blizzard's own interface code for the
-- engine this client runs, since the combined window does not exist in the
-- Classic code at all: UpdateContainerFrameAnchors clears the points of every
-- open bag window and pins the first one to the bottom right, every time a bag
-- opens or closes. So a window moved by hand is put back the next time the
-- game looks. This hooks that function and, after the game has placed the
-- window, puts it where the player left it. The game still does everything
-- else it does there, including the scale.
--
-- **Hold Shift and drag**, by the owner's decision and against the
-- recommendation. Blizzard lays an invisible button over the whole title bar,
-- `ContainerFramePortraitButtonRouterTemplate`, which opens the bag menu on the
-- mouse going *down*, so it swallowed every drag that started there: the first
-- version of this module made the window movable and nobody could move it,
-- measured by the owner the same day. The recommendation was a grip of our own
-- over the title, leaving the menu to the bag icon alone. The owner kept the
-- game's behaviour whole instead: a click on the title still opens the menu,
-- and only while Shift is held does the title turn into a grip. Shift counts on
-- the rest of the window too, so a missed item slot never moves it by accident.
--
-- Edit Mode does not own this window. Its Bags system is the bar of bag
-- buttons, not the window the bags open in.
--
-- **Nothing here calls Blizzard's own bag code**, since 2026-10-04. The owner
-- found the game refusing to use Waylaid Supplies from the bags, "ForeverPlus
-- has been blocked from an action", with UseContainerItem named. The cause was
-- this file: `ContainerFrameSettingsManager:GetBagsShown()` looks like a
-- question and is not one. It builds the list of open bag windows when the
-- list is empty and keeps it in `self.bagsShown`, and ContainerFrame_OnShow
-- empties it just before our OnShow hook ran. So the hook built Blizzard's
-- list in this addon's name, the game's own placement code read it at every
-- bag that opened, and the bag code ran tainted from there, until an item
-- whose use is protected was refused. `UpdateContainerFrameAnchors`, called
-- from here to give the window back, did the same and more.
--
-- So the open bag windows are counted here by name, and giving the window back
-- puts it where the game last put it, read off the frame, rather than asking
-- the game to place it again. A Blizzard function is called from this file
-- only where its code was read and found to write nothing:
-- `IsUsingCombinedBags` is one.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("BagWindow", {
    title   = L["Movable Bag Windows"],
    default = true,
    desc    = L["Hold Shift and drag the bag window by its title bar to move it, "
           .. "while your bags are combined into one window."],
    group   = "display",
    order   = 35,
    options = {
        { type = "action", label = L["Reset position"], width = 150,
          desc  = L["Puts the bag window back where the game places it."],
          run   = function(mod) mod:ResetPosition() end },

        -- Where it was left. No default: until it is dragged, the game places
        -- it, and `positioned` says that somebody moved it.
        { key = "positioned", type = "store" },
        { key = "point",      type = "store" },
        { key = "relPoint",   type = "store" },
        { key = "x",          type = "store" },
        { key = "y",          type = "store" },
    },
})

local function Window()
    return _G.ContainerFrameCombinedBags
end

--- Are the bags combined into one window right now?
--
-- The game's own answer where it has one, the console variable behind it
-- otherwise. Asked every time rather than once, because the player can switch
-- in the bag window's own menu while the addon runs.
local function Combined()
    local manager = _G.ContainerFrameSettingsManager
    if type(manager) == "table" and type(manager.IsUsingCombinedBags) == "function" then
        local ok, yes = pcall(manager.IsUsingCombinedBags, manager)
        if ok then return FP:Truth(yes) == true end
    end
    local get = (C_CVar and C_CVar.GetCVarBool) or _G.GetCVarBool
    if not get then return false end
    local ok, value = pcall(get, "combinedBags")
    return ok and FP:Truth(value) == true
end

--- Can an addon move this frame right now?
--
-- The owner measured it unprotected on 2026-09-26, out of combat. It is asked
-- anyway, because a frame can become protected when something protected is
-- put inside it, and a move it refuses waits for the fight to end instead of
-- raising.
local function Movable(frame)
    if not (InCombatLockdown and InCombatLockdown()) then return true end
    return not (frame.IsProtected and frame:IsProtected())
end

local function Shift()
    return IsShiftKeyDown and IsShiftKeyDown() and true or false
end

--- Keeps the other bag windows on screen once ours has moved.
--
-- Reported by the owner the same day: drag the combined window to the left
-- edge and the reagent bag disappears off the screen. The game hangs every
-- further bag window off the **left** side of the combined one, which is right
-- where the game puts the combined window, at the bottom right, and wrong
-- anywhere near the left edge. So any window the game hung off ours that no
-- longer fits on the left is hung off the right side instead.
--
-- Only windows anchored to ours are touched, and only when they are off the
-- screen, so the game's own arrangement stands wherever it fits. And the way
-- back as well: a window moved to the right that would now run off the right
-- edge goes back to the left, where the game had it.
local SIDE_GAP = 11   -- the gap the game leaves between two bag windows

-- Compared in screen units, because a bag window carries a scale of its own.
local function OffRight(f)
    local right, screen = f:GetRight(), UIParent:GetRight()
    if not (right and screen) then return false end
    return right * f:GetEffectiveScale() > screen * UIParent:GetEffectiveScale() + 1
end

--- Every bag window the game has open, counted by name.
--
-- Not `ContainerFrameSettingsManager:GetBagsShown()`, which writes its answer
-- into Blizzard's own table when that is empty: see the head of this file.
-- ContainerFrame1 and up are the separate bag windows on this build, as many
-- as NUM_CONTAINER_FRAMES, and a few more are asked for in case that grows.
local function OpenBagWindows()
    local out = {}
    local count = tonumber(_G.NUM_CONTAINER_FRAMES) or 13
    for index = 1, count + 4 do
        local other = _G["ContainerFrame" .. index]
        if type(other) == "table" and other.IsShown and other:IsShown() then
            out[#out + 1] = other
        end
    end
    return out
end

local function KeepOthersOnScreen(frame)
    for _, other in ipairs(OpenBagWindows()) do
        if other ~= frame and other.GetPoint and Movable(other) then
            local _, relativeTo = other:GetPoint(1)
            if relativeTo == frame then
                local left = other:GetLeft()
                if left and left < 0 then
                    other:ClearAllPoints()
                    other:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", SIDE_GAP, 0)
                elseif OffRight(other) then
                    other:ClearAllPoints()
                    other:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -SIDE_GAP, 0)
                end
            end
        end
    end
end

--- Puts the window where the player left it, if there is anywhere to put it.
function M:Apply()
    local frame = Window()
    if not (self.enabled and frame and self.db.positioned and self.db.point) then
        return
    end
    if not Combined() then return end

    if not Movable(frame) then
        if not self.waiting then
            self.waiting = true
            FP:OutOfCombat("BagWindow:Apply", function()
                M.waiting = nil
                M:Apply()
            end)
        end
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(self.db.point, UIParent, self.db.relPoint or self.db.point,
        self.db.x or 0, self.db.y or 0)
    KeepOthersOnScreen(frame)
end

-- Where the game itself put the window, read off it each time the game has
-- placed it and before this addon moves it: { point, relativeTo, relPoint,
-- x, y }. Kept so that giving the window back needs nothing of the game's.
local gameAnchor

--- Writes down where the game just placed the window.
local function NoteGameAnchor()
    local frame = Window()
    if not (frame and frame:IsShown() and frame:GetNumPoints() > 0) then return end
    gameAnchor = { frame:GetPoint(1) }
end

--- Puts the window back where the game places it, at once.
--
-- To the spot the game itself chose the last time it placed the window, read
-- off the frame, see NoteGameAnchor. Not by calling UpdateContainerFrameAnchors,
-- which runs the game's placement in this addon's name and is what blocked
-- using items from the bags on 2026-10-04; see the head of this file. Before
-- the game has placed the window once this session there is nothing to put it
-- back to, and nothing needed either: the game places it when it opens.
local function GiveBack()
    local frame = Window()
    if not (gameAnchor and frame and frame:IsShown() and Movable(frame)) then
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint(unpack(gameAnchor))
    KeepOthersOnScreen(frame)
end

-- Below, and named here because the watch on the release calls it.
local StopDrag

--- Ends a drag the moment the left button is no longer held.
--
-- A safety net under OnDragStop, reported by the owner on 2026-10-04: the
-- window hung on the cursor after the button had been let go. The grip took
-- the mouse only while Shift was held, so letting go of Shift before the
-- button took the mouse from the grip in the middle of the drag, and the end
-- of the drag never reached it. The grip keeps the mouse while a drag runs
-- since, see SyncGrip, and this asks the button itself, every frame while a
-- drag runs and never otherwise.
local watcher
local function WatchRelease(frame)
    if type(IsMouseButtonDown) ~= "function" then return end
    watcher = watcher or CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function()
        local ok, down = pcall(IsMouseButtonDown, "LeftButton")
        if ok and not down then StopDrag(frame) end
    end)
end

local function StartDrag(frame)
    if not (M.enabled and Shift() and Combined() and Movable(frame)) then return end
    frame:StartMoving()
    M.dragging = true
    WatchRelease(frame)
end

function StopDrag(frame)
    if not M.dragging then return end
    M.dragging = nil
    if watcher then watcher:SetScript("OnUpdate", nil) end
    frame:StopMovingOrSizing()
    -- Moving a named frame by hand makes the client remember it in its own
    -- layout cache and put it back there by itself at the next login, which
    -- would be a second place deciding where this window goes.
    if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, false) end

    local point, _, relPoint, x, y = frame:GetPoint()
    if point then
        M.db.point, M.db.relPoint, M.db.x, M.db.y = point, relPoint, x, y
        M.db.positioned = true
    end
    KeepOthersOnScreen(frame)
    -- Shift may have gone up during the drag, and the grip kept the mouse for
    -- it until now.
    M:SyncGrip()
end

--- The grip takes the mouse while Shift is held, and gives it back after.
--
-- While it has the mouse it covers Blizzard's title button, so the press that
-- starts a drag cannot open the bag menu underneath. Without Shift it takes
-- nothing, and the title bar is the game's again. **A drag that is running
-- keeps it** until it ends, whatever Shift does in between: see WatchRelease.
function M:SyncGrip()
    local grip = self.grip
    if not grip then return end
    local wanted = self.enabled and Combined() and (Shift() or self.dragging)
    grip:EnableMouse(wanted and true or false)
end

--- Makes the window draggable and hooks the game's placement, once.
--
-- Once, because none of it can be taken back: a hook stays for the session and
-- the frame keeps its drag handlers. Everything here asks whether the module
-- is on before it does anything, so switching it off is switching it off.
function M:Prepare()
    if self.prepared then return true end
    local frame = Window()
    if not frame then return false end
    self.prepared = true

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnDragStart", StartDrag)
    frame:HookScript("OnDragStop", StopDrag)

    -- The grip over the title bar. Our own frame, without a template, above
    -- Blizzard's title button; the title container is where that button is
    -- anchored too, and the top edge of the window stands in when it is absent.
    local grip = CreateFrame("Frame", nil, frame)
    local title = frame.TitleContainer
    if type(title) == "table" and title.GetObjectType then
        grip:SetPoint("TOPLEFT", title, "TOPLEFT")
        grip:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT")
    else
        grip:SetPoint("TOPLEFT", frame, "TOPLEFT")
        grip:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
        grip:SetHeight(24)
    end
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:EnableMouse(false)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() StartDrag(frame) end)
    grip:SetScript("OnDragStop", function() StopDrag(frame) end)
    self.grip = grip

    -- After the game has placed its bag windows, which it does every time one
    -- opens or closes. A secure hook runs after the original and changes
    -- nothing about how the original runs.
    if type(_G.UpdateContainerFrameAnchors) == "function" then
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            FP:Safe("BagWindow:NoteGameAnchor", NoteGameAnchor)
            FP:Safe("BagWindow:Apply", M.Apply, M)
        end)
    end
    frame:HookScript("OnShow", function()
        FP:Safe("BagWindow:Apply", M.Apply, M)
        FP:Safe("BagWindow:SyncGrip", M.SyncGrip, M)
    end)
    return true
end

--- The only thing that ever forgets the position: the button on the page.
function M:ResetPosition()
    self.db.positioned = nil
    self.db.point, self.db.relPoint, self.db.x, self.db.y = nil, nil, nil, nil
    GiveBack()
    FP:Print(L["Bag window is back where the game places it."])
end

function M:OnEnable()
    if not self:Prepare() then
        return FP:Warn(L["BagWindow: this build has no combined bag window, so "
            .. "there is nothing to move."])
    end

    -- Shift going down and up is what arms and disarms the grip.
    self.events = self.events or CreateFrame("Frame")
    self.events:SetScript("OnEvent", function()
        FP:Safe("BagWindow:SyncGrip", M.SyncGrip, M)
    end)
    self.events:RegisterEvent("MODIFIER_STATE_CHANGED")

    self:SyncGrip()
    self:Apply()
end

function M:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if self.grip then self.grip:EnableMouse(false) end
    GiveBack()
end

--- A profile switch moves the window to that profile's place, or gives it back.
function M:Reapply()
    if self.db.positioned then self:Apply() else GiveBack() end
end
