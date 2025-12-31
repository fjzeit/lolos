; File Create Test (Phase 12)
; Tests: F22 (F_MAKE)
;
; Tests file creation, FCB initialization, duplicate handling,
; and persistence after close/reopen

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_OPEN  EQU     15
F_CLOSE EQU     16
F_SFIRST EQU    17
F_DELETE EQU    19
F_MAKE  EQU     22
F_DMAOFF EQU    26

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

        ; Clean up any leftover test files
        CALL    CLEANUP

        ;---------------------------------------------------------------
        ; Test 1: F22 - Create new file (expect 0-3)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Setup FCB for MAKE1.TST
        CALL    SETUPFCB
        LXI     H, FNAME1
        CALL    SETFNAME

        ; Create the file
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        ; A should be 0-3 (directory code) for success
        CPI     4
        JNC     T1FAIL

        ; Close the file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST2

T1FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 2: Verify file exists via search
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set DMA for search
        LXI     D, DMABUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Setup FCB for MAKE1.TST
        CALL    SETUPFCB
        LXI     H, FNAME1
        CALL    SETFNAME

        ; Search for file
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        ; A should be 0-3 if found
        CPI     4
        JNC     T2FAIL

        CALL    TPASS
        JMP     TEST3

T2FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGNF
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: Create file that already exists
        ; Behavior varies by implementation - we just verify no crash
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Setup FCB for MAKE1.TST (already exists)
        CALL    SETUPFCB
        LXI     H, FNAME1
        CALL    SETFNAME

        ; Try to create again
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        ; Store result but don't fail - behavior is implementation-defined
        ; Some return error, some create duplicate extent
        ; If we got here without crash, test passes
        STA     GOTVAL

        ; Close if it succeeded
        CPI     4
        JNC     T3SKIP
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS
T3SKIP:
        CALL    TPASS
        JMP     TEST4

        ;---------------------------------------------------------------
        ; Test 4: Verify FCB fields after create (EX=0, CR=0)
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete and create fresh file
        CALL    SETUPFCB
        LXI     H, FNAME2
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME2
        CALL    SETFNAME

        ; Create file
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T4FAIL

        ; Check EX (FCB+12) = 0
        LDA     FCB+12
        ANI     1FH
        JNZ     T4FAIL

        ; Check CR (FCB+32) = 0
        LDA     FCB+32
        ORA     A
        JNZ     T4FAIL

        ; Close
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 5: Create, close, reopen (verify persistence)
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete and create MAKE3.TST
        CALL    SETUPFCB
        LXI     H, FNAME3
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME3
        CALL    SETFNAME

        ; Create
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T5FAIL

        ; Close
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS
        CPI     4
        JNC     T5FAIL

        ; Clear FCB and reopen
        CALL    SETUPFCB
        LXI     H, FNAME3
        CALL    SETFNAME

        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T5FAIL          ; File should exist

        ; Close
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST6

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 6: Create multiple files in sequence
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create MAKE4.TST
        CALL    SETUPFCB
        LXI     H, FNAME4
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME4
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T6FAIL
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Create MAKE5.TST
        CALL    SETUPFCB
        LXI     H, FNAME5
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME5
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T6FAIL
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Verify both exist
        LXI     D, DMABUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME4
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     4
        JNC     T6FAIL

        CALL    SETUPFCB
        LXI     H, FNAME5
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     4
        JNC     T6FAIL

        CALL    TPASS
        JMP     TEST7

T6FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 7: Verify RC=0 after create (empty file)
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create fresh file
        CALL    SETUPFCB
        LXI     H, FNAME6
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME6
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T7FAIL

        ; Check RC (FCB+15) = 0 for new empty file
        LDA     FCB+15
        ORA     A
        JNZ     T7FAIL

        ; Close
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST8

T7FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 8: Create file with spaces in name
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create file with shorter name (spaces in filename area)
        CALL    SETUPFCB
        LXI     H, FNAME7
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME7
        CALL    SETFNAME

        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T8FAIL

        ; Close
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Verify it exists via search
        LXI     D, DMABUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        CALL    SETUPFCB
        LXI     H, FNAME7
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     4
        JNC     T8FAIL

        CALL    TPASS
        JMP     ENDTEST

T8FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Cleanup and Summary
        ;---------------------------------------------------------------
ENDTEST:
        CALL    CLEANUP

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

        ; Final result
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
; CLEANUP - Delete all test files
;---------------------------------------------------------------
CLEANUP:
        ; Delete MAKE1.TST
        CALL    SETUPFCB
        LXI     H, FNAME1
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Delete MAKE2.TST
        CALL    SETUPFCB
        LXI     H, FNAME2
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Delete MAKE3.TST
        CALL    SETUPFCB
        LXI     H, FNAME3
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Delete MAKE4.TST
        CALL    SETUPFCB
        LXI     H, FNAME4
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Delete MAKE5.TST
        CALL    SETUPFCB
        LXI     H, FNAME5
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Delete MAKE6.TST
        CALL    SETUPFCB
        LXI     H, FNAME6
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Delete MAKE7.TST
        CALL    SETUPFCB
        LXI     H, FNAME7
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        RET

;---------------------------------------------------------------
; SETUPFCB - Clear FCB to zeros
;---------------------------------------------------------------
SETUPFCB:
        LXI     H, FCB
        MVI     B, 36
        XRA     A
SFCLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     SFCLR
        RET

;---------------------------------------------------------------
; SETFNAME - Copy 11-byte filename from HL to FCB+1
;---------------------------------------------------------------
SETFNAME:
        LXI     D, FCB+1
        MVI     B, 11
SFCPY:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     SFCPY
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

; FCB for file operations (36 bytes)
FCB:    DS      36

; Filenames (8+3 format)
FNAME1: DB      'MAKE1   TST'
FNAME2: DB      'MAKE2   TST'
FNAME3: DB      'MAKE3   TST'
FNAME4: DB      'MAKE4   TST'
FNAME5: DB      'MAKE5   TST'
FNAME6: DB      'MAKE6   TST'
FNAME7: DB      'MAKE7   TST'

; Messages
MSGHDR: DB      'File Create Tests (F22)', CR, LF
        DB      '=======================', CR, LF, '$'
MSG_T1: DB      'T1: F22 Create new file... ', '$'
MSG_T2: DB      'T2: Verify via search... ', '$'
MSG_T3: DB      'T3: Create existing (no crash)... ', '$'
MSG_T4: DB      'T4: Verify EX=0, CR=0... ', '$'
MSG_T5: DB      'T5: Create, close, reopen... ', '$'
MSG_T6: DB      'T6: Create multiple files... ', '$'
MSG_T7: DB      'T7: Verify RC=0 (empty)... ', '$'
MSG_T8: DB      'T8: Create + verify exists... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGNF:  DB      'File not found', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

; DMA buffer for searches
DMABUF: DS      128

        END     START
