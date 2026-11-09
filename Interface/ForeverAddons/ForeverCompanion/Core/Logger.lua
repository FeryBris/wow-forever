local _, FC = ...

local Logger = {
    levels = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4,
        TRACE = 5,
    },
    session = {},
    maxSessionEntries = 100,
}
FC.Logger = Logger

local function formatMessage(message, ...)
    if select("#", ...) == 0 then
        return tostring(message)
    end

    local ok, formatted = pcall(string.format, tostring(message), ...)
    if ok then
        return formatted
    end
    return tostring(message)
end

function Logger:GetThreshold()
    local debugEnabled = FC.DB and FC.DB.settings and FC.DB.settings.debug
    return debugEnabled and self.levels.DEBUG or self.levels.INFO
end

function Logger:Write(level, category, message, ...)
    local numericLevel = self.levels[level] or self.levels.INFO
    local text = formatMessage(message, ...)
    local entry = {
        time = time and time() or 0,
        level = level,
        category = category or "CORE",
        message = text,
    }

    table.insert(self.session, entry)
    if #self.session > self.maxSessionEntries then
        table.remove(self.session, 1)
    end

    if numericLevel <= self:GetThreshold() then
        FC:Print(string.format("[%s/%s] %s", entry.category, entry.level, entry.message))
    end
end

function Logger:Error(category, message, ...)
    self:Write("ERROR", category, message, ...)
end

function Logger:Warn(category, message, ...)
    self:Write("WARN", category, message, ...)
end

function Logger:Info(category, message, ...)
    self:Write("INFO", category, message, ...)
end

function Logger:Debug(category, message, ...)
    self:Write("DEBUG", category, message, ...)
end
