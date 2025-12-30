; Multi-Extent File Test Program for CP/M
; Tests: Write and read files larger than 16K (multi-extent)
;
; Writes 256 records (32K) which requires 2 extents
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
NUMRECS EQU     200             ; Records to write (200 * 128 = 25K, spans 2 extents)

START:
        ; Print test header
        LXI     D, MSGHDR
        MVI     C, PRTSTR
        CALL    BDOS

        ; Initialize default FCB with filename BIGTEST.TMP
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

        ; Set DMA to buffer
        LXI     D, BUFFER
        MVI     C, SETDMA
        CALL    BDOS

        ; Write NUMRECS records
        MVI     A, 0
        STA     RECNUM          ; Current record counter
WRLOOP:
        ; Fill buffer with pattern: all bytes = record number
        LDA     RECNUM
        LXI     H, BUFFER
        MVI     B, 128
WFILL:
        MOV     M, A            ; Store record number
        INX     H
        DCR     B
        JNZ     WFILL

        ; Write record
        LXI     D, DFCB
        MVI     C, WRITE
        CALL    BDOS
        ORA     A
        JNZ     ERRWRT

        ; Print progress dot every 50 records
        LDA     RECNUM
        MOV     B, A
        MVI     A, 50
        ANA     B               ; Check if multiple of 50 (approximately)
        CPI     0
        JNZ     WRNODOT
        MVI     E, '.'
        MVI     C, CONOUT
        CALL    BDOS
WRNODOT:
        ; Increment and check record count
        LDA     RECNUM
        INR     A
        STA     RECNUM
        CPI     NUMRECS
        JNZ     WRLOOP

        ; Print newline
        MVI     E, CR
        MVI     C, CONOUT
        CALL    BDOS
        MVI     E, LF
        MVI     C, CONOUT
        CALL    BDOS

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

        ; Read and verify NUMRECS records
        MVI     A, 0
        STA     RECNUM
RDLOOP:
        ; Clear buffer first
        LXI     H, BUFFER
        MVI     B, 128
        XRA     A
RDCLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     RDCLR

        ; Set DMA
        LXI     D, BUFFER
        MVI     C, SETDMA
        CALL    BDOS

        ; Read record
        LXI     D, DFCB
        MVI     C, READ
        CALL    BDOS
        ORA     A
        JNZ     ERRRD

        ; Verify buffer pattern: all bytes should = record number
        LDA     RECNUM
        LXI     H, BUFFER
        MVI     B, 128
VERIFY:
        CMP     M               ; Compare record number with buffer byte
        JNZ     ERRVFY
        INX     H
        DCR     B
        JNZ     VERIFY

        ; Print progress dot
        LDA     RECNUM
        MOV     B, A
        MVI     A, 50
        ANA     B
        CPI     0
        JNZ     RDNODOT
        MVI     E, '.'
        MVI     C, CONOUT
        CALL    BDOS
RDNODOT:
        ; Increment and check record count
        LDA     RECNUM
        INR     A
        STA     RECNUM
        CPI     NUMRECS
        JNZ     RDLOOP

        ; Close file
        LXI     D, DFCB
        MVI     C, CLOSE
        CALL    BDOS

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
        ; Save error code and record number for debugging
        PUSH    PSW
        LXI     D, MSG2
        MVI     C, PRTSTR
        CALL    BDOS
        ; Print record number
        LXI     D, MSGREC
        MVI     C, PRTSTR
        CALL    BDOS
        LDA     RECNUM
        CALL    PRTHEX
        POP     PSW
        ; Print error code
        LXI     D, MSGERR
        MVI     C, PRTSTR
        CALL    BDOS
        CALL    PRTHEX
        LXI     D, MSGCRLF
        MVI     C, PRTSTR
        CALL    BDOS
        RET
ERRCLS:
        LXI     D, MSG3
        JMP     FAIL
ERROPN:
        LXI     D, MSG4
        JMP     FAIL
ERRRD:
        ; Save error code and record number
        PUSH    PSW
        LXI     D, MSG5
        MVI     C, PRTSTR
        CALL    BDOS
        LXI     D, MSGREC
        MVI     C, PRTSTR
        CALL    BDOS
        LDA     RECNUM
        CALL    PRTHEX
        POP     PSW
        LXI     D, MSGERR
        MVI     C, PRTSTR
        CALL    BDOS
        CALL    PRTHEX
        LXI     D, MSGCRLF
        MVI     C, PRTSTR
        CALL    BDOS
        RET
ERRVFY:
        LXI     D, MSG6
        MVI     C, PRTSTR
        CALL    BDOS
        LXI     D, MSGREC
        MVI     C, PRTSTR
        CALL    BDOS
        LDA     RECNUM
        CALL    PRTHEX
        ; Show expected vs actual
        LXI     D, MSGEXP
        MVI     C, PRTSTR
        CALL    BDOS
        LDA     RECNUM
        CALL    PRTHEX
        LXI     D, MSGGOT
        MVI     C, PRTSTR
        CALL    BDOS
        LDA     BUFFER          ; First byte of buffer
        CALL    PRTHEX
        LXI     D, MSGCRLF
        MVI     C, PRTSTR
        CALL    BDOS
        RET

FAIL:
        PUSH    D
        LXI     D, MSGFAL
        MVI     C, PRTSTR
        CALL    BDOS
        POP     D
        MVI     C, PRTSTR
        CALL    BDOS
        RET

; Print A as 2-digit hex
PRTHEX:
        PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        CALL    PRTNYB
        POP     PSW
        ; Fall through
PRTNYB:
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      PRTN1
        ADI     7
PRTN1:
        MOV     E, A
        MVI     C, CONOUT
        CALL    BDOS
        RET

; Data
RECNUM: DB      0               ; Current record number

; Filename for test (8+3 chars, space-padded)
FNAME:  DB      'BIGTEST TMP'

; Messages
MSGHDR: DB      'Multi-Extent File Test (', CR, LF
        DB      'Writing 200 records = 25K spanning 2 extents)', CR, LF, '$'
MSGPAS: DB      CR, LF, 'PASS: Multi-extent file test succeeded', CR, LF, '$'
MSGFAL: DB      'FAIL: ', '$'
MSG1:   DB      'Cannot create file', CR, LF, '$'
MSG2:   DB      'Write error', '$'
MSG3:   DB      'Close error', CR, LF, '$'
MSG4:   DB      'Cannot open file', CR, LF, '$'
MSG5:   DB      'Read error', '$'
MSG6:   DB      'Data mismatch', '$'
MSGREC: DB      ' at record ', '$'
MSGERR: DB      ' code=', '$'
MSGEXP: DB      ' exp=', '$'
MSGGOT: DB      ' got=', '$'
MSGCRLF: DB     CR, LF, '$'

; Buffer (128 bytes)
BUFFER: DS      128

        END     START
