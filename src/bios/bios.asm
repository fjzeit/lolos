;===============================================================================
; CP/M 2.2 BIOS - Basic Input/Output System
; Target: z80pack (cpmsim)
; CPU: Intel 8080 (no Z80 extensions)
;===============================================================================

;-------------------------------------------------------------------------------
; System Constants
;-------------------------------------------------------------------------------

MSIZE   EQU     64              ; System memory size in KB

; Memory layout calculations
BIAS    EQU     (MSIZE-20)*1024 ; Offset from 20K base system
CCP     EQU     3400H+BIAS      ; CCP base address
BDOS    EQU     CCP+0800H       ; BDOS base (CCP + 2K)
BIOS    EQU     CCP+1600H       ; BIOS base (CCP + 5.5K)

; Page zero locations
IOBYTE  EQU     0003H           ; Intel I/O byte
CDISK   EQU     0004H           ; Current disk/user

; z80pack I/O ports (cpmsim)
CONSTA  EQU     00H             ; Console status port
CONDAT  EQU     01H             ; Console data port
PRTSTA  EQU     02H             ; Printer status port
PRTDAT  EQU     03H             ; Printer data port
AUXDAT  EQU     05H             ; Auxiliary data port

; z80pack disk I/O ports
FDCD    EQU     10H             ; FDC drive select
FDCT    EQU     11H             ; FDC track
FDCS    EQU     12H             ; FDC sector
FDCOP   EQU     13H             ; FDC command (0=read, 1=write)
FDCST   EQU     14H             ; FDC status
DPTS    EQU     15H             ; Selected disk type
DMAL    EQU     16H             ; DMA address low
DMAH    EQU     17H             ; DMA address high

; Disk parameters for 8" SSSD (IBM 3740)
NDISKS  EQU     4               ; Number of drives supported
NSECTS  EQU     26              ; Sectors per track
NTRKS   EQU     77              ; Tracks per disk

;-------------------------------------------------------------------------------
; BIOS Jump Table - 17 entry points, each 3 bytes (JMP instruction)
;-------------------------------------------------------------------------------

        ORG     BIOS

CBOOT:  JMP     BOOT            ; 00 - Cold boot
WBOOTE: JMP     WBOOT           ; 03 - Warm boot
        JMP     CONST           ; 06 - Console status
        JMP     CONIN           ; 09 - Console input
        JMP     CONOUT          ; 0C - Console output
        JMP     LIST            ; 0F - List (printer) output
        JMP     PUNCH           ; 12 - Punch output
        JMP     READER          ; 15 - Reader input
        JMP     HOME            ; 18 - Home disk head
        JMP     SELDSK          ; 1B - Select disk
        JMP     SETTRK          ; 1E - Set track
        JMP     SETSEC          ; 21 - Set sector
        JMP     SETDMA          ; 24 - Set DMA address
        JMP     READ            ; 27 - Read sector
        JMP     WRITE           ; 2A - Write sector
        JMP     LISTST          ; 2D - List status
        JMP     SECTRAN         ; 30 - Sector translate

;-------------------------------------------------------------------------------
; Signon Message
;-------------------------------------------------------------------------------

SIGNON: DB      0DH, 0AH
        DB      'CP/M 2.2 (Lolos)', 0DH, 0AH
        DB      '64K TPA', 0DH, 0AH
        DB      0DH, 0AH, 0

;-------------------------------------------------------------------------------
; BOOT - Cold boot initialization
;-------------------------------------------------------------------------------

BOOT:
        XRA     A               ; Zero accumulator
        STA     CDISK           ; Clear current disk (A:, user 0)
        STA     IOBYTE          ; Clear IOBYTE

        ; Print signon message
        LXI     H, SIGNON
BOOT1:  MOV     A, M
        ORA     A               ; Check for null terminator
        JZ      GOCPM
        MOV     C, A
        CALL    CONOUT
        INX     H
        JMP     BOOT1

GOCPM:
        MVI     A, 0C3H         ; JMP opcode
        STA     0000H           ; Warm boot vector
        LXI     H, WBOOTE
        SHLD    0001H           ; Address for warm boot

        STA     0005H           ; BDOS entry vector
        LXI     H, BDOS+6       ; BDOS entry point (after serial check)
        SHLD    0006H

        LXI     B, 0080H        ; Default DMA address
        CALL    SETDMA

        LDA     CDISK           ; Get current disk
        MOV     C, A
        JMP     CCP             ; Enter CCP

;-------------------------------------------------------------------------------
; WBOOT - Warm boot (reload CCP and BDOS)
;-------------------------------------------------------------------------------

WBOOT:
        LXI     SP, 0080H       ; Temporary stack in page zero

        ; For now, just reinitialize vectors and enter CCP
        ; Full implementation would reload CCP+BDOS from disk

        MVI     A, 0C3H         ; JMP opcode
        STA     0000H
        LXI     H, WBOOTE
        SHLD    0001H

        STA     0005H
        LXI     H, BDOS+6
        SHLD    0006H

        LXI     B, 0080H
        CALL    SETDMA

        LDA     CDISK
        MOV     C, A
        JMP     CCP

;-------------------------------------------------------------------------------
; Console I/O Functions
;-------------------------------------------------------------------------------

; CONST - Return console status
;   Returns: A = 00H if no character ready
;            A = FFH if character ready

CONST:
        IN      CONSTA          ; Read console status
        ANI     01H             ; Mask to bit 0
        RZ                      ; Return 0 if not ready
        MVI     A, 0FFH         ; Return FF if ready
        RET

; CONIN - Read character from console (wait for input)
;   Returns: A = character

CONIN:
        IN      CONSTA          ; Check status
        ANI     01H
        JZ      CONIN           ; Loop until ready
        IN      CONDAT          ; Read character
        ANI     7FH             ; Strip parity/high bit
        RET

; CONOUT - Write character to console
;   Input: C = character to output

CONOUT:
        MOV     A, C
        OUT     CONDAT          ; Output character
        RET

;-------------------------------------------------------------------------------
; Auxiliary I/O Functions
;-------------------------------------------------------------------------------

; LIST - Send character to printer
;   Input: C = character

LIST:
        MOV     A, C
        OUT     PRTDAT
        RET

; LISTST - Return printer status
;   Returns: A = 00H if not ready, FFH if ready

LISTST:
        IN      PRTSTA
        ANI     01H
        RZ
        MVI     A, 0FFH
        RET

; PUNCH - Send character to punch device
;   Input: C = character

PUNCH:
        MOV     A, C
        OUT     AUXDAT
        RET

; READER - Read character from reader device
;   Returns: A = character (or 1AH/EOF if not implemented)

READER:
        IN      AUXDAT
        ANI     7FH
        RET

;-------------------------------------------------------------------------------
; Disk I/O Functions
;-------------------------------------------------------------------------------

; HOME - Move to track 0

HOME:
        LXI     B, 0            ; Track 0
        ; Fall through to SETTRK

; SETTRK - Set track number
;   Input: BC = track number

SETTRK:
        MOV     A, C
        STA     SEKTRK          ; Save track
        RET

; SETSEC - Set sector number
;   Input: BC = sector number

SETSEC:
        MOV     A, C
        STA     SEKSEC          ; Save sector
        RET

; SETDMA - Set DMA address
;   Input: BC = DMA address

SETDMA:
        MOV     L, C
        MOV     H, B
        SHLD    DMAADR          ; Save DMA address
        RET

; SELDSK - Select disk drive
;   Input: C = disk number (0=A, 1=B, etc.)
;          E = 0 if first select (cold), 1 if logged in
;   Returns: HL = address of DPH, or 0000H if invalid

SELDSK:
        MOV     A, C
        STA     SEKDSK          ; Save selected disk

        CPI     NDISKS          ; Check if valid drive
        JNC     SELNO           ; Invalid if >= NDISKS

        ; Calculate DPH address: DPH0 + (drive * 16)
        LXI     H, 0
        MOV     L, A
        DAD     H               ; *2
        DAD     H               ; *4
        DAD     H               ; *8
        DAD     H               ; *16
        LXI     D, DPH0
        DAD     D
        RET

SELNO:
        LXI     H, 0            ; Return 0 for invalid
        RET

; SECTRAN - Translate logical to physical sector
;   Input: BC = logical sector
;          DE = translation table address (or 0)
;   Returns: HL = physical sector

SECTRAN:
        MOV     A, D            ; Check if table exists
        ORA     E
        JZ      NOTRAN          ; No translation if DE=0

        XCHG                    ; HL = table address
        DAD     B               ; Add sector offset
        MOV     L, M            ; Get translated sector
        MVI     H, 0
        RET

NOTRAN:
        MOV     H, B            ; HL = BC (no translation)
        MOV     L, C
        RET

; READ - Read one sector
;   Returns: A = 0 if success, 1 if error

READ:
        CALL    SETFDC          ; Set up FDC parameters
        XRA     A               ; Command 0 = read
        OUT     FDCOP
        IN      FDCST           ; Get status
        RET

; WRITE - Write one sector
;   Input: C = write type (0=normal, 1=directory, 2=first block)
;   Returns: A = 0 if success, 1 if error

WRITE:
        CALL    SETFDC          ; Set up FDC parameters
        MVI     A, 1            ; Command 1 = write
        OUT     FDCOP
        IN      FDCST           ; Get status
        RET

; SETFDC - Set up FDC with current parameters

SETFDC:
        LDA     SEKDSK          ; Drive
        OUT     FDCD
        LDA     SEKTRK          ; Track
        OUT     FDCT
        LDA     SEKSEC          ; Sector
        OUT     FDCS
        LHLD    DMAADR          ; DMA address
        MOV     A, L
        OUT     DMAL
        MOV     A, H
        OUT     DMAH
        RET

;-------------------------------------------------------------------------------
; Disk Parameter Tables
;-------------------------------------------------------------------------------

; Sector translation table for 8" SSSD (6-sector skew)
XLAT:   DB      1,7,13,19,25,5,11,17,23,3,9,15,21
        DB      2,8,14,20,26,6,12,18,24,4,10,16,22

; Disk Parameter Header (DPH) for drive A:
DPH0:   DW      XLAT            ; Sector translation table
        DW      0000H           ; Scratch area 1
        DW      0000H           ; Scratch area 2
        DW      0000H           ; Scratch area 3
        DW      DIRBUF          ; Directory buffer address
        DW      DPB0            ; Disk Parameter Block
        DW      CHK00           ; Checksum vector
        DW      ALL00           ; Allocation vector

; DPH for drive B:
DPH1:   DW      XLAT
        DW      0000H
        DW      0000H
        DW      0000H
        DW      DIRBUF
        DW      DPB0
        DW      CHK01
        DW      ALL01

; DPH for drive C:
DPH2:   DW      XLAT
        DW      0000H
        DW      0000H
        DW      0000H
        DW      DIRBUF
        DW      DPB0
        DW      CHK02
        DW      ALL02

; DPH for drive D:
DPH3:   DW      XLAT
        DW      0000H
        DW      0000H
        DW      0000H
        DW      DIRBUF
        DW      DPB0
        DW      CHK03
        DW      ALL03

; Disk Parameter Block for 8" SSSD (IBM 3740 format)
; 77 tracks, 26 sectors/track, 128 bytes/sector
; 2 reserved tracks, 1K blocks, 64 directory entries
DPB0:   DW      26              ; SPT - sectors per track
        DB      3               ; BSH - block shift factor (1K = 2^3 * 128)
        DB      7               ; BLM - block mask
        DB      0               ; EXM - extent mask
        DW      242             ; DSM - total blocks - 1
        DW      63              ; DRM - directory entries - 1
        DB      0C0H            ; AL0 - directory allocation bitmap
        DB      00H             ; AL1
        DW      16              ; CKS - checksum vector size (DRM+1)/4
        DW      2               ; OFF - reserved tracks

;-------------------------------------------------------------------------------
; Data Area
;-------------------------------------------------------------------------------

SEKDSK: DS      1               ; Seek disk number
SEKTRK: DS      1               ; Seek track number
SEKSEC: DS      1               ; Seek sector number
DMAADR: DS      2               ; DMA address

DIRBUF: DS      128             ; Directory buffer (shared)

; Checksum vectors (16 bytes each for 64 dir entries)
CHK00:  DS      16
CHK01:  DS      16
CHK02:  DS      16
CHK03:  DS      16

; Allocation vectors (31 bytes each for 243 blocks)
ALL00:  DS      31
ALL01:  DS      31
ALL02:  DS      31
ALL03:  DS      31

        END
