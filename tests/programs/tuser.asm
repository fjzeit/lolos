; BDOS User Number Test (Function 32)
; Tests: Get user, Set user, User isolation
;
; F32 with E=FFH returns current user number
; F32 with E=0-15 sets user number
;
; T1: Initial user = 0 after reset
; T2: Set user 5, get 5
; T3: Set user 15 (max), get 15
; T4: User masked to 0-15
; T5: Reset clears user to 0
; T6: E=FFH returns current without changing
; T7: User isolation (file in user 0 not visible from user 1)

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_RESETDSK EQU  13
F_SFIRST EQU    17
F_DELETE EQU    19
F_MAKE  EQU     22
F_CLOSE EQU     16
F_SETDMA EQU    26
F_USERNUM EQU   32

; FCB address
DFCB    EQU     005CH

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
        JMP     TEST6

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
        ; Test 6: E=FFH returns current without changing
        ; Set to 3, call get twice, verify still 3
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set user to 3
        MVI     E, 3
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Get user (E=FFH) - first call
        MVI     E, 0FFH
        MVI     C, F_USERNUM
        CALL    BDOS
        CPI     3
        JNZ     T6FAIL

        ; Get user (E=FFH) - second call (should not change)
        MVI     E, 0FFH
        MVI     C, F_USERNUM
        CALL    BDOS
        CPI     3
        JNZ     T6FAIL

        ; Get user again - third time to be sure
        MVI     E, 0FFH
        MVI     C, F_USERNUM
        CALL    BDOS
        CPI     3
        JNZ     T6FAIL

        CALL    TPASS
        JMP     TEST7

T6FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS
        MVI     E, '3'
        MVI     C, F_CONOUT
        CALL    BDOS
        LXI     D, MSGGOT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     GOTVAL
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 7: User isolation
        ; Create file in user 0, switch to user 1, verify not visible
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Ensure user 0
        MVI     E, 0
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Delete test file if exists
        LXI     H, FCBTEST
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Create test file USRTST.TMP in user 0
        LXI     H, FCBTEST
        CALL    SETFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      T7FAIL          ; Create failed

        ; Close file
        LXI     D, DFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Verify file exists in user 0
        LXI     D, DMABUF
        MVI     C, F_SETDMA
        CALL    BDOS
        LXI     H, FCBTEST
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T7FAIL          ; File should exist in user 0

        ; Switch to user 1
        MVI     E, 1
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Search for file - should NOT be found (user isolation)
        LXI     H, FCBTEST
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JNZ     T7FAIL          ; File should NOT be visible in user 1

        ; Switch back to user 0
        MVI     E, 0
        MVI     C, F_USERNUM
        CALL    BDOS

        ; Cleanup: delete test file
        LXI     H, FCBTEST
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    TPASS
        JMP     SUMMARY

T7FAIL:
        ; Cleanup attempt
        MVI     E, 0
        MVI     C, F_USERNUM
        CALL    BDOS
        LXI     H, FCBTEST
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    TFAIL
        LXI     D, MSGISO
        MVI     C, F_PRTSTR
        CALL    BDOS

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

; Storage
GOTVAL: DB      0

; Test FCB for user isolation test
FCBTEST: DB     0, 'USRTST  ', 'TMP'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; DMA buffer for search
DMABUF: DS      128

; Messages
MSGHDR: DB      'BDOS User Number Tests (F32)', CR, LF
        DB      '============================', CR, LF, '$'
MSG_T1: DB      'T1: Initial user = 0... ', '$'
MSG_T2: DB      'T2: Set user 5, get 5... ', '$'
MSG_T3: DB      'T3: Set user 15, get 15... ', '$'
MSG_T4: DB      'T4: User masked to 0-15... ', '$'
MSG_T5: DB      'T5: Reset clears user... ', '$'
MSG_T6: DB      'T6: E=FFH idempotent... ', '$'
MSG_T7: DB      'T7: User isolation... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGEXP: DB      'Expected ', '$'
MSGGOT: DB      ', got ', '$'
MSGISO: DB      'User isolation failed', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
