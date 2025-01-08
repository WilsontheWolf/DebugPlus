-- Run `watch center Mods/DebugPlus/examples/watch_joker.lua`
-- Might want to change the key to one for a modded joker you have
return {
    key = "j_jam_buckleswasher",
    loc_txt = {
        name = "Bob",
        text = {"Enhances {C:attention}#1#", "selected cards", "to {C:attention}#2#s"}
    },
    pos = {
        x = 2,
        y = 3
    },
    update = function(self, card, dt)
        if G.STAGE ~= G.STAGES.RUN then
            return
        end
        local sell_cost = 0
        for i = #G.jokers.cards, 1, -1 do
            if G.jokers.cards[i] == card or (G.jokers.cards[i].area and (G.jokers.cards[i].area ~= G.jokers)) then
                break
            end
            sell_cost = sell_cost + G.jokers.cards[i].sell_cost
        end
        card.ability.extra.mult = 1 + math.max(0, sell_cost) * card.ability.extra.mult_mod 
    end,
    loc_vars = function(self, info_queue, center)
        return {
            vars = {center.ability.extra.mult, center.ability.extra.mult_mod}
        }
    end,
}
