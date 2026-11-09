
ForeverAurasSaved = {
["totemSpells"] = {
},
["editor_tab_spaces"] = 4,
["displays"] = {
["Revenge"] = {
["iconSource"] = -1,
["xOffset"] = 0,
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["cooldownSwipe"] = true,
["cooldownEdge"] = false,
["actions"] = {
["start"] = {
},
["finish"] = {
},
["init"] = {
},
},
["triggers"] = {
{
["trigger"] = {
["auraReadableSettings"] = {
["debuffType"] = "HELPFUL",
},
["cdmSource"] = "cooldown",
["genericShowOn"] = "showOnCooldown",
["unit"] = "player",
["cdmSpells"] = {
["multi"] = {
},
},
["debuffType"] = "HELPFUL",
["type"] = "spell",
["auraspellids"] = {
"6572",
},
["spellName"] = 6574,
["use_track"] = true,
["event"] = "Action Usable",
["use_genericShowOn"] = true,
["use_cdmSpells"] = false,
["use_spellName"] = true,
["spellIds"] = {
},
["useExactSpellId"] = true,
["subeventSuffix"] = "_CAST_START",
["names"] = {
},
["secretUseSpellIDs"] = true,
["subeventPrefix"] = "SPELL",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = 1,
},
["internalVersion"] = 91,
["progressSource"] = {
-1,
"",
},
["animation"] = {
["start"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["desaturate"] = false,
["subRegions"] = {
{
["type"] = "subbackground",
},
{
["text_text_format_p_time_precision"] = 1,
["text_text"] = "%p",
["text_text_format_p_time_mod_rate"] = true,
["text_selfPoint"] = "AUTO",
["text_automaticWidth"] = "Auto",
["text_fixedWidth"] = 64,
["text_shadowColor"] = {
0,
0,
0,
1,
},
["anchorYOffset"] = 0,
["text_justify"] = "CENTER",
["rotateText"] = "NONE",
["anchorXOffset"] = 0,
["text_shadowXOffset"] = 0,
["text_text_format_p_time_format"] = 0,
["type"] = "subtext",
["text_anchorXOffset"] = 0,
["text_color"] = {
1,
1,
1,
1,
},
["text_font"] = "Friz Quadrata TT",
["text_alpha"] = 1,
["text_shadowYOffset"] = 0,
["text_visible"] = true,
["text_wordWrap"] = "WordWrap",
["text_fontType"] = "OUTLINE",
["text_text_format_p_format"] = "timed",
["text_anchorYOffset"] = 0,
["anchor_point"] = "CENTER",
["text_fontSize"] = 16,
["text_text_format_p_time_dynamic_threshold"] = 60,
["text_text_format_p_time_legacy_floor"] = false,
},
{
["glowFrequency"] = 0.25,
["type"] = "subglow",
["glowDuration"] = 1.5,
["glowType"] = "Proc",
["glowLength"] = 10,
["glowYOffset"] = 0,
["glowColor"] = {
0.7764706015586853,
0.6078431606292725,
0.4274509847164154,
1,
},
["useGlowColor"] = true,
["glowXOffset"] = 0,
["glowThickness"] = 1,
["glowScale"] = 1,
["glow"] = true,
["glowLines"] = 8,
["glowBorder"] = false,
},
},
["height"] = 64,
["load"] = {
["talent"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["multi"] = {
},
},
["size"] = {
["multi"] = {
},
},
},
["useAdjustededMax"] = false,
["color"] = {
1,
1,
1,
1,
},
["useAdjustededMin"] = false,
["regionType"] = "icon",
["selfPoint"] = "CENTER",
["authorOptions"] = {
},
["parent"] = "Procs",
["information"] = {
},
["zoom"] = 0,
["uid"] = "Ta)YCrooQHh",
["cooldownTextDisabled"] = true,
["useCooldownModRate"] = true,
["anchorFrameType"] = "SCREEN",
["id"] = "Revenge",
["alpha"] = 1,
["frameStrata"] = 1,
["width"] = 64,
["blizzardAuraDisplay"] = {
["actionSounds"] = true,
["sharedDisplay"] = true,
},
["config"] = {
},
["inverse"] = true,
["icon"] = true,
["conditions"] = {
},
["cooldown"] = true,
["keepAspectRatio"] = false,
},
["Procs"] = {
["grow"] = "HORIZONTAL",
["controlledChildren"] = {
"Overpower",
"Revenge",
"Execute",
"Victory Rush",
},
["borderBackdrop"] = "Blizzard Tooltip",
["xOffset"] = 0,
["yOffset"] = -100,
["anchorPoint"] = "CENTER",
["borderColor"] = {
0,
0,
0,
1,
},
["space"] = 2,
["actions"] = {
["start"] = {
},
["init"] = {
},
["finish"] = {
},
},
["triggers"] = {
{
["trigger"] = {
["type"] = "aura2",
["subeventSuffix"] = "_CAST_START",
["auraTracking"] = "readable",
["event"] = "Health",
["subeventPrefix"] = "SPELL",
["spellIds"] = {
},
["names"] = {
},
["unit"] = "player",
["debuffType"] = "HELPFUL",
},
["untrigger"] = {
},
},
},
["columnSpace"] = 1,
["radius"] = 200,
["selfPoint"] = "CENTER",
["align"] = "CENTER",
["stagger"] = 0,
["useLimit"] = false,
["subRegions"] = {
},
["borderInset"] = 1,
["borderPixelPerfect"] = true,
["load"] = {
["size"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["multi"] = {
},
},
["talent"] = {
["multi"] = {
},
},
},
["fullCircle"] = true,
["backdropColor"] = {
1,
1,
1,
0.5,
},
["uid"] = "iGoAyxhjVg4",
["animate"] = false,
["animation"] = {
["start"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["scale"] = 1,
["centerType"] = "LR",
["border"] = false,
["borderEdge"] = "Square Full White",
["stepAngle"] = 15,
["borderSize"] = 2,
["limit"] = 5,
["authorOptions"] = {
},
["sort"] = "none",
["constantFactor"] = "RADIUS",
["arcLength"] = 360,
["borderOffset"] = 4,
["gridWidth"] = 5,
["rowSpace"] = 1,
["id"] = "Procs",
["frameStrata"] = 1,
["alpha"] = 1,
["anchorFrameType"] = "SCREEN",
["gridType"] = "RD",
["config"] = {
},
["internalVersion"] = 91,
["regionType"] = "dynamicgroup",
["conditions"] = {
},
["information"] = {
},
["rotation"] = 0,
},
["Execute"] = {
["iconSource"] = -1,
["parent"] = "Procs",
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["cooldownSwipe"] = true,
["cooldownEdge"] = false,
["actions"] = {
["start"] = {
},
["init"] = {
},
["finish"] = {
},
},
["triggers"] = {
{
["trigger"] = {
["auraReadableSettings"] = {
["debuffType"] = "HELPFUL",
},
["cdmSource"] = "cooldown",
["genericShowOn"] = "showOnCooldown",
["names"] = {
},
["cdmSpells"] = {
["multi"] = {
["199709"] = true,
},
},
["debuffType"] = "HELPFUL",
["type"] = "spell",
["spellName"] = 5308,
["useExactSpellId"] = true,
["use_track"] = true,
["use_genericShowOn"] = true,
["event"] = "Action Usable",
["cdmBuffShow"] = "active",
["use_cdmSpells"] = false,
["use_spellName"] = true,
["spellIds"] = {
},
["subeventSuffix"] = "_CAST_START",
["unit"] = "player",
["auraspellids"] = {
"5308",
},
["secretUseSpellIDs"] = true,
["subeventPrefix"] = "SPELL",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = 1,
},
["internalVersion"] = 91,
["progressSource"] = {
-1,
"",
},
["selfPoint"] = "CENTER",
["desaturate"] = false,
["subRegions"] = {
{
["type"] = "subbackground",
},
{
["text_shadowXOffset"] = 0,
["text_text"] = "%p",
["text_shadowColor"] = {
0,
0,
0,
1,
},
["text_selfPoint"] = "AUTO",
["text_automaticWidth"] = "Auto",
["text_fixedWidth"] = 64,
["text_text_format_p_time_precision"] = 1,
["text_text_format_p_time_legacy_floor"] = false,
["text_justify"] = "CENTER",
["rotateText"] = "NONE",
["text_text_format_p_time_dynamic_threshold"] = 60,
["anchorYOffset"] = 0,
["text_text_format_p_format"] = "timed",
["type"] = "subtext",
["text_anchorXOffset"] = 0,
["text_color"] = {
1,
1,
1,
1,
},
["text_font"] = "Friz Quadrata TT",
["text_anchorYOffset"] = 0,
["text_alpha"] = 1,
["text_text_format_p_time_format"] = 0,
["text_wordWrap"] = "WordWrap",
["text_visible"] = true,
["text_fontType"] = "OUTLINE",
["text_shadowYOffset"] = 0,
["anchor_point"] = "CENTER",
["text_fontSize"] = 16,
["anchorXOffset"] = 0,
["text_text_format_p_time_mod_rate"] = true,
},
{
["glowFrequency"] = 0.25,
["type"] = "subglow",
["useGlowColor"] = true,
["glowType"] = "Proc",
["glowLength"] = 10,
["glowYOffset"] = 0,
["glowColor"] = {
0.7764706015586853,
0.6078431606292725,
0.4274509847164154,
1,
},
["glowDuration"] = 1.5,
["glowXOffset"] = 0,
["glow"] = true,
["glowScale"] = 1,
["glowThickness"] = 1,
["glowLines"] = 8,
["glowBorder"] = false,
},
},
["height"] = 64,
["load"] = {
["size"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["multi"] = {
},
},
["talent"] = {
["multi"] = {
},
},
},
["useAdjustededMax"] = false,
["xOffset"] = 0,
["useAdjustededMin"] = false,
["regionType"] = "icon",
["keepAspectRatio"] = false,
["authorOptions"] = {
},
["icon"] = true,
["cooldown"] = true,
["cooldownTextDisabled"] = true,
["config"] = {
},
["zoom"] = 0,
["frameStrata"] = 1,
["width"] = 64,
["id"] = "Execute",
["useCooldownModRate"] = true,
["alpha"] = 1,
["anchorFrameType"] = "SCREEN",
["blizzardAuraDisplay"] = {
["actionSounds"] = true,
["sharedDisplay"] = true,
},
["uid"] = "mvVypd)ATuC",
["inverse"] = true,
["animation"] = {
["start"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["conditions"] = {
},
["information"] = {
},
["color"] = {
1,
1,
1,
1,
},
},
["Victory Rush"] = {
["iconSource"] = -1,
["xOffset"] = 0,
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["cooldownSwipe"] = true,
["cooldownEdge"] = false,
["icon"] = true,
["triggers"] = {
{
["trigger"] = {
["auraReadableSettings"] = {
["debuffType"] = "HELPFUL",
},
["type"] = "cdm",
["useExactSpellId"] = true,
["cdmSpells"] = {
["multi"] = {
["199584"] = true,
["200436"] = true,
},
},
["cdmSource"] = "buff",
["event"] = "Blizzard CDM Buff",
["subeventPrefix"] = "SPELL",
["use_cdmSpells"] = false,
["auraspellids"] = {
"402927",
},
["spellIds"] = {
},
["unit"] = "player",
["subeventSuffix"] = "_CAST_START",
["names"] = {
},
["secretUseSpellIDs"] = true,
["debuffType"] = "HELPFUL",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = 1,
},
["internalVersion"] = 91,
["keepAspectRatio"] = false,
["animation"] = {
["start"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["easeStrength"] = 3,
["type"] = "none",
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["desaturate"] = false,
["subRegions"] = {
{
["type"] = "subbackground",
},
{
["text_text_format_p_time_precision"] = 1,
["text_text"] = "%p",
["text_shadowColor"] = {
0,
0,
0,
1,
},
["text_selfPoint"] = "AUTO",
["text_automaticWidth"] = "Auto",
["text_fixedWidth"] = 64,
["text_shadowXOffset"] = 0,
["text_text_format_p_time_legacy_floor"] = false,
["text_justify"] = "CENTER",
["rotateText"] = "NONE",
["anchorXOffset"] = 0,
["text_text_format_p_time_mod_rate"] = true,
["text_text_format_p_time_format"] = 0,
["type"] = "subtext",
["text_anchorXOffset"] = 0,
["text_color"] = {
1,
1,
1,
1,
},
["text_font"] = "Friz Quadrata TT",
["text_alpha"] = 1,
["text_shadowYOffset"] = 0,
["text_fontType"] = "OUTLINE",
["text_wordWrap"] = "WordWrap",
["text_visible"] = true,
["text_text_format_p_format"] = "timed",
["text_anchorYOffset"] = 0,
["anchor_point"] = "CENTER",
["text_fontSize"] = 16,
["text_text_format_p_time_dynamic_threshold"] = 60,
["anchorYOffset"] = 0,
},
{
["glowFrequency"] = 0.25,
["type"] = "subglow",
["glowDuration"] = 1.5,
["glowType"] = "Proc",
["glowLength"] = 10,
["glowYOffset"] = 0,
["glowColor"] = {
0.7764706015586853,
0.6078431606292725,
0.4274509847164154,
1,
},
["useGlowColor"] = true,
["glowXOffset"] = 0,
["glowThickness"] = 1,
["glowScale"] = 1,
["glow"] = true,
["glowLines"] = 8,
["glowBorder"] = false,
},
},
["height"] = 64,
["load"] = {
["talent"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["multi"] = {
},
},
["size"] = {
["multi"] = {
},
},
},
["useAdjustededMax"] = false,
["color"] = {
1,
1,
1,
1,
},
["useAdjustededMin"] = false,
["regionType"] = "icon",
["selfPoint"] = "CENTER",
["authorOptions"] = {
},
["actions"] = {
["start"] = {
},
["finish"] = {
},
["init"] = {
},
},
["information"] = {
},
["zoom"] = 0,
["uid"] = "DFL3XphBd22",
["cooldownTextDisabled"] = true,
["alpha"] = 1,
["anchorFrameType"] = "SCREEN",
["id"] = "Victory Rush",
["frameStrata"] = 1,
["useCooldownModRate"] = true,
["width"] = 64,
["blizzardAuraDisplay"] = {
["actionSounds"] = true,
["sharedDisplay"] = true,
},
["config"] = {
},
["inverse"] = true,
["parent"] = "Procs",
["conditions"] = {
},
["cooldown"] = true,
["progressSource"] = {
-1,
"",
},
},
["Overpower"] = {
["iconSource"] = -1,
["color"] = {
1,
1,
1,
1,
},
["adjustedMax"] = "",
["adjustedMin"] = "",
["yOffset"] = 0,
["anchorPoint"] = "CENTER",
["cooldownSwipe"] = true,
["cooldownEdge"] = false,
["actions"] = {
["start"] = {
},
["init"] = {
},
["finish"] = {
},
},
["triggers"] = {
{
["trigger"] = {
["auraReadableSettings"] = {
["debuffType"] = "HELPFUL",
},
["cdmSource"] = "buff",
["genericShowOn"] = "showOnCooldown",
["subeventPrefix"] = "SPELL",
["cdmSpells"] = {
["multi"] = {
["199557"] = true,
},
},
["debuffType"] = "HELPFUL",
["type"] = "spell",
["auraspellids"] = {
"7384",
},
["spellName"] = 7384,
["use_track"] = true,
["event"] = "Action Usable",
["use_genericShowOn"] = true,
["use_cdmSpells"] = false,
["use_spellName"] = true,
["spellIds"] = {
},
["subeventSuffix"] = "_CAST_START",
["useExactSpellId"] = true,
["names"] = {
},
["secretUseSpellIDs"] = true,
["unit"] = "player",
},
["untrigger"] = {
},
},
["activeTriggerMode"] = 1,
},
["internalVersion"] = 91,
["progressSource"] = {
-1,
"",
},
["animation"] = {
["start"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
["main"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
["finish"] = {
["type"] = "none",
["easeStrength"] = 3,
["duration_type"] = "seconds",
["easeType"] = "none",
},
},
["desaturate"] = false,
["subRegions"] = {
{
["type"] = "subbackground",
},
{
["text_shadowXOffset"] = 0,
["text_text"] = "%p",
["text_shadowColor"] = {
0,
0,
0,
1,
},
["text_selfPoint"] = "AUTO",
["text_automaticWidth"] = "Auto",
["text_fixedWidth"] = 64,
["text_text_format_p_time_precision"] = 1,
["anchorYOffset"] = 0,
["text_justify"] = "CENTER",
["rotateText"] = "NONE",
["text_text_format_p_time_dynamic_threshold"] = 60,
["text_text_format_p_time_legacy_floor"] = false,
["text_text_format_p_format"] = "timed",
["type"] = "subtext",
["text_anchorXOffset"] = 0,
["text_color"] = {
1,
1,
1,
1,
},
["text_font"] = "Friz Quadrata TT",
["text_anchorYOffset"] = 0,
["text_alpha"] = 1,
["text_text_format_p_time_format"] = 0,
["text_wordWrap"] = "WordWrap",
["text_fontType"] = "OUTLINE",
["text_visible"] = true,
["text_shadowYOffset"] = 0,
["anchor_point"] = "CENTER",
["text_fontSize"] = 16,
["anchorXOffset"] = 0,
["text_text_format_p_time_mod_rate"] = true,
},
{
["glowFrequency"] = 0.25,
["type"] = "subglow",
["useGlowColor"] = true,
["glowType"] = "Proc",
["glowLength"] = 10,
["glowYOffset"] = 0,
["glowColor"] = {
0.7764706015586853,
0.6078431606292725,
0.4274509847164154,
1,
},
["glowDuration"] = 1.5,
["glowXOffset"] = 0,
["glow"] = true,
["glowScale"] = 1,
["glowThickness"] = 1,
["glowLines"] = 8,
["glowBorder"] = false,
},
},
["height"] = 64,
["load"] = {
["size"] = {
["multi"] = {
},
},
["spec"] = {
["multi"] = {
},
},
["class"] = {
["multi"] = {
},
},
["talent"] = {
["multi"] = {
},
},
},
["useAdjustededMax"] = false,
["keepAspectRatio"] = false,
["useAdjustededMin"] = false,
["regionType"] = "icon",
["icon"] = true,
["parent"] = "Procs",
["xOffset"] = 0,
["cooldown"] = true,
["cooldownTextDisabled"] = true,
["config"] = {
},
["zoom"] = 0,
["alpha"] = 1,
["width"] = 64,
["id"] = "Overpower",
["frameStrata"] = 1,
["useCooldownModRate"] = true,
["anchorFrameType"] = "SCREEN",
["blizzardAuraDisplay"] = {
["actionSounds"] = true,
["sharedDisplay"] = true,
},
["uid"] = "GpYa3yvbSnU",
["inverse"] = true,
["authorOptions"] = {
},
["conditions"] = {
},
["information"] = {
},
["selfPoint"] = "CENTER",
},
},
["dynamicIconCache"] = {
},
["login_squelch_time"] = 10,
["lastArchiveClear"] = 1794171340,
["minimap"] = {
["minimapPos"] = 243.1006153327326,
["hide"] = true,
},
["lastUpgrade"] = 1794171345,
["dbVersion"] = 91,
["migrationCutoff"] = 730,
["registered"] = {
},
["editor_font_size"] = 12,
["historyCutoff"] = 730,
["totemNames"] = {
},
["features"] = {
},
}
