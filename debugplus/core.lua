local logger = require("debugplus.logger")
local util = require("debugplus.util")
local global = {}

local enhancements = nil
local seals = nil
local suits = nil
local ranks = nil
local saveStateKeys = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}
local log = logger.log

local function getSeals()
    if seals then
        return seals
    end
    seals = {"None"}
    for i, v in pairs(G.P_SEALS) do
        seals[v.order + 1] = i
    end

    return seals
end

local function getEnhancements()
    if enhancements then
        return enhancements
    end
    enhancements = {"c_base"}
    for k, v in pairs(G.P_CENTER_POOLS["Enhanced"]) do
        enhancements[v.order] = v.key
    end
    return enhancements
end

local function getSuits()
    if suits then
        return suits
    end
    suits = {}
    for k, v in pairs(G.C.SUITS) do
        table.insert(suits, k)
    end
    return suits
end

local function getRanks()
    if ranks then
        return ranks
    end
    ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace"} -- No built in api for this, yippe
    if SMODS and SMODS.Ranks then
        for k, v in pairs(SMODS.Ranks) do
            if not util.hasValue(ranks, v.key) then
                table.insert(ranks, v.key)
            end
        end
    end
    return ranks
end

function global.handleKeys(controller, key, dt)
    if controller.hovering.target and controller.hovering.target:is(Card) then
        local _card = controller.hovering.target
        if key == 'w' then
            if _card.playing_card then
                for i, v in ipairs(getEnhancements()) do
                    if _card.config.center == G.P_CENTERS[v] then
                        local _next = i + 1
                        if _next > #enhancements then
                            _card:set_ability(G.P_CENTERS[enhancements[1]], nil, true)
                        else
                            _card:set_ability(G.P_CENTERS[enhancements[_next]], nil, true)
                        end
                        break
                    end
                end
            end
        end
        if key == "e" then
            if _card.playing_card then
                for i, v in ipairs(getSeals()) do
                    if (_card:get_seal(true) or "None") == v then
                        local _next = i + 1
                        if _next > #seals then
                            _next = 1
                        end
                        if _next == 1 then
                            _card:set_seal(nil, true)
                        else
                            _card:set_seal(seals[_next], true)
                        end
                        break
                    end
                end
            end
        end
        if key == "a" then
            if _card.ability.set == 'Joker' then
                _card.ability.eternal = not _card.ability.eternal
            end
        end
        if key == "s" then
            if _card.ability.set == 'Joker' then
                _card.ability.perishable = not _card.ability.perishable
                _card.ability.perish_tally = G.GAME.perishable_rounds
            end
        end
        if key == "d" then
            if _card.ability.set == 'Joker' then
                _card.ability.rental = not _card.ability.rental
                _card:set_cost()
            end
        end
        if key == "f" then
            if _card.ability.set == 'Joker' or _card.playing_card or _card.area then
                _card.ability.couponed = not _card.ability.couponed
                _card:set_cost()
            end
        end
        if key == "c" then
            local _area
            if _card.ability.set == 'Joker' then
                _area = G.jokers
            elseif _card.playing_card then
                if G.hand and G.hand.config.card_count ~= 0 then
                    _area = G.hand
                else 
                    _area = G.deck
                end
            elseif _card.ability.consumeable then
                _area = G.consumeables
            end
            if _area == nil then
                return log("Error: Trying to dup card without an area")
            end
            local new_card = copy_card(_card, nil, nil, _card.playing_card)
            new_card:add_to_deck()
            if _card.playing_card then
                table.insert(G.playing_cards, new_card)
            end
            _area:emplace(new_card)

        end
        if key == "r" then
            if _card.ability.name == "Glass Card" then
                _card.shattered = true
            end
            _card:remove()
            if _card.playing_card and G.jokers then
                if SMODS and SMODS.calculate_context then
                    SMODS.calculate_context{
                        cardarea = G.jokers,
                        remove_playing_cards = true,
                        removed = {_card}
                    }
                else
                    for j = 1, #G.jokers.cards do
                        eval_card(G.jokers.cards[j], {
                            cardarea = G.jokers,
                            remove_playing_cards = true,
                            removed = {_card}
                        })
                    end
                end
            end
        end
        if key == 'up' then
            if _card.playing_card then
                for i, v in ipairs(getRanks()) do
                    if _card.base.value == v then
                        local _next = i + 1
                        if _next > #ranks then
                            local new_card
                            for i, c in pairs(G.P_CARDS) do
                                if c.value == ranks[1] and c.suit == _card.base.suit then
                                    new_card = c
                                    break
                                end
                            end
                            if not new_card then
                                log("Error: Could not find card with rank", ranks[1], "and suit", _card.base.suit)
                                return
                            end
                            _card:set_base(new_card)
                            G.GAME.blind:debuff_card(_card)
                        else
                            local new_card
                            for i, c in pairs(G.P_CARDS) do
                                if c.value == ranks[_next] and c.suit == _card.base.suit then
                                    new_card = c
                                    break
                                end
                            end
                            if not new_card then
                                log("Error: Could not find card with rank", ranks[_next], "and suit", _card.base.suit)
                                return
                            end
                            _card:set_base(new_card)
                            G.GAME.blind:debuff_card(_card)
                        end
                        break
                    end
                end
            end
        end
        if key == 'down' then
            if _card.playing_card then
                for i, v in ipairs(getRanks()) do
                    if _card.base.value == v then
                        local _next = i - 1
                        if _next < 1 then
                            local new_card
                            for i, c in pairs(G.P_CARDS) do
                                if c.value == ranks[#ranks] and c.suit == _card.base.suit then
                                    new_card = c
                                    break
                                end
                            end
                            if not new_card then
                                log("Error: Could not find card with rank", ranks[#ranks], "and suit", _card.base.suit)
                                return
                            end
                            _card:set_base(new_card)
                            G.GAME.blind:debuff_card(_card)
                        else
                            local new_card
                            for i, c in pairs(G.P_CARDS) do
                                if c.value == ranks[_next] and c.suit == _card.base.suit then
                                    new_card = c
                                    break
                                end
                            end
                            if not new_card then
                                log("Error: Could not find card with rank", ranks[_next], "and suit", _card.base.suit)
                                return
                            end
                            _card:set_base(new_card)
                            G.GAME.blind:debuff_card(_card)
                        end
                        break
                    end
                end
            end
        end
        if key == 'right' then
            if _card.playing_card then
                for i, v in ipairs(getSuits()) do
                    if _card.base.suit == v then
                        local _next = i + 1
                        if _next > #suits then
                            _card:change_suit(suits[1])
                        else
                            _card:change_suit(suits[_next])
                        end
                        break
                    end
                end
            end
        end
        if key == 'left' then
            if _card.playing_card then
                for i, v in ipairs(getSuits()) do
                    if _card.base.suit == v then
                        local _next = i - 1
                        if _next < 1 then
                            _card:change_suit(suits[#suits])
                        else
                            _card:change_suit(suits[_next])
                        end
                        break
                    end
                end
            end
        end
    end

    local _element = controller.hovering.target
    if _element and _element.config and _element.config.tag then
        local _tag = _element.config.tag
        if key == "2" then
            G.P_TAGS[_tag.key].unlocked = true
            G.P_TAGS[_tag.key].discovered = true
            G.P_TAGS[_tag.key].alerted = true
            _tag.hide_ability = false
            set_discover_tallies()
            G:save_progress()
            _element:set_sprite_pos(_tag.pos)
        end
        if key == "3" or key == "c" then
            if G.STAGE == G.STAGES.RUN then
                add_tag(Tag(_tag.key, false, 'Big'))
            end
        end
	if key == "r" then
	    _element.config.tag:remove()
	end
    end
    if _element and _element.config and _element.config.blind then
        local _blind = _element.config.blind
        if key == "2" then
            G.P_BLINDS[_blind.key].unlocked = true
            G.P_BLINDS[_blind.key].discovered = true
            G.P_BLINDS[_blind.key].alerted = true
            if _element.set_sprite_pos then -- vanilla
                _element:set_sprite_pos(_blind.pos)
            else -- SMODS
                _element.children.center:set_sprite_pos(_blind.pos)
            end
            set_discover_tallies()
            G:save_progress()
        end
        if key == "3" then
            if G.STATE == G.STATES.BLIND_SELECT then
                local par = G.blind_select_opts.boss.parent
                G.GAME.round_resets.blind_choices.Boss = _blind.key

                G.blind_select_opts.boss:remove()
                G.blind_select_opts.boss = UIBox {
                    T = {par.T.x, 0, 0, 0},
                    definition = {
                        n = G.UIT.ROOT,
                        config = {
                            align = "cm",
                            colour = G.C.CLEAR
                        },
                        nodes = {UIBox_dyn_container({create_UIBox_blind_choice('Boss')}, false,
                            get_blind_main_colour('Boss'), mix_colours(G.C.BLACK, get_blind_main_colour('Boss'), 0.8))}
                    },
                    config = {
                        align = "bmi",
                        offset = {
                            x = 0,
                            y = G.ROOM.T.y + 9
                        },
                        major = par,
                        xy_bond = 'Weak'
                    }
                }
                par.config.object = G.blind_select_opts.boss
                par.config.object:recalculate()
                G.blind_select_opts.boss.parent = par
                G.blind_select_opts.boss.alignment.offset.y = 0

                for i = 1, #G.GAME.tags do
                    if G.GAME.tags[i]:apply_to_run({
                        type = 'new_blind_choice'
                    }) then
                        break
                    end
                end
            end
        end
    end

    if key == "1" or key == "2" then -- Reload any tooltips when unlocking/discovering stuff
        if _element and _element.stop_hover and _element.hover then
            _element:stop_hover()
            _element:hover()
        end
    end

    if key == "m" then
        G.FUNCS.change_pixel_smoothing({
            to_key = G.SETTINGS.GRAPHICS.texture_scaling
        })
        log("Reloaded Atlases")
    end

    for i, v in ipairs(saveStateKeys) do
        if key == v and love.keyboard.isDown("z") then
            if G.STAGE == G.STAGES.RUN then
                if not (G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.PLANET_PACK or G.STATE ==
                    G.STATES.SPECTRAL_PACK or G.STATE == G.STATES.STANDARD_PACK or G.STATE == G.STATES.BUFFOON_PACK or
                    G.STATE == G.STATES.SMODS_BOOSTER_OPENED) then
                    save_run()
                end
                compress_and_save(G.SETTINGS.profile .. '/' .. 'debugsave' .. v .. '.jkr', G.ARGS.save_run)
                log("Saved to slot", v)
            end
        end
        if key == v and love.keyboard.isDown("x") then
            G:delete_run()
            G.SAVED_GAME = get_compressed(G.SETTINGS.profile .. '/' .. 'debugsave' .. v .. '.jkr')
            if G.SAVED_GAME ~= nil then
                G.SAVED_GAME = STR_UNPACK(G.SAVED_GAME)
            end
            G:start_run({
                savetext = G.SAVED_GAME
            })
            log("Loaded slot", v)
        end
    end
end

function global.registerButtons()
    G.FUNCS.DT_win_blind = function()
        if G.STATE ~= G.STATES.SELECTING_HAND then
            return
        end
        G.GAME.chips = G.GAME.blind.chips
        G.STATE = G.STATES.HAND_PLAYED
        G.STATE_COMPLETE = true
        end_round()
    end
    G.FUNCS.DT_double_tag = function()
        if G.STAGE == G.STAGES.RUN then
            add_tag(Tag('tag_double', false, 'Big'))
        end
    end
end

function global.togglePerfUI()
    if G.F_ENABLE_PERF_OVERLAY == G.SETTINGS.perf_mode then -- first time run
        G.SETTINGS.perf_mode = true
    end
    G.F_ENABLE_PERF_OVERLAY = G.SETTINGS.perf_mode
    if G.F_ENABLE_PERF_OVERLAY then
        if not silent then
            log("Enabled profiler overlay. Press 'p' again to disable it.")
        end
    else
        if not silent then
            log("Disabled profiler overlay.")
        end
    end
end

function global.toggleProfiler()
    if G.prof then
		G.prof.stop()
		logger.handleLog({1, 0, 1}, "DEBUG", G.prof.report())
		G.prof = nil
		log("Performance profiler stopped")
    else
		G.prof = require "debugplus.prof"
		G.prof.start()
		log("Enabled performance profiler. Press 'v' again to disable it.")
    end
end

function global.handleSpawn(controller, _card)
    if _card.ability.set == 'Voucher' and G.shop_vouchers then
        local center = _card.config.center
        G.shop_vouchers.config.card_limit = G.shop_vouchers.config.card_limit + 1
        local card = Card(G.shop_vouchers.T.x + G.shop_vouchers.T.w / 2, G.shop_vouchers.T.y, G.CARD_W, G.CARD_H,
            G.P_CARDS.empty, center, {
                bypass_discovery_center = true,
                bypass_discovery_ui = true
            })
        create_shop_card_ui(card, 'Voucher', G.shop_vouchers)
        G.shop_vouchers:emplace(card)

    end
    if _card.ability.set == 'Booster' and G.shop_booster then
        local center = _card.config.center
        G.shop_booster.config.card_limit = G.shop_booster.config.card_limit + 1
        local card = Card(G.shop_booster.T.x + G.shop_booster.T.w / 2, G.shop_booster.T.y, G.CARD_W * 1.27,
            G.CARD_H * 1.27, G.P_CARDS.empty, center, {
                bypass_discovery_center = true,
                bypass_discovery_ui = true
            })

        create_shop_card_ui(card, 'Booster', G.shop_booster)
        card.ability.booster_pos = G.shop_booster.config.card_limit
        G.shop_booster:emplace(card)

    end

end

function global.isOkayToHandleDebugForKey(key)
    if not require("debugplus.config").getValue("ctrlKeybinds") then return true end
    for k,v in ipairs({"tab", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"}) do -- Keys that ignore the ctrl option (tab menu + collection keys + save state keys)
        if key == v then return true end
    end
    if util.isCtrlDown() then return true end    
end

return global
