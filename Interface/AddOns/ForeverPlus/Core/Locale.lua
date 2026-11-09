-- The addon's own text in the player's language.
--
-- Phase 7.7, settled with the owner on 2026-10-05; ROADMAP.md has the
-- decisions and TRANSLATION.md the words and the rules for German. The
-- client's language unless the player picks one, English for a language the
-- addon does not have, one choice for the whole account, and a change that
-- takes effect at the next reload.
--
-- **The English text is the key.** It stays in the code where it always was,
-- marked with L: `L["Report the cost in chat"]`. A file in Locales/ maps it to
-- its translation, and a text without one stays English, which is the fallback
-- the owner chose. tools/l10n.py finds every marked text, and the build
-- refuses while one has no German.
--
-- **L works in two moments.** Every file runs before the saved settings
-- exist, so a text marked while a file loads, an option's label for one, comes
-- out English: nobody knows the language yet. Whatever draws it translates it
-- then, which is why the widgets in Core/Widgets.lua, the option builder and
-- FP:Print pass their text through FP:T. A text marked while the game runs is
-- translated on the spot, and drawing it translates nothing a second time,
-- because a translation is not itself a key. tools/l10n.py checks that no
-- German text is also an English key, which is the one way it could be.
--
-- **Nothing is ever compared against a translation**, the locale rule in
-- AGENTS.md. A translation is display text, exactly like the client's own,
-- and anything stored or matched stays in the English the code was written in.
--
-- Loads before everything else, Init.lua included: every file after it marks
-- its texts with L, and the groups of the module list are marked in Init.lua.

local ADDON, FP = ...

--- The languages the picker offers, each in its own name: a player who cannot
--- read the language in use still finds theirs. Sorted alphabetically by that
--- name, the owner's order of 2026-10-07, with Automatic always above them;
--- a name in another alphabet goes after the Latin ones.
FP.LANGUAGES = {
    { "deDE", "Deutsch" },
    { "enUS", "English" },
    { "esES", "Español" },
    { "frFR", "Français" },
    { "ruRU", "Русский" },
}

-- Client languages served by another language's table. Spanish is one table
-- for Spain and Latin America, gated on 2026-10-07: the Mexican client gets
-- it too, worded so that both regions read it naturally, in Spain's words
-- where the two clients differ.
local SAME_AS = {
    esMX = "esES",
}

-- How each language writes the decimal point. English needs no entry. Spanish
-- writes the comma on every client, the owner's word at the Spanish gate,
-- although the Mexican client itself writes the point.
local DECIMAL = {
    deDE = ",",
    esES = ",",
    frFR = ",",
    ruRU = ",",
}

-- Which form a count takes: "one", "few" or "other". English, German and
-- Spanish give 1 alone the singular, which needs no entry here: "0 objetos
-- grises", "1 objeto gris". French counts 0 with 1:
-- "0 objet gris". Russian has three forms, gated on 2026-10-07: the singular
-- for every number ending in 1 but 11, "21 игрок"; a second for every number
-- ending in 2 to 4 but 12 to 14, "22 игрока"; and the plural for the rest,
-- 0 and 11 among them, "11 игроков".
local FORM = {
    frFR = function(n) return (n == 0 or n == 1) and "one" or "other" end,
    ruRU = function(n)
        local last, lastTwo = n % 10, n % 100
        if last == 1 and lastTwo ~= 11 then return "one" end
        if last >= 2 and last <= 4 and (lastTwo < 12 or lastTwo > 14) then
            return "few"
        end
        return "other"
    end,
}

local tables  = {}  -- [locale] = { [English text] = translation }
local plurals = {}  -- [locale] = { [English plural] = the form for a few }
local active        -- the table in use, nil while that is English

--- Registers a language. Each file in Locales/ calls this once.
function FP:AddLocale(locale, entries)
    tables[locale] = entries
end

--- Registers the plural forms of a language beyond the singular and the
--- plural every language has: Russian's form for 2 to 4, keyed by the English
--- plural it stands beside. See FP:Plural.
function FP:AddPlurals(locale, entries)
    plurals[locale] = entries
end

--- Does the addon speak this language? English always.
function FP:HasLocale(locale)
    return locale == "enUS" or tables[locale] ~= nil
end

--- The display text for an English text, in the language in use.
--
-- Anything that is not a key comes back untouched, so a name, a number or a
-- text already translated can pass through here without harm.
function FP:T(text)
    if active == nil or type(text) ~= "string" then return text end
    return active[text] or text
end

--- The same, in a language that need not be the one in use: the question after
--- picking a language asks in the language just picked.
function FP:TIn(locale, text)
    local entries = tables[locale]
    if entries == nil or type(text) ~= "string" then return text end
    return entries[text] or text
end

--- L["English text"] marks a text for tools/l10n.py and translates it.
--
-- A table rather than a function because that is the idiom every WoW addon
-- uses for this, and a reader who has seen one recognises it. It holds no keys
-- of its own; every lookup goes through FP:T.
FP.L = setmetatable({}, {
    __index    = function(_, text) return FP:T(text) end,
    __newindex = function() error("FP.L only translates; it stores nothing", 2) end,
})

--- N["English text"] marks a text without translating it, gettext's noop.
--
-- For the few texts that must stay English where they are written: a tab's
-- name, which is also how the window remembers it, and the question after
-- picking a language, which is translated into the language just picked
-- rather than the one in use. Whatever shows them translates them then.
FP.N = setmetatable({}, {
    __index    = function(_, text) return text end,
    __newindex = function() error("FP.N only marks; it stores nothing", 2) end,
})

--- Which language a setting means.
--
-- Nothing stored, or "auto", follows the client. So does a stored language the
-- addon no longer has: a stale value nobody can see is worse than the default.
-- A client whose language another table serves gets that one: a Mexican
-- client, Spanish.
-- @param choice  "auto", a locale such as "deDE", or nil
function FP:LanguageFor(choice)
    if choice ~= nil and choice ~= "auto" and self:HasLocale(choice) then
        return choice
    end
    local ok, client = pcall(GetLocale)
    if ok and type(client) == "string" then
        client = SAME_AS[client] or client
        if self:HasLocale(client) then return client end
    end
    return "enUS"
end

--- Settles the language for this session. Runs once, at ADDON_LOADED, the
--- first moment the saved choice exists; a change waits for the next reload.
function FP:ResolveLanguage()
    local choice = type(self.global) == "table" and self.global.language or nil
    self.language = self:LanguageFor(choice)
    active = (self.language ~= "enUS") and tables[self.language] or nil
end

--- The form of a text that fits a count, in the language in use.
--
-- Whole texts rather than an "s" stuck on the end, which is what the English
-- messages did before there was a second language: German changes the
-- adjective as well, "1 graues Item", "2 graue Items". Which form a count
-- takes is the language's, FORM above.
--
-- one and other are the English singular and plural, **marked with N**, so
-- they arrive untranslated: Russian's third form is found by the English
-- plural, which a translation could not be, and tools/l10n.py names a call
-- that marks them with L. The form comes back translated, and a language
-- without a third form, or a text without one, takes the plural.
function FP:Plural(count, one, other)
    local n = tonumber(count)
    local rule = FORM[self.language]
    local form = "other"
    if n ~= nil then
        form = rule and rule(n) or ((n == 1) and "one" or "other")
    end
    if form == "one" then return self:T(one) end
    if form == "few" then
        local forms = plurals[self.language]
        local few = forms and type(other) == "string" and forms[other]
        if few then return few end
    end
    return self:T(other)
end

--- A number with decimals, written the way the language in use writes them.
function FP:Decimal(value, places)
    local text = string.format("%." .. (places or 1) .. "f", tonumber(value) or 0)
    local point = DECIMAL[self.language]
    if point then text = text:gsub("%.", point) end
    return text
end

-- Lower case for searching, umlauts included, and **without string.lower**.
-- That one is byte based and follows the C library's idea of the system
-- language: measured in the test harness on 2026-10-05, it turned the first
-- byte of every umlaut into something else and left text that was no longer
-- UTF-8. AGENTS.md says the same of WoW's Lua. So A to Z by their byte values,
-- which no setting can move, and the accented capitals by their bytes too:
-- every capital from À to Þ is the byte 195 and a second byte 32 below its
-- small letter, the umlauts, the French accents and the Spanish ones with Ñ
-- among them, × apart. Œ and Ÿ sit elsewhere and are named.
--
-- Cyrillic the same way, for Russian since 2026-10-07: А to П are the byte
-- 208 and a second byte 32 below their small letters, Р to Я are 208 where
-- theirs are 209, 32 above. Ё and ё both fold to е, since the Russian client
-- writes е where ё belongs and a player may type either.
local FOLD = {
    ["\197\146"] = "\197\147",   -- Œ to œ
    ["\197\184"] = "\195\191",   -- Ÿ to ÿ
    ["\208\129"] = "\208\181",   -- Ё to е
    ["\209\145"] = "\208\181",   -- ё to е
}

local function LowerAscii(letter)
    return string.char(letter:byte() + 32)
end

local function LowerLatin(second)
    local byte = second:byte()
    if byte == 151 then return "\195" .. second end   -- ×, not a letter
    return "\195" .. string.char(byte + 32)
end

local function LowerCyrillicFirst(second)    -- А to П
    return "\208" .. string.char(second:byte() + 32)
end

local function LowerCyrillicSecond(second)   -- Р to Я
    return "\209" .. string.char(second:byte() - 32)
end

--- A text folded for comparing in a search box, and for nothing else.
function FP:Fold(text)
    local folded = tostring(text or ""):gsub("[A-Z]", LowerAscii)
    folded = folded:gsub("\195([\128-\158])", LowerLatin)
    folded = folded:gsub("\197[\146\184]", FOLD)
    folded = folded:gsub("\208([\144-\159])", LowerCyrillicFirst)
    folded = folded:gsub("\208([\160-\175])", LowerCyrillicSecond)
    folded = folded:gsub("\208\129", FOLD)
    folded = folded:gsub("\209\145", FOLD)
    return folded
end
