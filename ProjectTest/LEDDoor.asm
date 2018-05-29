;
; ProjectTest.asm
;
; Created: 22/05/2018 11:11:47 AM
; Author : Jeremy
;


; Replace with your application code
.include "m2560def.inc"

start:
	/*ser  r16
	out DDRC, r16*/					; set Port C as output, LED port
	ldi r17, 2
    //ldi r16, (0xF0 << r17)|(0x0F >> r17)			; r16 = 0b11111111
halt:
    rjmp halt

