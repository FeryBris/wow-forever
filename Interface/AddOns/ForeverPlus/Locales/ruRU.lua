-- Russian, phase 7.7.
--
-- The English text on the left is the key, exactly as it stands in the code,
-- and the Russian on the right is what a player reads. TRANSLATION.md holds the
-- words and the rules, gated with the owner on 2026-10-07: "вы" in lower case,
-- a setting as an infinitive, the Russian client's own words with buff the one
-- exception, straight quotes and е for ё as the client writes them, the dash
-- only where Russian grammar requires it, a decimal comma, a count after a
-- colon wherever FP:Plural does not choose the form, and a text that fits its
-- row.
--
-- Sorted like deDE.lua, by page and then by file. The form for 2 to 4 of every
-- plural FP:Plural is given sits in FP:AddPlurals at the end. tools/l10n.py
-- reports a text the code marks that is missing here, Russian left behind for
-- a text the code no longer marks, and what the client would not write.

local ADDON, FP = ...

FP:AddLocale("ruRU", {

    -- -----------------------------------------------------------------------
    -- The window
    -- -----------------------------------------------------------------------

    -- Core/Boot.lua
    ["v%s loaded, %d of %d modules enabled, profile |cffffffff%s|r. Open the settings with |cff888888/fplus|r."]
        = "v%s загружена, активно модулей: %d из %d, профиль |cffffffff%s|r. |cff888888/fplus|r открывает настройки.",

    -- Core/Init.lua
    ["NPC Interaction"] = "Взаимодействие с NPC",
    ["Merchants"] = "Торговцы",
    ["Loot"] = "Добыча",
    ["Interruptions"] = "Помехи",
    ["Display"] = "Отображение",
    ["Chat"] = "Чат",
    ["Tools"] = "Инструменты",

    -- Core/Options.lua
    ["Enable %s"] = "Включить \"%s\"",
    ["Do it"] = "Выполнить",
    ["%s: custom option failed to build: %s"] = "%s: не удалось построить особую настройку: %s",
    ["%s: option %s has an unknown type %q"] = "%s: у настройки %s неизвестный тип %q",
    ["Not in use until another setting here allows it."]
        = "Не используется, пока другая настройка здесь этого не разрешит.",
    ["Not in use until you switch the module on."] = "Не используется, пока модуль не включен.",

    -- Core/Util.lua
    ["%s: function is missing"] = "%s: функция отсутствует",
    ["%s: expected a function, got %s"] = "%s: ожидалась функция, получено: %s",
    ["Error in %s: %s"] = "Ошибка в %s: %s",
    ["%s: this client does not recognize %s. Those features remain unavailable."]
        = "%s: этот клиент не знает %s. Эти функции остаются недоступными.",

    -- Core/Widgets.lua
    ["Select all"] = "Выделить все",
    ["Close"] = "Закрыть",
    ["Paste the text here with Ctrl+V, then press the button below."]
        = "Вставьте сюда с помощью Ctrl+V, затем нажмите кнопку ниже.",
    ["Apply"] = "Применить",
    ["Delete Character Data"] = "Удалить данные персонажа",
    ["Do you really want to delete the data for your character %s from ForeverPlus?"]
        = "Вы действительно хотите удалить из ForeverPlus данные вашего персонажа %s?",
    ["This deletes its gold, its place in the mail list, its profile assignment, its Auto Buy choices, its cooldowns, the notices it has already been shown and the chat saved from its last session. Profiles are shared by all characters and are kept."]
        = "Удаляются его золото, его место в списке почты, его привязка к профилю, его выбор для автопокупки, его таймеры восстановления, уже показанные ему уведомления и чат его последнего сеанса. Профили общие для всех персонажей и остаются.",
    ["Delete"] = "Удалить",
    ["Cancel"] = "Отмена",
    ["ForeverPlus no longer keeps anything about %s."]
        = "ForeverPlus больше не хранит данных персонажа %s.",

    -- Modules/Menu.lua
    ["This window."] = "Данное окно.",
    ["Click the box to turn it on and off."] = "Щелкните по флажку, чтобы включить или отключить.",
    ["Its settings have a tab of their own: |cffffffff%s|r. Click to go there."]
        = "Настройки модуля на отдельной вкладке: |cffffffff%s|r. Щелкните, чтобы перейти туда.",
    ["Click the row to show its settings."] = "Щелкните по строке, чтобы показать настройки модуля.",
    ["This module has nothing to set."] = "У этого модуля нет настроек.",
    ["Gameplay"] = "Игровой процесс",
    ["Gameplay modules are on"] = "Модули игрового процесса включены",
    ["Gameplay modules are off"] = "Модули игрового процесса отключены",
    ["Turning this page off disables every module on it, including the minimap button. Each module keeps its own setting, so turning the page back on restores the previous settings."]
        = "Отключение останавливает все модули этой страницы, включая кнопку у мини-карты. Каждый сохраняет свой переключатель, поэтому при включении страницы вернутся те, что были включены.",
    ["Expand all"] = "Развернуть все",
    ["Collapse all"] = "Свернуть все",
    ["Clear"] = "Очистить",
    ["Search"] = "Поиск",
    ["%s is on"] = "%s: включено",
    ["%s is off"] = "%s: отключено",
    ["Switches everything on this page on or off. The settings are kept."]
        = "Включает или отключает все на этой странице. Настройки сохраняются.",
    ["Language"] = "Язык",
    ["Automatic"] = "Автоматически",
    ["Applies to every character and profile. Automatic uses the game's language, or English if the addon does not support that language. Changes take effect after the next reload."]
        = "Действует для всех персонажей и всех профилей. \"Автоматически\" берет язык игры или английский, если в этой модификации его нет. Изменение вступает в силу при следующей перезагрузке.",
    ["The language changes with the next reload. Reload now?"]
        = "Язык сменится при следующей перезагрузке. Перезагрузить сейчас?",
    ["Reload now"] = "Перезагрузить",
    ["Later"] = "Позже",
    ["Reload UI"] = "Перезагрузка",
    ["This page is switched off. The box on its tab switches it on again, with every setting here as you left it."]
        = "Эта страница отключена. Флажок на ее вкладке снова включает ее, со всеми настройками в том виде, в каком вы их оставили.",
    ["The %s page has no switch on its tab. Give it a switch, or mark it internal if it only arranges the addon."]
        = "У страницы \"%s\" нет переключателя на вкладке. Добавьте переключатель или пометьте ее как внутреннюю, если она лишь настраивает саму модификацию.",
    ["Tab %s failed to build its header: %s"] = "Не удалось построить заголовок вкладки \"%s\": %s",
    ["Tab %s failed to build: %s"] = "Не удалось построить вкладку \"%s\": %s",
    ["The settings window was off screen and has been moved back to the center."]
        = "Окно настроек было за пределами экрана и возвращено в центр.",

    -- The names of the other pages, and the switches on their tabs. The pages
    -- themselves follow in later parts of this file.
    ["Buffs"] = "Баффы",
    ["Buff warnings are on"] = "Предупреждения о баффах включены",
    ["Buff warnings are off"] = "Предупреждения о баффах отключены",
    ["The master switch for this page. Everything on it only decides what it warns about and when.|n|nOff means no icons at all. The settings are kept, so turning it back on restores what you had."]
        = "Главный переключатель этой страницы. Все остальное на ней решает лишь, о чем и когда предупреждать.|n|nОтключено: никаких значков. Настройки сохраняются, поэтому после включения все будет как прежде.",
    ["Consumables"] = "Расходуемые",
    ["Consumable warnings are on"] = "Предупреждения о расходуемых предметах включены",
    ["Consumable warnings are off"] = "Предупреждения о расходуемых предметах отключены",
    ["Tooltip"] = "Подсказки",
    ["Tooltip changes are on"] = "Изменения подсказок включены",
    ["Tooltip changes are off"] = "Изменения подсказок отключены",
    ["Off leaves the client's own tooltip exactly as it was, arrangement and position included. The settings are kept."]
        = "Отключено: подсказка клиента остается в точности такой, какой была, включая расположение строк и позицию. Настройки сохраняются.",
    ["Info bar"] = "Инфопанель",
    ["The info bar is on"] = "Инфопанель включена",
    ["The info bar is off"] = "Инфопанель отключена",
    ["Chat changes are on"] = "Изменения чата включены",
    ["Chat changes are off"] = "Изменения чата отключены",
    ["Off leaves the chat as the client has it. The settings are kept."]
        = "Отключено: чат работает так, как предусмотрено клиентом. Настройки сохраняются.",
    ["Design"] = "Внешний вид",
    ["Profiles"] = "Профили",
    ["Info"] = "Справка",

    -- -----------------------------------------------------------------------
    -- Gameplay
    -- -----------------------------------------------------------------------

    -- Shared by several modules
    ["Hold Shift to pause"] = "Приостанавливать при зажатом Shift",
    ["Shift is held, automation paused."] = "Зажат Shift, автоматика на паузе.",
    ["No merchant open."] = "Окно торговца не открыто.",

    -- Modules/QuestAutoAccept.lua
    ["Auto Accept Quests"] = "Автоматическое принятие заданий",
    ["Also from gossip windows"] = "Также из окон разговора",
    ["Accepts quests offered inside a conversation, not just through the regular quest window."]
        = "Принимает и задания, предложенные в разговоре, а не только в обычном окне задания.",
    ["Confirm shared quests and escorts"] = "Подтверждать переданные задания и сопровождения",
    ["Also accepts quests other players share with you and escort quests. An escort begins the moment it is accepted."]
        = "Также принимает задания, которыми с вами делятся другие игроки, и задания на сопровождение. Сопровождение начинается сразу после принятия задания.",
    ["While Shift is down, nothing is accepted, so you can read the text first."]
        = "Пока зажат Shift, ничего не принимается, на случай если вы хотите сначала прочитать текст.",

    -- Modules/QuestAutoTurnIn.lua
    ["Auto Turn In Quests"] = "Автоматическая сдача заданий",
    ["Hands quests in from inside a conversation as well as from the plain quest window."]
        = "Сдает задания и из разговора, а не только в обычном окне задания.",
    ["While Shift is down, nothing is handed in. Reward values are still shown because they belong to a separate module."]
        = "Пока зажат Shift, ничего не сдается. Стоимость наград все равно показывается, потому что за нее отвечает отдельный модуль.",

    -- Modules/QuestRewardValue.lua
    ["Quest Reward Value"] = "Стоимость наград за задания",
    ["Shows what each quest reward sells for, on every quest window."]
        = "Показывает в каждом окне задания, за сколько продается каждая награда.",
    ["Also on rewards you get anyway"] = "И для наград, которые вы получите в любом случае",
    ["Not only the ones you choose between. Off, and only a real choice carries a price."]
        = "Не только для тех, из которых вы выбираете. Отключено: цена есть только при настоящем выборе.",
    ["QuestRewardValue: could not hook QuestInfo_Display, falling back to the quest events alone."]
        = "Стоимость наград за задания: не удалось подключиться к QuestInfo_Display, остаются только события заданий.",

    -- Modules/GossipAuto.lua
    ["Skip Gossip"] = "Пропуск разговоров",
    ["Clicks past the extra line of talk at vendors, trainers, flight masters, bankers and guild masters."]
        = "Пропускает лишнюю строку разговора у торговцев, учителей, распорядителей полетов, банкиров и регистраторов гильдий.",
    ["Say when an unfamiliar service turns up"] = "Сообщать о незнакомой услуге",
    ["Nothing is clicked in that case. The line tells you the addon encountered an unfamiliar service, and the details are saved so the list can be expanded deliberately. Once per kind of service, not once per NPC."]
        = "В этом случае ничего не нажимается. Строка сообщает, что модификация обнаружила незнакомую услугу, а подробности сохраняются, чтобы список можно было расширить осознанно. Один раз для каждого вида услуг, а не для каждого NPC.",
    ["Say every time a line is clicked"] = "Сообщать о каждом нажатии строки",
    ["Writes a line in your chat each time the addon clicks a gossip line for you."]
        = "Пишет строку в ваш чат каждый раз, когда модификация нажимает за вас строку разговора.",
    ["While Shift is down, nothing is clicked, so you can read what the NPC actually says. Hold Shift and talk again to check whether the addon was skipping a window for you."]
        = "Пока зажат Shift, ничего не нажимается, чтобы вы могли прочитать, что на самом деле говорит NPC. Зажмите Shift и заговорите снова, чтобы проверить, не пропускала ли модификация окно за вас.",
    ["Opened the vendor for you."] = "Окно торговца открыто за вас.",
    ["Opened the trainer for you."] = "Окно учителя открыто за вас.",
    ["Opened the taxi for you."] = "Карта полетов открыта за вас.",
    ["Opened the petition for you."] = "Хартия гильдии открыта за вас.",
    ["Opened the bank for you."] = "Банк открыт за вас.",
    ["Left alone because the service is unfamiliar: icon %s, \"%s\". The details are saved so the list can be expanded deliberately."]
        = "Незнакомая услуга не тронута: значок %s, \"%s\". Записано, чтобы список можно было расширить осознанно.",

    -- Modules/Looting.lua
    ["Fast Auto Loot"] = "Быстрый автообыск",
    ["Loots without the delay, and can roll greed on greens."]
        = "Обыскивает без задержки и может выбирать \"Не откажусь\" для зеленых предметов.",
    ["Loot without the delay"] = "Обыскивать без задержки",
    ["Takes every slot at once instead of waiting for the client to process them one by one. It never decides whether to loot: that stays with your own auto loot setting and its modifier key, and this does nothing at all when the client was not going to loot."]
        = "Забирает все ячейки сразу, не дожидаясь, пока клиент обработает их по одной. Решать, обыскивать ли, не берется: это по-прежнему определяют ваша настройка автообыска и ее клавиша, и если клиент не собирался обыскивать, ничего не происходит.",
    ["Turn on Auto Loot"] = "Включить автообыск",
    ["Turns on the game's own auto loot."] = "Включает автообыск самой игры.",
    ["Rolling"] = "Розыгрыш добычи",
    ["Roll greed on green items"] = "Выбирать \"Не откажусь\" для зеленых предметов",
    ["Rolls greed on every green item automatically."]
        = "Автоматически выбирает \"Не откажусь\" для каждого зеленого предмета.",
    ["Say what was rolled on"] = "Сообщать о разыгранных предметах",
    ["Shows the item in your own chat. Nothing is sent to the group."]
        = "Строка с названием предмета в вашем собственном чате. В группу ничего не отправляется.",
    ["Looting: this client offers no way to set a CVar."]
        = "Быстрый автообыск: этот клиент не позволяет задать CVar.",
    ["The client's auto loot is already on, nothing changed."] = "Автообыск уже включен.",
    ["Looting: the client refused to set autoLootDefault."]
        = "Быстрый автообыск: клиент отказался задать autoLootDefault.",
    ["Looting: autoLootDefault was set but does not report that it is on. Check the client's own options."]
        = "Быстрый автообыск: autoLootDefault задан, но не читается как включенный. Проверьте настройки самого клиента.",
    ["The client's auto loot is now on. That is a client setting, so it stays on whether or not this addon is running."]
        = "Автообыск теперь включен. Это настройка игры, поэтому он остается включенным и без этой модификации.",
    ["Looting: the loot API is missing on this build."]
        = "Быстрый автообыск: в этой версии клиента нет функций для добычи.",
    ["Looting: the roll API is missing on this build."]
        = "Быстрый автообыск: в этой версии клиента нет функций для розыгрыша.",
    ["Rolled greed on %s."] = "Выбрано \"Не откажусь\" для предмета %s.",
    ["a green item"] = "зеленого качества",

    -- Modules/AutoSellGray.lua
    ["Sell Gray Items"] = "Продажа серых предметов",
    ["Sells gray items at any merchant."] = "Продает серые предметы любому торговцу.",
    ["Report earnings in chat"] = "Сообщать выручку в чате",
    ["Shows the total value of sold items in chat."]
        = "Подсчитывает проданное и показывает итог в чате.",
    ["While Shift is down, nothing is sold."] = "Пока зажат Shift, ничего не продается.",
    ["Sold %d gray item for %s%s."] = "Продан %d серый предмет на сумму %s%s.",
    ["Sold %d gray items for %s%s."] = "Продано %d серых предметов на сумму %s%s.",
    ["at least "] = "не менее ",
    ["%d gray item could not be sold."] = "%d серый предмет не удалось продать.",
    ["%d gray items could not be sold."] = "%d серых предметов не удалось продать.",
    ["%d gray item still had a sale pending and could not be checked. Reopen the merchant if it is still there."]
        = "Продажа %d серого предмета еще не завершилась, проверить его не удалось. Откройте окно торговца снова, если предмет еще на месте.",
    ["%d gray items still had a sale pending and could not be checked. Reopen the merchant if they are still there."]
        = "Продажа %d серых предметов еще не завершилась, проверить их не удалось. Откройте окно торговца снова, если они еще на месте.",
    ["AutoSellGray: C_Container.UseContainerItem or C_Timer is missing."]
        = "Продажа серых предметов: отсутствует C_Container.UseContainerItem или C_Timer.",
    ["No gray items in your bags."] = "В сумках нет серых предметов.",
    ["Found %d gray item, selling ..."] = "Найден %d серый предмет, идет продажа...",
    ["Found %d gray items, selling ..."] = "Найдено %d серых предметов, идет продажа...",

    -- Modules/AutoRepair.lua
    ["Auto Repair"] = "Автоматический ремонт",
    ["Repairs your gear at merchants who offer repairs."]
        = "Ремонтирует снаряжение у торговцев, которые это умеют.",
    ["Report the cost in chat"] = "Сообщать стоимость в чате",
    ["Shows the repair cost in chat."]
        = "Показывает в чате, сколько стоил ремонт.",
    ["While Shift is down, nothing is repaired."]
        = "Пока зажат Shift, ничего не ремонтируется.",
    ["AutoRepair: the repair API is missing on this build."]
        = "Автоматический ремонт: в этой версии клиента нет функций ремонта.",
    ["This merchant does not repair."] = "Этот торговец не ремонтирует.",
    ["Nothing to repair."] = "Нечего ремонтировать.",
    ["Repair costs %s, waiting until you can afford it."]
        = "Ремонт стоит %s. Он будет выполнен, когда вам хватит денег.",
    ["Repaired for %s."] = "Отремонтировано за %s.",

    -- Modules/Interruptions.lua
    ["Declines duels and releases your spirit in battlegrounds. Both off until you say so."]
        = "Отклоняет дуэли и покидает тело на полях боя. Оба отключены, пока вы их не включите.",
    ["Decline duels"] = "Отклонять дуэли",
    ["Say who was declined"] = "Сообщать, кому отказано",
    ["Shows the name in your own chat, so you know whose duel request was declined."]
        = "Показывает имя в вашем собственном чате, чтобы вы знали, чей вызов на дуэль был отклонен.",
    ["Battlegrounds"] = "Поля боя",
    ["Release when you die in a battleground"] = "Покидать тело после смерти на поле боя",
    ["Battlegrounds only, never in the world, a dungeon or a raid. It does not release when the client offers you a resurrection of your own. This build cannot check for a soulstone, so the delay is the only safeguard."]
        = "Только на полях боя, никогда в мире, подземелье или рейде. Ничего не делает, когда клиент предлагает вам собственное воскрешение, но в этой версии клиента нельзя узнать о камне души, поэтому от этого защищает только ожидание.",
    ["Wait before releasing"] = "Ждать, прежде чем покинуть тело",
    ["Time for a Druid to resurrect you or for a soulstone to do so. Zero releases immediately."]
        = "Время, за которое вас может воскресить друид или камень души. При нуле тело покидается сразу.",
    ["at once"] = "сразу",
    ["%d s"] = "%d сек.",
    ["While Shift is down, neither of these acts."]
        = "Пока зажат Shift, ни то ни другое не срабатывает.",
    ["Interruptions: CancelDuel is missing on this build."]
        = "Помехи: в этой версии клиента нет CancelDuel.",
    ["Declined a duel from %s."] = "Отклонен вызов на дуэль: %s.",
    ["somebody"] = "кто-то",
    ["Not releasing: the client is offering you a resurrection."]
        = "Тело не покидается: клиент предлагает вам воскрешение.",
    ["Interruptions: RepopMe is missing on this build."]
        = "Помехи: в этой версии клиента нет RepopMe.",

    -- Modules/ErrorFilter.lua
    ["Error Filter"] = "Фильтр ошибок",
    ["Hides the red spam errors."] = "Скрывает назойливые красные ошибки.",
    ["Hide every error (not quest progress)"] = "Скрывать все ошибки (кроме хода заданий)",
    ["Hides every red error. Quest progress and other yellow notices stay visible."]
        = "Скрывает все красные ошибки. Ход заданий и другие желтые уведомления остаются видны.",
    ["Or Choose Them Individually"] = "Или выбрать по отдельности",
    ["These settings are ignored while every error is hidden. Turn off the switch above to choose errors individually."]
        = "Сейчас скрываются все ошибки, поэтому это не учитывается. Отключите переключатель выше, чтобы выбирать их по одной.",
    ["Only used while the switch above is off."]
        = "Учитывается, только пока общий переключатель выше отключен.",
    ["Not enough mana / rage / energy"] = "Недостаточно маны / ярости / энергии",
    ["Hides the errors about not enough mana, rage or energy."]
        = "Скрывает ошибки о нехватке маны, ярости или энергии.",
    ["Ability is not ready yet"] = "Способность пока недоступна",
    ["Hides the errors about an ability that is not ready yet."]
        = "Скрывает ошибки о том, что способность пока недоступна.",
    ["Out of range / too far away"] = "Вне зоны действия / Вы слишком далеко",
    ["Hides the errors about being out of range or too far away."]
        = "Скрывает ошибки о том, что цель вне зоны действия или слишком далеко.",
    ["Facing the wrong way"] = "Вы смотрите мимо цели",
    ["Hides the errors about facing the wrong way."]
        = "Скрывает ошибки о том, что вы смотрите мимо цели.",
    ["Invalid target"] = "Нельзя применить к этой цели",
    ["Hides the errors about an invalid target."] = "Скрывает ошибки о неверной цели.",
    ["Log hidden messages to chat (for tuning)"] = "Выводить скрытое в чат (для настройки)",
    ["Shows what was filtered, so you can tell whether something is being hidden that you wanted to see."]
        = "Показывает отфильтрованное, чтобы вы видели, не скрывается ли то, что вы хотели видеть.",
    ["ErrorFilter: this build reports no message color, so 'hide all' stays off to avoid swallowing quest progress. The individual categories still work."]
        = "Фильтр ошибок: эта версия клиента не сообщает цвет сообщений, поэтому \"скрывать все\" остается отключенным, чтобы не пропадал ход заданий. Отдельные категории продолжают работать.",
    ["ErrorFilter: UIErrorsFrame has no filterable method on this build, nothing is hidden."]
        = "Фильтр ошибок: в этой версии клиента у UIErrorsFrame нет метода для фильтрации, ничего не скрывается.",
    ["ErrorFilter: this build knows none of the strings for %s, that category does nothing."]
        = "Фильтр ошибок: этой версии клиента неизвестен ни один текст для категории \"%s\", она ничего не делает.",
    ["ErrorFilter is on, but every category is off. Nothing is being hidden."]
        = "Фильтр ошибок включен, но все категории отключены, ничего не скрывается.",

    -- Modules/XPBarText.lua
    ["Experience Bar Text"] = "Индикатор опыта",
    ["Keeps the experience bar text visible."] = "Текст на полосе опыта всегда остается видимым.",
    ["XPBarText: this build has no '%s' setting. Run /fplus discover: the experience bar's structure is saved in SavedVariables, so the fallback can be built against it."]
        = "Индикатор опыта: в этой версии клиента нет настройки \"%s\". Выполните /fplus discover: устройство полосы опыта попадет в SavedVariables, чтобы по нему можно было собрать замену.",
    ["Experience bar text is now always visible."] = "Текст на полосе опыта теперь всегда виден.",
    ["XPBarText: '%s' exists but could not be set."]
        = "Индикатор опыта: \"%s\" существует, но задать не удалось.",

    -- Modules/BagSlots.lua
    ["Free Bag Slots"] = "Свободные ячейки сумок",
    ["Shows on the backpack how many bag slots are free. Special bags are shown separately."]
        = "Показывает на рюкзаке, сколько ячеек в сумках свободно. Особые сумки показываются отдельно.",
    ["Show the total as well"] = "Показывать и общее число",
    ["Shows 14/80 instead of 14."] = "Показывает 14/80 вместо 14.",
    ["BagSlots: %s is missing on this build, so there is nowhere to write the count."]
        = "Свободные ячейки сумок: в этой версии клиента нет %s, поэтому число негде показать.",
    ["BagSlots: C_Container does not offer the slot counts on this build."]
        = "Свободные ячейки сумок: в этой версии клиента C_Container не сообщает число ячеек.",

    -- Modules/Ammunition.lua
    ["Ammunition"] = "Боеприпасы",
    ["Ammunition Warning"] = "Предупреждение о боеприпасах",
    ["For Hunters: shows how much ammunition you carry, on your quiver or backpack, with a short warning when it runs low."]
        = "Для охотников: сколько у вас боеприпасов, на значке колчана или, без него, на рюкзаке, и короткое предупреждение, когда они на исходе.",
    ["Hunters only"] = "Только охотники",
    ["Warn when it runs low"] = "Предупреждать, когда на исходе",
    ["A short red line in the upper middle of the screen, once when your ammunition drops below the amount set here. It appears again only after you restock above that amount. While this is on, the count itself turns red below the threshold."]
        = "Короткая красная строка вверху посередине экрана, один раз, когда боеприпасов становится меньше заданного здесь количества. Она появится снова, только когда вы пополните запас выше него. Пока это включено, само число тоже становится красным ниже этого количества.",
    ["Warn below"] = "Предупреждать ниже",
    ["The ammunition count below which the warning appears."]
        = "Количество боеприпасов, ниже которого появляется предупреждение.",
    ["Play a sound with it"] = "Сопровождать звуком",
    ["Plays the sound selected below along with the red warning."]
        = "Звук, выбранный ниже, вместе с красной строкой.",
    ["Sound"] = "Звук",
    ["Picks one of the game's own sounds."] = "Выбирает один из звуков самой игры.",
    ["Play the sound"] = "Воспроизвести звук",
    ["Plays the selected sound now."] = "Воспроизводит выбранный звук сейчас.",
    ["Show the warning"] = "Показать предупреждение",
    ["Shows the warning once, with its sound when that is on."]
        = "Показывает предупреждение один раз, со звуком, если он включен.",
    ["Ammunition: this client has no sound called %s."]
        = "Боеприпасы: в этом клиенте нет звука %s.",
    ["Low on ammunition: %d left"] = "Боеприпасы на исходе: осталось %d",
    ["Adds a button for each kind of ammunition beside merchants who sell it. A click buys as many as your quiver or ammo pouch can still hold."]
        = "Рядом с торговцем, продающим стрелы или пули, кнопка для каждого вида. Щелчок покупает столько, сколько еще вмещает ваш колчан или подсумок.",
    ["Skip the purchase dialog"] = "Пропускать подтверждение покупки",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Ammunition you cannot use yet always shows the dialog."]
        = "Щелчок по кнопке рядом с торговцем сразу покупает и сообщает в чате, что было куплено. Для боеприпасов, которые вы пока не можете использовать, подтверждение показывается всегда.",
    ["Fills your quiver with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Автоматически пополняет ими колчан, когда вы открываете торговца, который их продает. Только один вид за раз.",
    ["Fills your ammo pouch with these automatically whenever you open a merchant who sells them. One kind at a time."]
        = "Автоматически пополняет ими подсумок, когда вы открываете торговца, который их продает. Только один вид за раз.",
    ["You cannot use these before level %d."] = "Их можно использовать только с уровня %d.",
    ["You cannot use these yet."] = "Вы пока не можете их использовать.",
    ["Fill the Quiver"] = "Пополнить колчан",
    ["Do not ask again"] = "Больше не спрашивать",
    ["Switches on \"Skip the purchase dialog\" under Ammunition on the Gameplay page, where it can be switched off again."]
        = "Включает \"Пропускать подтверждение покупки\" в разделе \"Боеприпасы\" на странице \"Игровой процесс\", где это можно снова отключить.",
    ["Buy"] = "Купить",
    ["Fill the Ammo Pouch"] = "Пополнить подсумок",
    ["Do you really want to buy %d %s to fill your quiver?"]
        = "Вы действительно хотите купить %d шт. %s, чтобы пополнить колчан?",
    ["Do you really want to buy %d %s to fill your ammo pouch?"]
        = "Вы действительно хотите купить %d шт. %s, чтобы пополнить подсумок?",
    ["Cost: %s"] = "Стоимость: %s",
    ["No more will fit in your quiver."] = "В колчан больше ничего не поместится.",
    ["No more will fit in your ammo pouch."] = "В подсумок больше ничего не поместится.",
    ["The merchant has none left."] = "У торговца их больше нет.",
    ["You cannot afford a stack."] = "Вам не хватает денег на стопку.",
    ["Buy this one in the merchant window."] = "Эти покупайте в окне торговца.",
    ["Your quiver cannot hold bullets."] = "Ваш колчан не принимает пули.",
    ["Your ammo pouch cannot hold arrows."] = "Ваш подсумок не принимает стрелы.",
    ["Waiting for the previous purchase to complete."] = "Ожидание завершения предыдущей покупки.",
    ["Buying from the merchant failed: %s"] = "Не удалось купить у торговца: %s",
    ["Reagents"] = "Реагенты",
    ["Beside a merchant, a button for each reagent your class uses and, for Rogues, each poison. A click buys what is missing for the amounts set here."]
        = "Рядом с торговцем кнопка для каждого реагента вашего класса, а у разбойников также кнопка для каждого яда. Щелчок покупает то, чего не хватает до заданного здесь количества.",
    ["A click on a button beside the merchant buys at once and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Щелчок по кнопке рядом с торговцем сразу покупает и сообщает в чате, что было куплено. Пока вашим классовым способностям не нужны реагенты от торговца, для реагентов подтверждение показывается всегда.",
    ["%s is active: your class abilities need no reagents bought from a merchant."]
        = "Действует %s: вашим классовым способностям не нужны реагенты от торговца.",
    ["How many you want to carry. A Shift click changes it by a full stack."]
        = "Сколько вы хотите носить с собой. Щелчок с Shift прибавляет или убавляет полную стопку.",
    ["Changes how many you want to carry, the same amount as under Reagents on the Gameplay page."]
        = "Меняет, сколько вы хотите носить с собой, то же число, что в разделе \"Реагенты\" на странице \"Игровой процесс\".",
    ["Your class uses no reagents."] = "Ваш класс не использует реагенты.",
    ["None of your spells that require reagents have been learned yet."]
        = "Вы еще не выучили ни одного заклинания, которому нужен реагент.",
    ["Not Relevant Right Now"] = "Сейчас неактуально",
    ["Auto Buy"] = "Автопокупка",
    ["Buys what you tick for it whenever you open a merchant who sells it: reagents and poisons up to their amounts, arrows or bullets as many as fit in your quiver or ammo pouch."]
        = "Покупает то, что вы для этого отметили, когда вы открываете торговца, который это продает: реагенты и яды до заданного числа, стрелы или пули столько, сколько поместится в колчан или подсумок.",
    ["Skip the auto buy dialog"] = "Пропускать подтверждение автопокупки",
    ["Buys without asking first and reports the purchase in chat. Reagents always show the dialog when your class abilities do not require reagents from a merchant."]
        = "Покупает, не спрашивая, и сообщает в чате, что было куплено. Пока вашим классовым способностям не нужны реагенты от торговца, для реагентов подтверждение показывается всегда.",
    ["Buy Automatically"] = "Автоматическая покупка",
    ["Buy everything ticked for buying automatically?"]
        = "Купить все, что отмечено для автопокупки?",
    ["Switches on \"Skip the auto buy dialog\" under Auto Buy on the Gameplay page, where it can be switched off again."]
        = "Включает \"Пропускать подтверждение автопокупки\" в разделе \"Автопокупка\" на странице \"Игровой процесс\", где это можно снова отключить.",
    ["Buys it automatically up to this amount whenever you open a merchant who sells it."]
        = "Автоматически докупает до этого числа, когда вы открываете торговца, который это продает.",
    ["You have %d of %d."] = "У вас %d из %d.",
    ["Click to buy %d."] = "Щелкните, чтобы купить %d шт.",
    ["Click to buy the ingredients for %d."] = "Щелкните, чтобы купить ингредиенты для %d шт.",
    ["You have enough."] = "У вас достаточно.",
    ["Just bought."] = "Только что куплено.",
    ["You cannot afford the ingredients."] = "Вам не хватает денег на ингредиенты.",
    ["Buy the ingredients in the merchant window."] = "Ингредиенты покупайте в окне торговца.",
    ["Buy Reagents"] = "Покупка реагентов",
    ["Do you really want to buy %d %s? You will then have %d."]
        = "Вы действительно хотите купить %d шт. %s? Тогда у вас будет %d.",
    ["Buy Poison Ingredients"] = "Покупка ингредиентов для ядов",
    ["Do you really want to buy the ingredients for %d %s?"]
        = "Вы действительно хотите купить ингредиенты для %d шт. %s?",
    ["Switches on \"Skip the purchase dialog\" under Reagents on the Gameplay page, where it can be switched off again."]
        = "Включает \"Пропускать подтверждение покупки\" в разделе \"Реагенты\" на странице \"Игровой процесс\", где это можно снова отключить.",
    ["Bought %d %s for %s."] = "Куплено %d шт. %s за %s.",
    ["Bought the ingredients for %d %s for %s."] = "Куплены ингредиенты для %d шт. %s за %s.",
    ["Click to buy %d and fill your quiver."] = "Щелкните, чтобы купить %d шт. и пополнить колчан.",
    ["Click to buy %d and fill your ammo pouch."]
        = "Щелкните, чтобы купить %d шт. и пополнить подсумок.",
    ["Bought %d %s for %s to fill your quiver."]
        = "Куплено %d шт. %s за %s, чтобы пополнить колчан.",
    ["Bought %d %s for %s to fill your ammo pouch."]
        = "Куплено %d шт. %s за %s, чтобы пополнить подсумок.",

    -- Modules/BagWindow.lua
    ["Movable Bag Windows"] = "Перемещаемые окна сумок",
    ["Hold Shift and drag the bag window by its title bar to move it, while your bags are combined into one window."]
        = "Зажмите Shift и перетащите окно сумок за заголовок, чтобы переместить его, пока ваши сумки объединены в одно окно.",
    ["Reset position"] = "Сброс позиции",
    ["Puts the bag window back where the game places it."]
        = "Возвращает окно сумок на место по умолчанию.",
    ["Bag window is back where the game places it."]
        = "Окно сумок возвращено на место по умолчанию.",
    ["BagWindow: this build has no combined bag window, so there is nothing to move."]
        = "Перемещаемые окна сумок: в этой версии клиента нет объединенного окна сумок, перемещать нечего.",

    -- Modules/MinimapButton.lua
    ["Minimap Button"] = "Кнопка у мини-карты",
    ["A button on the edge of the minimap that opens this window. Drag it to move it along the edge."]
        = "Кнопка на краю мини-карты, открывающая это окно. Перетащите ее, чтобы передвинуть вдоль края.",
    ["MinimapButton: this build has no minimap to put a button on. /fplus opens the settings."]
        = "Кнопка у мини-карты: в этой версии клиента нет мини-карты для кнопки. /fplus открывает настройки.",
    ["Click to open or close the settings."] = "Щелкните, чтобы открыть или закрыть настройки.",
    ["Drag to move this button along the edge of the minimap."]
        = "Перетащите, чтобы передвинуть эту кнопку вдоль края мини-карты.",

    -- Modules/MailAlts.lua
    ["Alts in the Mail Window"] = "Окно почты: ваши персонажи",
    ["Adds a button to the mail window that lists your characters of this ruleset and faction, and fills in the one you pick."]
        = "Добавляет в окно почты кнопку со списком ваших персонажей этого типа игрового мира и этой фракции и вписывает выбранного.",
    ["No other character of this ruleset and faction is known yet. Each one is added the next time it logs in."]
        = "Пока не известен ни один другой персонаж этого типа игрового мира и этой фракции. Новый персонаж добавится при следующем входе в игру.",
    ["Your Characters"] = "Ваши персонажи",
    ["Your characters of this ruleset and faction. A click fills in the name, the X at the end of a row deletes the character."]
        = "Ваши персонажи этого типа игрового мира и этой фракции. Щелчок вписывает имя, X в конце строки удаляет персонажа.",

    -- Modules/QuestZoneTracking.lua
    ["Track Zones in the Quest Log"] = "Отслеживание зон в журнале заданий",
    ["Adds a checkbox to every zone in the quest log to track or untrack all its quests with one click."]
        = "Добавляет каждой зоне в журнале заданий флажок, который одним щелчком отслеживает все ее задания или снимает их с отслеживания.",
    ["Track All"] = "Отслеживать все",
    ["Untrack All"] = "Снять все с отслеживания",
    ["QuestZoneTracking: could not hook QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Отслеживание зон в журнале заданий: не удалось подключиться к QuestLogQuests_Update, поэтому флажков в журнале заданий не будет.",
    ["QuestZoneTracking: this client has no QuestLogQuests_Update, so the quest log gets no checkboxes."]
        = "Отслеживание зон в журнале заданий: в этом клиенте нет QuestLogQuests_Update, поэтому флажков в журнале заданий не будет.",

    -- Modules/Diagnostics.lua
    ["Diagnostics"] = "Диагностика",
    ["Measures what this client's API offers. Use it to diagnose problems: the report lists what exists and what does not, for whoever fixes the addon."]
        = "Измеряет, что предлагает API этого клиента. Помогает диагностировать проблемы: отчет перечисляет, что есть и чего нет, для того, кто исправляет модификацию.",
    ["Keep the report in the saved settings"] = "Хранить отчет в сохраненных настройках",
    ["Saves the report, about nine hundred lines, in your saved settings. /fplus diag print reads the current one without saving it."]
        = "Сохраняет отчет, около девятисот строк, в сохраненных настройках. /fplus diag print читает текущий отчет, не сохраняя его.",

    -- -----------------------------------------------------------------------
    -- Design
    -- -----------------------------------------------------------------------

    -- Modules/Theme.lua
    ["Sets the appearance of the ForeverPlus windows."] = "Как выглядят окна ForeverPlus.",
    ["Color scheme"] = "Цветовая схема",
    ["Applies to the ForeverPlus windows only."] = "Действует только на окна ForeverPlus.",
    ["Show switches in your class color"] = "Показывать переключатели в цвете вашего класса",
    ["The switches that are on and the open tab take the color of this character's class, in every color scheme."]
        = "Включенные переключатели и открытая вкладка принимают цвет класса этого персонажа, в любой цветовой схеме.",
    ["Background opacity"] = "Непрозрачность фона",
    ["Sets the background opacity of the ForeverPlus windows, the info bar and the addon's tooltips. At 100 percent, it matches the color scheme."]
        = "Фон окон ForeverPlus, инфопанели и собственных подсказок модификации. При 100 процентах: фон самой цветовой схемы.",
    ["Text size"] = "Размер текста",
    ["Sets the text size as a percentage of the game's text size."] = "Процент от собственного размера текста игры.",

    -- Core/Theme.lua
    ["Midnight"] = "Полночь",
    ["Slate"] = "Сланец",
    ["High contrast"] = "Высокий контраст",
    ["Horde"] = "Орда",
    ["Gilded"] = "Позолота",
    ["Autumn"] = "Осень",
    ["Jade"] = "Нефрит",
    ["Arctic"] = "Арктика",
    ["Azure"] = "Лазурь",
    ["Alliance"] = "Альянс",
    ["Sunset"] = "Закат",

    -- -----------------------------------------------------------------------
    -- Profiles
    -- -----------------------------------------------------------------------

    -- Modules/Profiles.lua
    ["in use"] = "используется",
    ["The buttons below act on: |cffffffff%s|r"] = "Кнопки ниже действуют на: |cffffffff%s|r",
    ["... and %d more, see /fplus profile"] = "... и еще %d, см. /fplus profile",
    ["Use"] = "Использовать",
    ["Now using %s."] = "Теперь используется %s.",
    ["Reset"] = "Сброс",
    ["Sure?"] = "Точно?",
    ["%s is back to its defaults."] = "Профиль %s сброшен к значениям по умолчанию.",
    ["%s deleted."] = "Профиль %s удален.",
    ["Name for a new or renamed profile"] = "Имя для нового или переименованного профиля",
    ["New"] = "Новый",
    ["Created %s."] = "Создан профиль %s.",
    ["Copy"] = "Копировать",
    ["%s copied from %s."] = "Профиль %s скопирован из профиля %s.",
    ["Rename"] = "Переименовать",
    ["%s is now %s."] = "Профиль %s теперь называется %s.",
    ["Export"] = "Экспорт",
    ["Export profile"] = "Экспорт профиля",
    ["%s, %d characters"] = "%s, символов: %d",
    ["Import"] = "Импорт",
    ["Import profile"] = "Импорт профиля",
    ["Paste a string, then press Import"] = "Вставьте текст и нажмите \"Импорт\"",
    ["Import failed: %s"] = "Ошибка импорта: %s",
    ["Imported as %s, %d skipped."] = "Импортирован как %s, пропущено: %d.",
    ["Imported as %s."] = "Импортирован как %s.",
    ["%d profile now."] = "Теперь %d профиль.",
    ["%d profiles now."] = "Теперь %d профилей.",

    -- Core/Config.lua
    ["Settings were written by a newer version (format %d, this build reads %d). Leaving them unchanged."]
        = "Настройки записаны более новой версией (формат %d, эта версия читает %d). Они остаются без изменений.",
    ["No way to convert settings from format %d to %d."]
        = "Невозможно перевести настройки из формата %d в формат %d.",
    ["migration %d to %d"] = "переход с %d на %d",
    ["Settings stayed at format %d."] = "Настройки остались в формате %d.",
    ["Settings converted to format %d."] = "Настройки переведены в формат %d.",
    ["No character given"] = "Персонаж не указан",
    ["That is the character you are playing"] = "Это персонаж, которым вы играете",
    ["Could not identify this character, so %s is in use. A /reload should fix it."]
        = "Не удалось определить этого персонажа, поэтому используется %s. Это должна исправить команда /reload.",
    ["%s is off. Takes effect after /reload."] = "%s: отключено. Вступит в силу после /reload.",
    ["Unknown module: %s"] = "Неизвестный модуль: %s",
    ["%s: /reload needed for the change to take effect."]
        = "%s: изменение вступит в силу после /reload.",
    ["A profile needs a name"] = "У профиля должно быть имя",
    ["Profile names are limited to %d characters"] = "Максимальная длина имени профиля: %d",
    ["A profile name cannot contain a pipe or a control character"]
        = "Имя профиля не может содержать вертикальную черту или управляющий символ",
    ["A profile called %s already exists"] = "Профиль с именем %s уже существует",
    ["No profile called %s exists"] = "Профиля с именем %s нет",
    ["%s is the only profile. Reset it instead of deleting it"]
        = "профиль %s единственный: сбросьте его, а не удаляйте",
    ["Profile %s takes effect when you leave combat."]
        = "Профиль %s вступит в силу, когда вы выйдете из боя.",
    ["Profile %s disappeared before it could be applied."]
        = "Профиль %s исчез, прежде чем его удалось применить.",
    ["%s: /reload needed before its new settings apply."]
        = "%s: новые настройки вступят в силу после /reload.",
    ["Profile: %s"] = "Профиль: %s",
    ["that string is not a ForeverPlus profile"] = "этот текст не является профилем ForeverPlus",
    ["that profile has no readable settings in it"] = "в этом профиле нет читаемых настроек",
    ["import migration %d to %d"] = "переход при импорте с %d на %d",
    ["the settings being saved are not the ones in this table. The import was undone to prevent silent data loss. Please report this"]
        = "таблица настроек не та, что сохраняется: импорт отменен, чтобы предотвратить незаметную потерю данных. Пожалуйста, сообщите об этом",
    ["the profile was not saved successfully. Please report this"]
        = "не удалось успешно сохранить профиль. Пожалуйста, сообщите об этом",

    -- Core/Serialize.lua
    ["nested too deeply"] = "слишком глубокая вложенность",
    ["the string ends before a value is complete"] = "текст обрывается посреди значения",
    ["a string is missing its length"] = "для строки не указана длина",
    ["a string has an invalid length"] = "у строки неверная длина",
    ["a string extends beyond the end of the data"] = "строка выходит за пределы данных",
    ["a number has no terminating marker"] = "у числа отсутствует завершающий маркер",
    ["a number is not a number"] = "число не является числом",
    ["a boolean is neither true nor false"] = "логическое значение не истинно и не ложно",
    ["a table is missing its size"] = "для таблицы не указан размер",
    ["a table has an invalid size"] = "у таблицы неверный размер",
    ["a table specifies more entries than the string contains"]
        = "таблица заявляет больше записей, чем содержит текст",
    ["unknown marker at position %d"] = "неизвестная метка в позиции %d",
    ["nothing to import"] = "нечего импортировать",
    ["this does not look like a ForeverPlus string"] = "это не похоже на текст ForeverPlus",
    ["this string is version %s, but this build reads %s"] = "версия этого текста: %s, а модификация читает версию %s",
    ["the string is damaged or incomplete (%d characters received). If you pasted it, it may have been truncated. Paste it again and check that the end matches"]
        = "текст поврежден или неполон (получено символов: %d). Если его вставляли, он мог обрезаться: вставьте его снова и проверьте, совпадает ли конец",
    ["unexpected text after the end of the data"]
        = "после конца данных идет неожиданный текст",

    -- -----------------------------------------------------------------------
    -- Info
    -- -----------------------------------------------------------------------

    -- Modules/Info.lua
    ["All rights reserved"] = "Все права защищены",
    ["About"] = "О модификации",
    ["Author"] = "Автор",
    ["License"] = "Лицензия",
    ["Client"] = "Клиент",
    ["Contact"] = "Контакты",
    ["Leave ideas and bug reports in the comments on CurseForge"]
        = "Оставляйте идеи и сообщения об ошибках в комментариях на CurseForge",
    ["Free to use, but not open source. You may not redistribute it, publish modified versions or reuse it in other addons. Provided without warranty. See the LICENSE file for the full terms."]
        = "Можно пользоваться бесплатно, но исходный код не открыт: модификацию нельзя распространять, изменять и публиковать или повторно использовать в других модификациях. Предоставляется без гарантий. Полные условия в файле LICENSE.",

    -- -----------------------------------------------------------------------
    -- Info bar
    -- -----------------------------------------------------------------------

    -- Modules/InfoBar.lua
    ["Shows an info bar with your gold, durability, coordinates, latency and more."]
        = "Показывает инфопанель с вашим золотом, прочностью, координатами, задержкой и другими данными.",
    ["What It Shows"] = "Что показывается",
    ["Allow reordering"] = "Разрешить менять порядок",
    ["Drag the entries above to change their order on the info bar."]
        = "Перетаскивайте записи выше, чтобы изменить их порядок на инфопанели.",
    ["Restore default order"] = "Восстановить порядок",
    ["Puts the entries back in their default order, here and on the info bar."]
        = "Возвращает записям порядок по умолчанию, здесь и на инфопанели.",
    ["Time"] = "Время",
    ["The time of day, as the game's own clock shows it."]
        = "Время суток, как его показывают часы игры.",
    ["Shows"] = "Показывать",
    ["Local time"] = "Местное время",
    ["Realm time"] = "Серверное время",
    ["Choose local or realm time for both this bar and the minimap clock."]
        = "Выберите местное или серверное время для этой инфопанели и часов у мини-карты.",
    ["Choose a 12 or 24 hour format for both this bar and the minimap clock."]
        = "Выберите формат в 12 или 24 часа для этой инфопанели и часов у мини-карты.",
    ["Format"] = "Формат",
    ["24 hours"] = "24 часа",
    ["12 hours"] = "12 часов",
    ["Hearthstone"] = "Камень возвращения",
    ["Where your Hearthstone takes you and how long until it is ready."]
        = "Куда вас перенесет камень возвращения и сколько осталось до его готовности.",
    ["Gold"] = "Золото",
    ["Adds up each selected character's gold as of their last login."]
        = "Суммирует золото выбранных ниже персонажей на момент последнего входа каждого из них.",
    ["Characters"] = "Персонажи",
    ["Whose gold the display adds up. Its list shows every character, the ones not counted grayed out. A ruleset is, for example, Normal or PvP."]
        = "Чье золото учитывает показатель. В его списке все персонажи, неучтенные показаны серым. Примеры типов игрового мира: Обычный и PvP.",
    ["All"] = "Все",
    ["This ruleset and faction"] = "Этот тип игрового мира и эта фракция",
    ["Only this one"] = "Только этот",
    ["This ruleset"] = "Этот тип игрового мира",
    ["Hide characters not counted"] = "Скрывать неучтенных персонажей",
    ["PvE"] = "PvE",
    ["PvP"] = "PvP",
    ["The list on hover leaves out the characters the display does not count."]
        = "Список при наведении не показывает персонажей, которых показатель не учитывает.",
    ["Shown as"] = "Вид",
    ["Shows one display for all bags, with a breakdown by bag type on hover, or one display per bag type, with its name on hover."]
        = "Один показатель для всех сумок с разбивкой по типам при наведении или отдельный показатель для каждого типа сумок с названием при наведении.",
    ["One display"] = "Один показатель",
    ["A display per kind of bag"] = "Показатель для каждого типа сумок",
    ["Ordinary bags"] = "Обычные сумки",
    ["Special bag"] = "Особая сумка",
    ["Merchant's Favor"] = "Торговое обязательство",
    ["How much Merchant's Favor this character has. Red once it holds as much as the game allows."]
        = "Сколько валюты \"Торговое обязательство\" у этого персонажа. Красным, когда ее столько, сколько позволяет игра.",
    ["Honor Points"] = "Очки чести",
    ["How many Honor Points this character has. Red once it holds as much as the game allows."]
        = "Сколько очков чести у этого персонажа. Красным, когда их столько, сколько позволяет игра.",
    ["Volume"] = "Громкость",
    ["Shows the game's master volume. Hover over the display to adjust it with a slider. The speaker is crossed out while sound is disabled or the volume is at 0%, and the figure turns red while sound is disabled."]
        = "Общая громкость игры. Наведите на нее указатель, чтобы изменить ее ползунком. Динамик перечеркнут, пока звук отключен или громкость равна 0%. Число становится красным, пока звук отключен.",
    ["Master Volume"] = "Общая громкость",
    ["Cooldowns"] = "Восстановление",
    ["Shows the profession cooldowns and %s for all your characters. Hover over the icon to see the time remaining."]
        = "Показывает время восстановления способностей профессий и способности \"%s\" у всех ваших персонажей. Наведите указатель на значок, чтобы увидеть оставшееся время.",
    ["Ready"] = "Готово",
    ["%d d %d h"] = "%d д. %d ч.",
    ["%d h %d min"] = "%d ч. %d мин.",
    ["None of your characters has one yet."] = "Пока ни у одного из ваших персонажей их нет.",
    ["Elemental Transmutes"] = "Трансмутации стихий",
    ["Durability"] = "Прочность",
    ["Shows the lowest durability among your equipped items."]
        = "Самая низкая прочность среди надетых предметов.",
    ["Coordinates"] = "Координаты",
    ["Where you are in the current zone."] = "Где вы находитесь в текущей зоне.",
    ["Zone"] = "Зона",
    ["Shows your current zone and subzone in the minimap's colors."]
        = "Зона, в которой вы находитесь, и место в ней, в цветах мини-карты.",
    ["%s: %s"] = "%s: %s",
    ["Latency"] = "Задержка",
    ["Frames per second"] = "Кадров в секунду",
    ["Placement"] = "Расположение",
    ["Position on screen"] = "Положение на экране",
    ["Back to the default near the top of the screen."]
        = "Обратно на место по умолчанию у верхнего края экрана.",
    ["%d ms"] = "%d мс",
    ["%d fps"] = "%d к/сек",
    ["No Hearthstone"] = "Нет камня возвращения",
    ["%sk xp/h"] = "%s тыс. опыта/ч",
    ["%d xp/h"] = "%d опыта/ч",
    ["%s h to level"] = "%s ч до уровня",
    ["%d min to level"] = "%d мин. до уровня",
    ["Info bar: this client build does not recognize currency %d, so %s stays empty."]
        = "Инфопанель: этой версии клиента неизвестна валюта %d, поэтому поле \"%s\" остается пустым.",
    ["Maximum"] = "Максимум",
    ["This session"] = "Этот сеанс",
    ["Repair cost"] = "Стоимость ремонта",
    ["Experience per hour"] = "Опыт в час",
    ["Time to the next level"] = "Время до следующего уровня",
    ["Info bar is back at its default position."] = "Инфопанель возвращена на место по умолчанию.",
    ["Info bar can be dragged. Press the button again when it is where you want it."]
        = "Инфопанель можно перетаскивать. Нажмите кнопку снова, когда она будет на нужном месте.",
    ["Info bar is fixed again."] = "Инфопанель снова закреплена.",
    ["Click to use it"] = "Щелкните, чтобы использовать",
    ["Info bar: this client build cannot provide %s, so those entries stay empty regardless of their settings."]
        = "Инфопанель: эта версия клиента не может предоставить %s. Эти поля остаются пустыми при любых настройках.",
    ["Use it with a click"] = "Использовать щелчком",
    ["A click on the display uses your Hearthstone."]
        = "Щелчок по этому показателю использует ваш камень возвращения.",
    ["Move it with Shift and drag"] = "Перемещать перетаскиванием с Shift",
    ["While Shift is held, you can drag the bar by any display, and clicking the Hearthstone does not use it."]
        = "Пока зажат Shift, панель можно перетаскивать за любой из ее показателей. Щелчок по камню возвращения на панели при этом его не использует.",

    -- -----------------------------------------------------------------------
    -- Tooltip
    -- -----------------------------------------------------------------------

    -- Modules/Tooltip.lua
    ["Extra lines in the game tooltip, and where the tooltip appears."]
        = "Дополнительные строки в подсказке игры и угол, в котором она находится.",
    ["General"] = "Общие",
    ["Add extra information"] = "Добавлять дополнительные сведения",
    ["The lines this addon adds. The arrangement and the position still work while this is off."]
        = "Строки, которые пишет сама модификация. Если отключено, расположение строк и позиция продолжают работать.",
    ["Not in use until you switch extra information on."]
        = "Не используется, пока дополнительные сведения не включены.",
    ["Layout"] = "Компоновка",
    ["How the lines are arranged"] = "Как расположены строки",
    ["Blizzlike"] = "Как у Blizzard",
    ["One per line"] = "По одной в строке",
    ["Compact"] = "Компактно",
    ["Blizzlike keeps the client's lines in their original order and adds the rest underneath. One per line gives every entry its own line. Compact pairs entries up."]
        = "\"Как у Blizzard\" сохраняет строки клиента в их порядке и добавляет остальное ниже. \"По одной в строке\" дает каждому пункту отдельную строку. \"Компактно\" объединяет их попарно.",
    ["Where it appears"] = "Где она появляется",
    ["Default"] = "По умолчанию",
    ["Top left"] = "Вверху слева",
    ["Top right"] = "Вверху справа",
    ["Bottom left"] = "Внизу слева",
    ["Default leaves the tooltip where the client puts it. The other options pin it to the chosen corner, and it grows inward."]
        = "\"По умолчанию\" оставляет подсказку там, где ее размещает клиент. Остальные три закрепляют ее в этом углу, и она растет внутрь.",
    ["Lines on a Unit"] = "Строки для игроков и существ",
    ["Level"] = "Уровень",
    ["Shows a player's or creature's level. Under Blizzlike, it covers the whole line the client writes, including race."]
        = "Их уровень. При компоновке \"Как у Blizzard\" действует на всю строку клиента, включая расу.",
    ["Class"] = "Класс",
    ["Shows a player's class."] = "Класс игрока.",
    ["Race"] = "Раса",
    ["Shows a player's race or a creature's type."] = "Раса игрока или вид существа.",
    ["Blizzlike includes race on the level line, so the Level switch controls both."]
        = "\"Как у Blizzard\" пишет расу в строке уровня, поэтому переключатель \"Уровень\" действует на оба.",
    ["Faction"] = "Фракция",
    ["Which side they are on."] = "На чьей они стороне.",
    ["Guild"] = "Гильдия",
    ["The guild a player belongs to."] = "Гильдия, в которой состоит игрок.",
    ["Guild rank"] = "Звание в гильдии",
    ["The rank they hold there."] = "Их звание в ней.",
    ["Target"] = "Цель",
    ["Shows who they have targeted, or \"you\" if it is you."]
        = "Кого они выбрали целью. Показывает \"вы\", если это вы.",
    ["Class color on the name"] = "Цвет класса для имени",
    ["Colors a player's name by their class."] = "Окрашивает имя игрока в цвет его класса.",
    ["Lines on an Item or Spell"] = "Строки для предметов и заклинаний",
    ["What it sells for"] = "Цена продажи",
    ["Shows what a vendor pays for the item and the value of the whole stack."]
        = "Сколько платит торговец и сколько стоит вся стопка.",
    ["Item and spell ids"] = "ID предметов и заклинаний",
    ["Shows the IDs of an item, spell or creature."]
        = "Номера предмета, заклинания или существа.",
    ["Lines on Herbs, Veins and Corpses"] = "Строки для трав, жил и трупов",
    ["Skill needed to gather"] = "Навык для сбора",
    ["Shows the Herbalism, Mining or Skinning skill required for herbs, veins and corpses, in the color the game uses for your skill level."]
        = "Уровень травничества, горного дела или снятия шкур, нужный для травы, жилы или трупа, в цвете, которым игра отмечает ваш навык.",
    ["Sells for (%d)"] = "Цена продажи (%d)",
    ["Sells for"] = "Цена продажи",
    ["Item"] = "Предмет",
    ["Spell"] = "Заклинание",
    ["Requires %s"] = "Требуется: %s",
    ["you"] = "вы",
    ["Tooltip: TooltipDataProcessor is unavailable in this client build, so no lines can be added. Placement still works."]
        = "Подсказки: отсутствует TooltipDataProcessor, поэтому в этой версии клиента нельзя добавлять строки. Позиция по-прежнему работает.",
    ["Tooltip: GameTooltip_SetDefaultAnchor is unavailable in this client build, so the corner setting has no effect."]
        = "Подсказки: отсутствует GameTooltip_SetDefaultAnchor, поэтому в этой версии клиента настройка угла ничего не делает.",

    -- Data/Gathering.lua
    ["Herbalism"] = "Травничество",
    ["Mining"] = "Горное дело",
    ["Skinning"] = "Снятие шкур",

    -- -----------------------------------------------------------------------
    -- Consumables
    -- -----------------------------------------------------------------------

    -- Modules/Consumables.lua
    ["Warns when a selected consumable effect is missing or about to expire."]
        = "Предупреждает, когда эффект выбранного расходуемого предмета отсутствует или скоро закончится.",
    ["Main Hand"] = "Правая рука",
    ["Off Hand"] = "Левая рука",
    ["%d min"] = "%d мин.",
    ["%d:%02d min"] = "%d:%02d мин.",
    ["Show the remaining time"] = "Показывать оставшееся время",
    ["Icon size"] = "Размер значков",
    ["Conditions"] = "Условия",
    ["Warn at"] = "Предупреждать за",
    ["The remaining time at which a consumable warning appears."]
        = "Оставшееся время, при котором появляется предупреждение о расходуемых предметах.",
    ["Measurement"] = "Измерение",
    ["Print what was recorded"] = "Вывести записанное",
    ["Prints everything the probe recorded during this session in chat. The data is also saved and restored after a reload."]
        = "Все, что зонд увидел за этот сеанс, в виде строк чата. Это есть и в сохраненном файле, откуда оно читается после перезагрузки.",
    ["Consumables: C_Timer.NewTicker is missing, so the countdown only updates when something changes."]
        = "Расходуемые: отсутствует C_Timer.NewTicker, поэтому отсчет обновляется только при изменениях.",
    ["Weapon Coatings"] = "Точила, грузила и масла",

    -- Data/Consumables.lua
    ["Weapon Oil"] = "Масло для оружия",
    ["Sharpening Stone"] = "Точило",
    ["Weightstone"] = "Грузило",
    ["Food"] = "Еда",
    ["Any Food Buff"] = "Любой бафф от еды",
    ["Watches for a food buff, whichever food it came from: warns when none is on you, and before the one you have runs out."]
        = "Следит за баффом от еды, какой бы ни была еда: предупреждает, когда его на вас нет, и перед тем, как он закончится.",
    ["Strength"] = "Сила",
    ["Agility"] = "Ловкость",
    ["Armor"] = "Броня",
    ["Stamina"] = "Выносливость",
    ["Health Regeneration"] = "Восполнение здоровья",
    ["Mana Regeneration"] = "Восполнение маны",
    ["Spell Power"] = "Сила заклинаний",
    ["Fire Power"] = "Сила огня",
    ["Frost Power"] = "Сила льда",
    ["Shadow Power"] = "Сила тьмы",
    ["Resistance"] = "Сопротивление",
    ["Blasted Lands and Zandalar"] = "Выжженные земли и Зандалар",
    ["Attack Power"] = "Сила атаки",
    ["Juju"] = "Джуджу",
    ["Hit Chance"] = "Меткость",
    ["Alcohol"] = "Алкоголь",
    ["Other"] = "Прочее",
    ["Flask"] = "Настой",
    ["Intellect"] = "Интеллект",
    ["Spirit"] = "Дух",

    -- Core/Warnings.lua
    ["Gray"] = "Серый",
    ["Original colors"] = "Исходные цвета",
    ["Dimmed"] = "Затемненный",
    ["Alert red"] = "Тревожный красный",
    ["Scheme color"] = "Цвет схемы",
    ["new"] = "новый",

    -- Modules/Consumables.lua, names for an item or spell the client cannot name
    ["Item %s"] = "Предмет %s",
    ["Spell %s"] = "Заклинание %s",

    -- Modules/Consumables.lua, a row whose item is not loaded
    ["Item %s, not loaded yet"] = "Предмет %s, еще не загружен",
    ["Nothing to look up"] = "Нечего искать",

    -- -----------------------------------------------------------------------
    -- Buffs
    -- -----------------------------------------------------------------------

    -- Modules/BuffExpiry.lua
    ["Warns when a long buff is running out."]
        = "Предупреждает, когда долгий бафф подходит к концу.",
    ["Your own buffs"] = "Ваши собственные баффы",
    ["Armor spells, shouts, Inner Fire: anything you cast on yourself that runs out."]
        = "Доспехи, крики, Внутренний огонь: все, что вы накладываете на себя и что заканчивается.",
    ["Group buffs"] = "Групповые баффы",
    ["Buffs you also put on other people. The icon shows how many nearby players are missing the buff, except in combat."]
        = "Баффы, которые вы накладываете и на других. На значке показано, у скольких игроков рядом с вами его нет, кроме как в бою.",
    ["Weapon imbues and poisons"] = "Чары на оружии и яды",
    ["Warnings about the imbues, poisons, Firestones and Spellstones on your weapons."]
        = "Предупреждения о чарах, ядах, камнях огня и камнях чар на вашем оружии.",
    ["Tracking"] = "Отслеживание",
    ["Shows an icon whenever none of the tracking abilities you selected in the Tracking section is active. Either gathering tracking ability is enough."]
        = "Значок, когда не включено ни одно из отслеживаний, выбранных в разделе \"Отслеживание\". Достаточно любого из двух отслеживаний ресурсов.",
    ["Warn short buffs at"] = "Короткие баффы: предупреждать за",
    ["Applies to every buff lasting under 10 minutes."]
        = "Для каждого баффа, который длится меньше 10 минут.",
    ["Warn medium buffs at"] = "Средние баффы: предупреждать за",
    ["Applies to every buff lasting 10 to 29 minutes."]
        = "Для каждого баффа, который длится от 10 до 29 минут.",
    ["Warn long buffs at"] = "Долгие баффы: предупреждать за",
    ["Applies to every buff lasting 30 minutes or more."]
        = "Для каждого баффа, который длится 30 минут или дольше.",
    ["Warn while mounted"] = "Предупреждать верхом",
    ["Off: no warnings while you are mounted."]
        = "Отключено: никаких предупреждений, пока вы верхом.",
    ["Warn in a rested area"] = "Предупреждать в городах и тавернах",
    ["Off: no warnings in cities and inns."]
        = "Отключено: никаких предупреждений в городах и тавернах.",
    ["Buffs from others in dungeons"] = "Баффы от других в подземельях",
    ["Warnings about a buff another class in your group could give you, while you are in a dungeon."]
        = "Предупреждения о баффе, который вам мог бы дать другой класс из вашей группы, пока вы в подземелье.",
    ["Buffs from others in raids"] = "Баффы от других в рейдах",
    ["Warnings about a buff another class in your group could give you, while you are in a raid."]
        = "Предупреждения о баффе, который вам мог бы дать другой класс из вашей группы, пока вы в рейде.",
    ["Buffs from others in the open world"] = "Баффы от других в открытом мире",
    ["Warnings about a buff another class in your group could give you, anywhere outside a dungeon, a raid or a battleground."]
        = "Предупреждения о баффе, который вам мог бы дать другой класс из вашей группы, везде вне подземелий, рейдов и полей боя.",
    ["Count group members within"] = "Учитывать участников группы в радиусе",
    ["%d yd"] = "%d м",
    ["Group members farther away are not counted for buffs they could give you or buffs you could give them."]
        = "Участники группы дальше этого не учитываются ни для баффов, которые они могли бы дать вам, ни для баффов, которые вы могли бы дать им.",
    ["General Warnings"] = "Общие предупреждения",
    ["Combat Buffs"] = "Боевые баффы",
    ["Buffs on You Right Now"] = "Ваши баффы сейчас",
    ["During combat, the client cannot check whether %s is active on you. The addon can only track it from your own casts. If another player casts it on you, it may be reported as missing until combat ends. This message is shown once per character."]
        = "В бою клиент не может проверить, действует ли на вас %s. Модификация может отслеживать этот бафф только по вашим собственным применениям. Если его наложит другой игрок, до конца боя он может считаться отсутствующим. Это сообщение показывается один раз для каждого персонажа.",
    ["BuffExpiry: C_Timer.NewTicker is missing, so the countdown only updates when a buff changes."]
        = "Баффы: отсутствует C_Timer.NewTicker, поэтому отсчет обновляется только при изменении баффа.",
    ["missing"] = "отсутствует",
    ["upgrade"] = "новый уровень",
    ["showing"] = "показан",
    ["handout"] = "для других",
    ["waiting"] = "ожидает",
    ["unavailable"] = "недоступен",
    ["off"] = "откл.",
    ["%s of %s"] = "%s из %s",
    ["... and %d more"] = "... и еще %d",
    ["In combat, these are the remaining times recorded just before the fight, continuing to count down. Buffs cast on you by other players appear after combat ends."]
        = "В бою здесь показано время баффов на момент начала боя, и оно точно отсчитывается дальше. Бафф, наложенный на вас кем-то другим, появится, когда бой закончится.",
    ["No timed buffs on you."] = "На вас нет баффов с ограниченным временем.",
    ["(timer only)"] = "(только таймер)",
    ["(own class only)"] = "(только свой класс)",
    ["(not trained)"] = "(не изучено)",
    ["(not your race)"] = "(не ваша раса)",
    ["Class Buffs"] = "Баффы классов",
    ["(you)"] = "(вы)",
    ["Track on yourself"] = "Отслеживать на себе",
    ["Also tracks this buff on you."] = "Отслеживает этот бафф и на вас.",
    ["Track on friendly targets"] = "Отслеживать на дружественных целях",
    ["%d player"] = "%d игрок",
    ["%d players"] = "%d игроков",
    ["How many other players must have this buff active, not counting you. Outside combat, the icon shows how many are still missing it."]
        = "На скольких других игроках этот бафф должен держаться, не считая вас. Вне боя значок показывает, у скольких его еще нет.",
    ["Track on every group or raid member"] = "Отслеживать на всех участниках группы или рейда",
    ["Shows an icon whenever your pet is not happy, with a red border when it becomes unhappy. The icon is hidden during combat."]
        = "Значок, пока ваш питомец не счастлив, с красной рамкой, когда он несчастлив. Не в бою.",
    ["Tracks this buff on every member of your group or raid instead of using the number above. Outside combat, the icon shows how many are still missing it."]
        = "Отслеживает бафф на всех участниках вашей группы или рейда вместо числа выше. Вне боя значок показывает, у скольких его еще нет.",
    ["Only warn in combat"] = "Предупреждать только в бою",
    ["Warns about this buff only during a fight."]
        = "Предупреждает об этом баффе только во время боя.",

    -- Data/Buffs.lua, a name for when the client gives none
    ["Mark of the Wild"] = "Знак дикой природы",
    ["Thorns"] = "Шипы",
    ["Aspect of the Wild"] = "Дух дикой природы",
    ["Trueshot Aura"] = "Аура меткого выстрела",
    ["Aspect"] = "Дух",
    ["Arcane Intellect"] = "Чародейский интеллект",
    ["Armor Spell"] = "Доспех",
    ["Blessing"] = "Благословение",
    ["Aura"] = "Аура",
    ["Righteous Fury"] = "Праведное неистовство",
    ["Seal"] = "Печать",
    ["Power Word: Fortitude"] = "Слово силы: Стойкость",
    ["Divine Spirit"] = "Божественный дух",
    ["Shadow Protection"] = "Защита от темной магии",
    ["Inner Fire"] = "Внутренний огонь",
    ["Touch of Weakness"] = "Прикосновение слабости",
    ["Shadowguard"] = "Страж Тьмы",
    ["Main Hand Poison"] = "Яд на правой руке",
    ["Off Hand Poison"] = "Яд на левой руке",
    ["Shield Spell"] = "Щит",
    ["Main Hand Imbue"] = "Чары на правой руке",
    ["Off Hand Imbue"] = "Чары на левой руке",
    ["Demon Armor"] = "Демонический доспех",
    ["Firestone or Spellstone"] = "Камень огня или камень чар",
    ["Amplify Magic"] = "Усиление магии",
    ["Dampen Magic"] = "Ослабление магии",
    ["Water Breathing"] = "Подводное дыхание",
    ["Water Walking"] = "Хождение по воде",
    ["Unending Breath"] = "Нескончаемое дыхание",
    ["Detect Invisibility"] = "Обнаружение невидимости",
    ["Pet Happiness"] = "Настроение питомца",
    ["Battle Shout"] = "Боевой крик",

    -- Data/Tracking.lua
    ["Find Minerals"] = "Поиск минералов",
    ["Find Herbs"] = "Поиск трав",
    ["Find Treasure"] = "Поиск сокровища",

    -- -----------------------------------------------------------------------
    -- Chat
    -- -----------------------------------------------------------------------

    -- Modules/Chat.lua
    ["%d min %d s"] = "%d мин. %d сек.",
    ["Controls the chat's appearance, its surrounding buttons, and notification sounds."]
        = "Управляет внешним видом чата, кнопками вокруг него и звуками оповещений.",
    ["Names"] = "Имена",
    ["How names are written"] = "Как пишутся имена",
    ["Full name"] = "Полное имя",
    ["Initial and surname"] = "Инициал и фамилия",
    ["First name only"] = "Только имя",
    ["Surname only"] = "Только фамилия",
    ["Initials"] = "Инициалы",
    ["Shortens the name of the sender of each line. Hover over a shortened name to see the full name. Whispers are always addressed to the full name."]
        = "Сокращает имя автора строки. При наведении на сокращенное имя видно полное, а для шепота всегда используется полное имя.",
    ["Race icon before the name"] = "Значок расы перед именем",
    ["The race of whoever wrote a line, as an icon in front of the name."]
        = "Раса автора строки в виде значка перед именем.",
    ["Class icon before the name"] = "Значок класса перед именем",
    ["The class of whoever wrote a line, as an icon in front of the name."]
        = "Класс автора строки в виде значка перед именем.",
    ["%d px"] = "%d пикс.",
    ["Not in use until you switch on a race or class icon."] = "Не используется, пока не включен значок расы или класса.",
    ["Sets the size of both icons. Lines already in the chat keep the size they had when they arrived."]
        = "Насколько крупно рисуются оба значка. Строки, уже находящиеся в чате, сохраняют свой размер.",
    ["Channel Labels"] = "Сокращения каналов",
    ["Use the labels below"] = "Использовать сокращения ниже",
    ["Off: channels and groups appear in chat as the game writes them. Your labels below are kept."]
        = "Отключено: каналы и группы выглядят в чате так, как их пишет игра. Ваши сокращения ниже сохраняются.",
    ["Channel labels"] = "Сокращения каналов",
    ["Not in use until you switch the labels on."] = "Не используется, пока сокращения не включены.",
    ["A numbered channel uses its number as its label unless you enter a different one. Labels move with their channels when you reorder them. A number entered in a field always refers to that channel's number. An empty field leaves the label as the client writes it. The square beside each field shows that chat's color."]
        = "Нумерованный канал показывается своим номером, если в его поле не указано иное, и сокращение следует за своим каналом, когда каналы меняются местами. Число в поле всегда означает собственный номер канала. Пустое поле оставляет сокращение таким, каким его пишет клиент. Квадрат рядом окрашен в цвет этого чата.",
    ["Timestamps"] = "Время в чате",
    ["Timestamp format"] = "Формат времени",
    ["None"] = "Нет",
    ["03:27 PM"] = "03:27 PM",
    ["03:27:32 PM"] = "03:27:32 PM",
    ["Uses the client's timestamp setting. Changing it here also changes it in the game's options, and vice versa. Timestamps appear in square brackets."]
        = "Собственная настройка клиента для времени в чате. Изменение здесь меняет ее и в настройках игры, и наоборот. Чат показывает время в квадратных скобках.",
    ["Appearance"] = "Внешний вид",
    ["Sets the text size for every chat window at once. Each window's tab menu can still set its size individually. Windows without a chosen size default to 16."]
        = "Собственный размер текста клиента, для всех окон чата сразу. Меню вкладки по-прежнему настраивает одно окно. Окно, размер которого ни разу не выбирали, начинает с 16.",
    ["Space between lines"] = "Межстрочный интервал",
    ["Extra room between two lines of chat."] = "Дополнительное место между двумя строками чата.",
    ["Outline"] = "Контур",
    ["Thin"] = "Тонкий",
    ["Thick"] = "Толстый",
    ["Adds an outline around every letter, alongside the shadow."]
        = "Линия вокруг каждой буквы, в дополнение к тени.",
    ["Never fade chat out"] = "Никогда не скрывать чат",
    ["Old lines stay on screen rather than dimming and vanishing."]
        = "Старые строки остаются на экране, а не тускнеют и исчезают.",
    ["Fade after"] = "Скрывать через",
    ["Not in use until you let the chat fade."] = "Не используется, пока чат никогда не скрывается.",
    ["How long a line stays before it fades."]
        = "Сколько строка остается на экране, прежде чем исчезнуть.",
    ["Chat Window"] = "Окно чата",
    ["Hide the chat buttons"] = "Скрыть кнопки чата",
    ["Hides the buttons beside the chat window and the one that jumps to the newest line."]
        = "Кнопки рядом с окном чата и кнопка перехода к последней строке.",
    ["Show tabs only under the mouse"] = "Показывать вкладки только под курсором",
    ["The window tabs disappear while the mouse is elsewhere. A tab with a new message still lights up."]
        = "Вкладки окон исчезают, пока курсор в другом месте. Вкладка с новым сообщением все равно подсвечивается.",
    ["Show the input line only after Enter"] = "Показывать строку ввода только после Enter",
    ["Uses the client's chat style: the input line appears when you press Enter and disappears when the message is sent. Takes effect the next time the input line closes."]
        = "Собственный стиль чата клиента: строка ввода появляется, когда вы нажимаете Enter, и исчезает, когда сообщение отправлено. Вступает в силу, когда строка ввода закроется в следующий раз.",
    ["Input"] = "Ввод",
    ["Arrow keys bring back what you sent"] = "Стрелки возвращают отправленное",
    ["Use the Up and Down arrows in the input line to browse messages you sent during this session without holding Alt. Protected commands like /target and /cast still need Alt. In combat, keys without a modifier that the input does not use have no effect while it is open."]
        = "Стрелки вверх и вниз в строке ввода листают отправленное за этот сеанс, без зажатого Alt. Защищенные команды вроде /target и /cast все так же требуют Alt. В бою клавиши без модификаторов, которые строка ввода не использует, не действуют, пока она открыта.",
    ["Use Alt and Up for %s. The game blocks this command on the plain arrow keys."]
        = "Для %s используйте Alt и стрелку вверх. Игра блокирует эту команду на обычных стрелках.",
    ["Mouse Wheel"] = "Колесо мыши",
    ["Shift and the wheel jump to the top or bottom"]
        = "Shift и колесо: переход в начало или конец",
    ["Hold Shift and move the wheel one notch to jump straight to the top or bottom."]
        = "Один шаг колеса с зажатым Shift прокручивает до самого начала или конца.",
    ["Lines per wheel notch"] = "Строк за шаг колеса",
    ["How far one notch of the wheel moves."] = "На сколько строк прокручивает один шаг колеса.",
    ["Copy and Search"] = "Копирование и поиск",
    ["Shift click a timestamp to quote its line"] = "Shift+щелчок по времени цитирует сообщение",
    ["Not in use until you choose a timestamp format."]
        = "Не используется, пока не выбран формат времени.",
    ["A Shift click on a timestamp copies the whole line into the chat input, including the timestamp and sender, without sending it. Lines that arrived before this was enabled stay unchanged."]
        = "Shift+щелчок по времени сообщения копирует его целиком в строку ввода чата, вместе со временем и отправителем, не отправляя его. Сообщения, пришедшие до включения, остаются как есть.",
    ["Open the chat input when it is closed"] = "Открывать строку ввода, если она закрыта",
    ["Not in use until you switch on Shift clicking a timestamp."]
        = "Не используется, пока Shift+щелчок по времени не включен.",
    ["A Shift click on a timestamp opens the chat input with the line already entered, so you do not need to press Enter first."]
        = "Shift+щелчок по времени сообщения открывает строку ввода сразу с сообщением в ней, так что сначала нажимать Enter не нужно.",
    ["Search bar on the chat window"] = "Строка поиска в окне чата",
    ["Fade in and out"] = "Плавно показывать и скрывать",
    ["Not in use until you switch the search bar on."] = "Не используется, пока строка поиска не включена.",
    ["The bar fades in when the mouse comes over the chat and out when it leaves, rather than appearing at once."]
        = "Строка плавно появляется, когда курсор наводится на чат, и исчезает, когда уходит, а не появляется сразу.",
    ["Opacity"] = "Непрозрачность",
    ["Sets the search bar's opacity."] = "Насколько непрозрачно отображается строка поиска.",
    ["History"] = "История",
    ["Keep the chat across sessions"] = "Сохранять чат между сеансами",
    ["Saves every chat window when you log out or reload and restores them when this character logs in again."]
        = "Каждое окно чата записывается, когда вы выходите из игры или перезагружаете интерфейс, и восстанавливается, когда этот персонаж снова входит в игру.",
    ["Lines kept per window"] = "Сохраняемых строк на окно",
    ["Not in use until you keep the chat across sessions."] = "Не используется, пока чат не сохраняется между сеансами.",
    ["Keeps the newest lines in each window, up to the number of lines that window can hold."]
        = "Сохраняются последние строки каждого окна, не больше, чем вмещает окно чата.",
    ["Sounds"] = "Звуки",
    ["Plays a selected sound for each enabled message type. The button beside it plays the selected sound."]
        = "Звук для каждого включенного вида сообщений. Кнопка рядом воспроизводит выбранный звук.",
    ["Pause between sounds"] = "Пауза между звуками",
    ["After a sound plays, further messages of the same type from the same person are silent until this much time has passed. Applies to whispers, officer chat and messages from the party and raid leader. Messages from other people play a sound immediately."]
        = "После звука следующие сообщения того же человека в том же виде чата звука не вызывают, пока не пройдет это время. Действует для шепота, канала офицеров и лидеров группы и рейда. Сообщение другого человека звучит сразу.",
    ["Raid Warnings"] = "Объявления рейду",
    ["Plays a selected sound for raid warnings. The button beside it plays the selected sound."]
        = "Звук для объявлений рейду, пока он включен. Кнопка рядом воспроизводит выбранный звук.",
    ["Pause between raid warnings"] = "Пауза между объявлениями рейду",
    ["After a raid warning's sound plays, further raid warnings from the same person are silent until this much time has passed. At 0, every raid warning plays a sound."]
        = "После звука объявления рейду следующие объявления того же человека звука не вызывают, пока не пройдет это время. При 0 звучит каждое.",

    -- Core/Util.lua, the sounds to pick from
    ["Whisper"] = "Шепот",
    ["Raid warning"] = "Объявление рейду",
    ["Ready check"] = "Проверка готовности",
    ["Group invite"] = "Приглашение в группу",
    ["Friend online"] = "Друг в сети",
    ["Alarm clock"] = "Будильник",
    ["Alarm clock, short"] = "Будильник, короткий",
    ["Map ping"] = "Сигнал на карте",
    ["Auction house"] = "Аукционный дом",
    ["Coins"] = "Монеты",
    ["Level up"] = "Новый уровень",

    -- Modules/ChatHistory.lua
    ["Chat: this client cannot add older lines to a chat window, so the saved chat is not restored."]
        = "Чат: этот клиент не умеет добавлять строки перед содержимым окна, поэтому сохраненный чат не восстанавливается.",

    -- Modules/ChatLines.lua
    ["Chat: this client would not let a line be changed after it arrived, so labels and names stay as the game writes them."]
        = "Чат: этот клиент не позволяет менять строку после ее появления, поэтому сокращения и имена остаются такими, как их пишет игра.",
    ["Chat: changing a line failed once and is left alone from now on this session."]
        = "Чат: изменить строку однажды не удалось, и до конца сеанса это больше не пробуется.",
    ["Sets this chat's color using the client's own color picker."]
        = "Цвет этого чата. Это собственная настройка клиента, которая меняется через его собственную палитру цветов.",
    ["No channels to label yet."] = "Пока нет каналов для сокращений.",

    -- Modules/ChatSearch.lua
    ["Search for \"%s\": %d matching lines, showing the latest %d"]
        = "Поиск \"%s\": найдено строк: %d, показаны последние %d",
    ["Search for \"%s\": %d line"] = "Поиск \"%s\": %d строка",
    ["Search for \"%s\": %d lines"] = "Поиск \"%s\": %d строк",
    ["Empties the search field."] = "Очищает поле поиска.",
    ["Type a search and press Enter to display every matching line in this chat window again. Press Escape or click the X to clear the search."]
        = "Введите текст и нажмите Enter: каждая подходящая строка этого окна чата будет выведена снова. Escape или X в конце очищает поле.",

    -- Modules/ChatSound.lua
    ["Whispers"] = "Шепот",
    ["Officer Chat"] = "Канал офицеров",
    ["Party Leader"] = "Лидер группы",
    ["Raid Leader"] = "Лидер рейда",
    ["Chat: this client has no sound called %s."] = "Чат: в этом клиенте нет звука %s.",

    -- Late finds on the Consumables and Chat pages
    ["Replaced by a Class Buff"] = "Заменяется классовым баффом",
    ["Replaces the label before this chat's lines. Leave it empty to use the client's label."]
        = "Заменяет сокращение перед строками этого чата. Пустое поле оставляет сокращение клиента.",
    ["Plays the selected sound when a message of this type arrives."]
        = "Воспроизводит выбранный рядом звук, когда приходит сообщение этого вида.",

    -- -----------------------------------------------------------------------
    -- Late finds
    -- -----------------------------------------------------------------------

    -- Gameplay, Profiles and the export. The chat commands' own texts stay
    -- English since 2026-10-07, see ENGLISH_OUTPUT in tools/l10n.py.
    ["[ForeverPlus hid]"] = "[Скрыто ForeverPlus]",
    ["%s (a %s key)"] = "%s (ключ типа %s)",
    ["%s (no such module here)"] = "%s (такого модуля здесь нет)",
    ["Nested more than %d levels deep"] = "Превышена глубина вложенности: %d",
    ["Cannot include a %s in an export string"] = "Значение типа %s нельзя поместить в текст экспорта",
    -- Bar settings, shared movement and camp bonuses (2026-10-17).
    ["Bar %s"] = "Панель %s",
    ["Camp Benefits"] = "Бонусы лагеря",
    ["All Stats (%)"] = "Все характеристики (%)",
    ["Armor, Stats and Resistances"] = "Броня, характеристики и сопротивления",
    ["Critical Strike Chance"] = "Вероятность критического удара",
    ["Rested Experience"] = "Бонус отдыха",
    ["Bar"] = "Панель",
    ["The bar for this entry's icons. Use Manage bars to change its settings."]
        = "Панель для значков этой записи. Ее настройки находятся в разделе Управление панелями.",
    ["Custom warning time"] = "Свой порог предупреждения",
    ["Off: follows this page's warning time, including later changes."]
        = "Отключено: используется порог предупреждения с этой страницы, в том числе после его изменения.",
    ["Warns when less than this time remains. At 0, skips advance warnings but still warns when missing."]
        = "Предупреждает, когда остается меньше указанного времени. При 0 не предупреждает заранее об окончании, но по-прежнему сообщает об отсутствии эффекта.",
    ["Horizontal, centered"] = "По горизонтали, от центра",
    ["Vertical, centered"] = "По вертикали, от центра",
    ["To the right"] = "Вправо",
    ["To the left"] = "Влево",
    ["Downward"] = "Вниз",
    ["Upward"] = "Вверх",
    ["Delete Bar"] = "Удаление панели",
    ["Delete the bar %s?"] = "Удалить панель %s?",
    ["%d entry will move to %s."] = "Будет перенесена %d запись. Панель назначения: %s.",
    ["%d entries will move to %s."] = "Будет перенесено %d записей. Панель назначения: %s.",
    ["Restore Default Setup"] = "Восстановление исходных панелей",
    ["Restores General Warnings, Combat Buffs and Consumables with their original assignments. Custom bars are kept but emptied. Positions, icon sizes and warning times stay unchanged unless selected below."]
        = "Восстанавливает панели Общие предупреждения, Боевые баффы и Расходуемые с исходным распределением записей. Свои панели сохраняются, но становятся пустыми. Позиции, размеры значков и пороги предупреждений не меняются, если не отметить их ниже.",
    ["Reset default bar positions"] = "Сбросить позиции исходных панелей",
    ["Reset default bar icon sizes"] = "Сбросить размеры значков исходных панелей",
    ["Reset all warning times"] = "Сбросить все пороги предупреждений",
    ["Restore"] = "Восстановить",
    ["Bars"] = "Панели",
    ["Number of enabled entries assigned to this bar for your character."]
        = "Число включенных записей, назначенных этой панели для вашего персонажа.",
    ["New bar"] = "Новая панель",
    ["Creates an empty bar with the default appearance. Assign entries to it in their details."]
        = "Создает пустую панель со стандартным оформлением. Назначить ей записи можно в их настройках.",
    ["Restore default setup"] = "Вернуть исходные",
    ["Restores the three default bars and their original assignments."]
        = "Восстанавливает три исходные панели и распределение записей по ним.",
    ["Name"] = "Название",
    ["The name shown in bar lists and entry details. Leave blank to restore the default name."]
        = "Название в списках панелей и настройках записей. Оставьте поле пустым, чтобы вернуть исходное название.",
    ["Sets the size of every icon on this bar."] = "Задает размер всех значков на этой панели.",
    ["Growth direction"] = "Направление роста",
    ["Sets the bar's growth direction. At the screen edge, icons wrap to a new row or column."]
        = "Задает направление роста панели. У края экрана значки переходят на новую строку или в новый столбец.",
    ["The countdown under each icon on this bar."] = "Отсчет времени под каждым значком этой панели.",
    ["Missing icon color"] = "Цвет отсутствующих эффектов",
    ["Sets how missing buffs and consumables look on this bar. Borders stay red."]
        = "Задает вид отсутствующих баффов и расходуемых на этой панели. Рамки остаются красными.",
    ["Hides settings and lets you move all bars and the info bar, with this bar highlighted. Apply saves positions; Cancel discards changes."]
        = "Скрывает настройки и позволяет двигать все панели и инфопанель, выделяя эту панель. Применить сохраняет позиции, Отмена отменяет изменения.",
    ["Restores this bar's default position."] = "Возвращает эту панель в исходную позицию.",
    ["Moves this bar to the starting position for new bars."]
        = "Перемещает эту панель в начальную позицию новых панелей.",
    ["Delete bar"] = "Удалить панель",
    ["This is the fallback bar and cannot be deleted."] = "Это резервная панель, ее нельзя удалить.",
    ["Asks before deleting this bar. Its entries move to the fallback bar."]
        = "Запрашивает подтверждение перед удалением этой панели. Ее записи переходят на резервную панель.",
    ["Manage bars"] = "Управление панелями",
    ["Opens bar settings for buffs and consumables: size, appearance and screen position."]
        = "Открывает настройки панелей баффов и расходуемых: размер, оформление и положение на экране.",
    ["Warns when neither this bonus nor a replacement class buff is active. If no bonuses are selected, tracks %s itself."]
        = "Предупреждает, если нет ни этого бонуса, ни заменяющего его классового баффа. Если бонусы не выбраны, отслеживается сам эффект %s.",
    ["Given by these camp objects:"] = "Этот бонус дают следующие объекты лагеря:",
    ["These class buffs also count:"] = "Эти классовые баффы также учитываются:",
    ["Select up to three bonuses, the most you can have at once."]
        = "Можно выбрать до трех бонусов, столько может действовать одновременно.",
    ["Buffs for All Classes"] = "Баффы для всех классов",
    ["Off: uses this page's warning times. Your buff uses the setting for its duration; group counts use the setting for buffs lasting 10 to 29 minutes."]
        = "Отключено: используются пороги предупреждений с этой страницы. Для вашего баффа выбирается порог по его длительности. Для подсчета игроков в группе используется порог для баффов от 10 до 29 минут.",
    ["(no coating chosen)"] = "(ничего не выбрано)",
    ["Sets the bar and warning time for this hand's coating. Choose the oil or stone in the list below."]
        = "Задает панель и порог предупреждения для покрытия оружия в этой руке. Масло, точило или грузило выбирается в списке ниже.",
    ["Not in use until you choose an oil or stone for this hand in the list below."]
        = "Не используется, пока в списке ниже не выбрано масло, точило или грузило для оружия в этой руке.",
    ["Move bars"] = "Двигать панели",
    ["Hides settings so you can move all bars and the info bar. Apply saves positions; Cancel discards changes."]
        = "Скрывает настройки, чтобы можно было двигать все панели и инфопанель. Применить сохраняет позиции, Отмена отменяет изменения.",
    ["Confirm changes?"] = "Подтвердить изменения?",
    ["The bars cannot be moved during combat."] = "В бою панели нельзя двигать.",
    ["Drag the bars and the info bar into place. Apply saves positions; Cancel discards changes."]
        = "Перетащите панели и инфопанель в нужные места. Применить сохраняет позиции, Отмена отменяет изменения.",
    -- Translation round, 2026-10-18.
    ["Let the window reach the left edge"] = "Разрешить сдвиг окна к левому краю",
    ["Not in use until you hide the chat buttons."] = "Не используется, пока вы не скроете кнопки чата.",
    ["Removes the room kept free for the buttons on the left of the main chat window, so it can be moved up to the left edge of the screen."]
        = "Убирает место, оставленное для кнопок слева от основного окна чата, чтобы его можно было сдвинуть к левому краю экрана.",
    ["Turns every duel request down. Nothing is sent to whoever asked: they see the same refusal they would see if you had clicked it yourself."]
        = "Отклоняет все вызовы на дуэль. Вызвавшему вас игроку не отправляется сообщение: он видит тот же отказ, что и при вашем щелчке.",
    -- Translation round, 2026-10-18.
    ["Portrait style"] = "Стиль портретов",
    ["HD"] = "HD",
    ["SD"] = "SD",
    ["Not in use until you switch on the race icon."]
        = "Не используется, пока вы не включите значок расы.",
    ["HD shows the newer race portraits, SD the older ones. A race without an SD portrait keeps its HD one. Lines already in the chat keep theirs."]
        = "HD показывает новые портреты рас, SD показывает старые. Если у расы нет портрета SD, остается HD. Строки, уже показанные в чате, сохраняют свои портреты.",
    ["Tab background opacity"] = "Непрозрачность фона вкладок",
    ["Sets the opacity of every chat tab's background. The tab names stay fully visible."]
        = "Задает непрозрачность фона всех вкладок чата. Названия вкладок остаются полностью видимыми.",
    ["Horizontal offset"] = "Смещение по горизонтали",
    ["Moves the search bar to the right of its place in the chat window's top right corner, or to the left below zero. Hold Shift for steps of 50."]
        = "Сдвигает строку поиска вправо от ее позиции в правом верхнем углу окна чата, а при отрицательном значении влево. Удерживайте Shift для изменения с шагом 50.",
    ["Vertical offset"] = "Смещение по вертикали",
    ["Moves the search bar up from its place in the chat window's top right corner, or down below zero. Hold Shift for steps of 50."]
        = "Сдвигает строку поиска вверх от ее позиции в правом верхнем углу окна чата, а при отрицательном значении вниз. Удерживайте Shift для изменения с шагом 50.",
    ["Puts the search bar back in the chat window's top right corner."]
        = "Возвращает строку поиска в правый верхний угол окна чата.",
    ["Shown"] = "Видно",
    ["Hidden"] = "Скрыто",
    ["Shown on hover"] = "Видно при наведении",
    ["Bag bar"] = "Сумки",
    ["Micro menu"] = "Меню",
    ["Minimap tracking"] = "Отслеживание на мини-карте",
    ["Minimap zone name"] = "Название зоны на мини-карте",
    ["Minimap clock"] = "Часы на мини-карте",
    ["Minimap calendar"] = "Календарь на мини-карте",
    ["Minimap addon button"] = "Кнопка модификаций на мини-карте",
    ["Hide Interface Elements"] = "Скрытие элементов интерфейса",
    ["Hides the bag bar, the micro menu and parts of the minimap, always or depending on the mouse."]
        = "Скрывает панель сумок, меню и части мини-карты, постоянно или в зависимости от положения мыши.",
    ["Numbers"] = "Числа",
    ["Quest titles"] = "Названия заданий",
    ["Letters"] = "Письма",
    ["Combat text"] = "Текст боя",
    ["Open the stopwatch with a click"] = "Открывать таймер щелчком",
    ["A click on the display opens or closes the game's stopwatch."]
        = "Щелчок по показателю открывает или закрывает игровой таймер.",
    ["Open the calendar with a Shift click"] = "Открывать календарь через Shift+щелчок",
    ["A Shift click on the display opens or closes the game's calendar."]
        = "Shift+щелчок по показателю открывает или закрывает игровой календарь.",
    ["Open the world map with a click"] = "Открывать карту мира щелчком",
    ["A click on the display opens or closes the world map."]
        = "Щелчок по показателю открывает или закрывает карту мира.",
    ["How many of your bag slots are free."] = "Сколько свободных ячеек в ваших сумках.",
    ["Shows the free slots with the total, or the free slots alone. The hover always shows both."]
        = "Показывает свободные ячейки вместе с общим числом или только свободные. При наведении всегда видны оба числа.",
    ["Free and total"] = "Свободно и всего",
    ["Free only"] = "Только свободные",
    ["Reload the interface with a click"] = "Перезагружать интерфейс щелчком",
    ["A click on the display asks whether to reload the interface. Not in combat."]
        = "Щелчок по показателю запрашивает подтверждение перезагрузки интерфейса. Только вне боя.",
    ["Turn all sound off and on with a click"] = "Выключать и включать весь звук щелчком",
    ["A click on the display turns all game sound off, and the next one turns it back on. The volume stays as it was."]
        = "Щелчок по показателю выключает весь звук игры, следующий включает его снова. Установленная громкость сохраняется.",
    ["Font"] = "Шрифт",
    ["The font of the info bar. Default is the font of the addon, the others are fonts the game uses elsewhere."]
        = "Шрифт инфопанели. По умолчанию используется шрифт модификации, остальные варианты взяты из других частей игры.",
    ["The size of the info bar's text, relative to the text size on the Design page."]
        = "Размер текста инфопанели относительно размера текста на странице Внешний вид.",
    ["Text color"] = "Цвет текста",
    ["The color of the info bar's text."] = "Цвет текста инфопанели.",
    ["Status colors"] = "Цвета состояния",
    ["Colors displays by their state. Off, the whole bar is in its text color."]
        = "Окрашивает показатели в зависимости от состояния. Если отключено, вся панель использует свой цвет текста.",
    ["Background color"] = "Цвет фона",
    ["The color and opacity of the info bar's background."] = "Цвет и непрозрачность фона инфопанели.",
    ["Border color"] = "Цвет рамки",
    ["The color and opacity of the info bar's border."] = "Цвет и непрозрачность рамки инфопанели.",
    ["Show icons"] = "Показывать значки",
    ["The icons in front of the displays. A display that is only an icon shows its name instead."]
        = "Значки перед показателями. Если показатель состоит только из значка, вместо него показывается название.",
    ["Restore default look"] = "Сбросить оформление",
    ["Puts the info bar's font, colors and icons back as the design has them."]
        = "Возвращает шрифт, цвета и значки инфопанели к настройкам оформления.",
    ["Click to open the world map"] = "Щелкните, чтобы открыть карту мира",
    ["Click to open the stopwatch"] = "Щелкните, чтобы открыть таймер",
    ["Shift click to open the calendar"] = "Shift+щелчок, чтобы открыть календарь",
    ["Click to reload the interface"] = "Щелкните, чтобы перезагрузить интерфейс",
    ["The interface cannot be reloaded during combat."] = "В бою нельзя перезагрузить интерфейс.",
    ["Reload the interface now?"] = "Перезагрузить интерфейс сейчас?",
    ["Click the display to turn all sound off or on"]
        = "Щелкните по показателю, чтобы выключить или включить весь звук",
    ["Click an icon to hide or show it on the bar."]
        = "Щелкните по значку, чтобы скрыть или показать его на панели.",
    ["Hides or shows this display's icon on the bar."]
        = "Скрывает или показывает значок этого показателя на панели.",
    ["Accepts each quest automatically at most once per conversation with the quest giver."]
        = "Автоматически принимает задания, каждое не более одного раза за разговор с тем, кто его выдает.",
    ["Quest difficulty"] = "Сложность заданий",
    ["Accept all"] = "Принимать все",
    ["Skip gray quests"] = "Пропускать серые задания",
    ["Skip gray and green quests"] = "Пропускать серые и зеленые",
    ["Which quests are left for you to accept, by their color for your character. Handing quests in is not affected."]
        = "Какие задания оставлять вам для принятия вручную, по их цвету для вашего персонажа. На сдачу заданий не влияет.",
    ["Hands in each completed quest at most once per conversation with the quest giver. Never picks a reward for you."]
        = "Сдает выполненные задания, каждое не более одного раза за разговор с тем, кто его выдает. Никогда не выбирает награду за вас.",
    -- Translation round, 2026-10-18.
    ["Shown, hidden, or shown only while the mouse is over its place. A hidden piece takes no clicks."]
        = "Видно всегда, скрыто всегда или видно только при наведении мыши на его место. Скрытый элемент не реагирует на щелчки.",
    ["Always visible"] = "Всегда видно",
    ["Shows the search bar all the time, instead of only while the mouse is over the chat window or the input line is open."]
        = "Показывает строку поиска постоянно, а не только при наведении курсора на окно чата или открытой строке ввода.",
    ["Not in use until you switch off Always visible."]
        = "Не используется, пока вы не отключите настройку Всегда видно.",
    ["Appears in the chat window's top right corner while the mouse is over the window or the input line is open, unless it is set to be always visible. Press Enter to display every matching line again. The X at the end clears the search."]
        = "В правом верхнем углу чата, пока над ним курсор или открыта строка ввода, если не включена настройка Всегда видно. Enter снова выводит каждую подходящую строку. X в конце очищает поиск.",
    -- Translation round, 2026-10-20: chat fading and item level.
    ["Show chat on hover or while typing"] = "Показывать чат при наведении или вводе",
    ["Shows faded lines while the mouse is over the chat window or the input line is open. Afterward, they stay for the time set under \"Fade after\"."]
        = "Показывает скрытые строки, пока указатель находится над окном чата или открыта строка ввода. Затем они остаются видимыми в течение времени, заданного в настройке \"Скрывать через\".",
    ["Fade the background with the messages"] = "Скрывать фон вместе с сообщениями",
    ["Fades the window's background and tabs out with the last line. They return at your chosen opacity with a new message, when you scroll, while the mouse is over the window, or while you type."]
        = "Скрывает фон окна и вкладки вместе с последней строкой. Они снова отображаются с выбранной непрозрачностью при новом сообщении, прокрутке, наведении указателя на окно или вводе текста.",
    ["Item level"] = "Уровень предметов",
    ["Shows the average item level of a player's equipped items. For other players, the value updates when you hover over them outside combat. The last known value stays visible until the new one arrives."]
        = "Показывает средний уровень надетых предметов игрока. Для других игроков значение обновляется при наведении указателя вне боя. Последнее известное значение остается видимым, пока не придет новое.",
    -- Translation round, 2026-10-23: chat input and info bar.
    ["Input line position"] = "Положение строки ввода",
    ["Below the window"] = "Под окном",
    ["Between window and tabs"] = "Под вкладками",
    ["Above the tabs"] = "Над вкладками",
    ["Places the input line of every chat window below the window, between the window and its tabs, or above the tabs."]
        = "Размещает строку ввода каждого окна чата под окном, между окном и его вкладками или над вкладками.",
    ["How much ammunition you carry for your bow, gun or crossbow. Not shown while none of them is equipped."]
        = "Сколько боеприпасов вы носите для лука, ружья или арбалета. Не показывается, если такое оружие не экипировано.",
    ["What it counts"] = "Что считать",
    ["Counts every arrow or every bullet in your bags that your weapon fires, or only the ammunition in your ammo slot."]
        = "Считает все стрелы или пули в сумках, подходящие для вашего оружия, либо только боеприпасы в ячейке боеприпасов.",
    ["All arrows or bullets"] = "Все стрелы или пули",
    ["Ammo slot only"] = "Только из ячейки",
    ["Turns the display red below the amount set under this switch. Shared with Ammunition Warning on the Gameplay page, where it also shows a red line and plays a sound for Hunters."]
        = "Окрашивает число в красный ниже количества, заданного под этим переключателем. Настройка общая с модулем \"Предупреждение о боеприпасах\" на странице \"Игровой процесс\", который также предупреждает охотников красной строкой и звуком.",
    ["The amount below which the display turns red. Shared with Ammunition Warning on the Gameplay page."]
        = "Количество, ниже которого число становится красным. Настройка общая с модулем \"Предупреждение о боеприпасах\" на странице \"Игровой процесс\".",
    ["Destroy Cheapest Gray Item"] = "Уничтожать самый дешевый серый предмет",
    ["Shows an icon for the gray stack in your bags that is worth the least at a merchant. Shift click it to destroy that stack and free a bag slot. Not in combat."]
        = "Показывает значок стопки серых предметов в сумках, за которую торговец заплатит меньше всего. Shift+щелчок уничтожает эту стопку и освобождает ячейку сумки. Только вне боя.",
    ["Destroy with a click, without Shift"] = "Уничтожать щелчком без Shift",
    ["A click on the display destroys the stack without holding Shift."]
        = "Щелчок по показателю уничтожает стопку без удержания Shift.",
    ["Skip the confirmation"] = "Пропускать подтверждение",
    ["Destroys the stack at once, without the question, and reports it in chat."]
        = "Уничтожает стопку сразу, без подтверждения, и сообщает об этом в чате.",
    ["Counts %s, the ammunition in your ammo slot"] = "Считает боеприпасы из ячейки: %s",
    ["Your ammo slot is empty"] = "Ячейка боеприпасов пуста",
    ["Counts every bullet in your bags"] = "Считает все пули в сумках",
    ["Counts every arrow in your bags"] = "Считает все стрелы в сумках",
    ["Red below %d"] = "Красным ниже порога: %d",
    ["Nothing is destroyed in combat."] = "В бою ничего не уничтожается.",
    ["Nothing was destroyed: something is on your cursor."] = "Ничего не уничтожено: на курсоре что-то есть.",
    ["Nothing was destroyed: your bags changed."] = "Ничего не уничтожено: содержимое сумок изменилось.",
    ["Nothing was destroyed: this client cannot destroy items for an addon."]
        = "Ничего не уничтожено: этот клиент не может уничтожать предметы по запросу модификации.",
    ["The game did not destroy %s."] = "Игра не уничтожила предмет: %s.",
    ["Destroyed %d %s, worth %s at a merchant."] = "Уничтожено (количество: %d): %s. Цена у торговца: %s.",
    ["Destroyed %d %s, worth nothing at a merchant."]
        = "Уничтожено (количество: %d): %s. Торговец ничего за это не платит.",
    ["Destroy Gray Item"] = "Уничтожить серый предмет",
    ["Do you really want to destroy %d %s?"]
        = "Вы действительно хотите уничтожить эту стопку (количество: %d): %s?",
    ["A merchant would pay %s for it. This cannot be undone."]
        = "Торговец заплатил бы за это %s. Это действие нельзя отменить.",
    ["A merchant would pay nothing for it. This cannot be undone."]
        = "Торговец ничего бы за это не заплатил. Это действие нельзя отменить.",
    ["Destroy"] = "Уничтожить",
    ["Turns on \"Skip the confirmation\" on the Info bar page when you click Destroy."]
        = "Включает \"Пропускать подтверждение\" на странице \"Инфопанель\", когда вы нажимаете \"Уничтожить\".",
    ["No gray item to destroy"] = "Нет серых предметов для уничтожения",
    ["Stack of %d, worth %s at a merchant"] = "Предметов в стопке: %d. Цена у торговца: %s",
    ["Stack of %d, worth nothing at a merchant"] = "Предметов в стопке: %d. Торговец ничего за них не платит",
    ["Not in combat"] = "Недоступно в бою",
    ["Click to destroy this stack"] = "Щелчок, чтобы уничтожить эту стопку",
    ["Shift click to destroy this stack"] = "Shift+щелчок, чтобы уничтожить эту стопку",
    -- Shadow Protection, durability warning and web address copying.
    ["Warn about Shadow Protection from others"] = "Предупреждать о баффе от других",
    ["Warns when Shadow Protection is missing or about to expire and a Priest in your group could give it to you. Only applies where buffs from others are switched on under Conditions. A Priest's own warnings and group count do not change."]
        = "Предупреждает, если бафф \"Защита от темной магии\" отсутствует или скоро закончится и жрец в вашей группе мог бы наложить его на вас. Действует только там, где баффы от других включены в разделе \"Условия\". Предупреждения жреца о собственных баффах и его подсчет игроков в группе не меняются.",
    ["Durability Warning"] = "Предупреждение о прочности",
    ["Shows a short warning when an equipped item reaches the selected durability or lower. Also warns after login if an item is already low."]
        = "Показывает короткое предупреждение, когда прочность надетого предмета достигает выбранного порога или падает ниже. Также предупреждает после входа в игру, если прочность предмета уже на этом пороге или ниже.",
    ["Warn at or below"] = "Предупреждать при прочности до",
    ["Uses the lowest durability among your equipped items. At 0%, it warns only about broken equipment."]
        = "Учитывает самую низкую прочность среди надетых предметов. При 0% предупреждает только о сломанном снаряжении.",
    ["Low durability: %s (%d%%)"] = "Низкая прочность: %s (%d%%)",
    ["Durability Warning: this client has no sound called %s."]
        = "Предупреждение о прочности: в этом клиенте нет звука %s.",
    ["Copy web addresses"] = "Копировать веб-адреса",
    ["Makes web addresses in chat clickable for copying."]
        = "Позволяет щелкать по веб-адресам в чате для копирования.",
    ["Click to select this web address for copying."]
        = "Щелкните, чтобы выделить этот веб-адрес для копирования.",
    ["Web address"] = "Веб-адрес",
    ["Press Ctrl+C to copy."] = "Нажмите Ctrl+C для копирования.",
    -- Experience measurement, addon CPU usage and health bar textures.
    ["How much experience you gain per hour, measured since you logged in. Not shown at the maximum level."]
        = "Сколько опыта вы получаете в час с момента входа в игру. Не показывается на максимальном уровне.",
    ["Restart measurement with a click"] = "Перезапускать замер щелчком",
    ["A click on the display resets the measurement for both experience displays."]
        = "Щелчок по показателю сбрасывает замер для обоих показателей опыта.",
    ["Estimated time to your next level at your current experience rate. Not shown at the maximum level."]
        = "Примерное время до следующего уровня при текущей скорости получения опыта. Не показывается на максимальном уровне.",
    ["Click to restart measurement"] = "Щелкните, чтобы начать замер заново",
    ["Level %d"] = "%d-й уровень",
    ["Rested"] = "Отдохнувший",
    ["%s in %s"] = "%s за %s",
    ["Per hour"] = "В час",
    ["To the next level"] = "До следующего уровня",
    ["Addon CPU usage"] = "Нагрузка ЦП за счет модификаций",
    ["Total"] = "Всего",
    ["Health bar texture"] = "Текстура индикатора здоровья",
    ["Flat"] = "Однотонная",
    ["Soft gradient"] = "Мягкий градиент",
    ["Choose the texture of the health bar below unit tooltips."] = "Выберите текстуру индикатора здоровья под подсказками игроков и существ.",
    ["Preview"] = "Предпросмотр",
})

-- The form for 2 to 4, and for every count ending in 2 to 4 but 12 to 14,
-- of each plural FP:Plural is given, keyed by the English plural. The
-- singular and the plural above take every other count. See FP:Plural.
FP:AddPlurals("ruRU", {
    ["Sold %d gray items for %s%s."] = "Продано %d серых предмета на сумму %s%s.",
    ["%d gray items could not be sold."] = "%d серых предмета не удалось продать.",
    ["%d gray items still had a sale pending and could not be checked. Reopen the merchant if they are still there."]
        = "Продажа %d серых предметов еще не завершилась, проверить их не удалось. Откройте окно торговца снова, если они еще на месте.",
    ["Found %d gray items, selling ..."] = "Найдено %d серых предмета, идет продажа...",
    ["%d players"] = "%d игрока",
    ["Search for \"%s\": %d lines"] = "Поиск \"%s\": %d строки",
    ["%d profiles now."] = "Теперь %d профиля.",
    ["%d entries will move to %s."] = "Будут перенесены %d записи. Панель назначения: %s.",
})
