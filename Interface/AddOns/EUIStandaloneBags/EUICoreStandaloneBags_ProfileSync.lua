if _G.__EUISTANDALONE_BAGS_INERT then return end
if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EUICoreStandaloneBags_ClientGate.lua)
-------------------------------------------------------------------------------
--  EUICoreStandaloneBags_ProfileSync.lua
--  Profile sync mirror groups, per-module sync exclusions, and the sync
--  popup anchored to the sidebar. Loads after EUICoreStandaloneBags_Fonts.lua.
-------------------------------------------------------------------------------
local EUICoreStandaloneBags = _G.EUICoreStandaloneBags
-- Private namespace shared with EUICoreStandaloneBags.lua (sidebar buttons).
local _, EUI_NS = ...
EUI_NS = EUI_NS.__euiCoreNS or EUI_NS  -- standalone builds: the core's own table (EUICoreStandaloneBags.lua)

-------------------------------------------------------------------------------
--  Profile Sync System (mirror groups)
--  A module's sync set is a MEMBERSHIP group (popup adds the configuring profile too).
--  Two-way: active member pushes a selective copy to others on sync click, logout, and
--  profile switch; outside profiles never push in. Storage: EUICoreStandaloneBagsDB.syncedModules
--  = { [folder] = { [profileName] = true } }. Exclusions: EUICoreStandaloneBags._syncExclusions
--  [folder] = { key = true }; dot-wildcard "bars.*.growDirection" skips that key in any sub-table of bars.
-------------------------------------------------------------------------------
do
    -- Modules that should NOT get a sync icon (no per-profile settings; Loadout
    -- Manager and Simple Loot Council keep stores of their own)
    local SYNC_EXEMPT = { EUICoreStandaloneBagsPartyMode = true, EUICoreStandaloneBagsLoadoutManager = true,
        EUICoreStandaloneBagsSimpleLootCouncil = true }
    EUICoreStandaloneBags._syncExempt = SYNC_EXEMPT

    -- Modules with a sync icon but no per-profile data (always "synced"). BlizzardSkin hosts
    -- Dragon Riding's per-profile DB; its sync icon routes to EUICoreStandaloneBagsDragonRiding via syncFolder.
    local SYNC_GLOBAL_ONLY = { EUICoreStandaloneBagsForeverEssentials = true }
    EUICoreStandaloneBags._syncGlobalOnly = SYNC_GLOBAL_ONLY

    -- Exclusion registry: keys NOT copied during sync (flat or dot-wildcard, see banner)
    local syncExclusions = {}
    EUICoreStandaloneBags._syncExclusions = syncExclusions

    function EUICoreStandaloneBags.RegisterSyncExclusions(folder, keys)
        if not syncExclusions[folder] then syncExclusions[folder] = {} end
        local ex = syncExclusions[folder]
        for _, k in ipairs(keys) do
            ex[k] = true
        end
    end

    -- Merged exclusions for ONE src->dst copy: static registry plus every setting EITHER
    -- profile holds a spec/conditional OVERRIDE entry for (override-owned keys never sync --
    -- the override system owns them; a pushed blob would drift from the dest's recorded values).
    -- PURE READ of profile tables only (no override store creation/harvest/apply/capture).
    -- Returns staticEx unchanged (zero alloc) when neither profile has override data, else a
    -- fresh table (shared registry never mutated); callers pcall and fall back to staticEx on error.
    -- fkey = folder.."\31"..path, segments joined by "\30" (mirrors SplitFKey in
    -- EUICoreStandaloneBags_SpecOverrides.lua); matcher walks the tree dot-joined so gsub("\30",".") is exact.
    EUICoreStandaloneBags._SyncExclusionsWithOverrides = function(folder, staticEx, srcProf, dstProf)
        local merged
        local function ensure()
            if not merged then
                merged = {}
                if staticEx then for k in pairs(staticEx) do merged[k] = true end end
            end
        end
        local function addStore(store)
            if type(store) ~= "table" then return end
            for _, entry in ipairs(store) do
                local vals = type(entry) == "table" and entry.values
                if type(vals) == "table" then
                    for _, m in pairs(vals) do  -- default map + every spec/gid map
                        if type(m) == "table" then
                            for fkey in pairs(m) do
                                if type(fkey) == "string" then
                                    local f, path = fkey:match("^([^\31]+)\31(.*)$")
                                    if f == folder and path and path ~= "" then
                                        ensure()
                                        merged[path:gsub("\30", ".")] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local function addProf(prof)
            if type(prof) ~= "table" then return end
            addStore(prof.specOverrides)
            addStore(prof.condOverrides)
            if folder == "EUICoreStandaloneBagsRaidFrames" then
                -- BM forks are layer-shaped, not fkey-shaped: the fork system writes
                -- bmIndicators/bmSimple/bmDisplayMode/bmIconZoom straight into the live RF blob,
                -- so if EITHER profile carries ANY BM layer, those keys are fork territory and
                -- must not sync (emptiness check mirrors the BM harvest's zero-cost gate).
                local s, c = prof.specBmOverrides, prof.condBmOverrides
                if (type(s) == "table" and (s.active or s.baselineLayout
                        or (type(s.layouts) == "table" and next(s.layouts))))
                   or (type(c) == "table" and type(c.layouts) == "table"
                        and next(c.layouts)) then
                    ensure()
                    merged.bmIndicators  = true
                    merged.bmSimple      = true
                    merged.bmDisplayMode = true
                    merged.bmIconZoom    = true
                    merged.bm2           = true   -- v2 payload rides BM layers
                end
                -- Debuff Manager forks own the dmDebuff subtree the same way.
                local ds, dc = prof.specDmOverrides, prof.condDmOverrides
                if (type(ds) == "table" and (ds.active or ds.baselineLayout
                        or (type(ds.layouts) == "table" and next(ds.layouts))))
                   or (type(dc) == "table" and type(dc.layouts) == "table"
                        and next(dc.layouts)) then
                    ensure()
                    merged.dmDebuff = true
                end
            end
        end
        addProf(srcProf)
        addProf(dstProf)
        return merged or staticEx
    end

    -- Selective deep-copy: src minus excluded keys (flat "barPositions" or wildcard
    -- "bars.*.growDirection" = skip that key in any sub-table of "bars").
    local function SelectiveCopy(src, exclusions, parentPath)
        if type(src) ~= "table" then return src end
        local copy = {}
        for k, v in pairs(src) do
            local keyStr = tostring(k)
            local fullKey = parentPath and (parentPath .. "." .. keyStr) or keyStr
            if not exclusions[fullKey] then
                if type(v) == "table" then
                    -- Wildcard parent check (e.g. "bars" in "bars.*.X")
                    local isWildcardParent = false
                    local childExclusions = nil
                    for exKey in pairs(exclusions) do
                        local prefix, childKey = exKey:match("^(.-)%.%*%.(.+)$")
                        -- Full-path match only (a bare-name collision is not a wildcard parent)
                        if prefix and fullKey == prefix then
                            isWildcardParent = true
                            if not childExclusions then childExclusions = {} end
                            childExclusions[childKey] = true
                        end
                    end
                    if isWildcardParent and childExclusions then
                        -- Copy the container but apply child exclusions to each sub-table
                        local containerCopy = {}
                        for ck, cv in pairs(v) do
                            if type(cv) == "table" then
                                local subCopy = {}
                                local subPath = fullKey .. "." .. tostring(ck)
                                for sk, sv in pairs(cv) do
                                    local leafPath = subPath .. "." .. tostring(sk)
                                    if not childExclusions[tostring(sk)] and not exclusions[leafPath] then
                                        if type(sv) == "table" then
                                            subCopy[sk] = SelectiveCopy(sv, exclusions, leafPath)
                                        else
                                            subCopy[sk] = sv
                                        end
                                    end
                                end
                                containerCopy[ck] = subCopy
                            else
                                containerCopy[ck] = cv
                            end
                        end
                        copy[k] = containerCopy
                    else
                        copy[k] = SelectiveCopy(v, exclusions, fullKey)
                    end
                else
                    copy[k] = v
                end
            end
        end
        return copy
    end
    EUICoreStandaloneBags._SelectiveCopy = SelectiveCopy

    -- True when an exclusion is fullKey itself or a path below it, by string prefix; a
    -- wildcard only counts above its '*', so a removed list entry goes with its
    -- wildcard-excluded leaves.
    local function HoldsExclusion(exclusions, fullKey)
        if exclusions[fullKey] then return true end
        local pre = fullKey .. "."
        for exKey in pairs(exclusions) do
            if exKey:sub(1, #pre) == pre then return true end
        end
        return false
    end

    -- Exclusion-aware deep overlay for destinations with existing data: writes src into dst
    -- leaf-by-leaf wherever an exclusion path (flat/dotted/wildcard) touches the subtree, so
    -- excluded keys keep dest values (replacing a parent whole would delete them).
    function EUICoreStandaloneBags._SelectiveOverlay(src, dst, exclusions, deepCopy, parentPath)
        -- Mirror deletions, as the full copy does: drop dest keys the source no
        -- longer has, unless they hold excluded data.
        for k in pairs(dst) do
            if src[k] == nil then
                local fullKey = parentPath and (parentPath .. "." .. tostring(k)) or tostring(k)
                if not HoldsExclusion(exclusions, fullKey) then dst[k] = nil end
            end
        end
        for k, v in pairs(src) do
            local keyStr = tostring(k)
            local fullKey = parentPath and (parentPath .. "." .. keyStr) or keyStr
            if not exclusions[fullKey] then
                if type(v) == "table" then
                    -- Wildcard parent and/or dotted exclusions deeper in this subtree
                    local childExclusions = nil
                    local hasNested = false
                    for exKey in pairs(exclusions) do
                        local prefix, childKey = exKey:match("^(.-)%.%*%.(.+)$")
                        -- Full-path match only (same rule as SelectiveCopy)
                        if prefix and fullKey == prefix then
                            if not childExclusions then childExclusions = {} end
                            childExclusions[childKey] = true
                        elseif exKey:sub(1, #fullKey + 1) == (fullKey .. ".") then
                            hasNested = true
                        end
                    end
                    if childExclusions then
                        -- Merge each sub-table, preserving excluded child keys
                        if type(dst[k]) ~= "table" then dst[k] = {} end
                        local dstContainer = dst[k]
                        for ck in pairs(dstContainer) do
                            if v[ck] == nil
                               and not HoldsExclusion(exclusions, fullKey .. "." .. tostring(ck)) then
                                dstContainer[ck] = nil
                            end
                        end
                        for ck, cv in pairs(v) do
                            if type(cv) == "table" then
                                if type(dstContainer[ck]) ~= "table" then dstContainer[ck] = {} end
                                local dstSub = dstContainer[ck]
                                local subPath = fullKey .. "." .. tostring(ck)
                                -- Exact paths below the wildcard (override-owned keys) are
                                -- excluded too, not only the wildcard child names.
                                for sk in pairs(dstSub) do
                                    if cv[sk] == nil and not childExclusions[tostring(sk)]
                                       and not HoldsExclusion(exclusions, subPath .. "." .. tostring(sk)) then
                                        dstSub[sk] = nil
                                    end
                                end
                                for sk, sv in pairs(cv) do
                                    local leafPath = subPath .. "." .. tostring(sk)
                                    if not childExclusions[tostring(sk)] and not exclusions[leafPath] then
                                        if type(sv) == "table" and HoldsExclusion(exclusions, leafPath) then
                                            if type(dstSub[sk]) ~= "table" then dstSub[sk] = {} end
                                            EUICoreStandaloneBags._SelectiveOverlay(sv, dstSub[sk], exclusions, deepCopy, leafPath)
                                        else
                                            dstSub[sk] = type(sv) == "table" and deepCopy(sv) or sv
                                        end
                                    end
                                end
                            else
                                dstContainer[ck] = cv
                            end
                        end
                    elseif hasNested then
                        if type(dst[k]) ~= "table" then dst[k] = {} end
                        EUICoreStandaloneBags._SelectiveOverlay(v, dst[k], exclusions, deepCopy, fullKey)
                    else
                        dst[k] = deepCopy(v)
                    end
                else
                    dst[k] = v
                end
            end
        end
    end

    function EUICoreStandaloneBags.IsProfileSynced(folder, profileName)
        if not EUICoreStandaloneBagsDB then return false end
        local sm = EUICoreStandaloneBagsDB.syncedModules
        if not sm or not sm[folder] then return false end
        local targets = sm[folder]
        return type(targets) == "table" and targets[profileName] == true
    end

    function EUICoreStandaloneBags.GetSyncedProfiles(folder)
        if not EUICoreStandaloneBagsDB or not EUICoreStandaloneBagsDB.syncedModules then return {} end
        local targets = EUICoreStandaloneBagsDB.syncedModules[folder]
        if type(targets) == "table" then return targets end
        return {}
    end

    -- Check if ANY profile is synced for a module (for icon state)
    function EUICoreStandaloneBags.IsModuleSynced(folder)
        if not EUICoreStandaloneBagsDB or not EUICoreStandaloneBagsDB.syncedModules then return false end
        local targets = EUICoreStandaloneBagsDB.syncedModules[folder]
        if type(targets) ~= "table" then return false end
        for _, v in pairs(targets) do if v then return true end end
        return false
    end

    -- Sync one module from active profile to specific target profiles
    function EUICoreStandaloneBags.SyncModuleToProfiles(folder, targetProfiles)
        if not EUICoreStandaloneBagsDB or not EUICoreStandaloneBagsDB.profiles then return end
        local active = EUICoreStandaloneBagsDB.activeProfile or "Default"
        local src = EUICoreStandaloneBagsDB.profiles[active]
        if not src or not src.addons or not src.addons[folder] then return end
        local DeepCopy = EUICoreStandaloneBags.Lite and EUICoreStandaloneBags.Lite.DeepCopy
        if not DeepCopy then return end

        local staticEx = syncExclusions[folder]
        local exFn = EUICoreStandaloneBags._SyncExclusionsWithOverrides
        for profName in pairs(targetProfiles) do
            if profName ~= active then
                local prof = EUICoreStandaloneBagsDB.profiles[profName]
                if prof then
                    if not prof.addons then prof.addons = {} end
                    -- Merge both profiles' override-entry paths into the static set
                    -- (fail-open: any derive error keeps static-only behavior).
                    local exclusions = staticEx
                    if exFn then
                        local ok, m = pcall(exFn, folder, staticEx, src, prof)
                        if ok and m then exclusions = m end
                    end
                    if exclusions and next(exclusions) then
                        local dst = prof.addons[folder]
                        if not dst then
                            -- First sync to this profile: no dest values to preserve
                            prof.addons[folder] = SelectiveCopy(src.addons[folder], exclusions)
                        else
                            -- Overlay leaf-by-leaf so excluded keys keep dest values
                            EUICoreStandaloneBags._SelectiveOverlay(src.addons[folder], dst, exclusions, DeepCopy)
                        end
                    else
                        -- Full blob copy (no exclusions)
                        prof.addons[folder] = DeepCopy(src.addons[folder])
                    end
                end
            end
        end
    end

    -- Equalize a module across group members from an explicit source ("seed"). Non-active dests
    -- get a selective copy; an ACTIVE dest is written IN PLACE (live db.profile refs stay valid),
    -- defaults re-merged (stored blobs are sparse), then UI refreshed. Excluded (layout) keys keep each dest's values.
    function EUICoreStandaloneBags.SyncModuleFromProfile(folder, srcName, targets)
        if not EUICoreStandaloneBagsDB or not EUICoreStandaloneBagsDB.profiles then return end
        local active = EUICoreStandaloneBagsDB.activeProfile or "Default"
        if srcName == active then
            EUICoreStandaloneBags.SyncModuleToProfiles(folder, targets)
            return
        end
        local DeepCopy = EUICoreStandaloneBags.Lite and EUICoreStandaloneBags.Lite.DeepCopy
        if not DeepCopy then return end
        local srcProf = EUICoreStandaloneBagsDB.profiles[srcName]
        local srcData = srcProf and srcProf.addons and srcProf.addons[folder]
        if not srcData then return end

        local staticEx = syncExclusions[folder]
        local exFn = EUICoreStandaloneBags._SyncExclusionsWithOverrides
        for profName in pairs(targets) do
            if profName ~= srcName then
                local prof = EUICoreStandaloneBagsDB.profiles[profName]
                if prof then
                    if not prof.addons then prof.addons = {} end
                    -- Same override-ownership exclusions as SyncModuleToProfiles.
                    local exclusions = staticEx
                    if exFn then
                        local ok, m = pcall(exFn, folder, staticEx, srcProf, prof)
                        if ok and m then exclusions = m end
                    end
                    local dst = prof.addons[folder]
                    if profName == active then
                        -- Live profile: adopt in place, never replace the table
                        if type(dst) ~= "table" then
                            dst = {}
                            prof.addons[folder] = dst
                        end
                        if exclusions and next(exclusions) then
                            EUICoreStandaloneBags._SelectiveOverlay(srcData, dst, exclusions, DeepCopy)
                        else
                            wipe(dst)
                            for k, v in pairs(srcData) do
                                dst[k] = type(v) == "table" and DeepCopy(v) or v
                            end
                        end
                    elseif not (exclusions and next(exclusions)) then
                        prof.addons[folder] = DeepCopy(srcData)
                    elseif type(dst) == "table" then
                        EUICoreStandaloneBags._SelectiveOverlay(srcData, dst, exclusions, DeepCopy)
                    else
                        prof.addons[folder] = SelectiveCopy(srcData, exclusions)
                    end
                end
            end
        end

        if targets[active] then
            -- Re-merge defaults into the adopted live table, then refresh addons and any open options page
            local reg = EUICoreStandaloneBags.Lite._dbRegistry
            if reg then
                for _, rdb in ipairs(reg) do
                    if rdb.folder == folder then
                        if rdb._profileDefaults and rdb.profile then
                            EUICoreStandaloneBags.Lite.DeepMergeDefaults(rdb.profile, rdb._profileDefaults)
                        end
                        break
                    end
                end
            end
            if EUICoreStandaloneBags.RefreshAllAddons then
                EUICoreStandaloneBags.RefreshAllAddons()
            end
            if EUICoreStandaloneBags.RefreshPage then
                EUICoreStandaloneBags:RefreshPage()
            end
        end
    end

    -- Pre-logout push to other group members. Only a MEMBER pushes; an outside
    -- profile must never overwrite member data regardless of what is active.
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        if EUICoreStandaloneBags.Lite and EUICoreStandaloneBags.Lite.RegisterPreLogout then
            EUICoreStandaloneBags.Lite.RegisterPreLogout(function()
                if not EUICoreStandaloneBagsDB or not EUICoreStandaloneBagsDB.syncedModules then return end
                local active = EUICoreStandaloneBagsDB.activeProfile or "Default"
                for folder, targets in pairs(EUICoreStandaloneBagsDB.syncedModules) do
                    if type(targets) == "table" and targets[active] then
                        EUICoreStandaloneBags.SyncModuleToProfiles(folder, targets)
                    end
                end
            end)
        end
    end)
end


-------------------------------------------------------------------------------
--  Sync Exclusions per Module -- keys listed here are NOT copied when syncing between profiles.
-------------------------------------------------------------------------------
EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsActionBars", {
    "barPositions",
    "bars.*.growDirection",
    "bars.*.orientation",
    "bars.*.buttonWidth",
    "bars.*.buttonHeight",
    "bars.*.targetWidth",
    "bars.*.targetHeight",
    "bars.*.width",
    "bars.*.height",
    "bars.*.overrideNumIcons",
    "bars.*.overrideNumRows",
    "bars.*.numIcons",
    "bars.*.numRows",
})

EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsUnitFrames", {
    "positions",
    "player.frameWidth", "player.healthHeight",
    "target.frameWidth", "target.healthHeight",
    "playerTarget.frameWidth", "playerTarget.healthHeight",
    "targettarget.frameWidth", "targettarget.healthHeight",
    "focustarget.frameWidth", "focustarget.healthHeight",
    "pet.frameWidth", "pet.healthHeight",
    "focus.frameWidth", "focus.healthHeight",
    "boss.frameWidth", "boss.healthHeight",
})

EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsCooldownManager", {
    "cdmBarPositions",
    "cdmBars.bars.*.iconSize",
    "cdmBars.bars.*.numRows",
    "cdmBars.bars.*.anchorFirstRow",
    "cdmBars.bars.*.rowGrowDirection",
    "cdmBars.bars.*.spacing",
    "cdmBars.bars.*.verticalOrientation",
    "cdmBars.bars.*.anchorTo",
    "cdmBars.bars.*.anchorPosition",
    "cdmBars.bars.*.anchorOffsetX",
    "cdmBars.bars.*.anchorOffsetY",
    "cdmBars.bars.*.keybindOffsetX",
    "cdmBars.bars.*.keybindOffsetY",
    "cdmBars.bars.*.keybindAnchor",
    -- Rotation Assist Icon: unlock position, size and keybind placement
    "rotationAssistIcon.position",
    "rotationAssistIcon.iconSize",
    "rotationAssistIcon.keybindAnchor",
    "rotationAssistIcon.keybindOffsetX",
    "rotationAssistIcon.keybindOffsetY",
})

EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsResourceBars", {
    "health.width", "health.height", "health.offsetX", "health.offsetY", "health.orientation",
    "primary.width", "primary.height", "primary.offsetX", "primary.offsetY", "primary.orientation",
    "secondary.pipWidth", "secondary.pipHeight", "secondary.pipSpacing", "secondary.pipOrientation",
    "secondary.offsetX", "secondary.offsetY",
    "castBar.width", "castBar.height", "castBar.anchorX", "castBar.anchorY", "castBar.unlockPos",
    "totemBar.iconSize", "totemBar.spacing", "totemBar.unlockPos",
    "callTotemBar.iconSize", "callTotemBar.spacing", "callTotemBar.unlockPos",
    "general.anchorX", "general.anchorY", "general.orientation",
})

EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsAuraBuffReminders", {
    "unlockPos",
    "display.xOffset", "display.yOffset",
})

EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsRaidFrames", {
    "unlockPos",
})

EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsMythicTimer", {
    "standalonePos",
    "scale",
    "frameWidth",
})

-- Dragon Riding HUD position (unlockPos) stays per-profile on sync, like every module.
EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsDragonRiding", {
    "unlockPos",
})

-- QoL Secondary Stats/FPS positions, the cursor slice (GCD ring, cast circle, at
-- profile.cursor) and the Battle Res and Bloodlust positions stay per-profile on
-- sync: exported intact, never push-overwritten.
EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsQoL", {
    "secondaryStatsPos",
    "fpsPos",
    "cursor.gcd.pos",
    "cursor.castCircle.pos",
    "battleRes.pos",
    "bloodlust.pos",
})

-- Minimap settings nest under profile.minimap.
EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsMinimap", {
    "minimap.position",      -- unlock-element drag position
    "minimap.btnPositions",  -- per-button shift-drag offsets
})

-- Chat settings nest under profile.chat.
EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsChat", {
    "chat.chatPosition",   -- unlock drag position
    "chat.chatScreenPoint", -- the screen point that position is measured from
    "chat.chatWidth",      -- unlock resize-handle width
    "chat.chatHeight",     -- unlock resize-handle height
    "chat.toastPosition",  -- BNet toast unlock position
    "chat.iconPositions",  -- per-sidebar-icon shift-drag offsets
})

-- Damage Meters settings nest under profile.dm.
EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsDamageMeters", {
    "dm.standaloneTimerPos",  -- drag-written standalone timer position
    "dm.windows.*.position",  -- per-window drag position
    "dm.windows.*.width",     -- per-window drag-resize width
    "dm.windows.*.height",    -- per-window drag-resize height
})

-- DataBars per-bar geometry lives in the top-level bars array (wildcard shape as ActionBars).
EUICoreStandaloneBags.RegisterSyncExclusions("EUICoreStandaloneBagsDataBars", {
    "bars.*.savedPos",   -- unlock drag position
    "bars.*.length",     -- unlock resize owned
    "bars.*.thickness",  -- unlock resize owned
    "bars.*.snapEdge",   -- mutated by the drag save itself
})

-- Bags is the one auto-synced module: without this the bank position mirrors across profiles.
EUICoreStandaloneBags.RegisterSyncExclusions("EUIStandaloneBags", {
    "bankPosition",  -- bank window drag position
})

-------------------------------------------------------------------------------
--  Sync Popup -- anchored flush to sidebar's right edge, centered on clicked sync icon,
--  clamped to the EUI window bottom.
-------------------------------------------------------------------------------
do
    local _syncPopup = nil

    function EUICoreStandaloneBags.CloseSyncPopup()
        if _syncPopup then _syncPopup:Hide() end
        if EUICoreStandaloneBags._syncConfirmFrame then EUICoreStandaloneBags._syncConfirmFrame:Hide() end
    end

    -- Seed-picker confirm for create/update: user picks which member's settings the
    -- group starts from; after that first equalization the group is a mirror.
    function EUICoreStandaloneBags._ShowSyncSeedConfirm(opts)
        local fontPath = (EUICoreStandaloneBags.GetFontPath and EUICoreStandaloneBags.GetFontPath()) or "Fonts\\FRIZQT__.TTF"
        local PP = EUICoreStandaloneBags.PanelPP or EUICoreStandaloneBags.PP
        local W, PAD = 360, 18

        if not EUICoreStandaloneBags._syncConfirmFrame then
            -- Controller cursor: screen-level overlays hang off the overlay
            -- parent, which is UIParent unless a controller cursor is loaded.
            local overlayParent = EUICoreStandaloneBags.OverlayParent()
            local nf = CreateFrame("Frame", nil, overlayParent)
            nf:SetFrameStrata("FULLSCREEN_DIALOG")
            -- Below 200: the shared dropdown menu (hardcoded level 200) must render above
            nf:SetFrameLevel(150)
            nf:EnableMouse(true)
            local bg = nf:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(17/255, 15/255, 12/255, 1)
            nf._bg = bg
            -- Fullscreen dimmer: darkens and click-blocks everything behind
            local dim = CreateFrame("Frame", nil, overlayParent)
            dim:SetFrameStrata("FULLSCREEN_DIALOG")
            dim:SetFrameLevel(140)
            dim:SetAllPoints(UIParent)
            dim:EnableMouse(true)
            dim:Hide()
            local dimTex = dim:CreateTexture(nil, "BACKGROUND")
            dimTex:SetAllPoints(); dimTex:SetColorTexture(0, 0, 0, 0.55)
            nf._dimmer = dim
            nf:SetScript("OnHide", function(self) self._dimmer:Hide() end)
            EUICoreStandaloneBags._syncConfirmFrame = nf
            -- Controller cursor: the dimmer and the panel block what is under
            -- them without being stops.
            EUICoreStandaloneBags.TrackOverlay(nf)
            EUICoreStandaloneBags.TrackOverlay(dim)
            EUICoreStandaloneBags.PadHint(nf, "nodepass")
            EUICoreStandaloneBags.PadHint(dim, "nodepass")
        end
        local f = EUICoreStandaloneBags._syncConfirmFrame

        local function MakeFont(parent, size, r, g, b, a)
            local fs = parent:CreateFontString(nil, "OVERLAY")
            if EUICoreStandaloneBags and EUICoreStandaloneBags.PrimeFontShadow then EUICoreStandaloneBags.PrimeFontShadow(fs, true) end
            fs:SetFont(fontPath, size, "")
            fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
            return fs
        end

        local function MakeBtn(label, r, g, b, a, hr, hg, hb)
            local btn = CreateFrame("Button", nil, f)
            btn:SetSize(120, 26)
            btn:SetFrameLevel(f:GetFrameLevel() + 1)
            local bgT = btn:CreateTexture(nil, "BACKGROUND")
            bgT:SetAllPoints(); bgT:SetColorTexture(r, g, b, a)
            local lbl = btn:CreateFontString(nil, "OVERLAY")
            if EUICoreStandaloneBags and EUICoreStandaloneBags.PrimeFontShadow then EUICoreStandaloneBags.PrimeFontShadow(lbl, false) end
            lbl:SetFont(fontPath, 10, "")
            lbl:SetTextColor(1, 1, 1, 1); lbl:SetPoint("CENTER"); lbl:SetText(label)
            btn:SetScript("OnEnter", function() bgT:SetColorTexture(hr, hg, hb, 1) end)
            btn:SetScript("OnLeave", function() bgT:SetColorTexture(r, g, b, a) end)
            -- Back to rest (each show starts un-hovered), in the font path given.
            btn._reset = function(fp)
                bgT:SetColorTexture(r, g, b, a)
                lbl:SetFont(fp, 10, "")
            end
            return btn
        end

        local DD_W = 190
        local DD_SCALE = 0.85
        local ddVisW = math.floor(DD_W * DD_SCALE + 0.5)
        local ddVisH = math.floor(30 * DD_SCALE + 0.5)

        -- The dropdown lists this call's members. Its values and order tables are the
        -- same ones every call, so the built control keeps reading them.
        local ui = f._ui
        local ddValues = ui and ui.ddValues or { _noLoc = true }  -- profile names: never translate
        local ddOrder = ui and ui.ddOrder or {}
        local members = opts.memberOrder
        local sameMembers = ui and #ddOrder == #members
        if sameMembers then
            for i = 1, #members do
                if ddOrder[i] ~= members[i] then sameMembers = false; break end
            end
        end
        if not sameMembers then
            wipe(ddValues); wipe(ddOrder)
            ddValues._noLoc = true
            for i, name in ipairs(members) do
                ddOrder[i] = name
                ddValues[name] = name
            end
        end

        -- Built once on the recycled frame; every call re-applies the font, texts,
        -- positions and the buttons' actions.
        if not ui then
            ui = { ddValues = ddValues, ddOrder = ddOrder }
            f._ui = ui
            if PP then EUICoreStandaloneBags.MakeBorder(f, 1, 1, 1, 0.15, PP) end
            ui.title = MakeFont(f, 14, 1, 1, 1, 0.9)
            ui.msg = MakeFont(f, 11, 1, 1, 1, 0.6)
            ui.msg:SetWidth(W - PAD * 2)
            ui.msg:SetJustifyH("CENTER")
            ui.ddLabel = MakeFont(f, 11, 1, 1, 1, 0.5)

            ui.seedChoice = opts.defaultSeed
            local ddHolder = CreateFrame("Frame", nil, f)
            ddHolder:SetSize(ddVisW, ddVisH)
            ddHolder:SetFrameLevel(f:GetFrameLevel() + 1)
            local ddBtn = EUICoreStandaloneBags.BuildDropdownControl(ddHolder, DD_W, ddHolder:GetFrameLevel() + 1,
                ddValues, ddOrder,
                function() return ui.seedChoice end,
                function(v) ui.seedChoice = v end)
            ddBtn:SetScale(DD_SCALE)
            ddBtn:SetPoint("TOPLEFT", ddHolder, "TOPLEFT", 0, 0)
            -- Menu is created lazily at UIParent scale; match it to the scaled button once it exists
            ddBtn:HookScript("OnClick", function(self)
                if self._ddMenu and self._ddMenu:GetScale() ~= DD_SCALE then
                    self._ddMenu:SetScale(DD_SCALE)
                end
            end)
            ui.ddHolder, ui.ddBtn = ddHolder, ddBtn

            ui.warn = MakeFont(f, 10, 0.92, 0.3, 0.3, 1)
            ui.warn:SetWidth(W - PAD * 2)
            ui.warn:SetJustifyH("CENTER")
            ui.warn:SetText(EUICoreStandaloneBags.L("Position and size settings are not synced and keep each profile's own values."))

            ui.cancelBtn = MakeBtn(EUICoreStandaloneBags.L("Cancel"), 0.172, 0.164, 0.156, 0.9, 0.231, 0.222, 0.215)
            ui.confirmBtn = MakeBtn(EUICoreStandaloneBags.L("Sync"), 0.05, 0.52, 0.39, 0.8, 0.07, 0.62, 0.49)
        else
            ui.seedChoice = opts.defaultSeed
            if sameMembers then
                ui.ddBtn._refreshLabel()
            else
                -- The member list changed: the next click builds the menu from it.
                ui.ddBtn._invalidateMenu()
            end
        end

        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)

        local cy = -PAD

        local title = ui.title
        title:SetFont(fontPath, 14, "")
        title:ClearAllPoints()
        title:SetPoint("TOP", f, "TOP", 0, cy)
        title:SetText(EUICoreStandaloneBags.L(opts.hadGroup and "Update Sync Group" or "Create Sync Group"))
        cy = cy - 22 - 8

        local msg = ui.msg
        msg:SetFont(fontPath, 11, "")
        msg:ClearAllPoints()
        msg:SetPoint("TOP", f, "TOP", 0, cy)
        msg:SetText(EUICoreStandaloneBags.Lf("All selected profiles will keep their %1$s settings in sync: changes made on any of them carry over to the others. Choose which profile's settings the group starts from.", EUICoreStandaloneBags.L(opts.displayName)))
        cy = cy - (msg:GetStringHeight() or 42) - 14

        local ddLabel = ui.ddLabel
        ddLabel:SetFont(fontPath, 11, "")
        ddLabel:ClearAllPoints()
        ddLabel:SetPoint("TOP", f, "TOP", 0, cy)
        ddLabel:SetText(EUICoreStandaloneBags.L("Sync settings from:"))
        cy = cy - 16 - 6

        ui.ddHolder:ClearAllPoints()
        ui.ddHolder:SetPoint("TOP", f, "TOP", 0, cy)
        cy = cy - ddVisH - 14

        local warn = ui.warn
        if opts.hasWarning then
            warn:SetFont(fontPath, 10, "")
            warn:ClearAllPoints()
            warn:SetPoint("TOP", f, "TOP", 0, cy)
            warn:Show()
            cy = cy - (warn:GetStringHeight() or 26) - 14
        else
            warn:Hide()
        end

        local cancelBtn, confirmBtn = ui.cancelBtn, ui.confirmBtn
        cancelBtn._reset(fontPath)
        confirmBtn._reset(fontPath)
        cancelBtn:ClearAllPoints()
        cancelBtn:SetPoint("TOPRIGHT", f, "TOP", -6, cy)
        confirmBtn:ClearAllPoints()
        confirmBtn:SetPoint("TOPLEFT", f, "TOP", 6, cy)
        cy = cy - 26

        f:SetSize(W, -cy + PAD)

        confirmBtn:SetScript("OnClick", function()
            f:Hide()
            if not EUICoreStandaloneBagsDB.syncedModules then EUICoreStandaloneBagsDB.syncedModules = {} end
            EUICoreStandaloneBagsDB.syncedModules[opts.folder] = opts.targets
            local seedChoice = ui.seedChoice
            if seedChoice then
                EUICoreStandaloneBags.SyncModuleFromProfile(opts.folder, seedChoice, opts.targets)
            end
            if opts.onDone then opts.onDone() end
        end)
        cancelBtn:SetScript("OnClick", function()
            f:Hide()
            if opts.onCancel then opts.onCancel() end
        end)
        -- Controller cursor: its cancel press backs out through Cancel.
        if EUICoreStandaloneBags.PadCP() then f.CloseButton = cancelBtn end

        f._dimmer:Show()
        f:Show()
        -- Controller cursor: start on the safe button.
        EUICoreStandaloneBags.PadFocus(cancelBtn)
    end

    function EUICoreStandaloneBags.OpenSyncPopup(folder, displayName, anchorBtn)
        if EUICoreStandaloneBags._syncConfirmFrame then EUICoreStandaloneBags._syncConfirmFrame:Hide() end
        -- Toggle off if already open for this module
        if _syncPopup and _syncPopup:IsShown() and _syncPopup._folder == folder then
            _syncPopup:Hide()
            return
        end

        if not EUICoreStandaloneBagsDB or not EUICoreStandaloneBagsDB.profiles then return end
        local active = EUICoreStandaloneBagsDB.activeProfile or "Default"
        local profileOrder = EUICoreStandaloneBagsDB.profileOrder or {}

        -- Full profile list, profileOrder first then stragglers (active included: groups are explicit membership)
        local allProfiles = {}
        for _, name in ipairs(profileOrder) do
            if EUICoreStandaloneBagsDB.profiles[name] then
                allProfiles[#allProfiles + 1] = name
            end
        end
        for name in pairs(EUICoreStandaloneBagsDB.profiles) do
            local found = false
            for _, n in ipairs(allProfiles) do if n == name then found = true; break end end
            if not found then allProfiles[#allProfiles + 1] = name end
        end

        if #allProfiles <= 1 then
            if EUICoreStandaloneBags.ShowWidgetTooltip then
                EUICoreStandaloneBags.ShowWidgetTooltip(anchorBtn, "No other profiles to sync to")
                C_Timer.After(1.5, function() EUICoreStandaloneBags.HideWidgetTooltip() end)
            end
            return
        end

        local MEDIA_PATH = "Interface\\AddOns\\EUIStandaloneBags\\media\\"
        local fontPath = (EUICoreStandaloneBags.GetFontPath and EUICoreStandaloneBags.GetFontPath()) or "Fonts\\FRIZQT__.TTF"
        local accentColor = EUICoreStandaloneBags.ACCENT_COLOR or EUICoreStandaloneBags.ELLESMERE_GREEN or { r = 0.05, g = 0.82, b = 0.62 }
        local PP = EUICoreStandaloneBags.PanelPP or EUICoreStandaloneBags.PP

        local POPUP_W = 300
        local PAD = 16
        local ROW_H = 30
        local ROW_GAP = 2
        local HEADER_H = 26
        local WARN_MODULES = {
            EUICoreStandaloneBagsActionBars = true,
            EUICoreStandaloneBagsUnitFrames = true,
            EUICoreStandaloneBagsCooldownManager = true,
            EUICoreStandaloneBagsResourceBars = true,
            EUICoreStandaloneBagsMythicTimer = true,
            EUICoreStandaloneBagsRaidFrames = true,
        }
        local hasWarning = WARN_MODULES[folder]
        local SUBTITLE_H = 30
        local popupH = PAD + HEADER_H + 7 + SUBTITLE_H + 14
            + #allProfiles * (ROW_H + ROW_GAP) - ROW_GAP + 16 + 30 + PAD

        if not _syncPopup then
            -- Controller cursor: overlay parent (UIParent unless a controller cursor is loaded).
            _syncPopup = CreateFrame("Frame", nil, EUICoreStandaloneBags.OverlayParent())
            _syncPopup:SetFrameStrata("FULLSCREEN_DIALOG")
            _syncPopup:SetFrameLevel(200)
            _syncPopup:EnableMouse(true)
            local bg = _syncPopup:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); bg:SetColorTexture(17/255, 15/255, 12/255, 1)
            _syncPopup._bg = bg
            -- Born hidden, so the Show below runs its OnShow (the click-away)
            -- on the first open too.
            _syncPopup:Hide()
            EUICoreStandaloneBags.TrackOverlay(_syncPopup)
            EUICoreStandaloneBags.PadHint(_syncPopup, "nodepass")
        end
        local popup = _syncPopup
        popup._folder = folder
        popup:SetFrameLevel(200)

        popup:SetSize(POPUP_W, popupH)
        -- The popup's border, header, profile rows (pooled by position) and action
        -- button are built once; every open re-applies their fonts, texts, colours,
        -- positions and actions.
        local ui = popup._ui
        if not ui then
            ui = { rows = {} }
            popup._ui = ui
            if PP then
                EUICoreStandaloneBags.MakeBorder(popup, 1, 1, 1, 0.15, PP)
            end
        end

        -- Position: flush right of sidebar, centered on the sync icon, clamped
        local sidebar = EUICoreStandaloneBags._sidebar
        local root = EUICoreStandaloneBags._mainFrame
        if sidebar and anchorBtn then
            local btnMidY = select(2, anchorBtn:GetCenter()) or 0
            local sidebarMidY = select(2, sidebar:GetCenter()) or 0
            local offsetY = btnMidY - sidebarMidY
            -- Clamp to EUI window bottom
            if root then
                local rootBot = root:GetBottom() or 0
                local popupBot = btnMidY - popupH / 2
                if popupBot < rootBot then offsetY = offsetY + (rootBot - popupBot) end
            end
            popup:ClearAllPoints()
            popup:SetPoint("LEFT", sidebar, "RIGHT", 0, offsetY)
        else
            popup:ClearAllPoints()
            popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end

        local function MakeFont(parent, size, r, g, b, a)
            local fs = parent:CreateFontString(nil, "OVERLAY")
            if EUICoreStandaloneBags and EUICoreStandaloneBags.PrimeFontShadow then EUICoreStandaloneBags.PrimeFontShadow(fs, true) end
            fs:SetFont(fontPath, size, "")
            fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
            return fs
        end

        local cy = -PAD

        -- Header: sync icon (left), title (centered), close X (right)
        if not ui.iconTex then
            local iconTex = popup:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(19, 19)
            iconTex:SetTexture(MEDIA_PATH .. "icons\\linked.png")
            ui.iconTex = iconTex
            ui.title = MakeFont(popup, 14, 1, 1, 1, 0.9)
            local subtitle = MakeFont(popup, 10, 1, 1, 1, 0.45)
            subtitle:SetWidth(POPUP_W - PAD * 2)
            subtitle:SetJustifyH("CENTER")
            subtitle:SetText(EUICoreStandaloneBags.L("Syncing allows you to auto update all profiles whenever you change settings. This can be enabled per module."))
            ui.subtitle = subtitle
        end
        local iconTex = ui.iconTex
        iconTex:ClearAllPoints()
        iconTex:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD - 1, cy + 1)
        -- Accent when this module has an active sync group, gray otherwise
        if EUICoreStandaloneBags.IsModuleSynced(folder) then
            iconTex:SetVertexColor(accentColor.r, accentColor.g, accentColor.b, 1)
        else
            iconTex:SetVertexColor(0.55, 0.55, 0.55, 1)
        end

        local title = ui.title
        title:SetFont(fontPath, 14, "")
        title:ClearAllPoints()
        title:SetPoint("TOP", popup, "TOP", 0, cy - 1)
        title:SetText(EUICoreStandaloneBags.Lf("%1$s Sync", EUICoreStandaloneBags.L(displayName)))
        cy = cy - HEADER_H - 7

        local subtitle = ui.subtitle
        subtitle:SetFont(fontPath, 10, "")
        subtitle:ClearAllPoints()
        subtitle:SetPoint("TOP", popup, "TOP", 0, cy)
        cy = cy - SUBTITLE_H - 14

        -- Toggle rows for every profile (the active one included)
        local currentSynced = EUICoreStandaloneBags.GetSyncedProfiles(folder)
        local toggleState = {}
        local hadGroup = next(currentSynced) ~= nil
        local refreshSyncBtnLabel  -- defined with the button below
        -- The pooled rows' toggles and clicks read and write this open's state.
        popup._toggleState = toggleState
        popup._refreshLabel = nil

        local accentHex = string.format("%02x%02x%02x",
            math.floor(accentColor.r * 255 + 0.5),
            math.floor(accentColor.g * 255 + 0.5),
            math.floor(accentColor.b * 255 + 0.5))

        local BuildToggleControl = EUICoreStandaloneBags.BuildToggleControl
        local rows = ui.rows
        for i, profName in ipairs(allProfiles) do
            local isSynced = currentSynced[profName] == true
            toggleState[profName] = isSynced

            -- Card-style row: label left, toggle right, whole row clickable
            local row = rows[i]
            if not row then
                row = CreateFrame("Button", nil, popup)
                row:SetFrameLevel(popup:GetFrameLevel() + 1)
                local rowBg = row:CreateTexture(nil, "BACKGROUND")
                rowBg:SetAllPoints()
                rowBg:SetColorTexture(1, 1, 1, 0.05)
                row._bg = rowBg
                row._profName = profName

                local tg, _, tgSnap = BuildToggleControl(row, row:GetFrameLevel() + 1,
                    function() return popup._toggleState[row._profName] end,
                    function(v)
                        popup._toggleState[row._profName] = v
                        if popup._refreshLabel then popup._refreshLabel() end
                    end,
                    { sizeRatio = 0.75 })
                tg:SetPoint("RIGHT", row, "RIGHT", -10, 0)
                row._tg, row._tgSnap = tg, tgSnap

                row:SetScript("OnClick", function(self)
                    local state = popup._toggleState
                    state[self._profName] = not state[self._profName]
                    self._tgSnap()
                    if popup._refreshLabel then popup._refreshLabel() end
                end)
                row:SetScript("OnEnter", function() rowBg:SetColorTexture(1, 1, 1, 0.08) end)
                row:SetScript("OnLeave", function() rowBg:SetColorTexture(1, 1, 1, 0.05) end)
                -- Toggle hover fires the row's OnLeave (child frame); keep the card lit
                tg:HookScript("OnEnter", function() rowBg:SetColorTexture(1, 1, 1, 0.08) end)
                tg:HookScript("OnLeave", function() rowBg:SetColorTexture(1, 1, 1, 0.05) end)

                local lblText = MakeFont(row, 12, 1, 1, 1, 0.85)
                lblText:SetPoint("LEFT", row, "LEFT", 10, 0)
                row._lbl = lblText
                rows[i] = row
            end
            row._profName = profName
            row:SetSize(POPUP_W - PAD * 2, ROW_H)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, cy)
            row:SetFrameLevel(popup:GetFrameLevel() + 1)
            row._tg:SetFrameLevel(row:GetFrameLevel() + 1)
            row._bg:SetColorTexture(1, 1, 1, 0.05)
            row._tgSnap()
            row:Show()

            local lblText = row._lbl
            lblText:SetFont(fontPath, 12, "")
            if profName == active then
                lblText:SetText(profName .. " |cff" .. accentHex .. "(active)|r")
            else
                lblText:SetText(profName)
            end

            cy = cy - ROW_H - ROW_GAP
        end
        for i = #allProfiles + 1, #rows do rows[i]:Hide() end

        cy = cy - (16 - ROW_GAP)

        -- Action button: full-width accent outline; label tracks the toggle state
        if not ui.syncBtn then
            local syncBtn = CreateFrame("Button", nil, popup)
            syncBtn:SetFrameLevel(popup:GetFrameLevel() + 1)
            local sBg = syncBtn:CreateTexture(nil, "BACKGROUND")
            sBg:SetAllPoints()
            local sBrd
            if PP then
                sBrd = EUICoreStandaloneBags.MakeBorder(syncBtn, accentColor.r, accentColor.g, accentColor.b, 0.7, PP)
            end
            local sLbl = syncBtn:CreateFontString(nil, "OVERLAY")
            if EUICoreStandaloneBags and EUICoreStandaloneBags.PrimeFontShadow then EUICoreStandaloneBags.PrimeFontShadow(sLbl, false) end
            sLbl:SetPoint("CENTER")
            ui.syncBtn, ui.sBg, ui.sBrd, ui.sLbl = syncBtn, sBg, sBrd, sLbl
        end
        local syncBtn, sBg, sBrd, sLbl = ui.syncBtn, ui.sBg, ui.sBrd, ui.sLbl
        syncBtn:SetSize(POPUP_W - PAD * 2, 30)
        syncBtn:ClearAllPoints()
        syncBtn:SetPoint("TOP", popup, "TOP", 0, cy)
        syncBtn:SetFrameLevel(popup:GetFrameLevel() + 1)
        sLbl:SetFont(fontPath, 11, "")

        -- Grayed out until the toggles actually differ from the saved group
        local function ApplyBtnState(dirty)
            syncBtn._dirty = dirty
            if dirty then
                sBg:SetColorTexture(accentColor.r, accentColor.g, accentColor.b, 0.08)
                if sBrd then sBrd:SetColor(accentColor.r, accentColor.g, accentColor.b, 0.7) end
                sLbl:SetTextColor(accentColor.r, accentColor.g, accentColor.b, 1)
            else
                sBg:SetColorTexture(1, 1, 1, 0.03)
                if sBrd then sBrd:SetColor(1, 1, 1, 0.15) end
                sLbl:SetTextColor(1, 1, 1, 0.35)
            end
        end
        syncBtn:SetScript("OnEnter", function()
            if not syncBtn._dirty then return end
            sBg:SetColorTexture(accentColor.r, accentColor.g, accentColor.b, 0.18)
        end)
        syncBtn:SetScript("OnLeave", function()
            ApplyBtnState(syncBtn._dirty)
        end)

        refreshSyncBtnLabel = function()
            local count = 0
            local dirty = false
            for profName, v in pairs(toggleState) do
                if v then count = count + 1 end
                if v ~= (currentSynced[profName] == true) then dirty = true end
            end
            if hadGroup and count == 0 then
                sLbl:SetText(EUICoreStandaloneBags.L("Disband Sync Group"))
            elseif hadGroup then
                sLbl:SetText(EUICoreStandaloneBags.L("Update Sync Group"))
            else
                sLbl:SetText(EUICoreStandaloneBags.L("Create Sync Group"))
            end
            ApplyBtnState(dirty)
        end
        popup._refreshLabel = refreshSyncBtnLabel
        refreshSyncBtnLabel()

        local function RefreshSidebarSyncIcon()
            local sidebarBtns = EUI_NS.sidebarButtons
            if sidebarBtns and sidebarBtns[folder] and sidebarBtns[folder]._syncBtn then
                local sb = sidebarBtns[folder]._syncBtn
                if sb._refreshAlpha then sb._refreshAlpha() end
            end
        end

        syncBtn:SetScript("OnClick", function()
            if not syncBtn._dirty then return end
            -- The group is exactly the toggled-on profiles
            local targets = {}
            local count = 0
            local anyNew = false
            for profName, checked in pairs(toggleState) do
                if checked then
                    targets[profName] = true
                    count = count + 1
                    if not currentSynced[profName] then anyNew = true end
                end
            end

            if count == 0 then
                -- Disband (or nothing was ever configured)
                if not EUICoreStandaloneBagsDB.syncedModules then EUICoreStandaloneBagsDB.syncedModules = {} end
                EUICoreStandaloneBagsDB.syncedModules[folder] = {}
                popup:Hide()
                RefreshSidebarSyncIcon()
                return
            end

            if count == 1 then
                if EUICoreStandaloneBags.ShowWidgetTooltip then
                    EUICoreStandaloneBags.ShowWidgetTooltip(syncBtn, "A sync group needs at least two profiles")
                    C_Timer.After(1.5, function() EUICoreStandaloneBags.HideWidgetTooltip() end)
                end
                return
            end

            if not anyNew then
                -- Pure removal / no change: nothing overwritten, save without confirmation
                if not EUICoreStandaloneBagsDB.syncedModules then EUICoreStandaloneBagsDB.syncedModules = {} end
                EUICoreStandaloneBagsDB.syncedModules[folder] = targets
                popup:Hide()
                RefreshSidebarSyncIcon()
                return
            end

            -- New members joining: confirm with a seed picker; default = an existing member
            -- on update (newcomers adopt group settings), active on create.
            local memberOrder = {}
            for _, name in ipairs(allProfiles) do
                if targets[name] then memberOrder[#memberOrder + 1] = name end
            end
            local defaultSeed
            if hadGroup then
                for _, name in ipairs(memberOrder) do
                    if currentSynced[name] then defaultSeed = name; break end
                end
            end
            if not defaultSeed then
                defaultSeed = targets[active] and active or memberOrder[1]
            end

            popup:SetFrameLevel(90)
            popup:SetScript("OnUpdate", nil)
            EUICoreStandaloneBags._ShowSyncSeedConfirm({
                folder = folder,
                displayName = displayName,
                targets = targets,
                memberOrder = memberOrder,
                defaultSeed = defaultSeed,
                hadGroup = hadGroup,
                hasWarning = hasWarning,
                active = active,
                onDone = function()
                    popup:Hide()
                    RefreshSidebarSyncIcon()
                end,
                onCancel = function()
                    popup:Hide()
                end,
            })
        end)

        -- Click-off to close (OnUpdate poll like CC popups)
        popup:SetScript("OnShow", function(self)
            self:SetScript("OnUpdate", function(self2)
                if IsMouseButtonDown("LeftButton") then
                    if not self2:IsMouseOver() and not (anchorBtn and anchorBtn:IsMouseOver()) then
                        self2:Hide()
                    end
                end
            end)
        end)
        popup:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        -- Controller cursor: its cancel press clicks the sync icon, which
        -- toggles this popup off.
        if EUICoreStandaloneBags.PadCP() then popup.CloseButton = anchorBtn end
        popup:Show()
        -- Controller cursor: move it into the popup (its first row).
        EUICoreStandaloneBags.PadFocus(popup)
    end
end
