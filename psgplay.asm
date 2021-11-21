.include	"m48def.inc"

;;;   ATmega48 <=> AY-3-8910(A)
;;; --------------------------
;;;    PD7-PD0 <=> D7-D0
;;; PB0 (CLKO) <-> φ (clock)
;;;	   PB6 <-> BC1
;;;	 (Vcc) <-> BC2
;;;	   PB7 <-> BDIR

#define DEBUG

.include "psgplay-commands.asm"

.def	PTR_AH		= r1
.def	PTR_AL		= r0
.def	COUNT_AH	= r3
.def	COUNT_AL	= r2

.def	PTR_BH		= r5
.def	PTR_BL		= r4
.def	COUNT_BH	= r7
.def	COUNT_BL	= r6

.def	PTR_CH		= r9
.def	PTR_CL		= r8
.def	COUNT_CH	= r11
.def	COUNT_CL	= r10

.def	VOL_A		= r12
.def	VOL_B		= r13
.def	VOL_C		= r14

.def	NOTE		= r19
.def	CHANNEL		= r20
.def	EXIT_STATUS	= r21

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
	rjmp	TIMER0_OVF
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

#ifdef DEBUG
	in	r16, DDRB
	ori	r16, (1<<PB1)
	out	DDRB, r16
#endif

	;; initialize AY-3-8910
	rcall	AY_INIT

	;; multiplex
	;; disable noise
	ldi	r24, 7
	ldi	r22, 0x38	; = 0b 00|11 1|000 (s. datasheet)
	rcall	sound

	;; volume / envelope
	ldi	r16, V_DEFAULT
	mov	VOL_A, r16
	mov	VOL_B, r16
	mov	VOL_C, r16

	ldi	r24, 8
	mov	r22, VOL_A
	rcall	sound
	ldi	r24, 9
	mov	r22, VOL_B
	rcall	sound
	ldi	r24, 10
	mov	r22, VOL_C
	rcall	sound

DATA_INIT:
	clr	EXIT_STATUS
	clr	XH
	clr	YH

	;; set address of music data and first timer value (dummy)
	;; Ch. A
	ldi	r17, high(MUSICDATA_CH0 * 2)
	ldi	r16, low(MUSICDATA_CH0 * 2)
	movw	PTR_AH:PTR_AL, r17:r16
	clr	COUNT_AH
	clr	COUNT_AL

	;; Ch. B
	ldi	r17, high(MUSICDATA_CH1 * 2)
	ldi	r16, low(MUSICDATA_CH1 * 2)
	movw	PTR_BH:PTR_BL, r17:r16
	clr	COUNT_BH
	clr	COUNT_BL

	;; Ch. C
	ldi	r17, high(MUSICDATA_CH2 * 2)
	ldi	r16, low(MUSICDATA_CH2 * 2)
	movw	PTR_CH:PTR_CL, r17:r16
	clr	COUNT_CH
	clr	COUNT_CL

TIMER_INIT:
	ldi	r16, (1<<CS00)
	out	TCCR0B, r16	; no prescaling
	ldi	r16, (1<<TOV0)
	out	TIFR0, r16	; clear TOV0 (clear pending interrupts)
	ldi	r16, (1<<TOIE0)
	sts	TIMSK0, r16	; enable Timer/Counter0 Overflow Interrupt

	sei

LOOP:
	cpi	EXIT_STATUS, 0x07
	breq	EXIT
	rjmp	LOOP

EXIT:
#ifdef DEBUG
	sbi	PORTB, PB1
#endif

	clr	r16
	sts	TIMSK0, r16	; disable Timer/Counter0 Overflow Interrupt
	cli

EXIT_LOOP:
	rjmp	EXIT_LOOP


;;; ============================================================
;;; timer

TIMER0_OVF:
	push	ZH
	push	ZL
	in	ZL, SREG
	push	ZL

#ifdef DEBUG
	sbic	PORTB, PB1
	rjmp	_DEBUG_TIMER_CLEAR_LED

_DEBUG_TIMER_SET_LED:
	sbi	PORTB, PB1
	rjmp	_DEBUG_TIMER_EXIT

_DEBUG_TIMER_CLEAR_LED:
	cbi	PORTB, PB1

_DEBUG_TIMER_EXIT:
#endif

_TIMER_CH_A:
	;; decrement counter
	sbrc	EXIT_STATUS, 0
	rjmp	_TIMER_CH_B

	movw	ZH:ZL, COUNT_AH:COUNT_AL
	sbiw	ZH:ZL, 1
	movw	COUNT_AH:COUNT_AL, ZH:ZL
	brpl	_TIMER_CH_B
	ldi	CHANNEL, 0x00
	rcall	PLAY_NEXT_NOTE

_TIMER_CH_B:
	sbrc	EXIT_STATUS, 1
	rjmp	_TIMER_CH_C

	movw	ZH:ZL, COUNT_BH:COUNT_BL
	sbiw	ZH:ZL, 1
	movw	COUNT_BH:COUNT_BL, ZH:ZL
	brpl	_TIMER_CH_C
	ldi	CHANNEL, 0x01
	rcall	PLAY_NEXT_NOTE

_TIMER_CH_C:
	sbrc	EXIT_STATUS, 2
	rjmp	_TIMER_EXIT

	movw	ZH:ZL, COUNT_CH:COUNT_CL
	sbiw	ZH:ZL, 1
	movw	COUNT_CH:COUNT_CL, ZH:ZL
	brpl	_TIMER_EXIT
	ldi	CHANNEL, 0x02
	rcall	PLAY_NEXT_NOTE

_TIMER_EXIT:
	pop	ZL
	out	SREG, ZL
	pop	ZL
	pop	ZH

	reti

;;; ============================================================
;;; main routine
;;; ============================================================

PLAY_NEXT_NOTE:
	;; X: address of register (Ch. A: 0, Ch. B: 4, Ch. C: 8)
	mov	XL, CHANNEL
	lsl	XL
	lsl	XL

	;; read address of music data from register
	ld	ZL, X+
	ld	ZH, X+

	;; read tone number from flash
	lpm	NOTE, Z+

_CMD_EOC:
	cpi	NOTE, CMD_EOC
	brne	_CMD_VOL

	;; r24 = 1 << CHANNEL
	mov	r16, CHANNEL
	ldi	r24, 1
_SET_STATUS:
	cpi	r16, 0
	breq	_EXIT_CMD
	lsl	r24
	dec	r16
	rjmp	_SET_STATUS

_EXIT_CMD:
	or	EXIT_STATUS, r24

	;; volume to 0
	ldi	r24, 8
	add	r24, CHANNEL
	ldi	r22, 0x0
	rcall	sound

	ret

_CMD_VOL:
	cpi	NOTE, CMD_VOL
	brne	_CMD_ENV_S

	;; read next byte
	lpm	r22, Z+
	andi	r22, 0x7f

	ldi	YL, 12
	add	YL, CHANNEL
	st	Y, r22

	ldi	r24, 8
	add	r24, CHANNEL
	rcall	sound

	;; execute next command immediately
	rjmp	_NEXT_CMD

_CMD_ENV_S:
	cpi	NOTE, CMD_ENV_S
	brne	_CMD_ENV_P

	lpm	r22, Z+
	andi	r22, 0x7f
	ori	r22, 0x10

	ldi	YL, 12
	add	YL, CHANNEL
	st	Y, r22

	rjmp	_NEXT_CMD

_CMD_ENV_P:
	cpi	NOTE, CMD_ENV_P
	brne	_CMD_REST

	lpm	r22, Z+
	ldi	r24, 12
	rcall	sound
	lpm	r22, Z+
	ldi	r24, 11
	rcall	sound

_NEXT_CMD:
	;; store address
	st	-X, ZH
	st	-X, ZL

	rjmp	PLAY_NEXT_NOTE

_CMD_REST:
	cpi	NOTE, CMD_REST
	brne	_CMD_CONT

	;; set REST flag in volume-register
	ldi	YL, 12
	add	YL, CHANNEL
	ld	r16, Y
	ori	r16, 0x80
	st	Y, r16

	ldi	r24, 8
	add	r24, CHANNEL
	ldi	r22, 0x0
	rcall	sound

	rjmp	_SET_COUNTER

_CMD_CONT:
	cpi	NOTE, CMD_CONT
	brne	_CMD_PLAY_NOTE

	rjmp	_SET_COUNTER

_CMD_PLAY_NOTE:
	;; restore volume/envelope
	ldi	YL, 12
	add	YL, CHANNEL
	ld	r22, Y

	;; drop 7th bit (REST flag)
	andi	r22, 0x7f
	st	Y, r22

	;; register of volume
	ldi	r24, 8
	add	r24, CHANNEL
	rcall	sound

	;; if envelop
	sbrs	r22, 4
	rjmp	_READ_TONEDATA
	andi	r22, 0x0f
	ldi	r24, 13
	rcall	sound

_READ_TONEDATA:
	;; read tone data
	push	ZH
	push	ZL

	;; read corresponding tone data from flash
	ldi	ZH, high(TONEDATA * 2)
	ldi	ZL, low(TONEDATA * 2)

	lsl	NOTE		; NOTE *= 2 (1 tone = 2 byte data)
	add	ZL, NOTE	; Z = base address (TONEDATA) + offset (note number * 2)
	clr	NOTE
	adc	ZH, NOTE

	;; read tone value (coarse) and send to PSG
	mov	r24, CHANNEL
	lsl	r24
	inc	r24		; r24 = 2 * CHANNEL + 1
	lpm	r22, Z+
	rcall	sound

	;; read tone value (fine)
	dec	r24		; r24 = 2 * CHANNEL
	lpm	r22, Z+
	rcall	sound

	pop	ZL
	pop	ZH

_SET_COUNTER:
	;; read further 2 bytes and store to wait counter
	adiw	XH:XL, 2
	lpm	r24, Z+
	st	-X, r24
	lpm	r24, Z+
	st	-X, r24

	st	-X, ZH
	st	-X, ZL

	ret

;;; ============================================================
;;; subroutines to control PSG
;;; ============================================================

AY_INIT:
	;; hardware setup
	in	r16, AY_BC_DDR
	ori	r16, (1<<AY_BC1)|(1<<AY_BDIR)
	out	AY_BC_DDR, r16

	ldi	r16, 0xff
	out	AY_DDR, r16

	rcall	AY_BC_inactive

AY_RESET_REGS:
	;;; clear all registers
	clr	r22
	ldi	r24, 16
_AY_RESET_REGS:
	dec	r24
	rcall	sound
	cpse	r24, r22	; check if r24 == 0
	rjmp	_AY_RESET_REGS

	ret

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

;;; ============================================================
.include "musicdata.asm"

TONEDATA:
.include "tonedata.asm"
