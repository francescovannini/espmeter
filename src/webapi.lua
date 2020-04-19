local M = {}
local rtctime = require("rtctime")
local memtools = require("memtools")
local http = require("http")
local conf = require("conf")
local sjson = require("sjson")
local tz = require("tz")
local net = require("net")
local tmr = require("tmr")
local sleep = require("sleep")
local wifi = require("wifi")
local sntp = require("sntp")

local function do_post(clock_sync_only)
	local content = nil

	if not clock_sync_only then
		content = memtools.rtcmem_read_log_json()
		print("POST payload: " .. content)
	end

	http.post(
		conf.net.api_endpoint,
		"Content-Type: application/json\r\n",
		content,
		function(code, response, _)
			if not response then
				response = ""
			end

			print(string.format("HTTP [%d] - %s", code, response))

			if code == 200 then
				local kv = sjson.decode(response)
				for k, v in pairs(kv) do
					if k == "time" then
						local sec, usec = string.match(v, "([^.]*)%.([^.]*)")
						local old_rtc = rtctime.get()
						rtctime.set(sec, usec)
						local new_rtc = rtctime.get()
						local tm = tz.get_offset(new_rtc) + new_rtc
						print(
							string.format(
								"Local time is now: %s (drift: %d)",tz.time_to_string(tm),
								old_rtc - new_rtc
							)
						)
					end
				end
			else
				print("Error during POST.")
			end

			if clock_sync_only then
				sleep.sleep_async(conf.time.calibration_sleep_time, true)
			else
				sleep.oclock()
			end
		end
	)
end

function M.do_api_call(clock_sync_only)
	print("Setting up Wi-Fi connection...")

	if conf.net.dns_primary_server then
		net.dns.setdnsserver(conf.net.dns_primary_server, 0)
	end

	if conf.net.dns_secondary_server then
		net.dns.setdnsserver(conf.net.dns_secondary_server, 1)
	end

	local wifi_timeout_timer = tmr.create()
	wifi_timeout_timer:alarm(
		10000,
		tmr.ALARM_SINGLE,
		function()
			print("Wi-Fi connection can't be established. Giving up.")
			sleep.oclock()
		end
	)

	wifi.setmode(wifi.STATION)
	wifi.sta.config(conf.wifi)
	wifi.sta.setip(conf.net)
	wifi.sta.connect(
		function()
			print("Wi-Fi connected.")
			wifi_timeout_timer:stop()
			if conf.net.ntp.enabled then
				print("Attempting SNTP time sync.")
				local old_rtc = rtctime.get()
				sntp.sync(
					conf.net.ntp.server,
					function(_, _, server, _)
						print(string.format("SNTP server: %s", server))
						local new_rtc = rtctime.get()
						local tm = tz.get_offset(new_rtc) + new_rtc
						print(
							string.format(
								"Local time is now: %s (drift: %d)",tz.time_to_string(tm),
								old_rtc - new_rtc
							)
						)

						if clock_sync_only then
							print("No need to POST, clock synced through SNTP.")
							sleep.sleep_async(conf.time.calibration_sleep_time, true)
						else
							do_post(false)
						end
					end,
					function(reason, _)
						print("SNTP sync failed: " .. tostring(reason) .. ". Giving up.")
						sleep.oclock()
					end
				)
			else
				do_post(clock_sync_only)
			end
		end
	)

end

return M
