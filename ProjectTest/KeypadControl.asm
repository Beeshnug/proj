/*
 * KeypadControl.asm
 *
 *  Created: 23/05/2018 3:55:15 PM
 *   Author: Jeremy
 */ 
 /*
 * PartA.asm : Keypad
 *
 *  Created: 25/04/2018 2:31:21 PM
 *   Author: Ainsley
 */ 

; Definitions and Macros
.equ PORTL_IO = 0xF0						; PORTL I/O
.equ INIT_COL_MASK = 0xEF
.equ INIT_ROW_MASK = 0x01
.equ ROW_MASK = 0x0F

INIT_KEYPAD:
	ldi		r16, PORTL_IO					; set PORTL PL7:4 output, PL3:0 input (keypad)
	sts		DDRL, r16
	ret

; Functions
; args: nil
; return: r16 ascii value
; notes: assumes only one key pressed
READ_KEYPAD:
	; prologue
	push	r17								; curr col
	push	r18								; curr row
	push	r19								; col mask
	push	r20								; row mask
	push	r21								; temp

	; body
	ldi		r19, INIT_COL_MASK				; load the column mask
	clr		r17								; clear the column
	READ_KEYPAD_CLOOP:
	cpi		r17, 4							; if (col == 4) stop
	breq	READ_KEYPAD_CLOOP_END

	sts		PORTL, r19						; enable pull-up ?

	ldi		r16, 0xFF
	READ_KEYPAD_DELAY:
	dec		r16
	brne	READ_KEYPAD_DELAY				; delay r16 from multiple inputs when button pressed
	
	lds		r16, PINL						; read input from PINL
	andi	r16, ROW_MASK
	cpi		r16, 0x0F						; if (button !pressed) continue
	breq	READ_KEYPAD_CLOOP_CONTINUE
	
	ldi		r20, INIT_ROW_MASK				; load the row mask
	clr		r18								; clear the row
	READ_KEYPAD_RLOOP:
	cpi		r18, 4
	breq	READ_KEYPAD_RLOOP_END

	mov		r21, r16
	and		r21, r20
	breq	READ_KEYPAD_CONVERT

	lsl		r20
	inc		r18
	rjmp	READ_KEYPAD_RLOOP
	READ_KEYPAD_RLOOP_END:

	READ_KEYPAD_CLOOP_CONTINUE:
	rol		r19
	inc		r17
	rjmp	READ_KEYPAD_CLOOP
	READ_KEYPAD_CLOOP_END:
	clr		r16
	rjmp	READ_KEYPAD_EPILOGUE

	READ_KEYPAD_CONVERT:
	cpi		r17, 3							; if (col == 3) { A|B|C|D }
	breq	READ_KEYPAD_C_LETTER
	cpi		r18, 3							; if (row == 3) { *|0|# }
	breq	READ_KEYPAD_C_SYMBOL
	mov		r16, r18						; r16 = row * 3
	lsl		r16
	add		r16, r18
	add		r16, r17						; r16 = row * 3 + col
	subi	r16, -'1'
	rjmp	READ_KEYPAD_EPILOGUE	

	READ_KEYPAD_C_LETTER:
	ldi		r16, 'A'						; return 'A' + row
	add		r16, r18
	rjmp	READ_KEYPAD_EPILOGUE

	READ_KEYPAD_C_SYMBOL:
	ldi		r16, '*'
	cpi		r17, 0
	breq	READ_KEYPAD_EPILOGUE
	ldi		r16, '0'
	cpi		r17, 1
	breq	READ_KEYPAD_EPILOGUE
	ldi		r16, '#'
	cpi		r17, 2
	breq	READ_KEYPAD_EPILOGUE

	; epilogue
	clr		r16								; empty just in case
	READ_KEYPAD_EPILOGUE:
	pop		r21
	pop		r20
	pop		r19
	pop		r18
	pop		r17
	ret