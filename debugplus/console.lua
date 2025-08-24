local util = require("debugplus.util")
local utf8 = require("utf8")
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
---@type {name: string, source: string, desc: string, shortDesc: string, exec: fun(args: string[], rawArgs: string, dp: table): string, string?, table?}[]
local commands = nil
local logOffset = 0

commands = {{
    name = "echo",
    source = "debugplus",
    shortDesc = "Repeat's what you say",
    desc = "Mostly just a testing command. Outputs what you input.",
    exec = function(args, rawArgs, dp)
        return rawArgs
    end
}, {
    name = "help",
    source = "debugplus",
    shortDesc = "Get command info",
    desc = "Get's help about commands. When run without args, lists all commands and their short descriptions. When run with a command name, shows info about that command.",
    exec = function(args, rawArgs, dp)
        local toLookup = args[1]
        if not toLookup then
            local out = "Help:\nBelow is a list of commands.\n"
            for k, v in ipairs(commands) do
                out = out .. v.name .. ": " .. v.shortDesc .. "\n"
            end
            out = out .. "\nFor more information about a specific command, run 'help <commandName>'"
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
        local success = table.remove(res, 1)
        res.n = res.n - 1
        local resString = ""
        if res.n > 1 then
            for k = 1, res.n do
                local v = res[k]
                if k ~= 1 then
                    resString = resString .. ", "
                end
                resString = resString .. util.stringifyTable(v)
            end
        else
            resString = util.stringifyTable(res[1])
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

local function loadHistory()
    if not config.getValue("commandHistory") then return end
    local content = love.filesystem.read("config/DebugPlus.history.jkr")
    if not content then
        return
    end
    local t = {}
    for str in string.gmatch(content, "([^\n\r]+)") do
        table.insert(history, 1, util.unescapeSimple(str))
    end
end

local function saveHistory()
    local max = config.getValue("commandHistoryMax")
    local str = ""
    for i = math.min(#history, max), 1, -1 do
        if str ~= "" then str = str .. "\n" end
        str = str .. util.escapeSimple(history[i])
    end
    love.filesystem.write("config/DebugPlus.history.jkr", str)
end

local function closeConsole()
    input:clear()
    consoleOpen = false
    love.keyboard.setKeyRepeat(gameKeyRepeat)
    love.keyboard.setTextInput(gameTextInput)

end

local function runCommand()
    local inputText = util.trim(input:toString())
    if inputText == "" then
        return
    end

    logger.handleLog({1, 0, 1}, "INFO", "> " .. inputText)
    if history[1] ~= inputText then
        table.insert(history, 1, inputText)
    end

    if config.getValue("commandHistory") then
        saveHistory()
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
        if config.getValue("hyjackErrorHandler") then hyjackErrorHandler() end
        loadHistory()
        hookStuffs()
        firstConsoleRender = now
        local key = "/"
        if love.keyboard.getScancodeFromKey("/") == "unknown" then
            key = love.keyboard.getKeyFromScancode("/")
        end
        logger.log("Press [" .. key .. "] to toggle console and press [shift] + [" .. key .. "] to toggle new log previews")
    end
    -- Input Box
    love.graphics.setColor(0, 0, 0, .5)
    if consoleOpen then
        bottom = bottom - padding * 2
        input:setWidth(lineWidth - padding * 2)
        local inputHeight = input:getHeight()
        love.graphics.rectangle("fill", padding, bottom - inputHeight + padding, lineWidth, inputHeight + padding * 2)
        love.graphics.setColor(1, 1, 1, 1)
        input:draw(padding * 2, bottom - inputHeight + padding * 2)


        bottom = bottom - inputHeight - padding
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
    if not options.name and not string.match(options.name, "^[%l%d_-]$") then
        error("Options.name must be provided and match pattern `^[%l%d_-]$`.")
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
    local cmd = {
        source = id,
        name = options.name,
        exec = options.exec,
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
