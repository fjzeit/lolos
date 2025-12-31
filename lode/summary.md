# Project Summary

**LOLOS** - A from-scratch CP/M 2.2 compatible operating system written in pure Intel 8080 assembly language. Fully bootable OS targeting z80pack emulator.

**Status**: Fully operational - boots, runs commands, executes .COM files, file I/O including multi-extent files (>16K). All 27 automated tests pass.

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
| BDOS | EC00h | ~2.9K |
| BIOS | FA00h | ~535 bytes |
| Boot | Track 0, Sector 1 | 66 bytes |

## Build
**Windows**: Run `build.bat`
**Linux**: Run `./build.sh` or manually:
```bash
mkdir -p build
./tools/zmac -8 --od build --oo cim,lst src/boot.asm
./tools/zmac -8 --od build --oo cim,lst src/bios.asm
./tools/zmac -8 --od build --oo cim,lst src/bdos.asm
./tools/zmac -8 --od build --oo cim,lst src/ccp.asm
python3 tools/mkdisk.py
```

## Testing
**Automated**: `python3 tests/run_tests.py` - runs 27 tests:
- Basic operations: boot, dir, type, era, ren, hello, save
- File I/O: fileio (sequential), bigfile (multi-extent)
- Console I/O: conch (F1,F2), constr (F9-11), rawio (F6), auxlst (F3-5)
- BDOS functions: version (F12), disk_mgmt (F13,14,24-29,31,37), search (F17-18), user (F32), random (F33-36,F40), attrib (F30), iobyte (F7,8,28), open (F15,F16), delete (F19), seqio (F20,F21), make (F22), rename (F23), dma (F26), alloc (F27-29)

Test programs are in `tests/programs/*.asm` (8080 assembly, 8.3 filename format)

**Manual**: Copy `drivea.dsk` to z80pack's `cpmsim/disks/` directory and run `./cpmsim`.

## Source Structure
```
src/
  boot.asm   - Boot loader (66 bytes)
  bios.asm   - Hardware abstraction (CP/M 2.2 compatible interface)
  bdos.asm   - System calls (CP/M 2.2 compatible API)
  ccp.asm    - Command processor (CP/M 2.2 compatible commands)
build/       - Assembled binaries (.cim, .lst)
tools/
  zmac       - Assembler (Linux binary)
  zmac.exe   - Assembler (Windows)
  mkdisk.py  - Disk image creator
```
