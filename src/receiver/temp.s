;***********************************************************
;*
;*	robot.asm
;*
;*	ECE375 - Lab 8 Robot 
;*
;*	This is the RECEIVE robot.asm file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Enter your name
;*	   Date: Enter Date
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	waitcnt = r17			; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter
.def	MSG = r20
.def	OldMSG = r21
.def	IDtemp = r22
.def	FreezeFlag = r23
.def	FreezeCNT = r24


.equ	Halt_WTime = 140				; Time to wait in wait loop (2.5s)
.equ	Whisker_WTime = 100				; Time to wait in wait loop (1.0s)

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	BotAddress = $66		;(Enter your robot's address here (8 bits))
.equ	FreezeSIGN = 0b01010101				;Freeze signal from other robot
;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code
.equ	FreezeCMD = $F8						;ob11111000	Freeze command (from remote)
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

;Should have Interrupt vectors for:

;- Left whisker
.org	$0002
		RCALL 	HitLeft			; Reset interrupt
		RETI

;- Right whisker
.org	$0004
		RCALL 	HitRight		; Reset interrupt
		RETI

;- USART receive
.org	$003C
		RCALL	ChkReceived
		RETI


.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	LDI		mpr, low(RAMEND)
	OUT		SPL, mpr
	LDI		mpr, high(RAMEND)
	OUT		SPH, mpr

	;I/O Ports
	LDI		mpr, $FF		; set PORTB as output
	OUT		DDRB, mpr

	LDI		mpr, $00		; set PORTD PIN 0&1 as input (Right&Left whisker)
	OUT		DDRD, mpr
	LDI		mpr, $FF		; Initialize Port D Data Register
	OUT		PORTD, mpr		; so all Port D inputs are Tri-State

	;USART1
		;Set baudrate at 2400bps
		LDI		mpr, (1<<U2X1)	; set double data rate
		STS		UCSR1A, mpr

		LDI		mpr, high(832)
		STS		UBRR1H, mpr
		LDI		mpr, low(832)
		STS		UBRR1L, mpr

		;Enable receiver and enable receive interrupts
		LDI		mpr, (1<<RXCIE1 | 1<<RXEN1 | 1<<TXEN1)
		STS		UCSR1B, mpr

		;Set frame format: 8 data bits, 2 stop bits
		LDI		mpr, (0<<UMSEL1 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10)
		STS		UCSR1C, mpr
		
	;Other
		LDI		mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)	; using falling edge
		STS		EICRA, mpr

		; Enable External interrupt requests 0 and 1
		LDI		mpr, (1<<INT0)|(1<<INT1)
		OUT		EIMSK, mpr
		
		CLR		IDtemp
		CLR		FreezeFlag
		CLR		FreezeCNT

		LDI		MSG, MovFwd		; initialize first action
		OUT		PORTB, MSG
		MOV		OldMSG, MSG

		SEI		; enable global interrupt
;***********************************************************
;*	Main Program
;***********************************************************

MAIN:	
		OUT		PORTB, OldMSG
		RJMP	MAIN				; otherwise loop over until interrupt triggered

ChkReceived:
		LDS		MSG, UDR1			; receive new signal/message (FreezeSIGN/ID)

		SBRS	MSG, 7				; check MSB, 0 (Freeze or ID) or 1 (Action)
		RCALL	ChkFreeze			; MSB is 0
		RCALL	ChkAction			; check action if MSB is 1

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

ChkFreeze:
		LDI		mpr, FreezeSIGN
		CP		mpr, MSG				; check if the MSG is freeze signal
		BRNE	ChkRobotID				; branch check id if not equal

		CPI		FreezeFlag, $01			;otherwise check if is sent by itself
		BREQ	SKIPFreeze

		CPI		FreezeCNT, 6 			; check if freeze up to 3 times
		BREQ	FrozenAct

		LDI		mpr, Halt				; otherwise, halt robot
		OUT		PORTB, mpr
		LDI		waitcnt, Halt_WTime		; Wait for 2.5 second
		RCALL	Wait					; Call wait function
		RCALL	Wait					; Call wait function 2nd time (5s)

		LDI		mpr, 1
		ADD		FreezeCNT, mpr			; increment counter 
		;OUT		PORTB, OldMSG
		RET

SKIPFreeze:
		CLR		FreezeFlag
		RJMP	MAIN

FrozenAct:
		LDI		mpr, Halt				; otherwise, halt robot
		OUT		PORTB, mpr
		RJMP	FrozenAct				; inifitely loop


ChkRobotID:
		LDI		mpr, BotAddress			; 
		CP		mpr, MSG				; check robot ID
		BRNE	SKIP					; if not matched, return

		MOV		IDtemp, MSG				; if matched, save ID
		RCALL	ChkReceived				; RJMP and get the next byte of message


ChkAction:
		LDI		mpr, BotAddress			; 
		CP		mpr, IDtemp				; check robot ID for previous byte (ID)
		BRNE	SKIP					; skip if not equal
										; otherwise, output action command
		
		CLR		IDtemp					; clear ID after output
		LDI		mpr, FreezeCMD
		CP		mpr, MSG				; check current msg with freeze command
		BREQ	SendFreeze				; if equal then let robot send freeze signal


		LSL		MSG						; otherwise, left shift action command
		MOV		OldMSG, MSG
		
		;OUT		PORTB, MSG				; output action

		RET

SKIP:	RET


SendFreeze:	
		LDS		mpr, UCSR1A
		SBRS	mpr, UDRE1
		RJMP	SendFreeze

		LDI		mpr, FreezeSIGN
		STS		UDR1, mpr	
		LDI		FreezeFlag, $01


		RET		



;***********************************************************
;***********************************************************
;*	Additional Program Includes
;***********************************************************
HitRight:
		push	mpr						; Save mpr register
		push	waitcnt					; Save wait register
		in		mpr, SREG				; Save program state
		push	mpr			;

		; Move Backwards for a second
		ldi		mpr, MovBck				; Load Move Backward command
		out		PORTB, mpr				; Send command to port
		ldi		waitcnt, Whisker_WTime			; Wait for 1 second
		rcall	Wait					; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL				; Load Turn Left Command
		out		PORTB, mpr				; Send command to port
		ldi		waitcnt, Whisker_WTime			; Wait for 1 second
		rcall	Wait					; Call wait function

		; Resume previous action again	
		;out		PORTB, OldMSG				; Send command to port

		pop		mpr						; Restore program state
		out		SREG, mpr	;
		pop		waitcnt					; Restore wait register
		pop		mpr						; Restore mpr
		ret								; Return from subroutine


HitLeft:
		push	mpr						; Save mpr register
		push	waitcnt					; Save wait register
		in		mpr, SREG				; Save program state
		push	mpr			;

		; Move Backwards for a second
		ldi		mpr, MovBck				; Load Move Backward command
		out		PORTB, mpr				; Send command to port
		ldi		waitcnt, Whisker_WTime			; Wait for 1 second
		rcall	Wait					; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR				; Load Turn Left Command
		out		PORTB, mpr				; Send command to port
		ldi		waitcnt, Whisker_WTime			; Wait for 1 second
		rcall	Wait					; Call wait function

		; Resume previous action again	
		;out		PORTB, OldMSG				; Send command to port

		pop		mpr						; Restore program state
		out		SREG, mpr	;
		pop		waitcnt					; Restore wait register
		pop		mpr						; Restore mpr
		ret								; Return from subroutine



;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine