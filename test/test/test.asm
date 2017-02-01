;***********************************************************
;*
;*	Enter remote.asm
;*
;*	ECE375 - Lab 8 Remote
;*
;*	This is the TRANSMIT remote.asm file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Jiongcheng Luo
;*	   Date: 2/24/16
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	CMD = r17

.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	FreezeSIGN = 0b01010101				;Freeze signal from other robot

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0002
		RCALL 	Hit			; Reset interrupt
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

	;I/O Ports (For Remote, input as PORTD)
	LDI		mpr, $00
	OUT		DDRD, mpr		;set PORTD as input

	LDI		mpr, $FF		;set PORTB as output for test only
	OUT		DDRB, mpr


	;USART1
		;Set baudrate at 2400bps
		LDI		mpr, (1<<U2X1)	; set double data rate
		STS		UCSR1A, mpr

		LDI		mpr, high(832)
		STS		UBRR1H, mpr
		LDI		mpr, low(832)
		STS		UBRR1L, mpr

		;Enable transmitter
		LDI		mpr, (1<<TXEN1)
		STS		UCSR1B, mpr

		;Set frame format: 8 data bits, 2 stop bits
		LDI		mpr, (0<<UMSEL1 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10)
		STS		UCSR1C, mpr

		LDI		mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)	; using falling edge
		STS		EICRA, mpr

		; Enable External interrupt requests 0 and 1
		LDI		mpr, (1<<INT0)
		OUT		EIMSK, mpr

		sei
	;Other
;***********************************************************
;*	Main Program	(Check input from pressing buttons)
;***********************************************************
MAIN:
		rjmp	MAIN

Hit:
		LDI		mpr, FreezeSIGN
		STS		UDR1, mpr
		OUT		PORTB, mpr
		RET

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************
