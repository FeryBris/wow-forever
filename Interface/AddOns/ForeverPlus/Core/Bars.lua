-- The bars: which exist, what each looks like, and which bar an entry is on.
--
-- Planned with the owner on 2026-10-14 and 15, see
-- planning/1.0.0/PLANNING-BUFFS-AND-LAYOUT.md, whose section *Decisions of
-- 2026-10-15* is the brief. Until then every module owned the displays it drew
-- on: BuffExpiry two, Consumables one, each with its own size, timer and look.
-- Since then a profile owns a list of bars, three to start with, and every
-- entry on the Buffs and Consumables pages names one of them, so one bar can
-- mix both pages.
--
-- **Plain Lua and nothing else**, so tools/luatest.py can run all of it: no
-- frame, no event, no client call. Drawing is Core/Warnings.lua's.
--
-- What a profile keeps, under `bars`:
--
--   next   the number the next bar of the player's own gets. Only ever grows,
--          so a deleted bar's id never comes back and nothing that pointed at
--          it can find a new bar by accident
--   list   [id] = the bar: name, size, timer, look, growth and its position.
--          Flat fields only, because an import keeps four levels and no more
--   dest   [entry key] = bar id, only where it differs from the factory one
--   warn   [entry key] = seconds, only where an entry has a time of its own.
--          Zero is a value, the explicit "no warning before it runs out"
--
-- An entry key is the source and the key that source already uses for the
-- entry, "buffs:WARRIOR/battleShout" or "cons:i13447", so the same row on the
-- page and the same icon on screen always find the same record.

local ADDON, FP = ...
local L = FP.L

local Bars = {}
FP.Bars = Bars

-- The three every profile starts with, in the order they are listed. General
-- Warnings is the one that cannot be deleted, so an entry always has a bar.
Bars.DEFAULTS = { "general", "combat", "consumables" }
Bars.FALLBACK = "general"

local IS_DEFAULT = { general = true, combat = true, consumables = true }

-- Marked here and translated where they are drawn: this file loads before the
-- language is known.
local DEFAULT_NAMES = {
    general     = L["General Warnings"],
    combat      = L["Combat Buffs"],
    consumables = L["Consumables"],
}

-- What a new bar looks like, whatever the others look like by then: the owner's
-- word of round 9. These are the values the displays always had.
Bars.FACTORY = { size = 48, timer = true, look = "gray", growth = "center" }

Bars.MIN_SIZE, Bars.MAX_SIZE, Bars.SIZE_STEP = 32, 128, 8

-- The six ways a bar grows, in the order the drop down lists them.
Bars.GROWTHS = { "center", "vcenter", "right", "left", "down", "up" }
local GROWTH = {}
for _, name in ipairs(Bars.GROWTHS) do GROWTH[name] = true end

local LOOKS = { gray = true, native = true, dimmed = true, red = true, scheme = true }

-- Plain air between two icons, the gap the displays always had.
Bars.GAP = 10

-- ---------------------------------------------------------------------------
-- Checking values
--
-- The same tests serve a bar being changed on the page and a profile arriving
-- in an import string, so a value nobody could have set by hand is refused in
-- both places alike.
-- ---------------------------------------------------------------------------

local function Finite(value)
    return type(value) == "number" and value == value
       and value ~= math.huge and value ~= -math.huge
end

local function ClampSize(value)
    if not Finite(value) then return Bars.FACTORY.size end
    value = math.floor(value / Bars.SIZE_STEP + 0.5) * Bars.SIZE_STEP
    return math.max(Bars.MIN_SIZE, math.min(Bars.MAX_SIZE, value))
end

local POINTS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

--- A bar record with every field it may have and nothing else, or nil.
local function CleanBar(bar)
    if type(bar) ~= "table" then return nil end
    local out = {
        size   = ClampSize(bar.size),
        timer  = bar.timer ~= false,
        look   = LOOKS[bar.look] and bar.look or Bars.FACTORY.look,
        growth = GROWTH[bar.growth] and bar.growth or Bars.FACTORY.growth,
    }
    if type(bar.name) == "string" and bar.name ~= "" and not bar.name:find("[%c|]") then
        out.name = bar.name:sub(1, 32)
    end
    if bar.positioned == true and POINTS[bar.point] and POINTS[bar.relPoint]
       and Finite(bar.x) and Finite(bar.y) then
        out.positioned = true
        out.point, out.relPoint, out.x, out.y = bar.point, bar.relPoint, bar.x, bar.y
    end
    return out
end

local function FactoryBar()
    return {
        size = Bars.FACTORY.size, timer = Bars.FACTORY.timer,
        look = Bars.FACTORY.look, growth = Bars.FACTORY.growth,
    }
end

-- ---------------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------------

--- Makes a profile's registry whole: the three defaults present, the fallback
--- never deleted, and `next` beyond every bar of the player's own.
--
-- Run whenever a profile is bound, so a profile that was reset, created fresh
-- or imported from an older string has its bars before anything draws.
function Bars.Ensure(profile)
    if type(profile) ~= "table" then return nil end
    local store = profile.bars
    if type(store) ~= "table" then
        store = {}
        profile.bars = store
    end
    if type(store.list) ~= "table" then store.list = {} end
    if type(store.dest) ~= "table" then store.dest = {} end
    if type(store.warn) ~= "table" then store.warn = {} end

    for _, id in ipairs(Bars.DEFAULTS) do
        if type(store.list[id]) ~= "table" then store.list[id] = FactoryBar() end
    end
    store.list[Bars.FALLBACK].deleted = nil

    local highest = 0
    for id in pairs(store.list) do
        local number = type(id) == "string" and tonumber(id:match("^b(%d+)$"))
        if number and number > highest then highest = number end
    end
    if not Finite(store.next) or store.next <= highest then store.next = highest + 1 end
    return store
end

--- The active profile's registry.
function Bars.Store()
    return FP.db and Bars.Ensure(FP.db) or nil
end

function Bars.IsDefault(id)
    return IS_DEFAULT[id] == true
end

--- A bar that exists, or nil. A deleted default is dormant rather than gone,
--- and does not count as existing.
function Bars.Get(store, id)
    local bar = store and store.list and store.list[id]
    if type(bar) ~= "table" or bar.deleted then return nil end
    return bar
end

--- The bars that exist, in the order they are listed: the three defaults, then
--- the player's own by the order they were made.
function Bars.Ids(store)
    local out = {}
    if not store then return out end
    for _, id in ipairs(Bars.DEFAULTS) do
        if Bars.Get(store, id) then out[#out + 1] = id end
    end
    local own = {}
    for id, bar in pairs(store.list) do
        local number = type(id) == "string" and tonumber(id:match("^b(%d+)$"))
        if number and type(bar) == "table" and not bar.deleted then
            own[#own + 1] = { id = id, number = number }
        end
    end
    table.sort(own, function(a, b) return a.number < b.number end)
    for _, item in ipairs(own) do out[#out + 1] = item.id end
    return out
end

--- What to call a bar: the player's name for it, or its own in the language in
--- use. A bar of the player's own is "Bar 4" until renamed; its number is part
--- of its id and never changes.
function Bars.NameOf(store, id)
    local bar = store and store.list and store.list[id]
    if type(bar) == "table" and type(bar.name) == "string" and bar.name ~= "" then
        return bar.name
    end
    if DEFAULT_NAMES[id] then return FP:T(DEFAULT_NAMES[id]) end
    local number = type(id) == "string" and id:match("^b(%d+)$")
    return L["Bar %s"]:format(number or tostring(id))
end

--- A new bar with the factory look. Returns its id.
function Bars.Create(store)
    local number = store.next
    store.next = number + 1
    local id = "b" .. number
    store.list[id] = FactoryBar()
    return id
end

--- Renames a bar. An empty name, or the bar's own name in the language in use,
--- takes the player's name away again, so the bar goes on following the
--- language. A pipe or a control character is refused: the name is printed.
function Bars.Rename(store, id, name)
    local bar = Bars.Get(store, id)
    if not bar or type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name:find("[%c|]") then return nil end

    local own
    if DEFAULT_NAMES[id] then
        own = FP:T(DEFAULT_NAMES[id])
    else
        own = L["Bar %s"]:format(id:match("^b(%d+)$") or id)
    end
    if name == "" or name == own then
        bar.name = nil
    else
        bar.name = name:sub(1, 32)
    end
    return true
end

--- Deletes a bar. Its entries go to the fallback, keeping their selection and
--- their warning times, which live elsewhere and are not touched.
--
-- A default is kept as a dormant record with its position and look, so
-- restoring the default setup brings it back as it was. One of the player's
-- own goes for good.
--
-- @param factoryOf  function(entry key) -> the entry's factory bar, used to
--                   tell an entry moved there by hand from one that lives there
-- @return true, or nil and a reason
function Bars.Delete(store, id, factoryOf)
    if id == Bars.FALLBACK then return nil, "fallback" end
    if not Bars.Get(store, id) then return nil, "missing" end

    if IS_DEFAULT[id] then
        store.list[id].deleted = true
    else
        store.list[id] = nil
    end

    -- An entry moved to this bar by hand goes to the fallback by name, unless
    -- the fallback is where it lives anyway. Clearing a key during pairs() is
    -- allowed; adding one is not, so the changes are collected first.
    local moved = {}
    for key, dest in pairs(store.dest) do
        if dest == id then moved[#moved + 1] = key end
    end
    for _, key in ipairs(moved) do
        local factory = factoryOf and factoryOf(key)
        if factory == Bars.FALLBACK then
            store.dest[key] = nil
        else
            store.dest[key] = Bars.FALLBACK
        end
    end
    return true
end

--- How many entries draw on a bar, of the keys a caller can name.
function Bars.Count(store, id, keys, factoryOf)
    local count = 0
    for _, key in ipairs(keys or {}) do
        if Bars.Dest(store, key, factoryOf and factoryOf(key)) == id then
            count = count + 1
        end
    end
    return count
end

-- ---------------------------------------------------------------------------
-- An entry's bar and time
-- ---------------------------------------------------------------------------

--- The bar an entry draws on: the one it was moved to, else its factory bar,
--- else the fallback. A record pointing at a bar that is gone is not an error,
--- it simply lands on the next answer.
function Bars.Dest(store, key, factory)
    local chosen = store and store.dest and store.dest[key]
    if chosen and Bars.Get(store, chosen) then return chosen end
    if factory and Bars.Get(store, factory) then return factory end
    return Bars.FALLBACK
end

--- Moves an entry to a bar. Its factory bar is stored as no record at all, so
--- the list of records stays a list of exceptions.
function Bars.SetDest(store, key, id, factory)
    if not Bars.Get(store, id) then return nil end
    if id == factory then store.dest[key] = nil else store.dest[key] = id end
    return true
end

--- An entry's own warning time in seconds, or nil while it uses the page's.
function Bars.Warn(store, key)
    local value = store and store.warn and store.warn[key]
    if Finite(value) and value >= 0 then return value end
    return nil
end

--- Gives an entry a time of its own, or nil to follow the page again.
function Bars.SetWarn(store, key, seconds)
    if seconds == nil then
        store.warn[key] = nil
        return true
    end
    if not Finite(seconds) or seconds < 0 then return nil end
    store.warn[key] = math.floor(seconds + 0.5)
    return true
end

--- Whether an entry differs from the factory: another bar than its own, or a
--- time of its own, zero included. What the small marker on a closed row says.
function Bars.Customized(store, key, factory)
    if Bars.Warn(store, key) ~= nil then return true end
    local chosen = store and store.dest and store.dest[key]
    return chosen ~= nil and chosen ~= factory and Bars.Get(store, chosen) ~= nil
end

-- ---------------------------------------------------------------------------
-- Restoring the default setup
--
-- The three defaults come back with their factory assignment of entries, and
-- what the player built is kept: positions, sizes, warning times, selections
-- and the bars of their own, which stay with every setting and simply hold
-- nothing. Three resets can be added, each on its own.
-- ---------------------------------------------------------------------------

--- @param options  { positions = bool, sizes = bool, times = bool }
--                  times clears every entry's own time here; the pages' common
--                  times are their modules' to reset
function Bars.RestoreDefaults(store, options)
    options = options or {}
    for _, id in ipairs(Bars.DEFAULTS) do
        local bar = store.list[id]
        if type(bar) ~= "table" then
            bar = FactoryBar()
            store.list[id] = bar
        end
        bar.deleted = nil
        if options.positions then
            bar.positioned, bar.point, bar.relPoint, bar.x, bar.y = nil, nil, nil, nil, nil
        end
        if options.sizes then bar.size = Bars.FACTORY.size end
    end
    store.dest = {}
    if options.times then store.warn = {} end
end

-- ---------------------------------------------------------------------------
-- From the older settings
--
-- Format 8 to 9. Each module kept its displays' look and position in its own
-- branch: BuffExpiry the warnings' and, prefixed with "tracker", the lower
-- display's, both sharing one size, timer and look; Consumables its own. They
-- become the three default bars exactly as they were, and the old keys go,
-- since nothing reads them any more.
--
-- Written so a second run changes nothing: a profile that already has bars is
-- only made whole.
-- ---------------------------------------------------------------------------

local POSITION = { "positioned", "point", "relPoint", "x", "y" }

local function FromModule(branch, prefix, look)
    local bar = FactoryBar()
    if type(branch) ~= "table" then return bar end
    if branch.iconSize ~= nil then bar.size = branch.iconSize end
    if branch.showTimer ~= nil then bar.timer = branch.showTimer end
    if branch.missingLook ~= nil then bar.look = branch.missingLook end
    for _, field in ipairs(POSITION) do
        local key = prefix and (prefix .. field:sub(1, 1):upper() .. field:sub(2)) or field
        bar[field] = branch[key]
    end
    return CleanBar(bar)
end

local function Forget(branch, prefix)
    if type(branch) ~= "table" then return end
    for _, field in ipairs(POSITION) do
        local key = prefix and (prefix .. field:sub(1, 1):upper() .. field:sub(2)) or field
        branch[key] = nil
    end
end

function Bars.Migrate(profile)
    if type(profile) ~= "table" then return end
    if type(profile.bars) == "table" then
        Bars.Ensure(profile)
        return
    end

    local buffs, cons = profile.BuffExpiry, profile.Consumables
    profile.bars = {
        next = 1,
        list = {
            general     = FromModule(buffs, nil),
            combat      = FromModule(buffs, "tracker"),
            consumables = FromModule(cons, nil),
        },
        dest = {},
        warn = {},
    }
    Bars.Ensure(profile)

    for _, branch in ipairs({ buffs, cons }) do
        if type(branch) == "table" then
            branch.iconSize, branch.showTimer, branch.missingLook = nil, nil, nil
        end
    end
    Forget(buffs, nil)
    Forget(buffs, "tracker")
    Forget(cons, nil)
end

--- Reduces imported bars to what a profile may hold, naming what it drops.
--
-- The import has already cut the profile to four levels and to plain values;
-- this checks that the values are ones the page could have set, so a string
-- edited by hand cannot leave an entry pointing nowhere or a bar with a size
-- of a million.
function Bars.Validate(profile, skipped)
    if profile.bars == nil then return end
    if type(profile.bars) ~= "table" then
        skipped[#skipped + 1] = "bars"
        profile.bars = nil
        return
    end
    local store = profile.bars
    local list = {}
    if type(store.list) == "table" then
        for id, bar in pairs(store.list) do
            local valid = type(id) == "string"
                and (IS_DEFAULT[id] or id:match("^b%d+$") ~= nil)
            local clean = valid and CleanBar(bar)
            if clean then
                -- Only a default can be dormant; one of the player's own that
                -- was deleted is not kept at all.
                if IS_DEFAULT[id] and bar.deleted == true then clean.deleted = true end
                list[id] = clean
            else
                skipped[#skipped + 1] = "bars.list." .. tostring(id)
            end
        end
    end
    store.list = list

    for _, field in ipairs({ "dest", "warn" }) do
        local kept = {}
        if type(store[field]) == "table" then
            for key, value in pairs(store[field]) do
                local ok = type(key) == "string"
                if field == "dest" then
                    ok = ok and type(value) == "string" and list[value] ~= nil
                else
                    ok = ok and Finite(value) and value >= 0
                end
                if ok then kept[key] = value
                else skipped[#skipped + 1] = "bars." .. field .. "." .. tostring(key) end
            end
        end
        store[field] = kept
    end
    if not Finite(store.next) then store.next = 1 end
    Bars.Ensure(profile)
end

-- ---------------------------------------------------------------------------
-- Where the icons go
--
-- The bar's anchor is the square of its first icon: the most urgent icon sits
-- there in every growth but the two centered ones, which center the whole row
-- or column on it instead. Rows of a horizontal bar and columns of a vertical
-- one are added when the screen edge comes, keeping the icon size; the side
-- they go to depends only on where the anchor is, so they do not flip back and
-- forth while icons come and go.
--
-- **When even that does not fit, the bar moves away from the edge**, the
-- owner's word of 2026-10-15: first along the bar, as far as needed for longer
-- rows, then across it for more of them. Nothing is saved by that, and the bar
-- returns as soon as there is room. Icons are never shrunk and none is left
-- out; only a bar with more icons than the whole screen holds runs over.
-- ---------------------------------------------------------------------------

local function Ceil(a, b) return math.floor((a + b - 1) / b) end

local function Clamp(value, low, high)
    if high < low then return low end
    return math.max(low, math.min(high, value))
end

--- The places of `count` icons around their anchor.
--
-- @param o  { count, size, timer (room under an icon, 0 for none), growth,
--             width, height (the screen), cx, cy (the anchor's center), gap }
-- @return a list of { x, y }, each an icon's center relative to the anchor's
--         center with any move away from the edge already in it, and the move
--         itself as dx, dy
function Bars.Layout(o)
    local n = math.max(0, math.floor(o.count or 0))
    local S, T = o.size, o.timer or 0
    local G = o.gap or Bars.GAP
    local W, H = o.width, o.height
    local cx, cy = o.cx, o.cy
    local growth = GROWTH[o.growth] and o.growth or "center"
    local out = {}
    if n == 0 then return out, 0, 0 end

    local dx, dy = 0, 0

    if growth == "center" or growth == "right" or growth == "left" then
        local step, rowStep = S + G, S + T + G
        local function Fits(free) return math.max(1, math.floor((free + G) / step)) end
        local function Capacity(x)
            if growth == "center" then return Fits(2 * math.min(x, W - x)) end
            if growth == "right" then return Fits(W - (x - S / 2)) end
            return Fits(x + S / 2)
        end
        local down = cy >= H / 2
        local function Rows(y)
            local room = down and (y - S / 2 - T) or (H - y - S / 2)
            return math.max(1, math.floor(room / rowStep) + 1)
        end

        local per, rows = Capacity(cx), Rows(cy)
        if growth == "center" then
            -- **A centered row moves along before it wraps**, the owner's word
            -- of 2026-10-18, after a bar in a corner had wrapped upward one
            -- icon a row: horizontal was chosen, and only the centering cannot
            -- be kept there. So the row leaves its anchor as far as the edge
            -- needs, and only a row longer than the screen wraps.
            per = math.min(n, Fits(W))
            local length = per * S + (per - 1) * G
            dx = Clamp(cx, length / 2, W - length / 2) - cx
        end
        if Ceil(n, per) > rows then
            -- Longer rows first, by moving along the bar.
            local most = Fits(W)
            local wanted = per
            while wanted < most and Ceil(n, wanted) > rows do wanted = wanted + 1 end
            local length = wanted * S + (wanted - 1) * G
            if growth == "center" then
                dx = Clamp(cx, length / 2, W - length / 2) - cx
            elseif growth == "right" then
                dx = math.min(0, (W - length) - (cx - S / 2))
            else
                dx = math.max(0, length - (cx + S / 2))
            end
            per = wanted
            -- Then more rows, by moving across it.
            local needed = Ceil(n, per)
            if needed > rows then
                local span = (needed - 1) * rowStep
                if down then
                    dy = Clamp(cy, span + S / 2 + T, H - S / 2) - cy
                else
                    dy = Clamp(cy, S / 2 + T, H - S / 2 - span) - cy
                end
            end
        end

        for i = 0, n - 1 do
            local row, col = math.floor(i / per), i % per
            local inRow = math.min(per, n - row * per)
            local x
            if growth == "center" then x = (col - (inRow - 1) / 2) * step
            elseif growth == "right" then x = col * step
            else x = -col * step end
            local y = (down and -1 or 1) * row * rowStep
            out[#out + 1] = { x = x + dx, y = y + dy }
        end
        return out, dx, dy
    end

    -- Vertical: the same with the axes swapped. An icon and its countdown take
    -- S + T, so that is the step along the bar.
    local step, colStep = S + T + G, S + G
    -- How far the centers of the first and the last icon may lie apart.
    local function Capacity(y)
        local room
        if growth == "vcenter" then
            room = 2 * math.min(H - y - S / 2, y - S / 2 - T)
        elseif growth == "down" then
            room = y - S / 2 - T
        else
            room = H - y - S / 2
        end
        return math.max(1, math.floor(room / step) + 1)
    end
    local right = cx <= W / 2
    local function Cols(x)
        local room = right and (W - x - S / 2) or (x - S / 2)
        return math.max(1, math.floor(room / colStep) + 1)
    end

    local per, cols = Capacity(cy), Cols(cx)
    if growth == "vcenter" then
        -- The same for a centered column: it moves up or down before it wraps.
        per = math.min(n, math.max(1, math.floor((H - S - T) / step) + 1))
        local span = (per - 1) * step
        dy = Clamp(cy, span / 2 + S / 2 + T, H - S / 2 - span / 2) - cy
    end
    if Ceil(n, per) > cols then
        local most = math.max(1, math.floor((H - S - T) / step) + 1)
        local wanted = per
        while wanted < most and Ceil(n, wanted) > cols do wanted = wanted + 1 end
        local span = (wanted - 1) * step
        if growth == "vcenter" then
            dy = Clamp(cy, span / 2 + S / 2 + T, H - S / 2 - span / 2) - cy
        elseif growth == "down" then
            dy = math.max(0, (span + S / 2 + T) - cy)
        else
            dy = math.min(0, (H - S / 2 - span) - cy)
        end
        per = wanted
        local needed = Ceil(n, per)
        if needed > cols then
            local across = (needed - 1) * colStep
            if right then
                dx = Clamp(cx, S / 2, W - S / 2 - across) - cx
            else
                dx = Clamp(cx, S / 2 + across, W - S / 2) - cx
            end
        end
    end

    for i = 0, n - 1 do
        local col, row = math.floor(i / per), i % per
        local inCol = math.min(per, n - col * per)
        local y
        if growth == "vcenter" then y = ((inCol - 1) / 2 - row) * step
        elseif growth == "down" then y = -row * step
        else y = row * step end
        local x = (right and 1 or -1) * col * colStep
        out[#out + 1] = { x = x + dx, y = y + dy }
    end
    return out, dx, dy
end
