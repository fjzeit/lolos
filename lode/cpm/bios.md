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
| 1Bh | SELDSK | Select disk (C=drive) - return HL=DPH or 0000h |
| 1Eh | SETTRK | Set track number (BC=track) |
| 21h | SETSEC | Set sector number (BC=sector) |
| 24h | SETDMA | Set DMA address (BC=address) |
| 27h | READ | Read sector - return A=0 success, 1 error |
| 2Ah | WRITE | Write sector (C=type) - return A=0 success, 1 error |
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
| Port | Purpose |
|------|---------|
| 10h | Drive select (0-3) |
| 11h | Track number |
| 12h | Sector number |
| 13h | Command: 0=read, 1=write |
| 14h | Status: 0=OK, nonzero=error |
| 15h | Disk type select |
| 16h | DMA address low byte |
| 17h | DMA address high byte |

**IMPORTANT**: These ports are based on z80pack cpmsim defaults. If boot fails, verify ports against your z80pack version's `iosim.c` source.

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

## Related
- [memory-map.md](memory-map.md) - System memory layout
- [filesystem.md](filesystem.md) - Directory and file structures
