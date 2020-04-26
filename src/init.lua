--[[

	GasCounter monitors home gas consumption by counting the rotations of
	the last digit of a gas meter; gas meter must have a magnet on one of
	the digits.

	Pulses are captured by a Hall effect sensor managed by an ATTiny13
	which stores 3 hours of pulse counting in memory. The ESP takes care
	of dumping data from the Tiny13 into its RTC memory and then sending
	it to the server via HTTP.

	The whole system is powered by 3 AAA batteries which should last a year.

	On Tin13 side:

	The whole structure is 40 bytes, comprising:

	typedef struct pulse_log_t {
		uint8_t checksum;
		uint8_t vcc;
		uint16_t ticks;
		uint8_t frames[LOG_FRAMES];
	} pulse_log_t;

	- checksum is a simple modulo 256 of the rest of the structure.
	- vcc is the output of the internal Tiny13 ADC comparing VCC with VREF;
	  VCC is battery voltage, which is read every 3 hours
	- ticks is the number of seconds since last communication with the ESP
	- frames is an array of 36 bytes, every byte is the number of pulses
	  recorded in the corresponding 5 minutes interval. 36 * 5m = 180m = 3h


	On ESP8266 side:

	ESP8266 could theoretically stay alseep for 3 consecutive hours, however
	due to the internal ESP sleep counter implementation, it's impossible to
	sleep longer than about 71 minutes (4294967295us). The ESP therefore
	sleeps 1 hour, and when it wakes up, depending on the hour, either:

	3, 6, 9, 12, 15, 18, 21: retrieves data from Tiny13 and stores it in RTC
	0/24: retrieves data from Tiny13, sends the whole RTC memory dump to server
		  and performs clock syncronization using the response from server
	rest: goes back to sleep immediately for another hour

	When the ESP dumps the Tiny memory, the Tiny13 clears its own memory.

	ESP8266 RTC memory is configured as a 32-bit integer array. The 40 bytes
	struct dumped from the Tiny13 is converted into a 10 elements array of
	32-bits integers by bit shifting left and stored into the RTC.

	RTC Memory Allocation (unit: 32bit array)
	[00-09]: Used by rtctime library to compensate poor "RTC" timekeeping of ESP
	[10-10]: Clock calibration counter (+ checksum)
	[11-91]: 8 slots, 10 elements each, every element 4 bytes; every slot
			 corresponds to a Tiny13 memory dump (40 bytes). Checksum is 
			 performed on the Tiny13 and checked on the ESP before sending
			 the slot content to the server

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

local tmr = require("tmr")
tmr.create():alarm(
	2000,
	tmr.ALARM_SINGLE,
	function()
		-- local l = file.list("%.lc$")
		-- for k, _ in pairs(l) do
		-- 	print("Removing " .. k)
		-- 	file.remove(k)
		-- end

		compile_lua()

		--local tests = require("tests")
		--tests.timekeeping()
		--tmr.wdclr()
		--tests.bitshift()
		--tmr.wdclr()
		--tests.rtcmem()
		--tmr.wdclr()
		-- print(node.heap())
		--tests.post()
		-- tests.tinypoll()
		--tests = nil

		local gascounter = require("gascounter")
		gascounter.main()
	end
)
