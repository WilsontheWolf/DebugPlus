if string.match(debug.getinfo(1).source, '=%[SMODS %w+ ".+"]') then
    error("Please update your steamodded thanks")
end

local util = require("debugplus-util")
local global = {}

local configDefinition = {
    debugMode = {
        label = "Debug Mode",
        type = "toggle",
        default = true,
        info = {"Toggles everything in DebugPlus except the console"},
        onUpdate = function(v) _RELEASE_MODE = not v end
    },
    ctrlKeybinds = {
        label = util.ctrlText .. " for Keybinds",
        type = "toggle",
        default = true,
        info = {"Requires you hold ".. util.ctrlText .. " when pressing the built in keybinds"}
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
        info = {
            "Show a message when something is logged. Can also press shift + / to temporarily toggle."
        } 
    },
    onlyCommands = {
        label = "Only Show Commands",
        type = "toggle",
        default = false,
        info = {"Do not show any logs, other than ones from commands or from you pressing debug keybinds."}
    },
    showHUD = {
        label = "Show Debug HUD",
        type = "toggle",
        default = true,
        info = {"Shows some debug information on the top left of the screen."}
    },
}

global.configDefinition = configDefinition

local configPages = { -- TODO: implement paging, maybe only when I need to
    {
        "debugMode",
        "ctrlKeybinds",
        "showNewLogs",
        "onlyCommands",
        "logLevel",
        "showHUD",
    }
}

for k,v in pairs(configDefinition) do
    v.key = k
end

local testValues = {}
local configTypes
local configMemory

local function loadSaveFromFile()
    print("load save")
    local content = love.filesystem.read("config/DebugPlus.jkr")
    if not content then
        return {}
    end
    local success, res = pcall(STR_UNPACK, content)
    if success and type(res) == "table" then
        return res
    end
    print("Loading save err", res)
    return {}
end


local function generateSaveFileTable()
    if not configMemory then return loadSaveFromFile() end
    local fin = {}
    for k, v in pairs(configMemory) do
        fin[k] = v.store
    end
    return fin
end

local function updateSaveFile()
    local conf = generateSaveFileTable()
    love.filesystem.createDirectory("config")
    local success, res = pcall(serialize, conf)
    if success then
        love.filesystem.write("config/DebugPlus.jkr", "return " .. res)
    else
        print("Failure saving config", res)
    end
end


function global.setValue(key, value) 
    local def = configDefinition[key]
    if not def then return end
    if configTypes[def.type] and configTypes[def.type].validate then
        if not configTypes[def.type].validate(value, def) then
            print('Value for saving key ' .. key .. ' failed to validate')
            return
        end
    end
    local mem = configMemory[key]
    mem.store = value
    mem.value = value
    if def.onUpdate then
        def.onUpdate(value)
    end
    updateSaveFile()
end

function global.clearValue(key)
    local def = configDefinition[key]
    if not def then return end
    local mem = configMemory[key]
    mem.store = nil
    mem.value = def.default
    if def.onUpdate then
        def.onUpdate(value)
    end
    updateSaveFile()
end

function global.getValue(key)
    local def = configDefinition[key]
    if not def then return end
    return configMemory[key].value
end

configTypes = {
    toggle = {
        validate = function(data, def)
            return type(data) == "boolean"
        end,
        render = function(def)
            return create_toggle({
                label = def.label,
                ref_table = configMemory[def.key],
                ref_value = "value",
                callback = function(v) global.setValue(def.key, v) end,
                info = def.info
            })
        end
    },
    select = {
        validate = function(data, def)
            return util.hasValue(def.values, data)
        end,
        render = function(def)
            local curr = util.hasValue(def.values, configMemory[def.key].value) or 1
            return create_option_cycle({
                options = def.values,
                current_option = curr, -- TODO: how to dynamically get me
                scale = 0.8,
                opt_callback = "DP_conf_select_callback",
                label = def.label,
                info = def.info,
                dp_key = def.key
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
            if def.onUpdate then
                def.onUpdate(value)
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

function global.generateConfigTab()
    function G.FUNCS.DP_conf_select_callback(e)
        global.setValue(e.cycle_config.dp_key, e.to_val) 
    end
    local nodes = {}
    for k,v in ipairs(configPages[1]) do
        local def = configDefinition[v]
        table.insert(nodes, configTypes[def.type].render(def))
    end
    return {
        -- ROOT NODE
        n = G.UIT.ROOT,
        config = {r = 0.1, minw = 7, minh = 5, align = "tm", padding = .5, colour = G.C.BLACK},
        nodes = {
            {
                -- COLUMN NODE TO ALIGN EVERYTHING INSIDE VERTICALLY
                n = G.UIT.C,
                config = {align = "tm", padding = 0.1},
                nodes = nodes
            }
        }
    }
end

generateMemory()
if debug.getinfo(1).source:match("@.*") then -- For when running under watch
    print("DebugPlus config in watch")
    return global.generateConfigTab() -- For watch config_tab
end

return global
