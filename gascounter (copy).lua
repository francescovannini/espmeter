--	IO	ESP8266	IO 	ESP8266
--	0	GPIO16	7	GPIO13
--	1	GPIO5	8	GPIO15
--	2	GPIO4	9	GPIO3
--	3	GPIO0	10	GPIO1
--	4	GPIO2	11	GPIO9
--	5	GPIO14	12	GPIO10
--	6	GPIO12

function deep_sleep() 
	print("Entering deep sleep")
	--node.dsleep(5000000, 4)
	node.dsleep(5000000)
end

id = 0
sda = 1
scl = 2
slv = 0x5d

print("GasCounter node started!")

i2c.setup(id, sda, scl, i2c.SLOW)
i2c.address(id, slv, i2c.RECEIVER)
rec = i2c.read(id, 5)

-- TODO verify checksum

local t = {}
for i = 1, #rec do
    t[i] = string.byte(rec:sub(i, i))
end

counter = 256 * t[2] + t[1]
adc = 256 * t[4] + t[3]
voltage = adc * 3.3 / 512
content = '{"c": ' .. counter .. ', "v": ' .. voltage .. '}'
print("Content: " .. content)

print("Configuring Wi-Fi...")

local conf = nil
if file.exists("conf.lc") then
	conf = dofile("conf.lc")
else
	print("config.lc not found, can't continue")
	do return end
end

wifi.setmode(wifi.STATION)
wifi.sta.config(conf.wifi)
wifi.sta.setip(conf.net)
wifi.sta.connect()

local wifi_timer = tmr.create()
wifi_timer:alarm(1000, tmr.ALARM_AUTO, function()
	if not wifi.sta.status() == wifi.STA_GOTIP then
		print("Waiting to complete Wi-Fi configuration...")
	else
		wifi_timer:stop()
		print("Got IP from server " .. wifi.sta.getip())
		net.dns.setdnsserver(conf.dns.ip)
		print("Posting JSON content '" .. content .. "'")
		http.post('http://orbital/gascounter/post.php', 'Content-Type: application/json\r\n', content, function(code, body, headers)
			print(code, body, headers)
			deep_sleep()
		end)
	end
end
)