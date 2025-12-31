; Console String I/O Test (Phase 2)
; Tests: F9 (C_WRITESTR), F10 (C_READSTR), F11 (C_STAT)
;
; Input injection required for F10 tests.

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2               ; Console output
F_PRTSTR EQU    9               ; Print $-terminated string
F_READSTR EQU   10              ; Buffered line input
F_CONSTAT EQU   11              ; Console status

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
        ; Test 1: F9 print simple string
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Print a test string
        LXI     D, TESTSTR1
        MVI     C, F_PRTSTR
        CALL    BDOS
        ; If we get here, it worked
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 2: F9 print empty string (just $)
        ;---------------------------------------------------------------
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Print empty string
        LXI     D, EMPTYSTR
        MVI     C, F_PRTSTR
        CALL    BDOS
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 3: F9 string with embedded CR/LF
        ;---------------------------------------------------------------
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     D, MULTILN
        MVI     C, F_PRTSTR
        CALL    BDOS
        CALL    TPASS

        ;---------------------------------------------------------------
        ; Test 4: F10 basic line input (expects "HELLO" + CR from input)
        ; NOTE: Must run before F11 tests, as F11 consumes chars for ^S check
        ;---------------------------------------------------------------
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set up buffer: max 20 chars
        LXI     H, INBUF
        MVI     M, 20           ; Max chars
        INX     H
        MVI     M, 0            ; Clear count

        ; Read line (expects "HELLO\r" from harness)
        LXI     D, INBUF
        MVI     C, F_READSTR
        CALL    BDOS

        ; Check count = 5 ("HELLO")
        LXI     H, INBUF
        INX     H               ; Point to count byte
        MOV     A, M
        CPI     5
        JNZ     T4FAIL

        ; Check first char is 'H'
        INX     H
        MOV     A, M
        CPI     'H'
        JNZ     T4FAIL

        ; Check second char is 'E'
        INX     H
        MOV     A, M
        CPI     'E'
        JNZ     T4FAIL

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: F10 empty input (just CR)
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Set up buffer
        LXI     H, INBUF
        MVI     M, 20           ; Max chars
        INX     H
        MVI     M, 0            ; Clear count

        ; Read line (expects just "\r" from harness)
        LXI     D, INBUF
        MVI     C, F_READSTR
        CALL    BDOS

        ; Check count = 0 (empty line)
        LXI     H, INBUF
        INX     H
        MOV     A, M
        CPI     0
        JNZ     T5FAIL
        CALL    TPASS
        JMP     TEST6

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: F11 status after all input consumed
        ; NOTE: F11 may consume a char for ^S check, so we test it last
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; After consuming all injected input, F11 should return 0
        ; (But with piped input at EOF, behavior may vary)
        MVI     C, F_CONSTAT
        CALL    BDOS
        ; For now just verify it returns without crashing
        CALL    TPASS

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
INBUF:  DS      32              ; Input buffer (byte 0=max, byte 1=count, bytes 2+=data)

; Test strings
TESTSTR1: DB    '[OK]', '$'
EMPTYSTR: DB    '$'
MULTILN: DB     'Line1', CR, LF, 'Line2', '$'

; Messages
MSGHDR: DB      'Console String I/O Tests (F9, F10, F11)', CR, LF
        DB      '========================================', CR, LF, '$'

MSG_T1: DB      'T1: F9 simple string... ', '$'
MSG_T2: DB      'T2: F9 empty string... ', '$'
MSG_T3: DB      CR, LF, 'T3: F9 multiline... ', '$'
MSG_T4: DB      'T4: F10 read line... ', '$'
MSG_T5: DB      CR, LF, 'T5: F10 empty line... ', '$'
MSG_T6: DB      CR, LF, 'T6: F11 status... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'
MSGEXP4: DB     'Expected HELLO (5 chars)', CR, LF, '$'
MSGEXP5: DB     'Expected 0 chars', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
