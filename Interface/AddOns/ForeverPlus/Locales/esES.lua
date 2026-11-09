-- Spanish, phase 7.7, for the Spanish and the Mexican client alike.
--
-- The English text on the left is the key, exactly as it stands in the code,
-- and the Spanish on the right is what a player reads. TRANSLATION.md holds the
-- words and the rules, gated with the owner on 2026-10-07: one table for Spain
-- and Latin America, worded so that both read it naturally and in Spain's
-- words where the two clients differ; "tú", as both clients say it; a setting
-- as an infinitive; the client's own words throughout, with no player's word;
-- straight quotes and ¿ and ¡ as the clients write them; no dash; a decimal
-- comma on every client; and a text that fits its row.
--
-- Sorted like deDE.lua, by page and then by file. tools/l10n.py reports a text
-- the code marks that is missing here, Spanish left behind for a text the code
-- no longer marks, and what the gate ruled out. The Mexican client reads this
-- file as well, see SAME_AS in Core/Locale.lua.

local ADDON, FP = ...

FP:AddLocale("esES", {

    -- -----------------------------------------------------------------------
    -- The window
    -- -----------------------------------------------------------------------

    -- Core/Boot.lua
    ["v%s loaded, %d of %d modules enabled, profile |cffffffff%s|r. Open the settings with |cff888888/fplus|r."]
        = "v%s cargado, %d de %d módulos activos, perfil |cffffffff%s|r. |cff888888/fplus|r abre la configuración.",

    -- Core/Init.lua
    ["NPC Interaction"] = "Interacción con PNJ",
    ["Merchants"] = "Mercaderes",
    ["Loot"] = "Botín",
    ["Interruptions"] = "Interrupciones",
    ["Display"] = "Visualización",
    ["Chat"] = "Chat",
    ["Tools"] = "Herramientas",

    -- Core/Options.lua
    ["Enable %s"] = "Activar %s",
    ["Do it"] = "Ejecutar",
    ["%s: custom option failed to build: %s"] = "%s: no se pudo crear una opción propia: %s",
    ["%s: option %s has an unknown type %q"] = "%s: la opción %s tiene un tipo desconocido %q",
    ["Not in use until another setting here allows it."]
        = "No se usa hasta que otra opción de aquí lo permita.",
    ["Not in use until you switch the module on."] = "No se usa hasta activar el módulo.",

    -- Core/Util.lua
    ["%s: function is missing"] = "%s: falta la función",
    ["%s: expected a function, got %s"] = "%s: se esperaba una función y se recibió %s",
    ["Error in %s: %s"] = "Error en %s: %s",
    ["%s: this client does not recognize %s. Those features remain unavailable."]
        = "%s: este cliente no conoce %s. Esas funciones siguen sin estar disponibles.",

    -- Core/Widgets.lua
    ["Select all"] = "Seleccionar todo",
    ["Close"] = "Cerrar",
    ["Paste the text here with Ctrl+V, then press the button below."]
        = "Pega aquí con Ctrl+V y luego haz clic en el botón de abajo.",
    ["Apply"] = "Aplicar",
    ["Delete Character Data"] = "Borrar datos del personaje",
    ["Do you really want to delete the data for your character %s from ForeverPlus?"]
        = "¿Seguro que quieres borrar de ForeverPlus los datos de tu personaje %s?",
    ["This deletes its gold, its place in the mail list, its profile assignment, its Auto Buy choices, its cooldowns, the notices it has already been shown and the chat saved from its last session. Profiles are shared by all characters and are kept."]
        = "Se borran su oro, su lugar en la lista del correo, su asignación de perfil, su selección de compra automática, sus tiempos de reutilización, los avisos que ya se le han mostrado y el chat guardado de su última sesión. Los perfiles se comparten entre todos los personajes y se conservan.",
    ["Delete"] = "Borrar",
    ["Cancel"] = "Cancelar",
    ["ForeverPlus no longer keeps anything about %s."] = "ForeverPlus ya no guarda nada sobre %s.",

    -- Modules/Menu.lua
    ["This window."] = "Esta ventana.",
    ["Click the box to turn it on and off."]
        = "Haz clic en la casilla para activarlo o desactivarlo.",
    ["Its settings have a tab of their own: |cffffffff%s|r. Click to go there."]
        = "Su configuración tiene una pestaña propia: |cffffffff%s|r. Haz clic para ir allí.",
    ["Click the row to show its settings."] = "Haz clic en la fila para ver su configuración.",
    ["This module has nothing to set."] = "Este módulo no tiene nada que configurar.",
    ["Gameplay"] = "Experiencia de juego",
    ["Gameplay modules are on"] = "Los módulos de juego están activados",
    ["Gameplay modules are off"] = "Los módulos de juego están desactivados",
    ["Turning this page off disables every module on it, including the minimap button. Each module keeps its own setting, so turning the page back on restores the previous settings."]
        = "Si se desactiva, se detienen todos los módulos de esta página, el botón del minimapa incluido. Cada uno conserva su propio interruptor, así que al volver a activar la página vuelven los que estaban activados.",
    ["Expand all"] = "Expandir todo",
    ["Collapse all"] = "Contraer todo",
    ["Clear"] = "Limpiar",
    ["Search"] = "Buscar",
    ["%s is on"] = "%s: activado",
    ["%s is off"] = "%s: desactivado",
    ["Switches everything on this page on or off. The settings are kept."]
        = "Activa o desactiva todo lo de esta página. La configuración se conserva.",
    ["Language"] = "Idioma",
    ["Automatic"] = "Automático",
    ["Applies to every character and profile. Automatic uses the game's language, or English if the addon does not support that language. Changes take effect after the next reload."]
        = "Se aplica a todos los personajes y perfiles. Automático usa el idioma del juego, o el inglés si este addon no lo tiene. Un cambio surte efecto al reiniciar la IU.",
    ["The language changes with the next reload. Reload now?"]
        = "El idioma cambia al reiniciar la IU. ¿Reiniciarla ahora?",
    ["Reload now"] = "Reiniciar ahora",
    ["Later"] = "Más tarde",
    ["Reload UI"] = "Reiniciar IU",
    ["This page is switched off. The box on its tab switches it on again, with every setting here as you left it."]
        = "Esta página está desactivada. La casilla de su pestaña la vuelve a activar, con toda la configuración tal como la dejaste.",
    ["The %s page has no switch on its tab. Give it a switch, or mark it internal if it only arranges the addon."]
        = "La página %s no tiene interruptor en su pestaña. Dale uno, o márcala como interna si solo organiza el addon.",
    ["Tab %s failed to build its header: %s"] = "No se pudo crear la cabecera de la pestaña %s: %s",
    ["Tab %s failed to build: %s"] = "No se pudo crear la pestaña %s: %s",
    ["The settings window was off screen and has been moved back to the center."]
        = "La ventana de configuración estaba fuera de la pantalla y se ha movido al centro.",

    -- The names of the other pages, and the switches on their tabs. The pages
    -- themselves follow in later parts of this file.
    ["Buffs"] = "Beneficios",
    ["Buff warnings are on"] = "Los avisos de beneficios están activados",
    ["Buff warnings are off"] = "Los avisos de beneficios están desactivados",
    ["The master switch for this page. Everything on it only decides what it warns about and when.|n|nOff means no icons at all. The settings are kept, so turning it back on restores what you had."]
        = "El interruptor principal de esta página. Todo lo demás en ella solo decide de qué se avisa y cuándo.|n|nSi se desactiva, no hay ningún icono. La configuración se conserva, así que al volver a activarlo recuperas lo que tenías.",
    ["Consumables"] = "Consumibles",
    ["Consumable warnings are on"] = "Los avisos de consumibles están activados",
    ["Consumable warnings are off"] = "Los avisos de consumibles están desactivados",
    ["Tooltip"] = "Descripciones",
    ["Tooltip changes are on"] = "Los cambios en las descripciones están activados",
    ["Tooltip changes are off"] = "Los cambios en las descripciones están desactivados",
    ["Off leaves the client's own tooltip exactly as it was, arrangement and position included. The settings are kept."]
        = "Si se desactiva, la descripción del cliente queda tal como era, con su disposición y su posición. La configuración se conserva.",
    ["Info bar"] = "Barra de información",
    ["The info bar is on"] = "La barra de información está activada",
    ["The info bar is off"] = "La barra de información está desactivada",
    ["Chat changes are on"] = "Los cambios en el chat están activados",
    ["Chat changes are off"] = "Los cambios en el chat están desactivados",
    ["Off leaves the chat as the client has it. The settings are kept."]
        = "Si se desactiva, el chat funciona como en el cliente. La configuración se conserva.",
    ["Design"] = "Apariencia",
    ["Profiles"] = "Perfiles",
    ["Info"] = "Info.",

    -- -----------------------------------------------------------------------
    -- Gameplay
    -- -----------------------------------------------------------------------

    -- Shared by several modules
    ["Hold Shift to pause"] = "Pausar con Mayús",
    ["Shift is held, automation paused."]
        = "Mientras mantienes Mayús, la automatización está en pausa.",
    ["No merchant open."] = "No hay ninguna ventana de mercader abierta.",

    -- Modules/QuestAutoAccept.lua
    ["Auto Accept Quests"] = "Aceptar misiones automáticamente",
    ["Also from gossip windows"] = "También desde los diálogos",
    ["Accepts quests offered inside a conversation, not just through the regular quest window."]
        = "Acepta también las misiones que se ofrecen dentro de una conversación, no solo las de la ventana de misión simple.",
    ["Confirm shared quests and escorts"] = "Confirmar misiones compartidas y escoltas",
    ["Also accepts quests other players share with you and escort quests. An escort begins the moment it is accepted."]
        = "También acepta las misiones que otros jugadores comparten contigo y las misiones de escolta. Una escolta empieza en cuanto se acepta la misión.",
    ["While Shift is down, nothing is accepted, so you can read the text first."]
        = "Mientras mantienes Mayús, no se acepta nada, por si quieres leer el texto primero.",

    -- Modules/QuestAutoTurnIn.lua
    ["Auto Turn In Quests"] = "Entregar misiones automáticamente",
    ["Hands quests in from inside a conversation as well as from the plain quest window."]
        = "Entrega misiones también desde una conversación, no solo desde la ventana de misión simple.",
    ["While Shift is down, nothing is handed in. Reward values are still shown because they belong to a separate module."]
        = "Mientras mantienes Mayús, no se entrega nada. El valor de las recompensas se sigue mostrando porque pertenece a otro módulo.",

    -- Modules/QuestRewardValue.lua
    ["Quest Reward Value"] = "Valor de las recompensas de misión",
    ["Shows what each quest reward sells for, on every quest window."]
        = "Muestra en cada ventana de misión por cuánto se vende cada recompensa.",
    ["Also on rewards you get anyway"] = "También en las recompensas fijas",
    ["Not only the ones you choose between. Off, and only a real choice carries a price."]
        = "No solo en las que se eligen. Si se desactiva, solo una elección real lleva precio.",
    ["QuestRewardValue: could not hook QuestInfo_Display, falling back to the quest events alone."]
        = "Valor de las recompensas de misión: no se pudo enganchar QuestInfo_Display, se usan solo los eventos de misión.",

    -- Modules/GossipAuto.lua
    ["Skip Gossip"] = "Saltar diálogos",
    ["Clicks past the extra line of talk at vendors, trainers, flight masters, bankers and guild masters."]
        = "Salta la línea de diálogo adicional en vendedores, instructores, maestros de vuelo, banqueros y maestros de hermandad.",
    ["Say when an unfamiliar service turns up"] = "Avisar cuando aparezca un servicio desconocido",
    ["Nothing is clicked in that case. The line tells you the addon encountered an unfamiliar service, and the details are saved so the list can be expanded deliberately. Once per kind of service, not once per NPC."]
        = "En ese caso no se hace clic en nada. El mensaje te indica que el addon ha encontrado un servicio desconocido, y los detalles se guardan para poder ampliar la lista a propósito. Una vez por tipo de servicio, no por cada PNJ.",
    ["Say every time a line is clicked"] = "Avisar cada vez que se haga clic en una línea",
    ["Writes a line in your chat each time the addon clicks a gossip line for you."]
        = "Escribe una línea en tu chat cada vez que el addon hace clic por ti en una línea de diálogo.",
    ["While Shift is down, nothing is clicked, so you can read what the NPC actually says. Hold Shift and talk again to check whether the addon was skipping a window for you."]
        = "Mientras mantienes Mayús no se hace clic en nada, para que puedas leer lo que dice el PNJ. Mantén Mayús y vuelve a hablarle para comprobar si el addon se estaba saltando una ventana por ti.",
    ["Opened the vendor for you."] = "Vendedor abierto para ti.",
    ["Opened the trainer for you."] = "Instructor abierto para ti.",
    ["Opened the taxi for you."] = "Mapa de vuelo abierto para ti.",
    ["Opened the petition for you."] = "Petición abierta para ti.",
    ["Opened the bank for you."] = "Banco abierto para ti.",
    ["Left alone because the service is unfamiliar: icon %s, \"%s\". The details are saved so the list can be expanded deliberately."]
        = "Servicio desconocido sin tocar: icono %s, \"%s\". Anotado para poder ampliar la lista a propósito.",

    -- Modules/Looting.lua
    ["Fast Auto Loot"] = "Despojo automático rápido",
    ["Loots without the delay, and can roll greed on greens."]
        = "Despoja sin espera y puede tirar por codicia en los objetos verdes.",
    ["Loot without the delay"] = "Despojar sin espera",
    ["Takes every slot at once instead of waiting for the client to process them one by one. It never decides whether to loot: that stays with your own auto loot setting and its modifier key, and this does nothing at all when the client was not going to loot."]
        = "Recoge todas las casillas a la vez en lugar de esperar a que el cliente las procese una por una. Nunca decide si se despoja: eso depende de tu opción \"Despojar automáticamente\" y de su tecla modificadora, y no hace nada si el cliente no iba a despojar.",
    ["Turn on Auto Loot"] = "Activar despojo automático",
    ["Turns on the game's own auto loot."] = "Activa la opción \"Despojar automáticamente\" del juego.",
    ["Rolling"] = "Tiradas",
    ["Roll greed on green items"] = "Tirar por codicia en objetos verdes",
    ["Rolls greed on every green item automatically."]
        = "Tira por codicia automáticamente en cada objeto verde.",
    ["Say what was rolled on"] = "Indicar el objeto de cada tirada",
    ["Shows the item in your own chat. Nothing is sent to the group."]
        = "Una línea en tu propio chat con el nombre del objeto. No se envía nada al grupo.",
    ["Looting: this client offers no way to set a CVar."]
        = "Despojo automático rápido: este cliente no ofrece forma de establecer una CVar.",
    ["The client's auto loot is already on, nothing changed."]
        = "\"Despojar automáticamente\" ya está activada.",
    ["Looting: the client refused to set autoLootDefault."]
        = "Despojo automático rápido: el cliente se negó a establecer autoLootDefault.",
    ["Looting: autoLootDefault was set but does not report that it is on. Check the client's own options."]
        = "Despojo automático rápido: autoLootDefault se ha establecido, pero no se lee como activado. Revisa las opciones del cliente.",
    ["The client's auto loot is now on. That is a client setting, so it stays on whether or not this addon is running."]
        = "\"Despojar automáticamente\" está ahora activada. Es una opción del juego y sigue activada aunque este addon no esté en marcha.",
    ["Looting: the loot API is missing on this build."]
        = "Despojo automático rápido: falta la interfaz de despojo en esta versión del cliente.",
    ["Looting: the roll API is missing on this build."]
        = "Despojo automático rápido: falta la interfaz de tiradas en esta versión del cliente.",
    ["Rolled greed on %s."] = "Tirada de codicia para %s.",
    ["a green item"] = "un objeto verde",

    -- Modules/AutoSellGray.lua
    ["Sell Gray Items"] = "Vender objetos grises",
    ["Sells gray items at any merchant."] = "Vende los objetos grises en cualquier mercader.",
    ["Report earnings in chat"] = "Mostrar las ganancias en el chat",
    ["Shows the total value of sold items in chat."]
        = "Suma lo vendido y lo muestra en el chat.",
    ["While Shift is down, nothing is sold."] = "Mientras mantienes Mayús, no se vende nada.",
    ["Sold %d gray item for %s%s."] = "%d objeto gris vendido por %s%s.",
    ["Sold %d gray items for %s%s."] = "%d objetos grises vendidos por %s%s.",
    ["at least "] = "al menos",
    ["%d gray item could not be sold."] = "%d objeto gris no se pudo vender.",
    ["%d gray items could not be sold."] = "%d objetos grises no se pudieron vender.",
    ["%d gray item still had a sale pending and could not be checked. Reopen the merchant if it is still there."]
        = "La venta de %d objeto gris seguía pendiente y no se pudo comprobar. Vuelve a abrir el mercader si sigue ahí.",
    ["%d gray items still had a sale pending and could not be checked. Reopen the merchant if they are still there."]
        = "La venta de %d objetos grises seguía pendiente y no se pudieron comprobar. Vuelve a abrir el mercader si siguen ahí.",
    ["AutoSellGray: C_Container.UseContainerItem or C_Timer is missing."]
        = "Vender objetos grises: falta C_Container.UseContainerItem o C_Timer.",
    ["No gray items in your bags."] = "No hay objetos grises en tus bolsas.",
    ["Found %d gray item, selling ..."] = "%d objeto gris encontrado, vendiendo...",
    ["Found %d gray items, selling ..."] = "%d objetos grises encontrados, vendiendo...",

    -- Modules/AutoRepair.lua
    ["Auto Repair"] = "Reparar automáticamente",
    ["Repairs your gear at merchants who offer repairs."]
        = "Repara tu equipo en los mercaderes que pueden hacerlo.",
    ["Report the cost in chat"] = "Mostrar el coste en el chat",
    ["Shows the repair cost in chat."]
        = "Muestra en el chat cuánto ha costado la reparación.",
    ["While Shift is down, nothing is repaired."]
        = "Mientras mantienes Mayús, no se repara nada.",
    ["AutoRepair: the repair API is missing on this build."]
        = "Reparar automáticamente: falta la interfaz de reparación en esta versión del cliente.",
    ["This merchant does not repair."] = "Este mercader no repara.",
    ["Nothing to repair."] = "No hay nada que reparar.",
    ["Repair costs %s, waiting until you can afford it."]
        = "La reparación cuesta %s. Se hará en cuanto puedas pagarla.",
    ["Repaired for %s."] = "Reparado por %s.",

    -- Modules/Interruptions.lua
    ["Declines duels and releases your spirit in battlegrounds. Both off until you say so."]
        = "Rechaza duelos y libera el espíritu en los campos de batalla. Ambas cosas desactivadas hasta que las actives.",
    ["Decline duels"] = "Rechazar duelos",
    ["Say who was declined"] = "Indicar a quién se rechazó",
    ["Shows the name in your own chat, so you know whose duel request was declined."]
        = "Muestra el nombre en tu propio chat, para que sepas de quién era el duelo rechazado.",
    ["Battlegrounds"] = "Campos de batalla",
    ["Release when you die in a battleground"]
        = "Liberar el espíritu al morir en un campo de batalla",
    ["Battlegrounds only, never in the world, a dungeon or a raid. It does not release when the client offers you a resurrection of your own. This build cannot check for a soulstone, so the delay is the only safeguard."]
        = "Solo en campos de batalla, nunca en el mundo, en una mazmorra ni en una banda. No actúa cuando el cliente te ofrece una resurrección propia, pero esta versión del cliente no puede preguntar por una piedra de alma, así que una espera es la única protección para eso.",
    ["Wait before releasing"] = "Esperar antes de liberar",
    ["Time for a Druid to resurrect you or for a soulstone to do so. Zero releases immediately."]
        = "Tiempo para que te resucite un druida o una piedra de alma. Cero libera al instante.",
    ["at once"] = "al instante",
    ["%d s"] = "%d s",
    ["While Shift is down, neither of these acts."]
        = "Mientras mantienes Mayús, no actúa ninguna de las dos.",
    ["Interruptions: CancelDuel is missing on this build."]
        = "Interrupciones: falta CancelDuel en esta versión del cliente.",
    ["Declined a duel from %s."] = "Duelo de %s rechazado.",
    ["somebody"] = "alguien",
    ["Not releasing: the client is offering you a resurrection."]
        = "No se libera el espíritu: el cliente te ofrece una resurrección.",
    ["Interruptions: RepopMe is missing on this build."]
        = "Interrupciones: falta RepopMe en esta versión del cliente.",

    -- Modules/ErrorFilter.lua
    ["Error Filter"] = "Filtro de errores",
    ["Hides the red spam errors."] = "Oculta los mensajes de error rojos.",
    ["Hide every error (not quest progress)"]
        = "Ocultar todos los errores (no el progreso de misiones)",
    ["Hides every red error. Quest progress and other yellow notices stay visible."]
        = "Oculta todos los errores rojos. El progreso de las misiones y otros avisos amarillos siguen visibles.",
    ["Or Choose Them Individually"] = "O elegirlos uno a uno",
    ["These settings are ignored while every error is hidden. Turn off the switch above to choose errors individually."]
        = "Ahora se ocultan todos los errores, así que esto no se tiene en cuenta. Desactiva \"Ocultar todos los errores\" para elegirlos uno a uno.",
    ["Only used while the switch above is off."]
        = "Solo se tiene en cuenta mientras el interruptor general de arriba está desactivado.",
    ["Not enough mana / rage / energy"] = "No tienes suficiente maná / ira / energía",
    ["Hides the errors about not enough mana, rage or energy."]
        = "Oculta los errores por falta de maná, ira o energía.",
    ["Ability is not ready yet"] = "Esa habilidad todavía no está lista",
    ["Hides the errors about an ability that is not ready yet."]
        = "Oculta los errores por una habilidad que todavía no está lista.",
    ["Out of range / too far away"] = "Fuera de alcance / Estás demasiado lejos",
    ["Hides the errors about being out of range or too far away."]
        = "Oculta los errores por estar fuera de alcance o demasiado lejos.",
    ["Facing the wrong way"] = "Estás de espaldas",
    ["Hides the errors about facing the wrong way."]
        = "Oculta los errores por estar de espaldas al objetivo.",
    ["Invalid target"] = "Objetivo no válido",
    ["Hides the errors about an invalid target."] = "Oculta los errores por un objetivo no válido.",
    ["Log hidden messages to chat (for tuning)"] = "Mostrar en el chat lo ocultado (para ajustar)",
    ["Shows what was filtered, so you can tell whether something is being hidden that you wanted to see."]
        = "Muestra lo que se ha filtrado, para que veas si se oculta algo que querías ver.",
    ["ErrorFilter: this build reports no message color, so 'hide all' stays off to avoid swallowing quest progress. The individual categories still work."]
        = "Filtro de errores: esta versión del cliente no indica el color de los mensajes, así que \"ocultar todos\" sigue desactivado para no tragarse el progreso de misiones. Las categorías individuales siguen funcionando.",
    ["ErrorFilter: UIErrorsFrame has no filterable method on this build, nothing is hidden."]
        = "Filtro de errores: UIErrorsFrame no ofrece nada que filtrar en esta versión del cliente, no se oculta nada.",
    ["ErrorFilter: this build knows none of the strings for %s, that category does nothing."]
        = "Filtro de errores: esta versión del cliente no conoce ninguno de los textos de %s, esa categoría no hace nada.",
    ["ErrorFilter is on, but every category is off. Nothing is being hidden."]
        = "El filtro de errores está activado, pero todas las categorías están desactivadas: no se oculta nada.",

    -- Modules/XPBarText.lua
    ["Experience Bar Text"] = "Texto de barra de experiencia",
    ["Keeps the experience bar text visible."]
        = "Mantiene visible el texto de la barra de experiencia.",
    ["XPBarText: this build has no '%s' setting. Run /fplus discover: the experience bar's structure is saved in SavedVariables, so the fallback can be built against it."]
        = "Texto de barra de experiencia: esta versión del cliente no tiene la opción \"%s\". Ejecuta /fplus discover: la estructura de la barra de experiencia se guarda en las SavedVariables para poder crear una alternativa a partir de ella.",
    ["Experience bar text is now always visible."]
        = "El texto de la barra de experiencia ahora está siempre visible.",
    ["XPBarText: '%s' exists but could not be set."]
        = "Texto de barra de experiencia: \"%s\" existe, pero no se pudo establecer.",

    -- Modules/BagSlots.lua
    ["Free Bag Slots"] = "Casillas libres de las bolsas",
    ["Shows on the backpack how many bag slots are free. Special bags are shown separately."]
        = "Muestra en el botón de la mochila cuántas casillas de bolsa quedan libres. Las bolsas especiales se muestran aparte.",
    ["Show the total as well"] = "Mostrar también el total",
    ["Shows 14/80 instead of 14."] = "Muestra 14/80 en lugar de 14.",
    ["BagSlots: %s is missing on this build, so there is nowhere to write the count."]
        = "Casillas libres de las bolsas: falta %s en esta versión del cliente, así que no hay dónde mostrar el número.",
    ["BagSlots: C_Container does not offer the slot counts on this build."]
        = "Casillas libres de las bolsas: C_Container no ofrece el número de casillas en esta versión del cliente.",

    -- Modules/Ammunition.lua
    ["Ammunition"] = "Munición",
    ["Ammunition Warning"] = "Aviso de munición",
    ["For Hunters: shows how much ammunition you carry, on your quiver or backpack, with a short warning when it runs low."]
        = "Para cazadores: cuánta munición llevas, en el carcaj o si no en la mochila, y un breve aviso cuando se está acabando.",
    ["Hunters only"] = "Solo cazadores",
    ["Warn when it runs low"] = "Avisar cuando se esté acabando",
    ["A short red line in the upper middle of the screen, once when your ammunition drops below the amount set here. It appears again only after you restock above that amount. While this is on, the count itself turns red below the threshold."]
        = "Una breve línea roja arriba en el centro de la pantalla, una vez, cuando tu munición baja de la cantidad fijada aquí. Vuelve a aparecer solo después de que repongas por encima de esa cantidad. Mientras esto está activado, el propio número se vuelve rojo por debajo de esa cantidad.",
    ["Warn below"] = "Avisar por debajo de",
    ["The ammunition count below which the warning appears."]
        = "La cantidad de munición por debajo de la cual aparece el aviso.",
    ["Play a sound with it"] = "Reproducir también un sonido",
    ["Plays the sound selected below along with the red warning."]
        = "El sonido elegido abajo, junto con la línea roja.",
    ["Sound"] = "Sonido",
    ["Picks one of the game's own sounds."] = "Elige uno de los sonidos del propio juego.",
    ["Play the sound"] = "Reproducir el sonido",
    ["Plays the selected sound now."] = "Reproduce ahora el sonido elegido.",
    ["Show the warning"] = "Mostrar el aviso",
    ["Shows the warning once, with its sound when that is on."]
        = "Muestra el aviso una vez, con su sonido si está activado.",
    ["Ammunition: this client has no sound called %s."]
        = "Munición: este cliente no tiene ningún sonido llamado %s.",
    ["Low on ammunition: %d left"] = "Queda poca munición: %d",
    ["Adds a button for each kind of ammunition beside merchants who sell it. A click buys as many as your quiver or ammo pouch can still hold."]
        = "Junto a un mercader que venda flechas o balas, un botón para cada tipo. Un clic compra tantas como aún quepan en tu carcaj o tu bolsa de munición.",
    ["Skip the purchase dialog"] = "Omitir la confirmación de compra",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Ammunition you cannot use yet always shows the dialog."]
        = "Un clic en un botón junto al mercader compra al instante y muestra en el chat lo que se ha comprado. Con la munición que aún no puedes usar, la confirmación aparece siempre.",
    ["Fills your quiver with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Llena tu carcaj con estas automáticamente cuando abres un mercader que las vende. Solo un tipo a la vez.",
    ["Fills your ammo pouch with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Llena tu bolsa de munición con estas automáticamente cuando abres un mercader que las vende. Solo un tipo a la vez.",
    ["You cannot use these before level %d."] = "No puedes usarlas antes del nivel %d.",
    ["You cannot use these yet."] = "Aún no puedes usarlas.",
    ["Fill the Quiver"] = "Llenar el carcaj",
    ["Do not ask again"] = "No volver a preguntar",
    ["Switches on \"Skip the purchase dialog\" under Ammunition on the Gameplay page, where it can be switched off again."]
        = "Activa \"Omitir la confirmación de compra\" en Munición, en la página Experiencia de juego, donde se puede volver a desactivar.",
    ["Buy"] = "Comprar",
    ["Fill the Ammo Pouch"] = "Llenar la bolsa de munición",
    ["Do you really want to buy %d %s to fill your quiver?"]
        = "¿Seguro que quieres comprar %d %s para llenar tu carcaj?",
    ["Do you really want to buy %d %s to fill your ammo pouch?"]
        = "¿Seguro que quieres comprar %d %s para llenar tu bolsa de munición?",
    ["Cost: %s"] = "Coste: %s",
    ["No more will fit in your quiver."] = "No cabe nada más en tu carcaj.",
    ["No more will fit in your ammo pouch."] = "No cabe nada más en tu bolsa de munición.",
    ["The merchant has none left."] = "Al mercader no le quedan.",
    ["You cannot afford a stack."] = "No tienes dinero suficiente para un montón.",
    ["Buy this one in the merchant window."] = "Compra esta en la ventana del mercader.",
    ["Your quiver cannot hold bullets."] = "Tu carcaj no admite balas.",
    ["Your ammo pouch cannot hold arrows."] = "Tu bolsa de munición no admite flechas.",
    ["Waiting for the previous purchase to complete."] = "Esperando a que se complete la compra anterior.",
    ["Buying from the merchant failed: %s"] = "No se pudo comprar al mercader: %s",
    ["Reagents"] = "Componentes",
    ["Beside a merchant, a button for each reagent your class uses and, for Rogues, each poison. A click buys what is missing for the amounts set here."]
        = "Junto a un mercader, un botón para cada componente de tu clase y, para los pícaros, para cada veneno. Un clic compra lo que falta para las cantidades fijadas aquí.",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Un clic en un botón junto al mercader compra al instante y muestra en el chat lo que se ha comprado. Mientras tus habilidades de clase no necesiten componentes comprados a un mercader, la confirmación aparece siempre para los componentes.",
    ["%s is active: your class abilities need no reagents bought from a merchant."]
        = "Con %s, tus habilidades de clase no necesitan componentes comprados a un mercader.",
    ["How many you want to carry. A Shift click changes it by a full stack."]
        = "Cuántos quieres llevar. Un clic con Mayús suma o resta un montón entero.",
    ["Changes how many you want to carry, the same amount as under Reagents on the Gameplay page."]
        = "Cambia la cantidad que quieres llevar, igual que en Componentes, en la página Experiencia de juego.",
    ["Your class uses no reagents."] = "Tu clase no usa componentes.",
    ["None of your spells that require reagents have been learned yet."]
        = "Aún no has aprendido ningún hechizo que necesite un componente.",
    ["Not Relevant Right Now"] = "No relevantes por ahora",
    ["Auto Buy"] = "Compra automática",
    ["Buys what you tick for it whenever you open a merchant who sells it: reagents and poisons up to their amounts, arrows or bullets as many as fit in your quiver or ammo pouch."]
        = "Compra lo que marcas para ello cuando abres un mercader que lo vende: componentes y venenos hasta las cantidades fijadas, flechas o balas tantas como quepan en tu carcaj o tu bolsa de munición.",
    ["Skip the auto buy dialog"]
        = "Omitir la confirmación de compra automática",
    ["Buys without asking first and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Compra sin preguntar antes, y muestra en el chat lo que se ha comprado. Mientras tus habilidades de clase no necesiten componentes comprados a un mercader, la confirmación aparece siempre para los componentes.",
    ["Buy Automatically"] = "Comprar automáticamente",
    ["Buy everything ticked for buying automatically?"]
        = "¿Comprar todo lo marcado para la compra automática?",
    ["Switches on \"Skip the auto buy dialog\" under Auto Buy on the Gameplay page, where it can be switched off again."]
        = "Activa \"Omitir la confirmación de compra automática\" en Compra automática, en la página Experiencia de juego, donde se puede volver a desactivar.",
    ["Buys it automatically up to this amount whenever you open a merchant who sells it."]
        = "Lo compra automáticamente hasta esta cantidad cuando abres un mercader que lo vende.",
    ["You have %d of %d."] = "Tienes %d de %d.",
    ["Click to buy %d."] = "Haz clic para comprar %d.",
    ["Click to buy the ingredients for %d."] = "Haz clic para comprar los ingredientes para %d.",
    ["You have enough."] = "Ya tienes suficientes.",
    ["Just bought."] = "Recién comprado.",
    ["You cannot afford the ingredients."] = "No tienes dinero suficiente para los ingredientes.",
    ["Buy the ingredients in the merchant window."]
        = "Compra los ingredientes en la ventana del mercader.",
    ["Buy Reagents"] = "Comprar componentes",
    ["Do you really want to buy %d %s? You will then have %d."]
        = "¿Seguro que quieres comprar %d %s? Después tendrás %d.",
    ["Buy Poison Ingredients"] = "Comprar ingredientes de veneno",
    ["Do you really want to buy the ingredients for %d %s?"]
        = "¿Seguro que quieres comprar los ingredientes para %d %s?",
    ["Switches on \"Skip the purchase dialog\" under Reagents on the Gameplay page, where it can be switched off again."]
        = "Activa \"Omitir la confirmación de compra\" en Componentes, en la página Experiencia de juego, donde se puede volver a desactivar.",
    ["Bought %d %s for %s."] = "Has comprado %d %s por %s.",
    ["Bought the ingredients for %d %s for %s."]
        = "Has comprado los ingredientes para %d %s por %s.",
    ["Click to buy %d and fill your quiver."] = "Haz clic para comprar %d y llenar tu carcaj.",
    ["Click to buy %d and fill your ammo pouch."]
        = "Haz clic para comprar %d y llenar tu bolsa de munición.",
    ["Bought %d %s for %s to fill your quiver."]
        = "Has comprado %d %s por %s para llenar tu carcaj.",
    ["Bought %d %s for %s to fill your ammo pouch."]
        = "Has comprado %d %s por %s para llenar tu bolsa de munición.",

    -- Modules/BagWindow.lua
    ["Movable Bag Windows"] = "Ventanas de bolsas movibles",
    ["Hold Shift and drag the bag window by its title bar to move it, while your bags are combined into one window."]
        = "Mantén Mayús y arrastra la ventana de bolsas por su barra de título para moverla, mientras tus bolsas estén combinadas en una sola ventana.",
    ["Reset position"] = "Restablecer posición",
    ["Puts the bag window back where the game places it."]
        = "Devuelve la ventana a su posición predeterminada.",
    ["Bag window is back where the game places it."]
        = "La ventana de bolsas vuelve a estar en su posición predeterminada.",
    ["BagWindow: this build has no combined bag window, so there is nothing to move."]
        = "Ventanas de bolsas movibles: esta versión del cliente no tiene ventana de bolsas combinada, así que no hay nada que mover.",

    -- Modules/MinimapButton.lua
    ["Minimap Button"] = "Botón del minimapa",
    ["A button on the edge of the minimap that opens this window. Drag it to move it along the edge."]
        = "Un botón en el borde del minimapa que abre esta ventana. Arrástralo para moverlo a lo largo del borde.",
    ["MinimapButton: this build has no minimap to put a button on. /fplus opens the settings."]
        = "Botón del minimapa: esta versión del cliente no tiene minimapa donde poner un botón. /fplus abre la configuración.",
    ["Click to open or close the settings."] = "Haz clic para abrir o cerrar la configuración.",
    ["Drag to move this button along the edge of the minimap."]
        = "Arrastra para mover este botón a lo largo del borde del minimapa.",

    -- Modules/MailAlts.lua
    ["Alts in the Mail Window"] = "Tus personajes en la ventana de correo",
    ["Adds a button to the mail window that lists your characters of this ruleset and faction, and fills in the one you pick."]
        = "Añade a la ventana de correo un botón que muestra tus personajes de este conjunto de reglas y facción, y escribe el que elijas.",
    ["No other character of this ruleset and faction is known yet. Each one is added the next time it logs in."]
        = "Aún no se conoce ningún otro personaje de este conjunto de reglas y facción. Cada uno se añade la próxima vez que se conecta.",
    ["Your Characters"] = "Tus personajes",
    ["Your characters of this ruleset and faction. A click fills in the name, the X at the end of a row deletes the character."]
        = "Tus personajes de este conjunto de reglas y facción. Un clic escribe el nombre; la X al final de una fila borra el personaje.",

    -- Modules/QuestZoneTracking.lua
    ["Track Zones in the Quest Log"] = "Seguir zonas en el registro de misiones",
    ["Adds a checkbox to every zone in the quest log to track or untrack all its quests with one click."]
        = "Añade a cada zona del registro de misiones una casilla que sigue todas sus misiones con un clic, o deja de seguirlas.",
    ["Track All"] = "Seguir todas",
    ["Untrack All"] = "Dejar de seguir todas",
    ["QuestZoneTracking: could not hook QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Seguir zonas en el registro de misiones: no se pudo enganchar QuestLogQuests_Update, así que el registro de misiones no tendrá casillas.",
    ["QuestZoneTracking: this client has no QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Seguir zonas en el registro de misiones: este cliente no tiene QuestLogQuests_Update, así que el registro de misiones no tendrá casillas.",

    -- Modules/Diagnostics.lua
    ["Diagnostics"] = "Diagnóstico",
    ["Measures what this client's API offers. Use it to diagnose problems: the report lists what exists and what does not, for whoever fixes the addon."]
        = "Mide lo que ofrece la API de este cliente. Sirve para diagnosticar problemas: el informe es una lista de lo que existe y lo que no, para quien arregla el addon.",
    ["Keep the report in the saved settings"] = "Conservar el informe en la configuración guardada",
    ["Saves the report, about nine hundred lines, in your saved settings. /fplus diag print reads the current one without saving it."]
        = "Guarda el informe, unas novecientas líneas, en la configuración guardada. /fplus diag print lee el actual sin guardarlo.",

    -- -----------------------------------------------------------------------
    -- Design
    -- -----------------------------------------------------------------------

    -- Modules/Theme.lua
    ["Sets the appearance of the ForeverPlus windows."] = "El aspecto de las ventanas de ForeverPlus.",
    ["Color scheme"] = "Esquema de colores",
    ["Applies to the ForeverPlus windows only."] = "Solo se aplica a las ventanas de ForeverPlus.",
    ["Show switches in your class color"] = "Mostrar los interruptores en el color de tu clase",
    ["The switches that are on and the open tab take the color of this character's class, in every color scheme."]
        = "Los interruptores activados y la pestaña abierta toman el color de la clase de este personaje, en todos los esquemas de colores.",
    ["Background opacity"] = "Opacidad del fondo",
    ["Sets the background opacity of the ForeverPlus windows, the info bar and the addon's tooltips. At 100 percent, it matches the color scheme."]
        = "El fondo de las ventanas de ForeverPlus, de la barra de información y de las descripciones propias del addon. Al 100 por ciento, se usa el del esquema de colores.",
    ["Text size"] = "Tamaño del texto",
    ["Sets the text size as a percentage of the game's text size."]
        = "Un porcentaje del tamaño de texto del propio juego.",

    -- Core/Theme.lua
    ["Midnight"] = "Medianoche",
    ["Slate"] = "Pizarra",
    ["High contrast"] = "Alto contraste",
    ["Horde"] = "Horda",
    ["Gilded"] = "Dorado",
    ["Autumn"] = "Otoño",
    ["Jade"] = "Jade",
    ["Arctic"] = "Ártico",
    ["Azure"] = "Azur",
    ["Alliance"] = "Alianza",
    ["Sunset"] = "Atardecer",

    -- -----------------------------------------------------------------------
    -- Profiles
    -- -----------------------------------------------------------------------

    -- Modules/Profiles.lua
    ["in use"] = "en uso",
    ["The buttons below act on: |cffffffff%s|r"]
        = "Los botones de abajo actúan sobre: |cffffffff%s|r",
    ["... and %d more, see /fplus profile"] = "... y %d más, consulta /fplus profile",
    ["Use"] = "Usar",
    ["Now using %s."] = "Ahora se usa %s.",
    ["Reset"] = "Restablecer",
    ["Sure?"] = "¿Seguro?",
    ["%s is back to its defaults."] = "%s vuelve a los valores predeterminados.",
    ["%s deleted."] = "Se ha borrado %s.",
    ["Name for a new or renamed profile"] = "Nombre para un perfil nuevo o renombrado",
    ["New"] = "Nuevo",
    ["Created %s."] = "Se ha creado %s.",
    ["Copy"] = "Copiar",
    ["%s copied from %s."] = "Se ha creado %s como copia de %s.",
    ["Rename"] = "Renombrar",
    ["%s is now %s."] = "%s ahora se llama %s.",
    ["Export"] = "Exportar",
    ["Export profile"] = "Exportar perfil",
    ["%s, %d characters"] = "%s, %d caracteres",
    ["Import"] = "Importar",
    ["Import profile"] = "Importar perfil",
    ["Paste a string, then press Import"] = "Pega un texto y luego haz clic en Importar",
    ["Import failed: %s"] = "No se pudo importar: %s",
    ["Imported as %s, %d skipped."] = "Importado como %s. Omitidos: %d.",
    ["Imported as %s."] = "Importado como %s.",
    ["%d profile now."] = "Ahora hay %d perfil.",
    ["%d profiles now."] = "Ahora hay %d perfiles.",

    -- Core/Config.lua
    ["Settings were written by a newer version (format %d, this build reads %d). Leaving them unchanged."]
        = "La configuración la escribió una versión más reciente (formato %d, esta versión lee %d). Se deja tal como está.",
    ["No way to convert settings from format %d to %d."]
        = "No hay forma de llevar la configuración del formato %d al %d.",
    ["migration %d to %d"] = "migración de %d a %d",
    ["Settings stayed at format %d."] = "La configuración se queda en el formato %d.",
    ["Settings converted to format %d."] = "Configuración convertida al formato %d.",
    ["No character given"] = "No se ha indicado ningún personaje",
    ["That is the character you are playing"] = "Es el personaje con el que estás jugando",
    ["Could not identify this character, so %s is in use. A /reload should fix it."]
        = "No se pudo identificar este personaje, así que se usa %s. Un /reload debería arreglarlo.",
    ["%s is off. Takes effect after /reload."] = "%s: desactivado. Surte efecto tras un /reload.",
    ["Unknown module: %s"] = "Módulo desconocido: %s",
    ["%s: /reload needed for the change to take effect."]
        = "%s: hace falta un /reload para que el cambio surta efecto.",
    ["A profile needs a name"] = "Un perfil necesita un nombre",
    ["Profile names are limited to %d characters"]
        = "Los nombres de perfil tienen como máximo %d caracteres",
    ["A profile name cannot contain a pipe or a control character"]
        = "Un nombre de perfil no puede contener una barra vertical ni un carácter de control",
    ["A profile called %s already exists"] = "Ya existe un perfil llamado %s",
    ["No profile called %s exists"] = "No existe ningún perfil llamado %s",
    ["%s is the only profile. Reset it instead of deleting it"]
        = "%s es el único perfil que hay: restablécelo en lugar de borrarlo",
    ["Profile %s takes effect when you leave combat."]
        = "El perfil %s surtirá efecto cuando salgas de combate.",
    ["Profile %s disappeared before it could be applied."]
        = "El perfil %s desapareció antes de poder aplicarse.",
    ["%s: /reload needed before its new settings apply."]
        = "%s: hace falta un /reload para que se aplique su nueva configuración.",
    ["Profile: %s"] = "Perfil: %s",
    ["that string is not a ForeverPlus profile"] = "ese texto no es un perfil de ForeverPlus",
    ["that profile has no readable settings in it"]
        = "ese perfil no contiene ninguna configuración legible",
    ["import migration %d to %d"] = "migración al importar de %d a %d",
    ["the settings being saved are not the ones in this table. The import was undone to prevent silent data loss. Please report this"]
        = "la tabla de configuración no es la que se guarda: la importación se ha deshecho para evitar una pérdida de datos inadvertida. Por favor, comunícalo",
    ["the profile was not saved successfully. Please report this"]
        = "no se ha podido guardar el perfil correctamente. Por favor, comunícalo",

    -- Core/Serialize.lua
    ["nested too deeply"] = "anidado a demasiada profundidad",
    ["the string ends before a value is complete"] = "el texto termina en medio de un valor",
    ["a string is missing its length"] = "falta la indicación de longitud de un texto",
    ["a string has an invalid length"] = "un texto tiene una longitud no válida",
    ["a string extends beyond the end of the data"] = "un texto se extiende más allá del final de los datos",
    ["a number has no terminating marker"] = "a un número le falta el marcador de fin",
    ["a number is not a number"] = "un número no es un número",
    ["a boolean is neither true nor false"] = "un booleano no es ni verdadero ni falso",
    ["a table is missing its size"] = "falta la indicación del tamaño de una tabla",
    ["a table has an invalid size"] = "una tabla tiene un tamaño no válido",
    ["a table specifies more entries than the string contains"]
        = "una tabla indica más entradas de las que contiene el texto",
    ["unknown marker at position %d"] = "marca desconocida en la posición %d",
    ["nothing to import"] = "no hay nada que importar",
    ["this does not look like a ForeverPlus string"] = "esto no parece un texto de ForeverPlus",
    ["this string is version %s, but this build reads %s"] = "este texto es de la versión %s, y este addon lee la %s",
    ["the string is damaged or incomplete (%d characters received). If you pasted it, it may have been truncated. Paste it again and check that the end matches"]
        = "el texto está dañado o incompleto (han llegado %d caracteres). Si se pegó, puede que se haya cortado: vuelve a pegarlo y comprueba que el final coincide",
    ["unexpected text after the end of the data"]
        = "hay texto inesperado después del final de los datos",

    -- -----------------------------------------------------------------------
    -- Info
    -- -----------------------------------------------------------------------

    -- Modules/Info.lua
    ["All rights reserved"] = "Todos los derechos reservados",
    ["About"] = "Acerca de",
    ["Author"] = "Autor",
    ["License"] = "Licencia",
    ["Client"] = "Cliente",
    ["Contact"] = "Contacto",
    ["Leave ideas and bug reports in the comments on CurseForge"]
        = "Deja ideas e informes de errores en los comentarios de CurseForge",
    ["Free to use, but not open source. You may not redistribute it, publish modified versions or reuse it in other addons. Provided without warranty. See the LICENSE file for the full terms."]
        = "De uso libre, pero no de código abierto: no se puede redistribuir, modificar y publicar, ni reutilizar en otros addons. Se ofrece sin garantía. Las condiciones completas están en el archivo LICENSE.",

    -- -----------------------------------------------------------------------
    -- Info bar
    -- -----------------------------------------------------------------------

    -- Modules/InfoBar.lua
    ["Shows an info bar with your gold, durability, coordinates, latency and more."]
        = "Muestra una barra de información con tu oro, la durabilidad, las coordenadas, la latencia y más.",
    ["What It Shows"] = "Qué muestra",
    ["Allow reordering"] = "Permitir reordenar",
    ["Drag the entries above to change their order on the info bar."]
        = "Arrastra las entradas de arriba para cambiar su orden en la barra de información.",
    ["Restore default order"] = "Restablecer el orden",
    ["Puts the entries back in their default order, here and on the info bar."]
        = "Devuelve las entradas a su orden predeterminado, aquí y en la barra de información.",
    ["Time"] = "Hora",
    ["The time of day, as the game's own clock shows it."]
        = "La hora, tal como la muestra el reloj del juego.",
    ["Shows"] = "Muestra",
    ["Local time"] = "Hora local",
    ["Realm time"] = "Hora del reino",
    ["Choose local or realm time for both this bar and the minimap clock."]
        = "Elige la hora local o la del reino para esta barra y el reloj del minimapa.",
    ["Choose a 12 or 24 hour format for both this bar and the minimap clock."]
        = "Elige el formato de 12 o 24 horas para esta barra y el reloj del minimapa.",
    ["Format"] = "Formato",
    ["24 hours"] = "24 horas",
    ["12 hours"] = "12 horas",
    ["Hearthstone"] = "Piedra de hogar",
    ["Where your Hearthstone takes you and how long until it is ready."]
        = "Adónde te lleva tu piedra de hogar y cuánto falta para que esté lista.",
    ["Gold"] = "Oro",
    ["Adds up each selected character's gold as of their last login."]
        = "Suma el oro de los personajes elegidos abajo, tal como estaba la última vez que se conectó cada uno.",
    ["Characters"] = "Personajes",
    ["Whose gold the display adds up. Its list shows every character, the ones not counted grayed out. A ruleset is, for example, Normal or PvP."]
        = "De qué personajes se suma el oro mostrado. La lista muestra todos los personajes; los que no se incluyen en el total aparecen en gris. Normal y JcJ son ejemplos de conjuntos de reglas.",
    ["All"] = "Todos",
    ["This ruleset and faction"] = "Este conjunto de reglas y esta facción",
    ["Only this one"] = "Solo este",
    ["This ruleset"] = "Este conjunto de reglas",
    ["Hide characters not counted"] = "Ocultar los personajes que no suma",
    ["PvE"] = "JcE",
    ["PvP"] = "JcJ",
    ["The list on hover leaves out the characters the display does not count."]
        = "La lista al pasar el ratón omite los personajes que el dato no suma.",
    ["Shown as"] = "Mostrar como",
    ["Shows one display for all bags, with a breakdown by bag type on hover, or one display per bag type, with its name on hover."]
        = "Un dato para todas las bolsas, desglosado por tipo al pasar el ratón, o un dato por tipo de bolsa, con su nombre al pasar el ratón.",
    ["One display"] = "Un dato",
    ["A display per kind of bag"] = "Un dato por tipo de bolsa",
    ["Ordinary bags"] = "Bolsas normales",
    ["Special bag"] = "Bolsa especial",
    ["Merchant's Favor"] = "Favor de mercader",
    ["How much Merchant's Favor this character has. Red once it holds as much as the game allows."]
        = "Cuánto Favor de mercader tiene este personaje. En rojo en cuanto tiene el máximo que permite el juego.",
    ["Honor Points"] = "Puntos de honor",
    ["How many Honor Points this character has. Red once it holds as much as the game allows."]
        = "Cuántos puntos de honor tiene este personaje. En rojo en cuanto tiene el máximo que permite el juego.",
    ["Volume"] = "Volumen",
    ["Shows the game's master volume. Hover over the display to adjust it with a slider. The speaker is crossed out while sound is disabled or the volume is at 0%, and the figure turns red while sound is disabled."]
        = "El volumen general del juego. Pasa el ratón por encima para cambiarlo con un control deslizante. El altavoz aparece tachado mientras todo el sonido está desactivado o el volumen está al 0%. La cifra se vuelve roja mientras todo el sonido está desactivado.",
    ["Master Volume"] = "Volumen general",
    ["Cooldowns"] = "Tiempos de reutilización",
    ["Shows the profession cooldowns and %s for all your characters. Hover over the icon to see the time remaining."]
        = "Muestra los tiempos de reutilización de las habilidades de profesión y de %s de todos tus personajes. Pasa el ratón por el icono para ver cuánto falta.",
    ["Ready"] = "Listo",
    ["%d d %d h"] = "%d d %d h",
    ["%d h %d min"] = "%d h %d min",
    ["None of your characters has one yet."] = "Ninguno de tus personajes tiene uno todavía.",
    ["Elemental Transmutes"] = "Transmutaciones elementales",
    ["Durability"] = "Durabilidad",
    ["Shows the lowest durability among your equipped items."]
        = "El peor estado de las piezas que llevas puestas.",
    ["Coordinates"] = "Coordenadas",
    ["Where you are in the current zone."] = "Dónde estás en la zona actual.",
    ["Zone"] = "Zona",
    ["Shows your current zone and subzone in the minimap's colors."]
        = "La zona en la que estás y el lugar dentro de ella, con los colores del minimapa.",
    ["%s: %s"] = "%s: %s",
    ["Latency"] = "Latencia",
    ["Frames per second"] = "Imágenes por segundo",
    ["Placement"] = "Ubicación",
    ["Position on screen"] = "Posición en la pantalla",
    ["Back to the default near the top of the screen."]
        = "Vuelve a la posición predeterminada, cerca de la parte superior de la pantalla.",
    ["%d ms"] = "%d ms",
    ["%d fps"] = "%d fps",
    ["No Hearthstone"] = "Sin piedra de hogar",
    ["%sk xp/h"] = "%sk PE/h",
    ["%d xp/h"] = "%d PE/h",
    ["%s h to level"] = "%s h para subir de nivel",
    ["%d min to level"] = "%d min para subir de nivel",
    ["Info bar: this client build does not recognize currency %d, so %s stays empty."]
        = "Barra de información: esta versión del cliente no conoce la moneda %d, así que %s se queda sin datos.",
    ["Maximum"] = "Máximo",
    ["This session"] = "Esta sesión",
    ["Repair cost"] = "Coste de la reparación",
    ["Experience per hour"] = "Experiencia por hora",
    ["Time to the next level"] = "Tiempo hasta el siguiente nivel",
    ["Info bar is back at its default position."]
        = "La barra de información vuelve a estar en su posición predeterminada.",
    ["Info bar can be dragged. Press the button again when it is where you want it."]
        = "Ya puedes arrastrar la barra de información. Vuelve a hacer clic en el botón cuando esté donde quieres.",
    ["Info bar is fixed again."] = "La barra de información vuelve a estar fija.",
    ["Click to use it"] = "Haz clic para usarla",
    ["Info bar: this client build cannot provide %s, so those entries stay empty regardless of their settings."]
        = "Barra de información: esta versión del cliente no puede proporcionar %s. Esas entradas se quedan vacías, se configuren como se configuren.",
    ["Use it with a click"] = "Usarla con un clic",
    ["A click on the display uses your Hearthstone."]
        = "Un clic en el dato usa tu piedra de hogar.",
    ["Move it with Shift and drag"] = "Mover con Mayús y arrastrar",
    ["While Shift is held, you can drag the bar by any display, and clicking the Hearthstone does not use it."]
        = "Mientras mantienes Mayús, la barra se puede arrastrar por cualquiera de sus datos. Un clic en la piedra de hogar de la barra no la activa.",

    -- -----------------------------------------------------------------------
    -- Tooltip
    -- -----------------------------------------------------------------------

    -- Modules/Tooltip.lua
    ["Extra lines in the game tooltip, and where the tooltip appears."]
        = "Líneas adicionales en la descripción del juego y la esquina en la que aparece.",
    ["General"] = "General",
    ["Add extra information"] = "Añadir información adicional",
    ["The lines this addon adds. The arrangement and the position still work while this is off."]
        = "Las líneas que escribe el propio addon. Si se desactiva, la disposición y la posición siguen funcionando.",
    ["Not in use until you switch extra information on."]
        = "No se usa hasta activar la información adicional.",
    ["Layout"] = "Disposición",
    ["How the lines are arranged"] = "Cómo se ordenan las líneas",
    ["Blizzlike"] = "Blizzlike",
    ["One per line"] = "Una por línea",
    ["Compact"] = "Compacta",
    ["Blizzlike keeps the client's lines in their original order and adds the rest underneath. One per line gives every entry its own line. Compact pairs entries up."]
        = "Blizzlike mantiene las líneas del cliente en su orden y añade el resto debajo. Una por línea da a cada dato una línea propia. Compacta los agrupa de dos en dos.",
    ["Where it appears"] = "Dónde aparece",
    ["Default"] = "Predeterminado",
    ["Top left"] = "Arriba a la izquierda",
    ["Top right"] = "Arriba a la derecha",
    ["Bottom left"] = "Abajo a la izquierda",
    ["Default leaves the tooltip where the client puts it. The other options pin it to the chosen corner, and it grows inward."]
        = "Predeterminado deja la descripción donde la pone el cliente. Las otras tres opciones la fijan en esa esquina, y crece hacia dentro.",
    ["Lines on a Unit"] = "Líneas en unidades",
    ["Level"] = "Nivel",
    ["Shows a player's or creature's level. Under Blizzlike, it covers the whole line the client writes, including race."]
        = "Su nivel. Con Blizzlike abarca toda la línea que escribe el cliente, raza incluida.",
    ["Class"] = "Clase",
    ["Shows a player's class."] = "La clase de un jugador.",
    ["Race"] = "Raza",
    ["Shows a player's race or a creature's type."]
        = "La raza de un jugador o el tipo de criatura.",
    ["Blizzlike includes race on the level line, so the Level switch controls both."]
        = "Blizzlike escribe la raza en la línea del nivel, así que el interruptor de Nivel abarca ambas.",
    ["Faction"] = "Facción",
    ["Which side they are on."] = "De qué bando son.",
    ["Guild"] = "Hermandad",
    ["The guild a player belongs to."] = "La hermandad a la que pertenece un jugador.",
    ["Guild rank"] = "Rango de hermandad",
    ["The rank they hold there."] = "El rango que tiene en ella.",
    ["Target"] = "Objetivo",
    ["Shows who they have targeted, or \"you\" if it is you."]
        = "A quién tiene seleccionado. Muestra \"tú\" cuando eres tú.",
    ["Class color on the name"] = "Color de clase en el nombre",
    ["Colors a player's name by their class."] = "Colorea el nombre de un jugador según su clase.",
    ["Lines on an Item or Spell"] = "Líneas en objetos y hechizos",
    ["What it sells for"] = "Precio de venta",
    ["Shows what a vendor pays for the item and the value of the whole stack."]
        = "Lo que paga un vendedor y lo que vale el montón entero.",
    ["Item and spell ids"] = "ID de objetos y hechizos",
    ["Shows the IDs of an item, spell or creature."]
        = "Los números que identifican un objeto, un hechizo o una criatura.",
    ["Lines on Herbs, Veins and Corpses"] = "Líneas en hierbas, filones y cadáveres",
    ["Skill needed to gather"] = "Habilidad necesaria para recolectar",
    ["Shows the Herbalism, Mining or Skinning skill required for herbs, veins and corpses, in the color the game uses for your skill level."]
        = "El nivel de Herboristería, Minería o Desuello que pide una hierba, un filón o un cadáver, en el color que el juego da a tu habilidad en ello.",
    ["Sells for (%d)"] = "Precio de venta (%d)",
    ["Sells for"] = "Precio de venta",
    ["Item"] = "Objeto",
    ["Spell"] = "Hechizo",
    ["Requires %s"] = "Requiere %s",
    ["you"] = "tú",
    ["Tooltip: TooltipDataProcessor is unavailable in this client build, so no lines can be added. Placement still works."]
        = "Descripciones: falta TooltipDataProcessor, así que en esta versión del cliente no se pueden añadir líneas. La ubicación sigue funcionando.",
    ["Tooltip: GameTooltip_SetDefaultAnchor is unavailable in this client build, so the corner setting has no effect."]
        = "Descripciones: falta GameTooltip_SetDefaultAnchor, así que la opción de la esquina no hace nada en esta versión del cliente.",

    -- Data/Gathering.lua
    ["Herbalism"] = "Herboristería",
    ["Mining"] = "Minería",
    ["Skinning"] = "Desuello",

    -- -----------------------------------------------------------------------
    -- Consumables
    -- -----------------------------------------------------------------------

    -- Modules/Consumables.lua
    ["Warns when a selected consumable effect is missing or about to expire."]
        = "Avisa cuando falta el efecto de un consumible seleccionado o está a punto de terminar.",
    ["Main Hand"] = "Mano principal",
    ["Off Hand"] = "Mano secundaria",
    ["%d min"] = "%d min",
    ["%d:%02d min"] = "%d:%02d min",
    ["Show the remaining time"] = "Mostrar el tiempo restante",
    ["Icon size"] = "Tamaño de los iconos",
    ["Conditions"] = "Condiciones",
    ["Warn at"] = "Avisar con",
    ["The remaining time at which a consumable warning appears."]
        = "Tiempo restante a partir del cual aparece el aviso de consumibles.",
    ["Measurement"] = "Medición",
    ["Print what was recorded"] = "Mostrar lo registrado",
    ["Prints everything the probe recorded during this session in chat. The data is also saved and restored after a reload."]
        = "Todo lo que la sonda ha visto en esta sesión, como líneas de chat. También está en el archivo guardado, de donde se lee tras reiniciar la IU.",
    ["Consumables: C_Timer.NewTicker is missing, so the countdown only updates when something changes."]
        = "Consumibles: falta C_Timer.NewTicker, así que la cuenta atrás solo se actualiza cuando algo cambia.",
    ["Weapon Coatings"] = "Piedras y aceites",

    -- Data/Consumables.lua
    ["Weapon Oil"] = "Aceite para armas",
    ["Sharpening Stone"] = "Piedra de afilar",
    ["Weightstone"] = "Piedrafuerte",
    ["Food"] = "Comida",
    ["Any Food Buff"] = "Cualquier beneficio de comida",
    ["Watches for a food buff, whichever food it came from: warns when none is on you, and before the one you have runs out."]
        = "Vigila un beneficio de comida, venga de la comida que venga: avisa cuando no tienes ninguno y antes de que se acabe el que tienes.",
    ["Strength"] = "Fuerza",
    ["Agility"] = "Agilidad",
    ["Armor"] = "Armadura",
    ["Stamina"] = "Aguante",
    ["Health Regeneration"] = "Regeneración de salud",
    ["Mana Regeneration"] = "Regeneración de maná",
    ["Spell Power"] = "Poder con hechizos",
    ["Fire Power"] = "Poder de fuego",
    ["Frost Power"] = "Poder de escarcha",
    ["Shadow Power"] = "Poder de las Sombras",
    ["Resistance"] = "Resistencia",
    ["Blasted Lands and Zandalar"] = "Las Tierras Devastadas y Zandalar",
    ["Attack Power"] = "Poder de ataque",
    ["Juju"] = "Juju",
    ["Hit Chance"] = "Probabilidad de golpe",
    ["Alcohol"] = "Alcohol",
    ["Other"] = "Otros",
    ["Flask"] = "Frasco",
    ["Intellect"] = "Intelecto",
    ["Spirit"] = "Espíritu",

    -- Core/Warnings.lua
    ["Gray"] = "Gris",
    ["Original colors"] = "Colores originales",
    ["Dimmed"] = "Atenuado",
    ["Alert red"] = "Rojo de alerta",
    ["Scheme color"] = "Color del esquema",
    ["new"] = "nuevo",

    -- Modules/Consumables.lua, names for an item or spell the client cannot name
    ["Item %s"] = "Objeto %s",
    ["Spell %s"] = "Hechizo %s",

    -- Modules/Consumables.lua, a row whose item is not loaded
    ["Item %s, not loaded yet"] = "Objeto %s, aún no cargado",
    ["Nothing to look up"] = "Nada que consultar",

    -- -----------------------------------------------------------------------
    -- Buffs
    -- -----------------------------------------------------------------------

    -- Modules/BuffExpiry.lua
    ["Warns when a long buff is running out."]
        = "Avisa cuando un beneficio largo se está acabando.",
    ["Your own buffs"] = "Tus propios beneficios",
    ["Armor spells, shouts, Inner Fire: anything you cast on yourself that runs out."]
        = "Hechizos de armadura, gritos, Fuego interno: todo lo que lanzas sobre ti y que se agota.",
    ["Group buffs"] = "Beneficios de grupo",
    ["Buffs you also put on other people. The icon shows how many nearby players are missing the buff, except in combat."]
        = "Beneficios que también pones a otros. El icono indica a cuántos cerca de ti les falta, salvo en combate.",
    ["Weapon imbues and poisons"] = "Encantamientos de arma y venenos",
    ["Warnings about the imbues, poisons, Firestones and Spellstones on your weapons."]
        = "Avisos sobre los encantamientos, venenos, pirorrocas y piedras de hechizos de tus armas.",
    ["Tracking"] = "Rastreo",
    ["Shows an icon whenever none of the tracking abilities you selected in the Tracking section is active. Either gathering tracking ability is enough."]
        = "Un icono siempre que no esté activo ninguno de los rastreos que elegiste en la sección Rastreo. Basta con cualquiera de los dos rastreos de recolección.",
    ["Warn short buffs at"] = "Beneficios cortos: avisar con",
    ["Applies to every buff lasting under 10 minutes."]
        = "Se aplica a todos los beneficios que duran menos de 10 minutos.",
    ["Warn medium buffs at"] = "Beneficios medios: avisar con",
    ["Applies to every buff lasting 10 to 29 minutes."]
        = "Se aplica a todos los beneficios que duran de 10 a 29 minutos.",
    ["Warn long buffs at"] = "Beneficios largos: avisar con",
    ["Applies to every buff lasting 30 minutes or more."]
        = "Se aplica a todos los beneficios que duran 30 minutos o más.",
    ["Warn while mounted"] = "Avisar mientras vas montado",
    ["Off: no warnings while you are mounted."]
        = "Si se desactiva, no hay avisos mientras vas montado.",
    ["Warn in a rested area"] = "Avisar en ciudades y posadas",
    ["Off: no warnings in cities and inns."]
        = "Si se desactiva, no hay avisos en ciudades y posadas.",
    ["Buffs from others in dungeons"] = "Beneficios de otros en mazmorras",
    ["Warnings about a buff another class in your group could give you, while you are in a dungeon."]
        = "Avisos sobre un beneficio que otra clase de tu grupo podría darte, mientras estás en una mazmorra.",
    ["Buffs from others in raids"] = "Beneficios de otros en bandas",
    ["Warnings about a buff another class in your group could give you, while you are in a raid."]
        = "Avisos sobre un beneficio que otra clase de tu grupo podría darte, mientras estás en una banda.",
    ["Buffs from others in the open world"] = "Beneficios de otros en el mundo abierto",
    ["Warnings about a buff another class in your group could give you, anywhere outside a dungeon, a raid or a battleground."]
        = "Avisos sobre un beneficio que otra clase de tu grupo podría darte, en cualquier lugar fuera de mazmorras, bandas y campos de batalla.",
    ["Count group members within"] = "Contar miembros del grupo a menos de",
    ["%d yd"] = "%d m",
    ["Group members farther away are not counted for buffs they could give you or buffs you could give them."]
        = "Los miembros del grupo que estén más lejos no cuentan ni para los beneficios que podrían darte ni para los que tú podrías darles.",
    ["General Warnings"] = "Avisos generales",
    ["Combat Buffs"] = "Beneficios de combate",
    ["Buffs on You Right Now"] = "Beneficios que tienes ahora",
    ["During combat, the client cannot check whether %s is active on you. The addon can only track it from your own casts. If another player casts it on you, it may be reported as missing until combat ends. This message is shown once per character."]
        = "En combate, el cliente no puede comprobar si %s está activo en ti. El addon solo puede seguir este beneficio a partir de tus propios lanzamientos. Si otro jugador te lo lanza, puede aparecer como ausente hasta que termine el combate. Este mensaje se muestra una vez por personaje.",
    ["BuffExpiry: C_Timer.NewTicker is missing, so the countdown only updates when a buff changes."]
        = "Beneficios: falta C_Timer.NewTicker, así que la cuenta atrás solo se actualiza cuando cambia un beneficio.",
    ["missing"] = "falta",
    ["upgrade"] = "rango superior",
    ["showing"] = "mostrado",
    ["handout"] = "para otros",
    ["waiting"] = "en espera",
    ["unavailable"] = "no disponible",
    ["off"] = "desactivado",
    ["%s of %s"] = "%s de %s",
    ["... and %d more"] = "... y %d más",
    ["In combat, these are the remaining times recorded just before the fight, continuing to count down. Buffs cast on you by other players appear after combat ends."]
        = "En combate se muestran los tiempos de justo antes de empezar, con su cuenta atrás exacta. Un beneficio que te lance otro jugador aparece al terminar el combate.",
    ["No timed buffs on you."] = "No tienes beneficios con duración.",
    ["(timer only)"] = "(solo temporizador)",
    ["(own class only)"] = "(solo tu clase)",
    ["(not trained)"] = "(no aprendido)",
    ["(not your race)"] = "(no es tu raza)",
    ["Class Buffs"] = "Beneficios de clase",
    ["(you)"] = "(tú)",
    ["Track on yourself"] = "Vigilar en ti",
    ["Also tracks this buff on you."] = "Vigila este beneficio también en ti.",
    ["Track on friendly targets"] = "Vigilar en objetivos amistosos",
    ["%d player"] = "%d jugador",
    ["%d players"] = "%d jugadores",
    ["How many other players must have this buff active, not counting you. Outside combat, the icon shows how many are still missing it."]
        = "En cuántos otros jugadores debe mantenerse, sin contarte a ti. Fuera de combate, el icono muestra a cuántos les falta todavía.",
    ["Track on every group or raid member"] = "Vigilar en todos los miembros del grupo o la banda",
    ["Shows an icon whenever your pet is not happy, with a red border when it becomes unhappy. The icon is hidden during combat."]
        = "Un icono mientras tu mascota no está feliz, con borde rojo en cuanto está descontenta. No en combate.",
    ["Tracks this buff on every member of your group or raid instead of using the number above. Outside combat, the icon shows how many are still missing it."]
        = "Lo vigila en todos los miembros de tu grupo o banda en lugar del número de arriba. Fuera de combate, el icono muestra a cuántos les falta todavía.",
    ["Only warn in combat"] = "Avisar solo en combate",
    ["Warns about this buff only during a fight."]
        = "Avisa de este beneficio solo durante un combate.",

    -- Data/Buffs.lua, a name for when the client gives none
    ["Mark of the Wild"] = "Marca de lo salvaje",
    ["Thorns"] = "Espinas",
    ["Aspect of the Wild"] = "Aspecto salvaje",
    ["Trueshot Aura"] = "Aura de disparo certero",
    ["Aspect"] = "Aspecto",
    ["Arcane Intellect"] = "Intelecto Arcano",
    ["Armor Spell"] = "Hechizo de armadura",
    ["Blessing"] = "Bendición",
    ["Aura"] = "Aura",
    ["Righteous Fury"] = "Furia justa",
    ["Seal"] = "Sello",
    ["Power Word: Fortitude"] = "Palabra de poder: entereza",
    ["Divine Spirit"] = "Espíritu divino",
    ["Shadow Protection"] = "Protección de las Sombras",
    ["Inner Fire"] = "Fuego interno",
    ["Touch of Weakness"] = "Toque de debilidad",
    ["Shadowguard"] = "Guardia de las Sombras",
    ["Main Hand Poison"] = "Veneno en la mano principal",
    ["Off Hand Poison"] = "Veneno en la mano secundaria",
    ["Shield Spell"] = "Hechizo de escudo",
    ["Main Hand Imbue"] = "Encantamiento de la mano principal",
    ["Off Hand Imbue"] = "Encantamiento de la mano secundaria",
    ["Demon Armor"] = "Armadura demoníaca",
    ["Firestone or Spellstone"] = "Pirorroca o piedra de hechizos",
    ["Amplify Magic"] = "Amplificar magia",
    ["Dampen Magic"] = "Empapar magia",
    ["Water Breathing"] = "Respiración acuática",
    ["Water Walking"] = "Caminar sobre el agua",
    ["Unending Breath"] = "Fuerza inmortal",
    ["Detect Invisibility"] = "Detectar invisibilidad",
    ["Pet Happiness"] = "Felicidad de la mascota",
    ["Battle Shout"] = "Grito de guerra",

    -- Data/Tracking.lua
    ["Find Minerals"] = "Buscar minerales",
    ["Find Herbs"] = "Buscar hierbas",
    ["Find Treasure"] = "Buscar tesoro",

    -- -----------------------------------------------------------------------
    -- Chat
    -- -----------------------------------------------------------------------

    -- Modules/Chat.lua
    ["%d min %d s"] = "%d min %d s",
    ["Controls the chat's appearance, its surrounding buttons, and notification sounds."]
        = "Controla el aspecto del chat, los botones que lo rodean y los sonidos de aviso.",
    ["Names"] = "Nombres",
    ["How names are written"] = "Cómo se escriben los nombres",
    ["Full name"] = "Nombre completo",
    ["Initial and surname"] = "Inicial y apellido",
    ["First name only"] = "Solo el nombre",
    ["Surname only"] = "Solo el apellido",
    ["Initials"] = "Iniciales",
    ["Shortens the name of the sender of each line. Hover over a shortened name to see the full name. Whispers are always addressed to the full name."]
        = "Acorta el nombre de quien escribió una línea. Al pasar el ratón por un nombre acortado se ve completo, y un susurro siempre va al nombre completo.",
    ["Race icon before the name"] = "Icono de raza antes del nombre",
    ["The race of whoever wrote a line, as an icon in front of the name."]
        = "La raza de quien escribió una línea, como icono delante del nombre.",
    ["Class icon before the name"] = "Icono de clase antes del nombre",
    ["The class of whoever wrote a line, as an icon in front of the name."]
        = "La clase de quien escribió una línea, como icono delante del nombre.",
    ["%d px"] = "%d px",
    ["Not in use until you switch on a race or class icon."] = "No se usa hasta activar el icono de raza o el de clase.",
    ["Sets the size of both icons. Lines already in the chat keep the size they had when they arrived."]
        = "El tamaño con el que se dibujan ambos iconos. Las líneas que ya están en el chat conservan el tamaño con el que llegaron.",
    ["Channel Labels"] = "Abreviaturas de canal",
    ["Use the labels below"] = "Usar las abreviaturas de abajo",
    ["Off: channels and groups appear in chat as the game writes them. Your labels below are kept."]
        = "Si se desactiva, los canales y grupos aparecen en el chat como los escribe el juego. Tus abreviaturas de abajo se conservan.",
    ["Channel labels"] = "Abreviaturas de canal",
    ["Not in use until you switch the labels on."]
        = "No se usa hasta activar las abreviaturas.",
    ["A numbered channel uses its number as its label unless you enter a different one. Labels move with their channels when you reorder them. A number entered in a field always refers to that channel's number. An empty field leaves the label as the client writes it. The square beside each field shows that chat's color."]
        = "Un canal numerado aparece como su número salvo que su campo diga otra cosa, y una abreviatura se mueve con su canal cuando se reordenan los canales. Un número en un campo siempre representa el número propio del canal. Un campo vacío deja la abreviatura como la escribe el cliente. El cuadrado de al lado tiene el color de ese chat.",
    ["Timestamps"] = "Hora de los mensajes",
    ["Timestamp format"] = "Formato de la hora",
    ["None"] = "Ninguno",
    ["03:27 PM"] = "03:27 PM",
    ["03:27:32 PM"] = "03:27:32 PM",
    ["Uses the client's timestamp setting. Changing it here also changes it in the game's options, and vice versa. Timestamps appear in square brackets."]
        = "La opción de hora del propio cliente. Cambiarla aquí la cambia también en las opciones del juego, y al revés. El chat la muestra entre corchetes.",
    ["Appearance"] = "Aspecto",
    ["Sets the text size for every chat window at once. Each window's tab menu can still set its size individually. Windows without a chosen size default to 16."]
        = "El tamaño de texto del propio cliente, para todas las ventanas de chat a la vez. El menú de su pestaña sigue ajustando una sola ventana. Una ventana cuyo tamaño nunca se eligió empieza en 16.",
    ["Space between lines"] = "Espacio entre líneas",
    ["Extra room between two lines of chat."] = "Espacio adicional entre dos líneas de chat.",
    ["Outline"] = "Contorno",
    ["Thin"] = "Fino",
    ["Thick"] = "Grueso",
    ["Adds an outline around every letter, alongside the shadow."]
        = "Una línea alrededor de cada letra, además de la sombra.",
    ["Never fade chat out"] = "No desvanecer nunca el chat",
    ["Old lines stay on screen rather than dimming and vanishing."]
        = "Las líneas antiguas se quedan en pantalla en lugar de atenuarse y desaparecer.",
    ["Fade after"] = "Desvanecer tras",
    ["Not in use until you let the chat fade."] = "No se usa hasta permitir que el chat se desvanezca.",
    ["How long a line stays before it fades."]
        = "Cuánto tiempo se queda una línea antes de desvanecerse.",
    ["Chat Window"] = "Ventana de chat",
    ["Hide the chat buttons"] = "Ocultar los botones del chat",
    ["Hides the buttons beside the chat window and the one that jumps to the newest line."]
        = "Los botones junto a la ventana de chat y el de ir a la última línea.",
    ["Show tabs only under the mouse"] = "Mostrar las pestañas solo bajo el ratón",
    ["The window tabs disappear while the mouse is elsewhere. A tab with a new message still lights up."]
        = "Las pestañas de las ventanas desaparecen mientras el ratón está en otro sitio. Una pestaña con un mensaje nuevo se sigue iluminando.",
    ["Show the input line only after Enter"] = "Mostrar la línea de entrada solo tras Intro",
    ["Uses the client's chat style: the input line appears when you press Enter and disappears when the message is sent. Takes effect the next time the input line closes."]
        = "El estilo de chat del propio cliente: la línea de entrada aparece al pulsar Intro y se va al enviar el mensaje. Surte efecto la próxima vez que se cierre la línea de entrada.",
    ["Input"] = "Entrada",
    ["Arrow keys bring back what you sent"] = "Recuperar lo enviado con las flechas",
    ["Use the Up and Down arrows in the input line to browse messages you sent during this session without holding Alt. Protected commands like /target and /cast still need Alt. In combat, keys without a modifier that the input does not use have no effect while it is open."]
        = "Arriba y Abajo en la línea de entrada recorren lo que enviaste en esta sesión, sin mantener Alt. Los comandos protegidos como /target y /cast siguen necesitando Alt. En combate, las teclas sin modificador que la línea de entrada no usa no tienen efecto mientras esté abierta.",
    ["Use Alt and Up for %s. The game blocks this command on the plain arrow keys."]
        = "Usa Alt y Arriba para %s. El juego bloquea este comando en las flechas normales.",
    ["Mouse Wheel"] = "Rueda del ratón",
    ["Shift and the wheel jump to the top or bottom"]
        = "Saltar arriba o abajo con Mayús y la rueda",
    ["Hold Shift and move the wheel one notch to jump straight to the top or bottom."]
        = "Un paso de la rueda manteniendo Mayús lleva directamente al principio o al final.",
    ["Lines per wheel notch"] = "Líneas por paso de la rueda",
    ["How far one notch of the wheel moves."] = "Cuántas líneas avanza un paso de la rueda.",
    ["Copy and Search"] = "Copiar y buscar",
    ["Shift click a timestamp to quote its line"] = "Citar una línea con Mayús+clic en su hora",
    ["Not in use until you choose a timestamp format."]
        = "No se usa hasta elegir un formato de hora.",
    ["A Shift click on a timestamp copies the whole line into the chat input, including the timestamp and sender, without sending it. Lines that arrived before this was enabled stay unchanged."]
        = "Mayús+clic en la hora de un mensaje copia la línea entera en la entrada del chat, con la hora y el remitente, sin enviarla. Las líneas que llegaron antes de activar esto se quedan como están.",
    ["Open the chat input when it is closed"] = "Abrir la entrada del chat si está cerrada",
    ["Not in use until you switch on Shift clicking a timestamp."]
        = "No se usa hasta activar Mayús+clic en la hora.",
    ["A Shift click on a timestamp opens the chat input with the line already entered, so you do not need to press Enter first."]
        = "Mayús+clic en la hora abre la entrada del chat con la línea ya dentro, así que no hace falta pulsar Intro antes.",
    ["Search bar on the chat window"] = "Barra de búsqueda en la ventana de chat",
    ["Fade in and out"] = "Aparecer y desaparecer gradualmente",
    ["Not in use until you switch the search bar on."]
        = "No se usa hasta activar la barra de búsqueda.",
    ["The bar fades in when the mouse comes over the chat and out when it leaves, rather than appearing at once."]
        = "La barra aparece gradualmente cuando el ratón entra en el chat y desaparece cuando sale, en lugar de aparecer de golpe.",
    ["Opacity"] = "Opacidad",
    ["Sets the search bar's opacity."] = "Lo opaca que se dibuja la barra de búsqueda.",
    ["History"] = "Historial",
    ["Keep the chat across sessions"] = "Conservar el chat entre sesiones",
    ["Saves every chat window when you log out or reload and restores them when this character logs in again."]
        = "Cada ventana de chat se guarda al desconectarte o reiniciar la IU, y se restaura cuando este personaje vuelve a conectarse.",
    ["Lines kept per window"] = "Líneas conservadas por ventana",
    ["Not in use until you keep the chat across sessions."] = "No se usa hasta conservar el chat entre sesiones.",
    ["Keeps the newest lines in each window, up to the number of lines that window can hold."]
        = "Se conservan las líneas más recientes de cada ventana, como máximo tantas como caben en una ventana de chat.",
    ["Sounds"] = "Sonidos",
    ["Plays a selected sound for each enabled message type. The button beside it plays the selected sound."]
        = "Un sonido para cada tipo de mensaje que esté activado. El botón de al lado reproduce el sonido elegido.",
    ["Pause between sounds"] = "Pausa entre sonidos",
    ["After a sound plays, further messages of the same type from the same person are silent until this much time has passed. Applies to whispers, officer chat and messages from the party and raid leader. Messages from other people play a sound immediately."]
        = "Tras un sonido, los siguientes mensajes de la misma persona en el mismo tipo de chat no suenan hasta que pasa este tiempo. Se aplica a los susurros, al chat de oficiales y a los líderes de grupo y de banda. El mensaje de otra persona suena al instante.",
    ["Raid Warnings"] = "Avisos de banda",
    ["Plays a selected sound for raid warnings. The button beside it plays the selected sound."]
        = "Un sonido para los avisos de banda mientras esté activado. El botón de al lado reproduce el sonido elegido.",
    ["Pause between raid warnings"] = "Pausa entre avisos de banda",
    ["After a raid warning's sound plays, further raid warnings from the same person are silent until this much time has passed. At 0, every raid warning plays a sound."]
        = "Tras el sonido de un aviso de banda, los siguientes avisos de la misma persona no suenan hasta que pasa este tiempo. Con 0 suenan todos.",

    -- Core/Util.lua, the sounds to pick from
    ["Whisper"] = "Susurro",
    ["Raid warning"] = "Aviso de banda",
    ["Ready check"] = "¿Listos?",
    ["Group invite"] = "Invitación de grupo",
    ["Friend online"] = "Amigo conectado",
    ["Alarm clock"] = "Despertador",
    ["Alarm clock, short"] = "Despertador corto",
    ["Map ping"] = "Señal en el mapa",
    ["Auction house"] = "Casa de subastas",
    ["Coins"] = "Monedas",
    ["Level up"] = "Subida de nivel",

    -- Modules/ChatHistory.lua
    ["Chat: this client cannot add older lines to a chat window, so the saved chat is not restored."]
        = "Chat: este cliente no puede añadir líneas antes de las que ya hay en una ventana, así que el chat conservado no se restaura.",

    -- Modules/ChatLines.lua
    ["Chat: this client would not let a line be changed after it arrived, so labels and names stay as the game writes them."]
        = "Chat: este cliente no permite cambiar una línea una vez llegada, así que las abreviaturas y los nombres se quedan como los escribe el juego.",
    ["Chat: changing a line failed once and is left alone from now on this session."]
        = "Chat: cambiar una línea falló una vez y ya no se intenta en lo que queda de sesión.",
    ["Sets this chat's color using the client's own color picker."]
        = "El color de este chat. Es una opción del propio cliente y se cambia con su propio selector de color.",
    ["No channels to label yet."] = "Todavía no hay canales que abreviar.",

    -- Modules/ChatSearch.lua
    ["Search for \"%s\": %d matching lines, showing the latest %d"] = "Búsqueda de \"%s\": %d líneas, las últimas %d",
    ["Search for \"%s\": %d line"] = "Búsqueda de \"%s\": %d línea",
    ["Search for \"%s\": %d lines"] = "Búsqueda de \"%s\": %d líneas",
    ["Empties the search field."] = "Vacía el campo de búsqueda.",
    ["Type a search and press Enter to display every matching line in this chat window again. Press Escape or click the X to clear the search."]
        = "Escribe y pulsa Intro: se vuelve a mostrar cada línea de esta ventana de chat que coincida. Escape o la X del final lo vacían.",

    -- Modules/ChatSound.lua
    ["Whispers"] = "Susurros",
    ["Officer Chat"] = "Chat de oficiales",
    ["Party Leader"] = "Líder del grupo",
    ["Raid Leader"] = "Líder de banda",
    ["Chat: this client has no sound called %s."]
        = "Chat: este cliente no tiene ningún sonido llamado %s.",

    -- Late finds on the Consumables and Chat pages
    ["Replaced by a Class Buff"] = "Sustituido por un beneficio de clase",
    ["Replaces the label before this chat's lines. Leave it empty to use the client's label."]
        = "Sustituye la abreviatura delante de las líneas de este chat. Vacío deja la del cliente.",
    ["Plays the selected sound when a message of this type arrives."]
        = "Reproduce el sonido elegido al lado cuando llega un mensaje de este tipo.",

    -- -----------------------------------------------------------------------
    -- Late finds
    -- -----------------------------------------------------------------------

    -- Gameplay, Profiles and the export. The chat commands' own texts stay
    -- English since 2026-10-07, see ENGLISH_OUTPUT in tools/l10n.py.
    ["[ForeverPlus hid]"] = "[Ocultado por ForeverPlus]",
    ["%s (a %s key)"] = "%s (una clave de tipo %s)",
    ["%s (no such module here)"] = "%s (este módulo no existe aquí)",
    ["Nested more than %d levels deep"] = "Anidado a más de %d niveles",
    ["Cannot include a %s in an export string"]
        = "No se puede poner un valor de tipo %s en un texto de exportación",
    -- Bar settings, shared movement and camp bonuses (2026-10-17).
    ["Bar %s"] = "Barra %s",
    ["Camp Benefits"] = "Beneficios del campamento",
    ["All Stats (%)"] = "Todos los atributos (%)",
    ["Armor, Stats and Resistances"] = "Armadura, atributos y resistencias",
    ["Critical Strike Chance"] = "Probabilidad de golpe crítico",
    ["Rested Experience"] = "Bonificación de descanso",
    ["Bar"] = "Barra",
    ["The bar for this entry's icons. Use Manage bars to change its settings."]
        = "La barra para los iconos de esta entrada. Sus ajustes se encuentran en Gestionar barras.",
    ["Custom warning time"] = "Tiempo de aviso personalizado",
    ["Off: follows this page's warning time, including later changes."]
        = "Desactivado: usa el tiempo de aviso de esta página, incluidos los cambios posteriores.",
    ["Warns when less than this time remains. At 0, skips advance warnings but still warns when missing."]
        = "Avisa cuando queda menos de este tiempo. Con 0, no avisa antes de que expire, pero sigue avisando si falta el efecto.",
    ["Horizontal, centered"] = "Horizontal, centrada",
    ["Vertical, centered"] = "Vertical, centrada",
    ["To the right"] = "Hacia la derecha",
    ["To the left"] = "Hacia la izquierda",
    ["Downward"] = "Hacia abajo",
    ["Upward"] = "Hacia arriba",
    ["Delete Bar"] = "Borrar barra",
    ["Delete the bar %s?"] = "¿Borrar la barra %s?",
    ["%d entry will move to %s."] = "Se moverá %d entrada a %s.",
    ["%d entries will move to %s."] = "Se moverán %d entradas a %s.",
    ["Restore Default Setup"] = "Restablecer barras predeterminadas",
    ["Restores General Warnings, Combat Buffs and Consumables with their original assignments. Custom bars are kept but emptied. Positions, icon sizes and warning times stay unchanged unless selected below."]
        = "Restablece Avisos generales, Beneficios de combate y Consumibles con sus asignaciones originales. Las barras personalizadas se conservan vacías. Las posiciones, los tamaños de icono y los tiempos de aviso no cambian, salvo que se seleccionen abajo.",
    ["Reset default bar positions"] = "Restablecer posiciones de las barras predeterminadas",
    ["Reset default bar icon sizes"] = "Restablecer tamaños de icono de las barras predeterminadas",
    ["Reset all warning times"] = "Restablecer todos los tiempos de aviso",
    ["Restore"] = "Restablecer",
    ["Bars"] = "Barras",
    ["Number of enabled entries assigned to this bar for your character."]
        = "Número de entradas activadas asignadas a esta barra para tu personaje.",
    ["New bar"] = "Nueva barra",
    ["Creates an empty bar with the default appearance. Assign entries to it in their details."]
        = "Crea una barra vacía con el aspecto predeterminado. Las entradas se asignan desde sus detalles.",
    ["Restore default setup"] = "Restablecer barras",
    ["Restores the three default bars and their original assignments."]
        = "Restablece las tres barras predeterminadas y sus asignaciones originales.",
    ["Name"] = "Nombre",
    ["The name shown in bar lists and entry details. Leave blank to restore the default name."]
        = "El nombre que aparece en las listas de barras y los detalles de las entradas. Un campo vacío restaura el nombre predeterminado.",
    ["Sets the size of every icon on this bar."] = "Define el tamaño de todos los iconos de esta barra.",
    ["Growth direction"] = "Dirección de expansión",
    ["Sets the bar's growth direction. At the screen edge, icons wrap to a new row or column."]
        = "Define en qué dirección crece la barra. Al llegar al borde de la pantalla, los iconos pasan a una nueva fila o columna.",
    ["The countdown under each icon on this bar."] = "La cuenta atrás bajo cada icono de esta barra.",
    ["Missing icon color"] = "Color de efectos ausentes",
    ["Sets how missing buffs and consumables look on this bar. Borders stay red."]
        = "Define el aspecto de los beneficios y consumibles ausentes en esta barra. Los bordes siguen rojos.",
    ["Hides settings and lets you move all bars and the info bar, with this bar highlighted. Apply saves positions; Cancel discards changes."]
        = "Oculta la configuración para mover todas las barras y la barra de información, resaltando esta barra. Aplicar guarda las posiciones; Cancelar descarta los cambios.",
    ["Restores this bar's default position."] = "Restablece la posición predeterminada de esta barra.",
    ["Moves this bar to the starting position for new bars."]
        = "Mueve esta barra a la posición inicial de las barras nuevas.",
    ["Delete bar"] = "Borrar barra",
    ["This is the fallback bar and cannot be deleted."]
        = "Esta es la barra de respaldo y no se puede borrar.",
    ["Asks before deleting this bar. Its entries move to the fallback bar."]
        = "Pide confirmación antes de borrar esta barra. Sus entradas pasan a la barra de respaldo.",
    ["Manage bars"] = "Gestionar barras",
    ["Opens bar settings for buffs and consumables: size, appearance and screen position."]
        = "Abre los ajustes de las barras de beneficios y consumibles: tamaño, aspecto y posición en pantalla.",
    ["Warns when neither this bonus nor a replacement class buff is active. If no bonuses are selected, tracks %s itself."]
        = "Avisa si no está activo este bonus ni un beneficio de clase que lo sustituya. Si no se selecciona ningún bonus, vigila el propio efecto %s.",
    ["Given by these camp objects:"] = "Lo otorgan estos objetos de campamento:",
    ["These class buffs also count:"] = "Estos beneficios de clase también cuentan:",
    ["Select up to three bonuses, the most you can have at once."]
        = "Permite seleccionar hasta tres bonus, el máximo que puede estar activo a la vez.",
    ["Buffs for All Classes"] = "Beneficios para todas las clases",
    ["Off: uses this page's warning times. Your buff uses the setting for its duration; group counts use the setting for buffs lasting 10 to 29 minutes."]
        = "Desactivado: usa los tiempos de aviso de esta página. Tu beneficio usa el ajuste de su duración; el recuento del grupo usa el de los beneficios de 10 a 29 minutos.",
    ["(no coating chosen)"] = "(sin piedra ni aceite)",
    ["Sets the bar and warning time for this hand's coating. Choose the oil or stone in the list below."]
        = "Define la barra y el tiempo de aviso de la piedra o el aceite de esta mano. Se elige en la lista de abajo.",
    ["Not in use until you choose an oil or stone for this hand in the list below."]
        = "No se usa hasta elegir un aceite o una piedra para esta mano en la lista de abajo.",
    ["Move bars"] = "Mover barras",
    ["Hides settings so you can move all bars and the info bar. Apply saves positions; Cancel discards changes."]
        = "Oculta la configuración para mover todas las barras y la barra de información. Aplicar guarda las posiciones; Cancelar descarta los cambios.",
    ["Confirm changes?"] = "¿Confirmar los cambios?",
    ["The bars cannot be moved during combat."] = "No se pueden mover las barras en combate.",
    ["Drag the bars and the info bar into place. Apply saves positions; Cancel discards changes."]
        = "Arrastra las barras y la barra de información a su sitio. Aplicar guarda las posiciones; Cancelar descarta los cambios.",
    -- Translation round, 2026-10-18.
    ["Let the window reach the left edge"] = "Permitir mover la ventana hasta el borde izquierdo",
    ["Not in use until you hide the chat buttons."]
        = "No se usa hasta que ocultes los botones del chat.",
    ["Removes the room kept free for the buttons on the left of the main chat window, so it can be moved up to the left edge of the screen."]
        = "Elimina el espacio reservado para los botones a la izquierda de la ventana principal del chat, para poder moverla hasta el borde izquierdo de la pantalla.",
    ["Turns every duel request down. Nothing is sent to whoever asked: they see the same refusal they would see if you had clicked it yourself."]
        = "Rechaza todas las solicitudes de duelo. No envía ningún mensaje a quien te reta: ve el mismo rechazo que si hubieras hecho clic tú.",
    -- Translation round, 2026-10-18.
    ["Portrait style"] = "Estilo de retrato",
    ["HD"] = "HD",
    ["SD"] = "SD",
    ["Not in use until you switch on the race icon."] = "No se usa hasta que actives el icono de raza.",
    ["HD shows the newer race portraits, SD the older ones. A race without an SD portrait keeps its HD one. Lines already in the chat keep theirs."]
        = "HD muestra los retratos de raza nuevos y SD los antiguos. Una raza sin retrato SD conserva el HD. Las líneas ya mostradas en el chat mantienen sus retratos.",
    ["Tab background opacity"] = "Opacidad del fondo de las pestañas",
    ["Sets the opacity of every chat tab's background. The tab names stay fully visible."]
        = "Define la opacidad del fondo de todas las pestañas del chat. Sus nombres permanecen totalmente visibles.",
    ["Horizontal offset"] = "Desplazamiento horizontal",
    ["Moves the search bar to the right of its place in the chat window's top right corner, or to the left below zero. Hold Shift for steps of 50."]
        = "Desplaza la barra de búsqueda a la derecha desde su posición en la esquina superior derecha del chat, o a la izquierda con valores negativos. Mantén Mayús para cambiar de 50 en 50.",
    ["Vertical offset"] = "Desplazamiento vertical",
    ["Moves the search bar up from its place in the chat window's top right corner, or down below zero. Hold Shift for steps of 50."]
        = "Desplaza la barra de búsqueda hacia arriba desde su posición en la esquina superior derecha del chat, o hacia abajo con valores negativos. Mantén Mayús para cambiar de 50 en 50.",
    ["Puts the search bar back in the chat window's top right corner."]
        = "Devuelve la barra de búsqueda a la esquina superior derecha del chat.",
    ["Shown"] = "Visible",
    ["Hidden"] = "Oculto",
    ["Shown on hover"] = "Visible al pasar el ratón",
    ["Bag bar"] = "Bolsas",
    ["Micro menu"] = "Menú",
    ["Minimap tracking"] = "Rastreo del minimapa",
    ["Minimap zone name"] = "Nombre de zona del minimapa",
    ["Minimap clock"] = "Reloj del minimapa",
    ["Minimap calendar"] = "Calendario del minimapa",
    ["Minimap addon button"] = "Botón de addons del minimapa",
    ["Hide Interface Elements"] = "Ocultar elementos de la interfaz",
    ["Hides the bag bar, the micro menu and parts of the minimap, always or depending on the mouse."]
        = "Oculta la barra de bolsas, el menú y partes del minimapa, siempre o según la posición del ratón.",
    ["Numbers"] = "Números",
    ["Quest titles"] = "Títulos de misión",
    ["Letters"] = "Cartas",
    ["Combat text"] = "Texto de combate",
    ["Open the stopwatch with a click"] = "Abrir el cronómetro con un clic",
    ["A click on the display opens or closes the game's stopwatch."]
        = "Un clic en el dato abre o cierra el cronómetro del juego.",
    ["Open the calendar with a Shift click"] = "Abrir el calendario con Mayús+clic",
    ["A Shift click on the display opens or closes the game's calendar."]
        = "Mayús+clic en el dato abre o cierra el calendario del juego.",
    ["Open the world map with a click"] = "Abrir el mapa del mundo con un clic",
    ["A click on the display opens or closes the world map."]
        = "Un clic en el dato abre o cierra el mapa del mundo.",
    ["How many of your bag slots are free."] = "Cuántas casillas libres hay en tus bolsas.",
    ["Shows the free slots with the total, or the free slots alone. The hover always shows both."]
        = "Muestra las casillas libres junto al total, o solo las libres. Al pasar el ratón siempre se muestran ambas cifras.",
    ["Free and total"] = "Libres y total",
    ["Free only"] = "Solo libres",
    ["Reload the interface with a click"] = "Reiniciar la interfaz con un clic",
    ["A click on the display asks whether to reload the interface. Not in combat."]
        = "Un clic en el dato pide confirmación para reiniciar la interfaz. Solo fuera de combate.",
    ["Turn all sound off and on with a click"] = "Desactivar y activar todo el sonido con un clic",
    ["A click on the display turns all game sound off, and the next one turns it back on. The volume stays as it was."]
        = "Un clic en el dato desactiva todo el sonido del juego y el siguiente lo vuelve a activar. El volumen se conserva.",
    ["Font"] = "Fuente",
    ["The font of the info bar. Default is the font of the addon, the others are fonts the game uses elsewhere."]
        = "La fuente de la barra de información. Predeterminado usa la del addon; las demás se usan en otras partes del juego.",
    ["The size of the info bar's text, relative to the text size on the Design page."]
        = "El tamaño del texto de la barra de información, relativo al de la página Apariencia.",
    ["Text color"] = "Color del texto",
    ["The color of the info bar's text."] = "El color del texto de la barra de información.",
    ["Status colors"] = "Colores de estado",
    ["Colors displays by their state. Off, the whole bar is in its text color."]
        = "Colorea los datos según su estado. Desactivado, toda la barra usa su color de texto.",
    ["Background color"] = "Color del fondo",
    ["The color and opacity of the info bar's background."]
        = "El color y la opacidad del fondo de la barra de información.",
    ["Border color"] = "Color del borde",
    ["The color and opacity of the info bar's border."]
        = "El color y la opacidad del borde de la barra de información.",
    ["Show icons"] = "Mostrar iconos",
    ["The icons in front of the displays. A display that is only an icon shows its name instead."]
        = "Los iconos delante de los datos. Un dato que solo tiene un icono muestra su nombre en su lugar.",
    ["Restore default look"] = "Restablecer aspecto",
    ["Puts the info bar's font, colors and icons back as the design has them."]
        = "Restablece la fuente, los colores y los iconos de la barra de información según la apariencia elegida.",
    ["Click to open the world map"] = "Haz clic para abrir el mapa del mundo",
    ["Click to open the stopwatch"] = "Haz clic para abrir el cronómetro",
    ["Shift click to open the calendar"] = "Mayús+clic para abrir el calendario",
    ["Click to reload the interface"] = "Haz clic para reiniciar la interfaz",
    ["The interface cannot be reloaded during combat."]
        = "No se puede reiniciar la interfaz en combate.",
    ["Reload the interface now?"] = "¿Reiniciar la interfaz ahora?",
    ["Click the display to turn all sound off or on"]
        = "Haz clic en el dato para desactivar o activar todo el sonido",
    ["Click an icon to hide or show it on the bar."]
        = "Haz clic en un icono para ocultarlo o mostrarlo en la barra.",
    ["Hides or shows this display's icon on the bar."]
        = "Oculta o muestra el icono de este dato en la barra.",
    ["Accepts each quest automatically at most once per conversation with the quest giver."]
        = "Acepta misiones automáticamente, cada una como máximo una vez por conversación con quien la ofrece.",
    ["Quest difficulty"] = "Dificultad de las misiones",
    ["Accept all"] = "Aceptar todas",
    ["Skip gray quests"] = "Omitir misiones grises",
    ["Skip gray and green quests"] = "Omitir grises y verdes",
    ["Which quests are left for you to accept, by their color for your character. Handing quests in is not affected."]
        = "Qué misiones quedan para que las aceptes manualmente, según su color para tu personaje. No afecta a la entrega de misiones.",
    ["Hands in each completed quest at most once per conversation with the quest giver. Never picks a reward for you."]
        = "Entrega las misiones completadas, cada una como máximo una vez por conversación con quien la ofrece. Nunca elige una recompensa por ti.",
    -- Translation round, 2026-10-18.
    ["Shown, hidden, or shown only while the mouse is over its place. A hidden piece takes no clicks."]
        = "Visible, oculto o visible solo al pasar el ratón por su posición. Un elemento oculto no recibe clics.",
    ["Always visible"] = "Siempre visible",
    ["Shows the search bar all the time, instead of only while the mouse is over the chat window or the input line is open."]
        = "Muestra la barra de búsqueda siempre, en lugar de solo cuando el ratón está sobre el chat o la línea de entrada está abierta.",
    ["Not in use until you switch off Always visible."]
        = "No se usa hasta que desactives Siempre visible.",
    ["Appears in the chat window's top right corner while the mouse is over the window or the input line is open, unless it is set to be always visible. Press Enter to display every matching line again. The X at the end clears the search."]
        = "En la esquina superior derecha del chat mientras el ratón está encima o la línea de entrada está abierta, salvo si Siempre visible está activado. Intro vuelve a mostrar cada línea que coincide. La X del final borra la búsqueda.",
    -- Translation round, 2026-10-20: chat fading and item level.
    ["Show chat on hover or while typing"] = "Mostrar el chat al pasar el ratón o escribir",
    ["Shows faded lines while the mouse is over the chat window or the input line is open. Afterward, they stay for the time set under \"Fade after\"."]
        = "Muestra las líneas desvanecidas mientras el ratón está sobre la ventana de chat o la línea de entrada está abierta. Después, siguen visibles durante el tiempo definido en \"Desvanecer tras\".",
    ["Fade the background with the messages"] = "Desvanecer el fondo con los mensajes",
    ["Fades the window's background and tabs out with the last line. They return at your chosen opacity with a new message, when you scroll, while the mouse is over the window, or while you type."]
        = "Desvanece el fondo de la ventana y las pestañas junto con la última línea. Recuperan la opacidad elegida con un mensaje nuevo, al desplazarte, mientras el ratón está sobre la ventana o mientras escribes.",
    ["Item level"] = "Nivel de objeto",
    ["Shows the average item level of a player's equipped items. For other players, the value updates when you hover over them outside combat. The last known value stays visible until the new one arrives."]
        = "Muestra el nivel de objeto medio del equipo que lleva puesto un jugador. Para otros jugadores, el valor se actualiza al pasar el ratón sobre ellos fuera de combate. El último valor conocido sigue visible hasta que llega el nuevo.",
    -- Translation round, 2026-10-23: chat input and info bar.
    ["Input line position"] = "Posición de la línea de entrada",
    ["Below the window"] = "Bajo la ventana",
    ["Between window and tabs"] = "Bajo las pestañas",
    ["Above the tabs"] = "Sobre las pestañas",
    ["Places the input line of every chat window below the window, between the window and its tabs, or above the tabs."]
        = "Coloca la línea de entrada de cada ventana de chat bajo la ventana, entre la ventana y sus pestañas o sobre las pestañas.",
    ["How much ammunition you carry for your bow, gun or crossbow. Not shown while none of them is equipped."]
        = "Cuánta munición llevas para tu arco, arma de fuego o ballesta. No se muestra si no tienes equipada ninguna de estas armas.",
    ["What it counts"] = "Qué contar",
    ["Counts every arrow or every bullet in your bags that your weapon fires, or only the ammunition in your ammo slot."]
        = "Cuenta todas las flechas o balas de tus bolsas que puede disparar tu arma, o solo la munición de tu casilla de munición.",
    ["All arrows or bullets"] = "Todas las flechas o balas",
    ["Ammo slot only"] = "Solo casilla de munición",
    ["Turns the display red below the amount set under this switch. Shared with Ammunition Warning on the Gameplay page, where it also shows a red line and plays a sound for Hunters."]
        = "Muestra la cifra en rojo por debajo de la cantidad fijada bajo esta opción. Se comparte con Aviso de munición en la página Experiencia de juego, que también avisa a los cazadores con una línea roja y un sonido.",
    ["The amount below which the display turns red. Shared with Ammunition Warning on the Gameplay page."]
        = "La cantidad por debajo de la cual la cifra se vuelve roja. Se comparte con Aviso de munición en la página Experiencia de juego.",
    ["Destroy Cheapest Gray Item"] = "Destruir el objeto gris más barato",
    ["Shows an icon for the gray stack in your bags that is worth the least at a merchant. Shift click it to destroy that stack and free a bag slot. Not in combat."]
        = "Muestra un icono del montón de objetos grises de tus bolsas por el que un mercader pagaría menos. Mayús+clic destruye ese montón y libera una casilla de bolsa. No funciona en combate.",
    ["Destroy with a click, without Shift"] = "Destruir con un clic, sin Mayús",
    ["A click on the display destroys the stack without holding Shift."]
        = "Un clic en el dato destruye el montón sin mantener pulsada Mayús.",
    ["Skip the confirmation"] = "Omitir la confirmación",
    ["Destroys the stack at once, without the question, and reports it in chat."]
        = "Destruye el montón al instante, sin confirmación, y lo anuncia en el chat.",
    ["Counts %s, the ammunition in your ammo slot"] = "Cuenta %s, la munición de tu casilla de munición",
    ["Your ammo slot is empty"] = "Tu casilla de munición está vacía",
    ["Counts every bullet in your bags"] = "Cuenta todas las balas de tus bolsas",
    ["Counts every arrow in your bags"] = "Cuenta todas las flechas de tus bolsas",
    ["Red below %d"] = "En rojo por debajo de %d",
    ["Nothing is destroyed in combat."] = "No se destruye nada en combate.",
    ["Nothing was destroyed: something is on your cursor."] = "No se ha destruido nada: hay algo en el cursor.",
    ["Nothing was destroyed: your bags changed."]
        = "No se ha destruido nada: el contenido de tus bolsas ha cambiado.",
    ["Nothing was destroyed: this client cannot destroy items for an addon."]
        = "No se ha destruido nada: este cliente no puede destruir objetos a petición de un addon.",
    ["The game did not destroy %s."] = "El juego no ha destruido %s.",
    ["Destroyed %d %s, worth %s at a merchant."] = "Destruido: %d %s, con un valor de %s en un mercader.",
    ["Destroyed %d %s, worth nothing at a merchant."] = "Destruido: %d %s, sin valor en un mercader.",
    ["Destroy Gray Item"] = "Destruir objeto gris",
    ["Do you really want to destroy %d %s?"] = "¿Seguro que quieres destruir %d %s?",
    ["A merchant would pay %s for it. This cannot be undone."]
        = "Un mercader pagaría %s por ello. Esta acción no se puede deshacer.",
    ["A merchant would pay nothing for it. This cannot be undone."]
        = "Un mercader no pagaría nada por ello. Esta acción no se puede deshacer.",
    ["Destroy"] = "Destruir",
    ["Turns on \"Skip the confirmation\" on the Info bar page when you click Destroy."]
        = "Activa \"Omitir la confirmación\" en la página Barra de información al hacer clic en Destruir.",
    ["No gray item to destroy"] = "No hay objetos grises para destruir",
    ["Stack of %d, worth %s at a merchant"] = "Montón de %d, con un valor de %s en un mercader",
    ["Stack of %d, worth nothing at a merchant"] = "Montón de %d, sin valor en un mercader",
    ["Not in combat"] = "No disponible en combate",
    ["Click to destroy this stack"] = "Clic para destruir este montón",
    ["Shift click to destroy this stack"] = "Mayús+clic para destruir este montón",
    -- Shadow Protection, durability warning and web address copying.
    ["Warn about Shadow Protection from others"] = "Avisar de este beneficio de otros",
    ["Warns when Shadow Protection is missing or about to expire and a Priest in your group could give it to you. Only applies where buffs from others are switched on under Conditions. A Priest's own warnings and group count do not change."]
        = "Avisa cuando falta Protección de las Sombras o está a punto de expirar y un sacerdote de tu grupo podría otorgártela. Solo se aplica donde los beneficios de otros estén activados en \"Condiciones\". Los avisos del sacerdote sobre sus propios beneficios y su recuento del grupo no cambian.",
    ["Durability Warning"] = "Aviso de durabilidad",
    ["Shows a short warning when an equipped item reaches the selected durability or lower. Also warns after login if an item is already low."]
        = "Muestra un aviso breve cuando la durabilidad de un objeto equipado alcanza el umbral elegido o baja de él. También avisa al iniciar sesión si algún objeto ya está en ese umbral o por debajo.",
    ["Warn at or below"] = "Avisar con este valor o menos",
    ["Uses the lowest durability among your equipped items. At 0%, it warns only about broken equipment."]
        = "Usa la durabilidad más baja de tus objetos equipados. Con 0%, solo avisa del equipo roto.",
    ["Low durability: %s (%d%%)"] = "Durabilidad baja: %s (%d%%)",
    ["Durability Warning: this client has no sound called %s."]
        = "Aviso de durabilidad: este cliente no tiene ningún sonido llamado %s.",
    ["Copy web addresses"] = "Copiar direcciones web",
    ["Makes web addresses in chat clickable for copying."]
        = "Permite hacer clic en las direcciones web del chat para copiarlas.",
    ["Click to select this web address for copying."]
        = "Haz clic para seleccionar esta dirección web para copiarla.",
    ["Web address"] = "Dirección web",
    ["Press Ctrl+C to copy."] = "Pulsa Ctrl+C para copiar.",
    -- Experience measurement, addon CPU usage and health bar textures.
    ["How much experience you gain per hour, measured since you logged in. Not shown at the maximum level."]
        = "Cuánta experiencia ganas por hora desde que iniciaste sesión. No se muestra en el nivel máximo.",
    ["Restart measurement with a click"] = "Reiniciar la medición con un clic",
    ["A click on the display resets the measurement for both experience displays."]
        = "Un clic en el dato reinicia la medición de los dos datos de experiencia.",
    ["Estimated time to your next level at your current experience rate. Not shown at the maximum level."]
        = "Tiempo estimado hasta tu siguiente nivel al ritmo actual de experiencia. No se muestra en el nivel máximo.",
    ["Click to restart measurement"] = "Haz clic para reiniciar la medición",
    ["Level %d"] = "Nivel %d",
    ["Rested"] = "Descansado",
    ["%s in %s"] = "%s en %s",
    ["Per hour"] = "Por hora",
    ["To the next level"] = "Hasta el siguiente nivel",
    ["Addon CPU usage"] = "Uso de CPU de los addons",
    ["Total"] = "Total",
    ["Health bar texture"] = "Textura de la barra de salud",
    ["Flat"] = "Uniforme",
    ["Soft gradient"] = "Degradado suave",
    ["Choose the texture of the health bar below unit tooltips."] = "Elige la textura de la barra de salud bajo las descripciones de unidades.",
    ["Preview"] = "Vista previa",
})
