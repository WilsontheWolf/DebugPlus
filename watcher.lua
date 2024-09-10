local hash
local global = {}
local event
local file
local running = false
local log
local type

local function loadFile()
    local content = love.filesystem.read(file)
    local newHash = love.data.hash("md5", content)
    local showReloaded = hash ~= nil
    if newHash == hash then
        return
    end
    hash = newHash
    local fn, err = load(content, file)
    if not fn then
        return log({1, 0, 0}, "ERROR", "[Watcher] Error Loading File:", err)
    end
    local succ, err = pcall(fn)
    if not succ then
        return log({1, 0, 0}, "ERROR", "[Watcher] Error Running FIle:", err)
    end
    if showReloaded then
        log({0, 1, 0}, "INFO", "[Watcher] Reloaded")
    end
    return true
end

local function makeEvent()
    event = Event {
        blockable = false,
        pause_force = true,
        no_delete = true,
        trigger = "after",
        delay = .5,
        func = function()
            if not running then
                return true
            end
            loadFile()
            event.start_timer = false
        end
    }
end

function global.startWatching(_file, _log, _type)
    if not _file then
        return nil, "No file"
    end
    local info = love.filesystem.getInfo(_file)
    if not info then
        return nil, "File doesn't exist"
    end
    if not (info.type == "file") then
        return nil, "Not a regular file"
    end
    if not event then makeEvent() end
    log = _log
    hash = nil
    file = _file
    type = _type
    if not running then
        running = true
        loadFile()
        G.E_MANAGER:add_event(event)
    end
    return true
end

function global.stopWatching()
    running = false
end

return global
