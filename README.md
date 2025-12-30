# Lolos - A CP/M 2.2 Recreation

A from-scratch implementation of CP/M 2.2 (Control Program for Microcomputers) written in pure Intel 8080 assembly language. Lolos is a fully bootable operating system that runs on the z80pack emulator.

> **Note**: This project is still under active development and testing. While core functionality works and passes automated tests, some edge cases may not yet be fully handled.

## Features

- **Complete CP/M 2.2 implementation** - All standard BDOS functions (0-37, 40)
- **Full file system support** - Including multi-extent files (>16KB)
- **Built-in commands** - DIR, TYPE, ERA, REN, SAVE, USER
- **Transient program execution** - Load and run .COM files
- **8080 compatible** - No Z80 extensions, maximum portability
- **Tested with real software** - MBASIC, BBC BASIC, Colossal Cave Adventure

## Quick Start

### Prerequisites

**Build Requirements:**
- [zmac](http://48k.ca/zmac.html) assembler (included in `tools/` for Linux and Windows)

**Runtime Requirements:**
- [z80pack](https://github.com/udo-munk/z80pack) emulator (cpmsim)

**Test Suite Requirements:**
- Python 3.8+
- [cpmtools](https://github.com/lipro-cpm4l/cpmtools) (cpmcp, cpmls) - for disk image manipulation

### Build and Run

```bash
# Clone the repository
git clone https://github.com/yourusername/lolos.git
cd lolos

# Run automated tests (builds automatically)
python3 tests/run_tests.py

# Copy disk image to emulator
cp drivea.dsk ~/z80pack/cpmsim/disks/

# Run the emulator
cd ~/z80pack/cpmsim
./cpmsim
```

### Manual Build

```bash
# Assemble components
./tools/zmac -8 --od src/boot --oo cim,lst src/boot/boot.asm
./tools/zmac -8 --od src/bios --oo cim,lst src/bios/bios.asm
./tools/zmac -8 --od src/bdos --oo cim,lst src/bdos/bdos.asm
./tools/zmac -8 --od src/ccp --oo cim,lst src/ccp/ccp.asm

# Create disk image
python3 tools/mkdisk.py
```

## Memory Map (64K System)

```
FFFFh ┌─────────────────────────┐
      │        (unused)         │
FBACh ├─────────────────────────┤
      │         BIOS            │  ~428 bytes
FA00h ├─────────────────────────┤
      │         BDOS            │  ~2.4K
EC00h ├─────────────────────────┤
      │         CCP             │  ~2K
E400h ├─────────────────────────┤
      │                         │
      │         TPA             │  ~57K
      │    (User Programs)      │
      │                         │
0100h ├─────────────────────────┤
      │      Page Zero          │  256 bytes
0000h └─────────────────────────┘
```

## Architecture

### Components

| Component | File | Size | Description |
|-----------|------|------|-------------|
| Boot | `src/boot/boot.asm` | 66 bytes | Loads CCP/BDOS/BIOS from disk |
| BIOS | `src/bios/bios.asm` | ~428 bytes | Hardware abstraction layer |
| BDOS | `src/bdos/bdos.asm` | ~2.4K | System call interface |
| CCP | `src/ccp/ccp.asm` | ~2K | Command line interpreter |

### BDOS Functions Implemented

**Console I/O (0-11)**
- System reset, console input/output, string I/O, status

**Disk Operations (12-37, 40)**
- File open/close/create/delete/rename
- Sequential and random read/write
- Directory search
- Drive selection and status
- DMA address management
- User number support

### Disk Format

- **Type**: IBM 3740 (8" SSSD)
- **Tracks**: 77
- **Sectors/Track**: 26
- **Bytes/Sector**: 128
- **Block Size**: 1024 bytes
- **Directory Entries**: 64
- **Reserved Tracks**: 2

## Built-in Commands

| Command | Description |
|---------|-------------|
| `DIR [filespec]` | List directory (supports wildcards) |
| `TYPE file` | Display text file contents |
| `ERA filespec` | Erase files (wildcards allowed) |
| `REN new=old` | Rename a file |
| `SAVE n file` | Save n pages (256 bytes each) from TPA to file |
| `USER n` | Switch user area (0-15) |
| `d:` | Change current drive |

## Testing

The test suite requires Python 3.8+ and cpmtools.

### Automated Tests

```bash
# Run all tests
python3 tests/run_tests.py

# Verbose output
python3 tests/run_tests.py -v

# Skip rebuild
python3 tests/run_tests.py --no-build

# Run specific test
python3 tests/run_tests.py --test fileio
```

### Test Coverage

| Test | Description |
|------|-------------|
| boot | System boots and displays prompt |
| dir | DIR command lists files |
| type | TYPE command displays file contents |
| era | ERA command deletes files |
| ren | REN command renames files |
| hello | .COM file execution |
| save | SAVE command creates executable files |
| fileio | Create, write, read, verify file data |
| bigfile | Multi-extent file (25K, 200 records) |

### Compatibility Tested

Initial compatibility testing with third-party CP/M software:

| Software | Status | Notes |
|----------|--------|-------|
| MBASIC 5.29 | ✅ Works | Interactive mode, file I/O |
| BBC BASIC 5.x | ✅ Works | FOR/NEXT, PRINT, file I/O |
| Colossal Cave Adventure | ✅ Works | Full game, reads data file |

Additional software compatibility testing is ongoing.

## Project Structure

```
lolos/
├── src/
│   ├── boot/boot.asm     # Boot loader
│   ├── bios/bios.asm     # Hardware abstraction
│   ├── bdos/bdos.asm     # System calls
│   └── ccp/ccp.asm       # Command processor
├── tools/
│   ├── zmac              # Assembler (Linux)
│   ├── zmac.exe          # Assembler (Windows)
│   └── mkdisk.py         # Disk image creator
├── tests/
│   ├── run_tests.py      # Test harness
│   └── programs/         # Test programs
├── lode/                 # Project documentation
└── drivea.dsk           # Output disk image
```

## Technical Details

### Page Zero Layout

| Address | Purpose |
|---------|---------|
| 0000h | Warm boot vector (`JMP BIOS+3`) |
| 0003h | IOBYTE |
| 0004h | Current drive/user |
| 0005h | BDOS entry (`JMP BDOS`) |
| 005Ch | Default FCB (36 bytes) |
| 006Ch | Second FCB (overlaps first) |
| 0080h | DMA buffer / command tail |

### FCB Structure (File Control Block)

| Offset | Size | Field |
|--------|------|-------|
| 0 | 1 | Drive (0=default, 1=A:, ...) |
| 1-8 | 8 | Filename (space padded) |
| 9-11 | 3 | Extension (space padded) |
| 12 | 1 | Extent (EX) |
| 13 | 1 | S1 (reserved) |
| 14 | 1 | S2 (extent high byte) |
| 15 | 1 | Record count (RC) |
| 16-31 | 16 | Allocation map |
| 32 | 1 | Current record (CR) |
| 33-35 | 3 | Random record (R0, R1, R2) |

### Multi-Extent Files

Files larger than 16KB span multiple directory entries (extents). Each extent contains:
- Up to 128 records (16KB)
- Its own allocation map (16 block pointers)
- Sequential extent numbers (EX field)

Lolos correctly handles extent transitions during sequential I/O.

## Development

### Assembler Notes

The project uses zmac with 8080-only mode:

```bash
./tools/zmac -8 --od output_dir --oo cim,lst source.asm
```

- `-8`: 8080-only mode (no Z80 instructions)
- `--oo cim,lst`: Output .cim (binary) and .lst (listing)

### Adding New Tests

```python
def test_example(tester: CpmTester):
    """Test description"""
    tester.create_text_file("TEST.TXT", "content")
    success, output = tester.run_cpmsim(["TYPE TEST.TXT"], timeout=5)
    if "content" in output:
        return True, "Test passed", output
    return False, "Expected content not found", output
```

## Historical Context

CP/M (Control Program for Microcomputers) was created by Gary Kildall in 1974 and became the dominant operating system for 8-bit microcomputers in the late 1970s and early 1980s. It ran on Intel 8080, 8085, and Zilog Z80 processors.

Lolos is an educational recreation that demonstrates:
- Operating system fundamentals
- File system design
- Hardware abstraction layers
- 8080 assembly programming

## License

This project is provided for educational purposes. CP/M is a trademark of its respective owners.

## Acknowledgments

- Gary Kildall for creating CP/M
- The z80pack project for the excellent emulator
- The cpmtools project for disk utilities
