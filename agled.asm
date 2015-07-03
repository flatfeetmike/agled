;**********************************************************************
;   This file is a basic code template for assembly code generation   *
;   on the PIC12F675. This file contains the basic code               *
;   building blocks to build upon.                                    *
;                                                                     *
;   Refer to the MPASM User's Guide for additional information on     *
;   features of the assembler (Document DS33014).                     *
;                                                                     *
;   Refer to the respective PIC data sheet for additional             *
;   information on the instruction set.                               *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Filename:	    agled.asm                                         *
;    Date:          06/22/2015                                        *
;    File Version:  1                                                 *
;                                                                     *
;    Author: M10                                                      *
;    Company:                                                         *
;                                                                     *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Files Required: P12F675.INC                                      *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Notes:                                                           *
;      Clock source: internal 4 mhz osc                               *
;                                                                     *
;          PIC12F675 Pinout for this project                          *
;          ----------                                                 *
; 3V-- Vdd |1      8| GND                                             *
;      GP5 |2      7| GP0 --> IR LED output                           *
;      GP4 |3      6| GP1 <-- Button 1 input <-- GND                  *
;      GP3 |4      5| GP2 <-- Button 2 input <-- GND                  *
;          ----------                                                 *
;                                                                     *
;**********************************************************************
; fan2 up   - 0x6c 0x6e 0x36 0x00
; fan2 down - 0x6c 0x6e 0xb6 0x00
; fan2 led  - 0x6c 0x6e 0x42 0x00
; fan2 mem  - 0x6c 0x6e 0x52 0x00
;**********************************************************************
	list      p=12f675		; list directive to define processor
	#include <p12f675.inc>  ; processor specific variable definitions

	errorlevel  -302        ; suppress message 302 from list file
	radix	dec				; set the default radix

	__CONFIG   _CP_OFF & _CPD_OFF & _BODEN_OFF & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT 

; '__CONFIG' directive is used to embed configuration word within .asm file.
; The lables following the directive are located in the respective .inc file.
; See data sheet for additional information on configuration word settings.


;***** VARIABLE DEFINITIONS
w_temp		EQU		0x20    ; variable used for context saving 
status_temp	EQU     0x21    ; variable used for context saving

d1			equ		0x22	; temp counter for delay loop
d2			equ		0x23	; temp counter for delay loop
d3			equ		0x24	; temp counter for delay loop
d4			equ		0x25	; temp counter for delay loop
c1			equ		0x26	; temp counter for ir loop
c2			equ		0x27	; temp counter for 8 bit loop
ircode		equ		0x28	; one octet ir code

;**********************************************************************
	ORG     0x000			; processor reset vector
	goto    main            ; go to beginning of program

	ORG     0x004           ; interrupt vector location
	movwf   w_temp          ; save off current W register contents
	movf	STATUS,w        ; move status register into W register
	movwf	status_temp     ; save off contents of STATUS register

; isr code can go here or be located as a call subroutine elsewhere

	movf    status_temp,w   ; retrieve copy of STATUS register
	movwf	STATUS          ; restore pre-isr STATUS register contents
	swapf   w_temp, f
	swapf   w_temp, w       ; restore pre-isr W register contents
	retfie                  ; return from interrupt

; these first 4 instructions are not required if the internal oscillator is not used
main
	call    0x3FF           ; retrieve factory calibration value
	bsf     STATUS, RP0     ; set file register bank to 1 
	movwf   OSCCAL          ; update register with factory cal value 
	bcf     STATUS, RP0     ; set file register bank to 0
; remaining code goes here
	clrf	GPIO			; clear all gpio ports
	movlw	b'00000111'		; disable comparators
	movwf	CMCON			;

	bsf		STATUS, RP0		; set file register bank to 1
	clrf	ANSEL			; disable adc on pic12f675
	
	movlw	b'00111110'		; set GP<5:1> as inputs, GP<0> as output
	movwf	TRISIO			;
	
	movlw	b'00110110'		; set weak pull-up on selected pins
	movwf	WPU				;
	
	movlw	b'01111111'		; enable pull-ups on inputs
	movwf	OPTION_REG		;
	
	movlw	b'00110110'		; enable interrupt-on-change on selected pins
	movwf	IOC				;

	bcf     STATUS, RP0		; set file register bank to 0

	call	delay2			; place a long delay here for stability with initial sleep
	call	delay2
	call	delay2

	bcf		INTCON, GPIF	; clear gpio port change interrupt flag
	bsf		INTCON, GPIE	; enable gpio port change interrupt

main_loop
	clrf	GPIO			; clear all gpio bits
	movf	GPIO, w			; read gpio registers to end mismatch condition
	bcf		INTCON, GPIF	; clear gpio port change interrupt flag
	sleep					; sleep now
							; ---------------------------
							; resume after wake up, return from isr

	btfss	GPIO, 1			; button 1 pressed
	goto	button1

	btfss	GPIO, 2			; button 2 pressed
	goto	button2

	call	delay2
	goto	main_loop		; goback and sleep

button1
	call	send_ir			; send the ir command
	goto	main_loop
button2
	call	send_ir			; send the ir command
	goto	main_loop

send_ir
	call	send_irleader
	movlw	0x6c			; fan2f octet 1
	movwf	ircode
	call	send_ircode
	movlw	0x6e			; fan2f octet 2
	movwf	ircode
	call	send_ircode
	movlw	0xb6			; fan2f octet 3
	movwf	ircode
	call	send_ircode
	movlw	0x00			; fan2f octet 4
	movwf	ircode
	call	send_ircode
	call	send_zero		; stop bit

	call	delay4			; send the 2nd copy after a delay

	call	send_irleader
	movlw	0x6c			; fan2f octet 1
	movwf	ircode
	call	send_ircode
	movlw	0x6e			; fan2f octet 2
	movwf	ircode
	call	send_ircode
	movlw	0xb6			; fan2f octet 3
	movwf	ircode
	call	send_ircode
	movlw	0x00			; fan2f octet 4
	movwf	ircode
	call	send_ircode
	call	send_zero		; stop bit

	call	delay2
	return

send_irleader
	movlw	101
	movwf	c1
send_irleader_loop1
	call	send_38kpulse
	call	send_38kpulse
	decfsz	c1, f
	goto	send_irleader_loop1
	movlw	4
	movwf	c1
send_irleader_loop2
	call	delay3
	decfsz	c1, f
	goto	send_irleader_loop2
	return

send_ircode
	movlw	8
	movwf	c2
send_ircode_loop
	btfsc	ircode, 7		; check the msb
	call	send_one
	btfss	ircode, 7
	call	send_zero
	rlf		ircode, f		; rotate left
	decfsz	c2, f
	goto	send_ircode_loop
	return

send_zero
	movlw	27
	movwf	c1
send_zero_loop
	call	send_38kpulse
	decfsz	c1, f
	goto	send_zero_loop
	call	delay1
	call	delay1
	return

send_one
	movlw	27
	movwf	c1
send_one_loop
	call	send_38kpulse
	decfsz	c1, f
	goto	send_one_loop
	call	delay1
	call	delay1
	call	delay1
	call	delay1
	return

send_38kpulse				; 40khz actual (25us period)
	movlw	b'00000001'		; gpio 1
	movwf	GPIO			; turn on the led
	nop
	nop
	nop
	nop
	nop
	clrf	GPIO			; turn off the led
	goto $+1				; consumes 2 x nop cycles
	goto $+1
	goto $+1
	goto $+1
	goto $+1
	return

delay1						; 'wait' routine
	movlw	143
	movwf	d1
delay1_loop
	decfsz	d1, f
	goto delay1_loop
	return

delay2						; 'wait2', calls delay1 100 times
	movlw	100
	movwf	d2
delay2_loop
	call	delay1
	decfsz	d2, f
	goto	delay2_loop
	return

delay3						; delay used in leader space
	movlw	215
	movwf	d3
delay3_loop
	decfsz	d3, f
	goto	delay3_loop
	return

delay4						; delay between two consecutive ir codes
	movlw	35
	movwf	d4
delay4_loop
	call 	delay1
	decfsz	d4, f
	goto	delay4_loop
	return

; initialize eeprom locations
	ORG	0x2100
	DE	0x00, 0x01, 0x02, 0x03, 0x04

	END                     ; directive 'end of program'
