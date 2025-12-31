; Sequential I/O Test (Phase 11)
; Tests: F20 (F_READ), F21 (F_WRITE)
;
; Tests sequential record read/write, CR increment, EOF handling,
; extent transitions, and data verification

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_OPEN  EQU     15
F_CLOSE EQU     16
F_DELETE EQU    19
F_READ  EQU     20
F_WRITE EQU     21
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

        ;---------------------------------------------------------------
        ; Test 1: F21 - Write single record
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete any existing test file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Create new file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     0FFH
        JZ      T1FAIL

        ; Fill write buffer with pattern (00-7F)
        LXI     H, WRBUF
        MVI     B, 128
        XRA     A
FILL1:
        MOV     M, A
        INX     H
        INR     A
        DCR     B
        JNZ     FILL1

        ; Set DMA to write buffer
        LXI     D, WRBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Write record (F21)
        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ; A=0 means success
        ORA     A
        JNZ     T1FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST2

T1FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 2: F20 - Read single record back
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Clear FCB extent/record fields for re-open
        CALL    SETUPFCB

        ; Open file
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4               ; 0-3 = success
        JNC     T2FAIL

        ; Set DMA to read buffer
        LXI     D, RDBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Clear read buffer
        LXI     H, RDBUF
        MVI     B, 128
        XRA     A
CLR2:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     CLR2

        ; Read record (F20)
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        ; A=0 means success
        ORA     A
        JNZ     T2FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST3

T2FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 3: Verify data matches (00-7F pattern)
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Compare WRBUF with RDBUF
        LXI     H, WRBUF
        LXI     D, RDBUF
        MVI     B, 128
VFY3:
        LDAX    D
        CMP     M
        JNZ     T3FAIL
        INX     H
        INX     D
        DCR     B
        JNZ     VFY3

        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL
        LXI     D, MSGMIS
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: Write 3 records, verify CR increments
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete and create new file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     0FFH
        JZ      T4FAIL

        ; Set DMA
        LXI     D, WRBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Check CR before writes (should be 0)
        LDA     FCB+32          ; CR = current record
        ORA     A
        JNZ     T4FAIL

        ; Write record 1
        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T4FAIL

        ; Check CR after first write (should be 1)
        LDA     FCB+32
        CPI     1
        JNZ     T4FAIL

        ; Write record 2
        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T4FAIL

        ; Check CR after second write (should be 2)
        LDA     FCB+32
        CPI     2
        JNZ     T4FAIL

        ; Write record 3
        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T4FAIL

        ; Check CR after third write (should be 3)
        LDA     FCB+32
        CPI     3
        JNZ     T4FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 5: Read past EOF (expect A=1)
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open the 3-record file from T4
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T5FAIL

        ; Set DMA
        LXI     D, RDBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Read 3 records (should succeed)
        MVI     B, 3
T5RD:
        PUSH    B
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        POP     B
        ORA     A
        JNZ     T5FAIL          ; Should not fail yet
        DCR     B
        JNZ     T5RD

        ; Now read 4th record - should return A=1 (EOF)
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        CPI     1               ; EOF indicator
        JNZ     T5FAIL2

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST6

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL
        JMP     TEST6

T5FAIL2:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEOF
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: Extent transition on write (129 records)
        ; CP/M extent holds 128 records, so record 129 triggers new extent
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete and create new file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     0FFH
        JZ      T6FAIL

        ; Set DMA
        LXI     D, WRBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Write 129 records (first extent = 128, second extent = 1)
        LXI     H, 129          ; Counter in HL
T6WR:
        PUSH    H
        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        POP     H
        ORA     A
        JNZ     T6FAIL
        DCX     H
        MOV     A, H
        ORA     L
        JNZ     T6WR

        ; Check extent number - should be 1 (second extent)
        LDA     FCB+12          ; EX = extent number
        ANI     1FH             ; Mask to get extent
        CPI     1
        JNZ     T6FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST7

T6FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 7: Extent transition on read (read 129 records)
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Re-open the 129-record file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T7FAIL

        ; Set DMA
        LXI     D, RDBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Read 129 records
        LXI     H, 129
T7RD:
        PUSH    H
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        POP     H
        ORA     A
        JNZ     T7FAIL
        DCX     H
        MOV     A, H
        ORA     L
        JNZ     T7RD

        ; Record 130 should be EOF
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        CPI     1               ; EOF
        JNZ     T7FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST8

T7FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 8: Verify DMA buffer has correct data after read
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete and create test file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     0FFH
        JZ      T8FAIL

        ; Fill write buffer with distinct pattern ('X' repeated)
        LXI     H, WRBUF
        MVI     B, 128
        MVI     A, 'X'
FILL8:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     FILL8

        ; Set DMA and write
        LXI     D, WRBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T8FAIL

        ; Close
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Clear read buffer with 'Y' (different pattern)
        LXI     H, RDBUF
        MVI     B, 128
        MVI     A, 'Y'
CLR8:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     CLR8

        ; Re-open and read
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T8FAIL

        LXI     D, RDBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        ORA     A
        JNZ     T8FAIL

        ; Verify RDBUF now contains 'X' (not 'Y')
        LXI     H, RDBUF
        MVI     B, 128
VFY8:
        MOV     A, M
        CPI     'X'
        JNZ     T8FAIL
        INX     H
        DCR     B
        JNZ     VFY8

        ; Close and cleanup
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     CLEANUP

T8FAIL:
        STA     GOTVAL
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Cleanup and Summary
        ;---------------------------------------------------------------
CLEANUP:
        ; Delete test file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
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
; SETUPFCB - Initialize FCB for SEQIO.TST
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

        ; Set filename: SEQIO.TST
        LXI     H, FCB+1
        MVI     M, 'S'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'Q'
        INX     H
        MVI     M, 'I'
        INX     H
        MVI     M, 'O'
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
GOTVAL: DB      0

; FCB for file operations (36 bytes)
FCB:    DS      36

; Messages
MSGHDR: DB      'Sequential I/O Tests (F20, F21)', CR, LF
        DB      '===============================', CR, LF, '$'
MSG_T1: DB      'T1: F21 Write single record... ', '$'
MSG_T2: DB      'T2: F20 Read single record... ', '$'
MSG_T3: DB      'T3: Verify data matches... ', '$'
MSG_T4: DB      'T4: CR increment (3 writes)... ', '$'
MSG_T5: DB      'T5: Read past EOF (A=1)... ', '$'
MSG_T6: DB      'T6: Extent transition write... ', '$'
MSG_T7: DB      'T7: Extent transition read... ', '$'
MSG_T8: DB      'T8: Verify DMA contents... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGMIS: DB      'Data mismatch', CR, LF, '$'
MSGEOF: DB      'Expected EOF (A=1)', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

; Buffers (128 bytes each)
WRBUF:  DS      128
RDBUF:  DS      128

        END     START
