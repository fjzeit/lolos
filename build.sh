#!/bin/bash
# Build script for LOLOS - Linux version

set -e

echo "Building LOLOS..."
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

# Create output directory
mkdir -p build

# Assemble boot loader
echo "Assembling boot loader..."
$ZMAC -8 --od build --oo cim,lst src/boot.asm

# Assemble BIOS
echo "Assembling BIOS..."
$ZMAC -8 --od build --oo cim,lst src/bios.asm

# Assemble BDOS
echo "Assembling BDOS..."
$ZMAC -8 --od build --oo cim,lst src/bdos.asm

# Assemble CCP
echo "Assembling CCP..."
$ZMAC -8 --od build --oo cim,lst src/ccp.asm

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
