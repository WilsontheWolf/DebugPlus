if string.match(debug.getinfo(1).source, '=%[SMODS %w+ ".+"]') then
    error("Please update your steamodded thanks")
end

local util = require("debugplus-util")

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
local configTypes
local configMemory

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

local function setValue(key, value) 
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
    updateSaveFile()
end

local function clearValue(key)
    local def = configDefinition[key]
    if not def then return end
    local mem = configMemory[key]
    mem.store = nil
    mem.value = def.default
    updateSaveFile()

end

function G.FUNCS.DP_conf_select_callback(e)
    setValue(e.cycle_config.dp_key, e.to_val) 
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
                callback = function(v) setValue(def.key, v) end,
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



-- TODO: Clean me up. Stolen from watcher for testing
local function showTabOverlay(definition, tabName)
    tabName = tabName or "Tab"
    return G.FUNCS.overlay_menu({
        definition = create_UIBox_generic_options({
            contents = {{
                n = G.UIT.R,
                nodes = {create_tabs({
                    snap_to_nav = true,
                    colour = G.C.BOOSTER,
                    tabs = {{
                        label = tabName,
                        chosen = true,
                        tab_definition_function = function()
                            return definition
                        end
                    }}
                })}
            }}
        })
    })

end


if debug.getinfo(1).source:match("@.*") then -- For when running under watch
    -- print("Config:", util.stringifyTable(getConfig()))
    -- print("Defaults:", util.stringifyTable(getDefaultsObject()))
    generateMemory()
    print("Memory:", util.stringifyTable(configMemory))
    print("New store:", util.stringifyTable(generateSaveFileTable()))
    showTabOverlay({
        -- ROOT NODE
        n = G.UIT.ROOT,
        config = {r = 0.1, minw = 7, minh = 5, align = "tm", padding = 1, colour = G.C.BLACK},
        nodes = {
            {
                -- COLUMN NODE TO ALIGN EVERYTHING INSIDE VERTICALLY
                n = G.UIT.C,
                config = {align = "tm", padding = 0.1, colour = G.C.BLACK},
                nodes = {
                    configTypes.toggle.render(configDefinition.debugMode),
                    configTypes.toggle.render(configDefinition.ctrlKeybinds),
                    configTypes.toggle.render(configDefinition.showNewLogs) ,
                    configTypes.select.render(configDefinition.logLevel),
                } 
            }
        }
    })
end

return function()
end
