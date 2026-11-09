local _, FC = ...

local API = FC.API
local previousRefreshCapabilities = API.RefreshCapabilities

local function isSafeValue(value)
    if value == nil then
        return true
    end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then
            return false
        end
    end
    return true
end

function API:RefreshCapabilities()
    previousRefreshCapabilities(self)
    self.capabilities.unitAuras = type(C_UnitAuras) == "table"
        and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function"
    self.capabilities.restedXP = type(GetXPExhaustion) == "function"
        and type(UnitXPMax) == "function"
    self.capabilities.camps = FC.Client.isForever == true
        and self.capabilities.unitAuras
end

function API:GetCampBenefitSnapshot()
    local data = FC.CampData
    if not data or not self.capabilities or not self.capabilities.camps then
        return nil
    end

    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, data.benefitAuraSpellID)
    if not ok or type(aura) ~= "table" then
        return nil
    end

    local snapshot = {
        spellID = data.benefitAuraSpellID,
        active = true,
    }

    if isSafeValue(aura.name) then snapshot.name = aura.name end
    if isSafeValue(aura.icon) then snapshot.icon = aura.icon end
    if isSafeValue(aura.duration) then snapshot.duration = tonumber(aura.duration) end
    if isSafeValue(aura.expirationTime) then snapshot.expirationTime = tonumber(aura.expirationTime) end
    if isSafeValue(aura.applications) then snapshot.applications = tonumber(aura.applications) end

    if snapshot.expirationTime and type(GetTime) == "function" then
        local now = GetTime()
        snapshot.remaining = math.max(0, snapshot.expirationTime - now)
    end

    return snapshot
end

function API:GetRestedXPSnapshot()
    if not self.capabilities or not self.capabilities.restedXP then
        return nil
    end

    local okRested, rested = pcall(GetXPExhaustion)
    local okMax, maxXP = pcall(UnitXPMax, "player")
    if not okRested or not okMax or not isSafeValue(rested) or not isSafeValue(maxXP) then
        return nil
    end

    rested = tonumber(rested) or 0
    maxXP = tonumber(maxXP) or 0
    if maxXP <= 0 then
        return {
            restedXP = rested,
            maxXP = maxXP,
            percentOfLevel = 0,
        }
    end

    return {
        restedXP = rested,
        maxXP = maxXP,
        percentOfLevel = (rested / maxXP) * 100,
    }
end
