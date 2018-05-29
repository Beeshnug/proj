/*
 * main.asm
 *
 *  Created: 22/05/2018 11:27:27 AM
 *   Author: Jeremy
 */ 

 .include "m2560def.inc"

 .dseg
 Moving:			.byte 1				; 0 = Not Moving
 Door:				.byte 1				; 0 = Opening, 1 = Open, 2 = Closing
 TimerMoveCounter:	.byte 1		
 TimerDoorCounter:	.byte 1
 MoveCounter:		.byte 1
 counter:			.byte 1
 keyLock:			.byte 1
 Emergency:			.byte 1

 currFloor: .byte 1				; used to store the current floor
 direction: .byte 1				; used to store the current direction
 state: .byte 10

.cseg
.org 0x0000			jmp		RESET
.org INT0addr		jmp		EXT_INT0
.org INT1addr		jmp		EXT_INT1
.org OVF0ADDR		jmp		TIMER0OVF

 .include "LcdControl.asm"
 .include "KeypadControl.asm"
 .include "State.asm"

str1:		.db "YMov",0,0
str2:		.db "NMov",0,0
floor:		.db "Flr: ",0
dOpening:	.db "O Door",0,0
dClosing:	.db "C Door",0,0
dOpen:		.db "Door O",0,0
dClose:		.db "Door C",0,0
Emr1:		.db	"Emergency",0
Emr2:		.db "Call 000",0,0

RESET:
	ldi		r16, high(RAMEND)			; init stack pointer
	out		SPH, r16
	ldi		r16, low(RAMEND)
	out		SPL, r16
	; LED Setup
	ser		r16							; set PORTC to output, LED port
	out		DDRC, r16
	out		DDRE, r16
	; LCD Setup
	rcall	INIT_LCD
	;Keypad Setup
	rcall	INIT_KEYPAD
	; State Setup
	rcall	INIT_STATE

	; Status Setup
	ldi		r16, 0
	sts		Moving, r16					; Not Moving
	sts		CurrFloor, r16				; Floor 0
	sts		Emergency, r16				; Emergency  = false
	ldi		r16, 1
	sts		Door, r16					; Closed
	sts		MoveCounter, r16

START:
	ldi		r16, 0x0					; clear Counters
	sts		TimerMoveCounter, r16
	sts		TimerDoorCounter, r16

	; Timer 0 Setup
	ldi		r16, 0b00000000				; set timer to normal
	out		TCCR0A, r16
	ldi		r16, 0b00000101				; set timer prescaler = 1024
	out		TCCR0B, r16
	ldi		r16, 1 << TOIE0				; enable timer overflow
	sts		TIMSK0, r16								

	; Push Buttons Interrupt Setup
	ldi		r16, 2 << ISC00				; setup external interrupt control register
	ori		r16, 2 << ISC10
	sts		EICRA, r16
	ldi		r16, 1 << INT0				; setup external interrupt mask
	ori		r16, 1 << INT1
	out		EIMSK, r16
	sei									; global interrupt enable
    
HALT:
	rcall	READ_KEYPAD						; read the keypad
	cpi		r16, 0
	brne	MAIN_ELSE						; if (char == 0) { ... }
	MAIN_IF:
	lds		r17, counter
	inc		r17
	sts		counter, r17
	cpi		r17, 100
	brne	MAIN_IF_END
	clr		r17
	sts		counter, r17
	sts		keyLock, r17
	rjmp	MAIN_IF_END
	MAIN_ELSE:								; else (char != 0) { ... }
	lds		r17, keyLock
	cpi		r17, 1							; if (keyLock == 1) // already pressed
	breq	MAIN_IF_END
	ldi		r17, 1
	sts		keyLock, r17					; update the keyLock
	cpi		r16, '*'						; handle specific keys
	breq	EMERGENCY_TOGGLE
	cpi		r16, '9'+1						; ignore non number
	brsh	MAIN_IF_END
	cpi		r16, '0'
	brlo	MAIN_IF_END
	subi	r16, '0'
	lds		r18, currFloor
	cp		r16, r18
	breq	MAIN_IF_END
	rcall	ADD_FLOOR
	rcall	PRINT_STATE
	MAIN_IF_END:
	rjmp	HALT

DUMMY:
	rcall	CYCLE
	rjmp	HALT

EMERGENCY_TOGGLE:
	lds		r16, Emergency
	cpi		r16, 0
	brne	EMERGENCY_DISABLE
	rcall	INIT_STATE
	lds		r16, Currfloor
	cpi		r16, 0
	breq	EM_0
	ldi		r16, 0
	rcall	ADD_FLOOR
	EM_0:
	ldi		r16, 1
	sts		Emergency, r16
	rjmp	HALT
	EMERGENCY_DISABLE:
	ldi		r16, 0
	sts		Emergency, r16
	rjmp	RESET
	
; Interrupt Handlers

; Timer 0 Interrupt Handler
TIMER0OVF:
	; prologue
	push	r16
	in		r16, SREG
	push	r16
	; body
	
	; Moving 
	lds		r16, TimerMoveCounter		; load the counter
	inc		r16
	cpi		r16, 60
	brne	TIMER_MOVE_END_IF			; if (counter == 60) { ... }
	TIMER_MOVE_IF:
	rcall	SWAP_MOVE_STATUS
	rcall	CHK_DOOR_STATUS
	rcall	PRINT_STATE
	ldi		r16, 0						; reset TimerMoveCounter
	TIMER_MOVE_END_IF:
	sts		TimerMoveCounter, r16		; update the counter
		
	; epilogue
TIMER0OVF_EPILOGUE:
	pop		r16
	out		SREG, r16
	pop		r16
	reti

PRINT_FLOOR_STATUS:
	; INPUT		-> NONE
	; USES		-> r16, Z
	; CHANGES	-> NONE
	; OUTPUT	-> NONE
	; prologue
	push	r16
	push	ZL
	push	ZH

	; Body
	ldi		r16, 0b10001011
	ldi		ZL, low(floor << 1)
	ldi		ZH, high(floor << 1)
	rcall	PRINT_STRING

	LCD_C	0b10001111
	lds		r16, CurrFloor 
	rcall	PRINT_NUM

PRINT_FLOOR_STATUS_EPILOGUE:
	pop		ZH
	pop		ZL
	pop		r16
	ret

PRINT_MOVE_STATUS:
	; INPUT		-> NONE
	; USES		-> r16, Z
	; CHANGES	-> NONE
	; OUTPUT	-> NONE
	; prologue
	push	r16
	push	ZL
	push	ZH

	; Body
	lds		r16, Moving
	cpi		r16, 1
	brne	PRINT_NO_MOVE
	ldi		ZL, low(str1 << 1)
	ldi		ZH, high(str1 << 1)
	rcall	PRINT_STRING
	rjmp	PRINT_MOVE_STATUS_EPILOGUE

	PRINT_NO_MOVE:
	ldi		ZL, low(str2 << 1)
	ldi		ZH, high(str2 << 1)
	rcall	PRINT_STRING

	; epilogue
	PRINT_MOVE_STATUS_EPILOGUE:
	pop		ZH
	pop		ZL
	pop		r16
	ret

PRINT_DOOR_STATUS:
	; INPUT		-> NONE
	; USES		-> r16, Z
	; CHANGES	-> NONE
	; OUTPUT	-> NONE
	; prologue
	push	r16
	push	ZL
	push	ZH

	; Body
	lds		r16, Door
	cpi		r16, 0
	breq	PRINT_DOOR_OPENING
	cpi		r16, 1
	breq	PRINT_DOOR_OPEN
	cpi		r16, 2
	breq	PRINT_DOOR_CLOSING
	ldi		r16, 0b10000111
	ldi		ZL, low(dClose << 1)
	ldi		ZH, high(dClose << 1)
	rcall	PRINT_STRING
	rjmp	PRINT_DOOR_STATUS_EPILOGUE

	PRINT_DOOR_OPENING:
	ldi		r16, 0b10000111
	ldi		ZL, low(dOpening << 1)
	ldi		ZH, high(dOpening << 1)
	rcall	PRINT_STRING
	rjmp	PRINT_DOOR_STATUS_EPILOGUE

	PRINT_DOOR_OPEN:
	ldi		r16, 0b10000111
	ldi		ZL, low(dOpen << 1)
	ldi		ZH, high(dOpen << 1)
	rcall	PRINT_STRING
	rjmp	PRINT_DOOR_STATUS_EPILOGUE

	PRINT_DOOR_CLOSING:
	ldi		r16, 0b10000111
	ldi		ZL, low(dClosing << 1)
	ldi		ZH, high(dClosing << 1)
	rcall	PRINT_STRING

	; epilogue
	PRINT_DOOR_STATUS_EPILOGUE:
	pop		ZH
	pop		ZL
	pop		r16
	ret


SWAP_MOVE_STATUS:
	; INPUT		-> NONE
	; USES		-> r16, r17
	; CHANGES	-> MoveCounter, Moving
	; Output	-> NONE
	; prologue
	push	r16
	push	r17
	push	r18
	push	r19
		
	; Body
	lds		r17, Moving					; load Moving status
	lds		r19, MoveCounter			; load moveCounter
	lds		r18, direction
	cpi		r18, 0
	breq	NO_MOVE_CHANGE
	
/*	inc		r16							; increment moveCounter
	SWAP_MOVE:
	cpi		r17, 1						; if (Moving == 1) {
	brne	NOT_MOVING
	cpi		r16, 2						;	if (moveCounter >= 2) {		// The lift has arrived at a floor
	brlt	NO_MOVE_CHANGE	
	rcall	CHECK_FLOOR
	cpi		r16, 1
	ldi		r16, 0
	brne	LEAVE_FLOOR
	ldi		r17, 0						;		Moving = 0
	rcall	ARRIVE
	rjmp	NO_MOVE_CHANGE				;}	}
	NOT_MOVING:	
	cpi		r17, 0						; else if (Moving == 0) {		
	brne	NO_MOVE_CHANGE
	cpi		r16, 5						;	if (moveCounter == 5) {		// The lift has departed a floor
	brne	NO_MOVE_CHANGE
	ldi		r17, 1						;		Moving = 1
	ldi		r16, 0						;		moveCounter = 0
	LEAVE_FLOOR:
	//rcall	DEPART						;}	}*/

	inc		r19							; increment MoveCounter

	cpi		r17, 1
	brne	NOT_MOVING					; if (Moving) {
	cpi		r19, 1						;	if (MoveCounter >= 2) {
	brlt	NO_MOVE_CHANGE
	rcall	CHECK_FLOOR
	cpi		r16, 1
	breq	STOP_AT_FLOOR				;		if (CurrFloor != Floor to stop at) {
	rcall	DEPART						;			Currfloor++
	ldi		r19, 0						;			MoveCounter = 0
	rjmp	NO_MOVE_CHANGE				;		} else {
	STOP_AT_FLOOR:						
	rcall	ARRIVE						;			remove floor from state
	rcall	DEPART						;			Currfloor++
	ldi		r17, 0						;			Moving = false
	ldi		r19, 0						;			MoveCounter = 0
										;		}
	rjmp	NO_MOVE_CHANGE				;	}
	NOT_MOVING:							; } else {
	cpi		r19, 5						;		if (MoveCounter == 5) {
	brne	NO_MOVE_CHANGE			
	ldi		r17, 1						;			Moving = true
	ldi		r19, 0						;			MoveCounter = 0

	NO_MOVE_CHANGE:
	sts		Moving,	r17
	sts		MoveCounter, r19			; save changes to variables

	; epilogue
SWAP_MOVE_STATUS_EPILOGUE:
	pop		r19
	pop		r18
	pop		r17
	pop		r16
	ret
	
CHK_DOOR_STATUS:
	; INPUT		-> NONE
	; USES		-> r16, r17, r18
	; CHANGES	-> Door
	; Output	-> NONE
	; prologue
	push	r16
	push	r17
	push	r18
		
	; Body
	lds		r16, MoveCounter			; load moveCounter
	lds		r17, Moving					; load Moving status
	lds		r18, Door

	cpi		r17, 1						; if (Moving == 1) {
	brne	CHK_DOOR_NOT_MOVING
	ldi		r18, 3						;	Door = 3;
	rjmp	CHK_DOOR_END_IF				; }

CHK_DOOR_NOT_MOVING:	
	cpi		r17, 0						; else if (Moving == 0) {
	brne	CHK_DOOR_END_IF
	cpi		r16, 0						
	breq	CHK_DOOR_OPENING
	cpi		r16, 1
	breq	CHK_DOOR_OPEN
	cpi		r16, 4
	breq	CHK_DOOR_CLOSING
	rjmp	CHK_DOOR_END_IF

	CHK_DOOR_OPENING:
	ldi		r18, 0
	rjmp	CHK_DOOR_END_IF

	CHK_DOOR_OPEN:
	ldi		r18, 1
	rjmp	CHK_DOOR_END_IF

	CHK_DOOR_CLOSING:
	ldi		r18, 2

	CHK_DOOR_END_IF:
	sts		Door, r18			; save changes to variables

	; epilogue
CHK_DOOR_STATUS_EPILOGUE:
	pop		r18
	pop		r17
	pop		r16
	ret
	
	; Right Push Button Interrupt --> Early Door Close
EXT_INT0:
	push	r16

	ldi		r16, 0xF0
	out		PORTC, r16

	lds		r16, Door
	cpi		r16, 1
	brne	EXT_INT0_EPILOGUE

	ldi		r16, 3
	sts		MoveCounter, r16
	ldi		r16, 50
	sts		TimerMoveCounter, r16

	EXT_INT0_EPILOGUE:
	; Epilogue
	pop		r16
	reti

	; Left Push Button Interrupt --> Early Door Open
EXT_INT1:
	push	r16

	ldi		r16, 0x0F
	out		PORTC, r16

	lds		r16, Door
	cpi		r16, 1
	breq	HOLD_OPEN_DOOR
	cpi		r16, 2
	breq	HOLD_OPEN_DOOR
	rjmp	EXT_INT1_EPILOGUE

	HOLD_OPEN_DOOR:
	ldi		r16, -1
	sts		MoveCounter, r16
	ldi		r16, 50
	sts		TimerMoveCounter, r16

	EXT_INT1_EPILOGUE:
	; Epilogue
	pop		r16
	reti

	MOTOR_ON:
	push	r16
	ldi		r16, 0b00001111
	out		PORTE, r16
	pop		r16
	ret

	MOTOR_OFF:
	push	r16
	ldi		r16, 0
	out		PORTE, r16
	pop		r16
	ret