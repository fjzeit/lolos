#!/bin/bash
# Build script for CP/M (Lolos) - Linux version

set -e

echo "Building CP/M..."
echo

# Check for zmac
if ! command -v zmac &> /dev/null; then
    echo "zmac not found. Checking for local copy..."
    if [ -f "./tools/zmac" ]; then
        ZMAC="./tools/zmac"
    else
        echo "Please install zmac:"
        echo "  git clone https://github.com/g2000/zmac.git"
        echo "  cd zmac && make && sudo cp zmac /usr/local/bin/"
        exit 1
    fi
else
    ZMAC="zmac"
fi

# Create output directories
mkdir -p src/boot src/bios src/bdos src/ccp

# Assemble boot loader
echo "Assembling boot loader..."
$ZMAC -8 --od src/boot --oo cim,lst src/boot/boot.asm

# Assemble BIOS
echo "Assembling BIOS..."
$ZMAC -8 --od src/bios --oo cim,lst src/bios/bios.asm

# Assemble BDOS
echo "Assembling BDOS..."
$ZMAC -8 --od src/bdos --oo cim,lst src/bdos/bdos.asm

# Assemble CCP
echo "Assembling CCP..."
$ZMAC -8 --od src/ccp --oo cim,lst src/ccp/ccp.asm

# Create disk image
echo
echo "Creating disk image..."
python3 tools/mkdisk.py

echo
echo "Build complete!"
echo
echo "To test:"
echo "  cp drivea.dsk ~/.z80pack/cpmsim/disks/"
echo "  cd ~/.z80pack/cpmsim && ./cpmsim"
