local conf = {}

conf.log = {}
conf.log.enabled = false
conf.log.filename = "debug.log"
conf.log.maxsize = 128 * 1024
conf.log.maxfiles = 16

conf.ota = {}
conf.ota.version = 1
conf.ota.enabled = false

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
conf.net.ntp.server = "192.168.1.64"
conf.net.ntp.enabled = false

conf.time = {}
conf.time.timezone = "brussels.zone"
conf.time.calibration_sleep_time = 3600
conf.time.calibration_cycles = 3
conf.time.drift_margin = 300

return conf
