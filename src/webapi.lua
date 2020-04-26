local M = {}
local rtctime = require("rtctime")
local http = require("http")
local conf = require("conf")
local sjson = require("sjson")
local tz = require("tz")
local net = require("net")
local tmr = require("tmr")
local wifi = require("wifi")
local sntp

local function do_post(content, callback)
	if content then
		print(string.format("Posting content: %s", content))
	end

	-- TODO: Tune timeout, too long now
	http.post(
		conf.net.api_endpoint,
		"Content-Type: application/json\r\n",
		content,
		function(code, response, _)
			if not response then
				response = ""
			end

			if code == 200 then
				local kv = sjson.decode(response)
				for k, v in pairs(kv) do
					if k == "time" then
						local sec, usec = string.match(v, "([^.]*)%.([^.]*)")
						local old_rtc = rtctime.get()
						rtctime.set(sec, usec)
						local new_rtc = rtctime.get()
						local tm = tz.get_offset(new_rtc) + new_rtc
						print(string.format("Local time is now: %s (drift: %d)", tz.time_to_string(tm), old_rtc - new_rtc))
					end
				end
				callback(true)
			else
				print("Error during POST.")
				callback(false)
			end
		end
	)
end

function M.server_sync(content, callback)
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
			callback(false)
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
				sntp = require("sntp")
				print("Attempting SNTP time sync.")
				local old_rtc = rtctime.get()
				sntp.sync(
					conf.net.ntp.server,
					function(_, _, server, _)
						print(string.format("SNTP server: %s", server))
						local new_rtc = rtctime.get()
						local tm = tz.get_offset(new_rtc) + new_rtc
						print(string.format("Local time is now: %s (drift: %d)", tz.time_to_string(tm), old_rtc - new_rtc))

						if not content then
							print("No need to POST, clock synced through SNTP.")
							callback(true)
						else
							do_post(content, callback)
						end
					end,
					function(reason, _)
						print("SNTP sync failed: " .. tostring(reason) .. ". Giving up.")
						callback(false)
					end
				)
			else
				do_post(content, callback)
			end
		end
	)
end

return M
