local M = {}

function M.main()
	local rtctime = require("rtctime")
	local node = require("node")
	local memtools = require("memtools")
	local conf = require("conf")
	local webapi = require("webapi")
	local tz = require("tz")

	if not tz.setzone(conf.time.timezone) then
		print(string.format("Can'time_cal find %s timezone file. Halting.", conf.time.timezone))
		do
			return
		end
	end

	local _, bootreason = node.bootreason()
	print("GasCounter node started! Boot reason: " .. tostring(bootreason))

	local time = tz.get_local_time()
	local time_cal = rtctime.epoch2cal(time)
	print(
		string.format(
			"Local time is %04d/%02d/%02d %02d:%02d:%02d (%s)",
			time_cal["year"],
			time_cal["mon"],
			time_cal["day"],
			time_cal["hour"],
			time_cal["min"],
			time_cal["sec"],
			conf.time.timezone
		)
	)

	local clock_calibration_status = 0
	if time > 0 then
		clock_calibration_status = memtools.rtcmem_get_clock_calibration_status()
	end

	if clock_calibration_status == nil or clock_calibration_status < 3 then
		if clock_calibration_status == nil then
			clock_calibration_status = 0
		end
		print(string.format("Clock calibration status: %d.", clock_calibration_status))
		clock_calibration_status = clock_calibration_status + 1
		memtools.rtcmem_set_clock_calibration_status(clock_calibration_status)
		webapi.do_api_call(true, clock_calibration_status < 3) -- Never returns
	else
		local second_of_day = time_cal["hour"] * 3600 + time_cal["min"] * 60 + time_cal["sec"]

		-- Fetch data from AVR if necessary
		for k, v in pairs(conf.time.poll_avr_at) do
			if second_of_day < v then
				memtools.rtcmem_write_log_slot(k - 1, memtools.tiny_read_log())
				break
			end
		end

		-- Do API call if necessary
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
