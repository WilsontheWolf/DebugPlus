local util = require("debugplus-util")
local utf8 = require("utf8")
local watcher = require("debugplus-watcher")

local global = {}

local showTime = 5 -- Amount of time new console messages show up 
local fadeTime = 1 -- Amount of time it takes for a message to fade
local consoleOpen = false
local openNextFrame = false
local showNewLogs = true
local firstConsoleRender = nil
local logs = nil
local history = {}
local currentHistory = nil
local commands = nil
local controller = nil
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
        return cmd.name .. ":\n" .. cmd.desc .. "\n\nThis command can be run by typing '" .. cmd.name .. "'' or '" ..
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
        local success, res = pcall(func)
        if not success then
            return "Error: " .. res, "ERROR"
        end
        return util.stringifyTable(res)
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
    desc = "Watch and execute a file when it changes. Usage:\nwatch stop - Stop's watching files.\nwatch add [file] - Starts watching the file provided. File should be a relative path to something in the save directory (e.g. `Mods/Example/test.lua`)",
    exec = function(args, rawArgs, dp)
        local subCmd = args[1]
        local file = args[2]
        if subCmd == "stop" then
            watcher.stopWatching()
            return "I will stop watching for files."
        elseif subCmd == "add" then
            local succ, err = watcher.startWatching(file, dp.handleLog)
            if not succ then return err, "ERROR" end
            return "Started watching " .. file
        else
            return "Please choose whether you want to add or set. For more info, run 'help hand'"
        end
    end
}}
local inputText = ""
local old_print = print
local levelMeta = {
    DEBUG = {
        level = 'DEBUG',
        colour = {1, 0, 1}
    },
    INFO = {
        level = 'INFO',
        colour = {0, 1, 1}
    },
    WARN = {
        level = 'WARN',
        colour = {1, 1, 0}
    },
    ERROR = {
        level = 'ERROR',
        colour = {1, 0, 0}
    }
}
local SMODSLogPattern = "[%d-]+ [%d:]+ :: (%S+) +:: (%S+) :: (.*)"
local SMODSLevelMeta = {
    TRACE = levelMeta.DEBUG,
    DEBUG = levelMeta.DEBUG,
    INFO = levelMeta.INFO,
    WARN = levelMeta.WARN,
    ERROR = levelMeta.ERROR,
    FATAL = levelMeta.ERROR
}

local function handleLog(colour, _level, ...)
    old_print(...)
    local _str = ""
    for i, v in ipairs({...}) do
        _str = _str .. tostring(v) .. " "
    end
    local level, source, msg = string.match(_str, SMODSLogPattern)
    local meta;

    if not level then
        meta = {
            str = _str,
            time = love.timer.getTime(),
            colour = colour,
            level = _level
        }
    else
        local levelMeta = SMODSLevelMeta[level] or SMODSLevelMeta.INFO
        meta = {
            str = "[" .. source .. "] " .. msg,
            time = love.timer.getTime(),
            colour = levelMeta.colour,
            level = levelMeta.level
        }
    end
    -- Dirty hack to work better with multiline text
    if string.match(meta.str, "\n") then
        local first = true
        for w in string.gmatch(meta.str, "[^\n]+") do
            local meta = {
                str = w,
                time = love.timer.getTime(),
                colour = colour,
                level = _level,
                hack_no_prefix = not first
            }
            first = false
            table.insert(logs, meta)
            if logOffset ~= 0 then
                logOffset = math.min(logOffset + 1, #logs)
            end
            if #logs > 1000 then
                table.remove(logs, 1)
            end
        end
    else
        table.insert(logs, meta)
        if logOffset ~= 0 then
            logOffset = math.min(logOffset + 1, #logs)
        end
        if #logs > 1000 then
            table.remove(logs, 1)
        end
    end
end

local function log(...)
    handleLog({.65, .36, 1}, "INFO", "[DebugPlus]", ...)
end
global.log = log

local function runCommand()
    if inputText == "" then
        return
    end

    handleLog({1, 0, 1}, "INFO", "> " .. inputText)
    if history[1] ~= inputText then
        table.insert(history, 1, inputText)
    end

    local cmdName = string.lower(string.gsub(inputText, "^(%S+).*", "%1"))
    local rawArgs = string.gsub(inputText, "^%S+%s*(.*)", "%1")
    local args = {}
    for w in string.gmatch(rawArgs, "%S+") do
        table.insert(args, w)
    end

    inputText = ""
    consoleOpen = false

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
        return handleLog({1, 0, 0}, "ERROR", "< ERROR: Command '" .. cmdName .. "' not found.")
    end
    local dp = {
        test = "testing",
        hovered = G.CONTROLLER.hovering.target,
        handleLog = handleLog
    }
    local success, result, loglevel, colourOverride = pcall(cmd.exec, args, rawArgs, dp)
    if not success then
        return handleLog({1, 0, 0}, "ERROR", "< An error occured processing the command:", result)
    end
    local level = loglevel or "INFO" -- TODO: verify correctness
    local colour = colourOverride or levelMeta[level].colour
    if success and success ~= "" then
        return handleLog(colour, level, "<", result)
    else
        return handleLog(colour, level, "< Command exited without a response.")
    end
end

function global.consoleHandleKey(_controller, key)
    if not consoleOpen then
        if key == '/' then
            if util.isShiftDown() then
                showNewLogs = not showNewLogs
            else
                controller = _controller
                openNextFrame = true -- This is to prevent the keyboard handler from typing this key
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
        if util.isShiftDown() then
            inputText = inputText .. "\n"
        else
            runCommand()
        end
    end

    if key == "v" and util.isCtrlDown() then
        inputText = inputText .. love.system.getClipboardText()
    end

    if key == "up" then
        if currentHistory.index >= #history then
            return
        end
        if currentHistory.index == 0 then
            currentHistory.val = inputText
        end
        currentHistory.index = currentHistory.index + 1
        inputText = history[currentHistory.index]
    end

    if key == "down" then
        if currentHistory.index <= 0 then
            return
        end
        currentHistory.index = currentHistory.index - 1
        if currentHistory.index == 0 then
            inputText = currentHistory.val
        else
            inputText = history[currentHistory.index]
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

local orig_wheelmoved = love.wheelmoved
function love.wheelmoved(x, y)
    if orig_wheelmoved then
        orig_wheelmoved(x, y)
    end
    if not consoleOpen then
        return
    end
    logOffset = math.min(math.max(logOffset + y, 0), #logs - 1)
end

local function calcHeight(text, width)
    local font = love.graphics.getFont()
    local rw, lines = font:getWrap(text, width)
    local lineHeight = font:getHeight()

    return #lines * lineHeight, rw, lineHeight
end

function global.registerLogHandler()
    if logs then
        return
    end
    logs = {}
    print = function(...)
        handleLog({0, 1, 1}, "INFO", ...)
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
        local text = "> " .. inputText
        local lineHeight, realWidth, singleLineHeight = calcHeight(text, lineWidth)
        love.graphics.rectangle("fill", padding, bottom - lineHeight + padding, lineWidth, lineHeight + padding * 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(text, padding * 2, bottom - lineHeight + singleLineHeight, lineWidth - padding * 2)

        bottom = bottom - lineHeight - padding * 2
    end

    -- Main window
    if consoleOpen then
        love.graphics.setColor(0, 0, 0, .5)
        love.graphics.rectangle("fill", padding, padding, lineWidth, bottom)
    end
    for i = #logs, 1, -1 do
        local v = logs[i]
        if consoleOpen and #logs - logOffset < i then
            goto finishrender
        end
        if not consoleOpen and v.time < firstConsoleRender then
            break
        end
        local age = now - v.time
        if not consoleOpen and age > showTime + fadeTime then
            break
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

function global.createLogFn(name, level)
    return function(...)
        handleLog(levelMeta[level].colour, level, "[" .. name .. "]", ...)
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

return global
