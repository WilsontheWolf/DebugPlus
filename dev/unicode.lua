local utf8 = require "utf8"
local M = {}

local Unicode = {}
M.Unicode = Unicode
Unicode.__index = Unicode

local function toCodes(str)
	-- TODO: Is this loop nessicary?
	local obj = {}
	for _, c in utf8.codes(str) do
		table.insert(obj, c)
	end
	return obj
end
M.toCodes = toCodes

local function getStartPos(pos, len)
	if pos > 0 then return pos end
	if pos == 0 then return 1 end
	if pos < -len then return 1 end
	return len + pos + 1
end

local function getEndPos(pos, len)
	if pos > len then return len end
	if pos >= 0 then return pos end
	if pos < -len then return 0 end
	return len + pos + 1
end

local nonWords = toCodes(" \t\n-_<>(){}[]:;/\\.!?|")

local nonWordLookup = {}

for _, v in ipairs(nonWords) do
	nonWordLookup[v] = true
end

function Unicode.new(inital)
	local self = Unicode._new()
	if inital then self.codes = toCodes(inital)
	else self.codes = {} end
	return self
end

function Unicode.fromCodes(codes)
	local self = Unicode._new()
	local newCodes = {}
	for _, c in ipairs(codes) do
		table.insert(newCodes, c)
	end
	self.codes = newCodes
	return self
end

function Unicode._new()
	local self = setmetatable({}, Unicode)
	return self
end

function Unicode:toString()
	return utf8.char(unpack(self.codes))
end

Unicode.__tostring = Unicode.toString

function Unicode:sub(i, j)
	assert(type(i) == "number", "Unicode:sub: i must be a number")
	j = j or -1
	assert(type(j) == "number", "Unicode:sub: j must be a number")

	local new = Unicode.new()
	local codes = self.codes
	local newCodes = new.codes

	local len = #self.codes

	i = getStartPos(i, len)
	j = getEndPos(j, len)

	if i > j then return new end

	for count = i, j do
		table.insert(newCodes, codes[count])
	end

	return new
end

function Unicode:is()
	local mt = getmetatable(self)
	return Unicode == mt
end

function Unicode.__concat(op1, op2)
	local is = Unicode.is
	if not is(op1) then op1 = Unicode.new(tostring(op1)) end
	if not is(op2) then op2 = Unicode.new(tostring(op2)) end

	local new = Unicode.fromCodes(op1.codes)
	local newCodes = new.codes

	for _, c in ipairs(op2.codes) do
		table.insert(newCodes, c)
	end
	return new
end

function Unicode:__len()
	return #self.codes
end

function Unicode:backspace()
	local code = table.remove(self.codes)
	if not code then return nil end
	return utf8.char(code)
end

function Unicode:del()
	local code = table.remove(self.codes, 1)
	if not code then return nil end
	return utf8.char(code)
end

function Unicode:append(chars)
	local codes = self.codes
	for _, c in utf8.codes(chars) do
		table.insert(codes, c)
	end
end

function Unicode:prepend(chars)
	local codes = self.codes
	local i = 1
	for _, c in utf8.codes(chars) do
		table.insert(codes, i, c)
		i = i + 1
	end
end

function Unicode:backspaceWord()
	local res = {}
	local codes = self.codes
	local firstPart = true

	local count = #codes

	while true do
		if count == 0 then
			return utf8.char(unpack(res))
		end
		local code = codes[count]
		if firstPart then
			if not nonWordLookup[code] then
				firstPart = false
			end
		elseif nonWordLookup[code] then
			return utf8.char(unpack(res))
		end
		table.remove(codes)
		count = count - 1
		table.insert(res, 1, code)
	end
end

function Unicode:delWord()
	local res = {}
	local codes = self.codes
	local firstPart = true

	local count = #codes

	while true do
		if count == 0 then
			return utf8.char(unpack(res))
		end
		local code = codes[1]
		if firstPart then
			if not nonWordLookup[code] then
				firstPart = false
			end
		elseif nonWordLookup[code] then
			return utf8.char(unpack(res))
		end
		table.remove(codes, 1)
		count = count - 1
		table.insert(res, code)
	end
end

M.new = Unicode.new

return M
