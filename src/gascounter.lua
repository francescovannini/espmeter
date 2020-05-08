local M = {}

function M.main()
	local node = require("node")
	local memtools = require("memtools")
	local conf = require("conf")
	local tz = require("tz")
	local sleep = require("sleep")

	if not tz.setzone(conf.time.timezone) then
		print(string.format("Can'time_cal find %s timezone file. Halting.", conf.time.timezone))
		do
			return
		end
	end

	local _, bootreason = node.bootreason()
	local time = tz.get_local_time()
	local second_of_day = tz.get_second_of_day(time)

	print(
		string.format(
			"GasCounter started - Boot reason: %s - Local time is %s (tz: %s) - Seconds past midnight: %d",
			tostring(bootreason),
			tz.time_to_string(time),
			conf.time.timezone,
			second_of_day
		)
	)

	local clock_calibration_status = memtools.rtcmem_get_clock_calibration_status()
	if (time < 100) or (bootreason == 0 or clock_calibration_status == nil) then
		clock_calibration_status = 0
	end

	if clock_calibration_status < conf.time.calibration_cycles then
		clock_calibration_status = clock_calibration_status + 1
		print(string.format("Clock calibration cycle: %d out of %d", clock_calibration_status, conf.time.calibration_cycles))

		-- Sleep until o'clock and align Tiny when waking up
		if clock_calibration_status == conf.time.calibration_cycles then
			memtools = nil
			local webapi = require("webapi")
			webapi.server_sync(
				false,
				function(sync_result, ota_update)
					if sync_result then
						memtools = require("memtools")
						memtools.rtcmem_set_clock_calibration_status(clock_calibration_status)
						memtools = nil
					else
						print("Error during time synchronization.")
					end
					sleep.oclock()
				end
			)
			do
				return
			end
		else -- Sleep for the clock calibration interval
			memtools = nil
			local webapi = require("webapi")
			webapi.server_sync(
				false,
				function(sync_result, ota_update)
					if sync_result then
						memtools = require("memtools")
						memtools.rtcmem_set_clock_calibration_status(clock_calibration_status)
						memtools = nil
					else
						print("Error during time synchronization.")
					end
					sleep.seconds(conf.time.calibration_sleep_time)
				end
			)
			do
				return
			end
		end
	else
		if clock_calibration_status == conf.time.calibration_cycles then
			print("Syncing cycle with TINY after clock calibration")
			memtools.tiny_read_log()
			clock_calibration_status = clock_calibration_status + 1
			memtools.rtcmem_set_clock_calibration_status(clock_calibration_status)
		else
			print("Not in clock calibration mode.")
		end
	end

	-- around midnight data is collected and sent and clock is synchronized
	if second_of_day > ((24 * 3600) - conf.time.drift_margin) or second_of_day < conf.time.drift_margin then
		memtools.rtcmem_write_log_slot(7, memtools.tiny_read_log())

		local content = memtools.rtcmem_read_log_json()
		memtools = nil

		local webapi = require("webapi")
		webapi.server_sync(
			content,
			function(sync_result, ota_update)
				if sync_result then
					print("Content posted, clearing RTC")
					memtools = require("memtools")
					memtools.rtcmem_clear_log()
					memtools = nil
				else
					print("Error during POST") --TODO repost after a delay maybe or store to fs?
				end
				sleep.oclock()
			end
		)

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
			break
		end
		s = s + 1
	end

	sleep.oclock()

	do
		return
	end
end

return M
