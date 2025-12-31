; BDOS File Attributes Test (Function 30)
; Tests: Setting R/O and SYS attributes on files
;
; F30 - Set file attributes (copies FCB+9..11 to directory)

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
F_SETDMA EQU    26
F_ATTRIB EQU    30

; FCB offsets
DFCB    EQU     005CH

; Attribute bits (in high bit of T1, T2, T3)
ATTR_RO EQU     80H             ; T1 bit 7 = Read-Only
ATTR_SYS EQU    80H             ; T2 bit 7 = System

; ASCII
CR      EQU     0DH
LF      EQU     0AH

TESTNUM: DB     0
PASSED: DB      0
FAILED: DB      0

START:
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Setup: Create test file ATTRTST.TMP
        ;---------------------------------------------------------------
        LXI     D, MSGSETUP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Delete existing
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Create file
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      SETUP_ERR

        ; Close
        LXI     D, DFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     D, MSGOK
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: Set R/O attribute
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Load FCB with R/O bit set in T1 (offset 9)
        LXI     H, FCB1
        CALL    SETFCB

        ; Set R/O bit: FCB+9 (T1) high bit
        LDA     DFCB+9
        ORI     ATTR_RO
        STA     DFCB+9

        ; Call F30
        LXI     D, DFCB
        MVI     C, F_ATTRIB
        CALL    BDOS
        INR     A
        JZ      T1FAIL

        ; Verify by searching and checking directory entry
        LXI     D, DMABUF
        MVI     C, F_SETDMA
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T1FAIL

        ; A = directory code (0-3), entry at DMABUF + A*32
        ; Calculate offset
        ADD     A
        ADD     A
        ADD     A
        ADD     A
        ADD     A               ; *32
        MOV     E, A
        MVI     D, 0
        LXI     H, DMABUF
        DAD     D               ; HL = directory entry

        ; Check T1 (offset 9) has R/O bit
        LXI     D, 9
        DAD     D
        MOV     A, M
        ANI     ATTR_RO
        JZ      T1FAIL

        CALL    TPASS
        JMP     TEST2

T1FAIL:
        CALL    TFAIL
        LXI     D, MSGRO
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 2: Set SYS attribute
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Load FCB with SYS bit set in T2 (offset 10)
        LXI     H, FCB1
        CALL    SETFCB

        ; Set SYS bit: FCB+10 (T2) high bit
        LDA     DFCB+10
        ORI     ATTR_SYS
        STA     DFCB+10

        ; Also keep R/O from before
        LDA     DFCB+9
        ORI     ATTR_RO
        STA     DFCB+9

        ; Call F30
        LXI     D, DFCB
        MVI     C, F_ATTRIB
        CALL    BDOS
        INR     A
        JZ      T2FAIL

        ; Verify
        LXI     D, DMABUF
        MVI     C, F_SETDMA
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T2FAIL

        ADD     A
        ADD     A
        ADD     A
        ADD     A
        ADD     A
        MOV     E, A
        MVI     D, 0
        LXI     H, DMABUF
        DAD     D

        ; Check T2 (offset 10)
        LXI     D, 10
        DAD     D
        MOV     A, M
        ANI     ATTR_SYS
        JZ      T2FAIL

        CALL    TPASS
        JMP     TEST3

T2FAIL:
        CALL    TFAIL
        LXI     D, MSGSYS
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: Clear attributes
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Load FCB with no attributes
        LXI     H, FCB1
        CALL    SETFCB

        ; Clear bits
        LDA     DFCB+9
        ANI     7FH
        STA     DFCB+9
        LDA     DFCB+10
        ANI     7FH
        STA     DFCB+10
        LDA     DFCB+11
        ANI     7FH
        STA     DFCB+11

        ; Call F30
        LXI     D, DFCB
        MVI     C, F_ATTRIB
        CALL    BDOS
        INR     A
        JZ      T3FAIL

        ; Verify both attributes cleared
        LXI     D, DMABUF
        MVI     C, F_SETDMA
        CALL    BDOS

        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_SFIRST
        CALL    BDOS
        CPI     0FFH
        JZ      T3FAIL

        ADD     A
        ADD     A
        ADD     A
        ADD     A
        ADD     A
        MOV     E, A
        MVI     D, 0
        LXI     H, DMABUF
        DAD     D
        LXI     D, 9
        DAD     D

        ; T1 should have no R/O
        MOV     A, M
        ANI     ATTR_RO
        JNZ     T3FAIL

        ; T2 should have no SYS
        INX     H
        MOV     A, M
        ANI     ATTR_SYS
        JNZ     T3FAIL

        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL
        LXI     D, MSGCLR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: F30 on non-existent file returns FFH
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCBNE
        CALL    SETFCB
        MVI     C, F_ATTRIB
        CALL    BDOS
        CPI     0FFH
        JNZ     T4FAIL
        CALL    TPASS
        JMP     CLEANUP

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGNF
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Cleanup
        ;---------------------------------------------------------------
CLEANUP:
        LXI     D, MSGCLEAN
        MVI     C, F_PRTSTR
        CALL    BDOS

        LXI     H, FCB1
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
        LXI     D, MSGOKLN
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
; FCBs
;---------------------------------------------------------------
FCB1:   DB      0, 'ATTRTST ', 'TMP'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

FCBNE:  DB      0, 'NOTEXIST', 'XXX'
        DB      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        DB      0,0,0,0

; DMA buffer
DMABUF: DS      128

; Messages
MSGHDR: DB      'BDOS File Attributes Test (F30)', CR, LF
        DB      '================================', CR, LF, '$'
MSGSETUP: DB    'Setup: Creating test file... ', '$'
MSGCLEAN: DB    'Cleanup... ', '$'
MSGSETERR: DB   'FAIL: Setup failed', CR, LF, '$'

MSG_T1: DB      'T1: Set R/O attribute... ', '$'
MSG_T2: DB      'T2: Set SYS attribute... ', '$'
MSG_T3: DB      'T3: Clear attributes... ', '$'
MSG_T4: DB      'T4: F30 on missing file... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGOKLN: DB     'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGRO:  DB      'R/O not set', CR, LF, '$'
MSGSYS: DB      'SYS not set', CR, LF, '$'
MSGCLR: DB      'Attrs not cleared', CR, LF, '$'
MSGNF:  DB      'Should return FFH', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
