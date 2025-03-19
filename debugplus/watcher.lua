local logger = require("debugplus.logger")
local modtime
local global = {}
local event
local file
local running = false
local currentType
-- For edition type
local editionIndex

local function genSafeFunc(name, fn)
    return function(...)
        if not fn or type(fn) ~= "function" then
            return
        end
        local res = {pcall(fn, ...)}
        local succ = table.remove(res, 1)
        if not succ then
            logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Center function \"" .. name .. "\" errored:", unpack(res))
            return
        end
        return unpack(res)
    end
end


local function evalLuaFile(content)
    local fn, err = load(content, "@" .. file)

    if not fn then
        logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Error Loading File:", err)
        return false
    end
    local succ, err = pcall(fn)
    if not succ then
        logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Error Running File:", err)
        return false
    end
    return true, err
end

local function showTabOverlay(definition, tabName)
    tabName = tabName or "Tab"
    return G.FUNCS.overlay_menu({
        definition = create_UIBox_generic_options({
            contents = {{
                n = G.UIT.R,
                nodes = {create_tabs({
                    snap_to_nav = true,
                    colour = G.C.BOOSTER,
                    tabs = {{
                        label = tabName,
                        chosen = true,
                        tab_definition_function = function()
                            return definition
                        end
                    }}
                })}
            }}
        })
    })

end

local types = {
    lua = {
        desc = "Starts watching the lua file provided.",
        run = function(content)
            return evalLuaFile(content)
        end,
    },
    config_tab = {
        desc = "Starts watching the lua file provided. The returned value is rendered like a config tab (such as the one in SMODS.current_mod.config_tab). Note that invalid tabs will likely crash the game.",
        run = function(content)
            local success, res = evalLuaFile(content)
            if not success then return false end
            if type(res) ~= "table" or next(res) == nil then
                logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Config tab doesn't look valid. Not rendering to prevent a crash. Make sure you're returning something.")
                return
            end
            showTabOverlay(res)
        end,
    },
    shader = {
        desc = "Starts watching the the shader file provided. Pops up a ui with a joker to preview the shader on.",
        check = function()
            if SMODS and SMODS.Shaders and SMODS.Edition then
                return true
            end
            return false, "Steamodded (v1.0.0~+) is necessary to watch shader files."
        end,
        run = function(content)
            local result, shader = pcall(love.graphics.newShader, content)
            if not result then
                return logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Error Loading Shader:", shader)
            end
            local name = content:match("extern [%w_]+ vec2 (%w+);");
            if not name then
                return logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Could not guess name of shader :/. Not applying to avoid crash.")
            end

            G.SHADERS.debugplus_watcher_shader = shader
            SMODS.Shaders.debugplus_watcher_shader = {
                original_key = name
            }
            if not editionIndex then
                editionIndex = #G.P_CENTER_POOLS.Edition + 1
            end
            G.P_CENTER_POOLS.Edition[editionIndex] = {
                key = "e_debugplus_watcher_edition",
                shader = "debugplus_watcher_shader"
            }

            -- Make an area with a joker with our editon
            local area = CardArea(
                G.ROOM.T.x + 0.2*G.ROOM.T.w/2,G.ROOM.T.h,
                G.CARD_W,
                G.CARD_H,
                {card_limit = 5, type = 'title', highlight_limit = 0, deck_height = 0.75, thin_draw = 1}
            )
                local card = Card(area.T.x + area.T.w/2, area.T.y, G.CARD_W, G.CARD_H,
                nil, G.P_CENTERS["j_joker"])
                card.edition = {debugplus_watcher_edition = true}
                area:emplace(card)

            showTabOverlay({
                -- ROOT NODE
                n = G.UIT.ROOT,
                config = {
                    r = 0.1,
                    minw = 7,
                    minh = 5,
                    align = "tm",
                    padding = 1,
                    colour = G.C.BLACK
                },
                nodes = {{
                    n = G.UIT.R,
                    config = {
                        align = "cm",
                        padding = 0.07,
                        no_fill = true,
                        scale = 1
                    },
                    nodes = {{
                        n = G.UIT.O,
                        config = {
                            object = area
                        }
                    }}
                }}
            }, "Shader Test")

            return true
        end,
        cleanup = function()
            table.remove(G.P_CENTER_POOLS.Edition, editionIndex)
            G.SHADERS.debugplus_watcher_shader = nil
            SMODS.Shaders.debugplus_watcher_shader = nil
        end
    },
    center = {
        desc = "Starts watching the lua file provided. The returned table is used to modify the center given in the key value. The table is similar to SMODS.Joker and friends.",
        check = function() -- Not entirely sure what to all check for here.
            if SMODS and SMODS.Joker then
                return true
            end
            return false, "Steamodded (v1.0.0~+) is necessary to watch centers."
        end,
        run = function(content)
            local success, res = evalLuaFile(content)
            if not success then return false end
            if not res or type(res) ~= "table" then
                logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Center config doesn't look correct. Make sure you are returning an object.")
                return
            end
            if not res.key then
                logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Center config is missing a key.")
                return
            end
            local center = G.P_CENTERS[res.key]
            if not center then
                logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] The key \"" .. res.key .. "\" does not exist. Make sure your object has been loaded and the key is correct (don't forget the object prefix (e.g. j_) and your mod prefix) you can get the key by hovering over your object and then running `eval dp.hovered.config.center.key`.")
                return
            end
            if res.loc_txt then
                local loc_txt = res.loc_txt
                local loc = G.localization.descriptions[center.set][res.key]
                local loc_changed = false

                if loc_txt.name then
                    if loc_txt.name ~= loc.name then
                        loc_changed = true
                        loc.name = loc_txt.name
                    end
                end

                if loc_txt.text then
                    if #loc_txt.text ~= #loc.text then
                        loc_changed = true
                    else
                        for k, v in ipairs(loc_txt.text) do
                            if v ~= loc.text[k] then
                                loc_changed = true
                                break
                            end
                        end
                    end
                    loc.text = loc_txt.text
                end

                if loc_changed then
                    init_localization()
                end
            end

			if res.pos then
				center.pos.x = res.pos.x
				center.pos.y = res.pos.y
			end

            for k,v in pairs(res) do
				if type(v) ~= "function" then
					goto finishfunc
				end
				center[k] = genSafeFunc(k, v)
                ::finishfunc::
            end
            return true
        end,
    }
}

local function loadFile()
    local info = love.filesystem.getInfo(file) or {}
    local showReloaded = modtime ~= nil
    if info.modtime == modtime then
        return
    end
    modtime = info.modtime
	local content = love.filesystem.read(file)
    local result, subResult = pcall(currentType.run, content)
    if not result then
        return logger.handleLog({1, 0, 0}, "ERROR", "[Watcher] Error Running Watcher:", subResult)
    end
    if showReloaded and subResult then
        logger.handleLog({0, 1, 0}, "INFO", "[Watcher] Reloaded")
    end
    return true
end

local function makeEvent()
    event = Event {
        blockable = false,
        blocking = false,
        pause_force = true,
        no_delete = true,
        trigger = "after",
        delay = .5,
        timer = "UPTIME",
        func = function()
            if not running then
                return true
            end
            loadFile()
            event.start_timer = false
        end
    }
end

local function correctFile(file) -- Fixes issues with slashes
    return file:gsub("^%.?[\\/]", ""):gsub("\\", "/")
end

function global.startWatching(_file, _type)
    if not _file then
        return nil, "No file"
    end
    local info = love.filesystem.getInfo(_file)
    if not info then
        _file = correctFile(_file)
        info = love.filesystem.getInfo(_file)
        if not info then
            return nil, "File doesn't exist"
        end
    end
    if not (info.type == "file") then
        return nil, "Not a regular file"
    end
    if not event then makeEvent() end
    if running and currentType and currentType.cleanup and type(currentType.cleanup) == "function" then
        currentType.cleanup()
    end
    modtime = nil
    file = _file
    currentType = types[_type]
    if not currentType then
        return nil, "Shit's erroring (no type)"
    end
    if currentType.check and type(currentType.check) == "function" then
        local res, msg = currentType.check();
        if not res then
            return nil, msg or "Pre-check failed!"
        end
    end
    if not running then
        running = true
        loadFile()
        G.E_MANAGER:add_event(event)
    end
    return true
end

function global.stopWatching()
    running = false
    if currentType.cleanup and type(currentType.cleanup) == "function" then
        currentType.cleanup()
    end
end

global.types = types;

global.subCommandDesc = ""

for k,v in pairs(types) do
    global.subCommandDesc = global.subCommandDesc .. "watch " .. k .. " [file] - " .. (v.desc or "Wilson forgot to make a description for me.") .. "\n"
end

return global
