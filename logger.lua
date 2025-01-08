local global = {}
local logs = nil
local old_print = print
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
local SMODSLogPattern = "[%d-]+ [%d:]+ :: (%S+) +:: (%S+) :: (.*)"
local SMODSLevelMeta = {
    TRACE = levelMeta.DEBUG,
    DEBUG = levelMeta.DEBUG,
    INFO = levelMeta.INFO,
    WARN = levelMeta.WARN,
    ERROR = levelMeta.ERROR,
    FATAL = levelMeta.ERROR
}

function global.handleLogAdvanced(data, ...)
	local stringifyPrint = require("debugplus.config").getValue("stringifyPrint")
	if not stringifyPrint then
    	old_print(...)
	end
    local _str = ""
	local stringify = tostring
	if require("debugplus.config").getValue("processTables") then
		stringify = util.stringifyTable
	end
	for _, v in ipairs({...}) do
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
            elseif _str:match("^\n [+-]+ \n | #") and debug.getinfo(3).short_src == "engine/controller.lua" then -- Profiler results table. Extra check cause I don't trust this pattern to not have false positives
                meta.level = "DEBUG"
                meta.colour = levelMeta.DEBUG.colour
                meta.command = true
            end
        end
    end
    if not meta.colour then meta.colour = levelMeta[meta.level].colour end

    -- Dirty hack to work better with multiline text
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

function global.log(...)
    global.handleLogAdvanced({
        colour = {.65, .36, 1},
        level = "INFO",
    }, "[DebugPlus]",  ...)
end

function global.logCmd(...)
    global.handleLog({.65, .36, 1}, "INFO", "[DebugPlus]", ...)
end


function global.errorLog(...)
    global.handleLogAdvanced({
        colour = {1, 0, 0},
        level = "ERROR",
    }, "[DebugPlus]", ...)
end

function global.registerLogHandler()
    if logs then
        return
    end
    logs = {}
    global.logs = logs
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


-- config.configDefinition.logLevel.onUpdate = function(v)
--     for k, v in pairs(levelMeta) do
--         v.shouldShow = false
--     end
    
--     levelMeta.ERROR.shouldShow = true
--     if v == "ERROR" then return end
--     levelMeta.WARN.shouldShow = true
--     if v == "WARN" then return end
--     levelMeta.INFO.shouldShow = true
--     if v == "INFO" then return end
--     levelMeta.DEBUG.shouldShow = true
-- end

-- config.configDefinition.logLevel.onUpdate(config.getValue("logLevel"))

return global
