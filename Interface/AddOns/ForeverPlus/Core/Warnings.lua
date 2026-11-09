-- The bars on screen, and the one place that knows how a warning icon looks.
--
-- Lifted out of BuffExpiry on 2026-09-20, when Consumables needed the same
-- thing, and each module owned a display of its own from then on. **Since the
-- redesign planned on 2026-10-14 and 15 the displays belong to the profile**,
-- see Core/Bars.lua: a bar is drawn here, and what it holds comes from every
-- page that has an entry on it. A module hands in what it wants to say, its
-- *contribution*, and never touches a bar itself, so a bar holding buffs and
-- consumables at once is the ordinary case rather than a special one.
--
-- A module switched off hands in nothing, so only its own icons leave a bar
-- they share with another page.
local ADDON, FP = ...
local L = FP.L

-- Shown when nothing else produced a picture.
--
-- **A warning that exists must be visible.** An icon frame with no texture is
-- drawn, occupies its place and shows nothing at all, which reads exactly like
-- the feature being broken and is the third time this shape of fault has cost
-- something here: see the two entries in AGENTS.md about a frame with no point.
-- The question mark is ugly on purpose. It says "something is missing and the
-- addon cannot tell you what", which is true and useful, where an empty square
-- says nothing and looks like a bug.
FP.FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
FP.PREVIEW_ICON  = "Interface\\Icons\\INV_Misc_QuestionMark"

local Bars = FP.Bars

-- ---------------------------------------------------------------------------
-- How the icon of something missing is drawn
--
-- A choice on the Buffs and the Consumables page since 2026-09-30, the owner's
-- request: it was always drained of color. A choice per bar since the
-- redesign. The border stays red in every look, so missing still reads as
-- missing at a glance.
--
-- A texture can be drained of color and multiplied by a color, and that is
-- all: the client has no way to invert one and gives an addon no way to read
-- its colors. So a complementary look, among the owner's proposals, is not
-- here. The scheme color stands in its place, from the same day's designs.
-- ---------------------------------------------------------------------------

local MISSING_LOOKS = {
    gray   = { drain = true },
    native = { drain = false },
    dimmed = { drain = false, tint = { 0.45, 0.45, 0.45 } },
    -- Drained, then red by how light each part of the picture was.
    red    = { drain = true, tint = { 1, 0.25, 0.25 } },
    scheme = { drain = true, tint = function() return FP.colors.on end },
}

--- The looks in the shape a select option wants.
FP.MISSING_LOOK_VALUES = {
    { "gray",   L["Gray"] },
    { "native", L["Original colors"] },
    { "dimmed", L["Dimmed"] },
    { "red",    L["Alert red"] },
    { "scheme", L["Scheme color"] },
}

--- Draws a texture in a look, or plainly for no look at all. Both parts are
--- set every time: the icons are reused, and a look left behind by the last
--- warning would carry over to the next.
local function Paint(texture, look)
    local drain, tint = false, nil
    if look then drain, tint = look.drain, look.tint end
    if type(tint) == "function" then tint = tint() end
    if texture.SetDesaturated then pcall(texture.SetDesaturated, texture, drain) end
    if texture.SetVertexColor then
        local r, g, b = 1, 1, 1
        if tint then r, g, b = tint[1], tint[2], tint[3] end
        pcall(texture.SetVertexColor, texture, r, g, b)
    end
end

--- How much room the countdown under an icon takes.
--
-- Asked of the theme rather than assumed, because the text size is a setting
-- and a number written here would be right at one notch of it.
local function TimerRoom()
    local font = FP:Font("heading")
    if font and font.GetFont then
        local ok, _, size = pcall(font.GetFont, font)
        if ok and type(size) == "number" and size > 0 then return size + 6 end
    end
    return 18
end
FP.TimerRoom = TimerRoom

function FP:FormatTime(seconds)
    -- Never below zero. A caller that hands over a passed expiry has a bug of
    -- its own, and one did: blessings counted on into negative numbers during a
    -- fight in Wailing Caverns on 2026-09-22. That is fixed where it happened,
    -- and this stays as the net, because a minus sign on screen is the kind of
    -- thing somebody screenshots.
    seconds = math.floor(math.max(0, seconds or 0))
    if seconds >= 60 then
        return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
    end
    return tostring(seconds)
end

local function CreateIcon(parent, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    -- Trim the border baked into icon art so the picture fills the square.
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.texture = texture

    FP:AddBorder(frame, { 0, 0, 0, 0.9 }, 2)

    local timer = FP:FontString(frame, "OVERLAY", "heading")
    timer:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    frame.timer = timer

    -- How many people near you are missing this one. Top right, out of the
    -- way of the countdown underneath, and small: it is a number you glance
    -- at while deciding whether to cast, not something to read.
    local count = FP:FontString(frame, "OVERLAY", "body")
    count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -1)
    count:SetTextColor(1, 1, 1)
    frame.count = count

    return frame
end

-- ---------------------------------------------------------------------------
-- Where a bar sits before anybody moves it
--
-- A share of the screen height rather than a fixed offset, because UIParent's
-- unit height tracks the resolution on this client. The three defaults keep
-- the places their displays always had: the warnings 22 percent above the
-- middle, the consumables above them, the combat buffs 21 percent below it,
-- between the character's feet and the cast bar at 1080p. A bar of the
-- player's own appears in the middle, a little apart from the one before.
--
-- **The consumables clear the warnings**, measured in the units the icons are
-- in: at 720p the gap between 72 and 80 percent is 58 units, and two rows of 48
-- with a countdown under each need about 76. The share is what they want; the
-- separation is what they get when the two disagree.
-- ---------------------------------------------------------------------------

local SHARES = { general = 0.22, consumables = 0.30, combat = -0.21 }
local STACK_AIR = 8

local function DefaultY(id, store)
    local height = UIParent:GetHeight()
    if id == "consumables" then
        local below, mine = store.list.general, store.list.consumables
        local clear = DefaultY("general", store)
            + ((below and below.size) or 48) / 2 + ((mine and mine.size) or 48) / 2
            + TimerRoom() + STACK_AIR
        return math.max(height * SHARES.consumables, clear)
    end
    if SHARES[id] then return height * SHARES[id] end
    local number = tonumber(tostring(id):match("^b(%d+)$")) or 1
    return height * (0.12 - 0.07 * ((number - 1) % 5))
end

--- Puts a frame where a bar is: its saved place, or its default one. Shared by
--- the bar itself and by its stand in while it is being moved.
function FP:PlaceAsBar(frame, id, bar, store)
    frame:SetSize(bar.size, bar.size)
    frame:ClearAllPoints()
    if bar.positioned then
        frame:SetPoint(bar.point, UIParent, bar.relPoint, bar.x, bar.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, DefaultY(id, store))
    end
end

-- ---------------------------------------------------------------------------
-- Drawing one bar
-- ---------------------------------------------------------------------------

--- Lays the icons of one bar out and paints them.
--
-- `holder` is { frame, icons }: a bar on screen, or its stand in while the
-- player moves it, which is why the stand in looks exactly like the bar.
function FP:DrawBar(holder, bar, items)
    local frame = holder.frame
    local size  = bar.size
    local room  = bar.timer and TimerRoom() or 0
    local look  = MISSING_LOOKS[bar.look] or MISSING_LOOKS.gray

    -- Shown before it is measured: where it is decides how it wraps.
    frame:Show()
    local cx, cy = frame:GetCenter()
    local places = Bars.Layout({
        count = #items, size = size, timer = room, growth = bar.growth,
        width = UIParent:GetWidth(), height = UIParent:GetHeight(),
        cx = cx or UIParent:GetWidth() / 2, cy = cy or UIParent:GetHeight() / 2,
        gap = Bars.GAP,
    })

    for index, item in ipairs(items) do
        local icon = holder.icons[index]
        if not icon then
            icon = CreateIcon(frame, size)
            holder.icons[index] = icon
        end
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", frame, "CENTER", places[index].x, places[index].y)

        -- Never nil. SetTexture(nil) leaves the frame in place and empty, so a
        -- warning would be raised, laid out, shown, and invisible.
        icon.texture:SetTexture(item.icon or FP.FALLBACK_ICON)

        -- Missing reads as absent at a glance: the icon in the bar's look,
        -- gray unless somebody chose otherwise, and the border red. Expiring
        -- keeps its colors, because it is still there.
        local missing = (item.kind == "missing")
        Paint(icon.texture, missing and look or nil)
        if icon.SetBorderColor then
            if missing then icon:SetBorderColor(0.85, 0.15, 0.15, 1)
            elseif item.kind == "upgrade" then icon:SetBorderColor(1, 0.75, 0.1, 1)
            elseif item.kind == "handout" then icon:SetBorderColor(0.25, 0.55, 1, 1)
            else icon:SetBorderColor(0, 0, 0, 0.9) end
        end

        -- The count, when there is one. Never in combat: other players cannot
        -- be read there, so the number would be a claim nobody can act on.
        if (item.waiting or 0) > 0 then
            icon.count:SetText(tostring(item.waiting))
            icon.count:Show()
        else
            icon.count:Hide()
        end

        if item.kind == "handout" then
            -- You have it. The icon is here about everybody else, so there is
            -- nothing of your own to count down.
            icon.timer:SetText("")
            icon.timer:Hide()
        elseif item.kind == "missing" then
            -- A dash rather than a countdown. There is nothing counting down:
            -- it is not coming back on its own.
            icon.timer:SetText("-")
            icon.timer:SetTextColor(1, 0.35, 0.35)
            icon.timer:SetShown(bar.timer)
        elseif item.kind == "upgrade" then
            icon.timer:SetText(L["new"])
            icon.timer:SetTextColor(1, 0.82, 0)
            icon.timer:SetShown(bar.timer)
        elseif item.kind == "notice" then
            -- A state rather than a time, so nothing is written under it: a
            -- Hunter's pet that is content rather than happy is the case.
            icon.timer:SetText("")
            icon.timer:Hide()
        elseif item.kind == "tracker" then
            icon.timer:SetText(FP:FormatTime(item.remaining))
            -- A share of the buff's own length rather than the warning's
            -- fixed minute, with a floor. A tracked buff can be shorter than
            -- that minute from end to end, and a countdown that is red from
            -- its first tick says nothing at all. Thirty seconds turns red at
            -- five, three minutes at eighteen.
            if (item.remaining or 0) <= math.max(5, (item.duration or 0) * 0.1) then
                icon.timer:SetTextColor(1, 0.25, 0.25)
            else
                icon.timer:SetTextColor(1, 0.82, 0)
            end
            icon.timer:SetShown(bar.timer)
        elseif bar.timer then
            icon.timer:SetText(FP:FormatTime(item.remaining))
            -- Red in the last minute: by then it is not a reminder any more.
            if (item.remaining or 0) <= 60 then
                icon.timer:SetTextColor(1, 0.25, 0.25)
            else
                icon.timer:SetTextColor(1, 0.82, 0)
            end
            icon.timer:Show()
        else
            icon.timer:Hide()
        end

        icon:Show()
    end

    for index = #items + 1, #holder.icons do
        holder.icons[index]:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- The bars on screen
-- ---------------------------------------------------------------------------

local displays = {}     -- [bar id] = { frame, icons }
local handedIn = {}     -- [source] = what that page wants to say

--- The frame a bar is drawn on, made the first time the bar has something.
--
-- MEDIUM rather than HIGH: the world map's border, the quest log beside it and
-- the game's options all sit on HIGH, and a warning drawn over them hides the
-- very window the player opened. Reported on CurseForge.
--
-- **Never takes the mouse.** A mouse enabled frame in the middle of the screen
-- swallows clicks meant for the world behind it, see AGENTS.md; moving a bar
-- is done on a stand in, see Core/Mover.lua.
local function DisplayFor(id)
    local holder = displays[id]
    if holder then return holder end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:Hide()
    holder = { frame = frame, icons = {} }
    displays[id] = holder
    return holder
end

--- Urgency first, the way each page sorts: missing before running out, and a
--- countdown that is merely running last. Two icons the rules cannot tell
--- apart are kept in a fixed order, so they do not swap places between ticks.
local function Ordered(a, b)
    local first, second = a.sort or math.huge, b.sort or math.huge
    if first ~= second then return first < second end
    return tostring(a.rid or "") < tostring(b.rid or "")
end

--- Hands in what one page wants to say, and draws every bar again.
--
-- @param source  "buffs" or "cons", the page's prefix of its entry keys
-- @param items   warning items, each carrying `key`, the entry it is about,
--                `factory`, the bar that entry starts on, and `rid`, which
--                tells two icons of one entry apart
function FP:HandIn(source, items)
    handedIn[source] = items or {}
    self:RedrawBars()
end

--- Draws every bar from what the pages last handed in.
--
-- Cheap enough to run on every tick of either page: a handful of icons, and
-- the place of each bar put again every time, so a profile switch, a reset or a
-- change of the screen's size is followed without anybody having to say so.
function FP:RedrawBars()
    local store = Bars.Store()
    if not store then return end

    local byBar = {}
    if not self.movingBars then
        for _, items in pairs(handedIn) do
            for _, item in ipairs(items) do
                local id = Bars.Dest(store, item.key, item.factory)
                local list = byBar[id]
                if not list then
                    list = {}
                    byBar[id] = list
                end
                list[#list + 1] = item
            end
        end
    end

    -- Whatever has nothing to say, or no longer exists, goes away first.
    for id, holder in pairs(displays) do
        if not byBar[id] or not Bars.Get(store, id) then holder.frame:Hide() end
    end

    for id, list in pairs(byBar) do
        local bar = Bars.Get(store, id)
        if bar then
            table.sort(list, Ordered)
            local holder = DisplayFor(id)
            FP:PlaceAsBar(holder.frame, id, bar, store)
            FP:DrawBar(holder, bar, list)
        end
    end
end

--- Takes every bar off the screen, for the time the player moves them.
function FP:HideBars()
    for _, holder in pairs(displays) do holder.frame:Hide() end
end
