local global = {}

local enhancements = nil
local seals = nil
local saveStateKeys = {"1", "2", "3"}

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
							_card:set_sprites(nil, "cards_"..(G.SETTINGS.colourblind_option and 2 or 1))
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
        if key == "3" then
            if G.STAGE == G.STAGES.RUN then
                add_tag(Tag(_tag.key, false, 'Big'))
            end
        end
    end

    for i, v in ipairs(saveStateKeys) do
        if key == v and love.keyboard.isDown("z") then
            if G.STAGE == G.STAGES.RUN then
                compress_and_save(G.SETTINGS.profile .. '/' .. 'debugsave' .. v .. '.jkr', G.ARGS.save_run)
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

return global
