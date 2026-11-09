local _, FC = ...

FC.Locales = FC.Locales or {}

function FC:RegisterLocale(locale, strings)
    if type(locale) ~= "string" or type(strings) ~= "table" then return end
    self.Locales[locale] = self.Locales[locale] or {}
    for key, value in pairs(strings) do
        self.Locales[locale][key] = value
    end
end

function FC:GetLocale()
    if self.DB and self.DB.settings and self.DB.settings.locale and self.DB.settings.locale ~= "AUTO" then
        return self.DB.settings.locale
    end
    if type(GetLocale) == "function" then
        local ok, locale = pcall(GetLocale)
        if ok and locale then return locale end
    end
    return "enUS"
end

function FC:GetText(key, ...)
    local locale = self:GetLocale()
    local tableForLocale = self.Locales[locale] or self.Locales.enUS or {}
    local fallback = self.Locales.enUS or {}
    local value = tableForLocale[key] or fallback[key] or tostring(key)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

local CLASS_KEYS = {
    DEATHKNIGHT = "CLASS_DEATHKNIGHT",
    DEMONHUNTER = "CLASS_DEMONHUNTER",
    DRUID = "CLASS_DRUID",
    EVOKER = "CLASS_EVOKER",
    HUNTER = "CLASS_HUNTER",
    MAGE = "CLASS_MAGE",
    MONK = "CLASS_MONK",
    PALADIN = "CLASS_PALADIN",
    PRIEST = "CLASS_PRIEST",
    ROGUE = "CLASS_ROGUE",
    SHAMAN = "CLASS_SHAMAN",
    WARLOCK = "CLASS_WARLOCK",
    WARRIOR = "CLASS_WARRIOR",
}

local PROFESSION_KEYS = {
    [129] = "PROF_FIRST_AID",
    [164] = "PROF_BLACKSMITHING",
    [165] = "PROF_LEATHERWORKING",
    [171] = "PROF_ALCHEMY",
    [182] = "PROF_HERBALISM",
    [185] = "PROF_COOKING",
    [186] = "PROF_MINING",
    [197] = "PROF_TAILORING",
    [202] = "PROF_ENGINEERING",
    [333] = "PROF_ENCHANTING",
    [356] = "PROF_FISHING",
    [393] = "PROF_SKINNING",
    [755] = "PROF_JEWELCRAFTING",
    [773] = "PROF_INSCRIPTION",
    [794] = "PROF_ARCHAEOLOGY",
}

function FC:GetClassDisplayName(characterOrClassFile, fallback)
    local classFile = type(characterOrClassFile) == "table" and characterOrClassFile.classFile or characterOrClassFile
    local rawFallback = fallback
    if type(characterOrClassFile) == "table" then
        rawFallback = characterOrClassFile.className or fallback
    end
    local key = CLASS_KEYS[tostring(classFile or ""):upper()]
    if key then return self:GetText(key) end
    return tostring(rawFallback or self:GetText("CHAR_UNKNOWN_CLASS"))
end

function FC:GetProfessionDisplayName(professionOrID, fallback)
    local professionID = professionOrID
    local rawFallback = fallback
    if type(professionOrID) == "table" then
        professionID = professionOrID.skillLineID or professionOrID.professionID
        rawFallback = professionOrID.name or professionOrID.professionName or professionOrID.skillLineName or fallback
    end
    local key = PROFESSION_KEYS[tonumber(professionID)]
    if key then return self:GetText(key) end
    return tostring(rawFallback or self:GetText("PROF_UNKNOWN"))
end
