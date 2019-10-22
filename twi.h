#ifndef __TWI_H
#define __TWI_H

#include <avr/io.h>
#include <avr/interrupt.h>

/* SDA pin definition */
#define SDA PB1

/* SCL pin definition */
#define SCL PB0

/* Device slave address */
#define SLAVE_ADDRESS 0x5D

/* SDA manipulation macros */
#define GET_SDA()  (PINB & (1 << SDA) ? 1 : 0)
#define SET_SDA()  (DDRB &= ~(1 << SDA))
#define CLR_SDA()  (DDRB |= (1 << SDA))

/* SCL manipulation macros */
#define GET_SCL()  (PINB & (1 << SCL) ? 1 : 0)
#define SET_SCL()  (DDRB &= ~(1 << SCL))
#define CLR_SCL()  (DDRB |= (1 << SCL))

/* TWI interrupt manipulation macros */
#define TWI_INT_INIT()          (PCMSK |= (1 << PCINT1))
#define TWI_INT_ENABLE()        (GIMSK |= (1 << PCIE))
#define TWI_INT_DISABLE()       (GIMSK &= ~(1 << PCIE))
#define TWI_INT_CLEAR_FLAG()    (GIFR = (1 << PCIF))

// Dedicated general purpose registers.
register uint8_t TWSR asm("r2");
register uint8_t TWDR asm("r3");

#define I2C_BUFFER_SIZE     39
volatile uint8_t i2c_buffer[I2C_BUFFER_SIZE];
volatile register uint8_t i2c_buffer_idx asm("r4");

/* TWI state machine macros */
# define TWI_SLA_REQ_W_ACK_RTD              0x60
# define TWI_SLA_REQ_R_ACK_RTD              0xA8
# define TWI_SLA_DATA_SND_ACK_RCV           0xB8
# define TWI_SLA_DATA_SND_NACK_RCV          0xC0
# define TWI_SLA_LAST_DATA_SND_ACK_RCV      0xC8
# define TWI_SLA_REPEAT_START               0xA0
# define TWI_SLA_STOP                       0x68
# define I2C_IDLE                           0x00

uint8_t read_byte(void);
void twi_slave_init(void);
void twi_slave_enable(void);
void send_data(void);
void get_start_condition(void);

#endif //__TWI_H