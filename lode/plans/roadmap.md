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
- [x] Fix CCP RDCMD null termination
- [x] Fix CMDDIR wildcard handling
- [x] Fix BDOS USERNO initialization (via B_RESET at CCP startup)
- [x] Fix CCP register preservation (OUTCHR/BDOSCL preserve HL/BC)
- [x] Fix BDOS READREC EOF detection (check RC field)
- [x] Fix BDOS SEARCH DIRPTR setting
- [x] Fix BDOS SEARCHI reset before independent searches
- [x] Test hello.com - loads and executes correctly

### Phase 9: Program Testing (Completed)
- [x] Write and assemble hello.com test program
- [x] Copy to disk with cpmtools
- [x] Verify transient program loading and execution

### Phase 10: Extended Testing (In Progress)
- [x] Create automated test harness (`tests/run_tests.py`)
- [x] Test TYPE, ERA, REN commands with real files
- [x] Fix TYPE command argument parsing (was using command name, not filename)
- [x] Fix ERA command argument parsing (same issue)
- [x] Fix HASWILD function (inverted logic)
- [x] Test SAVE command
- [x] Test file I/O with fileio.com test program
- [x] Fix BDOS WRITEREC - PUTBLOCK was corrupting HL (block number) before BLKTOSEC
- [x] Fix BDOS SELDRIVE - ALV not initialized on first drive login
- [ ] Test multi-extent files (files > 16K)

## Next Steps

### Phase 11: Compatibility Testing
- [ ] Test MBASIC
- [ ] Test WordStar or similar
- [ ] Test Turbo Pascal or other compilers
- [ ] Fix compatibility issues

### Known Issues to Address
- Warm boot doesn't reload CCP/BDOS from disk (uses memory copy)
- Multi-extent files not tested

## Toolchain
- **Assembler**: zmac with `-8` flag for 8080 mode
  - Windows: `tools/zmac.exe`
  - Linux: `tools/zmac`
- **Disk tool**: `tools/mkdisk.py` (Python 3)
- **Build**: `build.bat` (Windows) or manual zmac commands (Linux)
- **Disk management**: cpmtools (`cpmcp`, `cpmls`) with format `ibm-3740`
