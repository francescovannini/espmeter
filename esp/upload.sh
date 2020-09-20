#!/bin/bash

PORT="/dev/ttyUSB3"

if [ -f "upload.lst" ]; then
	last=$(cat upload.lst)
else
	last="1970-01-01 00:00"
fi

read -p "Power on the board, then press ENTER immediately after"

touch boot.lock
nodemcu-uploader --port $PORT upload boot.lock  || exit 1
cd src
if [ "$1" == "-a" ]; then
	list=$(find * -printf "%f ")	
	echo "Uploading all files in src/"
else
	list=$(find * -newermt "$last" -printf "%f ")	
	echo "Uploading new files: $list"	
fi

nodemcu-uploader --port $PORT --baud 115200 --timeout 60 upload $list || exit 1
nodemcu-uploader --port $PORT file remove boot.lock  || exit 1
cd ..
date "+%F %T" > "upload.lst"

