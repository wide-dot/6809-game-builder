;*******************************************************************************
; TO8 key numbers : what the keyboard's 6804 sends in bits 6-0 of its frame
; (keyboard.fast). $38 and $48 are no key ; Shift and CNT send no frame of
; their own, F6-F10 are Shift + F1-F5.
;*******************************************************************************

 IFNDEF scancode.const.asm
scancode.const.asm equ 1

scancode.F2                equ   $00
scancode.6                 equ   $01
scancode.Y                 equ   $02
scancode.H                 equ   $03
scancode.UP                equ   $04
scancode.RIGHT             equ   $05
scancode.RAZ               equ   $06
scancode.N                 equ   $07
scancode.F3                equ   $08
scancode.5                 equ   $09
scancode.T                 equ   $0A
scancode.G                 equ   $0B
scancode.EQUALS            equ   $0C
scancode.LEFT              equ   $0D
scancode.INS               equ   $0E
scancode.B                 equ   $0F
scancode.F4                equ   $10
scancode.4                 equ   $11
scancode.R                 equ   $12
scancode.F                 equ   $13
scancode.ACC               equ   $14
scancode.PAD_1             equ   $15
scancode.EFF               equ   $16
scancode.V                 equ   $17
scancode.F5                equ   $18
scancode.3                 equ   $19
scancode.E                 equ   $1A
scancode.D                 equ   $1B
scancode.PAD_7             equ   $1C
scancode.PAD_4             equ   $1D
scancode.PAD_0             equ   $1E
scancode.C                 equ   $1F
scancode.F1                equ   $20
scancode.2                 equ   $21
scancode.Z                 equ   $22
scancode.S                 equ   $23
scancode.PAD_8             equ   $24
scancode.PAD_2             equ   $25
scancode.PAD_PERIOD        equ   $26
scancode.X                 equ   $27
scancode.HASH              equ   $28
scancode.1                 equ   $29
scancode.A                 equ   $2A
scancode.Q                 equ   $2B
scancode.LEFT_BRACKET      equ   $2C
scancode.PAD_5             equ   $2D
scancode.PAD_6             equ   $2E
scancode.W                 equ   $2F
scancode.STOP              equ   $30
scancode.7                 equ   $31
scancode.U                 equ   $32
scancode.J                 equ   $33
scancode.SPACE             equ   $34
scancode.PAD_9             equ   $35
scancode.PAD_ENTER         equ   $36
scancode.COMMA             equ   $37
scancode.8                 equ   $39
scancode.I                 equ   $3A
scancode.K                 equ   $3B
scancode.DOLLAR            equ   $3C
scancode.DOWN              equ   $3D
scancode.RIGHT_BRACKET     equ   $3E
scancode.SEMICOLON         equ   $3F
scancode.CAPS_LOCK         equ   $40
scancode.9                 equ   $41
scancode.O                 equ   $42
scancode.L                 equ   $43
scancode.MINUS             equ   $44
scancode.U_GRAVE           equ   $45
scancode.ENTER             equ   $46
scancode.COLON             equ   $47
scancode.0                 equ   $49
scancode.P                 equ   $4A
scancode.M                 equ   $4B
scancode.PARENTHESIS_RIGHT equ   $4C
scancode.CARET             equ   $4D
scancode.PAD_3             equ   $4E
scancode.GREATER_THAN      equ   $4F

; the frame's modifiers, in D as keyboard.fast returns it
scancode.SHIFT             equ   $80   ; in B
scancode.CNT               equ   $01   ; in A

 ENDC
