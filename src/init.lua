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

	Sleep cycle 0 begins at midnight. End of cycle 7 ends approximately
	around midnight. Each cycle lasts 3 hours; at the end of each cycle, data
	from the Tiny13 is dumped into ESP RTC memory and the Tiny13 clears its
    own memory.

    ESP8266 RTC memory is configured as a 32-bit integer array.
    The 40 bytes struct dumped from the Tiny13 is converted into a 10 elements
    array of 32-bits integers by bit shifting left.

    At the end of cycle 7, all RTC memory is transferred to server
	and the sleep cycle is synchronized using server time, received in the
	API response.

	Sleep cycle information is stored in RTC memory slot 0.
	Data dumped from Tiny13 is stored from slots 1-80 totalling 320 bytes
	per day.

]] --

local tmr = require("tmr")
tmr.create():alarm(
	2000,
	tmr.ALARM_SINGLE,
	function()
		
		--local memtools = require("memtools")
		--memtools.rtcmem_clear_rtctime_data()	
		--do return end

		local gascounter = require("gascounter")
		gascounter.main()
	end
)

