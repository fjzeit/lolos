# BIOS - Basic Input/Output System

## Overview

The BIOS provides hardware abstraction through a 17-entry jump table. This implementation targets z80pack's simulated hardware.

## Jump Table (CP/M 2.2)

| Offset | Name | Description |
|--------|------|-------------|
| 00h | BOOT | Cold start - initialize system |
| 03h | WBOOT | Warm start - reload CCP, enter command loop |
| 06h | CONST | Console status - return FFh if char ready, 00h if not |
| 09h | CONIN | Console input - wait and return char in A |
| 0Ch | CONOUT | Console output - print char in C |
| 0Fh | LIST | Printer output - print char in C |
| 12h | PUNCH | Paper tape punch - output char in C |
| 15h | READER | Paper tape reader - return char in A |
| 18h | HOME | Move disk head to track 0 |
| 1Bh | SELDSK | Select disk (C=drive, E=login) - return HL=DPH or 0000h |
| 1Eh | SETTRK | Set track number (BC=track) |
| 21h | SETSEC | Set sector number (BC=sector) |
| 24h | SETDMA | Set DMA address (BC=address) |
| 27h | READ | Read sector - return A=0 success, 1 error |
| 2Ah | WRITE | Write sector (C=type: 0=normal, 1=dir, 2=first) - return A=0/1 |
| 2Dh | LISTST | Printer status - return FFh if ready |
| 30h | SECTRAN | Translate sector (BC=logical, DE=table) - return HL=physical |

## z80pack I/O Ports (as implemented)

### Console
| Port | Read | Write |
|------|------|-------|
| 00h | Status (bit 0 = char ready) | - |
| 01h | Character in | Character out |

### Printer
| Port | Read | Write |
|------|------|-------|
| 02h | Status | - |
| 03h | - | Character out |

### Auxiliary (Punch/Reader)
| Port | Read | Write |
|------|------|-------|
| 05h | Character in | Character out |

### Disk FDC
| Port (decimal) | Hex | Purpose |
|----------------|-----|---------|
| 10 | 0Ah | Drive select (0-3) |
| 11 | 0Bh | Track number |
| 12 | 0Ch | Sector number (low byte) |
| 13 | 0Dh | Command: 0=read, 1=write |
| 14 | 0Eh | Status: 0=OK, nonzero=error |
| 15 | 0Fh | DMA address low byte |
| 16 | 10h | DMA address high byte |

**CRITICAL**: z80pack uses DECIMAL port numbers in source (simio.c line 300+). The hex equivalents above are for reference. Do NOT use `10H` in assembly - it means 16 decimal!

## Disk Parameter Header (DPH)

```
DPH:    DW  XLT         ; Sector translation table (or 0000h)
        DW  0000h       ; Scratch 1
        DW  0000h       ; Scratch 2
        DW  0000h       ; Scratch 3
        DW  DIRBUF      ; 128-byte directory buffer
        DW  DPB         ; Disk Parameter Block
        DW  CSV         ; Checksum vector
        DW  ALV         ; Allocation vector
```

## Disk Parameter Block (DPB) - 8" SSSD

```
DPB:    DW  26          ; SPT - sectors per track
        DB  3           ; BSH - block shift (1K blocks)
        DB  7           ; BLM - block mask
        DB  0           ; EXM - extent mask
        DW  242         ; DSM - total blocks - 1
        DW  63          ; DRM - directory entries - 1
        DB  0C0h        ; AL0 - allocation bitmap
        DB  00h         ; AL1
        DW  16          ; CKS - checksum vector size
        DW  2           ; OFF - reserved tracks
```

## Terminal Compatibility

Modern terminals send DEL (7Fh) for backspace, but CP/M programs handle DEL and BS differently:
- DEL (7Fh) → "rubout" with backslash echo (teletype style)
- BS (08h) → visual backspace

CONIN converts DEL to BS so programs like MBASIC do visual backspace:
```asm
CONIN:
        ...
        CPI     7FH             ; DEL?
        RNZ
        MVI     A, 08H          ; Convert DEL to BS
        RET
```

## Related
- [memory-map.md](memory-map.md) - System memory layout
- [filesystem.md](filesystem.md) - Directory and file structures
