# Session Handover - CP/M Implementation

## Current State
**Status**: Initial implementation complete, ready for first boot test on z80pack.

All source code is written and assembles cleanly. A bootable disk image (`drivea.dsk`) has been generated.

## What Was Built

| File | Purpose | Size |
|------|---------|------|
| `src/boot/boot.asm` | Boot loader - loads system from disk | 64 bytes |
| `src/bios/bios.asm` | BIOS - z80pack I/O, disk params | 428 bytes |
| `src/bdos/bdos.asm` | BDOS - 41 system calls | 2354 bytes |
| `src/ccp/ccp.asm` | CCP - command processor | 1353 bytes |
| `tools/mkdisk.py` | Creates 8" SSSD disk image | - |
| `build.bat` | Windows build script | - |

## Memory Layout (64K)
- CCP: E400h
- BDOS: EC00h
- BIOS: FA00h
- System loaded to E400h by boot loader

## z80pack I/O Ports Used
- Console: 00h (status), 01h (data)
- Disk: 10h-17h (drive, track, sector, command, status, DMA)

## Next Steps

### 1. Install z80pack on Linux
```bash
sudo apt install z80pack
# or build from source
```

### 2. Build on Linux
Need to install zmac or use the assembled .cim files from Windows.

Option A - Use existing binaries:
```bash
python3 tools/mkdisk.py
```

Option B - Reassemble on Linux:
```bash
# Install zmac (may need to build from source)
zmac -8 --oo cim src/boot/boot.asm
zmac -8 --oo cim src/bios/bios.asm
zmac -8 --oo cim src/bdos/bdos.asm
zmac -8 --oo cim src/ccp/ccp.asm
python3 tools/mkdisk.py
```

### 3. Copy disk to z80pack
```bash
cp drivea.dsk ~/.z80pack/cpmsim/disks/drivea.dsk
```

### 4. Boot test
```bash
cd ~/.z80pack/cpmsim
./cpmsim
```

### 5. Expected Output
```
CP/M 2.2 (Lolos)
64K TPA

A>
```

### 6. Debug if needed
Likely issues on first boot:
- Boot loader not finding system (check sector numbering)
- BIOS I/O ports different than expected (check z80pack docs)
- Console not working (verify port 00h/01h)

## Known Limitations / TODO
- Warm boot doesn't reload CCP/BDOS from disk (just reinits vectors)
- Function 10 (buffered input) has incomplete character handling
- No multi-extent file support tested
- HASWILD function logic may be inverted

## Debugging Guide

### If nothing happens on boot:
1. Check z80pack I/O ports in `~/.z80pack/cpmsim/srcsim/iosim.c`
2. Console should be port 0 (status) and port 1 (data)
3. Disk FDC should be ports 10h-17h

### If boot loader runs but system doesn't start:
1. Boot loader loads 48 sectors starting at sector 2
2. System is loaded to E400h (CCP address)
3. Boot jumps to FA00h (BIOS cold boot)
4. Check that sectors are being read correctly

### If CCP prompt appears but commands fail:
1. DIR requires working BDOS search (functions 17/18)
2. File loading requires BDOS read (function 20)
3. Check directory is being read from correct track (track 2 = first data track)

### z80pack disk image format:
- Raw sectors, no header
- Sector 1 at offset 0 in our image
- Track 0 sectors 1-26, then track 1, etc.
- Our boot loader is at offset 0 (track 0, sector 1)
- System starts at offset 128 (track 0, sector 2)

### Key addresses to verify in debugger:
- 0000h: Should be JMP to warm boot (C3 03 FA)
- 0005h: Should be JMP to BDOS entry (C3 06 EC)
- E400h: CCP code start
- EC00h: BDOS code start
- FA00h: BIOS jump table

### z80pack debugger commands:
```
g           - run
s           - single step
b addr      - set breakpoint
d addr      - dump memory
r           - show registers
```

## Key Files to Read First
- `lode/summary.md` - Project overview
- `lode/cpm/bios.md` - BIOS details and z80pack ports
- `lode/cpm/memory-map.md` - Memory layout
- `lode/plans/roadmap.md` - What's done, what's next

## Source Files Quick Reference
| File | Key Routines |
|------|--------------|
| `src/boot/boot.asm` | LDLP (load loop), sector/track wrap |
| `src/bios/bios.asm` | CONST, CONIN, CONOUT, READ, WRITE, SELDSK, SETFDC |
| `src/bdos/bdos.asm` | BDOSENT, FTABLE, SEARCH, READREC, WRITEREC, ALLOCBLK |
| `src/ccp/ccp.asm` | CCPLP, PARSE, PARFCB, EXEC, EXTRAN, CMDDIR |

## Resume Prompt
When resuming on Linux, start with:
> "I'm continuing the CP/M project. Read lode/tmp/handover.md and lode/summary.md, then help me test on z80pack."
