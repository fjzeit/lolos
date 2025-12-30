;===============================================================================
; HELLO.COM - Test program for CP/M
;===============================================================================

BDOS    EQU     5               ; BDOS entry point
PRINT   EQU     9               ; Print string function

        ORG     100H            ; TPA start

        LXI     D, MSG          ; Point to message
        MVI     C, PRINT        ; Print string function
        CALL    BDOS
        RET                     ; Return to CCP

MSG:    DB      'Hello from CP/M!', 0DH, 0AH, '$'

        END
