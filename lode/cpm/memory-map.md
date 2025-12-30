# CP/M 2.2 Memory Map (64K System)

## Overview

```
FFFFh ┌─────────────────────────┐
      │        (unused)        │
FBACh ├─────────────────────────┤
      │        BIOS            │  ~428 bytes - Hardware abstraction
FA00h ├─────────────────────────┤
      │        BDOS            │  ~2.4K - System calls
EC00h ├─────────────────────────┤
      │        CCP             │  ~2K   - Command processor
E400h ├─────────────────────────┤
      │                        │
      │        TPA             │  ~57K  - Transient Program Area
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

For a 64K system (MSIZE=64):
```
BIAS = (MSIZE - 20) * 1024 = 44 * 1024 = B000h
CCP  = 3400h + BIAS = E400h
BDOS = CCP + 0800h  = EC00h
BIOS = CCP + 1600h  = FA00h
Top of TPA = CCP - 1 = E3FFh
```

The base addresses (3400h, 0800h offset, 1600h offset) are fixed CP/M 2.2 constants.

## Related
- [bios.md](bios.md) - BIOS implementation
- [bdos.md](bdos.md) - BDOS functions
