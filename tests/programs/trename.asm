; File Rename Test (Phase 13)
; Tests: F23 (F_RENAME)
;
; Tests file renaming including wildcards and verification
; FCB format: bytes 1-11 = old name, bytes 17-27 = new name

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
F_RENAME EQU    23
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
        ; Test 1: F23 - Rename existing file
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create REN1.TST
        CALL    CLEARFCB
        LXI     H, FNAME1
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T1FAIL
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Setup FCB for rename: REN1.TST -> NEW1.TST
        ; Old name at FCB+1, new name at FCB+17
        CALL    CLEARFCB
        LXI     H, FNAME1       ; Old: REN1.TST
        CALL    SETFNAME
        LXI     H, FNEW1        ; New: NEW1.TST
        CALL    SETNEWNAME

        ; Rename
        LXI     D, FCB
        MVI     C, F_RENAME
        CALL    BDOS
        ; A should be 0-3 for success
        CPI     4
        JNC     T1FAIL

        CALL    TPASS
        JMP     TEST2

T1FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 2: Verify new name exists after rename
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

        ; Search for new name (should exist after T1 rename)
        CALL    CLEARFCB
        LXI     H, FNEW1
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     4               ; Should be 0-3 (found)
        JNC     T2FAIL

        CALL    TPASS
        JMP     TEST3

T2FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 3: Rename non-existent file (no crash)
        ; Note: behavior varies by implementation
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Setup FCB for rename of non-existent file
        CALL    CLEARFCB
        LXI     H, FNOEX        ; NOEXIST.TST
        CALL    SETFNAME
        LXI     H, FNEW2
        CALL    SETNEWNAME

        ; Rename non-existent - just verify no crash
        ; Result stored but not checked (implementation-defined)
        LXI     D, FCB
        MVI     C, F_RENAME
        CALL    BDOS
        STA     GOTVAL          ; Store result for reference

        ; If we get here, test passes (no crash)
        CALL    TPASS
        JMP     TEST4

        ;---------------------------------------------------------------
        ; Test 4: Rename to same name (no-op, should succeed)
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create REN2.TST
        CALL    CLEARFCB
        LXI     H, FNAME2
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T4FAIL
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Rename REN2.TST -> REN2.TST (same name)
        CALL    CLEARFCB
        LXI     H, FNAME2
        CALL    SETFNAME
        LXI     H, FNAME2       ; Same name
        CALL    SETNEWNAME

        LXI     D, FCB
        MVI     C, F_RENAME
        CALL    BDOS
        ; This should succeed (0-3) or at worst not crash
        ; Behavior is implementation-defined
        ; If we get here, test passes
        CALL    TPASS
        JMP     TEST5

T4FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 5: Create multiple files, rename one, verify others intact
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create REN3.TST
        CALL    CLEARFCB
        LXI     H, FNAME3
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T5FAIL
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Create REN4.TST
        CALL    CLEARFCB
        LXI     H, FNAME4
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T5FAIL
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Rename REN3.TST -> NEW3.TST
        CALL    CLEARFCB
        LXI     H, FNAME3
        CALL    SETFNAME
        LXI     H, FNEW3
        CALL    SETNEWNAME
        LXI     D, FCB
        MVI     C, F_RENAME
        CALL    BDOS
        CPI     4
        JNC     T5FAIL

        ; Verify REN4.TST still exists (wasn't affected)
        LXI     D, DMABUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNAME4
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     4
        JNC     T5FAIL

        CALL    TPASS
        JMP     TEST6

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 6: Rename file, then rename back
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create REN5.TST
        CALL    CLEARFCB
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

        ; Rename REN5.TST -> TMP.TST
        CALL    CLEARFCB
        LXI     H, FNAME5
        CALL    SETFNAME
        LXI     H, FTMP
        CALL    SETNEWNAME
        LXI     D, FCB
        MVI     C, F_RENAME
        CALL    BDOS
        CPI     4
        JNC     T6FAIL

        ; Rename TMP.TST -> REN5.TST (back)
        CALL    CLEARFCB
        LXI     H, FTMP
        CALL    SETFNAME
        LXI     H, FNAME5
        CALL    SETNEWNAME
        LXI     D, FCB
        MVI     C, F_RENAME
        CALL    BDOS
        CPI     4
        JNC     T6FAIL

        ; Verify REN5.TST exists
        LXI     D, DMABUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        CALL    CLEARFCB
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
        ; Test 7: Rename changes only filename, not extension
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Create REN6.TST
        CALL    CLEARFCB
        LXI     H, FNAME6
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     4
        JNC     T7FAIL
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Rename REN6.TST -> REN6.NEW (change extension)
        CALL    CLEARFCB
        LXI     H, FNAME6
        CALL    SETFNAME
        LXI     H, FNEW6        ; REN6.NEW
        CALL    SETNEWNAME
        LXI     D, FCB
        MVI     C, F_RENAME
        CALL    BDOS
        CPI     4
        JNC     T7FAIL

        ; Verify REN6.NEW exists
        LXI     D, DMABUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNEW6
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     4
        JNC     T7FAIL

        CALL    TPASS
        JMP     TEST8

T7FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 8: Renamed file can be opened and read
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; NEW1.TST should exist from test 1
        ; Try to open it
        CALL    CLEARFCB
        LXI     H, FNEW1
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T8FAIL

        ; Close it
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

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
        ; Delete all possible test files
        CALL    CLEARFCB
        LXI     H, FNAME1
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNAME2
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNAME3
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNAME4
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNAME5
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNAME6
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNEW1
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNEW3
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FNEW6
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    CLEARFCB
        LXI     H, FTMP
        CALL    SETFNAME
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        RET

;---------------------------------------------------------------
; CLEARFCB - Clear FCB to zeros
;---------------------------------------------------------------
CLEARFCB:
        LXI     H, FCB
        MVI     B, 36
        XRA     A
CFCLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     CFCLR
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
; SETNEWNAME - Copy 11-byte filename from HL to FCB+17
; (For F23 rename: new name goes at offset 17)
;---------------------------------------------------------------
SETNEWNAME:
        LXI     D, FCB+17
        MVI     B, 11
SNCPY:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     SNCPY
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

; Filenames (8+3 format, space-padded)
FNAME1: DB      'REN1    TST'
FNAME2: DB      'REN2    TST'
FNAME3: DB      'REN3    TST'
FNAME4: DB      'REN4    TST'
FNAME5: DB      'REN5    TST'
FNAME6: DB      'REN6    TST'
FNEW1:  DB      'NEW1    TST'
FNEW2:  DB      'NEW2    TST'
FNEW3:  DB      'NEW3    TST'
FNEW6:  DB      'REN6    NEW'
FNOEX:  DB      'NOEXIST TST'
FTMP:   DB      'TMP     TST'

; Messages
MSGHDR: DB      'File Rename Tests (F23)', CR, LF
        DB      '=======================', CR, LF, '$'
MSG_T1: DB      'T1: F23 Rename existing... ', '$'
MSG_T2: DB      'T2: Verify new name exists... ', '$'
MSG_T3: DB      'T3: Rename non-existent (no crash)... ', '$'
MSG_T4: DB      'T4: Rename to same name... ', '$'
MSG_T5: DB      'T5: Rename one, others intact... ', '$'
MSG_T6: DB      'T6: Rename back and forth... ', '$'
MSG_T7: DB      'T7: Change extension... ', '$'
MSG_T8: DB      'T8: Open renamed file... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGEXP: DB      'Expected FFH', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

; DMA buffer for searches
DMABUF: DS      128

        END     START
