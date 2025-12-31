# Project Summary

A from-scratch recreation of CP/M 2.2 (Control Program for Microcomputers) written in pure Intel 8080 assembly language. Fully bootable operating system targeting z80pack emulator.

**Status**: Fully operational - boots, runs commands, executes .COM files, file I/O including multi-extent files (>16K)

## Design Decisions
- **CPU**: Intel 8080 (no Z80 extensions, maximum compatibility)
- **Emulator**: z80pack (cpmsim)
- **Disk format**: 8" SSSD (IBM 3740) - 77 tracks, 26 sectors, 128 bytes/sector
- **CP/M version**: 2.2 (full compatibility target)

## Memory Map (64K System)
| Component | Address | Size |
|-----------|---------|------|
| TPA | 0100h-E3FFh | ~57K |
| CCP | E400h | ~1.4K |
| BDOS | EC00h | ~3K |
| BIOS | FA00h | ~428 bytes |
| Boot | Track 0, Sector 1 | 66 bytes |

## Build
**Windows**: Run `build.bat`
**Linux**:
```bash
./tools/zmac -8 --od src/boot --oo cim,lst src/boot/boot.asm
./tools/zmac -8 --od src/bios --oo cim,lst src/bios/bios.asm
./tools/zmac -8 --od src/bdos --oo cim,lst src/bdos/bdos.asm
./tools/zmac -8 --od src/ccp --oo cim,lst src/ccp/ccp.asm
python3 tools/mkdisk.py
```

## Testing
**Automated**: `python3 tests/run_tests.py` - runs 16 tests:
- Basic operations: boot, dir, type, era, ren, hello, save
- File I/O: fileio (sequential), bigfile (multi-extent)
- BDOS functions: version (F12), disk_mgmt (F13,14,24-29,31,37), search (F17-18), user (F32), random (F33-36,F40), attrib (F30), iobyte (F7,8,28)

Test programs are in `tests/programs/*.asm` (8080 assembly, 8.3 filename format)

**Manual**: Copy `drivea.dsk` to z80pack's `cpmsim/disks/` directory and run `./cpmsim`.

## Source Structure
```
src/
  boot/boot.asm   - Boot loader (66 bytes)
  bios/bios.asm   - Hardware abstraction
  bdos/bdos.asm   - System calls
  ccp/ccp.asm     - Command processor
tools/
  zmac            - Assembler (Linux binary)
  zmac.exe        - Assembler (Windows)
  mkdisk.py       - Disk image creator
```
