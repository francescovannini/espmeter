#!/bin/bash

rm -rf cmake-build-release
mkdir cmake-build-release
cd cmake-build-release
cmake -DCMAKE_BUILD_TYPE=Releases ..
make
cd ..


