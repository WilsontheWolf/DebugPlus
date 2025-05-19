local logger = require "debugplus.logger"
logger.registerLogHandler()
local console = require "debugplus.console"
local Unicode = require "dev.unicode".Unicode

local text
local textInput = {Unicode.new(), Unicode.new()}
local cursorPos = {0,0,0}

local function processInput()
	print(textInput[1]:toString() .. "_" .. textInput[2]:toString())
end

function love.draw()
	love.graphics.clear({.25, .25, 1})
	if text then
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(text, 10, 10)
		-- cursor test
		love.graphics.rectangle("fill", cursorPos[1], cursorPos[2], 1, cursorPos[3])
	end
	console.doConsoleRender()
end

function love.keypressed(key)
	local handle = console.consoleHandleKey(key)
	if handle then
		-- print(key)
		if key == "backspace" then
			textInput[1] = textInput[1]:sub(1, -2)
			processInput()
		elseif key == "delete" then
			textInput[2] = textInput[2]:sub(2)
			processInput()
		elseif key == "left" then
			local toMove = textInput[1]:sub(-1)
			textInput[1] = textInput[1]:sub(1, -2)
			textInput[2] = toMove .. textInput[2]
			processInput()
		elseif key == "right" then
			local toMove = textInput[2]:sub(1, 1)
			textInput[2] = textInput[2]:sub(2)
			textInput[1] = textInput[1] .. toMove
			processInput()
		end
	end
end

function love.textinput(t)
	textInput[1] = textInput[1] .. t
	processInput()
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
	if not text then
		text = love.graphics.newText(font)
	else
		text:clear()
	end
	text:setf(ct, wrapLimit, "left")

	print(text:getDimensions(1)) -- width, height
	print(font:getWrap(ct, wrapLimit)) -- width, table of elements
	print(font:getHeight()) -- height (times by number of elements to get full height)

end

renderInBox({"testing123\nhi mom", {colour = {1,0,1,1}, text = "_"}, "testing\n" ..(" mom"):rep(100),}, 100)

function processInput() -- Note: reimplemntation
	if true then
		renderInBox({textInput[1]:toString(), --[[{colour = {1,0,1,1}, text = "_"},]] textInput[2]:toString()}, 100)
		local font = love.graphics.getFont()

		local width, elements = font:getWrap(textInput[1]:toString(), 100)
		local lineHeight = font:getHeight()

		print(width, elements)

		cursorPos[1] = width + 10 -- x pos (naive approch)
		cursorPos[2] = lineHeight * (#elements - 1) + 10-- y pos
		cursorPos[3] = lineHeight -- Height
	else
		local wrapLimit = 100

		local font = love.graphics.getFont()

		local c1 = {1, 1, 0, 1}

		if not text then
			text = love.graphics.newText(font)
		else
			text:clear()
		end

		text:addf(textInput[1], wrapLimit, "left", 0, 0)
		text:addf(textInput[2], wrapLimit, "left", 0, 0)

		print(text:getDimensions()) -- width, height
		-- print(font:getWrap(ct, wrapLimit)) -- width, table of elements
		-- print(font:getHeight()) -- height (times by number of elements to get full height)
	end
end



console.consoleHandleKey("/") -- open console

print(Unicode.new("Hello mom. Here is an emoji (😊)"))
