#!/usr/bin/env python3
"""
Create a bootable LOLOS disk image for z80pack.
Combines boot loader, CCP, BDOS, and BIOS into an 8" SSSD disk image.
"""

import sys
import os

# Disk geometry (8" SSSD - IBM 3740)
TRACKS = 77
SECTORS_PER_TRACK = 26
SECTOR_SIZE = 128
DISK_SIZE = TRACKS * SECTORS_PER_TRACK * SECTOR_SIZE  # 256,256 bytes

# Memory layout (64K system)
CCP_ADDR = 0xE400
BDOS_ADDR = 0xEC00
BIOS_ADDR = 0xFA00

# Reserved tracks for system
RESERVED_TRACKS = 2
RESERVED_SECTORS = RESERVED_TRACKS * SECTORS_PER_TRACK  # 52 sectors


def read_binary(filename, expected_org=0):
    """Read a binary file and return its contents."""
    with open(filename, 'rb') as f:
        return f.read()


def create_system_image(boot_file, ccp_file, bdos_file, bios_file):
    """
    Create a combined system image.
    The system image contains CCP, BDOS, and BIOS concatenated.
    """
    # Read all components
    boot = read_binary(boot_file)
    ccp = read_binary(ccp_file)
    bdos = read_binary(bdos_file)
    bios = read_binary(bios_file)

    print(f"Boot loader: {len(boot)} bytes")
    print(f"CCP: {len(ccp)} bytes (at {CCP_ADDR:04X}h)")
    print(f"BDOS: {len(bdos)} bytes (at {BDOS_ADDR:04X}h)")
    print(f"BIOS: {len(bios)} bytes (at {BIOS_ADDR:04X}h)")

    # Create memory image from CCP to end of BIOS
    # This needs to start at CCP_ADDR and include everything up to BIOS end
    system_start = CCP_ADDR
    system_end = BIOS_ADDR + len(bios)
    system_size = system_end - system_start

    print(f"System spans {system_start:04X}h to {system_end:04X}h ({system_size} bytes)")

    # Create system memory image
    system = bytearray(system_size)

    # Place CCP
    ccp_offset = 0  # CCP_ADDR - CCP_ADDR
    system[ccp_offset:ccp_offset + len(ccp)] = ccp

    # Place BDOS
    bdos_offset = BDOS_ADDR - CCP_ADDR
    system[bdos_offset:bdos_offset + len(bdos)] = bdos

    # Place BIOS
    bios_offset = BIOS_ADDR - CCP_ADDR
    system[bios_offset:bios_offset + len(bios)] = bios

    return boot, bytes(system)


def create_disk_image(boot, system, output_file):
    """
    Create a z80pack disk image.
    Track 0, Sector 1: Boot loader
    Track 0, Sectors 2-26 + Track 1: System (CCP+BDOS+BIOS)
    """
    # Initialize disk with 0xE5 (empty/formatted)
    disk = bytearray([0xE5] * DISK_SIZE)

    # Write boot loader to track 0, sector 1 (offset 0)
    boot_padded = boot + bytes(SECTOR_SIZE - len(boot))
    disk[0:SECTOR_SIZE] = boot_padded[:SECTOR_SIZE]
    print(f"Boot loader written to track 0, sector 1")

    # Write system starting at track 0, sector 2
    # Sector 2 is at offset 128 (1 * SECTOR_SIZE)
    system_offset = SECTOR_SIZE  # Skip boot sector
    sectors_needed = (len(system) + SECTOR_SIZE - 1) // SECTOR_SIZE

    print(f"System needs {sectors_needed} sectors")

    for i in range(sectors_needed):
        src_start = i * SECTOR_SIZE
        src_end = min(src_start + SECTOR_SIZE, len(system))
        sector_data = system[src_start:src_end]

        # Pad to full sector if needed
        if len(sector_data) < SECTOR_SIZE:
            sector_data = sector_data + bytes(SECTOR_SIZE - len(sector_data))

        disk_offset = system_offset + (i * SECTOR_SIZE)
        disk[disk_offset:disk_offset + SECTOR_SIZE] = sector_data

    print(f"System written to {sectors_needed} sectors")

    # Write disk image
    with open(output_file, 'wb') as f:
        f.write(disk)

    print(f"Disk image written: {output_file} ({len(disk)} bytes)")


def main():
    if len(sys.argv) < 2:
        # Use default paths
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        boot_file = os.path.join(base_dir, 'build', 'boot.cim')
        ccp_file = os.path.join(base_dir, 'build', 'ccp.cim')
        bdos_file = os.path.join(base_dir, 'build', 'bdos.cim')
        bios_file = os.path.join(base_dir, 'build', 'bios.cim')
        output_file = os.path.join(base_dir, 'drivea.dsk')
    else:
        output_file = sys.argv[1]
        boot_file = sys.argv[2] if len(sys.argv) > 2 else 'build/boot.cim'
        ccp_file = sys.argv[3] if len(sys.argv) > 3 else 'build/ccp.cim'
        bdos_file = sys.argv[4] if len(sys.argv) > 4 else 'build/bdos.cim'
        bios_file = sys.argv[5] if len(sys.argv) > 5 else 'build/bios.cim'

    print("Creating LOLOS disk image...")
    print()

    try:
        boot, system = create_system_image(boot_file, ccp_file, bdos_file, bios_file)
        create_disk_image(boot, system, output_file)
        print()
        print("Done! Boot with z80pack: cpmsim")
    except FileNotFoundError as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
