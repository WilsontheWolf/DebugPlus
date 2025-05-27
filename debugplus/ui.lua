local util = require "debugplus.util"
local Unicode = require "debugplus.unicode"

local M = {}

local TextInput = {}
TextInput.__index = TextInput
M.TextInput = TextInput

function TextInput.new(width, font)
	assert(type(width) == "number", "Width must be a number")
	font = font or love.graphics.getFont()
	local self = setmetatable({}, TextInput)
	self.font = font
	self.input1 = Unicode.new()
	self.input2 = Unicode.new()
	self.lineHeight = font:getHeight()
	self.text = love.graphics.newText(font)
	self.cursorPos = { x = -1, y = -1}
	self.width = width
	self.dirty = true

	return self
end

function TextInput:process()
	local font = self.font
	local _, wrap = font:getWrap(self.input1:toString(), self.width)

	local lastLine = table.remove(wrap)

	self.cursorPos.x = font:getWidth(lastLine)
	self.cursorPos.y = self.lineHeight * (#wrap)

	local _, wrap2 = font:getWrap(lastLine .. self.input2:toString(), self.width)

	local toPrint = ""
	for _, v in ipairs(wrap) do
		toPrint = toPrint .. v .. "\n"
	end
	for _, v in ipairs(wrap2) do
		toPrint = toPrint .. v .. "\n"
	end

	self.text:set(toPrint)
	self.cursorTime = love.timer.getTime() -- Ensures cursor is always rendered when user makes input
	self.dirty = false
end

function TextInput:textinput(t)
	self.input1:append(t)
	self.dirty = true
end

function TextInput:keypressed(key)
	local input1 = self.input1
	local input2 = self.input2
	if key == "backspace" then
		if util.isCtrlDown() then
			input1:backspaceWord()
		else
			input1:backspace()
		end
		self.dirty = true
	elseif key == "delete" then
		if util.isCtrlDown() then
			input2:delWord()
		else
			input2:del()
		end
		self.dirty = true
	elseif key == "left" then
		local toMove
		if util.isCtrlDown() then
			toMove = input1:backspaceWord()
		else
			toMove = input1:backspace()
		end
		if toMove then
			input2:prepend(toMove)
			self.dirty = true
		end
	elseif key == "right" then
		local toMove
		if util.isCtrlDown() then
			toMove = input2:delWord()
		else
			toMove = input2:del()
		end
		if toMove then
			input1:append(toMove)
			self.dirty = true
		end
	end
end

function TextInput:setWidth(width)
	if width == self.width then return end
	self.width = width
	self.dirty = true
end

function TextInput:getHeight()
	if self.dirty then
		self:process()
	end
	return self.text:getHeight()
end

function TextInput:clear()
	self.input1 = Unicode.new()
	self.input2 = Unicode.new()
	self.dirty = true
end

function TextInput:set(str)
	self.input1 = Unicode.new(str)
	self.input2 = Unicode.new()
	self.dirty = true
end

function TextInput:draw(x, y)
	if self.dirty then
		self:process()
	end
	love.graphics.draw(self.text, x, y)
	if math.floor((love.timer.getTime() - self.cursorTime) * 2) % 2 == 0 then -- Cursor Blink
		local cursor = self.cursorPos
		local width = 1
		local height = self.lineHeight
		love.graphics.rectangle("fill", cursor.x + x, cursor.y + y, width, height)
	end
end

function TextInput:toString()
	return self.input1:toString() .. self.input2:toString()
end

return M
