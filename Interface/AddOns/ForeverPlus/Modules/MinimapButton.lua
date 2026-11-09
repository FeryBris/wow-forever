-- A button on the edge of the minimap that opens the settings window.
--
-- Asked for on CurseForge on 2026-09-28 by a player who would rather click than
-- type /fplus. They suggested it start switched off, so that nothing changes for
-- anybody who did not ask. **The owner decided the other way: on by default**,
-- and the switch on the Gameplay page turns it off.
--
-- A click does exactly what /fplus does, through the same function, so the two
-- can never drift apart: see FP:ToggleSettings in Core/Commands.lua.
--
-- Built by hand like everything else here, with no library and no Blizzard
-- template. The ring, the round backdrop and the highlight are the client's own
-- minimap art, the files minimap buttons have worn since the original game;
-- this client's minimap code uses the highlight itself. The picture is the
-- addon's icon from the TOC, cut round to sit inside the ring.
--
-- **Round, because this client's minimap is round.** Read in Blizzard's
-- interface code for this build: the map is 198 units wide under a circular
-- mask, and its zoom buttons sit at the bottom right. So the button starts at
-- the bottom left, and a drag moves it along the edge rather than anywhere on
-- the screen, where it could be lost off the side. An addon that squares the
-- minimap would want the corners followed; that is not built until somebody
-- runs one.
--
-- Parented to the minimap, so Edit Mode moving or scaling the map takes the
-- button along without this file knowing about it.

local ADDON, FP = ...
local L = FP.L

-- Degrees, counterclockwise from the right, which is how the arithmetic below
-- counts. 225 is the bottom left.
local DEFAULT_ANGLE = 225

local M = FP:RegisterModule("MinimapButton", {
    title   = L["Minimap Button"],
    default = true,
    desc    = L["A button on the edge of the minimap that opens this window. "
           .. "Drag it to move it along the edge."],
    group   = "display",
    order   = 40,
    options = {
        { key = "angle", type = "store", default = DEFAULT_ANGLE },
    },
})

local SIZE    = 31   -- the button, which is what the pointer hits
local RING    = 50   -- the ring art is drawn larger than its button, from the top left
local BACK    = 24   -- the dark disc behind the picture
local ICON    = 18   -- the picture, inside the ring's opening
local OUTSIDE = 5    -- how far past the map's edge the button's centre sits

local button

--- Where the button sits, from the stored angle.
local function Place()
    local minimap = _G.Minimap
    if not (button and minimap) then return end

    local angle  = math.rad(tonumber(M.db.angle) or DEFAULT_ANGLE)
    local radius = minimap:GetWidth() / 2 + OUTSIDE
    button:ClearAllPoints()
    button:SetPoint("CENTER", minimap, "CENTER",
        math.cos(angle) * radius, math.sin(angle) * radius)
end

--- While dragging: the angle from the map's centre to the pointer.
--
-- In the minimap's own units, because the map carries a scale of its own and
-- the pointer is reported in the screen's.
local function FollowCursor()
    local minimap = _G.Minimap
    local cx, cy = minimap:GetCenter()
    if not cx then return end

    local scale = minimap:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    M.db.angle = math.deg(math.atan2(y - cy, x - cx)) % 360
    Place()
end

--- Above the button or below it, whichever side has the screen's room.
local function TipSide(frame)
    local _, y = frame:GetCenter()
    if not y then return "BOTTOM" end
    local screen = UIParent:GetHeight() * UIParent:GetEffectiveScale()
    return (y * frame:GetEffectiveScale() > screen / 2) and "BOTTOM" or "TOP"
end

local function ShowTip(frame)
    FP:ShowTip(frame, {
        "ForeverPlus",
        L["Click to open or close the settings."],
        L["Drag to move this button along the edge of the minimap."],
    }, TipSide(frame))
end

--- Builds the button, once. Nil when this client has no minimap to put it on.
local function Build()
    if button then return button end
    local minimap = _G.Minimap
    if not minimap then return nil end

    local b = CreateFrame("Button", "ForeverPlusMinimapButton", minimap)
    b:SetSize(SIZE, SIZE)
    -- Above the map's own frame art, which is drawn by the minimap's children
    -- as well. Fixed, so a parent that changes its level cannot bury it.
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    if b.SetFixedFrameStrata then b:SetFixedFrameStrata(true) end
    if b.SetFixedFrameLevel then b:SetFixedFrameLevel(true) end
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")

    local back = b:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    back:SetSize(BACK, BACK)
    back:SetPoint("CENTER")

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(FP:AddonIcon() or FP.FALLBACK_ICON)
    icon:SetSize(ICON, ICON)
    icon:SetPoint("CENTER")
    -- Round, or the corners of a square picture poke out from under the ring.
    if b.CreateMaskTexture and icon.AddMaskTexture then
        local mask = b:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    b.icon = icon

    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(RING, RING)
    ring:SetPoint("TOPLEFT")

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b:SetScript("OnClick", function() FP:ToggleSettings() end)

    -- The picture gives a little under the pointer, the way the game's own
    -- minimap buttons do, and comes back however the press ends.
    local function Release(self)
        self.icon:SetPoint("CENTER", 0, 0)
    end
    b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", Release)

    b:SetScript("OnEnter", function(self)
        if not self.dragging then ShowTip(self) end
    end)
    b:SetScript("OnLeave", function(self) FP:HideTip(self) end)

    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        FP:HideTip(self)
        self:SetScript("OnUpdate", FollowCursor)
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
        Release(self)
        -- A tenth of a degree is finer than a pixel at this radius, and keeps
        -- the stored number short in an exported profile.
        M.db.angle = math.floor((tonumber(M.db.angle) or DEFAULT_ANGLE) * 10 + 0.5) / 10
        Place()
    end)
    -- A map hidden in the middle of a drag must not leave the button following
    -- the pointer once it comes back.
    b:SetScript("OnHide", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
        Release(self)
    end)

    button = b
    return b
end

function M:OnEnable()
    local b = Build()
    if not b then
        return FP:Warn(L["MinimapButton: this build has no minimap to put a "
            .. "button on. /fplus opens the settings."])
    end
    Place()
    b:Show()
end

function M:OnDisable()
    if not button then return end
    FP:HideTip(button)
    button:Hide()
end

--- A profile switch may carry another angle; nothing else needs rebuilding.
function M:Reapply()
    Place()
end

-- ---------------------------------------------------------------------------
-- Blizzard's addon compartment
--
-- The list of addons behind the small button by the minimap, asked for together
-- with the minimap button by a player on CurseForge on 2026-09-28, so the
-- settings can be reached from the game's own menu with the button switched off.
-- That is why it answers to no switch: it is the way back when the button is
-- gone.
--
-- Read in this client's interface code: AddonCompartmentMixin:RegisterAddons
-- reads the three names below from the TOC at the first PLAYER_ENTERING_WORLD
-- and calls these globals, insecurely, with the addon's name first. The title
-- and the icon come from the TOC as well. The list sits by the minimap at the
-- right of the screen, so the hover text opens to the left.
-- ---------------------------------------------------------------------------

function ForeverPlus_OnAddonCompartmentClick()
    FP:ToggleSettings()
end

function ForeverPlus_OnAddonCompartmentEnter(_, entry)
    if not entry then return end
    FP:ShowTip(entry, { "ForeverPlus", L["Click to open or close the settings."] },
        "LEFT")
end

function ForeverPlus_OnAddonCompartmentLeave(_, entry)
    FP:HideTip(entry)
end
