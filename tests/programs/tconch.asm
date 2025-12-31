; Console Character I/O Test (Phase 1)
; Tests: F1 (C_READ), F2 (C_WRITE)
;
; Input injection required: This test expects specific characters
; to be piped to stdin for F1 to read.

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONIN EQU     1               ; Console input with echo
F_CONOUT EQU    2               ; Console output
F_PRTSTR EQU    9               ; Print $-terminated string

; ASCII
CR      EQU     0DH
LF      EQU     0AH

; Test tracking
TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0

START:
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: F2 output printable character
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Output 'X' via F2
        MVI     E, 'X'
        MVI     C, F_CONOUT
        CALL    BDOS
        ; If we get here without crash, it passed
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 2: F2 output CR/LF sequence
        ;---------------------------------------------------------------
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Output CR
        MVI     E, CR
        MVI     C, F_CONOUT
        CALL    BDOS
        ; Output LF
        MVI     E, LF
        MVI     C, F_CONOUT
        CALL    BDOS
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 3: F2 output TAB
        ;---------------------------------------------------------------
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     E, 09H          ; TAB
        MVI     C, F_CONOUT
        CALL    BDOS
        MVI     E, '*'          ; Marker after tab
        MVI     C, F_CONOUT
        CALL    BDOS
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 4: F1 read single character (expects 'A' from input)
        ;---------------------------------------------------------------
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Read character via F1 (expects 'A' injected from harness)
        MVI     C, F_CONIN
        CALL    BDOS
        ; A now has the character read (with echo already done)
        CPI     'A'
        JNZ     T4FAIL
        CALL    TPASS
        JMP     TEST5

T4FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXPA
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: F1 read second character (expects 'B' from input)
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_CONIN
        CALL    BDOS
        CPI     'B'
        JNZ     T5FAIL
        CALL    TPASS
        JMP     SUMMARY

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXPB
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Summary
        ;---------------------------------------------------------------
SUMMARY:
        LXI     D, MSGSUMM
        MVI     C, F_PRTSTR
        CALL    BDOS

        LDA     PASSED
        CALL    PRTHEX
        LXI     D, MSGOF
        MVI     C, F_PRTSTR
        CALL    BDOS

        LDA     TESTNUM
        CALL    PRTHEX
        LXI     D, MSGTESTS
        MVI     C, F_PRTSTR
        CALL    BDOS

        LDA     FAILED
        ORA     A
        JNZ     ALLFAIL
        LXI     D, MSGPASS
        MVI     C, F_PRTSTR
        CALL    BDOS
        RET

ALLFAIL:
        LXI     D, MSGFAILED
        MVI     C, F_PRTSTR
        CALL    BDOS
        RET

;---------------------------------------------------------------
; Helper routines
;---------------------------------------------------------------
TPASS:
        LXI     D, MSGOK
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     PASSED
        INR     A
        STA     PASSED
        RET

TFAIL:
        LXI     D, MSGNG
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     FAILED
        INR     A
        STA     FAILED
        RET

PRTHEX:
        PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        CALL    PRTNYB
        POP     PSW
PRTNYB:
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      PRN1
        ADI     7
PRN1:
        MOV     E, A
        MVI     C, F_CONOUT
        CALL    BDOS
        RET

; Storage
GOTVAL: DB      0

; Messages
MSGHDR: DB      'Console Character I/O Tests (F1, F2)', CR, LF
        DB      '=====================================', CR, LF, '$'

MSG_T1: DB      'T1: F2 output char... ', '$'
MSG_T2: DB      'T2: F2 CR/LF... ', '$'
MSG_T3: DB      'T3: F2 TAB... ', '$'
MSG_T4: DB      CR, LF, 'T4: F1 read (expect A)... ', '$'
MSG_T5: DB      'T5: F1 read (expect B)... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGEXPA: DB     'Expected A', CR, LF, '$'
MSGEXPB: DB     'Expected B', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
