local moduleName = "conf"

if not _G[moduleName] == nil then
    return _G[moduleName]
else
    local conf = {}
    conf.tz = "brussels.zone"

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
    conf.net.ntp.server = nil
    conf.net.ntp.enabled = true

    conf.time = {}
    conf.time.sleep_time = 3600
    conf.time.transmit_at = conf.time.sleep_time * 24
    conf.time.poll_avr_at = {
        0,
        conf.time.sleep_time * 3,
        conf.time.sleep_time * 6,
        conf.time.sleep_time * 9,
        conf.time.sleep_time * 12,
        conf.time.sleep_time * 15,
        conf.time.sleep_time * 18,
        conf.time.sleep_time * 21
    }

    _G[moduleName] = conf
    return conf
end
