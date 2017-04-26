;---------------------------------------------------------------
; Console I/O through the on board UART for MSP 430g2553 on the launchpad
; Do not to forget to set the jumpers on the launchpad board to the vertical
; direction for hardware TXD and RXD UART communications.  This program
; uses a hyperterminal program connected to the USB Code Composer
; interface com port .  Use the Device manager under the control panel
; to determine the com port address.  RS232 settings 1 stop, 8 data,
; no parity, 9600 baud, and no handshaking.
;---------------------------------------------------------------

;-------------------------------------------------------------------------------
;            .cdecls C,LIST,"msp430.h"       ; Include device header file
			.cdecls C,LIST,"msp430g2553.h"
;-------------------------------------------------------------------------------
            .text                           ; Assemble into program memory
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section
            .retainrefs                     ; Additionally retain any sections
                                            ; that have references to current
                                            ; section


; Main Code
;----------------------------------------------------------------
	; This is the constant area flash begins at address 0x3100 can be
	; used for program code or constants
			.sect ".const" ; initialized data rom for
	; constants. Use this .sect to
	; put data in ROM
error1 		.string "Command not recognized" ; example of a string stored
	; in ROM
			.byte 0x0d,0x0a ; add a CR and a LF
			.byte 0x00 ; null terminate the string with
	; This is the code area flash begins at address 0x3100 can be
	; used for program code or constants
			.text ; program start
			.global _START ; define entry point
	;----------------------------------------------------------------
STRT 		mov.w #300h,SP ; Initialize 'x1121
; stackpointer
StopWDT 	mov.w #WDTPW+WDTHOLD,&WDTCTL ; Stop WDT
SetupP1 	bis.b #01h,&P1DIR ; P1.0 red led output
			call #Init_UART
Mainloop 	xor.b #01,&P1OUT ; Toggle P1.0
Wait mov.w 	#0A000h,R15 ; Delay to R15
L1 			dec.w R15 ; Decrement R15
			jnz L1 ; Delay over?
			call	#NewLine		; Send new line to terminal
			mov.b	#'>', r4		; Send cursor to output register
			call	#OUTA_UART		; Print cursor
			call	#Space			; Print space following cursor
			call	#GetCommand		; Get command
			call	#Space			; Send space to terminal
			call	#Hex8In			; Get parameters for command XXXX YYYY
			call	#Space			; Send space to terminal

			; Determine command & subroutine
			cmp.b	#'D', r10			; Check if first char is 'D'
			jeq		firstCharD			; First char valid
			cmp.b	#'M', r10			; Check if first char is 'M'
			jeq		firstCharM			; First char valid
			cmp.b	#'H', r10			; Check if first char is 'H'
			jeq		firstCharH			; First char valid
			jmp		invalidCommand		; Command was invalid
firstCharD
			cmp.b	#' ', r11			; Valid if second char is space
			jne		invalidCommand		; Otherwise invalid command
			call	#DisplayMemory		; Display Memory subroutine
			jmp		resProgram			; Restart Main Loop
firstCharM
			cmp.b	#' ', r11			; Valid if second char is space
			jne		invalidCommand		; Otherwise invalid
			call	#ChangeMemory		; Change memory subroutin
			jmp		resProgram			; Reset program
firstCharH
			cmp.b	#'A', r11			; Valid if second char is 'A'
			jeq		callCalc			; Valid
			cmp.b	#'S', r11			; Valid if char is 'S'
			jeq		callCalc			; Go to calculator label
			jmp		invalidCommand		; Otherwise, invalid command
callCalc
			call	#Calculator			; Call calculator subroutine
			jmp		resProgram			; Restart main loop
invalidCommand
			call	#NewLine			; Send newline to terminal
			mov.w	#error1, r10		; Otherwise send address of error string to r10
			call	#PrintString		; Print error message to output
resProgram
			jmp		Mainloop			; Again...

Calculator
;----------------------------------------------------------------
; R11 == Operation ( S = Sub, A = Add)
;----------------------------------------------------------------
	push.w	r10							; Store r10 onto stack
	mov.b	#'R', r4					; Send 'R' to output register
	call	#OUTA_UART					; Print 'R' to terminal
	mov.b	#'=', r4					; Send '=' to output register
	call	#OUTA_UART					; Send '=' to terminal
	cmp.b	#'A', r11					; Check for 'A' in r11
	jeq		performAddition				; if r11 == 'A' do ADD operation
	; Otherwise Do subtraction	( r8 -> left op, r9 -> right op)
	sub.w	r9, r8						; R8 = r8 - r9
	mov.w	r2, r13						; Copy status register
	mov.w	r8, r12						; Move result to r12
	call	#Print4ASCII				; Print difference to terminal
	call	#GetFlags					; Print flags to terminal
	jmp		endCalculator				; Finish calculator subroutine
performAddition
	add.w	r8, r9						; Addition result now in r9
	mov.w	r2, r13						; Save contents of status register to r13
	mov.w	r9,	r12						; Move result into r12
	call	#Print4ASCII				; Print result to terminal
	call	#GetFlags					; Call Flags subroutine to print flags to screen
endCalculator
	call	#NewLine					; Send new line to terminal
	pop.w	r10							; Restore r10 from stack
	ret									; Return to calling routine


GetFlags
;----------------------------------------------------------------
; r13 holds status register
;----------------------------------------------------------------
	and.w 	#0x00FF, r13	; Zero out all but lower byte of r10
	mov.w	r13, r11		; Move r10 into r11
	; Get V
	and.b	#0x80, r11		; Zero out all but top MSB
	rra.b	r11				; Move MSB to LSB
	rra.b	r11				; Shift
	rra.b	r11				; Shift
	rra.b	r11				; Shift
	rra.b	r11				; Shift
	rra.b	r11				; Shift
	rra.b	r11				; Shift
	rra.b	r11				; Shift
	mov.b	r11, r10		; Shift
	call	#NewLine		; Send newline to terminal
	mov.b	#'V', r4		; Send 'V' to output register
	call	#OUTA_UART		; Send 'V' to terminal
	mov.b	#'=', r4,		; Send '=' to output register
	call	#OUTA_UART		; Send '=' to terminal
	call	#Print2ASCII	; Print out the flag
	call	#Space			; Send ' ' to terminal

	; Get N
	mov.w	r13, r11		; Copy r13 into r11
	and.b	#0x04, r11		; Clear all but needed bit into r11
	rra.b	r11				; Shift N flag bit down to LSB
	rra.b	r11				; Shift
	mov.b	r11, r10		; Copy r11 to r10
	mov.b	#'N', r4		; Send 'N' to output register
	call	#OUTA_UART		; Send 'N' to terminal
	mov.b	#'=', r4,		; Send '=' to output register
	call	#OUTA_UART		; Send '=' to terminal
	call	#Print2ASCII	; Print the flag to ther terminal
	call	#Space			; Send ' ' to terminal

	; Get Z
	mov.w	r13, r11		; Copy r13 (status) into r11
	and.b	#0x02, r11		; Zero out all but Z bit
	rra.b	r11				; Shift Z bit into LSB position
	mov.b	r11, r10		; Send r11 to r10 bit
	mov.b	#'Z', r4		; Send 'Z' to output register
	call	#OUTA_UART		; Send 'Z' to terminal
	mov.b	#'=', r4,		; Send '=' to output register
	call	#OUTA_UART		; Send '=' to terminal
	call	#Print2ASCII	; Print Z flag
	call	#Space			; Send ' ' to terminal

	; Get C
	mov.w	r13, r11		; Copy r13 (status) into r11
	and.b	#0x01, r11		; Zero out all but C bit
	mov.b	r11, r10		; Send to r10
	mov.b	#'C', r4		; Send 'C' output register
	call	#OUTA_UART		; Send 'C' to terminal
	mov.b	#'=', r4,		; Send '=' to output register
	call	#OUTA_UART		; Send '=' to terminal
	call	#Print2ASCII	; Print C flag
	ret						; Return to calling routine

DisplayMemory
;----------------------------------------------------------------
; Display Memory
; Starting memory address in r8, Ending memory address in r9
;----------------------------------------------------------------
	; Pushes happen in here
	push.w	r13					; Save r13 onto stack
	push.w	r14					; Save r14 onto stack
	mov.w	#0x00, r13			; Initialize r13 with 0 (counter)
	call	#NewLine			; send new line to terminal
DMLoop
	cmp.b	#0x08, r13			; Compare with r13
	jge		AddNewLine			; Add a new line, if there are 8 words on screen
	cmp.w	r9, r8				; check to see if starting address is equal to end adress
	jhs		endDisplayMemory	; End subroutine

	mov.w	0(r8), r12			; Move memory contents of r8 into r12
	call	#Print4ASCII		; Print Contents of current memory address
	call	#Space				; Print Space

	add.w	#0x02, r8			; Increment r8 to next memory address
	inc		r13					; Increment r13

	jmp		endDMLoop			; Skip newline
AddNewLine
	call	#NewLine			; Send new line to terminal
	mov.b	#0x00, r13			; Reset r13
	jmp		DMLoop				; Continue
endDMLoop
	jmp		DMLoop				; Repeat loop
endDisplayMemory
	pop.w	r14					; Restore r14
	pop.w	r13					; Restore r13
; end DisplayMemory Subroutine ----------------------------------------
	ret							; Return

ChangeMemory
;----------------------------------------------------------------
; Change Memory function....
; Initial Memory address in r8, Memory content in r9
;----------------------------------------------------------------
	call	#NewLine				; Go to next line
	mov.w	r9, 0(r8)				; Move initial Contents of r9 to memory location in r8
	add.w	#0x02, r8				; Increment memory location
	mov.w	r8, r12					; Send memory location to r12
	call	#Print4ASCII			; Output current memory location
	call	#Space					; Print space
ChangeMemoryLoop
	call	#INCHAR_UART			; get first character
	cmp.b	#'p', r4				; Check for 'p'
	jeq		incrementMemoryLocation	; If 'p' increment memory location
	cmp.b	#'n', r4				; Check for 'n'
	jeq		decrementMemoryLocation	; If 'n' decrement memory location
	cmp.b	#' ', r4				; Check for ' ' (space)
	jeq		exitChangeMemory		; If Space, exit subroutine
	cmp.b	#'h', r4				; Check for 'h'
	jeq		getHexInput				; If 'h' Take in 4 ASCII values
	jmp		ChangeMemoryLoop		; Otherwise restart loop, and take more input
incrementMemoryLocation				; Increment memory location
	add.w	#0x02, r8				; 	- Add 2 to memory location
	jmp		nextLine				; 	- Start a new line
decrementMemoryLocation				; Decrement memory location
	sub.w	#0x02, r8				; 	- Subtract 2 from memory location
	jmp		nextLine				; 	- Start a new line
getHexInput
	call	#OUTA_UART				; Print 'h' to terminal
	mov.b	#':', r4				; Print ':' to terminal
	call	#OUTA_UART
	call	#Hex4In					; Get 16 bit HEX value
	mov.w	r7, 0(r8)				; Store HEX value to current memory location
	jmp		incrementMemoryLocation	; Go to next memory location
nextLine
	call	#NewLine				; Send newline to terminal
	mov.w	r8, r12					; Send current memory address to r12
	call	#Print4ASCII			; Print current memory address
	call	#Space					; Print a space to terminal
	jmp		ChangeMemoryLoop		; Restart loop for new input
finishChangeMemoryLoop
	call	#NewLine				; Insert a new line
	jmp		ChangeMemoryLoop		; Restart loop for new input
exitChangeMemory
	ret								; Return to calling routine
; end ChangeMemory Subroutine ----------------------------------------


GetCommand
;----------------------------------------------------------------
; Gets 2 HEX characters
; Characters returned in r5, r6
;----------------------------------------------------------------
	push.w	r4					; Save r4 onto stack
	call	#INCHAR_UART		; Get first character
	call	#OUTA_UART			; Print character to terminal
	mov.b	r4, r10
	call	#INCHAR_UART		; Get second character
	call	#OUTA_UART			; Print character to terminal
	mov.b	r4, r11
endGetCommand
	pop.w	r4					; Restore r4
	ret							; Return
; end GetCommand Subroutine ----------------------------------------

Print2ASCII
;----------------------------------------------------------------
; Prints a newline and carriage return to the screen
; Takes a byte as input in register 10, prints contents to screen
;----------------------------------------------------------------
	push.w	r11					; Save r11 onto stack
	push.w	r10					; Save r10 onto stack
	mov.b	r10, r11			; Copy r10 into r11
	and.b	#0xF0, r11			; Zero out all but top 4 bits in byte
	rra.b	r11					; Shift down to bottom 4 bit positions
	rra.b	r11					; Shift
	rra.b	r11					; Shift
	rra.b	r11					; Shift
	mov.w 	r11, r4				; Copy r11 into output register
	and.b	#0x0F, r4			; Clear out all but bottom 4 bits
	cmp.b	#0x0A,r4			; Check to see if value is a number
	jlo		isNum1
	add.b	#0x37, r4			; Add #0x37 if letter
	call	#OUTA_UART			; Print value to terminal
	jmp		nxtChar				; Go to next character
isNum1
	add.b	#0x30, r4			; Add #0x30 if number
	call	#OUTA_UART			; Send to terminal
nxtChar
	mov.b	r10, r11			; Send r10 to r11
	and.w	#0x000F, r11		; Zero out all but bottom 4 bits
	mov.w	r11, r4				; copy r11 into r4
	cmp.b	#0x0A, r4			; Check to see if its a letter or number
	jlo		isNum2
	; if letter
	add.b	#0x37, r4			; Add 37h if letter
	call	#OUTA_UART			; Print to terminal
	jmp		endPrint2ASCII
isNum2
	add.b	#0x30, r4			; Add 30h if number
	call	#OUTA_UART			; Print to terminal
endPrint2ASCII
	pop.w	r10					; restore r10
	pop.w	r11					; restor r11
	ret
; end Print2ASCII Subroutine ----------------------------------------

Print4ASCII
;----------------------------------------------------------------
; Print 4 ASCII numbers to the terminal
;----------------------------------------------------------------
	push.w	r13				; Save r13 onto stack
	push.w	r10				; Save r10 onto stack
	mov.w	r12, r13		; Copy r12 onto r13
	and.w	#0xFF00, r13	; Zero out all but the top byte
	swpb	r13				; Swap the bytes in register r13
	mov.b	r13, r10		; Copy to r10
	call	#Print2ASCII	; Send to output
	mov.w	r12, r13		; Copy again, r12 into r13
	and.w	#0x00FF, r13	; Zero out all but lower byte
	mov.b	r13, r10		; Copy to r10
	call	#Print2ASCII	; Send to output
endPrint4ASCII
	pop.w	r10				; Restore r10
	pop.w	r13				; Restore r13
	ret

NewLine
;----------------------------------------------------------------
; Prints a newline and carriage return to the screen
;----------------------------------------------------------------
	push.w 	r4			; Push contents of r4 onto stack
	mov.b	#0x0A, r4	; Send newline char to r4
	call 	#OUTA_UART	; Print newline
	mov.b	#0X0D, r4	; Send carriage ret char to r4
	call	#OUTA_UART	; Print carriage return
	pop.w	r4			; Restore r4
	ret
; end NewLine Subroutine ----------------------------------------


Space
;----------------------------------------------------------------
; Prints a space to the terminal
;----------------------------------------------------------------
	push.w	r4				; Save r4
	mov.b	#0x20, r4		; Send ' ' to r4
	call	#OUTA_UART		; Send ' ' to terminal
	pop.w	r4				; Restore r4
	ret
; end Space Subroutine ----------------------------------------




Hex1In
;----------------------------------------------------------------
; Gets a single HEX character and prints it to the terminal
; Content returned in r5
;----------------------------------------------------------------
		push.w	r4				; Save r4
Ilp1	call	#INCHAR_UART	; Get character from keyboard
		cmp.b	#0x30, r4		; Compare 30h w/ r4
		jlo		Ilp1			; Get another char if lower than 0 on ascii table
		cmp.b	#0x47, r4		; Gheck to see if letter
		jhs		Ilp1			; Restart if char is > 'G' on ascii table
		cmp.b	#0x3A, r4		; Compare 3Ah w/ r4
		jlo		Inum1			; valid input - is number
		cmp.b	#0x41, r4		; Compare 41h w/ r4
		jhs		Ilet1			; valid input - is letter
		jmp		Ilp1			; For all other cases...
Ilet1
		call 	#OUTA_UART		; Print to terminal
		sub.b	#0x37, r4		; Convert to "10 - 15" as a 4-bit binary value
		jmp		Ilp2			; Finish and return
Inum1
		call	#OUTA_UART		; Print to terminal
		sub.b	#0x30, r4		; Convert to 4-bit binary as 0-9
Ilp2
		mov.b	r4, r5			; Move contents into r5
		pop.w	r4				; Restore r4 from stack
		ret						; Return from subroutine
; end Hex1In Subroutine ----------------------------------------


Hex2In
;----------------------------------------------------------------
; Gets 2 HEX characters, converts each to 4 bit binary number,
; combines, and returns content in register 6
;----------------------------------------------------------------
		push.w	r5				; Save contents of r5 onto stack
		call	#Hex1In			; Get a single valid HEX char
		rla.b	r5				; Shift r5 right by 4 bits
		rla.b	r5				; Shift
		rla.b	r5				; Shift
		rla.b	r5				; Shift
		mov.w	r5, r6			; Copy r5 into r6
		and.w	#0x00F0, r6		; Zero out all but top 4 bits in bottom byte
		call	#Hex1In			; Get a second character
		and.w	#0x000F, r5		; Zero out all but bottom 4 bits
		add.w	r5, r6			; Copy r5 into r6
		pop.w	r5				; Restore r5
		ret						; Return from subroutine
; end Hex2In Subroutine ----------------------------------------


Hex4In
;----------------------------------------------------------------
; Gets 4 HEX characters, converts each to 4 bit binary number,
; combines, and returns content in register 7
;----------------------------------------------------------------
		push.w	r6				; Save contents of r6 onto stack
		call	#Hex2In			; Get 2 HEX characters
		and.w	#0x00FF, r6		; Zero out all but lower 8 bits
		mov.w	r6, r7			; copy r6 into r7
		swpb	r7				; Swap bytes in r7
		call	#Hex2In			; Get 2 more HEX characters
		and.w	#0x00FF, r6		; zero out all but lower 8 bits
		add.w r6, r7			; Combine contents of r6 & r7
		pop.w r6				; Restore r6
		ret						; Return from subroutine
; end Hex4In Subroutine ----------------------------------------


Hex8In
;----------------------------------------------------------------
; Gets 8 HEX characters, converts each to 4 bit binary number,
; combines, and returns contens in r6, r7
; First 4 characters in r8, second 4 in r9
;----------------------------------------------------------------
		push.w	r7				; Save r7 onto stack
		call	#Hex4In			; Get 4 HEX characters
		mov.w	r7, r8			; Move contents of r7 into r8
		call	#Space			; Print a space to the terminal
		call	#Hex4In			; Get 4 more HEX characters
		mov.w	r7, r9			; Copy contents of r7 into r9
		pop.w	r7				; Restore r7
		ret						; Return from subroutine
; end Hex8In Subroutine ----------------------------------------


PrintString
	mov.b	0(r10), r4			; Get a character from string's address
	cmp.b	#00, r4				; Check to see if char is NULL
	jeq		done				; End subroutine if NULL char
	call	#OUTA_UART			; Otherwise send character to terminal
	inc		r10					; increment address
	jmp		PrintString			; Again...
done
	ret							; Return


OUTA_UART
;----------------------------------------------------------------
; prints to the screen the ASCII value stored in register 4 and
; uses register 5 as a temp value
;----------------------------------------------------------------
			push R5
lpa 		mov.b &IFG2,R5
			and.b #0x02,R5
			cmp.b #0x00,R5
			jz lpa
			mov.b R4,&UCA0TXBUF
			pop R5
			ret

INCHAR_UART
;----------------------------------------------------------------
; returns the ASCII value in register 4
;----------------------------------------------------------------
			push R5
lpb 		mov.b &IFG2,R5
			and.b #0x01,R5
			cmp.b #0x00,R5
			jz lpb
			mov.b &UCA0RXBUF,R4
			pop R5
			ret

Init_UART
;----------------------------------------------------------------
; Initialization code to set up the uart on the experimenter board to 8 data,
; 1 stop, no parity, and 9600 baud, polling operation
;----------------------------------------------------------------

			mov.b &CALBC1_1MHZ, &BCSCTL1
			mov.b &CALDCO_1MHZ, &DCOCTL

			mov.b #0x06,&P1SEL
			mov.b #0x06,&P1SEL2

			mov.b #0x00,&UCA0CTL0

			mov.b #0x81,&UCA0CTL1

			mov.b #0x00,&UCA0BR1
			mov.b #0x68,&UCA0BR0

			mov.b #0x06,&UCA0MCTL

			mov.b #0x00,&UCA0STAT

			mov.b #0x80,&UCA0CTL1
			mov.b #0x00,&IE2

			ret

;----------------------------------------------------------------
; Interrupt Vectors
;----------------------------------------------------------------
			.sect ".reset" ; MSP430 RESET Vector
			.short STRT
			.end
