#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <util/delay.h>
#include "main.h"
#include "twi.h"

_Static_assert(sizeof(pulse_log_t) == TWI_BUFFER_SIZE - 1, "pulse_log_t size must be equal to TWI_BUFFER_SIZE - 1");

extern volatile uint8_t output_buffer[];
volatile uint8_t flags;

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
    sbi(flags, FL_WD_TRIGGERED);
}

int main(void) {

    pulse_log_t *pulse_log = (pulse_log_t*) &output_buffer;
    pulse_log->ticks = 0;
    uint8_t i;

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
        if (!rbi(flags, FL_WD_TRIGGERED))
            continue;

        cbi(flags, FL_WD_TRIGGERED);

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
                if (!cbi(flags, FL_PREV_SENSOR_VAL)) {
                    pulse_log->frames[pulse_log->ticks / 60 * LOG_FRAME_MINUTES]++;
                }
                sbi(flags, FL_PREV_SENSOR_VAL);
            } else {
                cbi(flags, FL_PREV_SENSOR_VAL);
            }

            // Turn-off sensor
            cbi(CONTROL_PORT, SENSOR_VCC_PIN);

        }

    }
}
