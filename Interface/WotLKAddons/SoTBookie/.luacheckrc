-- Luacheck config for SoTBookie (WoW 3.3.5a, Lua 5.1).
-- Run from this folder: ..\Wydlica\.tools\luacheck.exe . --no-color
std = "lua51"
max_line_length = false
self = false -- don't warn about unused `self` in methods
exclude_files = { "Libs" }

globals = { "_G", "StaticPopupDialogs", "SoTBookieFrame" }

-- WoW 3.3.5 API surface used by this addon; extend as it grows
read_globals = {
    "LibStub",
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "wipe",
    "strtrim", "strsplit", "strjoin",
    "GetAddOnMetadata",
    "UnitName",
    "IsInGuild",
    "GetNumRaidMembers", "GetNumPartyMembers",
    "InCombatLockdown", "GuildRoster",
    "PlaySound",
    "SendChatMessage",
    "UISpecialFrames",
    "GetTime", "GetRealmName",
    "time", "date",
    "StaticPopup_Show",
    "CloseDropDownMenus",
    SlashCmdList = { other_fields = true },
    string = { fields = { "trim" } }, -- WoW extends the string library
    table = { fields = { "wipe" } },
}
