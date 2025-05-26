local global = {}
local logs = nil
local old_print = print
local safeMode = false
local util = require("debugplus.util")
local levelMeta = {
    DEBUG = {
        level = 'DEBUG',
        colour = {1, 0, 1},
        shouldShow = false,
    },
    INFO = {
        level = 'INFO',
        colour = {0, 1, 1},
        shouldShow = true,
    },
    WARN = {
        level = 'WARN',
        colour = {1, 1, 0},
        shouldShow = true,
    },
    ERROR = {
        level = 'ERROR',
        colour = {1, 0, 0},
        shouldShow = true,
    }
}
global.levelMeta = levelMeta
local SMODSLogPattern = "[%d-]+ [%d:]+ :: (%S+) +:: ([%S ]-) :: (.*)"
local SMODSLevelMeta = {
    TRACE = levelMeta.DEBUG,
    DEBUG = levelMeta.DEBUG,
    INFO = levelMeta.INFO,
    WARN = levelMeta.WARN,
    ERROR = levelMeta.ERROR,
    FATAL = levelMeta.ERROR
}

function global.handleLogAdvanced(data, ...)
    local succ, config = pcall(require, "debugplus.config")
    local safe = safeMode or not succ
    local stringifyPrint = safe or config.getValue("stringifyPrint")
    if not stringifyPrint then
        old_print(...)
    end
    local _str = ""
    local stringify = tostring
    if safe or config.getValue("processTables") then
        stringify = util.stringifyTable
    end
    local args = util.pack(...)
    for i = 1, args.n do
        local v = args[i]
        _str = _str .. stringify(v) .. " "
    end
    if stringifyPrint then
        old_print(_str)
    end
    local meta = {
        str = _str,
        time = love.timer.getTime(),
        colour = data.colour,
        level = data.level,
        command = data.command,
    }
    if data.fromPrint then
        local level, source, msg = string.match(_str, SMODSLogPattern)
        if level then
            local levelMeta = SMODSLevelMeta[level] or SMODSLevelMeta.INFO
            meta = {
                str = "[" .. source .. "] " .. msg,
                time = love.timer.getTime(),
                colour = levelMeta.colour,
                level = levelMeta.level
            }
        else
            -- Handling the few times the game itself prints
            if _str:match("^LONG DT @ [%d.: ]+$") then -- LONG DT messages
                meta.level = "DEBUG"
                meta.colour = levelMeta.DEBUG.colour
            elseif _str:match("^ERROR LOADING GAME: Card area '[%w%d_-]+' not instantiated before load") then -- Error loading areas
                meta.level = "ERROR"
                meta.colour = levelMeta.ERROR.colour
            end
        end
    end
    if not meta.colour then meta.colour = levelMeta[meta.level].colour end

    -- HACK: Dirty hack to work better with multiline text
    if string.match(meta.str, "\n") then
        local first = true
        for w in string.gmatch(meta.str, "[^\n]+") do
            local _meta = {
                str = w,
                time = meta.time,
                colour = meta.colour,
                level = meta.level,
                command = meta.command,
                hack_no_prefix = not first
            }
            first = false
            table.insert(logs, _meta)
            -- TODO: fix me
            if logOffset ~= 0 then
                global.handleLogsChange(1)
            end
            if #logs > 5000 then
                table.remove(logs, 1)
            end
        end
    else
        table.insert(logs, meta)
        global.handleLogsChange(1)
        if logOffset ~= 0 then
            global.handleLogsChange(1)
        end
        if #logs > 5000 then
            table.remove(logs, 1)
        end
    end
end

function global.handleLog(colour, level, ...)
    global.handleLogAdvanced({
        colour = colour,
        level = level,
        command = true,
    }, ...)
end

function global.registerLogHandler()
    if logs then
        return
    end
    logs = {}
    global.logs = logs
	local succ, res = pcall(require, "debugplus.config")

	if not succ then
		safeMode = true
		print("DebugPlus could not load config!!! Not hooking logging")
		error(res)
	end
    print = function(...)
        global.handleLogAdvanced({
            colour = {0, 1, 1},
            level = "INFO",
            fromPrint = true,
        }, ...)
    end
end

function global.handleLogsChange() -- Placeholder. Overwritten in console.lua
end

function global.log(...)
    global.handleLog({.65, .36, 1}, "INFO", "[DebugPlus]", ...)
end

function global.error(...)
    global.handleLogAdvanced({
        colour = levelMeta.ERROR.colour,
        level = "ERROR",
    }, "[DebugPlus]", ...)
end

function global.warn(...)
    global.handleLogAdvanced({
        colour = levelMeta.WARN.colour,
        level = "WARN",
    }, "[DebugPlus]", ...)
end

function global.info(...)
    global.handleLogAdvanced({
        colour = levelMeta.INFO.colour,
        level = "INFO",
    }, "[DebugPlus]", ...)
end

function global.debug(...)
    global.handleLogAdvanced({
        colour = levelMeta.DEBUG.colour,
        level = "DEBUG",
    }, "[DebugPlus]", ...)
end

function global.createLogFn(name, level)
    return function(...)
        global.handleLogAdvanced({
            colour = levelMeta[level].colour,
            level = level,
        }, "[" .. name .. "]", ...)
    end
end

return global
