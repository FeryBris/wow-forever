-- Hides parts of the client's own interface: the bag bar, the micro menu and
-- five pieces of the minimap, always or by the mouse.
--
-- CF6.5 and CF6.6 on CurseForge, settled with the owner on 2026-10-17: three
-- ways for each piece, shown, hidden, and shown only while the mouse is over
-- its place. A fourth, hidden while the mouse is over it, the comment's own
-- words, was built the same day and taken out again on 2026-10-18 at the
-- owner's word. **Everything shown by default**, so nothing changes until a
-- player picks.
--
-- **By alpha, never by Hide or a new parent.** The client shows, hides and
-- moves these frames itself, Edit Mode places two of them, and the micro menu
-- goes to the vehicle bar and back; an alpha of ours sits on top of all that
-- and is never undone by it. Nothing here calls the client's Lua: alpha and
-- mouse are the frames' own widget methods, which write no Lua state. Every
-- frame was read in the client's interface code for build 70425, and none is
-- protected there; a frame that is anyway is left alone in combat, see Mouse.
--
-- **A hidden piece takes no clicks**, so nothing invisible catches the mouse:
-- its buttons give their mouse up while hidden and get it back when shown.
-- Shown only under the mouse keeps the mouse, since it is drawn the moment
-- the pointer reaches it, before any click can land.
--
-- **The mouse is judged by the place, not the picture**: IsMouseOver measures
-- a frame's rectangle whether it is drawn or not, so a piece that is not drawn
-- still knows the moment the pointer reaches its place.
--
-- While Edit Mode is open everything shows, so it can be found and moved.

local ADDON, FP = ...
local L = FP.L

local MODES = {
    { "show",  L["Shown"] },
    { "hide",  L["Hidden"] },
    { "hover", L["Shown on hover"] },
}

-- [mode] = true for each of the modes above; anything else stored is shown.
local KNOWN = {}
for _, mode in ipairs(MODES) do KNOWN[mode[1]] = true end

local DESC = L["Shown, hidden, or shown only while the mouse is over its "
    .. "place. A hidden piece takes no clicks."]

local function Cluster(key)
    local cluster = rawget(_G, "MinimapCluster")
    return type(cluster) == "table" and cluster[key] or nil
end

-- The pieces, by the names this client gives them. The clock belongs to code
-- the client loads by itself after login, so every name is asked anew.
local TARGETS = {
    { key = "bags",     label = L["Bag bar"],
      frame = function() return rawget(_G, "BagsBar") end },
    { key = "micro",    label = L["Micro menu"],
      frame = function() return rawget(_G, "MicroMenuContainer") end },
    { key = "tracking", label = L["Minimap tracking"],
      frame = function() return Cluster("Tracking") end },
    { key = "zone",     label = L["Minimap zone name"],
      frame = function() return Cluster("ZoneTextButton") end },
    { key = "clock",    label = L["Minimap clock"],
      frame = function() return rawget(_G, "TimeManagerClockButton") end },
    { key = "calendar", label = L["Minimap calendar"],
      frame = function() return rawget(_G, "GameTimeFrame") end },
    { key = "addons",   label = L["Minimap addon button"],
      frame = function() return rawget(_G, "AddonCompartmentFrame") end },
}

local options = {}
for _, target in ipairs(TARGETS) do
    options[#options + 1] = { key = target.key, type = "select", default = "show",
        label = target.label, values = MODES, desc = DESC }
end

local M = FP:RegisterModule("HideElements", {
    title   = L["Hide Interface Elements"],
    default = true,
    desc    = L["Hides the bag bar, the micro menu and parts of the minimap, "
           .. "always or depending on the mouse."],
    group   = "display",
    order   = 38,
    options = options,
})

-- [frame] = the alpha it had before this file touched it.
local alphas = {}
-- [frame] = true for every frame whose mouse this file took away.
local muted = {}
-- [piece] = whether its frames have their mouse, as last set here, so the
-- frames under a piece are walked only when that changes.
local mouseOf = {}

local function Fighting()
    return InCombatLockdown and InCombatLockdown()
end

--- Sets a piece's alpha, remembering what it had first.
local function Alpha(frame, alpha)
    if alphas[frame] == nil then
        local ok, was = pcall(frame.GetAlpha, frame)
        alphas[frame] = (ok and tonumber(was)) or 1
    end
    local ok, now = pcall(frame.GetAlpha, frame)
    if not (ok and now == alpha) then pcall(frame.SetAlpha, frame, alpha) end
end

--- Every frame under a piece, the piece included.
local function Each(frame, fn)
    fn(frame)
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do Each(child, fn) end
end

--- Takes the mouse from a piece's frames, or gives it back. A protected
--- frame is left as it is in combat, where changing it is refused.
local function Mouse(root, on)
    if mouseOf[root] == on then return end
    local skipped = false
    Each(root, function(frame)
        local protected = frame.IsProtected and select(2, pcall(frame.IsProtected, frame))
        if protected == true and Fighting() then
            skipped = true
            return
        end
        if on then
            if muted[frame] then
                pcall(frame.EnableMouse, frame, true)
                muted[frame] = nil
            end
        elseif not muted[frame] then
            local ok, enabled = pcall(frame.IsMouseEnabled, frame)
            if ok and enabled == true then
                pcall(frame.EnableMouse, frame, false)
                muted[frame] = true
            end
        end
    end)
    -- Asked again next time when a frame had to wait for the fight's end.
    mouseOf[root] = (not skipped) and on or nil
end

local function EditModeOpen()
    local manager = rawget(_G, "EditModeManagerFrame")
    if type(manager) ~= "table" then return false end
    local ok, shown = pcall(manager.IsShown, manager)
    return ok and shown == true
end

--- Shown or not, by the piece's mode and where the mouse is.
local function Wanted(mode, frame)
    if mode == "hide" then return false end
    if mode == "hover" then
        local ok, over = pcall(frame.IsMouseOver, frame)
        return ok and over == true
    end
    return true
end

--- A mode this file no longer offers, the fourth one of 2026-10-17 above
--- all, goes back to shown, so the page never shows a value it cannot set.
local function Normalize(db)
    for _, target in ipairs(TARGETS) do
        local mode = db[target.key]
        if mode ~= nil and not KNOWN[mode] then db[target.key] = "show" end
    end
end

--- Puts every piece into the state its mode asks for, now.
function M:Update()
    local editing = EditModeOpen()
    for _, target in ipairs(TARGETS) do
        local frame = target.frame()
        local mode = self.db[target.key] or "show"
        if type(frame) == "table" then
            if mode == "show" or editing then
                if alphas[frame] ~= nil then
                    Alpha(frame, alphas[frame])
                    Mouse(frame, true)
                end
            else
                local shown = Wanted(mode, frame)
                Alpha(frame, shown and (alphas[frame] or 1) or 0)
                -- Shown only under the mouse keeps the mouse, see the top.
                Mouse(frame, shown or mode == "hover")
            end
        end
    end
end

--- Gives every piece its own alpha and mouse back.
function M:RestoreAll()
    for frame, alpha in pairs(alphas) do pcall(frame.SetAlpha, frame, alpha) end
    wipe(alphas)
    wipe(mouseOf)
    for frame in pairs(muted) do
        local protected = frame.IsProtected and select(2, pcall(frame.IsProtected, frame))
        if not (protected == true and Fighting()) then
            pcall(frame.EnableMouse, frame, true)
            muted[frame] = nil
        end
    end
    -- A protected frame still without its mouse gets it after the fight.
    if next(muted) then
        FP:OutOfCombat("Hide elements back", function()
            for frame in pairs(muted) do pcall(frame.EnableMouse, frame, true) end
            wipe(muted)
        end)
    end
end

--- Whether any piece asks for anything but shown, which is when the mouse
--- has to be watched at all.
local function AnyChosen()
    for _, target in ipairs(TARGETS) do
        if (M.db[target.key] or "show") ~= "show" then return true end
    end
    return false
end

function M:OnEnable()
    Normalize(self.db)
    self.ticker = self.ticker or CreateFrame("Frame")
    -- Every frame rather than on a timer: shown under the mouse has to be
    -- drawn before a click can land, see the top.
    self.ticker:SetScript("OnUpdate", function()
        FP:Safe("HideElements:Update", M.Update, M)
    end)
    self.ticker:SetShown(AnyChosen())
    self:Update()
end

function M:OnDisable()
    if self.ticker then self.ticker:Hide() end
    self:RestoreAll()
end

--- A mode changed: watch the mouse only while some piece needs it, and put
--- a piece set back to shown as it was at once.
function M:Reapply()
    Normalize(self.db)
    if self.ticker then self.ticker:SetShown(AnyChosen()) end
    self:Update()
end
