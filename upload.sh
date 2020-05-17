#!/bin/bash
if [ -f "upload.lst" ]; then
	last=$(cat upload.lst)
else
	last="1970-01-01 00:00"
fi

read -p "Power on the board, then press ENTER immediately after"

cd src
nodemcu-uploader file remove init.lua || exit 1
if [ "$1" == "-i" ]; then
	list=$(find *.lua ! -name "init.lua" -newermt "$last" -printf "%f ")
	list=$list"init.lua"
	echo "Uploading $list"
	nodemcu-uploader --baud 921600 --timeout 60 upload $list || exit 1
else
	echo "Uploading all files in src/"
	nodemcu-uploader --baud 921600 --timeout 60 upload * || exit 1
fi
cd ..
date "+%F %T" > "upload.lst"

