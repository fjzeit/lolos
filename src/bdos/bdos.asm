;===============================================================================
; LOLOS BDOS - Basic Disk Operating System (CP/M 2.2 Compatible)
; Target: z80pack (cpmsim)
; CPU: Intel 8080 (no Z80 extensions)
;===============================================================================

;-------------------------------------------------------------------------------
; System Constants (must match BIOS)
;-------------------------------------------------------------------------------

MSIZE   EQU     64
BIAS    EQU     (MSIZE-20)*1024
CCP     EQU     3400H+BIAS
BDOS    EQU     CCP+0800H
BIOS    EQU     CCP+1600H

; Page zero
IOBYTE  EQU     0003H
CDISK   EQU     0004H
TDRIVE  EQU     0004H           ; Current drive in low nibble

; BIOS entry points (offsets from BIOS base)
BOOT    EQU     BIOS+00H
WBOOT   EQU     BIOS+03H
BCONST  EQU     BIOS+06H
BCONIN  EQU     BIOS+09H
BCONOUT EQU     BIOS+0CH
BLIST   EQU     BIOS+0FH
BPUNCH  EQU     BIOS+12H
BREADER EQU     BIOS+15H
BHOME   EQU     BIOS+18H
BSELDSK EQU     BIOS+1BH
BSETTRK EQU     BIOS+1EH
BSETSEC EQU     BIOS+21H
BSETDMA EQU     BIOS+24H
BREAD   EQU     BIOS+27H
BWRITE  EQU     BIOS+2AH
BLISTST EQU     BIOS+2DH
BSECTRN EQU     BIOS+30H

; ASCII codes
CR      EQU     0DH
LF      EQU     0AH
TAB     EQU     09H
CTRLC   EQU     03H
CTRLE   EQU     05H
CTRLH   EQU     08H             ; Backspace
CTRLP   EQU     10H             ; Printer toggle
CTRLR   EQU     12H             ; Retype line
CTRLS   EQU     13H             ; Pause
CTRLU   EQU     15H             ; Delete line
CTRLX   EQU     18H             ; Delete line (alt)
CTRLZ   EQU     1AH             ; End of file
DEL     EQU     7FH             ; Delete/rubout

;-------------------------------------------------------------------------------
; BDOS Entry Point
;-------------------------------------------------------------------------------

        ORG     BDOS

        JMP     BDOSENT         ; Reserved for serial number check
        DB      0,0,0           ; Serial number bytes (unused)

; Main BDOS entry - function number in C, parameter in DE
BDOSENT:
        XCHG                    ; HL = parameter
        SHLD    PARAM           ; Save parameter
        XCHG
        MOV     A, E
        STA     PARAMLO         ; Save low byte separately for easy access
        MOV     A, C
        STA     FUNCT           ; Save function number

        LXI     H, 0
        SHLD    RETS            ; Clear return value
        DAD     SP              ; HL = current SP
        SHLD    ENTSP           ; Save entry stack pointer
        LXI     SP, BDOSSK      ; Switch to BDOS stack

        MOV     A, C
        CPI     41              ; Check function range
        JNC     BFRET           ; Return if >= 41

        MOV     E, A            ; Function number in E
        MVI     D, 0
        LXI     H, FTABLE       ; Jump table address
        DAD     D
        DAD     D               ; HL = FTABLE + function*2
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A            ; HL = handler address

        PUSH    H               ; Push handler address
        LHLD    PARAM           ; HL = parameter
        XCHG                    ; DE = parameter
        RET                     ; "Call" handler via RET

; Return from BDOS function
BFRET:
        LHLD    ENTSP
        SPHL                    ; Restore caller's stack
        LHLD    RETS            ; Get return value
        MOV     A, L            ; Also return in A
        MOV     B, H            ; And B for some functions
        RET

; Set A in L, clear H, and return
SETLA:
        MOV     L, A
        MVI     H, 0
        ; falls through to SETRET

; Set return value and exit
SETRET:
        SHLD    RETS
        JMP     BFRET

;-------------------------------------------------------------------------------
; Function Jump Table
;-------------------------------------------------------------------------------

FTABLE:
        DW      FUNC00          ; 0  - System reset
        DW      FUNC01          ; 1  - Console input
        DW      FUNC02          ; 2  - Console output
        DW      FUNC03          ; 3  - Auxiliary input
        DW      FUNC04          ; 4  - Auxiliary output
        DW      FUNC05          ; 5  - List output
        DW      FUNC06          ; 6  - Direct console I/O
        DW      FUNC07          ; 7  - Get IOBYTE
        DW      FUNC08          ; 8  - Set IOBYTE
        DW      FUNC09          ; 9  - Print string
        DW      FUNC10          ; 10 - Read console buffer
        DW      FUNC11          ; 11 - Console status
        DW      FUNC12          ; 12 - Return version
        DW      FUNC13          ; 13 - Reset disk system
        DW      FUNC14          ; 14 - Select disk
        DW      FUNC15          ; 15 - Open file
        DW      FUNC16          ; 16 - Close file
        DW      FUNC17          ; 17 - Search first
        DW      FUNC18          ; 18 - Search next
        DW      FUNC19          ; 19 - Delete file
        DW      FUNC20          ; 20 - Read sequential
        DW      FUNC21          ; 21 - Write sequential
        DW      FUNC22          ; 22 - Make file
        DW      FUNC23          ; 23 - Rename file
        DW      FUNC24          ; 24 - Return login vector
        DW      FUNC25          ; 25 - Return current disk
        DW      FUNC26          ; 26 - Set DMA address
        DW      FUNC27          ; 27 - Get allocation vector
        DW      FUNC28          ; 28 - Write protect disk
        DW      FUNC29          ; 29 - Get R/O vector
        DW      FUNC30          ; 30 - Set file attributes
        DW      FUNC31          ; 31 - Get DPB address
        DW      FUNC32          ; 32 - Get/set user code
        DW      FUNC33          ; 33 - Read random
        DW      FUNC34          ; 34 - Write random
        DW      FUNC35          ; 35 - Compute file size
        DW      FUNC36          ; 36 - Set random record
        DW      FUNC37          ; 37 - Reset drive
        DW      BFRET           ; 38 - (not used in 2.2)
        DW      BFRET           ; 39 - (not used in 2.2)
        DW      FUNC40          ; 40 - Write random with zero fill

;-------------------------------------------------------------------------------
; Console I/O Functions (0-12)
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; FUNC00 - System reset (BDOS Function 0)
;-------------------------------------------------------------------------------
; Description:
;   Terminates the calling program and performs a warm boot. Reloads
;   CCP and reinitializes page zero vectors.
;
; Input:
;   C       - [REQ] Function number (0)
;
; Output:
;   (none)  - Does not return
;
; Notes:
;   - Equivalent to JMP 0000H
;-------------------------------------------------------------------------------

FUNC00:
        JMP     WBOOT

;-------------------------------------------------------------------------------
; FUNC01 - Console input with echo (BDOS Function 1)
;-------------------------------------------------------------------------------
; Description:
;   Reads a character from the console, waiting if necessary. Echoes
;   printable characters and CR/LF/TAB back to the console. Handles
;   ^S (pause) and ^P (printer toggle) control characters.
;
; Input:
;   C       - [REQ] Function number (1)
;
; Output:
;   A       - ASCII character read
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC01:
        CALL    CONINW          ; Get character (with ^S/^P handling)
        PUSH    PSW
        MOV     C, A
        CPI     ' '             ; Printable?
        JC      F01NE           ; No echo for control chars (except CR, LF, TAB)
        CALL    CONOUTW
        JMP     F01DN
F01NE:
        CPI     CR
        JZ      F01EC
        CPI     LF
        JZ      F01EC
        CPI     TAB
        JNZ     F01DN
F01EC:
        CALL    CONOUTW         ; Echo CR, LF, TAB
F01DN:
        POP     PSW
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC02 - Console output (BDOS Function 2)
;-------------------------------------------------------------------------------
; Description:
;   Outputs a character to the console. If printer echo is enabled
;   (via ^P), also sends the character to the list device.
;
; Input:
;   C       - [REQ] Function number (2)
;   E       - [REQ] ASCII character to output
;
; Output:
;   (none)
;
; Clobbers:
;   A, BC, flags
;-------------------------------------------------------------------------------

FUNC02:
        MOV     C, E
        CALL    CONOUTW
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC03 - Auxiliary input (BDOS Function 3)
;-------------------------------------------------------------------------------
; Description:
;   Reads a character from the auxiliary (reader) input device.
;
; Input:
;   C       - [REQ] Function number (3)
;
; Output:
;   A       - ASCII character read
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC03:
        CALL    BREADER
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC04 - Auxiliary output (BDOS Function 4)
;-------------------------------------------------------------------------------
; Description:
;   Outputs a character to the auxiliary (punch) output device.
;
; Input:
;   C       - [REQ] Function number (4)
;   E       - [REQ] ASCII character to output
;
; Output:
;   (none)
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FUNC04:
        MOV     C, E
        CALL    BPUNCH
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC05 - List output (BDOS Function 5)
;-------------------------------------------------------------------------------
; Description:
;   Outputs a character to the list (printer) device.
;
; Input:
;   C       - [REQ] Function number (5)
;   E       - [REQ] ASCII character to output
;
; Output:
;   (none)
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FUNC05:
        MOV     C, E
        CALL    BLIST
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC06 - Direct console I/O (BDOS Function 6)
;-------------------------------------------------------------------------------
; Description:
;   Provides raw console I/O without ^S/^P processing. Mode is
;   determined by the value in E.
;
; Input:
;   C       - [REQ] Function number (6)
;   E       - [REQ] Mode/character:
;             FFH = Input if ready, else return 0
;             FEH = Return console status
;             FDH = Input, wait for character
;             00H-FCH = Output character E
;
; Output:
;   A       - For input: character read (or 0 if not ready)
;           - For status: 0=not ready, FFH=ready
;           - For output: undefined
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC06:
        MOV     A, E
        CPI     0FFH
        JZ      F06IN
        CPI     0FEH
        JZ      F06ST
        CPI     0FDH
        JZ      F06IW
        MOV     C, E            ; Output
        CALL    BCONOUT
        JMP     BFRET
F06ST:
        CALL    BCONST          ; Status
        JMP     SETLA
F06IW:
        CALL    BCONIN          ; Input, wait
        JMP     SETLA
F06IN:
        CALL    BCONST          ; Check status
        ORA     A
        JZ      BFRET           ; Return 0 if not ready
        CALL    BCONIN          ; Get character
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC07 - Get I/O byte (BDOS Function 7)
;-------------------------------------------------------------------------------
; Description:
;   Returns the current value of the IOBYTE at address 0003H.
;   IOBYTE controls device assignments for CON:, RDR:, PUN:, LST:.
;
; Input:
;   C       - [REQ] Function number (7)
;
; Output:
;   A       - Current IOBYTE value
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC07:
        LDA     IOBYTE
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC08 - Set I/O byte (BDOS Function 8)
;-------------------------------------------------------------------------------
; Description:
;   Sets the IOBYTE at address 0003H to control device assignments.
;
; Input:
;   C       - [REQ] Function number (8)
;   E       - [REQ] New IOBYTE value
;
; Output:
;   (none)
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FUNC08:
        MOV     A, E
        STA     IOBYTE
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC09 - Print string (BDOS Function 9)
;-------------------------------------------------------------------------------
; Description:
;   Outputs a string to the console. The string is terminated by a '$'
;   character (which is not printed). Uses CONOUTW for printer echo.
;
; Input:
;   C       - [REQ] Function number (9)
;   DE      - [REQ] Address of '$'-terminated string
;
; Output:
;   (none)
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FUNC09:
        XCHG                    ; HL = string address
F09LP:
        MOV     A, M
        CPI     '$'
        JZ      BFRET
        MOV     C, A
        CALL    CONOUTW
        INX     H
        JMP     F09LP

;-------------------------------------------------------------------------------
; FUNC10 - Read console buffer (BDOS Function 10)
;-------------------------------------------------------------------------------
; Description:
;   Reads a line of input from the console with editing support.
;   Supports backspace/delete, ^U/^X (delete line), ^R (retype),
;   ^E (physical end of line). Input terminates on CR or LF.
;
; Input:
;   C       - [REQ] Function number (10)
;   DE      - [REQ] Buffer address with format:
;             Byte 0: Maximum characters to read (1-255)
;             Byte 1: Actual count (filled by BDOS on return)
;             Bytes 2+: Character data (filled by BDOS)
;
; Output:
;   Buffer  - Byte 1 = actual character count (excluding CR)
;           - Bytes 2+ = characters entered
;
; Clobbers:
;   BC, DE, HL, flags
;
; Notes:
;   - CR/LF is echoed but not stored in buffer
;   - ^C causes warm boot
;-------------------------------------------------------------------------------

FUNC10:
        XCHG                    ; HL = buffer address
        MOV     B, M            ; B = max length
        INX     H
        PUSH    H               ; Save pointer to length byte
        INX     H               ; HL = first char position
        MVI     C, 0            ; C = current length

F10LP:
        PUSH    B
        PUSH    H
        CALL    CONINW          ; Get character
        POP     H
        POP     B

        ; Save character in E for later
        MOV     E, A

        CPI     CR              ; End of line?
        JZ      F10DN

        CPI     LF              ; Also end of line
        JZ      F10DN

        CPI     CTRLH           ; Backspace?
        JZ      F10BS
        CPI     DEL             ; Delete?
        JZ      F10BS

        CPI     CTRLU           ; Delete line?
        JZ      F10DL
        CPI     CTRLX           ; Delete line?
        JZ      F10DL

        CPI     CTRLR           ; Retype?
        JZ      F10RT

        CPI     CTRLE           ; Physical end of line?
        JZ      F10PE

        CPI     ' '             ; Control char?
        JC      F10LP           ; Ignore other control chars

        ; Regular character - check if room
        MOV     A, C
        CMP     B               ; At max?
        JNC     F10BEL          ; Ring bell if full

        ; Store character in buffer
        MOV     A, E            ; Get saved character
        MOV     M, A            ; Store in buffer
        INX     H               ; Advance buffer pointer
        INR     C               ; Increment count

        ; Echo the character
        PUSH    B
        PUSH    H
        MOV     C, E            ; Character to echo
        CALL    CONOUTW
        POP     H
        POP     B
        JMP     F10LP

F10BEL:
        PUSH    B               ; Save count FIRST
        PUSH    H
        MVI     C, 07H          ; Bell character
        CALL    CONOUTW
        POP     H
        POP     B
        JMP     F10LP

F10BS:
        MOV     A, C
        ORA     A               ; At start?
        JZ      F10LP
        DCR     C               ; Back up count
        DCX     H               ; Back up pointer
        MVI     A, CTRLH        ; Backspace
        PUSH    B
        PUSH    H
        MOV     C, A
        CALL    CONOUTW
        MVI     C, ' '          ; Space
        CALL    CONOUTW
        MVI     C, CTRLH        ; Backspace again
        CALL    CONOUTW
        POP     H
        POP     B
        JMP     F10LP

F10DL:
        ; Delete entire line
        MOV     A, C
        ORA     A
        JZ      F10LP
F10DL2:
        MOV     A, C
        ORA     A
        JZ      F10RST
        DCR     C
        DCX     H
        PUSH    B
        PUSH    H
        MVI     C, CTRLH
        CALL    CONOUTW
        MVI     C, ' '
        CALL    CONOUTW
        MVI     C, CTRLH
        CALL    CONOUTW
        POP     H
        POP     B
        JMP     F10DL2
F10RST:
        JMP     F10LP

F10RT:
        ; Retype line - print CR/LF then all chars
        PUSH    B
        PUSH    H
        CALL    CRLF
        POP     H
        POP     B
        ; Retype... skip for now
        JMP     F10LP

F10PE:
        ; Physical end of line - CR/LF but continue
        PUSH    B
        PUSH    H
        CALL    CRLF
        POP     H
        POP     B
        JMP     F10LP

F10DN:
        ; Done - store length and echo CR/LF
        POP     H               ; Get length byte pointer
        MOV     M, C            ; Store actual length
        PUSH    B
        CALL    CRLF
        POP     B
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC11 - Console status (BDOS Function 11)
;-------------------------------------------------------------------------------
; Description:
;   Returns the console input status. Handles ^S (pause) if a character
;   is waiting.
;
; Input:
;   C       - [REQ] Function number (11)
;
; Output:
;   A       - 0 if no character ready, FFH if character ready
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC11:
        CALL    CONSTAT
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC12 - Return version number (BDOS Function 12)
;-------------------------------------------------------------------------------
; Description:
;   Returns the CP/M version number. Used by programs to check
;   compatibility.
;
; Input:
;   C       - [REQ] Function number (12)
;
; Output:
;   HL      - 0022H (CP/M 2.2)
;   A       - 22H (low byte)
;   B       - 00H (high byte)
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - H=00 indicates CP/M (vs MP/M), L=22H indicates version 2.2
;-------------------------------------------------------------------------------

FUNC12:
        LXI     H, 0022H        ; CP/M 2.2
        JMP     SETRET

;-------------------------------------------------------------------------------
; Console Helper Routines
;-------------------------------------------------------------------------------

; CRLF - Print carriage return and line feed
; Input: (none)  Output: (none)  Clobbers: A, C
CRLF:
        MVI     C, CR
        CALL    CONOUTW
        MVI     C, LF
        JMP     CONOUTW

;-------------------------------------------------------------------------------
; CONINW - Console input with control character handling
;-------------------------------------------------------------------------------
; Description:
;   Reads a character from console via BIOS. Handles ^S (pause until
;   another key) and ^P (toggle printer echo flag).
;
; Input:
;   (none)
;
; Output:
;   A       - Character read (^S and ^P consumed, not returned)
;
; Clobbers:
;   Flags
;-------------------------------------------------------------------------------

CONINW:
        CALL    BCONIN
        ANI     7FH             ; Strip high bit
        CPI     CTRLS           ; Pause?
        JNZ     COINRT
        CALL    BCONIN          ; Wait for another key
        ANI     7FH
COINRT:
        CPI     CTRLP           ; Printer toggle?
        JNZ     COINR2
        LDA     PFLG
        XRI     0FFH            ; Toggle flag
        STA     PFLG
        JMP     CONINW          ; Get another character
COINR2:
        RET

;-------------------------------------------------------------------------------
; CONOUTW - Console output with printer echo
;-------------------------------------------------------------------------------
; Description:
;   Outputs a character to the console via BIOS. If printer echo is
;   enabled (PFLG set), also sends the character to the list device.
;
; Input:
;   C       - [REQ] Character to output
;
; Output:
;   (none)
;
; Clobbers:
;   A, flags
;
; Notes:
;   - Preserves PSW across call
;-------------------------------------------------------------------------------

CONOUTW:
        PUSH    PSW
        CALL    BCONOUT
        LDA     PFLG
        ORA     A
        JZ      COUTR
        POP     PSW
        PUSH    PSW
        MOV     C, A
        CALL    BLIST
COUTR:
        POP     PSW
        RET

;-------------------------------------------------------------------------------
; CONSTAT - Console status with pause handling
;-------------------------------------------------------------------------------
; Description:
;   Checks console status via BIOS. If a character is waiting and it's
;   ^S, pauses until another key is pressed.
;
; Input:
;   (none)
;
; Output:
;   A       - 0 if no character, FFH if character ready
;
; Clobbers:
;   Flags
;-------------------------------------------------------------------------------

CONSTAT:
        CALL    BCONST
        ORA     A
        RZ
        CALL    BCONIN          ; Character waiting
        ANI     7FH
        CPI     CTRLS           ; Pause?
        JNZ     CSTRT
        CALL    BCONIN          ; Wait for key
        CALL    BCONST          ; Check again
CSTRT:
        RET

;-------------------------------------------------------------------------------
; Disk System Functions (13-40)
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; FUNC13 - Reset disk system (BDOS Function 13)
;-------------------------------------------------------------------------------
; Description:
;   Resets the disk subsystem. Selects drive A:, user 0, resets DMA
;   to 0080H, clears the login and read-only vectors.
;
; Input:
;   C       - [REQ] Function number (13)
;
; Output:
;   CDISK   - Reset to 0 (drive A:)
;   USERNO  - Reset to 0
;   DMADDR  - Reset to 0080H
;   LOGINV  - Cleared to 0
;   ROVEC   - Cleared to 0
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FUNC13:
        XRA     A
        STA     CDISK           ; Reset to drive A
        STA     USERNO          ; Reset to user 0
        LXI     H, 0080H
        SHLD    DMADDR          ; Reset DMA to 0080H
        LXI     B, 0080H
        CALL    BSETDMA

        ; Clear login vector and R/O vector
        LXI     H, 0
        SHLD    LOGINV
        SHLD    ROVEC
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC14 - Select disk (BDOS Function 14)
;-------------------------------------------------------------------------------
; Description:
;   Selects a disk drive as the default for subsequent file operations.
;   Logs the drive in if not already logged, initializing its ALV.
;
; Input:
;   C       - [REQ] Function number (14)
;   E       - [REQ] Drive number (0=A, 1=B, ... 15=P)
;
; Output:
;   CDISK   - Updated with selected drive
;   LOGINV  - Bit set for selected drive
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FUNC14:
        MOV     A, E
        ANI     0FH             ; Mask to 0-15
        STA     CDISK
        CALL    SELDRIVE        ; Select in BIOS and get DPH
        JMP     BFRET

;-------------------------------------------------------------------------------
; SELDRIVE - Select drive and initialize if needed (internal)
;-------------------------------------------------------------------------------
; Description:
;   Selects a disk drive via BIOS and initializes its allocation vector
;   if this is the first login. Updates the login vector.
;
; Input:
;   A       - [REQ] Drive number (0=A, 1=B, etc.)
;
; Output:
;   HL      - DPH address, or 0 if invalid drive
;   CURDPH  - Updated with DPH address
;   LOGINV  - Bit set for selected drive
;
; Clobbers:
;   A, BC, DE, flags
;-------------------------------------------------------------------------------

SELDRIVE:
        MOV     C, A
        MVI     E, 0            ; First select
        CALL    BSELDSK
        MOV     A, H
        ORA     L
        RZ                      ; Return if invalid
        SHLD    CURDPH          ; Save DPH
        ; Mark drive as logged in
        LDA     CDISK
        CALL    BITMASK         ; B = mask for drive
        ; Check if already logged in
        LDA     LOGINV
        ANA     B
        JNZ     SELD3           ; Already logged in, skip init
        ; First login - initialize ALV
        PUSH    B
        CALL    INITALV
        POP     B
SELD3:
        LDA     LOGINV
        ORA     B
        STA     LOGINV
        LHLD    CURDPH
        RET

;-------------------------------------------------------------------------------
; FUNC15 - Open file (BDOS Function 15)
;-------------------------------------------------------------------------------
; Description:
;   Opens an existing file. Searches the directory for an entry matching
;   the FCB filename and extent number. If found, copies the directory
;   data (extent, S1, S2, RC, allocation map) into the FCB.
;
; Input:
;   C       - [REQ] Function number (15)
;   DE      - [REQ] FCB address (drive, filename, extent must be set)
;
; Output:
;   A       - Directory code (0-3) on success, FFH if not found
;   L       - Same as A
;   H       - 0
;   FCB     - On success: bytes 12-32 filled from directory entry
;             CR (byte 32) cleared to 0
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Extent byte (FCB+12) must match directory entry
;   - Drive byte: 0=default, 1=A:, 2=B:, etc.
;-------------------------------------------------------------------------------

FUNC15:
        CALL    SETFCB
        ; Get extent from user's FCB
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        MOV     A, M            ; A = requested extent
        STA     OPENEXT         ; Save for comparison
        XRA     A
        STA     SEARCHI         ; Start from entry 0
F15LP:
        CALL    SEARCH          ; Find directory entry
        CPI     0FFH
        JZ      F15NF           ; Not found
        ; Check if extent matches
        LHLD    DIRPTR
        LXI     D, 12
        DAD     D               ; HL = dir entry + 12 (extent)
        MOV     A, M            ; A = directory extent
        ANI     1FH             ; Mask to extent bits (0-31)
        MOV     B, A
        LDA     OPENEXT
        ANI     1FH
        CMP     B               ; Compare extents
        JNZ     F15LP           ; Not matching extent, try next
        ; Found matching extent - copy directory data to FCB
        LHLD    CURFCB
        LXI     D, 12           ; Skip to extent field
        DAD     D
        XCHG                    ; DE = FCB+12
        LHLD    DIRPTR
        LXI     B, 12
        DAD     B               ; HL = dir entry + 12
        MVI     B, 21           ; Copy EX through allocation
        CALL    COPYB
        LHLD    CURFCB
        LXI     D, 32
        DAD     D
        XRA     A
        MOV     M, A            ; Clear CR (current record)
        MVI     L, 0            ; Return directory code
        JMP     SETRET
F15NF:
        MVI     A, 0FFH
        JMP     SETLA

OPENEXT: DS     1               ; Requested extent for OPEN
CLOSEXT: DS     1               ; Extent for CLOSE

;-------------------------------------------------------------------------------
; FUNC16 - Close file (BDOS Function 16)
;-------------------------------------------------------------------------------
; Description:
;   Closes an open file by writing the FCB data back to the directory.
;   Searches for the directory entry matching filename and extent,
;   then updates it with the FCB's allocation map and record count.
;
; Input:
;   C       - [REQ] Function number (16)
;   DE      - [REQ] FCB address
;
; Output:
;   A       - 0 on success, FFH if not found
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Must match both filename and extent number
;   - Updates EX, S1, S2, RC and allocation map in directory
;-------------------------------------------------------------------------------

FUNC16:
        CALL    SETFCB
        ; Get extent from user's FCB
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        MOV     A, M            ; A = FCB's extent
        STA     CLOSEXT         ; Save for comparison
        XRA     A
        STA     SEARCHI         ; Start from entry 0
F16LP:
        CALL    SEARCH
        CPI     0FFH
        JZ      F16NF
        ; Check if extent matches
        LHLD    DIRPTR
        LXI     D, 12
        DAD     D
        MOV     A, M
        ANI     1FH
        MOV     B, A
        LDA     CLOSEXT
        ANI     1FH
        CMP     B
        JNZ     F16LP           ; Not matching extent, try next
        ; Update directory entry from FCB
        LHLD    CURFCB
        LXI     D, 12
        DAD     D               ; HL = FCB+12
        XCHG                    ; DE = FCB+12
        LHLD    DIRPTR
        LXI     B, 12
        DAD     B               ; HL = dir+12
        XCHG                    ; Swap: HL=FCB+12, DE=dir+12
        MVI     B, 20           ; Copy EX through allocation (not CR)
        CALL    COPYB
        CALL    WRITEDIR        ; Write directory sector back
        MVI     L, 0
        JMP     SETRET
F16NF:
        MVI     A, 0FFH
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC17 - Search for first (BDOS Function 17)
;-------------------------------------------------------------------------------
; Description:
;   Searches the directory for the first entry matching the FCB filename.
;   Wildcards ('?') in the FCB match any character. The matching
;   directory sector is copied to the DMA buffer.
;
; Input:
;   C       - [REQ] Function number (17)
;   DE      - [REQ] FCB address with filename pattern
;
; Output:
;   A       - Directory code (0-3) indicating entry position, FFH if not found
;   L       - Same as A
;   H       - 0
;   DMA     - 128-byte directory sector containing match (if found)
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Sets SEARCHI for subsequent Search Next calls
;   - '?' in FCB byte 0 matches all user numbers
;-------------------------------------------------------------------------------

FUNC17:
        CALL    SETFCB
        XRA     A
        STA     SEARCHI         ; Start from entry 0
        ; Fall through to search next

;-------------------------------------------------------------------------------
; FUNC18 - Search for next (BDOS Function 18)
;-------------------------------------------------------------------------------
; Description:
;   Continues a directory search started by Search First (F17). Returns
;   the next matching entry.
;
; Input:
;   C       - [REQ] Function number (18)
;   (implicit) - SEARCHI from previous F17 or F18 call
;
; Output:
;   A       - Directory code (0-3), FFH if no more matches
;   L       - Same as A
;   H       - 0
;   DMA     - 128-byte directory sector containing match (if found)
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Must be preceded by F17 or another F18 call
;-------------------------------------------------------------------------------

FUNC18:
        CALL    SEARCH
        CPI     0FFH
        JZ      F18NF           ; Not found
        ; Copy directory buffer to DMA address
        PUSH    PSW
        LHLD    DMADDR
        XCHG                    ; DE = DMA address
        LXI     H, DIRBUF
        MVI     B, 128
        CALL    COPYB
        POP     PSW
        JMP     SETLA           ; Return directory code (0-3)
F18NF:
        MVI     A, 0FFH
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC19 - Delete file (BDOS Function 19)
;-------------------------------------------------------------------------------
; Description:
;   Deletes all directory entries matching the FCB filename pattern.
;   Wildcards are supported for deleting multiple files.
;
; Input:
;   C       - [REQ] Function number (19)
;   DE      - [REQ] FCB address with filename pattern
;
; Output:
;   A       - 0 on success
;   L       - Same as A
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Marks entries with E5H (deleted)
;   - Does not free disk blocks (freed on next INITALV)
;-------------------------------------------------------------------------------

FUNC19:
        CALL    SETFCB
        XRA     A
        STA     SEARCHI
F19LP:
        CALL    SEARCH
        CPI     0FFH
        JZ      F19DN           ; No more matches
        ; Mark entry as deleted
        CALL    GETDIRENT
        MVI     M, 0E5H         ; E5 = deleted
        CALL    WRITEDIR
        JMP     F19LP
F19DN:
        MVI     L, 0
        JMP     SETRET

;-------------------------------------------------------------------------------
; FUNC20 - Read sequential (BDOS Function 20)
;-------------------------------------------------------------------------------
; Description:
;   Reads the next 128-byte record from the file. Automatically advances
;   to the next extent when the current extent is exhausted.
;
; Input:
;   C       - [REQ] Function number (20)
;   DE      - [REQ] FCB address (must be opened)
;
; Output:
;   A       - 0 on success, 1 on EOF/error
;   L       - Same as A
;   H       - 0
;   DMA     - 128 bytes of file data (on success)
;   FCB     - CR incremented, extent updated if needed
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - CR (FCB+32) is the current record within extent
;   - Extent auto-advances when CR reaches 128
;-------------------------------------------------------------------------------

FUNC20:
        CALL    SETFCB
        LHLD    CURFCB
        LXI     D, 32
        DAD     D               ; HL = FCB+32 (CR)
        MOV     A, M            ; Get current record
        PUSH    H               ; Save CR pointer
        CALL    READREC         ; Read record A from current extent
        POP     H
        ORA     A
        JNZ     F20ERR          ; Error
        INR     M               ; Increment CR
        MOV     A, M
        CPI     128             ; End of extent?
        JC      F20OK
        ; Need next extent
        MVI     M, 0            ; Reset CR
        LHLD    CURFCB
        LXI     D, 12
        DAD     D               ; HL = extent byte
        INR     M               ; Increment extent
        ; Re-open file to load next extent's data
        CALL    F20OPN          ; Open next extent
        ORA     A
        JNZ     F20EOF          ; No more extents = EOF
F20OK:
        MVI     L, 0
        JMP     SETRET
F20ERR:
        MVI     A, 1
        JMP     SETLA
F20EOF:
        MVI     A, 1            ; Return 1 = EOF
        JMP     SETLA

; F20OPN - Open next extent for reading
; Searches directory for matching filename and extent, loads allocation map
; Returns: A=0 if found, A=FFH if not found
F20OPN:
        ; Get extent from FCB
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        MOV     A, M            ; A = extent to find
        STA     OPENEXT         ; Save for comparison
        XRA     A
        STA     SEARCHI         ; Start search from beginning
F20OLP:
        CALL    SEARCH          ; Search for filename match
        CPI     0FFH
        RZ                      ; Not found - return FFH
        ; Check if extent matches
        LHLD    DIRPTR
        LXI     D, 12
        DAD     D
        MOV     A, M            ; A = directory extent
        ANI     1FH             ; Mask extent bits
        MOV     B, A
        LDA     OPENEXT
        ANI     1FH
        CMP     B
        JNZ     F20OLP          ; Wrong extent, keep searching
        ; Found matching extent - copy data to FCB
        ; Copy extent byte, S1, S2, RC
        LHLD    DIRPTR
        LXI     D, 12
        DAD     D               ; HL = dir entry extent
        XCHG                    ; DE = dir entry extent
        LHLD    CURFCB
        PUSH    H               ; Save FCB base
        LXI     B, 12
        DAD     B               ; HL = FCB extent
        XCHG                    ; DE = FCB extent, HL = dir extent
        MVI     B, 4            ; Copy 4 bytes (EX, S1, S2, RC)
F20OC1:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     F20OC1
        ; Copy allocation map (16 bytes)
        POP     H               ; HL = FCB base
        PUSH    H
        LXI     D, 16
        DAD     D               ; HL = FCB allocation map
        XCHG                    ; DE = FCB alloc map
        LHLD    DIRPTR
        LXI     B, 16
        DAD     B               ; HL = dir alloc map
        MVI     B, 16
F20OC2:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     F20OC2
        POP     H               ; Clean up stack
        XRA     A               ; Return 0 = success
        RET

;-------------------------------------------------------------------------------
; FUNC21 - Write sequential (BDOS Function 21)
;-------------------------------------------------------------------------------
; Description:
;   Writes a 128-byte record to the file at the current position.
;   Allocates new blocks as needed. Automatically creates a new extent
;   when the current one fills (128 records).
;
; Input:
;   C       - [REQ] Function number (21)
;   DE      - [REQ] FCB address (must be opened or created)
;   DMA     - 128 bytes of data to write
;
; Output:
;   A       - 0 on success, 1 on error, 2 on disk full
;   L       - Same as A
;   H       - 0
;   FCB     - CR incremented, RC/extent updated
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Closes current extent and creates new one at 128 records
;   - Allocates blocks from allocation vector as needed
;   - Error 1 = I/O error or directory full
;   - Error 2 = disk full (no free blocks)
;-------------------------------------------------------------------------------

FUNC21:
        CALL    SETFCB
        CALL    CHKRO           ; Check if drive is read-only
        JNZ     F21ERR          ; If R/O, return error (A=1)
        LHLD    CURFCB
        LXI     D, 32
        DAD     D               ; HL = FCB+32 (CR)
        MOV     A, M            ; Get current record
        PUSH    H
        CALL    WRITEREC        ; Write record A to current extent
        POP     H
        ORA     A
        JNZ     F21ERR
        INR     M               ; Increment CR
        MOV     A, M
        CPI     128             ; End of extent?
        JC      F21OK
        ; Extent overflow - need new extent
        ; First, close current extent
        CALL    F21CLS
        ORA     A
        JNZ     F21ERR
        ; Increment extent number in FCB
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        INR     M               ; Increment extent
        ; Reset CR and RC
        LHLD    CURFCB
        LXI     D, 32
        DAD     D
        MVI     M, 0            ; Reset CR
        LHLD    CURFCB
        LXI     D, 15
        DAD     D
        MVI     M, 0            ; Reset RC
        ; Clear allocation map for new extent
        LHLD    CURFCB
        LXI     D, 16
        DAD     D
        MVI     B, 16
F21CAL:
        MVI     M, 0
        INX     H
        DCR     B
        JNZ     F21CAL
        ; Create new directory entry for this extent
        CALL    F21MKE
        ORA     A
        JNZ     F21ERR
F21OK:
        MVI     L, 0
        JMP     SETRET
F21ERR:
        JMP     SETLA           ; Pass through error code (1=error, 2=disk full)

; Close current extent (internal helper for extent overflow)
F21CLS:
        ; Get extent from FCB
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        MOV     A, M
        STA     CLOSEXT
        XRA     A
        STA     SEARCHI
F21CLP:
        CALL    SEARCH
        CPI     0FFH
        JZ      F21CNF          ; Not found - OK for new extent
        ; Check extent match
        LHLD    DIRPTR
        LXI     D, 12
        DAD     D
        MOV     A, M
        ANI     1FH
        MOV     B, A
        LDA     CLOSEXT
        ANI     1FH
        CMP     B
        JNZ     F21CLP
        ; Update directory entry
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        XCHG
        LHLD    DIRPTR
        LXI     B, 12
        DAD     B
        XCHG
        MVI     B, 20
        CALL    COPYB
        CALL    WRITEDIR
F21CNF:
        XRA     A               ; Return success
        RET

; Create new directory entry for current extent
F21MKE:
        CALL    FINDFREE
        CPI     0FFH
        JZ      F21MER          ; Directory full
        ; Clear the directory entry (32 bytes)
        CALL    GETDIRENT
        MVI     B, 32
        XRA     A
F21MCL:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     F21MCL
        ; Set user number
        CALL    GETDIRENT
        LDA     USERNO
        MOV     M, A
        ; Copy filename from FCB (11 bytes at FCB+1)
        INX     H               ; dir+1 = filename start
        PUSH    H               ; Save destination
        LHLD    CURFCB
        INX     H               ; FCB+1 = filename start
        POP     D               ; DE = dir+1
        XCHG                    ; HL = dir+1, DE = FCB+1
        MVI     B, 11
F21MCN:
        LDAX    D               ; Get from FCB
        MOV     M, A            ; Store to dir
        INX     H
        INX     D
        DCR     B
        JNZ     F21MCN
        ; Set extent number from FCB
        CALL    GETDIRENT
        LXI     D, 12
        DAD     D               ; HL = dir+12 (extent field)
        PUSH    H
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        MOV     A, M            ; Get extent from FCB
        POP     H
        MOV     M, A            ; Store in directory entry
        CALL    WRITEDIR
        XRA     A
        RET
F21MER:
        MVI     A, 1
        RET

;-------------------------------------------------------------------------------
; FUNC22 - Make file (BDOS Function 22)
;-------------------------------------------------------------------------------
; Description:
;   Creates a new file in the directory. Finds a free directory entry
;   and initializes it with the FCB's filename and user number.
;
; Input:
;   C       - [REQ] Function number (22)
;   DE      - [REQ] FCB address (filename set)
;
; Output:
;   A       - Directory code (0-3) on success, FFH if directory full
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - File is created with zero length (no blocks allocated)
;   - EX, S1, S2, RC, and allocation map are zeroed
;-------------------------------------------------------------------------------

FUNC22:
        CALL    SETFCB
        ; Find free directory entry
        CALL    FINDFREE
        CPI     0FFH
        JZ      F22ERR          ; Directory full
        ; Initialize directory entry
        CALL    GETDIRENT
        PUSH    H
        ; Clear entry
        MVI     B, 32
        XRA     A
F22CLR:
        MOV     M, A
        INX     H
        DCR     B
        JNZ     F22CLR
        ; Copy filename from FCB
        POP     H
        PUSH    H
        LDA     USERNO
        MOV     M, A            ; User number
        INX     H
        LHLD    CURFCB
        INX     H               ; Skip drive byte, HL = FCB+1 (source)
        XCHG                    ; DE = FCB+1
        POP     H
        INX     H               ; HL = dir+1 (dest)
        XCHG                    ; Now HL = FCB+1 (source), DE = dir+1 (dest)
        MVI     B, 11           ; Copy filename + type
        CALL    COPYB
        CALL    WRITEDIR
        MVI     L, 0
        JMP     SETRET
F22ERR:
        MVI     A, 0FFH
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC23 - Rename file (BDOS Function 23)
;-------------------------------------------------------------------------------
; Description:
;   Renames files matching the pattern. The new name is taken from
;   the second half of the FCB (bytes 17-27).
;
; Input:
;   C       - [REQ] Function number (23)
;   DE      - [REQ] FCB address:
;             Bytes 1-11: Old filename pattern (wildcards allowed)
;             Bytes 17-27: New filename
;
; Output:
;   A       - 0 on success
;   L       - Same as A
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - All matching entries are renamed
;   - Wildcards in old name match multiple files
;-------------------------------------------------------------------------------

FUNC23:
        CALL    SETFCB
        XRA     A
        STA     SEARCHI
F23LP:
        CALL    SEARCH
        CPI     0FFH
        JZ      F23DN
        ; Rename: copy new name from FCB+17 to directory entry
        CALL    GETDIRENT
        INX     H               ; Skip user number
        XCHG                    ; DE = dest (dir entry + 1)
        LHLD    CURFCB
        LXI     B, 17           ; New name at FCB+17
        DAD     B               ; HL = source (FCB+17)
        MVI     B, 11           ; Copy filename+type
        CALL    COPYB
        CALL    WRITEDIR
        JMP     F23LP
F23DN:
        MVI     L, 0
        JMP     SETRET

;-------------------------------------------------------------------------------
; FUNC24 - Return login vector (BDOS Function 24)
;-------------------------------------------------------------------------------
; Description:
;   Returns a bitmap indicating which drives are currently logged in.
;   Bit 0 = A:, bit 1 = B:, etc.
;
; Input:
;   C       - [REQ] Function number (24)
;
; Output:
;   HL      - Login vector (bit set = drive logged in)
;   A       - Low byte of login vector
;   B       - High byte of login vector
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC24:
        LHLD    LOGINV
        JMP     SETRET

;-------------------------------------------------------------------------------
; FUNC25 - Return current disk (BDOS Function 25)
;-------------------------------------------------------------------------------
; Description:
;   Returns the currently selected default disk number.
;
; Input:
;   C       - [REQ] Function number (25)
;
; Output:
;   A       - Current disk (0=A, 1=B, etc.)
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC25:
        LDA     CDISK
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC26 - Set DMA address (BDOS Function 26)
;-------------------------------------------------------------------------------
; Description:
;   Sets the DMA (Direct Memory Access) address for subsequent disk
;   and directory operations. The 128-byte buffer at this address
;   is used for file I/O.
;
; Input:
;   C       - [REQ] Function number (26)
;   DE      - [REQ] DMA buffer address
;
; Output:
;   DMADDR  - Updated with new address
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FUNC26:
        XCHG
        SHLD    DMADDR
        XCHG
        MOV     B, D
        MOV     C, E
        CALL    BSETDMA
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC27 - Get allocation vector address (BDOS Function 27)
;-------------------------------------------------------------------------------
; Description:
;   Returns the address of the allocation vector (ALV) for the current
;   disk. The ALV is a bitmap where each bit represents one disk block.
;
; Input:
;   C       - [REQ] Function number (27)
;
; Output:
;   HL      - ALV address
;   A       - Low byte of address
;   B       - High byte of address
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Returns 0 if no disk selected
;   - ALV pointer is at DPH+14
;-------------------------------------------------------------------------------

FUNC27:
        LHLD    CURDPH
        MOV     A, H
        ORA     L
        JZ      BFRET           ; No disk selected
        LXI     D, 14           ; Offset to ALV pointer in DPH
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A
        JMP     SETRET

;-------------------------------------------------------------------------------
; FUNC28 - Write protect disk (BDOS Function 28)
;-------------------------------------------------------------------------------
; Description:
;   Sets the current disk as read-only. Subsequent write attempts
;   will fail until the disk is reset.
;
; Input:
;   C       - [REQ] Function number (28)
;
; Output:
;   ROVEC   - Bit set for current drive
;
; Clobbers:
;   BC, DE, HL, flags
;
; Notes:
;   - Reset via F13 (Reset Disk System) or F37 (Reset Drive)
;-------------------------------------------------------------------------------

FUNC28:
        LDA     CDISK
        CALL    BITMASK         ; B = mask for drive
        LDA     ROVEC
        ORA     B
        STA     ROVEC
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC29 - Get R/O vector (BDOS Function 29)
;-------------------------------------------------------------------------------
; Description:
;   Returns a bitmap indicating which drives are write-protected.
;   Bit 0 = A:, bit 1 = B:, etc.
;
; Input:
;   C       - [REQ] Function number (29)
;
; Output:
;   HL      - R/O vector (bit set = read-only)
;   A       - Low byte
;   B       - High byte
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC29:
        LHLD    ROVEC
        JMP     SETRET

;-------------------------------------------------------------------------------
; FUNC30 - Set file attributes (BDOS Function 30)
;-------------------------------------------------------------------------------
; Description:
;   Updates the attribute bits (high bits of T1-T3) in the directory
;   from the FCB. Used to set Read-Only and System attributes.
;
; Input:
;   C       - [REQ] Function number (30)
;   DE      - [REQ] FCB address with attributes set in bytes 9-11
;             Bit 7 of T1 (byte 9): Read-Only
;             Bit 7 of T2 (byte 10): System
;             Bit 7 of T3 (byte 11): Archive
;
; Output:
;   A       - 0 on success, FFH if file not found
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC30:
        ; Copy attribute bits from FCB to directory
        CALL    SETFCB
        XRA     A
        STA     SEARCHI         ; Start from entry 0
        CALL    SEARCH
        CPI     0FFH
        JZ      F30NF
        CALL    GETDIRENT
        PUSH    H
        LHLD    CURFCB
        LXI     D, 9            ; T1 (first type char)
        DAD     D
        XCHG                    ; DE = FCB+9
        POP     H
        LXI     B, 9
        DAD     B               ; HL = dir+9
        XCHG                    ; HL = FCB+9, DE = dir+9
        MVI     B, 3            ; Copy T1-T3
        CALL    COPYB
        CALL    WRITEDIR
        MVI     L, 0
        JMP     SETRET
F30NF:
        MVI     A, 0FFH
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC31 - Get DPB address (BDOS Function 31)
;-------------------------------------------------------------------------------
; Description:
;   Returns the address of the Disk Parameter Block (DPB) for the
;   current disk. The DPB contains disk geometry parameters.
;
; Input:
;   C       - [REQ] Function number (31)
;
; Output:
;   HL      - DPB address
;   A       - Low byte
;   B       - High byte
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Returns 0 if no disk selected
;   - DPB pointer is at DPH+10
;-------------------------------------------------------------------------------

FUNC31:
        LHLD    CURDPH
        MOV     A, H
        ORA     L
        JZ      BFRET
        LXI     D, 10           ; Offset to DPB pointer in DPH
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A
        JMP     SETRET

;-------------------------------------------------------------------------------
; FUNC32 - Get/set user code (BDOS Function 32)
;-------------------------------------------------------------------------------
; Description:
;   Gets or sets the current user number. User numbers (0-15) provide
;   separate file namespaces on the same disk.
;
; Input:
;   C       - [REQ] Function number (32)
;   E       - [REQ] FFH to get current user, 0-15 to set user
;
; Output:
;   A       - Current user number (if E=FFH on input)
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;-------------------------------------------------------------------------------

FUNC32:
        MOV     A, E
        CPI     0FFH            ; Get user?
        JNZ     F32SET
        LDA     USERNO
        JMP     SETLA
F32SET:
        ANI     0FH             ; Mask to 0-15
        STA     USERNO
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC33 - Read random (BDOS Function 33)
;-------------------------------------------------------------------------------
; Description:
;   Reads a record at the position specified by the random record
;   field (FCB bytes 33-35). Does not advance the record pointer.
;
; Input:
;   C       - [REQ] Function number (33)
;   DE      - [REQ] FCB address (must be opened, R0-R2 set)
;
; Output:
;   A       - 0 on success
;             1 on unwritten record (CR >= RC or block unallocated)
;             6 on seek past end of disk (R2 > 0)
;   L       - Same as A
;   H       - 0
;   DMA     - 128 bytes of file data (on success)
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Random record is 24-bit: R0 (LSB), R1, R2 (MSB)
;   - Converts to extent/CR internally
;-------------------------------------------------------------------------------

FUNC33:
        CALL    SETFCB
        CALL    RNDREC          ; Convert random record to extent/record
        ORA     A
        JNZ     F33ERR          ; RNDREC returned error (6=past disk)
        ; Load CR from FCB for READREC
        LHLD    CURFCB
        LXI     D, 32
        DAD     D
        MOV     A, M            ; A = CR
        CALL    READREC
F33ERR:
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC34 - Write random (BDOS Function 34)
;-------------------------------------------------------------------------------
; Description:
;   Writes a record at the position specified by the random record
;   field (FCB bytes 33-35). Allocates blocks as needed.
;
; Input:
;   C       - [REQ] Function number (34)
;   DE      - [REQ] FCB address (must be opened, R0-R2 set)
;   DMA     - 128 bytes of data to write
;
; Output:
;   A       - 0 on success
;             2 on disk full (no free blocks)
;             6 on seek past end of disk (R2 > 0)
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Creates sparse files (unwritten blocks not allocated)
;   - Random record is 24-bit: R0 (LSB), R1, R2 (MSB)
;-------------------------------------------------------------------------------

FUNC34:
        CALL    SETFCB
        CALL    CHKRO           ; Check if drive is read-only
        JNZ     F34ERR          ; If R/O, return error (A=1)
        CALL    RNDREC          ; Convert random record to extent/record
        ORA     A
        JNZ     F34ERR          ; RNDREC returned error (6=past disk)
        ; Load CR from FCB for WRITEREC
        LHLD    CURFCB
        LXI     D, 32
        DAD     D
        MOV     A, M            ; A = CR
        CALL    WRITEREC        ; Returns 0=success, 2=disk full
F34ERR:
        JMP     SETLA

;-------------------------------------------------------------------------------
; FUNC35 - Compute file size (BDOS Function 35)
;-------------------------------------------------------------------------------
; Description:
;   Calculates the file size in 128-byte records and stores the result
;   in the random record field (FCB bytes 33-35). Scans all extents.
;
; Input:
;   C       - [REQ] Function number (35)
;   DE      - [REQ] FCB address (filename set)
;
; Output:
;   FCB     - Bytes 33-35 (R0-R2) set to file size in records
;
; Clobbers:
;   BC, DE, HL, flags
;
; Notes:
;   - Searches all extents to find the highest record
;   - Size = (max_extent * 128) + max_RC
;-------------------------------------------------------------------------------

FUNC35:
        ; Set random record field to file size
        CALL    SETFCB
        ; Search all extents, find highest
        XRA     A
        STA     SEARCHI
        LXI     H, 0
        SHLD    MAXREC          ; Max record found
F35LP:
        CALL    SEARCH
        CPI     0FFH
        JZ      F35DN
        ; Calculate records in this extent
        CALL    GETDIRENT
        LXI     D, 12
        DAD     D               ; HL = extent byte
        MOV     A, M            ; Extent number
        RLC                     ; *2
        RLC                     ; *4
        RLC                     ; *8
        RLC                     ; *16
        RLC                     ; *32
        RLC                     ; *64
        RLC                     ; *128
        MOV     B, A            ; B = extent * 128
        INX     H
        INX     H
        INX     H               ; HL = RC
        MOV     A, M
        ADD     B               ; A = extent*128 + RC
        MOV     C, A
        MVI     B, 0            ; BC = total records
        LHLD    MAXREC
        MOV     A, C
        SUB     L
        MOV     A, B
        SBB     H               ; Compare BC - HL
        JC      F35LP           ; Current less than max
        MOV     H, B
        MOV     L, C
        SHLD    MAXREC
        JMP     F35LP
F35DN:
        LHLD    MAXREC
        XCHG                    ; DE = size
        LHLD    CURFCB
        LXI     B, 33
        DAD     B               ; HL = R0
        MOV     M, E            ; Store low byte
        INX     H
        MOV     M, D            ; Store high byte
        INX     H
        MVI     M, 0            ; R2 = 0
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC36 - Set random record (BDOS Function 36)
;-------------------------------------------------------------------------------
; Description:
;   Sets the random record field (FCB bytes 33-35) from the current
;   sequential position (extent and CR).
;
; Input:
;   C       - [REQ] Function number (36)
;   DE      - [REQ] FCB address
;
; Output:
;   FCB     - Bytes 33-35 (R0-R2) set from extent*128 + CR
;
; Clobbers:
;   BC, DE, HL, flags
;
; Notes:
;   - Allows switching from sequential to random access
;   - Random record = (EX * 128) + CR
;-------------------------------------------------------------------------------

FUNC36:
        CALL    SETFCB
        LHLD    CURFCB
        LXI     D, 12
        DAD     D
        MOV     A, M            ; Extent
        RLC
        RLC
        RLC
        RLC
        RLC
        RLC
        RLC                     ; *128
        PUSH    H
        LHLD    CURFCB
        LXI     D, 32
        DAD     D
        ADD     M               ; Add CR
        POP     H
        ; Store in random record field
        PUSH    PSW
        LHLD    CURFCB
        LXI     D, 33
        DAD     D
        POP     PSW
        MOV     M, A            ; R0
        INX     H
        MVI     M, 0            ; R1
        INX     H
        MVI     M, 0            ; R2
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC37 - Reset drive (BDOS Function 37)
;-------------------------------------------------------------------------------
; Description:
;   Resets specified drives by clearing their login and R/O bits.
;   The drive bitmap specifies which drives to reset.
;
; Input:
;   C       - [REQ] Function number (37)
;   DE      - [REQ] Drive bitmap (bit 0=A:, bit 1=B:, etc.)
;
; Output:
;   LOGINV  - Specified bits cleared
;   ROVEC   - Specified bits cleared
;
; Clobbers:
;   BC, DE, HL, flags
;
; Notes:
;   - Drives will be re-logged on next access (ALV rebuilt)
;-------------------------------------------------------------------------------

FUNC37:
        ; DE = drive bitmap - reset specified drives
        XCHG
        SHLD    TEMP16
        ; Clear login bits for specified drives
        LDA     LOGINV
        MOV     B, A
        LDA     TEMP16
        CMA
        ANA     B
        STA     LOGINV
        ; Clear R/O bits too
        LDA     ROVEC
        MOV     B, A
        LDA     TEMP16
        CMA
        ANA     B
        STA     ROVEC
        JMP     BFRET

;-------------------------------------------------------------------------------
; FUNC40 - Write random with zero fill (BDOS Function 40)
;-------------------------------------------------------------------------------
; Description:
;   Same as Write Random (F34), but fills unallocated blocks with zeros
;   instead of leaving them as garbage. Prevents data leakage.
;
; Input:
;   C       - [REQ] Function number (40)
;   DE      - [REQ] FCB address (must be opened, R0-R2 set)
;   DMA     - 128 bytes of data to write
;
; Output:
;   A       - 0 on success, 1 on seek error, 2 on disk full
;   L       - Same as A
;   H       - 0
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Currently implemented same as F34 (zero fill not done)
;-------------------------------------------------------------------------------

FUNC40:
        ; Same as write random, but fills unallocated blocks with zeros
        ; For now, same as regular write
        JMP     FUNC34

;-------------------------------------------------------------------------------
; Disk I/O Helper Routines
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; SETFCB - Set up FCB pointer and select drive (internal)
;-------------------------------------------------------------------------------
; Description:
;   Initializes CURFCB from PARAM and selects the drive specified in
;   the FCB (or default drive if FCB byte 0 is 0).
;
; Input:
;   PARAM   - [REQ] FCB address (set by BDOS entry)
;
; Output:
;   CURFCB  - Set to FCB address
;   CURDSK  - Set to drive number
;   CURDPH  - Set via SELDRIVE
;
; Clobbers:
;   A, BC, DE, HL, flags
;-------------------------------------------------------------------------------

SETFCB:
        LHLD    PARAM
        SHLD    CURFCB
        ; Get drive from FCB
        MOV     A, M
        ORA     A               ; 0 = default drive
        JZ      SFDEF
        DCR     A               ; Convert 1-16 to 0-15
        JMP     SFSEL
SFDEF:
        LDA     CDISK
SFSEL:
        STA     CURDSK
        CALL    SELDRIVE
        RET

;-------------------------------------------------------------------------------
; CHKRO - Check if current drive is read-only (internal)
;-------------------------------------------------------------------------------
; Description:
;   Checks ROVEC to see if CURDSK is marked read-only.
;
; Input:
;   CURDSK  - Drive to check (0-15)
;
; Output:
;   A       - 0 if writable, 1 if read-only
;   Z flag  - Set if writable, clear if read-only
;
; Clobbers:
;   BC, HL, flags
;-------------------------------------------------------------------------------

CHKRO:
        LDA     CURDSK
        CALL    BITMASK         ; B = mask for drive
        ; Check appropriate byte of ROVEC based on drive number
        LDA     CURDSK
        CPI     8
        JNC     CHKRH           ; Drive 8-15, check high byte
        LDA     ROVEC
        ANA     B
        RZ                      ; Z=writable
        MVI     A, 1
        RET
CHKRH:
        LDA     ROVEC+1
        ANA     B
        RZ                      ; Z=writable
        MVI     A, 1
        RET

;-------------------------------------------------------------------------------
; SEARCH - Search directory for matching FCB entry (internal)
;-------------------------------------------------------------------------------
; Description:
;   Scans directory starting from SEARCHI for an entry matching CURFCB.
;   Supports '?' wildcards. Skips deleted (E5H) entries and entries
;   with non-matching user numbers.
;
; Input:
;   CURFCB  - [REQ] FCB with search pattern
;   SEARCHI - [REQ] Starting directory index
;   USERNO  - [REQ] Current user number
;
; Output:
;   A       - Directory code (0-3) if found, FFH if not found
;   SEARCHI - Updated to next entry (for Search Next)
;   DIRPTR  - Points to matched entry in DIRBUF
;   DIRBUF  - Contains directory sector
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

SEARCH:
        LDA     SEARCHI
SRCHLP:
        STA     SRCHCUR
        ; Calculate directory sector and entry
        ; Each sector has 4 entries (128/32)
        MOV     B, A
        ANI     03H             ; Entry within sector (0-3)
        STA     DIRENT
        MOV     A, B
        RRC
        RRC
        ANI     3FH             ; Sector number
        STA     DIRSEC

        ; Check if past end of directory
        LHLD    CURDPH
        MOV     A, H
        ORA     L
        JZ      SRCHNF          ; No disk
        LXI     D, 10
        DAD     D               ; DPB pointer
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A            ; HL = DPB
        LXI     D, 7
        DAD     D               ; DRM
        MOV     A, M
        INX     H
        MOV     E, A
        MOV     D, M            ; DE = DRM (max dir entry)
        LDA     SRCHCUR
        MOV     L, A
        MVI     H, 0
        ; Compare HL vs DE
        MOV     A, L
        SUB     E
        MOV     A, H
        SBB     D
        JNC     SRCHNF          ; Past end

        ; Read directory sector
        CALL    READDIR
        ORA     A
        JNZ     SRCHNF          ; Read error

        ; Get pointer to entry
        CALL    GETDIRENT

        ; Check if entry matches FCB
        ; First check user number / deleted status
        MOV     A, M
        CPI     0E5H            ; Deleted?
        JZ      SRCHNX          ; Skip deleted entries

        ; Check user number (unless FCB has ?)
        LHLD    CURFCB
        MOV     B, M            ; FCB drive/user
        MOV     A, B
        CPI     '?'             ; Match all?
        JZ      SRCHUM
        LDA     USERNO
        MOV     B, A
        CALL    GETDIRENT
        MOV     A, M
        CMP     B               ; Compare user numbers
        JNZ     SRCHNX          ; No match

SRCHUM:
        ; Compare filename (11 bytes)
        CALL    GETDIRENT
        INX     H               ; Skip user byte
        XCHG                    ; DE = dir entry + 1
        LHLD    CURFCB
        INX     H               ; Skip drive byte
        ; Compare 11 bytes, ? in FCB matches anything
        MVI     B, 11
SRCHCMP:
        LDAX    D
        ANI     7FH             ; Mask attribute bits
        MOV     C, A
        MOV     A, M
        CPI     '?'             ; Wildcard?
        JZ      SRCHCN
        ANI     7FH
        CMP     C
        JNZ     SRCHNX          ; No match
SRCHCN:
        INX     H
        INX     D
        DCR     B
        JNZ     SRCHCMP

        ; Match found
        CALL    GETDIRENT       ; Get entry pointer
        SHLD    DIRPTR          ; Save for OPEN/etc
        LDA     SRCHCUR
        INR     A
        STA     SEARCHI         ; Save for search next
        LDA     DIRENT          ; Return entry index (0-3)
        RET

SRCHNX:
        ; Try next entry
        LDA     SRCHCUR
        INR     A
        JMP     SRCHLP

SRCHNF:
        MVI     A, 0FFH         ; Not found
        RET

;-------------------------------------------------------------------------------
; FINDFREE - Find free directory entry (internal)
;-------------------------------------------------------------------------------
; Description:
;   Scans directory for a free (E5H) entry for creating new files.
;
; Input:
;   CURDPH  - [REQ] Current disk's DPH
;
; Output:
;   A       - Directory code (0-3) if found, FFH if directory full
;   DIRSEC  - Sector containing free entry
;   DIRENT  - Entry index within sector
;   DIRBUF  - Contains directory sector
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

FINDFREE:
        XRA     A
FFREELP:
        STA     SRCHCUR
        ; Check bounds
        LHLD    CURDPH
        MOV     A, H
        ORA     L
        JZ      FFREENF
        LXI     D, 10
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A
        LXI     D, 7
        DAD     D
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = DRM
        LDA     SRCHCUR
        MOV     L, A
        MVI     H, 0
        MOV     A, L
        SUB     E
        MOV     A, H
        SBB     D
        JNC     FFREENF

        ; Calculate sector/entry
        LDA     SRCHCUR
        MOV     B, A
        ANI     03H
        STA     DIRENT
        MOV     A, B
        RRC
        RRC
        ANI     3FH
        STA     DIRSEC

        CALL    READDIR
        ORA     A
        JNZ     FFREENF

        CALL    GETDIRENT
        MOV     A, M
        CPI     0E5H            ; Deleted/free?
        JZ      FFREEFND

        LDA     SRCHCUR
        INR     A
        JMP     FFREELP

FFREEFND:
        LDA     DIRENT
        RET

FFREENF:
        MVI     A, 0FFH
        RET

; GETDIRENT - Get pointer to directory entry in DIRBUF
; Input: DIRENT=entry index (0-3)  Output: HL=pointer  Clobbers: A, DE, flags
GETDIRENT:
        ; Calculate pointer to directory entry in DIRBUF
        ; Entry 0: offset 0, Entry 1: offset 32, Entry 2: offset 64, Entry 3: offset 96
        ; offset = entry * 32
        LDA     DIRENT
        ADD     A               ; *2
        ADD     A               ; *4
        ADD     A               ; *8
        ADD     A               ; *16
        ADD     A               ; *32
        MOV     E, A
        MVI     D, 0
        LXI     H, DIRBUF
        DAD     D
        RET

;-------------------------------------------------------------------------------
; READDIR - Read directory sector from disk (internal)
;-------------------------------------------------------------------------------
; Description:
;   Reads the directory sector specified by DIRSEC into DIRBUF. Sets up
;   BIOS with track (reserved tracks) and translated sector.
;
; Input:
;   DIRSEC  - [REQ] Logical sector number within directory
;   CURDPH  - [REQ] Current disk's DPH
;
; Output:
;   A       - 0 on success, non-0 on error
;   DIRBUF  - 128 bytes of directory data
;
; Clobbers:
;   BC, DE, HL, flags
;
; Notes:
;   - Temporarily changes DMA to DIRBUF, restores DMADDR after
;-------------------------------------------------------------------------------

READDIR:
        ; Calculate absolute sector
        ; Dir starts at track OFF (reserved tracks)
        LHLD    CURDPH
        MOV     A, H
        ORA     L
        MVI     A, 1
        RZ                      ; Error if no DPH
        LXI     D, 10
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A            ; HL = DPB
        LXI     D, 13
        DAD     D               ; OFF (reserved tracks)
        MOV     C, M
        INX     H
        MOV     B, M            ; BC = reserved tracks

        ; Set track
        CALL    BSETTRK

        ; Set sector (DIRSEC is already logical sector)
        LDA     DIRSEC
        MOV     C, A
        MVI     B, 0
        ; Translate sector
        LHLD    CURDPH
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = translation table
        CALL    BSECTRN         ; HL = physical sector
        MOV     B, H
        MOV     C, L
        CALL    BSETSEC

        ; Set DMA to directory buffer
        LXI     B, DIRBUF
        CALL    BSETDMA

        ; Read
        CALL    BREAD
        PUSH    PSW

        ; Restore user DMA
        LHLD    DMADDR
        MOV     B, H
        MOV     C, L
        CALL    BSETDMA

        POP     PSW
        RET

;-------------------------------------------------------------------------------
; WRITEDIR - Write directory sector to disk (internal)
;-------------------------------------------------------------------------------
; Description:
;   Writes DIRBUF back to the directory sector specified by DIRSEC.
;   Used after modifying directory entries.
;
; Input:
;   DIRSEC  - [REQ] Logical sector number within directory
;   CURDPH  - [REQ] Current disk's DPH
;   DIRBUF  - [REQ] 128 bytes of directory data
;
; Output:
;   A       - 0 on success, non-0 on error
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

WRITEDIR:
        LHLD    CURDPH
        MOV     A, H
        ORA     L
        MVI     A, 1
        RZ
        LXI     D, 10
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A
        LXI     D, 13
        DAD     D
        MOV     C, M
        INX     H
        MOV     B, M

        CALL    BSETTRK

        LDA     DIRSEC
        MOV     C, A
        MVI     B, 0
        LHLD    CURDPH
        MOV     E, M
        INX     H
        MOV     D, M
        CALL    BSECTRN
        MOV     B, H
        MOV     C, L
        CALL    BSETSEC

        LXI     B, DIRBUF
        CALL    BSETDMA

        MVI     C, 1            ; Directory write type
        CALL    BWRITE
        PUSH    PSW

        LHLD    DMADDR
        MOV     B, H
        MOV     C, L
        CALL    BSETDMA

        POP     PSW
        RET

;-------------------------------------------------------------------------------
; READREC - Read record from file (internal)
;-------------------------------------------------------------------------------
; Description:
;   Reads a 128-byte record from the current file. Checks record count,
;   gets block from allocation map, converts to physical address, and
;   reads via BIOS.
;
; Input:
;   A       - [REQ] Record number within extent (0-127)
;   CURFCB  - [REQ] Current FCB
;   DMADDR  - [REQ] DMA buffer address
;
; Output:
;   A       - 0 on success, 1 on EOF/error
;   DMA     - 128 bytes of data (on success)
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

READREC:
        STA     RECREQ
        ; Check if record is beyond file size (RC)
        LHLD    CURFCB
        LXI     D, 15           ; Offset to RC (record count)
        DAD     D
        MOV     B, M            ; B = RC
        LDA     RECREQ          ; A = requested record
        CMP     B               ; Compare record with RC
        JNC     RRECEOF         ; Record >= RC = EOF

        ; Get block number from allocation map
        LDA     RECREQ          ; Reload record number
        CALL    GETBLOCK
        MOV     A, H
        ORA     L
        JZ      RRECEOF         ; Block 0 = unallocated = EOF

        ; Calculate physical sector
        ; Block * 8 + (record mod 8) = absolute sector
        ; Then add reserved tracks
        ; For 8" SSSD: 26 sectors/track, 2 reserved tracks

        CALL    BLKTOSEC        ; Convert block + record to track/sector
        CALL    BREAD
        RET

RRECEOF:
        MVI     A, 1
        RET

;-------------------------------------------------------------------------------
; WRITEREC - Write record to file (internal)
;-------------------------------------------------------------------------------
; Description:
;   Writes a 128-byte record to the current file. Allocates a new block
;   if needed, updates the FCB allocation map and record count.
;
; Input:
;   A       - [REQ] Record number within extent (0-127)
;   CURFCB  - [REQ] Current FCB
;   DMADDR  - [REQ] DMA buffer with data
;
; Output:
;   A       - 0 on success, 2 on disk full (no free blocks)
;   FCB     - RC updated if record extends file
;
; Clobbers:
;   BC, DE, HL, flags
;-------------------------------------------------------------------------------

WRITEREC:
        STA     RECREQ
        CALL    GETBLOCK
        MOV     A, H
        ORA     L
        JNZ     WRECHB          ; Have block
        ; Need to allocate new block
        CALL    ALLOCBLK
        MOV     A, H
        ORA     L
        JZ      WRECERR         ; Disk full
        ; Store in FCB allocation map
        PUSH    H               ; Save block number
        CALL    PUTBLOCK
        POP     H               ; Restore block number
WRECHB:
        CALL    BLKTOSEC
        MVI     C, 0            ; Normal write
        CALL    BWRITE
        ; Update record count if needed
        PUSH    PSW
        LHLD    CURFCB
        LXI     D, 15
        DAD     D               ; RC
        LDA     RECREQ
        INR     A               ; Records = record+1
        CMP     M
        JC      WRECSK          ; RC already higher
        MOV     M, A            ; Update RC
WRECSK:
        POP     PSW
        RET
WRECERR:
        MVI     A, 2            ; 2 = disk full
        RET

; GETBLOCK - Get block number for record from FCB allocation map
; Input: RECREQ=record, CURFCB  Output: HL=block (0=unallocated)  Clobbers: A, BC, DE, flags
GETBLOCK:
        LDA     RECREQ
        RRC
        RRC
        RRC                     ; /8 = block index within extent
        ANI     0FH
        MOV     E, A
        MVI     D, 0
        LHLD    CURFCB
        LXI     B, 16           ; Allocation map starts at FCB+16
        DAD     B
        DAD     D               ; HL = pointer to block number
        MOV     L, M            ; Get block (8-bit for small disks)
        MVI     H, 0
        RET

; PUTBLOCK - Store block number in FCB allocation map
; Input: HL=block, RECREQ=record, CURFCB  Output: (FCB updated)  Clobbers: A, BC, DE, HL, flags
PUTBLOCK:
        SHLD    TEMP16
        LDA     RECREQ
        RRC
        RRC
        RRC
        ANI     0FH
        MOV     E, A
        MVI     D, 0
        LHLD    CURFCB
        LXI     B, 16
        DAD     B
        DAD     D
        LDA     TEMP16
        MOV     M, A
        RET

;-------------------------------------------------------------------------------
; ALLOCBLK - Allocate a new disk block (internal)
;-------------------------------------------------------------------------------
; Description:
;   Scans the allocation vector for a free block (bit=0), marks it as
;   used, and returns the block number.
;
; Input:
;   CURDPH  - [REQ] Current disk's DPH (for ALV and DPB)
;
; Output:
;   HL      - Block number (1-DSM), or 0 if disk full
;
; Clobbers:
;   A, BC, DE, flags
;-------------------------------------------------------------------------------

ALLOCBLK:
        ; Scan allocation vector for free block
        LHLD    CURDPH
        MOV     A, H
        ORA     L
        JZ      ABLKERR
        LXI     D, 14           ; ALV pointer
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A
        SHLD    ALVPTR          ; Save ALV address

        ; Get DSM from DPB
        LHLD    CURDPH
        LXI     D, 10
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A            ; HL = DPB
        LXI     D, 5
        DAD     D               ; DSM
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = DSM

        ; Scan for free block (bit = 0 in ALV)
        LXI     H, 0            ; Block counter
ABLKLP:
        ; Check if past DSM
        MOV     A, L
        SUB     E
        MOV     A, H
        SBB     D
        JNC     ABLKERR         ; Past end

        ; Check bit in ALV
        PUSH    H
        PUSH    D
        CALL    GETBIT          ; Check if block HL is free
        POP     D
        POP     H
        JZ      ABLKFND         ; Found free block

        INX     H
        JMP     ABLKLP

ABLKFND:
        ; Mark block as used
        PUSH    H
        CALL    SETBIT
        POP     H
        RET

ABLKERR:
        LXI     H, 0
        RET

;-------------------------------------------------------------------------------
; INITALV - Initialize allocation vector for drive (internal)
;-------------------------------------------------------------------------------
; Description:
;   Clears the ALV and rebuilds it by scanning all directory entries.
;   Called when a drive is first logged in.
;
; Input:
;   CURDPH  - [REQ] Current disk's DPH
;
; Output:
;   ALV     - Rebuilt with all used blocks marked
;
; Clobbers:
;   All registers
;-------------------------------------------------------------------------------

INITALV:
        ; Get ALV address from DPH
        LHLD    CURDPH
        LXI     D, 14           ; Offset to ALV pointer
        DAD     D
        MOV     E, M
        INX     H
        MOV     D, M
        XCHG
        SHLD    ALVPTR          ; Save ALV address

        ; Get DSM from DPB to calculate ALV size
        LHLD    CURDPH
        LXI     D, 10           ; Offset to DPB pointer
        DAD     D
        MOV     E, M
        INX     H
        MOV     D, M
        XCHG                    ; HL = DPB address
        LXI     D, 5            ; Offset to DSM
        DAD     D
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = DSM (max block number)

        ; ALV size in bytes = (DSM / 8) + 1
        MOV     A, E
        RRC
        RRC
        RRC
        ANI     1FH
        MOV     C, A            ; Low part
        MOV     A, D
        RLC
        RLC
        RLC
        RLC
        RLC
        ORA     C
        INR     A               ; +1 for partial byte
        MOV     B, A            ; B = bytes to clear

        ; Clear ALV to zeros
        LHLD    ALVPTR
IALCLR:
        MVI     M, 0
        INX     H
        DCR     B
        JNZ     IALCLR

        ; Mark directory blocks as used
        ; Get AL0, AL1 from DPB which has pre-set bits for dir blocks
        LHLD    CURDPH
        LXI     D, 10
        DAD     D
        MOV     E, M
        INX     H
        MOV     D, M
        XCHG                    ; HL = DPB
        LXI     D, 9            ; Offset to AL0
        DAD     D
        MOV     A, M            ; AL0
        INX     H
        MOV     B, M            ; AL1
        LHLD    ALVPTR
        MOV     M, A            ; Store AL0
        INX     H
        MOV     M, B            ; Store AL1

        ; Now scan directory and mark blocks as used
        XRA     A
        STA     SEARCHI
IALSCAN:
        LDA     SEARCHI
        ; Calculate sector and entry
        MOV     B, A
        ANI     03H
        STA     DIRENT
        MOV     A, B
        RRC
        RRC
        ANI     3FH
        STA     DIRSEC

        ; Check if past end of directory
        LHLD    CURDPH
        LXI     D, 10
        DAD     D
        MOV     E, M
        INX     H
        MOV     D, M
        XCHG                    ; HL = DPB
        LXI     D, 7            ; Offset to DRM
        DAD     D
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = DRM (max dir entry)
        LDA     SEARCHI
        MOV     L, A
        MVI     H, 0
        ; Compare HL with DE
        MOV     A, L
        SUB     E
        MOV     A, H
        SBB     D
        JNC     IALDON          ; Past directory end

        ; Read directory sector
        LDA     DIRSEC
        CALL    READDIR

        ; Get pointer to entry
        CALL    GETDIRENT
        MOV     A, M            ; First byte = user number or E5
        CPI     0E5H
        JZ      IALNXT          ; Empty entry, skip

        ; Valid entry - mark its blocks as used
        PUSH    H
        LXI     D, 16           ; Offset to allocation map
        DAD     D
        MVI     C, 16           ; 16 block pointers (8-bit each)
IALBLK:
        MOV     A, M
        ORA     A
        JZ      IALBN           ; Zero = unused
        ; Mark block A as used
        PUSH    H
        PUSH    B
        MOV     L, A
        MVI     H, 0
        CALL    SETBIT
        POP     B
        POP     H
IALBN:
        INX     H
        DCR     C
        JNZ     IALBLK
        POP     H

IALNXT:
        LDA     SEARCHI
        INR     A
        STA     SEARCHI
        JMP     IALSCAN

IALDON:
        RET

; BITMASK - Create bit mask for drive number (internal)
; Input: A = drive (0-15)
; Output: B = mask (1 << drive)
; Clobbers: C
BITMASK:
        MOV     C, A
        MVI     B, 1
        ORA     A
        RZ                      ; Drive 0, mask is already 1
BMLP:   MOV     A, B
        ADD     A               ; Shift left
        MOV     B, A
        DCR     C
        JNZ     BMLP
        RET

; BITPREP - Calculate ALV byte address and bit position (internal)
; Input: HL=block  Output: HL=ALV byte addr, B=bit position  Clobbers: A,C,DE
BITPREP:
        MOV     A, L
        ANI     07H
        MOV     B, A            ; B = bit position (0-7)
        MOV     A, L
        RRC
        RRC
        RRC
        ANI     1FH
        MOV     E, A
        MOV     A, H
        RLC
        RLC
        RLC
        RLC
        RLC
        ORA     E
        MOV     E, A
        MVI     D, 0            ; DE = byte offset
        LHLD    ALVPTR
        DAD     D               ; HL = byte address
        RET

; GETBIT - Test bit for block HL in allocation vector
; Input: HL=block, ALVPTR  Output: Z=free(0), NZ=used(1)  Clobbers: A,BC,DE
GETBIT:
        CALL    BITPREP
        MOV     A, M            ; Get byte
        MVI     C, 80H          ; Start with bit 7
GBITLP:
        MOV     D, A
        MOV     A, B
        ORA     A
        JZ      GBITDN
        MOV     A, C
        RRC
        MOV     C, A
        DCR     B
        MOV     A, D
        JMP     GBITLP
GBITDN:
        MOV     A, D
        ANA     C
        RET

; SETBIT - Set bit for block HL in allocation vector (mark used)
; Input: HL=block, ALVPTR  Output: (ALV updated)  Clobbers: A,BC,DE
SETBIT:
        CALL    BITPREP
        PUSH    H
        MOV     A, M
        MVI     C, 80H
SBITLP:
        MOV     D, A
        MOV     A, B
        ORA     A
        JZ      SBITDN
        MOV     A, C
        RRC
        MOV     C, A
        DCR     B
        MOV     A, D
        JMP     SBITLP
SBITDN:
        MOV     A, D
        ORA     C               ; Set the bit
        POP     H
        MOV     M, A
        RET

;-------------------------------------------------------------------------------
; BLKTOSEC - Convert block to track/sector and set BIOS (internal)
;-------------------------------------------------------------------------------
; Description:
;   Converts a block number and record offset to physical track/sector.
;   Sets BIOS track, sector (translated), and DMA address.
;
; Input:
;   HL      - [REQ] Block number
;   RECREQ  - [REQ] Record number (mod 8 used for offset within block)
;   CURDPH  - [REQ] Current disk's DPH
;   DMADDR  - [REQ] DMA buffer address
;
; Output:
;   (BIOS)  - Track, sector, DMA configured for read/write
;
; Clobbers:
;   All registers
;-------------------------------------------------------------------------------

BLKTOSEC:
        SHLD    TEMP16
        ; Sector = block * (block_size/128) + record_within_block
        ; For 1K blocks: sector = block * 8 + (record mod 8)
        ; Then convert to track/sector

        ; Get SPT from DPB
        LHLD    CURDPH
        LXI     D, 10
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A            ; HL = DPB
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = SPT

        ; Calculate absolute sector
        ; abs_sector = block * 8 + (record mod 8) + (reserved_tracks * SPT)
        LHLD    TEMP16          ; Block number
        DAD     H               ; *2
        DAD     H               ; *4
        DAD     H               ; *8
        ; Add record offset within block
        LDA     RECREQ
        ANI     07H
        MOV     C, A
        MVI     B, 0
        DAD     B               ; HL = sector offset from start of data area

        ; Add reserved tracks * SPT
        PUSH    H
        LHLD    CURDPH
        LXI     D, 10
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A            ; DPB
        PUSH    H
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = SPT
        POP     H
        LXI     B, 13
        DAD     B               ; OFF
        MOV     C, M
        INX     H
        MOV     B, M            ; BC = reserved tracks

        ; Multiply BC * DE (tracks * SPT)
        ; Simple: add DE, BC times
        LXI     H, 0
BTSLP:
        MOV     A, B
        ORA     C
        JZ      BTSDN
        DAD     D
        DCX     B
        JMP     BTSLP
BTSDN:
        ; HL = reserved sectors
        POP     D               ; DE = data sector
        DAD     D               ; HL = absolute sector

        ; Now divide by SPT to get track and sector
        ; Save for division
        SHLD    TEMP16

        ; Get SPT again
        LHLD    CURDPH
        LXI     D, 10
        DAD     D
        MOV     A, M
        INX     H
        MOV     H, M
        MOV     L, A
        MOV     E, M
        INX     H
        MOV     D, M            ; DE = SPT

        ; Divide TEMP16 by SPT
        ; Track = TEMP16 / SPT, Sector = TEMP16 mod SPT
        LHLD    TEMP16
        LXI     B, 0            ; BC = quotient (track)
DIVLP:
        MOV     A, L
        SUB     E
        MOV     L, A
        MOV     A, H
        SBB     D
        MOV     H, A
        JC      DIVDN
        INX     B
        JMP     DIVLP
DIVDN:
        ; Restore remainder
        DAD     D               ; HL = remainder (sector)
        PUSH    H
        ; Set track
        CALL    BSETTRK         ; BC = track
        POP     B               ; BC = logical sector

        ; Translate sector
        LHLD    CURDPH
        MOV     E, M
        INX     H
        MOV     D, M
        CALL    BSECTRN
        MOV     B, H
        MOV     C, L
        CALL    BSETSEC

        ; Set DMA
        LHLD    DMADDR
        MOV     B, H
        MOV     C, L
        CALL    BSETDMA
        RET

;-------------------------------------------------------------------------------
; RNDREC - Convert random record to extent and CR (internal)
;-------------------------------------------------------------------------------
; Description:
;   Converts the 24-bit random record number (FCB bytes 33-35) to
;   extent and current record (CR) for random access operations.
;
; Input:
;   CURFCB  - [REQ] FCB with random record field set
;
; Output:
;   A       - 0 on success, 6 if R2 > 0 (seek past end of disk)
;   FCB     - Extent (byte 12) and CR (byte 32) updated (if success)
;
; Clobbers:
;   DE, HL, flags
;
; Notes:
;   - Extent = random_record / 128
;   - CR = random_record mod 128
;   - Maximum addressable record is 65535 (R2 must be 0)
;-------------------------------------------------------------------------------

RNDREC:
        LHLD    CURFCB
        LXI     D, 33
        DAD     D
        MOV     E, M            ; R0
        INX     H
        MOV     D, M            ; R1
        INX     H
        MOV     A, M            ; R2
        ORA     A               ; Check if R2 > 0
        JNZ     RNDERR6         ; Past end of disk
        ; Record = R1:R0, extent = record / 128, CR = record mod 128
        ; CR = R0 AND 7FH (low 7 bits)
        MOV     A, E
        ANI     7FH
        PUSH    PSW             ; Save CR
        ; Extent = (R1 << 1) | (R0 >> 7) = bits 14:7 of record
        MOV     A, E            ; A = R0
        RLC                     ; Bit 7 of R0 → carry
        MOV     A, D            ; A = R1
        RAL                     ; (R1 << 1) | carry = extent
        ANI     1FH             ; Mask to 5 bits (extents 0-31)
        ; Store extent
        LHLD    CURFCB
        PUSH    D
        LXI     D, 12
        DAD     D
        POP     D
        MOV     M, A
        ; Store CR
        POP     PSW
        LHLD    CURFCB
        LXI     D, 32
        DAD     D
        MOV     M, A
        ; For random access, just return success
        ; The FCB should already have correct allocation from OPEN
        XRA     A               ; Return success
        RET
RNDERR6:
        MVI     A, 6            ; 6 = seek past end of disk
        RET

; COPYB - Copy B bytes from HL to DE
; Input: B=count, HL=source, DE=dest  Output: HL,DE advanced  Clobbers: A, B, flags
COPYB:
        MOV     A, M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     COPYB
        RET

;-------------------------------------------------------------------------------
; Data Area
;-------------------------------------------------------------------------------

FUNCT:  DS      1               ; Current function number
PARAM:  DS      2               ; Parameter (from DE)
PARAMLO: DS     1               ; Low byte of parameter
RETS:   DS      2               ; Return value
ENTSP:  DS      2               ; Entry stack pointer
PFLG:   DS      1               ; Printer echo flag

; Disk variables
CURDSK: DS      1               ; Current disk for operation
CURDPH: DS      2               ; Current DPH address
CURFCB: DS      2               ; Current FCB address
DMADDR: DS      2               ; DMA address
USERNO: DS      1               ; Current user number
LOGINV: DS      2               ; Login vector
ROVEC:  DS      2               ; Read-only vector

; Directory search variables
SEARCHI: DS     1               ; Search starting index
SRCHCUR: DS     1               ; Current search index
DIRSEC: DS      1               ; Directory sector
DIRENT: DS      1               ; Entry within sector (0-3)
DIRPTR: DS      2               ; Pointer to directory entry

; File I/O variables
RECREQ: DS      1               ; Requested record number
MAXREC: DS      2               ; Max record (for file size)
ALVPTR: DS      2               ; Allocation vector pointer
TEMP16: DS      2               ; Temporary 16-bit value

; Directory buffer (128 bytes = 4 entries)
DIRBUF: DS      128

; BDOS stack
        DS      64              ; 32 levels
BDOSSK:

        END
