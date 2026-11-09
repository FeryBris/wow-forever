local _, FC = ...

FC:RegisterLocale("enUS", {
    CHAR_SUMMARY = "%d cached character(s) • %d account item type(s) • %d cached recipe(s) • %d goal(s)",
    CHAR_CACHE_FRESHNESS = "Freshness: %d stale character inventory cache(s) (>24h) • account bank last scanned: %s",
    CHAR_CACHE_UNAVAILABLE = "Cache freshness data unavailable.",
    CHAR_HEADER = "Character • Level / Class • Cache age • Inventory",
    CHAR_ROW = "%s %s • Level %d %s • %s • Bags %d • Bank %d",
    CHAR_NO_PROFESSION_CACHE = "No profession cache",
    CHAR_UNKNOWN_CLASS = "Unknown",
    CHAR_AGE_UNKNOWN = "unknown",
    CHAR_AGE_NOW = "now",
    CHAR_AGE_NEVER = "never",
    CHAR_NOTE = "Offline characters use the last cache collected while that character was logged in. Bank data is cached only after the bank was opened successfully.",
    PAGE_X_OF_Y = "Page %d / %d",

    ACCOUNT_RECIPE_CURRENT = "current %d/%d",
    ACCOUNT_RECIPE_CURRENT_UNSCANNED = "current not scanned",
    ACCOUNT_RECIPE_PROFESSION_ROW = "%s\n   account %d/%d learned • %s • %d elsewhere-known gap(s)",
    ACCOUNT_RECIPE_EMPTY = "Open profession windows on your characters to build the recipe matrix.",
    ACCOUNT_RECIPE_OPPORTUNITY_ROW = "%s — %s\n   Known by: %s",
    ACCOUNT_RECIPE_NO_DIFFERENCES = "No cross-character recipe differences are currently known from the cache.",
    ACCOUNT_RECIPE_PROF_PAGE = "Professions %d / %d",
    ACCOUNT_RECIPE_DIFF_PAGE = "Recipe differences %d / %d • %d total",
})
