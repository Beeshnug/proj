/*
 * LcdControl.asm
 *
 *  Created: 13/05/2018 2:14:18 PM
 *   Author: Ainsley
 */ 

; Definitions and Macros
.macro LCD_C								; wrapper for function
	ldi		r16, @0
	rcall	LCD_CMD
.endmacro

.macro LCD_D								; wrapper for function
	ldi		r16, @0
	rcall	LCD_DATA
.endmacro
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

; Initialises the LCD display
INIT_LCD:
	LCD_C	0b00111000						; display size
	rcall	SLEEP_5MS
	LCD_C	0b00111000						; display size
	rcall	SLEEP_1MS
	LCD_C	0b00111000						; display size
	LCD_C	0b00111000						; display size

	LCD_C	0b00001000						; display off
	LCD_C	0b00000001						; clear display
	LCD_C	0b00000110						; increment ???
	LCD_C	0b00001100						; display on, cursor off, blink off
	
	ser		r16							; set PORTF/A output
	out		DDRF, r16
	out		DDRA, r16
	clr		r16
	out		PORTF, r16
	out		PORTA, r16
	ret

; Print string at location
; args: r16 - LCD address
;         Z - string address
PRINT_STRING:
	rcall	LCD_CMD
	PRINT_STRING_WHILE:
	lpm		r16, Z+
	cpi		r16, 0
	breq	PRINT_STRING_END
	rcall	LCD_DATA
	rjmp	PRINT_STRING_WHILE
	PRINT_STRING_END:
	ret

; Print a number
; args:		r16 - number to print
PRINT_NUM:
	subi	r16, -'0'
	rcall	LCD_DATA
	ret

; Send command to LCD display
; args: r16 - command
LCD_CMD:
	out		PORTF, r16
	rcall	SLEEP_1MS
	sbi		PORTA, LCD_E
	rcall	SLEEP_1MS
	cbi		PORTA, LCD_E
	rcall	SLEEP_1MS
	rcall	LCD_WAIT
	ret

; Send data to LCD display
; args: r16 - data
LCD_DATA:
	out		PORTF, r16
	sbi		PORTA, LCD_RS
	rcall	SLEEP_1MS
	sbi		PORTA, LCD_E
	rcall	SLEEP_1MS
	cbi		PORTA, LCD_E
	rcall	SLEEP_1MS
	cbi		PORTA, LCD_RS
	rcall	LCD_WAIT
	ret

; Wait until ready
LCD_WAIT:
	push	r16
	clr		r16
	out		DDRF, r16
	out		PORTF, r16
	sbi		PORTA, LCD_RW
LCD_WAIT_LOOP:
	rcall	SLEEP_1MS
	sbi		PORTA, LCD_E
	rcall	SLEEP_1MS
	in		r16, PINF
	cbi		PORTA, LCD_E
	sbrc	r16, 7
	rjmp	LCD_WAIT_LOOP
	cbi		PORTA, LCD_RW
	ser		r16
	out		DDRF, r16
	pop		r16
	ret

; Sleep for ~1ms
SLEEP_1MS:
	push	r24
	push	r25
	ldi		r25, high(DELAY_1MS)
	ldi		r24, low(DELAY_1MS)
DELAYLOOP_1MS:
	sbiw	r25:r24, 1
	brne	DELAYLOOP_1MS
	pop		r25
	pop		r24
	ret

; Sleep for ~5ms
SLEEP_5MS:
	rcall	SLEEP_1MS
	rcall	SLEEP_1MS
	rcall	SLEEP_1MS
	rcall	SLEEP_1MS
	rcall	SLEEP_1MS
	ret