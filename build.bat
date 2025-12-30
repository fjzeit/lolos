@echo off
REM Build script for CP/M (Lolos)

echo Building CP/M...
echo.

REM Assemble boot loader
echo Assembling boot loader...
tools\zmac.exe -8 --od src\boot --oo cim,lst src\boot\boot.asm
if errorlevel 1 goto error

REM Assemble BIOS
echo Assembling BIOS...
tools\zmac.exe -8 --od src\bios --oo cim,lst src\bios\bios.asm
if errorlevel 1 goto error

REM Assemble BDOS
echo Assembling BDOS...
tools\zmac.exe -8 --od src\bdos --oo cim,lst src\bdos\bdos.asm
if errorlevel 1 goto error

REM Assemble CCP
echo Assembling CCP...
tools\zmac.exe -8 --od src\ccp --oo cim,lst src\ccp\ccp.asm
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
