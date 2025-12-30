# Implementation Roadmap

## Completed

### Phase 1: Bootstrap
- [x] Set up toolchain (zmac assembler)
- [x] Create skeleton BIOS with console I/O
- [x] Boot loader implementation

### Phase 2: BIOS
- [x] 17 BIOS entry points
- [x] Disk read/write via z80pack ports
- [x] Sector translation table (6-sector skew)
- [x] DPH and DPB structures for 8" SSSD

### Phase 3-5: BDOS
- [x] Console functions (0-11)
- [x] Disk/file operations (12-37, 40)
- [x] Directory search and file management
- [x] Sequential and random access
- [x] Block allocation

### Phase 6: CCP
- [x] Command line input and parsing
- [x] Built-in commands: DIR, ERA, REN, TYPE, SAVE, USER
- [x] Drive switching
- [x] Transient .COM loading

### Phase 7: System Integration
- [x] Cold boot loader (64 bytes)
- [x] Bootable disk image creation

## Next Steps

### Phase 8: Testing & Debugging
- [ ] Boot test on z80pack
- [ ] Test basic commands (DIR, TYPE)
- [ ] Debug any BIOS/BDOS issues
- [ ] Test with simple .COM programs

### Phase 9: Compatibility Testing
- [ ] Test MBASIC
- [ ] Test WordStar or similar
- [ ] Fix compatibility issues

## Toolchain
- **Assembler**: zmac (tools/zmac.exe) with -8 flag for 8080 mode
- **Disk tool**: tools/mkdisk.py
- **Build**: build.bat
