-- Start-up order. Loads last so that every module is already registered.

local ADDON, FP = ...
local L = FP.L

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")

boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        -- Our SavedVariables are only available from here on. This creates the
        -- structure and runs any pending migration -- but it does not choose a
        -- profile, because that needs the character's name and realm, and
        -- neither is reliably there yet.
        if arg1 ~= ADDON then return end
        FP:InitDB()
        -- The first moment the saved choice of language exists, and nothing
        -- has drawn a word yet. See Core/Locale.lua.
        FP:ResolveLanguage()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- PLAYER_LOGIN rather than PLAYER_ENTERING_WORLD: the Blizzard frames
        -- exist by now, the player does too, and it fires exactly once (not on
        -- every zone change).
        FP:ActivateProfile()
        FP:EnableAll()

        local active = 0
        for _, name in ipairs(FP.order) do
            if FP:IsEnabled(name) then active = active + 1 end
        end
        FP:Print(L["v%s loaded, %d of %d modules enabled, profile "
            .. "|cffffffff%s|r. Open the settings with |cff888888/fplus|r."],
            FP.version, active, #FP.order, tostring(FP.profileName))

        -- A warning used to follow here whenever nothing had come back from
        -- the saved file: "this version of the game is not saving addon
        -- settings". True on builds 69913 and 69977, and removed on 2026-09-26
        -- by the owner's decision, the day 70009 started handing the file back.
        -- From then on "nothing came back" almost always means a first run,
        -- and the line would have greeted every new player with a fault they
        -- did not have. FP.loaded still records what came back, silently:
        -- /dump ForeverPlus.loaded reads it in game.
    end
end)
