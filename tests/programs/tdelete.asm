; File Delete Test (Phase 10)
; Tests: F19 (F_DELETE)
;
; Creates test files, deletes them, verifies deletion

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_CLOSE EQU     16
F_SFIRST EQU    17
F_DELETE EQU    19
F_MAKE  EQU     22
F_DMAOFF EQU    26

; FCB location
DFCB    EQU     005CH

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
        ; Setup: Create test files DEL1.TST, DEL2.TST, DEL3.TST
        ;---------------------------------------------------------------
        LXI     D, MSGSETUP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete any existing test files first
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS

        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS

        LXI     H, FCB3
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Create test files
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      SETUP_ERR
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      SETUP_ERR
        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     H, FCB3
        CALL    SETFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      SETUP_ERR
        LXI     H, FCB3
        CALL    SETFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     D, MSGOK
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: F19 Delete existing file (DEL1.TST)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS
        ; A should be 0-3 (success)
        CPI     4
        JNC     T1FAIL
        CALL    TPASS
        JMP     TEST2

T1FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 2: F19 Delete non-existent file (no crash)
        ; Note: Some CP/M implementations return FFH, others return 0
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCBNE
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS
        ; Just verify we return (no crash), any return value OK
        CALL    TPASS
        JMP     TEST3

        ;---------------------------------------------------------------
        ; Test 3: Verify DEL1.TST is gone (search should fail)
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set DMA for search
        LXI     D, DMABUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        ; A should be FFH (not found - file was deleted)
        CPI     0FFH
        JNZ     T3FAIL
        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL
        LXI     D, MSGSTILL
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: DEL2.TST and DEL3.TST should still exist
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T4FAIL          ; Should exist

        LXI     H, FCB3
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T4FAIL          ; Should exist

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGGONE
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: Delete with wildcard DEL?.TST (should delete 2 files)
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCBWC
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS
        ; A should be 0-3 (at least one deleted)
        CPI     4
        JNC     T5FAIL
        CALL    TPASS
        JMP     TEST6

T5FAIL:
        CALL    TFAIL
        LXI     D, MSGWC
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: Verify DEL2.TST gone after wildcard delete
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JNZ     T6FAIL          ; Should be gone
        CALL    TPASS
        JMP     TEST7

T6FAIL:
        CALL    TFAIL
        LXI     D, MSGSTILL
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 7: Verify DEL3.TST gone after wildcard delete
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCB3
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JNZ     T7FAIL          ; Should be gone
        CALL    TPASS
        JMP     TEST8

T7FAIL:
        CALL    TFAIL
        LXI     D, MSGSTILL
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 8: Delete already-deleted file (no crash)
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS
        ; Just verify we return (no crash), any return value OK
        CALL    TPASS
        JMP     SUMMARY

        ;---------------------------------------------------------------
        ; Summary
        ;---------------------------------------------------------------
SUMMARY:
        CALL    CRLF
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

SETUP_ERR:
        LXI     D, MSGSETERR
        MVI     C, F_PRTSTR
        CALL    BDOS
        RET

;---------------------------------------------------------------
; Helper: Copy FCB from HL to DFCB
;---------------------------------------------------------------
SETFCB:
        LXI     D, DFCB
        MVI     B, 36
CPFCB:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     CPFCB
        LXI     D, DFCB
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

;---------------------------------------------------------------
; FCBs for test files (36 bytes each)
;---------------------------------------------------------------
FCB1:   DB      0, 'DEL1    ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

FCB2:   DB      0, 'DEL2    ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

FCB3:   DB      0, 'DEL3    ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Non-existent file
FCBNE:  DB      0, 'NOTHERE ', 'XXX'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Wildcard DEL?.TST
FCBWC:  DB      0, 'DEL?    ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Storage
GOTVAL: DB      0

; DMA buffer for search
DMABUF: DS      128

; Messages
MSGHDR: DB      'File Delete Tests (F19)', CR, LF
        DB      '=======================', CR, LF, '$'
MSGSETUP: DB    'Setup: Creating test files... ', '$'
MSGSETERR: DB   'FAIL: Cannot create test files', CR, LF, '$'

MSG_T1: DB      'T1: F19 Delete existing... ', '$'
MSG_T2: DB      'T2: F19 Del non-exist (no crash)... ', '$'
MSG_T3: DB      'T3: Verify DEL1 gone... ', '$'
MSG_T4: DB      'T4: DEL2,DEL3 still exist... ', '$'
MSG_T5: DB      'T5: Delete wildcard DEL?... ', '$'
MSG_T6: DB      'T6: Verify DEL2 gone... ', '$'
MSG_T7: DB      'T7: Verify DEL3 gone... ', '$'
MSG_T8: DB      'T8: Delete already-deleted... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGEXP: DB      'Expected 0-3', CR, LF, '$'
MSGFF:  DB      'Expected FFH', CR, LF, '$'
MSGSTILL: DB    'File still exists', CR, LF, '$'
MSGGONE: DB     'File missing', CR, LF, '$'
MSGWC:  DB      'Wildcard delete failed', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
