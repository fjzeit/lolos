# CCP - Console Command Processor

## Overview

The CCP is the command-line interface. It displays the prompt, parses commands, and either executes built-in commands or loads .COM files from disk.

## Boot Sequence

```mermaid
flowchart TD
    A[BIOS WBOOT] --> B[Reload CCP+BDOS from disk]
    B --> C[Initialize page zero vectors]
    C --> D[CCP: Display prompt]
    D --> E[Read command line]
    E --> F{Built-in command?}
    F -->|Yes| G[Execute internal]
    F -->|No| H[Search for .COM file]
    G --> D
    H --> I{Found?}
    I -->|Yes| J[Load at 0100h]
    I -->|No| K[Print error]
    J --> L[Parse FCBs at 5Ch, 6Ch]
    L --> M[Copy tail to 80h]
    M --> N[CALL 0100h]
    N --> O[Program runs]
    O --> P[Returns or warm boot]
    P --> D
    K --> D
```

## Built-in Commands

| Command | Description |
|---------|-------------|
| `dir [filespec]` | List directory |
| `era filespec` | Erase files (wildcards allowed) |
| `ren new=old` | Rename file |
| `save n file` | Save n pages from TPA to file |
| `type file` | Display text file |
| `user n` | Switch user area (0-15) |
| `d:` | Change current drive |

## Command Line Parsing

1. Convert to uppercase
2. Extract drive prefix if present (e.g., `B:`)
3. Parse first filename into FCB at 005Ch
4. Parse second filename into FCB at 006Ch
5. Store remainder (command tail) at 0080h with length byte

## Prompt Format

```
A>_
```

Where A is current drive letter (A-P) and > is the prompt character.

## Transient Command Loading

1. Search current drive for `COMMAND.COM`
2. If not found and drive specified, search that drive
3. Load file at 0100h
4. Initialize: DMA=0080h, FCBs parsed, tail at 0080h
5. `CALL 0100h`

## Related
- [bdos.md](bdos.md) - System calls used by CCP
- [memory-map.md](memory-map.md) - Page zero layout
