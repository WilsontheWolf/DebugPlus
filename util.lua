local global = {}

function global.stringifyTable(tab, depth, indent)
    if not indent then
        indent = ""
    end 
    if not depth then
        depth = 2
    end
    if depth == 0 then
        return tostring(tab)
    end
    if type(tab) ~= "table" then
        return tostring(tab)
    end
    local res = "Table:\n"
    for k, v in pairs(tab) do
        res = res .. indent .. k .. ": " .. global.stringifyTable(v, depth - 1, indent .. "  ") .. "\n"
    end
    return res
end

function global.hasValue(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function global.isShiftDown() 
    return love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')
end

function global.isCtrlDown()
    return love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
end

return global