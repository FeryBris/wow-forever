-- Modified for ForeverAuras
-- Modifications Copyright (C) 2026 ForeverAuras. Licensed under the GNU GPL v2 (see LICENSE).
if not WeakAuras.IsLibsOK() then return end
local L = WeakAuras.L
local _, Private = ...
-- Frames and hooks from this file are timed by the profiler (see Private.TimedAPI).
local CreateFrame, hooksecurefunc, TimedHookScript = Private.TimedAPI("SecretAuraGrid")
local Display = Private.BlizzardAuraDisplay

local GROWTH_LETTER = {RIGHT = "R", LEFT = "L", UP = "U", DOWN = "D", CENTER_HORIZONTAL = "H", CENTER_VERTICAL = "V"}
local VALID = {RU = true, UR = true, LU = true, UL = true, RD = true, DR = true, LD = true, DL = true, HD = true, HU = true,
  VR = true, VL = true, DH = true, UH = true, LV = true, RV = true, HV = true, VH = true}

local grids = {}
function Display.FlowGrid(group)
  return group and group.blizzardFlow and group.blizzardFlowGrid
    and group.blizzardFlowFrames ~= "UNITFRAME" and group.blizzardFlowFrames ~= "NAMEPLATE" or false
end

function Display.GridPerRow(group)
  return math.max(1, math.floor(tonumber(group.blizzardFlowPerRow) or 6))
end

-- Grid direction, as a Dynamic Group's: first letter along a row, second where new rows go.
function Display.GridType(group)
  if VALID[group.blizzardFlowGridType] then return group.blizzardFlowGridType end
  local first = GROWTH_LETTER[group.blizzardFlowGrowth or "RIGHT"] or "R"
  local vertical = first == "U" or first == "D" or first == "V"
  local rows = group.blizzardFlowRowGrowth
  if vertical then return first .. (rows == "LEFT" and "L" or "R") end
  return first .. (rows == "UP" and "U" or "D")
end

function Display.GridSpaces(group)
  local space = tonumber(group.blizzardFlowSpacing) or 2
  return tonumber(group.blizzardFlowRowSpace) or space, tonumber(group.blizzardFlowColumnSpace) or space
end

-- Returns the corner the flow starts from, the point that places the block,
-- the horizontal and vertical directions, and whether rows are columns.
function Display.GridLayout(gridType)
  local first, second = gridType:sub(1, 1), gridType:sub(2, 2)
  local vertical = first == "U" or first == "D" or first == "V"
  local horizontal, verticalDirection, centerX, centerY
  if vertical then
    verticalDirection = first == "U" and "UP" or "DOWN"
    horizontal = second == "L" and "LEFT" or "RIGHT"
    centerY, centerX = first == "V", second == "H"
  else
    horizontal = first == "L" and "LEFT" or "RIGHT"
    verticalDirection = second == "U" and "UP" or "DOWN"
    centerX, centerY = first == "H", second == "V"
  end
  local corner = (verticalDirection == "UP" and "BOTTOM" or "TOP") .. (horizontal == "LEFT" and "RIGHT" or "LEFT")
  local point = (centerY and "" or (verticalDirection == "UP" and "BOTTOM" or "TOP"))
    .. (centerX and "" or (horizontal == "LEFT" and "RIGHT" or "LEFT"))
  if point == "" then point = "CENTER" end
  return corner, point, horizontal, verticalDirection, vertical, centerX, centerY
end

local function ActiveNative(childID)
  local entry = Private.regions[childID]
  local region = entry and entry.region
  local native = region and region.blizzardAuraDisplay
  if native and native.active then return region, native end
end

function Display.GridProblem(data)
  local trigger = Display.GetTrigger(data)
  if not trigger then return end
  if Display.ShowOn(trigger) ~= "showOnActive" then return L["In a Grid layout, use Show On: Aura(s) Found. This aura is shown at its own position."] end
  if Display.RemainingWindow(trigger) or Display.UsesGate(data) then
    return L["In a Grid layout, Remaining Time, Total Duration and Stack Count filters are not available. This aura is shown at its own position."]
  end
  if not Display.IsSingleUnit(trigger) then return L["In a Grid layout, choose one unit (Player, Target, Focus, Pet...). This aura is shown at its own position."] end
end

local function Members(group)
  local members, unit = {}, nil
  for _, childID in ipairs(group.controlledChildren or {}) do
    local region, native = ActiveNative(childID)
    if region then
      local data = native.data
      local problem = Display.GridProblem(data)
      -- ForeverAuras: the resolved unit token (party1, party2), not the unit
      -- category: two Specific Unit auras are both "member", and the grid
      -- binds one container to the first member's unit, so a party2 aura
      -- in a grid bound to party1 showed party1's auras.
      local childUnit = not problem and Display.UnitTokens(Display.GetTrigger(data))[1]
      if childUnit and unit and childUnit ~= unit then
        problem = L["In a Grid layout, every aura watches the same unit as the first one. This aura is shown at its own position."]
      end
      if not problem then
        unit = unit or childUnit
        members[#members + 1] = {region = region, native = native, data = data, key = "FAGrid" .. tostring(data.uid)}
      end
      Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_grid", problem and "warning" or nil, problem)
    end
  end
  return members
end

-- ForeverAuras: a Grid owns the regions it has taken over (grid.owned, set
-- by Assign): their own displays are hidden while native.gridMember names
-- the Grid. Releasing goes by that ledger, never by the group's current
-- children (a member moved to another group, or a replaced group table,
-- would otherwise keep a stale gridMember), one member at a time, each
-- fallback refresh on its own guard: a refresh the client refuses is noted
-- (grid.cleanupPending) and tried again by the next quiet or rebuild, and
-- never stops the other members from being released (dev.6 review).
local function Release(grid, region)
  local native = region.blizzardAuraDisplay
  if native and native.gridMember == grid.id then native.gridMember = nil end
  grid.owned[region] = nil
  local ok = pcall(Display.RefreshUnits, region)
  if not ok then grid.cleanupPending[region] = true end
end

-- Fallback refreshes the client refused earlier (grid.cleanupPending, keyed
-- by region only; the container's own cleanup is grid.containerDirty), tried
-- again now and cleared one by one as each succeeds. Also run for retired
-- Grids (retiredCleanup), whose members were released but not refreshed.
local function RetryCleanup(grid, keep)
  for region in pairs(grid.cleanupPending) do
    if not (keep and keep[region]) and pcall(Display.RefreshUnits, region) then grid.cleanupPending[region] = nil end
  end
end

local function ClearMembership(group, keep, grid)
  grid = grid or (group and grids[group.id])
  if not grid then return end
  for region in pairs(grid.owned) do
    if not (keep and keep[region]) then Release(grid, region) end
  end
  RetryCleanup(grid, keep)
  if not keep then
    for _, childID in ipairs(group and group.controlledChildren or {}) do
      local data = WeakAuras.GetData(childID)
      if data then Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_grid", nil) end
    end
  end
end

-- Takes a member's display over for this Grid: a region owned by another
-- Grid is released from that one first (a child moved between groups).
local function Assign(grid, member)
  local native, region = member.native, member.region
  if native.gridMember == grid.id and grid.owned[region] then return end
  local other = native.gridMember and native.gridMember ~= grid.id and grids[native.gridMember]
  if other then other.owned[region] = nil end
  native.gridMember = grid.id
  grid.owned[region] = true
  Display.RefreshUnits(region)
  -- A refresh refused at its release is made good by this one.
  grid.cleanupPending[region] = nil
end

-- ForeverAuras: a Grid member's own X/Y Offset moves its artwork inside its
-- cell (Display.SetBoxOffset), never the cell or the other members, as a
-- Dynamic Group child's offset moves that child alone. Only on the current
-- layout (group-owned origin); the old layout ignores member offsets in a
-- Grid, as it did.
local function MemberOffset(group, data)
  if not Display.FlowGroupOwned(group) then return 0, 0 end
  return tonumber(data.xOffset) or 0, tonumber(data.yOffset) or 0
end

-- ForeverAuras: the Grid's buttons are tracked per aura group as records,
-- one per raw button the client made (grid.records[key]), from the moment
-- the client hands the button to initializeFrame: {button, native, styled,
-- offsetOK, list}. A record whose wrapper, style or offset failed is kept
-- (the client's button exists either way) and completed by a later rebuild
-- out of restrictions; a Grid is complete only when every record of every
-- wanted aura group is built, styled and offset (GridComplete), so a native
-- group existing is never taken as proof that its artwork was built (dev.5
-- review). List membership (the member's instances[1].buttons, which the
-- condition repaint walks) is separate from styling: a record joins a list
-- once (record.list), and a restyle never inserts it again.
local function Records(grid, key)
  grid.records[key] = grid.records[key] or {}
  return grid.records[key]
end

-- Builds, styles and offsets one record as far as the client allows now.
-- Returns true when the record is complete. Errors propagate to the caller
-- (the build transaction or the callback guard), which counts them.
local function CompleteRecord(grid, key, record, region, restricted)
  local native = region.blizzardAuraDisplay
  local list = native.instances[1] and native.instances[1].buttons
  if not record.native then
    record.native = Display.BuildNativeButton(grid.container, record.button, true)
    record.styled, record.offsetOK = false, false
  end
  local wrapper = record.native
  if list and record.list ~= list then
    -- A new owner list (first time, or the member's instance was replaced):
    -- join it once. The look already applied stays valid (same member, same
    -- settings), so a locked button keeps working across the replacement.
    local found = false
    for _, entry in ipairs(list) do if entry == wrapper then found = true end end
    if not found then list[#list + 1] = wrapper end
    record.list = list
  end
  -- Styled once per data table here. A settings change edits the saved table
  -- in place and is delivered to every wrapper, these included, by the
  -- member's own ApplyInstance pass (BlizzardAuraDisplay.lua), which styles
  -- native.instances[1].buttons; a replaced table (a re-created member) is
  -- caught here. A layout or visibility rechain changes neither, so it does
  -- not restyle every button (dev.6 review: 30 extra styling calls on an
  -- unchanged rechain). Do not remove the ApplyInstance pass on the
  -- assumption that this comparison catches in-place edits: it does not.
  -- Condition appearance changes repaint through RestyleButtons.
  if not record.styled or record.styledFor ~= native.data then
    if restricted and record.locked then
      -- A locked button cannot be restyled now: it keeps its current look;
      -- the rebuild out of restrictions styles it (incomplete until then).
      return false
    end
    Display.StyleNative(wrapper, native.data, region)
    record.styled, record.styledFor = true, native.data
  end
  local ox, oy = MemberOffset(grid.group, native.data)
  if not record.offsetOK or record.ox ~= ox or record.oy ~= oy then
    local okOffset = Display.SetBoxOffset(wrapper, ox, oy)
    record.offsetOK = okOffset ~= false
    record.ox, record.oy = ox, oy
  end
  return record.styled and record.offsetOK
end

-- Completes every record of a member's aura group; returns the number left incomplete.
local function CompleteRecords(grid, key, region, restricted)
  local left = 0
  for _, record in ipairs(Records(grid, key)) do
    if not CompleteRecord(grid, key, record, region, restricted) then left = left + 1 end
  end
  return left
end

-- ForeverAuras: where the grid block sits. On the current layout it is the
-- group's own anchor: the block's corner for its grow directions (TOPLEFT
-- for Right/Down, TOP for a horizontally centred one, CENTER for both) on
-- the group's anchored point, as a Dynamic Group's grid sits on its anchor,
-- so Group X/Y moves the whole grid and no member's offset or eligibility
-- moves it. The old layout keeps anchoring to the first eligible member's
-- own position (rc.54 review: moving that member moved the whole grid).
local function Layout(group, groupRegion)
  local grid = grids[group.id]
  local first = grid.members[1]
  local width, height = Display.Dimensions(first.data)
  local rowSpace, columnSpace = Display.GridSpaces(group)
  local corner, point, horizontal, verticalDirection, vertical = Display.GridLayout(Display.GridType(group))
  local along, across = columnSpace, rowSpace
  if vertical then along, across = rowSpace, columnSpace end
  Display.ApplyFlowWrap(grid.container, corner, horizontal, verticalDirection, vertical, Display.GridPerRow(group), width, height, along)
  grid.container:ClearAllPoints()
  if Display.FlowGroupOwned(group) and groupRegion then
    grid.container:SetPoint(point, groupRegion, group.selfPoint or "CENTER")
  else
    grid.container:SetPoint(point, first.region, point)
  end
  return along, across
end

-- ForeverAuras: the Grid is built under aura restrictions too (a reload in
-- combat, a group whose load conditions come true in a fight), the way the
-- single Modern displays are (BlizzardAuraDisplay.lua, the probe build):
-- everything a new button needs is made inside the client's initializeFrame
-- call (BuildNativeButton, CompleteRecord: box, artwork, texts, conditions,
-- glows, bindings, offset), and every failure in that callback is counted
-- here, since the client swallows the callback's errors. What cannot be
-- done under restrictions is changing an aura group that already exists
-- (filters, layout, limit, sort) or restyling a button the client has
-- locked; those wait for the paced drain.
--
-- One completion contract covers the whole build (BuildGrid, run under one
-- error boundary): container configuration and placement, every aura
-- group, every button record, the unit binding and the membership handover.
-- The Grid is live, the members' own displays are hidden and the group's
-- warning cleared only when all of it completed; otherwise FailGrid puts
-- the Grid out of use (container disabled and hidden, members back to
-- their own displays, warning on the group) and hands the group to the
-- paced drain (Display.QueueGridRebuild): at once under restrictions, since
-- the drain waits for their end, and a bounded number of times out of them,
-- so a refusal the client repeats does not become work every frame. A
-- failure in a later batch of buttons (the client makes more as auras need
-- them) enters the same state from the callback.
local GRID_RETRIES = 2

local function ProbeFailure(grid, key, what, err)
  grid.failures = (grid.failures or 0) + 1
  if not grid.firstFailure then grid.firstFailure = ("%s: %s"):format(tostring(what), tostring(err)) end
end

-- Takes the Grid out of use without destroying it (the client keeps its
-- aura groups' frames): container disabled and hidden, every member back to
-- its own display. Every write is guarded: a frame the client has locked is
-- left as it is and the Grid still counts as out of use.
-- A refused disable or hide is noted (grid.containerDirty, kept apart from
-- the region-keyed cleanup set) and tried again by the next quiet or
-- rebuild; each operation clears its own mark only when it succeeds.
local function QuietContainer(grid)
  local container = grid.container
  if not container then return end
  grid.containerDirty = grid.containerDirty or {}
  if not pcall(container.SetEnabled, container, false) then grid.containerDirty.enabled = true else grid.containerDirty.enabled = nil end
  if not pcall(container.Hide, container) then grid.containerDirty.hidden = true else grid.containerDirty.hidden = nil end
  if not next(grid.containerDirty) then grid.containerDirty = nil end
end

-- Grids forgotten by a reset whose cleanup was refused: their unfinished
-- cleanup is owned here until it succeeds (RetireGrid, FinishRetired).
local retiredCleanup = {}
local function FinishRetired()
  for grid in pairs(retiredCleanup) do
    if grid.containerDirty then QuietContainer(grid) end
    RetryCleanup(grid)
    if not grid.containerDirty and not next(grid.cleanupPending) then retiredCleanup[grid] = nil end
  end
end

local function QuietGrid(group, grid)
  QuietContainer(grid)
  grid.members = {}
  grid.live = false
  ClearMembership(group, nil, grid)
end

-- The group's current data, by id: a later callback or retry never acts on
-- a group table that a settings change has replaced.
local function CurrentGroup(grid)
  return WeakAuras.GetData(grid.id)
end

local function FailGrid(grid, why, restricted)
  local group = CurrentGroup(grid)
  QuietGrid(group, grid)
  local uid = group and group.uid
  if restricted then
    grid.retries = 0
    if uid then Private.AuraWarnings.UpdateWarning(uid, "blizzard_aura_grid_build", "warning",
      L["The Grid could not be built under aura restrictions (%s). It is built again when they end; its displays show on their own until then."]:format(tostring(why))) end
    if Display.QueueGridRebuild then Display.QueueGridRebuild(grid.id) end
  else
    grid.retries = (grid.retries or 0) + 1
    geterrorhandler()(("ForeverAuras: Grid %s failed to build: %s"):format(tostring(grid.id), tostring(why)))
    if grid.retries <= GRID_RETRIES then
      if uid then Private.AuraWarnings.UpdateWarning(uid, "blizzard_aura_grid_build", "warning",
        L["The Grid could not be built (%s). It is tried again shortly; its displays show on their own until then."]:format(tostring(why))) end
      if Display.QueueGridRebuild then Display.QueueGridRebuild(grid.id) end
    elseif uid then
      -- Stopped: ordinary layouts (a member shown or hidden) build nothing
      -- more until a settings change of the group or a member reopens the
      -- allowance (GridSettingsChanged; dev.8 review).
      grid.stopped = true
      Private.AuraWarnings.UpdateWarning(uid, "blizzard_aura_grid_build", "warning",
        L["The Grid could not be built (%s) and is not tried again until its settings change; its displays show on their own."]:format(tostring(why)))
    end
  end
end

-- The build itself; any error or counted failure means not complete.
local function BuildGrid(group, grid, members, groupRegion, restricted)
  -- Allocation and its configuration are part of the contract: the frame is
  -- owned (grid.container) the moment CreateFrame returns, so a refused
  -- configuration is retried on the same frame later, not on a new one.
  if not grid.container then
    grid.container = CreateFrame("AuraContainer", nil, groupRegion, "CustomAuraContainerTemplate")
    grid.madeRestricted, grid.madeAt = restricted, GetTime()
  end
  local container = grid.container
  if not grid.configured then
    container:SetEnabled(false)
    container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    grid.configured = true
  end
  if grid.containerDirty then QuietContainer(grid) end
  if container:GetParent() ~= groupRegion then container:SetParent(groupRegion) end
  container:SetEnabled(false)
  grid.members = members
  grid.group = group
  local along, across = Layout(group, groupRegion)
  local wanted = {}
  local deferred = false
  for index, member in ipairs(members) do
    local key, data = member.key, member.data
    local trigger = Display.GetTrigger(data)
    local width, height = Display.Dimensions(data)
    local layout = {elementWidth = width, elementHeight = height, elementSpacing = along, lineSpacing = across, layoutIndex = index}
    grid.regions[key] = member.region
    local sortMethod, sortDirection = Display.SortOrder(data, trigger)
    if not grid.keys[key] then
      local ok, err = pcall(container.AddAuraGroup, container, key, Display.FilterString(trigger), {
        maxFrameCount = Display.MaxAuras(data),
        candidateFilters = Display.CandidateFilters(data),
        layout = layout,
        -- Sorting is part of the creation (dev.5 review: a fresh Grid under
        -- restrictions kept the client's default order).
        sortMethod = sortMethod,
        sortDirection = sortDirection,
        initializeFrame = function(button)
          -- The record exists from here on, whatever happens to its setup.
          local record = {button = button}
          table.insert(Records(grid, key), record)
          -- The client calls this through its own error boundary: a failure
          -- here is counted, not raised.
          local okInit, result = pcall(function()
            local region = grid.regions[key]
            if region and region.blizzardAuraDisplay then
              return CompleteRecord(grid, key, record, region, false)
            end
            record.native = Display.BuildNativeButton(container, button, true)
            return false
          end)
          -- Made under restrictions: locked by the client from now on.
          record.locked = InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()
          -- The same rule as the build's: an error, or a record that did
          -- not complete without one (a refused offset), is a failure.
          local complete = okInit and result == true
          if not complete then
            local why = okInit and "button not completed" or tostring(result)
            ProbeFailure(grid, key, "button setup", why)
            -- A later batch, after the build finished: the live Grid is not
            -- complete any more; the same failure state as a build's.
            if not grid.building and grid.live then
              FailGrid(grid, ("button setup: %s"):format(why), record.locked)
            end
          end
        end,
      })
      grid.keys[key] = ok
      if not ok then ProbeFailure(grid, key, "AddAuraGroup", err) end
    elseif restricted then
      deferred = true
    else
      container:SetAuraGroupFilterString(key, Display.FilterString(trigger))
      container:SetAuraGroupCandidateFilters(key, Display.CandidateFilters(data))
      container:SetAuraGroupLayout(key, layout)
      container:SetAuraGroupMaxFrameCount(key, Display.MaxAuras(data))
      container:SetAuraGroupSortMethod(key, sortMethod, sortDirection)
    end
    if grid.keys[key] then
      wanted[key] = true
      local left = CompleteRecords(grid, key, member.region, restricted)
      if left > 0 then ProbeFailure(grid, key, "buttons", ("%d button(s) not completed"):format(left)) end
    end
  end
  if grid.failures > 0 then return false, grid.firstFailure, deferred end
  -- Complete: aura groups no member wants are switched off, the members
  -- hand their display over to the Grid, and the Grid binds its unit.
  for key in pairs(grid.keys) do
    if grid.keys[key] and not wanted[key] then container:SetAuraGroupEnabled(key, false) end
  end
  local keep = {}
  for _, member in ipairs(members) do
    keep[member.region] = true
    Assign(grid, member)
  end
  ClearMembership(group, keep, grid)
  grid.unit = nil
  grid.live = true
  Display.RefreshGrid(group)
  return true, nil, deferred
end

-- ForeverAuras (development): "/fa grid <group>" prints a Grid's state for
-- the combat construction tests: whether its container exists, whether it
-- was made under restrictions and when, whether it is live, and per member
-- how many button records exist and how many are complete. Opt-in output.
function Display.PrintGrid(id)
  local grid = id and grids[id]
  local data = id and WeakAuras.GetData(id)
  if not data then print(L["FA grid: no group named %s"]:format(tostring(id))); return end
  if not grid or not grid.container then print(L["FA grid %s: no Grid container exists (not built yet, or reset)."]:format(id)); return end
  if grid.containerDirty or next(grid.cleanupPending) then print(L["  cleanup still pending (a disable, hide or fallback refresh the client refused)"]) end
  print(L["FA grid %s: container made %s at %.1f s, %s, retries %d, %s"]:format(id,
    grid.madeRestricted and L["under restrictions"] or L["out of restrictions"], grid.madeAt or 0,
    grid.live and L["live"] or L["quiet"], grid.retries or 0,
    (InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()) and L["restrictions on now"] or L["restrictions off now"]))
  for key, list in pairs(grid.records) do
    local complete, built = 0, 0
    for _, record in ipairs(list) do
      if record.native then built = built + 1 end
      if record.native and record.styled and record.offsetOK then complete = complete + 1 end
    end
    local region = grid.regions[key]
    local name = region and region.blizzardAuraDisplay and region.blizzardAuraDisplay.data and region.blizzardAuraDisplay.data.id or key
    print(L["  %s: %d button(s), %d built, %d complete, aura group %s"]:format(tostring(name), #list, built, complete,
      grid.keys[key] and L["present"] or L["missing"]))
  end
end

-- ForeverAuras (development): "/fa gridreset <group>" forgets a Grid out of
-- combat, so its next build makes a fresh container: the way to test that a
-- Grid is constructed under restrictions, since the prewarming of standby
-- displays otherwise builds it hidden before the fight. The old container
-- is quieted and left to the client (its aura groups cannot be removed).
function Display.ResetGrid(id)
  local grid = id and grids[id]
  local data = id and WeakAuras.GetData(id)
  if not data then print(L["FA grid: no group named %s"]:format(tostring(id))); return end
  if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then print(L["FA gridreset: only out of combat."]); return end
  if grid then
    QuietGrid(data, grid)
    -- The retired Grid's wrappers leave the members' button lists (the
    -- condition repaint walks those), so repeated resets do not pile up
    -- retired buttons; the members' ordinary buttons stay.
    for _, list in pairs(grid.records) do
      for _, record in ipairs(list) do
        local owner = record.list
        if owner and record.native then
          for i = #owner, 1, -1 do if owner[i] == record.native then table.remove(owner, i) end end
        end
        record.list = nil
      end
    end
    grids[id] = nil
    -- Cleanup the client refused stays owned until it succeeds (FinishRetired);
    -- a retired Grid is never queued as live again.
    if grid.containerDirty or next(grid.cleanupPending) then retiredCleanup[grid] = true end
  end
  if Display.CancelGridRebuild then Display.CancelGridRebuild(id) end
  Private.AuraWarnings.UpdateWarning(data.uid, "blizzard_aura_grid_build", nil)
  print(L["FA gridreset %s: Grid forgotten; it is built fresh on the next layout (members show on their own until then)."]:format(id))
end

-- ForeverAuras: a settings change of the group (RegionTypes/Group.lua,
-- modify) starts the bounded retries over for a Grid whose build the client
-- refused; an unchanged failed attempt never does (dev.7 review: the retry
-- count was reset by the attempt itself when the container's configuration
-- failed before the build recorded its group).
function Display.GridSettingsChanged(id)
  local grid = id and grids[id]
  if grid then grid.retries, grid.stopped = 0, nil end
end

-- Whether a display took part in the group's Grid attempt (the one that may
-- have stopped it), so that editing it out of the Grid also reopens the
-- allowance for the members that remain.
function Display.GridMemberAttempted(groupId, childId)
  local grid = groupId and grids[groupId]
  return grid ~= nil and grid.attempted ~= nil and grid.attempted[childId] == true
end

-- ForeverAuras (development): "/fa gridrebuild <group>" lays the group out
-- again now (out of combat), the explicit step after a reset in the tests.
function Display.RebuildGridNow(id)
  local data = id and WeakAuras.GetData(id)
  if not data then print(L["FA grid: no group named %s"]:format(tostring(id))); return end
  if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then print(L["FA gridrebuild: only out of combat."]); return end
  Display.RechainFlow(data)
  print(L["FA gridrebuild %s: layout requested."]:format(id))
end

function Display.RebuildGrid(group)
  -- Cleanup of retired Grids the client refused earlier is tried whenever
  -- any group is laid out (no polling of its own).
  if next(retiredCleanup) then FinishRetired() end
  local grid = grids[group.id]
  if not Display.FlowGrid(group) then
    if grid then QuietGrid(group, grid) end
    if Display.CancelGridRebuild then Display.CancelGridRebuild(group.id) end
    Private.AuraWarnings.UpdateWarning(group.uid, "blizzard_aura_grid_build", nil)
    return
  end
  local restricted = InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()
  local entry = Private.regions[group.id]
  local groupRegion = entry and entry.region
  local members = Members(group)
  if not groupRegion or #members == 0 then
    if grid then QuietGrid(group, grid) end
    return
  end
  -- Stopped after the bounded retries: no construction on an unchanged
  -- attempt, the members keep their own displays. Only this Grid's cleanup
  -- the client refused earlier (a hide, a fallback refresh) is tried again,
  -- each mark cleared as its own operation succeeds (dev.9 review).
  if grid and grid.stopped then
    if grid.containerDirty then QuietContainer(grid) end
    RetryCleanup(grid)
    return
  end
  if not grid then
    -- The Grid's record exists before anything is allocated, so a refused
    -- allocation or configuration is owned, warned about and retried.
    grid = {id = group.id, records = {}, keys = {}, regions = {}, members = {}, owned = {}, cleanupPending = {}, retries = 0}
    grids[group.id] = grid
  end
  -- The displays this attempt covers, by id, taken from the complete input
  -- before anything can fail and replacing the previous attempt's set: an
  -- edit to one of them later is a relevant change even if it takes the
  -- display out of the Grid (GridMemberAttempted), while a display that
  -- left before this attempt is not (dev.11 review). Kept while stopped
  -- (the stopped return above never reaches this).
  local attempted = {}
  for _, member in ipairs(members) do attempted[member.data.id] = true end
  grid.attempted = attempted
  grid.failures, grid.firstFailure, grid.building = 0, nil, true
  local okBuild, complete, why, deferred = pcall(BuildGrid, group, grid, members, groupRegion, restricted)
  grid.building = nil
  if not okBuild then complete, why = false, complete end
  if not complete then
    FailGrid(grid, why or grid.firstFailure or "unknown", restricted)
    return
  end
  grid.retries = 0
  Private.AuraWarnings.UpdateWarning(group.uid, "blizzard_aura_grid_build", nil)
  if deferred and Display.QueueGridRebuild then Display.QueueGridRebuild(group.id) end
end

-- ForeverAuras: Ignore Dead / Ignore Disconnected for a grid member. The
-- ordinary layout hides the member's own container (ApplyUnitStatus,
-- BlizzardAuraDisplay.lua), which a grid member does not draw with; its aura
-- group in the grid container is switched off instead.
-- Each member is judged on its own trigger: status (dead, offline) and
-- eligibility (hostility, class, self; Display.UnitEligible), so one member's
-- filter switches off that member's aura group only, never the grid.
local function MemberHidden(member, unit)
  local trigger = Display.GetSavedTrigger(member.data)
  if Display.UnitIgnored(trigger, unit) then return true end
  if Display.UnitEligible and not Display.UnitEligible(trigger, unit) then return true end
  return nil
end

function Display.RefreshGrid(group)
  local grid = group and grids[group.id]
  if not grid or not grid.container then return end
  local first = grid.members[1]
  local entry = Private.regions[group.id]
  local groupRegion = entry and entry.region
  local preview = WeakAuras.IsOptionsOpen() and not InCombatLockdown()
  local unit = first and Display.UnitTokens(Display.GetTrigger(first.data))[1]
  -- The unit the grid watches, kept whether or not anything shows now: a
  -- grid built while every member's unit was dead or offline has no bound
  -- unit yet, and the status events must still find it (RefreshGridStatus).
  grid.watchUnit = unit
  grid.byRegion = {}
  local any = false
  for _, member in ipairs(grid.members) do
    grid.byRegion[member.region] = member
    member.statusHidden = MemberHidden(member, unit)
    local enabled = not preview and member.native.active and member.region:IsShown() and member.native.gridMember == group.id
      and not member.statusHidden
    pcall(grid.container.SetAuraGroupEnabled, grid.container, member.key, enabled and true or false)
    any = any or enabled
  end
  local shown = any and unit ~= nil and groupRegion ~= nil
  if shown and grid.unit ~= unit then
    grid.container:SetEnabled(false)
    grid.container:SetUnit(unit)
    grid.unit = unit
  end
  grid.container:SetShown(shown)
  grid.container:SetEnabled(shown)
  if shown then grid.container:UpdateAllAuras() end
end

-- Called by the status events (BlizzardAuraDisplay.lua) for a grid member:
-- the grid is refreshed only when the member's dead or offline state changed.
function Display.RefreshGridStatus(region, unit)
  local native = region.blizzardAuraDisplay
  local id = native and native.gridMember
  local grid = id and grids[id]
  local watched = grid and grid.watchUnit
  if not watched then return end
  if watched ~= unit and not Private.ExecEnv.UnitIsUnit(watched, unit) then return end
  local member = grid.byRegion and grid.byRegion[region]
  if member and MemberHidden(member, watched) ~= member.statusHidden then Display.RefreshGridFor(region) end
end

function Display.RefreshGridFor(region)
  local native = region and region.blizzardAuraDisplay
  local id = native and native.gridMember
  local group = id and WeakAuras.GetData(id)
  if group and not Display.DeferGridRefresh(group) then Display.RefreshGrid(group) end
end

-- Options preview: the samples are plain frames, laid out like the live grid.
function Display.ArrangeGridPreview(group)
  local samples = {}
  local offsets = {}
  local firstRegion
  -- ForeverAuras: the same eligibility as the live grid (Members): a member
  -- watching a different unit than the first eligible one is left at its
  -- own position, as the live grid leaves it. The preview checked only the
  -- per-display rules, so a Target display previewed inside a Player grid.
  local unit
  for _, childID in ipairs(group.controlledChildren or {}) do
    local entry = Private.regions[childID]
    local region = entry and entry.region
    local data = WeakAuras.GetData(childID)
    local eligible = region and region.secretAuraSamplesActive and data and Display.Enabled(data) and not Display.GridProblem(data)
    if eligible then
      local childUnit = Display.UnitTokens(Display.GetTrigger(data))[1]
      if childUnit and unit and childUnit ~= unit then
        eligible = false
        -- Its box and its samples go back to its own layout: the samples
        -- were anchored to the grid's first box the last time it was in the
        -- grid, and stayed there (PlaceOwnSample, SecretAuraPreview.lua).
        if Display.RestorePreviewRegion then Display.RestorePreviewRegion(region) end
        if Display.PlaceOwnSample then
          local shown = {}
          for _, sample in ipairs(region.secretAuraSamples or {}) do
            if sample.button:IsShown() then shown[#shown + 1] = sample.button end
          end
          for index, button in ipairs(shown) do Display.PlaceOwnSample(region, data, button, index, #shown) end
        end
      else
        unit = unit or childUnit
      end
    end
    if eligible then
      -- ForeverAuras: the row preview moves a display's own box onto its
      -- first sample (MovePreviewRegion, SecretAuraFlow.lua). Switched to a
      -- Grid with the editor open, the box was still on the sample, and
      -- anchoring the samples to the first box below made a cycle ("Cannot
      -- anchor to a region dependent on it"). The box goes back on its own
      -- anchor first.
      if Display.RestorePreviewRegion then Display.RestorePreviewRegion(region) end
      for _, sample in ipairs(region.secretAuraSamples or {}) do
        if sample.button:IsShown() then
          firstRegion = firstRegion or region
          samples[#samples + 1] = sample.button
          -- The member's own offset moves its samples inside their cells (live: SetBoxOffset).
          offsets[sample.button] = data
        end
      end
    end
  end
  if not firstRegion then return end
  -- ForeverAuras: the block sits where the live grid sits (Layout): on the
  -- current layout the group's own anchored point, on the old layout the
  -- first eligible member's position.
  local groupEntry = Private.regions[group.id]
  local groupRegion = groupEntry and groupEntry.region
  local owned = Display.FlowGroupOwned(group) and groupRegion ~= nil
  local originFrame, originPoint = firstRegion, nil
  if owned then originFrame, originPoint = groupRegion, group.selfPoint or "CENTER" end
  local perRow = Display.GridPerRow(group)
  local rowSpace, columnSpace = Display.GridSpaces(group)
  local corner, point, horizontal, verticalDirection, vertical, centerX, centerY = Display.GridLayout(Display.GridType(group))
  local width, height = samples[1]:GetWidth() or 0, samples[1]:GetHeight() or 0
  local hSign = horizontal == "LEFT" and -1 or 1
  local vSign = verticalDirection == "UP" and 1 or -1
  local line, lines = math.min(#samples, perRow), math.ceil(#samples / perRow)
  local columns, rows = line, lines
  if vertical then columns, rows = lines, line end
  local blockWidth = columns * width + (columns - 1) * columnSpace
  local blockHeight = rows * height + (rows - 1) * rowSpace
  local ox = centerX and -hSign * blockWidth / 2 or 0
  local oy = centerY and -vSign * blockHeight / 2 or 0
  for index, button in ipairs(samples) do
    local along, across = (index - 1) % perRow, math.floor((index - 1) / perRow)
    local column, row = along, across
    if vertical then column, row = across, along end
    local mx, my = 0, 0
    if owned then
      local data = offsets[button]
      mx, my = tonumber(data and data.xOffset) or 0, tonumber(data and data.yOffset) or 0
    end
    button:ClearAllPoints()
    button:SetPoint(corner, originFrame, originPoint or point, ox + hSign * column * (width + columnSpace) + mx, oy + vSign * row * (height + rowSpace) + my)
  end
  -- The group's editor box covers the previewed grid, as the row's does
  -- (SetGroupPreviewUnion, SecretAuraFlow.lua), measured from the samples
  -- just placed, in the group's units from its anchored point.
  if Display.SetGroupPreviewUnion and groupRegion then Display.SetGroupPreviewUnion(group, groupRegion, samples, nil) end
  return true
end

-- ForeverAuras 1.2.4 (Dan's session-long growth): the file's own tables are memory scan roots (/fa memscan), resolved to the CURRENT table only when the scan runs (Astra's dev.1 review: a saved reference would pin a table a reset has replaced)
Private.memoryRootAccessors = Private.memoryRootAccessors or {}
Private.memoryRootAccessors["SecretAuraGrid: grids"] = function() return grids end
Private.memoryRootAccessors["SecretAuraGrid: retiredCleanup"] = function() return retiredCleanup end
