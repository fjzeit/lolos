; BDOS Disk Management Test
; Tests: F13, F14, F24, F25, F27, F29, F31, F37
;
; F13 - Reset disk system
; F14 - Select disk
; F24 - Return login vector
; F25 - Return current disk
; F27 - Get allocation vector address
; F29 - Get R/O vector
; F31 - Get DPB address
; F37 - Reset drive

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_CONOUT EQU    2
F_PRTSTR EQU    9
F_RESETDSK EQU  13
F_SELDSK EQU    14
F_LOGINVEC EQU  24
F_GETDSK EQU    25
F_GETALV EQU    27
F_ROVEC EQU     29
F_GETDPB EQU    31
F_RSTDRV EQU    37

; ASCII
CR      EQU     0DH
LF      EQU     0AH

; Test count
TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0

START:
        ; Print test header
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: F25 - Get current disk (should be 0 = A:)
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_GETDSK
        CALL    BDOS
        ; A should be 0 (drive A)
        ORA     A
        JNZ     T1FAIL
        CALL    TPASS
        JMP     TEST2

T1FAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP0
        MVI     C, F_PRTSTR
        CALL    BDOS
        LDA     GOTVAL
        CALL    PRTHEX
        CALL    CRLF

        ;---------------------------------------------------------------
        ; Test 2: F24 - Get login vector (bit 0 should be set for A:)
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_LOGINVEC
        CALL    BDOS
        ; HL = login vector, bit 0 = A:
        SHLD    GOTHL
        MOV     A, L
        ANI     01H             ; Check bit 0
        JZ      T2FAIL
        CALL    TPASS
        JMP     TEST3

T2FAIL:
        CALL    TFAIL
        LXI     D, MSGBIT0
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: F13 - Reset disk system
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_RESETDSK
        CALL    BDOS

        ; After reset, current disk should be 0, login vector should be 0
        MVI     C, F_LOGINVEC
        CALL    BDOS
        ; HL should be 0 (no drives logged in)
        MOV     A, H
        ORA     L
        JNZ     T3FAIL
        CALL    TPASS
        JMP     TEST3B

T3FAIL:
        SHLD    GOTHL
        CALL    TFAIL
        LXI     D, MSGLOGIN0
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3b: After reset, current disk should still be 0
        ;---------------------------------------------------------------
TEST3B:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T3B
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_GETDSK
        CALL    BDOS
        ORA     A
        JNZ     T3BFAIL
        CALL    TPASS
        JMP     TEST4

T3BFAIL:
        STA     GOTVAL
        CALL    TFAIL
        LXI     D, MSGEXP0
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: F14 - Select disk A, verify login
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     E, 0            ; Select drive A
        MVI     C, F_SELDSK
        CALL    BDOS

        ; Check login vector has bit 0 set
        MVI     C, F_LOGINVEC
        CALL    BDOS
        MOV     A, L
        ANI     01H
        JZ      T4FAIL
        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGBIT0
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: F27 - Get allocation vector address (should be non-zero)
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_GETALV
        CALL    BDOS
        ; HL should be non-zero (valid address)
        MOV     A, H
        ORA     L
        JZ      T5FAIL
        CALL    TPASS
        JMP     TEST6

T5FAIL:
        CALL    TFAIL
        LXI     D, MSGNZ
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: F31 - Get DPB address (should be non-zero)
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_GETDPB
        CALL    BDOS
        ; HL should be non-zero
        MOV     A, H
        ORA     L
        JZ      T6FAIL
        ; Verify DPB looks valid - SPT should be 26 for 8" SSSD
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = SPT
        MOV     A, E
        CPI     26              ; Should be 26 sectors/track
        JNZ     T6FAIL
        MOV     A, D
        ORA     A               ; High byte should be 0
        JNZ     T6FAIL
        CALL    TPASS
        JMP     TEST7

T6FAIL:
        CALL    TFAIL
        LXI     D, MSGDPB
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 7: F29 - Get R/O vector (should be 0 initially)
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        MVI     C, F_ROVEC
        CALL    BDOS
        ; HL should be 0 (no read-only drives)
        MOV     A, H
        ORA     L
        JNZ     T7FAIL
        CALL    TPASS
        JMP     TEST8

T7FAIL:
        CALL    TFAIL
        LXI     D, MSGRO0
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 8: F37 - Reset drive, then check login vector
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 9
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; First ensure drive A is logged in
        MVI     E, 0
        MVI     C, F_SELDSK
        CALL    BDOS

        ; Now reset drive A (bitmap = 0001)
        LXI     D, 0001H
        MVI     C, F_RSTDRV
        CALL    BDOS

        ; Check login vector - bit 0 should be cleared
        MVI     C, F_LOGINVEC
        CALL    BDOS
        MOV     A, L
        ANI     01H
        JNZ     T8FAIL
        CALL    TPASS
        JMP     SUMMARY

T8FAIL:
        CALL    TFAIL
        LXI     D, MSGRSTD
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
GOTHL:  DW      0

; Messages
MSGHDR: DB      'BDOS Disk Management Tests', CR, LF
        DB      '==========================', CR, LF, '$'
MSG_T1: DB      'T1: F25 Get Current Disk... ', '$'
MSG_T2: DB      'T2: F24 Login Vector bit 0... ', '$'
MSG_T3: DB      'T3: F13 Reset clears login... ', '$'
MSG_T3B: DB     'T4: F13 Reset keeps disk 0... ', '$'
MSG_T4: DB      'T5: F14 Select sets login... ', '$'
MSG_T5: DB      'T6: F27 Get ALV address... ', '$'
MSG_T6: DB      'T7: F31 Get DPB (SPT=26)... ', '$'
MSG_T7: DB      'T8: F29 R/O vector = 0... ', '$'
MSG_T8: DB      'T9: F37 Reset drive clears login... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGEXP0: DB     'Expected 0, got ', '$'
MSGBIT0: DB     'Expected bit 0 set', CR, LF, '$'
MSGLOGIN0: DB   'Expected login=0 after reset', CR, LF, '$'
MSGNZ:  DB      'Expected non-zero address', CR, LF, '$'
MSGDPB: DB      'DPB invalid or SPT!=26', CR, LF, '$'
MSGRO0: DB      'Expected R/O vector=0', CR, LF, '$'
MSGRSTD: DB     'Drive not reset', CR, LF, '$'

MSGSUMM: DB     'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
