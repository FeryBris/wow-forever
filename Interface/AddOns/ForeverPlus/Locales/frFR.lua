-- French, phase 7.7.
--
-- The English text on the left is the key, exactly as it stands in the code,
-- and the French on the right is what a player reads. TRANSLATION.md holds the
-- words and the rules, gated with the owner on 2026-10-07: "vous", a setting
-- as an infinitive, the French client's own words, buff the one exception, a
-- non breaking space before : ; ! ? and inside « », the client's apostrophe,
-- a decimal comma, no long dashes, and a text that fits its row.
--
-- Sorted like deDE.lua, by page and then by file. tools/l10n.py reports a
-- text the code marks that is missing here, French left behind for a text the
-- code no longer marks, and punctuation without its space.

local ADDON, FP = ...

FP:AddLocale("frFR", {

    -- -----------------------------------------------------------------------
    -- The window
    -- -----------------------------------------------------------------------

    -- Core/Boot.lua
    ["v%s loaded, %d of %d modules enabled, profile |cffffffff%s|r. Open the settings with |cff888888/fplus|r."]
        = "v%s chargée, %d modules actifs sur %d, profil |cffffffff%s|r. |cff888888/fplus|r pour les réglages.",

    -- Core/Init.lua
    ["NPC Interaction"] = "Interactions avec les PNJ",
    ["Merchants"] = "Marchands",
    ["Loot"] = "Butin",
    ["Interruptions"] = "Interruptions",
    ["Display"] = "Affichage",
    ["Chat"] = "Discussion",
    ["Tools"] = "Outils",

    -- Core/Options.lua
    ["Enable %s"] = "Activer %s",
    ["Do it"] = "Exécuter",
    ["%s: custom option failed to build: %s"] = "%s : une option personnalisée n’a pas pu être construite : %s",
    ["%s: option %s has an unknown type %q"] = "%s : l’option %s a un type inconnu %q",
    ["Not in use until another setting here allows it."]
        = "Inactif tant qu’un autre réglage ici ne l’autorise pas.",
    ["Not in use until you switch the module on."] = "Inactif tant que le module n’est pas activé.",

    -- Core/Util.lua
    ["%s: function is missing"] = "%s : la fonction est absente",
    ["%s: expected a function, got %s"] = "%s : fonction attendue, %s reçu",
    ["Error in %s: %s"] = "Erreur dans %s : %s",
    ["%s: this client does not recognize %s. Those features remain unavailable."]
        = "%s : ce client ne connaît pas %s. Ces fonctionnalités restent indisponibles.",

    -- Core/Widgets.lua
    ["Select all"] = "Tout sélectionner",
    ["Close"] = "Fermer",
    ["Paste the text here with Ctrl+V, then press the button below."]
        = "Collez ici avec Ctrl+V, puis appuyez sur le bouton en dessous.",
    ["Apply"] = "Appliquer",
    ["Delete Character Data"] = "Supprimer les données du personnage",
    ["Do you really want to delete the data for your character %s from ForeverPlus?"]
        = "Voulez-vous vraiment supprimer de ForeverPlus les données de votre personnage %s ?",
    ["This deletes its gold, its place in the mail list, its profile assignment, its Auto Buy choices, its cooldowns, the notices it has already been shown and the chat saved from its last session. Profiles are shared by all characters and are kept."]
        = "Cela supprime son or, sa place dans la liste du courrier, son attribution de profil, ses choix d’achat automatique, ses temps de recharge, les avis qu’il a déjà vus et l’historique de discussion conservé de sa dernière session. Les profils sont partagés par tous les personnages et restent.",
    ["Delete"] = "Supprimer",
    ["Cancel"] = "Annuler",
    ["ForeverPlus no longer keeps anything about %s."] = "ForeverPlus ne garde plus rien sur %s.",

    -- Modules/Menu.lua
    ["This window."] = "Cette fenêtre.",
    ["Click the box to turn it on and off."] = "Cliquez sur la case pour activer ou désactiver le module.",
    ["Its settings have a tab of their own: |cffffffff%s|r. Click to go there."]
        = "Ses réglages ont leur propre onglet : |cffffffff%s|r. Cliquez pour y aller.",
    ["Click the row to show its settings."] = "Cliquez sur la ligne pour afficher ses réglages.",
    ["This module has nothing to set."] = "Ce module n’a rien à régler.",
    ["Gameplay"] = "Jeu",
    ["Gameplay modules are on"] = "Les modules de jeu sont activés",
    ["Gameplay modules are off"] = "Les modules de jeu sont désactivés",
    ["Turning this page off disables every module on it, including the minimap button. Each module keeps its own setting, so turning the page back on restores the previous settings."]
        = "Désactivé, chaque module de cette page s’arrête, bouton de la minicarte compris. Chacun garde sa propre case, donc réactiver la page ramène ceux qui étaient activés.",
    ["Expand all"] = "Tout développer",
    ["Collapse all"] = "Tout réduire",
    ["Clear"] = "Effacer",
    ["Search"] = "Recherche",
    ["%s is on"] = "%s est activé",
    ["%s is off"] = "%s est désactivé",
    ["Switches everything on this page on or off. The settings are kept."]
        = "Active ou désactive tout ce qui se trouve sur cette page. Les réglages sont conservés.",
    ["Language"] = "Langue",
    ["Automatic"] = "Automatique",
    ["Applies to every character and profile. Automatic uses the game's language, or English if the addon does not support that language. Changes take effect after the next reload."]
        = "S’applique à tous les personnages et à tous les profils. Automatique prend la langue du jeu, ou l’anglais si cet add-on ne l’a pas. Un changement prend effet au prochain rechargement.",
    ["The language changes with the next reload. Reload now?"]
        = "La langue change au prochain rechargement. Recharger maintenant ?",
    ["Reload now"] = "Recharger maintenant",
    ["Later"] = "Plus tard",
    ["Reload UI"] = "Recharger",
    ["This page is switched off. The box on its tab switches it on again, with every setting here as you left it."]
        = "Cette page est désactivée. La case de son onglet la réactive, avec tous les réglages tels que vous les avez laissés.",
    ["The %s page has no switch on its tab. Give it a switch, or mark it internal if it only arranges the addon."]
        = "La page %s n’a pas de case sur son onglet. Donnez-lui une case, ou marquez-la comme interne si elle ne fait qu’organiser l’add-on.",
    ["Tab %s failed to build its header: %s"] = "L’onglet %s n’a pas pu construire son en-tête : %s",
    ["Tab %s failed to build: %s"] = "L’onglet %s n’a pas pu être construit : %s",
    ["The settings window was off screen and has been moved back to the center."]
        = "La fenêtre des réglages était hors de l’écran, elle est revenue au centre.",

    -- The names of the other pages, and the switches on their tabs. The pages
    -- themselves follow in later parts of this file.
    ["Buffs"] = "Buffs",
    ["Buff warnings are on"] = "Les alertes de buffs sont activées",
    ["Buff warnings are off"] = "Les alertes de buffs sont désactivées",
    ["The master switch for this page. Everything on it only decides what it warns about and when.|n|nOff means no icons at all. The settings are kept, so turning it back on restores what you had."]
        = "La case principale de cette page. Tout ce qu’elle contient décide seulement de quoi et quand vous êtes alerté.|n|nDésactivé, aucune icône n’apparaît. Les réglages sont conservés, donc la réactiver rétablit ce que vous aviez.",
    ["Consumables"] = "Consommables",
    ["Consumable warnings are on"] = "Les alertes de consommables sont activées",
    ["Consumable warnings are off"] = "Les alertes de consommables sont désactivées",
    ["Tooltip"] = "Bulles d’aide",
    ["Tooltip changes are on"] = "Les changements des bulles d’aide sont activés",
    ["Tooltip changes are off"] = "Les changements des bulles d’aide sont désactivés",
    ["Off leaves the client's own tooltip exactly as it was, arrangement and position included. The settings are kept."]
        = "Désactivé, la bulle d’aide du client reste exactement comme elle était, disposition et position comprises. Les réglages sont conservés.",
    ["Info bar"] = "Barre d’infos",
    ["The info bar is on"] = "La barre d’infos est activée",
    ["The info bar is off"] = "La barre d’infos est désactivée",
    ["Chat changes are on"] = "Les changements de la discussion sont activés",
    ["Chat changes are off"] = "Les changements de la discussion sont désactivés",
    ["Off leaves the chat as the client has it. The settings are kept."]
        = "Désactivé, la discussion fonctionne comme dans le client. Les réglages sont conservés.",
    ["Design"] = "Apparence",
    ["Profiles"] = "Profils",
    ["Info"] = "Info",

    -- -----------------------------------------------------------------------
    -- Gameplay
    -- -----------------------------------------------------------------------

    -- Shared by several modules
    ["Hold Shift to pause"] = "Maintenir Maj pour suspendre",
    ["Shift is held, automation paused."] = "Maj est maintenue, l’automatisme est suspendu.",
    ["No merchant open."] = "Aucun marchand ouvert.",

    -- Modules/QuestAutoAccept.lua
    ["Auto Accept Quests"] = "Accepter les quêtes automatiquement",
    ["Also from gossip windows"] = "Aussi depuis les dialogues",
    ["Accepts quests offered inside a conversation, not just through the regular quest window."]
        = "Accepte aussi les quêtes proposées dans une conversation, pas seulement dans la simple fenêtre de quête.",
    ["Confirm shared quests and escorts"] = "Confirmer les quêtes partagées et les escortes",
    ["Also accepts quests other players share with you and escort quests. An escort begins the moment it is accepted."]
        = "Accepte aussi les quêtes partagées avec vous par d’autres joueurs et les quêtes d’escorte. Une escorte commence dès que sa quête est acceptée.",
    ["While Shift is down, nothing is accepted, so you can read the text first."]
        = "Tant que Maj est enfoncée, rien n’est accepté, pour le cas où vous voulez d’abord lire le texte.",

    -- Modules/QuestAutoTurnIn.lua
    ["Auto Turn In Quests"] = "Rendre les quêtes automatiquement",
    ["Hands quests in from inside a conversation as well as from the plain quest window."]
        = "Rend aussi les quêtes depuis une conversation, pas seulement dans la simple fenêtre de quête.",
    ["While Shift is down, nothing is handed in. Reward values are still shown because they belong to a separate module."]
        = "Tant que Maj est enfoncée, rien n’est rendu. La valeur des récompenses reste affichée, car elle relève d’un module à part.",

    -- Modules/QuestRewardValue.lua
    ["Quest Reward Value"] = "Valeur des récompenses de quête",
    ["Shows what each quest reward sells for, on every quest window."]
        = "Affiche dans chaque fenêtre de quête le prix de vente de chaque récompense.",
    ["Also on rewards you get anyway"] = "Aussi pour les récompenses fixes",
    ["Not only the ones you choose between. Off, and only a real choice carries a price."]
        = "Pas seulement celles entre lesquelles vous choisissez. Désactivé, le prix n’apparaît que pour un véritable choix.",
    ["QuestRewardValue: could not hook QuestInfo_Display, falling back to the quest events alone."]
        = "Valeur des récompenses de quête : impossible de se greffer sur QuestInfo_Display, seuls les évènements de quête restent.",

    -- Modules/GossipAuto.lua
    ["Skip Gossip"] = "Passer les dialogues",
    ["Clicks past the extra line of talk at vendors, trainers, flight masters, bankers and guild masters."]
        = "Passe la ligne de dialogue supplémentaire chez les marchands, les maîtres, les maîtres de vol, les banquiers et les maîtres de guilde.",
    ["Say when an unfamiliar service turns up"] = "Signaler un service inconnu",
    ["Nothing is clicked in that case. The line tells you the addon encountered an unfamiliar service, and the details are saved so the list can be expanded deliberately. Once per kind of service, not once per NPC."]
        = "Dans ce cas, rien n’est cliqué. La ligne vous indique que l’add-on a rencontré un service inconnu, et les détails sont conservés pour que la liste puisse être élargie sciemment. Une fois par type de service, pas une fois par PNJ.",
    ["Say every time a line is clicked"] = "Signaler chaque clic sur une ligne",
    ["Writes a line in your chat each time the addon clicks a gossip line for you."]
        = "Écrit une ligne dans votre discussion chaque fois que l’add-on clique pour vous sur une ligne de dialogue.",
    ["While Shift is down, nothing is clicked, so you can read what the NPC actually says. Hold Shift and talk again to check whether the addon was skipping a window for you."]
        = "Tant que Maj est enfoncée, rien n’est cliqué, pour que vous puissiez lire ce que dit vraiment le PNJ. Maintenez Maj et parlez-lui de nouveau pour vérifier si l’add-on passait une fenêtre pour vous.",
    ["Opened the vendor for you."] = "Le marchand a été ouvert pour vous.",
    ["Opened the trainer for you."] = "Le maître a été ouvert pour vous.",
    ["Opened the taxi for you."] = "La carte de vol a été ouverte pour vous.",
    ["Opened the petition for you."] = "La charte de guilde a été ouverte pour vous.",
    ["Opened the bank for you."] = "La banque a été ouverte pour vous.",
    ["Left alone because the service is unfamiliar: icon %s, \"%s\". The details are saved so the list can be expanded deliberately."]
        = "Un service inconnu a été laissé tel quel : icône %s, « %s ». Noté pour que la liste puisse être élargie sciemment.",

    -- Modules/Looting.lua
    ["Fast Auto Loot"] = "Fouille automatique rapide",
    ["Loots without the delay, and can roll greed on greens."]
        = "Fouille sans délai, et peut choisir Cupidité pour les objets verts.",
    ["Loot without the delay"] = "Fouiller sans délai",
    ["Takes every slot at once instead of waiting for the client to process them one by one. It never decides whether to loot: that stays with your own auto loot setting and its modifier key, and this does nothing at all when the client was not going to loot."]
        = "Prend tous les emplacements d’un coup au lieu d’attendre que le client les traite un par un. Ne décide jamais s’il faut fouiller : cela dépend toujours de votre réglage de fouille automatique et de sa touche, et ceci ne fait rien du tout quand le client n’allait pas fouiller.",
    ["Turn on Auto Loot"] = "Activer la fouille automatique",
    ["Turns on the game's own auto loot."] = "Active la fouille automatique du jeu.",
    ["Rolling"] = "Jets de dés",
    ["Roll greed on green items"] = "Choisir Cupidité pour les objets verts",
    ["Rolls greed on every green item automatically."]
        = "Choisit automatiquement Cupidité pour chaque objet vert.",
    ["Say what was rolled on"] = "Signaler les objets concernés",
    ["Shows the item in your own chat. Nothing is sent to the group."]
        = "Une ligne dans votre propre discussion avec le nom de l’objet. Rien n’est envoyé au groupe.",
    ["Looting: this client offers no way to set a CVar."]
        = "Fouille automatique rapide : ce client n’offre aucun moyen de définir une CVar.",
    ["The client's auto loot is already on, nothing changed."]
        = "La fouille automatique est déjà activée.",
    ["Looting: the client refused to set autoLootDefault."]
        = "Fouille automatique rapide : le client a refusé de définir autoLootDefault.",
    ["Looting: autoLootDefault was set but does not report that it is on. Check the client's own options."]
        = "Fouille automatique rapide : autoLootDefault a été défini mais ne se relit pas comme activé. Vérifiez les options du client.",
    ["The client's auto loot is now on. That is a client setting, so it stays on whether or not this addon is running."]
        = "La fouille automatique est maintenant activée. C’est un réglage du jeu, elle reste donc activée même sans cet add-on.",
    ["Looting: the loot API is missing on this build."]
        = "Fouille automatique rapide : l’interface de fouille est absente de cette version du client.",
    ["Looting: the roll API is missing on this build."]
        = "Fouille automatique rapide : l’interface des jets de dés est absente de cette version du client.",
    ["Rolled greed on %s."] = "Cupidité choisie pour %s.",
    ["a green item"] = "un objet vert",

    -- Modules/AutoSellGray.lua
    ["Sell Gray Items"] = "Vendre les objets gris",
    ["Sells gray items at any merchant."] = "Vend les objets gris chez n’importe quel marchand.",
    ["Report earnings in chat"] = "Indiquer le gain dans la discussion",
    ["Shows the total value of sold items in chat."]
        = "Additionne ce qui a été vendu et l’affiche dans la discussion.",
    ["While Shift is down, nothing is sold."] = "Tant que Maj est enfoncée, rien n’est vendu.",
    ["Sold %d gray item for %s%s."] = "%d objet gris vendu pour %s%s.",
    ["Sold %d gray items for %s%s."] = "%d objets gris vendus pour %s%s.",
    ["at least "] = "au moins ",
    ["%d gray item could not be sold."] = "%d objet gris n’a pas pu être vendu.",
    ["%d gray items could not be sold."] = "%d objets gris n’ont pas pu être vendus.",
    ["%d gray item still had a sale pending and could not be checked. Reopen the merchant if it is still there."]
        = "%d objet gris était encore en cours de vente et n’a pas pu être vérifié. Rouvrez le marchand s’il est toujours là.",
    ["%d gray items still had a sale pending and could not be checked. Reopen the merchant if they are still there."]
        = "%d objets gris étaient encore en cours de vente et n’ont pas pu être vérifiés. Rouvrez le marchand s’ils sont toujours là.",
    ["AutoSellGray: C_Container.UseContainerItem or C_Timer is missing."]
        = "Vendre les objets gris : C_Container.UseContainerItem ou C_Timer est absent.",
    ["No gray items in your bags."] = "Aucun objet gris dans vos sacs.",
    ["Found %d gray item, selling ..."] = "%d objet gris trouvé, vente en cours...",
    ["Found %d gray items, selling ..."] = "%d objets gris trouvés, vente en cours...",

    -- Modules/AutoRepair.lua
    ["Auto Repair"] = "Réparation automatique",
    ["Repairs your gear at merchants who offer repairs."] = "Répare votre équipement chez les marchands qui le peuvent.",
    ["Report the cost in chat"] = "Indiquer le coût dans la discussion",
    ["Shows the repair cost in chat."]
        = "Affiche dans la discussion ce qu’a coûté la réparation.",
    ["While Shift is down, nothing is repaired."]
        = "Tant que Maj est enfoncée, rien n’est réparé.",
    ["AutoRepair: the repair API is missing on this build."]
        = "Réparation automatique : l’interface de réparation est absente de cette version du client.",
    ["This merchant does not repair."] = "Ce marchand ne répare pas.",
    ["Nothing to repair."] = "Rien à réparer.",
    ["Repair costs %s, waiting until you can afford it."]
        = "La réparation coûte %s. Elle se fera dès que vous pourrez la payer.",
    ["Repaired for %s."] = "Réparé pour %s.",

    -- Modules/Interruptions.lua
    ["Declines duels and releases your spirit in battlegrounds. Both off until you say so."]
        = "Refuse les duels et libère l’esprit en champ de bataille. Les deux sont désactivés jusqu’à ce que vous les activiez.",
    ["Decline duels"] = "Refuser les duels",
    ["Say who was declined"] = "Signaler qui a été refusé",
    ["Shows the name in your own chat, so you know whose duel request was declined."]
        = "Affiche le nom dans votre propre discussion, pour que vous sachiez à qui le duel a été refusé.",
    ["Battlegrounds"] = "Champs de bataille",
    ["Release when you die in a battleground"] = "Libérer l’esprit en champ de bataille",
    ["Battlegrounds only, never in the world, a dungeon or a raid. It does not release when the client offers you a resurrection of your own. This build cannot check for a soulstone, so the delay is the only safeguard."]
        = "Seulement en champ de bataille, jamais dans le monde, dans un donjon ou dans un raid. Rien ne se fait quand le client vous propose une résurrection, mais cette version du client ne permet pas de savoir s’il y a une pierre d’âme, donc seule une attente vous en protège.",
    ["Wait before releasing"] = "Attendre avant de libérer l’esprit",
    ["Time for a Druid to resurrect you or for a soulstone to do so. Zero releases immediately."]
        = "Le temps qu’un druide ou une pierre d’âme vous ressuscite. Zéro libère l’esprit immédiatement.",
    ["at once"] = "aussitôt",
    ["%d s"] = "%d s",
    ["While Shift is down, neither of these acts."] = "Tant que Maj est enfoncée, aucun des deux n’agit.",
    ["Interruptions: CancelDuel is missing on this build."]
        = "Interruptions : CancelDuel est absent de cette version du client.",
    ["Declined a duel from %s."] = "Duel de %s refusé.",
    ["somebody"] = "quelqu’un",
    ["Not releasing: the client is offering you a resurrection."]
        = "L’esprit n’est pas libéré : le client vous propose une résurrection.",
    ["Interruptions: RepopMe is missing on this build."]
        = "Interruptions : RepopMe est absent de cette version du client.",

    -- Modules/ErrorFilter.lua
    ["Error Filter"] = "Filtre d’erreurs",
    ["Hides the red spam errors."] = "Masque les messages d’erreur rouges.",
    ["Hide every error (not quest progress)"] = "Masquer toutes les erreurs (pas la progression des quêtes)",
    ["Hides every red error. Quest progress and other yellow notices stay visible."]
        = "Masque chaque erreur rouge. La progression des quêtes et les autres avis jaunes restent visibles.",
    ["Or Choose Them Individually"] = "Ou les choisir une par une",
    ["These settings are ignored while every error is hidden. Turn off the switch above to choose errors individually."]
        = "Toutes les erreurs sont masquées, ceci ne compte donc pas. Désactivez « Masquer toutes les erreurs » pour les choisir une par une.",
    ["Only used while the switch above is off."]
        = "Ne compte que tant que l’option pour toutes les erreurs au-dessus est désactivée.",
    ["Not enough mana / rage / energy"] = "Pas assez de mana / rage / énergie",
    ["Hides the errors about not enough mana, rage or energy."]
        = "Masque les erreurs signalant trop peu de mana, de rage ou d’énergie.",
    ["Ability is not ready yet"] = "La technique n’est pas encore disponible",
    ["Hides the errors about an ability that is not ready yet."]
        = "Masque les erreurs signalant une technique pas encore prête.",
    ["Out of range / too far away"] = "Hors de portée / Vous êtes trop loin",
    ["Hides the errors about being out of range or too far away."]
        = "Masque les erreurs signalant une cible hors de portée ou trop loin.",
    ["Facing the wrong way"] = "Vous ne faites pas face à la bonne direction",
    ["Hides the errors about facing the wrong way."]
        = "Masque les erreurs signalant que vous ne faites pas face à la bonne direction.",
    ["Invalid target"] = "Cible incorrecte",
    ["Hides the errors about an invalid target."]
        = "Masque les erreurs signalant une cible incorrecte.",
    ["Log hidden messages to chat (for tuning)"] = "Afficher ce qui est masqué dans la discussion (pour régler)",
    ["Shows what was filtered, so you can tell whether something is being hidden that you wanted to see."]
        = "Affiche ce qui a été filtré, pour que vous sachiez si un message que vous vouliez voir est masqué.",
    ["ErrorFilter: this build reports no message color, so 'hide all' stays off to avoid swallowing quest progress. The individual categories still work."]
        = "Filtre d’erreurs : cette version du client n’indique pas la couleur des messages, donc « tout masquer » reste désactivé pour ne pas avaler la progression des quêtes. Les catégories individuelles fonctionnent toujours.",
    ["ErrorFilter: UIErrorsFrame has no filterable method on this build, nothing is hidden."]
        = "Filtre d’erreurs : UIErrorsFrame n’offre rien à filtrer dans cette version du client, rien n’est masqué.",
    ["ErrorFilter: this build knows none of the strings for %s, that category does nothing."]
        = "Filtre d’erreurs : cette version du client ne connaît aucun des textes pour %s, cette catégorie reste sans effet.",
    ["ErrorFilter is on, but every category is off. Nothing is being hidden."]
        = "Le filtre d’erreurs est activé mais chaque catégorie est désactivée, rien n’est masqué.",

    -- Modules/XPBarText.lua
    ["Experience Bar Text"] = "Texte de la barre d’expérience",
    ["Keeps the experience bar text visible."] = "Garde le texte de la barre d’expérience visible.",
    ["XPBarText: this build has no '%s' setting. Run /fplus discover: the experience bar's structure is saved in SavedVariables, so the fallback can be built against it."]
        = "Texte de la barre d’expérience : cette version du client n’a pas de réglage « %s ». Lancez /fplus discover : la structure de la barre d’expérience est enregistrée dans les SavedVariables, pour qu’un remplacement puisse être construit d’après elle.",
    ["Experience bar text is now always visible."] = "Le texte de la barre d’expérience est maintenant toujours visible.",
    ["XPBarText: '%s' exists but could not be set."]
        = "Texte de la barre d’expérience : « %s » existe mais n’a pas pu être défini.",

    -- Modules/BagSlots.lua
    ["Free Bag Slots"] = "Emplacements libres",
    ["Shows on the backpack how many bag slots are free. Special bags are shown separately."]
        = "Affiche sur le sac à dos le nombre d’emplacements libres. Les sacs spéciaux sont affichés à part.",
    ["Show the total as well"] = "Afficher aussi le total",
    ["Shows 14/80 instead of 14."] = "Affiche 14/80 au lieu de 14.",
    ["BagSlots: %s is missing on this build, so there is nowhere to write the count."]
        = "Emplacements libres : %s est absent de cette version du client, le nombre n’a donc nulle part où s’afficher.",
    ["BagSlots: C_Container does not offer the slot counts on this build."]
        = "Emplacements libres : C_Container ne fournit pas le nombre d’emplacements dans cette version du client.",

    -- Modules/Ammunition.lua
    ["Ammunition"] = "Munitions",
    ["Ammunition Warning"] = "Alerte de munitions",
    ["For Hunters: shows how much ammunition you carry, on your quiver or backpack, with a short warning when it runs low."]
        = "Pour les chasseurs : la quantité de munitions que vous portez, affichée sur votre carquois ou sinon sur le sac à dos, et une courte alerte quand elles viennent à manquer.",
    ["Hunters only"] = "Chasseurs uniquement",
    ["Warn when it runs low"] = "Alerter quand elles viennent à manquer",
    ["A short red line in the upper middle of the screen, once when your ammunition drops below the amount set here. It appears again only after you restock above that amount. While this is on, the count itself turns red below the threshold."]
        = "Une courte ligne rouge en haut au milieu de l’écran, une fois, dès que vos munitions passent sous la quantité réglée ici. Elle revient seulement après que vous avez reconstitué vos munitions au-dessus de ce seuil. Tant que ceci est activé, le nombre lui-même devient rouge sous cette quantité.",
    ["Warn below"] = "Alerter en dessous de",
    ["The ammunition count below which the warning appears."] = "La quantité de munitions en dessous de laquelle l’alerte apparaît.",
    ["Play a sound with it"] = "Jouer un son avec",
    ["Plays the sound selected below along with the red warning."]
        = "Le son choisi en dessous, en même temps que la ligne rouge.",
    ["Sound"] = "Son",
    ["Picks one of the game's own sounds."] = "Choisit l’un des sons du jeu.",
    ["Play the sound"] = "Jouer le son",
    ["Plays the selected sound now."] = "Joue le son choisi, maintenant.",
    ["Show the warning"] = "Afficher l’alerte",
    ["Shows the warning once, with its sound when that is on."]
        = "Affiche l’alerte une fois, avec le son s’il est activé.",
    ["Ammunition: this client has no sound called %s."]
        = "Munitions : ce client n’a pas de son nommé %s.",
    ["Low on ammunition: %d left"] = "Munitions bientôt épuisées : encore %d",
    ["Adds a button for each kind of ammunition beside merchants who sell it. A click buys as many as your quiver or ammo pouch can still hold."]
        = "À côté d’un marchand qui vend des flèches ou des balles, un bouton pour chaque sorte. Un clic en achète autant que votre carquois ou votre sacoche de munitions peut encore en contenir.",
    ["Skip the purchase dialog"] = "Passer la confirmation d’achat",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Ammunition you cannot use yet always shows the dialog."]
        = "Un clic sur un bouton à côté du marchand achète aussitôt et indique dans la discussion ce qui a été acheté. Pour les munitions que vous ne pouvez pas encore utiliser, la confirmation s’affiche toujours.",
    ["Fills your quiver with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Remplit automatiquement votre carquois avec celles-ci dès que vous ouvrez un marchand qui les vend. Une seule sorte à la fois.",
    ["Fills your ammo pouch with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Remplit automatiquement votre sacoche de munitions avec celles-ci dès que vous ouvrez un marchand qui les vend. Une seule sorte à la fois.",
    ["You cannot use these before level %d."]
        = "Vous ne pouvez pas les utiliser avant le niveau %d.",
    ["You cannot use these yet."] = "Vous ne pouvez pas encore les utiliser.",
    ["Fill the Quiver"] = "Remplir le carquois",
    ["Do not ask again"] = "Ne plus demander",
    ["Switches on \"Skip the purchase dialog\" under Ammunition on the Gameplay page, where it can be switched off again."]
        = "Active « Passer la confirmation d’achat » sous Munitions, sur la page Jeu, où cela peut être désactivé de nouveau.",
    ["Buy"] = "Acheter",
    ["Fill the Ammo Pouch"] = "Remplir la sacoche de munitions",
    ["Do you really want to buy %d %s to fill your quiver?"]
        = "Voulez-vous vraiment acheter %d %s pour remplir votre carquois ?",
    ["Do you really want to buy %d %s to fill your ammo pouch?"]
        = "Voulez-vous vraiment acheter %d %s pour remplir votre sacoche de munitions ?",
    ["Cost: %s"] = "Coût : %s",
    ["No more will fit in your quiver."] = "Votre carquois ne peut plus rien contenir.",
    ["No more will fit in your ammo pouch."] = "Votre sacoche de munitions ne peut plus rien contenir.",
    ["The merchant has none left."] = "Le marchand n’en a plus.",
    ["You cannot afford a stack."] = "Vous n’avez pas de quoi acheter une pile.",
    ["Buy this one in the merchant window."] = "Achetez celles-ci dans la fenêtre du marchand.",
    ["Your quiver cannot hold bullets."] = "Votre carquois n’accepte pas de balles.",
    ["Your ammo pouch cannot hold arrows."] = "Votre sacoche de munitions n’accepte pas de flèches.",
    ["Waiting for the previous purchase to complete."] = "En attente de la fin de l’achat précédent.",
    ["Buying from the merchant failed: %s"] = "Échec de l’achat chez le marchand : %s",
    ["Reagents"] = "Composants",
    ["Beside a merchant, a button for each reagent your class uses and, for Rogues, each poison. A click buys what is missing for the amounts set here."]
        = "À côté d’un marchand, un bouton pour chaque composant de votre classe et, pour les voleurs, pour chaque poison. Un clic achète ce qui manque pour atteindre les quantités définies ici.",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Un clic sur un bouton à côté du marchand achète aussitôt et indique dans la discussion ce qui a été acheté. Tant que vos techniques de classe n’ont besoin d’aucun composant acheté chez un marchand, la confirmation s’affiche toujours pour les composants.",
    ["%s is active: your class abilities need no reagents bought from a merchant."]
        = "Avec %s, vos techniques de classe n’ont besoin d’aucun composant acheté chez un marchand.",
    ["How many you want to carry. A Shift click changes it by a full stack."]
        = "Combien vous voulez en avoir sur vous. Un clic avec Maj modifie la quantité d’une pile entière.",
    ["Changes how many you want to carry, the same amount as under Reagents on the Gameplay page."]
        = "Modifie la quantité que vous voulez avoir sur vous, comme sous Composants, sur la page Jeu.",
    ["Your class uses no reagents."] = "Votre classe n’utilise aucun composant.",
    ["None of your spells that require reagents have been learned yet."]
        = "Vous n’avez encore appris aucun sort nécessitant un composant.",
    ["Not Relevant Right Now"] = "Pas pertinent pour l’instant",
    ["Auto Buy"] = "Achat automatique",
    ["Buys what you tick for it whenever you open a merchant who sells it: reagents and poisons up to their amounts, arrows or bullets as many as fit in your quiver or ammo pouch."]
        = "Achète ce que vous cochez pour cela dès que vous ouvrez un marchand qui le vend : composants et poisons jusqu’aux quantités définies, flèches ou balles autant que votre carquois ou votre sacoche de munitions peut en contenir.",
    ["Skip the auto buy dialog"] = "Passer la confirmation d’achat automatique",
    ["Buys without asking first and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Achète sans demander d’abord, et indique dans la discussion ce qui a été acheté. Tant que vos techniques de classe n’ont besoin d’aucun composant acheté chez un marchand, la confirmation s’affiche toujours pour les composants.",
    ["Buy Automatically"] = "Acheter automatiquement",
    ["Buy everything ticked for buying automatically?"]
        = "Acheter tout ce qui est coché pour l’achat automatique ?",
    ["Switches on \"Skip the auto buy dialog\" under Auto Buy on the Gameplay page, where it can be switched off again."]
        = "Active « Passer la confirmation d’achat automatique » sous Achat automatique, sur la page Jeu, où cela peut être désactivé de nouveau.",
    ["Buys it automatically up to this amount whenever you open a merchant who sells it."]
        = "L’achète automatiquement jusqu’à cette quantité dès que vous ouvrez un marchand qui le vend.",
    ["You have %d of %d."] = "Vous en avez %d sur %d.",
    ["Click to buy %d."] = "Cliquez pour en acheter %d.",
    ["Click to buy the ingredients for %d."] = "Cliquez pour acheter les ingrédients pour %d.",
    ["You have enough."] = "Vous en avez assez.",
    ["Just bought."] = "Acheté à l’instant.",
    ["You cannot afford the ingredients."] = "Vous n’avez pas de quoi acheter les ingrédients.",
    ["Buy the ingredients in the merchant window."]
        = "Achetez les ingrédients dans la fenêtre du marchand.",
    ["Buy Reagents"] = "Acheter des composants",
    ["Do you really want to buy %d %s? You will then have %d."]
        = "Voulez-vous vraiment acheter %d %s ? Vous en aurez alors %d.",
    ["Buy Poison Ingredients"] = "Acheter des ingrédients de poison",
    ["Do you really want to buy the ingredients for %d %s?"]
        = "Voulez-vous vraiment acheter les ingrédients pour %d %s ?",
    ["Switches on \"Skip the purchase dialog\" under Reagents on the Gameplay page, where it can be switched off again."]
        = "Active « Passer la confirmation d’achat » sous Composants, sur la page Jeu, où cela peut être désactivé de nouveau.",
    ["Bought %d %s for %s."] = "Achat de %d %s pour %s.",
    ["Bought the ingredients for %d %s for %s."] = "Ingrédients pour %d %s achetés pour %s.",
    ["Click to buy %d and fill your quiver."]
        = "Cliquez pour en acheter %d et remplir votre carquois.",
    ["Click to buy %d and fill your ammo pouch."]
        = "Cliquez pour en acheter %d et remplir votre sacoche de munitions.",
    ["Bought %d %s for %s to fill your quiver."]
        = "Achat de %d %s pour %s afin de remplir votre carquois.",
    ["Bought %d %s for %s to fill your ammo pouch."]
        = "Achat de %d %s pour %s afin de remplir votre sacoche de munitions.",

    -- Modules/BagWindow.lua
    ["Movable Bag Windows"] = "Fenêtres de sacs déplaçables",
    ["Hold Shift and drag the bag window by its title bar to move it, while your bags are combined into one window."]
        = "Maintenez Maj et faites glisser la fenêtre des sacs par sa barre de titre pour la déplacer, tant que vos sacs sont réunis en une seule fenêtre.",
    ["Reset position"] = "Position par défaut",
    ["Puts the bag window back where the game places it."]
        = "Remet la fenêtre à sa position par défaut.",
    ["Bag window is back where the game places it."]
        = "La fenêtre des sacs est revenue à sa position par défaut.",
    ["BagWindow: this build has no combined bag window, so there is nothing to move."]
        = "Fenêtres de sacs déplaçables : cette version du client n’a pas de fenêtre de sacs réunis, il n’y a donc rien à déplacer.",

    -- Modules/MinimapButton.lua
    ["Minimap Button"] = "Bouton de la minicarte",
    ["A button on the edge of the minimap that opens this window. Drag it to move it along the edge."]
        = "Un bouton au bord de la minicarte qui ouvre cette fenêtre. Faites-le glisser pour le déplacer le long du bord.",
    ["MinimapButton: this build has no minimap to put a button on. /fplus opens the settings."]
        = "Bouton de la minicarte : cette version du client n’a pas de minicarte où placer un bouton. /fplus ouvre les réglages.",
    ["Click to open or close the settings."] = "Cliquez pour ouvrir ou fermer les réglages.",
    ["Drag to move this button along the edge of the minimap."]
        = "Faites glisser pour déplacer ce bouton le long du bord de la minicarte.",

    -- Modules/MailAlts.lua
    ["Alts in the Mail Window"] = "Fenêtre du courrier : vos personnages",
    ["Adds a button to the mail window that lists your characters of this ruleset and faction, and fills in the one you pick."]
        = "Ajoute à la fenêtre du courrier un bouton qui liste vos personnages de cet ensemble de règles et de cette faction, et inscrit celui que vous choisissez.",
    ["No other character of this ruleset and faction is known yet. Each one is added the next time it logs in."]
        = "Aucun autre personnage de cet ensemble de règles et de cette faction n’est encore connu. Un nouveau personnage s’ajoute dès sa prochaine connexion.",
    ["Your Characters"] = "Vos personnages",
    ["Your characters of this ruleset and faction. A click fills in the name, the X at the end of a row deletes the character."]
        = "Vos personnages de cet ensemble de règles et de cette faction. Un clic inscrit le nom, le X en bout de ligne supprime le personnage.",

    -- Modules/QuestZoneTracking.lua
    ["Track Zones in the Quest Log"] = "Suivre les zones du journal des quêtes",
    ["Adds a checkbox to every zone in the quest log to track or untrack all its quests with one click."]
        = "Ajoute à chaque zone du journal des quêtes une case qui suit toutes ses quêtes d’un clic, ou arrête de les suivre.",
    ["Track All"] = "Tout suivre",
    ["Untrack All"] = "Tout arrêter de suivre",
    ["QuestZoneTracking: could not hook QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Suivre les zones du journal des quêtes : impossible de se greffer sur QuestLogQuests_Update, le journal des quêtes n’a donc pas de cases.",
    ["QuestZoneTracking: this client has no QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Suivre les zones du journal des quêtes : ce client n’a pas de QuestLogQuests_Update, le journal des quêtes n’a donc pas de cases.",

    -- Modules/Diagnostics.lua
    ["Diagnostics"] = "Diagnostic",
    ["Measures what this client's API offers. Use it to diagnose problems: the report lists what exists and what does not, for whoever fixes the addon."]
        = "Mesure ce que l’interface de programmation de ce client propose. Sert à diagnostiquer les problèmes : le rapport liste ce qui existe et ce qui n’existe pas, à destination de la personne qui corrige l’add-on.",
    ["Keep the report in the saved settings"] = "Garder le rapport dans les réglages enregistrés",
    ["Saves the report, about nine hundred lines, in your saved settings. /fplus diag print reads the current one without saving it."]
        = "Enregistre le rapport, environ neuf cents lignes, dans les réglages enregistrés. /fplus diag print lit le rapport actuel sans l’enregistrer.",

    -- -----------------------------------------------------------------------
    -- Design
    -- -----------------------------------------------------------------------

    -- Modules/Theme.lua
    ["Sets the appearance of the ForeverPlus windows."] = "L’apparence des fenêtres de ForeverPlus.",
    ["Color scheme"] = "Jeu de couleurs",
    ["Applies to the ForeverPlus windows only."] = "S’applique uniquement aux fenêtres de ForeverPlus.",
    ["Show switches in your class color"] = "Afficher les cases dans la couleur de votre classe",
    ["The switches that are on and the open tab take the color of this character's class, in every color scheme."]
        = "Les cases activées et l’onglet ouvert prennent la couleur de la classe de ce personnage, dans chaque jeu de couleurs.",
    ["Background opacity"] = "Opacité du fond",
    ["Sets the background opacity of the ForeverPlus windows, the info bar and the addon's tooltips. At 100 percent, it matches the color scheme."]
        = "Le fond des fenêtres de ForeverPlus, de la barre d’infos et des bulles d’aide de l’add-on. À 100 pour cent, celui du jeu de couleurs.",
    ["Text size"] = "Taille du texte",
    ["Sets the text size as a percentage of the game's text size."] = "Un pourcentage de la taille du texte du jeu.",

    -- Core/Theme.lua
    ["Midnight"] = "Minuit",
    ["Slate"] = "Ardoise",
    ["High contrast"] = "Contraste élevé",
    ["Horde"] = "Horde",
    ["Gilded"] = "Doré",
    ["Autumn"] = "Automne",
    ["Jade"] = "Jade",
    ["Arctic"] = "Arctique",
    ["Azure"] = "Azur",
    ["Alliance"] = "Alliance",
    ["Sunset"] = "Crépuscule",

    -- -----------------------------------------------------------------------
    -- Profiles
    -- -----------------------------------------------------------------------

    -- Modules/Profiles.lua
    ["in use"] = "actif",
    ["The buttons below act on: |cffffffff%s|r"] = "Les boutons ci-dessous agissent sur : |cffffffff%s|r",
    ["... and %d more, see /fplus profile"] = "... et %d autres, voir /fplus profile",
    ["Use"] = "Utiliser",
    ["Now using %s."] = "%s est maintenant utilisé.",
    ["Reset"] = "Réinitialiser",
    ["Sure?"] = "Vraiment ?",
    ["%s is back to its defaults."] = "%s est revenu aux valeurs par défaut.",
    ["%s deleted."] = "%s supprimé.",
    ["Name for a new or renamed profile"] = "Nom d’un nouveau profil ou d’un profil renommé",
    ["New"] = "Nouveau",
    ["Created %s."] = "%s créé.",
    ["Copy"] = "Copier",
    ["%s copied from %s."] = "%s copié depuis %s.",
    ["Rename"] = "Renommer",
    ["%s is now %s."] = "%s s’appelle maintenant %s.",
    ["Export"] = "Exporter",
    ["Export profile"] = "Exporter le profil",
    ["%s, %d characters"] = "%s, %d caractères",
    ["Import"] = "Importer",
    ["Import profile"] = "Importer un profil",
    ["Paste a string, then press Import"] = "Collez un texte, puis appuyez sur Importer",
    ["Import failed: %s"] = "Échec de l’importation : %s",
    ["Imported as %s, %d skipped."] = "Importé sous %s, %d ignorés.",
    ["Imported as %s."] = "Importé sous %s.",
    ["%d profile now."] = "%d profil désormais.",
    ["%d profiles now."] = "%d profils désormais.",

    -- Core/Config.lua
    ["Settings were written by a newer version (format %d, this build reads %d). Leaving them unchanged."]
        = "Les réglages viennent d’une version plus récente (format %d, cette version lit %d). Ils restent tels quels.",
    ["No way to convert settings from format %d to %d."]
        = "Aucun moyen de convertir les réglages du format %d au format %d.",
    ["migration %d to %d"] = "conversion de %d à %d",
    ["Settings stayed at format %d."] = "Les réglages restent au format %d.",
    ["Settings converted to format %d."] = "Réglages convertis au format %d.",
    ["No character given"] = "Aucun personnage indiqué",
    ["That is the character you are playing"] = "C’est le personnage que vous jouez",
    ["Could not identify this character, so %s is in use. A /reload should fix it."]
        = "Impossible d’identifier ce personnage, %s est donc actif. Un /reload devrait corriger cela.",
    ["%s is off. Takes effect after /reload."] = "%s est désactivé. Prend effet après un /reload.",
    ["Unknown module: %s"] = "Module inconnu : %s",
    ["%s: /reload needed for the change to take effect."]
        = "%s : le changement ne prend effet qu’après un /reload.",
    ["A profile needs a name"] = "Un profil a besoin d’un nom",
    ["Profile names are limited to %d characters"] = "Les noms de profil sont limités à %d caractères",
    ["A profile name cannot contain a pipe or a control character"]
        = "Un nom de profil ne peut contenir ni barre verticale ni caractère de contrôle",
    ["A profile called %s already exists"] = "Il existe déjà un profil nommé %s",
    ["No profile called %s exists"] = "Il n’existe pas de profil nommé %s",
    ["%s is the only profile. Reset it instead of deleting it"]
        = "%s est le seul profil : réinitialisez-le au lieu de le supprimer",
    ["Profile %s takes effect when you leave combat."]
        = "Le profil %s prend effet dès que vous quittez le combat.",
    ["Profile %s disappeared before it could be applied."]
        = "Le profil %s a disparu avant de pouvoir être appliqué.",
    ["%s: /reload needed before its new settings apply."]
        = "%s : les nouveaux réglages ne s’appliquent qu’après un /reload.",
    ["Profile: %s"] = "Profil : %s",
    ["that string is not a ForeverPlus profile"] = "ce texte n’est pas un profil ForeverPlus",
    ["that profile has no readable settings in it"]
        = "ce profil ne contient aucun réglage lisible",
    ["import migration %d to %d"] = "conversion à l’importation de %d à %d",
    ["the settings being saved are not the ones in this table. The import was undone to prevent silent data loss. Please report this"]
        = "la table des réglages n’est pas celle qui est enregistrée : l’importation a été annulée pour éviter une perte de données inaperçue. Merci de le signaler",
    ["the profile was not saved successfully. Please report this"]
        = "le profil n’a pas pu être enregistré correctement. Merci de le signaler",

    -- Core/Serialize.lua
    ["nested too deeply"] = "imbrication trop profonde",
    ["the string ends before a value is complete"] = "le texte s’arrête au milieu d’une valeur",
    ["a string is missing its length"] = "la longueur d’un texte n’est pas indiquée",
    ["a string has an invalid length"] = "un texte a une longueur invalide",
    ["a string extends beyond the end of the data"] = "un texte dépasse la fin",
    ["a number has no terminating marker"] = "il manque le marqueur de fin d’un nombre",
    ["a number is not a number"] = "un nombre n’est pas un nombre",
    ["a boolean is neither true nor false"] = "un booléen n’est ni vrai ni faux",
    ["a table is missing its size"] = "la taille d’une table n’est pas indiquée",
    ["a table has an invalid size"] = "une table a une taille invalide",
    ["a table specifies more entries than the string contains"]
        = "une table annonce plus d’entrées que le texte n’en contient",
    ["unknown marker at position %d"] = "marqueur inconnu à la position %d",
    ["nothing to import"] = "rien à importer",
    ["this does not look like a ForeverPlus string"]
        = "ceci ne ressemble pas à un texte ForeverPlus",
    ["this string is version %s, but this build reads %s"] = "ce texte est en version %s, et la version lue est %s",
    ["the string is damaged or incomplete (%d characters received). If you pasted it, it may have been truncated. Paste it again and check that the end matches"]
        = "le texte est endommagé ou incomplet (%d caractères reçus). S’il a été collé, il a peut-être été coupé : collez-le de nouveau et vérifiez que la fin correspond",
    ["unexpected text after the end of the data"]
        = "un texte inattendu suit la fin des données",

    -- -----------------------------------------------------------------------
    -- Info
    -- -----------------------------------------------------------------------

    -- Modules/Info.lua
    ["All rights reserved"] = "Tous droits réservés",
    ["About"] = "À propos",
    ["Author"] = "Auteur",
    ["License"] = "Licence",
    ["Client"] = "Client",
    ["Contact"] = "Contact",
    ["Leave ideas and bug reports in the comments on CurseForge"]
        = "Laissez vos idées et signalements de bugs dans les commentaires sur CurseForge",
    ["Free to use, but not open source. You may not redistribute it, publish modified versions or reuse it in other addons. Provided without warranty. See the LICENSE file for the full terms."]
        = "Gratuit, mais pas open source : il ne peut être ni redistribué, ni modifié et publié, ni réutilisé dans d’autres add-ons. Fourni sans garantie. Les conditions complètes figurent dans le fichier LICENSE.",

    -- -----------------------------------------------------------------------
    -- Info bar
    -- -----------------------------------------------------------------------

    -- Modules/InfoBar.lua
    ["Shows an info bar with your gold, durability, coordinates, latency and more."]
        = "Affiche une barre d’infos avec votre or, la durabilité, les coordonnées, la latence et plus encore.",
    ["What It Shows"] = "Ce qu’elle affiche",
    ["Allow reordering"] = "Permettre de changer l’ordre",
    ["Drag the entries above to change their order on the info bar."]
        = "Faites glisser les entrées de la liste plus haut pour changer leur ordre dans la barre d’infos.",
    ["Restore default order"] = "Rétablir l’ordre par défaut",
    ["Puts the entries back in their default order, here and on the info bar."]
        = "Remet les entrées dans leur ordre par défaut, ici et dans la barre d’infos.",
    ["Time"] = "Heure",
    ["The time of day, as the game's own clock shows it."]
        = "L’heure, telle que l’affiche l’horloge du jeu.",
    ["Shows"] = "Affiche",
    ["Local time"] = "Heure locale",
    ["Realm time"] = "Heure du royaume",
    ["Choose local or realm time for both this bar and the minimap clock."]
        = "Choisissez l’heure locale ou l’heure du royaume pour cette barre et l’horloge de la minicarte.",
    ["Choose a 12 or 24 hour format for both this bar and the minimap clock."]
        = "Choisissez le format sur 12 ou 24 heures pour cette barre et l’horloge de la minicarte.",
    ["Format"] = "Format",
    ["24 hours"] = "24 heures",
    ["12 hours"] = "12 heures",
    ["Hearthstone"] = "Pierre de foyer",
    ["Where your Hearthstone takes you and how long until it is ready."]
        = "Où votre pierre de foyer vous emmène et dans combien de temps elle sera prête.",
    ["Gold"] = "Or",
    ["Adds up each selected character's gold as of their last login."]
        = "Additionne l’or des personnages choisis ci-dessous, selon ce que chacun possédait lors de sa dernière connexion.",
    ["Characters"] = "Personnages",
    ["Whose gold the display adds up. Its list shows every character, the ones not counted grayed out. A ruleset is, for example, Normal or PvP."]
        = "Les personnages dont l’or est inclus dans le total affiché. La liste montre tous les personnages, ceux qui ne sont pas comptés étant grisés. Normal et JcJ sont des exemples d’ensembles de règles.",
    ["All"] = "Tous",
    ["This ruleset and faction"] = "Cet ensemble de règles et cette faction",
    ["Only this one"] = "Seulement celui-ci",
    ["This ruleset"] = "Cet ensemble de règles",
    ["Hide characters not counted"] = "Masquer les personnages non comptés",
    ["PvE"] = "JcE",
    ["PvP"] = "JcJ",
    ["The list on hover leaves out the characters the display does not count."]
        = "La liste au survol omet les personnages que l’affichage ne compte pas.",
    ["Shown as"] = "Affichage",
    ["Shows one display for all bags, with a breakdown by bag type on hover, or one display per bag type, with its name on hover."]
        = "Un seul affichage pour tous les sacs, détaillé par type au survol, ou un affichage par type de sac, nommé au survol.",
    ["One display"] = "Un seul affichage",
    ["A display per kind of bag"] = "Un affichage par type de sac",
    ["Ordinary bags"] = "Sacs ordinaires",
    ["Special bag"] = "Sac spécial",
    ["Merchant's Favor"] = "Faveur marchande",
    ["How much Merchant's Favor this character has. Red once it holds as much as the game allows."]
        = "La faveur marchande de ce personnage. En rouge dès qu’il en a autant que le jeu le permet.",
    ["Honor Points"] = "Points d’honneur",
    ["How many Honor Points this character has. Red once it holds as much as the game allows."]
        = "Les points d’honneur de ce personnage. En rouge dès qu’il en a autant que le jeu le permet.",
    ["Volume"] = "Volume",
    ["Shows the game's master volume. Hover over the display to adjust it with a slider. The speaker is crossed out while sound is disabled or the volume is at 0%, and the figure turns red while sound is disabled."]
        = "Le volume principal du jeu. Passez la souris dessus pour le régler avec un curseur. Le haut-parleur est barré si tous les sons sont désactivés ou si le volume est à 0%. Le nombre devient rouge si tous les sons sont désactivés.",
    ["Master Volume"] = "Volume principal",
    ["Cooldowns"] = "Temps de recharge",
    ["Shows the profession cooldowns and %s for all your characters. Hover over the icon to see the time remaining."]
        = "Affiche les temps de recharge des métiers et de « %s » pour tous vos personnages. Survolez l’icône pour voir le temps restant.",
    ["Ready"] = "Prêt",
    ["%d d %d h"] = "%d j %d h",
    ["%d h %d min"] = "%d h %d min",
    ["None of your characters has one yet."] = "Aucun de vos personnages n’en a encore.",
    ["Elemental Transmutes"] = "Transmutations élémentaires",
    ["Durability"] = "Durabilité",
    ["Shows the lowest durability among your equipped items."]
        = "L’état le plus bas parmi les pièces que vous portez.",
    ["Coordinates"] = "Coordonnées",
    ["Where you are in the current zone."] = "Où vous êtes dans la zone actuelle.",
    ["Zone"] = "Zone",
    ["Shows your current zone and subzone in the minimap's colors."]
        = "La zone où vous êtes et le lieu précis dans cette zone, colorés comme sur la minicarte.",
    ["%s: %s"] = "%s : %s",
    ["Latency"] = "Latence",
    ["Frames per second"] = "IPS",
    ["Placement"] = "Position",
    ["Position on screen"] = "Position à l’écran",
    ["Back to the default near the top of the screen."]
        = "Retour à la position par défaut en haut de l’écran.",
    ["%d ms"] = "%d ms",
    ["%d fps"] = "%d IPS",
    ["No Hearthstone"] = "Pas de pierre de foyer",
    ["%sk xp/h"] = "%sk PX/h",
    ["%d xp/h"] = "%d PX/h",
    ["%s h to level"] = "%s h avant le niveau",
    ["%d min to level"] = "%d min avant le niveau",
    ["Info bar: this client build does not recognize currency %d, so %s stays empty."]
        = "Barre d’infos : cette version du client ne connaît pas la monnaie %d, %s reste donc vide.",
    ["Maximum"] = "Maximum",
    ["This session"] = "Cette session",
    ["Repair cost"] = "Coût de réparation",
    ["Experience per hour"] = "PX par heure",
    ["Time to the next level"] = "Temps avant le prochain niveau",
    ["Info bar is back at its default position."]
        = "La barre d’infos est revenue à sa position par défaut.",
    ["Info bar can be dragged. Press the button again when it is where you want it."]
        = "La barre d’infos peut maintenant être déplacée. Appuyez de nouveau sur le bouton quand elle est bien placée.",
    ["Info bar is fixed again."] = "La barre d’infos est de nouveau fixe.",
    ["Click to use it"] = "Cliquez pour l’utiliser",
    ["Info bar: this client build cannot provide %s, so those entries stay empty regardless of their settings."]
        = "Barre d’infos : cette version du client ne peut pas fournir %s. Ces éléments restent vides, quel que soit leur réglage.",
    ["Use it with a click"] = "L’utiliser d’un clic",
    ["A click on the display uses your Hearthstone."]
        = "Un clic sur l’affichage utilise votre pierre de foyer.",
    ["Move it with Shift and drag"] = "Déplacer avec Maj et en faisant glisser",
    ["While Shift is held, you can drag the bar by any display, and clicking the Hearthstone does not use it."]
        = "Tant que Maj est enfoncée, la barre peut être déplacée par n’importe lequel de ses affichages. Un clic sur la pierre de foyer dans la barre ne l’utilise alors pas.",

    -- -----------------------------------------------------------------------
    -- Tooltip
    -- -----------------------------------------------------------------------

    -- Modules/Tooltip.lua
    ["Extra lines in the game tooltip, and where the tooltip appears."]
        = "Des lignes en plus dans la bulle d’aide du jeu, et le coin où elle se place.",
    ["General"] = "Général",
    ["Add extra information"] = "Ajouter des informations",
    ["The lines this addon adds. The arrangement and the position still work while this is off."]
        = "Les lignes que cet add-on écrit lui-même. Désactivé, la disposition et la position continuent de fonctionner.",
    ["Not in use until you switch extra information on."]
        = "Inactif tant que les informations en plus ne sont pas activées.",
    ["Layout"] = "Disposition",
    ["How the lines are arranged"] = "Disposition des lignes",
    ["Blizzlike"] = "Blizzlike",
    ["One per line"] = "Une par ligne",
    ["Compact"] = "Compacte",
    ["Blizzlike keeps the client's lines in their original order and adds the rest underneath. One per line gives every entry its own line. Compact pairs entries up."]
        = "Blizzlike garde les lignes du client dans leur ordre et ajoute le reste en dessous. Une par ligne donne à chaque élément sa propre ligne. Compacte les regroupe par deux.",
    ["Where it appears"] = "Où elle apparaît",
    ["Default"] = "Défaut",
    ["Top left"] = "En haut à gauche",
    ["Top right"] = "En haut à droite",
    ["Bottom left"] = "En bas à gauche",
    ["Default leaves the tooltip where the client puts it. The other options pin it to the chosen corner, and it grows inward."]
        = "Défaut laisse la bulle d’aide là où le client la place. Les trois autres la fixent dans ce coin, et elle s’agrandit vers l’intérieur.",
    ["Lines on a Unit"] = "Lignes sur une unité",
    ["Level"] = "Niveau",
    ["Shows a player's or creature's level. Under Blizzlike, it covers the whole line the client writes, including race."]
        = "Son niveau. Avec Blizzlike, cela concerne toute la ligne écrite par le client, race comprise.",
    ["Class"] = "Classe",
    ["Shows a player's class."] = "La classe d’un joueur.",
    ["Race"] = "Race",
    ["Shows a player's race or a creature's type."]
        = "La race d’un joueur, ou le type de créature.",
    ["Blizzlike includes race on the level line, so the Level switch controls both."]
        = "Blizzlike écrit la race sur la ligne du niveau, la case Niveau concerne donc les deux.",
    ["Faction"] = "Faction",
    ["Which side they are on."] = "Son camp.",
    ["Guild"] = "Guilde",
    ["The guild a player belongs to."] = "La guilde d’un joueur.",
    ["Guild rank"] = "Grade de guilde",
    ["The rank they hold there."] = "Son grade dans cette guilde.",
    ["Target"] = "Cible",
    ["Shows who they have targeted, or \"you\" if it is you."]
        = "Qui il a sélectionné. Affiche « vous » quand c’est vous.",
    ["Class color on the name"] = "Couleur de classe sur le nom",
    ["Colors a player's name by their class."]
        = "Colore le nom d’un joueur selon sa classe.",
    ["Lines on an Item or Spell"] = "Lignes sur un objet ou un sort",
    ["What it sells for"] = "Prix de vente",
    ["Shows what a vendor pays for the item and the value of the whole stack."]
        = "Ce que paie un marchand, et ce que vaut toute la pile.",
    ["Item and spell ids"] = "Identifiants des objets et des sorts",
    ["Shows the IDs of an item, spell or creature."]
        = "Les numéros derrière un objet, un sort ou une créature.",
    ["Lines on Herbs, Veins and Corpses"] = "Lignes sur les plantes, les filons et les cadavres",
    ["Skill needed to gather"] = "Compétence requise pour récolter",
    ["Shows the Herbalism, Mining or Skinning skill required for herbs, veins and corpses, in the color the game uses for your skill level."]
        = "Le niveau d’herboristerie, de minage ou de dépeçage qu’une plante, un filon ou un cadavre demande, dans la couleur que le jeu donne à votre compétence.",
    ["Sells for (%d)"] = "Prix de vente (%d)",
    ["Sells for"] = "Prix de vente",
    ["Item"] = "Objet",
    ["Spell"] = "Sort",
    ["Requires %s"] = "Requiert %s",
    ["you"] = "vous",
    ["Tooltip: TooltipDataProcessor is unavailable in this client build, so no lines can be added. Placement still works."]
        = "Bulles d’aide : TooltipDataProcessor est absent, aucune ligne ne peut donc être ajoutée dans cette version du client. La position fonctionne toujours.",
    ["Tooltip: GameTooltip_SetDefaultAnchor is unavailable in this client build, so the corner setting has no effect."]
        = "Bulles d’aide : GameTooltip_SetDefaultAnchor est absent, le réglage du coin est donc sans effet dans cette version du client.",

    -- Data/Gathering.lua
    ["Herbalism"] = "Herboristerie",
    ["Mining"] = "Minage",
    ["Skinning"] = "Dépeçage",

    -- -----------------------------------------------------------------------
    -- Consumables
    -- -----------------------------------------------------------------------

    -- Modules/Consumables.lua
    ["Warns when a selected consumable effect is missing or about to expire."]
        = "Avertit quand l’effet d’un consommable sélectionné manque ou va bientôt expirer.",
    ["Main Hand"] = "Main droite",
    ["Off Hand"] = "Main gauche",
    ["%d min"] = "%d min",
    ["%d:%02d min"] = "%d:%02d min",
    ["Show the remaining time"] = "Afficher le temps restant",
    ["Icon size"] = "Taille des icônes",
    ["Conditions"] = "Conditions",
    ["Warn at"] = "Alerter à",
    ["The remaining time at which a consumable warning appears."]
        = "Le temps restant à partir duquel l’alerte des consommables apparaît.",
    ["Measurement"] = "Mesure",
    ["Print what was recorded"] = "Afficher ce qui a été enregistré",
    ["Prints everything the probe recorded during this session in chat. The data is also saved and restored after a reload."]
        = "Tout ce que la sonde a vu pendant cette session, sous forme de lignes de discussion. C’est aussi dans le fichier enregistré, d’où c’est relu après un rechargement.",
    ["Consumables: C_Timer.NewTicker is missing, so the countdown only updates when something changes."]
        = "Consommables : C_Timer.NewTicker est absent, le compte à rebours ne se met donc à jour que lorsque quelque chose change.",
    ["Weapon Coatings"] = "Pierres et huiles",

    -- Data/Consumables.lua
    ["Weapon Oil"] = "Huile pour arme",
    ["Sharpening Stone"] = "Pierre à aiguiser",
    ["Weightstone"] = "Caillou",
    ["Food"] = "Nourriture",
    ["Any Food Buff"] = "Tout buff de nourriture",
    ["Watches for a food buff, whichever food it came from: warns when none is on you, and before the one you have runs out."]
        = "Surveille un buff de nourriture, quelle que soit la nourriture : alerte quand vous n’en avez aucun, et avant que le vôtre ne se termine.",
    ["Strength"] = "Force",
    ["Agility"] = "Agilité",
    ["Armor"] = "Armure",
    ["Stamina"] = "Endurance",
    ["Health Regeneration"] = "Régénération de vie",
    ["Mana Regeneration"] = "Régénération de mana",
    ["Spell Power"] = "Puissance des sorts",
    ["Fire Power"] = "Puissance du feu",
    ["Frost Power"] = "Puissance du givre",
    ["Shadow Power"] = "Puissance de l’ombre",
    ["Resistance"] = "Résistance",
    ["Blasted Lands and Zandalar"] = "Terres foudroyées et Zandalar",
    ["Attack Power"] = "Puissance d’attaque",
    ["Juju"] = "Juju",
    ["Hit Chance"] = "Chances de toucher",
    ["Alcohol"] = "Alcool",
    ["Other"] = "Autres",
    ["Flask"] = "Flacon",
    ["Intellect"] = "Intelligence",
    ["Spirit"] = "Esprit",

    -- Core/Warnings.lua
    ["Gray"] = "Gris",
    ["Original colors"] = "Couleurs d’origine",
    ["Dimmed"] = "Assombri",
    ["Alert red"] = "Rouge d’alerte",
    ["Scheme color"] = "Couleur du jeu de couleurs",
    ["new"] = "nouveau",

    -- Modules/Consumables.lua, names for an item or spell the client cannot name
    ["Item %s"] = "Objet %s",
    ["Spell %s"] = "Sort %s",

    -- Modules/Consumables.lua, a row whose item is not loaded
    ["Item %s, not loaded yet"] = "Objet %s, pas encore chargé",
    ["Nothing to look up"] = "Rien à rechercher",

    -- -----------------------------------------------------------------------
    -- Buffs
    -- -----------------------------------------------------------------------

    -- Modules/BuffExpiry.lua
    ["Warns when a long buff is running out."] = "Alerte quand un buff long arrive à sa fin.",
    ["Your own buffs"] = "Vos propres buffs",
    ["Armor spells, shouts, Inner Fire: anything you cast on yourself that runs out."]
        = "Armures, cris, Feu intérieur : tout ce que vous lancez sur vous-même et qui se termine.",
    ["Group buffs"] = "Buffs de groupe",
    ["Buffs you also put on other people. The icon shows how many nearby players are missing the buff, except in combat."]
        = "Les buffs que vous donnez aussi aux autres. L’icône indique combien de personnes autour de vous ne l’ont pas, sauf en combat.",
    ["Weapon imbues and poisons"] = "Enchantements d’arme et poisons",
    ["Warnings about the imbues, poisons, Firestones and Spellstones on your weapons."]
        = "Alertes sur les enchantements d’arme, poisons, pierres de feu et pierres de sort sur vos armes.",
    ["Tracking"] = "Pistage",
    ["Shows an icon whenever none of the tracking abilities you selected in the Tracking section is active. Either gathering tracking ability is enough."]
        = "Une icône dès qu’aucun des pistages choisis dans la section Pistage n’est actif. L’un des deux pistages de récolte suffit.",
    ["Warn short buffs at"] = "Buffs courts : alerter à",
    ["Applies to every buff lasting under 10 minutes."]
        = "S’applique à chaque buff qui dure moins de 10 minutes.",
    ["Warn medium buffs at"] = "Buffs moyens : alerter à",
    ["Applies to every buff lasting 10 to 29 minutes."]
        = "S’applique à chaque buff qui dure de 10 à 29 minutes.",
    ["Warn long buffs at"] = "Buffs longs : alerter à",
    ["Applies to every buff lasting 30 minutes or more."]
        = "S’applique à chaque buff qui dure 30 minutes ou plus.",
    ["Warn while mounted"] = "Alerter sur une monture",
    ["Off: no warnings while you are mounted."] = "Désactivé : aucune alerte tant que vous êtes sur une monture.",
    ["Warn in a rested area"] = "Alerter dans une zone de repos",
    ["Off: no warnings in cities and inns."] = "Désactivé : aucune alerte dans les villes et les auberges.",
    ["Buffs from others in dungeons"] = "Buffs des autres en donjon",
    ["Warnings about a buff another class in your group could give you, while you are in a dungeon."]
        = "Alertes sur un buff qu’une autre classe de votre groupe pourrait vous donner, tant que vous êtes dans un donjon.",
    ["Buffs from others in raids"] = "Buffs des autres en raid",
    ["Warnings about a buff another class in your group could give you, while you are in a raid."]
        = "Alertes sur un buff qu’une autre classe de votre groupe pourrait vous donner, tant que vous êtes dans un raid.",
    ["Buffs from others in the open world"] = "Buffs des autres dans le monde",
    ["Warnings about a buff another class in your group could give you, anywhere outside a dungeon, a raid or a battleground."]
        = "Alertes sur un buff qu’une autre classe de votre groupe pourrait vous donner, partout hors des donjons, des raids et des champs de bataille.",
    ["Count group members within"] = "Compter les membres du groupe dans un rayon de",
    ["%d yd"] = "%d m",
    ["Group members farther away are not counted for buffs they could give you or buffs you could give them."]
        = "Les membres du groupe plus éloignés ne comptent ni pour les buffs qu’ils pourraient vous donner ni pour ceux que vous pourriez leur donner.",
    ["General Warnings"] = "Alertes générales",
    ["Combat Buffs"] = "Buffs de combat",
    ["Buffs on You Right Now"] = "Vos buffs actuels",
    ["During combat, the client cannot check whether %s is active on you. The addon can only track it from your own casts. If another player casts it on you, it may be reported as missing until combat ends. This message is shown once per character."]
        = "En combat, le client ne peut pas vérifier si %s est actif sur vous. L’add-on ne peut suivre ce buff que d’après vos propres lancements. Si un autre joueur vous le lance, il peut être signalé comme manquant jusqu’à la fin du combat. Ce message ne s’affiche qu’une fois par personnage.",
    ["BuffExpiry: C_Timer.NewTicker is missing, so the countdown only updates when a buff changes."]
        = "Buffs : C_Timer.NewTicker est absent, le compte à rebours ne se met donc à jour que lorsqu’un buff change.",
    ["missing"] = "manquant",
    ["upgrade"] = "rang supérieur",
    ["showing"] = "affiché",
    ["handout"] = "pour les autres",
    ["waiting"] = "en attente",
    ["unavailable"] = "indisponible",
    ["off"] = "désactivé",
    ["%s of %s"] = "%s sur %s",
    ["... and %d more"] = "... et %d autres",
    ["In combat, these are the remaining times recorded just before the fight, continuing to count down. Buffs cast on you by other players appear after combat ends."]
        = "En combat, ce sont les durées d’avant le combat, décomptées exactement. Un buff que quelqu’un d’autre vous lance n’apparaît qu’après le combat.",
    ["No timed buffs on you."] = "Aucun buff à durée limitée sur vous.",
    ["(timer only)"] = "(minuteur seul)",
    ["(own class only)"] = "(votre classe uniquement)",
    ["(not trained)"] = "(non appris)",
    ["(not your race)"] = "(pas votre race)",
    ["Class Buffs"] = "Buffs de classe",
    ["(you)"] = "(vous)",
    ["Track on yourself"] = "Suivre sur vous-même",
    ["Also tracks this buff on you."] = "Suit aussi ce buff sur vous.",
    ["Track on friendly targets"] = "Suivre sur des cibles amicales",
    ["%d player"] = "%d joueur",
    ["%d players"] = "%d joueurs",
    ["How many other players must have this buff active, not counting you. Outside combat, the icon shows how many are still missing it."]
        = "Sur combien d’autres joueurs ce buff doit rester, vous non compris. Hors combat, l’icône indique combien ne l’ont pas encore.",
    ["Track on every group or raid member"]
        = "Suivre sur tous les membres du groupe ou du raid",
    ["Shows an icon whenever your pet is not happy, with a red border when it becomes unhappy. The icon is hidden during combat."]
        = "Une icône tant que votre familier n’est pas heureux, avec une bordure rouge dès qu’il est mécontent. Pas en combat.",
    ["Tracks this buff on every member of your group or raid instead of using the number above. Outside combat, the icon shows how many are still missing it."]
        = "Suit le buff sur tous les membres de votre groupe ou de votre raid au lieu du nombre ci-dessus. Hors combat, l’icône indique combien ne l’ont pas encore.",
    ["Only warn in combat"] = "Alerter seulement en combat",
    ["Warns about this buff only during a fight."]
        = "Alerte sur ce buff seulement pendant un combat.",

    -- Data/Buffs.lua, a name for when the client gives none
    ["Mark of the Wild"] = "Marque du fauve",
    ["Thorns"] = "Epines",
    ["Aspect of the Wild"] = "Aspect de la nature",
    ["Trueshot Aura"] = "Aura de précision",
    ["Aspect"] = "Aspect",
    ["Arcane Intellect"] = "Intelligence des arcanes",
    ["Armor Spell"] = "Armure",
    ["Blessing"] = "Bénédiction",
    ["Aura"] = "Aura",
    ["Righteous Fury"] = "Fureur vertueuse",
    ["Seal"] = "Sceau",
    ["Power Word: Fortitude"] = "Mot de pouvoir : Robustesse",
    ["Divine Spirit"] = "Esprit divin",
    ["Shadow Protection"] = "Protection contre l'Ombre",
    ["Inner Fire"] = "Feu intérieur",
    ["Touch of Weakness"] = "Toucher de faiblesse",
    ["Shadowguard"] = "Garde de l'ombre",
    ["Main Hand Poison"] = "Poison de la main droite",
    ["Off Hand Poison"] = "Poison de la main gauche",
    ["Shield Spell"] = "Bouclier",
    ["Main Hand Imbue"] = "Enchantement de la main droite",
    ["Off Hand Imbue"] = "Enchantement de la main gauche",
    ["Demon Armor"] = "Armure démoniaque",
    ["Firestone or Spellstone"] = "Pierre de feu ou pierre de sort",
    ["Amplify Magic"] = "Amplification de la magie",
    ["Dampen Magic"] = "Atténuation de la magie",
    ["Water Breathing"] = "Respiration aquatique",
    ["Water Walking"] = "Marche sur l’eau",
    ["Unending Breath"] = "Respiration interminable",
    ["Detect Invisibility"] = "Détection de l'invisibilité",
    ["Pet Happiness"] = "Humeur du familier",
    ["Battle Shout"] = "Cri de guerre",

    -- Data/Tracking.lua
    ["Find Minerals"] = "Découverte de gisements",
    ["Find Herbs"] = "Découverte d'herbes",
    ["Find Treasure"] = "Découverte de trésors",

    -- -----------------------------------------------------------------------
    -- Chat
    -- -----------------------------------------------------------------------

    -- Modules/Chat.lua
    ["%d min %d s"] = "%d min %d s",
    ["Controls the chat's appearance, its surrounding buttons, and notification sounds."]
        = "Règle l’aspect de la discussion, les boutons qui l’entourent et les sons de notification.",
    ["Names"] = "Noms",
    ["How names are written"] = "Écriture des noms",
    ["Full name"] = "Nom complet",
    ["Initial and surname"] = "Initiale et nom de famille",
    ["First name only"] = "Prénom seulement",
    ["Surname only"] = "Nom de famille seulement",
    ["Initials"] = "Initiales",
    ["Shortens the name of the sender of each line. Hover over a shortened name to see the full name. Whispers are always addressed to the full name."]
        = "Raccourcit le nom de l’auteur d’une ligne. Survoler un nom raccourci l’affiche en entier, et un chuchotement va toujours au nom complet.",
    ["Race icon before the name"] = "Icône de race devant le nom",
    ["The race of whoever wrote a line, as an icon in front of the name."]
        = "La race de l’auteur d’une ligne, sous forme d’icône devant le nom.",
    ["Class icon before the name"] = "Icône de classe devant le nom",
    ["The class of whoever wrote a line, as an icon in front of the name."]
        = "La classe de l’auteur d’une ligne, sous forme d’icône devant le nom.",
    ["%d px"] = "%d px",
    ["Not in use until you switch on a race or class icon."] = "Inactif tant qu’aucune icône de race ou de classe n’est activée.",
    ["Sets the size of both icons. Lines already in the chat keep the size they had when they arrived."]
        = "La taille des deux icônes. Les lignes déjà dans la discussion gardent leur taille.",
    ["Channel Labels"] = "Abréviations des canaux",
    ["Use the labels below"] = "Utiliser les abréviations ci-dessous",
    ["Off: channels and groups appear in chat as the game writes them. Your labels below are kept."]
        = "Désactivé : les canaux et les groupes apparaissent dans la discussion comme le jeu les écrit. Vos abréviations ci-dessous sont conservées.",
    ["Channel labels"] = "Abréviations des canaux",
    ["Not in use until you switch the labels on."]
        = "Inactif tant que les abréviations ne sont pas activées.",
    ["A numbered channel uses its number as its label unless you enter a different one. Labels move with their channels when you reorder them. A number entered in a field always refers to that channel's number. An empty field leaves the label as the client writes it. The square beside each field shows that chat's color."]
        = "Un canal numéroté s’affiche sous son numéro, sauf si son champ dit autre chose, et une abréviation suit son canal quand les canaux sont réordonnés. Un nombre dans un champ représente toujours le numéro du canal lui-même. Un champ vide laisse l’abréviation telle que le client l’écrit. Le carré à côté a la couleur de cette discussion.",
    ["Timestamps"] = "Heures des messages",
    ["Timestamp format"] = "Format de l’heure",
    ["None"] = "Aucun",
    ["03:27 PM"] = "03:27 PM",
    ["03:27:32 PM"] = "03:27:32 PM",
    ["Uses the client's timestamp setting. Changing it here also changes it in the game's options, and vice versa. Timestamps appear in square brackets."]
        = "Le réglage d’heure des messages du client. Le modifier ici le modifie aussi dans les options du jeu, et inversement. La discussion l’affiche entre crochets.",
    ["Appearance"] = "Apparence",
    ["Sets the text size for every chat window at once. Each window's tab menu can still set its size individually. Windows without a chosen size default to 16."]
        = "La taille du texte du client, pour toutes les fenêtres de discussion à la fois. Le menu d’un onglet règle toujours une seule fenêtre. Une fenêtre dont la taille n’a jamais été choisie commence à 16.",
    ["Space between lines"] = "Espace entre les lignes",
    ["Extra room between two lines of chat."] = "De l’espace en plus entre deux lignes de discussion.",
    ["Outline"] = "Contour",
    ["Thin"] = "Fin",
    ["Thick"] = "Épais",
    ["Adds an outline around every letter, alongside the shadow."]
        = "Un trait autour de chaque lettre, en plus de l’ombre.",
    ["Never fade chat out"] = "Ne jamais faire disparaître la discussion",
    ["Old lines stay on screen rather than dimming and vanishing."]
        = "Les anciennes lignes restent à l’écran au lieu de pâlir et disparaître.",
    ["Fade after"] = "Faire disparaître après",
    ["Not in use until you let the chat fade."] = "Inactif tant que la discussion reste toujours visible.",
    ["How long a line stays before it fades."]
        = "Combien de temps une ligne reste avant de disparaître.",
    ["Chat Window"] = "Fenêtre de discussion",
    ["Hide the chat buttons"] = "Masquer les boutons de discussion",
    ["Hides the buttons beside the chat window and the one that jumps to the newest line."]
        = "Les boutons à côté de la fenêtre de discussion, et celui qui saute à la ligne la plus récente.",
    ["Show tabs only under the mouse"] = "Onglets seulement sous la souris",
    ["The window tabs disappear while the mouse is elsewhere. A tab with a new message still lights up."]
        = "Les onglets des fenêtres disparaissent tant que la souris est ailleurs. Un onglet avec un nouveau message s’allume quand même.",
    ["Show the input line only after Enter"] = "Ligne de saisie seulement après Entrée",
    ["Uses the client's chat style: the input line appears when you press Enter and disappears when the message is sent. Takes effect the next time the input line closes."]
        = "Le style de discussion du client : la ligne de saisie apparaît quand vous appuyez sur Entrée et disparaît quand le message est envoyé. Prend effet la prochaine fois que la ligne de saisie se ferme.",
    ["Input"] = "Saisie",
    ["Arrow keys bring back what you sent"] = "Les flèches rappellent vos messages",
    ["Use the Up and Down arrows in the input line to browse messages you sent during this session without holding Alt. Protected commands like /target and /cast still need Alt. In combat, keys without a modifier that the input does not use have no effect while it is open."]
        = "Haut et Bas dans la ligne de saisie parcourent ce que vous avez envoyé pendant cette session, sans maintenir Alt. Les commandes protégées comme /target et /cast nécessitent toujours Alt. En combat, les touches sans modificateur que la saisie n’utilise pas restent sans effet tant qu’elle est ouverte.",
    ["Use Alt and Up for %s. The game blocks this command on the plain arrow keys."]
        = "Utilisez Alt et Haut pour %s. Le jeu bloque cette commande sur les flèches seules.",
    ["Mouse Wheel"] = "Molette",
    ["Shift and the wheel jump to the top or bottom"]
        = "Maj et la molette sautent en haut ou en bas",
    ["Hold Shift and move the wheel one notch to jump straight to the top or bottom."]
        = "Un cran de molette avec Maj enfoncée va jusqu’en haut ou en bas.",
    ["Lines per wheel notch"] = "Lignes par cran de molette",
    ["How far one notch of the wheel moves."] = "Le nombre de lignes que fait défiler un cran de molette.",
    ["Copy and Search"] = "Copier et rechercher",
    ["Shift click a timestamp to quote its line"] = "Maj+clic sur l’heure cite la ligne",
    ["Not in use until you choose a timestamp format."]
        = "Inactif tant qu’aucun format de l’heure n’est choisi.",
    ["A Shift click on a timestamp copies the whole line into the chat input, including the timestamp and sender, without sending it. Lines that arrived before this was enabled stay unchanged."]
        = "Un Maj+clic sur l’heure d’un message copie toute la ligne dans la saisie, heure et expéditeur compris, sans l’envoyer. Les lignes arrivées avant l’activation restent telles quelles.",
    ["Open the chat input when it is closed"] = "Ouvrir la saisie si elle est fermée",
    ["Not in use until you switch on Shift clicking a timestamp."]
        = "Inactif tant que le Maj+clic sur l’heure n’est pas activé.",
    ["A Shift click on a timestamp opens the chat input with the line already entered, so you do not need to press Enter first."]
        = "Un Maj+clic sur l’heure d’un message ouvre la saisie avec la ligne déjà dedans, sans avoir à appuyer d’abord sur Entrée.",
    ["Search bar on the chat window"] = "Barre de recherche sur la discussion",
    ["Fade in and out"] = "Apparition et disparition progressives",
    ["Not in use until you switch the search bar on."] = "Inactif tant que la barre de recherche n’est pas activée.",
    ["The bar fades in when the mouse comes over the chat and out when it leaves, rather than appearing at once."]
        = "La barre apparaît progressivement quand la souris passe sur la discussion et disparaît quand elle la quitte, au lieu d’apparaître d’un coup.",
    ["Opacity"] = "Opacité",
    ["Sets the search bar's opacity."] = "L’opacité de la barre de recherche.",
    ["History"] = "Historique",
    ["Keep the chat across sessions"] = "Garder la discussion d’une session à l’autre",
    ["Saves every chat window when you log out or reload and restores them when this character logs in again."]
        = "Chaque fenêtre de discussion est enregistrée quand vous vous déconnectez ou rechargez, et rétablie quand ce personnage se reconnecte.",
    ["Lines kept per window"] = "Lignes gardées par fenêtre",
    ["Not in use until you keep the chat across sessions."]
        = "Inactif tant que la discussion n’est pas gardée d’une session à l’autre.",
    ["Keeps the newest lines in each window, up to the number of lines that window can hold."]
        = "Les lignes les plus récentes de chaque fenêtre sont conservées, dans la limite de ce qu’une fenêtre de discussion peut contenir.",
    ["Sounds"] = "Sons",
    ["Plays a selected sound for each enabled message type. The button beside it plays the selected sound."]
        = "Un son pour chaque type de message activé. Le bouton à côté joue le son choisi.",
    ["Pause between sounds"] = "Pause entre les sons",
    ["After a sound plays, further messages of the same type from the same person are silent until this much time has passed. Applies to whispers, officer chat and messages from the party and raid leader. Messages from other people play a sound immediately."]
        = "Après un son, les messages suivants de la même personne dans le même type de discussion restent silencieux tant que ce délai n’est pas écoulé. S’applique aux chuchotements, à la discussion des officiers et aux chefs de groupe et de raid. Le message de quelqu’un d’autre sonne aussitôt.",
    ["Raid Warnings"] = "Avertissements raid",
    ["Plays a selected sound for raid warnings. The button beside it plays the selected sound."]
        = "Un son pour les avertissements raid, tant qu’il est activé. Le bouton à côté joue le son choisi.",
    ["Pause between raid warnings"] = "Pause entre les avertissements raid",
    ["After a raid warning's sound plays, further raid warnings from the same person are silent until this much time has passed. At 0, every raid warning plays a sound."]
        = "Après le son d’un avertissement raid, les avertissements suivants de la même personne restent silencieux tant que ce délai n’est pas écoulé. À 0, chacun sonne.",

    -- Core/Util.lua, the sounds to pick from
    ["Whisper"] = "Chuchoter",
    ["Raid warning"] = "Avertissement raid",
    ["Ready check"] = "Appel",
    ["Group invite"] = "Invitation de groupe",
    ["Friend online"] = "Ami en ligne",
    ["Alarm clock"] = "Réveil",
    ["Alarm clock, short"] = "Réveil, court",
    ["Map ping"] = "Signal sur la carte",
    ["Auction house"] = "Hôtel des ventes",
    ["Coins"] = "Pièces",
    ["Level up"] = "Prise de niveau",

    -- Modules/ChatHistory.lua
    ["Chat: this client cannot add older lines to a chat window, so the saved chat is not restored."]
        = "Discussion : ce client ne peut pas ajouter d’anciennes lignes à une fenêtre de discussion, la discussion enregistrée n’est donc pas rétablie.",

    -- Modules/ChatLines.lua
    ["Chat: this client would not let a line be changed after it arrived, so labels and names stay as the game writes them."]
        = "Discussion : ce client ne permet pas de modifier une ligne après son arrivée, les abréviations et les noms restent donc tels que le jeu les écrit.",
    ["Chat: changing a line failed once and is left alone from now on this session."]
        = "Discussion : la modification d’une ligne a échoué une fois et n’est plus tentée pendant cette session.",
    ["Sets this chat's color using the client's own color picker."]
        = "La couleur de cette discussion. Le réglage du client, modifié avec son propre sélecteur de couleur.",
    ["No channels to label yet."] = "Pas encore de canaux à abréger.",

    -- Modules/ChatSearch.lua
    ["Search for \"%s\": %d matching lines, showing the latest %d"] = "Recherche de « %s » : %d lignes, les %d dernières",
    ["Search for \"%s\": %d line"] = "Recherche de « %s » : %d ligne",
    ["Search for \"%s\": %d lines"] = "Recherche de « %s » : %d lignes",
    ["Empties the search field."] = "Vide le champ de recherche.",
    ["Type a search and press Enter to display every matching line in this chat window again. Press Escape or click the X to clear the search."]
        = "Tapez, puis appuyez sur Entrée : chaque ligne correspondante de cette fenêtre de discussion est réaffichée. Échap ou le X au bout le vide.",

    -- Modules/ChatSound.lua
    ["Whispers"] = "Chuchotements",
    ["Officer Chat"] = "Discussion des officiers",
    ["Party Leader"] = "Chef de groupe",
    ["Raid Leader"] = "Chef de raid",
    ["Chat: this client has no sound called %s."]
        = "Discussion : ce client n’a pas de son nommé %s.",

    -- Late finds on the Consumables and Chat pages
    ["Replaced by a Class Buff"] = "Remplacé par un buff de classe",
    ["Replaces the label before this chat's lines. Leave it empty to use the client's label."]
        = "Remplace l’abréviation devant les lignes de cette discussion. Vide, celle du client reste.",
    ["Plays the selected sound when a message of this type arrives."]
        = "Joue le son choisi à côté quand un message de ce type arrive.",

    -- -----------------------------------------------------------------------
    -- Late finds
    -- -----------------------------------------------------------------------

    -- Gameplay, Profiles and the export. The chat commands' own texts stay
    -- English since 2026-10-07, see ENGLISH_OUTPUT in tools/l10n.py.
    ["[ForeverPlus hid]"] = "[Masqué par ForeverPlus]",
    ["%s (a %s key)"] = "%s (une clé de type %s)",
    ["%s (no such module here)"] = "%s (ce module n’existe pas ici)",
    ["Nested more than %d levels deep"] = "Imbriqué sur plus de %d niveaux",
    ["Cannot include a %s in an export string"] = "Impossible de mettre une valeur de type %s dans un texte d’exportation",
    -- Bar settings, shared movement and camp bonuses (2026-10-17).
    ["Bar %s"] = "Barre %s",
    ["Camp Benefits"] = "Bonus de campement",
    ["All Stats (%)"] = "Toutes les caractéristiques (%)",
    ["Armor, Stats and Resistances"] = "Armure, caractéristiques et résistances",
    ["Critical Strike Chance"] = "Chances de coup critique",
    ["Rested Experience"] = "Bonus de repos",
    ["Bar"] = "Barre",
    ["The bar for this entry's icons. Use Manage bars to change its settings."]
        = "La barre des icônes de cette entrée. Ses réglages se trouvent dans Gérer les barres.",
    ["Custom warning time"] = "Délai d’alerte personnalisé",
    ["Off: follows this page's warning time, including later changes."]
        = "Désactivé : suit le délai d’alerte de cette page, y compris ses modifications ultérieures.",
    ["Warns when less than this time remains. At 0, skips advance warnings but still warns when missing."]
        = "Alerte quand le temps restant passe sous ce seuil. À 0, aucune alerte avant expiration, mais l’absence de l’effet est toujours signalée.",
    ["Horizontal, centered"] = "Horizontal, centré",
    ["Vertical, centered"] = "Vertical, centré",
    ["To the right"] = "Vers la droite",
    ["To the left"] = "Vers la gauche",
    ["Downward"] = "Vers le bas",
    ["Upward"] = "Vers le haut",
    ["Delete Bar"] = "Supprimer la barre",
    ["Delete the bar %s?"] = "Supprimer la barre %s ?",
    ["%d entry will move to %s."] = "%d entrée sera déplacée vers %s.",
    ["%d entries will move to %s."] = "%d entrées seront déplacées vers %s.",
    ["Restore Default Setup"] = "Rétablir les barres par défaut",
    ["Restores General Warnings, Combat Buffs and Consumables with their original assignments. Custom bars are kept but emptied. Positions, icon sizes and warning times stay unchanged unless selected below."]
        = "Rétablit Alertes générales, Buffs de combat et Consommables avec leurs entrées d’origine. Les barres personnalisées sont conservées, mais vidées. Les positions, tailles d’icônes et délais d’alerte restent inchangés, sauf sélection ci-dessous.",
    ["Reset default bar positions"] = "Réinitialiser les positions des barres par défaut",
    ["Reset default bar icon sizes"] = "Réinitialiser la taille des icônes des barres par défaut",
    ["Reset all warning times"] = "Réinitialiser tous les délais d’alerte",
    ["Restore"] = "Rétablir",
    ["Bars"] = "Barres",
    ["Number of enabled entries assigned to this bar for your character."]
        = "Nombre d’entrées activées attribuées à cette barre pour votre personnage.",
    ["New bar"] = "Nouvelle barre",
    ["Creates an empty bar with the default appearance. Assign entries to it in their details."]
        = "Crée une barre vide avec l’apparence par défaut. L’attribution des entrées se fait dans leurs détails.",
    ["Restore default setup"] = "Rétablir les barres",
    ["Restores the three default bars and their original assignments."]
        = "Rétablit les trois barres par défaut et leurs attributions d’origine.",
    ["Name"] = "Nom",
    ["The name shown in bar lists and entry details. Leave blank to restore the default name."]
        = "Le nom affiché dans les listes de barres et les détails des entrées. Un champ vide rétablit le nom par défaut.",
    ["Sets the size of every icon on this bar."]
        = "Définit la taille de toutes les icônes de cette barre.",
    ["Growth direction"] = "Sens d’extension",
    ["Sets the bar's growth direction. At the screen edge, icons wrap to a new row or column."]
        = "Définit le sens d’extension de la barre. Au bord de l’écran, les icônes passent à une nouvelle ligne ou colonne.",
    ["The countdown under each icon on this bar."]
        = "Le compte à rebours sous chaque icône de cette barre.",
    ["Missing icon color"] = "Couleur des effets absents",
    ["Sets how missing buffs and consumables look on this bar. Borders stay red."]
        = "Définit l’apparence des buffs et consommables absents sur cette barre. Les bordures restent rouges.",
    ["Hides settings and lets you move all bars and the info bar, with this bar highlighted. Apply saves positions; Cancel discards changes."]
        = "Masque les réglages pour déplacer toutes les barres et la barre d’infos, en mettant cette barre en évidence. Appliquer enregistre les positions ; Annuler abandonne les modifications.",
    ["Restores this bar's default position."] = "Rétablit la position par défaut de cette barre.",
    ["Moves this bar to the starting position for new bars."]
        = "Place cette barre à la position de départ des nouvelles barres.",
    ["Delete bar"] = "Supprimer la barre",
    ["This is the fallback bar and cannot be deleted."]
        = "Cette barre de secours ne peut pas être supprimée.",
    ["Asks before deleting this bar. Its entries move to the fallback bar."]
        = "Demande confirmation avant de supprimer cette barre. Ses entrées passent sur la barre de secours.",
    ["Manage bars"] = "Gérer les barres",
    ["Opens bar settings for buffs and consumables: size, appearance and screen position."]
        = "Ouvre les réglages des barres de buffs et de consommables : taille, apparence et position à l’écran.",
    ["Warns when neither this bonus nor a replacement class buff is active. If no bonuses are selected, tracks %s itself."]
        = "Alerte si ni ce bonus ni un buff de classe équivalent n’est actif. Sans bonus sélectionné, suit l’effet %s lui-même.",
    ["Given by these camp objects:"] = "Accordé par ces objets de campement :",
    ["These class buffs also count:"] = "Ces buffs de classe comptent aussi :",
    ["Select up to three bonuses, the most you can have at once."]
        = "Permet de sélectionner jusqu’à trois bonus, le maximum actif en même temps.",
    ["Buffs for All Classes"] = "Buffs pour toutes les classes",
    ["Off: uses this page's warning times. Your buff uses the setting for its duration; group counts use the setting for buffs lasting 10 to 29 minutes."]
        = "Désactivé : utilise les délais d’alerte de cette page. Votre buff suit le réglage correspondant à sa durée ; le décompte du groupe utilise celui des buffs de 10 à 29 minutes.",
    ["(no coating chosen)"] = "(aucune pierre ni huile choisie)",
    ["Sets the bar and warning time for this hand's coating. Choose the oil or stone in the list below."]
        = "Définit la barre et le délai d’alerte de la pierre ou de l’huile de cette main. Le choix se fait dans la liste ci-dessous.",
    ["Not in use until you choose an oil or stone for this hand in the list below."]
        = "Inactif tant qu’aucune huile ou pierre n’est choisie pour cette main dans la liste ci-dessous.",
    ["Move bars"] = "Déplacer les barres",
    ["Hides settings so you can move all bars and the info bar. Apply saves positions; Cancel discards changes."]
        = "Masque les réglages pour déplacer toutes les barres et la barre d’infos. Appliquer enregistre les positions ; Annuler abandonne les modifications.",
    ["Confirm changes?"] = "Confirmer les modifications ?",
    ["The bars cannot be moved during combat."] = "Impossible de déplacer les barres en combat.",
    ["Drag the bars and the info bar into place. Apply saves positions; Cancel discards changes."]
        = "Faire glisser les barres et la barre d’infos à l’endroit souhaité. Appliquer enregistre les positions ; Annuler abandonne les modifications.",
    -- Translation round, 2026-10-18.
    ["Let the window reach the left edge"] = "Permettre le déplacement jusqu’au bord gauche",
    ["Not in use until you hide the chat buttons."]
        = "Inactif tant que les boutons de discussion ne sont pas masqués.",
    ["Removes the room kept free for the buttons on the left of the main chat window, so it can be moved up to the left edge of the screen."]
        = "Supprime l’espace réservé aux boutons à gauche de la fenêtre de discussion principale, pour pouvoir la déplacer jusqu’au bord gauche de l’écran.",
    ["Turns every duel request down. Nothing is sent to whoever asked: they see the same refusal they would see if you had clicked it yourself."]
        = "Refuse toutes les demandes de duel. Aucun message n’est envoyé à l’adversaire : il voit le même refus que si vous aviez cliqué vous-même.",
    -- Translation round, 2026-10-18.
    ["Portrait style"] = "Style de portrait",
    ["HD"] = "HD",
    ["SD"] = "SD",
    ["Not in use until you switch on the race icon."]
        = "Inactif tant que l’icône de race n’est pas activée.",
    ["HD shows the newer race portraits, SD the older ones. A race without an SD portrait keeps its HD one. Lines already in the chat keep theirs."]
        = "HD affiche les portraits de race récents, SD les anciens. Une race sans portrait SD conserve son portrait HD. Les lignes déjà affichées dans la discussion gardent leurs portraits.",
    ["Tab background opacity"] = "Opacité du fond des onglets",
    ["Sets the opacity of every chat tab's background. The tab names stay fully visible."]
        = "Définit l’opacité du fond de tous les onglets de discussion. Leurs noms restent entièrement visibles.",
    ["Horizontal offset"] = "Décalage horizontal",
    ["Moves the search bar to the right of its place in the chat window's top right corner, or to the left below zero. Hold Shift for steps of 50."]
        = "Décale la barre de recherche vers la droite depuis sa position en haut à droite de la fenêtre de discussion, ou vers la gauche avec une valeur négative. Maintenir Maj pour des pas de 50.",
    ["Vertical offset"] = "Décalage vertical",
    ["Moves the search bar up from its place in the chat window's top right corner, or down below zero. Hold Shift for steps of 50."]
        = "Décale la barre de recherche vers le haut depuis sa position en haut à droite de la fenêtre de discussion, ou vers le bas avec une valeur négative. Maintenir Maj pour des pas de 50.",
    ["Puts the search bar back in the chat window's top right corner."]
        = "Replace la barre de recherche en haut à droite de la fenêtre de discussion.",
    ["Shown"] = "Visible",
    ["Hidden"] = "Masqué",
    ["Shown on hover"] = "Visible au survol",
    ["Bag bar"] = "Sacs",
    ["Micro menu"] = "Menu",
    ["Minimap tracking"] = "Pistage de la minicarte",
    ["Minimap zone name"] = "Nom de zone de la minicarte",
    ["Minimap clock"] = "Horloge de la minicarte",
    ["Minimap calendar"] = "Calendrier de la minicarte",
    ["Minimap addon button"] = "Bouton des add-ons de la minicarte",
    ["Hide Interface Elements"] = "Masquer des éléments d’interface",
    ["Hides the bag bar, the micro menu and parts of the minimap, always or depending on the mouse."]
        = "Masque la barre des sacs, le menu et des éléments de la minicarte, en permanence ou selon la position de la souris.",
    ["Numbers"] = "Nombres",
    ["Quest titles"] = "Titres de quête",
    ["Letters"] = "Lettres",
    ["Combat text"] = "Texte de combat",
    ["Open the stopwatch with a click"] = "Ouvrir le chronomètre d’un clic",
    ["A click on the display opens or closes the game's stopwatch."]
        = "Un clic sur l’affichage ouvre ou ferme le chronomètre du jeu.",
    ["Open the calendar with a Shift click"] = "Ouvrir le calendrier avec Maj+clic",
    ["A Shift click on the display opens or closes the game's calendar."]
        = "Un Maj+clic sur l’affichage ouvre ou ferme le calendrier du jeu.",
    ["Open the world map with a click"] = "Ouvrir la carte du monde d’un clic",
    ["A click on the display opens or closes the world map."]
        = "Un clic sur l’affichage ouvre ou ferme la carte du monde.",
    ["How many of your bag slots are free."] = "Le nombre d’emplacements libres dans vos sacs.",
    ["Shows the free slots with the total, or the free slots alone. The hover always shows both."]
        = "Affiche les emplacements libres avec le total, ou seulement les emplacements libres. Le survol montre toujours les deux.",
    ["Free and total"] = "Libres et total",
    ["Free only"] = "Libres seulement",
    ["Reload the interface with a click"] = "Recharger l’interface d’un clic",
    ["A click on the display asks whether to reload the interface. Not in combat."]
        = "Un clic sur l’affichage demande confirmation avant de recharger l’interface. Hors combat uniquement.",
    ["Turn all sound off and on with a click"] = "Couper et rétablir le son d’un clic",
    ["A click on the display turns all game sound off, and the next one turns it back on. The volume stays as it was."]
        = "Un clic sur l’affichage coupe tous les sons du jeu, le suivant les rétablit. Le volume réglé est conservé.",
    ["Font"] = "Police",
    ["The font of the info bar. Default is the font of the addon, the others are fonts the game uses elsewhere."]
        = "La police de la barre d’infos. L’option Par défaut utilise celle de l’add-on ; les autres sont des polices utilisées ailleurs dans le jeu.",
    ["The size of the info bar's text, relative to the text size on the Design page."]
        = "La taille du texte de la barre d’infos, par rapport à celle définie sur la page Apparence.",
    ["Text color"] = "Couleur du texte",
    ["The color of the info bar's text."] = "La couleur du texte de la barre d’infos.",
    ["Status colors"] = "Couleurs d’état",
    ["Colors displays by their state. Off, the whole bar is in its text color."]
        = "Colore les affichages selon leur état. Désactivé, toute la barre utilise sa couleur de texte.",
    ["Background color"] = "Couleur du fond",
    ["The color and opacity of the info bar's background."]
        = "La couleur et l’opacité du fond de la barre d’infos.",
    ["Border color"] = "Couleur de la bordure",
    ["The color and opacity of the info bar's border."]
        = "La couleur et l’opacité de la bordure de la barre d’infos.",
    ["Show icons"] = "Afficher les icônes",
    ["The icons in front of the displays. A display that is only an icon shows its name instead."]
        = "Les icônes devant les affichages. Un affichage composé uniquement d’une icône montre son nom à la place.",
    ["Restore default look"] = "Rétablir l’apparence",
    ["Puts the info bar's font, colors and icons back as the design has them."]
        = "Rétablit la police, les couleurs et les icônes de la barre d’infos selon l’apparence choisie.",
    ["Click to open the world map"] = "Cliquez pour ouvrir la carte du monde",
    ["Click to open the stopwatch"] = "Cliquez pour ouvrir le chronomètre",
    ["Shift click to open the calendar"] = "Maj+clic pour ouvrir le calendrier",
    ["Click to reload the interface"] = "Cliquez pour recharger l’interface",
    ["The interface cannot be reloaded during combat."]
        = "Impossible de recharger l’interface en combat.",
    ["Reload the interface now?"] = "Recharger l’interface maintenant ?",
    ["Click the display to turn all sound off or on"]
        = "Cliquez sur l’affichage pour couper ou rétablir tous les sons",
    ["Click an icon to hide or show it on the bar."]
        = "Cliquez sur une icône pour la masquer ou l’afficher sur la barre.",
    ["Hides or shows this display's icon on the bar."]
        = "Masque ou affiche l’icône de cet affichage sur la barre.",
    ["Accepts each quest automatically at most once per conversation with the quest giver."]
        = "Accepte les quêtes automatiquement, chacune au plus une fois par conversation avec le donneur de quête.",
    ["Quest difficulty"] = "Difficulté des quêtes",
    ["Accept all"] = "Tout accepter",
    ["Skip gray quests"] = "Ignorer les quêtes grises",
    ["Skip gray and green quests"] = "Ignorer les grises et vertes",
    ["Which quests are left for you to accept, by their color for your character. Handing quests in is not affected."]
        = "Les quêtes à accepter vous-même, selon leur couleur pour votre personnage. La remise des quêtes n’est pas modifiée.",
    ["Hands in each completed quest at most once per conversation with the quest giver. Never picks a reward for you."]
        = "Rend les quêtes terminées, chacune au plus une fois par conversation avec le donneur de quête. Ne choisit jamais de récompense à votre place.",
    -- Translation round, 2026-10-18.
    ["Shown, hidden, or shown only while the mouse is over its place. A hidden piece takes no clicks."]
        = "Visible, masqué ou visible uniquement lorsque la souris survole son emplacement. Un élément masqué ne reçoit aucun clic.",
    ["Always visible"] = "Toujours visible",
    ["Shows the search bar all the time, instead of only while the mouse is over the chat window or the input line is open."]
        = "Affiche la barre de recherche en permanence, et non uniquement lorsque la souris survole la fenêtre de discussion ou que la ligne de saisie est ouverte.",
    ["Not in use until you switch off Always visible."]
        = "Inactif tant que l’option Toujours visible n’est pas désactivée.",
    ["Appears in the chat window's top right corner while the mouse is over the window or the input line is open, unless it is set to be always visible. Press Enter to display every matching line again. The X at the end clears the search."]
        = "En haut à droite de la discussion, tant que la souris est dessus ou que la ligne de saisie est ouverte, sauf si l’option Toujours visible est activée. Entrée réaffiche chaque ligne correspondante. Le X au bout efface la recherche.",
    -- Translation round, 2026-10-20: chat fading and item level.
    ["Show chat on hover or while typing"] = "Afficher la discussion au survol ou à la saisie",
    ["Shows faded lines while the mouse is over the chat window or the input line is open. Afterward, they stay for the time set under \"Fade after\"."]
        = "Affiche les lignes disparues tant que la souris survole la fenêtre de discussion ou que la ligne de saisie est ouverte. Elles restent ensuite visibles pendant la durée définie dans « Faire disparaître après ».",
    ["Fade the background with the messages"] = "Faire disparaître le fond avec les messages",
    ["Fades the window's background and tabs out with the last line. They return at your chosen opacity with a new message, when you scroll, while the mouse is over the window, or while you type."]
        = "Fait disparaître le fond de la fenêtre et les onglets avec la dernière ligne. Ils retrouvent l’opacité choisie à l’arrivée d’un message, lors du défilement, tant que la souris survole la fenêtre ou pendant la saisie.",
    ["Item level"] = "Niveau d'objet",
    ["Shows the average item level of a player's equipped items. For other players, the value updates when you hover over them outside combat. The last known value stays visible until the new one arrives."]
        = "Affiche le niveau d'objet moyen de l’équipement d’un joueur. Pour les autres joueurs, la valeur est actualisée lorsque vous les survolez hors combat. La dernière valeur connue reste visible jusqu’à l’arrivée de la nouvelle.",
    -- Translation round, 2026-10-23: chat input and info bar.
    ["Input line position"] = "Position de la ligne de saisie",
    ["Below the window"] = "Sous la fenêtre",
    ["Between window and tabs"] = "Sous les onglets",
    ["Above the tabs"] = "Au-dessus des onglets",
    ["Places the input line of every chat window below the window, between the window and its tabs, or above the tabs."]
        = "Place la ligne de saisie de chaque fenêtre de discussion sous la fenêtre, entre la fenêtre et ses onglets ou au-dessus des onglets.",
    ["How much ammunition you carry for your bow, gun or crossbow. Not shown while none of them is equipped."]
        = "La quantité de munitions que vous portez pour votre arc, fusil ou arbalète. Masquée si aucune de ces armes n’est équipée.",
    ["What it counts"] = "Munitions comptées",
    ["Counts every arrow or every bullet in your bags that your weapon fires, or only the ammunition in your ammo slot."]
        = "Compte toutes les flèches ou balles de vos sacs que votre arme peut tirer, ou seulement les munitions de votre emplacement de munitions.",
    ["All arrows or bullets"] = "Toutes les flèches ou balles",
    ["Ammo slot only"] = "Emplacement seul",
    ["Turns the display red below the amount set under this switch. Shared with Ammunition Warning on the Gameplay page, where it also shows a red line and plays a sound for Hunters."]
        = "Affiche le nombre en rouge sous la quantité définie sous cette option. Réglage partagé avec Alerte de munitions sur la page Jeu, qui avertit aussi les chasseurs par une ligne rouge et un son.",
    ["The amount below which the display turns red. Shared with Ammunition Warning on the Gameplay page."]
        = "La quantité sous laquelle le nombre devient rouge. Réglage partagé avec Alerte de munitions sur la page Jeu.",
    ["Destroy Cheapest Gray Item"] = "Détruire l’objet gris le moins cher",
    ["Shows an icon for the gray stack in your bags that is worth the least at a merchant. Shift click it to destroy that stack and free a bag slot. Not in combat."]
        = "Affiche une icône pour la pile d’objets gris de vos sacs qui vaut le moins chez un marchand. Un Maj+clic détruit cette pile pour libérer un emplacement de sac. Hors combat uniquement.",
    ["Destroy with a click, without Shift"] = "Détruire d’un clic sans Maj",
    ["A click on the display destroys the stack without holding Shift."]
        = "Un clic sur l’affichage détruit la pile sans maintenir Maj.",
    ["Skip the confirmation"] = "Passer la confirmation",
    ["Destroys the stack at once, without the question, and reports it in chat."]
        = "Détruit la pile immédiatement, sans confirmation, et le signale dans la discussion.",
    ["Counts %s, the ammunition in your ammo slot"]
        = "Compte %s, les munitions de votre emplacement de munitions",
    ["Your ammo slot is empty"] = "Votre emplacement de munitions est vide",
    ["Counts every bullet in your bags"] = "Compte toutes les balles de vos sacs",
    ["Counts every arrow in your bags"] = "Compte toutes les flèches de vos sacs",
    ["Red below %d"] = "En rouge sous %d",
    ["Nothing is destroyed in combat."] = "Rien n’est détruit en combat.",
    ["Nothing was destroyed: something is on your cursor."]
        = "Rien n’a été détruit : votre curseur tient quelque chose.",
    ["Nothing was destroyed: your bags changed."] = "Rien n’a été détruit : le contenu de vos sacs a changé.",
    ["Nothing was destroyed: this client cannot destroy items for an addon."]
        = "Rien n’a été détruit : ce client ne peut pas détruire d’objets pour un add-on.",
    ["The game did not destroy %s."] = "Le jeu n’a pas détruit %s.",
    ["Destroyed %d %s, worth %s at a merchant."] = "Détruit : %d %s, d’une valeur de %s chez un marchand.",
    ["Destroyed %d %s, worth nothing at a merchant."] = "Détruit : %d %s, sans valeur chez un marchand.",
    ["Destroy Gray Item"] = "Détruire un objet gris",
    ["Do you really want to destroy %d %s?"] = "Voulez-vous vraiment détruire %d %s ?",
    ["A merchant would pay %s for it. This cannot be undone."]
        = "Un marchand en donnerait %s. Cette action est irréversible.",
    ["A merchant would pay nothing for it. This cannot be undone."]
        = "Un marchand n’en donnerait rien. Cette action est irréversible.",
    ["Destroy"] = "Détruire",
    ["Turns on \"Skip the confirmation\" on the Info bar page when you click Destroy."]
        = "Active « Passer la confirmation » sur la page Barre d’infos quand vous cliquez sur Détruire.",
    ["No gray item to destroy"] = "Aucun objet gris à détruire",
    ["Stack of %d, worth %s at a merchant"] = "Pile de %d, d’une valeur de %s chez un marchand",
    ["Stack of %d, worth nothing at a merchant"] = "Pile de %d, sans valeur chez un marchand",
    ["Not in combat"] = "Pas en combat",
    ["Click to destroy this stack"] = "Clic pour détruire cette pile",
    ["Shift click to destroy this stack"] = "Maj+clic pour détruire cette pile",
    -- Shadow Protection, durability warning and web address copying.
    ["Warn about Shadow Protection from others"] = "Alerter sur ce buff venant des autres",
    ["Warns when Shadow Protection is missing or about to expire and a Priest in your group could give it to you. Only applies where buffs from others are switched on under Conditions. A Priest's own warnings and group count do not change."]
        = "Alerte lorsque Protection contre l'Ombre manque ou va bientôt expirer et qu’un prêtre de votre groupe pourrait vous l’accorder. S’applique uniquement là où les buffs des autres sont activés dans « Conditions ». Les alertes du prêtre pour ses propres buffs et son décompte du groupe restent inchangés.",
    ["Durability Warning"] = "Alerte de durabilité",
    ["Shows a short warning when an equipped item reaches the selected durability or lower. Also warns after login if an item is already low."]
        = "Affiche une courte alerte lorsque la durabilité d’un objet équipé atteint le seuil choisi ou passe en dessous. Alerte aussi après la connexion si un objet est déjà à ce seuil ou en dessous.",
    ["Warn at or below"] = "Alerter à ce seuil ou en dessous",
    ["Uses the lowest durability among your equipped items. At 0%, it warns only about broken equipment."]
        = "Se base sur la durabilité la plus basse parmi vos objets équipés. À 0%, alerte uniquement pour l’équipement brisé.",
    ["Low durability: %s (%d%%)"] = "Durabilité faible : %s (%d%%)",
    ["Durability Warning: this client has no sound called %s."]
        = "Alerte de durabilité : ce client n’a pas de son nommé %s.",
    ["Copy web addresses"] = "Copier les adresses web",
    ["Makes web addresses in chat clickable for copying."]
        = "Rend les adresses web cliquables dans la discussion pour les copier.",
    ["Click to select this web address for copying."]
        = "Cliquez pour sélectionner cette adresse web à copier.",
    ["Web address"] = "Adresse web",
    ["Press Ctrl+C to copy."] = "Appuyez sur Ctrl+C pour copier.",
    -- Experience measurement, addon CPU usage and health bar textures.
    ["How much experience you gain per hour, measured since you logged in. Not shown at the maximum level."]
        = "Le nombre de PX gagnés par heure depuis votre connexion. Masqué au niveau maximum.",
    ["Restart measurement with a click"] = "Relancer la mesure d’un clic",
    ["A click on the display resets the measurement for both experience displays."]
        = "Un clic sur l’affichage remet à zéro la mesure des deux affichages de PX.",
    ["Estimated time to your next level at your current experience rate. Not shown at the maximum level."]
        = "Le temps estimé avant votre prochain niveau au rythme actuel de gain de PX. Masqué au niveau maximum.",
    ["Click to restart measurement"] = "Cliquez pour relancer la mesure",
    ["Level %d"] = "Niveau %d",
    ["Rested"] = "Reposé(e)",
    ["%s in %s"] = "%s en %s",
    ["Per hour"] = "Par heure",
    ["To the next level"] = "Avant le prochain niveau",
    ["Addon CPU usage"] = "Utilisation du processeur par les add-ons",
    ["Total"] = "Total",
    ["Health bar texture"] = "Texture de la barre de vie",
    ["Flat"] = "Unie",
    ["Soft gradient"] = "Dégradé doux",
    ["Choose the texture of the health bar below unit tooltips."] = "Choisissez la texture de la barre de vie sous les bulles d’aide des unités.",
    ["Preview"] = "Aperçu",
})
