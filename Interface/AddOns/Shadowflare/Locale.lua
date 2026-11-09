local _, ns = ...

local L = {
    H_PROFILE  = "Profile",
    PROFILE    = "Profile",
    PROFILE_TIP = "A profile holds the settings of every proc. Each character picks its own; a new character starts on the first one.",
    PROFILE_NOTE = "Changes are saved in this profile, for every character that uses it.",
    PROFILE_DEFAULT = "Default",
    PROFILE_CHARS = "Characters on \"%s\":",
    PROFILE_YOU = "- this character",
    SAVE_AS_BTN = "Save as...",
    SAVE_AS_TIP = "Saves a copy of this profile under a new name. The profile you started from does not change.",
    RENAME_BTN = "Rename",
    DELETE_BTN = "Delete",
    SHARE      = "Share",
    SHARE_TIP  = "Export gives a text to copy. Import reads it back, on another account or from another player.",
    EXPORT_BTN = "Export",
    IMPORT_BTN = "Import",
    SAVE_AS_TITLE = "Save the profile as",
    SAVE_AS_TEXT = "A copy of \"%s\" is saved under this name, and this character uses it from now on. \"%s\" does not change.",
    RENAME_TITLE = "Rename the profile",
    RENAME_TEXT = "New name for \"%s\":",
    DELETE_TITLE = "Delete the profile",
    DELETE_TEXT = "Delete the profile \"%s\"? This character will use \"%s\".",
    DELETE_LAST = "This is your only profile: it can't be deleted.",
    REPLACE_TITLE = "Replace the profile",
    REPLACE_TEXT = "A profile named \"%s\" already exists. Replace it?",
    NAME_EMPTY = "Type a name.",
    NAME_TAKEN = "A profile already has this name.",
    EXPORT_TITLE = "Export \"%s\"",
    EXPORT_TEXT = "Copy this text with Ctrl+C, then paste it with Import on any character or account.",
    IMPORT_TITLE = "Import a profile",
    IMPORT_TEXT = "Paste the profile text with Ctrl+V.",
    IMPORT_BAD = "This text is not a Shadowflare profile, or it is incomplete.",
    IMPORT_NAME_TITLE = "Name the imported profile",
    IMPORT_NAME_TEXT = "It is saved as a new profile, and this character uses it from now on.",
    IMPORTED   = "Imported",
    OK_SAVE    = "Save",
    OK_RENAME  = "Rename",
    OK_DELETE  = "Delete",
    OK_REPLACE = "Replace",
    OK_IMPORT  = "Import",
    CANCEL     = "Cancel",
    CLOSE      = "Close",
    COPY_FROM  = "Copy from",
    COPY_TIP   = "Copies another proc's look onto this one: style, color, size, angle, sound, place and time left. Only this proc changes.",
    COPY_PICK  = "Pick a proc",
    COPIED     = "look of %s copied onto %s.",
    NOTES      = "Shows an alert when a proc makes a spell instant, faster, free or usable.",
    H_ALERT    = "Alert",
    CLASS      = "Class",
    CLASS_TIP  = "The procs listed below depend on the class.",
    SPELL      = "Proc",
    SPELL_TIP  = "Each proc has its own alert: its own style, color, sound and place on screen.",
    ENABLED    = "Show this alert",
    ENABLED_TIP = "Untick to never show this proc's alert.",
    CL_WARLOCK = "Warlock",
    CL_WARRIOR = "Warrior",
    SPEC_arms  = "Arms",
    SPEC_protection = "Protection",
    P_overpower = "Overpower",
    P_revenge  = "Revenge",
    L_overpower = "Overpower ready",
    L_revenge  = "Revenge ready",
    D_overpower = "Usable for a few seconds after your target dodges. The alert stays up even without rage.",
    D_revenge  = "Usable for a few seconds after you block, dodge or parry. The alert stays up even without rage.",
    P_shieldblock = "Shield Block", L_shieldblock = "Shield Block ready",
    D_shieldblock = "Shown when Shield Block can be pressed again (shield, Defensive Stance and enough rage), to keep it up. Hidden during its cooldown after a cast. No sound by default.",
    C_blood    = "Blood",
    SPEC_affliction = "Affliction",
    SPEC_demonology = "Demonology",
    SPEC_destruction = "Destruction",
    P_trance   = "Shadow Trance",
    P_decimation = "Decimation",
    L_trance   = "Instant Shadow Bolt",
    L_decimation = "Faster Soul Fire",
    D_trance   = "Your next Shadow Bolt is instant.",
    D_decimation = "Soul Fire casts faster and costs no Soul Shard.",
    P_conflagrate = "Conflagrate", L_conflagrate = "Conflagrate ready",
    D_conflagrate = "Shown when Conflagrate can be cast: your Immolate is on the target and Conflagrate is off cooldown. Hidden during its cooldown after a cast. Off by default: tick it if you have the talent.",
    SPEC_any   = "All specs",
    SPEC_fury  = "Fury",
    CL_MAGE = "Mage", CL_DRUID = "Druid", CL_SHAMAN = "Shaman", CL_PALADIN = "Paladin",
    CL_PRIEST = "Priest", CL_ROGUE = "Rogue", CL_HUNTER = "Hunter",
    CL_WEAPONS = "Weapons", CL_ENCHANTS = "Enchants", SPEC_mace = "Mace", SPEC_weapon = "Weapon enchant",
    SPEC_arcane = "Arcane", SPEC_fire = "Fire", SPEC_frost = "Frost",
    SPEC_balance = "Balance", SPEC_feral = "Feral", SPEC_restoration = "Restoration",
    SPEC_elemental = "Elemental", SPEC_enhancement = "Enhancement",
    SPEC_holy = "Holy", SPEC_retribution = "Retribution", SPEC_discipline = "Discipline", SPEC_shadow = "Shadow",
    SPEC_combat = "Combat", SPEC_assassination = "Assassination", SPEC_subtlety = "Subtlety",
    SPEC_survival = "Survival", SPEC_marksmanship = "Marksmanship", SPEC_beastmastery = "Beast Mastery",
    P_execute = "Execute", L_execute = "Execute",
    D_execute = "Shown while your target is low enough and you have the rage to Execute.",
    P_victoryrush = "Victory Rush", L_victoryrush = "Victory Rush ready",
    D_victoryrush = "Usable for a while after you kill an enemy.",
    P_clearcasting = "Clearcasting", L_clearcasting = "Free spell",
    D_clearcasting = "Your next spell costs no mana.",
    P_missilebarrage = "Missile Barrage", L_missilebarrage = "Free Arcane Missiles",
    D_missilebarrage = "Your next Arcane Missiles costs no mana.",
    P_fingers = "Fingers of Frost", L_fingers = "Frozen target",
    D_fingers = "Your next 2 spells treat the target as frozen. The sound is the game's own.",
    P_hotstreak = "Heating Up", L_hotstreak = "Fast Pyroblast",
    D_hotstreak = "Each stack makes your next Pyroblast cast 25% faster, up to 3 stacks (75%).",
    P_omen = "Omen of Clarity", L_omen = "Free spell",
    D_omen = "Clearcasting: your next spell or ability costs nothing.",
    P_eclipse = "Eclipse", L_eclipse = "Eclipse: 4 charges",
    D_eclipse = "Each Wrath adds a charge, up to 4. Each charge makes your next Starfire cast faster.",
    P_maelstrom = "Maelstrom Weapon", L_maelstrom = "Instant Lightning Bolt",
    D_maelstrom = "Each stack makes your next Lightning Bolt 20% faster and cheaper. At 5 stacks it is instant.",
    P_elemfocus = "Elemental Focus", L_elemfocus = "Free spell",
    D_elemfocus = "Clearcasting: your next damage spell costs no mana.",
    P_infusion = "Infusion of Light", L_infusion = "Faster Holy Light",
    D_infusion = "After a critical Holy Shock or Flash of Light, your next Holy Light casts faster.",
    P_hammer = "Hammer of Wrath", L_hammer = "Hammer of Wrath",
    D_hammer = "Shown while your target is low enough and you have the mana. Hidden during its cooldown after a cast.",
    P_searinglight = "Searing Light", L_searinglight = "Free Holy Nova",
    D_searinglight = "Your next Holy Nova costs no mana.",
    P_riposte = "Riposte", L_riposte = "Riposte ready",
    D_riposte = "Usable for a few seconds after you parry.",
    P_cutthroat = "Ghostly Strike", L_cutthroat = "Ambush ready",
    D_cutthroat = "After Ghostly Strike, your next Ambush within 7 sec doesn't need Stealth.",
    P_remorseless = "Remorseless Attacks", L_remorseless = "Critical strike ready",
    D_remorseless = "After a kill, your next strike has a higher critical strike chance.",
    P_mongoose = "Mongoose Bite", L_mongoose = "Mongoose Bite ready",
    D_mongoose = "Usable for a few seconds after your target dodges.",
    P_counterattack = "Counterattack", L_counterattack = "Counterattack ready",
    D_counterattack = "Usable for a few seconds after you parry.",
    P_rapidkilling = "Rapid Killing", L_rapidkilling = "Empowered shot",
    D_rapidkilling = "After a kill, your next Shot deals more damage.",
    P_deadlyaspects = "Deadly Aspects", L_deadlyaspects = "Attack speed up",
    D_deadlyaspects = "With Aspect of the Hawk or the Beast, your attack speed is higher for 12 sec.",
    P_redoubt = "Redoubt", L_redoubt = "Block chance up",
    D_redoubt = "Your block chance is higher for 10 sec or 5 blocks.",
    P_vengeance = "Vengeance", L_vengeance = "More damage",
    D_vengeance = "After a critical strike, your Physical and Holy damage is higher for 30 sec. Stacks up to 5 times. Needs Seal of Command.",
    P_martyrdom = "Martyrdom", L_martyrdom = "Focused Casting",
    D_martyrdom = "After a critical hit taken, damage no longer slows your casting for 6 sec.",
    P_arcaneblast = "Arcane Blast", L_arcaneblast = "Arcane Blast stacks",
    D_arcaneblast = "Each Arcane Blast gives you Spell Damage for 18 sec, up to 4 stacks. Choose from how many stacks it shows.",
    P_stormstrike = "Improved Stormstrike", L_stormstrike = "Stormstrike ready again",
    D_stormstrike = "A dodge or a parry reset Stormstrike's cooldown: it's ready again. Shows until you use it.",
    P_naturesgrace = "Nature's Grace", L_naturesgrace = "Faster casting",
    D_naturesgrace = "After a spell crit, faster casting and a shorter global cooldown for 3 sec.",
    P_reckoning = "Reckoning", L_reckoning = "Extra attacks",
    D_reckoning = "After a block or a critical hit taken, you store an extra attack, up to 4. They are used on your next swings.",
    P_edward = "Hand of Edward the Odd", L_edward = "Next spell instant",
    D_edward = "One-hand mace. When it procs, your next spell cast within 4 sec is instant.",
    P_revelation = "Revelation", L_revelation = "Next spell: +100% crit",
    D_revelation = "Weapon enchant. When a spell doesn't crit, your next non-periodic spell can get 100% more critical strike chance.",
    P_insight = "Insight", L_insight = "More Spirit",
    D_insight = "Weapon enchant. Your Spirit can go up by 100% for 10 sec.",
    NO_CLASS   = "Shadowflare has no alert for your class yet. Test mode still works.",
    STYLE      = "Style",
    S_arcs     = "Arcs",
    S_ring     = "Ring",
    S_icon     = "Icon",
    S_sigil    = "Sigil",
    S_bar      = "Bar",
    S_text     = "Text",
    S_crescent = "Crescent",
    S_shockwave = "Shockwave",
    S_brackets = "Brackets",
    S_procglow = "Modern glow",
    S_none = "None",
    NONE_TIME = "Time left",
    NONE_TIME_TIP = "Shows the time left on the alert. For the None style only: the other styles keep their own setting (Timer and sound tab).",
    NONE_DOTS = "Stack dots",
    NONE_DOTS_TIP = "Shows one dot per stack. For the None style only: the other styles keep their own look (Stacks tab).",
    NONE_EMPTY = "Nothing to show: tick at least one.",
    NONE_ELSEWHERE = "None style: what it shows is set in the Style tab.",
    NONE_NOTHING = "This alert has no time left or stacks to show.",
    S_umbra = "Umbra", S_hellfire = "Hellfire", S_wildgrowth = "Wildgrowth", S_rend = "Rend", S_stormcall = "Stormcall",
    SHARP      = "Sharp size",
    SHARP_TIP  = "For the game's pictures (Classic and Retail): sets the size where each pixel of the picture is one pixel of your screen. As sharp as it can be, but smaller. Click again after changing your resolution or UI scale.",
    SHARP_NONE = "Game art only",
    MODERN     = "Modern",
    CLASSIC    = "Classic - the game's own proc art",
    CLASSIC_NONE = "This client has none of the game's proc art.",
    RETAIL     = "Retail - the game's newer proc art",
    GAME_ART   = "Shadow Trance (game)",
    TINT       = "Color the classic, retail and HD styles too",
    TINT_TIP   = "Classic, retail and HD styles keep their own colors unless this box is ticked.",
    H_LOOK     = "Look",
    H_SHOW     = "Display",
    H_POSITION = "Position",
    COLOR_TIP  = "Color of the alert. Classic, retail and HD styles and the modern glow keep their own colors.",
    C_custom   = "Other...",
    SIZE_TIP   = "You can also use the mouse wheel on the alert while moving it.",
    EDGES_TIP  = "Adds a glow along the left and right edges of the screen, on top of the style.",
    MOVE_TIP   = "Closes the options and shows the alert on a grid. Drag the alert to move it. The mouse wheel changes its size. Done opens the options again.",
    PLACE_BTN  = "Place the alert",
    PLACING_HELP = "Drag the alert: it snaps to the grid. Mouse wheel to change its size, Shift + mouse wheel to turn it.",
    PLACING_HELP_TIMER = "Drag the alert, the time left follows it. Then drag the time left where you want it. Mouse wheel to resize, Shift + mouse wheel to turn the alert.",
    ROTATION   = "Rotation",
    ROTATION_TIP = "Turns the alert, for example to put the arcs above and below. Round styles look the same at any angle. While placing the alert: Shift + mouse wheel.",
    DONE       = "Done",
    NOT_IN_COMBAT = "can't be placed in combat.",
    PREVIEW    = "Preview",
    PREVIEW_TIP = "Shows the alert for as long as the proc lasts, as if it had just happened.",
    COLOR      = "Color",
    C_violet   = "Violet",
    C_fel      = "Fel",
    C_shadow   = "Shadow",
    C_fire     = "Fire",
    C_frost    = "Frost",
    SIZE       = "Size",
    OPACITY    = "Opacity",
    SHADOW     = "Shadow",
    SHADOW_TIP = "A dark shadow under the alert, so it stays easy to see on bright ground. 0% turns it off.",
    TIMER      = "Show time left",
    EDGES      = "Glow on the edges of the screen",
    EDGES_ONLY = "Only the glow on the edges",
    EDGES_ONLY_TIP = "Hides the alert itself and keeps only the glow on the edges of the screen. The time left placed apart still shows.",
    SOUND      = "Sound",
    SOUND_TIP  = "The game's choice keeps the game's proc alert, with its sound and arcs. Any other choice turns the game's alert off. Picking the game's again turns it back on.",
    SND_game   = "The game's (its sound and arcs)",
    SND_gameonly = "The game's (the only signal for this proc)",
    ANIM = "Animation",
    ANIM_TIP = "How the alert appears and moves. The chosen style above plays it in a loop. Preview shows it on screen.",
    ANIM_breath = "Breathing (default)", ANIM_classic = "Classic pulse", ANIM_impact = "Impact", ANIM_impactpulse = "Impact pulse",
    ANIM_flash = "Flash", ANIM_still = "Still",
    SND_none   = "None (game's alert off too)",
    SND_auraonly = "None (shown by the game itself)",
    SND_power  = "Proc alert",
    SND_raid   = "Raid warning",
    SND_ready  = "Ready check",
    SND_alarm  = "Alarm clock",
    SND_whisper = "Whisper",
    SND_ping   = "Map ping",
    TEST       = "Test",
    MOVE       = "On screen",
    CENTER     = "Center",
    DRAG       = "Drag to move - mouse wheel to resize",
    HELP       = "/flare - /flare test - /flare move - /flare notes - /flare debug",
    TIMER_FREE = "Move the time left separately",
    TIMER_FREE_TIP = "The time left gets its own frame, which follows the alert. Place it once next to the alert. After that, moving the alert moves both. The mouse wheel changes its size.",
    DRAG_TIMER = "Time left - drag, mouse wheel to resize",
    H_ABOUT    = "About",
    OPT_NOTES  = "Show what's new after an update",
    VERSION    = "Version %s",
    NOTES_BTN  = "What's new",
    NOTES_TITLE = "Shadowflare - What's new",
    NOTES_HINT = "Type /flare notes to see this again.",
    LOADED     = "loaded. Type /flare to set it up.",
    DEBUG_ON   = "debug on: each proc prints how it was detected.",
    DEBUG_OFF  = "debug off.",
    MEMORY     = "memory used: %.0f KB.",
    DETECTED   = "proc detected (%s).",
    ENDED      = "proc ended.",
    GS_LEARNED = "%s: from now on the game shows this alert itself (buff %d).",
    GS_OFF     = "alerts shown by the game: off. Every proc uses Shadowflare's own alert. Type /flare gameshow to turn them back on.",
    GS_ON      = "alerts shown by the game: on.",
    GS_COMBAT  = "buffs can't be read in combat: try again after the fight.",
    AURA_READY = "|cff40ff40Shown by the game itself, without sound: ready.|r",
    AURA_WAIT  = "|cffffd100Shown by the game itself, without sound: starts once its buff has been on you out of combat.|r",
    GS_NONE    = "no buff on you.",
    IDS_TITLE  = "Shadowflare - spell numbers",
    IDS_TEXT   = "Every number Shadowflare uses, with the name this game gives it. Press Ctrl+A then Ctrl+C to copy it, and paste it in a message to the author.",
    IDS_DONE   = "spell numbers checked: %d not found in this game (\"?\" in the list).",
    GS_STATE_GAME  = "shown by the game",
    GS_STATE_READY = "the game can show it, but its frame could not be made yet: Shadowflare's own alert",
    GS_STATE_WAIT  = "Shadowflare's own detection (buff not seen out of combat yet)",
    H_STACKS   = "Stacks",
    H_RESET    = "Cooldown reset",
    STACK_LOOK = "Below the maximum",
    STACK_LOOK_TIP = "How the alert looks before the last stack.\nDimmer: the whole alert, dimmer.\nFills up, Fills from the left: the alert fills a part per stack. The rest stays faint.\nDots: the whole alert, with one dot per stack under it.",
    LOOK_dim = "Dimmer", LOOK_fillup = "Fills up", LOOK_fillleft = "Fills from the left", LOOK_dots = "Dots",
    LOOKC_dim = "Dimmer", LOOKC_fillup = "Fills up", LOOKC_fillleft = "Fills from left", LOOKC_dots = "Dots",
    LOOKD_dim = "The whole alert, dimmer until the last stack.",
    LOOKD_fillup = "The alert fills from the bottom, one part per stack. The rest stays faint.",
    LOOKD_fillleft = "The alert fills from the left, one part per stack. The rest stays faint.",
    LOOKD_dots = "The whole alert, with one dot per stack under it.",
    LOOK_AT = "%d / %d",
    LOOK_ONE_SIDE = "Fills from the left needs both sides: with one side shown, the alert fills up instead.",
    FILL_HIDE  = "Hide the part not reached yet",
    FILL_HIDE_TIP = "Fills up and Fills from the left: below the maximum, the part not filled yet is hidden instead of faint.",
    SHOW_FOR   = "Show for",
    SHOW_FOR_TIP = "How long the alert stays after the reset, unless you use the spell first.",
    SECONDS    = "%d sec",
    STACKS_FROM = "Show from",
    STACKS_FROM_TIP = "The alert shows from this number of stacks. The sound plays at the maximum only.",
    STACKS_ONE = "1 stack",
    STACKS_N   = "%d stacks",
    STACKS_MAX = "%d stacks (maximum)",
    STACK_NUM  = "Show the number of stacks",
    STACK_NUM_TIP = "Shows the number of stacks next to the alert. Place the alert to move it. The mouse wheel on it changes its size.",
    STACK_SIZE = "Number size",
    STACK_SIZE_TIP = "Size of the number of stacks. You can also use the mouse wheel on it while placing the alert.",
    DRAG_STACKS = "Stacks - drag, mouse wheel to resize",
    PLACING_HELP_STACKS = "Drag the number of stacks where you want it.",
    -- The settings window (0.22.0)
    ENTRY_SUB  = "Proc alerts for every class - v%s",
    ENTRY_TEXT = "Shadowflare has its own settings window, with a live preview of each alert while you set it up.",
    OPEN_SETTINGS = "Open Shadowflare settings",
    ENTRY_TIP  = "Tip: type /flare in the chat to open it at any time.",
    H_ALERTS   = "Alerts",
    YOUR_CLASS = "Your class",
    BY_GAME    = "shown by the game",
    CLASS_LINE_MINE = "%s - your class - %d alerts",
    CLASS_LINE = "%s - %d alerts",
    LIST_HINT  = "Tick to turn an alert on or off. Click a name to set it up.",
    PLACE_ALL  = "Place all %s alerts",
    PLACE_ALL_TIPT = "Place all alerts",
    PLACE_ALL_TIP = "Shows every alert of this class that is on, together on the grid, to arrange them. Drag each one; the mouse wheel over one changes its size.",
    PLACING_ALL_TITLE = "%s alerts",
    PLACING_HELP_ALL = "Drag each alert where you want it: they snap to the grid. Mouse wheel over one to change its size, Shift + mouse wheel to turn it.",
    TAB_style  = "Style",
    TAB_look   = "Look",
    TAB_stacks = "Stacks",
    TAB_timer  = "Timer and sound",
    COPY_BTN   = "Copy from...",
    RESET_BTN  = "Reset",
    SAME_LOOK_BTN   = "Same look for all: %s",
    SAME_LOOK_TITLE = "Same look for the class",
    SAME_LOOK_TIP   = "Gives the look of the selected alert (%s) to every other alert of the same class (%s). Alerts of other classes do not change.",
    SAME_LOOK_COPIED = "Copied: style, color, size, angle, sides and spacing, animation, brightness, shadow, screen edges, time left (on the alert or apart, its size, alignment and font), and the look of the stacks between alerts that have stacks.",
    SAME_LOOK_KEPT  = "Kept on each alert: its place on screen (and that of its time left and stack number), whether it is on, its sound, Only in combat, Show from, and how long it stays.",
    SAME_LOOK_ASK   = "Give the look of %s to the %d other %s alerts? Their place on screen, sound and on/off are kept. This can't be undone.",
    SAME_LOOK_OK    = "Apply",
    SAME_LOOK_DONE  = "look of %s given to %d other alerts of its class.",
    RESET_TIP  = "Puts this alert's look back to its defaults. Its place and size on screen are kept.",
    RESET_ASK  = "Put the look of %s back to its defaults? Its place and size on screen are kept.",
    ANIMS_breath = "Breathing", ANIMS_classic = "Classic pulse", ANIMS_impact = "Impact", ANIMS_impactpulse = "Impact pulse", ANIMS_flash = "Flash", ANIMS_still = "Still",
    ANIMD_breath = "Fades in, breathes slowly (quicker for the last 3 seconds), fades out. For long buffs.",
    ANIMD_classic = "Pops in like the game's old proc alert, swells every second, grows as it goes. For free or faster spells.",
    ANIMD_impact = "Lands at once with a white-hot flare, then holds still. For short windows: use it now.",
    ANIMD_impactpulse = "Lands at once with a white-hot flare like Impact, then swells every second like Classic pulse.",
    ANIMD_flash = "Three hard flashes, then holds still. For rare, strong procs.",
    ANIMD_still = "On and off at once, nothing moves. For states such as Execute.",
    ANIM_EXIT  = "When you use the proc it bursts out; when it runs out it fades. The preview shows both.",
    ANIM_GAME  = "This alert is shown by the game itself: in game it appears at once and holds still.",
    ANIM_TARGET = "This alert follows your target: it appears and goes at once, with no fade.",
    NOMOVES    = "No way in or out",
    NOMOVES_TIP = "This alert appears at once and goes with a quick fade, and does not punch when it comes again. Its animation keeps moving while it is shown.",
    ANIM_NOMOVES = "No way in or out: it appears at once and goes with a quick fade.",
    EXIT_USED  = "Used",
    EXIT_RANOUT = "Ran out",
    H_BRIGHT   = "Brightness and angle",
    SIZE_MOVED = "The size is next to the preview, with Place on screen.",
    H_SIDES    = "Sides",
    SIDE_both  = "Both sides", SIDE_left = "Left side", SIDE_right = "Right side",
    SPACING    = "Spacing",
    SPACING_TIP = "Moves the two sides apart, or closer, without making them bigger.",
    SIDES_NONE = "Only for styles drawn on two sides, such as Arcs.",
    H_NUMBER   = "Number of stacks",
    H_TIME     = "Time left",
    TIME_ON    = "On the alert",
    TIME_APART = "Placed apart",
    TIME_OFF   = "Hidden",
    TIME_SIZE  = "Text size",
    TIME_ALIGN = "Alignment",
    TIME_ALIGN_TIP = "How the time left placed apart sits in its place. Left keeps its left edge still, so the numbers don't shift when they change width (10, 9.9, 8). Right keeps its right edge still.",
    ALIGN_LEFT = "Left", ALIGN_CENTER = "Center", ALIGN_RIGHT = "Right",
    FONT       = "Font",
    FONT_TIP   = "The font of every text of this alert: the time left, the words of styles that have some (Text, Bar...) and the number of stacks. The game's fonts, plus the fonts other addons share, if you have any.",
    FONT_GAME  = "Game font (default)",
    TIME_SIZE_TIP = "Size of the time left when it is placed apart. You can also use the mouse wheel on it while placing the alert.",
    H_EDGES    = "Screen edges",
    PLAY       = "Play",
    PLAY_TIP   = "Plays this alert's sound.",
    SOUND_WHEN = "Plays once when the alert shows (at the maximum for procs with stacks).",
    H_WHEN     = "When to show",
    ONLY_COMBAT = "Only in combat",
    ONLY_COMBAT_TIP = "Shows this alert only during a fight. Untick it to see it between fights too.",
    ONLY_COMBAT_HINT = "On by default. Victory Rush is off: a kill often ends the fight.",
    OTHER_STANCES = "Also in other stances",
    OTHER_STANCES_TIP = "In another stance the game says this ability can't be used. With this ticked, Shadowflare watches the dodge, parry or block itself and shows the alert with the stance to take. In a group, a dodge on another player's attack can show Overpower too.",
    OTHER_STANCES_HINT = "Off by default. In test.",
    STANCE_2457 = "Battle Stance", STANCE_71 = "Defensive Stance",
    BG_LABEL   = "Background",
    BG_DARK    = "Dark",
    BG_BRIGHT  = "Bright",
    BG_TIP     = "For the preview only: see the alert on dark or bright ground.",
    STACKS_LABEL = "Stacks",
    STACKS_MAXS = "%d stacks (max)",
    PLAY_STACKS = "Play",
    PV_PLAY    = "Play",
    PV_PLAY_TIP = "Plays the alert in the preview: its way in, its animation, its time, its way out, and its stacks going up, again and again.",
    PV_STOP    = "Stop",
    PV_STOP_TIP = "Holds the preview still, so you can set the alert's look calmly.",
    PLAY_STACKS_TIP = "Plays 1 stack to the maximum, again and again. Click a number or a picture below to stay on it.",
    ENDS_SOON  = "Ends soon",
    ENDS_SOON_TIP = "The last 3 seconds of the alert.",
    REAL_SIZE  = "Real size",
    SHOWN_AT   = "Shown at %d%%",
    PLACE_ON_SCREEN = "Place on screen",
    PLACE_HINT = "The alert is ready as you see it: on screen you only move it and set its size.",
}

if GetLocale() == "frFR" then
    L.H_PROFILE  = "Profil"
    L.PROFILE    = "Profil"
    L.PROFILE_TIP = "Un profil regroupe les réglages de tous les procs. Chaque personnage choisit le sien ; un nouveau personnage commence avec le premier."
    L.PROFILE_NOTE = "Les changements sont enregistrés dans ce profil, pour tous les personnages qui l'utilisent."
    L.PROFILE_DEFAULT = "Par défaut"
    L.PROFILE_CHARS = "Personnages sur « %s » :"
    L.PROFILE_YOU = "- ce personnage"
    L.SAVE_AS_BTN = "Enregistrer sous..."
    L.SAVE_AS_TIP = "Enregistre une copie de ce profil sous un nouveau nom. Le profil de départ ne change pas."
    L.RENAME_BTN = "Renommer"
    L.DELETE_BTN = "Supprimer"
    L.SHARE      = "Partager"
    L.SHARE_TIP  = "Exporter donne un texte à copier. Importer le relit, sur un autre compte ou depuis un autre joueur."
    L.EXPORT_BTN = "Exporter"
    L.IMPORT_BTN = "Importer"
    L.SAVE_AS_TITLE = "Enregistrer le profil sous"
    L.SAVE_AS_TEXT = "Une copie de « %s » est enregistrée sous ce nom, et ce personnage l'utilise désormais. « %s » ne change pas."
    L.RENAME_TITLE = "Renommer le profil"
    L.RENAME_TEXT = "Nouveau nom pour « %s » :"
    L.DELETE_TITLE = "Supprimer le profil"
    L.DELETE_TEXT = "Supprimer le profil « %s » ? Ce personnage utilisera « %s »."
    L.DELETE_LAST = "C'est ton seul profil : il ne peut pas être supprimé."
    L.REPLACE_TITLE = "Remplacer le profil"
    L.REPLACE_TEXT = "Un profil nommé « %s » existe déjà. Le remplacer ?"
    L.NAME_EMPTY = "Saisis un nom."
    L.NAME_TAKEN = "Un profil porte déjà ce nom."
    L.EXPORT_TITLE = "Exporter « %s »"
    L.EXPORT_TEXT = "Copie ce texte avec Ctrl+C, puis colle-le avec Importer, sur n'importe quel personnage ou compte."
    L.IMPORT_TITLE = "Importer un profil"
    L.IMPORT_TEXT = "Colle le texte du profil avec Ctrl+V."
    L.IMPORT_BAD = "Ce texte n'est pas un profil Shadowflare, ou il est incomplet."
    L.IMPORT_NAME_TITLE = "Nommer le profil importé"
    L.IMPORT_NAME_TEXT = "Il est enregistré comme nouveau profil, et ce personnage l'utilise désormais."
    L.IMPORTED   = "Importé"
    L.OK_SAVE    = "Enregistrer"
    L.OK_RENAME  = "Renommer"
    L.OK_DELETE  = "Supprimer"
    L.OK_REPLACE = "Remplacer"
    L.OK_IMPORT  = "Importer"
    L.CANCEL     = "Annuler"
    L.CLOSE      = "Fermer"
    L.COPY_FROM  = "Copier depuis"
    L.COPY_TIP   = "Copie l'apparence d'un autre proc sur celui-ci : style, couleur, taille, angle, son, place et temps restant. Seul ce proc change."
    L.COPY_PICK  = "Choisir un proc"
    L.COPIED     = "apparence de %s copiée sur %s."
    L.NOTES      = "Affiche une alerte quand un proc rend un sort instantané, plus rapide, gratuit ou utilisable."
    L.H_ALERT    = "Alerte"
    L.CLASS      = "Classe"
    L.CLASS_TIP  = "Les procs proposés dépendent de la classe."
    L.SPELL      = "Proc"
    L.SPELL_TIP  = "Chaque proc a sa propre alerte : son style, sa couleur, son son et sa place à l'écran."
    L.ENABLED    = "Afficher cette alerte"
    L.ENABLED_TIP = "Décocher pour ne jamais afficher l'alerte de ce proc."
    L.CL_WARLOCK = "Démoniste"
    L.CL_WARRIOR = "Guerrier"
    L.SPEC_arms  = "Armes"
    L.SPEC_protection = "Protection"
    L.P_overpower = "Fulgurance"
    L.P_revenge  = "Vengeance"
    L.L_overpower = "Fulgurance prête"
    L.L_revenge  = "Vengeance prête"
    L.D_overpower = "Utilisable quelques secondes après une esquive de ta cible. L'alerte reste affichée même sans rage."
    L.D_revenge  = "Utilisable quelques secondes après un blocage, une esquive ou une parade. L'alerte reste affichée même sans rage."
    L.P_shieldblock = "Maîtrise du blocage"; L.L_shieldblock = "Maîtrise du blocage prête"
    L.D_shieldblock = "Affichée quand Maîtrise du blocage peut être relancée (bouclier, posture défensive et assez de rage), pour la garder active. Masquée pendant sa recharge après un lancer. Sans son par défaut."
    L.C_blood    = "Sang"
    L.SPEC_affliction = "Affliction"
    L.SPEC_demonology = "Démonologie"
    L.SPEC_destruction = "Destruction"
    L.P_trance   = "Transe de l'ombre"
    L.P_decimation = "Décimation"
    L.L_trance   = "Trait de l'ombre instantané"
    L.L_decimation = "Feu de l'âme accéléré"
    L.D_trance   = "Ton prochain Trait de l'ombre est instantané."
    L.D_decimation = "Feu de l'âme s'incante plus vite et ne coûte pas de fragment d'âme."
    L.P_conflagrate = "Conflagration"; L.L_conflagrate = "Conflagration prête"
    L.D_conflagrate = "Affichée quand Conflagration peut être lancée : ton Immolation est sur la cible et Conflagration n'est pas en recharge. Masquée pendant sa recharge après un lancer. Coupée par défaut : coche-la si tu as le talent."
    L.SPEC_any   = "Toutes spécialisations"
    L.SPEC_fury  = "Fureur"
    L.CL_MAGE = "Mage"; L.CL_DRUID = "Druide"; L.CL_SHAMAN = "Chaman"; L.CL_PALADIN = "Paladin"
    L.CL_PRIEST = "Prêtre"; L.CL_ROGUE = "Voleur"; L.CL_HUNTER = "Chasseur"
    L.CL_WEAPONS = "Armes"; L.CL_ENCHANTS = "Enchantements"; L.SPEC_mace = "Masse"; L.SPEC_weapon = "Enchantement d'arme"
    L.SPEC_arcane = "Arcanes"; L.SPEC_fire = "Feu"; L.SPEC_frost = "Givre"
    L.SPEC_balance = "Équilibre"; L.SPEC_feral = "Combat farouche"; L.SPEC_restoration = "Restauration"
    L.SPEC_elemental = "Élémentaire"; L.SPEC_enhancement = "Amélioration"
    L.SPEC_holy = "Sacré"; L.SPEC_retribution = "Vindicte"; L.SPEC_discipline = "Discipline"; L.SPEC_shadow = "Ombre"
    L.SPEC_combat = "Combat"; L.SPEC_assassination = "Assassinat"; L.SPEC_subtlety = "Finesse"
    L.SPEC_survival = "Survie"; L.SPEC_marksmanship = "Précision"; L.SPEC_beastmastery = "Maîtrise des bêtes"
    L.P_execute = "Exécution"; L.L_execute = "Exécution"
    L.D_execute = "Affichée tant que ta cible est assez basse et que tu as la rage pour Exécution."
    L.P_victoryrush = "Ivresse de la victoire"; L.L_victoryrush = "Ivresse de la victoire prête"
    L.D_victoryrush = "Utilisable un moment après avoir tué un ennemi."
    L.P_clearcasting = "Idées claires"; L.L_clearcasting = "Sort gratuit"
    L.D_clearcasting = "Ton prochain sort ne coûte pas de mana."
    L.P_missilebarrage = "Barrage de projectiles"; L.L_missilebarrage = "Projectiles des arcanes gratuits"
    L.D_missilebarrage = "Tes prochains Projectiles des arcanes ne coûtent pas de mana."
    L.P_fingers = "Doigts de givre"; L.L_fingers = "Cible gelée"
    L.D_fingers = "Tes 2 prochains sorts considèrent la cible comme gelée. Le son est celui du jeu."
    L.P_hotstreak = "Réchauffement"; L.L_hotstreak = "Explosion pyrotechnique rapide"
    L.D_hotstreak = "Chaque cumul rend ta prochaine Explosion pyrotechnique 25 % plus rapide, jusqu'à 3 cumuls (75 %)."
    L.P_omen = "Augure de clarté"; L.L_omen = "Sort gratuit"
    L.D_omen = "Idées claires : ton prochain sort ou ta prochaine technique ne coûte rien."
    L.P_eclipse = "Éclipse"; L.L_eclipse = "Éclipse : 4 charges"
    L.D_eclipse = "Chaque Colère ajoute une charge, jusqu'à 4. Chaque charge rend ton prochain Feu stellaire plus rapide."
    L.P_maelstrom = "Arme du Maelström"; L.L_maelstrom = "Éclair instantané"
    L.D_maelstrom = "Chaque cumul rend ton prochain Éclair 20 % plus rapide et moins cher. À 5 cumuls, il est instantané."
    L.P_elemfocus = "Focalisation élémentaire"; L.L_elemfocus = "Sort gratuit"
    L.D_elemfocus = "Idées claires : ton prochain sort de dégâts ne coûte pas de mana."
    L.P_infusion = "Imprégnation de lumière"; L.L_infusion = "Lumière sacrée plus rapide"
    L.D_infusion = "Après un coup critique de Horion sacré ou d'Éclair lumineux, ta prochaine Lumière sacrée s'incante plus vite."
    L.P_hammer = "Marteau de courroux"; L.L_hammer = "Marteau de courroux"
    L.D_hammer = "Affiché tant que ta cible est assez basse et que tu as la mana. Masqué pendant sa recharge après un lancer."
    L.P_searinglight = "Lumière incendiaire"; L.L_searinglight = "Nova sacrée gratuite"
    L.D_searinglight = "Ta prochaine Nova sacrée ne coûte pas de mana."
    L.P_riposte = "Riposte"; L.L_riposte = "Riposte prête"
    L.D_riposte = "Utilisable quelques secondes après une parade."
    L.P_cutthroat = "Frappe fantomatique"; L.L_cutthroat = "Embuscade prête"
    L.D_cutthroat = "Après Frappe fantomatique, ta prochaine Embuscade dans les 7 s n'a pas besoin du Camouflage."
    L.P_remorseless = "Attaques impitoyables"; L.L_remorseless = "Coup critique prêt"
    L.D_remorseless = "Après une victoire, ta prochaine attaque a plus de chances de coup critique."
    L.P_mongoose = "Morsure de la mangouste"; L.L_mongoose = "Morsure de la mangouste prête"
    L.D_mongoose = "Utilisable quelques secondes après une esquive de ta cible."
    L.P_counterattack = "Contre-attaque"; L.L_counterattack = "Contre-attaque prête"
    L.D_counterattack = "Utilisable quelques secondes après une parade."
    L.P_rapidkilling = "Tuerie rapide"; L.L_rapidkilling = "Tir renforcé"
    L.D_rapidkilling = "Après une victoire, ton prochain tir inflige plus de dégâts."
    L.P_deadlyaspects = "Aspects mortels"; L.L_deadlyaspects = "Vitesse d'attaque augmentée"
    L.D_deadlyaspects = "Avec l'Aspect du faucon ou de la bête, ta vitesse d'attaque est plus élevée pendant 12 s."
    L.P_redoubt = "Redoute"; L.L_redoubt = "Blocage augmenté"
    L.D_redoubt = "Tes chances de bloquer sont plus élevées pendant 10 s ou 5 blocages."
    L.P_vengeance = "Vengeance"; L.L_vengeance = "Plus de dégâts"
    L.D_vengeance = "Après un coup critique, tes dégâts physiques et du Sacré sont plus élevés pendant 30 s. Se cumule jusqu'à 5 fois. Demande le Sceau d'autorité."
    L.P_martyrdom = "Martyre"; L.L_martyrdom = "Incantation focalisée"
    L.D_martyrdom = "Après un coup critique subi, les dégâts ne ralentissent plus tes incantations pendant 6 s."
    L.P_arcaneblast = "Déflagration des Arcanes"; L.L_arcaneblast = "Cumuls de Déflagration"
    L.D_arcaneblast = "Chaque Déflagration des Arcanes te donne de la puissance des sorts pendant 18 s, jusqu'à 4 cumuls. Choisis à partir de combien de cumuls elle s'affiche."
    L.P_stormstrike = "Frappe-tempête améliorée"; L.L_stormstrike = "Frappe-tempête à nouveau prête"
    L.D_stormstrike = "Une esquive ou une parade a remis à zéro le temps de recharge de Frappe-tempête : elle est de nouveau prête. Affichée jusqu'à ce que tu la lances."
    L.P_naturesgrace = "Grâce de la nature"; L.L_naturesgrace = "Incantation plus rapide"
    L.D_naturesgrace = "Après un critique avec un sort, incantation plus rapide et temps de recharge global plus court pendant 3 s."
    L.P_reckoning = "Rétribution"; L.L_reckoning = "Attaques en plus"
    L.D_reckoning = "Après un blocage ou un coup critique subi, tu stockes une attaque en plus, jusqu'à 4. Elles partent avec tes coups suivants."
    L.P_edward = "Hand of Edward the Odd"; L.L_edward = "Prochain sort instantané"
    L.D_edward = "Masse à une main. Quand elle se déclenche, ton prochain sort lancé dans les 4 s est instantané."
    L.P_revelation = "Révélation"; L.L_revelation = "Prochain sort : +100 % de critique"
    L.D_revelation = "Enchantement d'arme. Quand un sort ne fait pas de critique, ton prochain sort non périodique peut gagner 100 % de chances de critique en plus."
    L.P_insight = "Clairvoyance"; L.L_insight = "Plus d'Esprit"
    L.D_insight = "Enchantement d'arme. Ton Esprit peut augmenter de 100 % pendant 10 s."
    L.NO_CLASS   = "Shadowflare n'a pas encore d'alerte pour ta classe. Le mode test reste disponible."
    L.S_arcs     = "Arcs"
    L.S_ring     = "Anneau"
    L.S_icon     = "Icône"
    L.S_sigil    = "Sceau"
    L.S_bar      = "Barre"
    L.S_text     = "Texte"
    L.S_crescent = "Croissant"
    L.S_shockwave = "Onde de choc"
    L.S_brackets = "Viseur"
    L.S_procglow = "Lueur moderne"
    L.S_none = "Aucun"
    L.NONE_TIME = "Temps restant"
    L.NONE_TIME_TIP = "Affiche le temps restant sur l'alerte. Pour le style Aucun seulement : les autres styles gardent leur réglage (onglet Temps et son)."
    L.NONE_DOTS = "Points des cumuls"
    L.NONE_DOTS_TIP = "Affiche un point par cumul. Pour le style Aucun seulement : les autres styles gardent leur apparence (onglet Cumuls)."
    L.NONE_EMPTY = "Rien à afficher : coche au moins une case."
    L.NONE_ELSEWHERE = "Style Aucun : ce qu'il affiche se règle dans l'onglet Style."
    L.NONE_NOTHING = "Cette alerte n'a ni temps restant ni cumuls à afficher."
    L.SHARP      = "Taille nette"
    L.SHARP_TIP  = "Pour les dessins du jeu (Classiques et Retail) : règle la taille où chaque pixel du dessin est un pixel de ton écran. Aussi net que possible, mais plus petit. Clique de nouveau après avoir changé ta résolution ou l'échelle de l'interface."
    L.SHARP_NONE = "Dessins du jeu"
    L.MODERN     = "Modernes"
    L.CLASSIC    = "Classiques - les dessins de procs du jeu"
    L.CLASSIC_NONE = "Ce client n'a aucun des dessins de procs du jeu."
    L.RETAIL     = "Retail - les dessins de procs plus récents du jeu"
    L.GAME_ART   = "Transe de l'ombre (jeu)"
    L.TINT       = "Colorer aussi les styles classiques, retail et HD"
    L.TINT_TIP   = "Les styles classiques, retail et HD gardent leurs propres couleurs, sauf si cette case est cochée."
    L.H_LOOK     = "Apparence"
    L.H_SHOW     = "Affichage"
    L.H_POSITION = "Position"
    L.COLOR_TIP  = "La couleur de l'alerte. Les styles classiques, retail et HD et la lueur moderne gardent leurs propres couleurs."
    L.C_custom   = "Autre..."
    L.SIZE_TIP   = "Tu peux aussi utiliser la molette sur l'alerte pendant que tu la déplaces."
    L.EDGES_TIP  = "Ajoute une lueur sur les bords gauche et droit de l'écran, en plus du style."
    L.MOVE_TIP   = "Ferme les options et affiche l'alerte sur une grille. Fais glisser l'alerte pour la déplacer. La molette change sa taille. Terminé rouvre les options."
    L.PLACE_BTN  = "Placer l'alerte"
    L.PLACING_HELP = "Fais glisser l'alerte : elle s'accroche à la grille. Molette pour changer sa taille, Maj + molette pour la tourner."
    L.PLACING_HELP_TIMER = "Fais glisser l'alerte, le temps restant la suit. Place ensuite le temps restant où tu veux. Molette pour la taille, Maj + molette pour tourner l'alerte."
    L.ROTATION   = "Rotation"
    L.ROTATION_TIP = "Tourne l'alerte, par exemple pour mettre les arcs au-dessus et en dessous. Les styles ronds restent identiques. Pendant le placement de l'alerte : Maj + molette."
    L.DONE       = "Terminé"
    L.NOT_IN_COMBAT = "ne peut pas être placé en combat."
    L.PREVIEW    = "Aperçu"
    L.PREVIEW_TIP = "Affiche l'alerte pendant la durée du proc, comme s'il venait de se déclencher."
    L.COLOR      = "Couleur"
    L.C_violet   = "Violet"
    L.C_fel      = "Gangrené"
    L.C_shadow   = "Ombre"
    L.C_fire     = "Feu"
    L.C_frost    = "Givre"
    L.SIZE       = "Taille"
    L.OPACITY    = "Opacité"
    L.SHADOW     = "Ombre"
    L.SHADOW_TIP = "Une ombre sombre sous l'alerte, pour bien la voir sur un sol clair. 0 % la coupe."
    L.TIMER      = "Afficher le temps restant"
    L.EDGES      = "Lueur sur les bords de l'écran"
    L.EDGES_ONLY = "Seulement la lueur sur les bords"
    L.EDGES_ONLY_TIP = "Masque l'alerte elle-même et garde seulement la lueur sur les bords de l'écran. Le temps restant placé à part reste affiché."
    L.SOUND      = "Son"
    L.SOUND_TIP  = "Le choix « celui du jeu » garde l'alerte de proc du jeu, avec son son et ses arcs. Tout autre choix désactive l'alerte du jeu. Revenir à celui du jeu la réactive."
    L.SND_game   = "Celui du jeu (son et arcs du jeu)"
    L.SND_gameonly = "Celui du jeu (seul signal pour ce proc)"
    L.ANIM = "Animation"
    L.ANIM_TIP = "La façon dont l'alerte apparaît et bouge. Le style choisi plus haut la joue en boucle. Aperçu la montre à l'écran."
    L.ANIM_breath = "Respiration (par défaut)"; L.ANIM_classic = "Pulsation classique"; L.ANIM_impact = "Impact"; L.ANIM_impactpulse = "Impact pulsé"
    L.ANIM_flash = "Éclairs"; L.ANIM_still = "Fixe"
    L.SND_none   = "Aucun (alerte du jeu coupée aussi)"
    L.SND_auraonly = "Aucun (affiché par le jeu lui-même)"
    L.SND_power  = "Alerte de proc"
    L.SND_raid   = "Avertissement de raid"
    L.SND_ready  = "Appel"
    L.SND_alarm  = "Réveil"
    L.SND_whisper = "Chuchotement"
    L.SND_ping   = "Signal sur la carte"
    L.TEST       = "Tester"
    L.MOVE       = "À l'écran"
    L.CENTER     = "Recentrer"
    L.DRAG       = "Glisser pour déplacer - molette pour la taille"
    L.HELP       = "/flare - /flare test - /flare move - /flare notes - /flare debug"
    L.TIMER_FREE = "Déplacer le temps restant à part"
    L.TIMER_FREE_TIP = "Le temps restant a son propre cadre, qui suit l'alerte. Place-le une fois à côté de l'alerte. Ensuite, déplacer l'alerte déplace les deux. La molette change sa taille."
    L.DRAG_TIMER = "Temps restant - glisser, molette pour la taille"
    L.H_ABOUT    = "À propos"
    L.OPT_NOTES  = "Afficher les nouveautés après une mise à jour"
    L.VERSION    = "Version %s"
    L.NOTES_BTN  = "Nouveautés"
    L.NOTES_TITLE = "Shadowflare - Nouveautés"
    L.NOTES_HINT = "Tape /flare notes pour les revoir."
    L.LOADED     = "chargé. Tape /flare pour le régler."
    L.DEBUG_ON   = "débogage activé : chaque proc indique comment il a été détecté."
    L.DEBUG_OFF  = "débogage désactivé."
    L.MEMORY     = "mémoire utilisée : %.0f Ko."
    L.DETECTED   = "proc détecté (%s)."
    L.ENDED      = "proc terminé."
    L.GS_LEARNED = "%s : désormais, c'est le jeu qui affiche lui-même cette alerte (buff %d)."
    L.GS_OFF     = "alertes affichées par le jeu : désactivées. Chaque proc utilise l'alerte de Shadowflare. Tape /flare gameshow pour les réactiver."
    L.GS_ON      = "alertes affichées par le jeu : activées."
    L.GS_COMBAT  = "les buffs ne sont pas lisibles en combat : réessaie après le combat."
    L.AURA_READY = "|cff40ff40Affiché par le jeu lui-même, sans son : prêt.|r"
    L.AURA_WAIT  = "|cffffd100Affiché par le jeu lui-même, sans son : fonctionne une fois que son buff a été sur toi hors combat.|r"
    L.GS_NONE    = "aucun buff sur toi."
    L.IDS_TITLE  = "Shadowflare - numéros des sorts"
    L.IDS_TEXT   = "Chaque numéro utilisé par Shadowflare, avec le nom que lui donne le jeu. Appuie sur Ctrl+A puis Ctrl+C pour le copier, et colle-le dans un message à l'auteur."
    L.IDS_DONE   = "numéros des sorts vérifiés : %d introuvables dans ce jeu (« ? » dans la liste)."
    L.GS_STATE_GAME  = "affiché par le jeu"
    L.GS_STATE_READY = "le jeu peut l'afficher, sa fenêtre n'est pas encore faite : alerte de Shadowflare"
    L.GS_STATE_WAIT  = "détection de Shadowflare (buff pas encore vu hors combat)"
    L.H_STACKS   = "Cumuls"
    L.H_RESET    = "Remise à zéro"
    L.STACK_LOOK = "Sous le maximum"
    L.STACK_LOOK_TIP = "L'apparence de l'alerte avant le dernier cumul.\nMoins lumineuse : toute l'alerte, moins lumineuse.\nSe remplit vers le haut, Se remplit depuis la gauche : l'alerte se remplit d'une partie par cumul. Le reste reste pâle.\nPoints : toute l'alerte, avec un point par cumul en dessous."
    L.LOOK_dim = "Moins lumineuse"; L.LOOK_fillup = "Se remplit vers le haut"; L.LOOK_fillleft = "Se remplit depuis la gauche"; L.LOOK_dots = "Points"
    L.LOOKC_dim = "Moins lumineuse"; L.LOOKC_fillup = "Vers le haut"; L.LOOKC_fillleft = "Depuis la gauche"; L.LOOKC_dots = "Points"
    L.LOOKD_dim = "Toute l'alerte, moins lumineuse jusqu'au dernier cumul."
    L.LOOKD_fillup = "L'alerte se remplit depuis le bas, une partie par cumul. Le reste est pâle."
    L.LOOKD_fillleft = "L'alerte se remplit depuis la gauche, une partie par cumul. Le reste est pâle."
    L.LOOKD_dots = "Toute l'alerte, avec un point par cumul en dessous."
    L.LOOK_ONE_SIDE = "Depuis la gauche demande les deux côtés : avec un seul côté, l'alerte se remplit vers le haut."
    L.FILL_HIDE  = "Masquer la partie pas encore atteinte"
    L.FILL_HIDE_TIP = "Se remplit vers le haut et Se remplit depuis la gauche : sous le maximum, la partie pas encore remplie est masquée au lieu d'être pâle."
    L.SHOW_FOR   = "Afficher pendant"
    L.SHOW_FOR_TIP = "Combien de temps l'alerte reste après la remise à zéro, sauf si tu lances le sort avant."
    L.SECONDS    = "%d s"
    L.STACKS_FROM = "Afficher à partir de"
    L.STACKS_FROM_TIP = "L'alerte s'affiche à partir de ce nombre de cumuls. Le son ne joue qu'au maximum."
    L.STACKS_ONE = "1 cumul"
    L.STACKS_N   = "%d cumuls"
    L.STACKS_MAX = "%d cumuls (maximum)"
    L.STACK_NUM  = "Afficher le nombre de cumuls"
    L.STACK_NUM_TIP = "Affiche le nombre de cumuls à côté de l'alerte. Place l'alerte pour le déplacer. La molette sur le nombre change sa taille."
    L.STACK_SIZE = "Taille du nombre"
    L.STACK_SIZE_TIP = "Taille du nombre de cumuls. Tu peux aussi utiliser la molette dessus pendant le placement de l'alerte."
    L.DRAG_STACKS = "Cumuls - glisser, molette pour la taille"
    L.PLACING_HELP_STACKS = "Fais glisser le nombre de cumuls où tu veux."
    -- La fenêtre de réglages (0.22.0)
    L.ENTRY_SUB  = "Alertes de procs pour toutes les classes - v%s"
    L.ENTRY_TEXT = "Shadowflare a sa propre fenêtre de réglages, avec un aperçu en direct de chaque alerte pendant que tu la règles."
    L.OPEN_SETTINGS = "Ouvrir les réglages de Shadowflare"
    L.ENTRY_TIP  = "Astuce : tape /flare dans la discussion pour l'ouvrir à tout moment."
    L.H_ALERTS   = "Alertes"
    L.YOUR_CLASS = "Ta classe"
    L.BY_GAME    = "affichée par le jeu"
    L.CLASS_LINE_MINE = "%s - ta classe - %d alertes"
    L.CLASS_LINE = "%s - %d alertes"
    L.LIST_HINT  = "Coche pour activer ou couper une alerte. Clique sur un nom pour la régler."
    L.PLACE_ALL  = "Placer les alertes : %s"
    L.PLACE_ALL_TIPT = "Placer toutes les alertes"
    L.PLACE_ALL_TIP = "Affiche ensemble sur la grille toutes les alertes actives de cette classe, pour les disposer. Fais glisser chacune ; la molette sur l'une change sa taille."
    L.PLACING_ALL_TITLE = "alertes : %s"
    L.PLACING_HELP_ALL = "Fais glisser chaque alerte où tu veux : elles s'alignent sur la grille. Molette sur l'une pour sa taille, Maj + molette pour la tourner."
    L.TAB_style  = "Style"
    L.TAB_look   = "Apparence"
    L.TAB_stacks = "Cumuls"
    L.TAB_timer  = "Temps et son"
    L.COPY_BTN   = "Copier depuis..."
    L.RESET_BTN  = "Réinitialiser"
    L.SAME_LOOK_BTN   = "Même apparence pour : %s"
    L.SAME_LOOK_TITLE = "Même apparence pour la classe"
    L.SAME_LOOK_TIP   = "Donne l'apparence de l'alerte choisie (%s) à toutes les autres alertes de la même classe (%s). Les alertes des autres classes ne changent pas."
    L.SAME_LOOK_COPIED = "Copié : style, couleur, taille, angle, côtés et écart, animation, luminosité, ombre, bords de l'écran, temps restant (sur l'alerte ou à part, sa taille, son alignement et sa police), et l'apparence des cumuls entre alertes qui en ont."
    L.SAME_LOOK_KEPT  = "Gardé sur chaque alerte : sa place à l'écran (et celle de son temps restant et de son nombre de cumuls), si elle est activée, son son, Seulement en combat, Afficher à partir de, et combien de temps elle reste."
    L.SAME_LOOK_ASK   = "Donner l'apparence de %s aux %d autres alertes %s ? Leur place à l'écran, leur son et leur activation sont gardés. Impossible d'annuler."
    L.SAME_LOOK_OK    = "Appliquer"
    L.SAME_LOOK_DONE  = "apparence de %s donnée à %d autres alertes de sa classe."
    L.RESET_TIP  = "Remet l'apparence de cette alerte par défaut. Sa place et sa taille à l'écran sont gardées."
    L.RESET_ASK  = "Remettre l'apparence de %s par défaut ? Sa place et sa taille à l'écran sont gardées."
    L.ANIMS_breath = "Respiration"; L.ANIMS_classic = "Pulsation"; L.ANIMS_impact = "Impact"; L.ANIMS_impactpulse = "Impact pulsé"; L.ANIMS_flash = "Éclairs"; L.ANIMS_still = "Fixe"
    L.ANIMD_breath = "Apparaît en fondu, respire lentement (plus vite les 3 dernières secondes), disparaît en fondu. Pour les longs buffs."
    L.ANIMD_classic = "Jaillit comme l'ancienne alerte de proc du jeu, pulse chaque seconde, grandit en partant. Pour les sorts gratuits ou plus rapides."
    L.ANIMD_impact = "Arrive d'un coup avec un éclat blanc, puis reste fixe. Pour les fenêtres courtes : à utiliser tout de suite."
    L.ANIMD_impactpulse = "Arrive d'un coup avec un éclat blanc comme Impact, puis pulse chaque seconde comme Pulsation."
    L.ANIMD_flash = "Trois éclairs francs, puis reste fixe. Pour les procs rares et puissants."
    L.ANIMD_still = "S'allume et s'éteint d'un coup, rien ne bouge. Pour les états comme Exécution."
    L.ANIM_EXIT  = "Quand tu utilises le proc, il éclate ; quand il expire, il s'efface. L'aperçu montre les deux."
    L.ANIM_GAME  = "Cette alerte est affichée par le jeu lui-même : en jeu, elle apparaît d'un coup et reste fixe."
    L.ANIM_TARGET = "Cette alerte suit ta cible : elle apparaît et part d'un coup, sans fondu."
    L.NOMOVES    = "Sans entrée ni sortie"
    L.NOMOVES_TIP = "Cette alerte apparaît d'un coup et part avec un fondu rapide, et ne frappe pas quand elle revient. Son animation continue de bouger tant qu'elle est affichée."
    L.ANIM_NOMOVES = "Sans entrée ni sortie : elle apparaît d'un coup et part avec un fondu rapide."
    L.EXIT_USED  = "Utilisé"
    L.EXIT_RANOUT = "Expiré"
    L.H_BRIGHT   = "Luminosité et angle"
    L.SIZE_MOVED = "La taille est à côté de l'aperçu, avec Placer à l'écran."
    L.H_SIDES    = "Côtés"
    L.SIDE_both  = "Les deux côtés"; L.SIDE_left = "Côté gauche"; L.SIDE_right = "Côté droit"
    L.SPACING    = "Écart"
    L.SPACING_TIP = "Écarte les deux côtés, ou les rapproche, sans les agrandir."
    L.SIDES_NONE = "Seulement pour les styles dessinés sur deux côtés, comme Arcs."
    L.H_NUMBER   = "Nombre de cumuls"
    L.H_TIME     = "Temps restant"
    L.TIME_ON    = "Sur l'alerte"
    L.TIME_APART = "Placé à part"
    L.TIME_OFF   = "Masqué"
    L.TIME_SIZE  = "Taille du texte"
    L.TIME_ALIGN = "Alignement"
    L.TIME_ALIGN_TIP = "Comment le temps restant placé à part se tient à sa place. Gauche garde son bord gauche fixe, pour que les chiffres ne bougent pas quand leur largeur change (10, 9.9, 8). Droite garde son bord droit fixe."
    L.ALIGN_LEFT = "Gauche"; L.ALIGN_CENTER = "Centre"; L.ALIGN_RIGHT = "Droite"
    L.FONT       = "Police"
    L.FONT_TIP   = "La police de chaque texte de cette alerte : le temps restant, les mots des styles qui en ont (Texte, Barre...) et le nombre de cumuls. Les polices du jeu, plus celles que partagent d'autres addons, si tu en as."
    L.FONT_GAME  = "Police du jeu (par défaut)"
    L.TIME_SIZE_TIP = "Taille du temps restant quand il est placé à part. Tu peux aussi utiliser la molette dessus pendant le placement de l'alerte."
    L.H_EDGES    = "Bords de l'écran"
    L.PLAY       = "Écouter"
    L.PLAY_TIP   = "Joue le son de cette alerte."
    L.SOUND_WHEN = "Joue une fois quand l'alerte s'affiche (au maximum pour les procs à cumuls)."
    L.H_WHEN     = "Quand afficher"
    L.ONLY_COMBAT = "Seulement en combat"
    L.ONLY_COMBAT_TIP = "N'affiche cette alerte que pendant un combat. Décoche pour la voir aussi entre les combats."
    L.ONLY_COMBAT_HINT = "Coché par défaut. Décoché pour Ivresse de la victoire : une victime termine souvent le combat."
    L.OTHER_STANCES = "Aussi dans les autres postures"
    L.OTHER_STANCES_TIP = "Dans une autre posture, le jeu dit que cette technique n'est pas utilisable. Coché, Shadowflare suit lui-même l'esquive, la parade ou le blocage et affiche l'alerte avec la posture à prendre. En groupe, l'esquive d'une attaque d'un autre joueur peut aussi afficher Fulgurance."
    L.OTHER_STANCES_HINT = "Décoché par défaut. En test."
    L.STANCE_2457 = "Posture de combat"; L.STANCE_71 = "Posture défensive"
    L.BG_LABEL   = "Fond"
    L.BG_DARK    = "Sombre"
    L.BG_BRIGHT  = "Clair"
    L.BG_TIP     = "Pour l'aperçu seulement : voir l'alerte sur un sol sombre ou clair."
    L.STACKS_LABEL = "Cumuls"
    L.STACKS_MAXS = "%d cumuls (max)"
    L.PLAY_STACKS = "Lecture"
    L.PV_PLAY    = "Lecture"
    L.PV_PLAY_TIP = "Joue l'alerte dans l'aperçu : son entrée, son animation, son temps, sa sortie, et ses cumuls qui montent, en boucle."
    L.PV_STOP    = "Arrêt"
    L.PV_STOP_TIP = "Fige l'aperçu, pour régler l'apparence de l'alerte tranquillement."
    L.PLAY_STACKS_TIP = "Joue de 1 cumul jusqu'au maximum, en boucle. Clique sur un nombre ou une image en dessous pour rester dessus."
    L.ENDS_SOON  = "Fin proche"
    L.ENDS_SOON_TIP = "Les 3 dernières secondes de l'alerte."
    L.REAL_SIZE  = "Taille réelle"
    L.SHOWN_AT   = "Affichée à %d %%"
    L.PLACE_ON_SCREEN = "Placer à l'écran"
    L.PLACE_HINT = "L'alerte est prête telle que tu la vois : à l'écran tu n'as plus qu'à la déplacer et régler sa taille."
end

ns.L = L
