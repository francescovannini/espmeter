--[[

	espmeter monitors home gas consumption by counting the rotations of
	the last digit of a gas meter; gas meter must have a magnet on one of
	the digits.

	See README.md in the repo root for details

]] --

local function compile_lua()
	local file = require("file")
	local node = require("node")
	local l = file.list("%.lua$")
	for k, _ in pairs(l) do
		if k ~= "init.lua" then
			print("Compiling " .. k)
			node.compile(k)
			print("Removing " .. k)
			file.remove(k)
		end
	end
	node = nil
	file = nil
end

local _, extendedbr = require("node").bootreason()
local t = 1
if extendedbr == 0 then
	t = 5000
end

local tmr = require("tmr")
tmr.create():alarm(
	t,
	tmr.ALARM_SINGLE,
	function()
		tmr = nil
		compile_lua()
		local espmeter = require("espmeter")
		espmeter()
	end
)
