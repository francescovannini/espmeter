#!/bin/bash
if [ -f "upload.lst" ]; then
	last=$(cat upload.lst)
else
	last="1970-01-01 00:00"
fi

cd src
nodemcu-uploader file remove init.lua

if [ "$1" == "-i" ]; then
	list=$(find *.lua -newermt "$last" -printf "%f ")
	list=$list"init.lua"
	echo "Uploading $list"
	nodemcu-uploader --baud 921600 --timeout 60 upload $list
else
	nodemcu-uploader --baud 921600 --timeout 60 upload *.lua
	echo "Uploading all lua files"
fi
cd ..
date "+%F %T" > "upload.lst"

