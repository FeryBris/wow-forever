local addonName, FC = ...

_G.ForeverCompanion = FC

FC.name = addonName or "ForeverCompanion"
FC.version = "v0.1.1"
if FC.version == "v0.1.1" then
    FC.version = "0.1.0-dev"
end
FC.DB_VERSION = 9
FC.ready = false
FC.Client = FC.Client or {}
FC.API = FC.API or {}
FC.UI = FC.UI or {}

local function joinArguments(...)
    local values = {}
    for index = 1, select("#", ...) do
        values[index] = tostring(select(index, ...))
    end
    return table.concat(values, " ")
end

function FC:Print(...)
    local message = joinArguments(...)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff5fd7ffForever Companion|r: " .. message)
    else
        print("Forever Companion: " .. message)
    end
end

function FC:SafeCall(context, callback, ...)
    if type(callback) ~= "function" then
        return false, "callback is not a function"
    end

    local ok, result = pcall(callback, ...)
    if not ok then
        if self.Logger then
            self.Logger:Error("CORE", "%s failed: %s", tostring(context), tostring(result))
        else
            self:Print(context, "failed:", result)
        end
        return false, result
    end

    return true, result
end

function FC:DetectClient()
    local version, build, buildDate, interfaceVersion = GetBuildInfo()
    interfaceVersion = tonumber(interfaceVersion) or 0

    self.Client.version = version or "unknown"
    self.Client.build = build or "unknown"
    self.Client.buildDate = buildDate or "unknown"
    self.Client.interface = interfaceVersion
    self.Client.isForever = interfaceVersion >= 16000 and interfaceVersion < 17000
    self.Client.gameType = self.Client.isForever and "camelot" or "unknown"
end

function FC:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = nil

    if GetNormalizedRealmName then
        realm = GetNormalizedRealmName()
    end
    if not realm or realm == "" then
        realm = GetRealmName and GetRealmName() or "UnknownRealm"
    end

    realm = tostring(realm):gsub("%s+", "")
    return name .. "-" .. realm
end

function FC:GetCurrentCharacter()
    if not self.DB or not self.DB.account or not self.DB.account.characters then
        return nil
    end
    return self.DB.account.characters[self:GetCharacterKey()]
end
