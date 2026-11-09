local _, FC = ...

local previous = FC.HandleSlashCommand
if type(previous) ~= "function" then return end

local function show(method, ...)
    local callback = FC.UI and FC.UI[method]
    if type(callback) == "function" then
        callback(FC.UI, ...)
        return true
    end
    FC:Print("This companion tool is currently unavailable.")
    return false
end

FC.HandleSlashCommand = function(message)
    message = tostring(message or "")
    local command, argument = message:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "hub" or command == "tools" or command == "companion" then
        show("ShowHub")
    elseif command == "search" or command == "find" then
        show("ShowGlobalSearch", argument ~= "" and argument or nil)
    elseif command == "suggestions" or command == "suggest" then
        show("ShowSuggestions")
    elseif command == "cache" or command == "caches" then
        show("ShowCacheManager")
    elseif command == "account" or command == "alts" then
        show("ShowCharacters")
    elseif command == "recipes" or command == "accountrecipes" then
        show("ShowAccountRecipes")
    elseif command == "checklist" or command == "prepare" then
        show("ShowPreparationChecklist")
    elseif command == "planner" or command == "professionplanner" then
        show("ShowProfessionPlanner")
    elseif command == "routes" or command == "route" then
        show("ShowTravelRoutes")
    elseif command == "transfer" or command == "export" or command == "import" then
        show("ShowDataTransfer")
    elseif command == "items" and argument == "" then
        show("ShowItems")
    elseif command == "groups" or command == "group" then
        show("ShowGroups")
    elseif command == "milestones" or command == "milestone" then
        show("ShowMilestones")
    else
        previous(message)
    end
end
