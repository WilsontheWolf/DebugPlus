local global = {}
local resolvedGameFonts = false
local cachedFont = nil
local cachedFontPx = nil
local cachedFontId = nil
local outdatedFonts = true

local header = ">I4I2I2I2I2"
local tab = ">c4I4I4I4"
local head = ">I2I2I4I4I4I2I2"
local hhea = ">I2I2i2i2i2"

local function parseHead(str, offset, data)
    local major, minor, fontRevision, checksumAdjustment, magic, flags, unitsPerEm = love.data.unpack(head, str, offset + 1)
    assert(major == 1, "Invalid major version in head table (" .. major .. ")")
    assert(minor == 0, "Invalid minor version in head table (" .. minor .. ")")
    assert(magic == 0x5F0F3CF5, "Invalid magic in head table (" .. magic .. ")")
    assert(unitsPerEm > 16 and unitsPerEm < 16384, "Invalid unitsPerEm in head table (" .. unitsPerEm .. ", must be >16 <16384)")
    data.unitsPerEm = unitsPerEm
end

local function parseHhea(str, offset, data)
    local major, minor, accent, decent, lineGap = love.data.unpack(hhea, str, offset + 1)
    assert(major == 1, "Invalid major version in hhea table (" .. major .. ")")
    assert(minor == 0, "Invalid minor version in hhea table (" .. minor .. ")")
    data.accent = accent
    data.decent = decent
    data.lineGap = lineGap
end

local function extractSizing(file)
    local data = file
    if type(file) == "string" then
        data = assert(love.filesystem.read("data",file))
    end
    local desired = {
        head = parseHead,
        hhea = parseHhea,
    }
    local out = {}

    local str = data:getString()
    local sfntVersion, numTables, searchRange, entrySelector, rangeShift, offset = love.data.unpack(header, str)
    assert(sfntVersion == 0x00010000 or sfntVersion == 0x4F54544F, "Font had invalid sfntVersion (" .. sfntVersion .. ")")
    for n = 0,numTables do
        local tag, checksum, tabOffset, len, off = love.data.unpack(tab, str, offset)
        offset = off
        if desired[tag] then
            desired[tag](str, tabOffset, out)
            desired[tag] = nil
            if not next(desired) then
                break
            end
        end
    end
    out.ratio = out.unitsPerEm/(out.accent - out.decent + out.lineGap)
    return out
end
global.extractSizing = extractSizing

local fonts = {
    love = {
        name = "Vera Sans",
        newFont = function(self, px)
            return love.graphics.newFont(px)
        end,
        fallback = false,
    }
}

local balatroExpected = {
    ["resources/fonts/m6x11plus.ttf"] = "m6x11 plus",
    ["resources/fonts/GoNotoCurrent-Bold.ttf"] = "Go Noto Current Bold",
    ["resources/fonts/NotoSansKR-Bold.ttf"] = "Noto Sans KR Bold",
}
local balatroFallback = {
    ["GoNotoCurrent-Bold"] = 0.73421439060206,
    ["NotoSansKR-Bold"] = 0.69060773480663,
}

local function resolveFonts()
    if not G or not G.FONTS then return end
    local changed = false
    for _, f in ipairs(G.FONTS) do
        local file = f.file
        if balatroExpected[file] then
            changed = true
            local id = file:match("([^/]+)%.%w+")
            local name = balatroExpected[file]
            local ratio = balatroFallback[id]
            fonts["game_" .. id] = {
                name = name,
                fallback = ratio and 10 or false,
                ratio = ratio,
                newFont = function(self, px)
                    return love.graphics.newFont(file, px)
                end,
            }
        end
    end
    resolvedGameFonts = true
    if changed then
        outdatedFonts = true
    end
end

local function resolveFallbacks(id)
    local fallbacks = {}
    for k,v in pairs(fonts) do
        if k == id then goto continue end
        if not v.fallback then goto continue end
        table.insert(fallbacks, v)
        ::continue::
    end
    table.sort(fallbacks, function(a,b)
        return a.fallback < b.fallback
    end)
    return fallbacks
end

local function makeFont(key, px)
    local data = fonts[key]
    local fallbacks = resolveFallbacks(key)
    local font = data:newFont(px)
    if fallbacks[1] then
        local fbs = {}
        for _,v in ipairs(fallbacks) do
            local size = math.floor(font:getHeight() * v.ratio + 0.5)
            table.insert(fbs, v:newFont(size))
        end
        font:setFallbacks(unpack(fbs))
    end
    return font
end

local defaults = {
    "game_mx6x11plus",
    "game_GoNotoCurrent-Bold",
    "love",
}
local function resolveID(id)
    if fonts[id] then
        return id
    end
    for _, v in ipairs(defaults) do
        if fonts[v] then
            return v
        end
    end
    error("Could not resolve a font!")
end

-- TODO: Resolve this
local desired = "game_m6x11plus"
local desiredPx = 20
local function getFont()
    if not resolvedGameFonts then
        resolveFonts()
    end
    if outdatedFonts then
        cachedFont = nil
        cachedFontPx = nil
        cachedFontId = nil
        outdatedFonts = false
    end
    if cachedFontId == desired and cachedFontPx == desiredPx then
        return cachedFont
    end
    local id = resolveID(desired)
    if cachedFontId == id and cachedFontPx == desiredPx then
        return cachedFont
    end

    local font = makeFont(id, desiredPx)
    cachedFont = font
    cachedFontPx = desiredPx
    cachedFontId = id
    return font
end
global.getFont = getFont


return global
