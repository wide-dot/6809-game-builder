;*******************************************************************************
; Thomson - keyboard scan code values
; ------------------------------------------------------------------------------
;
;*******************************************************************************

 IFNDEF scancode.const.asm
scancode.const.asm equ 1

scancode.LEFT  equ   8
scancode.RIGHT equ   9
scancode.DOWN  equ   10
scancode.UP    equ   11
scancode.ENTER equ   13
scancode.SPACE equ   32
scancode.0     equ   48
scancode.1     equ   49
scancode.2     equ   50
scancode.3     equ   51
scancode.4     equ   52
scancode.5     equ   53
scancode.6     equ   54
scancode.7     equ   55
scancode.8     equ   56
scancode.9     equ   57
scancode.A     equ   65
scancode.B     equ   66
scancode.C     equ   67
scancode.D     equ   68
scancode.E     equ   69
scancode.F     equ   70
scancode.G     equ   71
scancode.H     equ   72
scancode.I     equ   73
scancode.J     equ   74
scancode.K     equ   75
scancode.L     equ   76
scancode.M     equ   77
scancode.N     equ   78
scancode.O     equ   79
scancode.P     equ   80
scancode.Q     equ   81
scancode.R     equ   82
scancode.S     equ   83
scancode.T     equ   84
scancode.U     equ   85
scancode.V     equ   86
scancode.W     equ   87
scancode.X     equ   88
scancode.Y     equ   89
scancode.Z     equ   90
scancode.a     equ   97
scancode.b     equ   98
scancode.c     equ   99
scancode.d     equ   100
scancode.e     equ   101
scancode.f     equ   102
scancode.g     equ   103
scancode.h     equ   104
scancode.i     equ   105
scancode.j     equ   106
scancode.k     equ   107
scancode.l     equ   108
scancode.m     equ   109
scancode.n     equ   110
scancode.o     equ   111
scancode.p     equ   112
scancode.q     equ   113
scancode.r     equ   114
scancode.s     equ   115
scancode.t     equ   116
scancode.u     equ   117
scancode.v     equ   118
scancode.w     equ   119
scancode.x     equ   120
scancode.y     equ   121
scancode.z     equ   122

; BASIC shortcut keys
scancode.BAS_INSTR        equ   $82
scancode.BAS_CLEAR        equ   $83
scancode.BAS_CSRLIN       equ   $85
scancode.BAS_CLS          equ   $86
scancode.BAS_CONSOLE      equ   $87
scancode.BAS_CONT         equ   $88
scancode.BAS_FRE          equ   $89
scancode.BAS_GR_DOLLAR    equ   $8A
scancode.BAS_INKEY_DOLLAR equ   $8B
scancode.BAS_ATTRB        equ   $8C
scancode.BAS_MERGE        equ   $8D
scancode.BAS_RETURN       equ   $8E
scancode.BAS_LINE         equ   $8F
scancode.BAS_TRON         equ   $90
scancode.BAS_EXEC         equ   $91
scancode.BAS_LEFT_DOLLAR  equ   $92
scancode.BAS_RESTORE      equ   $93
scancode.BAS_LOCATE       equ   $94
scancode.BAS_PRINT        equ   $95
scancode.BAS_SCREEN       equ   $96
scancode.BAS_BOX          equ   $97
scancode.BAS_SKIPF        equ   $98
scancode.BAS_DATA         equ   $99
scancode.BAS_MID_DOLLAR   equ   $9A
scancode.BAS_READ         equ   $9B
scancode.BAS_ELSE         equ   $9C
scancode.BAS_PSET         equ   $9D
scancode.BAS_DELETE       equ   $9E
scancode.BAS_MOTOR        equ   $9F
scancode.BAS_TROFF        equ   $A0
scancode.BAS_COLOR        equ   $A1
scancode.BAS_RIGHT_DOLLAR equ   $A2
scancode.BAS_STIG         equ   $A3
scancode.BAS_RUN          equ   $A4
scancode.BAS_ON           equ   $A5
scancode.BAS_FOR          equ   $A6
scancode.BAS_LIST         equ   $A7
scancode.BAS_PLAY         equ   $A8
scancode.BAS_PEEK         equ   $A9
scancode.BAS_INPUT        equ   $AA
scancode.BAS_STICK        equ   $AB
scancode.BAS_TO           equ   $AC
scancode.BAS_IF           equ   $AD
scancode.BAS_GO           equ   $AE
scancode.BAS_RND          equ   $AF
scancode.BAS_LOAD         equ   $B0
scancode.BAS_COMMA        equ   $B1
scancode.BAS_INPEN        equ   $B2
scancode.BAS_PTRIG        equ   $B3
scancode.BAS_STEP         equ   $B4
scancode.BAS_DIM          equ   $B5
scancode.BAS_SUB          equ   $B6
scancode.BAS_THEN         equ   $B7
scancode.BAS_SAVE         equ   $B8
scancode.BAS_NEXT         equ   $B9

    ENDC