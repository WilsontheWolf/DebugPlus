--- STEAMODDED HEADER
--- MOD_NAME: DebugPlus
--- MOD_ID: DebugPlus
--- MOD_AUTHOR: [WilsontheWolf]
--- MOD_DESCRIPTION: Better Debug Tools for Balatro 
--- PREFIX: DebugPlus

-- Steamodded is not necessary. This just adds a bit of compatibility.
SMODS.Atlas({
    key = "modicon",
    path = "modicon.png",
    px = 32,
    py = 32
})

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

SMODS.current_mod.config_tab = require("debugplus-config").generateConfigTab

function SMODS.current_mod.load_mod_config() end
function SMODS.current_mod.save_mod_config() end
