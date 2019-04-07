#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <util/delay.h>
#include "main.h"
#include "twi.h"

_Static_assert(sizeof(pulse_log_t) == MAX_READ_SIZE, "pulse_log_t must be MAX_READ_SIZE size");

extern volatile uint8_t output_buffer[];
volatile uint8_t wd_triggered = 0;

void readVccVoltage(uint8_t *vcc) {

    // VCC is compared with PB2, result is left adjusted
    ADMUX |= (1 << MUX0) | (1 << ADLAR);

    // Enable ADC, set prescaler to /64 so f~150kHz
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1);

    // Start conversion
    ADCSRA |= (1 << ADSC);
    while (ADCSRA & (1 << ADSC));

    // 8-bit precision, left adjusted result
    *vcc = ADCH;

    // Disable ADC
    ADCSRA &= ~(1 << ADEN);

}

/* Watchdog service routine called at about @2Hz*/
ISR(WDT_vect) {
    wd_triggered = 1;
}

int main(void) {

    pulse_log_t *pulse_log = (pulse_log_t*) &output_buffer;
    uint8_t sensor_output_prev = 0;

    pulse_log->ticks = 0;
    for (uint8_t i = 0; i < LOG_FRAMES; i++) {
        pulse_log->frames[i] = 0;
    }

    // Watchdog prescaler @1Hz
    WDTCR |= (1 << WDP2) | (1 << WDP1);

    // Enable watchdog
    WDTCR |= (1 << WDTIE);

    cbi(CONTROL_PORT_DDR, SENSOR_PIN);
    sbi(CONTROL_PORT_DDR, SENSOR_VCC_PIN);

    twi_slave_init();
    twi_slave_enable();

    readVccVoltage(&pulse_log->vcc);

    set_sleep_mode(SLEEP_MODE_PWR_DOWN);
    sei();
    for (;;) {
        sleep_enable();
        sleep_cpu();
        sleep_disable();

        // System woken up by I2C?
        if (!wd_triggered)
            continue;

        wd_triggered = 0;

        // Log space is exhausted?
        if (pulse_log->ticks < LOG_HOURS * 60 * 60) {

            pulse_log->ticks++;

            // Samples VCC 5 minutes before timeout
            if (pulse_log->ticks == LOG_HOURS * 60 * 55) {
                readVccVoltage(&pulse_log->vcc);
            }

            // Turn-on sensor
            sbi(CONTROL_PORT, SENSOR_VCC_PIN);

            // Wait for sensor to settle
            _delay_us(500);

            // Check magnetic field
            if (!rbi(CONTROL_PORT_PINS, SENSOR_PIN)) {

                // Check if pulse not already accounted
                if (!sensor_output_prev) {
                    pulse_log->frames[pulse_log->ticks / 60 * LOG_FRAME_MINUTES]++;
                }

                sensor_output_prev = 1;

            } else {
                sensor_output_prev = 0;
            }

            // Turn-off sensor
            cbi(CONTROL_PORT, SENSOR_VCC_PIN);

        }

        // Calculate checksum
        pulse_log->checksum = 64;
        for (uint8_t i = 1; i < MAX_READ_SIZE; i++) {
            pulse_log->checksum += output_buffer[i];
        }
    }
}
