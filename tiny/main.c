#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <util/delay.h>
#include "main.h"
#include "twi.h"

_Static_assert(sizeof(pulse_log_t) == I2C_BUFFER_SIZE, "pulse_log_t size must be equal to I2C_BUFFER_SIZE");

extern volatile uint8_t i2c_buffer[];
volatile uint8_t flags;

void readVccVoltage(uint8_t *vcc)
{

    // VCC as reference voltage
    ADMUX &= ~(1 << REFS0);

    // VCC compared with PB2, result is left adjusted
    ADMUX |= (1 << MUX0) | (1 << ADLAR);

    // Prescaler to /64 and ADC enabled
    ADCSRA |= (1 << ADPS2) | (1 << ADPS1) | (1 << ADEN);

    // Begin single conversion
    ADCSRA |= (1 << ADSC);

    // Wait until conversion is done
    while (ADCSRA & (1 << ADSC));

    // 8-bit precision, left adjusted result, one read
    *vcc = ADCH;

    // Disable ADC
    ADCSRA &= ~(1 << ADEN);
}

/* Watchdog service routine called at about @1Hz*/
ISR(WDT_vect)
{
    sbi(flags, FL_WD_TRIGGERED);
}

int main(void)
{

    pulse_log_t *pulse_log = (pulse_log_t *)&i2c_buffer;
    pulse_log->ticks = 0;
    uint8_t frame = 0;

    // Watchdog prescaler @1Hz
    WDTCR |= (1 << WDP2) | (1 << WDP1) | (0 << WDP0);

    // Enable watchdog
    WDTCR |= (1 << WDTIE);

    cbi(CONTROL_PORT_DDR, SENSOR_PIN);
    sbi(CONTROL_PORT_DDR, SENSOR_VCC_PIN);

    twi_slave_init();
    twi_slave_enable();

    // Let VCC settle
    _delay_us(1000000);
    readVccVoltage(&pulse_log->vcc);

    set_sleep_mode(SLEEP_MODE_PWR_DOWN);
    sei();
    for (;;)
    {
        sleep_enable();
        sleep_cpu();
        sleep_disable();

        // Not woken up by watchdog but by I2C
        if (!rbi(flags, FL_WD_TRIGGERED))
            continue;

        cbi(flags, FL_WD_TRIGGERED);

        // Woke up after 1 second
        pulse_log->ticks++;

        frame = (pulse_log->ticks + (LOG_FRAME_MINUTES * 60) - 1) / (LOG_FRAME_MINUTES * 60) - 1;
        if (frame >= LOG_FRAMES)
        {
            frame = LOG_FRAMES - 1;
        }

        // Turn-on sensor
        sbi(CONTROL_PORT, SENSOR_VCC_PIN);

        // Wait for sensor to settle
        _delay_us(500);

        // Detect magnetic field
        if (!rbi(CONTROL_PORT_PINS, SENSOR_PIN))
        {
            // Check if pulse not already accounted
            if (!rbi(flags, FL_PREV_SENSOR_VAL))
            {
                pulse_log->frames[frame]++;
            }
            sbi(flags, FL_PREV_SENSOR_VAL);
        }
        else
        {
            cbi(flags, FL_PREV_SENSOR_VAL);
        }

        // Turn-off sensor
        cbi(CONTROL_PORT, SENSOR_VCC_PIN);

        // Samples VCC 5 minutes before timeout
        if (pulse_log->ticks == LOG_HOURS * 60 * 55)
        {
            readVccVoltage(&pulse_log->vcc);
        }
    }
}
