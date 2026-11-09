--========================================================================--
-- SoTBookie / Minimap.lua
-- Minimap launcher: one LibDataBroker object + LibDBIcon button.
-- Core calls W:MinimapOnEnable() from OnEnable; the Stats tab's "Hide
-- minimap icon" option calls W:UpdateMinimapVisibility().
-- The icon only ever opens the window - it never creates or resolves bets.
--========================================================================--

local W = LibStub("AceAddon-3.0"):GetAddon("SoTBookie")

local ICON_NAME = "SoTBookie"

function W:MinimapOnEnable()
    if self.ldb then return end -- OnEnable can run again after a disable
    local LDB = LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    self.ldb = LDB:NewDataObject(ICON_NAME, {
        type  = "launcher",
        icon  = "Interface\\Icons\\INV_Misc_Coin_02",
        label = "SoTBookie",
        OnClick = function() W:ToggleWindow() end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("SoTBookie")
            tooltip:AddLine(("Otevrene sazky: %d"):format(#W:GetActiveBets()),
                0.8, 0.8, 0.8)
            tooltip:AddLine("Kliknutim otevres", 0.8, 0.8, 0.8)
        end,
    })
    if not self.ldb then return end

    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then icon:Register(ICON_NAME, self.ldb, self.db.profile.minimap) end
end

function W:UpdateMinimapVisibility()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon or not icon:IsRegistered(ICON_NAME) then return end
    if self.db.profile.minimap.hide then
        icon:Hide(ICON_NAME)
    else
        icon:Show(ICON_NAME) -- creates the button lazily if it never existed
    end
end
