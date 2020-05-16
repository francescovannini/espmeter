local conf = require("conf")
local rtctime = require("rtctime")
local tmr = require("tmr")
local tz = require("tz")
local log = require("log")

tz.setzone(conf.time.timezone)

local M = {}
M.hour = 3600

function M.seconds(s, wifi_wakeup_on)
	if s > M.hour then
		s = M.hour
	end

	local wifi_opt = 4 -- OFF by default
	if wifi_wakeup_on == true then
		wifi_opt = 0
	else
		wifi_wakeup_on = false
	end

	log(
		string.format(
			"Deep sleep until %s (%d seconds from now). Wi-Fi available at wakeup: %s",
			tz.time_to_string(tz.get_local_time() + s),
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

function M.oclock()
	local time = tz.get_local_time()
	local cal = rtctime.epoch2cal(time)
	local s = 3600 - (cal["min"] * 60 + cal["sec"])
	M.seconds(s, cal["hour"] == 23)
end

function M._unload()
	package.loaded["sleep"] = nil
end

return M
