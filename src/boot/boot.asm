;===============================================================================
; CP/M Boot Loader
;===============================================================================
;
; Description:
;   Minimal boot loader for CP/M 2.2 on z80pack simulator. Loaded by the
;   simulator at address 0000H from track 0, sector 1. Loads CCP, BDOS,
;   and BIOS from disk into high memory, then transfers control to BIOS
;   cold boot entry point.
;
; Constraints:
;   - Must fit in 128 bytes (single 8" floppy sector)
;   - No subroutine calls (saves stack space and bytes)
;
; Memory Map:
;   0000H-007FH : This boot loader during load
;   0080H       : Stack pointer during load
;   CCP         : Destination for system load (MSIZE-dependent)
;   BIOS        : Cold boot entry point (CCP + 1600H)
;
; Disk Layout (8" SSSD, 26 sectors/track):
;   Track 0, Sector 1  : This boot loader
;   Track 0, Sector 2+ : CCP, BDOS, BIOS image (continues to Track 1)
;
; Load Sequence:
;   1. Initialize stack and select drive A, track 0
;   2. Loop: Set DMA, set sector, read, advance address
;   3. Wrap sector 26->1 and increment track
;   4. After NSECTS sectors, jump to BIOS cold boot
;
;===============================================================================

MSIZE   EQU     64
BIAS    EQU     (MSIZE-20)*1024
CCP     EQU     3400H+BIAS
BIOS    EQU     CCP+1600H

NSECTS  EQU     48              ; Sectors to load

; z80pack I/O ports (decimal values)
FDCD    EQU     10              ; FDC drive select
FDCT    EQU     11              ; FDC track
FDCS    EQU     12              ; FDC sector (low)
FDCOP   EQU     13              ; FDC command
FDCST   EQU     14              ; FDC status
DMAL    EQU     15              ; DMA address low
DMAH    EQU     16              ; DMA address high

        ORG     0000H

;-------------------------------------------------------------------------------
; BOOT - Main entry point (called by simulator at power-on)
;-------------------------------------------------------------------------------
; Registers used during load:
;   B  = Sectors remaining
;   C  = Current sector number (1-26)
;   D  = Current track number
;   HL = Current DMA (load) address
;-------------------------------------------------------------------------------

BOOT:
        DI
        LXI     SP, 0080H

        ; Select drive A, track 0
        XRA     A
        OUT     FDCD
        OUT     FDCT

        MVI     C, 2            ; Current sector
        MVI     D, 0            ; Current track (must initialize!)
        LXI     H, CCP          ; Load address
        MVI     B, NSECTS       ; Sector count

LDLP:
        ; Set DMA
        MOV     A, L
        OUT     DMAL
        MOV     A, H
        OUT     DMAH

        ; Set sector and read
        MOV     A, C
        OUT     FDCS
        XRA     A
        OUT     FDCOP
        IN      FDCST
        ORA     A
        JNZ     ERR

        ; Advance address
        PUSH    D
        LXI     D, 128
        DAD     D
        POP     D

        ; Advance sector
        INR     C
        MOV     A, C
        CPI     27
        JC      NOSEC
        MVI     C, 1            ; Wrap to sector 1
        ; Next track
        INR     D
        MOV     A, D
        OUT     FDCT
NOSEC:
        DCR     B
        JNZ     LDLP

        JMP     BIOS            ; Cold boot

; ERR - Halt on disk error (never returns)
ERR:    HLT
        JMP     ERR

        END
