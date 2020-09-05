#!/bin/bash
echo "Connect GPIO0 to GND, disconnect RST, power up ESP and press enter"
read
esptool.py --port /dev/ttyUSB0 write_flash -fm dio 0x00000 nodemcu-master-16-modules-2020-04-22-19-41-23-float.bin

