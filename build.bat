@echo off
REM Build script for LOLOS

echo Building LOLOS...
echo.

REM Create output directory
if not exist build mkdir build

REM Assemble boot loader
echo Assembling boot loader...
tools\zmac.exe -8 --od build --oo cim,lst src\boot.asm
if errorlevel 1 goto error

REM Assemble BIOS
echo Assembling BIOS...
tools\zmac.exe -8 --od build --oo cim,lst src\bios.asm
if errorlevel 1 goto error

REM Assemble BDOS
echo Assembling BDOS...
tools\zmac.exe -8 --od build --oo cim,lst src\bdos.asm
if errorlevel 1 goto error

REM Assemble CCP
echo Assembling CCP...
tools\zmac.exe -8 --od build --oo cim,lst src\ccp.asm
if errorlevel 1 goto error

REM Create disk image
echo.
echo Creating disk image...
python tools\mkdisk.py

echo.
echo Build complete!
echo Run with: cpmsim (ensure drivea.dsk is in z80pack's disks directory)
goto end

:error
echo.
echo Build failed!
exit /b 1

:end
