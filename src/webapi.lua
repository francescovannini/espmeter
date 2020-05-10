local M = {}
local conf = require("conf")
local wifi = require("wifi")
local tmr = require("tmr")

-- https://github.com/luvit/luvit/blob/master/deps/url.lua
local function parseURL(url)
	local chunk, protocol = url:match("^(([a-z0-9+]+)://)")
	url = url:sub((chunk and #chunk or 0) + 1)

	local auth
	chunk, auth = url:match("(([%w%p]+:?[%w%p]+)@)")
	url = url:sub((chunk and #chunk or 0) + 1)

	local host
	local hostname
	local port
	if protocol then
		host = url:match("^([%a%.%d-]+:?%d*)")
		if host then
			hostname = host:match("^([^:/]+)")
			port = host:match(":(%d+)$") or 80
		end
		url = url:sub((host and #host or 0) + 1)
	end

	local parsed = {
		hostname = hostname,
		port = port,
		auth = auth,
		path = url
	}

	return parsed
end

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

			local sjson = require("sjson")
			local kv = sjson.decode(response)
			sjson = nil

			local ota_update = nil
			for k, v in pairs(kv) do
				if k == "time" and not conf.net.ntp.enabled then
					local sec, usec = string.match(v, "([^.]*)%.([^.]*)")
					local rtctime = require("rtctime")
					local tz = require("tz")
					rtctime.set(sec, usec)
					print(string.format("Local time is now: %s", tz.time_to_string()))
					rtctime = nil
					tz._unload()
					tz = nil
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
				sntp.sync(
					conf.net.ntp.server,
					function(_, _, server, _)
						sntp = nil
						print(string.format("Time set from SNTP server: %s", server))
						if not content then
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

local function ota_get_content(ota_base_url, ota_content, callback)
	-- Take first entry
	local name = table.remove(ota_content, 1)

	-- No more entries left
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

	print(string.format("Downloading %s", name))

	local net = require("net")
	local file = require("file")
	local f = nil

	local tcp = net.createConnection(net.TCP, 0)
	tcp:on(
		"receive",
		function(sck, data)
			if f == nil then
				name = name .. ".upd"
				f = file.open(name, "w+")
			end
			f:write(data)
		end
	)
	tcp:on(
		"connection",
		function(sck, c)
			print("Connection: ", c)

			local req =
				-- add auth

			string.format(
				"GET %s/%s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nAccept: */*\r\n\r\n",
				ota_base_url.path,
				name,
				ota_base_url.host
			)

			tcp:send(req)
		end
	)

	tcp:on(
		"disconnection",
		function(sck, c)
			print("Disconnection: ", c)
			f:close()
			ota_get_content(ota_base_url, ota_content, callback)
		end
	)

	tcp:connect(ota_base_url.port, ota_base_url.host)
end

function M.ota_update(ota_content, callback)
	if wifi.sta.status() ~= wifi.STA_GOTIP then
		callback(false)
		return
	end

	local requested = nil
	local base_url = nil
	for k, v in pairs(ota_content) do
		if k == "size" and v > 0 then
			local file = require("file")
			local avail = file.fsinfo()
			requested = v + 1024 -- tolerance for compilation
			file = nil
			if requested > avail then
				print(string.format("OTA update requires %d bytes but only %d are available", requested, avail))
				callback(false)
				return
			else
				print(string.format("OTA update requires %d bytes", v))
			end
		end
		if k == "url" then
			base_url = parseURL(v)
		end
	end

	if not requested or not base_url then
		print("OTA size hasn't been received from server, can't continue")
		callback(false)
		return
	end

	for k, v in pairs(ota_content) do
		if k == "files" then
			ota_get_content(base_url, v, callback)
			return
		end
	end

	callback(false)
end

function M._unload()
	package.loaded["webapi"] = nil
end

return M
