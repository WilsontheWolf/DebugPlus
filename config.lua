if string.match(debug.getinfo(1).source, '=%[SMODS %w+ ".+"]') then
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

local configMemory

local configTypes = {
    toggle = {
        validate = function(data, def)
            return type(data) == "boolean"
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

local function generateMemory() 
    local defaults = getDefaultsObject()
    local loaded = loadSaveFromFile()

    configMemory = {}

    for k, v in pairs(loaded) do
        local store = v
        local value = nil
        local def = configDefinition[k]
        if def then
            if configTypes[def.type] and configTypes[def.type].validate then
                if configTypes[def.type].validate(v, def) then
                    value = v
                else
                    print('Value for saved key ' .. k .. ' failed to validate')
                    value = def.default
                end
            else
                value = v
            end
        end
        configMemory[k] = {
            store = store,
            value = value,
        }
    end

    for k, v in pairs(defaults) do
        if configMemory[k] then
            goto continue
        end
        configMemory[k] = {
            store = nil,
            value = v,
        }
        ::continue::
    end
end

local function generateSaveFileTable()
    if not configMemory then return loadSaveFromFile() end
    local fin = {}
    for k, v in pairs(configMemory) do
        fin[k] = v.store
    end
    return fin
end

if debug.getinfo(1).source:match("@.*") then -- For when running under watch
    -- print("Config:", require('debugplus-util').stringifyTable(getConfig()))
    -- print("Defaults:", require('debugplus-util').stringifyTable(getDefaultsObject()))
    generateMemory()
    print("Memory:", require('debugplus-util').stringifyTable(configMemory))
    print("New store:", require('debugplus-util').stringifyTable(generateSaveFileTable()))
end

return function()
end
