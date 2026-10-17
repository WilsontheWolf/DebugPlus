-- Steamodded is not necessary. This just adds a bit of compatibility.

if SMODS.Atlas then
    SMODS.Atlas({
        key = "modicon",
        path = "modicon.png",
        px = 32,
        py = 32
    })
end

if SMODS.current_mod then
    local configSuccess, config = pcall(require, "debugplus.config")

    if not configSuccess then
        error("DebugPlus modules not successfully initialized.\nMake sure your DebugPlus folder is not nested (there should be a bunch of files in the DebugPlus folder and not just another folder).\n\n" .. (config or "No further info."))
    end
    SMODS.current_mod.config_tab = true
	SMODS.current_mod.extra_tabs = config.generateConfigTabs
    config.SMODSLoaded = true

    function SMODS.current_mod.load_mod_config() end
    function SMODS.current_mod.save_mod_config() end
end

