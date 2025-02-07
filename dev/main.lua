local logger = require "debugplus.logger"
logger.registerLogHandler()
local console = require "debugplus.console"

function love.draw()
	love.graphics.clear({.25, .25, 1})
	console.doConsoleRender()
end

function love.keypressed(key)
	console.consoleHandleKey(key)
end


local font = love.graphics.getFont()

local c1 = {1, 1, 1, 1}
local c2 = {1, 1, 1, 0}

print(font:getWrap({ c1, "testing 123\nhi mom", c2, "_", c1, "testing mom mom mom mom"}, 40))

console.consoleHandleKey("/") -- open console
