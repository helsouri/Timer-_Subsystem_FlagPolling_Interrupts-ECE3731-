;*****************************************************************
;* Clock.ASM
;* -for Full Chip Simulation or Board -- select your target
;* DO NOT DELETE ANY LINES IN THIS TEMPLATE
;* --ONLY FILL IN SECTIONS
;*****************************************************************
; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 
		
;-------------------------------------------------- 
; Equates Section  
;----------------------------------------------------  
ROMStart EQU  $2000  ; absolute address to place my code
TEN     EQU   $80
C2F     EQU   $04
C2I     EQU   $04
IOS2    EQU   $04
RED:       EQU     $10    ; PP4
BLUE:     EQU     $20    ; PP5
GREEN:  EQU     $40    ; PP6
;---------------------------------------------------- 
; Variable/Data Section
;----------------------------------------------------  
            ORG RAMStart   ; loc $1000  (RAMEnd = $3FFF)
; Insert here your data definitions here

COUNT       DS   1
NUMTICKS    DS   1
SECONDS     DS   1   ;keeps track of seconds
MINUTES     DS   1   ;keeps track of minutes
HOURS       DS   1   ;keeps track of hours
COUNTB dc.b 0

       INCLUDE 'utilities.inc'
       INCLUDE 'LCD.inc'

;---------------------------------------------------- 
; Code Section
;---------------------------------------------------- 
            ORG   ROMStart  ; loc $2000
Entry:
_Startup:
            ; remap the RAM &amp; EEPROM here. See EB386.pdf
 ifdef _HCS12_SERIALMON
            ; set registers at $0000
            CLR   $11                  ; INITRG= $0
            ; set ram to end at $3FFF
            LDAB  #$39
            STAB  $10                  ; INITRM= $39

            ; set eeprom to end at $0FFF
            LDAA  #$9
            STAA  $12                  ; INITEE= $9
            JSR   PLL_init      ; initialize PLL  
  endif

;---------------------------------------------------- 
; Insert your code here
;---------------------------------------------------- 
        lds   #ROMStart ; load stack pointer
*SET UP THE (interrupt) SERVICE & INITIALIZE
        JSR   TermInit  ; Initialize Serial Port (for simulation)
        JSR   led_enable
      	CLR   COUNT
        CLR   SECONDS
        CLR   MINUTES
        CLR   HOURS
        MOVB  #100,NUMTICKS  ; number of ticks (interrupts) for 1 second
        bset  DDRT,%00100000 ; PT5 (spkr) is output
        bset  TSCR1,TEN     ; enable TCNT
        bset  TIOS,IOS2      ; choose OC2 for timer CH. 2
        movb  #$03,TSCR2     ; set prescaler to 8
        movb  #C2F,TFLG1    ; clear  C2F flag initially
        bset  TIE,C2I     ; arm OC2
        cli               ; allow interupts
; main program loop follows     
LOOP
    BRCLR TFLG2, #%10000000,LOOP
    LDAA PTT
    EORA #%00100000
    STAA PTT
    MOVB  #%10000000, TFLG2
    bra LOOP
    
*====END OF MAIN ROUTINE 




*============= SERVICE PROCESS
OC2ISR
        MOVB   #C2F,TFLG1   ; clear flag
        LDD    TC2  ; schedule next interrupt
        ADDD   #30000  ; 30000 cycles = 10ms
        STD    TC2     ; .....
        INC    COUNT   ; one more interrupt interval counted
        LDAB   COUNT
        CMPB   NUMTICKS ; has count reached amount for 1 second?
        BNE    DONE  ; not one second yet so return
        CLR    COUNT
        JSR    ONE.SECOND  ; one second has elapsed
DONE    RTI
*============= END OF SERVICE ROUTINE
* subroutines follow this

; ONE.SECOND:
; what to do every second
; display curent time as HH:MM:SS
; update timekeeping variables
              ;
ONE.SECOND 
        inc PORTB
        bclr PORTB,%11110000          
        INC   SECONDS
        LDAA  SECONDS
        CMPA  #60
        BEQ   ONE.MINUTE ; need to update minutes if >= 60 seconds`
        BRA   UpdateDone 
ONE.MINUTE
        CLR   SECONDS
        INC   MINUTES
        LDAA  MINUTES
        CMPA  #60
        BEQ   ONE.HOUR
        BRA   UpdateDone 
ONE.HOUR
        CLR   MINUTES
        INC   HOURS
        LDAA  HOURS
        CMPA  #24
        BEQ   ONE.DAY
        BEQ   UpdateDone 
ONE.DAY
        CLR   HOURS
UpdateDone  ; return from subrouitne        
        RTS


DISPLAY  ; DISPLAY THE TIME AS HH:MM:SS
        PSHB  
        LDAB   HOURS
        JSR    HEX2BCD  ; convert value in A to decimal
        JSR    out2hex   ; output B as 2 hex digits
        LDAB   #':'
        JSR    putchar
        LDAB   MINUTES
        JSR    HEX2BCD  ; convert value in A to decimal
        JSR    out2hex   ; output B as 2 hex digits
        LDAB   #':'
        JSR    putchar
        LDAB   SECONDS
        JSR    HEX2BCD  ; convert value in A to decimal
        JSR    out2hex   ; output B as 2 hex digits
        LDAB   #13     ; print new line
        JSR   putchar  ; ..... 13,10
        LDAB   #10
        JSR   putchar
        PULB
        RTS

;HEX2BCD: Converts hex  value in B register to BCD
; works for 2-digit values
; e.g. 1B becomes 27
; assumes value to be converted is in ACC B and result in B       
HEX2BCD  
        TFR    B,A   ; make copy in A
; add 6 to A for every 10 that can be subtracted from B
UP      CMPB   #10
        BLO    DONE2
        SUBB   #10
        ADDA   #6
        BRA    UP
DONE2
        TFR   A,B  ; Use B to return value
        RTS
                         
;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   Vtimch2  ; timer CH2 vector
            dc.w  OC2ISR
            
            ORG   Vreset
            DC.W  Entry         ; Reset Vector
 