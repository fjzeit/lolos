; File Open/Close Test (Phase 8)
; Tests: F15 (F_OPEN), F16 (F_CLOSE)
;
; Uses HELLO.COM which should exist on disk

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

        ;---------------------------------------------------------------
        ; Test 1: F15 - Open existing file (HELLO.COM)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Initialize FCB for HELLO.COM
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'H'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        ; Type = COM
        LXI     H, FCB+9
        MVI     M, 'C'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'M'

        ; Open the file
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        ; A should be 0-3 (directory code) for success
        CPI     4
        JNC     T1FAIL          ; >= 4 means error (FFH)
        CALL    TPASS
        JMP     TEST2

T1FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGDIR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 2: F15 - Open non-existent file (expect FFH)
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Initialize FCB for NOEXIST.XXX
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'N'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'X'
        INX     H
        MVI     M, 'I'
        INX     H
        MVI     M, 'S'
        INX     H
        MVI     M, 'T'
        INX     H
        MVI     M, ' '
        ; Type = XXX
        LXI     H, FCB+9
        MVI     M, 'X'
        INX     H
        MVI     M, 'X'
        INX     H
        MVI     M, 'X'

        ; Try to open
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        ; A should be FFH (not found)
        CPI     0FFH
        JNZ     T2FAIL
        CALL    TPASS
        JMP     TEST3

T2FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: F16 - Close file after open
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; First open HELLO.COM
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'H'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        LXI     H, FCB+9
        MVI     M, 'C'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'M'

        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T3FAIL          ; Open failed

        ; Now close it
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS
        ; A should be 0-3 for success
        CPI     4
        JNC     T3FAIL
        CALL    TPASS
        JMP     TEST4

T3FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGCLS
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: F15 - Verify FCB fields after open (RC valid)
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open HELLO.COM
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'H'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        LXI     H, FCB+9
        MVI     M, 'C'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'M'

        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T4FAIL

        ; Check RC field (FCB+15) - should be > 0 for non-empty file
        LDA     FCB+15          ; RC = record count
        ORA     A
        JZ      T4FAIL          ; HELLO.COM should have some records
        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGRC
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: F15 - Open with wildcard (? in extension)
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Setup FCB for HELLO.???
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'H'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        ; Type = ??? (wildcards)
        LXI     H, FCB+9
        MVI     M, '?'
        INX     H
        MVI     M, '?'
        INX     H
        MVI     M, '?'

        ; Open with wildcard should find first match
        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        ; Should succeed if HELLO.COM exists
        CPI     4
        JNC     T5FAIL
        CALL    TPASS
        JMP     TEST6

T5FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGWC
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: F16 - Close without prior open (FCB zeroed)
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Clear FCB completely
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'Z'          ; ZZZZZZZZ.ZZZ - unlikely to exist
        INX     H
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'
        LXI     H, FCB+9
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'
        INX     H
        MVI     M, 'Z'

        ; Try to close without opening - behavior varies
        ; Some implementations return FFH, others return 0
        ; We just verify it doesn't crash
        LXI     D, FCB
        MVI     C, F_CLOSE
        CALL    BDOS
        ; If we get here, test passed (no crash)
        CALL    TPASS
        JMP     TEST7

        ;---------------------------------------------------------------
        ; Test 7: F15 - Verify extent 0 after open
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open HELLO.COM (should be extent 0)
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'H'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        LXI     H, FCB+9
        MVI     M, 'C'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'M'

        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T7FAIL

        ; Check EX field (FCB+12) - should be 0 for first open
        LDA     FCB+12
        ANI     1FH             ; Mask extent bits
        JNZ     T7FAIL          ; Should be extent 0
        CALL    TPASS
        JMP     TEST8

T7FAIL:
        CALL    TFAIL
        LXI     D, MSGEX
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 8: F15 - Verify allocation map populated after open
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open HELLO.COM
        CALL    INITFCB
        LXI     H, FCB+1
        MVI     M, 'H'
        INX     H
        MVI     M, 'E'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'L'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        INX     H
        MVI     M, ' '
        LXI     H, FCB+9
        MVI     M, 'C'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'M'

        LXI     D, FCB
        MVI     C, F_OPEN
        CALL    BDOS
        CPI     4
        JNC     T8FAIL

        ; Check D0 (FCB+16) - first allocation block, should be non-zero
        LDA     FCB+16
        ORA     A
        JZ      T8FAIL          ; File should have at least one block allocated
        CALL    TPASS
        JMP     SUMMARY

T8FAIL:
        CALL    TFAIL
        LXI     D, MSGALV
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Print Summary
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
; INITFCB - Clear FCB to all zeros, set drive to 0 (default)
;---------------------------------------------------------------
INITFCB:
        LXI     H, FCB
        MVI     B, 36           ; FCB is 36 bytes
INITLP:
        MVI     M, 0
        INX     H
        DCR     B
        JNZ     INITLP
        ; Set filename to spaces
        LXI     H, FCB+1
        MVI     B, 11
INITSP:
        MVI     M, ' '
        INX     H
        DCR     B
        JNZ     INITSP
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
MSGHDR: DB      'File Open/Close Tests (F15, F16)', CR, LF
        DB      '================================', CR, LF, '$'
MSG_T1: DB      'T1: F15 Open HELLO.COM... ', '$'
MSG_T2: DB      'T2: F15 Open non-existent... ', '$'
MSG_T3: DB      'T3: F16 Close after open... ', '$'
MSG_T4: DB      'T4: F15 Verify RC>0... ', '$'
MSG_T5: DB      'T5: F15 Open with wildcard... ', '$'
MSG_T6: DB      'T6: F16 Close without open... ', '$'
MSG_T7: DB      'T7: F15 Verify EX=0... ', '$'
MSG_T8: DB      'T8: F15 Verify alloc map... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGDIR: DB      'Expected dir code 0-3', CR, LF, '$'
MSGEXP: DB      'Expected FFH', CR, LF, '$'
MSGCLS: DB      'Close failed', CR, LF, '$'
MSGRC:  DB      'RC should be > 0', CR, LF, '$'
MSGWC:  DB      'Wildcard open failed', CR, LF, '$'
MSGEX:  DB      'EX should be 0', CR, LF, '$'
MSGALV: DB      'D0 should be non-zero', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
