if string.match(debug.getinfo(function() end).source, '=%[SMODS %w+ ".+"]') then
    error("Please update your steamodded thanks")
end

local configDefinition = {
    debugMode = {
        label = "Debug Mode",
        type = "toggle",
        default = true,
        info = {"Toggles everything in DebugPlus except the console"}
    },
    ctrlKeybinds = {
        label = "CTRL for Keybinds",
        type = "toggle",
        default = true,
        info = {"Requires you hold ctrl when pressing the built in keybinds"}
    },
    logLevel = {
        label = "Log Level",
        type = "select",
        default = "INFO",
        values = {"DEBUG", "INFO", "WARN", "ERROR"},
        info = {"Only shows you logs of a certain level. This setting ignore command logs."}
    },
    showNewLogs = {
        label = "Show New Logs",
        type = "toggle",
        default = true,
        info = {"Show the a message when something is logged. Can also press shift + / to toggle."}
    },
}

for k,v in pairs(configDefinition) do
    v.key = k
end

local testValues = {}

local configTypes = {
    toggle = {
        validate = function(data, def)
            return type(data.value) == "boolean"
        end,
        render = function(data, def)
            return create_toggle({
                label = def.label,
                ref_table = testValues, -- TODO: fix me
                ref_value = def.key,
                callback = print,
                info = def.info
            })
        end
    },
}

local function getDefaultsObject()
    local config = {}
    for k, v in pairs(configDefinition) do
        config[k] = v.default
    end
    return config
end

local function loadSaveFromFile()
    local content = love.filesystem.read("config/DebugPlus.jkr")
    if not content then
        return {}
    end
    local success, res = pcall(STR_UNPACK, content)
    if success and type(res) == "table" then
        return res
    end
    return {}
end

local function getConfig()
    local res = getDefaultsObject()
    print(loadSaveFromFile())
    for k,v in pairs(loadSaveFromFile()) do
        print(k)
        local def = configDefinition[k]
        if def and configTypes[def.type] and configTypes[def.type].validate then
            if configTypes[def.type].validate(v, def) then
                res[k] = v
            else
                print("Value for key " .. k .. " failed to validate.")    
            end
        else
            res[k] = v
        end
    end
    return res
end
print(require('debugplus-util').stringifyTable(getConfig()))

return function()
end

