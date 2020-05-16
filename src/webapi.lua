local M = {}
local conf = require("conf")
local tmr = require("tmr")
local log = require("log")

local function do_post(content, callback)
	local rtctime = require("rtctime")
	if not content then
		content = string.format('{"vrs":"%s","ts":%d}', conf.ota.version, rtctime.get())
	end

	log(string.format("POST content length %d", content:len()))

	-- TODO: Tune timeout, too long now
	local http = require("http")
	http.post(
		conf.net.api_endpoint,
		"Content-Type: application/json\r\n",
		content,
		function(code, response, _)
			http = nil

			if code ~= 200 then
				log(string.format("Server answered %d to POST", code))
				callback(false, nil)
				return
			end

			if not response then
				log(string.format("Received empty response from server"))
				callback(false, nil)
				return
			end

			local sjson = require("sjson")
			local kv = sjson.decode(response)
			sjson = nil

			local ota_update = nil
			for k, v in pairs(kv) do
				if k == "time" and not conf.net.ntp.enabled then
					local sec, usec = string.match(v, "([^.]*)%.([^.]*)")
					rtctime.set(sec, usec)
					log(string.format("Time set from server"))
					rtctime = nil
				end

				if k == "otaupdate" then
					ota_update = v
				end
			end

			callback(true, ota_update)
		end
	)
end

function M.server_sync(content, callback) -- callback(result, ota_update)
	log("Setting up Wi-Fi connection...")

	if conf.net.dns_primary_server or conf.net.dns_secondary_server then
		local net = require("net")

		if conf.net.dns_primary_server then
			net.dns.setdnsserver(conf.net.dns_primary_server, 0)
		end

		if conf.net.dns_secondary_server then
			net.dns.setdnsserver(conf.net.dns_secondary_server, 1)
		end
	end

	local wifi_timeout_timer = tmr.create()
	wifi_timeout_timer:alarm(
		10000,
		tmr.ALARM_SINGLE,
		function()
			log("Wi-Fi connection can't be established. Giving up.")
			callback(false, nil)
		end
	)

	local wifi = require("wifi")
	wifi.setmode(wifi.STATION)
	wifi.sta.config(conf.wifi)
	wifi.sta.setip(conf.net)
	wifi.sta.connect(
		function()
			wifi = nil
			log("Wi-Fi connected.")
			wifi_timeout_timer:stop()
			if conf.net.ntp.enabled then
				local sntp = require("sntp")
				sntp.sync(
					conf.net.ntp.server,
					function(_, _, server, _)
						sntp = nil
						log(string.format("Time set from SNTP server: %s", server))
						if not content then
							log(string.format("No content to POST."))
							callback(true, nil)
						else
							do_post(content, callback)
						end
					end,
					function(reason, _)
						log("SNTP sync failed: " .. tostring(reason))
						if not content then
							log(string.format("No content to POST."))
							callback(false, nil)
						else
							do_post(content, callback)
						end
					end
				)
			else
				do_post(content, callback)
			end
		end
	)
end

function M._unload()
	package.loaded["webapi"] = nil
end

return M
