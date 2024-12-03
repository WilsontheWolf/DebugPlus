-- Run `watch config_tab Mods/DebugPlus/examples/watch_config_tab.lua`
return {
    -- ROOT NODE
    n = G.UIT.ROOT,
    config = {
        r = 0.1,
        minw = 7,
        minh = 5,
        align = "tm",
        padding = 1,
        colour = G.C.BLACK
    },
    nodes = {{
        -- COLUMN NODE TO ALIGN EVERYTHING INSIDE VERTICALLY
        n = G.UIT.C,
        config = {
            align = "tm",
            padding = 0.1,
            colour = G.C.BLACK
        },
        nodes = {create_toggle({
            label = "Debug Mode",
            ref_table = testValues,
            ref_value = "debugMode",
            callback = debugToggle,
            info = {"Toggles everything in DebugPlus except the console"}
        }), create_toggle({
            label = "CTRL for keybinds",
            ref_table = testValues,
            ref_value = "debugMode",
            callback = debugToggle,
            info = {"Requires you hold ctrl when pressing the built in keybinds"}
        }), create_option_cycle({
            options = {"DEBUG", "INFO", "WARNING", "ERROR"},
            current_option = 2,
            ref_table = test.config,
            ref_value = "logLevel",
            opt_callback = "DP_config_callback",
            info = {"Log Level"}
        }), create_option_cycle({
            options = {"Page 1", "Page 2"},
            scale = 0.8,
            cycle_shoulders = true,
            opt_callback = 'update_mod_list',
            -- current_option = 1,
            -- colour = G.C.RED,
            no_pips = true,
            focus_args = {
                snap_to = true,
                nav = 'wide'
            }
        })}
    }}
}
