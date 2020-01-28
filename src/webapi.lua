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

local function do_post(include_data, wifi_wakeup_on)
	local content = nil

	if include_data then
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
						rtctime.set(sec, usec)
						local tm = rtctime.epoch2cal(tz.get_local_time())
						print(
							string.format(
								"Clock set from HTTP server: %04d/%02d/%02d %02d:%02d:%02d",
								tm["year"],
								tm["mon"],
								tm["day"],
								tm["hour"],
								tm["min"],
								tm["sec"]
							)
						)
					end
				end
			else
				print("Error during POST.")
			end

			sleep.until_next_poll(wifi_wakeup_on)
		end
	)
end

function M.do_api_call(include_data, wifi_wakeup_on)
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
			sleep.until_next_poll(wifi_wakeup_on)
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
				sntp.sync(
					conf.net.ntp.server,
					function(_, _, server, _)
						local tm = rtctime.epoch2cal(tz.get_local_time())
						print(
							string.format(
								"Clock set from SNTP server %s: %04d/%02d/%02d %02d:%02d:%02d",
								server,
								tm["year"],
								tm["mon"],
								tm["day"],
								tm["hour"],
								tm["min"],
								tm["sec"]
							)
						)

						if include_data then
							do_post(include_data, wifi_wakeup_on)
						else
							sleep.until_next_poll(wifi_wakeup_on)
						end
					end,
					function(reason, _)
						print("SNTP sync failed: " .. tostring(reason) .. ". Giving up.")
						sleep.until_next_poll()
					end
				)
			else
				do_post(include_data, wifi_wakeup_on)
			end
		end
	)
end

return M
