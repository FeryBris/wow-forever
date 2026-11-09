-- Keeps the experience bar text visible instead of only on hover.
--
-- Done through the client's own setting rather than by touching frames. That
-- is the same switch the game's own options menu would flip, it survives Edit
-- Mode rearranging the status bars, and it needs no knowledge of the bar's
-- internals -- which are unverified on this build.
--
-- If the setting turns out not to exist here, the module says so and points at
-- the discovery report rather than silently doing nothing. The bar's real
-- structure is enumerated into ForeverPlusDB.discovery, so the fallback can be
-- written against measurements instead of guesses.

local ADDON, FP = ...
local L = FP.L

local M = FP:RegisterModule("XPBarText", {
    title    = L["Experience Bar Text"],
    default  = true,
    desc     = L["Keeps the experience bar text visible."],
    group    = "display",
    order    = 20,
    -- No options: there is nothing here worth a switch. `previous` is written
    -- into mod.db at runtime by OnEnable, and needs no declared default.
})

local CVAR = "xpBarText"

local function GetCVarSafe(name)
    local getter = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
    if not getter then return nil end
    local ok, value = pcall(getter, name)
    return ok and value or nil
end

local function SetCVarSafe(name, value)
    local setter = (C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if not setter then return false end
    return (pcall(setter, name, value))
end

function M:OnEnable()
    local current = GetCVarSafe(CVAR)

    if current == nil then
        return FP:Warn(
            L["XPBarText: this build has no '%s' setting. Run /fplus "
            .. "discover: the experience bar's structure is saved in "
            .. "SavedVariables, so the fallback can be built against it."], CVAR)
    end

    if current == "1" then return end   -- already on, nothing to say

    -- Remember the previous value so switching the module off restores it,
    -- rather than assuming a default that may not be the user's.
    if self.db.previous == nil then
        self.db.previous = current
    end

    if SetCVarSafe(CVAR, "1") then
        FP:Print(L["Experience bar text is now always visible."])
    else
        FP:Warn(L["XPBarText: '%s' exists but could not be set."], CVAR)
    end
end

function M:OnDisable()
    local previous = self.db and self.db.previous
    if previous == nil then return end

    SetCVarSafe(CVAR, previous)
    self.db.previous = nil
end
