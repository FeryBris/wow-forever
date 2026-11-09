-- Copyright (C) 2026 ForeverAuras. Part of ForeverAuras, licensed under the GNU GPL v2 (see LICENSE).
-- ForeverAuras (dev.40 experiment, dev.41 review fixes): the CELL CHAIN of a
-- filtered list in an independent-carrier row (combined gates, design v5 as
-- amended by the dev.38 and dev.40 reviews). A list with a Total Duration
-- >= / = gate or a Stack Count >= n gate lays every candidate out natively,
-- and today shows the matching ones on ONE spot, measuring its row space
-- with a separate single aura: the picture and the space could disagree
-- (Dan's S/M overlap). Here each native RECORD (button) of the list gets a
-- cell whose length AND whose artwork visibility come from the same bound
-- element of that record:
--   duration gate: the record's duration text, bound with a formatter that
--     writes a texture fill of F screen pixels inside the range, "" outside;
--   stack gate: the record's application bar, bound with the supported
--     minApplications = n-1 / maxApplications = n options, so its fill is
--     0 below n and the full bar from n on;
--   both on one aura: the bar's far edge hangs from the text's far edge, so
--     the bar is F wide only while the duration matches and its fill is the
--     product of the two tests (the bar clamps its fill to its width).
-- The cell point P_k of record k is the start corner of its holder H_k; the
-- next record's holder hangs from the midpoint of a padded span over the
-- element's extent, halved log2(q) times (F = q * step): a matching record
-- advances the chain by exactly one step (icon + spacing), a record without
-- a matching aura by nothing, whatever its place in the native layout.
-- Nothing in Lua reads a position; the client drives every element. The
-- member's end is a frame on the last record's point (the chain is bound to
-- the first native batch of ten records: a prototype limit, see FlowChain).
-- Opt-in with the group's independent-carriers setting; everything is built
-- on the record's own button (the client requires bound targets to be its
-- descendants) and anchored only to the previous record's span.
-- Acceptance (dev.40 review): every link of the current construction and
-- the end must be in place before a build counts (FinishChain checks all
-- records; a refused link raises inside a probe build so the build's own
-- accounting sees it, and asks for a bounded paced re-apply in an ordinary
-- one, RequestReapply); an eleventh record is hidden and said in the editor
-- (no re-apply: the client's pool is not ours to shrink).
if not WeakAuras.IsLibsOK() then return end
local _, Private = ...
local Display = Private.BlizzardAuraDisplay
local L = WeakAuras.L

local CHAIN_RECORDS = 10        -- one native batch
Display.CHAIN_RECORDS = CHAIN_RECORDS
local PAD_PX = 8                -- span padding, screen pixels (keeps every span positive)
local MAX_Q = 8                 -- the longest fill: 8 steps
local FILL_TOLERANCE_PX = 2     -- how far the rendered fill may miss F (the residual the halvings divide)
local SLACK_UNITS = 2           -- the pixel rounding of the step, covered in the artwork bound
local TEXT_CHARS = 10           -- a text without a fixed width counts as this many characters wide
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SIDE = {RIGHT = {near = "LEFT", far = "RIGHT", corner = "TOPLEFT", cross = {"TOP", "BOTTOM"}},
  LEFT = {near = "RIGHT", far = "LEFT", corner = "TOPRIGHT", cross = {"TOP", "BOTTOM"}},
  DOWN = {near = "TOP", far = "BOTTOM", corner = "TOPLEFT", cross = {"LEFT", "RIGHT"}},
  UP = {near = "BOTTOM", far = "TOP", corner = "BOTTOMLEFT", cross = {"LEFT", "RIGHT"}}}
-- Unit offsets of a frame's anchor points from its centre (x right, y up).
local POINTS = {TOPLEFT = {-1, 1}, TOP = {0, 1}, TOPRIGHT = {1, 1}, LEFT = {-1, 0}, CENTER = {0, 0}, RIGHT = {1, 0},
  BOTTOMLEFT = {-1, -1}, BOTTOM = {0, -1}, BOTTOMRIGHT = {1, -1}}
local INVERSE = {TOPLEFT = "BOTTOMRIGHT", TOP = "BOTTOM", TOPRIGHT = "BOTTOMLEFT", LEFT = "RIGHT", CENTER = "CENTER", RIGHT = "LEFT",
  BOTTOMLEFT = "TOPRIGHT", BOTTOM = "TOP", BOTTOMRIGHT = "TOPLEFT"}

local function Readable(v) return v ~= nil and not issecretvalue(v) and type(v) == "number" end

---------------------------------------------------------------------------- the artwork bound
-- The rectangle an element can reach, in the display's units from the box's
-- centre (x right, y up): the renderer's own placement rules
-- (SecretAuraAppearance.lua): point mode = anchor point on the box (or the
-- INNER_ 0.8 / OUTER_ 1.1 frames) + xOffset/yOffset, the element's own
-- self point on its width/height; area mode = the box grown by half the
-- offsets on each side. Texts take their font size for their height and
-- TEXT_CHARS characters for their width unless a fixed width is set
-- (documented limit); borders their offset plus size; glows their margin.
local function Target(point, w, h)
  local prefix = point:sub(1, 6)
  if prefix == "INNER_" then return point:sub(7), w * 0.8, h * 0.8 end
  if prefix == "OUTER_" then return point:sub(7), w * 1.1, h * 1.1 end
  return point, w, h
end
local function PointRect(anchorPoint, selfPoint, x, y, ew, eh, w, h)
  local point, tw, th = Target(anchorPoint or "CENTER", w, h)
  local a = POINTS[point] or POINTS.CENTER
  local sp = POINTS[selfPoint or "CENTER"] or POINTS.CENTER
  local cx = a[1] * tw / 2 + (tonumber(x) or 0) - sp[1] * ew / 2
  local cy = a[2] * th / 2 + (tonumber(y) or 0) - sp[2] * eh / 2
  return {cx - ew / 2, cx + ew / 2, cy - eh / 2, cy + eh / 2}
end
local function AreaRect(x, y, w, h)
  local dx, dy = (tonumber(x) or 0) / 2, (tonumber(y) or 0) / 2
  return {-w / 2 - dx, w / 2 + dx, -h / 2 - dy, h / 2 + dy}
end
local function ElementRect(element, w, h)
  local kind = element.type
  if kind == "subtexture" or kind == "subcdmdispel" or kind == "subcdmdispelborder" then
    if kind == "subtexture" and element.textureVisible == false then return end
    if kind ~= "subtexture" and element.dispelVisible == false then return end
    local defaultSize = kind == "subcdmdispel" and 16 or 32
    local defaultPoint = kind == "subcdmdispel" and "TOPLEFT" or "CENTER"
    local rect
    if element.anchor_mode == "point" then
      rect = PointRect(element.anchor_point or defaultPoint, element.self_point or defaultPoint, element.xOffset, element.yOffset,
        tonumber(element.width) or defaultSize, tonumber(element.height) or defaultSize, w, h)
    else
      rect = AreaRect(element.xOffset, element.yOffset, w, h)
    end
    if kind == "subcdmdispelborder" then
      -- The border's four strips (DispelTypeDisplay.lua, Layout): the anchor
      -- rectangle grown by dispelBorderOffset, each strip `size` thick inward
      -- from its edge; a strip thicker than the rectangle it frames pokes out
      -- of the opposite side, so the union takes both (dev.41/42 reviews).
      local offset = tonumber(element.dispelBorderOffset) or 0   -- signed, as Layout takes it (dev.43 review)
      local size = math.max(1, math.min(32, tonumber(element.dispelBorderSize) or 2))
      local l, r, b, t = rect[1] - offset, rect[2] + offset, rect[3] - offset, rect[4] + offset
      -- A negative offset larger than the anchor inverts the rectangle; the
      -- strips then hang from its crossed edges: both orders are covered.
      if l > r then l, r = r, l end
      if b > t then b, t = t, b end
      rect = {math.min(l, r - size), math.max(r, l + size), math.min(b, t - size), math.max(t, b + size)}
    end
    return rect
  elseif kind == "subtext" then
    if element.text_visible == false then return end
    local size = tonumber(element.text_fontSize) or 18
    local ew = element.text_automaticWidth == "Fixed" and tonumber(element.text_fixedWidth) or size * TEXT_CHARS * 0.6
    local eh = size * 1.4
    local anchor = element.anchor_point or "CENTER"
    -- The renderer's rule (StyleText, BlizzardAuraDisplay.lua), exactly: no
    -- self point means "AUTO" on an INNER_/OUTER_ anchor and the anchor point
    -- itself on a plain one; "AUTO" means the stripped point on INNER_, its
    -- mirror on OUTER_, and CENTER on a plain anchor (dev.42 review).
    local prefix, point = anchor:sub(1, 6), Target(anchor, 1, 1)
    local framed = prefix == "INNER_" or prefix == "OUTER_"
    local selfPoint = element.text_selfPoint
    if selfPoint == nil then selfPoint = framed and "AUTO" or point end
    if selfPoint == "AUTO" then
      selfPoint = prefix == "INNER_" and point or prefix == "OUTER_" and INVERSE[point] or "CENTER"
    end
    return PointRect(anchor, selfPoint, element.text_anchorXOffset or element.anchorXOffset, element.text_anchorYOffset or element.anchorYOffset, ew, eh, w, h)
  elseif kind == "subborder" then
    if element.border_visible == false then return end
    local reach = math.max(0, tonumber(element.border_offset) or 0) + math.max(0.1, tonumber(element.border_size) or 2)
    return {-w / 2 - reach, w / 2 + reach, -h / 2 - reach, h / 2 + reach}
  elseif kind == "subglow" then
    local margin = Display.GlowMargin and Display.GlowMargin(w, h, element) or (math.ceil(math.max(w, h) * 0.5) + 4)
    return {-w / 2 - margin, w / 2 + margin, -h / 2 - margin, h / 2 + margin}
  end
end

-- The chain's extents for a display, from its settings alone (units):
--   alongUnits, crossUnits  the icon along and across the row
--   stepUnits               icon + spacing along the row
--   reachAlong              how far past the icon's edge the artwork reaches
--                           along the row (the larger side; the clip is symmetric)
--   marginUnits             the clip's cross margin: today's gate margin or
--                           the artwork's cross reach, whichever is more
--   needUnits               the fill the clip needs: icon + 2 * (reach + slack)
--   q                       the smallest power of two with q * step >= need
-- or nil and why ("growth", "step", "reach": the artwork needs more than
-- MAX_Q steps, which the chain refuses rather than clipping it).
local OPPOSITE_GROWTH = {RIGHT = "LEFT", LEFT = "RIGHT", DOWN = "UP", UP = "DOWN"}
function Display.ChainBound(data, opts)
  if opts == true then opts = {shadow = true} end
  opts = opts or {}
  local width, height = Display.Dimensions(data)
  local growth, spacing = Display.FlowGrowth(data)
  local g = Display.GROWTH and Display.GROWTH[growth]
  if not g then return nil, "growth" end
  -- ForeverAuras (dev.74): a Centered row: the member's cells grow the
  -- visible way; its shadow chain (opts.shadow) grows the shadows' way;
  -- (dev.78) a reversed measurement chain grows the other way round
  if g.shadow then
    if opts.shadow then growth, g = g.shadowKey, g.shadow else growth, g = g.visible, Display.GROWTH[g.visible] end
  elseif opts.shadow then return nil, "growth" end
  if opts.reverse then growth = OPPOSITE_GROWTH[growth]; g = Display.GROWTH[growth] end
  local along = g.sign[1] ~= 0
  local alongUnits, crossUnits = along and width or height, along and height or width
  local stepUnits = alongUnits + spacing
  if stepUnits <= 0 then return nil, "step" end
  local margin = math.ceil(math.max(width, height) * 0.5) + 8   -- GateMargin (SecretAuraSingle.lua)
  local reachAlong, reachCross = margin, margin
  for _, element in ipairs(data.subRegions or {}) do
    local rect = ElementRect(element, width, height)
    if rect then
      local left, right = math.max(0, -width / 2 - rect[1]), math.max(0, rect[2] - width / 2)
      local bottom, top = math.max(0, -height / 2 - rect[3]), math.max(0, rect[4] - height / 2)
      local x, y = math.max(left, right), math.max(bottom, top)
      reachAlong = math.max(reachAlong, along and x or y)
      reachCross = math.max(reachCross, along and y or x)
    end
  end
  local needUnits = alongUnits + 2 * (reachAlong + SLACK_UNITS)
  local q = 1
  while q * stepUnits < needUnits and q < MAX_Q do q = q * 2 end
  if q * stepUnits < needUnits then return nil, "reach" end
  return {alongUnits = alongUnits, crossUnits = crossUnits, stepUnits = stepUnits, reachAlong = reachAlong, marginUnits = reachCross,
    needUnits = needUnits, q = q, along = along, g = g, growth = growth, side = SIDE[growth]}
end

---------------------------------------------------------------------------- eligibility
-- The gates the saved trigger asks for, read from its fields alone (no
-- editor validation): whether a Total Duration = / >= filter is set, and
-- the Stack Count filter's kind and n (Display.StackFilter).
local function ChainGates(trigger)
  local op = Display.TotalFilter(trigger)
  local kind, n = Display.StackFilter(trigger)
  -- ForeverAuras (dev.55): a Remaining Time window is a timed gate like a
  -- Total Duration filter (the text follows RemainingDuration instead).
  local remLower, remUpper
  if Display.RemainingRange then remLower, remUpper = Display.RemainingRange(trigger) end
  return op == "=" or op == ">=", kind, n, remLower, remUpper
end

-- Why the display's shape keeps it out of the chain, or nil: not a supported
-- row ("group"), a row on unit frames ("frame") or wrapped ("wrap"), not an
-- Aura(s) Found list ("showOn"), a Remaining Time window ("remaining"), more
-- than one unit ("unit"). A gated list's capacity is always CHAIN_RECORDS
-- (RawMaxAuras: ten for a list with a gate), so the batch holds every
-- record. Reads no gate reader and not MaxAuras (which reads UsesGate), so
-- the gate readers may ask it (no recursion).
local function ChainShapeProblem(data, trigger)
  if not Display.FlowIndependentGroup then return "group" end
  local group = Display.FlowGroup and Display.FlowGroup(data)
  -- Unsupported group layouts retain their existing explanations. A legacy,
  -- Grid or explicitly disabled group is an ordinary row ("group": silent).
  local groupWhy = Display.FlowIndependentGroupProblem and Display.FlowIndependentGroupProblem(group)
  if groupWhy == "off" or (not Display.FlowIndependentGroupProblem and not Display.FlowIndependentGroup(group)) then return "group" end
  if groupWhy then return groupWhy end
  if Display.FlowFrameMode and Display.FlowFrameMode(data) then return "frame" end
  if Display.IconsPerRow and Display.IconsPerRow(data) then return "wrap" end
  if not trigger or Display.ShowOn(trigger) ~= "showOnActive" then return "showOn" end
  -- ForeverAuras (dev.55): Remaining Time on an Icon draws ONE aura (the
  -- single display, IsSingle), not a list: it keeps its one spot (the row
  -- closes up when the window is empty: the remain measure). On bars, textures
  -- and texts it is a list and chains like a Total Duration filter.
  if Display.IsSingle and Display.IsSingle(trigger, data) then return "remaining" end
  if Display.singleUnits and not Display.singleUnits[trigger.unit] then return "unit" end
end

-- Whether a Total Duration = / >= filter and a Stack Count >= n filter may
-- be set together on this display: only where the chain draws them (the
-- bar hangs from the text; dev.40 review). Asked by the Stack Count
-- validator (SecretAuraSingle.lua, StackFilterProblem); calls no gate
-- reader itself, so FlowChain -> StackGate -> StackFilterProblem -> here
-- never comes back to FlowChain.
function Display.ChainAllowsConjunction(data, trigger)
  -- ForeverAuras (dev.61, Dan's dev.60 probes; wording dev.62 after Astra's
  -- dev.61 review): NEVER, for now. The conjunction of a timed filter with a
  -- Stack Count was the one bar whose width came from the timed text: with
  -- the text closed that bar had zero width, and in Dan's zero check a 1 px
  -- frame hung from an explicitly zero-WIDTH StatusBar (SetSize(0, 20)) or
  -- its fill read nil while the 160 px control resolved. The production bar
  -- got its zero from two edge anchors to a text, which was not the probed
  -- shape, so this is the disabling of an unverified construction, not a
  -- proof that no construction exists (a bar of e + D with a second e-long
  -- bar to subtract is one untested candidate). The validator's rejection
  -- of the pair stays (the display is refused with its warning, not built
  -- at one spot) until a replacement is designed and checked.
  return false
end

-- Supported single-unit Found lists use row cells automatically. Eligibility,
-- binding conflicts and the ten-record capacity still decide whether a list
-- can be chained. Historical experiment switches no longer change eligibility.
function Display.ChainEnabled()
  return true
end

function Display.FlowChain(data)
  if not data then return nil end
  local trigger = Display.GetTrigger(data)
  if not trigger then return nil end
  local hasDuration, kind, n, remLower, remUpper = ChainGates(trigger)
  -- A list without any filter says nothing.
  if not (hasDuration or kind or remLower) then return nil end
  local why = ChainShapeProblem(data, trigger)
  if why == "group" then return nil end
  if not Display.ChainEnabled() then return nil, "switch" end
  -- ForeverAuras (dev.70): a display being built under aura restrictions
  -- takes its ordinary construction for now (BlizzardAuraDisplay.lua,
  -- native.chainDeferred); it is built again as chained when they end.
  do
    local entry = Private.regions and Private.regions[data.id]
    local native = entry and entry.region and entry.region.blizzardAuraDisplay
    if native and native.chainDeferred then return nil, "deferred" end
  end
  if why then return nil, why end
  local spec = {}
  if hasDuration then
    local lower, upper = Display.DurationGate(data, trigger)
    -- A filter the display cannot draw at all: its own text explains it.
    if not lower then return nil end
    spec.duration = {lower = lower, upper = upper}
  elseif remLower then
    -- ForeverAuras (dev.55): a Remaining Time list (bars, textures, texts):
    -- the cell's text follows the time left; the ordinary gate's rules
    -- (RemainingGateRange: no Total Duration with it, a usable window)
    -- decide whether it can be drawn at all.
    if not (Display.RemainingGateRange and Display.RemainingGateRange(data, trigger)) then return nil end
    spec.remaining = {lower = remLower, upper = remUpper}
  end
  local timed = spec.duration or spec.remaining
  if kind == "never" then return nil, "stacks" end
  if kind then
    -- ForeverAuras (dev.55-63): every Stack Count kind lays out with the
    -- button's bound COUNT text (SetApplicationCount, as the ordinary exact
    -- gate: StyleExactStackGate) formatted to the cell's markup for counts
    -- in the range and empty otherwise (empty for an absent record too; no
    -- duration binding touched: a timed glow keeps its own): >= n is n..,
    -- <= n is 0..n, = n is n..n. (dev.63, Dan's first row: the >= cell was a
    -- bound bar with minApplications = n - 1 / maxApplications = n; in game
    -- that prototype failed: cells open for unstacked buffs and for records
    -- without an aura, gaps, while the = and <= count-text cells of the same
    -- row were right. Not diagnosed - the reference updater also HIDES the
    -- bar below its minimum, which the model never had, and the cells'
    -- geometry is secret to the addon - the bar was replaced by the count
    -- text's rule, the one shown working. Astra's dev.63 review.) The button has one
    -- count binding: a display whose %s stack text uses it keeps that text
    -- only for = n (the count is known: StackTextFor hands it off); for >= n
    -- and <= n such a display keeps one spot ("stacksText"). A Stack Count
    -- together with a timed filter cannot lay out at all
    -- (ChainAllowsConjunction).
    if timed then return nil, "stacksConjunction" end
    if kind == "atLeast" and (n or 0) < 1 then return nil end
    local gateKind, gateN = Display.StackGate(data, trigger)
    if gateKind ~= kind then return nil end
    if kind ~= "exactly" and Display.UsesStackText and Display.UsesStackText(data) then return nil, "stacksText" end
    spec.stacks, spec.stackKind = gateN, kind
    if kind == "atMost" then spec.count = {lower = 0, upper = gateN}
    elseif kind == "exactly" then spec.count = {lower = gateN, upper = gateN}
    else spec.count = {lower = gateN, upper = nil} end
  end
  -- (dev.115) with the glow on a binding of the addon's own (SecretAuraSingle.lua, Display.GlowGateViaBinding)
  -- a timed chain keeps its "Remaining Time < X" glow and packs; without it the glow needs the gate text
  if timed and Display.LateGlowSpec and Display.LateGlowSpec(data, trigger) and not Display.GlowGateViaBinding then return nil, "glow" end
  local bound, boundWhy = Display.ChainBound(data)
  if not bound then return nil, boundWhy end
  return spec
end

-- Why a gated list in an opted-in row is NOT chained (editor text), or nil.
local chainProblemTexts
function Display.ChainProblem(data)
  local spec, why = Display.FlowChain(data)
  if spec or not why then return nil end
  chainProblemTexts = chainProblemTexts or {
    stacks = L["Row cells: a Stack Count filter that can never match keeps one spot in the row."],
    deferred = L["Row cells: built as one spot during combat (the client allows no packed construction under aura restrictions); laid out side by side when the restrictions end."],
    stacksConjunction = L["Row cells: a Stack Count filter together with a Total Duration = / >= or Remaining Time filter is not supported yet (its side-by-side construction was withdrawn); the display is not shown. Each filter alone lays out side by side."],
    stacksText = L["Row cells: Stack Count >= n and <= n use the display's one stack-count binding, so a display with a %s stack text keeps one spot in the row; remove the stack text to lay it out side by side (= n keeps it: the count is known)."],
    glow = L["Row cells: a Total Duration filter and a Remaining Time glow condition share one measurement; this display keeps one spot in the row."],
    remaining = L["Row cells: Remaining Time on an Icon draws one aura and keeps one spot in the row (the row closes up while no aura is in the window); on bars, textures and texts the list lays out side by side."],
    unit = L["Row cells: a list of several units keeps one spot in the row; only single-unit lists lay out side by side."],
    reach = L["Row cells: this display's elements reach further than 8 row steps around the icon; the display keeps one spot in the row. Move the elements closer or make the spacing larger."],
    growth = L["Row cells: a Centered row keeps one spot for this display."],
    frame = L["Row cells: a row on unit frames or nameplates keeps one spot for this display."],
    wrap = L["Row cells: a wrapped list keeps one spot in the row."],
  }
  return chainProblemTexts[why]
end

---------------------------------------------------------------------------- calibration
-- Texture markup n screen pixels long along the row and 1 across.
local function Markup(n, along) return ("|T%s:%d:%d|t"):format(WHITE, along and 1 or n, along and n or 1) end

-- The member's chain geometry, measured once per apply on the display's own
-- unbound probe text (readable: nothing secret is involved), on the row's
-- actual axis (horizontal markup and widths for a horizontal row, vertical
-- markup and heights for a vertical one):
--   px        screen pixels per unit of the region
--   stepPx    icon + spacing in whole pixels (the row's step, as FlowSpacing)
--   q, Fpx    the fill length F = q * step (q from ChainBound)
--   n         the markup length whose rendered extent is closest to F
--   rPx       rendered - F (the residual the halvings divide; at most FILL_TOLERANCE_PX)
--   bPx       the anchor extent of the empty text (its baseline)
--   crossUnits, alongUnits, marginUnits   from ChainBound
-- Returns nil and why when a read is refused or unreadable, when no markup
-- renders within FILL_TOLERANCE_PX of F, or when the rendered extent does
-- not follow the markup length (the axis does not measure): an assumed
-- measurement is no calibration (dev.40 review).
-- ForeverAuras (dev.79, Astra's dev.77 review): a HALF-step chain (a Centered
-- row's shadow) is the measured calibration with q DOUBLED: the same markup
-- renders the same F + r, and one more halving makes every cell advance
-- exactly half of the visible cell's, (F + r) / 2q, with no rounding of its
-- own. opts.from: a calibration measured on this member (its numbers are
-- reused; only the direction and q change).
function Display.ChainCalibrate(region, data, native, opts)
  if opts == true then opts = {shadow = true, half = true} end
  opts = opts or {}
  local bound, why = Display.ChainBound(data, opts)
  if not bound then return nil, why end
  local from = opts.from
  if from and from.px == ((Display.PixelsPerUnit and Display.PixelsPerUnit(region)) or 1) and from.along == bound.along and from.stepUnits == bound.stepUnits then
    local c = {}
    for k, v in pairs(from) do c[k] = v end
    c.content, c.localCells, c.g, c.growth, c.side = nil, nil, bound.g, bound.growth, bound.side
    if opts.half then c.q = from.q * 2 end
    return c
  end
  local px = (Display.PixelsPerUnit and Display.PixelsPerUnit(region)) or 1
  local along = bound.along
  local stepPx = math.floor(bound.stepUnits * px + 0.5)
  if stepPx <= 0 then return nil, "step" end
  local alongPx = math.floor(bound.alongUnits * px + 0.5)
  local Fpx = bound.q * stepPx
  -- Probe: the empty baseline and the fill's rendered extent, by anchoring a
  -- frame to the probe text's edges on the row's axis (anchor extents, not
  -- GetStringWidth).
  -- ForeverAuras (dev.69, Astra's dev.68 review): every probe frame is owned
  -- (native.chainProbe) the moment it exists, so a refusal between the
  -- allocations loses nothing; a partial probe is completed next time.
  local probe = native.chainProbe
  if not probe then probe = {}; native.chainProbe = probe end
  if not probe.holder then probe.holder = CreateFrame("Frame", nil, region) end
  if not probe.ruler then probe.ruler = CreateFrame("Frame", nil, region) end
  if not probe.text then probe.text = probe.holder:CreateFontString(nil, "ARTWORK") end
  if not probe.placed then
    probe.holder:SetAlpha(0); probe.holder:SetSize(1, 1); probe.holder:ClearAllPoints(); probe.holder:SetPoint("TOPLEFT", region, "TOPLEFT")
    probe.text:ClearAllPoints(); probe.text:SetPoint("TOPLEFT", probe.holder, "TOPLEFT")
    probe.placed = true
  end
  probe.holder:SetScale(1 / px)
  probe.text:SetFont(STANDARD_TEXT_FONT, 12, "")
  probe.text:SetWordWrap(false)
  probe.text:SetWidth(0)
  probe.ruler:ClearAllPoints()
  if along then
    probe.ruler:SetHeight(1)
    probe.ruler:SetPoint("TOP", probe.holder, "TOP")
    probe.ruler:SetPoint("LEFT", probe.text, "LEFT"); probe.ruler:SetPoint("RIGHT", probe.text, "RIGHT")
  else
    probe.ruler:SetWidth(1)
    probe.ruler:SetPoint("LEFT", probe.holder, "LEFT")
    probe.ruler:SetPoint("TOP", probe.text, "TOP"); probe.ruler:SetPoint("BOTTOM", probe.text, "BOTTOM")
  end
  -- The ruler frame (unscaled) spans the text's screen extent on the axis;
  -- its size in region units times px is the extent in pixels.
  local read = along and probe.ruler.GetWidth or probe.ruler.GetHeight
  local function ExtentPx(s)
    probe.text:SetText(s)
    local okW, w = pcall(read, probe.ruler)
    if not okW or not Readable(w) then return nil end
    return w * px
  end
  local function Done(result, reason)
    probe.text:SetText("")
    return result, reason
  end
  local bPx = ExtentPx("")
  if not bPx then return Done(nil, "the empty text could not be measured") end
  local best, bestExtent
  -- ForeverAuras (dev.62): the search spans F +- 10 (was +- 3): Dan's dev.61
  -- cell check rendered a 160 px markup 156.35 px wide on his client (2.3 %
  -- short); +- 3 only just reached that with the tolerance, a larger client
  -- difference would have refused the display for nothing.
  for n = math.max(1, Fpx - 10), Fpx + 10 do
    local e = ExtentPx(Markup(n, along))
    if e and e > 0 and (not best or math.abs(e - bPx - Fpx) < math.abs(bestExtent - bPx - Fpx)) then best, bestExtent = n, e end
  end
  if not best then return Done(nil, "the fill could not be measured") end
  local rPx = bestExtent - bPx - Fpx
  if math.abs(rPx) > FILL_TOLERANCE_PX then return Done(nil, ("the fill renders %.1f px off its length"):format(rPx)) end
  -- The extent must follow the markup length on this axis (a vertical text
  -- whose height ignores the markup would otherwise pass with a fixed line).
  local shorter = ExtentPx(Markup(best - 4, along))
  if not shorter or math.abs((bestExtent - shorter) - 4) > FILL_TOLERANCE_PX then return Done(nil, "the fill's length does not follow the markup on this axis") end
  return Done({px = px, stepUnits = bound.stepUnits, stepPx = stepPx, alongUnits = bound.alongUnits, alongPx = alongPx,
    crossUnits = bound.crossUnits, q = opts.half and bound.q * 2 or bound.q, Fpx = Fpx, n = best, rPx = rPx, bPx = bPx, marginUnits = bound.marginUnits,
    along = along, g = bound.g, growth = bound.growth, side = bound.side})
end

---------------------------------------------------------------------------- the link
-- A guarded write; the first refusal names the operation (dev.18 convention).
local function Try(op, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then return false, op .. ": " .. tostring(err) end
  return true
end

-- ForeverAuras (cell chain, dev.42-47 reviews): what may still be drawn
-- while the client refused to hide a cell: the member reserves the longest
-- construction those frames can hold (SetFlowEnd): ten cells at the measured
-- advance (step + residual / q, residual counted when it lengthens a cell),
-- kept across later settings attempts until every frame is hidden or the
-- chain is committed. The frames may hold the construction being attempted
-- (chainCalib) or the last one completed in them (chainBuilt), or both: the
-- longer. Shared by a failure's hides (NoteChainFailure) and a staged cell's
-- (StyleChainLink).
local function ReserveRefusedHides(native)
  local function Extent(calib)
    if calib and calib.px then return CHAIN_RECORDS * (calib.stepPx + math.max(0, calib.rPx or 0) / calib.q) / calib.px end
  end
  local extent = Extent(native.chainCalib)
  local built = Extent(native.chainBuilt)
  if built and (not extent or built > extent) then extent = built end
  if not extent then
    local bound = native.data and Display.ChainBound(native.data)
    extent = bound and CHAIN_RECORDS * (bound.stepUnits + 1) or nil
  end
  if extent then native.chainReserve = math.max(native.chainReserve or 0, extent) end
end
-- ForeverAuras (cell chain, dev.48 review): the quiet display's current
-- refused hides, by record identity: quiet.hides[record] = hidden (true/false)
-- for every record asked to hide (a failure's QuietChain and a staged cell's
-- StyleChainLink alike); quiet.refused is the number of records whose LAST
-- hide was refused, so a repeated refusal counts once and a hide accepted
-- later resolves that record's own refusal.
local function NoteQuietHide(quiet, record, hidden)
  quiet.hides = quiet.hides or setmetatable({}, {__mode = "k"})
  local was = quiet.hides[record]
  quiet.hides[record] = hidden
  if was == false and hidden then quiet.refused = math.max(0, (quiet.refused or 0) - 1)
  elseif was ~= false and not hidden then quiet.refused = (quiet.refused or 0) + 1 end
end
-- A quiet display's record asked to hide (a staged cell, StyleChainLink; a
-- record past the batch, NoteChainOverflow; dev.49 review: every path that
-- hides one record updates the same identity): the record's own refusal is
-- repeated or resolved; a refusal reserves the member's full length; the last
-- one resolved releases it (every frame is known hidden). Outside an apply, a
-- change of the count or the reserve is said and laid out through the usual
-- paths (inside one, FinishApply does both).
local function NoteStagedHide(region, owner, record, hidden)
  local quiet = owner.chainQuiet
  local before, reserveBefore = quiet.refused or 0, owner.chainReserve
  NoteQuietHide(quiet, record, hidden)
  if not hidden then
    ReserveRefusedHides(owner)
  elseif (quiet.refused or 0) == 0 then
    owner.chainReserve = nil
  end
  if not owner.applying and ((quiet.refused or 0) ~= before or owner.chainReserve ~= reserveBefore) and owner.data then
    Display.PublishChainWarnings(region, owner.data)
    if owner.chainReserve ~= reserveBefore and Display.SetFlowEnd and Display.RechainFlow and Display.FlowGroup then
      Display.SetFlowEnd(region, owner.data, nil)
      Display.RechainFlow(Display.FlowGroup(owner.data))
    end
  end
end

-- ForeverAuras (dev.67, Dan's combat reloads of the row): the SPINE - the
-- holders, the spans and the anchors between them - is the display's own,
-- built for all CHAIN_RECORDS positions at once, BEFORE any record's text is
-- bound. Under aura restrictions the client taints a frame anchored (even
-- indirectly) to a bound text with its forbidden aspect, so once record k's
-- text is bound nothing may be anchored to record k's spans any more: the
-- dev.65/66 attempt (spans under the region, hung per record) still failed
-- with "holder to the previous cell: Attempt to access forbidden object" for
-- records 6-10. Here holder k is anchored to span k-1 while that span hangs
-- from nothing yet; a record's own callback later only anchors ITS first
-- span to ITS text (both fresh) and its text, box and clip to ITS holder.
-- Every frame is made with DisableUntrustedLayoutScriptsTemplate (a plain
-- frame may not be anchored to a bound text at all: dev.66). Built once per
-- calibration (a new apply calibrates anew); the positions' geometry is the
-- dev.53 single-target spine unchanged.
-- The geometry a spine was built for (a new calibration table with the same
-- numbers reuses the spine as it is: a repaint or a condition change does
-- not disturb the shown cells).
local function SpineKey(calib)
  return table.concat({calib.px, calib.q, calib.crossUnits, calib.side.near, calib.side.corner, calib.along and 1 or 0, calib.g.sign[1], calib.g.sign[2]}, "|")
end

-- Measurement stays at the fixed pin. Only these outputs depend on the row.
-- Build every output before binding records; callbacks never translate a
-- secret-dependent edge. A failed rewrite keeps the existing anchors intact.
local function OutputPadding(data, calib)
  local group = Display.FlowGroup(data)
  local configured = Display.CarrierPadding and group and Display.CarrierPadding(group) or 64
  local localReach = CHAIN_RECORDS * ((calib.stepPx or 0) + math.abs(calib.rPx or 0)) / calib.px
    + (calib.Fpx or 0) / calib.px + (calib.crossUnits or 0)
    + math.abs(tonumber(data.xOffset) or 0) + math.abs(tonumber(data.yOffset) or 0) + 64
  return math.max(configured, localReach)
end
local function Output(owner, key, region, pin, corner)
  local item = owner[key]
  if item and item.corner ~= corner then
    owner.retiredOutputs = owner.retiredOutputs or {}
    owner.retiredOutputs[#owner.retiredOutputs + 1] = item
    item = nil
  end
  if not item then item = {corner = corner}; owner[key] = item end
  item.initialized = item.initialized or {}
  for _, name in ipairs({"h", "p", "out"}) do
    if not item[name] then
      item[name] = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
    end
    if not item.initialized[name] then
      local f = item[name]
      f:EnableMouse(false)
      if name == "out" then f:SetSize(1, 1); f:SetPoint(corner, pin, "TOPLEFT", 0, 0)
      elseif name == "h" then
        f:SetPoint("TOPLEFT", pin, "TOPLEFT", 0, 0)
        f:SetPoint("BOTTOMRIGHT", pin, "TOPLEFT", 1, -1)
      else
        f:SetPoint("TOPLEFT", pin, "TOPLEFT", 0, 0)
        f:SetPoint("CENTER", pin, "TOPLEFT", 1, -1)
      end
      item.initialized[name] = true
    end
  end
  return item
end
local function OutputCurrent(item, start, startPoint, input, inputPoint, pin, padding)
  local at = item.placed
  return at and at[1] == start and at[2] == startPoint and at[3] == input
    and at[4] == inputPoint and at[5] == pin and at[6] == padding
end
local function PlaceOutput(item, start, startPoint, input, inputPoint, pin, padding)
  if OutputCurrent(item, start, startPoint, input, inputPoint, pin, padding) then return true end
  local ok, step, why = Display.TranslatePoint(item, start, startPoint, input, inputPoint,
    pin, padding, item.out, item.corner)
  if not ok then return false, tostring(step) .. ": " .. tostring(why) end
  item.placed = {start, startPoint, input, inputPoint, pin, padding}
  return true
end
local function RefreshMainOutputs(region, data, native)
  if not Display.FlowChain(data) then return true end
  local calib, spine, flow = native.chainCalib, native.chainSpine, native.flow
  if not (calib and calib.localCells and spine and spine.key and flow and flow.chainLocalEnd) then return true end
  local pin, content = Display.CarrierPin(data), Display.ContentAnchor(region)
  if not pin then return false, "no group pin" end
  local padding, s = OutputPadding(data, calib), calib.side
  local hw = calib.along and 1 / calib.px or calib.crossUnits
  local hh = calib.along and calib.crossUnits or 1 / calib.px
  local rewriting = spine.endOutput and spine.endOutput.placed
    and not OutputCurrent(spine.endOutput, content, s.corner, flow.chainLocalEnd, s.corner, pin, padding)
  for k = 1, CHAIN_RECORDS do
    local p = spine[k]
    local holder, far = p and p.holderOutput, p and p.farOutput
    if holder and holder.placed and (holder.width ~= hw or holder.height ~= hh
      or not OutputCurrent(holder, content, s.corner, p.holder, s.corner, pin, padding)) then rewriting = true end
    if far and far.placed and not OutputCurrent(far, content, s.corner, p.spans[1], s.far, pin, padding) then rewriting = true end
  end
  if rewriting and native.instances and native.instances[1] then
    -- A partial rewrite must never expose partially translated artwork.
    -- Refused hides stop the rewrite before its first placement write.
    local quiet = native.chainQuiet or {}
    quiet.hides, quiet.refused = nil, 0
    native.chainQuiet = quiet
    for _, instance in ipairs(native.instances) do
      quiet.refused = quiet.refused + Display.QuietChain(instance, nil, quiet)
    end
    if quiet.refused > 0 then
      ReserveRefusedHides(native)
      return false, "artwork could not be hidden before updating its row position"
    end
    if flow.chainEndReady then
      native.chainCommitPending = native.chainCommitPending or {instance = native.instances[1]}
      native.chainCommitResult = nil
    end
  end
  for k = 1, CHAIN_RECORDS do
    local p = spine[k]
    if not p then return false, "local cell missing" end
    local holder = Output(p, "holderOutput", region, pin, s.corner)
    local far = Output(p, "farOutput", region, pin, "TOPLEFT")
    -- The output holder has the same rectangle as its pixel-scaled input.
    if holder.width ~= hw or holder.height ~= hh then
      holder.out:SetSize(hw, hh); holder.width, holder.height = hw, hh
    end
    local ok, why = PlaceOutput(holder, content, s.corner, p.holder, s.corner, pin, padding)
    if not ok then return false, "cell position: " .. why end
    ok, why = PlaceOutput(far, content, s.corner, p.spans[1], s.far, pin, padding)
    if not ok then return false, "cell clipping: " .. why end
    p.visualHolder, p.clipFarOutput = holder.out, far.out
  end
  local endpoint = Output(spine, "endOutput", region, pin, s.corner)
  local ok, why = PlaceOutput(endpoint, content, s.corner, flow.chainLocalEnd, s.corner, pin, padding)
  if not ok then return false, "member end: " .. why end
  flow.chainEnd, flow.chainEndWired, flow.chainCorner = endpoint.out, true, s.corner
  return true
end
function Display.RefreshLocalChainOutputs(region, data)
  local native = region and region.blizzardAuraDisplay
  if not native then return true end
  local ok, result, why = pcall(RefreshMainOutputs, region, data, native)
  if not ok then return false, tostring(result), "main" end
  if not result then return false, why, "main" end
  local flow = native.flow
  for _, key in ipairs({"measureChain", "shadowChain"}) do
    local mc = flow and flow[key]
    if mc and mc.localOutput and mc.out and mc.chainCalib and mc.chainSpine and mc.chainSpine.key
      and mc.flow and mc.flow.chainEndWired then
      local output = mc.localOutput
      local padding = OutputPadding(data, mc.chainCalib)
      local anchor = key == "shadowChain" and flow.shadowStart or Display.ContentAnchor(region)
      local placed, op, err = true, nil, nil
      if mc.outputPadding ~= padding or mc.outOn ~= anchor then
        placed, op, err = Display.TranslatePoint(mc.helpers, anchor, output.anchorPoint,
          mc.flow.chainEnd, output.corner, output.pin, padding, mc.out, output.corner)
        if placed then mc.outputPadding, mc.outOn = padding, anchor end
      end
      if not placed then return false, "measurement output: " .. tostring(op) .. ": " .. tostring(err), key end
    end
  end
  return true
end
-- A built spine is reused as it is only for the same geometry AND the same
-- content frame (dev.69, Astra's dev.68 review: the first holder hangs from
-- Display.ContentAnchor(region), which a row-origin change or a replaced
-- layout frame swaps while the numbers stay the same).
-- ForeverAuras (dev.74): owner is the construction the spine belongs to: the
-- display's native state, or a shadow chain (its content frame is the
-- member's shadow start, calib.content; its end lives in its own flow).
local function SpineCurrent(spine, region, calib, owner)
  local content = calib.content or Display.ContentAnchor(region)
  if not (spine ~= nil and spine.key ~= nil and spine.key == SpineKey(calib) and spine.content == content) then return false end
  -- the prewired end must be in place (dev.70; dev.71: whether the client
  -- lets us touch it is no criterion - once the last cell is bound the end
  -- depends on a secret and is forbidden to us by design; it is never
  -- written again)
  local native = owner or region.blizzardAuraDisplay
  local flow = native and native.flow
  if flow and not (flow.chainEnd and flow.chainEndWired) then return false end
  return true
end
-- Unfinished release writes (a refused ClearAllPoints or Hide) are kept by
-- frame and operation and tried again by the next release or preparation
-- (dev.69): nothing is assumed writable.
local function ServiceSpine(spine)
  local left = spine and spine.unfinished
  if not left then return true end
  local still = {}
  for _, job in ipairs(left) do
    local ok = pcall(job.frame[job.op], job.frame)
    if not ok then still[#still + 1] = job end
  end
  spine.unfinished = (#still > 0) and still or nil
  return #still == 0
end
local function EnsureSpine(owner, region, calib, data)
  local spine = owner.chainSpine
  if SpineCurrent(spine, region, calib, owner) then return spine end
  local function Forbidden(frame) return frame ~= nil and Display.Locked ~= nil and Display.Locked(frame) end
  -- ForeverAuras (dev.84, Dan's combat freeze): under restrictions a spine
  -- that would have to be written again is first checked whole. The writes
  -- below clear each holder and span and anchor it again; a frame of the
  -- old spine that the client has made forbidden (its place depends on a
  -- bound end: a member rebuilt under restrictions after the row was placed
  -- out of them, Dan's "SetScale on bad self") refuses the write part way,
  -- and whatever was cleared before it hung unresolved from then on, with the
  -- rest of the row behind it; the client's layout walk then revisits that
  -- unresolved dependency until it hangs. So: forbidden content or a
  -- forbidden spine frame means nothing is written and the old spine stays
  -- as it is (resolvable, drawing nothing new); the build is set aside and
  -- prepares again when restrictions end.
  -- (Astra's dev.83 review: a frame may stay forbidden through a short spell
  -- out of restrictions, so the check does not depend on them: a forbidden
  -- frame refuses the write whenever it is made)
  do
    local content = calib.content or Display.ContentAnchor(region)
    if Forbidden(content) then return nil, "the row's spine: the content is forbidden under restrictions (kept as built)" end
    if spine then
      for k = 1, CHAIN_RECORDS do
        local p = spine[k]
        if p then
          if Forbidden(p.holder) then return nil, "the row's spine: holder " .. k .. " is forbidden under restrictions (kept as built)" end
          for i, z in ipairs(p.spans) do if Forbidden(z) then return nil, "the row's spine: span " .. k .. "." .. i .. " is forbidden under restrictions (kept as built)" end end
        end
      end
    end
    -- (a forbidden END is replaced by a fresh frame below, as before: the old one stays where it is, anchored)
  end
  -- ForeverAuras (dev.89, Astra's dev.88 review P1): the rewrite is NON-
  -- DESTRUCTIVE. No frame of a published spine is ever cleared: each anchor is
  -- written on the same point it had (a point set again replaces its anchor
  -- in one write), so a refusal anywhere leaves every frame with the anchors
  -- it had on the points not yet written and the new ones on the points
  -- written - all resolvable, nothing to restore. Sizes and scales are
  -- written only when they differ; a rewrite of the same geometry refused
  -- part way therefore changes nothing, while one of a changed geometry
  -- leaves a mix (resolvable, drawn nothing of until the member is prepared
  -- again) - not the old geometry back. A spine whose SIDE changed (the row grows another way:
  -- other point names) is not rewritten at all: the old one is retired as it
  -- is (hidden, anchored, the hosts and the end still hang from it) and a
  -- fresh one is made; the next row pass moves the followers to the new end.
  local sideKey = calib.side.corner .. "/" .. calib.side.near .. "/" .. calib.side.far
  if spine and spine.side and spine.side ~= sideKey then
    local retired = owner.chainSpineRetired or {}
    owner.chainSpineRetired = retired
    retired[#retired + 1] = spine
    for k = 1, CHAIN_RECORDS do
      local p = spine[k]
      if p then pcall(p.holder.Hide, p.holder); for _, z in ipairs(p.spans) do pcall(z.Hide, z) end end
    end
    spine = nil
    if owner.flow then
      owner.flow.chainEnd, owner.flow.chainEndWired, owner.flow.chainLocalEnd = nil, nil, nil
    end   -- fresh public and local ends too (their point names change)
  end
  spine = spine or {}
  owner.chainSpine = spine
  spine.key, spine.content = nil, nil   -- incomplete until every write below succeeded (dev.68: Astra's dev.67 review)
  -- (dev.71) an earlier release's refused writes are tried once more here; what is
  -- still refused is written again below anyway, under this build's protection
  ServiceSpine(spine)
  -- a property is written only when it differs (a refused rewrite leaves the old geometry whole); one that
  -- cannot be read is written as before
  -- ForeverAuras 1.2.1 (Dan's re-add refusal, "arithmetic on local 'have' (a secret number value)"): a
  -- holder kept from the member's earlier construction can report a SECRET size or scale (it hung from
  -- bound frames); that counts as unreadable and is written again, never compared
  local function Differs(frame, method, want)
    local okR, have = pcall(frame[method], frame)
    if not okR or not Readable(have) then return true end
    return math.abs(have - want) >= 1e-6
  end
  local ok, err = pcall(function()
    local s, px, sign, along = calib.side, calib.px, calib.g.sign, calib.along
    local sx, sy = along and (sign[1]) or 0, along and 0 or sign[2]
    local function Along(v) return sx * v, sy * v end
    local Lu = PAD_PX / px
    local halvings, qq = 0, calib.q
    while qq > 1 do halvings = halvings + 1; qq = qq / 2 end
    local content = calib.content or Display.ContentAnchor(region)
    for k = 1, CHAIN_RECORDS do
      local p = spine[k] or {spans = {}}
      spine[k] = p
      if not p.holder then
        p.holder = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
        p.holder:EnableMouse(false)
      end
      if Differs(p.holder, "GetScale", 1 / px) then p.holder:SetScale(1 / px) end
      local hw, hh = along and 1 or calib.crossUnits * px, along and calib.crossUnits * px or 1
      if Differs(p.holder, "GetWidth", hw) or Differs(p.holder, "GetHeight", hh) then p.holder:SetSize(hw, hh) end
      if k == 1 then
        p.holder:SetPoint(s.corner, content, s.corner, 0, 0)
      else
        local prev = spine[k - 1]
        p.holder:SetPoint(s.near, prev.point, prev.pointSide, Along((prev.pointOffset or 0) * px))
      end
      p.holder:Show()
      local n = halvings == 0 and 1 or halvings
      for i = 1, n do
        local z = p.spans[i]
        if not z then z = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate"); p.spans[i] = z end
        if along then if Differs(z, "GetHeight", calib.crossUnits) then z:SetHeight(calib.crossUnits) end
        else if Differs(z, "GetWidth", calib.crossUnits) then z:SetWidth(calib.crossUnits) end end
        -- span i > 1 hangs from span i - 1: [previous.near, previous.CENTER + L]; span 1 is anchored to the
        -- record's text in the record's own callback (StyleChainLink). (dev.79, Astra's dev.77 review:
        -- nothing of the spine is left unresolved between the preparation and the callbacks: the client's
        -- layout walk revisits an unresolved dependency through every duplicate entry) until then span 1
        -- holds the CLOSED cell's geometry on its own holder, [near - L, near + L]: the point advances by 0
        if i > 1 then
          z:SetPoint(s.near, p.spans[i - 1], s.near, Along(0))
          z:SetPoint(s.far, p.spans[i - 1], "CENTER", Along(Lu))
        else
          z:SetPoint(s.near, p.holder, s.near, Along(-Lu))
          z:SetPoint(s.far, p.holder, s.near, Along(Lu))
        end
        z:Show()
      end
      for i = n + 1, #p.spans do p.spans[i]:Hide() end
      if halvings == 0 then p.point, p.pointSide, p.pointOffset = p.spans[1], s.far, -Lu
      else p.point, p.pointSide, p.pointOffset = p.spans[n], "CENTER", 0 end
    end
    -- ForeverAuras (dev.70, Astra's dev.69 handoff): the member's END is
    -- wired to the LAST cell's point here, before any record is bound (the
    -- records are bound from the last cell back to the first, StyleChainLink,
    -- so an anchor to the end is never written after it depends on a secret).
    local flow = owner.flow
    if flow then
      local E = calib.localCells and flow.chainLocalEnd or flow.chainEnd
      if not E or (Display.Locked and Display.Locked(E)) then
        E = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
        if calib.localCells then flow.chainLocalEnd = E else flow.chainEnd = E end
        E:EnableMouse(false)
      end
      local width, height = Display.Dimensions(data or owner.data)
      local last = spine[CHAIN_RECORDS]
      if Differs(E, "GetWidth", width) or Differs(E, "GetHeight", height) then E:SetSize(width, height) end
      E:SetPoint(s.near, last.point, last.pointSide, Along((last.pointOffset or 0)))
      if not calib.localCells then flow.chainEndWired, flow.chainCorner = true, s.corner end
    end
  end)
  if not ok then return nil, "the row's spine: " .. tostring(err) end
  spine.key, spine.content, spine.side = SpineKey(calib), calib.content or Display.ContentAnchor(region), sideKey
  return spine
end

-- The spine let go (dev.68): a stopped probe build, a release, containers
-- made new. Every frame unanchored and hidden (they are the addon's own,
-- made outside any record's callback: always writable), the structure kept
-- for reuse; the next preparation anchors it again. Nothing of an old
-- construction stays drawn through them (they have no artwork; the cells'
-- clips are the records').
function Display.ReleaseChainSpine(native)
  -- ForeverAuras (dev.74): the member's shadow chain (a Centered row) goes with it
  local shadowChain = native and native.flow and native.flow.shadowChain
  if shadowChain and shadowChain ~= native then Display.ReleaseChainSpine(shadowChain) end
  local measureChain = native and native.flow and native.flow.measureChain
  if measureChain and measureChain ~= native then Display.ReleaseChainSpine(measureChain) end
  local spine = native and native.chainSpine
  if not spine then return end
  spine.key, spine.content = nil, nil
  -- ForeverAuras (dev.84, Dan's combat freeze; Astra's dev.83 review P1):
  -- a released spine is never UNANCHORED. Its end is still published to the
  -- row (the next member's start was prewired on it, a shadow's translation
  -- hangs from a measurement's end), and a frame left with no anchors while
  -- others hang from it is an unresolved dependency that the client's layout
  -- walk revisits through every duplicate entry until it hangs (Dan's
  -- combat re-entry: a member rebuilt under restrictions, its old spine let
  -- go, the row behind it hanging from the cleared end). So the spine is
  -- marked stale (key cleared above) and its frames hidden only; the next
  -- preparation clears and anchors each frame again in one go, and the end
  -- is written again before any record binds, as always.
  do
    local flow = native.flow
    if flow then flow.chainEndReady, flow.chainEndWired = nil, nil end
  end
  ServiceSpine(spine)
  local unfinished, listed = {}, {}
  for _, job in ipairs(spine.unfinished or {}) do listed[job.frame] = listed[job.frame] or {}; listed[job.frame][job.op] = true; unfinished[#unfinished + 1] = job end
  local function Write(frame, op)
    if listed[frame] and listed[frame][op] then return end   -- still refused from before: listed once
    if not pcall(frame[op], frame) then unfinished[#unfinished + 1] = {frame = frame, op = op} end
  end
  for k = 1, CHAIN_RECORDS do
    local p = spine[k]
    if p then
      if p.holder then Write(p.holder, "Hide") end
      for _, z in ipairs(p.spans) do Write(z, "Hide") end
    end
  end
  local flow = native.flow
  spine.unfinished = (#unfinished > 0) and unfinished or nil
end

-- Called by Apply before the containers are made (outside callbacks): the
-- calibration and the spine of a chained display. A refusal here is left
-- for the first record's styling to report (the same functions run again
-- there and find the work done, or fail with the reason).
-- Returns true, or false and why (dev.68: the preparation is part of the
-- build's contract: Apply stops a probe build on it and records an ordinary
-- build's refusal; nothing is allocated for the spine inside a callback).
-- The old cells are quieted first when the spine's geometry changes (a size
-- or direction change): shared holders are rewritten below, and the quiet
-- display shows nothing until its commit anyway.
function Display.PrepareChain(region, data, native)
  if not (Display.FlowChain and Display.FlowChain(data)) then return true end
  if not native.chainCalib then
    -- ForeverAuras (dev.69): the calibration (its allocations, placements and
    -- reads) under the same protection as the spine: an exception is the
    -- preparation's first cause, returned through the build's contract.
    local okC, calib, why = pcall(Display.ChainCalibrate, region, data, native)
    if not okC then return false, "calibration: " .. tostring(calib) end
    if not calib then return false, "calibration: " .. tostring(why) end
    native.chainCalib = calib
  end
  local okLocal, localError = pcall(function()
    local calib = native.chainCalib
    local pin = Display.CarrierPin(data)
    if not pin then error("no group pin") end
    local base = native.chainLocalBase
    if not base or native.chainLocalCorner ~= calib.side.corner then
      native.chainLocalBases = native.chainLocalBases or {}
      base = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
      native.chainLocalBases[#native.chainLocalBases + 1] = base
      native.chainLocalBase = base
      base:EnableMouse(false)
      local width, height = Display.Dimensions(data)
      base:SetSize(width, height)
      base:SetPoint(calib.side.corner, pin, "TOPLEFT", 0, 0)
      native.chainLocalCorner, native.chainLocalPin = calib.side.corner, pin
    elseif native.chainLocalPin ~= pin then
      base:SetPoint(calib.side.corner, pin, "TOPLEFT", 0, 0)
      native.chainLocalPin = pin
    end
    calib.content, calib.localCells = base, true
  end)
  if not okLocal then return false, "local measurement: " .. tostring(localError) end
  local spine = native.chainSpine
  if spine and spine.key and not SpineCurrent(spine, region, native.chainCalib, native) then
    local quiet = native.chainQuiet or {}
    quiet.hides = nil
    for _, instance in ipairs(native.instances or {}) do quiet.refused = (quiet.refused or 0) + Display.QuietChain(instance, nil, quiet) end
    native.chainQuiet = quiet
    if (quiet.refused or 0) > 0 then ReserveRefusedHides(native) end
  end
  local built, err = EnsureSpine(native, region, native.chainCalib, data)
  if not built then return false, err end
  local okOutputs, outputError = Display.RefreshLocalChainOutputs(region, data)
  if not okOutputs then return false, "local outputs: " .. tostring(outputError) end
  -- the next member's start on this member's end, before any record is bound (dev.70)
  -- (dev.72) under the same protection as the calibration and the spine: an
  -- exception in the follower's allocation, placement or its own preparation
  -- is this preparation's first cause, returned through the build's contract
  -- (the follower's frames stay owned by the follower's own native state)
  if Display.PrewireFollower then
    local okP, okF, whyF = pcall(Display.PrewireFollower, region, data)
    if not okP then return false, "follower: " .. tostring(okF) end
    if not okF then return false, "follower: " .. tostring(whyF) end
  end
  return true
end

local invisibleCurve
-- The record's chain link: holder, spans, box, clip, element(s), binding.
-- previous: the previous record's native (its last span), nil for record 1.
-- The link's completion is dropped first, so a refused write leaves the
-- record incomplete for FinishChain. Returns true, or false and
-- "operation: error".
function Display.StyleChainLink(native, region, data, spec, calib, previous)
  local button = native.button
  local c = native.chain or {}
  native.chain = c
  c.complete, c.point, c.pointSide, c.pointOffset = nil, nil, nil, nil
  local s, px, sign = calib.side, calib.px, calib.g.sign
  local along = calib.along
  local sx, sy = along and (sign[1]) or 0, along and 0 or sign[2]   -- unit vector along the row
  local function Along(v) return sx * v, sy * v end                  -- offsets (units) along the row
  local Lu = PAD_PX / px
  local bu = calib.bPx / px
  local width, height = Display.Dimensions(data)
  -- Holder and spans: the record's position in the display's spine (dev.67,
  -- EnsureSpine): 1 px along, the icon across, pixel-scaled; its start
  -- corner is P. previous is no longer an anchor target (it may be forbidden
  -- in combat); the position index is the record's.
  local owner = native.owner or region.blizzardAuraDisplay   -- (dev.74) a shadow record's owner is its shadow chain
  local k = native.record or ((previous and previous.record or 0) + 1)
  if k > CHAIN_RECORDS then return false, "record beyond the chain" end
  local spine = owner and owner.chainSpine
  if not SpineCurrent(spine, region, calib, owner) then return false, "the row's spine was not prepared (Apply)" end
  -- ForeverAuras (dev.70, Astra's dev.69 handoff): records take the cells
  -- from the LAST back to the FIRST (record 1 is cell 10). A cell's holder
  -- depends on the cells BEFORE it, which are still unbound when it is
  -- written, so the client never refuses the write as depending on a secret;
  -- the cells after it, already bound, are never written again - they move
  -- through their anchors. (Forward order failed in combat from record 6 on:
  -- the holder already depended on the bound texts before it.)
  local pos = spine[CHAIN_RECORDS - k + 1]
  c.holder, c.localHolder, c.spans = pos.visualHolder or pos.holder, pos.holder, pos.spans
  -- The texts' host: the record's own pixel-scaled frame under the button
  -- (the bindings accept the button's descendants; the markup renders in
  -- screen pixels at scale 1 / px, as the calibration's probe text does),
  -- its near edge on the holder's (so its near edge is P).
  if not c.host then
    -- ForeverAuras (dev.77; Dan's Centered import freeze, the client's layout
    -- recursing): the host opts out of untrusted layout scripts like every
    -- other frame of the chain. In a Centered row the whole visible row hangs
    -- from the shadows' end, a secret-sized container for the ordinary
    -- members, so the hosts downstream are "placed from a secret-length
    -- container" too; without the opt-out the client's dependency tracking
    -- ran away (directional rows never had a container upstream of a host)
    c.host = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    c.host:EnableMouse(false)
  end
  c.host:SetScale(1 / px)
  if along then c.host:SetSize(1, calib.crossUnits * px) else c.host:SetSize(calib.crossUnits * px, 1) end
  c.host:ClearAllPoints()
  local ok, err = Try("the texts' host to the holder", c.host.SetPoint, c.host, s.near, c.localHolder, s.near, 0, 0)
  if not ok then return false, err end
  -- Output anchors are connected while this cell and its predecessors are
  -- still unbound. Binding below then moves them without another addon write.
  -- Box: the artwork, at P with the display's size (BuildButton gave it
  -- opposite anchors and no size of its own; dev.40 review).
  if native.box then
    native.box:ClearAllPoints()
    native.box:SetSize(width, height)
    native.box:SetPoint(s.corner, c.holder, s.corner, 0, 0)
  end
  -- Clip: F long centred on the icon while open, 0 while closed; the cross
  -- axis from the box with the artwork's cross margin (ChainBound). Shown
  -- here, inside the client's callback where the record is writable, unless
  -- the display is quiet (an incomplete chain, QuietChain): a repaint of a
  -- quiet display's records (RestyleButtons) must not reveal single cells;
  -- an apply drops the quiet state first and shows every link it completes,
  -- and a late record's completed chain is revealed by FinishChain
  -- (dev.42 review).
  local clip = native.gateClip
  if clip then
    local cu = (calib.Fpx - calib.alongPx) / 2 / px
    Display.ClipChildren(clip)
    local owner = region.blizzardAuraDisplay
    local quiet = owner and owner.chainQuiet
    if quiet then
      -- ForeverAuras (cell chain, dev.47 review): a staged cell is HIDDEN
      -- here, not merely left unshown: a reused record's clip is still shown
      -- by the construction before (an apply or Modify of a laid-out
      -- display), and a new record's clip is made shown (BuildButton). The
      -- hide is this record's current unresolved one when the client
      -- refuses it, and the member then reserves its full length until the
      -- commit (ReserveRefusedHides, SetFlowEnd). The accounting is by record
      -- identity (quiet.hides, dev.48 review): a failure's QuietChain and
      -- this staging write the same map, so a record styled again (a condition
      -- repaint) repeats or resolves its OWN refusal, never a second count;
      -- once no refused hide is left, every frame is known hidden and the
      -- reserve goes (the one-spot fallback again); NoteStagedHide.
      NoteStagedHide(region, owner, native, pcall(clip.Hide, clip))
    else
      clip:Show()
    end
    clip:ClearAllPoints()
    clip:SetPoint(s.near, c.holder, s.near, Along(-cu))
    if pos.clipFarOutput then
      clip:SetPoint(s.far, pos.clipFarOutput, "TOPLEFT", Along(-Lu - cu))
    else
      clip:SetPoint(s.far, c.spans[1], s.far, Along(-Lu - cu))
    end
    local box = native.box or button
    local m = calib.marginUnits
    if along then
      clip:SetPoint("TOP", box, "TOP", 0, m); clip:SetPoint("BOTTOM", box, "BOTTOM", 0, -m)
    else
      clip:SetPoint("LEFT", box, "LEFT", -m, 0); clip:SetPoint("RIGHT", box, "RIGHT", m, 0)
    end
  end
  -- Gate elements. The cell's extent is [P, X.farSide + farOffset] where X
  -- is the last bound element (a text, or a bar's fill texture); X's near
  -- edge is P (the texts are anchored at the holder's near edge with offset
  -- 0; the fill starts at the bar's near edge, an assumption checked by
  -- "/fa chainprobe fill"), so the spans hang from X alone (dev.53 topology).
  local far, farSide, farOffset = nil, s.far, 0  -- the frame and side whose edge ends the element's extent
  local timed = spec.duration or spec.remaining
  if timed then
    if not c.text then
      c.text = c.host:CreateFontString(nil, "ARTWORK")
      c.text:SetAlpha(0)
    end
    c.text:SetFont(STANDARD_TEXT_FONT, 12, "")
    c.text:SetWordWrap(false)
    c.text:SetWidth(0)
    c.text:SetJustifyH(s.near == "RIGHT" and "RIGHT" or "LEFT")
    c.text:ClearAllPoints()
    c.text:SetPoint(s.near, c.host, s.near, 0, 0)
    local formatter, ferr = Display.GateFormatter(timed.lower, timed.upper, Markup(calib.n, along))
    if not formatter then return false, "formatter: " .. tostring(ferr) end
    if not invisibleCurve then
      invisibleCurve = C_CurveUtil.CreateColorCurve()
      invisibleCurve:SetType(Enum.LuaCurveType.Step)
      invisibleCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
    end
    -- ForeverAuras (dev.55): a Remaining Time list's text follows the time
    -- left (RemainingDuration), a Total Duration filter's the total.
    local property = spec.remaining and Enum.DurationTextBindingProperty.RemainingDuration or Enum.DurationTextBindingProperty.TotalDuration
    ok, err = Try("duration text binding", button.SetDurationText, button, c.text, {
      textFormat = {formatString = "{}", components = {{property = property, formatter = formatter}}},
      textColor = {curve = invisibleCurve, property = property},
    })
    if not ok then return false, err end
    c.text:Show()
    far, farSide, farOffset = c.text, s.far, -bu
  elseif c.text then
    c.text:Hide()
  end
  -- ForeverAuras (dev.56): Stack Count <= n / = n: the button's bound COUNT
  -- text (SetApplicationCount) formatted to the cell's markup while the count
  -- is in the range and empty otherwise (and empty for an absent record):
  -- one target, no bar, no duration binding touched (a timed glow keeps its
  -- own). The ordinary exact gate's count text (StyleExactStackGate) is the
  -- model; the display's own %s text, if any, is handed its known count by
  -- the dispatcher (= n only; FlowChain keeps <= n at one spot then).
  if spec.count then
    if not c.count then
      c.count = c.host:CreateFontString(nil, "ARTWORK")
      c.count:SetAlpha(0)
      c.count:SetTextColor(0, 0, 0, 0)
    end
    c.count:SetFont(STANDARD_TEXT_FONT, 12, "")
    c.count:SetWordWrap(false)
    c.count:SetWidth(0)
    c.count:SetJustifyH(s.near == "RIGHT" and "RIGHT" or "LEFT")
    c.count:ClearAllPoints()
    c.count:SetPoint(s.near, c.host, s.near, 0, 0)
    local formatter, ferr = Display.GateFormatter(spec.count.lower, spec.count.upper, Markup(calib.n, along))
    if not formatter then return false, "formatter: " .. tostring(ferr) end
    ok, err = Try("application count binding", button.SetApplicationCount, button, c.count, {formatter = formatter})
    if not ok then return false, err end
    c.count:Show()
    far, farSide, farOffset = c.count, s.far, -bu
  elseif c.count then
    c.count:Hide()
  end
  -- ForeverAuras (dev.63): no bar cell any more (the >= cell is a count text
  -- too, FlowChain); a bar left by an earlier build of this record is hidden.
  if c.bar then c.bar:Hide() end
  -- Span 1: [X.near - L, X.far + delta + L] from the record's element X
  -- alone (the dev.53 single-target spine; the other spans and the next
  -- holder already hang from it: EnsureSpine). Anchored here, in the
  -- record's own callback, where X and the span are both writable.
  local z1 = c.spans[1]
  ok, err = Try("span to the cell's element", function()
    z1:ClearAllPoints()
    z1:SetPoint(s.near, far, s.near, Along(-Lu))
    z1:SetPoint(s.far, far, farSide, Along(farOffset + Lu))
  end)
  if not ok then return false, err end
  local point, pointSide, pointOffset = pos.point, pos.pointSide, pos.pointOffset
  c.point, c.pointSide, c.pointOffset = point, pointSide, pointOffset
  c.complete = true
  return true
end

-- The member's end: a frame of the display's size whose start corner is the
-- last record's cell point; followers hang from it (SetFlowEnd). Every
-- record of the batch must hold a complete link of the current construction
-- first (dev.40 review: only the last one was checked); the end's readiness
-- is dropped before it is placed again, so a refusal leaves no stale end.
-- Returns true, or false and why.
-- pending: a record the client's callback is still making (not in the
-- instance's list yet), counted as the last one.
function Display.FinishChain(region, instance, calib, pending)
  local native = region.blizzardAuraDisplay
  local flow = native and native.flow
  if not flow then return false, "no row" end
  flow.chainEndReady = nil
  if not calib then return false, "no calibration" end
  local records = instance.buttons
  if pending and records[#records] ~= pending then
    records = {}
    for k, record in ipairs(instance.buttons) do records[k] = record end
    records[#records + 1] = pending
  end
  local count = math.min(#records, CHAIN_RECORDS)
  for k = 1, count do
    local c = records[k].chain
    if not (c and c.complete and c.point) then return false, ("link %d incomplete"):format(k) end
  end
  -- ForeverAuras (dev.70): the end was wired to the last cell's point by the
  -- preparation (EnsureSpine), before any binding; nothing is written to it
  -- here. The cells are complete when every record of the batch holds its
  -- link; the end's position resolves once every cell is bound (the records
  -- fill the cells from the last back to the first).
  local s = calib.side
  if not (flow.chainEnd and flow.chainEndWired) then return false, "end: not prepared" end
  -- Whole: every current frame is placed by this construction, which is
  -- the one the frames hold from now on (chainBuilt: the bound of what a
  -- later refused attempt may leave drawn). A quiet display (an earlier
  -- refusal) stays quiet here: its cells are revealed by CompleteChain once
  -- the row has taken the end (dev.45 review: prepare, verify, then show);
  -- an apply's display is not quiet and its links showed their cells.
  native.chainBuilt = calib
  if not native.chainQuiet then native.chainReserve = nil end
  flow.chainEndReady, flow.chainCorner = true, s.corner
  return true
end

-- The quiet display's cells shown, once the row has taken its end: every
-- record of the batch (the incoming one included). Returns how many the
-- client refused (the caller rolls back on any).
function Display.RevealChain(instance, pending)
  local refused, seen = 0, {}
  local function Show(record)
    if seen[record] then return end
    seen[record] = true
    if record.gateClip and not pcall(record.gateClip.Show, record.gateClip) then refused = refused + 1 end
  end
  for k = 1, math.min(#(instance and instance.buttons or {}), CHAIN_RECORDS) do Show(instance.buttons[k]) end
  if pending then Show(pending) end
  return refused
end

---------------------------------------------------------------------------- failures and the editor
-- What the editor says about a chained display's state: the member's
-- warnings (one key each), published from the state the display holds, so
-- a finished apply and a later callback say the same thing:
--   blizzard_aura_chain_why   info: a gated list in an opted-in row that is
--                             not chained, and why (ChainProblem)
--   blizzard_aura_chain       warning: a refused link or end (the display
--                             keeps one spot until the paced re-apply, or
--                             for good once that is stopped)
--   blizzard_aura_chain_more  warning: records past the batch (hidden)
function Display.PublishChainWarnings(region, data)
  if not (Private.AuraWarnings and data and data.uid) then return end
  local native = region and region.blizzardAuraDisplay
  local spec = Display.FlowChain(data)
  local why = (not spec) and Display.ChainProblem(data) or nil
  Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_chain_why", why and "info" or nil, why)
  local problem, more
  if spec and native and native.data == data then
    local epoch = native.settingsEpoch or 0
    local record = native.reapplyRequests
    local failure = native.chainFailure
    local stopped = record and Display.ReapplyStopped and Display.ReapplyStopped(native)
    if stopped and not failure and native.flow and native.flow.chainEndReady then
      -- Whole after all (a later completion): drawn; only the automatic
      -- repair for these settings is used up (dev.44 review).
      problem = L["Row cells: this display is laid out; Blizzard refused it %d times for these settings, so no further automatic repair is made until its settings change or the interface is reloaded."]:format(record.count)
    elseif stopped then
      problem = L["Row cells: Blizzard refused %s %d times. This display keeps one spot in the row and shows nothing until its settings change or the interface is reloaded."]:format(tostring(failure and failure.what or record.why), record.count)
    elseif failure then
      problem = L["Row cells: Blizzard refused %s. This display keeps one spot in the row and shows nothing until it is laid out again."]:format(tostring(failure.what))
    end
    local quiet = native.chainQuiet
    if problem and quiet and (quiet.refused or 0) > 0 then
      problem = problem .. " " .. L["%d cell(s) could not be hidden, so the display reserves its full length meanwhile."]:format(quiet.refused)
    end
    local overflow = native.chainOverflow
    if overflow and overflow.epoch == epoch then
      more = L["Row cells: the game made %d more aura record(s) than the 10 this row lays out; they are hidden."]:format(overflow.records)
    end
  end
  Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_chain", problem and "warning" or nil, problem)
  Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_chain_more", more and "warning" or nil, more)
end

-- A refused link or end of a chained display. In a probe build (styleEarly)
-- the refusal is raised: the build's own accounting (the pcall around the
-- styling in Create and ApplyInstance) counts it and stops the build. In an
-- ordinary build it is counted where a finishing attempt listens
-- (NoteSlotFailure), remembered for the editor (native.chainFailure) and a
-- bounded, paced re-apply is asked for (Display.RequestReapply: under
-- restrictions their end, else the paced drain, at most twice per settings
-- epoch, then stopped with the warning). The display meanwhile keeps one
-- spot in the row (SetFlowEnd: no ready end).
-- A chain that is not whole draws nothing (dev.41 review): its complete
-- cells would otherwise stay visible while the member reserves one spot,
-- and the next member would be drawn over them. Every record's clip is
-- hidden; the display is marked quiet (native.chainQuiet) until an apply
-- completes the chain again, so a repaint of single records keeps them
-- hidden (StyleChainLink). Returns how many hides the client refused: those
-- cells may still be drawn, so the caller reserves the member's full length
-- instead of one spot (SetFlowEnd) until the re-apply (dev.42 review).
-- pending: a record the client's callback is still making (not in the list
-- yet), hidden with the rest (dev.44 review).
function Display.QuietChain(instance, pending, quiet)
  local refused, seen = 0, {}
  local function Hide(record)
    if seen[record] then return end   -- by identity: a record styled again is not counted twice
    seen[record] = true
    local hidden = not record.gateClip or pcall(record.gateClip.Hide, record.gateClip)
    if not hidden then refused = refused + 1 end
    if quiet then quiet.hides = quiet.hides or setmetatable({}, {__mode = "k"}); quiet.hides[record] = hidden end
  end
  for _, record in ipairs(instance and instance.buttons or {}) do Hide(record) end
  if pending then Hide(pending) end
  return refused
end

function Display.NoteChainFailure(region, instance, what, err, pending)
  local native = region and region.blizzardAuraDisplay
  local flow = native and native.flow
  if flow then flow.chainEndReady = nil end
  local text = (what == "end" and L["the member's end (%s)"] or what == "follower" and L["the next member's place (%s)"]
    or what == "start" and L["this display's place in the row (%s)"] or L["a row cell (%s)"]):format(tostring(err))
  -- (dev.80) said in chat with "/fa cells debug on", out of combat too (the editor's warning alone was not enough
  -- to see why a first load built a row wrong, Dan's dev.79 run)
  if Display.BuildReport and native and native.data then Display.BuildReport(("%s refused: %s"):format(tostring(native.data.id), text)) end
  if instance and instance.styleEarly then error(text, 0) end
  -- The CURRENT unresolved hides (dev.44 review): every record is asked to
  -- hide now; what the client refused may be drawn, an earlier refusal that
  -- succeeded this time is not. Recorded by record identity (quiet.hides),
  -- the same map a staged cell or a repaint writes (dev.48 review).
  local quiet = native and (native.chainQuiet or {}) or nil
  if quiet then quiet.hides = nil end
  local refused = Display.QuietChain(instance, pending, quiet)
  if native then
    quiet.refused = refused
    native.chainQuiet = quiet
    if refused > 0 then
      ReserveRefusedHides(native)
    else
      -- Every current frame is hidden: nothing of any construction is drawn.
      native.chainReserve = nil
    end
  end
  -- ForeverAuras (cell chain, dev.47 review): the finishing of a probe build
  -- (a first construction in combat), whether its chain pass ran at once or
  -- was held by a batch and decides now: the refusal is counted with the
  -- build's failures (finishing, kept open while the commit is held), which
  -- stop the build and set it aside to be made new when the restrictions
  -- end (FinishProbeBuild, SettleProbeCommit). The ordinary contract below
  -- (a kept display, one spot, the bounded paced repair) is not its.
  if native and native.probeBuild and instance and instance.finishing then
    if Display.NoteSlotFailure then Display.NoteSlotFailure(instance, "chain " .. tostring(what), err) end
    if not native.chainFailure then native.chainFailure = {what = text, epoch = native.settingsEpoch or 0} end
    return
  end
  -- (dev.68: a preparation refusal has no instance yet; nothing to count on one)
  if instance and Display.NoteSlotFailure then Display.NoteSlotFailure(instance, "chain " .. tostring(what), err) end
  -- The first refusal of an apply is the one worth reading (the end's follows from it).
  if native and not native.chainFailure then native.chainFailure = {what = text, epoch = native.settingsEpoch or 0} end
  if native and native.data then Display.PublishChainWarnings(region, native.data) end
  if Display.RequestReapply then Display.RequestReapply(region, text) end
end

-- ONE completion contract for every build (dev.43-46 reviews): an apply, a
-- probe build, a late record. The cells are staged (an unrestricted build
-- stages them quiet: StyleChainLink shows nothing while native.chainQuiet
-- is set; a probe build in combat shows them inline, where the records are
-- still writable), the end is prepared (FinishChain), the member asks the
-- row to take it (native.chainCommitPending, read by RechainFlow at the end
-- of its pass), and RechainFlow calls CommitChain for every member that
-- asked and took part in that pass: both placements this member depends on
-- are checked (its own start, flow.startPlaced; the next member's start on
-- its end, flow.followerPlaced), then a quiet display is revealed, then the
-- failure state and the repair are closed. A refusal is a failure like a
-- refused end: the records are quieted (the incoming one included), the
-- one-spot fallback published and the row chained once more (RechainFlow
-- runs its pass again), and the bounded paced repair stays. A chain pass
-- that is deferred to a batch (a load hold, a paced drain) leaves the
-- request pending and the display quiet until the flush's pass verifies it:
-- a healthy build is not failed for a layout that was merely held. A probe
-- build's finishing accounting and frame ownership stay open through such a
-- hold too (FinishProbeBuild; dev.47 review) and are settled by the pass
-- that decides (SettleProbeCommit: accepted, or stopped and set aside).
-- Returns true (committed), false (refused), nil (still pending).
function Display.CommitChain(region, instance, pending)
  local native = region and region.blizzardAuraDisplay
  if not native or not native.data then return false end
  local flow = native.flow
  local function Fail(what, why)
    native.chainFailure = nil -- the refusal that stands now is this one
    Display.NoteChainFailure(region, instance, what, why, pending)
    Display.SetFlowEnd(region, native.data, nil)
    native.chainCommitResult = false
    -- A probe build whose finishing waited for this pass is decided by its
    -- own accounting now (dev.47 review: stopped and set aside).
    if Display.SettleProbeCommit then Display.SettleProbeCommit(region) end
    return false
  end
  if not (flow and flow.chainEndReady) then return Fail("end", "the end is not in place") end
  if flow.startPlaced == false then return Fail("start", "this display's start frame refused its place") end
  if flow.followerPlaced == false then return Fail("follower", "the next member's start frame refused its place") end
  if native.chainQuiet then
    local refused = Display.RevealChain(instance, pending)
    if refused > 0 then return Fail("end", ("reveal: %d record(s) refused"):format(refused)) end
  end
  native.chainQuiet, native.chainReserve, native.chainFailure = nil, nil, nil
  if Display.ChainRepaired then Display.ChainRepaired(region) end
  Display.PublishChainWarnings(region, native.data)
  native.chainCommitResult = true
  -- A probe build whose finishing waited for this pass is accepted now
  -- (unless another refusal was counted meanwhile; dev.47 review).
  if Display.SettleProbeCommit then Display.SettleProbeCommit(region) end
  return true
end

-- Asks the row to take this member's prepared end and commit it (above).
-- Used by a late record (StyleDurationGate) and by FinishApply for every
-- build. Returns the commit's result, or nil while the chain pass is held.
function Display.CompleteChain(region, instance, pending)
  local native = region and region.blizzardAuraDisplay
  if not native or not native.data then return end
  local flow = native.flow
  if not (flow and flow.chainEndReady) then
    native.chainFailure = nil
    Display.NoteChainFailure(region, instance, "end", "the end is not in place", pending)
    Display.SetFlowEnd(region, native.data, nil)
    if Display.RechainFlow and Display.FlowGroup then Display.RechainFlow(Display.FlowGroup(native.data)) end
    return false
  end
  native.chainCommitPending, native.chainCommitResult = {instance = instance, pending = pending}, nil
  Display.SetFlowEnd(region, native.data, nil)
  local ran = Display.RechainFlow and Display.FlowGroup and Display.RechainFlow(Display.FlowGroup(native.data))
  if not ran or native.chainCommitPending then return nil end   -- held, or not in this pass: still pending and quiet
  return native.chainCommitResult
end

-- An 11th record in a chained list (the client grew the pool past the
-- batch the chain is bound to): its artwork is hidden and the editor says
-- so (PublishChainWarnings). No re-apply: the pool is the client's, and an
-- apply in place would restyle the same records (dev.40 review). A record
-- the client locked (restrictions) is hidden when they end, through the
-- pending relayout the restriction-end handler applies.
function Display.NoteChainOverflow(region, native)
  local owner = region.blizzardAuraDisplay
  local hidden = true
  if native.box then hidden = pcall(native.box.SetAlpha, native.box, 0) and hidden end
  local clipHidden = true
  if native.gateClip then clipHidden = pcall(native.gateClip.Hide, native.gateClip); hidden = clipHidden and hidden end
  -- ForeverAuras (cell chain, dev.49 review): a quiet display's record past
  -- the batch resolves or repeats its OWN refused hide here (a failure's
  -- QuietChain hid it too), like a staged cell does (NoteStagedHide).
  if owner and owner.chainQuiet and native.gateClip then NoteStagedHide(region, owner, native, clipHidden) end
  if owner then
    local epoch = owner.settingsEpoch or 0
    local record = owner.chainOverflow
    if not (record and record.epoch == epoch) then record = {epoch = epoch, records = 0, seen = setmetatable({}, {__mode = "k"})}; owner.chainOverflow = record end
    -- Distinct records: a restyle of the same record (RestyleButtons) is not
    -- another hidden record (dev.41 review).
    if not record.seen[native] then record.seen[native] = true; record.records = record.records + 1 end
    if owner.data then Display.PublishChainWarnings(region, owner.data) end
  end
  if not hidden and Display.NotePendingRelayout then Display.NotePendingRelayout(region) end
end


---------------------------------------------------------------------------- measurement chains
-- ForeverAuras (dev.74-78; Astra's Centered handoff, Dan's import freezes):
-- a MEASUREMENT CHAIN is the cell construction used for its length alone: its
-- own spine (EnsureSpine), hung from a base frame and grown in a chosen
-- direction, cells a step (or half a step) long, bound to the same texts
-- (a count text open for ANY aura, or the member's own gate) from a second
-- invisible native container with the member's filters, pinned to the
-- group's frame like every container of the row. Nothing of it is drawn: no
-- box, no clip. Its END is where the measured length ends.
-- Three uses:
--   the SHADOW of a member of a Centered row (half a step per open cell,
--     grown the shadows' way from the member's shadow start; a Missing
--     member's grows BACK from half a step beyond, so its end sits half a
--     step out while the aura is missing and on the shadow start while it is
--     present: the half-size copy of the member, SecretAuraFlow.lua);
--   the END of an ordinary Found list (a step per aura, grown the row's way
--     from the member's content), and of a Missing member (grown BACK from
--     one step beyond the content: one step out while missing, none while
--     present), in a row that chains cells. Dan's dev.77/78 imports froze
--     the client's layout engine (its own function 763 deep) whenever a
--     chain hung downstream of a native CONTAINER's edge (a Missing member's
--     presence container ahead of T): so in a row with cells no member's
--     end is a container's edge any more; it is a text measurement, as the
--     cells' own ends are.
-- No edge runs from a measurement chain back to what hangs from it: its
-- base hangs from the member's content or shadow start, which hang from the
-- row before it.
-- A measurement chain is its own owner (mc): chainSpine, chainCalib, flow
-- (chainEnd, chainEndWired, chainEndReady, chainCorner), buttons, base.
local MEASURE_GROUP = "FAMeasure"
local function Busy(frame) return InCombatLockdown() and frame.IsProtected ~= nil and frame:IsProtected() end
local ANY_AURA = {count = {lower = 0}}   -- a count text open for any aura (GateFormatter: open from zero)
local readyFlips, readyFlipsAt = 0, nil
local function MeasureReady(mc)
  local ready = #mc.buttons >= CHAIN_RECORDS and mc.flow.chainEndWired == true
  for k = 1, math.min(#mc.buttons, CHAIN_RECORDS) do
    local c = mc.buttons[k].chain
    if not (c and c.complete) then ready = false end
  end
  local was = mc.flow.chainEndReady
  mc.flow.chainEndReady = ready or nil
  if ready then mc.flow.chainCorner = mc.chainCalib.side.corner end
  -- completed (or undone) after the member's apply: the row's pass places
  -- what follows again from the new end
  if (mc.flow.chainEndReady or nil) ~= (was or nil) and not mc.applying and Display.QueueRechain then
    -- (dev.75 watchdog) a readiness that flips more than 50 times in one frame is a loop
    local now = GetTime()
    if readyFlipsAt ~= now then readyFlipsAt, readyFlips = now, 0 end
    readyFlips = readyFlips + 1
    if readyFlips > 50 then error("ForeverAuras watchdog: the measurement chain of " .. tostring(mc.data and mc.data.id) .. " changed readiness " .. readyFlips .. " times in one frame") end
    Display.QueueRechain(mc.region)
  end
  return ready
end
local function MeasureStyle(mc, n)
  local ok, err = Display.StyleChainLink(n, mc.region, mc.data, mc.spec, mc.chainCalib)
  if not ok then mc.failed = (mc.failed or 0) + 1; mc.failure = err end
  return ok
end
local function MeasureRecord(mc, button)
  -- a button the client offers again keeps its record; a pool past twice
  -- the batch is a runaway and is reported, not styled (dev.75 watchdog)
  for _, existing in ipairs(mc.buttons) do
    if existing.button == button then MeasureStyle(mc, existing); MeasureReady(mc); return end
  end
  -- (dev.79) an exception in a record's styling is that record's failure, counted, never swallowed
  local okR, errR = pcall(function()
  if #mc.buttons >= 2 * CHAIN_RECORDS then error("ForeverAuras watchdog: the measurement chain of " .. tostring(mc.data and mc.data.id) .. " was offered more than " .. (2 * CHAIN_RECORDS) .. " records") end
  local n = {button = button, record = #mc.buttons + 1, owner = mc, measure = true}
  mc.buttons[#mc.buttons + 1] = n
  pcall(button.SetAlpha, button, 0)
  pcall(button.EnableMouse, button, false)
  MeasureStyle(mc, n)
  end)
  if not okR then mc.failed = (mc.failed or 0) + 1; mc.failure = tostring(errR) end
  MeasureReady(mc)
end
-- opts: shadow (the shadows' direction and half a step), reverse (grown
-- back from a base one length beyond), filter, candidates, spec (default:
-- any aura), anchor/anchorPoint and length (units; the base sits length
-- along the chosen direction's opposite... i.e. where the chain starts: for
-- a reversed chain one length beyond the anchor), slot (flow key: the
-- chain's owner table), containerKey (the instance key of its container).
-- Returns true, or nil and why; a failed measurement leaves no chain end
-- (its users fall back: a fixed spot in the shadows, the container's edge).
function Display.EnsureMeasureChain(region, data, native, instance, opts)
  local function RestrictedNow() return InCombatLockdown() or (C_Secrets and C_Secrets.ShouldAurasBeSecret()) end
  local function Forbidden(frame) return frame ~= nil and Display.Locked ~= nil and Display.Locked(frame) end
  local flow = native.flow
  if not (flow and instance) then return nil, "no row state" end
  local mc = flow[opts.slot]
  if not mc then mc = {flow = {}, buttons = {}}; flow[opts.slot] = mc end
  mc.region, mc.data, mc.spec, mc.applying = region, data, opts.spec or ANY_AURA, true
  mc.failed, mc.failure = nil, nil
  local function Fail(why) mc.applying = nil; mc.flow.chainEndReady = nil; return nil, why end
  -- the geometry: the member's own measured calibration where there is one
  -- (its numbers reused, q doubled for a half-step chain), else measured now
  local okC, calib, why = pcall(Display.ChainCalibrate, region, data, native, {shadow = opts.shadow, reverse = opts.reverse, half = opts.shadow, from = opts.from})
  if not okC then return Fail("measurement calibration: " .. tostring(calib)) end
  if not calib then return Fail("measurement calibration: " .. tostring(why)) end
  -- the base: the frame the chain hangs from. A LOCAL chain (opts.localChain) is
  -- measured at the group's pin, a fixed place, and only its END is
  -- translated to where the member's measurement belongs (the carriers'
  -- translation, Display.TranslatePoint: out = anchor + (end - pin)), so the
  -- deep measuring spine never hangs downstream of the row (dev.79, Astra's
  -- dev.77 review: the client's layout walk is capped at 500 deep and
  -- revisits duplicate entries). Otherwise the base sits at the anchor. A
  -- reversed chain's base sits one length beyond, the way the member grows
  -- (the opposite of this chain's growth): its end then comes BACK by the
  -- open cells.
  if not mc.base then
    mc.base = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
    mc.base:EnableMouse(false)
    mc.base:SetSize(1, 1)
  end
  local s = calib.side
  local pin = Display.CarrierPin and Display.CarrierPin(data)
  local baseFrame, basePoint = opts.anchor, opts.anchorPoint or s.corner
  if opts.localChain then
    if not pin then return Fail("no group frame to measure at") end
    baseFrame, basePoint = pin, "TOPLEFT"
  end
  -- ForeverAuras (dev.82): a chain prepared under restrictions without its
  -- records (opts.defer below) and now asked for them with the same geometry
  -- keeps its base, spine and translation as they are: nothing is written
  -- again (the base and the helpers may hang from ends bound meanwhile), only
  -- the container is made.
  calib.content = mc.base
  -- (dev.84, Dan's combat freeze) likewise under restrictions any chain of
  -- this geometry that is whole already is kept as it is: a rewrite would
  -- clear its base, spine and translation first and might not be allowed to
  -- anchor them again (a forbidden shadow start), leaving the row hanging
  -- from an unresolved end.
  local intact = mc.scaffoldOn == baseFrame and SpineCurrent(mc.chainSpine, region, calib, mc)
    and (not opts.localChain or (mc.out ~= nil and mc.outCorner == s.corner and mc.outOn == opts.anchor))
  local prepared = intact and ((mc.scaffold and not opts.defer) or RestrictedNow())
  if prepared then mc.chainCalib = calib end
  -- (dev.84) and a chain that must be written under restrictions checks its
  -- targets first: a forbidden one means the writes would be refused part
  -- way, so none is made (the measurement then reports as not made)
  -- (dev.89, Astra's dev.88 review: a target may stay forbidden through a spell out of restrictions, so the
  -- checks do not depend on them)
  if not prepared then
    if Forbidden(baseFrame) then return Fail("measurement base: the frame it hangs from is forbidden under restrictions") end
    if Forbidden(mc.base) then return Fail("measurement base: forbidden under restrictions") end
    if opts.localChain and Forbidden(opts.anchor) then return Fail("measurement translation: the member's start is forbidden under restrictions") end
    if mc.helpers then for _, f in pairs(mc.helpers) do if Forbidden(f) then return Fail("measurement translation: a helper is forbidden under restrictions") end end end
    if Forbidden(mc.out) then return Fail("measurement translation: the end is forbidden under restrictions") end
  end
  -- (dev.87, Astra's dev.85 review) an explicit branch, so a refusal keeps its
  -- cause; and the base's anchors are remembered and put back on a refusal
  -- (the chain's spine and its published end hang from the base)
  -- (dev.89, Astra's dev.88 review P1) non-destructive: the base's anchor is
  -- written on the same point (replaced in one write, nothing cleared); a base
  -- that carried another corner (the chain grows another way now) is retired as
  -- it is and a fresh one made, so the spine hanging from the old one stays
  -- resolvable until it is rewritten onto the new base
  local okB, errB = true, nil
  if not prepared then
    if mc.baseCorner and mc.baseCorner ~= s.corner then
      pcall(mc.base.Hide, mc.base)
      mc.base = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate")
      mc.base:EnableMouse(false)
      mc.base:SetSize(1, 1)
      calib.content = mc.base
      if mc.chainSpine then mc.chainSpine.key = nil end
    end
    okB, errB = pcall(function()
      local dx, dy = 0, 0
      if opts.reverse then
        -- one whole step (half a step for a half-step chain): the absent aura's spot lands on the pixel grid;
        -- the open cell comes back by that plus its residual share (under half a pixel)
        local length = calib.Fpx / calib.q / calib.px
        dx, dy = -calib.g.sign[1] * length, -calib.g.sign[2] * length
      end
      mc.base:SetPoint(s.corner, baseFrame, basePoint, dx, dy)
      mc.base:Show()
    end)
    if okB then mc.baseCorner = s.corner end
  end
  if not okB then return Fail("measurement base: " .. tostring(errB)) end
  mc.chainCalib = calib
  mc.scaffoldOn = baseFrame
  local spine, err = EnsureSpine(mc, region, calib, data)
  if not spine then return Fail("measurement spine: " .. tostring(err)) end
  -- a local chain's end translated to the anchor: out = anchor + (end - pin)
  if opts.localChain and not prepared then
    -- (dev.89) the translated end carries one point (the corner): another corner means fresh helpers and a
    -- fresh end, the old ones retired as they are (what hangs from the old end stays resolvable)
    if mc.helpers and mc.outCorner and mc.outCorner ~= s.corner then
      pcall(mc.out.Hide, mc.out)
      mc.helpers, mc.out = nil, nil
    end
    if not mc.helpers then
      local h, p2, out = {}, nil, nil
      for _, key in ipairs({"h", "p"}) do
        local f = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate"); f:EnableMouse(false); h[key] = f
      end
      out = CreateFrame("Frame", nil, region, "DisableUntrustedLayoutScriptsTemplate"); out:EnableMouse(false); out:SetSize(1, 1)
      mc.helpers, mc.out = h, out
    end
    local group = Display.FlowGroup(data)
    local M = OutputPadding(data, calib)
    local corner = s.corner
    local okT, step, errT = Display.TranslatePoint(mc.helpers, opts.anchor, opts.anchorPoint or corner, mc.flow.chainEnd, corner, pin, M, mc.out, corner)
    if not okT then return Fail("measurement translation (" .. tostring(step) .. "): " .. tostring(errT)) end
    mc.out:Show()
    mc.outCorner, mc.outOn, mc.outputPadding = corner, opts.anchor, M
    mc.localOutput = {pin = pin, corner = corner, anchorPoint = opts.anchorPoint or corner}
  end
  -- the next member's start on this chain's end, before any record binds
  -- (as a chained member's follower, PrewireFollower)
  if opts.prewire and Display.PrewireFollower and not prepared then
    local okP, okF, whyF = pcall(Display.PrewireFollower, region, data, mc)
    if not okP then return Fail("measurement follower: " .. tostring(okF)) end
    if not okF then return Fail("measurement follower: " .. tostring(whyF)) end
  end
  -- ForeverAuras (dev.82): a DEFERRED chain stops here, prepared but without
  -- its container: nothing of it is bound, so every frame that will hang from
  -- its end (the next shadow's start, the visible row's start) can still be
  -- anchored there. The records come with a later call without opts.defer
  -- (ActivateShadows, SecretAuraFlow.lua: once the whole row is in place).
  if opts.defer then
    -- (dev.84) a chain kept whole under restrictions, container and records
    -- with it, is bound already: it is not a scaffold (nothing to bind later)
    local bound = instance[opts.containerKey]
    if prepared and bound and bound.faMeasureChain == mc and #mc.buttons >= CHAIN_RECORDS and not mc.scaffold then
      MeasureReady(mc)
      mc.applying = nil
      return true
    end
    mc.scaffold = true
    mc.flow.chainEndReady = nil
    mc.applying = nil
    return true, "deferred"
  end
  -- the container: the member's filters and candidates, one batch of records
  -- (every record of the pool is made, bound or not: the empties take no space)
  local container = instance[opts.containerKey]
  if container and container.faMeasureChain ~= mc then
    if not Busy(container) then container:SetEnabled(false); container:Hide() end
    container = nil
  end
  -- (dev.84) a chain kept as it is under restrictions, with its container and records: nothing to restyle
  -- (the records are locked; their cells are bound already)
  if prepared and RestrictedNow() and container and #mc.buttons >= CHAIN_RECORDS and not mc.scaffold then
    instance[opts.containerKey], instance[opts.containerKey .. "Active"] = container, true
    MeasureReady(mc)
    mc.applying = nil
    return true
  end
  if not container then
    -- (dev.79, Astra's dev.76 review) owned the moment it is allocated, the whole setup protected: a refusal
    -- anywhere leaves the container owned (retired) and the chain not applying
    -- (dev.84, Astra's dev.83 review P2) the allocation itself under the same protection; a prepared chain
    -- (scaffold) stays prepared until its container is made
    local okA, made = pcall(Display.CreateAuraContainer, region, data)
    if not okA then return Fail("the measurement container: " .. tostring(made)) end
    instance[opts.containerKey], instance[opts.containerKey .. "Active"] = made, false
    made.faMeasureChain = mc
    mc.buttons = {}
    local okS, errS = pcall(function()
      made:SetEnabled(false)
      made:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
      -- pinned to the group's frame like the member's own container (AnchorToContent): a place no measurement moves
      made:SetPoint("TOPLEFT", pin or region, "TOPLEFT")
      made:AddAuraGroup(MEASURE_GROUP, opts.filter, {
        candidateFilters = opts.candidates, maxFrameCount = CHAIN_RECORDS,
        layout = {elementWidth = 1, elementHeight = 1, elementSpacing = 0},
        initializeFrame = function(button) MeasureRecord(mc, button) end,
      })
    end)
    if not okS then
      pcall(made.Hide, made); Display.RetireFrame(made)
      instance[opts.containerKey] = nil
      return Fail("the measurement container: " .. tostring(errS))
    end
    container = made
  else
    container:SetAuraGroupFilterString(MEASURE_GROUP, opts.filter)
    container:SetAuraGroupCandidateFilters(MEASURE_GROUP, opts.candidates)
    container:SetAuraGroupMaxFrameCount(MEASURE_GROUP, CHAIN_RECORDS)
    container:SetAuraGroupEnabled(MEASURE_GROUP, true)
    -- records made before are styled into the (possibly rebuilt) spine again
    for _, n in ipairs(mc.buttons) do MeasureStyle(mc, n) end
  end
  instance[opts.containerKey], instance[opts.containerKey .. "Active"] = container, true
  mc.scaffold = nil
  MeasureReady(mc)
  mc.applying = nil
  -- (dev.79, Astra's dev.77 review) a measurement whose records refused is no
  -- measurement: reported as such (its users fall back), never as a success
  if mc.failed then return nil, "measurement records: " .. tostring(mc.failure) end
  return true
end
-- A measurement chain let go (its spine unanchored, its base hidden; the
-- container stays with the instance, disabled by its owner).
function Display.ReleaseMeasureChain(mc)
  if not mc then return end
  Display.ReleaseChainSpine(mc)
  mc.flow.chainEndReady, mc.scaffold = nil, nil
  -- (dev.84) under restrictions the base stays anchored too (ReleaseChainSpine)
  if mc.base then pcall(mc.base.Hide, mc.base) end
end

-- The member's filter, candidates and (for the Centered shadow) kind: what
-- a measurement chain of this member binds. nil when the member measures
-- nothing this way (a chained member's own end is its chain; a single icon
-- shown always is one fixed step; lists past the batch keep the container).
-- Returns filter, candidates, reverse (a Missing member: present = open,
-- measured back), spec.
function Display.MeasureFilters(data, native)
  local trigger = Display.GetTrigger(data)
  if not trigger then return nil end
  local showOn = Display.ShowOn(trigger)
  local filter, candidates = Display.FilterString(trigger), Display.CandidateFilters(data)
  if showOn == "showOnMissing" then return filter, candidates, true, ANY_AURA end
  if showOn == "showOnActive" and not Display.UsesGate(data) and Display.MaxAuras(data) <= CHAIN_RECORDS then return filter, candidates, false, ANY_AURA end
  return nil
end

-- Called by EnsureFlowShadows for a member of a Centered row: the member's
-- shadow as a measurement chain. Returns true, or nil and why (the member
-- then keeps a fixed spot in the shadows: one half step).
-- activate (dev.82): bind the records of a shadow prepared under restrictions
-- (ActivateShadows); otherwise, under restrictions, the shadow is prepared
-- WITHOUT its records (opts.defer): the row's pass then wires the shadows
-- and the visible start to ends that depend on nothing yet, and the records
-- come once the whole row is in place. Bound during the member's own build,
-- as out of restrictions, the shadows' ends were secret before the start
-- could be placed on them, and the row sat a few cells from the centre
-- (Dan's dev.81 combat reload: no refusal line, the placement a quiet no-op).
function Display.EnsureChainShadow(region, data, native, instance, activate)
  -- "/fa cells shadows off": no shadow chains (a diagnostic switch)
  if type(ForeverAurasSaved) == "table" and ForeverAurasSaved.rowCellsNoShadowChains then return nil, "off" end
  -- (dev.82, Astra's dev.81 review) "/fa cells off" turns the measurements off with the cells
  if not Display.ChainEnabled() then return nil, "off" end
  -- (dev.81) only a row that opted into the cells (the independent-carriers row, FlowIndependentGroup): every other
  -- Centered row keeps its container shadows (dev.79 measured them all, outside the experiment's scope)
  local group = Display.FlowGroup and Display.FlowGroup(data)
  if not (group and Display.FlowIndependentGroup and Display.FlowIndependentGroup(group)) then return nil, "off" end
  local flow = native.flow
  local sh = flow and flow.growth and flow.growth.shadow
  if not (sh and flow.shadowStart and instance) then return nil, "no shadow start" end
  local spec = Display.FlowChain(data)
  local filter, candidates, reverse, from
  if spec then
    local trigger = Display.GetTrigger(data)
    filter, candidates, reverse, from = Display.FilterString(trigger), Display.CandidateFilters(data), false, native.chainCalib
  else
    filter, candidates, reverse, spec = Display.MeasureFilters(data, native)
    if not filter then return nil, "nothing to measure" end
    from = flow.measureChain and flow.measureChain.chainCalib
  end
  -- half a step per open cell, measured LOCALLY at the group's pin and its
  -- end translated to the shadow start (the shadows' sequence then holds
  -- one translation per member, not every member's cells)
  return Display.EnsureMeasureChain(region, data, native, instance, {
    shadow = true, reverse = reverse, filter = filter, candidates = candidates, spec = spec, from = from, localChain = true,
    anchor = flow.shadowStart, anchorPoint = sh.start,
    slot = "shadowChain", containerKey = "flowShadow",
    defer = (not activate) and InCombatLockdown() or nil,
  })
end
-- Whether this member's shadow is prepared but not yet bound (dev.82).
function Display.ShadowDeferred(native)
  local sc = native and native.flow and native.flow.shadowChain
  return sc ~= nil and sc.scaffold == true
end

-- Called by FinishApply (BlizzardAuraDisplay.lua) before the member's end is
-- recorded: an ordinary member of a row with cells marks its END with a
-- measurement chain (SetFlowEnd takes it over the container's edge).
function Display.EnsureFlowMeasure(region, data, native)
  local flow = native and native.flow
  local instance = native and native.instances and native.instances[1]
  local group = Display.FlowGroup and Display.FlowGroup(data)
  local wanted = flow and instance and group and Display.FlowGroupOwned(group) and Display.FlowIndependentGroup and Display.FlowIndependentGroup(group)
    and Display.ChainEnabled()   -- ForeverAuras (dev.82, Astra's dev.81 review): "/fa cells off" turns the end measurements off too
    and not (Display.FlowChain and Display.FlowChain(data))
  local filter, candidates, reverse, spec
  if wanted then filter, candidates, reverse, spec = Display.MeasureFilters(data, native) end
  if not filter then
    if flow and flow.measureChain then Display.ReleaseMeasureChain(flow.measureChain) end
    if instance and instance.flowMeasure and not Busy(instance.flowMeasure) then instance.flowMeasure:SetEnabled(false); instance.flowMeasure:Hide(); instance.flowMeasureActive = false end
    return nil
  end
  local g = flow.growth
  local content = Display.ContentAnchor(region)
  local made, why = Display.EnsureMeasureChain(region, data, native, instance, {
    reverse = reverse, filter = filter, candidates = candidates, spec = spec, from = flow.measureChain and flow.measureChain.chainCalib,
    anchor = content, anchorPoint = g.start,
    slot = "measureChain", containerKey = "flowMeasure", prewire = true, localChain = true,
  })
  if Display.BuildReport then
    local mc = flow.measureChain
    if made then Display.BuildReport(("%s measures its end: %d records, end %s"):format(tostring(data.id), mc and #mc.buttons or 0, (mc and mc.flow.chainEndReady) and "ready" or "NOT ready"))
    else Display.BuildReport(("%s could not measure its end (%s); its container's edge is its end"):format(tostring(data.id), tostring(why))) end
  end
  return made, why
end
-- Whether this member's end is a measurement chain (the restricted drain
-- orders such members like chained ones: whole before the member before
-- them binds).
function Display.MeasuresEnd(data)
  local group = Display.FlowGroup and Display.FlowGroup(data)
  if not (group and Display.FlowGroupOwned(group) and Display.FlowIndependentGroup and Display.FlowIndependentGroup(group)) then return false end
  if not Display.ChainEnabled() then return false end   -- ForeverAuras (dev.82): with the cells off nothing measures
  if Display.FlowChain and Display.FlowChain(data) then return false end
  return Display.MeasureFilters(data) ~= nil
end
