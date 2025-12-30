;===============================================================================
; CP/M 2.2 BDOS - Basic Disk Operating System
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
; Console I/O Functions (0-11)
;-------------------------------------------------------------------------------

; Function 0: System reset (warm boot)
FUNC00:
        JMP     WBOOT

; Function 1: Console input with echo
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
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 2: Console output
FUNC02:
        MOV     C, E
        CALL    CONOUTW
        JMP     BFRET

; Function 3: Auxiliary (reader) input
FUNC03:
        CALL    BREADER
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 4: Auxiliary (punch) output
FUNC04:
        MOV     C, E
        CALL    BPUNCH
        JMP     BFRET

; Function 5: List (printer) output
FUNC05:
        MOV     C, E
        CALL    BLIST
        JMP     BFRET

; Function 6: Direct console I/O
;   E = FF: Input if ready, else 0
;   E = FE: Return status
;   E = FD: Input, wait
;   E = other: Output character
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
        MOV     L, A
        MVI     H, 0
        JMP     SETRET
F06IW:
        CALL    BCONIN          ; Input, wait
        MOV     L, A
        MVI     H, 0
        JMP     SETRET
F06IN:
        CALL    BCONST          ; Check status
        ORA     A
        JZ      BFRET           ; Return 0 if not ready
        CALL    BCONIN          ; Get character
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 7: Get IOBYTE
FUNC07:
        LDA     IOBYTE
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 8: Set IOBYTE
FUNC08:
        MOV     A, E
        STA     IOBYTE
        JMP     BFRET

; Function 9: Print string ($ terminated)
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

; Function 10: Read console buffer
;   DE = buffer address
;   Buffer: byte 0 = max length, byte 1 = actual length (filled by BDOS)
;   Characters stored starting at byte 2
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

; Function 11: Console status
FUNC11:
        CALL    CONSTAT
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 12: Return version number
FUNC12:
        LXI     H, 0022H        ; CP/M 2.2
        JMP     SETRET

;-------------------------------------------------------------------------------
; Console Helper Routines
;-------------------------------------------------------------------------------

; Print CR/LF
CRLF:
        MVI     C, CR
        CALL    CONOUTW
        MVI     C, LF
        JMP     CONOUTW

; Console input with ^S pause and ^P printer toggle handling
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

; Console output with printer echo
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

; Console status (check for ^S)
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

; Function 13: Reset disk system
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

; Function 14: Select disk
FUNC14:
        MOV     A, E
        ANI     0FH             ; Mask to 0-15
        STA     CDISK
        CALL    SELDRIVE        ; Select in BIOS and get DPH
        JMP     BFRET

; Select drive - A = drive number, returns HL = DPH or 0
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
        MOV     C, A
        MVI     B, 1
SELD1:
        MOV     A, C
        ORA     A
        JZ      SELD2
        MOV     A, B
        RLC
        MOV     B, A
        DCR     C
        JMP     SELD1
SELD2:
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

; Function 15: Open file
; Must find directory entry matching filename AND extent
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
        MVI     L, 0FFH
        MVI     H, 0
        JMP     SETRET

OPENEXT: DS     1               ; Requested extent for OPEN
CLOSEXT: DS     1               ; Extent for CLOSE

; Function 16: Close file
; Must find directory entry matching filename AND extent
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
        MVI     L, 0FFH
        MVI     H, 0
        JMP     SETRET

; Function 17: Search for first
FUNC17:
        CALL    SETFCB
        XRA     A
        STA     SEARCHI         ; Start from entry 0
        ; Fall through to search next

; Function 18: Search for next
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
        MOV     L, A            ; Return directory code (0-3)
        MVI     H, 0
        JMP     SETRET
F18NF:
        MVI     L, 0FFH
        MVI     H, 0
        JMP     SETRET

; Function 19: Delete file
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

; Function 20: Read sequential
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
        MVI     L, 1
        MVI     H, 0
        JMP     SETRET
F20EOF:
        MVI     L, 1            ; Return 1 = EOF
        MVI     H, 0
        JMP     SETRET

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

; Function 21: Write sequential
FUNC21:
        CALL    SETFCB
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
        MVI     L, 1
        MVI     H, 0
        JMP     SETRET

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

; Function 22: Make file
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
        INX     H               ; Skip drive byte
        XCHG                    ; DE = FCB+1
        POP     H
        INX     H               ; Skip user byte
        MVI     B, 11           ; Copy filename + type
        CALL    COPYB
        CALL    WRITEDIR
        MVI     L, 0
        JMP     SETRET
F22ERR:
        MVI     L, 0FFH
        MVI     H, 0
        JMP     SETRET

; Function 23: Rename file
FUNC23:
        CALL    SETFCB
        XRA     A
        STA     SEARCHI
F23LP:
        CALL    SEARCH
        CPI     0FFH
        JZ      F23DN
        ; Rename: copy new name from FCB+16 to directory entry
        CALL    GETDIRENT
        INX     H               ; Skip user number
        PUSH    H               ; Save dest pointer
        LHLD    CURFCB
        LXI     D, 17           ; New name at FCB+17
        DAD     D
        XCHG                    ; DE = new name
        POP     H               ; HL = dest
        MVI     B, 11           ; Copy filename+type
        CALL    COPYB
        CALL    WRITEDIR
        JMP     F23LP
F23DN:
        MVI     L, 0
        JMP     SETRET

; Function 24: Return login vector
FUNC24:
        LHLD    LOGINV
        JMP     SETRET

; Function 25: Return current disk
FUNC25:
        LDA     CDISK
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 26: Set DMA address
FUNC26:
        XCHG
        SHLD    DMADDR
        XCHG
        MOV     B, D
        MOV     C, E
        CALL    BSETDMA
        JMP     BFRET

; Function 27: Get allocation vector address
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

; Function 28: Write protect current disk
FUNC28:
        LDA     CDISK
        MOV     C, A
        MVI     B, 1
F28LP:
        MOV     A, C
        ORA     A
        JZ      F28DN
        MOV     A, B
        RLC
        MOV     B, A
        DCR     C
        JMP     F28LP
F28DN:
        LDA     ROVEC
        ORA     B
        STA     ROVEC
        JMP     BFRET

; Function 29: Get R/O vector
FUNC29:
        LHLD    ROVEC
        JMP     SETRET

; Function 30: Set file attributes
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
        MVI     L, 0FFH
        MVI     H, 0
        JMP     SETRET

; Function 31: Get DPB address
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

; Function 32: Get/set user code
FUNC32:
        MOV     A, E
        CPI     0FFH            ; Get user?
        JNZ     F32SET
        LDA     USERNO
        MOV     L, A
        MVI     H, 0
        JMP     SETRET
F32SET:
        ANI     0FH             ; Mask to 0-15
        STA     USERNO
        JMP     BFRET

; Function 33: Read random
FUNC33:
        CALL    SETFCB
        CALL    RNDREC          ; Convert random record to extent/record
        CALL    READREC
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 34: Write random
FUNC34:
        CALL    SETFCB
        CALL    RNDREC
        CALL    WRITEREC
        MOV     L, A
        MVI     H, 0
        JMP     SETRET

; Function 35: Compute file size
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

; Function 36: Set random record from sequential position
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

; Function 37: Reset drive
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

; Function 40: Write random with zero fill
FUNC40:
        ; Same as write random, but fills unallocated blocks with zeros
        ; For now, same as regular write
        JMP     FUNC34

;-------------------------------------------------------------------------------
; Disk I/O Helper Routines
;-------------------------------------------------------------------------------

; Set up FCB pointer from DE parameter
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

; Search for directory entry matching FCB
; Returns A = directory code (0-3) or FF if not found
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

; Find free directory entry
; Returns A = directory code or FF if full
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

; Get pointer to current directory entry in buffer
; Returns HL = pointer
GETDIRENT:
        LDA     DIRENT
        LXI     H, DIRBUF
        ; Multiply by 32
        RRC                     ; /2, bit 0 to carry
        JNC     GDE1
        LXI     D, 128          ; Add 128 if bit 0 was set
        DAD     D
GDE1:
        ANI     01H             ; Remaining bit
        JZ      GDE2
        LXI     D, 64
        DAD     D
GDE2:
        ; Wait, this is wrong. Let me recalculate.
        ; Entry 0: offset 0, Entry 1: offset 32, Entry 2: offset 64, Entry 3: offset 96
        ; So offset = entry * 32
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

; Read directory sector
; DIRSEC = sector number within directory
; Returns A = 0 if OK
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

; Write current directory sector
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

; Read record from file
; A = record number within extent
; Returns A = 0 if OK, 1 if error/EOF
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

; Write record to file
; A = record number within extent
; Returns A = 0 if OK, 1 if error
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
        MVI     A, 1
        RET

; Get block number for current record
; Returns HL = block number
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

; Store block number in FCB allocation map
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

; Allocate a new block
; Returns HL = block number or 0 if full
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

; Initialize allocation vector for current drive
; Called when drive is first logged in
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

; Get bit for block HL in ALV
; Returns Z if free (0), NZ if used (1)
GETBIT:
        ; Byte = block / 8, bit = block mod 8
        MOV     A, L
        ANI     07H
        MOV     B, A            ; B = bit position
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
        DAD     D
        MOV     A, M            ; Get byte
        ; Test bit B
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

; Set bit for block HL in ALV
SETBIT:
        MOV     A, L
        ANI     07H
        MOV     B, A
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
        MVI     D, 0
        LHLD    ALVPTR
        DAD     D
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

; Convert block number to track/sector and set BIOS params
; HL = block number
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

; Convert random record to extent/CR
RNDREC:
        LHLD    CURFCB
        LXI     D, 33
        DAD     D
        MOV     E, M            ; R0
        INX     H
        MOV     D, M            ; R1
        ; Record = R1:R0, extent = record / 128, CR = record mod 128
        MOV     A, E
        ANI     7FH
        PUSH    PSW             ; Save CR
        MOV     A, E
        RRC
        MOV     E, A
        MOV     A, D
        RAR
        MOV     D, A
        ; Repeat 6 more times for /128
        MOV     A, E
        RRC
        MOV     E, A
        MOV     A, D
        RAR
        MOV     D, A
        MOV     A, E
        RRC
        MOV     E, A
        MOV     A, D
        RAR
        MOV     D, A
        MOV     A, E
        RRC
        MOV     E, A
        MOV     A, D
        RAR
        MOV     D, A
        MOV     A, E
        RRC
        MOV     E, A
        MOV     A, D
        RAR
        MOV     D, A
        MOV     A, E
        RRC
        MOV     E, A
        MOV     A, D
        RAR
        MOV     D, A
        MOV     A, E
        RRC
        ANI     1FH             ; Extent = bits 11:7
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
        ; Re-open file for new extent
        XRA     A
        STA     SEARCHI         ; Start from entry 0
        CALL    SEARCH
        RET

; Copy B bytes from HL to DE
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
