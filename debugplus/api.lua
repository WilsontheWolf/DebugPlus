local console = require("debugplus.console")
local logger = require("debugplus.logger")

local global = {}
local modIDs = {
    debugplus = {
        internal = true,
        name = "DebugPlus"
    }
}
-- API versions:
-- 1: Initial release 

function global.isVersionCompatible(version)
    if version == 1 then
        return true
    end
    return false
end

local function createLogger(name)
    return {
        log = logger.createLogFn(name, "INFO"),
        debug = logger.createLogFn(name, "DEBUG"),
        info = logger.createLogFn(name, "INFO"),
        warn = logger.createLogFn(name, "WARN"),
        error = logger.createLogFn(name, "ERROR"),
    }
end

local function createCommandRegister(id, name)
    return function (options)
        options.sourceName = name
        return console.registerCommand(id, options)
    end
end

function global.registerID(name)
    if not name then
        return false, "Name not provided"
    end
    local id = string.lower(name)
    if modIDs[id] then
        return false, "ID " .. id .." already exists"
    end
    modIDs[id] = {
        name = name
    }
    local ret = {
        logger = createLogger(name),
        addCommand = createCommandRegister(id, name)
    }
    return ret
end

return global
