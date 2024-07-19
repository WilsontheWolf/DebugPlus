--- STEAMODDED HEADER
--- MOD_NAME: DebugPlusTest
--- MOD_ID: DebugPlusTest
--- MOD_AUTHOR: [WilsontheWolf]
--- MOD_DESCRIPTION: DebugPlusTest
local success, dpAPI = pcall(require, "debugplus-api")

local logger = {
    log = print,
    debug = print,
    info = print,
    warn = print,
    error = print, 
}

if success and dpAPI.isVersionCompatible(0) then
    local debugplus = dpAPI.registerID("Example")
    logger = debugplus.logger
end

logger.log("Hi")