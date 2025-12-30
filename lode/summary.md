# Project Summary

A from-scratch recreation of CP/M 2.2 (Control Program for Microcomputers) written in pure Intel 8080 assembly language. Fully bootable operating system targeting z80pack emulator.

**Status**: Initial implementation complete, ready for testing

## Design Decisions
- **CPU**: Intel 8080 (no Z80 extensions, maximum compatibility)
- **Emulator**: z80pack (cpmsim)
- **Disk format**: 8" SSSD (IBM 3740) - 77 tracks, 26 sectors, 128 bytes/sector
- **CP/M version**: 2.2 (full compatibility target)

## Memory Map (64K System)
| Component | Address | Size |
|-----------|---------|------|
| TPA | 0100h-DBFFh | ~55K |
| CCP | E400h | 1353 bytes |
| BDOS | EC00h | 2354 bytes |
| BIOS | FA00h | 428 bytes |

## Build
Run `build.bat` to assemble all components and create `drivea.dsk`.

## Source Structure
```
src/
  boot/boot.asm   - Boot loader (64 bytes)
  bios/bios.asm   - Hardware abstraction
  bdos/bdos.asm   - System calls
  ccp/ccp.asm     - Command processor
tools/
  zmac.exe        - Assembler
  mkdisk.py       - Disk image creator
```
