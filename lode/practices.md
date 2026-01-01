# Practices

## Assembly Style
- Use uppercase mnemonics (8080 convention)
- Constants in UPPERCASE with EQU
- Comment non-obvious logic
- One logical unit per source file

## Function Documentation Format

### Verbose Block (public functions and complex internals)
```asm
;-------------------------------------------------------------------------------
; FUNCNAME - Brief one-line description
;-------------------------------------------------------------------------------
; Description:
;   Multi-line description of purpose and behavior.
;
; Input:
;   A       - [REQ] Required input description
;   DE      - [OPT] Optional input (default: value)
;   HL      - [---] Not used
;
; Output:
;   A       - Return value description
;   Z flag  - Set if condition, clear otherwise
;
; Clobbers:
;   BC, DE, flags
;
; Notes:
;   - Edge cases, dependencies, etc.
;-------------------------------------------------------------------------------
```

### Compact Block (small internal helpers)
```asm
; HELPER - Brief description
; Input: REG=desc  Output: REG=desc  Clobbers: REG, flags
```

### Clobbers Documentation Rules
- **Always document flags** - Most 8080 instructions modify flags; explicitly list them
- **Outputs are not clobbers** - If A is a return value, don't list it as clobbered
- **Be specific** - List specific registers (BC, DE, HL, flags) rather than "All registers"
- **"(none)" means nothing** - Only use when truly no registers/flags are modified
- BDOS public functions with output in HL: "Clobbers: BC, DE, flags"
- BDOS public functions without output: "Clobbers: BC, DE, HL, flags"

### Register Notation
- `[REQ]` - Required input, must be set by caller
- `[OPT]` - Optional input, has default or conditional use
- `[---]` - Not used / ignored
- `[COND]` - Conditional, depends on another parameter

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

### CCP Command Buffer Must Be Null-Terminated
RDCMD reads characters into DBUFF but must add a null terminator after the copy loop. Without this, PARSE sees garbage after the command name:
```asm
        ; After copy loop
        XRA     A
        STAX    D               ; Null terminate
```

### CCP DIR Command Wildcard Handling
CMDDIR must scan DBUFF for arguments after the command name, not check DFCB. PARSE puts the command name ("DIR") in DFCB, so checking `DFCB+1 == ' '` fails.

### CCP DIR Must Filter by Extent Number
DIR uses BDOS Search (F17/F18) which returns ALL directory entries including extent 1, 2, etc. for multi-extent files. DIR must check byte 12 (extent) and skip non-zero entries:
```asm
        ; Check if extent 0 (only show first extent of each file)
        LXI     D, 12           ; Offset to extent byte
        DAD     D
        MOV     A, M
        ORA     A
        JNZ     DIRNXT          ; Skip non-zero extents
```
Without this, a 25K file (2 extents) appears twice in DIR output.

### BDOS SEARCH State (SEARCHI) Must Be Reset
SEARCH maintains `SEARCHI` to support FUNC17+FUNC18 multi-call searches. Any function that starts a new independent search MUST reset SEARCHI to 0:
```asm
        XRA     A
        STA     SEARCHI         ; Start from entry 0
        CALL    SEARCH
```
Functions that need this: FUNC15 (Open), FUNC16 (Close), FUNC19 (Delete), FUNC23 (Rename), FUNC30 (Set Attributes), RNDREC (random access).

### BDOS SEARCH Must Set DIRPTR
When SEARCH finds a match, it must save the directory entry pointer for later use by FUNC15/FUNC16:
```asm
        ; Match found
        CALL    GETDIRENT       ; Get entry pointer
        SHLD    DIRPTR          ; Save for OPEN/CLOSE
```

### CCP Must Reset DMA After Transient Programs
Transient programs may set DMA to their own buffers and not restore it. CCPRET must reset DMA to DBUFF (0080h) before built-in commands run, otherwise FUNC18 copies directory data to the wrong address:
```asm
CCPRET:
        ...
        ; Reset DMA to DBUFF - transient programs may leave it pointing elsewhere
        LXI     D, DBUFF
        MVI     C, B_SETDMA
        CALL    ENTRY
```

### Register Preservation Contracts
- BDOS entry does XCHG which corrupts caller's HL
- CCP utilities (OUTCHR, BDOSCL) should preserve HL/BC internally
- BDOS functions may corrupt any register except those documented as preserved

### BDOS Variables (DS) Are Not Initialized
`DS` reserves space but doesn't initialize memory. Variables like USERNO must be explicitly initialized (CCP calls B_RESET at startup to initialize BDOS state).

## Testing
- Use `strace -e trace=read ./cpmsim` to verify disk reads
- Check t-state count in cpmsim output - low count means early crash
- "No File" from DIR with empty disk is correct behavior
