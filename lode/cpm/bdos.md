# BDOS - Basic Disk Operating System

## Overview

The BDOS provides system calls accessed via `CALL 0005h` with:
- C = function number
- DE = parameter (if needed)
- Returns in A and/or HL

## CP/M 2.2 Function List

### Console I/O (0-11)
| Fn | Name | Input | Output | Description |
|----|------|-------|--------|-------------|
| 0 | P_TERMCPM | - | - | System reset (warm boot) |
| 1 | C_READ | - | A=char | Console input with echo |
| 2 | C_WRITE | E=char | - | Console output |
| 3 | A_READ | - | A=char | Auxiliary input |
| 4 | A_WRITE | E=char | - | Auxiliary output |
| 5 | L_WRITE | E=char | - | Printer output |
| 6 | C_RAWIO | E=FFh/FEh/FDh/char | A=char/status | Direct console I/O |
| 7 | A_STATIN | - | A=status | Get IOBYTE |
| 8 | A_STATOUT | - | - | Set IOBYTE |
| 9 | C_WRITESTR | DE=addr | - | Print string ($ terminated) |
| 10 | C_READSTR | DE=buffer | - | Buffered console input |
| 11 | C_STAT | - | A=00/FF | Console status |

### Disk/File Operations (12-40)
| Fn | Name | Input | Output | Description |
|----|------|-------|--------|-------------|
| 12 | S_BDOSVER | - | HL=0022h | Return version (2.2) |
| 13 | DRV_ALLRESET | - | - | Reset disk system |
| 14 | DRV_SET | E=drive | A=0 | Select disk (0=A:) |
| 15 | F_OPEN | DE=FCB | A=dir code | Open file |
| 16 | F_CLOSE | DE=FCB | A=dir code | Close file |
| 17 | F_SFIRST | DE=FCB | A=dir code | Search first |
| 18 | F_SNEXT | - | A=dir code | Search next |
| 19 | F_DELETE | DE=FCB | A=dir code | Delete file |
| 20 | F_READ | DE=FCB | A=0/1 | Read sequential |
| 21 | F_WRITE | DE=FCB | A=0/1/2 | Write sequential |
| 22 | F_MAKE | DE=FCB | A=dir code | Create file |
| 23 | F_RENAME | DE=FCB | A=dir code | Rename file |
| 24 | DRV_LOGINVEC | - | HL=bitmap | Get login vector |
| 25 | DRV_GET | - | A=drive | Get current disk |
| 26 | F_DMAOFF | DE=addr | - | Set DMA address |
| 27 | DRV_ALLOCVEC | - | HL=addr | Get allocation vector |
| 28 | DRV_SETRO | - | - | Set disk read-only |
| 29 | DRV_ROVEC | - | HL=bitmap | Get R/O vector |
| 30 | F_ATTRIB | DE=FCB | A=dir code | Set file attributes |
| 31 | DRV_DPB | - | HL=addr | Get DPB address |
| 32 | F_USERNUM | E=user/FFh | A=user | Get/set user number |
| 33 | F_READRAND | DE=FCB | A=0/1/6 | Read random |
| 34 | F_WRITERAND | DE=FCB | A=0/2/6 | Write random |
| 35 | F_SIZE | DE=FCB | - | Compute file size |
| 36 | F_RANDREC | DE=FCB | - | Set random record |
| 37 | DRV_RESET | DE=bitmap | - | Reset specific drives |
| 40 | F_WRITEZF | DE=FCB | A=0/2/6 | Write random zero fill |

## Directory Code Returns

- 00h-03h: Success (index into directory buffer)
- FFh (255): Error / not found

## Sequential/Random I/O Error Codes

| Code | Meaning | Functions |
|------|---------|-----------|
| 0 | Success | F20, F21, F33, F34, F40 |
| 1 | Unwritten record or I/O error | F20, F21, F33 |
| 2 | Disk full (no free blocks) | F21, F34, F40 |
| 6 | Seek past end of disk (R2 > 0) | F33, F34, F40 |

## Implementation Notes

### SEARCH Function
The SEARCH function maintains state in `SEARCHI` (next entry to search from) to support multi-call operations like FUNC17+FUNC18.

**Critical invariant**: Any function that starts a new search must reset `SEARCHI` to 0:
- FUNC15 (Open) - must reset SEARCHI
- FUNC16 (Close) - must reset SEARCHI
- FUNC17 (Search First) - resets SEARCHI, then falls through to FUNC18
- FUNC18 (Search Next) - continues from SEARCHI (no reset)
- FUNC19 (Delete) - resets SEARCHI for loop
- FUNC23 (Rename) - resets SEARCHI for loop
- FUNC30 (Set Attributes) - must reset SEARCHI
- RNDREC (Random access) - must reset SEARCHI before extent search

### DIRPTR Variable
When SEARCH finds a match, it must save the directory entry pointer to `DIRPTR` using `SHLD DIRPTR`. FUNC15 (Open) and FUNC16 (Close) use DIRPTR to copy data between the FCB and directory entry.

### Register Preservation Contract
BDOS may corrupt HL (used for return values) but callers expect BC/DE to be preserved. Internal utilities like OUTCHR and BDOSCL should preserve HL/BC for caller convenience.

### WRITEREC Block Handling
When WRITEREC needs to allocate a new block:
1. GETBLOCK returns HL=0 (no block)
2. ALLOCBLK returns HL=new block number
3. PUTBLOCK stores block in FCB but **destroys HL**
4. Must preserve HL before PUTBLOCK: `PUSH H / CALL PUTBLOCK / POP H`
5. Then BLKTOSEC uses correct block number

### ALV Initialization
The Allocation Vector (ALV) must be initialized on first drive login:
- SELDRIVE checks LOGINV to see if drive already logged in
- If not, calls INITALV before setting login bit
- INITALV clears ALV, sets AL0/AL1 bits, then scans directory to mark used blocks

### Multi-Extent File Handling

Files larger than 16K (128 records) span multiple **extents**. Each extent is a separate directory entry with:
- Same filename (bytes 1-11)
- Different extent number (byte 12, masked to 5 bits for 0-31)
- Own allocation map (bytes 16-31)
- Own record count RC (byte 15)

**FUNC15 (Open)**: Must search for entry matching both filename AND extent number:
```
F15LP:  CALL    SEARCH          ; Find filename match
        CPI     0FFH
        JZ      F15NF           ; Not found
        ; Check if extent matches
        LHLD    DIRPTR
        LXI     D, 12
        DAD     D
        MOV     A, M            ; Directory extent
        ANI     1FH             ; Mask extent bits
        MOV     B, A
        LDA     OPENEXT         ; Requested extent
        ANI     1FH
        CMP     B
        JNZ     F15LP           ; Wrong extent, keep searching
```

**FUNC16 (Close)**: Same pattern - must find matching extent to update RC and allocation map.

**FUNC20 (Read Sequential)**: When CR reaches 128 after a read:
1. Reset CR to 0
2. Increment extent number in FCB
3. Call F20OPN to search directory for next extent
4. Copy allocation map from directory to FCB
5. If extent not found, return EOF (A=1)

**FUNC21 (Write Sequential)**: When CR reaches 128 after a write:
1. Close current extent (F21CLS) - updates RC, writes directory
2. Increment extent number in FCB
3. Reset CR, RC to 0
4. Clear allocation map (16 bytes)
5. Create new directory entry (F21MKE) for the new extent

### Random Access (F33, F34)

Random read/write uses RNDREC to convert the 24-bit random record number (FCB+33,34,35) to extent and CR:

1. **CR (Current Record)** = R0 AND 7Fh (low 7 bits)
2. **Extent** = (R1:R0) / 128 = (R1 << 1) | (R0 >> 7)

**RNDREC Implementation**: The extent calculation extracts bits 14:7 of the 16-bit record number:
```asm
; extent = (R1 << 1) | (R0 >> 7)
MOV     A, E            ; A = R0
RLC                     ; Bit 7 of R0 → carry
MOV     A, D            ; A = R1
RAL                     ; (R1 << 1) | carry = extent
ANI     1FH             ; Mask to 5 bits (extents 0-31)
```

**Pitfall**: Do NOT use multiple RRC/RAR iterations to divide by 128. RRC is a **circular rotate** (bit 0 → bit 7 AND carry), not a logical shift. This produces incorrect results.

RNDREC sets FCB+12 (extent) and FCB+32 (CR), then the caller:
- **FUNC33** loads CR and calls READREC
- **FUNC34** loads CR and calls WRITEREC

**Important**: After calling RNDREC, the record number is in FCB+32, NOT in A. READREC/WRITEREC expect the record in A:
```asm
LHLD    CURFCB
LXI     D, 32
DAD     D
MOV     A, M            ; A = CR from FCB+32
CALL    READREC         ; or WRITEREC
```

## Related
- [filesystem.md](filesystem.md) - FCB structure and directory format
- [bios.md](bios.md) - Low-level I/O calls
