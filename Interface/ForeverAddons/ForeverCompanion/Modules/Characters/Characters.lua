local _, FC = ...

local Characters = {}

function Characters:Scan()
    if not FC.DB then
        return
    end

    local key = FC:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown Realm"
    local className, classFile = UnitClass("player")

    local character = FC.DB.account.characters[key] or {}
    character.key = key
    character.name = name
    character.realm = realm
    character.className = className or "Unknown"
    character.classFile = classFile or "UNKNOWN"
    character.level = UnitLevel("player") or 0
    character.faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    character.lastSeen = time()
    character.professions = character.professions or {}
    character.preparation = character.preparation or {}

    FC.DB.account.characters[key] = character
    self.character = character
end

function Characters:Refresh()
    self:Scan()
end

function Characters:OnEvent(event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP" then
        self:Scan()
    end
end

FC:RegisterModule("Characters", Characters)
