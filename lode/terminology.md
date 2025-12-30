# Terminology

- **CP/M** - Control Program for Microcomputers, 8-bit OS created by Gary Kildall (1974)
- **CCP** - Console Command Processor, the command line interface
- **BDOS** - Basic Disk Operating System, provides system calls (file I/O, console)
- **BIOS** - Basic Input/Output System, hardware abstraction layer
- **FCB** - File Control Block, 36-byte structure for file operations
- **DPH** - Disk Parameter Header, describes disk geometry
- **DPB** - Disk Parameter Block, detailed disk format parameters
- **TPA** - Transient Program Area, memory where user programs load (0100h and up)
- **BDOS call** - System call via CALL 0005h with function number in C register
- **Warm boot** - Reload CCP/BDOS, preserving BIOS (jump to 0000h)
- **Cold boot** - Full system initialization
