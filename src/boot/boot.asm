;===============================================================================
; CP/M Boot Loader - Minimal version (must fit in 128 bytes)
; Loaded at track 0, sector 1 by z80pack
;===============================================================================

MSIZE   EQU     64
BIAS    EQU     (MSIZE-20)*1024
CCP     EQU     3400H+BIAS
BIOS    EQU     CCP+1600H

NSECTS  EQU     48              ; Sectors to load

; z80pack I/O ports
FDCD    EQU     10H
FDCT    EQU     11H
FDCS    EQU     12H
FDCOP   EQU     13H
FDCST   EQU     14H
DMAL    EQU     16H
DMAH    EQU     17H

        ORG     0000H

BOOT:
        DI
        LXI     SP, 0080H

        ; Select drive A, track 0
        XRA     A
        OUT     FDCD
        OUT     FDCT

        MVI     C, 2            ; Current sector
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

ERR:    HLT
        JMP     ERR

        END
