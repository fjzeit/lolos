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

### Phase 8: Testing & Debugging
- [x] Boot test on z80pack (Linux)
- [x] Fix I/O port numbers (decimal vs hex)
- [x] Fix boot loader track counter initialization
- [x] Fix BDOS console buffer input
- [x] Fix CCP character output and prompt
- [x] Test basic commands (DIR works, shows "No File" on empty disk)
- [ ] Test with simple .COM programs
- [ ] Test TYPE, ERA, REN, SAVE commands with real files

## Next Steps

### Phase 9: Program Testing
- [ ] Write and assemble hello.com test program
- [ ] Copy to disk with cpmtools
- [ ] Verify transient program loading and execution
- [ ] Test file I/O with a program that reads/writes files

### Phase 10: Compatibility Testing
- [ ] Test MBASIC
- [ ] Test WordStar or similar
- [ ] Test Turbo Pascal or other compilers
- [ ] Fix compatibility issues

### Known Issues to Address
- Warm boot doesn't reload CCP/BDOS from disk
- DIR command doesn't handle "DIR" vs "DIR *.COM" correctly (minor)
- Multi-extent files not tested

## Toolchain
- **Assembler**: zmac with `-8` flag for 8080 mode
  - Windows: `tools/zmac.exe`
  - Linux: `tools/zmac`
- **Disk tool**: `tools/mkdisk.py` (Python 3)
- **Build**: `build.bat` (Windows) or manual zmac commands (Linux)
- **Disk management**: cpmtools (`cpmcp`, `cpmls`) with format `ibm-3740`
