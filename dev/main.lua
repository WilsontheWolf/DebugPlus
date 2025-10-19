local logger = require "debugplus.logger"
logger.registerLogHandler()
local console = require "debugplus.console"
local ui = require "debugplus.ui"
local input = ui.TextInput.new(500)

function love.draw()
	love.graphics.clear({.25, .25, 1})
	love.graphics.setColor(1, 1, 1)
	input:draw(10, 10)
	console.doConsoleRender()
end

function love.keypressed(key)
	-- local handle = console.consoleHandleKey(key)
	-- if handle then
	-- 	input:keypressed(key)
	-- end
end

function love.textinput(t)
	input:textinput(t)
end

love.keyboard.setKeyRepeat(true)
-- console.consoleHandleKey("/") -- open console
