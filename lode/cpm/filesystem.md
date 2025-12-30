# CP/M Filesystem

## Overview

CP/M uses a flat directory structure with 32-byte directory entries. Files are allocated in blocks (1K for 8" SSSD). No subdirectories exist; user numbers (0-15) provide namespace separation.

## 8" SSSD Disk Geometry (IBM 3740)

| Parameter | Value |
|-----------|-------|
| Tracks | 77 |
| Sectors/track | 26 |
| Bytes/sector | 128 |
| Total capacity | 256,256 bytes |
| Reserved tracks | 2 (for boot loader, CCP, BDOS) |
| Block size | 1024 bytes (8 sectors) |
| Directory entries | 64 |
| Usable capacity | ~243K |

## Sector Skew Table

Physical sectors are interleaved for performance. Standard 8" skew:
```
1,7,13,19,25,5,11,17,23,3,9,15,21,2,8,14,20,26,6,12,18,24,4,10,16,22
```

## Directory Entry (32 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 1 | ST | Status/User (E5h=deleted, 0-15=user) |
| 1 | 8 | F1-F8 | Filename (space padded) |
| 9 | 3 | T1-T3 | Type/extension (high bits = attributes) |
| 12 | 1 | EX | Extent number (low 5 bits) |
| 13 | 1 | S1 | Reserved (extent high bits in CP/M 2.2) |
| 14 | 1 | S2 | Reserved (extent high bits) |
| 15 | 1 | RC | Record count in this extent (0-128) |
| 16 | 16 | D0-D15 | Block allocation (8-bit or 16-bit entries) |

## File Attributes (high bits of T1-T3)

| Byte | Bit 7 | Meaning |
|------|-------|---------|
| T1 | 1 | Read-only |
| T2 | 1 | System (hidden from DIR) |
| T3 | 1 | Archive |

## File Control Block (FCB) - 36 bytes

```
       0    1        9       12  13  14  15  16       32  33  34  35
      +----+--------+-------+---+---+---+---+---------+---+---+---+
      | DR | F1..F8 | T1-T3 | EX| S1| S2| RC| D0..D15 |CR |R0 |R1 |R2|
      +----+--------+-------+---+---+---+---+---------+---+---+---+
```

| Field | Description |
|-------|-------------|
| DR | Drive (0=default, 1=A, 2=B, ...) |
| F1-F8 | Filename, uppercase, space-padded |
| T1-T3 | Extension, uppercase, space-padded |
| EX | Current extent |
| S1,S2 | Reserved |
| RC | Record count |
| D0-D15 | Filled by BDOS |
| CR | Current record (sequential I/O) |
| R0-R2 | Random record number (24-bit) |

## Wildcards

- `?` matches any single character
- `*` expands to `????????` or `???`

Example: `*.COM` becomes `????????COM`

## Block Allocation

For DSM < 256: Single-byte block numbers (D0-D15 = 16 blocks max)
For DSM >= 256: Two-byte block numbers (D0-D15 = 8 blocks max)

8" SSSD has DSM=242, so uses 8-bit allocation.

## Related
- [bdos.md](bdos.md) - File operation functions
- [bios.md](bios.md) - Disk Parameter Block
