--- STEAMODDED HEADER
--- MOD_NAME: DebugPlus
--- MOD_ID: DebugPlus
--- MOD_AUTHOR: [WilsontheWolf]
--- MOD_DESCRIPTION: Better Debug Tools for Balatro 
--- PREFIX: DebugPlus

-- Steamodded is not necessary. This just adds a bit of compatibility.
if SMODS then
    if SMODS.Atlas then
        SMODS.Atlas({
            key = "modicon",
            path = "modicon.png",
            px = 32,
            py = 32
        })
    end
    
    if SMODS.current_mod then
        local config = require("debugplus-config")
        
        SMODS.current_mod.config_tab = config.generateConfigTab
        config.SMODSLoaded = true
        
        function SMODS.current_mod.load_mod_config() end
        function SMODS.current_mod.save_mod_config() end
    end
end
