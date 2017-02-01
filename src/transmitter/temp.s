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

.equ	Forward = 0		; PORTD PIN 0 as forward input
.equ	Reverse = 1		; PORTD PIN 1 as reverse input
.equ	TRight = 6		; PORTD PIN 6 as turn right input
.equ	TLeft = 7		; PORTD PIN 7 as turn left input
.equ	THalt = 2		; PORTD PIN 3 as hult input
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
		LDI		mpr, high(416)
		STS		UBRR1H, mpr
		LDI		mpr, low(416)
		STS		UBRR1L, mpr

		;Enable transmitter
		LDI		mpr, (1<<RXCIE1|1<<RXEN1|1<<TXEN1)
		STS		UCSR1B, mpr

		;Set frame format: 8 data bits, 2 stop bits
		LDI		mpr, (0<<UMSEL0 | 1<<USBS0 | 1<<UCSZ01 | 1<<UCSZ00)
		STS		UCSR1C, mpr

	;Other
;***********************************************************
;*	Main Program	(Check input from pressing buttons)
;***********************************************************
MAIN:
		IN		MPR, PIND		; Poll PortD for inputs
		ANDI	MPR, $F3		; Isolate Inputs

		CPI		MPR, $E3
		BRNE	ChkReverse
		RCALL	Trans_Forward

ChkReverse: 
		CPI		MPR, $D3
		BRNE	ChkTRight
		RCALL	Trans_Reverse

ChkTRight: 
		CPI		MPR, $B3
		BRNE	ChkTLeft
		RCALL	Trans_Right

ChkTLeft: 
		CPI		MPR, $73
		BRNE	ChkHalt
		RCALL	Trans_Left

ChkHalt:	
		CPI		MPR, $F1
		BRNE	SKIP
		RCALL	Trans_Halt

SKIP:	
		RJMP	MAIN



;***********************************************************
;*	Functions and Subroutines
;***********************************************************
SendID:
		RCALL	Wait_Trans
		LDI		mpr, RobotID
		STS		UDR1, mpr
		RET

Trans_Forward:
		RCALL	SendID
		RCALL	Wait_Trans
		LDI		mpr, MovFwd
		STS		UDR1, mpr		; send command

		OUT		PORTB, mpr		; for test	
		RET

Trans_Reverse:
		RCALL	SendID
		RCALL	Wait_Trans
		LDI		mpr, MovBck
		STS		UDR1, mpr		; send command

		OUT		PORTB, mpr		; for test	
		RET

Trans_Right:
		RCALL	SendID
		RCALL	Wait_Trans
		LDI		mpr, TurnR
		STS		UDR1, mpr		; send command

		OUT		PORTB, mpr		; for test	
		RET

Trans_Left:
		RCALL	SendID
		RCALL	Wait_Trans
		LDI		mpr, TurnL
		STS		UDR1, mpr		; send command

		OUT		PORTB, mpr		; for test	
		RET

Trans_Halt:
		RCALL	SendID
		RCALL	Wait_Trans
		LDI		mpr, Halt
		STS		UDR1, mpr		; send command

		OUT		PORTB, mpr		; for test	
		RET

Wait_Trans:
		LDS		mpr, UCSR1A
		SBRS	mpr, UDRE1		; check if transmit buffer is empty
		RJMP	Wait_Trans		; loop over if buffer is empty
		RET







;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************
