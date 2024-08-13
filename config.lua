if string.match(debug.getinfo(function()end).source, '=%[SMODS %w+ ".+"]') then
    error("Please update your steamodded thanks")
end

local configDefinition = {
    debugMode = {
        label = "Debug Mode",
        type = "toggle",
        default = true,
        info = {"Toggles everything in DebugPlus except the console"},
    },
    ctrlKeybinds = {
        label = "CTRL for Keybinds",
        type = "toggle",
        default = true,
        info =  {"Requires you hold ctrl when pressing the built in keybinds"},
    }
}

local function getDefaultsObject() 
    local config = {}
    for k, v in pairs(configDefinition) do
        config[k] = v.default
    end
    return config
end

local function loadSaveFromFile()
    local content = love.filesystem.read("config/DebugPlus.jkr")
    if not content then return {} end
    local success, res = pcall(STR_UNPACK(content))
    if success and type(res) == "table" then
        return res
    end
    return {}
end


return function()
    print(require('debugplus-util').stringifyTable(getDefaultsObject()))
end
