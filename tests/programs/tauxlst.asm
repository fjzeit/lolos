; Auxiliary & List Device Tests (Phase 4)
; Tests: F3 (A_READ), F4 (A_WRITE), F5 (L_WRITE)
;
; These are legacy reader/punch/printer devices.
; Tests verify the functions work without crashing.

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2               ; Console output
F_AUXIN EQU     3               ; Auxiliary (reader) input
F_AUXOUT EQU    4               ; Auxiliary (punch) output
F_LSTOUT EQU    5               ; List (printer) output
F_PRTSTR EQU    9               ; Print $-terminated string

; ASCII
CR      EQU     0DH
LF      EQU     0AH
EOF     EQU     1AH             ; Ctrl-Z, end of file

; Test tracking
TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0

START:
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: F4 output character to auxiliary (punch)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Output 'P' to punch device
        MVI     E, 'P'
        MVI     C, F_AUXOUT
        CALL    BDOS
        ; Output 'U' to punch device
        MVI     E, 'U'
        MVI     C, F_AUXOUT
        CALL    BDOS
        ; If we get here without crash, pass
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 2: F5 output character to list (printer)
        ;---------------------------------------------------------------
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Output 'L' to list device
        MVI     E, 'L'
        MVI     C, F_LSTOUT
        CALL    BDOS
        ; Output 'S' to list device
        MVI     E, 'S'
        MVI     C, F_LSTOUT
        CALL    BDOS
        ; Output 'T' to list device
        MVI     E, 'T'
        MVI     C, F_LSTOUT
        CALL    BDOS
        ; If we get here without crash, pass
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 3: F5 output CR/LF to list
        ;---------------------------------------------------------------
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Output CR to list
        MVI     E, CR
        MVI     C, F_LSTOUT
        CALL    BDOS
        ; Output LF to list
        MVI     E, LF
        MVI     C, F_LSTOUT
        CALL    BDOS
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 4: F3 read from auxiliary (reader)
        ; Note: In cpmsim, reader likely returns EOF (1AH) or blocks
        ; This test verifies F3 returns without hanging
        ;---------------------------------------------------------------
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Read from reader device
        ; WARNING: This might block if reader has no data
        ; In cpmsim, it typically returns immediately with EOF or 0
        MVI     C, F_AUXIN
        CALL    BDOS
        ; A = character read (probably EOF=1AH or 0)
        STA     GOTVAL
        ; Verify we got a value (any value is acceptable)
        ; Just check we didn't crash
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 5: Verify F3 return value is in expected range
        ;---------------------------------------------------------------
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Check that the value from T4 is a valid byte
        LDA     GOTVAL
        ; Should be 00-7F (7-bit ASCII) per BIOS spec
        ; BIOS does ANI 7FH so high bit is always clear
        ANI     80H
        JNZ     T5FAIL
        CALL    TPASS
        JMP     SUMMARY

T5FAIL:
        CALL    TFAIL
        LXI     D, MSGHI
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
MSGHDR: DB      'Auxiliary & List Device Tests (F3, F4, F5)', CR, LF
        DB      '==========================================', CR, LF, '$'

MSG_T1: DB      'T1: F4 punch output... ', '$'
MSG_T2: DB      'T2: F5 list output... ', '$'
MSG_T3: DB      'T3: F5 list CR/LF... ', '$'
MSG_T4: DB      'T4: F3 reader input... ', '$'
MSG_T5: DB      'T5: F3 7-bit value... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGHI:  DB      'High bit set', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
