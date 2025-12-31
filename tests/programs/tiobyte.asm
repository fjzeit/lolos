; BDOS IOBYTE and Write Protect Test
; Tests: F7, F8, F28
;
; F7 - Get IOBYTE
; F8 - Set IOBYTE
; F28 - Write protect disk

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_RESETDSK EQU  13
F_SELDSK EQU    14
F_GETIOB EQU    7
F_SETIOB EQU    8
F_ROVEC EQU     29
F_WRTPROT EQU   28

; ASCII
CR      EQU     0DH
LF      EQU     0AH

TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0
SAVED_IOB: DB   0

START:
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Save initial IOBYTE
        MVI     C, F_GETIOB
        CALL    BDOS
        STA     SAVED_IOB

        ; Reset disk system
        MVI     C, F_RESETDSK
        CALL    BDOS

        ; Select drive A
        MVI     E, 0
        MVI     C, F_SELDSK
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: Get IOBYTE (F7)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_GETIOB
        CALL    BDOS
        ; Just verify we get a value (no exception)
        ; A should have the IOBYTE value
        STA     GOTVAL
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 2: Set IOBYTE (F8) then get it back
        ;---------------------------------------------------------------
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set IOBYTE to 0x55
        MVI     E, 55H
        MVI     C, F_SETIOB
        CALL    BDOS

        ; Get it back
        MVI     C, F_GETIOB
        CALL    BDOS
        CPI     55H
        JNZ     T2FAIL
        CALL    TPASS
        JMP     TEST3

T2FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP55
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: Set IOBYTE to different value
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set IOBYTE to 0xAA
        MVI     E, 0AAH
        MVI     C, F_SETIOB
        CALL    BDOS

        ; Get it back
        MVI     C, F_GETIOB
        CALL    BDOS
        CPI     0AAH
        JNZ     T3FAIL
        CALL    TPASS
        JMP     TEST4

T3FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXPAA
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: Write protect disk (F28)
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Check R/O vector is 0 initially
        MVI     C, F_ROVEC
        CALL    BDOS
        MOV     A, H
        ORA     L
        JNZ     T4FAIL

        ; Write protect current disk
        MVI     C, F_WRTPROT
        CALL    BDOS

        ; Check R/O vector has bit 0 set
        MVI     C, F_ROVEC
        CALL    BDOS
        MOV     A, L
        ANI     01H
        JZ      T4FAIL

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGWP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: Reset clears write protect
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Reset disk system
        MVI     C, F_RESETDSK
        CALL    BDOS

        ; Check R/O vector is 0
        MVI     C, F_ROVEC
        CALL    BDOS
        MOV     A, H
        ORA     L
        JNZ     T5FAIL

        CALL    TPASS
        JMP     SUMMARY

T5FAIL:
        CALL    TFAIL
        LXI     D, MSGRSTRO
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Summary and restore
        ;---------------------------------------------------------------
SUMMARY:
        ; Restore IOBYTE
        LDA     SAVED_IOB
        MOV     E, A
        MVI     C, F_SETIOB
        CALL    BDOS

        ; Re-select drive A
        MVI     E, 0
        MVI     C, F_SELDSK
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
MSGHDR: DB      'BDOS IOBYTE & Write Protect Tests', CR, LF
        DB      '==================================', CR, LF, '$'

MSG_T1: DB      'T1: F7 Get IOBYTE... ', '$'
MSG_T2: DB      'T2: F8 Set IOBYTE 55H... ', '$'
MSG_T3: DB      'T3: F8 Set IOBYTE AAH... ', '$'
MSG_T4: DB      'T4: F28 Write protect... ', '$'
MSG_T5: DB      'T5: Reset clears R/O... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGEXP55: DB    'Expected 55H', CR, LF, '$'
MSGEXPAA: DB    'Expected AAH', CR, LF, '$'
MSGWP:  DB      'R/O vector not set', CR, LF, '$'
MSGRSTRO: DB    'R/O not cleared', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
