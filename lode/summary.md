# Project Summary

A from-scratch recreation of CP/M 2.2 (Control Program for Microcomputers) written in pure Intel 8080 assembly language. Fully bootable operating system targeting z80pack emulator.

**Status**: Fully operational - boots, accepts commands, displays prompts correctly

## Design Decisions
- **CPU**: Intel 8080 (no Z80 extensions, maximum compatibility)
- **Emulator**: z80pack (cpmsim)
- **Disk format**: 8" SSSD (IBM 3740) - 77 tracks, 26 sectors, 128 bytes/sector
- **CP/M version**: 2.2 (full compatibility target)

## Memory Map (64K System)
| Component | Address | Size |
|-----------|---------|------|
| TPA | 0100h-DBFFh | ~55K |
| CCP | E400h | 1345 bytes |
| BDOS | EC00h | 2358 bytes |
| BIOS | FA00h | 428 bytes |
| Boot | 0000h | 66 bytes |

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
Copy `drivea.dsk` to z80pack's `cpmsim/disks/` directory and run `./cpmsim`.

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
