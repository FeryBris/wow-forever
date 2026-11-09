-- How many bag slots are free, written on the backpack itself.
--
-- Phase 5. It began as an item on the info bar and the owner moved it out on
-- 2026-09-23: a number about the bags belongs on the bags, not in a row of
-- unrelated figures in the middle of the screen. That is the same judgement
-- Leatrix Plus made, and it is why this is a module of its own on the Gameplay
-- page rather than a switch on the bar.
--
-- **The client did not show this on 69977.** Measured 2026-09-23:
-- `displayFreeBagSlots`, which is the console variable other builds carry for
-- exactly this, did not exist, and the owner confirmed by looking that no
-- number appeared. The backpack button does carry a `freeSlots` field, so
-- Blizzard's own display was half present and never filled, and this module
-- uses it when it can.
--
-- **On 70009 it does, after a reload.** Reported by the owner on 2026-09-26:
-- Blizzard's own count, in its own format of "(19)", appears after every
-- /reload and sits on top of ours, and a fresh login shows ours alone. Two
-- numbers in one place is the thing this module was written not to be, so
-- while it is on, the client's count is made transparent. See NativeCounts.
--
-- **And the backpack icon keeps its size**, since 2026-09-28. The client
-- shrinks that icon into a black frame after it has darkened the button, and
-- never gives the size back. See KeepIconWhole. It lives here because this is
-- the button the module writes on, and a shrunken icon under our number gets
-- blamed on the number.
--
-- **Special bags count on their own button**, also since 2026-09-28, asked for
-- on CurseForge. A quiver, a soul bag or a herb bag holds one kind of thing, so
-- its free slots are not room for loot, and the backpack now counts only the
-- ordinary bags, as the client's own count does. Each special bag, the reagent
-- bag among them, shows its own number on its own button: the owner's call, by
-- the rule that a number about the bags belongs on the bags. See Count.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("BagSlots", {
    title   = L["Free Bag Slots"],
    default = true,
    desc    = L["Shows on the backpack how many bag slots are free. Special "
           .. "bags are shown separately."],
    group   = "display",
    order   = 30,
    options = {
        { key = "showTotal", type = "toggle", default = true,
          label = L["Show the total as well"],
          desc = L["Shows 14/80 instead of 14."] },
    },
})

-- The button the number is drawn on. Named rather than searched for: it came
-- back present in the 2026-09-23 measurement, and a module that quietly draws
-- nothing is the failure this project keeps writing pitfalls about.
local BUTTON = "MainMenuBarBackpackButton"

--- Where the reagent bag sits: the client's own index where this build names
--- it, else the slot after the last ordinary bag, which is where its code
--- counts it.
local function ReagentBag()
    local index = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    return index or ((NUM_BAG_SLOTS or 4) + 1)
end

--- The slot button a bag is equipped in.
--
-- CharacterBag0Slot holds bag 1, which is the client's own numbering, read in
-- BaseBagSlotButtonMixin:GetBagID; the reagent bag has a button of its own.
local function BagButton(bag)
    if bag == ReagentBag() then return _G.CharacterReagentBag0Slot end
    return _G["CharacterBag" .. (bag - 1) .. "Slot"]
end

--- Free slots in the backpack and every ordinary bag, and each special bag on
--- its own.
--
-- **Ordinary means bag family 0**, and the reagent bag is special: see
-- FP:ReadBags in `Core/Util.lua`, which reads the bags for the info bar as
-- well since 2026-10-09.
--
-- @return free, total, and { [bag] = { free = n, total = n } } for the special
--         bags; nil when the client offers no slot counts
local function Count()
    local bags = FP:ReadBags()
    if not bags then return nil end

    local free, total, special = 0, 0, {}
    for _, bag in ipairs(bags) do
        if bag.reagent or bag.family ~= 0 then
            special[bag.bag] = { free = bag.free, total = bag.total }
        else
            free, total = free + bag.free, total + bag.total
        end
    end
    return free, total, special
end

--- The font string, Blizzard's own where it exists and ours where it does not.
--
-- The `freeSlots` field is on the button and the client never writes to it,
-- since the setting that drove it is gone. Using it keeps one number in one
-- place; creating a second one beside a hidden first is how two displays end up
-- disagreeing.
local function Label()
    local button = _G[BUTTON]
    if not button then return nil end

    local existing = rawget(button, "freeSlots")
    if type(existing) == "table" and existing.SetText and existing.SetPoint then
        return existing
    end

    if M.label then return M.label end
    -- Low on the button and clear of the border, which is where the client puts
    -- this number on the builds that have it. White rather than the gold of a
    -- button caption: the first version of this module wrote gold digits onto a
    -- gold backpack.
    M.label = FP:IconText(button, "BOTTOM", 0, 2)
    return M.label
end

-- [button] = the number written on that bag button, made the first time a
-- special bag sits there and kept, so a bag swapped out leaves an empty string
-- rather than a stale number.
local bagLabels = {}

local function BagLabel(button)
    local fs = bagLabels[button]
    if not fs then
        fs = FP:IconText(button, "BOTTOM", 0, 2)
        bagLabels[button] = fs
    end
    return fs
end

--- The client's own count on a button, wherever this build keeps it, other than
--- the string this module writes into.
--
-- Two places, because the button has had two shapes: the Classic one names the
-- string after the button, the retail one hangs it on the button as `Count`.
-- Which one 70009 fills was not measured when this was written; both are
-- looked for, and a place that is not there costs nothing.
--
-- Every bag button has one, not only the backpack. The owner's screenshot of a
-- soul bag on 2026-09-28 showed the client's number at its bottom right, over
-- the one this module had just started writing there.
local function NativeCounts(button)
    if not button then return {} end
    local name = button.GetName and button:GetName()

    -- A fixed pair walked by index: ipairs would stop at a first place that is
    -- not there and never reach the second.
    local candidates = { rawget(button, "Count"), name and _G[name .. "Count"] or nil }
    local found, ours = {}, Label()
    for index = 1, 2 do
        local candidate = candidates[index]
        if type(candidate) == "table" and candidate.SetAlpha
           and candidate ~= ours and candidate ~= found[1] then
            found[#found + 1] = candidate
        end
    end
    return found
end

-- [button] = true for every button whose own count is transparent because of
-- this module, so what is given back is exactly what was taken.
local silenced = {}

--- Makes the client's count on a button invisible while this module writes
--- there, or gives it back.
--
-- **Transparent rather than hidden**, and that is deliberate. The client shows
-- and hides that string and rewrites its text as it sees fit, and a Hide from
-- here would be undone by the next Show from there. It never touches alpha, so
-- a zero set here holds, and everything the client does to the string carries
-- on underneath untouched. Giving back sets it to one, and only on a button
-- this module took it from.
local function Silence(button, silent)
    if not button or (not silent and not silenced[button]) then return end
    for _, native in ipairs(NativeCounts(button)) do
        pcall(native.SetAlpha, native, silent and 0 or 1)
    end
    silenced[button] = silent or nil
end

--- White on a hard shadow, see FP:StyleIconText.
--
-- Applied to whichever string we ended up with, ours or Blizzard's, because the
-- borrowed one carries whatever styling it was given for a display this build
-- never shows.
local function Style(label)
    FP:StyleIconText(label)
end

-- ---------------------------------------------------------------------------
-- The backpack icon, kept whole
--
-- A fault in the client, found on 2026-09-28 from a screenshot of the owner's
-- backpack: the icon sat at half its size inside a black frame, and a reload
-- put it right until the next time. Read in Blizzard's interface code for this
-- build, Blizzard_MainMenuBarBagButtons/Shared/MainMenuBarBagButtons.lua.
--
-- Whenever the game darkens the backpack button, which it does for a bag
-- search that finds nothing in the backpack and while it asks for an item the
-- backpack does not hold, a cursor waiting for something to enchant or to feed
-- a pet among them, `MainMenuBarBackpackMixin:UpdateItemContextOverlayTextures`
-- moves the mask that cuts the icon onto a smaller square, 4 points in at the
-- top left and 6 at the bottom right. **Nothing ever moves it back.** The
-- darkening ends, the mask stays, and the icon is drawn at half its size until
-- the interface is rebuilt. The other bag buttons darken without touching a
-- mask, which is why only the backpack ever looks like this.
--
-- So the masks are written down while the button is still as the game built
-- it, and put back every time the darkening has ended. While the button is dark
-- the game's own arrangement stands: that is what it was made for, and the
-- fault is only that it outlives the darkness.
--
-- The check in game is one line, `/dump
-- MainMenuBarBackpackButton.SquareMask:GetNumPoints()`: 1 as the game built
-- it, 2 once the game has moved it.
-- ---------------------------------------------------------------------------

-- Every mask the backpack carries, and where the game anchored it:
--   { mask = <MaskTexture>, points = { { point, relativeTo, relativePoint, x, y } } }
local maskHome

--- Writes down where the backpack's masks sit, once.
--
-- First when this file loads, which is before anybody could have searched a bag
-- or picked up a stone, and again on enabling, in case the button did not exist
-- yet at that moment. Both names are looked for because the client picks one by
-- the button's shape.
local function RecordMasks()
    if maskHome then return end
    local button = _G[BUTTON]
    if not button then return end

    maskHome = {}
    for _, key in ipairs({ "SquareMask", "CircleMask" }) do
        local mask = rawget(button, key)
        if type(mask) == "table" and mask.GetNumPoints and mask.SetPoint then
            local points = {}
            for index = 1, mask:GetNumPoints() do
                points[index] = { mask:GetPoint(index) }
            end
            if #points > 0 then
                maskHome[#maskHome + 1] = { mask = mask, points = points }
            end
        end
    end
end
FP:Safe("BagSlots:RecordMasks", RecordMasks)

--- Has the game moved this mask away from where it built it?
local function Moved(home)
    local mask = home.mask
    if mask:GetNumPoints() ~= #home.points then return true end
    for index, wanted in ipairs(home.points) do
        local point, relativeTo, relativePoint, x, y = mask:GetPoint(index)
        if point ~= wanted[1] or relativeTo ~= wanted[2]
           or relativePoint ~= wanted[3] or x ~= wanted[4] or y ~= wanted[5] then
            return true
        end
    end
    return false
end

--- Puts the backpack's masks back, once the button is no longer dark.
local function KeepIconWhole()
    if not maskHome then return end
    local button = _G[BUTTON]
    local overlay = button and rawget(button, "ItemContextOverlay")
    if type(overlay) == "table" and overlay.IsShown and overlay:IsShown() then
        return
    end

    for _, home in ipairs(maskHome) do
        if Moved(home) then
            home.mask:ClearAllPoints()
            for _, point in ipairs(home.points) do
                home.mask:SetPoint(unpack(point))
            end
        end
    end
end

--- Follows every decision the game makes about how dark the button is, which
--- is also the only moment it ever moves the mask.
--
-- A secure hook, so the game's own call runs exactly as before and this only
-- comes after it. Once per session, because a hook cannot be taken off; it asks
-- whether the module is on before doing anything, so switching the module off
-- hands the button back to the game, fault included.
local function HookBackpack()
    if M.hooked then return end
    local button = _G[BUTTON]
    if not (button and type(button.UpdateItemContextOverlay) == "function") then
        return
    end
    M.hooked = true
    hooksecurefunc(button, "UpdateItemContextOverlay", function()
        if M.enabled then FP:Safe("BagSlots:KeepIconWhole", KeepIconWhole) end
    end)
end

function M:Update()
    if not self.enabled then return end
    local label = Label()
    if not label then
        return FP:Warn(L["BagSlots: %s is missing on this build, so there is "
            .. "nowhere to write the count."], BUTTON)
    end

    local free, total, special = Count()
    if not free then
        return FP:Warn(L["BagSlots: C_Container does not offer the slot counts "
            .. "on this build."])
    end

    local function Text(spare, slots)
        return self.db.showTotal and string.format("%d/%d", spare, slots)
            or tostring(spare)
    end

    Style(label)
    label:SetText(Text(free, total))
    label:Show()
    -- Every time rather than once: the client builds or refills its own count
    -- when it pleases, a reload being one of those times.
    Silence(_G[BUTTON], true)

    -- Each special bag on its own button, with the client's number there made
    -- transparent as on the backpack. Every other bag button is emptied and
    -- given its number back, since the bag that was there may have been
    -- swapped for an ordinary one.
    local written = {}
    for bag, room in pairs(special) do
        local button = BagButton(bag)
        if button then
            local fs = BagLabel(button)
            fs:SetText(Text(room.free, room.total))
            fs:Show()
            Silence(button, true)
            written[button] = true
        end
    end
    for button, fs in pairs(bagLabels) do
        if not written[button] then
            fs:SetText("")
            Silence(button, false)
        end
    end
end

function M:OnEnable()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function() FP:Safe("BagSlots:Update", M.Update, M) end)
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- Equipping a bag changes the total without touching what is in it.
    self.frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    -- And swapping one bag for another; asked rather than assumed, because an
    -- event this build does not know raises when it is registered.
    pcall(self.frame.RegisterEvent, self.frame, "BAG_CONTAINER_UPDATE")

    -- The icon as well. Put right at once, too: the module may be switched on
    -- after the game has already shrunk it.
    FP:Safe("BagSlots:RecordMasks", RecordMasks)
    FP:Safe("BagSlots:HookBackpack", HookBackpack)
    FP:Safe("BagSlots:KeepIconWhole", KeepIconWhole)

    self:Update()
end

function M:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
    -- Blizzard's own string is borrowed rather than owned, so switching off
    -- empties it instead of hiding it: hiding a frame the client may later want
    -- to show itself is a change that outlives this module.
    local label = M.label or (function()
        local button = _G[BUTTON]
        local existing = button and rawget(button, "freeSlots")
        return (type(existing) == "table" and existing.SetText) and existing or nil
    end)()
    if label then pcall(label.SetText, label, "") end
    for _, fs in pairs(bagLabels) do fs:SetText("") end
    -- And the client's own counts come back, in the client's own format, on
    -- every button they were taken from.
    for button in pairs(silenced) do Silence(button, false) end
end

--- Changing the format should not tear the display down and build it again.
function M:Reapply()
    self:Update()
end
