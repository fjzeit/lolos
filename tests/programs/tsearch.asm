; BDOS Search Functions Test
; Tests: F17 (Search First), F18 (Search Next)
;
; Creates test files, then searches for them with various patterns

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_OPEN  EQU     15
F_CLOSE EQU     16
F_SFIRST EQU    17
F_SNEXT EQU     18
F_DELETE EQU    19
F_MAKE  EQU     22
F_SETDMA EQU    26

; FCB offsets
DFCB    EQU     005CH

; ASCII
CR      EQU     0DH
LF      EQU     0AH

; Test tracking
TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0

START:
        ; Print test header
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Setup: Create test files SRCH1.TST, SRCH2.TST, SRCH3.TST
        ;---------------------------------------------------------------
        LXI     D, MSGSETUP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete any existing test files
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

        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      SETUP_ERR

        LXI     H, FCB3
        CALL    SETFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      SETUP_ERR

        ; Close files
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     H, FCB3
        CALL    SETFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     D, MSGOK
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: Search for exact file SRCH1.TST
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set DMA for search results
        LXI     D, DMABUF
        MVI     C, F_SETDMA
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS

        ; A should be 0-3 (found)
        CPI     0FFH
        JZ      T1FAIL
        CALL    TPASS
        JMP     TEST2

T1FAIL:
        CALL    TFAIL
        LXI     D, MSGNF
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 2: Search for non-existent file
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCBNE
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS

        ; A should be FFH (not found)
        CPI     0FFH
        JNZ     T2FAIL
        CALL    TPASS
        JMP     TEST3

T2FAIL:
        CALL    TFAIL
        LXI     D, MSGFND
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: Search with wildcard *.TST - should find 3 files
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        XRA     A
        STA     FCOUNT          ; Count of files found

        LXI     H, FCBWC
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T3CHECK         ; No matches

T3LOOP:
        ; Count this match
        LDA     FCOUNT
        INR     A
        STA     FCOUNT
        CPI     10              ; Safety limit
        JNC     T3CHECK

        ; Search next
        MVI     C, F_SNEXT
        CALL    BDOS
        CPI     0FFH
        JNZ     T3LOOP

T3CHECK:
        LDA     FCOUNT
        CPI     3               ; Should find 3 files
        JC      T3FAIL          ; Less than 3
        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL
        LXI     D, MSGCNT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     FCOUNT
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 4: Search with wildcard SRCH?.TST - should find 3 files
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        XRA     A
        STA     FCOUNT

        LXI     H, FCBWC2
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T4CHECK

T4LOOP:
        LDA     FCOUNT
        INR     A
        STA     FCOUNT
        CPI     10
        JNC     T4CHECK

        MVI     C, F_SNEXT
        CALL    BDOS
        CPI     0FFH
        JNZ     T4LOOP

T4CHECK:
        LDA     FCOUNT
        CPI     3
        JC      T4FAIL
        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGCNT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     FCOUNT
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 5: Verify directory code (0-3) is valid
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS

        CPI     0FFH
        JZ      T5FAIL
        CPI     4               ; Should be 0-3
        JNC     T5FAIL
        CALL    TPASS
        JMP     TEST6

T5FAIL:
        CALL    TFAIL
        LXI     D, MSGDC
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: Verify DMA buffer has valid directory entry
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set DMA for search results
        LXI     D, DMABUF
        MVI     C, F_SETDMA
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T6FAIL

        ; A = directory code (0-3), entry is at DMABUF + (A * 32)
        ; Calculate offset
        ADD     A               ; A * 2
        ADD     A               ; A * 4
        ADD     A               ; A * 8
        ADD     A               ; A * 16
        ADD     A               ; A * 32
        MOV     E, A
        MVI     D, 0
        LXI     H, DMABUF
        DAD     D               ; HL = DMABUF + offset

        ; Check first byte is user number (0-15, not E5H)
        MOV     A, M
        CPI     0E5H            ; Deleted?
        JZ      T6FAIL
        CPI     16              ; User > 15?
        JNC     T6FAIL

        ; Check first char of filename is 'S' (from SRCH1)
        INX     H
        MOV     A, M
        CPI     'S'
        JNZ     T6FAIL
        CALL    TPASS
        JMP     TEST7

T6FAIL:
        CALL    TFAIL
        LXI     D, MSGDMA
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 7: Search with ? in middle position (SR?H1.TST)
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCBWC3
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        ; Should find SRCH1.TST
        CPI     0FFH
        JZ      T7FAIL
        CALL    TPASS
        JMP     TEST8

T7FAIL:
        CALL    TFAIL
        LXI     D, MSGNF
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 8: Search all files (*.*) - should find many
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        XRA     A
        STA     FCOUNT

        LXI     H, FCBALL
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T8CHECK

T8LOOP:
        LDA     FCOUNT
        INR     A
        STA     FCOUNT
        CPI     50              ; Safety limit
        JNC     T8CHECK

        MVI     C, F_SNEXT
        CALL    BDOS
        CPI     0FFH
        JNZ     T8LOOP

T8CHECK:
        ; Should find at least 3 (our test files) plus system files
        LDA     FCOUNT
        CPI     3
        JC      T8FAIL
        CALL    TPASS
        JMP     TEST9

T8FAIL:
        CALL    TFAIL
        LXI     D, MSGCNT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     FCOUNT
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 9: Verify full filename match in DMA
        ;---------------------------------------------------------------
TEST9:
        MVI     A, 9
        STA     TESTNUM
        LXI     D, MSG_T9
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set DMA
        LXI     D, DMABUF
        MVI     C, F_SETDMA
        CALL    BDOS

        ; Search for SRCH2.TST
        LXI     H, FCB2
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T9FAIL

        ; Get entry offset
        ADD     A
        ADD     A
        ADD     A
        ADD     A
        ADD     A               ; A * 32
        MOV     E, A
        MVI     D, 0
        LXI     H, DMABUF
        DAD     D
        INX     H               ; Skip user byte, now at filename

        ; Verify "SRCH2   TST"
        MVI     A, 'S'
        CMP     M
        JNZ     T9FAIL
        INX     H
        MVI     A, 'R'
        CMP     M
        JNZ     T9FAIL
        INX     H
        MVI     A, 'C'
        CMP     M
        JNZ     T9FAIL
        INX     H
        MVI     A, 'H'
        CMP     M
        JNZ     T9FAIL
        INX     H
        MVI     A, '2'
        CMP     M
        JNZ     T9FAIL

        CALL    TPASS
        JMP     CLEANUP

T9FAIL:
        CALL    TFAIL
        LXI     D, MSGNAME
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Cleanup: Delete test files
        ;---------------------------------------------------------------
CLEANUP:
        LXI     D, MSGCLEAN
        MVI     C, F_PRTSTR
        CALL    BDOS

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

        LXI     D, MSGOK
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
;         DR F1 F2 F3 F4 F5 F6 F7 F8 T1 T2 T3 EX S1 S2 RC ...
FCB1:   DB      0, 'SRCH1   ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0     ; 16 alloc bytes
        DB      0,0,0,0                             ; CR, R0, R1, R2

FCB2:   DB      0, 'SRCH2   ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

FCB3:   DB      0, 'SRCH3   ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Non-existent file
FCBNE:  DB      0, 'NOTHERE ', 'XXX'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Wildcard *.TST
FCBWC:  DB      0, '????????', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Wildcard SRCH?.TST
FCBWC2: DB      0, 'SRCH?   ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Wildcard SR?H1.TST (? in middle)
FCBWC3: DB      0, 'SR?H1   ', 'TST'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Wildcard *.* (all files)
FCBALL: DB      0, '????????', '???'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; Variables
FCOUNT: DB      0

; DMA buffer for search results
DMABUF: DS      128

; Messages
MSGHDR: DB      'BDOS Search Function Tests', CR, LF
        DB      '==========================', CR, LF, '$'
MSGSETUP: DB    'Setup: Creating test files... ', '$'
MSGCLEAN: DB    'Cleanup: Deleting test files... ', '$'
MSGSETERR: DB   'FAIL: Cannot create test files', CR, LF, '$'

MSG_T1: DB      'T1: F17 Search exact file... ', '$'
MSG_T2: DB      'T2: F17 Search non-existent... ', '$'
MSG_T3: DB      'T3: F17/18 Wildcard *.TST... ', '$'
MSG_T4: DB      'T4: F17/18 Wildcard SRCH?... ', '$'
MSG_T5: DB      'T5: Directory code 0-3... ', '$'
MSG_T6: DB      'T6: Verify DMA entry... ', '$'
MSG_T7: DB      'T7: Wildcard SR?H1.TST... ', '$'
MSG_T8: DB      'T8: Search *.* (all)... ', '$'
MSG_T9: DB      'T9: Verify filename in DMA... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGNF:  DB      'File not found', CR, LF, '$'
MSGFND: DB      'Should not find', CR, LF, '$'
MSGCNT: DB      'Expected 3+, got ', '$'
MSGDC:  DB      'Invalid directory code', CR, LF, '$'
MSGDMA: DB      'Invalid DMA entry', CR, LF, '$'
MSGNAME: DB     'Filename mismatch', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
