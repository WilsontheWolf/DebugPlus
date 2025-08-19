if string.match(debug.getinfo(1).source, '=%[SMODS %w+ ".+"]') then
    error("Please update your steamodded thanks")
end

local util = require("debugplus.util")
local loggerSucc, logger = pcall(require, "debugplus.logger")
local global = {}

if not loggerSucc then -- To handle older lovely versions, where I can't properly load my deps.
    return {
        getValue = function() -- Can't error myself because it's not propagated, so I error in the first function that is called.
            error("DebugPlus couldn't load a required component. Please make sure your lovely is up to date.\nYou can grab the latest lovely at: https://github.com/ethangreen-dev/lovely-injector/releases\n\n".. (logger or "No further info"))
        end
    }
end


local configDefinition = {
    debugMode = {
        label = "Debug Mode",
        type = "toggle",
        default = true,
        info = {"Toggles everything in DebugPlus except the console."},
        onUpdate = function(v) _RELEASE_MODE = not v end
    },
    ctrlKeybinds = {
        label = util.ctrlText .. " for Keybinds",
        type = "toggle",
        default = true,
        info = {"Requires you hold ".. util.ctrlText .. " when pressing the built in keybinds."}
    },
    logLevel = {
        label = "Log Level",
        type = "select",
        default = "INFO",
        values = {"ERROR", "WARN", "INFO", "DEBUG"},
        info = {
            "Only shows you logs of a certain level. This setting ignore command logs.",
            "Will show all logs for the selected level and higher."
        },
        -- Most of the time I wouldn't define onUpdate here for something in another module, 
        -- but I need to avoid circular dependencies and want the logger here.
        onUpdate = function(v)
            for k, v in pairs(logger.levelMeta) do
                v.shouldShow = false
            end

            logger.levelMeta.ERROR.shouldShow = true
            if v == "ERROR" then return logger.handleLogsChange() end
            logger.levelMeta.WARN.shouldShow = true
            if v == "WARN" then return logger.handleLogsChange() end
            logger.levelMeta.INFO.shouldShow = true
            if v == "INFO" then return logger.handleLogsChange() end
            logger.levelMeta.DEBUG.shouldShow = true
            logger.handleLogsChange()
        end
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
    -- Hidden config for rn. Even though they are hidden at the default logging level, 
    -- they are so frequent is starts clearing normal logs if left run for a bit.
    -- This option was added so if someone does want them, they can be reenabled. 
    enableLongDT = {
        label = "Enable Long DT Messages",
        type = "toggle",
        default = false,
        info = {}
    },
    processTables = {
        label = "Automatically Expand Printed Tables",
        type = "toggle",
        default = true,
        info = {"When a table is printed, expand it's contents (like in the eval command) instead of just strigifying it."}
    },
    stringifyPrint = {
        label = "Process Arguments Before Logging",
        type = "toggle",
        default = true,
        info = {
            "When this is enabled and something is printed to the lovely console/log DebugPlus will handle the processing of the args before logging them.",
            "This allows the 'Automatically Expand Printed Tables' option to also show up in those logs."
        }
    },
    hyjackErrorHandler = {
        label = "Console In Crash Handler",
        type = "toggle",
        default = true,
        info = {
            "When this is toggled, DebugPlus's console will be accessible in the error handler.",
            "Requires Steamodded (or another tool to replace the error handler) to function",
            "Requires a restart for the toggle to take effect"
        }
    },
    commandHistory = {
        label = "Store Command History",
        type = "toggle",
        default = true,
        info = {
            "When this is enabled, DebugPlus's console will store your run commands",
            "so they can be used when the game is restarted."
        }
    },
    commandHistoryMax = {
        label = "Max History Size",
        type = "range",
        default = 100000,
        min = 1,
        max = 1000000,
        info = {
            "Controls the number of commands to save to disk.",
        }
    },
}

global.configDefinition = configDefinition

local configPages = {
    {
        name = "Console",
        "showNewLogs",
        "onlyCommands",
        "logLevel",
        "processTables",
        "stringifyPrint",
        "hyjackErrorHandler",
        "commandHistory",
        -- "commandHistoryMax", -- NOTE: Likely not worth letting the user config it.
    },
    {
        name = "Misc",
        "debugMode",
        "ctrlKeybinds",
        "showHUD",
    }
}

for k,v in pairs(configDefinition) do
    v.key = k
end

local testValues = {}
local configTypes
local configMemory

local function parseConfigValue(val)
    val = util.trim(val)
    if val == "true" then
        return true
    end
    if val == "false" then
        return false
    end
    if val:sub(1, 1) == '"' and val:sub(#val) == '"' then
        return util.unescapeSimple(val:sub(2, #val - 1))
    end
    if tonumber(val) then
        return tonumber(val)
    end
    return {
        type = "raw",
        val = val
    }
end

local function stringifyConfigValue(val)
    if val == true then
        return "true"
    end
    if val == false then
        return "false"
    end
    if type(val) == "string" then
        return '"' .. util.escapeSimple(val) .. '"'
    end
    if type(val) == "number" then
        return string.format("%g", val)
    end
    if val.type == "raw" then
        return val.val
    end
end

local function parseConfigFile(data)
    local t = {}
    for str in string.gmatch(data, "([^\n\r]+)") do
        local name, val = str:match("(%w+)%s*=%s*(.+)")
        if not name then
            logger.error("Failed to parse line:", str)
        else
            t[name] = parseConfigValue(val)
        end
    end
    return t
end

local function stringifyConfigFile(data)
    local str = ""
    for k, v in pairs(data) do
        local val = stringifyConfigValue(v)
        if val then
            str = str .. k .. "=" .. val .. "\n"
        end
    end
    return str
end

local function loadSaveFromFile()
    local content = love.filesystem.read("config/DebugPlus.jkr")
    if not content then
        return {}
    end
    local success, res = pcall(parseConfigFile, content)
    if success and type(res) == "table" then
        return res
    end
    logger.error("Loading save err", res)
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
    local success, res = pcall(stringifyConfigFile, conf)
    if success then
        love.filesystem.write("config/DebugPlus.jkr", res)
    else
        logger.error("Failure saving config", res)
    end
end


function global.setValue(key, value)
    local def = configDefinition[key]
    if not def then return end
    if configTypes[def.type] and configTypes[def.type].validate then
        if not configTypes[def.type].validate(value, def) then
            logger.error('Value for saving key ' .. key .. ' failed to validate')
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
                current_option = curr,
                scale = 0.8,
                opt_callback = "DP_conf_select_callback",
                label = def.label,
                info = def.info,
                dp_key = def.key
            })
        end
    },
    range = {
        validate = function(data, def)
            if type(data) ~= "number" then return false end
            if def.max and data > def.max then return false end
            if def.min and data < def.min then return false end
            return true
        end,
        render = function(def)
            local ret = create_slider({
                label = def.label,
                ref_table = configMemory[def.key],
                ref_value = "value",
                callback = "DP_conf_slider_callback",
                dp_key = def.key,
                w = 4,
                h = 0.4,
                label_scale = 0.4, -- Matches the other config values
                min = def.min,
                max = def.max,
            })
            if def.info then
                local info = {}
                for k, v in ipairs(def.info) do
                    table.insert(info, {n=G.UIT.R, config={align = "cm", minh = 0.05}, nodes={
                        {n=G.UIT.T, config={text = v, scale = 0.25, colour = G.C.UI.TEXT_LIGHT}}
                    }})
                end
                info =  {n=G.UIT.R, config={align = "cm", minh = 0.05}, nodes=info}
                ret = { n = G.UIT.R, config={align = "cm"}, nodes={
                    ret,
                    info,
                }}
            end
            return ret
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
                    logger.error('Value for saved key ' .. k .. ' failed to validate')
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

function global.generateConfigTab(arg)
    local index = arg.index or 1
    function G.FUNCS.DP_conf_select_callback(e)
        global.setValue(e.cycle_config.dp_key, e.to_val)
    end
    function G.FUNCS.DP_conf_slider_callback(e)
        global.setValue(e.dp_key, math.floor(e.ref_table[e.ref_value]))
    end
    local nodes = {}
    for k,v in ipairs(configPages[index]) do
        local def = configDefinition[v]
        table.insert(nodes, configTypes[def.type].render(def))
    end
    return {
        -- ROOT NODE
        n = G.UIT.ROOT,
        config = {r = 0.1, minw = 7, minh = 5, align = "cm", padding = arg.source == "lovely" and .05 or .5, colour = arg.source == "lovely" and G.C.CLEAR or G.C.BLACK},
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

function global.generateConfigTabs(source)
    local tab = {}
    for i,v in ipairs(configPages) do
        table.insert(tab, {
            label = v.name,
            tab_definition_function = global.generateConfigTab,
            tab_definition_function_args = {source = source, index = i }
        })
    end
    return tab
end

function global.fakeConfigTab()
    local tabs = global.generateConfigTabs("lovely")
    tabs[1].chosen = true
    G.FUNCS.overlay_menu({
        definition = create_UIBox_generic_options({
            back_func = "settings",
            contents = {create_tabs({
                snap_to_nav = true,
                -- colour = {.65, .36, 1, 1},
                tabs = tabs,
                tab_h = 7.05,
                tab_alignment = 'tm',
            })}
        })
    })
    return {}
end

generateMemory()

-- if debug.getinfo(1).source:match("@.*") then -- For when running under watch
--      logger.log("DebugPlus config in watch")
--     return global.generateConfigTab({}) -- For watch config_tab
-- end

return global
