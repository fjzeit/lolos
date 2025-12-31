; BDOS Version Test (Function 12)
; Tests: F12 returns 0022H for CP/M 2.2
;
; Prints "PASS" if version is correct
; Prints "FAIL" with details otherwise

        ORG     0100H

; BDOS Functions
BDOS    EQU     0005H
F_PRTSTR EQU    9
F_VERSION EQU   12

; ASCII
CR      EQU     0DH
LF      EQU     0AH

START:
        ; Print test header
        LXI     D, MSGHDR
        MVI     C, F_PRTSTR
        CALL    BDOS

        ; Call BDOS function 12 - Get Version
        MVI     C, F_VERSION
        CALL    BDOS

        ; HL should be 0022H (CP/M 2.2)
        ; A should be 22H (low byte)
        ; B should be 00H (high byte)

        ; Save return values
        SHLD    RETHL
        STA     RETA
        MOV     A, B
        STA     RETB

        ; Test 1: Check HL = 0022H
        LHLD    RETHL
        MOV     A, H
        ORA     A               ; H should be 0
        JNZ     FAIL1
        MOV     A, L
        CPI     22H             ; L should be 22H
        JNZ     FAIL1

        ; Test 2: Check A = 22H
        LDA     RETA
        CPI     22H
        JNZ     FAIL2

        ; Test 3: Check B = 00H
        LDA     RETB
        ORA     A
        JNZ     FAIL3

        ; All tests passed!
        LXI     D, MSGPASS
        MVI     C, F_PRTSTR
        CALL    BDOS
        RET

FAIL1:
        LXI     D, MSGF1
        JMP     FAILOUT
FAIL2:
        LXI     D, MSGF2
        JMP     FAILOUT
FAIL3:
        LXI     D, MSGF3
        JMP     FAILOUT

FAILOUT:
        PUSH    D
        LXI     D, MSGFAIL
        MVI     C, F_PRTSTR
        CALL    BDOS
        POP     D
        MVI     C, F_PRTSTR
        CALL    BDOS
        ; Print actual HL value
        LXI     D, MSGGOT
        MVI     C, F_PRTSTR
        CALL    BDOS
        LHLD    RETHL
        CALL    PRTHL
        LXI     D, MSGCRLF
        MVI     C, F_PRTSTR
        CALL    BDOS
        RET

; Print HL as 4-digit hex
PRTHL:
        MOV     A, H
        CALL    PRTHEX
        MOV     A, L
        ; Fall through
PRTHEX:
        PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        CALL    PRTNYB
        POP     PSW
PRTNYB:
        ANI     0FH
        ADI     '0'
        CPI     '9'+1
        JC      PRN1
        ADI     7
PRN1:
        MOV     E, A
        MVI     C, 2            ; CONOUT
        CALL    BDOS
        RET

; Storage
RETHL:  DW      0
RETA:   DB      0
RETB:   DB      0

; Messages
MSGHDR: DB      'BDOS Version Test (F12)', CR, LF, '$'
MSGPASS: DB     'PASS: Version = 0022H (CP/M 2.2)', CR, LF, '$'
MSGFAIL: DB     'FAIL: ', '$'
MSGF1:  DB      'HL != 0022H', '$'
MSGF2:  DB      'A != 22H', '$'
MSGF3:  DB      'B != 00H', '$'
MSGGOT: DB      ' Got HL=', '$'
MSGCRLF: DB     CR, LF, '$'

        END     START
