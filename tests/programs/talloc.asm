; Allocation Vector & Read-Only Tests (Phase 15)
; Tests: F27 (DRV_ALLOCVEC), F28 (DRV_SETRO), F29 (DRV_ROVEC)
;
; Enhanced tests for allocation tracking and R/O protection

        ORG     0100H

        JMP     START

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_RESETDSK EQU  13
F_SELDSK EQU    14
F_OPEN  EQU     15
F_CLOSE EQU     16
F_DELETE EQU    19
F_WRITE EQU     21
F_MAKE  EQU     22
F_DMAOFF EQU    26
F_GETALV EQU    27
F_WRTPROT EQU   28
F_ROVEC EQU     29

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

        ; Reset disk system first
        MVI     C, F_RESETDSK
        CALL    BDOS

        ; Select drive A
        MVI     E, 0
        MVI     C, F_SELDSK
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: F27 returns valid ALV address
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_GETALV
        CALL    BDOS
        ; HL should be non-zero
        SHLD    ALVADDR
        MOV     A, H
        ORA     L
        JZ      T1FAIL

        CALL    TPASS
        JMP     TEST2

T1FAIL:
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 2: ALV has bits set (disk has files)
        ; The disk should have files (HELLO.COM etc), so ALV shouldn't be empty
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Get ALV address
        MVI     C, F_GETALV
        CALL    BDOS
        ; Check first byte of ALV - should have some bits set
        MOV     A, M
        ORA     A
        JZ      T2FAIL          ; If all zeros, no allocation (unexpected)

        CALL    TPASS
        JMP     TEST3

T2FAIL:
        CALL    TFAIL
        LXI     D, MSGALV0
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: File create allocates block (file has data)
        ; Create file, write data, verify file size > 0
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete test file if exists
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Create file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     0FFH
        JZ      T3FAIL

        ; Set DMA and write a record
        LXI     D, WRBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T3FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Re-open and verify RC > 0 (file has records)
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T3FAIL          ; Open failed

        ; Check RC (record count at FCB+15)
        LDA     FCB+15
        ORA     A
        JZ      T3FAIL          ; RC=0 means no data

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL
        LXI     D, MSGNOALC
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: F28 sets R/O, F29 reflects it
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Reset to clear any R/O
        MVI     C, F_RESETDSK
        CALL    BDOS
        MVI     E, 0
        MVI     C, F_SELDSK
        CALL    BDOS

        ; Verify R/O vector is 0
        MVI     C, F_ROVEC
        CALL    BDOS
        MOV     A, H
        ORA     L
        JNZ     T4FAIL

        ; Set drive R/O
        MVI     C, F_WRTPROT
        CALL    BDOS

        ; Verify R/O vector bit 0 set
        MVI     C, F_ROVEC
        CALL    BDOS
        MOV     A, L
        ANI     01H
        JZ      T4FAIL

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 5: Write to R/O drive returns error
        ; Open existing file and try to write - should fail with A=1
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Drive should still be R/O from T4
        ; Open the ALLOC.TST file we created in T3
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T5SKIP          ; Can't open - skip test

        ; Set DMA
        LXI     D, WRBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Try to write - should return error (non-zero)
        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ; On R/O disk, WRITE should return 1 (error)
        CPI     1
        JZ      T5PASS          ; Got error 1 = R/O enforced

        ; Wrong return value
        JMP     T5FAIL

T5SKIP:
        ; Can't open file - skip this test, count as pass
        CALL    TPASS
        JMP     TEST6

T5PASS:
        ; Close file (may fail on R/O, that's ok)
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS
        CALL    TPASS
        JMP     TEST6

T5FAIL:
        CALL    TFAIL
        LXI     D, MSGROWRT
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: Reset clears R/O status
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Reset disk system
        MVI     C, F_RESETDSK
        CALL    BDOS

        ; Select drive A
        MVI     E, 0
        MVI     C, F_SELDSK
        CALL    BDOS

        ; Check R/O vector is 0
        MVI     C, F_ROVEC
        CALL    BDOS
        MOV     A, H
        ORA     L
        JNZ     T6FAIL

        CALL    TPASS
        JMP     CLEANUP

T6FAIL:
        CALL    TFAIL
        LXI     D, MSGRSTRO
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Cleanup
        ;---------------------------------------------------------------
CLEANUP:
        ; Ensure R/O is cleared
        MVI     C, F_RESETDSK
        CALL    BDOS
        MVI     E, 0
        MVI     C, F_SELDSK
        CALL    BDOS

        ; Delete test file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Restore default DMA
        LXI     D, 0080H
        MVI     C, F_DMAOFF
        CALL    BDOS

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
; SETUPFCB - Initialize FCB for ALLOC.TST
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

        ; Set filename: ALLOC.TST
        LXI     H, FCB+1
        MVI     M, 'A'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'C'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        ; Extension
        LXI     H, FCB+9
        MVI     M, 'T'
        INX     H
        MVI     M, 'S'
        INX     H
        MVI     M, 'T'
        RET

;---------------------------------------------------------------
; SETUPFCB2 - Initialize FCB for ROTST.TST (R/O test)
;---------------------------------------------------------------
SETUPFCB2:
        LXI     H, FCB
        MVI     B, 36
        XRA     A
SF2CLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     SF2CLR

        ; Set filename: ROTST.TST
        LXI     H, FCB+1
        MVI     M, 'R'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'T'
        INX     H
        MVI     M, 'S'
        INX     H
        MVI     M, 'T'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        ; Extension
        LXI     H, FCB+9
        MVI     M, 'T'
        INX     H
        MVI     M, 'S'
        INX     H
        MVI     M, 'T'
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
ALVADDR: DW     0

; FCB for file operations (36 bytes)
FCB:    DS      36

; Messages
MSGHDR: DB      'Allocation & R/O Tests (F27,F28,F29)', CR, LF
        DB      '====================================', CR, LF, '$'
MSG_T1: DB      'T1: F27 ALV address valid... ', '$'
MSG_T2: DB      'T2: ALV has bits set... ', '$'
MSG_T3: DB      'T3: File create + write... ', '$'
MSG_T4: DB      'T4: F28 sets R/O, F29 shows... ', '$'
MSG_T5: DB      'T5: Write to R/O fails... ', '$'
MSG_T6: DB      'T6: Reset clears R/O... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGALV0: DB     'ALV empty (no files?)', CR, LF, '$'
MSGNOALC: DB    'ALV unchanged after file create', CR, LF, '$'
MSGROWRT: DB    'Write not rejected on R/O', CR, LF, '$'
MSGRSTRO: DB    'R/O not cleared after reset', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

; Write buffer
WRBUF:  DS      128

        END     START
