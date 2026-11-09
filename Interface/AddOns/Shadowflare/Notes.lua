-- Shadowflare: what's new, shown once after an update (as in Travelcraft).
-- The window uses the game's own frame template; older templates are only a fallback.
local _, ns = ...
local L = ns.L

-- Newest first. After an update, only the versions the player has not seen are shown.
ns.NOTES = {
    { v = "0.23.33", en = "November 8, 2026", fr = "8 novembre 2026",
      items = {
        { en = "Fixed: the Modern glow style now shows its animated glow from the first time the settings open (before, only after switching tabs).",
          fr = "Corrigé : le style Lueur moderne affiche maintenant sa lueur animée dès la première ouverture des réglages (avant, seulement après un changement d'onglet)." },
      } },
    { v = "0.23.32", en = "November 8, 2026", fr = "8 novembre 2026",
      items = {
        { en = "None style: what it shows (time left, stack dots) is now its own choice, in the Style tab. It no longer changes the other styles.",
          fr = "Style Aucun : ce qu'il affiche (temps restant, points des cumuls) est maintenant son propre choix, dans l'onglet Style. Il ne change plus les autres styles." },
        { en = "Fixed: the text of \"Also in other stances\" showed in the Timer and sound tab of every alert.",
          fr = "Corrigé : le texte de « Aussi dans les autres postures » s'affichait dans l'onglet Temps et son de toutes les alertes." },
        { en = "Fixed: the Modern glow style could show a broken picture the first time the settings opened. When its glow can't play, the icon now shows without it.",
          fr = "Corrigé : le style Lueur moderne pouvait afficher une image cassée à la première ouverture des réglages. Quand sa lueur ne peut pas s'animer, l'icône s'affiche maintenant sans elle." },
      } },
    { v = "0.23.31", en = "November 8, 2026", fr = "8 novembre 2026",
      items = {
        { en = "Mage: Arcane Blast is now always counted by Shadowflare from your casts, never handed to the game's own frame, which could stop following the stacks.",
          fr = "Mage : Déflagration des Arcanes est maintenant toujours comptée par Shadowflare à partir de tes lancers, plus jamais confiée au cadre du jeu, qui pouvait ne plus suivre les cumuls." },
      } },
    { v = "0.23.30", en = "November 8, 2026", fr = "8 novembre 2026",
      items = {
        { en = "New style: None, in the Modern group. No picture, only the time left and, for procs with stacks, the dots. Pick what it shows at the top of the Style tab: time left, stack dots, or both.",
          fr = "Nouveau style : Aucun, dans le groupe Modernes. Pas d'image, seulement le temps restant et, pour les procs à cumuls, les points. Choisis ce qu'il affiche en haut de l'onglet Style : temps restant, points des cumuls, ou les deux." },
      } },
    { v = "0.23.29", en = "November 7, 2026", fr = "7 novembre 2026",
      items = {
        { en = "Fixed: the Modern glow style could show a grid of yellow squares over the icon when its glow couldn't play (often on alerts the game shows itself). It now shows a still glow.",
          fr = "Corrigé : le style Lueur moderne pouvait afficher une grille de carrés jaunes sur l'icône quand sa lueur ne pouvait pas s'animer (souvent sur les alertes affichées par le jeu). Il affiche maintenant une lueur fixe." },
        { en = "Shaman: Improved Stormstrike no longer misses resets while you keep the global cooldown running, and shows them sooner.",
          fr = "Chaman : Frappe-tempête améliorée ne rate plus les remises à zéro quand le temps de recharge global tourne sans arrêt, et les affiche plus tôt." },
        { en = "Mage: Arcane Blast works again after learning its higher ranks. Higher ranks of other spells are found by their name too.",
          fr = "Mage : Déflagration des Arcanes remarche après avoir appris ses rangs supérieurs. Les rangs supérieurs des autres sorts sont aussi trouvés par leur nom." },
      } },
    { v = "0.23.28", en = "November 7, 2026", fr = "7 novembre 2026",
      items = {
        { en = "Fixed: an alert you switched off could still show when the game showed it itself (seen on Clearcasting and Missile Barrage).",
          fr = "Corrigé : une alerte décochée pouvait encore s'afficher quand le jeu l'affichait lui-même (vu sur Idées claires et Barrage de projectiles)." },
        { en = "Mage: Arcane Missiles during Missile Barrage no longer plays the Clearcasting sound again (since the release, Clearcasting stays up then).",
          fr = "Mage : Projectiles des arcanes pendant Barrage de projectiles ne rejoue plus le son d'Idées claires (depuis la sortie, Idées claires reste alors actif)." },
      } },
    { v = "0.23.27", en = "November 6, 2026", fr = "6 novembre 2026",
      items = {
        { en = "Warrior: Overpower and Revenge have a new option, Also in other stances (in the Timer and sound tab). In another stance, the alert shows with the stance to take. Off by default, in test.",
          fr = "Guerrier : Fulgurance et Vengeance ont une nouvelle option, Aussi dans les autres postures (onglet Temps et son). Dans une autre posture, l'alerte s'affiche avec la posture à prendre. Décochée par défaut, en test." },
      } },
    { v = "0.23.26", en = "November 3, 2026", fr = "3 novembre 2026",
      items = {
        { en = "Updated for the class changes of the release (Blizzard's notes of November 2).",
          fr = "Mis à jour pour les changements de classes de la sortie (notes de Blizzard du 2 novembre)." },
        { en = "Rogue: Cutthroat is gone from the game. Its alert becomes Ghostly Strike, which now lets your next Ambush skip Stealth for 7 sec. Your settings are kept. Thousand Cuts is gone from the game, and from Shadowflare.",
          fr = "Voleur : Coupe-gorge n'existe plus dans le jeu. Son alerte devient Frappe fantomatique, qui permet maintenant à ta prochaine Embuscade de se passer du Camouflage pendant 7 s. Tes réglages sont gardés. Mille entailles n'existe plus dans le jeu, ni dans Shadowflare." },
        { en = "Shaman: Stormstrike's cooldown is now 6 sec. Improved Stormstrike follows it: no more false alert after a normal cooldown.",
          fr = "Chaman : le temps de recharge de Frappe-tempête est maintenant de 6 s. Frappe-tempête améliorée le suit : plus de fausse alerte après une recharge normale." },
        { en = "Mage: Arcane Blast stacks now last 18 sec.",
          fr = "Mage : les cumuls de Déflagration des Arcanes durent maintenant 18 s." },
        { en = "Paladin: Vengeance now goes up to 5 stacks. If yours showed at 3 (the old maximum), it now shows at 5.",
          fr = "Paladin : Vengeance va maintenant jusqu'à 5 cumuls. Si la tienne s'affichait à 3 (l'ancien maximum), elle s'affiche maintenant à 5." },
      } },
    { v = "0.23.25", en = "October 30, 2026", fr = "30 octobre 2026",
      items = {
        { en = "New button under the list of alerts, \"Same look for all\". It gives the selected alert's look to every other alert of the same class: style, color, size, animation, time left, font and more. Each alert keeps its place on screen, its sound and whether it is on.",
          fr = "Nouveau bouton sous la liste des alertes, « Même apparence pour ». Il donne l'apparence de l'alerte choisie à toutes les autres alertes de la même classe : style, couleur, taille, animation, temps restant, police et plus. Chaque alerte garde sa place à l'écran, son son et son activation." },
        { en = "Timer and sound tab: new Font menu, alert by alert. It changes every text of the alert: the time left, the words of styles that have some (Text, Bar...) and the number of stacks. The game's fonts, plus the fonts other addons share, if you have any.",
          fr = "Onglet Temps et son : nouveau menu Police, alerte par alerte. Il change chaque texte de l'alerte : le temps restant, les mots des styles qui en ont (Texte, Barre...) et le nombre de cumuls. Les polices du jeu, plus celles que partagent d'autres addons, si tu en as." },
        { en = "Timer and sound tab: new Alignment setting (Left, Center, Right) for the time left placed apart. Left keeps its left edge still, so the numbers don't shift when they change width. Center by default, as before.",
          fr = "Onglet Temps et son : nouveau réglage Alignement (Gauche, Centre, Droite) pour le temps restant placé à part. Gauche garde son bord gauche fixe, pour que les chiffres ne bougent pas quand leur largeur change. Centre par défaut, comme avant." },
      } },
    { v = "0.23.22", en = "October 24, 2026", fr = "24 octobre 2026",
      items = {
        { en = "New command /flare ids: lists every spell and buff number Shadowflare uses, with the name the game gives it, in a box you can copy. Used to check the released game.",
          fr = "Nouvelle commande /flare ids : liste chaque numéro de sort et de buff utilisé par Shadowflare, avec le nom que lui donne le jeu, dans une case à copier. Sert à vérifier le jeu sorti." },
      } },
    { v = "0.23.21", en = "October 24, 2026", fr = "24 octobre 2026",
      items = {
        { en = "Heating Up, Maelstrom Weapon, Decimation and Eclipse are now shown by the game from your first fight after logging in too, with their stacks.",
          fr = "Réchauffement, Arme du Maelström, Décimation et Éclipse sont maintenant aussi affichées par le jeu dès ton premier combat après la connexion, avec leurs cumuls." },
        { en = "Rapid Killing (hunter): it looked for the wrong buff numbers and only worked once its buff had been seen out of combat. Fixed.",
          fr = "Tuerie rapide (chasseur) : elle cherchait les mauvais numéros de buff et ne marchait qu'une fois son buff vu hors combat. Corrigé." },
      } },
    { v = "0.23.20", en = "October 24, 2026", fr = "24 octobre 2026",
      items = {
        { en = "Alerts shown by the game itself no longer wait for you to have their buff once out of combat. They now work from your very first fight after logging in: Fingers of Frost, Clearcasting, Missile Barrage, Omen of Clarity, Elemental Focus, Victory Rush, Cutthroat, and every alert only the game can show (Redoubt, Vengeance, Reckoning, Martyrdom, Remorseless Attacks, Rapid Killing, Deadly Aspects, Nature's Grace, Thousand Cuts, Hand of Edward the Odd).",
          fr = "Les alertes affichées par le jeu lui-même n'attendent plus que tu aies eu leur buff une fois hors combat. Elles marchent maintenant dès ton tout premier combat après la connexion : Doigts de givre, Idées claires, Barrage de projectiles, Augure de clarté, Focalisation élémentaire, Ivresse de la victoire, Coupe-gorge, et toutes les alertes que seul le jeu peut afficher (Redoute, Vengeance, Rétribution, Martyre, Attaques impitoyables, Tuerie rapide, Aspects mortels, Grâce de la nature, Mille entailles, Hand of Edward the Odd)." },
        { en = "The other alerts the game can show (such as Heating Up, Eclipse or Maelstrom Weapon) switch to it the first time their buff is on you out of combat, at any number of stacks. Before, they needed 2 stacks or more.",
          fr = "Les autres alertes que le jeu peut afficher (comme Réchauffement, Éclipse ou Arme du Maelström) passent au jeu la première fois que leur buff est sur toi hors combat, quel que soit le nombre de cumuls. Avant, il en fallait au moins 2." },
        { en = "Fingers of Frost and other alerts with charges or stacks show them right away. Before, a buff first seen with one charge stayed without its charges until a /reload. Fixed.",
          fr = "Doigts de givre et les autres alertes à charges ou cumuls les affichent tout de suite. Avant, un buff vu la première fois avec une seule charge restait sans ses charges jusqu'à un /reload. Corrigé." },
      } },
    { v = "0.23.19", en = "October 24, 2026", fr = "24 octobre 2026",
      items = {
        { en = "Stacks tab: with only one side of a two-sided style shown, Fills from the left cut that side in the middle. It is now greyed out in that case and the alert fills up instead. With both sides, nothing changes.",
          fr = "Onglet Cumuls : avec un seul côté d'un style à deux côtés, Se remplit depuis la gauche coupait ce côté au milieu. Elle est maintenant grisée dans ce cas et l'alerte se remplit vers le haut. Avec les deux côtés, rien ne change." },
      } },
    { v = "0.23.18", en = "October 24, 2026", fr = "24 octobre 2026",
      items = {
        { en = "HD styles (Umbra, Hellfire, Wildgrowth, Rend, Stormcall): the edges of the picture and of its shadow no longer show as straight lines. Each picture now fades out softly before its edges.",
          fr = "Styles HD (Umbra, Hellfire, Wildgrowth, Rend, Stormcall) : les bords du dessin et de son ombre ne se voient plus en lignes droites. Chaque dessin s'efface maintenant en douceur avant ses bords." },
      } },
    { v = "0.23.17", en = "October 23, 2026", fr = "23 octobre 2026",
      items = {
        { en = "Five new HD styles drawn for Shadowflare, in the Modern group: Umbra (shadow), Hellfire (fire), Wildgrowth (nature), Rend (claws) and Stormcall (lightning). Twice the size of the game's pictures, so they stay sharp, and drawn on two sides: Sides, Spacing, Rotation and the stack looks work on them.",
          fr = "Cinq nouveaux styles HD dessinés pour Shadowflare, dans le groupe Modernes : Umbra (ombre), Hellfire (feu), Wildgrowth (nature), Rend (griffes) et Stormcall (foudre). Deux fois la taille des dessins du jeu, pour rester nets, et dessinés sur deux côtés : Côtés, Écart, Rotation et les apparences de cumuls marchent avec eux." },
        { en = "New Sharp size button next to Size, for the game's pictures (Classic and Retail): it sets the size where each pixel of the picture is one pixel of your screen. As sharp as it can be, but smaller. Off until you click it.",
          fr = "Nouveau bouton Taille nette à côté de Taille, pour les dessins du jeu (Classiques et Retail) : il règle la taille où chaque pixel du dessin est un pixel de ton écran. Aussi net que possible, mais plus petit. Rien ne change tant que tu ne cliques pas." },
      } },
    { v = "0.23.16", en = "October 23, 2026", fr = "23 octobre 2026",
      items = {
        { en = "New Destruction warlock alert: Conflagrate. It shows when Conflagrate can be cast: your Immolate is on the target and it is off cooldown. Hidden during its cooldown after a cast. With Shadow and Flame at 5/5, it comes back at the end of each cooldown as long as Immolate stays. Off by default: tick it in the list if you have the talent.",
          fr = "Nouvelle alerte démoniste Destruction : Conflagration. Elle s'affiche quand Conflagration peut être lancée : ton Immolation est sur la cible et elle n'est pas en recharge. Masquée pendant sa recharge après un lancer. Avec Ombre et flammes à 5/5, elle revient à chaque fin de recharge tant qu'Immolation reste. Coupée par défaut : coche-la dans la liste si tu as le talent." },
        { en = "Alerts that follow your target (Execute, Hammer of Wrath, Conflagrate) now appear and go at once, with no fade, so they keep up when you change target.",
          fr = "Les alertes qui suivent ta cible (Exécution, Marteau de courroux, Conflagration) apparaissent et partent maintenant d'un coup, sans fondu, pour suivre quand tu changes de cible." },
        { en = "Settings: the first time you placed an alert after logging in, the settings window stayed open and did not come back after Done. Fixed.",
          fr = "Réglages : la première fois qu'on plaçait une alerte après la connexion, la fenêtre des réglages restait ouverte et ne revenait pas après Terminé. Corrigé." },
      } },
    { v = "0.23.15", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "New warrior alert: Shield Block (Protection). It shows when Shield Block can be pressed again, so you can keep it up. Hidden during its cooldown after a cast, shown only with enough rage, in combat. No sound by default.",
          fr = "Nouvelle alerte guerrier : Maîtrise du blocage (Protection). Elle s'affiche quand Maîtrise du blocage peut être relancée, pour la garder active. Masquée pendant sa recharge après un lancer, affichée seulement avec assez de rage, en combat. Sans son par défaut." },
        { en = "New Sides settings in the Look tab, alert by alert, for styles drawn on two sides: show both sides, the left one or the right one, and a Spacing slider to move the sides apart without making them bigger.",
          fr = "Nouveaux réglages Côtés dans l'onglet Apparence, alerte par alerte, pour les styles dessinés sur deux côtés : afficher les deux côtés, le gauche ou le droit, et un curseur Écart pour écarter les côtés sans les agrandir." },
        { en = "New Retail group in the Style tab: 25 of the game's newer proc pictures, such as Arcane Missiles, Thrill of the Hunt, Grand Crusader or Tooth and Claw.",
          fr = "Nouveau groupe Retail dans l'onglet Style : 25 dessins de procs plus récents du jeu, comme Arcane Missiles, Thrill of the Hunt, Grand Crusader ou Tooth and Claw." },
        { en = "New box in the Stacks tab: Hide the part not reached yet. With Fills up or Fills from the left, the part not filled yet is hidden instead of faint (on a style drawn on two sides: one side, then both).",
          fr = "Nouvelle case dans l'onglet Cumuls : Masquer la partie pas encore atteinte. Avec Se remplit vers le haut ou depuis la gauche, la partie pas encore remplie est masquée au lieu d'être pâle (sur un style dessiné sur deux côtés : un côté, puis les deux)." },
        { en = "Fingers of Frost: the Sides look (one side at 1 charge) is replaced by Dots, the whole alert at full brightness. The new Sides settings work for it like for every other alert.",
          fr = "Doigts de givre : l'apparence Côtés (un côté à 1 charge) est remplacée par Points, toute l'alerte à pleine luminosité. Les nouveaux réglages Côtés marchent pour elle comme pour toutes les autres alertes." },
        { en = "Settings: the preview now holds still, so you can set an alert calmly. Play runs it (its way in, animation, time, way out and stacks), Stop holds it still again.",
          fr = "Réglages : l'aperçu reste maintenant fixe, pour régler une alerte tranquillement. Lecture la joue (entrée, animation, temps, sortie et cumuls), Arrêt la fige de nouveau." },
        { en = "Remorseless Attacks now stays on screen out of combat too, like Victory Rush: it comes from a kill, which often ends the fight, and it went away while looting. Tick Only in combat to have it as before.",
          fr = "Attaques impitoyables reste maintenant affichée hors combat aussi, comme Ivresse de la victoire : elle vient d'une victime, qui termine souvent le combat, et elle partait pendant le butin. Coche Seulement en combat pour l'avoir comme avant." },
        { en = "Weapon and enchant alerts are now off by default. Tick them in the list to use them (the ones you ticked yourself stay on).",
          fr = "Les alertes d'armes et d'enchantements sont maintenant coupées par défaut. Coche-les dans la liste pour les utiliser (celles que tu as cochées toi-même restent actives)." },
        { en = "Backlash, Blood Surge and Fury of Stormrage (classic styles) are now drawn on top, as the game does. They were squeezed on the sides.",
          fr = "Backlash, Blood Surge et Fury of Stormrage (styles classiques) sont maintenant dessinés en haut, comme dans le jeu. Ils étaient écrasés sur les côtés." },
      } },
    { v = "0.23.14", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "Arcane Blast: new detection. Shadowflare now counts its stacks itself, so it no longer waits for its buff to be seen out of combat. It shows from 1 stack by default, with a sound at 4 stacks. Its time left counts from the first stack.",
          fr = "Déflagration des Arcanes : nouvelle détection. Shadowflare compte maintenant ses cumuls lui-même, sans attendre d'avoir vu son buff hors combat. Elle s'affiche dès 1 cumul par défaut, avec un son à 4 cumuls. Son temps restant part du premier cumul." },
      } },
    { v = "0.23.13", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "New box in the Look tab, under Animation: No way in or out. Set alert by alert: that alert appears at once, goes with a quick fade, and does not punch when it comes again. Its animation keeps moving while it is shown.",
          fr = "Nouvelle case dans l'onglet Apparence, sous Animation : Sans entrée ni sortie. Alerte par alerte : l'alerte apparaît d'un coup, part avec un fondu rapide et ne frappe pas quand elle revient. Son animation continue de bouger tant qu'elle est affichée." },
      } },
    { v = "0.23.12", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "Victory Rush: after a cast, out of combat, its alert came back a few seconds after the end of the cooldown. It now comes back right then.",
          fr = "Ivresse de la victoire : après un lancer, hors combat, son alerte revenait quelques secondes après la fin du temps de recharge. Elle revient maintenant à ce moment-là." },
        { en = "Settings: the chosen button of a row (animation, stack look, preview background, tabs...) now has a gold frame and full colour; the others are darker.",
          fr = "Réglages : le bouton choisi d'une rangée (animation, apparence des cumuls, fond de l'aperçu, onglets...) a maintenant un cadre doré et sa pleine couleur ; les autres sont plus sombres." },
      } },
    { v = "0.23.10", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "Alerts shown by the game itself now appear at once and hold still. The game replayed their way in each time it rebuilt its frames (the alert popped in and out after a kill), and addons can't stop it.",
          fr = "Les alertes affichées par le jeu lui-même apparaissent maintenant d'un coup et restent fixes. Le jeu rejouait leur entrée à chaque fois qu'il reconstruisait ses cadres (l'alerte apparaissait et disparaissait après une victime), et les addons ne peuvent pas l'en empêcher." },
      } },
    { v = "0.23.9", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "Settings preview: the Ring and Icon timers sometimes stayed empty after a change. They start again each time.",
          fr = "Aperçu des réglages : le temps des styles Anneau et Icône restait parfois vide après un changement. Il repart à chaque fois." },
      } },
    { v = "0.23.8", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "Alerts shown by the game: the Ring and Icon styles turn with the buff's real time left again.",
          fr = "Alertes affichées par le jeu : les styles Anneau et Icône tournent de nouveau avec le vrai temps restant du buff." },
        { en = "Alerts shown by the game: the way in no longer plays again when a fight ends (the alert popped in and out for a moment).",
          fr = "Alertes affichées par le jeu : l'entrée ne se rejoue plus quand un combat se termine (l'alerte apparaissait et disparaissait un instant)." },
      } },
    { v = "0.23.7", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "Fixed: in 0.23.3, the alerts shown by the game itself (Heating Up, Fingers of Frost and the other procs whose buff has been seen) did not show at all.",
          fr = "Corrigé : en 0.23.3, les alertes affichées par le jeu lui-même (Réchauffement, Doigts de givre et les autres procs dont le buff a été vu) ne s'affichaient pas du tout." },
        { en = "Alerts shown by the game: the game doesn't let addons change them during a fight. They now keep their way in, then hold still. With Only in combat, they are switched off between fights.",
          fr = "Alertes affichées par le jeu : le jeu ne laisse pas les addons les modifier pendant un combat. Elles gardent leur entrée, puis restent fixes. Avec Seulement en combat, elles sont coupées entre les combats." },
        { en = "Victory Rush is now shown by the game from its buff: its time left is the buff's own, and a kill that renews it starts its 20 s again. It starts once its buff has been on you out of combat. After a cast, its alert is off during the cooldown.",
          fr = "Ivresse de la victoire est maintenant affichée par le jeu à partir de son buff : son temps restant est celui du buff, et une victime qui le renouvelle relance ses 20 s. Cela fonctionne une fois que son buff a été sur toi hors combat. Après un lancer, son alerte est coupée pendant le temps de recharge." },
      } },
    { v = "0.23.3", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "Fixed: when Victory Rush, Overpower, Revenge, Riposte, Cutthroat, Mongoose Bite or Counterattack ran out, the alert could come back for a moment before going. It now goes once, when its time runs out.",
          fr = "Corrigé : quand Ivresse de la victoire, Fulgurance, Vengeance, Riposte, Coupe-gorge, Morsure de la mangouste ou Contre-attaque expirait, l'alerte pouvait revenir un instant avant de partir. Elle part maintenant une seule fois, à la fin de son temps." },
      } },
    { v = "0.23.2", en = "October 22, 2026", fr = "22 octobre 2026",
      items = {
        { en = "New animation: Impact pulse. It lands like Impact, with the white-hot flare, then swells every second like Classic pulse.",
          fr = "Nouvelle animation : Impact pulsé. Elle arrive comme Impact, avec l'éclat blanc, puis pulse chaque seconde comme Pulsation." },
        { en = "Fingers of Frost uses Impact pulse by default. If it was on Impact, it moves to Impact pulse once; you can change it as before.",
          fr = "Doigts de givre utilise Impact pulsé par défaut. S'il était sur Impact, il passe une fois sur Impact pulsé ; tu peux le changer comme avant." },
      } },
    { v = "0.23.1", en = "October 21, 2026", fr = "21 octobre 2026",
      items = {
        { en = "Fixed: two characters with the same first name (and a different surname) shared the same profile. Each character now keeps its own.",
          fr = "Corrigé : deux personnages avec le même prénom (et un nom de famille différent) partageaient le même profil. Chaque personnage garde maintenant le sien." },
        { en = "After the update, each character starts on the profile it used before. If two characters shared a first name, both start on the last one picked: choose the right profile once on each.",
          fr = "Après la mise à jour, chaque personnage reprend le profil qu'il utilisait. Si deux personnages avaient le même prénom, les deux reprennent le dernier choisi : choisis le bon profil une fois sur chacun." },
        { en = "The settings window shows your character's full name, and the profile tooltip lists the characters on it, with their realm and class.",
          fr = "La fenêtre des réglages affiche le nom complet de ton personnage, et l'infobulle du profil liste les personnages qui l'utilisent, avec leur royaume et leur classe." },
      } },
    { v = "0.23.0", en = "October 21, 2026", fr = "21 octobre 2026",
      items = {
        { en = "Each animation now has its own way in and out. Breathing fades in and out. Classic pulse pops in and grows as it goes. Impact lands at once with a white-hot flare. Flash gives three hard flashes. Still turns on and off at once.",
          fr = "Chaque animation a maintenant sa propre entrée et sortie. Respiration apparaît et disparaît en fondu. Pulsation jaillit et grandit en partant. Impact arrive d'un coup avec un éclat blanc. Éclairs donne trois éclairs francs. Fixe s'allume et s'éteint d'un coup." },
        { en = "When you use a proc, its alert bursts out; when it runs out, it fades. A proc that comes again, or reaches its maximum of stacks, punches again.",
          fr = "Quand tu utilises un proc, son alerte éclate ; quand il expire, elle s'efface. Un proc qui revient, ou atteint son maximum de cumuls, frappe à nouveau." },
        { en = "Each proc has a default animation that suits it: Impact for short windows (Overpower, Revenge, Heating Up...), Flash for rare strong procs, Classic pulse for free or faster spells (Shadow Trance, Missile Barrage...), Breathing for long buffs, Still for Execute and Hammer of Wrath. Procs set to Breathing take their new default once; you can change it as before.",
          fr = "Chaque proc a une animation par défaut qui lui va : Impact pour les fenêtres courtes (Fulgurance, Vengeance du guerrier, Réchauffement...), Éclairs pour les procs rares et puissants, Pulsation pour les sorts gratuits ou plus rapides (Transe de l'ombre, Barrage de projectiles...), Respiration pour les longs buffs, Fixe pour Exécution et Marteau de courroux. Les procs réglés sur Respiration prennent une fois leur nouvelle animation par défaut ; tu peux la changer comme avant." },
        { en = "The preview in the settings shows both ways out: used and ran out.",
          fr = "L'aperçu des réglages montre les deux sorties : utilisé et expiré." },
      } },
    { v = "0.22.0", en = "October 21, 2026", fr = "21 octobre 2026",
      items = {
        { en = "New settings window, bigger, with a live preview: the alert you set up shows on the right as it will be in game, at its real size, with its time left and its stacks. Type /flare, or open it from Options > AddOns > Shadowflare.",
          fr = "Nouvelle fenêtre de réglages, plus grande, avec un aperçu en direct : l'alerte que tu règles s'affiche à droite telle qu'elle sera en jeu, à sa taille réelle, avec son temps restant et ses cumuls. Tape /flare, ou ouvre-la depuis Options > Add-ons > Shadowflare." },
        { en = "On the left, the classes and their alerts, each with its box to turn it on or off. In the middle, four tabs: Style, Look, Stacks, Timer and sound.",
          fr = "À gauche, les classes et leurs alertes, chacune avec sa case pour l'activer ou la couper. Au milieu, quatre onglets : Style, Apparence, Cumuls, Temps et son." },
        { en = "Procs with stacks: the preview plays 1 stack to the maximum, with a picture of each step. Click one to stay on it.",
          fr = "Procs à cumuls : l'aperçu joue de 1 cumul jusqu'au maximum, avec une image de chaque étape. Clique sur l'une pour rester dessus." },
        { en = "New: Only in combat, on by default (off for Victory Rush). Untick it to see an alert between fights too.",
          fr = "Nouveau : Seulement en combat, coché par défaut (décoché pour Ivresse de la victoire). Décoche-le pour voir une alerte entre les combats aussi." },
        { en = "New: Place all, to arrange every alert of a class together on screen. Play, to hear an alert's sound. Reset, to put an alert's look back to its defaults. Dark or bright background in the preview.",
          fr = "Nouveau : Placer les alertes, pour disposer ensemble à l'écran toutes les alertes d'une classe. Écouter, pour entendre le son d'une alerte. Réinitialiser, pour remettre l'apparence d'une alerte par défaut. Fond sombre ou clair dans l'aperçu." },
        { en = "First install: only the alerts of your class are on (and the weapon and enchant ones). Another class logging in with the same profile gets its own alerts on.",
          fr = "Première installation : seules les alertes de ta classe sont activées (et celles des armes et enchantements). Une autre classe qui se connecte avec le même profil a ses alertes activées à son tour." },
        { en = "The Test button is gone: the preview shows the alert all the time.",
          fr = "Le bouton Tester disparaît : l'aperçu montre l'alerte en permanence." },
      } },
    { v = "0.21.3", en = "October 21, 2026", fr = "21 octobre 2026",
      items = {
        { en = "Victory Rush: after a kill during its cooldown, the alert now shows the time really left when the cooldown ends, not a full 20 seconds.",
          fr = "Ivresse de la victoire : après une victime pendant son temps de recharge, l'alerte affiche maintenant le temps qu'il reste vraiment à la fin de la recharge, et non 20 secondes pleines." },
        { en = "Same for Overpower, Revenge, Riposte, Mongoose Bite and Counterattack.",
          fr = "Pareil pour Fulgurance, Vengeance, Riposte, Morsure de la mangouste et Contre-attaque." },
      } },
    { v = "0.21.2", en = "October 20, 2026", fr = "20 octobre 2026",
      items = {
        { en = "Options: a long proc description no longer runs over the Show this alert checkbox (seen in French). The settings under it move down to make room.",
          fr = "Options : une longue description de proc ne passe plus sur la case Afficher cette alerte (vu en français). Les réglages en dessous descendent pour lui faire de la place." },
      } },
    { v = "0.21.1", en = "October 20, 2026", fr = "20 octobre 2026",
      items = {
        { en = "Alerts are easier to see on bright ground: a dark shadow is now drawn under every alert, so it shows in its own color instead of fading into the floor. New setting Shadow (60% by default, 0% turns it off).",
          fr = "Les alertes se voient mieux sur un sol clair : une ombre sombre est maintenant dessinée sous chaque alerte, qui garde sa couleur au lieu de se perdre dans le sol. Nouveau réglage Ombre (60 % par défaut, 0 % la coupe)." },
        { en = "Stacks, Below the maximum: the menu is now a row of cards, one per look. Each card shows your proc with its own style and color, going from 1 stack to the maximum, so you can see each look before you pick it. Click a card to choose it.",
          fr = "Cumuls, Sous le maximum : le menu devient une rangée de cartes, une par apparence. Chaque carte montre ton proc avec son style et sa couleur, de 1 cumul jusqu'au maximum, pour voir chaque apparence avant de choisir. Clique sur une carte pour la choisir." },
        { en = "A line under the cards says what the chosen look does.",
          fr = "Une ligne sous les cartes explique ce que fait l'apparence choisie." },
      } },
    { v = "0.21.0", en = "October 20, 2026", fr = "20 octobre 2026",
      items = {
        { en = "New setting for procs with stacks, Below the maximum: Dimmer (as before), Fills up, Fills from the left, or Dots. With a fill, the alert fills a part per stack and the rest stays faint. With Dots, one dot per stack shows under the alert.",
          fr = "Nouveau réglage pour les procs à cumuls, Sous le maximum : Moins lumineuse (comme avant), Se remplit vers le haut, Se remplit depuis la gauche, ou Points. Avec un remplissage, l'alerte se remplit d'une partie par cumul et le reste reste pâle. Avec Points, un point par cumul s'affiche sous l'alerte." },
        { en = "Fingers of Frost: new look Sides, now its default. With 1 charge, one side of its art shows; with 2, both sides, like the game's own art. Only for procs with 2 stacks and a style drawn on two sides (Arcs, or the game's art on the sides).",
          fr = "Doigts de givre : nouvelle apparence Côtés, désormais par défaut. Avec 1 charge, un côté de son dessin s'affiche ; avec 2, les deux côtés, comme le dessin du jeu. Seulement pour les procs à 2 cumuls et un style dessiné sur deux côtés (Arcs, ou les dessins du jeu sur les côtés)." },
        { en = "Each proc with stacks has a default look that suits it: a fill for Heating Up and Eclipse, dots for Maelstrom Weapon, Arcane Blast, Reckoning and Thousand Cuts, dimmer for Vengeance. It shows when Show from is below the maximum.",
          fr = "Chaque proc à cumuls a une apparence par défaut qui lui va : un remplissage pour Réchauffement et Éclipse, des points pour Arme du Maelström, Déflagration des Arcanes, Rétribution et Mille entailles, moins lumineuse pour Vengeance. Elle se voit quand « Afficher à partir de » est sous le maximum." },
        { en = "It works with every style, and for alerts shown by the game itself.",
          fr = "Il marche avec tous les styles, et pour les alertes affichées par le jeu lui-même." },
        { en = "In test: please report any problem.",
          fr = "En test : signalez-moi tout problème." },
      } },
    { v = "0.20.1", en = "October 20, 2026", fr = "20 octobre 2026",
      items = {
        { en = "Less work in combat: when the game sends many changes at once (rage, energy, mana, buffs), Shadowflare checks them together, at most 10 times a second. Combat start and end, casts and the game's proc alerts are still checked at once.",
          fr = "Moins de travail en combat : quand le jeu envoie beaucoup de changements à la fois (rage, énergie, mana, buffs), Shadowflare les vérifie ensemble, au plus 10 fois par seconde. Le début et la fin du combat, les sorts lancés et les alertes de proc du jeu sont toujours vérifiés tout de suite." },
        { en = "Each spell is read once per check, and only warlocks look for Shadow Trance.",
          fr = "Chaque sort n'est lu qu'une fois par vérification, et seuls les démonistes cherchent Transe de l'ombre." },
        { en = "Alerts shown by the game: no work for alerts that are off, and nothing is redone when nothing moves (Still, Impact, Flash).",
          fr = "Alertes affichées par le jeu : rien n'est fait pour les alertes coupées, et rien n'est refait quand rien ne bouge (Fixe, Impact, Éclairs)." },
      } },
    { v = "0.20.0", en = "October 20, 2026", fr = "20 octobre 2026",
      items = {
        { en = "New: Reckoning for paladins, with the Stacks settings (from how many stored attacks it shows).",
          fr = "Nouveau : Rétribution pour les paladins, avec les réglages de cumuls (à partir de combien d'attaques stockées elle s'affiche)." },
        { en = "New: Nature's Grace for druids, Thousand Cuts for rogues, Arcane Blast stacks for mages (choose from how many stacks they show).",
          fr = "Nouveau : Grâce de la nature pour les druides, Mille entailles pour les voleurs, cumuls de Déflagration des Arcanes pour les mages (choisis à partir de combien de cumuls ils s'affichent)." },
        { en = "New: Improved Stormstrike for shamans. When a dodge or a parry resets Stormstrike, the alert shows until you use it, or for the time you choose (Show for). With sound.",
          fr = "Nouveau : Frappe-tempête améliorée pour les chamans. Quand une esquive ou une parade remet Frappe-tempête à zéro, l'alerte s'affiche jusqu'à ce que tu la lances, ou pendant le temps choisi (Afficher pendant). Avec son." },
        { en = "New: two sections for every class, Weapons (Hand of Edward the Odd) and Enchants (Revelation, Insight). Pick them in the Class menu.",
          fr = "Nouveau : deux parties pour toutes les classes, Armes (Hand of Edward the Odd) et Enchantements (Révélation, Clairvoyance). À choisir dans le menu Classe." },
        { en = "Like the other procs shown by the game, they have no sound and start once their buff has been on you out of combat.",
          fr = "Comme les autres procs affichés par le jeu, ils n'ont pas de son et démarrent une fois que leur buff a été sur toi hors combat." },
        { en = "In test: please report any problem.",
          fr = "En test : signalez-moi tout problème." },
      } },
    { v = "0.19.0", en = "October 20, 2026", fr = "20 octobre 2026",
      items = {
        { en = "New: Deadly Aspects for hunters, Redoubt and Vengeance for paladins, Martyrdom for priests. They are shown by the game itself, without sound, once their buff has been on you out of combat. Vengeance has the Stacks settings.",
          fr = "Nouveau : Aspects mortels pour les chasseurs, Redoute et Vengeance (Vindicte) pour les paladins, Martyre pour les prêtres. Ils sont affichés par le jeu lui-même, sans son, une fois que leur buff a été sur toi hors combat. Vengeance a les réglages de cumuls." },
        { en = "Alerts shown by the game can now use the Impact and Flash animations.",
          fr = "Les alertes affichées par le jeu peuvent maintenant utiliser les animations Impact et Éclairs." },
        { en = "Alerts shown by the game only animate in combat and for 20 seconds after. Nothing runs between fights.",
          fr = "Les alertes affichées par le jeu ne s'animent qu'en combat et pendant 20 secondes après. Rien ne tourne entre les combats." },
        { en = "Fixed: Overpower, Revenge, Riposte, Mongoose Bite and Counterattack could show again for a moment after combat. They now show in combat only.",
          fr = "Corrigé : Fulgurance, Vengeance (guerrier), Riposte, Morsure de la mangouste et Contre-attaque pouvaient réapparaître un instant après le combat. Elles ne s'affichent plus qu'en combat." },
        { en = "In test: please report any problem.",
          fr = "En test : signalez-moi tout problème." },
      } },
    { v = "0.18.2", en = "October 20, 2026", fr = "20 octobre 2026",
      items = {
        { en = "Fingers of Frost: a second way to show it. Once its buff has been on you out of combat, the game shows the alert itself, with the charges left. The game's proc alert still works as before.",
          fr = "Doigts de givre : une deuxième façon de l'afficher. Une fois que son buff a été sur toi hors combat, le jeu affiche lui-même l'alerte, avec les charges restantes. L'alerte de proc du jeu fonctionne toujours comme avant." },
        { en = "Fixed: with \"Show from\" below the maximum, an alert shown by the game could show several times on top of itself.",
          fr = "Corrigé : avec « Afficher à partir de » sous le maximum, une alerte affichée par le jeu pouvait s'afficher plusieurs fois l'une sur l'autre." },
      } },
    { v = "0.18.1", en = "October 19, 2026", fr = "19 octobre 2026",
      items = {
        { en = "Fixed: the time left showed one second more than the buff. It now rounds down, like the game's buff timer.",
          fr = "Corrigé : le temps restant affichait une seconde de plus que le buff. Il est maintenant arrondi à l'inférieur, comme le minuteur des buffs du jeu." },
      } },
    { v = "0.18.0", en = "October 19, 2026", fr = "19 octobre 2026",
      items = {
        { en = "New Stacks section in the options of Heating Up, Maelstrom Weapon and Eclipse. \"Show from\" shows the alert from fewer stacks. By default it still shows at the maximum.",
          fr = "Nouvelle partie Cumuls dans les options de Réchauffement, Arme du Maelström et Éclipse. « Afficher à partir de » montre l'alerte avec moins de cumuls. Par défaut, elle s'affiche toujours au maximum." },
        { en = "Below the maximum, the alert is dimmer. The sound plays at the maximum only.",
          fr = "Sous le maximum, l'alerte est moins lumineuse. Le son ne joue qu'au maximum." },
        { en = "The number of stacks shows next to the alert. Place the alert to move it, use the mouse wheel on it to resize it, or untick \"Show the number of stacks\".",
          fr = "Le nombre de cumuls s'affiche à côté de l'alerte. Place l'alerte pour le déplacer, utilise la molette dessus pour changer sa taille, ou décoche « Afficher le nombre de cumuls »." },
        { en = "In test: please report any problem.",
          fr = "En test : signalez-moi tout problème." },
      } },
    { v = "0.17.1", en = "October 19, 2026", fr = "19 octobre 2026",
      items = {
        { en = "Plainer texts in the options and in this window.",
          fr = "Textes plus simples dans les options et dans cette fenêtre." },
      } },
    { v = "0.17.0", en = "October 18, 2026", fr = "18 octobre 2026",
      items = {
        { en = "New: Remorseless Attacks for rogues and Rapid Killing for hunters. After a kill, they show when your next strike or shot is empowered.",
          fr = "Nouveau : Attaques impitoyables pour les voleurs et Tuerie rapide pour les chasseurs. Après une victoire, ils montrent quand ton prochain coup ou ton prochain tir est renforcé." },
        { en = "These two are shown by the game itself, without sound. They start working once their buff has been on you out of combat (a message in the chat says so). In test: please report any problem.",
          fr = "Ces deux-là sont affichés par le jeu lui-même, sans son. Ils fonctionnent une fois que leur buff a été sur toi hors combat (un message dans le chat le signale). En test : signalez-moi tout problème." },
      } },
    { v = "0.16.0", en = "October 17, 2026", fr = "17 octobre 2026",
      items = {
        { en = "For procs that are buffs, the game itself can now show Shadowflare's alert, with the right number of stacks and the real time left: Heating Up, Eclipse, Maelstrom Weapon, Decimation, Infusion of Light, Cutthroat, Clearcasting, Missile Barrage, Omen of Clarity, Elemental Focus and Searing Light.",
          fr = "Pour les procs qui sont des buffs, le jeu lui-même peut maintenant afficher l'alerte de Shadowflare, au bon nombre de cumuls et avec le vrai temps restant : Réchauffement, Éclipse, Arme du Maelström, Décimation, Imprégnation de lumière, Coupe-gorge, Idées claires, Barrage de projectiles, Augure de clarté, Focalisation élémentaire et Lumière incendiaire." },
        { en = "Each one switches the first time its buff is on you out of combat. A message in the chat says so. Until then, nothing changes. The sound still comes from Shadowflare.",
          fr = "Chacun bascule la première fois que son buff est sur toi hors combat. Un message dans le chat le signale. D'ici là, rien ne change. Le son vient toujours de Shadowflare." },
        { en = "An alert shown by the game can use Breathing or Classic pulse. Impact and Flash hold still. To go back to the old way, type /flare gameshow.",
          fr = "Une alerte affichée par le jeu peut utiliser Respiration ou Pulsation classique. Impact et Éclairs restent fixes. Pour revenir à l'ancienne méthode, tape /flare gameshow." },
      } },
    { v = "0.15.0", en = "October 16, 2026", fr = "16 octobre 2026",
      items = {
        { en = "New Animation setting for each proc: Breathing (as before), Classic pulse, Impact, Flash or Still. The chosen style plays it in a loop in the options.",
          fr = "Nouveau réglage Animation pour chaque proc : Respiration (comme avant), Pulsation classique, Impact, Éclairs ou Fixe. Le style choisi la joue en boucle dans les options." },
        { en = "More of the game's proc art in the classic styles, including Frozen Fingers. Fingers of Frost now uses it by default, with the Impact animation.",
          fr = "Davantage de dessins de procs du jeu dans les styles classiques, dont Frozen Fingers. Doigts de givre l'utilise maintenant par défaut, avec l'animation Impact." },
      } },
    { v = "0.14.0", en = "October 16, 2026", fr = "16 octobre 2026",
      items = {
        { en = "New: Fingers of Frost for Frost mages. Shadowflare follows the game's own proc alert for it, so the sound is the game's. In test: please report if it does not show.",
          fr = "Nouveau : Doigts de givre pour les mages Givre. Shadowflare suit l'alerte de proc du jeu pour lui, donc le son est celui du jeu. En test : signalez-moi s'il ne s'affiche pas." },
      } },
    { v = "0.13.3", en = "October 16, 2026", fr = "16 octobre 2026",
      items = {
        { en = "Victory Rush no longer shows while it is on cooldown (thanks for the report). The same goes for Overpower, Riposte, Mongoose Bite and Counterattack.",
          fr = "Ivresse de la victoire ne s'affiche plus pendant son temps de recharge (merci pour le signalement). Pareil pour Fulgurance, Riposte, Morsure de la mangouste et Contre-attaque." },
      } },
    { v = "0.13.2", en = "October 16, 2026", fr = "16 octobre 2026",
      items = {
        { en = "Hot Streak becomes Heating Up, as in the latest beta: the alert shows at 3 stacks, when your next Pyroblast casts 75% faster. Presence of Mind no longer shows it by mistake.",
          fr = "Chaleur continue devient Réchauffement, comme dans la dernière bêta : l'alerte s'affiche à 3 cumuls, quand ta prochaine Explosion pyrotechnique s'incante 75 % plus vite. Présence spirituelle ne l'affiche plus par erreur." },
        { en = "Searing Light no longer shows when Inner Focus makes Holy Nova free.",
          fr = "Lumière incendiaire ne s'affiche plus quand Focalisation intérieure rend Nova sacrée gratuite." },
        { en = "Elemental Focus shows only when the spell is free, so Maelstrom Weapon no longer shows it by mistake.",
          fr = "Focalisation élémentaire ne s'affiche que si le sort est gratuit : Arme du Maelström ne l'affiche plus par erreur." },
        { en = "Omen of Clarity and Missile Barrage are now listed for every spec, as in the game.",
          fr = "Augure de clarté et Barrage de projectiles sont maintenant proposés pour toutes les spécialisations, comme dans le jeu." },
        { en = "Proc names now come from the game for more of them.",
          fr = "Les noms des procs viennent maintenant du jeu pour davantage d'entre eux." },
      } },
    { v = "0.13.1", en = "October 15, 2026", fr = "15 octobre 2026",
      items = {
        { en = "Fixed an error on every Rejuvenation or shapeshift in combat (thanks for the report).",
          fr = "Correction d'une erreur à chaque Récupération ou changement de forme en combat (merci pour le signalement)." },
        { en = "Clearcasting, Omen of Clarity and Elemental Focus now show the Clearcasting icon instead of one of the spells they make free.",
          fr = "Idées claires, Augure de clarté et Focalisation élémentaire affichent maintenant l'icône du buff au lieu d'un des sorts qu'ils rendent gratuits." },
        { en = "New option: only the glow on the edges of the screen, without the alert itself.",
          fr = "Nouvelle option : seulement la lueur sur les bords de l'écran, sans l'alerte elle-même." },
      } },
    { v = "0.13.0", en = "October 15, 2026", fr = "15 octobre 2026",
      items = {
        { en = "Shadowflare now covers every class. Mage: Clearcasting, Missile Barrage, Hot Streak. Druid: Omen of Clarity, Eclipse. Shaman: Maelstrom Weapon, Elemental Focus. Paladin: Infusion of Light, Hammer of Wrath. Priest: Searing Light. Rogue: Riposte, Cutthroat. Hunter: Mongoose Bite, Counterattack. Warrior: Execute and Victory Rush too.",
          fr = "Shadowflare couvre maintenant toutes les classes. Mage : Idées claires, Barrage de projectiles, Chaleur continue. Druide : Augure de clarté, Éclipse. Chaman : Arme du Maelström, Focalisation élémentaire. Paladin : Imprégnation de lumière, Marteau de courroux. Prêtre : Lumière incendiaire. Voleur : Riposte, Coupe-gorge. Chasseur : Morsure de la mangouste, Contre-attaque. Guerrier : Exécution et Ivresse de la victoire en plus." },
        { en = "The new procs are in test: they were not all checked in game. Please report problems on CurseForge.",
          fr = "Les nouveaux procs sont en test : ils n'ont pas tous été vérifiés en jeu. Signalez les problèmes sur CurseForge." },
        { en = "Execute and Hammer of Wrath show only while you can cast them: enough rage or mana, and the target low enough.",
          fr = "Exécution et Marteau de courroux ne s'affichent que lorsque tu peux les lancer : assez de rage ou de mana, et la cible assez basse." },
      } },
    { v = "0.12.0", en = "October 14, 2026", fr = "14 octobre 2026",
      items = {
        { en = "Profiles: each character picks one. Save as... makes a copy under a new name. Rename and Delete too.",
          fr = "Profils : chaque personnage choisit le sien. Enregistrer sous... en fait une copie sous un nouveau nom. Renommer et Supprimer aussi." },
        { en = "Export and Import: a profile becomes a text to copy, for another account or to share it.",
          fr = "Exporter et Importer : un profil devient un texte à copier, pour un autre compte ou pour le partager." },
        { en = "Copy from: gives this proc the look of another one (style, color, size, angle, sound, place).",
          fr = "Copier depuis : donne à ce proc l'apparence d'un autre (style, couleur, taille, angle, son, place)." },
        { en = "Your current settings become the first profile.",
          fr = "Tes réglages actuels deviennent le premier profil." },
      } },
    { v = "0.11.1", en = "October 14, 2026", fr = "14 octobre 2026",
      items = {
        { en = "Revenge and Overpower: once cast, the alert no longer comes back while the spell is on cooldown.",
          fr = "Vengeance et Fulgurance : une fois lancées, l'alerte ne revient plus pendant le temps de recharge du sort." },
      } },
    { v = "0.11.0", en = "October 13, 2026", fr = "13 octobre 2026",
      items = {
        { en = "New Rotation setting: turn the alert to any angle, for example arcs above and below. While placing it: Shift + mouse wheel.",
          fr = "Nouveau réglage Rotation : tourne l'alerte dans le sens que tu veux, par exemple les arcs au-dessus et en dessous. Pendant le placement : Maj + molette." },
        { en = "The time left placed apart now follows the alert when you move it. While placing, it sits above the alert.",
          fr = "Le temps restant placé à part suit maintenant l'alerte quand tu la déplaces. Pendant le placement, il passe au-dessus de l'alerte." },
      } },
    { v = "0.10.0", en = "October 13, 2026", fr = "13 octobre 2026",
      items = {
        { en = "New: Overpower and Revenge for warriors. The alert shows while the spell can be used and hides when you use it. It stays up when you lack rage.",
          fr = "Nouveau : Fulgurance et Vengeance pour les guerriers. L'alerte s'affiche tant que le sort est utilisable et disparaît quand tu le lances. Elle reste affichée quand tu manques de rage." },
        { en = "New warrior styles from the game's own proc art (Sudden Death, Sword and Board and more), and a new Blood color.",
          fr = "Nouveaux styles de guerrier tirés des dessins de procs du jeu (Mort subite, Épée et bouclier, et d'autres), et une nouvelle couleur Sang." },
      } },
    { v = "0.9.1", en = "October 12, 2026", fr = "12 octobre 2026",
      items = {
        { en = "Shadow Trance: the alert now hides when Shadow Bolt is cast, even when two procs come close together. A proc right after a bolt gets its own 10 seconds.",
          fr = "Transe de l'ombre : l'alerte disparaît quand le Trait de l'ombre part, même quand deux procs se suivent de près. Un proc juste après un Trait a ses propres 10 secondes." },
        { en = "Decimation: when it starts again (Shadow Bolt or Searing Pain on a target below 35%), its time left starts again too.",
          fr = "Décimation : quand elle se relance (Trait de l'ombre ou Douleur brûlante sur une cible sous 35 %), son temps restant repart aussi." },
      } },
    { v = "0.9.0", en = "October 11, 2026", fr = "11 octobre 2026",
      items = {
        { en = "New alert for Demonology: Decimation, when Soul Fire casts faster.",
          fr = "Nouvelle alerte en Démonologie : Décimation, quand Feu de l'âme s'incante plus vite." },
        { en = "Options: choose a class, then a proc (its spec is shown next to it). Each proc has its own alert: style, color, size, sound and place on screen. Your Shadow Trance settings are kept.",
          fr = "Options : choisis une classe, puis un proc (sa spécialisation est indiquée à côté). Chaque proc a sa propre alerte : style, couleur, taille, son et place à l'écran. Tes réglages de Transe de l'ombre sont conservés." },
        { en = "In combat, the game hides your buffs from addons: Shadowflare follows the cast time of the spell each proc speeds up.",
          fr = "En combat, le jeu cache tes buffs aux addons : Shadowflare suit le temps d'incantation du sort que chaque proc accélère." },
      } },
    { v = "0.8.1", en = "October 10, 2026", fr = "10 octobre 2026",
      items = {
        { en = "Fixed: the alert no longer showed up in 0.8.0. Shadowflare asks the game directly again whenever your buffs change, and checks Shadow Bolt's cast time in combat.",
          fr = "Corrigé : l'alerte ne s'affichait plus en 0.8.0. Shadowflare interroge de nouveau le jeu à chaque changement de buffs, et surveille le temps d'incantation du Trait de l'ombre en combat." },
      } },
    { v = "0.8.0", en = "October 10, 2026", fr = "10 octobre 2026",
      items = {
        { en = "Shadowflare now runs nothing between procs, follows only the buffs that change in combat, and builds its options page the first time you open it.",
          fr = "Shadowflare ne fait plus rien entre deux procs, ne suit que les buffs qui changent en combat, et construit sa page d'options à la première ouverture." },
        { en = "The alert now fades out when the proc ends.",
          fr = "L'alerte s'efface maintenant progressivement à la fin du proc." },
      } },
    { v = "0.7.1", en = "October 9, 2026", fr = "9 octobre 2026",
      items = {
        { en = "Options: the Center button is no longer cut off at the edge of the page.",
          fr = "Options : le bouton Recentrer n'est plus coupé au bord de la page." },
      } },
    { v = "0.7.0", en = "October 9, 2026", fr = "9 octobre 2026",
      items = {
        { en = "Placing the alert: the options close, a small window shows the steps, and Done (or Escape) opens the options again.",
          fr = "Placer l'alerte : les options se ferment, une petite fenêtre indique les étapes, et Terminé (ou Échap) rouvre les options." },
      } },
    { v = "0.6.0", en = "October 9, 2026", fr = "9 octobre 2026",
      items = {
        { en = "Choose the sound in the options: the game's own proc alert, one of six Shadowflare sounds, or none. A Shadowflare sound turns the game's alert off.",
          fr = "Choix du son dans les options : l'alerte de proc du jeu, l'un des six sons de Shadowflare, ou aucun. Un son de Shadowflare coupe l'alerte du jeu." },
        { en = "Placing the alert or the time left now shows a grid, like the game's Edit Mode. They snap to the lines.",
          fr = "Le placement de l'alerte et du temps restant affiche maintenant une grille, comme le mode Édition du jeu. Ils s'accrochent aux lignes." },
      } },
    { v = "0.5.0", en = "October 9, 2026", fr = "9 octobre 2026",
      items = {
        { en = "The time left can now be moved on its own: tick \"Move the time left separately\", then drag it anywhere while moving the alert. The mouse wheel changes its size.",
          fr = "Le temps restant se déplace maintenant à part : coche « Déplacer le temps restant à part », puis fais-le glisser où tu veux pendant le déplacement de l'alerte. La molette change sa taille." },
        { en = "This window: what's new is shown once after each update. It can be turned off in the options (About).",
          fr = "Cette fenêtre : les nouveautés s'affichent une fois après chaque mise à jour. Désactivable dans les options (À propos)." },
      } },
    { v = "0.4.0", en = "October 9, 2026", fr = "9 octobre 2026",
      items = {
        { en = "First version: an alert when Shadow Trance procs, with 10 modern styles and the game's own classic proc art.",
          fr = "Première version : une alerte quand Transe de l'ombre se déclenche, avec 10 styles modernes et les dessins de procs classiques du jeu." },
        { en = "Color, size, opacity, time left, sound and a glow on the edges of the screen, all in the options (/flare).",
          fr = "Couleur, taille, opacité, temps restant, son et lueur sur les bords de l'écran, le tout dans les options (/flare)." },
      } },
}

local FR = GetLocale() == "frFR"
local function lang(t) return (FR and t.fr) or t.en end

-- "0.10.0" is newer than "0.9.2"
local function newer(a, b)
    local pa, pb = {}, {}
    for n in string.gmatch(a or "0", "%d+") do pa[#pa + 1] = tonumber(n) end
    for n in string.gmatch(b or "0", "%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local win, content
local lines = { used = {}, free = {}, y = 0 }
local TEXT_W = 372

local function build()
    local ok, f = pcall(CreateFrame, "Frame", "ShadowflareNotesFrame", UIParent, "ButtonFrameTemplate")
    local modern = ok and f
    if not modern then
        ok, f = pcall(CreateFrame, "Frame", "ShadowflareNotesFrame", UIParent, "BasicFrameTemplateWithInset")
        if not (ok and f) then
            f = CreateFrame("Frame", "ShadowflareNotesFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
            if f.SetBackdrop then
                f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 } })
            end
            local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", -6, -6)
        end
    end
    f:SetSize(430, 360)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    table.insert(UISpecialFrames, "ShadowflareNotesFrame") -- Escape closes it

    local title = L.NOTES_TITLE
    if modern then
        if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
        if f.SetTitle then pcall(f.SetTitle, f, title)
        elseif f.TitleContainer and f.TitleContainer.TitleText then f.TitleContainer.TitleText:SetText(title)
        elseif f.TitleText then f.TitleText:SetText(title) end
    elseif f.TitleText then
        f.TitleText:SetText(title)
    else
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOP", 0, -16); fs:SetText(title)
    end

    local area = f.Inset or f.InsetBg or f
    local scroll = CreateFrame("ScrollFrame", "ShadowflareNotesScroll", f, "UIPanelScrollFrameTemplate")
    if area ~= f then
        scroll:SetPoint("TOPLEFT", area, "TOPLEFT", 10, -10)
        scroll:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -28, 8)
    else
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
        scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 40)
    end
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(TEXT_W, 10)
    scroll:SetScrollChild(content)
    f.scroll = scroll

    local closeB = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeB:SetSize(96, 22)
    closeB:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
    closeB:SetText(CLOSE or "Close")
    closeB:SetScript("OnClick", function() f:Hide() end)
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", f, "BOTTOMLEFT", 14, 15)
    hint:SetPoint("RIGHT", closeB, "LEFT", -8, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.NOTES_HINT)

    f:Hide()
    win = f
end

local function addLine(font, text, gapBefore, indent)
    local fs = table.remove(lines.free) or content:CreateFontString(nil, "OVERLAY", font)
    fs:SetFontObject(font)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetWidth(TEXT_W - (indent or 0))
    fs:SetText(text)
    fs:ClearAllPoints()
    lines.y = lines.y - (gapBefore or 0)
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", indent or 0, lines.y)
    fs:Show()
    lines.used[#lines.used + 1] = fs
    lines.y = lines.y - fs:GetStringHeight()
end

local function fill(sinceVersion)
    for _, fs in ipairs(lines.used) do fs:Hide(); lines.free[#lines.free + 1] = fs end
    lines.used, lines.y = {}, 0
    local first = true
    for _, n in ipairs(ns.NOTES) do
        if not sinceVersion or newer(n.v, sinceVersion) then
            addLine("GameFontNormalLarge", "Shadowflare " .. n.v, first and 2 or 18)
            addLine("GameFontDisableSmall", lang(n), 4)
            for _, it in ipairs(n.items) do addLine("GameFontHighlight", "- " .. lang(it), 10, 4) end
            first = false
        end
    end
    content:SetHeight(math.max(10, -lines.y + 8))
    if win.scroll.SetVerticalScroll then win.scroll:SetVerticalScroll(0) end
end

-- sinceVersion: only what is newer than it (after an update); nil shows every note
function ns.ShowNotes(sinceVersion)
    if not win then
        local ok, err = pcall(build)
        if not ok then ns.Print("notes error: " .. tostring(err)) return end
    end
    local ok, err = pcall(fill, sinceVersion)
    if not ok then ns.Print("notes error: " .. tostring(err)) return end
    win:Show(); win:Raise()
end

-- First login after an update. A fresh install shows nothing, it only records the version.
-- 0.4.x did not record anything, so a missing value means "updated from 0.4.1".
local function checkUpdate()
    local db = ns.db
    if not db then return end
    if ns.freshInstall then db.lastVersion = ns.version return end
    local seen = db.lastVersion or "0.4.1"
    db.lastVersion = ns.version
    if not newer(ns.version, seen) then return end
    if db.showNotes == false then return end
    -- Only open the window when there is something new to read
    for _, n in ipairs(ns.NOTES) do
        if newer(n.v, seen) then ns.ShowNotes(seen) return end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    -- A few seconds after the loading screen, once the game's own login windows have settled
    if C_Timer then C_Timer.After(4, function() pcall(checkUpdate) end) else pcall(checkUpdate) end
end)
