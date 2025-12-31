; DMA Address Test (Phase 14)
; Tests: F26 (F_DMAOFF)
;
; Tests DMA address setting, persistence, and proper use by file operations

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_OPEN  EQU     15
F_CLOSE EQU     16
F_SFIRST EQU    17
F_DELETE EQU    19
F_READ  EQU     20
F_WRITE EQU     21
F_MAKE  EQU     22
F_DMAOFF EQU    26

; ASCII
CR      EQU     0DH
LF      EQU     0AH

; Default DMA
DEFDMA  EQU     0080H

; Test tracking
TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0

START:
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: Set DMA to default 0080H (verify no crash)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set DMA to default address
        LXI     D, DEFDMA
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; If we got here without crash, pass
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 2: Set DMA to custom address, verify read uses it
        ; Create a file, write data, re-open, set custom DMA, read, verify
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete any existing test file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Create test file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     0FFH
        JZ      T2FAIL

        ; Fill BUF1 with pattern A5H
        LXI     H, BUF1
        MVI     B, 128
        MVI     A, 0A5H
T2FILL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T2FILL

        ; Set DMA to BUF1, write record
        LXI     D, BUF1
        MVI     C, F_DMAOFF
        CALL    BDOS

        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T2FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Clear BUF2 with zeros
        LXI     H, BUF2
        MVI     B, 128
        XRA     A
T2CLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T2CLR

        ; Re-open file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T2FAIL

        ; Set DMA to BUF2 (different buffer)
        LXI     D, BUF2
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Read record
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        ORA     A
        JNZ     T2FAIL

        ; Verify BUF2 now contains A5H pattern
        LXI     H, BUF2
        MVI     B, 128
T2VFY:
        MOV     A, M
        CPI     0A5H
        JNZ     T2FAIL
        INX     H
        DCR     B
        JNZ     T2VFY

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST3

T2FAIL:
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 3: Set DMA to custom address, verify search uses it
        ; F17 places directory entry at DMA address
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Clear BUF1 with zeros
        LXI     H, BUF1
        MVI     B, 128
        XRA     A
T3CLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T3CLR

        ; Set DMA to BUF1
        LXI     D, BUF1
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Search for DMATEST.TST (which we created in T2)
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     4               ; 0-3 = found
        JNC     T3FAIL

        ; Directory entry is at BUF1 + (A * 32)
        ; Calculate offset: multiply A by 32
        ADD     A               ; A*2
        ADD     A               ; A*4
        ADD     A               ; A*8
        ADD     A               ; A*16
        ADD     A               ; A*32
        MOV     E, A
        MVI     D, 0
        LXI     H, BUF1
        DAD     D               ; HL = BUF1 + offset

        ; First byte should be user number (0)
        MOV     A, M
        ORA     A               ; Should be 0 (user 0)
        JNZ     T3FAIL

        ; Byte at offset 1 should be 'D' (first char of DMATEST)
        INX     H
        MOV     A, M
        CPI     'D'
        JNZ     T3FAIL

        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 4: DMA at page boundary (0200H, 0300H)
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Re-open test file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T4FAIL

        ; Set DMA to PAGEBUF (aligned to 256-byte boundary)
        LXI     D, PAGEBUF
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Clear page buffer
        LXI     H, PAGEBUF
        MVI     B, 128
        XRA     A
T4CLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T4CLR

        ; Read record
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        ORA     A
        JNZ     T4FAIL

        ; Verify data at page boundary
        LXI     H, PAGEBUF
        MOV     A, M
        CPI     0A5H            ; Should contain our A5H pattern
        JNZ     T4FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL

        ;---------------------------------------------------------------
        ; Test 5: DMA persistence across multiple operations
        ; Set DMA once, do multiple reads, verify all go to same place
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete and create multi-record file
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_DELETE
        CALL    BDOS

        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_MAKE
        CALL    BDOS
        CPI     0FFH
        JZ      T5FAIL

        ; Set DMA to BUF1
        LXI     D, BUF1
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Write 3 records with different patterns
        ; Record 1: all 11H
        LXI     H, BUF1
        MVI     B, 128
        MVI     A, 11H
T5F1:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T5F1

        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T5FAIL

        ; Record 2: all 22H
        LXI     H, BUF1
        MVI     B, 128
        MVI     A, 22H
T5F2:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T5F2

        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T5FAIL

        ; Record 3: all 33H
        LXI     H, BUF1
        MVI     B, 128
        MVI     A, 33H
T5F3:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T5F3

        LXI     D, FCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     T5FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Re-open and read all 3 records
        CALL    SETUPFCB
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T5FAIL

        ; Set DMA to BUF2 ONCE - should persist
        LXI     D, BUF2
        MVI     C, F_DMAOFF
        CALL    BDOS

        ; Read record 1 - should go to BUF2
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        ORA     A
        JNZ     T5FAIL

        ; Verify BUF2 has 11H (record 1 data)
        LDA     BUF2
        CPI     11H
        JNZ     T5FAIL

        ; Read record 2 - should STILL go to BUF2 (DMA persists)
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        ORA     A
        JNZ     T5FAIL

        ; Verify BUF2 now has 22H (record 2 overwrote)
        LDA     BUF2
        CPI     22H
        JNZ     T5FAIL

        ; Read record 3 - should STILL go to BUF2
        LXI     D, FCB
        MVI     C, F_READ
        CALL    BDOS
        ORA     A
        JNZ     T5FAIL

        ; Verify BUF2 now has 33H
        LDA     BUF2
        CPI     33H
        JNZ     T5FAIL

        ; Close file
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS

        CALL    TPASS
        JMP     CLEANUP

T5FAIL:
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

        ; Restore default DMA
        LXI     D, DEFDMA
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
; SETUPFCB - Initialize FCB for DMATEST.TST
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

        ; Set filename: DMATEST.TST
        LXI     H, FCB+1
        MVI     M, 'D'
        INX     H
        MVI     M, 'M'
        INX     H
        MVI     M, 'A'
        INX     H
        MVI     M, 'T'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'S'
        INX     H
        MVI     M, 'T'
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

; FCB for file operations (36 bytes)
FCB:    DS      36

; Messages
MSGHDR: DB      'DMA Address Tests (F26)', CR, LF
        DB      '=======================', CR, LF, '$'
MSG_T1: DB      'T1: Set DMA to default... ', '$'
MSG_T2: DB      'T2: Custom DMA for read... ', '$'
MSG_T3: DB      'T3: Custom DMA for search... ', '$'
MSG_T4: DB      'T4: DMA at page boundary... ', '$'
MSG_T5: DB      'T5: DMA persistence... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

; Buffers (128 bytes each)
BUF1:   DS      128
BUF2:   DS      128

; Page-aligned buffer (for T4)
; Align to next 256-byte boundary
        ORG     ($+255) AND 0FF00H
PAGEBUF: DS     128

        END     START
