local conf = require("conf")
local rtctime = require("rtctime")
local tmr = require("tmr")
local tz = require("tz")
tz.setzone(conf.tz)

local M = {}

function M.sleep_async(s, wifi_wakeup_on)
	local wifi_opt = 4 -- OFF by default
	if wifi_wakeup_on == true then
		wifi_opt = 0
	else
		wifi_wakeup_on = false
	end

	local wakeup_cal = rtctime.epoch2cal(tz.get_local_time() + s)
	print(
		string.format(
			"Deep sleep until %04d/%02d/%02d %02d:%02d:%02d (%d seconds from now). Wi-Fi available at wakeup: %s",
			wakeup_cal["year"],
			wakeup_cal["mon"],
			wakeup_cal["day"],
			wakeup_cal["hour"],
			wakeup_cal["min"],
			wakeup_cal["sec"],
			s,
			tostring(wifi_wakeup_on)
		)
	)

	local tm = tmr.create()
	tm:alarm(
		1000,
		tmr.ALARM_SINGLE,
		function()
			rtctime.dsleep(1000000 * (s - 1), wifi_opt)
		end
	)

	do
		return
	end
end

function M.until_next_poll(wifi_wakeup_on)
	local t = rtctime.epoch2cal(tz.get_local_time())

	local second_of_day = t["hour"] * 3600 + t["min"] * 60 + t["sec"]

	local sleep_secs = nil
	for _, v in pairs(conf.time.poll_avr_at) do
		if second_of_day + 5 < v then
			sleep_secs = v - second_of_day
			break
		end
	end

	-- Last sleep before transmission
	if sleep_secs == nil then
		if second_of_day > conf.time.transmit_at then -- TODO remove this when verified doen't happen
			print(
				string.format(
					"Error: second_of_day=%d when transmit_at=%d. This should never happen!",
					second_of_day,
					conf.time.transmit_at
				)
			)
			do
				return
			end
		end

		sleep_secs = conf.time.transmit_at - second_of_day
		wifi_wakeup_on = true
	end

	M.sleep_async(sleep_secs, wifi_wakeup_on) -- Never returns
end

return M
