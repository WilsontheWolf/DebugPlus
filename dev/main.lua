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

