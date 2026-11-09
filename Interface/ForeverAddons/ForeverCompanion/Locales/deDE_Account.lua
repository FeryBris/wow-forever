local _, FC = ...

FC:RegisterLocale("deDE", {
    CHAR_SUMMARY = "%d gecachte(r) Charakter(e) • %d Account-Gegenstandstyp(en) • %d gecachte Rezept(e) • %d Ziel(e)",
    CHAR_CACHE_FRESHNESS = "Aktualität: %d veraltete(r) Charakter-Inventar-Cache(s) (>24h) • Account-Bank zuletzt gescannt: %s",
    CHAR_CACHE_UNAVAILABLE = "Cache-Aktualität ist nicht verfügbar.",
    CHAR_HEADER = "Charakter • Stufe / Klasse • Cache-Alter • Inventar",
    CHAR_ROW = "%s %s • Stufe %d %s • %s • Taschen %d • Bank %d",
    CHAR_NO_PROFESSION_CACHE = "Kein Berufs-Cache",
    CHAR_UNKNOWN_CLASS = "Unbekannt",
    CHAR_AGE_UNKNOWN = "unbekannt",
    CHAR_AGE_NOW = "jetzt",
    CHAR_AGE_NEVER = "nie",
    CHAR_NOTE = "Offline-Charaktere verwenden den zuletzt gespeicherten Stand dieses Charakters. Bankdaten werden erst gecacht, nachdem die Bank erfolgreich geöffnet wurde.",
    PAGE_X_OF_Y = "Seite %d / %d",

    ACCOUNT_RECIPE_CURRENT = "aktuell %d/%d",
    ACCOUNT_RECIPE_CURRENT_UNSCANNED = "aktuell nicht gescannt",
    ACCOUNT_RECIPE_PROFESSION_ROW = "%s\n   accountweit %d/%d erlernt • %s • %d auf anderen Charakteren bekannte Lücke(n)",
    ACCOUNT_RECIPE_EMPTY = "Öffne die Berufsfenster deiner Charaktere, um die Rezeptmatrix aufzubauen.",
    ACCOUNT_RECIPE_OPPORTUNITY_ROW = "%s — %s\n   Erlernt von: %s",
    ACCOUNT_RECIPE_NO_DIFFERENCES = "Im Cache sind aktuell keine charakterübergreifenden Rezeptunterschiede bekannt.",
    ACCOUNT_RECIPE_PROF_PAGE = "Berufe %d / %d",
    ACCOUNT_RECIPE_DIFF_PAGE = "Rezeptunterschiede %d / %d • %d gesamt",
})
