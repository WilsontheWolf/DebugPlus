-- Run `watch center Mods/DebugPlus/examples/watch_consumeable.lua`
-- Might want to change the key to one for a modded consumable you have
return {
    key = "c_cry_asteroidbelt",
    loc_txt = {
        name = "Hank",
        text = {"Hey mom", "{C:attention}#2#"}
    },
    pos = {
        x = 2,
        y = 3
    },
    loc_vars = function(self, info_queue, center)
        return {
            vars = {center.ability.hand_type}
        }
    end,
}
