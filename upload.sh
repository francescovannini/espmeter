#!/bin/bash
nodemcu-uploader file remove init.lua

if [ -z "$1" ]; then
    nodemcu-uploader --baud 921600 --timeout 60 upload -c *.lua
else
    nodemcu-uploader --baud 921600 --timeout 60 upload -c "$1" init.lua
fi
