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
    error = print
}

if success and dpAPI.isVersionCompatible(0) then
    local debugplus = dpAPI.registerID("Example")
    logger = debugplus.logger

    debugplus.addCommand({
        name = "test",
        shortDesc = "Testing Command",
        desc = "COmmand to test all the things",
        exec = function (args, rawArgs, dp)
            error("Shit's erroring")
            return "Hello chat", "INFO", {1, 0, 1}
        end
    })
end

logger.log("Hi")