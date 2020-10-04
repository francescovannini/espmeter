#!/bin/bash

PORT="/dev/ttyUSB3"

read -p "Power on the board, then press ENTER immediately after"

touch boot.lock
nodemcu-uploader --port $PORT upload boot.lock  || exit 1
nodemcu-uploader --port $PORT file list 2> loglist.txt || exit 1
list=$(grep "log\.[0-9]" loglist.txt | cut -f1 | tr '\n' ' ')
nodemcu-uploader --port $PORT --baud 115200 download $list || exit 1
nodemcu-uploader --port $PORT file remove boot.lock  || exit 1

