conf = {}
conf.tz = "brussels.zone"

conf.wifi = {}
conf.wifi.auto = false
conf.wifi.save = false
conf.wifi.ssid = "***REMOVED***"
conf.wifi.pwd =  "***REMOVED***"

conf.net = {}
conf.net.ip = "192.168.1.56"
conf.net.netmask = "255.255.255.0"
conf.net.gateway = "192.168.1.1"
conf.net.dns_primary_server = "192.168.1.64"
conf.net.dns_secondary_server = "192.168.1.64"
conf.net.api_endpoint = "http://raspitest/gascounter_web/post.php"

conf.net.ntp = {}
conf.net.ntp.server = nil
conf.net.ntp.enabled = true

conf.sleep = {}
conf.sleep.initial_cycle = 0
conf.sleep.cycle_length = 3 * 60 * 60

