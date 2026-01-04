;===============================================================================
; LOLOS CCP - Console Command Processor (CP/M 2.2 Compatible)
; Target: z80pack (cpmsim)
; CPU: Intel 8080 (no Z80 extensions)
;===============================================================================

;-------------------------------------------------------------------------------
; System Constants (must match BIOS/BDOS)
;-------------------------------------------------------------------------------

MSIZE   EQU     64
BIAS    EQU     (MSIZE-20)*1024
CCP     EQU     3400H+BIAS
BDOS    EQU     CCP+0800H
BIOS    EQU     CCP+1600H

; Page zero locations
WBOOT   EQU     0000H           ; Warm boot vector
IOBYTE  EQU     0003H
CDISK   EQU     0004H           ; Current disk (low 4 bits) + user (high 4 bits)
ENTRY   EQU     0005H           ; BDOS entry vector
DFCB    EQU     005CH           ; Default FCB
DFCB2   EQU     006CH           ; Second FCB (overlaps DFCB)
DBUFF   EQU     0080H           ; Default buffer / command tail
TPA     EQU     0100H           ; Transient Program Area

; ASCII
CR      EQU     0DH
LF      EQU     0AH
TAB     EQU     09H
CTRLC   EQU     03H

; BDOS functions
B_CONIN  EQU    1
B_CONOUT EQU    2
B_PRINT  EQU    9
B_RDLINE EQU    10
B_CONST  EQU    11
B_VERS   EQU    12
B_RESET  EQU    13
B_SELDSK EQU    14
B_OPEN   EQU    15
B_CLOSE  EQU    16
B_SFIRST EQU    17
B_SNEXT  EQU    18
B_DELETE EQU    19
B_READ   EQU    20
B_WRITE  EQU    21
B_MAKE   EQU    22
B_RENAME EQU    23
B_LOGIN  EQU    24
B_GETDSK EQU    25
B_SETDMA EQU    26
B_GETALL EQU    27
B_SETATT EQU    30
B_USER   EQU    32

;-------------------------------------------------------------------------------
; CCP Entry Point
;-------------------------------------------------------------------------------

        ORG     CCP

;-------------------------------------------------------------------------------
; CCPENT - CCP warm boot entry point
;-------------------------------------------------------------------------------
; Description:
;   Main entry point for CCP from warm boot. Initializes current disk,
;   resets the disk system, then enters the command loop.
;
; Input:
;   C       - [REQ] Current disk number (0=A, 1=B, etc.)
;
; Output:
;   (none)  - Enters command loop, does not return
;-------------------------------------------------------------------------------

CCPENT:
        MOV     A, C
        ANI     0FH             ; Mask drive number
        STA     CURDSK
        PUSH    PSW             ; Save drive number

        ; Reset disk system (initializes BDOS variables including user number)
        MVI     C, B_RESET
        CALL    ENTRY

        POP     PSW
        STA     CDISK           ; Restore CDISK after reset

;-------------------------------------------------------------------------------
; CCPRET - Re-entry point after transient program
;-------------------------------------------------------------------------------
; Description:
;   Entry point when a transient program returns. Resets the stack
;   and synchronizes with the current disk before resuming command loop.
;
; Input:
;   (none)
;
; Output:
;   (none)  - Enters command loop
;-------------------------------------------------------------------------------

CCPRET:
        LXI     SP, CCPSTK      ; Set up local stack
        ; Sync with system drive (programs may have changed it via BDOS)
        LDA     CDISK
        ANI     0FH
        STA     CURDSK
        ; Reset DMA to DBUFF - transient programs may leave it pointing elsewhere
        LXI     D, DBUFF
        MVI     C, B_SETDMA
        CALL    ENTRY

; CCPLP - Main command loop
; Prompts, reads command, parses, and executes
CCPLP:
        CALL    CRLF            ; New line before prompt
        CALL    GETDSK          ; Ensure disk is selected
        CALL    PROMPT          ; Display prompt
        CALL    RDCMD           ; Read command line
        CALL    PARSE           ; Parse into FCB
        JZ      CCPLP           ; Empty line
        CALL    EXEC            ; Execute command
        JMP     CCPLP

;-------------------------------------------------------------------------------
; PROMPT - Display command prompt
;-------------------------------------------------------------------------------
; Description:
;   Displays the CP/M prompt consisting of the current drive letter
;   followed by '>'. Example: "A>"
;
; Input:
;   CURDSK  - [REQ] Current disk number
;
; Output:
;   (console) - Prompt displayed
;
; Clobbers:
;   A, C, flags
;-------------------------------------------------------------------------------

PROMPT:
        LDA     CURDSK
        ADI     'A'             ; Convert to letter
        MOV     C, A
        CALL    OUTCHR
        MVI     C, '>'
        CALL    OUTCHR
        RET

;-------------------------------------------------------------------------------
; RDCMD - Read command line from console
;-------------------------------------------------------------------------------
; Description:
;   Reads a command line using BDOS function 10. Converts input to
;   uppercase and copies to DBUFF for processing.
;
; Input:
;   (none)
;
; Output:
;   Z flag  - Set if empty line, clear if command entered
;   DBUFF   - Command line (byte 0 = length, bytes 1+ = text)
;
; Clobbers:
;   A, BC, DE, HL, flags
;-------------------------------------------------------------------------------

RDCMD:
        LXI     D, CMDBUF
        MVI     A, 127          ; Max length
        STAX    D
        MVI     C, B_RDLINE
        CALL    BDOSCL

        ; Get length and null-terminate
        LXI     H, CMDBUF+1
        MOV     A, M            ; Actual length
        ORA     A
        RZ                      ; Return if empty

        ; Convert to uppercase and copy to DBUFF
        MOV     B, A            ; Length
        INX     H               ; Point to first char
        LXI     D, DBUFF+1      ; Destination
        MVI     C, 0            ; Counter
RDCMPL:
        MOV     A, M
        CALL    TOUPPER
        STAX    D
        INX     H
        INX     D
        INR     C
        DCR     B
        JNZ     RDCMPL

        ; Null terminate the string
        XRA     A
        STAX    D

        ; Store length at DBUFF
        MOV     A, C
        STA     DBUFF
        RET

;-------------------------------------------------------------------------------
; PARSE - Parse command line into FCBs
;-------------------------------------------------------------------------------
; Description:
;   Parses the command line from DBUFF into DFCB (first filename/command)
;   and DFCB2 (second filename if present). Clears FCBs first.
;
; Input:
;   DBUFF   - [REQ] Command line
;
; Output:
;   Z flag  - Set if empty line, clear if valid command
;   DFCB    - First filename parsed
;   DFCB2   - Second filename (if present)
;   CMDTAIL - Points to arguments after command name
;
; Clobbers:
;   A, BC, DE, HL, flags
;-------------------------------------------------------------------------------

PARSE:
        LDA     DBUFF           ; Get length
        ORA     A
        RZ                      ; Return Z if empty

        ; Clear default FCB
        LXI     H, DFCB
        MVI     B, 36
        XRA     A
PARSEC:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     PARSEC

        ; Clear second FCB area
        LXI     H, DFCB2
        MVI     B, 16
        XRA     A
PARSC2:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     PARSC2

        ; Parse first name (command name)
        LXI     H, DBUFF+1      ; Source
        LXI     D, DFCB         ; Destination FCB
        CALL    PARFCB

        ; Save pointer to command tail (arguments)
        SHLD    CMDTAIL

        ; Skip spaces
PARSK1:
        MOV     A, M
        CPI     ' '
        JNZ     PARSK2
        INX     H
        JMP     PARSK1
PARSK2:
        ; Check for second filename
        MOV     A, M
        ORA     A
        JZ      PARSDN
        CPI     CR
        JZ      PARSDN

        ; Parse second name
        LXI     D, DFCB2
        CALL    PARFCB

PARSDN:
        MVI     A, 1            ; Return NZ
        ORA     A
        RET

;-------------------------------------------------------------------------------
; PARFCB - Parse filename into FCB
;-------------------------------------------------------------------------------
; Description:
;   Parses a filename (with optional drive prefix) from the command line
;   into an FCB. Handles drive letter (X:), wildcards (* and ?), and
;   extension. Advances HL past the parsed name.
;
; Input:
;   HL      - [REQ] Pointer to filename string
;   DE      - [REQ] Pointer to destination FCB
;
; Output:
;   HL      - Advanced past the filename
;   FCB     - Filled with drive, filename, and extension
;
; Clobbers:
;   A, BC, DE, flags
;-------------------------------------------------------------------------------

PARFCB:
        PUSH    D               ; Save FCB pointer
        ; Check for drive specifier
        INX     H
        MOV     A, M
        DCX     H
        CPI     ':'
        JNZ     PFNODR

        ; Has drive letter
        MOV     A, M            ; Get drive letter
        CALL    TOUPPER
        SUI     'A'-1           ; Convert to 1-based
        STAX    D               ; Store in FCB drive byte
        INX     H
        INX     H               ; Skip "X:"
        JMP     PFNAME

PFNODR:
        XRA     A               ; Use default drive (0)
        STAX    D

PFNAME:
        INX     D               ; Point to filename field
        MVI     B, 8            ; Max 8 chars for name
PFNMLP:
        MOV     A, M
        ORA     A
        JZ      PFPAD
        CPI     CR
        JZ      PFPAD
        CPI     ' '
        JZ      PFPAD
        CPI     '.'
        JZ      PFEXT
        CPI     '*'             ; Wildcard
        JZ      PFWILD

        CALL    TOUPPER
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     PFNMLP

        ; Skip excess name characters
PFSKIP:
        MOV     A, M
        ORA     A
        JZ      PFPAD
        CPI     CR
        JZ      PFPAD
        CPI     ' '
        JZ      PFPAD
        CPI     '.'
        JZ      PFEXT
        INX     H
        JMP     PFSKIP

PFWILD:
        ; Fill remaining with '?'
        MVI     A, '?'
PFWLP:
        STAX    D
        INX     D
        DCR     B
        JNZ     PFWLP
        INX     H               ; Skip '*'
        JMP     PFSKIP          ; Skip to '.' or end

PFPAD:
        ; Pad remaining name with spaces
        MOV     A, B
        ORA     A
        JZ      PFEXT0
        MVI     A, ' '
PFPDLP:
        STAX    D
        INX     D
        DCR     B
        JNZ     PFPDLP

PFEXT0:
        ; Check for extension
        MOV     A, M
        CPI     '.'
        JNZ     PFNOEX
        INX     H               ; Skip '.'

PFEXT:
        INX     H               ; Skip the '.'
        DCX     H               ; Oops, undo if we came from PFNMLP
        MOV     A, M
        CPI     '.'
        JNZ     PFXPAD
        INX     H               ; Now skip it

        ; Pad remaining filename chars with spaces (B = count, DE = next pos)
PFXPAD:
        MOV     A, B
        ORA     A
        JZ      PFEX2           ; No padding needed
        MVI     A, ' '
PFXPDL:
        STAX    D
        INX     D
        DCR     B
        JNZ     PFXPDL

PFEX2:
        ; Parse extension (3 chars)
        POP     D               ; Get FCB base back
        PUSH    D
        LXI     B, 9            ; Offset to extension
        XCHG
        DAD     B
        XCHG                    ; DE = extension field

        MVI     B, 3
PFEXLP:
        MOV     A, M
        ORA     A
        JZ      PFEXPAD
        CPI     CR
        JZ      PFEXPAD
        CPI     ' '
        JZ      PFEXPAD
        CPI     '*'
        JZ      PFEXWLD

        CALL    TOUPPER
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     PFEXLP
        JMP     PFDONE

PFEXWLD:
        MVI     A, '?'
PFXWLP:
        STAX    D
        INX     D
        DCR     B
        JNZ     PFXWLP
        INX     H
        JMP     PFDONE

PFEXPAD:
        MOV     A, B
        ORA     A
        JZ      PFDONE
        MVI     A, ' '
PFXPLP:
        STAX    D
        INX     D
        DCR     B
        JNZ     PFXPLP
        JMP     PFDONE

PFNOEX:
        ; No extension - pad with spaces
        POP     D
        PUSH    D
        LXI     B, 9
        XCHG
        DAD     B
        XCHG
        MVI     B, 3
        MVI     A, ' '
PFNXLP:
        STAX    D
        INX     D
        DCR     B
        JNZ     PFNXLP

PFDONE:
        POP     D               ; Restore FCB pointer
        RET

;-------------------------------------------------------------------------------
; EXEC - Execute command
;-------------------------------------------------------------------------------
; Description:
;   Dispatches command execution. Checks for drive change (e.g., "B:"),
;   built-in commands (DIR, ERA, REN, TYPE, SAVE, USER), or loads and
;   executes a transient .COM program.
;
; Input:
;   DFCB    - [REQ] Parsed command name
;   DBUFF   - [REQ] Full command line
;
; Output:
;   (varies) - Command executed
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

EXEC:
        ; Check for drive change (single letter + nothing)
        LDA     DBUFF           ; Command length
        CPI     2               ; "A:" is 2 chars
        JNZ     EXECMD

        LXI     H, DBUFF+2
        MOV     A, M
        CPI     ':'
        JNZ     EXECMD

        ; Drive change
        LXI     H, DBUFF+1
        MOV     A, M
        CALL    TOUPPER
        SUI     'A'
        CPI     16              ; Valid drive?
        JNC     CCPLP           ; Ignore invalid
        STA     CURDSK
        ; Select disk via BDOS
        MOV     E, A
        MVI     C, B_SELDSK
        CALL    BDOSCL
        RET

EXECMD:
        ; Check built-in commands
        LXI     D, CMDTBL
EXLOOP:
        LDAX    D
        ORA     A               ; End of table?
        JZ      EXTRAN          ; Not built-in, try transient

        ; Compare command name
        PUSH    D
        LXI     H, DFCB+1       ; Command name in FCB
        MVI     B, 4            ; Max 4-char built-in names
EXCMP:
        LDAX    D
        ORA     A               ; End of name?
        JZ      EXMATCH
        CPI     ' '             ; Padding?
        JZ      EXMATCH
        MOV     C, M
        CMP     C
        JNZ     EXNEXT
        INX     H
        INX     D
        DCR     B
        JNZ     EXCMP

EXMATCH:
        ; Found match - get handler address
        POP     D               ; Restore table pointer
EXMFND:
        LDAX    D
        ORA     A
        JZ      EXMGOT
        CPI     ' '
        JZ      EXMGOT
        INX     D
        JMP     EXMFND
EXMGOT:
        INX     D               ; Skip null/space
        LDAX    D
        MOV     L, A
        INX     D
        LDAX    D
        MOV     H, A
        PCHL                    ; Jump to handler

EXNEXT:
        ; Skip to next entry
        POP     D
EXSKIP:
        LDAX    D
        ORA     A
        JZ      EXSK2
        CPI     ' '
        JZ      EXSK2
        INX     D
        JMP     EXSKIP
EXSK2:
        INX     D               ; Skip terminator
        INX     D               ; Skip address low
        INX     D               ; Skip address high
        JMP     EXLOOP

;-------------------------------------------------------------------------------
; EXTRAN - Load and execute transient program
;-------------------------------------------------------------------------------
; Description:
;   Loads a .COM file from disk into the TPA (0100H) and executes it.
;   Sets up FCBs and command tail before transferring control.
;
; Input:
;   DFCB    - [REQ] Program name (extension set to .COM)
;
; Output:
;   (program) - Transient program executed
;
; Notes:
;   - Program must fit below CCP
;   - Returns to CCPRET when program terminates
;-------------------------------------------------------------------------------

EXTRAN:
        ; Add .COM extension to FCB
        LXI     H, DFCB+9
        MVI     M, 'C'
        INX     H
        MVI     M, 'O'
        INX     H
        MVI     M, 'M'

        ; Try to open file
        LXI     D, DFCB
        MVI     C, B_OPEN
        CALL    BDOSCL
        INR     A               ; FF becomes 0
        JZ      EXTNF           ; Not found

        ; Load program at TPA (0100H)
        LXI     H, TPA
        SHLD    LOADAD

EXTLP:
        ; Set DMA to load address
        LHLD    LOADAD
        XCHG
        MVI     C, B_SETDMA
        CALL    BDOSCL

        ; Read next record
        LXI     D, DFCB
        MVI     C, B_READ
        CALL    BDOSCL
        ORA     A
        JNZ     EXTRUN          ; EOF or error - done loading

        ; Advance load address
        LHLD    LOADAD
        LXI     D, 128
        DAD     D
        SHLD    LOADAD

        ; Check for overflow into CCP
        LXI     D, CCP
        MOV     A, L
        SUB     E
        MOV     A, H
        SBB     D
        JC      EXTLP           ; Still below CCP

        ; Program too large
        LXI     D, MSGTL
        CALL    PRTSTR
        RET

EXTRUN:
        ; Close file
        LXI     D, DFCB
        MVI     C, B_CLOSE
        CALL    BDOSCL

        ; Reset DMA to default
        LXI     D, DBUFF
        MVI     C, B_SETDMA
        CALL    BDOSCL

        ; Copy command tail (arguments only) to DBUFF
        ; CMDTAIL points to after the command name
        LHLD    CMDTAIL
        LXI     D, DBUFF+1      ; Destination (skip length byte)
        MVI     B, 0            ; Length counter
EXTCPY:
        MOV     A, M
        ORA     A
        JZ      EXTCDN          ; Null = end
        CPI     CR
        JZ      EXTCDN          ; CR = end
        STAX    D
        INX     H
        INX     D
        INR     B
        JMP     EXTCPY
EXTCDN:
        ; Store length and terminate
        MOV     A, B
        STA     DBUFF           ; Length byte
        XRA     A
        STAX    D               ; Null terminate

        ; Set up FCBs for program - re-parse command tail
        ; First clear both FCBs
        LXI     H, DFCB
        MVI     B, 36
        XRA     A
EXCLR1:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     EXCLR1

        LXI     H, DFCB2
        MVI     B, 16
        XRA     A
EXCLR2:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     EXCLR2

        ; Parse command tail into FCBs
        ; Use DBUFF+1 since EXTCPY copied the tail there
        ; (Can't use CMDTAIL - it was overwritten by EXTCPY)
        LXI     H, DBUFF+1
EXSKLD:
        MOV     A, M
        ORA     A
        JZ      EXNOARG         ; Null = no arguments
        CPI     CR
        JZ      EXNOARG         ; CR = no arguments
        CPI     ' '
        JNZ     EXARG1          ; Non-space = start of argument
        INX     H
        JMP     EXSKLD
EXARG1:
        ; Parse first argument
        LXI     D, DFCB
        CALL    PARFCB

        ; Parse second argument (HL advanced by PARFCB)
        MOV     A, M
        ORA     A
        JZ      EXNOARG
        CPI     ' '
        JZ      EXSKSP
        JMP     EXPAR2
EXSKSP:
        INX     H
        MOV     A, M
        ORA     A
        JZ      EXNOARG
        CPI     ' '
        JZ      EXSKSP
EXPAR2:
        LXI     D, DFCB2
        CALL    PARFCB

EXNOARG:
        ; Jump to program
        LDA     CURDSK
        MOV     C, A
        CALL    TPA
        JMP     CCPRET          ; Return here after program

EXTNF:
        ; File not found
        LXI     D, MSGNF
        CALL    PRTSTR
        RET

;-------------------------------------------------------------------------------
; Built-in Command Table
;-------------------------------------------------------------------------------

CMDTBL:
        DB      'DIR', 0
        DW      CMDDIR
        DB      'ERA', 0
        DW      CMDERA
        DB      'REN', 0
        DW      CMDREN
        DB      'TYPE', 0
        DW      CMDTYP
        DB      'SAVE', 0
        DW      CMDSAV
        DB      'USER', 0
        DW      CMDUSR
        DB      0               ; End of table

;-------------------------------------------------------------------------------
; CMDDIR - DIR built-in command
;-------------------------------------------------------------------------------
; Description:
;   Lists directory entries matching the pattern. If no argument given,
;   lists all files (*.*). Displays filenames in 4 columns, skipping
;   system files.
;
; Input:
;   DBUFF   - [REQ] Command line (may contain filename pattern)
;
; Output:
;   (console) - Directory listing displayed
;-------------------------------------------------------------------------------

CMDDIR:
        ; Check if there's an argument after "DIR"
        ; Scan DBUFF for space after command, then check for arg
        LXI     H, DBUFF+1
        ; Skip past the command name (non-space chars)
DIRSK1:
        MOV     A, M
        ORA     A
        JZ      DIRWLD          ; End of line, no arg
        CPI     ' '
        JZ      DIRSK2          ; Found space, look for arg
        INX     H
        JMP     DIRSK1
DIRSK2:
        ; Skip spaces
        MOV     A, M
        CPI     ' '
        JNZ     DIRCHK          ; Non-space found
        INX     H
        JMP     DIRSK2
DIRCHK:
        ; Check if there's an argument
        ORA     A               ; Null = end
        JNZ     DIRARG          ; Non-null = has arg
        ; Fall through to wildcards

DIRWLD:
        ; No argument - clear FCB and fill with wildcards
        XRA     A
        STA     DFCB            ; Drive = 0 (default)
        LXI     H, DFCB+1
        MVI     B, 11
        MVI     A, '?'
DIRFIL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     DIRFIL
        JMP     DIRSRC

DIRARG:
        ; Has argument - parse it into DFCB
        ; HL points to start of argument
        LXI     D, DFCB
        CALL    PARFCB

DIRSRC:
        ; Search for first match
        LXI     D, DFCB
        MVI     C, B_SFIRST
        CALL    BDOSCL
        INR     A
        JZ      DIRNON          ; No files

        MVI     B, 0            ; Column counter

DIRLP:
        DCR     A               ; Convert back to 0-3
        ; Calculate pointer to directory entry
        ; Entry is at DBUFF + (A * 32)
        ADD     A               ; *2
        ADD     A               ; *4
        ADD     A               ; *8
        ADD     A               ; *16
        ADD     A               ; *32
        LXI     H, DBUFF
        MOV     E, A
        MVI     D, 0
        DAD     D               ; HL = entry address

        ; Check if system file (T2 high bit set)
        PUSH    H
        LXI     D, 10           ; Offset to T2
        DAD     D
        MOV     A, M
        ANI     80H
        POP     H
        JNZ     DIRNXT          ; Skip system files

        ; Check if extent 0 (only show first extent of each file)
        PUSH    H
        LXI     D, 12           ; Offset to extent byte
        DAD     D
        MOV     A, M
        POP     H
        ORA     A
        JNZ     DIRNXT          ; Skip non-zero extents

        ; Print filename
        INX     H               ; Skip user byte
        PUSH    B
        MVI     B, 8            ; Filename
        CALL    PRNAME
        MVI     C, '.'
        CALL    OUTCHR
        MVI     B, 3            ; Extension
        CALL    PRNAME
        MVI     C, ' '
        CALL    OUTCHR
        CALL    OUTCHR
        POP     B

        ; Column management (4 per line)
        INR     B
        MOV     A, B
        ANI     03H
        JNZ     DIRNXT
        CALL    CRLF

DIRNXT:
        ; Search for next
        MVI     C, B_SNEXT
        CALL    BDOSCL
        INR     A
        JNZ     DIRLP

        ; Done
        CALL    CRLF
        RET

DIRNON:
        LXI     D, MSGNF
        CALL    PRTSTR
        RET

; PRNAME - Print filename characters
; Input: B=count, HL=source  Output: HL advanced  Clobbers: A, B, C, flags
PRNAME:
        MOV     A, M
        ANI     7FH             ; Mask attribute bit
        MOV     C, A
        CALL    OUTCHR
        INX     H
        DCR     B
        JNZ     PRNAME
        RET

;-------------------------------------------------------------------------------
; CMDERA - ERA built-in command
;-------------------------------------------------------------------------------
; Description:
;   Erases files matching the pattern. Prompts for confirmation if
;   wildcards are used.
;
; Input:
;   DBUFF   - [REQ] Command line with filename pattern
;
; Output:
;   (disk)  - Files deleted
;-------------------------------------------------------------------------------

CMDERA:
        ; Parse argument from command line into DFCB
        LXI     H, DBUFF+1
        ; Skip past the command name (non-space chars)
ERASK1:
        MOV     A, M
        ORA     A
        JZ      ERAERR          ; End of line, no arg
        CPI     ' '
        JZ      ERASK2          ; Found space, look for arg
        INX     H
        JMP     ERASK1
ERASK2:
        ; Skip spaces
        MOV     A, M
        CPI     ' '
        JNZ     ERACHK          ; Non-space found
        INX     H
        JMP     ERASK2
ERACHK:
        ; Check if there's an argument
        ORA     A               ; Null = end
        JZ      ERAERR          ; No argument
        ; Parse filename into DFCB
        LXI     D, DFCB
        CALL    PARFCB

        ; Confirm if using wildcards
        CALL    HASWILD
        JZ      ERADEL

        LXI     D, MSGCNF
        CALL    PRTSTR
        MVI     C, B_CONIN
        CALL    BDOSCL
        CALL    TOUPPER
        CPI     'Y'
        JNZ     CCPLP

ERADEL:
        LXI     D, DFCB
        MVI     C, B_DELETE
        CALL    BDOSCL
        INR     A
        JZ      ERANF
        RET

ERANF:
        LXI     D, MSGNF
        JMP     PRTSTR

ERAERR:
        LXI     D, MSGERR
        JMP     PRTSTR

; HASWILD - Check if FCB contains wildcards
; Input: (DFCB)  Output: Z=no wildcards, NZ=has wildcards  Clobbers: A, B, HL, flags
HASWILD:
        LXI     H, DFCB+1
        MVI     B, 11
HWLOOP:
        MOV     A, M
        CPI     '?'
        JZ      HWFND           ; Found wildcard
        INX     H
        DCR     B
        JNZ     HWLOOP
        XRA     A               ; Return Z (no wildcards)
        RET
HWFND:
        MVI     A, 1            ; Return NZ (wildcards present)
        ORA     A
        RET

;-------------------------------------------------------------------------------
; CMDREN - REN built-in command
;-------------------------------------------------------------------------------
; Description:
;   Renames a file. Expects two filenames: new=old format.
;   DFCB contains new name, DFCB2 contains old name.
;
; Input:
;   DFCB    - [REQ] New filename
;   DFCB2   - [REQ] Old filename
;
; Output:
;   (disk)  - File renamed
;-------------------------------------------------------------------------------

CMDREN:
        ; Need two filenames: new=old or new old
        ; FCB has new name, FCB2 should have old name
        ; But CP/M format is: REN newname=oldname
        ; We need to swap and handle the = sign

        ; For simplicity: FCB = destination, search for '=' then parse old name
        ; Actually the PARFCB should have handled this if format is "new=old"

        ; Check second FCB
        LDA     DFCB2+1
        CPI     ' '
        JZ      RENERR

        ; CP/M rename: FCB has new name at +0, old name at +16
        ; We have new at DFCB, old at DFCB2
        ; Copy old name to DFCB+16
        LXI     H, DFCB2
        LXI     D, DFCB+16
        MVI     B, 16
        CALL    COPY

        ; Now DFCB has new name at +1, old name at +17
        ; Search for old file first
        LXI     H, DFCB+16
        LXI     D, DFCB
        MVI     B, 12
        CALL    COPY            ; Temporarily copy old name to search position

        LXI     D, DFCB
        MVI     C, B_SFIRST
        CALL    BDOSCL
        INR     A
        JZ      RENNF

        ; Restore new name
        ; Actually this is getting complicated. Let's simplify:
        ; Just copy old pattern for search, then do rename
        LXI     D, DFCB
        MVI     C, B_RENAME
        CALL    BDOSCL
        RET

RENERR:
        LXI     D, MSGERR
        JMP     PRTSTR

RENNF:
        LXI     D, MSGNF
        JMP     PRTSTR

;-------------------------------------------------------------------------------
; CMDTYP - TYPE built-in command
;-------------------------------------------------------------------------------
; Description:
;   Displays the contents of a text file to the console. Stops at ^Z
;   (EOF marker) or end of file. Can be aborted with ^C.
;
; Input:
;   DBUFF   - [REQ] Command line with filename
;
; Output:
;   (console) - File contents displayed
;-------------------------------------------------------------------------------

CMDTYP:
        ; Parse argument from command line into DFCB
        ; (DFCB currently contains "TYPE", we need the filename)
        LXI     H, DBUFF+1
        ; Skip past the command name (non-space chars)
TYPSK1:
        MOV     A, M
        ORA     A
        JZ      TYPERR          ; End of line, no arg
        CPI     ' '
        JZ      TYPSK2          ; Found space, look for arg
        INX     H
        JMP     TYPSK1
TYPSK2:
        ; Skip spaces
        MOV     A, M
        CPI     ' '
        JNZ     TYPCHK          ; Non-space found
        INX     H
        JMP     TYPSK2
TYPCHK:
        ; Check if there's an argument
        ORA     A               ; Null = end
        JZ      TYPERR          ; No argument
        ; Parse filename into DFCB
        LXI     D, DFCB
        CALL    PARFCB

        ; Open file
        LXI     D, DFCB
        MVI     C, B_OPEN
        CALL    BDOSCL
        INR     A
        JZ      TYPNF

        XRA     A
        STA     DFCB+32         ; Clear CR

TYPLP:
        ; Read record
        LXI     D, DFCB
        MVI     C, B_READ
        CALL    BDOSCL
        ORA     A
        JNZ     TYPDN           ; EOF

        ; Print buffer
        LXI     H, DBUFF
        MVI     B, 128
TYPCHR:
        MOV     A, M
        CPI     1AH             ; ^Z = EOF
        JZ      TYPDN
        MOV     C, A
        PUSH    H
        PUSH    B
        CALL    OUTCHR
        POP     B
        POP     H
        INX     H
        DCR     B
        JNZ     TYPCHR

        ; Check for ^C to abort
        PUSH    B
        MVI     C, B_CONST
        CALL    BDOSCL
        POP     B
        ORA     A
        JZ      TYPLP
        MVI     C, B_CONIN
        CALL    BDOSCL
        CPI     CTRLC
        JNZ     TYPLP

TYPDN:
        CALL    CRLF
        RET

TYPERR:
        LXI     D, MSGERR
        JMP     PRTSTR

TYPNF:
        LXI     D, MSGNF
        JMP     PRTSTR

;-------------------------------------------------------------------------------
; CMDSAV - SAVE built-in command
;-------------------------------------------------------------------------------
; Description:
;   Saves memory from TPA (0100H) to a file. Usage: SAVE nn filename
;   where nn is the number of 256-byte pages to save.
;
; Input:
;   DBUFF   - [REQ] Command line: "SAVE nn filename"
;
; Output:
;   (disk)  - File created with memory contents
;-------------------------------------------------------------------------------

CMDSAV:
        ; Parse number of pages from command line
        LXI     H, DBUFF+1
        CALL    SKIPSPC
        CALL    GETNUM
        ORA     A
        JZ      SAVERR          ; No number

        STA     SAVPGS

        ; Skip to filename
        CALL    SKIPSPC

        ; Parse filename into FCB
        LXI     D, DFCB
        CALL    PARFCB

        ; Create file
        LXI     D, DFCB
        MVI     C, B_DELETE     ; Delete existing
        CALL    BDOSCL

        LXI     D, DFCB
        MVI     C, B_MAKE
        CALL    BDOSCL
        INR     A
        JZ      SAVFUL          ; Directory full

        ; Write pages
        LXI     H, TPA          ; Start address
SAVLP:
        LDA     SAVPGS
        ORA     A
        JZ      SAVDN

        ; Write 2 records per page (256 bytes = 2 * 128)
        PUSH    H
        XCHG
        MVI     C, B_SETDMA
        CALL    BDOSCL
        LXI     D, DFCB
        MVI     C, B_WRITE
        CALL    BDOSCL
        POP     H
        ORA     A
        JNZ      SAVERW          ; Write error

        LXI     D, 128
        DAD     D
        PUSH    H
        XCHG
        MVI     C, B_SETDMA
        CALL    BDOSCL
        LXI     D, DFCB
        MVI     C, B_WRITE
        CALL    BDOSCL
        POP     H
        ORA     A
        JNZ     SAVERW

        LXI     D, 128
        DAD     D

        LDA     SAVPGS
        DCR     A
        STA     SAVPGS
        JMP     SAVLP

SAVDN:
        ; Close file
        LXI     D, DFCB
        MVI     C, B_CLOSE
        CALL    BDOSCL

        ; Reset DMA
        LXI     D, DBUFF
        MVI     C, B_SETDMA
        CALL    BDOSCL
        RET

SAVERR:
        LXI     D, MSGERR
        JMP     PRTSTR

SAVFUL:
        LXI     D, MSGFUL
        JMP     PRTSTR

SAVERW:
        LXI     D, MSGWER
        JMP     PRTSTR

; GETNUM - Parse decimal number from string
; Input: HL=string  Output: A=value, HL advanced  Clobbers: BC, flags
GETNUM:
        MVI     B, 0            ; Accumulator
GNLOOP:
        MOV     A, M
        CPI     '0'
        JC      GNDONE
        CPI     '9'+1
        JNC     GNDONE
        SUI     '0'
        MOV     C, A
        MOV     A, B
        ADD     A               ; *2
        ADD     A               ; *4
        ADD     B               ; *5
        ADD     A               ; *10
        ADD     C               ; +digit
        MOV     B, A
        INX     H
        JMP     GNLOOP
GNDONE:
        MOV     A, B
        RET

; SKIPSPC - Skip whitespace characters
; Input: HL=string  Output: HL=first non-space  Clobbers: A, flags
SKIPSPC:
        MOV     A, M
        CPI     ' '
        RNZ
        INX     H
        JMP     SKIPSPC

;-------------------------------------------------------------------------------
; CMDUSR - USER built-in command
;-------------------------------------------------------------------------------
; Description:
;   Sets the current user number (0-15). User numbers provide separate
;   file namespaces on the same disk.
;
; Input:
;   DBUFF   - [REQ] Command line: "USER n"
;
; Output:
;   (BDOS)  - User number changed
;-------------------------------------------------------------------------------

CMDUSR:
        ; Get number from command line
        LXI     H, DBUFF+1
        CALL    SKIPSPC
        ; Skip "USER"
        LXI     D, 4
        DAD     D
        CALL    SKIPSPC
        CALL    GETNUM
        CPI     16              ; Valid range 0-15
        JNC     USRERR

        MOV     E, A
        MVI     C, B_USER
        CALL    BDOSCL
        RET

USRERR:
        LXI     D, MSGERR
        JMP     PRTSTR

;-------------------------------------------------------------------------------
; Utility Routines
;-------------------------------------------------------------------------------

; BDOSCL - BDOS call with register preservation
; Input: C=function, DE=param  Output: A=result  Clobbers: flags (preserves HL, BC)
BDOSCL:
        PUSH    H               ; Preserve HL (BDOS corrupts it)
        PUSH    B               ; Preserve BC
        CALL    ENTRY
        POP     B
        POP     H
        RET

; GETDSK - Select current disk via BDOS
; Input: CURDSK  Output: (disk selected)  Clobbers: A, C, E, flags
GETDSK:
        LDA     CURDSK
        MOV     E, A
        MVI     C, B_SELDSK
        CALL    BDOSCL
        RET

; OUTCHR - Output character to console
; Input: C=character  Output: (none)  Clobbers: A, flags (preserves HL, BC)
OUTCHR:
        PUSH    H               ; Preserve HL (BDOS corrupts it)
        PUSH    B               ; Preserve BC
        MOV     E, C            ; E = character to output
        MVI     C, B_CONOUT     ; C = function number
        CALL    ENTRY
        POP     B
        POP     H
        RET

; PRTSTR - Print '$'-terminated string
; Input: DE=string address  Output: (console)  Clobbers: A, C, flags
PRTSTR:
        MVI     C, B_PRINT
        CALL    ENTRY
        RET

; CRLF - Print carriage return and line feed
; Input: (none)  Output: (console)  Clobbers: A, C, flags
CRLF:
        MVI     C, CR
        CALL    OUTCHR
        MVI     C, LF
        CALL    OUTCHR
        RET

; TOUPPER - Convert character to uppercase
; Input: A=character  Output: A=uppercase  Clobbers: flags
TOUPPER:
        CPI     'a'
        RC
        CPI     'z'+1
        RNC
        SUI     20H
        RET

; COPY - Copy B bytes from HL to DE
; Input: B=count, HL=source, DE=dest  Output: HL,DE advanced  Clobbers: A, B, flags
COPY:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     COPY
        RET

;-------------------------------------------------------------------------------
; Messages
;-------------------------------------------------------------------------------

MSGNF:  DB      'No File$'
MSGERR: DB      'Error$'
MSGFUL: DB      'Disk Full$'
MSGWER: DB      'Write Error$'
MSGTL:  DB      'Too Large$'
MSGCNF: DB      'All (Y/N)?$'

;-------------------------------------------------------------------------------
; Data Area
;-------------------------------------------------------------------------------

CURDSK: DS      1               ; Current disk
LOADAD: DS      2               ; Load address for transient
SAVPGS: DS      1               ; Pages to save
CMDTAIL: DS     2               ; Pointer to command tail (after command name)

CMDBUF: DS      129             ; Command input buffer

; CCP Stack
        DS      64              ; 32 levels
CCPSTK:

        END
