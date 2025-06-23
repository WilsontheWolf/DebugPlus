local global = {}
local isMac = love.system.getOS() == 'OS X'
global.ctrlText = isMac and "CMD" or "CTRL"

function global.stringifyTable(tab, depth, num, dec, indent)
    if not indent then
        indent = ""
    end
    if not depth then
        depth = 4
    end
	if not num then
		num = math.huge
	end
	if not dec then
		dec = 3
	end
    if depth == 0 or num <= 0 then
        return tostring(tab)
    end
    if type(tab) ~= "table" then
        return tostring(tab)
    end
	if (getmetatable(tab) or {}).__tostring then -- For tables with custom tostring values (such as a talisman number)
		return tostring(tab)
	end
    local res = "Table:\n"
	local count = 0
    for k, v in pairs(tab) do
		count = count + 1
		if count < num + 1 then
			res = res .. indent .. tostring(k) .. ": " .. global.stringifyTable(v, depth - 1, math.max(1, (num == math.huge and 10 or num) - dec), dec, indent .. "  ") .. "\n"
		end
    end
	if count > num then
		local c = count - num
		res = res .. indent .. "+" .. tostring(c) .. " more value" .. (c == 1 and "" or "s") .. ".\n"
	end
    return res
end

function global.hasValue(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return index
        end
    end

    return false
end

function global.isShiftDown()
    return love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')
end

if isMac then
    function global.isCtrlDown()
        return love.keyboard.isDown('lgui') or love.keyboard.isDown('rgui') or love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
    end
else
    function global.isCtrlDown()
        return love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
    end
end

function global.trim(string)
    return string:match("^%s*(.-)%s*$")
end

function global.split(str, sep)
    if not sep then
        sep = ","
    end
    local pattern = "([^"..sep.."]+)"
    if sep == "" then
        pattern = "."
    end
    local t = {}
    for str in string.gmatch(str, pattern) do
        table.insert(t, str)
    end
    return t
end

function global.pack(...) -- TODO: Might be nice to make a version of ipairs that uses this
    return { n = select("#", ...), ... }
end

function global.unescapeSimple(str)
    local r = str:gsub("\\(.?)", {
	["\\"] = "\\",
	n = "\n",
	r = "\r"
    })
    return r
end

function global.escapeSimple(str)
    return str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r")
end

return global
