function do_post(include_data)
	local content = nil

	if include_data then
		content = rtcmem_read_log_json()
		print("POST payload: " .. content)
	end

	http.post(conf.net.api_endpoint, 'Content-Type: application/json\r\n', content, function(code, response, headers)
		print("HTTP Response", code)
		print("HTTP Content", response)

		local cycle = nil
		local cycle_seconds_left = nil

		if code == 200 then
			t = sjson.decode(response)
			for k, v in pairs(t) do

				if k == "time" then
					rtctime.set(v, 0)
					local tm = rtctime.epoch2cal(tz.gettime())
					print(string.format("RTC time sync received from HTTP server: %04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
				end

				if k == "cycle_number" then
					print("Cycle number from HTTP server: " .. v)
					cycle = v
				end

				if k == "cycle_seconds_left" and not cycle == nil then
					print("Cycle seconds left from HTTP server: " .. v)
					cycle_seconds_left = v
				end
			end
		else
			print("POST failed, HTTP code " .. tostring(code) .. " received. Using fallback configuration.")
		end

		if rtctime.get() > 0 then			
			if cycle == nil and cycle_seconds_left == nil then				
				local tm = rtctime.epoch2cal(tz.gettime())
				local seconds_from_midnight = tm["hour"] * 3600 + tm["min"] * 60 + tm["sec"]			
				cycle = math.floor(seconds_from_midnight / conf.sleep.cycle_length)
				cycle_seconds_left = conf.sleep.cycle_length - seconds_from_midnight % conf.sleep.cycle_length
				print(string.format("Calculated plan: cycle=%d cycle_seconds_left=%d", cycle, cycle_seconds_left))
			end
		else 
			if cycle == nil or cycle_seconds_left == nil then
				print("Sleep plan not available, using fallback.")
				cycle = conf.sleep.initial_cycle
				cycle_seconds_left = conf.sleep.cycle_length
			end
		end

		deep_sleep(cycle, cycle_seconds_left, cycle == 7, true)

	end)
end

function do_api_call(include_data)

	print("Initializing Wi-Fi connection...")

	if conf.net.dns_primary_server then
		net.dns.setdnsserver(conf.net.dns_primary_server, 0)
	end

	if conf.net.dns_secondary_server then
		net.dns.setdnsserver(conf.net.dns_secondary_server, 1)
	end

	local wifi_timeout_timer = tmr.create()
	wifi_timeout_timer:alarm(60000, tmr.ALARM_SINGLE, function()
		print("Wi-Fi connection can't be established. Giving up.")
		deep_sleep(conf.sleep.initial_cycle, conf.sleep.cycle_length, false, true)
	end)

	wifi.setmode(wifi.STATION)
	wifi.sta.config(conf.wifi)
	wifi.sta.setip(conf.net)
	wifi.sta.connect(function()
		wifi_timeout_timer:stop()		
		if conf.net.ntp.enabled then
			print("Attempting SNTP time synchronization")
			sntp.sync(conf.net.ntp.server,
				function(sec, usec, server, info)
					print("Time synced with server " .. dump(server))
					local tm = rtctime.epoch2cal(tz.gettime())
					print(string.format("RTC time is now: %04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
					do_post(include_data)
				end,
				function(reason, info)
					print("SNTP sync failed: " .. tostring(reason) .. ". Giving up.")
					deep_sleep(conf.sleep.initial_cycle, conf.sleep.cycle_length, false, true)
				end
			)
		else
			do_post(include_data)
		end
	end)
end
