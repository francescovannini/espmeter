cmake_minimum_required(VERSION 3.7)
project(espmeter_tiny13 C)

SET(CMAKE_C_STANDARD 99)
SET(MCU "attiny13")
SET(F_CPU "9600000")
SET(CMAKE_SYSTEM_NAME Generic)
SET(CMAKE_C_COMPILER /usr/bin/avr-gcc)
SET(CMAKE_CXX_COMPILER /usr/bin/avr-g++)
SET(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -DDEBUG")
SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mmcu=${MCU} -DF_CPU=${F_CPU} -Os -I. -ffunction-sections -Wl,--gc-sections -Wl,--relax -std=c99")

SET(SOURCE_FILES main.c main.h twi.h twi.c)

add_executable(espmeter_tiny13 ${SOURCE_FILES})

add_custom_command(TARGET espmeter_tiny13
        POST_BUILD COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/checksize.sh
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Checking code size...")

add_custom_command(TARGET espmeter_tiny13
        POST_BUILD COMMAND nm --print-size --size-sort --reverse-sort --debug-syms --radix=d espmeter_tiny13
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Objects sort by descending size: ")
