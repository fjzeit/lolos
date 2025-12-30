# Practices

## Assembly Style
- Use uppercase mnemonics (8080 convention)
- Constants in UPPERCASE with EQU
- Comment non-obvious logic
- One logical unit per source file

## Toolchain
- **Assembler**: zmac with `-8` flag for 8080-only mode
- **Emulator**: z80pack (cpmsim)
- **Disk tools**: cpmtools (`cpmcp`, `cpmls`) with format `ibm-3740`
- **Build**: `mkdisk.py` assembles disk image from .cim binaries

## Critical Lessons Learned

### z80pack I/O Ports Use DECIMAL Numbers
The simio.c source defines ports as decimal integers. When the docs say "port 10", use `EQU 10` NOT `EQU 10H`:
```asm
; CORRECT
FDCD    EQU     10              ; Port 10 decimal

; WRONG - this is port 16!
FDCD    EQU     10H
```

### Always Initialize Registers Before Use
The boot loader bug: D register tracked the current track but was never initialized. After reading 25 sectors (track 0 full), it incremented garbage:
```asm
MVI     D, 0            ; MUST initialize track counter
```

### BDOS Console Buffer (Function 10)
Input character must be saved before any comparisons that might clobber it. Store in a register (E) immediately after CONINW returns, then store/echo after validation.

### CCP Character Output
BDOS function 2 expects: C=function (2), E=character. Don't clobber C before copying it to E:
```asm
; CORRECT
OUTCHR: MOV     E, C            ; Save char first
        MVI     C, B_CONOUT     ; Then set function
        CALL    ENTRY
```

## Testing
- Use `strace -e trace=read ./cpmsim` to verify disk reads
- Check t-state count in cpmsim output - low count means early crash
- "No File" from DIR with empty disk is correct behavior
