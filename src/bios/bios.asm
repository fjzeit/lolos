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

; z80pack disk I/O ports (decimal values per simio.c)
FDCD    EQU     10              ; FDC drive select
FDCT    EQU     11              ; FDC track
FDCS    EQU     12              ; FDC sector
FDCOP   EQU     13              ; FDC command (0=read, 1=write)
FDCST   EQU     14              ; FDC status
DMAL    EQU     15              ; DMA address low
DMAH    EQU     16              ; DMA address high

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
        DB      'LOLOS Version 1.00', 0DH, 0AH
        DB      'Copyright (c) 2025-2026 FJ Zeit. All rights reserved.', 0DH, 0AH
        DB      'https://github.com/fjzeit/lolos', 0DH, 0AH
        DB      'CP/M 2.2 Compatible', 0DH, 0AH
        DB      0DH, 0AH, 0

;-------------------------------------------------------------------------------
; BOOT - Cold boot initialization
;-------------------------------------------------------------------------------
; Description:
;   Performs initial system startup. Clears page zero state (CDISK, IOBYTE),
;   displays signon message, initializes warm boot and BDOS entry vectors
;   at addresses 0000H and 0005H, then transfers control to CCP.
;
; Input:
;   (none)  - [---] Called by boot loader after system load
;
; Output:
;   (0000H) - JMP WBOOT vector installed
;   (0005H) - JMP BDOS+6 vector installed
;   CDISK   - Cleared to 0 (drive A:, user 0)
;   IOBYTE  - Cleared to 0
;
; Clobbers:
;   All registers
;
; Notes:
;   - Does not return; transfers to CCP
;   - Sets default DMA to 0080H
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
; Description:
;   Reinitializes the system after a transient program terminates. Sets up
;   stack, reinstalls page zero vectors for warm boot (0000H) and BDOS
;   (0005H), then transfers control to CCP with current disk selection.
;
; Input:
;   (none)  - [---] Called via JMP 0000H
;
; Output:
;   (0000H) - JMP WBOOT vector installed
;   (0005H) - JMP BDOS+6 vector installed
;   SP      - Set to 0080H
;
; Clobbers:
;   All registers
;
; Notes:
;   - Does not return; transfers to CCP
;   - Preserves current disk from CDISK
;   - Sets default DMA to 0080H
;   - Full CP/M would reload CCP+BDOS from disk; this version skips reload
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

;-------------------------------------------------------------------------------
; CONST - Return console status
;-------------------------------------------------------------------------------
; Description:
;   Checks if a character is available from the console input device.
;   Non-blocking status check.
;
; Input:
;   (none)  - [---]
;
; Output:
;   A       - 00H if no character ready, FFH if character ready
;
; Clobbers:
;   Flags
;-------------------------------------------------------------------------------

CONST:
        IN      CONSTA          ; Read console status
        ANI     01H             ; Mask to bit 0
        RZ                      ; Return 0 if not ready
        MVI     A, 0FFH         ; Return FF if ready
        RET

;-------------------------------------------------------------------------------
; CONIN - Read character from console
;-------------------------------------------------------------------------------
; Description:
;   Waits for and reads a character from the console input device.
;   Blocks until a character is available. Strips high bit (parity).
;   Converts DEL (7FH) to backspace (08H) for editing compatibility.
;
; Input:
;   (none)  - [---]
;
; Output:
;   A       - ASCII character (00H-7EH, or 08H for DEL)
;
; Clobbers:
;   Flags
;-------------------------------------------------------------------------------

CONIN:
        IN      CONSTA          ; Check status
        ANI     01H
        JZ      CONIN           ; Loop until ready
        IN      CONDAT          ; Read character
        ANI     7FH             ; Strip parity/high bit
        CPI     7FH             ; DEL?
        RNZ                     ; No, return as-is
        MVI     A, 08H          ; Convert DEL to BS
        RET

;-------------------------------------------------------------------------------
; CONOUT - Write character to console
;-------------------------------------------------------------------------------
; Description:
;   Outputs a single character to the console display device.
;
; Input:
;   C       - [REQ] ASCII character to output
;
; Output:
;   (none)
;
; Clobbers:
;   A
;-------------------------------------------------------------------------------

CONOUT:
        MOV     A, C
        OUT     CONDAT          ; Output character
        RET

;-------------------------------------------------------------------------------
; Auxiliary I/O Functions
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; LIST - Send character to printer
;-------------------------------------------------------------------------------
; Description:
;   Outputs a character to the list (printer) device.
;
; Input:
;   C       - [REQ] ASCII character to output
;
; Output:
;   (none)
;
; Clobbers:
;   A
;-------------------------------------------------------------------------------

LIST:
        MOV     A, C
        OUT     PRTDAT
        RET

;-------------------------------------------------------------------------------
; LISTST - Return printer status
;-------------------------------------------------------------------------------
; Description:
;   Checks if the list (printer) device is ready to accept a character.
;
; Input:
;   (none)  - [---]
;
; Output:
;   A       - 00H if not ready, FFH if ready
;
; Clobbers:
;   Flags
;-------------------------------------------------------------------------------

LISTST:
        IN      PRTSTA
        ANI     01H
        RZ
        MVI     A, 0FFH
        RET

;-------------------------------------------------------------------------------
; PUNCH - Send character to punch device
;-------------------------------------------------------------------------------
; Description:
;   Outputs a character to the punch (auxiliary output) device.
;
; Input:
;   C       - [REQ] ASCII character to output
;
; Output:
;   (none)
;
; Clobbers:
;   A
;-------------------------------------------------------------------------------

PUNCH:
        MOV     A, C
        OUT     AUXDAT
        RET

;-------------------------------------------------------------------------------
; READER - Read character from reader device
;-------------------------------------------------------------------------------
; Description:
;   Reads a character from the reader (auxiliary input) device.
;   Strips high bit (parity).
;
; Input:
;   (none)  - [---]
;
; Output:
;   A       - ASCII character (00H-7FH)
;
; Clobbers:
;   Flags
;
; Notes:
;   - Returns 1AH (EOF) if device not available
;-------------------------------------------------------------------------------

READER:
        IN      AUXDAT
        ANI     7FH
        RET

;-------------------------------------------------------------------------------
; Disk I/O Functions
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; HOME - Move disk head to track 0
;-------------------------------------------------------------------------------
; Description:
;   Positions the disk head to track 0 of the currently selected drive.
;   Equivalent to SETTRK with BC=0. Falls through to SETTRK.
;
; Input:
;   (none)  - [---]
;
; Output:
;   SEKTRK  - Set to 0
;
; Clobbers:
;   A, BC
;-------------------------------------------------------------------------------

HOME:
        LXI     B, 0            ; Track 0
        ; Fall through to SETTRK

;-------------------------------------------------------------------------------
; SETTRK - Set track number for next disk operation
;-------------------------------------------------------------------------------
; Description:
;   Stores the track number for subsequent READ or WRITE operations.
;   Track is used from low byte (C) only.
;
; Input:
;   BC      - [REQ] Track number (0 to NTRKS-1, C register used)
;
; Output:
;   SEKTRK  - Updated with track number
;
; Clobbers:
;   A
;-------------------------------------------------------------------------------

SETTRK:
        MOV     A, C
        STA     SEKTRK          ; Save track
        RET

;-------------------------------------------------------------------------------
; SETSEC - Set sector number for next disk operation
;-------------------------------------------------------------------------------
; Description:
;   Stores the physical sector number for subsequent READ or WRITE
;   operations. Sector is used from low byte (C) only.
;
; Input:
;   BC      - [REQ] Sector number (1 to NSECTS, C register used)
;
; Output:
;   SEKSEC  - Updated with sector number
;
; Clobbers:
;   A
;-------------------------------------------------------------------------------

SETSEC:
        MOV     A, C
        STA     SEKSEC          ; Save sector
        RET

;-------------------------------------------------------------------------------
; SETDMA - Set DMA address for disk operations
;-------------------------------------------------------------------------------
; Description:
;   Sets the memory address for subsequent disk READ or WRITE operations.
;   The 128-byte sector will be read to or written from this address.
;
; Input:
;   BC      - [REQ] DMA buffer address
;
; Output:
;   DMAADR  - Updated with buffer address
;
; Clobbers:
;   HL
;-------------------------------------------------------------------------------

SETDMA:
        MOV     L, C
        MOV     H, B
        SHLD    DMAADR          ; Save DMA address
        RET

;-------------------------------------------------------------------------------
; SELDSK - Select disk drive
;-------------------------------------------------------------------------------
; Description:
;   Selects a disk drive and returns the address of its Disk Parameter
;   Header (DPH). The DPH contains pointers to the translation table,
;   directory buffer, DPB, checksum vector, and allocation vector.
;
; Input:
;   C       - [REQ] Disk number (0=A, 1=B, 2=C, 3=D)
;   E       - [OPT] 0=first select (cold), non-0=already logged in
;
; Output:
;   HL      - DPH address if valid (0-3), 0000H if invalid drive
;   SEKDSK  - Updated with selected disk number
;
; Clobbers:
;   A, DE, flags
;
; Notes:
;   - Supports NDISKS (4) drives: A: through D:
;   - DPH is 16 bytes per drive
;-------------------------------------------------------------------------------

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

;-------------------------------------------------------------------------------
; SECTRAN - Translate logical to physical sector
;-------------------------------------------------------------------------------
; Description:
;   Converts a logical sector number to a physical sector number using
;   the disk's sector translation table (skew table). If no translation
;   table is provided (DE=0), returns the logical sector unchanged.
;
; Input:
;   BC      - [REQ] Logical sector number (0 to NSECTS-1)
;   DE      - [OPT] Translation table address, or 0000H for no translation
;
; Output:
;   HL      - Physical sector number
;
; Clobbers:
;   A, DE, flags
;
; Notes:
;   - Translation table is indexed by logical sector
;   - 8" SSSD uses 6-sector skew for optimal rotational latency
;-------------------------------------------------------------------------------

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

;-------------------------------------------------------------------------------
; READ - Read one 128-byte sector from disk
;-------------------------------------------------------------------------------
; Description:
;   Reads a sector from the currently selected disk at the track and
;   sector set by SETTRK and SETSEC, into the buffer at the DMA address.
;
; Input:
;   (implicit) - SEKDSK, SEKTRK, SEKSEC, DMAADR must be set
;
; Output:
;   A       - 0 on success, non-0 on error
;   (DMAADR)- 128 bytes of sector data on success
;
; Clobbers:
;   HL, flags
;-------------------------------------------------------------------------------

READ:
        CALL    SETFDC          ; Set up FDC parameters
        XRA     A               ; Command 0 = read
        OUT     FDCOP
        IN      FDCST           ; Get status
        RET

;-------------------------------------------------------------------------------
; WRITE - Write one 128-byte sector to disk
;-------------------------------------------------------------------------------
; Description:
;   Writes a sector to the currently selected disk at the track and
;   sector set by SETTRK and SETSEC, from the buffer at the DMA address.
;
; Input:
;   C       - [OPT] Write type: 0=normal, 1=directory, 2=first block of file
;   (implicit) - SEKDSK, SEKTRK, SEKSEC, DMAADR must be set
;
; Output:
;   A       - 0 on success, non-0 on error
;
; Clobbers:
;   HL
;
; Notes:
;   - Write type used by BDOS for write optimization (not used here)
;-------------------------------------------------------------------------------

WRITE:
        CALL    SETFDC          ; Set up FDC parameters
        MVI     A, 1            ; Command 1 = write
        OUT     FDCOP
        IN      FDCST           ; Get status
        RET

;-------------------------------------------------------------------------------
; SETFDC - Configure FDC for disk operation (internal)
;-------------------------------------------------------------------------------
; Description:
;   Programs the z80pack FDC with disk, track, sector, and DMA address
;   from the saved state variables. Called by READ and WRITE.
;
; Input:
;   (implicit) - SEKDSK, SEKTRK, SEKSEC, DMAADR
;
; Output:
;   (FDC ports) - FDCD, FDCT, FDCS, DMAL, DMAH programmed
;
; Clobbers:
;   A, HL
;-------------------------------------------------------------------------------

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
