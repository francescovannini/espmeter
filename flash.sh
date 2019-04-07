#!/bin/bash

target="gascounter_tiny13"

cd cmake-build-release
make clean
make || exit 1

avr-objcopy -j .text -j .data -O ihex $target target.hex
avrdude -c usbtiny -pt13 -U flash:w:target.hex -U lfuse:w:0x7a:m -U hfuse:w:0xff:m
