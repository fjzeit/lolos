# Testing Complete - Session Summary

## Status: WORKING
CP/M 2.2 (Lolos) boots and runs on z80pack (cpmsim) on Linux.

## What Works
- Cold boot from disk image
- Signon message displays
- `A>` prompt appears
- Command input with echo
- Backspace editing
- Built-in commands (DIR, ERA, REN, TYPE, SAVE, USER)
- Drive selection (A:, B:, etc.)

## Bugs Fixed During Testing

### 1. I/O Port Numbers (boot.asm, bios.asm)
**Problem**: Ports defined as `10H` (16 decimal) instead of `10` (10 decimal)
**Fix**: Changed all FDC ports to decimal values per z80pack simio.c

### 2. Uninitialized Track Register (boot.asm)
**Problem**: D register used for track counter but never initialized to 0
**Fix**: Added `MVI D, 0` before load loop

### 3. Console Buffer Input (bdos.asm, Function 10)
**Problem**: Input character not saved before comparisons, never stored in buffer
**Fix**: Save char in E register immediately, store and echo after validation

### 4. CCP Character Output (ccp.asm)
**Problem**: OUTCHR clobbered character in C before saving it
**Fix**: `MOV E, C` before `MVI C, B_CONOUT`

### 5. Missing Newline Before Prompt (ccp.asm)
**Problem**: "No FileA>" appeared without line break
**Fix**: Added `CALL CRLF` at start of main loop

## Current Component Sizes
| Component | Size |
|-----------|------|
| Boot loader | 66 bytes |
| CCP | 1345 bytes |
| BDOS | 2358 bytes |
| BIOS | 428 bytes |

## Next Development Steps
1. Add .COM programs to disk using cpmtools
2. Write test programs to verify file I/O
3. Fix warm boot to reload CCP/BDOS from disk
4. Test multi-extent file support

## How to Run
```bash
cd /path/to/z80pack/cpmsim
cp /path/to/lolos/drivea.dsk disks/
./cpmsim
```

## Adding Programs
```bash
# Install cpmtools
sudo apt install cpmtools

# Copy a .COM file to drive A:
cpmcp -f ibm-3740 drivea.dsk program.com 0:

# List files on disk
cpmls -f ibm-3740 drivea.dsk
```
