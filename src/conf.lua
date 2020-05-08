local moduleName = "conf"

if not _G[moduleName] == nil then
	return _G[moduleName]
else
	local conf = {}

	conf.ota = {}
	conf.ota.version = 1
	conf.ota.enabled = true
	
	conf.wifi = {}
	conf.wifi.auto = false
	conf.wifi.save = false
	conf.wifi.ssid = "***REMOVED***"
	conf.wifi.pwd = "***REMOVED***"

	conf.net = {}
	conf.net.ip = "192.168.1.56"
	conf.net.netmask = "255.255.255.0"
	conf.net.gateway = "192.168.1.1"
	conf.net.dns_primary_server = "192.168.1.64"
	conf.net.dns_secondary_server = "192.168.1.64"
	conf.net.api_endpoint = "http://test.francescovannini.com/gascounter_web/post.php"

	conf.net.ntp = {}
	conf.net.ntp.server = "be.pool.ntp.org"
	conf.net.ntp.enabled = false

	conf.time = {}
	conf.time.timezone = "brussels.zone"
	conf.time.calibration_sleep_time = 600
	--conf.time.calibration_sleep_time = 10
	conf.time.calibration_cycles = 3
	conf.time.drift_margin = 300

	_G[moduleName] = conf
	return conf
end

