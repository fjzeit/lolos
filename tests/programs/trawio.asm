; Direct Console I/O Test (Phase 3)
; Tests: F6 (C_RAWIO) - all 4 modes
;
; Input injection required for blocking input test.

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2               ; Console output
F_RAWIO EQU     6               ; Direct console I/O
F_PRTSTR EQU    9               ; Print $-terminated string

; F6 modes
RAW_OUT EQU     00H             ; 00-FC: output character
RAW_STAT EQU    0FEH            ; FE: status query
RAW_NBIN EQU    0FFH            ; FF: non-blocking input
RAW_BIN EQU     0FDH            ; FD: blocking input

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
        ; Test 1: F6 output character (E=00-FC)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Output 'R' via F6
        MVI     E, 'R'
        MVI     C, F_RAWIO
        CALL    BDOS
        ; Output 'A'
        MVI     E, 'A'
        MVI     C, F_RAWIO
        CALL    BDOS
        ; Output 'W'
        MVI     E, 'W'
        MVI     C, F_RAWIO
        CALL    BDOS
        ; If we get here, it worked
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 2: F6 output control characters
        ;---------------------------------------------------------------
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Output CR via F6
        MVI     E, CR
        MVI     C, F_RAWIO
        CALL    BDOS
        ; Output LF
        MVI     E, LF
        MVI     C, F_RAWIO
        CALL    BDOS
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 3: F6 blocking input (E=FDH) - expects 'X' from input
        ; NOTE: Must run BEFORE status/non-blocking tests which might
        ;       consume the injected input
        ;---------------------------------------------------------------
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Read character via F6 blocking mode
        MVI     E, RAW_BIN
        MVI     C, F_RAWIO
        CALL    BDOS
        ; A = character read
        CPI     'X'
        JNZ     T3FAIL
        ; Echo it
        MOV     E, A
        MVI     C, F_RAWIO
        CALL    BDOS
        CALL    TPASS
        JMP     TEST4

T3FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXPX
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: F6 non-blocking input (E=FFH) - expects 'Y' from input
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Try non-blocking read (should get 'Y' if available)
        MVI     E, RAW_NBIN
        MVI     C, F_RAWIO
        CALL    BDOS
        ; A = character or 0 if not ready
        CPI     'Y'
        JNZ     T4FAIL
        ; Echo it
        MOV     E, A
        MVI     C, F_RAWIO
        CALL    BDOS
        CALL    TPASS
        JMP     TEST5

T4FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXPY
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: F6 status query (E=FEH) after input consumed
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Query status - should return 0 or FF
        MVI     E, RAW_STAT
        MVI     C, F_RAWIO
        CALL    BDOS
        ; A should be 0 (no char) or FF (char ready)
        ; Just verify it's one of these values
        ORA     A
        JZ      T5OK
        CPI     0FFH
        JNZ     T5FAIL
T5OK:
        CALL    TPASS
        JMP     TEST6

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGSTAT
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: F6 non-blocking when no input (should return 0)
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Non-blocking read with no input should return 0
        ; (All injected input was consumed by T3/T4)
        MVI     E, RAW_NBIN
        MVI     C, F_RAWIO
        CALL    BDOS
        ; A should be 0
        ORA     A
        JNZ     T6FAIL
        CALL    TPASS
        JMP     SUMMARY

T6FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP0
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
MSGHDR: DB      'Direct Console I/O Tests (F6)', CR, LF
        DB      '==============================', CR, LF, '$'

MSG_T1: DB      'T1: F6 output chars... ', '$'
MSG_T2: DB      'T2: F6 output CR/LF... ', '$'
MSG_T3: DB      'T3: F6 blocking in... ', '$'
MSG_T4: DB      'T4: F6 non-block in... ', '$'
MSG_T5: DB      CR, LF, 'T5: F6 status... ', '$'
MSG_T6: DB      'T6: F6 no-input=0... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGEXPX: DB     'Expected X', CR, LF, '$'
MSGEXPY: DB     'Expected Y', CR, LF, '$'
MSGSTAT: DB     'Expected 0 or FF', CR, LF, '$'
MSGEXP0: DB     'Expected 0', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
