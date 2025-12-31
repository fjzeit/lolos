; Test Utility Macros and Routines for CP/M BDOS Testing
; Include this file at the start of each test program
;
; Usage:
;   INCLUDE "testutil.inc"
;   ORG 0100H
;   ... test code ...
;   END START

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2               ; Console output
F_PRTSTR EQU    9               ; Print string

; ASCII codes
CR      EQU     0DH
LF      EQU     0AH

;-------------------------------------------------------------------------------
; Test Result Tracking
;-------------------------------------------------------------------------------
; Tests call PASS or FAIL to record results
; At end, call SUMMARY to print pass/fail counts

;-------------------------------------------------------------------------------
; Print Utilities
;-------------------------------------------------------------------------------

; Print a $-terminated string at HL
; Preserves all registers except A
PRTMSG:
        PUSH    B
        PUSH    D
        PUSH    H
        XCHG                    ; DE = string addr
        MVI     C, F_PRTSTR
        CALL    BDOS
        POP     H
        POP     D
        POP     B
        RET

; Print CR/LF
CRLF:
        PUSH    B
        PUSH    D
        MVI     E, CR
        MVI     C, F_CONOUT
        CALL    BDOS
        MVI     E, LF
        MVI     C, F_CONOUT
        CALL    BDOS
        POP     D
        POP     B
        RET

; Print A register as 2-digit hex
; Preserves BC, DE
PRTHEX:
        PUSH    PSW
        PUSH    B
        RRC
        RRC
        RRC
        RRC
        CALL    PRTNYB
        POP     B
        POP     PSW
        ; Fall through to print low nibble
PRTNYB:
        PUSH    B
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      PRTN1
        ADI     7               ; Convert A-F
PRTN1:
        MOV     E, A
        MVI     C, F_CONOUT
        CALL    BDOS
        POP     B
        RET

; Print HL as 4-digit hex
PRTHL:
        PUSH    H
        MOV     A, H
        CALL    PRTHEX
        POP     H
        MOV     A, L
        CALL    PRTHEX
        RET

; Print a single character in E
PRTCHR:
        PUSH    B
        PUSH    D
        MVI     C, F_CONOUT
        CALL    BDOS
        POP     D
        POP     B
        RET

; Print a space
PRTSPC:
        PUSH    D
        MVI     E, ' '
        CALL    PRTCHR
        POP     D
        RET

;-------------------------------------------------------------------------------
; Test Assertion Helpers
;-------------------------------------------------------------------------------

; Check if A == expected value in B
; Returns: Z flag set if equal
; Destroys: nothing
CHKEQ:
        CMP     B
        RET

; Check if HL == expected value in DE
; Returns: Z flag set if equal
CHKEQHL:
        MOV     A, H
        CMP     D
        RNZ
        MOV     A, L
        CMP     E
        RET
