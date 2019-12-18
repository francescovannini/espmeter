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

		local content = ""
		if include_data then
			content = rtcmem_read_log_json()
			print("Posting content: " .. content)
		end
					
		http.post(conf.net.api_endpoint, 'Content-Type: application/json\r\n', content, function(code, response, headers)
			print("HTTP Response", code)
			print("HTTP Content", response)

			local cycle = conf.sleep.initial_cycle 
			local cycle_seconds_left = conf.sleep.cycle_length

			if code == 200 then
				t = sjson.decode(response)
				for k, v in pairs(t) do 

					if k == "time" then						
						rtctime.set(v, 0)
						tm = rtctime.epoch2cal(rtctime.get())
						print(string.format("RTC time is now: %04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
					end

					if k == "cycle_number" then
						print("Cycle number from server: " .. v)
						cycle = v
					end

					if k == "cycle_seconds_left" then
						print("Cycle seconds left from server: " .. v)
						cycle_seconds_left = v
					end
				end
			else
				print("Received HTTP response different from 200, using predefined sleep plan")
			end
			deep_sleep(cycle, cycle_seconds_left, cycle == 7, true)
		end)
	end)
end
