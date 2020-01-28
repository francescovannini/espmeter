local M = {}

function M.main()
	local rtctime = require("rtctime")
	local node = require("node")
	local memtools = require("memtools")
	local conf = require("conf")
	local webapi = require("webapi")

	local _, bootreason = node.bootreason()

	print("GasCounter node started! Boot reason: " .. tostring(bootreason))

	local tz = require("tz")
	tz.setzone(conf.tz)
	local local_time, _, clock_rate_offs = tz.get_local_time()

	if clock_rate_offs then
		print(string.format("Clock rate offset: %f", clock_rate_offs))
	else
		print("Clock rate offset not set")
	end

	if bootreason == 0 or local_time == 0 or clock_rate_offs == nil or clock_rate_offs == 0 then
		print("Clock needs to be set.")
		webapi.do_api_call(false, true)
	else
	
		local t = rtctime.epoch2cal(local_time)
		print(
			string.format(
				"Current time: %04d/%02d/%02d %02d:%02d:%02d",
				t["year"],
				t["mon"],
				t["day"],
				t["hour"],
				t["min"],
				t["sec"]
			)
		)

		local second_of_day = t["hour"] * 3600 + t["min"] * 60 + t["sec"]

		-- Fetch data from AVR
		for k, v in pairs(conf.time.poll_avr_at) do
			if second_of_day < v then
				memtools.rtcmem_write_log_slot(k - 1, memtools.tiny_read_log())
				break
			end
		end

		-- Do API call
		if second_of_day > conf.time.transmit_at then
			webapi.do_api_call(true, false)
		else
			local sleep = require("sleep")
			sleep.until_next_poll()
		end
	end

	do
		return
	end
end

return M
