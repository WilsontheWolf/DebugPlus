local console = require("debugplus-console")

local global = {}
local modIDs = {
    debugplus = {
        internal = true
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
        log = console.createLogFn(name, "INFO"),
        debug = console.createLogFn(name, "DEBUG"),
        info = console.createLogFn(name, "INFO"),
        warn = console.createLogFn(name, "WARN"),
        error = console.createLogFn(name, "ERROR"),  
    }
end

local function createCommandRegister(id) 
    return function (options) 
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
    local ret = {
        logger = createLogger(name),
        addCommand = createCommandRegister(id)
    }
    return ret
end

return global
