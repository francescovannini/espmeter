local M = {}

function M.main()
	local node = require("node")
	local memtools = require("memtools")
	local conf = require("conf")
	local webapi = require("webapi")
	local tz = require("tz")
	local sleep = require("sleep")

	if not tz.setzone(conf.time.timezone) then
		print(string.format("Can'time_cal find %s timezone file. Halting.", conf.time.timezone))
		do
			return
		end
	end

	local _, bootreason = node.bootreason()
	print("GasCounter node started! Boot reason: " .. tostring(bootreason))

	local time = tz.get_local_time()
	local second_of_day = tz.get_second_of_day(time)
	print(
		string.format(
			"Local time is %s (tz: %s) - Seconds since midnight: %d",
			tz.time_to_string(time),
			conf.time.timezone,
			second_of_day
		)
	)

	local clock_calibration_status = memtools.rtcmem_get_clock_calibration_status()
	if bootreason == 0 or clock_calibration_status == nil or clock_calibration_status < conf.time.calibration_cycles then
		if bootreason == 0 or clock_calibration_status == nil then
			clock_calibration_status = 0
		end
		clock_calibration_status = clock_calibration_status + 1
		print(string.format("Clock calibration cycle: %d out of %d", clock_calibration_status, conf.time.calibration_cycles))
		memtools.rtcmem_set_clock_calibration_status(clock_calibration_status)
		webapi.do_api_call(true)
		do
			return
		end
	end

	print("Not in clock calibration mode.")

	-- around midnight data is collected and sent and clock is synchronized
	if second_of_day > ((24 * 3600) - conf.time.drift_margin) or second_of_day < conf.time.drift_margin then
		memtools.rtcmem_write_log_slot(7, memtools.tiny_read_log())
		webapi.do_api_call(false)
		do
			return
		end
	end

	-- 03:00 06:00 09:00 12:00 15:00 18:00 21:00
	local s = 0
	for hour = 3, 21, 3 do
		if math.abs((hour * 3600) - second_of_day) <= conf.time.drift_margin then
			print(string.format("Collecting data for slot %d", s))
			memtools.rtcmem_write_log_slot(s, memtools.tiny_read_log())
			sleep.until_time((hour + 1) * 3600)
			do
				return
			end
		end
		s = s + 1
	end

	sleep.oclock()

	do
		return
	end
end

return M
