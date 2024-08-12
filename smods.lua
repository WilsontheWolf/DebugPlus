--- STEAMODDED HEADER
--- MOD_NAME: DebugPlus
--- MOD_ID: DebugPlus
--- MOD_AUTHOR: [WilsontheWolf]
--- MOD_DESCRIPTION: Better Debug Tools for Balatro 
--- PREFIX: DEBUGPLUS


-- Steamodded is not necessary. This just adds a bit of compatibility.
SMODS.Atlas({
    key = "modicon",
    path = "modicon.png",
    px = 32,
    py = 32
}):register()

local config = {
    logLevel = "INFO",
}
test = {config = config}

function G.FUNCS.DP_config_callback(args)
    print(require('debugplus-util').stringifyTable(args))
end

local function debugToggle(args)
    _RELEASE_MODE = not args -- TODO: Save pref
end


local testValues = {
    debugMode = not _RELEASE_MODE
}

SMODS.current_mod.config_tab = function()
    return {
        -- ROOT NODE
        n = G.UIT.ROOT,
        config = {r = 0.1, minw = 7, minh = 5, align = "tm", padding = 1, colour = G.C.BLACK},
        nodes = {
            {
                -- COLUMN NODE TO ALIGN EVERYTHING INSIDE VERTICALLY
                n = G.UIT.C,
                config = {align = "tm", padding = 0.1, colour = G.C.BLACK},
                nodes = {
                        create_toggle({
                            label = "Debug Mode",
                            ref_table = testValues,
                            ref_value = "debugMode",
                            callback = debugToggle,
                            info = {"Toggles everything in DebugPlus except the console"}
                        }),
                        create_option_cycle({
                            options = {
                                "DEBUG",
                                "INFO",
                                "WARNING",
                                "ERROR",
                            },
                            current_option = 2, -- TODO: how to dynamically get me
                            ref_table = test.config,
                            ref_value = "logLevel",
                            opt_callback = "DP_config_callback",
                            info = {"Log Level"}
                        }),
                        
                }
            }
        }
    }
end
