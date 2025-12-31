; BDOS Random Access Tests
; Tests: F33, F34, F35, F36, F40
;
; F33 - Read random
; F34 - Write random
; F35 - Compute file size
; F36 - Set random record from sequential position
; F40 - Write random with zero fill

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
F_SETDMA EQU    26
F_READRAND EQU  33
F_WRITERAND EQU 34
F_FILESIZE EQU  35
F_SETRAND EQU   36
F_WRITEZF EQU   40

; FCB offsets
DFCB    EQU     005CH

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
        ; Setup: Create test file RANDTST.TMP with 10 records
        ;---------------------------------------------------------------
        LXI     D, MSGSETUP
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Initialize FCB at DFCB (clear 36 bytes, copy filename)
        LXI     H, DFCB
        MVI     B, 36
        XRA     A
CLRFCB:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     CLRFCB

        ; Copy filename to DFCB+1
        LXI     H, FNAME
        LXI     D, DFCB+1
        MVI     B, 11
CPYFN:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     CPYFN

        ; Delete existing
        LXI     D, DFCB
        MVI     C, F_DELETE
        CALL    BDOS

        ; Create file
        LXI     D, DFCB
        MVI     C, F_MAKE
        CALL    BDOS
        INR     A
        JZ      MAKE_ERR

        ; Set DMA
        LXI     D, BUFFER
        MVI     C, F_SETDMA
        CALL    BDOS

        ; Write 10 records sequentially
        ; Each record filled with its record number
        XRA     A
        STA     RECNUM
WRLOOP:
        ; Fill buffer with record number
        LDA     RECNUM
        LXI     H, BUFFER
        MVI     B, 128
WFILL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     WFILL

        ; Write
        LXI     D, DFCB
        MVI     C, F_WRITE
        CALL    BDOS
        ORA     A
        JNZ     WRITE_ERR

        LDA     RECNUM
        INR     A
        STA     RECNUM
        CPI     10              ; Write 10 records (0-9)
        JNZ     WRLOOP

        ; Close
        LXI     D, DFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        LXI     D, MSGOK
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 1: F35 - File size should be 10
        ;---------------------------------------------------------------
        MVI     A, 1
        STA     TESTNUM
        LXI     D, MSG_T1
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Clear FCB fields
        LXI     H, FCB1
        CALL    SETFCB

        ; Get file size
        MVI     C, F_FILESIZE
        CALL    BDOS

        ; Random record field (FCB+33,34,35) should be 10
        LDA     DFCB+33         ; R0
        CPI     10
        JNZ     T1FAIL
        LDA     DFCB+34         ; R1
        ORA     A
        JNZ     T1FAIL
        LDA     DFCB+35         ; R2
        ORA     A
        JNZ     T1FAIL
        CALL    TPASS
        JMP     TEST2

T1FAIL:
        CALL    TFAIL
        LXI     D, MSGFSZ
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 2: F33 - Read random record 5
        ;---------------------------------------------------------------
TEST2:
        MVI     A, 2
        STA     TESTNUM
        LXI     D, MSG_T2
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open file
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T2FAIL

        ; Set random record to 5
        XRA     A
        STA     DFCB+33         ; R0 = 5
        MVI     A, 5
        STA     DFCB+33
        XRA     A
        STA     DFCB+34         ; R1 = 0
        STA     DFCB+35         ; R2 = 0

        ; Clear buffer
        CALL    CLRBUF

        ; Read random
        LXI     D, DFCB
        MVI     C, F_READRAND
        CALL    BDOS
        ORA     A
        JNZ     T2FAIL

        ; Verify buffer contains all 5's
        LXI     H, BUFFER
        MVI     B, 128
T2VFY:
        MOV     A, M
        CPI     5
        JNZ     T2FAIL
        INX     H
        DCR     B
        JNZ     T2VFY

        CALL    TPASS
        JMP     TEST3

T2FAIL:
        CALL    TFAIL
        LXI     D, MSGRD5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 3: F34 - Write random to record 15 (beyond file)
        ;---------------------------------------------------------------
TEST3:
        MVI     A, 3
        STA     TESTNUM
        LXI     D, MSG_T3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Reopen file
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T3FAIL

        ; Set random record to 15
        MVI     A, 15
        STA     DFCB+33
        XRA     A
        STA     DFCB+34
        STA     DFCB+35

        ; Fill buffer with 0xAA
        LXI     H, BUFFER
        MVI     B, 128
        MVI     A, 0AAH
T3FILL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T3FILL

        ; Write random
        LXI     D, DFCB
        MVI     C, F_WRITERAND
        CALL    BDOS
        ORA     A
        JNZ     T3FAIL

        ; Close
        LXI     D, DFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Verify file size is now 16
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_FILESIZE
        CALL    BDOS
        LDA     DFCB+33
        CPI     16
        JNZ     T3FAIL

        CALL    TPASS
        JMP     TEST4

T3FAIL:
        CALL    TFAIL
        LXI     D, MSGWR15
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 4: Read back record 15
        ;---------------------------------------------------------------
TEST4:
        MVI     A, 4
        STA     TESTNUM
        LXI     D, MSG_T4
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T4FAIL

        ; Set record 15
        MVI     A, 15
        STA     DFCB+33
        XRA     A
        STA     DFCB+34
        STA     DFCB+35

        ; Clear buffer
        CALL    CLRBUF

        ; Read random
        LXI     D, DFCB
        MVI     C, F_READRAND
        CALL    BDOS
        ORA     A
        JNZ     T4FAIL

        ; Verify buffer contains 0xAA
        LXI     H, BUFFER
        MVI     B, 128
T4VFY:
        MOV     A, M
        CPI     0AAH
        JNZ     T4FAIL
        INX     H
        DCR     B
        JNZ     T4VFY

        CALL    TPASS
        JMP     TEST5

T4FAIL:
        CALL    TFAIL
        LXI     D, MSGRDAA
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 5: F36 - Set random record from sequential position
        ;---------------------------------------------------------------
TEST5:
        MVI     A, 5
        STA     TESTNUM
        LXI     D, MSG_T5
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open file fresh
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T5FAIL

        ; Read 3 records sequentially
        MVI     B, 3
T5RD:
        PUSH    B
        LXI     D, DFCB
        MVI     C, F_READ
        CALL    BDOS
        POP     B
        ORA     A
        JNZ     T5FAIL
        DCR     B
        JNZ     T5RD

        ; Now FCB CR should be 3
        ; Call F36 to set random record
        LXI     D, DFCB
        MVI     C, F_SETRAND
        CALL    BDOS

        ; Random record should be 3
        LDA     DFCB+33
        CPI     3
        JNZ     T5FAIL
        LDA     DFCB+34
        ORA     A
        JNZ     T5FAIL

        CALL    TPASS
        JMP     TEST6

T5FAIL:
        CALL    TFAIL
        LXI     D, MSGSR3
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 6: Read truly unallocated block should fail
        ;---------------------------------------------------------------
TEST6:
        MVI     A, 6
        STA     TESTNUM
        LXI     D, MSG_T6
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T6FAIL2

        ; Set record to 100 (block 12, truly unallocated)
        MVI     A, 100
        STA     DFCB+33
        XRA     A
        STA     DFCB+34
        STA     DFCB+35

        ; Read random - should return error (unallocated block)
        LXI     D, DFCB
        MVI     C, F_READRAND
        CALL    BDOS
        ; Expect non-zero return (error)
        ORA     A
        JZ      T6FAIL
        CALL    TPASS
        JMP     TEST7

T6FAIL:
        CALL    TFAIL
        LXI     D, MSGUNWR
        MVI     C, F_PRTSTR
        CALL    BDOS
        JMP     TEST7
T6FAIL2:
        CALL    TFAIL
        LXI     D, MSGOPEN
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 7: Extent boundary - write/read record 127 (extent 0)
        ; This is the LAST record of extent 0 (CR=127)
        ;---------------------------------------------------------------
TEST7:
        MVI     A, 7
        STA     TESTNUM
        LXI     D, MSG_T7
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T7FAIL

        ; Set record to 127 (extent=0, CR=127)
        MVI     A, 127
        STA     DFCB+33
        XRA     A
        STA     DFCB+34
        STA     DFCB+35

        ; Fill buffer with 0x7F (127)
        LXI     H, BUFFER
        MVI     B, 128
        MVI     A, 07FH
T7FILL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T7FILL

        ; Write random
        LXI     D, DFCB
        MVI     C, F_WRITERAND
        CALL    BDOS
        ORA     A
        JNZ     T7FAIL

        ; Close to save
        LXI     D, DFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Reopen and read back
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T7FAIL

        MVI     A, 127
        STA     DFCB+33
        XRA     A
        STA     DFCB+34
        STA     DFCB+35

        CALL    CLRBUF

        LXI     D, DFCB
        MVI     C, F_READRAND
        CALL    BDOS
        ORA     A
        JNZ     T7FAIL

        ; Verify buffer contains 0x7F
        LXI     H, BUFFER
        MVI     B, 128
T7VFY:
        MOV     A, M
        CPI     07FH
        JNZ     T7FAIL
        INX     H
        DCR     B
        JNZ     T7VFY

        CALL    TPASS
        JMP     TEST8

T7FAIL:
        CALL    TFAIL
        LXI     D, MSG127
        MVI     C, F_PRTSTR
        CALL    BDOS

        ;---------------------------------------------------------------
        ; Test 8: Extent boundary - write/read record 128 (extent 1)
        ; This is the FIRST record of extent 1 (CR=0)
        ; Critical test: if extent calc is wrong, this fails
        ;---------------------------------------------------------------
TEST8:
        MVI     A, 8
        STA     TESTNUM
        LXI     D, MSG_T8
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Open
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T8FAIL

        ; Set record to 128 (extent=1, CR=0)
        MVI     A, 128
        STA     DFCB+33
        XRA     A
        STA     DFCB+34
        STA     DFCB+35

        ; Fill buffer with 0x80 (128)
        LXI     H, BUFFER
        MVI     B, 128
        MVI     A, 080H
T8FILL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     T8FILL

        ; Write random
        LXI     D, DFCB
        MVI     C, F_WRITERAND
        CALL    BDOS
        ORA     A
        JNZ     T8FAIL

        ; Close to save
        LXI     D, DFCB
        MVI     C, F_CLOSE
        CALL    BDOS

        ; Reopen and read back
        LXI     H, FCB1
        CALL    SETFCB
        MVI     C, F_OPEN
        CALL    BDOS
        INR     A
        JZ      T8FAIL

        MVI     A, 128
        STA     DFCB+33
        XRA     A
        STA     DFCB+34
        STA     DFCB+35

        CALL    CLRBUF

        LXI     D, DFCB
        MVI     C, F_READRAND
        CALL    BDOS
        ORA     A
        JNZ     T8FAIL

        ; Verify buffer contains 0x80
        LXI     H, BUFFER
        MVI     B, 128
T8VFY:
        MOV     A, M
        CPI     080H
        JNZ     T8FAIL
        INX     H
        DCR     B
        JNZ     T8VFY

        CALL    TPASS
        JMP     CLEANUP

T8FAIL:
        CALL    TFAIL
        LXI     D, MSG128
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

MAKE_ERR:
        LXI     D, MSGMKERR
        MVI     C, F_PRTSTR
        CALL    BDOS
        RET

WRITE_ERR:
        ; Save error code
        STA     ERCODE
        LXI     D, MSGWRERR
        MVI     C, F_PRTSTR
        CALL    BDOS
        ; Print record number
        LDA     RECNUM
        CALL    PRTHEX
        MVI     E, ' '
        MVI     C, F_CONOUT
        CALL    BDOS
        ; Print error code
        LDA     ERCODE
        CALL    PRTHEX
        LXI     D, MSGCRLF
        MVI     C, F_PRTSTR
        CALL    BDOS
        RET

ERCODE: DB      0

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
; Helper: Clear buffer
;---------------------------------------------------------------
CLRBUF:
        LXI     H, BUFFER
        MVI     B, 128
        XRA     A
CLRBF1:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     CLRBF1
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
; Data
;---------------------------------------------------------------
RECNUM: DB      0

; Filename for test file (11 bytes: 8+3 space-padded)
FNAME:  DB      'RANDTST TMP'

; FCB for test file (must be 36 bytes)
FCB1:   DB      0               ; DR - drive (0=default)
        DB      'RANDTST '      ; F1-F8 filename (8 bytes, space-padded)
        DB      'TMP'           ; T1-T3 extension (3 bytes)
        DB      0,0,0,0         ; EX, S1, S2, RC
        DB      0,0,0,0,0,0,0,0 ; D0-D7 allocation
        DB      0,0,0,0,0,0,0,0 ; D8-D15 allocation
        DB      0               ; CR (current record)
        DB      0,0,0           ; R0, R1, R2 (random record)

; Buffer
BUFFER: DS      128

; Messages
MSGHDR: DB      'BDOS Random Access Tests', CR, LF
        DB      '========================', CR, LF, '$'
MSGSETUP: DB    'Setup: Creating 10-record file... ', '$'
MSGCLEAN: DB    'Cleanup... ', '$'
MSGSETERR: DB   'FAIL: Setup failed', CR, LF, '$'
MSGMKERR: DB    'FAIL: MAKE failed', CR, LF, '$'
MSGWRERR: DB    'FAIL: WRITE rec=', '$'
MSGCRLF: DB     CR, LF, '$'

MSG_T1: DB      'T1: F35 File size = 10... ', '$'
MSG_T2: DB      'T2: F33 Read random rec 5... ', '$'
MSG_T3: DB      'T3: F34 Write random rec 15... ', '$'
MSG_T4: DB      'T4: Read back rec 15... ', '$'
MSG_T5: DB      'T5: F36 Set random from seq... ', '$'
MSG_T6: DB      'T6: Read unallocated block fails... ', '$'
MSG_T7: DB      'T7: Write/read record 127 (ext 0)... ', '$'
MSG_T8: DB      'T8: Write/read record 128 (ext 1)... ', '$'

MSGOK:  DB      'OK', CR, LF, '$'
MSGNG:  DB      'NG', CR, LF, '$'

MSGFSZ: DB      'File size not 10', CR, LF, '$'
MSGRD5: DB      'Read rec 5 failed', CR, LF, '$'
MSGWR15: DB     'Write rec 15 failed', CR, LF, '$'
MSGRDAA: DB     'Read back failed', CR, LF, '$'
MSGSR3: DB      'Set random != 3', CR, LF, '$'
MSGUNWR: DB     'Should fail on unwritten', CR, LF, '$'
MSGOPEN: DB     'Open failed', CR, LF, '$'
MSG127: DB      'Record 127 failed', CR, LF, '$'
MSG128: DB      'Record 128 failed', CR, LF, '$'

MSGSUMM: DB     CR, LF, 'Summary: ', '$'
MSGOF:  DB      ' of ', '$'
MSGTESTS: DB    ' tests', CR, LF, '$'
MSGPASS: DB     'PASS', CR, LF, '$'
MSGFAILED: DB   'FAIL', CR, LF, '$'

        END     START
