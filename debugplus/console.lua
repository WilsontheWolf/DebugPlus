local util = require("debugplus.util")
local watcher = require("debugplus.watcher")
local config = require("debugplus.config")
local logger = require("debugplus.logger")
local ui = require "debugplus.ui"

local global = {}

local showTime = 5 -- Amount of time new console messages show up 
local fadeTime = 1 -- Amount of time it takes for a message to fade
local consoleOpen = false
local openNextFrame = false
local gameKeyRepeat = love.keyboard.hasKeyRepeat()
local gameTextInput = love.keyboard.hasTextInput()
local showNewLogs = config.getValue("showNewLogs")
local firstConsoleRender = nil
---@type string[]
local history = {}
---@type {index: number, val: string}
local currentHistory = nil
local autocompleteState = nil
---@type {name: string, source: string, desc: string, shortDesc: string, exec: fun(args: string[], rawArgs: string, dp: table): string, string?, table?}[]
local commands = nil
local logOffset = 0

commands = {{
    name = "echo",
    source = "debugplus",
    sourceName = "DebugPlus",
    shortDesc = "Repeat's what you say",
    desc = "Mostly just a testing command. Outputs what you input.",
    exec = function(args, rawArgs, dp)
        return rawArgs
    end
}, {
    name = "help",
    source = "debugplus",
    sourceName = "DebugPlus",
    shortDesc = "Get command info",
    desc = "Get's help about commands. When run without args, lists all commands and their short descriptions. When run with a command name, shows info about that command.",
    exec = function(args, rawArgs, dp)
        local toLookup = args[1]
        if not toLookup then
            local groups = {}
            local group_names = {}
            local source_names = {}
            for _, command in ipairs(commands) do
                local source_id = command.source:lower()
                if not groups[source_id] then
                    groups[source_id] = {}
                    source_names[source_id] = source_id == "debugplus" and "DebugPlus" or command.sourceName or command.source
                    table.insert(group_names, source_id)
                end
                table.insert(groups[source_id], command)
            end

            table.sort(group_names)
            local out = "Available commands:"
            for _, source_id in ipairs(group_names) do
                table.sort(groups[source_id], function(a, b)
                    return a.name < b.name
                end)
                out = out .. "\n\n" .. source_names[source_id] .. ":"
                for _, command in ipairs(groups[source_id]) do
                    out = out .. "\n  " .. command.name .. " - " .. command.shortDesc
                end
            end
            out = out .. "\n\nFor details, run 'help <commandName>'."
            return out
        end
        local cmdName = string.lower(string.gsub(toLookup, "^(%S+).*", "%1"))
        local cmd
        for i, c in ipairs(commands) do
            if c.source .. ":" .. c.name == cmdName then
                cmd = c
                break
            end
            if c.name == cmdName then
                cmd = c
                break
            end
        end
        if not cmd then
            return '"' .. cmdName .. '" could not be found. To see a list of all commands, run "help" without any args',
            "ERROR"
        end
        return cmd.name .. ":\n" .. cmd.desc .. "\n\nThis command can be run by typing '" .. cmd.name .. "' or '" ..
        cmd.source .. ":" .. cmd.name .. "'."
    end
}, {
    name = "eval",
    source = "debugplus",
    shortDesc = "Evaluate lua code",
    desc = "Execute's lua code. This code has access to all the globals that the game has, as well as a dp object, with some DebugPlus specific stuff.",
    exec = function(args, rawArgs, dp)
        local env = {}
        for k, v in pairs(_G) do
            env[k] = v
        end
        env.dp = dp
        local func, err = load("return " .. rawArgs, "DebugPlus Eval", "t", env)
        if not func then
            func, err = load(rawArgs, "DebugPlus Eval", "t", env)
        end
        if not func then
            return "Syntax Error: " .. err, "ERROR"
        end
        local res = util.pack(pcall(func))
        local success = res[1]
        res.n = res.n - 1
        local resString = ""
        if res.n > 1 then
            for k = 1, res.n do
                local v = res[k + 1]
                if k ~= 1 then
                    resString = resString .. ", "
                end
                resString = resString .. util.stringifyTable(v)
            end
        else
            resString = util.stringifyTable(res[2])
        end
        if not success then
            return "Error: " .. resString, "ERROR"
        end
        return resString
    end
}, {
    name = "money",
    source = "debugplus",
    shortDesc = "Set or add money",
    desc = "Set or add to your money. Usage:\nmoney set [amount] - Set your money to the given amount\nmoney add [amount] - Adds the given amount to your money.",
    exec = function(args, rawArgs, dp)
        if G.STAGE ~= G.STAGES.RUN then
            return "This command must be run during a run.", "ERROR"
        end
        local subCmd = args[1]
        local amount = tonumber(args[2])
        if subCmd == "set" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.dollars = amount
        elseif subCmd == "add" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.dollars = G.GAME.dollars + amount
        else
            return "Please choose whether you want to add or set. For more info, run 'help money'"
        end
        return "Money is now $" .. G.GAME.dollars
    end
}, {
    name = "round",
    source = "debugplus",
    shortDesc = "Set or add to your round",
    desc = "Set or add to your round. Usage:\nround set [amount] - Set the current round to the given amount\nround add [amount] - Adds the given number of rounds.",
    exec = function(args, rawArgs, dp)
        if G.STAGE ~= G.STAGES.RUN then
            return "This command must be run during a run.", "ERROR"
        end
        local subCmd = args[1]
        local amount = tonumber(args[2])
        if subCmd == "set" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.round = amount
        elseif subCmd == "add" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.round = G.GAME.round + amount
        else
            return "Please choose whether you want to add or set. For more info, run 'help round'"
        end
        return "Round is now " .. G.GAME.round
    end
}, {
    name = "ante",
    source = "debugplus",
    shortDesc = "Set or add to your ante",
    desc = "Set or add to your ante. Usage:\nante set [amount] - Set the current ante to the given amount\nante add [amount] - Adds the given number of antes.",
    exec = function(args, rawArgs, dp)
        if G.STAGE ~= G.STAGES.RUN then
            return "This command must be run during a run.", "ERROR"
        end
        local subCmd = args[1]
        local amount = tonumber(args[2])
        if subCmd == "set" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.round_resets.ante = amount
        elseif subCmd == "add" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.round_resets.ante = G.GAME.round_resets.ante + amount
        else
            return "Please choose whether you want to add or set. For more info, run 'help ante'"
        end
        return "Ante is now " .. G.GAME.round_resets.ante
    end
}, {
    name = "discards",
    source = "debugplus",
    shortDesc = "Set or add to your hand",
    desc = "Set or add to your hand. Usage:\ndiscards set [amount] - Set the current hand to the given amount\ndiscards add [amount] - Adds the given number of discards.",
    exec = function(args, rawArgs, dp)
        if G.STAGE ~= G.STAGES.RUN then
            return "This command must be run during a run.", "ERROR"
        end
        local subCmd = args[1]
        local amount = tonumber(args[2])
        if subCmd == "set" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.current_round.discards_left = amount
        elseif subCmd == "add" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.current_round.discards_left = G.GAME.current_round.discards_left + amount
        else
            return "Please choose whether you want to add or set. For more info, run 'help hand'"
        end
        return "Discards are now " .. G.GAME.current_round.discards_left
    end
}, {
    name = "hands",
    source = "debugplus",
    shortDesc = "Set or add to your hand",
    desc = "Set or add to your hand. Usage:\nhands set [amount] - Set the current hand to the given amount\nhands add [amount] - Adds the given number of hands.",
    exec = function(args, rawArgs, dp)
        if G.STAGE ~= G.STAGES.RUN then
            return "This command must be run during a run.", "ERROR"
        end
        local subCmd = args[1]
        local amount = tonumber(args[2])
        if subCmd == "set" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.current_round.hands_left = amount
        elseif subCmd == "add" then
            if not amount then
                return "Please provide a valid number to set/add.", "ERROR"
            end
            G.GAME.current_round.hands_left = G.GAME.current_round.hands_left + amount
        else
            return "Please choose whether you want to add or set. For more info, run 'help hand'"
        end
        return "Hands are now " .. G.GAME.current_round.hands_left
    end
}, {
    name = "watch",
    source = "debugplus",
    shortDesc = "Watch and execute a file when it changes.",
    desc = "Watch and execute a file when it changes. Usage:\nwatch stop - Stop's watching files.\n".. watcher.subCommandDesc .."Files should be a relative path to a file in the save directory (e.g. `Mods/Example/test.lua`)",
    exec = function(args, rawArgs, dp)
        local subCmd = args[1]
        local file = args[2]
        if subCmd == "stop" then
            watcher.stopWatching()
            return "I will stop watching for file changes."
        elseif watcher.types[subCmd] then
            local succ, err = watcher.startWatching(file, subCmd)
            if not succ then return err, "ERROR" end
            return "Started watching " .. file
        else
            return "Please provide a valid sub command. For more info, run 'help watch'"
        end
    end
}, {
    name = "tutorial",
    source = "debugplus",
    shortDesc = "Modify the tutorial state.",
    desc = "Modify the tutorial state. Usage:\ntutorial finish - Finish the tutorial.\ntutorial reset - Reset the tutorial progress to a fresh state.\ntutorial new - Starts a new tutorial run (like hitting play for the first time)",
    exec = function(args, rawArgs, dp)
        local subCmd = args[1]
        if subCmd == "finish" then
            if G.OVERLAY_TUTORIAL then
                G.FUNCS.skip_tutorial_section()
            end
            G.SETTINGS.tutorial_complete = true
            G.SETTINGS.tutorial_progress = nil
            return "Tutorial finished."
        elseif subCmd == "reset" then
            G.SETTINGS.tutorial_complete = false
            G.SETTINGS.tutorial_progress = {
                forced_shop = {'j_joker', 'c_empress'},
                forced_voucher = 'v_grabber',
                forced_tags = {'tag_handy', 'tag_garbage'},
                hold_parts = {},
                completed_parts = {}
            }
            return "Tutorial reset."
        elseif subCmd == "new" then
            G.FUNCS.start_tutorial()
            return "Starting a new run."
        else
            return "Please provide a valid sub command. For more info, run 'help tutorial'"
        end
    end
}, {
    name = "resetshop",
    source = "debugplus",
    shortDesc = "Reset the shop.",
    desc = "Resets the shop.",
    exec = function(args, rawArgs, dp)
        if G.STATE ~= G.STATES.SHOP then
            return "This command can only be run in a shop.", 'ERROR'
        end
        G.shop:remove()
        G.shop = nil
        G.SHOP_SIGN:remove()
        G.SHOP_SIGN = nil
        G.GAME.current_round.used_packs = nil
        G.STATE_COMPLETE = false
        G:update_shop()
        return "Reset shop."
    end
}, {
    name = "value",
    source = "debugplus",
    shortDesc = "Get and modify highlighted card values",
    desc = "Retrives or modifies the values of the currently hovered card. Usage:\nvalue get - Gets all detected values on the hovered card.\nvalue set [keys] [value] - Modifies a value of hovered card. The format of keys should match the 'get' command.\nvalue set_center [keys] [value] - Modifies a value on the center of the hovered card. This will modify future versions of the card.",
    exec = function (args, rawArgs, dp)
        local unmodified_vals = {
            bonus = 0,
            perma_bonus = 0,
            extra_value = 0,
            p_dollars = 0,
            h_mult = 0,
            h_x_mult = 0,
            h_dollars = 0,
            h_size = 0,
            d_size = 0,
            hands_played_at_create = 0,
            mult = 0,
            x_mult = 1,
            e_mult = 0,
            ee_mult = 0,
            eee_mult = 0,
            x_chips = 0,
            e_chips = 0,
            ee_chips = 0,
            eee_chips = 0,
            t_mult = 0,
            t_chips = 0,
        }
        local ignore_vals = {
            name = true,
            set = true,
            order = true,
            consumeable = true
        }
        if dp.hovered:is(Card) then
            if args[1] == "get" then
                local values = "Values:"
                for k, v in pairs(dp.hovered.ability) do
                    if (not ignore_vals[k]) and (not unmodified_vals[k] or unmodified_vals[k] ~= dp.hovered.ability[k]) then
                        if k == "hyper_chips" or k == "hyper_mult" then
                            if dp.hovered.ability[k][1] ~= 0 or dp.hovered.ability[k][2] ~= 0 then
                                values = values .. "\n" .. tostring(k) .. " " .. tostring(dp.hovered.ability[k][1]) .. " " .. tostring(dp.hovered.ability[k][2])
                            end
                        elseif type(dp.hovered.ability[k]) == "table" then
                            for kk, vv in pairs(dp.hovered.ability[k]) do
                                values = values .. "\n" .. tostring(k) .. " " .. tostring(kk) .. " " .. tostring(vv)
                            end
                        elseif dp.hovered.ability[k] ~= "" then
                            values = values .. "\n" .. tostring(k) .. " " .. tostring(dp.hovered.ability[k])
                        end
                    end
                end
                return values
            elseif args[1] == "set" or args[1] == "set_center" then
                local root = dp.hovered.ability
                if args[1] == "set_center" then
                    root = dp.hovered.config.center.config
                end
                local rootC
                if dp.hovered.ability.consumeable then
                    rootC = root.consumeable
                end
                if #args < 2 then
                    return "Please provide a key to set", "ERROR"
                end
                if #args < 3 then
                    return "Please provide a value to set", "ERROR"
                end
                for i = 2, #args-2 do
                    root = root[args[i]]
                    if rootC then rootC = rootC[args[i]] end
                end
                if tonumber(args[#args]) then --number
                    root[args[#args-1]] = tonumber(args[#args])
                    if rootC then rootC[args[#args-1]] = tonumber(args[#args]) end
                elseif args[#args] == "true" then --bool
                    root[args[#args-1]] = true
                    if rootC then rootC[args[#args-1]] = true end
                elseif args[#args] == "false" then
                    root[args[#args-1]] = false
                    if rootC then rootC[args[#args-1]] = false end
                else
                    root[args[#args-1]] = args[#args]
                    if rootC then rootC[args[#args-1]] = args[#args] end
                end
                return "Value set successfully."
            else
                return "Invalid argument. Use 'get' or 'set' or 'set_center'.", "ERROR"
            end
        else
            return "This command only works while hovering over a card. Rerun it while hovering over a card.", "ERROR"
        end
    end
}}
local input = ui.TextInput.new(0)

local function fullSaveHistory()
        local max = config.getValue("commandHistoryMax")
        local str = {}
        for i = math.min(#history, max), 1, -1 do
            local val = util.escapeSimple(history[i])
            table.insert(str, val)
        end
        love.filesystem.createDirectory("config")
        love.filesystem.write("config/DebugPlus.history.jkr", table.concat(str, "\n"))
end

local function loadHistory()
    if not config.getValue("commandHistory") then return end
    local content = love.filesystem.read("config/DebugPlus.history.jkr")
    if not content then
        return
    end
    for str in string.gmatch(content, "([^\n\r]+)") do
        table.insert(history, 1, util.unescapeSimple(str))
    end
    if #history > config.getValue("commandHistoryMax") then
        fullSaveHistory()
    end
end

local function saveHistory(latest)
    local file = "config/DebugPlus.history.jkr"
    local fs = love.filesystem
    if fs.getInfo(file) then
        fs.append(file, "\n" .. util.escapeSimple(latest))
    else
        fullSaveHistory()
    end
end

local function closeConsole()
    input:clear()
    autocompleteState = nil
    consoleOpen = false
    love.keyboard.setKeyRepeat(gameKeyRepeat)
    love.keyboard.setTextInput(gameTextInput)

end

local function fuzzyMatch(candidate, query)
    candidate = string.lower(candidate)
    query = string.lower(query)
    if query == "" or string.find(candidate, query, 1, true) then
        return true
    end

    local candidateIndex = 1
    for queryIndex = 1, #query do
        local found = string.find(candidate, query:sub(queryIndex, queryIndex), candidateIndex, true)
        if not found then
            return false
        end
        candidateIndex = found + 1
    end
    return true
end

local function getAutocompleteContext()
    local before = input.input1:toString()
    local after = input.input2:toString()
    local head, prefix = before:match("^(.*%s)(%S*)$")
    if not head then
        head = ""
        prefix = before
    end
    local suffix = after:match("^(%S*)") or ""
    local tail = after:sub(#suffix + 1)
    local tokens = {}
    for token in head:gmatch("%S+") do
        table.insert(tokens, token)
    end

    local candidates = {}
    if #tokens == 0 then
        for _, command in ipairs(commands) do
            table.insert(candidates, command.name)
        end
    else
        local command_name = string.lower(tokens[1])
        local command
        for _, candidate in ipairs(commands) do
            if candidate.name == command_name or candidate.source .. ":" .. candidate.name == command_name then
                command = candidate
                break
            end
        end
        if command and command.autocomplete then
            local args = {}
            for index = 2, #tokens do
                table.insert(args, tokens[index])
            end
            local success, results = pcall(command.autocomplete, args, #args + 1, prefix)
            if success and type(results) == "table" then
                candidates = results
            end
        end
    end

    local suggestions = {}
    local seen = {}
    for _, candidate in ipairs(candidates) do
        if type(candidate) == "string" and fuzzyMatch(candidate, prefix) then
            local normalized = candidate:lower()
            if not seen[normalized] then
                seen[normalized] = true
                table.insert(suggestions, candidate)
            end
        end
    end
    table.sort(suggestions, function(a, b)
        local a_starts = a:lower():sub(1, #prefix) == prefix:lower()
        local b_starts = b:lower():sub(1, #prefix) == prefix:lower()
        if a_starts ~= b_starts then
            return a_starts
        end
        return a:lower() < b:lower()
    end)
    return suggestions, head, tail
end

local function currentAutocompleteState()
    local current = input:toString()
    if autocompleteState and
        (autocompleteState.original == current or autocompleteState.applied == current) then
        return autocompleteState
    end

    local suggestions, head, tail = getAutocompleteContext()
    if #suggestions == 0 then
        autocompleteState = nil
        return nil
    end

    autocompleteState = {
        suggestions = suggestions,
        head = head,
        tail = tail,
        index = 1,
        original = current
    }
    return autocompleteState
end

local function cycleAutocomplete(direction)
    local state = currentAutocompleteState()
    if not state then
        return false
    end

    state.index = (state.index - 1 + direction) % #state.suggestions + 1
    return true
end

local function autocompleteInput()
    local state = currentAutocompleteState()
    if not state then
        return false
    end

    if state.applied == input:toString() then
        state.index = state.index % #state.suggestions + 1
    end
    local replacement = state.head .. state.suggestions[state.index] .. state.tail
    state.applied = replacement
    input:set(replacement)
    return true
end

local function runCommand()
    local inputText = util.trim(input:toString())
    if inputText == "" then
        return
    end

    logger.handleLog({1, 0, 1}, "INFO", "> " .. inputText)
    if history[1] ~= inputText then
        table.insert(history, 1, inputText)
        if config.getValue("commandHistory") then
            saveHistory(inputText)
        end
    end

    local cmdName = string.lower(string.gsub(inputText, "^(%S+).*", "%1"))
    local rawArgs = string.gsub(inputText, "^%S+%s*(.*)", "%1")
    local args = {}
    for w in string.gmatch(rawArgs, "%S+") do
        table.insert(args, w)
    end

    closeConsole()

    local cmd
    for i, c in ipairs(commands) do
        if c.source .. ":" .. c.name == cmdName then
            cmd = c
            break
        end
        if c.name == cmdName then
            cmd = c
            break
        end
    end
    if not cmd then
        return logger.handleLog({1, 0, 0}, "ERROR", "< ERROR: Command '" .. cmdName .. "' not found.")
    end
    local dp = {
        hovered = G and G.CONTROLLER and G.CONTROLLER.hovering.target,
        handleLog = logger.handleLog
    }
    local success, result, loglevel, colourOverride = pcall(cmd.exec, args, rawArgs, dp)
    if not success then
        return logger.handleLog({1, 0, 0}, "ERROR", "< An error occurred processing the command:", result)
    end
    local level = loglevel or "INFO"
    if not logger.levelMeta[level] then
        level = "INFO"
        logger.handleLogAdvanced({
            level = "WARN",
        }, "[DebugPlus] Command ".. cmdName.. " returned an invalid log level. Defaulting to INFO.")
    end
    local colour = colourOverride or logger.levelMeta[level].colour
    if success and success ~= "" then
        return logger.handleLog(colour, level, "<", result)
    else
        return logger.handleLog(colour, level, "< Command exited without a response.")
    end
end

local orig_keypressed
local function consoleHandleKey(key, scancode, isrepeat)
    if not consoleOpen then
        local toCheck = key
        if love.keyboard.getScancodeFromKey("/") == "unknown" then
            toCheck = scancode
        end
        if toCheck == '/' or toCheck == 'kp/' then
            if util.isShiftDown() then
                showNewLogs = not showNewLogs
            else
                openNextFrame = true -- This is to prevent the keyboard handler from typing this key
            end
        end
        if orig_keypressed then
            return orig_keypressed(key, scancode, isrepeat)
        end
        return true
    end

    if key == "escape" then
        closeConsole()
    end

    if key == "tab" then
        autocompleteInput()
        return
    end

    if key == "up" and cycleAutocomplete(-1) then
        return
    end

    if key == "down" and cycleAutocomplete(1) then
        return
    end

    autocompleteState = nil

    if key == "return" then
        if util.isShiftDown() then
            input:textinput("\n")
        else
            runCommand()
        end
    end

    if key == "v" and util.isCtrlDown() then
        input:textinput(love.system.getClipboardText())
    end

    if key == "up" then
        if currentHistory.index >= #history then
            return
        end
        if currentHistory.index == 0 then
            currentHistory.val = input:toString()
        end
        currentHistory.index = currentHistory.index + 1
        input:set(history[currentHistory.index])
    end

    if key == "down" then
        if currentHistory.index <= 0 then
            return
        end
        currentHistory.index = currentHistory.index - 1
        if currentHistory.index == 0 then
            input:set(currentHistory.val)
        else
            input:set(history[currentHistory.index])
        end
    end

    input:keypressed(key)
end

local orig_textinput
local function textinput(t)
    if not consoleOpen then
        if orig_textinput then
            orig_textinput(t)
        end -- That way if another mod uses this, I don't clobber it's implementation
        return
    end
    autocompleteState = nil
    input:textinput(t)
end

local orig_wheelmoved
local function wheelmoved(x, y)
    if not consoleOpen then
        if orig_wheelmoved then
            orig_wheelmoved(x, y)
        end
        return
    end
    logOffset = math.min(math.max(logOffset + y, 0), #logger.logs - 1)
end

local function hookStuffs()
    orig_textinput = love.textinput
    love.textinput = textinput

    orig_wheelmoved = love.wheelmoved
    love.wheelmoved = wheelmoved

    orig_keypressed = love.keypressed
    love.keypressed = consoleHandleKey
end

local function calcHeight(text, width)
    local font = love.graphics.getFont()
    local rw, lines = font:getWrap(text, width)
    local lineHeight = font:getHeight()

    return #lines * lineHeight, rw, lineHeight
end

local function hyjackErrorHandler()
    local orig = love.errorhandler
    if not orig then -- Vanilla
        return -- Doesn't work with love.errhand (need love.errorhandler)
    end
    local function safeCall(func, ...)
        local succ, res = pcall(func, ...)
        if not succ then print("ERROR", res)
        else return res end
    end
    function love.errorhandler(msg)
        local ret = orig(msg)
        if not ret or type(ret) ~= "function" then return ret end
        orig_wheelmoved = nil
        orig_textinput = nil
        orig_keypressed = nil
        closeConsole()
        local justCrashed = true

        local present = love.graphics.present
        function love.graphics.present()
            local r, g, b, a = love.graphics.getColor()
            if justCrashed then
                firstConsoleRender = love.timer.getTime()
                justCrashed = false
            end
            safeCall(global.doConsoleRender)
            love.graphics.setColor(r,g,b,a)
            present()
        end

        return function()
            love.event.pump()

            local evts = {}

            for e, a, b, c in love.event.poll() do
                if consoleOpen and e == "textinput" then
                    safeCall(textinput, a)
                elseif consoleOpen and e == "wheelmoved" then
                    safeCall(wheelmoved, a, b)
                elseif e == "keypressed" then
                    if safeCall(consoleHandleKey, a) then
                        table.insert(evts, {e,a,b,c})
                    end
                else
                    table.insert(evts, {e,a,b,c})
                end
            end
            for _,v in ipairs(evts) do -- Add back for the original handler
                love.event.push(unpack(v))
            end
            return ret()
        end
    end
end

function global.doConsoleRender()
    if openNextFrame then
        consoleOpen = true
        openNextFrame = false
        currentHistory = {
            index = 0,
            val = ""
        }
        logOffset = 0
        gameKeyRepeat = love.keyboard.hasKeyRepeat()
        gameTextInput = love.keyboard.hasTextInput()
        love.keyboard.setKeyRepeat(true)
        love.keyboard.setTextInput(true)
    end
    local now = love.timer.getTime()
    if firstConsoleRender == nil then
        if config.getValue("hyjackErrorHandler") then hyjackErrorHandler() end
        loadHistory()
        hookStuffs()
        firstConsoleRender = now
        local key = "/"
        if love.keyboard.getScancodeFromKey("/") == "unknown" then
            key = love.keyboard.getKeyFromScancode("/")
        end
        logger.log("Press [" .. key .. "] to toggle console and press [shift] + [" .. key .. "] to toggle new log previews")
        input:newFont()
    end
    if not consoleOpen and not showNewLogs then
        return
    end
    -- Setup
    local width, height = love.graphics.getDimensions()
    local padding = 10
    local lineWidth = width - padding * 2
    local bottom = height - padding * 2
    -- Input Box
    love.graphics.setColor(0, 0, 0, .5)
    if consoleOpen then
        bottom = bottom - padding * 2
        input:setWidth(lineWidth - padding * 2)
        local inputHeight = input:getHeight()
        love.graphics.rectangle("fill", padding, bottom - inputHeight + padding, lineWidth, inputHeight + padding * 2)
        love.graphics.setColor(1, 1, 1, 1)
        input:draw(padding * 2, bottom - inputHeight + padding * 2)

        local state = util.trim(input:toString()) ~= "" and currentAutocompleteState() or nil
        local suggestions = state and state.suggestions or {}
        local suggestionCount = math.min(#suggestions, 5)
        local suggestionLineHeight = love.graphics.getFont():getHeight() + 2
        local suggestionHeight = suggestionCount > 0 and suggestionCount * suggestionLineHeight + padding or 0
        if suggestionCount > 0 then
            local inputTop = bottom - inputHeight + padding
            local suggestionY = inputTop - suggestionHeight - 4
            local selected = state and state.index or 1
            love.graphics.setColor(0, 0, 0, 0.78)
            love.graphics.rectangle("fill", padding, suggestionY, lineWidth, suggestionHeight, 4, 4)
            for index = 1, suggestionCount do
                if index == selected then
                    love.graphics.setColor(1, 1, 1, 0.16)
                    love.graphics.rectangle(
                        "fill",
                        padding + 3,
                        suggestionY + (index - 1) * suggestionLineHeight + 2,
                        lineWidth - 6,
                        suggestionLineHeight
                    )
                end
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(
                    suggestions[index],
                    padding * 2,
                    suggestionY + (index - 1) * suggestionLineHeight + 2
                )
            end
        end

        bottom = bottom - inputHeight - padding - suggestionHeight - (suggestionCount > 0 and 4 or 0)
    end

    -- Main window
    if consoleOpen then
        love.graphics.setColor(0, 0, 0, .5)
        love.graphics.rectangle("fill", padding, padding, lineWidth, bottom)
    end
    for i = #logger.logs, 1, -1 do
        local v = logger.logs[i]
        if consoleOpen and #logger.logs - logOffset < i then -- TODO: could this be more efficent?
            goto finishrender
        end
        if not consoleOpen and v.time < firstConsoleRender then
            break
        end
        local age = now - v.time
        if not consoleOpen and age > showTime + fadeTime then
            break
        end
        if not logger.levelMeta[v.level].shouldShow and not v.command then
            goto finishrender
        end
        if not v.command and config.getValue("onlyCommands") then
            goto finishrender
        end
        local msg = v.str
        if consoleOpen and not v.hack_no_prefix then
            msg = "[" .. string.sub(v.level, 1, 1) .. "] " .. msg
        end
        local lineHeight, realWidth = calcHeight(msg, lineWidth)
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

        love.graphics.printf(msg, padding * 2, bottom, lineWidth - padding * 2)
        ::finishrender::
    end
end

function global.registerCommand(id, options)
    if not options then
        error("Options must be provided")
    end
    if type(options.name) ~= "string" or not string.match(options.name, "^[%l%d_-]+$") then
        error("Options.name must contain only lowercase letters, numbers, underscores, and hyphens.")
    end
    if not options.exec or type(options.exec) ~= "function" then
        error("Options.exec must be a function")
    end
    if not options.shortDesc or type(options.shortDesc) ~= "string" then
        error("Options.shortDesc must be a string")
    end
    if not options.desc or type(options.desc) ~= "string" then
        error("Options.desc must be a string")
    end
    if options.autocomplete ~= nil and type(options.autocomplete) ~= "function" then
        error("Options.autocomplete must be a function")
    end
    local cmd = {
        source = id,
        sourceName = options.sourceName or (id == "debugplus" and "DebugPlus" or id),
        name = options.name,
        exec = options.exec,
        autocomplete = options.autocomplete,
        shortDesc = options.shortDesc,
        desc = options.desc
    }
    for k, v in ipairs(commands) do
        if v.source == cmd.source and v.name == cmd.name then
            error("This command already exists")
        end
    end
    table.insert(commands, cmd)
end

local function handleLogsChange(added)
    added = added or 0
    logOffset = math.min(logOffset + added, #logger.logs)
end

logger.handleLogsChange = handleLogsChange
config.configDefinition.showNewLogs.onUpdate = function(v)
    showNewLogs = v
end

function global.isConsoleFocused() -- For mods to disable keys.
    return consoleOpen
end

return global
