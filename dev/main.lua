local logger = require "debugplus.logger"
logger.registerLogHandler()
local console = require "debugplus.console"

local text

function love.draw()
	love.graphics.clear({.25, .25, 1})
	if text then
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(text, 10, 10)
	end
	console.doConsoleRender()
end

function love.keypressed(key)
	console.consoleHandleKey(key)
end


local function renderInBox(lines, wrapLimit)

local font = love.graphics.getFont()

local c1 = {1, 1, 0, 1}

local ct = {}

for _,v in ipairs(lines) do
	if type(v) == "string" then
		table.insert(ct, c1)
		table.insert(ct, v)
	else
		table.insert(ct, v.colour)
		table.insert(ct, v.text)
	end
end

print(ct)
text = love.graphics.newText(font)
text:setf(ct, wrapLimit, "left")

print(text:getDimensions()) -- width, height
print(font:getWrap(ct, wrapLimit)) -- width, table of elements
print(font:getHeight()) -- height (times by number of elements to get full height)

end

renderInBox({"testing123\nhi mom", {colour = {1,0,1,1}, text = "_"}, "testing\n" ..(" mom"):rep(100),}, 100)


console.consoleHandleKey("/") -- open console
