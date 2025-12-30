# CP/M 2.2 Memory Map (64K System)

## Overview

```
FFFFh ┌─────────────────────────┐
      │        BIOS            │  ~2.5K - Hardware abstraction
F200h ├─────────────────────────┤
      │        BDOS            │  ~3.5K - System calls
E400h ├─────────────────────────┤
      │        CCP             │  ~2K   - Command processor
DC00h ├─────────────────────────┤
      │                        │
      │        TPA             │  ~55K  - Transient Program Area
      │   (User Programs)      │
      │                        │
0100h ├─────────────────────────┤
      │     Page Zero          │  256 bytes - System vectors & data
0000h └─────────────────────────┘
```

## Page Zero Layout (0000h-00FFh)

| Address | Size | Purpose |
|---------|------|---------|
| 0000h | 3 | Warm boot vector: `JMP BIOS+3` |
| 0003h | 1 | IOBYTE - Intel standard I/O byte |
| 0004h | 1 | Current drive/user: (user << 4) | drive |
| 0005h | 3 | BDOS entry vector: `JMP BDOS` |
| 0008h-003Fh | 56 | RST vectors (available for user) |
| 0040h-005Bh | 28 | Reserved |
| 005Ch | 36 | Default FCB (parsed from command line) |
| 006Ch | 36 | Second FCB (overlaps first at 16 bytes in) |
| 0080h | 128 | Default DMA buffer / command tail |

## Key Entry Points

- **0000h**: Warm boot - reload CCP, restart command processor
- **0005h**: BDOS entry - system calls (function in C, parameter in DE)
- **BIOS base**: 17-entry jump table for hardware operations

## Address Calculation

For a 64K system with BIOS at F200h:
- BIOS = F200h (must be page-aligned for some implementations)
- BDOS = BIOS - 0E00h = E400h
- CCP = BDOS - 0800h = DC00h
- Top of TPA = CCP - 1 = DBFFh

## Related
- [bios.md](bios.md) - BIOS implementation
- [bdos.md](bdos.md) - BDOS functions
