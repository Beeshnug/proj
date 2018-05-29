/*
 * State.asm
 *
 *  Created: 28/05/2018 10:14:09 AM
 *   Author: Jeremy
 */ 
 
; Definitions
.equ UP = 1
.equ STOP = 0
.equ DOWN = -1

; Required variables
.dseg


; Functions
.cseg

; Changes the state to include a button
; args: r16 - button pressed e{0 - 9}
ADD_FLOOR:
	push	ZL
	push	ZH
	push	r17
	push	r30
	push	r31

	; Save the input for later
	mov		r17, r16

	lds		r30, Emergency
	cpi		r30, 1
	breq	AF_E

	lds		r30, CurrFloor
	cp		r17, r30
	breq	AF_E

	; Update the state
	ldi		ZL, low(state)					; create the pointer to the state array
	ldi		ZH, high(state)
	add		ZL, r16							; add index to pointer
	clr		r16
	adc		ZH, r16
	ldi		r16, 1							; indicate floor is pressed
	st		Z, r16

	; Update the direction if necessary
	lds		r16, direction					; if (direction == 0) { update }
	cpi		r16, 0
	brne	AF_E
	lds		r30, currFloor
	cp		r17, r30						
	brlt	AF_EL
	AF_IF:									; if (i > currentFloor) direction = UP
	ldi		r31, UP
	rjmp	AF_EN
	AF_EL:									; else direction = DOWN
	ldi		r31, DOWN
	AF_EN:
	sts		direction, r31					; store the new direction

	AF_E:
	pop		r31
	pop		r30
	pop		r17
	pop		ZH
	pop		ZL
	ret


; Checks if the current floor is in the state
; rets: r16 - button check result
CHECK_FLOOR:
	push	ZL
	push	ZH

	ldi		ZL, low(state)					; create the pointer to the state array
	ldi		ZH, high(state)

	lds		r16, currFloor
	add		ZL, r16							; add index to pointer
	clr		r16
	adc		ZH, r16

	ld		r16, Z							; load the state of the button

	pop		ZH
	pop		ZL
	ret


; Changes the state to remove a button
REMOVE_FLOOR:
	push	ZL
	push	ZH
	push	r16

	ldi		ZL, low(state)					; create the pointer to the state array
	ldi		ZH, high(state)

	lds		r16, currFloor
	add		ZL, r16							; add index to pointer
	clr		r16
	adc		ZH, r16

	ldi		r16, 0							; indicate floor is pressed
	st		Z, r16

	pop		r16
	pop		ZH
	pop		ZL
	ret


; Updates the value stored in `direction`
; Local vars: r16 - `pushed`
;			  r17 - `i`
;			  r18 - `tmp`
UPDATE_DIRECTION:
	push	ZL
	push	ZH
	push	r16
	push	r17
	push	r18
	push	r19

	; 1. Check for no buttons pressed
	ldi		ZL, low(state)					; create the pointer to the state array
	ldi		ZH, high(state)
	clr		r16								; clear flag and counter for loop (r16 is the flag)
	clr		r17
	CD_L1:									; for (int i = 0; i < 10; i++) { ... }
	ld		r18, Z+							; load data from state
	tst		r18
	breq	CD_L1_I_E
	CD_L1_I:
	ldi		r16, 1							; a button was pressed
	CD_L1_I_E:
	inc		r17
	cpi		r17, 10
	brne	CD_L1
	CD_L1_E:
	cpi		r16, 0
	brne	CD_I_E
	CD_I:
	sts		direction, r16
	rjmp	CD_E
	CD_I_E:

	; 2. Assume a change in direction until proven otherwise
	ldi		r16, -1							; `pushed`: assume change
	lds		r17, currFloor					; `i`
	clr		r18								; `tmp`
	ldi		ZL, low(state)					; create the pointer to state[currFloor]
	ldi		ZH, high(state)
	add		ZL, r17
	adc		ZH, r18
	CD_L2:
	cpi		r17, 0							; if (i < 0) stop
	brlt	CD_L2_E
	cpi		r17, 10							; if (i >= 10) stop
	brge	CD_L2_E
	ld		r18, Z							; load in from state[i]
	cpi		r18, 0							; if (state[i] != 0) { ... }
	breq	CD_L2_I1_E
	CD_L2_I1:
	ldi		r16, 1
	rjmp	CD_L2_E
	CD_L2_I1_E:

	lds		r18, direction
	cpi		r18, 1							; if (dir == UP) { ... }
	brne	CD_L2_I2_L
	CD_L2_I2:
	inc		r17
	adiw	Z, 1
	rjmp	CD_L2_I2_E
	CD_L2_I2_L:								; eLse { ... }
	dec		r17
	sbiw	Z, 1
	CD_L2_I2_E:								; if End //
	
	rjmp	CD_L2
	CD_L2_E:

	; 3. Update the direction
	lds		r18, direction					; direction = direction * r16
	muls	r18, r16
	mov		r18, r0							; assume only 1, 0 or -1
	sts		direction, r18

	CD_E:
	pop		r19
	pop		r18
	pop		r17
	pop		r16
	pop		ZH
	pop		ZL
	ret

; Prints the current state of the elevator on the bottom line
PRINT_STATE:
	push	r16
	push	r17
	push	r18
	push	ZL
	push	ZH

	lds		r16, Emergency
	cpi		r16, 1
	brne	NOT_EMERGENCY
	ldi		ZL, low(Emr1 << 1)
	ldi		ZH, high(Emr1 << 1)
	rcall	PRINT_STRING
	ldi		r16, 0b11000000
	ldi		ZL, low(Emr2 << 1)
	ldi		ZH, high(Emr2 << 1)
	rcall	PRINT_STRING
	rjmp	FLOOR_PRINT

	NOT_EMERGENCY:
	rcall	PRINT_MOVE_STATUS
	rcall	PRINT_DOOR_STATUS
	
	FLOOR_PRINT:
	; Print the current floor
	LCD_C	0xC8
	LCD_D	'F'
	lds		r16, currFloor
	rcall	PRINT_NUM

	; Print the current direction
	LCD_D	'D'
	lds		r16, direction
	PS_I:	
	cpi		r16, 1
	brne	PS_EI1
	LCD_D	'U'
	rjmp	PS_EI
	PS_EI1:
	cpi		r16, 0
	brne	PS_EI2
	LCD_D	'S'
	rjmp	PS_EI
	PS_EI2:
	LCD_D	'D'
	PS_EI:

	; Print the active buttons
	LCD_D	'B'
	ldi		ZL, low(state)
	ldi		ZH, high(state)
	clr		r16
	clr		r17
	clr		r18
	PS_L:
	ld		r16, Z+
	cpi		r16, 0
	breq	PS_LE
	PS_LI:
	mov		r16, r17
	rcall	PRINT_NUM
	PS_LE:
	inc		r17
	cpi		r17, 10
	brne	PS_L
	PS_L_E:

	; Pad out the rest
	clr		r17
	PS_L2:
	LCD_D	' '
	inc		r17
	cpi		r17, 10
	brne	PS_L2
	PS_L2_E:

	lds		r16, Emergency
	out		PORTC, r16

	PRINT_STATE_EPILOGUE:
	pop		ZH
	pop		ZL
	pop		r18
	pop		r17
	pop		r16
	ret


; Update the state on arrival
ARRIVE:
	rcall	CHECK_FLOOR
	cpi		r16, 1
	brne	A_E
	A_I:
	rcall	REMOVE_FLOOR
	A_E:
	rcall	UPDATE_DIRECTION

	ret


; Update floor to next
DEPART:
	push	r16
	push	r17

	lds		r16, currFloor
	lds		r17, direction
	add		r16, r17
	sts		currFloor, r16

	pop		r17
	pop		r16
	ret


; Cycle
CYCLE:
	rcall	ARRIVE
	/*rcall	PRINT_STATE*/
	rcall	DEPART
	//rcall	PRINT_STATE
	ret


; Initialise and clear state array
INIT_STATE:
	; prologue
	push	ZL
	push	ZH
	push	r16
	push	r17
	push	r18

	; Body
	ldi		r17, 0
	ldi		r16, 0
	sts		direction, r16
	ldi		ZL, low(state)
	ldi		ZH, high(state)
	INIT_STATE_LOOP:
	cpi		r16, 10
	brsh	INIT_STATE_EPILOGUE
	st		Z+, r17
	inc		r16
	rjmp	INIT_STATE_LOOP

	INIT_STATE_EPILOGUE:
	;Epilogue
	pop		r18
	pop		r17
	pop		r16
	pop		ZH
	pop		ZL
	ret