local logger = require "debugplus.logger"
logger.registerLogHandler()
local console = require "debugplus.console"
local utf8 = require("utf8")

local text
local textInput = {"",""}


local function processInput()
	print(textInput[1] .. "_" .. textInput[2])
end

function love.draw()
	love.graphics.clear({.25, .25, 1})
	if text then
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(text, 10, 10)
	end
	console.doConsoleRender()
end

function love.keypressed(key)
	local handle = console.consoleHandleKey(key)
	if handle then
		print(key)
		if key == "backspace" then
			local byteoffset = utf8.offset(textInput[1], -1)

			if byteoffset then
				textInput[1] = string.sub(textInput[1], 1, byteoffset - 1)
				processInput()
			end
		elseif key == "delete" then
			local byteoffset = utf8.offset(textInput[2], 1)

			if byteoffset then
				textInput[2] = string.sub(textInput[2], byteoffset + 1)
				processInput()
			end
		elseif key == "left" then
			local byteoffset = utf8.offset(textInput[1], -1)

			if byteoffset then
				local toMove = string.sub(textInput[1], byteoffset)
				textInput[1] = string.sub(textInput[1], 1, byteoffset - 1)
				textInput[2] = toMove .. textInput[2]
				processInput()
			end
		elseif key == "right" then
			local byteoffset = utf8.offset(textInput[2], 1)

			if byteoffset then
				local toMove = string.sub(textInput[2], byteoffset, 1)
				textInput[2] = string.sub(textInput[2], byteoffset + 1)
				textInput[1] = textInput[1] .. toMove
				processInput()
			end
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
text = love.graphics.newText(font)
text:setf(ct, wrapLimit, "left")

print(text:getDimensions()) -- width, height
print(font:getWrap(ct, wrapLimit)) -- width, table of elements
print(font:getHeight()) -- height (times by number of elements to get full height)

end

renderInBox({"testing123\nhi mom", {colour = {1,0,1,1}, text = "_"}, "testing\n" ..(" mom"):rep(100),}, 100)





console.consoleHandleKey("/") -- open console
