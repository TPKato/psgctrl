.include	"m48def.inc"

;;;   ATmega48 <=> AY-3-8910(A)
;;; --------------------------
;;;    PD7-PD0 <=> D7-D0
;;; PB0 (CLKO) <-> φ (clock)
;;;	   PB6 <-> BC1
;;;	 (Vcc) <-> BC2
;;;	   PB7 <-> BDIR

.equ	AY_PORT		= PORTD
.equ	AY_DDR		= DDRD
.equ	AY_PIN		= PIND

.equ	AY_BC_PORT	= PORTB
.equ	AY_BC_DDR	= DDRB
.equ	AY_BC1		= 6
.equ	AY_BDIR		= 7

	; interupt vectors
	rjmp	RESET
	reti		;rjmp	INT0
	reti		;rjmp	INT1
	reti		;rjmp	PCINT0
	reti		;rjmp	PCINT1
	reti		;rjmp	PCINT2
	reti		;rjmp	WDT
	reti		;rjmp	TIMER2_COMPA
	reti		;rjmp	TIMER2_COMPB
	reti		;rjmp	TIMER2_OVF
	reti		;rjmp	TIMER1_CAPT
	reti		;rjmp	TIMER1_COMPA
	reti		;rjmp	TIMER1_COMPB
	reti		;rjmp	TIMER1_OVF
	reti		;rjmp	TIMER0_COMPA
	reti		;rjmp	TIMER0_COMPB
	reti		;rjmp	TIMER0_OVF
	reti		;rjmp	SPI_STC
	reti		;rjmp	USART_RX
	reti		;rjmp	USART_UDRE
	reti		;rjmp	USART_TX
	reti		;rjmp	ADC
	reti		;rjmp	EE_READY
	reti		;rjmp	ANALOG_COMP
	reti		;rjmp	TWI
	reti		;rjmp	SPM_READY

RESET:
	ldi	r16, high(RAMEND)
	out	SPH, r16
	ldi	r16,low(RAMEND)
	out	SPL, r16

	in	r16, AY_BC_DDR
	ori	r16, (1<<AY_BC1)|(1<<AY_BDIR)
	out	AY_BC_DDR, r16

	ldi	r16, 0xff
	out	AY_DDR, r16

	rcall	AY_BC_inactive

MAIN:
	;; tone (fine)
	ldi	r24, 0
	ldi	r22, 0x8e
	rcall	sound

	;; tone (coarse)
	ldi	r24, 1
	ldi	r22, 0
	rcall	sound

	;; mixer control
	;; disable noise
	ldi	r24, 7
	ldi	r22, 0x38	; = 0b 00|11 1|000 (s. datasheet)
	rcall	sound

	;; volume / envelope
	ldi	r24, 8
	ldi	r22, 15
	rcall	sound
	ldi	r24, 9
	ldi	r22, 0
	rcall	sound
	ldi	r24, 10
	ldi	r22, 0
	rcall	sound

	;; envelope period (fine)
	;; ldi	r24, 11
	;; ldi	r22, 0
	;; rcall	sound

	;; envelope period (coarse)
	;; ldi	r24, 12
	;; ldi	r22, 5
	;; rcall	sound

	;; envelope shape
	;; ldi	r24, 13
	;; ldi	r22, 14
	;; rcall	sound

loop:
	rjmp	loop

;;; ============================================================
;;; subroutines to control PSG
;;; ============================================================

;;; void sound(unsigned char address, unsigned char data)
;;; r24: addr
;;; r22: data
sound:
	;; send address
	rcall	AY_BC_address
	out	AY_PORT, r24
	rcall	AY_BC_inactive
	;; send data
	out	AY_PORT, r22
	rcall	AY_BC_write
	rcall	AY_BC_inactive
	ret

;;; Bus control
;;;
;;; BDIR BC1
;;;   0	  0  : inactive
;;;   0	  1  : read from PSG
;;;   1	  0  : write to PSG
;;;   1	  1  : latch address
AY_BC_inactive:
	cbi	AY_BC_PORT, AY_BC1
	cbi	AY_BC_PORT, AY_BDIR
	ret

AY_BC_read:
	sbi	AY_BC_PORT, AY_BC1
	cbi	AY_BC_PORT, AY_BDIR
	ret

AY_BC_write:
	cbi	AY_BC_PORT, AY_BC1
	sbi	AY_BC_PORT, AY_BDIR
	ret

AY_BC_address:
	sbi	AY_BC_PORT, AY_BC1
	sbi	AY_BC_PORT, AY_BDIR
	ret
