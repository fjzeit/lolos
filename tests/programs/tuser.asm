; BDOS User Number Test (Function 32)
; Tests: Get user, Set user, User isolation
;
; F32 with E=FFH returns current user number
; F32 with E=0-15 sets user number

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_RESETDSK EQU  13
F_USERNUM EQU   32

; ASCII
CR      EQU     0DH
LF      EQU     0AH

TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0

START:
        ; Print test header
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Reset disk system to start fresh
        MVI     C, F_RESETDSK
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: Get initial user (should be 0 after reset)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     E, 0FFH         ; Get user
        MVI     C, F_USERNUM
        CALL    BDOS

        ; A should be 0
        ORA     A
        JNZ     T1FAIL
        CALL    TPASS
        JMP     TEST2

T1FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS
        MVI     E, '0'
        MVI     C, F_CONOUT
        CALL    BDOS
        LXI     D, MSGGOT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     GOTVAL
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 2: Set user to 5, then get it back
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set user to 5
        MVI     E, 5
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Get user
        MVI     E, 0FFH
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Should be 5
        CPI     5
        JNZ     T2FAIL
        CALL    TPASS
        JMP     TEST3

T2FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS
        MVI     E, '5'
        MVI     C, F_CONOUT
        CALL    BDOS
        LXI     D, MSGGOT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     GOTVAL
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 3: Set user to 15 (max), verify
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     E, 15
        MVI     C, F_USERNUM
        CALL    BDOS

        MVI     E, 0FFH
        MVI     C, F_USERNUM
        CALL    BDOS

        CPI     15
        JNZ     T3FAIL
        CALL    TPASS
        JMP     TEST4

T3FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS
        MVI     E, 'F'
        MVI     C, F_CONOUT
        CALL    BDOS
        LXI     D, MSGGOT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     GOTVAL
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 4: User number masked to 0-15 (set 0x3F, get 0x0F)
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set user to 0x3F (should be masked to 0x0F)
        MVI     E, 3FH
        MVI     C, F_USERNUM
        CALL    BDOS

        MVI     E, 0FFH
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Should be 0x0F (masked)
        CPI     0FH
        JNZ     T4FAIL
        CALL    TPASS
        JMP     TEST5

T4FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS
        MVI     E, 'F'
        MVI     C, F_CONOUT
        CALL    BDOS
        LXI     D, MSGGOT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     GOTVAL
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 5: Reset disk resets user to 0
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set user to 7
        MVI     E, 7
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Reset disk system
        MVI     C, F_RESETDSK
        CALL    BDOS

        ; Get user - should be 0
        MVI     E, 0FFH
        MVI     C, F_USERNUM
        CALL    BDOS

        ORA     A
        JNZ     T5FAIL
        CALL    TPASS
        JMP     SUMMARY

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS
        MVI     E, '0'
        MVI     C, F_CONOUT
        CALL    BDOS
        LXI     D, MSGGOT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     GOTVAL
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Summary
        ;---------------------------------------------------------------
SUMMARY:
        ; Restore user 0
        MVI     E, 0
        MVI     C, F_USERNUM
        CALL    BDOS

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

CRLF:
        MVI     E, CR
        MVI     C, F_CONOUT
        CALL    BDOS
        MVI     E, LF
        MVI     C, F_CONOUT
        CALL    BDOS
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
MSGHDR: DB      'BDOS User Number Tests (F32)', CR, LF
        DB      '============================', CR, LF, '$'
MSG_T1: DB      'T1: Initial user = 0... ', '$'
MSG_T2: DB      'T2: Set user 5, get 5... ', '$'
MSG_T3: DB      'T3: Set user 15, get 15... ', '$'
MSG_T4: DB      'T4: User masked to 0-15... ', '$'
MSG_T5: DB      'T5: Reset clears user... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGEXP: DB      'Expected ', '$'
MSGGOT: DB      ', got ', '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
