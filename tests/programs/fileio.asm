; File I/O Test Program for CP/M
; Tests: Create, Write, Close, Open, Read, Verify
;
; Prints "PASS" if all operations succeed and data matches
; Prints "FAIL" with error code otherwise

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
CONOUT  EQU     2
PRTSTR  EQU     9
OPEN    EQU     15
CLOSE   EQU     16
DELETE  EQU     19
READ    EQU     20
WRITE   EQU     21
MAKE    EQU     22
SETDMA  EQU     26

; System addresses
DFCB    EQU     005CH           ; Default FCB

; Constants
CR      EQU     0DH
LF      EQU     0AH
EOF     EQU     1AH

START:
        ; Print test header
        LXI     D, MSGHDR
        MVI     C, PRTSTR
        CALL    BDOS

        ; Initialize default FCB with filename IOTEST.TMP
        LXI     H, DFCB
        MVI     B, 36           ; Clear 36 bytes
        XRA     A
CLRFCB:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     CLRFCB

        ; Set filename
        LXI     H, FNAME
        LXI     D, DFCB+1
        MVI     B, 11           ; 8+3 chars
CPYFN:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     CPYFN

        ; Delete any existing test file
        LXI     D, DFCB
        MVI     C, DELETE
        CALL    BDOS

        ; Create new file
        LXI     D, DFCB
        MVI     C, MAKE
        CALL    BDOS
        INR     A
        JZ      ERRMAK          ; Directory full

        ; Set DMA to write buffer
        LXI     D, WRBUF
        MVI     C, SETDMA
        CALL    BDOS

        ; Fill write buffer with test pattern
        LXI     H, WRBUF
        MVI     B, 128          ; 128 bytes
        MVI     A, 'A'
FILL:
        MOV     M, A
        INX     H
        INR     A
        CPI     'Z'+1
        JNZ     FILL2
        MVI     A, 'A'          ; Wrap back to A
FILL2:
        DCR     B
        JNZ     FILL

        ; Write record
        LXI     D, DFCB
        MVI     C, WRITE
        CALL    BDOS
        ORA     A
        JNZ     ERRWRT

        ; Close file
        LXI     D, DFCB
        MVI     C, CLOSE
        CALL    BDOS
        INR     A
        JZ      ERRCLS

        ; Clear FCB extent/record fields for re-open
        XRA     A
        STA     DFCB+12         ; Extent
        STA     DFCB+32         ; Current record

        ; Reopen file for reading
        LXI     D, DFCB
        MVI     C, OPEN
        CALL    BDOS
        INR     A
        JZ      ERROPN

        ; Set DMA to read buffer
        LXI     D, RDBUF
        MVI     C, SETDMA
        CALL    BDOS

        ; Clear read buffer first
        LXI     H, RDBUF
        MVI     B, 128
        XRA     A
CLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     CLR

        ; Read record
        LXI     D, DFCB
        MVI     C, READ
        CALL    BDOS
        ORA     A
        JNZ     ERRRD

        ; Close file
        LXI     D, DFCB
        MVI     C, CLOSE
        CALL    BDOS

        ; Verify data matches
        LXI     H, WRBUF
        LXI     D, RDBUF
        MVI     B, 128
VERIFY:
        LDAX    D
        CMP     M
        JNZ     ERRVFY
        INX     H
        INX     D
        DCR     B
        JNZ     VERIFY

        ; All tests passed!
        LXI     D, MSGPAS
        MVI     C, PRTSTR
        CALL    BDOS

        ; Clean up - delete test file
        LXI     D, DFCB
        MVI     C, DELETE
        CALL    BDOS

        RET

; Error handlers
ERRMAK:
        LXI     D, MSG1
        JMP     FAIL
ERRWRT:
        LXI     D, MSG2
        JMP     FAIL
ERRCLS:
        LXI     D, MSG3
        JMP     FAIL
ERROPN:
        LXI     D, MSG4
        JMP     FAIL
ERRRD:
        LXI     D, MSG5
        JMP     FAIL
ERRVFY:
        LXI     D, MSG6
        JMP     FAIL

FAIL:
        PUSH    D
        LXI     D, MSGFAL
        MVI     C, PRTSTR
        CALL    BDOS
        POP     D
        MVI     C, PRTSTR
        CALL    BDOS
        RET

; Filename for test (8+3 chars, space-padded)
FNAME:  DB      'IOTEST  TMP'

; Messages
MSGHDR: DB      'File I/O Test', CR, LF, '$'
MSGPAS: DB      'PASS: All file I/O tests succeeded', CR, LF, '$'
MSGFAL: DB      'FAIL: ', '$'
MSG1:   DB      'Cannot create file', CR, LF, '$'
MSG2:   DB      'Write error', CR, LF, '$'
MSG3:   DB      'Close error', CR, LF, '$'
MSG4:   DB      'Cannot open file', CR, LF, '$'
MSG5:   DB      'Read error', CR, LF, '$'
MSG6:   DB      'Data mismatch', CR, LF, '$'

; Buffers (128 bytes each)
WRBUF:  DS      128
RDBUF:  DS      128

        END     START
