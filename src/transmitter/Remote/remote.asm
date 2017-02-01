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

.equ	RobotID = $66			; set robot address/ID
; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ	Freeze =  $F8									;0b11111000	Freeze Command


.equ	Forward = 0		; PORTD PIN 0 as forward input
.equ	Reverse = 1		; PORTD PIN 1 as reverse input
.equ	TRight = 6		; PORTD PIN 6 as turn right input
.equ	TLeft = 7		; PORTD PIN 7 as turn left input
.equ	THalt = 5		; PORTD PIN 5 as hult input
.equ	TFreeze = 4		; PORTD	PIN 4 as freeze input
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

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

	;Other
;***********************************************************
;*	Main Program	(Check input from pressing buttons)
;***********************************************************
MAIN:
		IN		MPR, PIND		; Get inputs from PORTD
		ANDI	MPR, (1<<Forward)|(1<<Reverse)|(1<<TRight)|(1<<TLeft)|(1<<THalt)|(1<<TFreeze)	;$E3		; MASK out Inputs

		CPI		MPR, $F2		; Compare ob11110010 (Forward)
		BRNE	ChkReverse		
		LDI		CMD, MovFwd		; save action command
		RCALL	SendID

ChkReverse: 
		CPI		MPR, $F1		; Compare ob11110001 (Reverse)
		BRNE	ChkTRight
		LDI		CMD, MovBck
		RCALL	SendID

ChkTRight: 
		CPI		MPR, $B3		; Compare ob10110011 (Turn right)
		BRNE	ChkTLeft
		LDI		CMD, TurnR
		RCALL	SendID

ChkTLeft: 
		CPI		MPR, $73		; Compare ob01110011 (Turn left)
		BRNE	ChkHalt
		LDI		CMD, TurnL
		RCALL	SendID

ChkHalt:	
		CPI		MPR, $D3		; Compare ob11010011 (Halt)
		BRNE	ChkFreeze
		LDI		CMD, Halt
		RCALL	SendID

ChkFreeze:
		CPI		MPR, $E3		; Compare ob11100011 (Halt)
		BRNE	SKIP
		LDI		CMD, Freeze
		RCALL	SendID

SKIP:	
		RJMP	MAIN



;***********************************************************
;*	Functions and Subroutines
;***********************************************************
SendID:
		LDS		mpr, UCSR1A
		SBRS	mpr, UDRE1		; check if transmit buffer is empty
		RJMP	SendID			; loop over if buffer is empty

		LDI		mpr, RobotID	; Send Robot Address
		STS		UDR1, mpr
		RCALL	SendCMD

SendCMD:
		LDS		mpr, UCSR1A
		SBRS	mpr, UDRE1		; check if transmit buffer is empty
		RJMP	SendCMD			; loop over if buffer is empty

		STS		UDR1, CMD		; send action command

		OUT		PORTB, CMD		; for test	
		RJMP	MAIN




;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************
