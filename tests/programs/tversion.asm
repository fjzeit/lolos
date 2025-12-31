; BDOS Version Test (Function 12) - Enhanced
; Tests: F12 returns 0022H for CP/M 2.2
;
; Verifies all return registers and idempotence

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_VERSION EQU   12

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
        ; Test 1: HL = 0022H
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_VERSION
        CALL    BDOS
        ; Save HL for later tests
        SHLD    RETHL

        ; Check H = 00
        MOV     A, H
        ORA     A
        JNZ     T1FAIL
        ; Check L = 22H
        MOV     A, L
        CPI     22H
        JNZ     T1FAIL
        CALL    TPASS
        JMP     TEST2

T1FAIL:
        CALL    TFAIL
        LXI     D, MSGHLEXP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 2: A = L = 22H
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_VERSION
        CALL    BDOS
        ; A should equal L
        MOV     B, A            ; Save A
        MOV     A, L
        CMP     B               ; Compare L with saved A
        JNZ     T2FAIL
        ; A should be 22H
        MOV     A, B
        CPI     22H
        JNZ     T2FAIL
        CALL    TPASS
        JMP     TEST3

T2FAIL:
        CALL    TFAIL
        LXI     D, MSGALEXP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: B = H = 00H
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_VERSION
        CALL    BDOS
        ; B should equal H
        MOV     A, H
        CMP     B               ; Compare H with B
        JNZ     T3FAIL
        ; B should be 00H
        MOV     A, B
        ORA     A
        JNZ     T3FAIL
        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL
        LXI     D, MSGBHEXP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: Idempotence - multiple calls return same value
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Call 3 times, verify same result
        MVI     C, F_VERSION
        CALL    BDOS
        SHLD    RETHL           ; Save first result

        MVI     C, F_VERSION
        CALL    BDOS
        XCHG                    ; DE = second result
        LHLD    RETHL           ; HL = first result
        MOV     A, H
        CMP     D
        JNZ     T4FAIL
        MOV     A, L
        CMP     E
        JNZ     T4FAIL

        MVI     C, F_VERSION
        CALL    BDOS
        XCHG                    ; DE = third result
        LHLD    RETHL           ; HL = first result
        MOV     A, H
        CMP     D
        JNZ     T4FAIL
        MOV     A, L
        CMP     E
        JNZ     T4FAIL

        CALL    TPASS
        JMP     SUMMARY

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGIDMP
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
RETHL:  DW      0

; Messages
MSGHDR: DB      'BDOS Version Test (F12)', CR, LF
        DB      '=======================', CR, LF, '$'

MSG_T1: DB      'T1: HL=0022H... ', '$'
MSG_T2: DB      'T2: A=L=22H... ', '$'
MSG_T3: DB      'T3: B=H=00H... ', '$'
MSG_T4: DB      'T4: Idempotent... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGHLEXP: DB    'Expected HL=0022H', CR, LF, '$'
MSGALEXP: DB    'Expected A=L=22H', CR, LF, '$'
MSGBHEXP: DB    'Expected B=H=00H', CR, LF, '$'
MSGIDMP: DB     'Results differ', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
