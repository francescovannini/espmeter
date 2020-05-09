local M = {}
local rtctime = require("rtctime")
local tz = require("tz")
local conf = require("conf")
local wifi = require("wifi")
local tmr = require("tmr")
local node = require("node")
local sjson = require("sjson")

local function do_post(content, callback)
	-- send version when content is null

	print(string.format("Posting content: %s", content))

	-- TODO: Tune timeout, too long now
	local http = require("http")
	http.post(
		conf.net.api_endpoint,
		"Content-Type: application/json\r\n",
		content,
		function(code, response, _)
			http = nil

			print(node.heap())

			local ota_update = nil

			if code ~= 200 then
				print(string.format("Server answered %d to POST", code))
				callback(false, nil)
				return
			end

			if not response then
				print(string.format("Received empty response from server"))
				callback(false, nil)
				return
			end

			local kv = sjson.decode(response)
			sjson = nil

			for k, v in pairs(kv) do
				if k == "time" then
					local sec, usec = string.match(v, "([^.]*)%.([^.]*)")
					rtctime.set(sec, usec)
					print(string.format("Local time is now: %s", tz.time_to_string()))
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
	print("Setting up Wi-Fi connection...")

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
			print("Wi-Fi connection can't be established. Giving up.")
			callback(false, nil)
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
				local sntp = require("sntp")
				print("Attempting SNTP time sync.")
				local old_rtc = rtctime.get()

				sntp.sync(
					conf.net.ntp.server,
					function(_, _, server, _)
						sntp = nil
						print(string.format("SNTP server: %s", server))
						print(string.format("Local time is now: %s", tz.time_to_string()))

						if not content then
							print("No need to POST, clock synced through SNTP.")
							callback(true, nil)
						else
							do_post(content, callback)
						end
					end,
					function(reason, _)
						print("SNTP sync failed: " .. tostring(reason) .. ". Giving up.")
						callback(false, nil)
					end
				)
			else
				do_post(content, callback)
			end
		end
	)
end

local function ota_get_content(ota_content, callback)
	if wifi.sta.status() ~= wifi.STA_GOTIP then
		callback(false)
		return
	end

	local name, url
	for n, u in pairs(ota_content) do
		if name == nil and n ~= nil and u ~= nil then
			name = n
			url = u
		end
	end

	if name == nil then
		print("Contend downloaded, deploying...")
		local file = require("file")
		local l = file.list("%.upd$")
		for k, _ in pairs(l) do
			local n = string.sub(k, 1, string.len(k) - 4)
			if not file.rename(k, n) then
				print(string.format("Renaming %s to %s failed", k, n))
				callback(false)
				return
			end
		end
		file = nil
		callback(true)
		return
	end

	ota_content[name] = nil

	name = name .. ".upd"
	print(string.format("Downloading %s into %s", url, name))
	local http = require("http")
	http.get(
		url,
		nil,
		function(code, body, _)
			http = nil

			if code ~= 200 then
				callback(false)
				return
			end

			local file = require("file")
			if file.putcontents(name, body) then
				ota_get_content(ota_content, callback)
				return
			else
				file = nil
				callback(false)
				return
			end
		end
	)
end

function M.ota_update(ota_content, callback)
	local requested = nil
	for k, v in pairs(ota_content) do
		if k == "size" then
			local file = require("file")
			local avail = file.fsinfo()
			requested = v + 1024 -- tolerance for compilation
			file = nil
			if requested > avail then
				print(string.format("OTA update requires %d bytes but only %d are available", requested, avail))
				callback(false)
				return
			else
				print(string.format("OTA update requires %d bytes", requested))
			end
		end
	end

	if not requested then
		print("OTA size hasn't been received from server, can't continue")
		callback(false)
		return
	end

	for k, v in pairs(ota_content) do
		if k == "files" then
			ota_get_content(v, callback)
			return
		end
	end

	callback(false)
end

function M._unload()
	package.loaded["webapi"] = nil
end

return M
