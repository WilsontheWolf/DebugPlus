local utf8 = require("utf8")

local global = {}

-- Main Variables 
local enhancements = nil
local seals = nil
local suits = nil
local ranks = nil
local saveStateKeys = {"1", "2", "3"}

-- Console Variables
local showTime = 5 -- Amount of time new console messages show up 
local fadeTime = 1 -- Amount of time it takes for a message to fade
local consoleOpen = false
local openNextFrame = false
local showNewLogs = true
local firstConsoleRender = nil
local logs = nil
local inputText = ""
local old_print = print

local function handleLog(colour, ...)
    old_print(...)
    local _str = ""
    for i, v in ipairs({...}) do
        _str = _str .. tostring(v) .. " "
    end
    local meta = {
        str = _str,
        time = love.timer.getTime(),
        colour = colour
    }
    table.insert(logs, meta)
    if #logs > 100 then
        table.remove(logs, 1)
    end

end

local function log(...)
    handleLog({.65, .36, 1}, "[DebugPlus]", ...)
end

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

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
            if not has_value(ranks, v.key) then
                table.insert(ranks, v.key)
            end
        end
    end
    return ranks
end

local function runCommand() 
    if inputText == "" then return end
    handleLog({1, 0, 1}, "> " .. inputText)

    local args = {}
    for w in string.gmatch(inputText, "%a+") do
        table.insert(args, w)
    end
    local cmd = table.remove(args, 1)
    log("Command:", cmd)
    log("args:", inspect(args))


    -- Cleanup
    inputText = ""
end

function global.consoleHandleKey(controller, key)
    if not consoleOpen then
        if key == '/' then
            if love.keyboard.isDown('lshift') then
                showNewLogs = not showNewLogs
            else
                openNextFrame = true -- This is to prevent the keyboad handler from typing this key
            end
        end
        return true
    end

    if key == "escape" then
        consoleOpen = false
        inputText = ""
    end
    -- This bit stolen from https://love2d.org/wiki/love.textinput
    if key == "backspace" then
        -- get the byte offset to the last UTF-8 character in the string.
        local byteoffset = utf8.offset(inputText, -1)

        if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            inputText = string.sub(inputText, 1, byteoffset - 1)
        end
    end

    if key == "return" then
        if love.keyboard.isDown('lshift') then
            inputText = inputText .. "\n"
        else
            runCommand()
        end
    end

end

local orig_textinput = love.textinput
function love.textinput(t)
    if orig_textinput then
        orig_textinput(t)
    end -- That way if another mod uses this, I don't clobber it's implementation
    if not consoleOpen then
        return
    end
    inputText = inputText .. t
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
                            _card:set_sprites(nil, "cards_" .. (G.SETTINGS.colourblind_option and 2 or 1))
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
                _area = G.hand
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
            if _card.playing_card then
                for j = 1, #G.jokers.cards do
                    eval_card(G.jokers.cards[j], {
                        cardarea = G.jokers,
                        remove_playing_cards = true,
                        removed = {_card}
                    })
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
    if key == "m" then
        G.FUNCS.change_pixel_smoothing({
            to_key = G.SETTINGS.GRAPHICS.texture_scaling
        })
        log("Reloaded Atlases")
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
    if _element and _element.config and _element.config.blind then
        local _blind = _element.config.blind
        if key == "2" then
            G.P_BLINDS[_blind.key].unlocked = true
            G.P_BLINDS[_blind.key].discovered = true
            G.P_BLINDS[_blind.key].alerted = true
            _element:set_sprite_pos(_blind.pos)
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

local function calcHeight(text, width)
    local font = love.graphics.getFont()
    local rw, lines = font:getWrap(text, width)
    local lineHeight = font:getHeight()

    return #lines * lineHeight, rw, lineHeight
end

global.registerLogHandler = function()
    if logs then
        return
    end
    logs = {}
    print = function(...)
        handleLog({0, 1, 1}, ...)
    end
end

global.doConsoleRender = function()
    if openNextFrame then
        consoleOpen = true
        openNextFrame = false
    end
    if not consoleOpen and not showNewLogs then
        return
    end
    -- Setup
    local width, height = love.graphics.getDimensions()
    local padding = 10
    local lineWidth = width - padding * 2
    local bottom = height - padding * 2
    local now = love.timer.getTime()
    if firstConsoleRender == nil then
        firstConsoleRender = now
        log("Press [/] to toggle console and press [shift] + [/] to toggle new log previews")
    end
    -- Input Box
    love.graphics.setColor(0, 0, 0, .5)
    if consoleOpen then
        bottom = bottom - padding * 2
        local lineHeight, realWidth, singleLineHeight = calcHeight(inputText, lineWidth)
        love.graphics.rectangle("fill", padding, bottom - lineHeight + padding, lineWidth, lineHeight + padding * 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(inputText, padding * 2, bottom - lineHeight + singleLineHeight, lineWidth - padding * 2)

        bottom = bottom - lineHeight - padding * 2
    end

    -- Main window
    if consoleOpen then
        love.graphics.setColor(0, 0, 0, .5)
        love.graphics.rectangle("fill", padding, padding, lineWidth, bottom)
    end
    for i = #logs, 1, -1 do
        local v = logs[i]
        if not consoleOpen and v.time < firstConsoleRender then
            break
        end
        local age = now - v.time
        if not consoleOpen and age > showTime + fadeTime then
            break
        end
        local lineHeight, realWidth = calcHeight(v.str, lineWidth)
        bottom = bottom - lineHeight
        if bottom < padding then
            break
        end

        local opacityPercent = 1
        if not consoleOpen and age > showTime then
            opacityPercent = (fadeTime - (age - showTime)) / fadeTime
        end

        if not consoleOpen then
            love.graphics.setColor(0, 0, 0, .5 * opacityPercent)
            love.graphics.rectangle("fill", padding, bottom, lineWidth, lineHeight)
        end
        love.graphics.setColor(v.colour[1], v.colour[2], v.colour[3], opacityPercent)

        love.graphics.printf(v.str, padding * 2, bottom, lineWidth - padding * 2)
    end
end

return global
