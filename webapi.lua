function begin_sleep_cycle(cycle, sleep_seconds)
	print("Next sleeping plan: current cycle=" .. tostring(cycle) .. ", seconds left=" .. tostring(sleep_seconds))
	rtcmem_clear_log()
	rtcmem_set_sleep_cycle(cycle)			
	enter_sleep_cycle(cycle, sleep_seconds, cycle == 7)
end

function do_api_call(include_data)

	print("Initializing Wi-Fi connection")

	if conf.net.dns_primary_server then
		net.dns.setdnsserver(conf.net.dns_primary_server, 0)
	end

	if conf.net.dns_secondary_server then
		net.dns.setdnsserver(conf.net.dns_secondary_server, 1)
	end

	local wifi_timeout_timer = tmr.create()
	wifi_timeout_timer:alarm(60000, tmr.ALARM_SINGLE, function()
		print("Wi-Fi connection can't be established. Giving up.")
		begin_sleep_cycle(conf.sleep.initial_cycle, conf.sleep.sleep_seconds)
	end)

	wifi.setmode(wifi.STATION)
	wifi.sta.config(conf.wifi)
	wifi.sta.setip(conf.net)
	wifi.sta.connect(function()

		wifi_timeout_timer:stop()

		local content = ""
		if include_data then
			content = "{log:[" .. rtcmem_read_log() .. "]}"
			print("Posting content: " .. content)
		end
					
		http.post(conf.net.api_endpoint, 'Content-Type: application/json\r\n', content, function(code, response, headers)
			print("HTTP Response", code)
			print("HTTP Content", response)
			
			local cycle = conf.sleep.initial_cycle 
			local sleep_seconds = conf.sleep.sleep_seconds

			if code == 200 then
				t = sjson.decode(response)
				for k, v in pairs(t) do 
					if k == "cycle" then
						cycle = v
					elseif k == "seconds" then
						sleep_seconds = v
					end
				end
			else
				print("Received HTTP response different from 200, using predefined sleep plan")
			end
			begin_sleep_cycle(cycle, sleep_seconds)
		end)
	end)
end

