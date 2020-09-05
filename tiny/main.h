//
// Created by francesco on 24/02/19.
//

#ifndef I2C_WATCHDOG_MAIN_H
#define I2C_WATCHDOG_MAIN_H

#define CONTROL_PORT_DDR    DDRB
#define CONTROL_PORT        PORTB
#define CONTROL_PORT_PINS   PINB
#define SENSOR_PIN          PB4
#define SENSOR_VCC_PIN      PB3

#ifndef cbi
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#endif

#ifndef sbi
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
#endif

#ifndef fbi
#define fbi(sfr, bit) (_SFR_BYTE(sfr) ^= _BV(bit))
#endif

#ifndef rbi
#define rbi(sfr, bit) (((sfr)>>(bit)) & 1)
#endif

#define FL_WD_TRIGGERED     0   // IC has been woken up by watchdog
#define FL_PREV_SENSOR_VAL  1   // previous sensor reading

#define LOG_HOURS           3
#define LOG_FRAME_MINUTES   5
#define LOG_FRAMES          (LOG_HOURS * 60 / LOG_FRAME_MINUTES)

typedef struct pulse_log_t {
    uint8_t vcc;
    uint16_t ticks;
    uint8_t frames[LOG_FRAMES];
} pulse_log_t;

#endif //I2C_WATCHDOG_MAIN_H
