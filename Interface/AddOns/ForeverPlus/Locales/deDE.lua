-- German, phase 7.7.
--
-- The English text on the left is the key, exactly as it stands in the code,
-- and the German on the right is what a player reads. TRANSLATION.md holds the
-- words and the rules: "du", a setting as an infinitive, the words players
-- use, a decimal comma, no long dashes, and a text that fits its row.
--
-- Sorted by page and then by file, so the list can be read one page at a
-- time. tools/l10n.py reports a text the code marks that is missing here, and
-- German left behind for a text the code no longer marks.

local ADDON, FP = ...

FP:AddLocale("deDE", {

    -- -----------------------------------------------------------------------
    -- The window
    -- -----------------------------------------------------------------------

    -- Core/Boot.lua
    ["v%s loaded, %d of %d modules enabled, profile |cffffffff%s|r. Open the settings with |cff888888/fplus|r."]
        = "v%s geladen, %d von %d Modulen aktiv, Profil |cffffffff%s|r. |cff888888/fplus|r für die Einstellungen.",

    -- Core/Init.lua
    ["NPC Interaction"] = "Umgang mit NPCs",
    ["Merchants"] = "Händler",
    ["Loot"] = "Loot",
    ["Interruptions"] = "Unterbrechungen",
    ["Display"] = "Anzeige",
    ["Chat"] = "Chat",
    ["Tools"] = "Werkzeuge",

    -- Core/Options.lua
    ["Enable %s"] = "%s einschalten",
    ["Do it"] = "Ausführen",
    ["%s: custom option failed to build: %s"] = "%s: Eine eigene Option ließ sich nicht aufbauen: %s",
    ["%s: option %s has an unknown type %q"] = "%s: Die Option %s hat einen unbekannten Typ %q",
    ["Not in use until another setting here allows it."]
        = "Nicht aktiv, bis eine andere Einstellung hier sie freigibt.",
    ["Not in use until you switch the module on."] = "Nicht aktiv, bis du das Modul einschaltest.",

    -- Core/Util.lua
    ["%s: function is missing"] = "%s: Die Funktion fehlt",
    ["%s: expected a function, got %s"] = "%s: Funktion erwartet, %s erhalten",
    ["Error in %s: %s"] = "Fehler in %s: %s",
    ["%s: this client does not recognize %s. Those features remain unavailable."]
        = "%s: Dieser Client kennt %s nicht. Diese Funktionen stehen nicht zur Verfügung.",

    -- Core/Widgets.lua
    ["Select all"] = "Alles markieren",
    ["Close"] = "Schließen",
    ["Paste the text here with Ctrl+V, then press the button below."]
        = "Hier mit Strg+V einfügen, dann den Button unten drücken.",
    ["Apply"] = "Übernehmen",
    ["Delete Character Data"] = "Charakterdaten löschen",
    ["Do you really want to delete the data for your character %s from ForeverPlus?"]
        = "Willst du die Daten deines Charakters %s wirklich aus ForeverPlus löschen?",
    ["This deletes its gold, its place in the mail list, its profile assignment, its Auto Buy choices, its cooldowns, the notices it has already been shown and the chat saved from its last session. Profiles are shared by all characters and are kept."]
        = "Gelöscht werden sein Gold, sein Platz in der Liste der Post, seine Profilzuordnung, seine Auswahl für den Autokauf, seine Cooldowns, die Hinweise, die er schon gesehen hat, und der Chat seiner letzten Sitzung. Profile teilen sich alle Charaktere, sie bleiben.",
    ["Delete"] = "Löschen",
    ["Cancel"] = "Abbrechen",
    ["ForeverPlus no longer keeps anything about %s."] = "ForeverPlus speichert nichts mehr über %s.",

    -- Modules/Menu.lua
    ["This window."] = "Dieses Fenster.",
    ["Click the box to turn it on and off."] = "Ein Klick auf das Kästchen schaltet es ein und aus.",
    ["Its settings have a tab of their own: |cffffffff%s|r. Click to go there."]
        = "Seine Einstellungen haben einen eigenen Reiter: |cffffffff%s|r. Ein Klick führt dorthin.",
    ["Click the row to show its settings."] = "Ein Klick auf die Zeile zeigt seine Einstellungen.",
    ["This module has nothing to set."] = "Dieses Modul hat nichts einzustellen.",
    ["Gameplay"] = "Gameplay",
    ["Gameplay modules are on"] = "Gameplaymodule sind an",
    ["Gameplay modules are off"] = "Gameplaymodule sind aus",
    ["Turning this page off disables every module on it, including the minimap button. Each module keeps its own setting, so turning the page back on restores the previous settings."]
        = "Aus hält jedes Modul dieser Seite an, den Button an der Minimap eingeschlossen. Jedes behält seinen eigenen Schalter, beim Einschalten der Seite kommen also die zurück, die an waren.",
    ["Expand all"] = "Alles ausklappen",
    ["Collapse all"] = "Alles einklappen",
    ["Clear"] = "Leeren",
    ["Search"] = "Suchen",
    ["%s is on"] = "%s ist an",
    ["%s is off"] = "%s ist aus",
    ["Switches everything on this page on or off. The settings are kept."]
        = "Schaltet alles auf dieser Seite ein oder aus. Die Einstellungen bleiben erhalten.",
    ["Language"] = "Sprache",
    ["Automatic"] = "Automatisch",
    ["Applies to every character and profile. Automatic uses the game's language, or English if the addon does not support that language. Changes take effect after the next reload."]
        = "Gilt für alle Charaktere und alle Profile. Automatisch nimmt die Sprache des Spiels, oder Englisch, wenn dieses Addon sie nicht hat. Eine Änderung wirkt ab dem nächsten Neuladen.",
    ["The language changes with the next reload. Reload now?"]
        = "Die Sprache wechselt beim nächsten Neuladen. Jetzt neu laden?",
    ["Reload now"] = "Jetzt neu laden",
    ["Later"] = "Später",
    ["Reload UI"] = "UI neu laden",
    ["This page is switched off. The box on its tab switches it on again, with every setting here as you left it."]
        = "Diese Seite ist ausgeschaltet. Das Kästchen auf ihrem Reiter schaltet sie wieder ein, mit allen Einstellungen, wie du sie verlassen hast.",
    ["The %s page has no switch on its tab. Give it a switch, or mark it internal if it only arranges the addon."]
        = "Die Seite %s hat keinen Schalter auf ihrem Reiter. Gib ihr einen, oder markiere sie als intern, wenn sie nur das Addon selbst ordnet.",
    ["Tab %s failed to build its header: %s"] = "Der Reiter %s konnte seine Kopfzeile nicht aufbauen: %s",
    ["Tab %s failed to build: %s"] = "Der Reiter %s ließ sich nicht aufbauen: %s",
    ["The settings window was off screen and has been moved back to the center."]
        = "Das Einstellungsfenster war außerhalb des Bildschirms und ist zurück in der Mitte.",

    -- The names of the other pages, and the switches on their tabs. The pages
    -- themselves follow in later parts of this file.
    ["Buffs"] = "Buffs",
    ["Buff warnings are on"] = "Buffwarnungen sind an",
    ["Buff warnings are off"] = "Buffwarnungen sind aus",
    ["The master switch for this page. Everything on it only decides what it warns about and when.|n|nOff means no icons at all. The settings are kept, so turning it back on restores what you had."]
        = "Der Hauptschalter dieser Seite. Alles darauf entscheidet nur, wovor und wann gewarnt wird.|n|nAus heißt: gar keine Symbole. Die Einstellungen bleiben erhalten, nach dem Einschalten ist alles wie vorher.",
    ["Consumables"] = "Consumables",
    ["Consumable warnings are on"] = "Warnungen für Consumables sind an",
    ["Consumable warnings are off"] = "Warnungen für Consumables sind aus",
    ["Tooltip"] = "Tooltip",
    ["Tooltip changes are on"] = "Tooltipänderungen sind an",
    ["Tooltip changes are off"] = "Tooltipänderungen sind aus",
    ["Off leaves the client's own tooltip exactly as it was, arrangement and position included. The settings are kept."]
        = "Aus lässt den Tooltip des Clients genau so, wie er war, samt Anordnung und Position. Die Einstellungen bleiben erhalten.",
    ["Info bar"] = "Infoleiste",
    ["The info bar is on"] = "Die Infoleiste ist an",
    ["The info bar is off"] = "Die Infoleiste ist aus",
    ["Chat changes are on"] = "Chatänderungen sind an",
    ["Chat changes are off"] = "Chatänderungen sind aus",
    ["Off leaves the chat as the client has it. The settings are kept."]
        = "Aus überlässt den Chat ganz dem Client. Die Einstellungen bleiben erhalten.",
    ["Design"] = "Design",
    ["Profiles"] = "Profile",
    ["Info"] = "Info",

    -- -----------------------------------------------------------------------
    -- Gameplay
    -- -----------------------------------------------------------------------

    -- Shared by several modules
    ["Hold Shift to pause"] = "Mit Shift pausieren",
    ["Shift is held, automation paused."] = "Shift ist gedrückt, die Automatik pausiert.",
    ["No merchant open."] = "Kein Händler offen.",

    -- Modules/QuestAutoAccept.lua
    ["Auto Accept Quests"] = "Quests automatisch annehmen",
    ["Also from gossip windows"] = "Auch aus Dialogen",
    ["Accepts quests offered inside a conversation, not just through the regular quest window."]
        = "Nimmt auch Quests an, die in einem Gespräch angeboten werden, nicht nur im einfachen Questfenster.",
    ["Confirm shared quests and escorts"] = "Geteilte Quests und Eskorten bestätigen",
    ["Also accepts quests other players share with you and escort quests. An escort begins the moment it is accepted."]
        = "Nimmt auch Quests an, die andere Spieler mit dir teilen, sowie Eskortquests. Eine Eskorte beginnt, sobald sie angenommen ist.",
    ["While Shift is down, nothing is accepted, so you can read the text first."]
        = "Solange Shift gedrückt ist, wird nichts angenommen, für den Fall, dass du den Text erst lesen willst.",

    -- Modules/QuestAutoTurnIn.lua
    ["Auto Turn In Quests"] = "Quests automatisch abgeben",
    ["Hands quests in from inside a conversation as well as from the plain quest window."]
        = "Gibt Quests auch aus einem Gespräch heraus ab, nicht nur im einfachen Questfenster.",
    ["While Shift is down, nothing is handed in. Reward values are still shown because they belong to a separate module."]
        = "Solange Shift gedrückt ist, wird nichts abgegeben. Die Werte der Belohnungen werden trotzdem angezeigt, weil sie zu einem eigenen Modul gehören.",

    -- Modules/QuestRewardValue.lua
    ["Quest Reward Value"] = "Wert der Questbelohnungen",
    ["Shows what each quest reward sells for, on every quest window."]
        = "Zeigt in jedem Questfenster, was jede Belohnung beim Händler bringt.",
    ["Also on rewards you get anyway"] = "Auch bei festen Belohnungen",
    ["Not only the ones you choose between. Off, and only a real choice carries a price."]
        = "Nicht nur bei denen, zwischen denen du wählst. Aus heißt: Nur eine echte Wahl bekommt einen Preis.",
    ["QuestRewardValue: could not hook QuestInfo_Display, falling back to the quest events alone."]
        = "Wert der Questbelohnungen: QuestInfo_Display ließ sich nicht einhängen, es bleiben nur die Questereignisse.",

    -- Modules/GossipAuto.lua
    ["Skip Gossip"] = "Dialoge überspringen",
    ["Clicks past the extra line of talk at vendors, trainers, flight masters, bankers and guild masters."]
        = "Klickt bei Händlern, Lehrern, Flugmeistern, Bankiers und Gildenmeistern die zusätzliche Gesprächszeile weg.",
    ["Say when an unfamiliar service turns up"] = "Melden, wenn ein unbekannter Dienst auftaucht",
    ["Nothing is clicked in that case. The line tells you the addon encountered an unfamiliar service, and the details are saved so the list can be expanded deliberately. Once per kind of service, not once per NPC."]
        = "Dann wird nichts geklickt. Die Zeile sagt dir, dass das Addon auf einen unbekannten Dienst gestoßen ist, und die Einzelheiten werden aufbewahrt, damit die Liste gezielt erweitert werden kann. Einmal pro Art von Dienst, nicht einmal pro NPC.",
    ["Say every time a line is clicked"] = "Jeden Klick auf eine Zeile melden",
    ["Writes a line in your chat each time the addon clicks a gossip line for you."]
        = "Schreibt jedes Mal eine Zeile in deinen Chat, wenn das Addon eine Dialogzeile für dich anklickt.",
    ["While Shift is down, nothing is clicked, so you can read what the NPC actually says. Hold Shift and talk again to check whether the addon was skipping a window for you."]
        = "Solange Shift gedrückt ist, wird nichts geklickt, damit du lesen kannst, was der NPC eigentlich sagt. Halte Shift und sprich ihn erneut an, um zu prüfen, ob das Addon ein Fenster für dich übersprungen hat.",
    ["Opened the vendor for you."] = "Den Händler für dich geöffnet.",
    ["Opened the trainer for you."] = "Den Lehrer für dich geöffnet.",
    ["Opened the taxi for you."] = "Die Flugkarte für dich geöffnet.",
    ["Opened the petition for you."] = "Die Gildensatzung für dich geöffnet.",
    ["Opened the bank for you."] = "Die Bank für dich geöffnet.",
    ["Left alone because the service is unfamiliar: icon %s, \"%s\". The details are saved so the list can be expanded deliberately."]
        = "Einen unbekannten Dienst in Ruhe gelassen: Symbol %s, \"%s\". Notiert, damit die Liste gezielt erweitert werden kann.",

    -- Modules/Looting.lua
    ["Fast Auto Loot"] = "Schneller Autoloot",
    ["Loots without the delay, and can roll greed on greens."]
        = "Lootet ohne Verzögerung und kann bei grünen Items Gier würfeln.",
    ["Loot without the delay"] = "Ohne Verzögerung looten",
    ["Takes every slot at once instead of waiting for the client to process them one by one. It never decides whether to loot: that stays with your own auto loot setting and its modifier key, and this does nothing at all when the client was not going to loot."]
        = "Nimmt alle Plätze auf einmal, statt darauf zu warten, dass der Client sie einzeln verarbeitet. Ob gelootet wird, entscheidet es nie: Das bleibt bei deiner Einstellung für Autoloot und ihrer Taste, und es tut gar nichts, wenn der Client nicht looten wollte.",
    ["Turn on Auto Loot"] = "Autoloot einschalten",
    ["Turns on the game's own auto loot."] = "Schaltet das Autoloot des Spiels ein.",
    ["Rolling"] = "Würfeln",
    ["Roll greed on green items"] = "Bei grünen Items Gier würfeln",
    ["Rolls greed on every green item automatically."]
        = "Würfelt bei jedem grünen Item automatisch Gier.",
    ["Say what was rolled on"] = "Melden, worauf gewürfelt wurde",
    ["Shows the item in your own chat. Nothing is sent to the group."]
        = "Eine Zeile mit dem Item in deinem eigenen Chat. An die Gruppe geht nichts.",
    ["Looting: this client offers no way to set a CVar."]
        = "Schneller Autoloot: Dieser Client bietet keinen Weg, eine CVar zu setzen.",
    ["The client's auto loot is already on, nothing changed."]
        = "Autoloot ist bereits aktiv.",
    ["Looting: the client refused to set autoLootDefault."]
        = "Schneller Autoloot: Der Client hat sich geweigert, autoLootDefault zu setzen.",
    ["Looting: autoLootDefault was set but does not report that it is on. Check the client's own options."]
        = "Schneller Autoloot: autoLootDefault wurde gesetzt, liest sich aber nicht als an. Sieh in den Optionen des Clients nach.",
    ["The client's auto loot is now on. That is a client setting, so it stays on whether or not this addon is running."]
        = "Autoloot ist jetzt aktiv. Das ist eine Einstellung des Spiels und bleibt auch ohne dieses Addon an.",
    ["Looting: the loot API is missing on this build."]
        = "Schneller Autoloot: Die Schnittstelle zum Looten fehlt in dieser Clientversion.",
    ["Looting: the roll API is missing on this build."]
        = "Schneller Autoloot: Die Schnittstelle zum Würfeln fehlt in dieser Clientversion.",
    ["Rolled greed on %s."] = "Gier auf %s gewürfelt.",
    ["a green item"] = "ein grünes Item",

    -- Modules/AutoSellGray.lua
    ["Sell Gray Items"] = "Graue Items verkaufen",
    ["Sells gray items at any merchant."] = "Verkauft graue Items bei jedem Händler.",
    ["Report earnings in chat"] = "Erlös im Chat melden",
    ["Shows the total value of sold items in chat."]
        = "Rechnet zusammen, was verkauft wurde, und gibt es im Chat aus.",
    ["While Shift is down, nothing is sold."] = "Solange Shift gedrückt ist, wird nichts verkauft.",
    ["Sold %d gray item for %s%s."] = "%d graues Item für %s%s verkauft.",
    ["Sold %d gray items for %s%s."] = "%d graue Items für %s%s verkauft.",
    ["at least "] = "mindestens ",
    ["%d gray item could not be sold."] = "%d graues Item ließ sich nicht verkaufen.",
    ["%d gray items could not be sold."] = "%d graue Items ließen sich nicht verkaufen.",
    ["%d gray item still had a sale pending and could not be checked. Reopen the merchant if it is still there."]
        = "Bei %d grauen Item lief der Verkauf noch, es ließ sich nicht prüfen. Öffne den Händler erneut, falls es noch da ist.",
    ["%d gray items still had a sale pending and could not be checked. Reopen the merchant if they are still there."]
        = "Bei %d grauen Items lief der Verkauf noch, sie ließen sich nicht prüfen. Öffne den Händler erneut, falls sie noch da sind.",
    ["AutoSellGray: C_Container.UseContainerItem or C_Timer is missing."]
        = "Graue Items verkaufen: C_Container.UseContainerItem oder C_Timer fehlt.",
    ["No gray items in your bags."] = "Keine grauen Items in deinen Taschen.",
    ["Found %d gray item, selling ..."] = "%d graues Item gefunden, verkaufe ...",
    ["Found %d gray items, selling ..."] = "%d graue Items gefunden, verkaufe ...",

    -- Modules/AutoRepair.lua
    ["Auto Repair"] = "Automatisch reparieren",
    ["Repairs your gear at merchants who offer repairs."] = "Repariert deine Ausrüstung bei Händlern, die das können.",
    ["Report the cost in chat"] = "Kosten im Chat melden",
    ["Shows the repair cost in chat."]
        = "Gibt im Chat aus, was die Reparatur gekostet hat.",
    ["While Shift is down, nothing is repaired."]
        = "Solange Shift gedrückt ist, wird nichts repariert.",
    ["AutoRepair: the repair API is missing on this build."]
        = "Automatisch reparieren: Die Schnittstelle zum Reparieren fehlt in dieser Clientversion.",
    ["This merchant does not repair."] = "Dieser Händler repariert nicht.",
    ["Nothing to repair."] = "Nichts zu reparieren.",
    ["Repair costs %s, waiting until you can afford it."]
        = "Die Reparatur kostet %s. Sie folgt, sobald du sie bezahlen kannst.",
    ["Repaired for %s."] = "Für %s repariert.",

    -- Modules/Interruptions.lua
    ["Declines duels and releases your spirit in battlegrounds. Both off until you say so."]
        = "Lehnt Duelle ab und releast auf Schlachtfeldern. Beides aus, bis du es einschaltest.",
    ["Decline duels"] = "Duelle ablehnen",
    ["Say who was declined"] = "Melden, wer abgelehnt wurde",
    ["Shows the name in your own chat, so you know whose duel request was declined."]
        = "Zeigt den Namen in deinem eigenen Chat, damit du weißt, wessen Duellanfrage abgelehnt wurde.",
    ["Battlegrounds"] = "Schlachtfelder",
    ["Release when you die in a battleground"] = "Nach dem Tod auf dem Schlachtfeld releasen",
    ["Battlegrounds only, never in the world, a dungeon or a raid. It does not release when the client offers you a resurrection of your own. This build cannot check for a soulstone, so the delay is the only safeguard."]
        = "Nur auf Schlachtfeldern, nie in der Welt, in einem Dungeon oder einem Raid. Es hält sich zurück, wenn der Client dir eine eigene Wiederbelebung anbietet, aber diese Clientversion kann nicht nach einem Seelenstein fragen, deshalb ist eine Wartezeit der einzige Schutz dafür.",
    ["Wait before releasing"] = "Vor dem Releasen warten",
    ["Time for a Druid to resurrect you or for a soulstone to do so. Zero releases immediately."]
        = "Zeit, in der dich ein Druide oder ein Seelenstein wiederbeleben kann. Null releast sofort.",
    ["at once"] = "sofort",
    ["%d s"] = "%d Sek.",
    ["While Shift is down, neither of these acts."] = "Solange Shift gedrückt ist, tut keins von beiden etwas.",
    ["Interruptions: CancelDuel is missing on this build."]
        = "Unterbrechungen: CancelDuel fehlt in dieser Clientversion.",
    ["Declined a duel from %s."] = "Ein Duell von %s abgelehnt.",
    ["somebody"] = "jemandem",
    ["Not releasing: the client is offering you a resurrection."]
        = "Kein Release: Der Client bietet dir eine Wiederbelebung an.",
    ["Interruptions: RepopMe is missing on this build."]
        = "Unterbrechungen: RepopMe fehlt in dieser Clientversion.",

    -- Modules/ErrorFilter.lua
    ["Error Filter"] = "Fehlerfilter",
    ["Hides the red spam errors."] = "Blendet die roten Fehlermeldungen aus.",
    ["Hide every error (not quest progress)"] = "Alle Fehler ausblenden (nicht den Questfortschritt)",
    ["Hides every red error. Quest progress and other yellow notices stay visible."]
        = "Blendet jede rote Fehlermeldung aus. Questfortschritt und andere gelbe Hinweise bleiben sichtbar.",
    ["Or Choose Them Individually"] = "Oder einzeln auswählen",
    ["These settings are ignored while every error is hidden. Turn off the switch above to choose errors individually."]
        = "Alle Fehler werden gerade ausgeblendet, deshalb gilt das hier nicht. Schalte „Alle Fehler ausblenden“ aus, um sie einzeln zu wählen.",
    ["Only used while the switch above is off."]
        = "Gilt nur, solange der Schalter für alle Fehler darüber aus ist.",
    ["Not enough mana / rage / energy"] = "Nicht genug Mana / Wut / Energie",
    ["Hides the errors about not enough mana, rage or energy."]
        = "Blendet die Fehlermeldungen über zu wenig Mana, Wut oder Energie aus.",
    ["Ability is not ready yet"] = "Fähigkeit ist noch nicht bereit",
    ["Hides the errors about an ability that is not ready yet."]
        = "Blendet die Fehlermeldungen über noch nicht bereite Fähigkeiten aus.",
    ["Out of range / too far away"] = "Außer Reichweite / Du bist zu weit entfernt",
    ["Hides the errors about being out of range or too far away."]
        = "Blendet die Fehlermeldungen über fehlende Reichweite oder zu große Entfernung aus.",
    ["Facing the wrong way"] = "Du siehst in die falsche Richtung",
    ["Hides the errors about facing the wrong way."]
        = "Blendet die Fehlermeldungen über die falsche Blickrichtung aus.",
    ["Invalid target"] = "Ungültiges Ziel",
    ["Hides the errors about an invalid target."]
        = "Blendet die Fehlermeldungen über ein ungültiges Ziel aus.",
    ["Log hidden messages to chat (for tuning)"] = "Ausgeblendetes im Chat zeigen (zum Einstellen)",
    ["Shows what was filtered, so you can tell whether something is being hidden that you wanted to see."]
        = "Zeigt, was gefiltert wurde, damit du merkst, ob etwas verschwindet, das du sehen wolltest.",
    ["ErrorFilter: this build reports no message color, so 'hide all' stays off to avoid swallowing quest progress. The individual categories still work."]
        = "Fehlerfilter: Diese Clientversion meldet keine Farbe der Meldungen, deshalb bleibt „alle ausblenden“ aus, damit kein Questfortschritt verschluckt wird. Die einzelnen Kategorien funktionieren weiter.",
    ["ErrorFilter: UIErrorsFrame has no filterable method on this build, nothing is hidden."]
        = "Fehlerfilter: UIErrorsFrame bietet in dieser Clientversion nichts zum Filtern, es wird nichts ausgeblendet.",
    ["ErrorFilter: this build knows none of the strings for %s, that category does nothing."]
        = "Fehlerfilter: Diese Clientversion kennt keinen der Texte für %s, diese Kategorie bleibt wirkungslos.",
    ["ErrorFilter is on, but every category is off. Nothing is being hidden."]
        = "Der Fehlerfilter ist an, aber jede Kategorie ist aus, es wird nichts ausgeblendet.",

    -- Modules/XPBarText.lua
    ["Experience Bar Text"] = "Text der Erfahrungsleiste",
    ["Keeps the experience bar text visible."] = "Hält den Text der Erfahrungsleiste sichtbar.",
    ["XPBarText: this build has no '%s' setting. Run /fplus discover: the experience bar's structure is saved in SavedVariables, so the fallback can be built against it."]
        = "Text der Erfahrungsleiste: Diese Clientversion hat keine Einstellung '%s'. Führe /fplus discover aus: Der Aufbau der Erfahrungsleiste landet in den SavedVariables, damit sich ein Ersatz danach bauen lässt.",
    ["Experience bar text is now always visible."] = "Der Text der Erfahrungsleiste ist jetzt immer sichtbar.",
    ["XPBarText: '%s' exists but could not be set."]
        = "Text der Erfahrungsleiste: '%s' existiert, ließ sich aber nicht setzen.",

    -- Modules/BagSlots.lua
    ["Free Bag Slots"] = "Freie Taschenplätze",
    ["Shows on the backpack how many bag slots are free. Special bags are shown separately."]
        = "Zeigt auf dem Rucksack an, wie viele Taschenplätze frei sind. Spezialtaschen werden getrennt angezeigt.",
    ["Show the total as well"] = "Auch die Gesamtzahl zeigen",
    ["Shows 14/80 instead of 14."] = "Zeigt 14/80 statt 14.",
    ["BagSlots: %s is missing on this build, so there is nowhere to write the count."]
        = "Freie Taschenplätze: %s fehlt in dieser Clientversion, die Zahl hat also keinen Platz.",
    ["BagSlots: C_Container does not offer the slot counts on this build."]
        = "Freie Taschenplätze: C_Container liefert in dieser Clientversion keine Platzzahlen.",

    -- Modules/Ammunition.lua
    ["Ammunition"] = "Munition",
    ["Ammunition Warning"] = "Munitionswarnung",
    ["For Hunters: shows how much ammunition you carry, on your quiver or backpack, with a short warning when it runs low."]
        = "Für Jäger: wie viel Munition du dabeihast, auf dem Köcher oder sonst auf dem Rucksack, und eine kurze Warnung, wenn sie knapp wird.",
    ["Hunters only"] = "Nur Jäger",
    ["Warn when it runs low"] = "Warnen, wenn sie knapp wird",
    ["A short red line in the upper middle of the screen, once when your ammunition drops below the amount set here. It appears again only after you restock above that amount. While this is on, the count itself turns red below the threshold."]
        = "Eine kurze rote Zeile oben in der Bildschirmmitte, einmal, sobald deine Munition unter die hier eingestellte Menge fällt. Sie kommt erst wieder, nachdem du über diese Menge aufgefüllt hast. Solange das an ist, wird auch die Zahl selbst unter dieser Menge rot.",
    ["Warn below"] = "Warnen unter",
    ["The ammunition count below which the warning appears."] = "Die Menge Munition, unter der die Warnung erscheint.",
    ["Play a sound with it"] = "Dazu einen Sound abspielen",
    ["Plays the sound selected below along with the red warning."]
        = "Den unten gewählten Sound, zusammen mit der roten Zeile.",
    ["Sound"] = "Sound",
    ["Picks one of the game's own sounds."] = "Wählt einen der Sounds, die das Spiel mitbringt.",
    ["Play the sound"] = "Sound abspielen",
    ["Plays the selected sound now."] = "Spielt den gewählten Sound jetzt ab.",
    ["Show the warning"] = "Warnung zeigen",
    ["Shows the warning once, with its sound when that is on."]
        = "Zeigt die Warnung einmal, mit ihrem Sound, wenn der an ist.",
    ["Ammunition: this client has no sound called %s."]
        = "Munition: Dieser Client hat keinen Sound namens %s.",
    ["Low on ammunition: %d left"] = "Munition wird knapp: noch %d",
    ["Adds a button for each kind of ammunition beside merchants who sell it. A click buys as many as your quiver or ammo pouch can still hold."]
        = "Neben einem Händler, der Pfeile oder Kugeln verkauft, ein Button für jede Sorte. Ein Klick kauft so viele, wie dein Köcher oder Munitionsbeutel noch fasst.",
    ["Skip the purchase dialog"] = "Kaufdialog überspringen",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Ammunition you cannot use yet always shows the dialog."]
        = "Ein Klick auf einen Button neben dem Händler kauft sofort und gibt im Chat aus, was gekauft wurde. Bei Munition, die du noch nicht benutzen kannst, erscheint der Dialog immer.",
    ["Fills your quiver with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Füllt deinen Köcher automatisch damit, sobald du einen Händler öffnest, der sie verkauft. Immer nur eine Sorte.",
    ["Fills your ammo pouch with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Füllt deinen Munitionsbeutel automatisch damit, sobald du einen Händler öffnest, der sie verkauft. Immer nur eine Sorte.",
    ["You cannot use these before level %d."] = "Du kannst sie erst ab Level %d benutzen.",
    ["You cannot use these yet."] = "Du kannst sie noch nicht benutzen.",
    ["Fill the Quiver"] = "Köcher auffüllen",
    ["Do not ask again"] = "Nicht mehr fragen",
    ["Switches on \"Skip the purchase dialog\" under Ammunition on the Gameplay page, where it can be switched off again."]
        = "Schaltet „Kaufdialog überspringen“ unter Munition auf der Seite Gameplay ein, wo es sich wieder ausschalten lässt.",
    ["Buy"] = "Kaufen",
    ["Fill the Ammo Pouch"] = "Munitionsbeutel auffüllen",
    ["Do you really want to buy %d %s to fill your quiver?"]
        = "Willst du wirklich %d %s kaufen, um deinen Köcher aufzufüllen?",
    ["Do you really want to buy %d %s to fill your ammo pouch?"]
        = "Willst du wirklich %d %s kaufen, um deinen Munitionsbeutel aufzufüllen?",
    ["Cost: %s"] = "Kosten: %s",
    ["No more will fit in your quiver."] = "In deinen Köcher passt nichts mehr.",
    ["No more will fit in your ammo pouch."] = "In deinen Munitionsbeutel passt nichts mehr.",
    ["The merchant has none left."] = "Der Händler hat keine mehr.",
    ["You cannot afford a stack."] = "Du kannst dir keinen Stapel leisten.",
    ["Buy this one in the merchant window."] = "Diese kaufst du im Händlerfenster.",
    ["Your quiver cannot hold bullets."] = "Dein Köcher nimmt keine Kugeln auf.",
    ["Your ammo pouch cannot hold arrows."] = "Dein Munitionsbeutel nimmt keine Pfeile auf.",
    ["Waiting for the previous purchase to complete."] = "Der vorherige Kauf ist noch nicht abgeschlossen.",
    ["Buying from the merchant failed: %s"] = "Kauf beim Händler fehlgeschlagen: %s",
    ["Reagents"] = "Reagenzien",
    ["Beside a merchant, a button for each reagent your class uses and, for Rogues, each poison. A click buys what is missing for the amounts set here."]
        = "Neben einem Händler ein Button für jedes Reagenz deiner Klasse und bei Schurken für jedes Gift. Ein Klick kauft, was zu den hier eingestellten Mengen fehlt.",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Ein Klick auf einen Button neben dem Händler kauft sofort und gibt im Chat aus, was gekauft wurde. Solange deine Klassenfähigkeiten keine Reagenzien vom Händler brauchen, erscheint bei Reagenzien immer der Dialog.",
    ["%s is active: your class abilities need no reagents bought from a merchant."]
        = "Mit %s brauchen deine Klassenfähigkeiten keine Reagenzien vom Händler.",
    ["How many you want to carry. A Shift click changes it by a full stack."]
        = "Wie viele du dabeihaben willst. Ein Klick mit Shift ändert die Zahl um einen vollen Stapel.",
    ["Changes how many you want to carry, the same amount as under Reagents on the Gameplay page."]
        = "Ändert, wie viele du dabeihaben willst. Es gilt dieselbe Menge wie unter Reagenzien auf der Seite Gameplay.",
    ["Your class uses no reagents."] = "Deine Klasse braucht keine Reagenzien.",
    ["None of your spells that require reagents have been learned yet."]
        = "Du hast noch keinen Zauber gelernt, der ein Reagenz braucht.",
    ["Not Relevant Right Now"] = "Aktuell nicht relevant",
    ["Auto Buy"] = "Autokauf",
    ["Buys what you tick for it whenever you open a merchant who sells it: reagents and poisons up to their amounts, arrows or bullets as many as fit in your quiver or ammo pouch."]
        = "Kauft, was du dafür anhakst, sobald du einen Händler öffnest, der es verkauft: Reagenzien und Gifte bis zur eingestellten Menge, Pfeile oder Kugeln so viele, wie in den Köcher oder Munitionsbeutel passen.",
    ["Skip the auto buy dialog"] = "Dialog beim Autokauf überspringen",
    ["Buys without asking first and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Kauft, ohne vorher zu fragen, und gibt im Chat aus, was gekauft wurde. Solange deine Klassenfähigkeiten keine Reagenzien vom Händler brauchen, erscheint bei Reagenzien immer der Dialog.",
    ["Buy Automatically"] = "Automatisch kaufen",
    ["Buy everything ticked for buying automatically?"]
        = "Alles kaufen, was für den Autokauf angehakt ist?",
    ["Switches on \"Skip the auto buy dialog\" under Auto Buy on the Gameplay page, where it can be switched off again."]
        = "Schaltet „Dialog beim Autokauf überspringen“ unter Autokauf auf der Seite Gameplay ein, wo es sich wieder ausschalten lässt.",
    ["Buys it automatically up to this amount whenever you open a merchant who sells it."]
        = "Kauft es automatisch bis zu dieser Zahl, sobald du einen Händler öffnest, der es verkauft.",
    ["You have %d of %d."] = "Du hast %d von %d.",
    ["Click to buy %d."] = "Ein Klick kauft %d.",
    ["Click to buy the ingredients for %d."] = "Ein Klick kauft die Zutaten für %d.",
    ["You have enough."] = "Du hast genug.",
    ["Just bought."] = "Gerade gekauft.",
    ["You cannot afford the ingredients."] = "Du kannst dir die Zutaten nicht leisten.",
    ["Buy the ingredients in the merchant window."] = "Die Zutaten kaufst du im Händlerfenster.",
    ["Buy Reagents"] = "Reagenzien kaufen",
    ["Do you really want to buy %d %s? You will then have %d."]
        = "Willst du wirklich %d %s kaufen? Dann hast du %d.",
    ["Buy Poison Ingredients"] = "Giftzutaten kaufen",
    ["Do you really want to buy the ingredients for %d %s?"]
        = "Willst du wirklich die Zutaten für %d %s kaufen?",
    ["Switches on \"Skip the purchase dialog\" under Reagents on the Gameplay page, where it can be switched off again."]
        = "Schaltet „Kaufdialog überspringen“ unter Reagenzien auf der Seite Gameplay ein, wo es sich wieder ausschalten lässt.",
    ["Bought %d %s for %s."] = "%d %s für %s gekauft.",
    ["Bought the ingredients for %d %s for %s."] = "Zutaten für %d %s für %s gekauft.",
    ["Click to buy %d and fill your quiver."] = "Ein Klick kauft %d und füllt deinen Köcher auf.",
    ["Click to buy %d and fill your ammo pouch."]
        = "Ein Klick kauft %d und füllt deinen Munitionsbeutel auf.",
    ["Bought %d %s for %s to fill your quiver."]
        = "%d %s für %s gekauft, um deinen Köcher aufzufüllen.",
    ["Bought %d %s for %s to fill your ammo pouch."]
        = "%d %s für %s gekauft, um deinen Munitionsbeutel aufzufüllen.",

    -- Modules/BagWindow.lua
    ["Movable Bag Windows"] = "Verschiebbare Taschenfenster",
    ["Hold Shift and drag the bag window by its title bar to move it, while your bags are combined into one window."]
        = "Halte Shift gedrückt und zieh das Taschenfenster an seiner Titelleiste, um es zu verschieben, solange deine Taschen in einem Fenster zusammengefasst sind.",
    ["Reset position"] = "Position zurücksetzen",
    ["Puts the bag window back where the game places it."]
        = "Setzt das Fenster auf die Standardposition zurück.",
    ["Bag window is back where the game places it."]
        = "Das Taschenfenster steht wieder an seiner Standardposition.",
    ["BagWindow: this build has no combined bag window, so there is nothing to move."]
        = "Verschiebbare Taschenfenster: Diese Clientversion hat kein gemeinsames Taschenfenster, es gibt also nichts zu verschieben.",

    -- Modules/MinimapButton.lua
    ["Minimap Button"] = "Button an der Minimap",
    ["A button on the edge of the minimap that opens this window. Drag it to move it along the edge."]
        = "Ein Button am Rand der Minimap, der dieses Fenster öffnet. Zieh ihn, um ihn am Rand entlang zu verschieben.",
    ["MinimapButton: this build has no minimap to put a button on. /fplus opens the settings."]
        = "Button an der Minimap: Diese Clientversion hat keine Minimap für einen Button. /fplus öffnet die Einstellungen.",
    ["Click to open or close the settings."] = "Ein Klick öffnet oder schließt die Einstellungen.",
    ["Drag to move this button along the edge of the minimap."]
        = "Ziehen verschiebt diesen Button am Rand der Minimap entlang.",

    -- Modules/MailAlts.lua
    ["Alts in the Mail Window"] = "Twinks im Postfenster",
    ["Adds a button to the mail window that lists your characters of this ruleset and faction, and fills in the one you pick."]
        = "Fügt dem Postfenster einen Button hinzu, der deine Charaktere dieses Realm-Typs und dieser Fraktion auflistet und den gewählten einträgt.",
    ["No other character of this ruleset and faction is known yet. Each one is added the next time it logs in."]
        = "Noch kein anderer Charakter dieses Realm-Typs und dieser Fraktion bekannt. Ein neuer Charakter kommt dazu, sobald er sich das nächste Mal einloggt.",
    ["Your Characters"] = "Deine Charaktere",
    ["Your characters of this ruleset and faction. A click fills in the name, the X at the end of a row deletes the character."]
        = "Deine Charaktere dieses Realm-Typs und dieser Fraktion. Ein Klick trägt den Namen ein, das X am Ende einer Zeile löscht den Charakter.",

    -- Modules/QuestZoneTracking.lua
    ["Track Zones in the Quest Log"] = "Zonen im Questlog tracken",
    ["Adds a checkbox to every zone in the quest log to track or untrack all its quests with one click."]
        = "Fügt jeder Zone im Questlog ein Kästchen hinzu, das mit einem Klick alle ihre Quests trackt oder nicht mehr trackt.",
    ["Track All"] = "Alle tracken",
    ["Untrack All"] = "Keine tracken",
    ["QuestZoneTracking: could not hook QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Zonen im Questlog tracken: QuestLogQuests_Update ließ sich nicht einhängen, das Questlog bekommt also keine Kästchen.",
    ["QuestZoneTracking: this client has no QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Zonen im Questlog tracken: Dieser Client hat kein QuestLogQuests_Update, das Questlog bekommt also keine Kästchen.",

    -- Modules/Diagnostics.lua
    ["Diagnostics"] = "Diagnose",
    ["Measures what this client's API offers. Use it to diagnose problems: the report lists what exists and what does not, for whoever fixes the addon."]
        = "Misst, was die Schnittstelle dieses Clients bietet. Zur Diagnose von Problemen: Der Bericht listet, was es gibt und was nicht, für den, der das Addon repariert.",
    ["Keep the report in the saved settings"] = "Bericht in den Einstellungen speichern",
    ["Saves the report, about nine hundred lines, in your saved settings. /fplus diag print reads the current one without saving it."]
        = "Legt den Bericht, rund neunhundert Zeilen, in den gespeicherten Einstellungen ab. /fplus diag print liest den aktuellen, ohne ihn zu speichern.",

    -- -----------------------------------------------------------------------
    -- Design
    -- -----------------------------------------------------------------------

    -- Modules/Theme.lua
    ["Sets the appearance of the ForeverPlus windows."] = "Wie die Fenster von ForeverPlus aussehen.",
    ["Color scheme"] = "Farbschema",
    ["Applies to the ForeverPlus windows only."] = "Gilt nur für die Fenster von ForeverPlus.",
    ["Show switches in your class color"] = "Schalter in deiner Klassenfarbe anzeigen",
    ["The switches that are on and the open tab take the color of this character's class, in every color scheme."]
        = "Eingeschaltete Schalter und der offene Reiter nehmen die Farbe der Klasse dieses Charakters an, in jedem Farbschema.",
    ["Background opacity"] = "Deckkraft des Hintergrunds",
    ["Sets the background opacity of the ForeverPlus windows, the info bar and the addon's tooltips. At 100 percent, it matches the color scheme."]
        = "Der Hintergrund der Fenster von ForeverPlus, der Infoleiste und der eigenen Tooltips des Addons. Bei 100 Prozent der des Farbschemas.",
    ["Text size"] = "Textgröße",
    ["Sets the text size as a percentage of the game's text size."] = "Ein Prozentsatz der Textgröße des Spiels.",

    -- Core/Theme.lua
    ["Midnight"] = "Mitternacht",
    ["Slate"] = "Schiefer",
    ["High contrast"] = "Hoher Kontrast",
    ["Horde"] = "Horde",
    ["Gilded"] = "Vergoldet",
    ["Autumn"] = "Herbst",
    ["Jade"] = "Jade",
    ["Arctic"] = "Arktis",
    ["Azure"] = "Azur",
    ["Alliance"] = "Allianz",
    ["Sunset"] = "Abendrot",

    -- -----------------------------------------------------------------------
    -- Profiles
    -- -----------------------------------------------------------------------

    -- Modules/Profiles.lua
    ["in use"] = "aktiv",
    ["The buttons below act on: |cffffffff%s|r"] = "Die Buttons unten wirken auf: |cffffffff%s|r",
    ["... and %d more, see /fplus profile"] = "... und %d weitere, siehe /fplus profile",
    ["Use"] = "Verwenden",
    ["Now using %s."] = "%s wird jetzt verwendet.",
    ["Reset"] = "Zurücksetzen",
    ["Sure?"] = "Sicher?",
    ["%s is back to its defaults."] = "%s steht wieder auf den Standardwerten.",
    ["%s deleted."] = "%s gelöscht.",
    ["Name for a new or renamed profile"] = "Name für ein neues oder umbenanntes Profil",
    ["New"] = "Neu",
    ["Created %s."] = "%s erstellt.",
    ["Copy"] = "Kopieren",
    ["%s copied from %s."] = "%s aus %s kopiert.",
    ["Rename"] = "Umbenennen",
    ["%s is now %s."] = "%s heißt jetzt %s.",
    ["Export"] = "Exportieren",
    ["Export profile"] = "Profil exportieren",
    ["%s, %d characters"] = "%s, %d Zeichen",
    ["Import"] = "Importieren",
    ["Import profile"] = "Profil importieren",
    ["Paste a string, then press Import"] = "Text einfügen, dann auf Importieren drücken",
    ["Import failed: %s"] = "Import fehlgeschlagen: %s",
    ["Imported as %s, %d skipped."] = "Als %s importiert, %d übersprungen.",
    ["Imported as %s."] = "Als %s importiert.",
    ["%d profile now."] = "Jetzt %d Profil.",
    ["%d profiles now."] = "Jetzt %d Profile.",

    -- Core/Config.lua
    ["Settings were written by a newer version (format %d, this build reads %d). Leaving them unchanged."]
        = "Die Einstellungen stammen von einer neueren Version (Format %d, diese Version liest %d). Sie bleiben, wie sie sind.",
    ["No way to convert settings from format %d to %d."]
        = "Keine Möglichkeit, die Einstellungen von Format %d auf %d zu bringen.",
    ["migration %d to %d"] = "Umstellung von %d auf %d",
    ["Settings stayed at format %d."] = "Die Einstellungen bleiben bei Format %d.",
    ["Settings converted to format %d."] = "Einstellungen auf Format %d umgestellt.",
    ["No character given"] = "Kein Charakter angegeben",
    ["That is the character you are playing"] = "Das ist der Charakter, den du gerade spielst",
    ["Could not identify this character, so %s is in use. A /reload should fix it."]
        = "Dieser Charakter ließ sich nicht erkennen, deshalb ist %s aktiv. Ein /reload sollte das beheben.",
    ["%s is off. Takes effect after /reload."] = "%s ist aus. Wirkt nach einem /reload.",
    ["Unknown module: %s"] = "Unbekanntes Modul: %s",
    ["%s: /reload needed for the change to take effect."]
        = "%s: Die Änderung wirkt erst nach einem /reload.",
    ["A profile needs a name"] = "Ein Profil braucht einen Namen",
    ["Profile names are limited to %d characters"] = "Profilnamen haben höchstens %d Zeichen",
    ["A profile name cannot contain a pipe or a control character"]
        = "Ein Profilname darf keinen senkrechten Strich und kein Steuerzeichen enthalten",
    ["A profile called %s already exists"] = "Es gibt schon ein Profil namens %s",
    ["No profile called %s exists"] = "Es gibt kein Profil namens %s",
    ["%s is the only profile. Reset it instead of deleting it"]
        = "%s ist das einzige Profil: Setz es zurück, statt es zu löschen",
    ["Profile %s takes effect when you leave combat."]
        = "Das Profil %s wirkt, sobald du den Kampf verlässt.",
    ["Profile %s disappeared before it could be applied."]
        = "Das Profil %s ist verschwunden, bevor es angewendet werden konnte.",
    ["%s: /reload needed before its new settings apply."]
        = "%s: Die neuen Einstellungen wirken erst nach einem /reload.",
    ["Profile: %s"] = "Profil: %s",
    ["that string is not a ForeverPlus profile"] = "dieser Text ist kein Profil von ForeverPlus",
    ["that profile has no readable settings in it"]
        = "dieses Profil enthält keine lesbaren Einstellungen",
    ["import migration %d to %d"] = "Umstellung beim Import von %d auf %d",
    ["the settings being saved are not the ones in this table. The import was undone to prevent silent data loss. Please report this"]
        = "die Tabelle der Einstellungen ist nicht die, die gespeichert wird: Der Import wurde rückgängig gemacht, um einen unbemerkten Datenverlust zu verhindern. Bitte melde das",
    ["the profile was not saved successfully. Please report this"]
        = "das Profil wurde nicht erfolgreich gespeichert. Bitte melde das",

    -- Core/Serialize.lua
    ["nested too deeply"] = "zu tief verschachtelt",
    ["the string ends before a value is complete"] = "der Text endet mitten in einem Wert",
    ["a string is missing its length"] = "bei einem Text fehlt die Längenangabe",
    ["a string has an invalid length"] = "ein Text hat eine ungültige Längenangabe",
    ["a string extends beyond the end of the data"] = "ein Text läuft über das Ende hinaus",
    ["a number has no terminating marker"] = "bei einer Zahl fehlt das Abschlusszeichen",
    ["a number is not a number"] = "eine Zahl ist keine Zahl",
    ["a boolean is neither true nor false"] = "ein Wahrheitswert ist weder wahr noch falsch",
    ["a table is missing its size"] = "bei einer Tabelle fehlt die Größenangabe",
    ["a table has an invalid size"] = "eine Tabelle hat eine ungültige Größenangabe",
    ["a table specifies more entries than the string contains"]
        = "eine Tabelle gibt mehr Einträge an, als der Text enthält",
    ["unknown marker at position %d"] = "unbekannte Markierung an Stelle %d",
    ["nothing to import"] = "nichts zu importieren",
    ["this does not look like a ForeverPlus string"]
        = "das sieht nicht nach einem Text von ForeverPlus aus",
    ["this string is version %s, but this build reads %s"] = "dieser Text hat Version %s, gelesen wird %s",
    ["the string is damaged or incomplete (%d characters received). If you pasted it, it may have been truncated. Paste it again and check that the end matches"]
        = "der Text ist beschädigt oder unvollständig (%d Zeichen sind angekommen). Wenn er eingefügt wurde, ist er vielleicht abgeschnitten: Füge ihn erneut ein und prüfe, ob das Ende stimmt",
    ["unexpected text after the end of the data"]
        = "nach dem Ende der Daten folgt unerwarteter Text",

    -- -----------------------------------------------------------------------
    -- Info
    -- -----------------------------------------------------------------------

    -- Modules/Info.lua
    ["All rights reserved"] = "Alle Rechte vorbehalten",
    ["About"] = "Über",
    ["Author"] = "Autor",
    ["License"] = "Lizenz",
    ["Client"] = "Client",
    ["Contact"] = "Kontakt",
    ["Leave ideas and bug reports in the comments on CurseForge"]
        = "Schreib Anregungen und Fehler in die Kommentare auf CurseForge",
    ["Free to use, but not open source. You may not redistribute it, publish modified versions or reuse it in other addons. Provided without warranty. See the LICENSE file for the full terms."]
        = "Frei nutzbar, aber nicht quelloffen: Es darf nicht weiterverbreitet, verändert und veröffentlicht oder in anderen Addons wiederverwendet werden. Ohne Gewähr. Die vollständigen Bedingungen stehen in der Datei LICENSE.",

    -- -----------------------------------------------------------------------
    -- Info bar
    -- -----------------------------------------------------------------------

    -- Modules/InfoBar.lua
    ["Shows an info bar with your gold, durability, coordinates, latency and more."]
        = "Zeigt eine Infoleiste mit Gold, Haltbarkeit, Koordinaten, Latenz und mehr.",
    ["What It Shows"] = "Was sie zeigt",
    ["Allow reordering"] = "Reihenfolge ändern",
    ["Drag the entries above to change their order on the info bar."]
        = "Ziehe die Einträge darüber an die gewünschte Stelle, um ihre Reihenfolge auf der Infoleiste zu ändern.",
    ["Restore default order"] = "Reihenfolge zurücksetzen",
    ["Puts the entries back in their default order, here and on the info bar."]
        = "Stellt die Standardreihenfolge der Einträge wieder her, hier und auf der Infoleiste.",
    ["Time"] = "Uhrzeit",
    ["The time of day, as the game's own clock shows it."]
        = "Die Uhrzeit, wie die Uhr des Spiels sie anzeigt.",
    ["Shows"] = "Zeigt",
    ["Local time"] = "Ortszeit",
    ["Realm time"] = "Serverzeit",
    ["Choose local or realm time for both this bar and the minimap clock."]
        = "Wählt Ortszeit oder Serverzeit für diese Leiste und die Uhr an der Minimap.",
    ["Choose a 12 or 24 hour format for both this bar and the minimap clock."]
        = "Wählt 12 oder 24 Stunden für diese Leiste und die Uhr an der Minimap.",
    ["Format"] = "Format",
    ["24 hours"] = "24 Stunden",
    ["12 hours"] = "12 Stunden",
    ["Hearthstone"] = "Ruhestein",
    ["Where your Hearthstone takes you and how long until it is ready."]
        = "Wohin dein Ruhestein dich bringt und wie lange es dauert, bis er bereit ist.",
    ["Gold"] = "Gold",
    ["Adds up each selected character's gold as of their last login."]
        = "Zählt das Gold der unten gewählten Charaktere zusammen, so wie beim letzten Einloggen des jeweiligen Charakters.",
    ["Characters"] = "Charaktere",
    ["Whose gold the display adds up. Its list shows every character, the ones not counted grayed out. A ruleset is, for example, Normal or PvP."]
        = "Legt fest, wessen Gold die Anzeige zusammenzählt. Ihre Liste zeigt alle Charaktere, die nicht mitgezählten ausgegraut. Ein Realm-Typ ist zum Beispiel Normal oder PvP.",
    ["All"] = "Alle",
    ["This ruleset and faction"] = "Dieser Realm-Typ und diese Fraktion",
    ["Only this one"] = "Nur dieser",
    ["This ruleset"] = "Dieser Realm-Typ",
    ["Hide characters not counted"] = "Nicht gezählte Charaktere ausblenden",
    ["PvE"] = "PvE",
    ["PvP"] = "PvP",
    ["The list on hover leaves out the characters the display does not count."]
        = "Die Liste beim Darüberfahren lässt die Charaktere weg, die die Anzeige nicht zählt.",
    ["Shown as"] = "Darstellung",
    ["Shows one display for all bags, with a breakdown by bag type on hover, or one display per bag type, with its name on hover."]
        = "Eine Anzeige für alle Taschen, beim Darüberfahren nach Taschenart aufgeschlüsselt, oder eine Anzeige je Taschenart, deren Name beim Darüberfahren erscheint.",
    ["One display"] = "Eine Anzeige",
    ["A display per kind of bag"] = "Eine Anzeige je Taschenart",
    ["Ordinary bags"] = "Normale Taschen",
    ["Special bag"] = "Spezialtasche",
    ["Merchant's Favor"] = "Händlergunst",
    ["How much Merchant's Favor this character has. Red once it holds as much as the game allows."]
        = "Wie viel Händlergunst dieser Charakter hat. Rot, sobald er so viel hat, wie das Spiel erlaubt.",
    ["Honor Points"] = "Ehrenpunkte",
    ["How many Honor Points this character has. Red once it holds as much as the game allows."]
        = "Wie viele Ehrenpunkte dieser Charakter hat. Rot, sobald er so viele hat, wie das Spiel erlaubt.",
    ["Volume"] = "Lautstärke",
    ["Shows the game's master volume. Hover over the display to adjust it with a slider. The speaker is crossed out while sound is disabled or the volume is at 0%, and the figure turns red while sound is disabled."]
        = "Zeigt die Gesamtlautstärke des Spiels. Fahre mit der Maus über die Anzeige, um sie mit einem Regler anzupassen. Der Lautsprecher ist durchgestrichen, wenn der Sound deaktiviert ist oder die Lautstärke bei 0% liegt. Die Zahl wird rot, wenn der Sound deaktiviert ist.",
    ["Master Volume"] = "Gesamtlautstärke",
    ["Cooldowns"] = "Cooldowns",
    ["Shows the profession cooldowns and %s for all your characters. Hover over the icon to see the time remaining."]
        = "Zeigt die Berufscooldowns und %s für alle deine Charaktere. Fahre mit der Maus über das Symbol, um die verbleibende Zeit zu sehen.",
    ["Ready"] = "Bereit",
    ["%d d %d h"] = "%d T. %d Std.",
    ["%d h %d min"] = "%d Std. %d Min.",
    ["None of your characters has one yet."] = "Noch keiner deiner Charaktere hat einen.",
    ["Elemental Transmutes"] = "Elementare Transmutationen",
    ["Durability"] = "Haltbarkeit",
    ["Shows the lowest durability among your equipped items."]
        = "Der schlechteste Zustand eines Teils, das du trägst.",
    ["Coordinates"] = "Koordinaten",
    ["Where you are in the current zone."] = "Wo du in der aktuellen Zone bist.",
    ["Zone"] = "Zone",
    ["Shows your current zone and subzone in the minimap's colors."]
        = "Zeigt deine aktuelle Zone und Unterzone in den Farben der Minimap.",
    ["%s: %s"] = "%s: %s",
    ["Latency"] = "Latenz",
    ["Frames per second"] = "FPS",
    ["Placement"] = "Position",
    ["Position on screen"] = "Position auf dem Bildschirm",
    ["Back to the default near the top of the screen."]
        = "Zurück an die Standardposition oben am Bildschirm.",
    ["%d ms"] = "%d ms",
    ["%d fps"] = "%d FPS",
    ["No Hearthstone"] = "Kein Ruhestein",
    ["%sk xp/h"] = "%sk XP/h",
    ["%d xp/h"] = "%d XP/h",
    ["%s h to level"] = "%s Std. bis zum Level",
    ["%d min to level"] = "%d Min. bis zum Level",
    ["Info bar: this client build does not recognize currency %d, so %s stays empty."]
        = "Infoleiste: Diese Clientversion kennt keine Währung %d, %s bleibt deshalb leer.",
    ["Maximum"] = "Maximum",
    ["This session"] = "Diese Sitzung",
    ["Repair cost"] = "Reparaturkosten",
    ["Experience per hour"] = "XP pro Stunde",
    ["Time to the next level"] = "Zeit bis zum nächsten Level",
    ["Info bar is back at its default position."]
        = "Die Infoleiste ist wieder an ihrer Standardposition.",
    ["Info bar can be dragged. Press the button again when it is where you want it."]
        = "Die Infoleiste lässt sich jetzt verschieben. Drück den Button erneut, wenn sie richtig steht.",
    ["Info bar is fixed again."] = "Die Infoleiste ist wieder fest.",
    ["Click to use it"] = "Klick zum Benutzen",
    ["Info bar: this client build cannot provide %s, so those entries stay empty regardless of their settings."]
        = "Infoleiste: Diese Clientversion kann %s nicht liefern. Diese Einträge bleiben leer, egal wie sie eingestellt sind.",
    ["Use it with a click"] = "Per Klick benutzen",
    ["A click on the display uses your Hearthstone."]
        = "Ein Klick auf die Anzeige benutzt deinen Ruhestein.",
    ["Move it with Shift and drag"] = "Mit Shift und Ziehen verschieben",
    ["While Shift is held, you can drag the bar by any display, and clicking the Hearthstone does not use it."]
        = "Solange Shift gedrückt ist, lässt sich die Leiste an jeder ihrer Anzeigen ziehen. Ein Klick auf den Ruhestein in der Leiste benutzt ihn dann nicht.",

    -- -----------------------------------------------------------------------
    -- Tooltip
    -- -----------------------------------------------------------------------

    -- Modules/Tooltip.lua
    ["Extra lines in the game tooltip, and where the tooltip appears."]
        = "Zusätzliche Zeilen im Tooltip des Spiels, und in welcher Ecke er sitzt.",
    ["General"] = "Allgemein",
    ["Add extra information"] = "Zusätzliche Infos hinzufügen",
    ["The lines this addon adds. The arrangement and the position still work while this is off."]
        = "Die Zeilen, die dieses Addon selbst schreibt. Ausgeschaltet wirken Anordnung und Position weiter.",
    ["Not in use until you switch extra information on."]
        = "Nicht aktiv, bis du zusätzliche Infos einschaltest.",
    ["Layout"] = "Anordnung",
    ["How the lines are arranged"] = "Wie die Zeilen angeordnet sind",
    ["Blizzlike"] = "Blizzlike",
    ["One per line"] = "Eine pro Zeile",
    ["Compact"] = "Kompakt",
    ["Blizzlike keeps the client's lines in their original order and adds the rest underneath. One per line gives every entry its own line. Compact pairs entries up."]
        = "Blizzlike behält die Zeilen des Clients in ihrer Reihenfolge und hängt den Rest darunter. Eine pro Zeile gibt jedem Eintrag eine eigene Zeile. Kompakt fasst sie paarweise zusammen.",
    ["Where it appears"] = "Wo er erscheint",
    ["Default"] = "Standard",
    ["Top left"] = "Oben links",
    ["Top right"] = "Oben rechts",
    ["Bottom left"] = "Unten links",
    ["Default leaves the tooltip where the client puts it. The other options pin it to the chosen corner, and it grows inward."]
        = "Standard lässt den Tooltip, wo der Client ihn hinsetzt. Die anderen drei heften ihn an diese Ecke, und er wächst nach innen.",
    ["Lines on a Unit"] = "Zeilen bei Einheiten",
    ["Level"] = "Level",
    ["Shows a player's or creature's level. Under Blizzlike, it covers the whole line the client writes, including race."]
        = "Zeigt das Level eines Spielers oder einer Kreatur. Bei Blizzlike gilt es für die ganze Zeile des Clients, samt Volk.",
    ["Class"] = "Klasse",
    ["Shows a player's class."] = "Die Klasse eines Spielers.",
    ["Race"] = "Volk",
    ["Shows a player's race or a creature's type."]
        = "Das Volk eines Spielers oder welche Art Kreatur es ist.",
    ["Blizzlike includes race on the level line, so the Level switch controls both."]
        = "Blizzlike schreibt das Volk in die Levelzeile, der Schalter für Level gilt deshalb für beides.",
    ["Faction"] = "Fraktion",
    ["Which side they are on."] = "Auf welcher Seite sie stehen.",
    ["Guild"] = "Gilde",
    ["The guild a player belongs to."] = "Die Gilde eines Spielers.",
    ["Guild rank"] = "Gildenrang",
    ["The rank they hold there."] = "Ihr Rang dort.",
    ["Target"] = "Ziel",
    ["Shows who they have targeted, or \"you\" if it is you."]
        = "Wen sie ausgewählt haben. Zeigt „Du“, wenn du es bist.",
    ["Class color on the name"] = "Klassenfarbe für den Namen",
    ["Colors a player's name by their class."]
        = "Färbt den Namen eines Spielers in seiner Klassenfarbe.",
    ["Lines on an Item or Spell"] = "Zeilen bei Items und Zaubern",
    ["What it sells for"] = "Verkaufswert",
    ["Shows what a vendor pays for the item and the value of the whole stack."]
        = "Was ein Händler zahlt, und was der ganze Stapel wert ist.",
    ["Item and spell ids"] = "IDs von Items und Zaubern",
    ["Shows the IDs of an item, spell or creature."]
        = "Die Nummern hinter einem Item, einem Zauber oder einer Kreatur.",
    ["Lines on Herbs, Veins and Corpses"] = "Zeilen bei Kräutern, Vorkommen und Leichen",
    ["Skill needed to gather"] = "Benötigter Skill zum Sammeln",
    ["Shows the Herbalism, Mining or Skinning skill required for herbs, veins and corpses, in the color the game uses for your skill level."]
        = "Der Skill in Kräuterkunde, Bergbau oder Kürschnerei, den ein Kraut, ein Vorkommen oder eine Leiche verlangt, in der Farbe, die das Spiel deinem Skill dort gibt.",
    ["Sells for (%d)"] = "Verkaufswert (%d)",
    ["Sells for"] = "Verkaufswert",
    ["Item"] = "Item",
    ["Spell"] = "Zauber",
    ["Requires %s"] = "Benötigt %s",
    ["you"] = "Du",
    ["Tooltip: TooltipDataProcessor is unavailable in this client build, so no lines can be added. Placement still works."]
        = "Tooltip: TooltipDataProcessor fehlt, in dieser Clientversion lassen sich also keine Zeilen hinzufügen. Die Position funktioniert weiter.",
    ["Tooltip: GameTooltip_SetDefaultAnchor is unavailable in this client build, so the corner setting has no effect."]
        = "Tooltip: GameTooltip_SetDefaultAnchor fehlt, die Einstellung der Ecke wirkt in dieser Clientversion deshalb nicht.",

    -- Data/Gathering.lua
    ["Herbalism"] = "Kräuterkunde",
    ["Mining"] = "Bergbau",
    ["Skinning"] = "Kürschnerei",

    -- -----------------------------------------------------------------------
    -- Consumables
    -- -----------------------------------------------------------------------

    -- Modules/Consumables.lua
    ["Warns when a selected consumable effect is missing or about to expire."]
        = "Warnt, wenn die Wirkung eines ausgewählten Consumables fehlt oder bald ausläuft.",
    ["Main Hand"] = "Mainhand",
    ["Off Hand"] = "Offhand",
    ["%d min"] = "%d Min.",
    ["%d:%02d min"] = "%d:%02d Min.",
    ["Show the remaining time"] = "Verbleibende Zeit anzeigen",
    ["Icon size"] = "Symbolgröße",
    ["Conditions"] = "Bedingungen",
    ["Warn at"] = "Warnen ab",
    ["The remaining time at which a consumable warning appears."]
        = "Restlaufzeit, ab der die Warnung für Consumables erscheint.",
    ["Measurement"] = "Messung",
    ["Print what was recorded"] = "Aufgezeichnetes ausgeben",
    ["Prints everything the probe recorded during this session in chat. The data is also saved and restored after a reload."]
        = "Alles, was die Sonde in dieser Sitzung gesehen hat, als Chatzeilen. Es steht auch in der gespeicherten Datei, aus der es nach einem Reload gelesen wird.",
    ["Consumables: C_Timer.NewTicker is missing, so the countdown only updates when something changes."]
        = "Consumables: C_Timer.NewTicker fehlt, der Countdown aktualisiert sich deshalb nur, wenn sich etwas ändert.",
    ["Weapon Coatings"] = "Steine und Öle",

    -- Data/Consumables.lua
    ["Weapon Oil"] = "Waffenöl",
    ["Sharpening Stone"] = "Wetzstein",
    ["Weightstone"] = "Gewichtsstein",
    ["Food"] = "Essen",
    ["Any Food Buff"] = "Jeder Essensbuff",
    ["Watches for a food buff, whichever food it came from: warns when none is on you, and before the one you have runs out."]
        = "Achtet auf einen Essensbuff, egal von welchem Essen: Warnt, wenn keiner auf dir ist, und bevor deiner ausläuft.",
    ["Strength"] = "Stärke",
    ["Agility"] = "Beweglichkeit",
    ["Armor"] = "Rüstung",
    ["Stamina"] = "Ausdauer",
    ["Health Regeneration"] = "Gesundheitsregeneration",
    ["Mana Regeneration"] = "Manaregeneration",
    ["Spell Power"] = "Zaubermacht",
    ["Fire Power"] = "Feuermacht",
    ["Frost Power"] = "Frostmacht",
    ["Shadow Power"] = "Schattenmacht",
    ["Resistance"] = "Widerstand",
    ["Blasted Lands and Zandalar"] = "Verwüstete Lande und Zandalar",
    ["Attack Power"] = "Angriffskraft",
    ["Juju"] = "Juju",
    ["Hit Chance"] = "Trefferchance",
    ["Alcohol"] = "Alkohol",
    ["Other"] = "Sonstiges",
    ["Flask"] = "Flask",
    ["Intellect"] = "Intelligenz",
    ["Spirit"] = "Willenskraft",

    -- Core/Warnings.lua
    ["Gray"] = "Grau",
    ["Original colors"] = "Originalfarben",
    ["Dimmed"] = "Abgedunkelt",
    ["Alert red"] = "Alarmrot",
    ["Scheme color"] = "Farbe des Schemas",
    ["new"] = "neu",

    -- Modules/Consumables.lua, names for an item or spell the client cannot name
    ["Item %s"] = "Item %s",
    ["Spell %s"] = "Zauber %s",

    -- Modules/Consumables.lua, a row whose item is not loaded
    ["Item %s, not loaded yet"] = "Item %s, noch nicht geladen",
    ["Nothing to look up"] = "Nichts nachzuschlagen",

    -- -----------------------------------------------------------------------
    -- Buffs
    -- -----------------------------------------------------------------------

    -- Modules/BuffExpiry.lua
    ["Warns when a long buff is running out."] = "Warnt, wenn ein langer Buff ausläuft.",
    ["Your own buffs"] = "Deine eigenen Buffs",
    ["Armor spells, shouts, Inner Fire: anything you cast on yourself that runs out."]
        = "Rüstungszauber, Rufe, Inneres Feuer: alles, was du auf dich selbst wirkst und was ausläuft.",
    ["Group buffs"] = "Gruppenbuffs",
    ["Buffs you also put on other people. The icon shows how many nearby players are missing the buff, except in combat."]
        = "Buffs, die du auch anderen gibst. Das Symbol zeigt, wie vielen in deiner Nähe er fehlt, außer im Kampf.",
    ["Weapon imbues and poisons"] = "Waffenverzauberungen und Gifte",
    ["Warnings about the imbues, poisons, Firestones and Spellstones on your weapons."]
        = "Warnungen zu Waffenverzauberungen, Giften, Feuersteinen und Zaubersteinen auf deinen Waffen.",
    ["Tracking"] = "Tracking",
    ["Shows an icon whenever none of the tracking abilities you selected in the Tracking section is active. Either gathering tracking ability is enough."]
        = "Ein Symbol, sobald keins der Trackings läuft, die du im Abschnitt Tracking ausgewählt hast. Eins der beiden Sammeltrackings genügt.",
    ["Warn short buffs at"] = "Kurze Buffs: Warnung ab",
    ["Applies to every buff lasting under 10 minutes."]
        = "Gilt für jeden Buff, der kürzer als 10 Minuten hält.",
    ["Warn medium buffs at"] = "Mittlere Buffs: Warnung ab",
    ["Applies to every buff lasting 10 to 29 minutes."]
        = "Gilt für jeden Buff, der 10 bis 29 Minuten hält.",
    ["Warn long buffs at"] = "Lange Buffs: Warnung ab",
    ["Applies to every buff lasting 30 minutes or more."]
        = "Gilt für jeden Buff, der 30 Minuten oder länger hält.",
    ["Warn while mounted"] = "Beim Reiten warnen",
    ["Off: no warnings while you are mounted."] = "Aus: keine Warnungen, solange du reitest.",
    ["Warn in a rested area"] = "In Städten und Gasthäusern warnen",
    ["Off: no warnings in cities and inns."] = "Aus: keine Warnungen in Städten und Gasthäusern.",
    ["Buffs from others in dungeons"] = "Buffs von anderen in Dungeons",
    ["Warnings about a buff another class in your group could give you, while you are in a dungeon."]
        = "Warnungen zu einem Buff, den dir eine andere Klasse in deiner Gruppe geben könnte, solange du in einem Dungeon bist.",
    ["Buffs from others in raids"] = "Buffs von anderen in Raids",
    ["Warnings about a buff another class in your group could give you, while you are in a raid."]
        = "Warnungen zu einem Buff, den dir eine andere Klasse in deiner Gruppe geben könnte, solange du in einem Raid bist.",
    ["Buffs from others in the open world"] = "Buffs von anderen in der offenen Welt",
    ["Warnings about a buff another class in your group could give you, anywhere outside a dungeon, a raid or a battleground."]
        = "Warnungen zu einem Buff, den dir eine andere Klasse in deiner Gruppe geben könnte, überall außerhalb von Dungeons, Raids und Schlachtfeldern.",
    ["Count group members within"] = "Gruppenmitglieder zählen im Umkreis von",
    ["%d yd"] = "%d m",
    ["Group members farther away are not counted for buffs they could give you or buffs you could give them."]
        = "Gruppenmitglieder, die weiter weg sind, zählen weder für Buffs, die sie dir geben könnten, noch für Buffs, die du ihnen geben könntest.",
    ["General Warnings"] = "Allgemeine Warnungen",
    ["Combat Buffs"] = "Kampfbuffs",
    ["Buffs on You Right Now"] = "Aktuelle Buffs auf dir",
    ["During combat, the client cannot check whether %s is active on you. The addon can only track it from your own casts. If another player casts it on you, it may be reported as missing until combat ends. This message is shown once per character."]
        = "Im Kampf kann der Client nicht prüfen, ob %s auf dir aktiv ist. Das Addon kann den Buff nur über deine eigenen Zauber verfolgen. Wirkt ihn ein anderer Spieler auf dich, kann er bis zum Ende des Kampfes als fehlend gemeldet werden. Diese Meldung erscheint einmal pro Charakter.",
    ["BuffExpiry: C_Timer.NewTicker is missing, so the countdown only updates when a buff changes."]
        = "Buffs: C_Timer.NewTicker fehlt, der Countdown aktualisiert sich deshalb nur, wenn sich ein Buff ändert.",
    ["missing"] = "fehlt",
    ["upgrade"] = "höherer Rang",
    ["showing"] = "angezeigt",
    ["handout"] = "für andere",
    ["waiting"] = "wartet",
    ["unavailable"] = "nicht verfügbar",
    ["off"] = "aus",
    ["%s of %s"] = "%s von %s",
    ["... and %d more"] = "... und %d weitere",
    ["In combat, these are the remaining times recorded just before the fight, continuing to count down. Buffs cast on you by other players appear after combat ends."]
        = "Im Kampf stehen hier die Zeiten von kurz vor dem Kampf, genau heruntergezählt. Ein Buff, den dir jemand anderes gibt, erscheint erst nach dem Kampf.",
    ["No timed buffs on you."] = "Keine zeitlich begrenzten Buffs auf dir.",
    ["(timer only)"] = "(nur Timer)",
    ["(own class only)"] = "(nur eigene Klasse)",
    ["(not trained)"] = "(nicht gelernt)",
    ["(not your race)"] = "(nicht dein Volk)",
    ["Class Buffs"] = "Klassenbuffs",
    ["(you)"] = "(du)",
    ["Track on yourself"] = "Auf dir selbst tracken",
    ["Also tracks this buff on you."] = "Trackt den Buff auch auf dir selbst.",
    ["Track on friendly targets"] = "Auf freundlichen Zielen tracken",
    ["%d player"] = "%d Spieler",
    ["%d players"] = "%d Spieler",
    ["How many other players must have this buff active, not counting you. Outside combat, the icon shows how many are still missing it."]
        = "Auf wie vielen anderen Spielern dieser Buff bleiben soll, dich nicht mitgezählt. Außerhalb des Kampfes zeigt das Symbol, wie vielen er noch fehlt.",
    ["Track on every group or raid member"]
        = "Auf allen Gruppen- oder Raidmitgliedern tracken",
    ["Shows an icon whenever your pet is not happy, with a red border when it becomes unhappy. The icon is hidden during combat."]
        = "Ein Symbol, solange dein Pet nicht glücklich ist, mit rotem Rand, sobald es unglücklich ist. Nicht im Kampf.",
    ["Tracks this buff on every member of your group or raid instead of using the number above. Outside combat, the icon shows how many are still missing it."]
        = "Trackt den Buff auf allen Mitgliedern deiner Gruppe oder deines Raids statt auf der Anzahl darüber. Außerhalb des Kampfes zeigt das Symbol, wie vielen er noch fehlt.",
    ["Only warn in combat"] = "Nur im Kampf warnen",
    ["Warns about this buff only during a fight."]
        = "Warnungen zu diesem Buff nur während eines Kampfes.",

    -- Data/Buffs.lua, a name for when the client gives none
    ["Mark of the Wild"] = "Mal der Wildnis",
    ["Thorns"] = "Dornen",
    ["Aspect of the Wild"] = "Aspekt der Wildnis",
    ["Trueshot Aura"] = "Aura des Volltreffers",
    ["Aspect"] = "Aspekt",
    ["Arcane Intellect"] = "Arkane Intelligenz",
    ["Armor Spell"] = "Rüstungszauber",
    ["Blessing"] = "Segen",
    ["Aura"] = "Aura",
    ["Righteous Fury"] = "Zorn der Gerechtigkeit",
    ["Seal"] = "Siegel",
    ["Power Word: Fortitude"] = "Machtwort: Seelenstärke",
    ["Divine Spirit"] = "Göttlicher Willen",
    ["Shadow Protection"] = "Schattenschutz",
    ["Inner Fire"] = "Inneres Feuer",
    ["Touch of Weakness"] = "Berührung der Schwäche",
    ["Shadowguard"] = "Schattenwache",
    ["Main Hand Poison"] = "Gift auf der Mainhand",
    ["Off Hand Poison"] = "Gift auf der Offhand",
    ["Shield Spell"] = "Schildzauber",
    ["Main Hand Imbue"] = "Waffenverzauberung der Mainhand",
    ["Off Hand Imbue"] = "Waffenverzauberung der Offhand",
    ["Demon Armor"] = "Dämonenrüstung",
    ["Firestone or Spellstone"] = "Feuerstein oder Zauberstein",
    ["Amplify Magic"] = "Magie verstärken",
    ["Dampen Magic"] = "Magie dämpfen",
    ["Water Breathing"] = "Wasseratmung",
    ["Water Walking"] = "Wasserwandeln",
    ["Unending Breath"] = "Unendlicher Atem",
    ["Detect Invisibility"] = "Unsichtbarkeit entdecken",
    ["Pet Happiness"] = "Zufriedenheit des Pets",
    ["Battle Shout"] = "Schlachtruf",

    -- Data/Tracking.lua
    ["Find Minerals"] = "Mineraliensuche",
    ["Find Herbs"] = "Kräutersuche",
    ["Find Treasure"] = "Schatzsuche",

    -- -----------------------------------------------------------------------
    -- Chat
    -- -----------------------------------------------------------------------

    -- Modules/Chat.lua
    ["%d min %d s"] = "%d Min. %d Sek.",
    ["Controls the chat's appearance, its surrounding buttons, and notification sounds."]
        = "Steuert das Aussehen des Chats, die Buttons rundherum und die Sounds bei Nachrichten.",
    ["Names"] = "Namen",
    ["How names are written"] = "Wie Namen geschrieben werden",
    ["Full name"] = "Vollständiger Name",
    ["Initial and surname"] = "Initiale und Nachname",
    ["First name only"] = "Nur Vorname",
    ["Surname only"] = "Nur Nachname",
    ["Initials"] = "Initialen",
    ["Shortens the name of the sender of each line. Hover over a shortened name to see the full name. Whispers are always addressed to the full name."]
        = "Kürzt den Namen dessen, der eine Zeile geschrieben hat. Mit der Maus über einem gekürzten Namen siehst du ihn ganz, und ein Flüstern geht immer an den vollen Namen.",
    ["Race icon before the name"] = "Volkssymbol vor dem Namen",
    ["The race of whoever wrote a line, as an icon in front of the name."]
        = "Das Volk dessen, der eine Zeile geschrieben hat, als Symbol vor dem Namen.",
    ["Class icon before the name"] = "Klassensymbol vor dem Namen",
    ["The class of whoever wrote a line, as an icon in front of the name."]
        = "Die Klasse dessen, der eine Zeile geschrieben hat, als Symbol vor dem Namen.",
    ["%d px"] = "%d px",
    ["Not in use until you switch on a race or class icon."] = "Nicht aktiv, bis du das Volkssymbol oder das Klassensymbol einschaltest.",
    ["Sets the size of both icons. Lines already in the chat keep the size they had when they arrived."]
        = "Wie groß beide Symbole gezeichnet werden. Zeilen, die schon im Chat stehen, behalten ihre Größe.",
    ["Channel Labels"] = "Channelkürzel",
    ["Use the labels below"] = "Die Kürzel unten verwenden",
    ["Off: channels and groups appear in chat as the game writes them. Your labels below are kept."]
        = "Aus: Channels und Gruppen erscheinen im Chat wie im Spiel üblich. Deine Kürzel unten bleiben gespeichert.",
    ["Channel labels"] = "Channelkürzel",
    ["Not in use until you switch the labels on."]
        = "Nicht aktiv, bis du die Kürzel einschaltest.",
    ["A numbered channel uses its number as its label unless you enter a different one. Labels move with their channels when you reorder them. A number entered in a field always refers to that channel's number. An empty field leaves the label as the client writes it. The square beside each field shows that chat's color."]
        = "Ein nummerierter Channel erscheint als seine Nummer, solange sein Feld nichts anderes sagt, und ein Kürzel wandert mit seinem Channel, wenn die Channels umsortiert werden. Eine Zahl in einem Feld steht immer für die eigene Nummer des Channels. Ein leeres Feld lässt das Kürzel, wie der Client es schreibt. Das Quadrat daneben hat die Farbe dieses Chats.",
    ["Timestamps"] = "Zeitstempel",
    ["Timestamp format"] = "Format der Zeitstempel",
    ["None"] = "Keiner",
    ["03:27 PM"] = "03:27 PM",
    ["03:27:32 PM"] = "03:27:32 PM",
    ["Uses the client's timestamp setting. Changing it here also changes it in the game's options, and vice versa. Timestamps appear in square brackets."]
        = "Die Einstellung des Clients für Zeitstempel. Eine Änderung hier ändert sie auch in den Optionen des Spiels, und umgekehrt. Der Chat zeigt sie in eckigen Klammern.",
    ["Appearance"] = "Aussehen",
    ["Sets the text size for every chat window at once. Each window's tab menu can still set its size individually. Windows without a chosen size default to 16."]
        = "Die Textgröße des Clients, für alle Chatfenster auf einmal. Das Menü eines Reiters stellt weiterhin ein einzelnes Fenster ein. Ein Fenster, dessen Größe nie gewählt wurde, beginnt bei 16.",
    ["Space between lines"] = "Zeilenabstand",
    ["Extra room between two lines of chat."] = "Zusätzlicher Platz zwischen zwei Chatzeilen.",
    ["Outline"] = "Kontur",
    ["Thin"] = "Dünn",
    ["Thick"] = "Dick",
    ["Adds an outline around every letter, alongside the shadow."]
        = "Eine Linie um jeden Buchstaben, neben dem Schatten.",
    ["Never fade chat out"] = "Chat nie ausblenden",
    ["Old lines stay on screen rather than dimming and vanishing."]
        = "Alte Zeilen bleiben stehen, statt zu verblassen und zu verschwinden.",
    ["Fade after"] = "Ausblenden nach",
    ["Not in use until you let the chat fade."] = "Nicht aktiv, bis du den Chat ausblenden lässt.",
    ["How long a line stays before it fades."]
        = "Wie lange eine Zeile bleibt, bevor sie verblasst.",
    ["Chat Window"] = "Chatfenster",
    ["Hide the chat buttons"] = "Chatbuttons ausblenden",
    ["Hides the buttons beside the chat window and the one that jumps to the newest line."]
        = "Die Buttons neben dem Chatfenster und der, der zur neuesten Zeile springt.",
    ["Show tabs only under the mouse"] = "Reiter nur unter der Maus zeigen",
    ["The window tabs disappear while the mouse is elsewhere. A tab with a new message still lights up."]
        = "Die Reiter der Fenster verschwinden, solange die Maus woanders ist. Ein Reiter mit einer neuen Nachricht leuchtet trotzdem auf.",
    ["Show the input line only after Enter"] = "Eingabezeile erst nach Enter zeigen",
    ["Uses the client's chat style: the input line appears when you press Enter and disappears when the message is sent. Takes effect the next time the input line closes."]
        = "Der Chatstil des Clients: Die Eingabezeile erscheint, wenn du Enter drückst, und verschwindet, wenn die Nachricht gesendet ist. Wirkt, sobald sich die Eingabezeile das nächste Mal schließt.",
    ["Input"] = "Eingabe",
    ["Arrow keys bring back what you sent"] = "Pfeiltasten holen Gesendetes zurück",
    ["Use the Up and Down arrows in the input line to browse messages you sent during this session without holding Alt. Protected commands like /target and /cast still need Alt. In combat, keys without a modifier that the input does not use have no effect while it is open."]
        = "Hoch und Runter gehen in der Eingabezeile durch das, was du in dieser Sitzung gesendet hast, ohne Alt zu halten. Geschützte Befehle wie /target und /cast brauchen weiter Alt. Im Kampf bleiben Tasten ohne Strg, Alt oder Umschalt, die die Eingabe nicht nutzt, wirkungslos, solange sie offen ist.",
    ["Use Alt and Up for %s. The game blocks this command on the plain arrow keys."]
        = "Nimm für %s Alt und Pfeil hoch. Das Spiel blockiert diesen Befehl auf den normalen Pfeiltasten.",
    ["Mouse Wheel"] = "Mausrad",
    ["Shift and the wheel jump to the top or bottom"]
        = "Shift und Mausrad springen nach oben oder unten",
    ["Hold Shift and move the wheel one notch to jump straight to the top or bottom."]
        = "Mit gedrücktem Shift springt ein Mausradschritt ganz nach oben oder unten.",
    ["Lines per wheel notch"] = "Zeilen pro Mausradschritt",
    ["How far one notch of the wheel moves."] = "Wie viele Zeilen ein Mausradschritt weiterscrollt.",
    ["Copy and Search"] = "Kopieren und Suchen",
    ["Shift click a timestamp to quote its line"] = "Shiftklick auf Zeitstempel zitiert die Zeile",
    ["Not in use until you choose a timestamp format."]
        = "Nicht aktiv, bis du ein Format für Zeitstempel wählst.",
    ["A Shift click on a timestamp copies the whole line into the chat input, including the timestamp and sender, without sending it. Lines that arrived before this was enabled stay unchanged."]
        = "Ein Shiftklick auf einen Zeitstempel kopiert die ganze Zeile in die Chateingabe, samt Zeitstempel und Absender, ohne sie zu senden. Zeilen, die vor dem Einschalten kamen, bleiben, wie sie sind.",
    ["Open the chat input when it is closed"] = "Chateingabe öffnen, wenn sie zu ist",
    ["Not in use until you switch on Shift clicking a timestamp."]
        = "Nicht aktiv, bis du den Shiftklick auf Zeitstempel einschaltest.",
    ["A Shift click on a timestamp opens the chat input with the line already entered, so you do not need to press Enter first."]
        = "Ein Shiftklick auf einen Zeitstempel öffnet die Chateingabe gleich mit der Zeile darin, Enter vorher ist nicht nötig.",
    ["Search bar on the chat window"] = "Suchleiste am Chatfenster",
    ["Fade in and out"] = "Langsam einblenden und ausblenden",
    ["Not in use until you switch the search bar on."] = "Nicht aktiv, bis du die Suchleiste einschaltest.",
    ["The bar fades in when the mouse comes over the chat and out when it leaves, rather than appearing at once."]
        = "Die Leiste blendet sich ein, wenn die Maus über den Chat kommt, und aus, wenn sie ihn verlässt, statt sofort zu erscheinen.",
    ["Opacity"] = "Deckkraft",
    ["Sets the search bar's opacity."] = "Wie deckend die Suchleiste gezeichnet wird.",
    ["History"] = "Verlauf",
    ["Keep the chat across sessions"] = "Chat über Sitzungen hinweg behalten",
    ["Saves every chat window when you log out or reload and restores them when this character logs in again."]
        = "Jedes Chatfenster wird beim Ausloggen oder Neuladen aufgeschrieben und wiederhergestellt, wenn sich dieser Charakter erneut einloggt.",
    ["Lines kept per window"] = "Behaltene Zeilen pro Fenster",
    ["Not in use until you keep the chat across sessions."]
        = "Nicht aktiv, bis du den Chat über Sitzungen hinweg behältst.",
    ["Keeps the newest lines in each window, up to the number of lines that window can hold."]
        = "Die neuesten Zeilen jedes Fensters bleiben erhalten, höchstens so viele, wie ein Chatfenster fasst.",
    ["Sounds"] = "Sounds",
    ["Plays a selected sound for each enabled message type. The button beside it plays the selected sound."]
        = "Ein Sound für jede Art von Nachricht, die eingeschaltet ist. Der Button daneben spielt den gewählten Sound.",
    ["Pause between sounds"] = "Pause zwischen Sounds",
    ["After a sound plays, further messages of the same type from the same person are silent until this much time has passed. Applies to whispers, officer chat and messages from the party and raid leader. Messages from other people play a sound immediately."]
        = "Nach einem Sound bleiben weitere Nachrichten derselben Person in derselben Art Chat stumm, bis diese Zeit vergangen ist. Gilt für Flüstern, den Offizierschat und die Leiter von Gruppe und Raid. Die Nachricht eines anderen klingt sofort.",
    ["Raid Warnings"] = "Raidwarnungen",
    ["Plays a selected sound for raid warnings. The button beside it plays the selected sound."]
        = "Ein Sound für Raidwarnungen, solange er eingeschaltet ist. Der Button daneben spielt den gewählten Sound.",
    ["Pause between raid warnings"] = "Pause zwischen Raidwarnungen",
    ["After a raid warning's sound plays, further raid warnings from the same person are silent until this much time has passed. At 0, every raid warning plays a sound."]
        = "Nach dem Sound einer Raidwarnung bleiben weitere Raidwarnungen derselben Person stumm, bis diese Zeit vergangen ist. Bei 0 klingt jede.",

    -- Core/Util.lua, the sounds to pick from
    ["Whisper"] = "Flüstern",
    ["Raid warning"] = "Raidwarnung",
    ["Ready check"] = "Readycheck",
    ["Group invite"] = "Gruppeneinladung",
    ["Friend online"] = "Freund online",
    ["Alarm clock"] = "Wecker",
    ["Alarm clock, short"] = "Wecker kurz",
    ["Map ping"] = "Kartenping",
    ["Auction house"] = "Auktionshaus",
    ["Coins"] = "Münzen",
    ["Level up"] = "Levelaufstieg",

    -- Modules/ChatHistory.lua
    ["Chat: this client cannot add older lines to a chat window, so the saved chat is not restored."]
        = "Chat: Dieser Client kann keine älteren Zeilen in ein Chatfenster einfügen, der gespeicherte Chat wird deshalb nicht wiederhergestellt.",

    -- Modules/ChatLines.lua
    ["Chat: this client would not let a line be changed after it arrived, so labels and names stay as the game writes them."]
        = "Chat: Dieser Client lässt eine Zeile nach ihrem Eintreffen nicht ändern, Kürzel und Namen bleiben deshalb, wie das Spiel sie schreibt.",
    ["Chat: changing a line failed once and is left alone from now on this session."]
        = "Chat: Das Ändern einer Zeile ist einmal fehlgeschlagen und unterbleibt für den Rest dieser Sitzung.",
    ["Sets this chat's color using the client's own color picker."]
        = "Die Farbe dieses Chats. Die Einstellung des Clients, geändert über seine eigene Farbauswahl.",
    ["No channels to label yet."] = "Noch keine Channels für Kürzel.",

    -- Modules/ChatSearch.lua
    ["Search for \"%s\": %d matching lines, showing the latest %d"] = "Suche nach „%s“: %d Zeilen, die letzten %d",
    ["Search for \"%s\": %d line"] = "Suche nach „%s“: %d Zeile",
    ["Search for \"%s\": %d lines"] = "Suche nach „%s“: %d Zeilen",
    ["Empties the search field."] = "Leert das Suchfeld.",
    ["Type a search and press Enter to display every matching line in this chat window again. Press Escape or click the X to clear the search."]
        = "Tippen, dann Enter: Jede passende Zeile dieses Chatfensters wird erneut ausgegeben. Escape oder das X am Ende leert es.",

    -- Modules/ChatSound.lua
    ["Whispers"] = "Flüstern",
    ["Officer Chat"] = "Offizierschat",
    ["Party Leader"] = "Gruppenleiter",
    ["Raid Leader"] = "Raidleiter",
    ["Chat: this client has no sound called %s."]
        = "Chat: Dieser Client hat keinen Sound namens %s.",

    -- Late finds on the Consumables and Chat pages
    ["Replaced by a Class Buff"] = "Ersetzt durch einen Klassenbuff",
    ["Replaces the label before this chat's lines. Leave it empty to use the client's label."]
        = "Ersetzt das Kürzel vor den Zeilen dieses Chats. Leer lässt das des Clients.",
    ["Plays the selected sound when a message of this type arrives."]
        = "Spielt den daneben gewählten Sound, wenn eine Nachricht dieser Art kommt.",

    -- -----------------------------------------------------------------------
    -- Late finds
    -- -----------------------------------------------------------------------

    -- Gameplay, Profiles and the export. The chat commands' own texts stay
    -- English since 2026-10-07, see ENGLISH_OUTPUT in tools/l10n.py.
    ["[ForeverPlus hid]"] = "[Von ForeverPlus ausgeblendet]",
    ["%s (a %s key)"] = "%s (ein Schlüssel vom Typ %s)",
    ["%s (no such module here)"] = "%s (dieses Modul gibt es hier nicht)",
    ["Nested more than %d levels deep"] = "Tiefer als %d Ebenen verschachtelt",
    ["Cannot include a %s in an export string"] = "Ein Wert vom Typ %s passt nicht in einen Exporttext",
    -- Bar settings, shared movement and camp bonuses (2026-10-17).
    ["Bar %s"] = "Leiste %s",
    ["Camp Benefits"] = "Lagerboni",
    ["All Stats (%)"] = "Alle Attribute (%)",
    ["Armor, Stats and Resistances"] = "Rüstung, Attribute und Widerstände",
    ["Critical Strike Chance"] = "Kritische Trefferchance",
    ["Rested Experience"] = "Erholungsbonus",
    ["Bar"] = "Leiste",
    ["The bar for this entry's icons. Use Manage bars to change its settings."]
        = "Die Leiste für die Symbole dieses Eintrags. Ihre Einstellungen findest du unter Leisten verwalten.",
    ["Custom warning time"] = "Eigene Warnzeit",
    ["Off: follows this page's warning time, including later changes."]
        = "Aus: Übernimmt die Warnzeit dieser Seite, auch bei späteren Änderungen.",
    ["Warns when less than this time remains. At 0, skips advance warnings but still warns when missing."]
        = "Warnt, sobald weniger als diese Zeit übrig ist. Bei 0 entfällt die Vorwarnung vor dem Ablauf; bei fehlendem Effekt wird weiterhin gewarnt.",
    ["Horizontal, centered"] = "Horizontal, mittig",
    ["Vertical, centered"] = "Vertikal, mittig",
    ["To the right"] = "Nach rechts",
    ["To the left"] = "Nach links",
    ["Downward"] = "Nach unten",
    ["Upward"] = "Nach oben",
    ["Delete Bar"] = "Leiste löschen",
    ["Delete the bar %s?"] = "Leiste %s löschen?",
    ["%d entry will move to %s."] = "%d Eintrag wird nach %s verschoben.",
    ["%d entries will move to %s."] = "%d Einträge werden nach %s verschoben.",
    ["Restore Default Setup"] = "Standardleisten wiederherstellen",
    ["Restores General Warnings, Combat Buffs and Consumables with their original assignments. Custom bars are kept but emptied. Positions, icon sizes and warning times stay unchanged unless selected below."]
        = "Stellt Allgemeine Warnungen, Kampfbuffs und Consumables mit der ursprünglichen Zuordnung wieder her. Eigene Leisten bleiben leer erhalten. Positionen, Symbolgrößen und Warnzeiten bleiben unverändert, sofern du sie unten nicht auswählst.",
    ["Reset default bar positions"] = "Positionen der Standardleisten zurücksetzen",
    ["Reset default bar icon sizes"] = "Symbolgrößen der Standardleisten zurücksetzen",
    ["Reset all warning times"] = "Alle Warnzeiten zurücksetzen",
    ["Restore"] = "Wiederherstellen",
    ["Bars"] = "Leisten",
    ["Number of enabled entries assigned to this bar for your character."]
        = "Anzahl der aktivierten Einträge, die dieser Leiste für deinen Charakter zugeordnet sind.",
    ["New bar"] = "Neue Leiste",
    ["Creates an empty bar with the default appearance. Assign entries to it in their details."]
        = "Erstellt eine leere Leiste mit der Standarddarstellung. Ordne ihr Einträge in deren Details zu.",
    ["Restore default setup"] = "Standard wiederherstellen",
    ["Restores the three default bars and their original assignments."]
        = "Stellt die drei Standardleisten und ihre ursprüngliche Zuordnung wieder her.",
    ["Name"] = "Name",
    ["The name shown in bar lists and entry details. Leave blank to restore the default name."]
        = "Der Name in Leistenlisten und Eintragsdetails. Ein leeres Feld stellt den Standardnamen wieder her.",
    ["Sets the size of every icon on this bar."]
        = "Legt die Größe aller Symbole auf dieser Leiste fest.",
    ["Growth direction"] = "Wachstumsrichtung",
    ["Sets the bar's growth direction. At the screen edge, icons wrap to a new row or column."]
        = "Legt fest, in welche Richtung die Leiste wächst. Am Bildschirmrand beginnt eine neue Zeile oder Spalte.",
    ["The countdown under each icon on this bar."] = "Die Restzeit unter jedem Symbol dieser Leiste.",
    ["Missing icon color"] = "Farbe fehlender Effekte",
    ["Sets how missing buffs and consumables look on this bar. Borders stay red."]
        = "Legt fest, wie fehlende Buffs und Consumables auf dieser Leiste aussehen. Die Ränder bleiben rot.",
    ["Hides settings and lets you move all bars and the info bar, with this bar highlighted. Apply saves positions; Cancel discards changes."]
        = "Blendet die Einstellungen aus und lässt dich alle Leisten und die Infoleiste verschieben. Diese Leiste wird hervorgehoben. Übernehmen speichert die Positionen, Abbrechen verwirft die Änderungen.",
    ["Restores this bar's default position."] = "Stellt die Standardposition dieser Leiste wieder her.",
    ["Moves this bar to the starting position for new bars."]
        = "Verschiebt diese Leiste an die Ausgangsposition für neue Leisten.",
    ["Delete bar"] = "Leiste löschen",
    ["This is the fallback bar and cannot be deleted."]
        = "Diese Auffangleiste kann nicht gelöscht werden.",
    ["Asks before deleting this bar. Its entries move to the fallback bar."]
        = "Fragt vor dem Löschen dieser Leiste nach. Ihre Einträge wechseln zur Auffangleiste.",
    ["Manage bars"] = "Leisten verwalten",
    ["Opens bar settings for buffs and consumables: size, appearance and screen position."]
        = "Öffnet die Leisteneinstellungen für Buffs und Consumables: Größe, Darstellung und Bildschirmposition.",
    ["Warns when neither this bonus nor a replacement class buff is active. If no bonuses are selected, tracks %s itself."]
        = "Warnt, wenn weder dieser Bonus noch ein ersetzender Klassenbuff aktiv ist. Ohne ausgewählte Boni wird der Effekt %s selbst verfolgt.",
    ["Given by these camp objects:"] = "Gewährt von diesen Lagerobjekten:",
    ["These class buffs also count:"] = "Diese Klassenbuffs zählen ebenfalls:",
    ["Select up to three bonuses, the most you can have at once."]
        = "Wähle bis zu drei Boni aus, so viele können gleichzeitig aktiv sein.",
    ["Buffs for All Classes"] = "Buffs für alle Klassen",
    ["Off: uses this page's warning times. Your buff uses the setting for its duration; group counts use the setting for buffs lasting 10 to 29 minutes."]
        = "Aus: Übernimmt die Warnzeiten dieser Seite. Für deinen Buff gilt die Einstellung für seine Dauer; für die Gruppenzählung die für Buffs von 10 bis 29 Minuten.",
    ["(no coating chosen)"] = "(kein Stein oder Öl gewählt)",
    ["Sets the bar and warning time for this hand's coating. Choose the oil or stone in the list below."]
        = "Legt Leiste und Warnzeit für das Öl oder den Stein dieser Hand fest. Welches, wählst du in der Liste darunter.",
    ["Not in use until you choose an oil or stone for this hand in the list below."]
        = "Nicht aktiv, bis du in der Liste darunter ein Öl oder einen Stein für diese Hand auswählst.",
    ["Move bars"] = "Leisten verschieben",
    ["Hides settings so you can move all bars and the info bar. Apply saves positions; Cancel discards changes."]
        = "Blendet die Einstellungen aus, damit du alle Leisten und die Infoleiste verschieben kannst. Übernehmen speichert die Positionen, Abbrechen verwirft die Änderungen.",
    ["Confirm changes?"] = "Änderungen bestätigen?",
    ["The bars cannot be moved during combat."] = "Die Leisten lassen sich im Kampf nicht verschieben.",
    ["Drag the bars and the info bar into place. Apply saves positions; Cancel discards changes."]
        = "Ziehe die Leisten und die Infoleiste an die gewünschte Stelle. Übernehmen speichert die Positionen, Abbrechen verwirft die Änderungen.",
    -- Translation round, 2026-10-18.
    ["Let the window reach the left edge"] = "Fenster bis an den linken Rand verschieben",
    ["Not in use until you hide the chat buttons."] = "Nicht aktiv, bis du die Chatbuttons ausblendest.",
    ["Removes the room kept free for the buttons on the left of the main chat window, so it can be moved up to the left edge of the screen."]
        = "Entfernt den Platz für die Buttons links am Hauptchatfenster, damit du es bis an den linken Bildschirmrand verschieben kannst.",
    ["Turns every duel request down. Nothing is sent to whoever asked: they see the same refusal they would see if you had clicked it yourself."]
        = "Lehnt jede Duellanfrage ab. Dem Herausforderer wird nichts geschrieben: Er sieht dieselbe Ablehnung wie bei einem Klick von dir.",
    -- Translation round, 2026-10-18.
    ["Portrait style"] = "Porträtstil",
    ["HD"] = "HD",
    ["SD"] = "SD",
    ["Not in use until you switch on the race icon."]
        = "Nicht aktiv, bis du das Volkssymbol einschaltest.",
    ["HD shows the newer race portraits, SD the older ones. A race without an SD portrait keeps its HD one. Lines already in the chat keep theirs."]
        = "HD zeigt die neueren Völkerporträts, SD die älteren. Völker ohne SD-Porträt behalten ihr HD-Porträt. Bereits angezeigte Chatzeilen behalten ihre Porträts.",
    ["Tab background opacity"] = "Deckkraft der Reiterhintergründe",
    ["Sets the opacity of every chat tab's background. The tab names stay fully visible."]
        = "Legt die Deckkraft der Hintergründe aller Chatreiter fest. Die Namen auf den Reitern bleiben vollständig sichtbar.",
    ["Horizontal offset"] = "Horizontaler Versatz",
    ["Moves the search bar to the right of its place in the chat window's top right corner, or to the left below zero. Hold Shift for steps of 50."]
        = "Verschiebt die Suchleiste von ihrer Position oben rechts im Chatfenster nach rechts, bei negativen Werten nach links. Mit Shift in Schritten von 50.",
    ["Vertical offset"] = "Vertikaler Versatz",
    ["Moves the search bar up from its place in the chat window's top right corner, or down below zero. Hold Shift for steps of 50."]
        = "Verschiebt die Suchleiste von ihrer Position oben rechts im Chatfenster nach oben, bei negativen Werten nach unten. Mit Shift in Schritten von 50.",
    ["Puts the search bar back in the chat window's top right corner."]
        = "Setzt die Suchleiste wieder oben rechts ins Chatfenster.",
    ["Shown"] = "Sichtbar",
    ["Hidden"] = "Ausgeblendet",
    ["Shown on hover"] = "Unter der Maus sichtbar",
    ["Bag bar"] = "Taschen",
    ["Micro menu"] = "Menü",
    ["Minimap tracking"] = "Tracking an der Minimap",
    ["Minimap zone name"] = "Zonenname an der Minimap",
    ["Minimap clock"] = "Uhr an der Minimap",
    ["Minimap calendar"] = "Kalender an der Minimap",
    ["Minimap addon button"] = "Addonbutton an der Minimap",
    ["Hide Interface Elements"] = "UI-Elemente ausblenden",
    ["Hides the bag bar, the micro menu and parts of the minimap, always or depending on the mouse."]
        = "Blendet die Taschenleiste, das Menü und Teile der Minimap aus, dauerhaft oder abhängig von der Mausposition.",
    ["Numbers"] = "Zahlen",
    ["Quest titles"] = "Questtitel",
    ["Letters"] = "Briefe",
    ["Combat text"] = "Kampftext",
    ["Open the stopwatch with a click"] = "Stoppuhr per Klick öffnen",
    ["A click on the display opens or closes the game's stopwatch."]
        = "Ein Klick auf die Anzeige öffnet oder schließt die Stoppuhr des Spiels.",
    ["Open the calendar with a Shift click"] = "Kalender per Shiftklick öffnen",
    ["A Shift click on the display opens or closes the game's calendar."]
        = "Ein Shiftklick auf die Anzeige öffnet oder schließt den Kalender des Spiels.",
    ["Open the world map with a click"] = "Weltkarte per Klick öffnen",
    ["A click on the display opens or closes the world map."]
        = "Ein Klick auf die Anzeige öffnet oder schließt die Weltkarte.",
    ["How many of your bag slots are free."] = "Wie viele Plätze in deinen Taschen frei sind.",
    ["Shows the free slots with the total, or the free slots alone. The hover always shows both."]
        = "Zeigt freie Plätze mit der Gesamtzahl oder nur freie Plätze. Beim Darüberfahren werden immer beide Zahlen angezeigt.",
    ["Free and total"] = "Frei und gesamt",
    ["Free only"] = "Nur frei",
    ["Reload the interface with a click"] = "UI per Klick neu laden",
    ["A click on the display asks whether to reload the interface. Not in combat."]
        = "Ein Klick auf die Anzeige fragt, ob die UI neu geladen werden soll. Nicht im Kampf.",
    ["Turn all sound off and on with a click"] = "Spielton per Klick aus- und einschalten",
    ["A click on the display turns all game sound off, and the next one turns it back on. The volume stays as it was."]
        = "Ein Klick auf die Anzeige schaltet den gesamten Spielton aus, der nächste wieder ein. Die eingestellte Lautstärke bleibt erhalten.",
    ["Font"] = "Schriftart",
    ["The font of the info bar. Default is the font of the addon, the others are fonts the game uses elsewhere."]
        = "Die Schriftart der Infoleiste. Standard verwendet die Schrift des Addons, die anderen stammen aus verschiedenen Bereichen des Spiels.",
    ["The size of the info bar's text, relative to the text size on the Design page."]
        = "Die Textgröße der Infoleiste, relativ zur Textgröße auf der Seite Design.",
    ["Text color"] = "Textfarbe",
    ["The color of the info bar's text."] = "Die Textfarbe der Infoleiste.",
    ["Status colors"] = "Statusfarben",
    ["Colors displays by their state. Off, the whole bar is in its text color."]
        = "Färbt Anzeigen je nach Zustand. Ausgeschaltet verwendet die ganze Leiste ihre Textfarbe.",
    ["Background color"] = "Hintergrundfarbe",
    ["The color and opacity of the info bar's background."]
        = "Farbe und Deckkraft des Hintergrunds der Infoleiste.",
    ["Border color"] = "Rahmenfarbe",
    ["The color and opacity of the info bar's border."]
        = "Farbe und Deckkraft des Rahmens der Infoleiste.",
    ["Show icons"] = "Symbole anzeigen",
    ["The icons in front of the displays. A display that is only an icon shows its name instead."]
        = "Die Symbole vor den Anzeigen. Eine Anzeige, die nur aus einem Symbol besteht, zeigt stattdessen ihren Namen.",
    ["Restore default look"] = "Darstellung zurücksetzen",
    ["Puts the info bar's font, colors and icons back as the design has them."]
        = "Setzt Schriftart, Farben und Symbole der Infoleiste auf die Vorgaben des Designs zurück.",
    ["Click to open the world map"] = "Klick zum Öffnen der Weltkarte",
    ["Click to open the stopwatch"] = "Klick zum Öffnen der Stoppuhr",
    ["Shift click to open the calendar"] = "Shiftklick zum Öffnen des Kalenders",
    ["Click to reload the interface"] = "Klick zum Neuladen der UI",
    ["The interface cannot be reloaded during combat."]
        = "Die UI kann im Kampf nicht neu geladen werden.",
    ["Reload the interface now?"] = "UI jetzt neu laden?",
    ["Click the display to turn all sound off or on"]
        = "Ein Klick auf die Anzeige schaltet den gesamten Spielton aus oder ein",
    ["Click an icon to hide or show it on the bar."]
        = "Klicke auf ein Symbol, um es auf der Leiste aus- oder einzublenden.",
    ["Hides or shows this display's icon on the bar."]
        = "Blendet das Symbol dieser Anzeige auf der Leiste aus oder ein.",
    ["Accepts each quest automatically at most once per conversation with the quest giver."]
        = "Nimmt Quests automatisch an, jede höchstens einmal pro Gespräch mit dem Questgeber.",
    ["Quest difficulty"] = "Questschwierigkeit",
    ["Accept all"] = "Alle annehmen",
    ["Skip gray quests"] = "Graue Quests auslassen",
    ["Skip gray and green quests"] = "Graue und grüne auslassen",
    ["Which quests are left for you to accept, by their color for your character. Handing quests in is not affected."]
        = "Welche Quests du selbst annimmst, abhängig von ihrer Farbe für deinen Charakter. Die Questabgabe bleibt unverändert.",
    ["Hands in each completed quest at most once per conversation with the quest giver. Never picks a reward for you."]
        = "Gibt abgeschlossene Quests ab, jede höchstens einmal pro Gespräch mit dem Questgeber. Wählt nie eine Belohnung für dich aus.",
    -- Translation round, 2026-10-18.
    ["Shown, hidden, or shown only while the mouse is over its place. A hidden piece takes no clicks."]
        = "Immer sichtbar, immer ausgeblendet oder nur sichtbar, solange der Mauszeiger darüber ist. Ausgeblendete Elemente reagieren nicht auf Klicks.",
    ["Always visible"] = "Immer sichtbar",
    ["Shows the search bar all the time, instead of only while the mouse is over the chat window or the input line is open."]
        = "Zeigt die Suchleiste dauerhaft, statt nur, solange die Maus über dem Chatfenster ist oder die Eingabezeile offen ist.",
    ["Not in use until you switch off Always visible."]
        = "Nicht aktiv, bis du Immer sichtbar ausschaltest.",
    ["Appears in the chat window's top right corner while the mouse is over the window or the input line is open, unless it is set to be always visible. Press Enter to display every matching line again. The X at the end clears the search."]
        = "Oben rechts im Chat, solange die Maus darüber ist oder die Eingabezeile offen ist, außer wenn Immer sichtbar eingeschaltet ist. Enter gibt jede passende Zeile erneut aus. Das X am Ende leert die Suche.",
    -- Translation round, 2026-10-20: chat fading and item level.
    ["Show chat on hover or while typing"] = "Chat unter der Maus oder beim Tippen zeigen",
    ["Shows faded lines while the mouse is over the chat window or the input line is open. Afterward, they stay for the time set under \"Fade after\"."]
        = "Zeigt ausgeblendete Zeilen, solange die Maus über dem Chatfenster steht oder die Eingabezeile offen ist. Danach bleiben sie für die unter „Ausblenden nach“ eingestellte Zeit sichtbar.",
    ["Fade the background with the messages"] = "Hintergrund gleichzeitig mit den Nachrichten ausblenden",
    ["Fades the window's background and tabs out with the last line. They return at your chosen opacity with a new message, when you scroll, while the mouse is over the window, or while you type."]
        = "Blendet den Fensterhintergrund und die Reiter mit der letzten Zeile aus. Bei einer neuen Nachricht, beim Scrollen, solange die Maus über dem Fenster steht oder während du tippst, erscheinen beide wieder mit der gewählten Deckkraft.",
    ["Item level"] = "Gegenstandsstufe",
    ["Shows the average item level of a player's equipped items. For other players, the value updates when you hover over them outside combat. The last known value stays visible until the new one arrives."]
        = "Zeigt die durchschnittliche Gegenstandsstufe der angelegten Ausrüstung eines Spielers. Bei anderen Spielern wird der Wert aktualisiert, wenn du außerhalb des Kampfes mit der Maus über sie fährst. Bis der neue Wert eintrifft, bleibt der letzte bekannte sichtbar.",
    -- Translation round, 2026-10-23: chat input and info bar.
    ["Input line position"] = "Position der Eingabezeile",
    ["Below the window"] = "Unter dem Fenster",
    ["Between window and tabs"] = "Unter den Reitern",
    ["Above the tabs"] = "Über den Reitern",
    ["Places the input line of every chat window below the window, between the window and its tabs, or above the tabs."]
        = "Platziert die Eingabezeile jedes Chatfensters unter dem Fenster, zwischen Fenster und Reitern oder über den Reitern.",
    ["How much ammunition you carry for your bow, gun or crossbow. Not shown while none of them is equipped."]
        = "Wie viel Munition du für deinen Bogen, deine Schusswaffe oder deine Armbrust dabeihast. Ausgeblendet, solange keine davon angelegt ist.",
    ["What it counts"] = "Was gezählt wird",
    ["Counts every arrow or every bullet in your bags that your weapon fires, or only the ammunition in your ammo slot."]
        = "Zählt alle Pfeile oder Kugeln in deinen Taschen, die deine Waffe verschießt, oder nur die Munition in deinem Munitionsplatz.",
    ["All arrows or bullets"] = "Alle Pfeile oder Kugeln",
    ["Ammo slot only"] = "Nur Munitionsplatz",
    ["Turns the display red below the amount set under this switch. Shared with Ammunition Warning on the Gameplay page, where it also shows a red line and plays a sound for Hunters."]
        = "Färbt die Anzeige unter der Menge rot, die unter diesem Schalter eingestellt ist. Gilt auch für die Munitionswarnung auf der Seite Gameplay, die Jäger zusätzlich mit einer roten Zeile und einem Sound warnt.",
    ["The amount below which the display turns red. Shared with Ammunition Warning on the Gameplay page."]
        = "Die Menge, unter der die Anzeige rot wird. Gilt auch für die Munitionswarnung auf der Seite Gameplay.",
    ["Destroy Cheapest Gray Item"] = "Billigstes graues Item zerstören",
    ["Shows an icon for the gray stack in your bags that is worth the least at a merchant. Shift click it to destroy that stack and free a bag slot. Not in combat."]
        = "Zeigt ein Symbol für den grauen Stapel in deinen Taschen, für den ein Händler am wenigsten zahlt. Ein Shiftklick zerstört den Stapel und macht einen Taschenplatz frei. Nicht im Kampf.",
    ["Destroy with a click, without Shift"] = "Per Klick ohne Shift zerstören",
    ["A click on the display destroys the stack without holding Shift."]
        = "Ein Klick auf die Anzeige zerstört den Stapel, ohne Shift gedrückt zu halten.",
    ["Skip the confirmation"] = "Bestätigung überspringen",
    ["Destroys the stack at once, without the question, and reports it in chat."]
        = "Zerstört den Stapel sofort ohne Nachfrage und meldet es im Chat.",
    ["Counts %s, the ammunition in your ammo slot"] = "Zählt %s, die Munition in deinem Munitionsplatz",
    ["Your ammo slot is empty"] = "Dein Munitionsplatz ist leer",
    ["Counts every bullet in your bags"] = "Zählt alle Kugeln in deinen Taschen",
    ["Counts every arrow in your bags"] = "Zählt alle Pfeile in deinen Taschen",
    ["Red below %d"] = "Rot unter %d",
    ["Nothing is destroyed in combat."] = "Im Kampf wird nichts zerstört.",
    ["Nothing was destroyed: something is on your cursor."] = "Nichts zerstört: Du hast etwas am Mauszeiger.",
    ["Nothing was destroyed: your bags changed."] = "Nichts zerstört: Dein Tascheninhalt hat sich geändert.",
    ["Nothing was destroyed: this client cannot destroy items for an addon."]
        = "Nichts zerstört: Dieser Client kann keine Items für ein Addon zerstören.",
    ["The game did not destroy %s."] = "Das Spiel hat %s nicht zerstört.",
    ["Destroyed %d %s, worth %s at a merchant."] = "%d %s zerstört, beim Händler %s wert.",
    ["Destroyed %d %s, worth nothing at a merchant."] = "%d %s zerstört, beim Händler nichts wert.",
    ["Destroy Gray Item"] = "Graues Item zerstören",
    ["Do you really want to destroy %d %s?"] = "Möchtest du wirklich %d %s zerstören?",
    ["A merchant would pay %s for it. This cannot be undone."]
        = "Ein Händler würde dafür %s zahlen. Das lässt sich nicht rückgängig machen.",
    ["A merchant would pay nothing for it. This cannot be undone."]
        = "Ein Händler würde dafür nichts zahlen. Das lässt sich nicht rückgängig machen.",
    ["Destroy"] = "Zerstören",
    ["Turns on \"Skip the confirmation\" on the Info bar page when you click Destroy."]
        = "Schaltet „Bestätigung überspringen“ auf der Seite Infoleiste ein, wenn du auf Zerstören klickst.",
    ["No gray item to destroy"] = "Kein graues Item zum Zerstören",
    ["Stack of %d, worth %s at a merchant"] = "Stapel mit %d, beim Händler %s wert",
    ["Stack of %d, worth nothing at a merchant"] = "Stapel mit %d, beim Händler nichts wert",
    ["Not in combat"] = "Nicht im Kampf",
    ["Click to destroy this stack"] = "Klicken, um diesen Stapel zu zerstören",
    ["Shift click to destroy this stack"] = "Shiftklick, um diesen Stapel zu zerstören",
    -- Shadow Protection, durability warning and web address copying.
    ["Warn about Shadow Protection from others"] = "Warnen, wenn Schattenschutz von anderen fehlt",
    ["Warns when Shadow Protection is missing or about to expire and a Priest in your group could give it to you. Only applies where buffs from others are switched on under Conditions. A Priest's own warnings and group count do not change."]
        = "Warnt, wenn Schattenschutz fehlt oder bald ausläuft und ein Priester in deiner Gruppe ihn dir geben könnte. Gilt nur dort, wo Buffs von anderen unter „Bedingungen“ eingeschaltet sind. Die eigenen Warnungen und die Gruppenzählung eines Priesters bleiben unverändert.",
    ["Durability Warning"] = "Haltbarkeitswarnung",
    ["Shows a short warning when an equipped item reaches the selected durability or lower. Also warns after login if an item is already low."]
        = "Zeigt eine kurze Warnung, wenn die Haltbarkeit eines angelegten Items den eingestellten Wert erreicht oder unterschreitet. Warnt auch nach dem Einloggen, wenn ein Item bereits so weit abgenutzt ist.",
    ["Warn at or below"] = "Warnen bei oder unter",
    ["Uses the lowest durability among your equipped items. At 0%, it warns only about broken equipment."]
        = "Es zählt die niedrigste Haltbarkeit deiner angelegten Items. Bei 0% wird nur vor kaputter Ausrüstung gewarnt.",
    ["Low durability: %s (%d%%)"] = "Niedrige Haltbarkeit: %s (%d%%)",
    ["Durability Warning: this client has no sound called %s."]
        = "Haltbarkeitswarnung: Dieser Client hat keinen Sound namens %s.",
    ["Copy web addresses"] = "Webadressen kopieren",
    ["Makes web addresses in chat clickable for copying."]
        = "Macht Webadressen im Chat zum Kopieren anklickbar.",
    ["Click to select this web address for copying."]
        = "Klicken, um diese Webadresse zum Kopieren zu markieren.",
    ["Web address"] = "Webadresse",
    ["Press Ctrl+C to copy."] = "Zum Kopieren Strg+C drücken.",
    -- Experience measurement, addon CPU usage and health bar textures.
    ["How much experience you gain per hour, measured since you logged in. Not shown at the maximum level."]
        = "Wie viel XP du seit dem Einloggen pro Stunde gewinnst. Auf dem höchsten Level ausgeblendet.",
    ["Restart measurement with a click"] = "Messung per Klick neu starten",
    ["A click on the display resets the measurement for both experience displays."]
        = "Ein Klick auf die Anzeige setzt die Messung für beide Anzeigen zurück.",
    ["Estimated time to your next level at your current experience rate. Not shown at the maximum level."]
        = "Geschätzte Zeit bis zum nächsten Level bei deinen aktuellen XP pro Stunde. Auf dem höchsten Level ausgeblendet.",
    ["Click to restart measurement"] = "Klick zum Neustart der Messung",
    ["Level %d"] = "Level %d",
    ["Rested"] = "Erholt",
    ["%s in %s"] = "%s in %s",
    ["Per hour"] = "Pro Stunde",
    ["To the next level"] = "Bis zum nächsten Level",
    ["Addon CPU usage"] = "Auslastung der CPU durch Addons",
    ["Total"] = "Gesamt",
    ["Health bar texture"] = "Textur der Gesundheitsleiste",
    ["Flat"] = "Einfarbig",
    ["Soft gradient"] = "Sanfter Verlauf",
    ["Choose the texture of the health bar below unit tooltips."] = "Wählt die Textur der Gesundheitsleiste unter den Tooltips von Einheiten.",
    ["Preview"] = "Vorschau",
})
