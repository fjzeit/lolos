# Practices

## Assembly Style
- Use lowercase mnemonics for readability
- Label naming: `module_function` (e.g., `bdos_conout`, `ccp_parse`)
- Constants in UPPERCASE
- Comment non-obvious logic; Z80 idioms need no explanation
- One logical unit per source file

## Toolchain
- Assembler: TBD (zmac, z80asm, or similar)
- Emulator: TBD (z80pack, YAZE, or similar)
- Disk image tools: cpmtools for creating/inspecting disk images

## Testing
- Test each BDOS function in isolation before integration
- Use emulator debugging features (breakpoints, memory inspection)
- Create test .COM programs to exercise functionality
