#!/usr/bin/env bash

target="gascounter_tiny13"
codelimit=1024
datalimit=64

set -- `avr-size -d "$target" | awk '/[0-9]/ {print $1 + $2, $2 + $3, $2}'`
if [ $1 -gt $codelimit ]; then
	echo "*** code size $1 exceeds limit of $codelimit"
	exit 1
else
	echo "ROM: $1 bytes (data=$3)"
fi

if [ $2 -gt $datalimit ]; then
	echo "*** data size $2 exceeds limit of $datalimit"
	exit 1
else
	echo "RAM: $2 bytes"
fi
