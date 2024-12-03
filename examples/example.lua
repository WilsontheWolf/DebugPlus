-- Example of using the DebugPlus API with steamodded.
-- If you want to test this file, make sure to remove
-- these comments so the --- STEAMODDED HEADER is on 
-- the first line

--- STEAMODDED HEADER
--- MOD_NAME: DebugPlusTest
--- MOD_ID: DebugPlusTest
--- MOD_AUTHOR: [WilsontheWolf]
--- MOD_DESCRIPTION: DebugPlusTest
local success, dpAPI = pcall(require, "debugplus-api")

local logger = { -- Placeholder logger, for when DebugPlus isn't available
    log = print,
    debug = print,
    info = print,
    warn = print,
    error = print
}

if success and dpAPI.isVersionCompatible(1) then -- Make sure DebugPlus is available and compatible
    local debugplus = dpAPI.registerID("Example")
    logger = debugplus.logger -- Provides the logger object

    debugplus.addCommand({ -- register a command
        name = "test",
        shortDesc = "Testing command",
        desc = "This command is an example to get you familar with how commands work",
        exec = function (args, rawArgs, dp)
            -- DebugPlus fowards some data to you
            -- args is a list with arguments passed by the user. How it's parsed is up to DebugPlus, but you can assume that each argument is a seperate part of the user input
            -- rawArgs is just the raw string the user typed. Useful for if you want to handle args in a very particular way.
            -- dp is an object with some various properties on it to help you make commands.
            -- dp.hovered is the currently hovered ui element (equivalent to G.CONTROLLER.hovering.target)
            if #args == 0 then
                -- Return what we want to send to the user. The first arg is the message to pass to the user
                -- Second argument is the log level (defaults to INFO). Can be one of DEBUG, INFO, WARN, ERROR
                -- Third argument is colour (defaults to your log level's colour). Is a table with the first arg as red, second as green third as blue.
                return "Hello chat", "INFO", {1, 1, 1}
            end
            if args[1] == "error" then
                -- This is the prefered way of reporting errors to users
                return "Here is an error message", "ERROR"
            end 
            if #args == 69 then
                -- If you just want the defaults you just need to return the message.
                return "nice"
            end
        end
    })
    debugplus.addCommand({ -- register a command
        name = "error",
        shortDesc = "Testing errors",
        desc = "This command errors, to show that DebugPlus prevents errors",
        exec = function (args, rawArgs, dp)
            error("Shit's erroring")
        end
    })

end

logger.log("Hi")
