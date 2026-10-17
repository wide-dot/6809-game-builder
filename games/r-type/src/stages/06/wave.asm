;$00,$00,ObjID_stageInit,$00,$0B
;$00,$00,ObjID_objectPurge,$00,$00
	fcb   $00,$10,ObjID_newt,$01,$41
	fcb   $00,$10,ObjID_newt,$01,$55
;$00,$28,ObjID_cyclingPalette,$00,$12
;$00,$28,ObjID_cyclingPalette,$00,$13
;$00,$28,ObjID_cyclingPalette,$00,$14
;$00,$28,ObjID_cyclingPalette,$00,$15
;$00,$28,ObjID_cyclingPalette,$00,$16
	fcb   $00,$E0,ObjID_pow,$00,$06
	fcb   $01,$1E,ObjID_dop,$00,$22
	fcb   $01,$48,ObjID_dop,$00,$20
	fcb   $01,$90,ObjID_newt,$00,$17
	fcb   $01,$90,ObjID_newt,$00,$12
	fcb   $01,$BE,ObjID_dop,$00,$20
	fcb   $02,$04,ObjID_dop,$00,$20
	fcb   $02,$28,ObjID_newt,$00,$10
	fcb   $02,$34,ObjID_dop,$00,$20
	fcb   $02,$76,ObjID_dop,$00,$20
	fcb   $02,$A8,ObjID_newt,$00,$15
	fcb   $02,$E2,ObjID_dop,$00,$20
	fcb   $03,$A6,ObjID_dop,$01,$2F
	fcb   $03,$D4,ObjID_newt,$00,$07
	fcb   $04,$0A,ObjID_dop,$00,$27
	fcb   $04,$44,ObjID_dop,$01,$2E
	fcb   $04,$7A,ObjID_dop,$01,$20
	fcb   $04,$C8,ObjID_bink,$00,$67
	fcb   $04,$DA,ObjID_dop,$00,$29
	fcb   $04,$DC,ObjID_bink,$00,$64
	fcb   $05,$00,ObjID_dop,$00,$2D
	fcb   $05,$08,ObjID_bink,$00,$64
	fcb   $05,$14,ObjID_bink,$00,$64
	fcb   $05,$28,ObjID_dop,$00,$29
	fcb   $05,$66,ObjID_newt,$00,$10
	fcb   $05,$78,ObjID_dop,$01,$20
	fcb   $05,$8C,ObjID_dop,$00,$29
	fcb   $05,$EE,ObjID_dop,$00,$29
	fcb   $05,$F8,ObjID_newt,$00,$12
	fcb   $06,$54,ObjID_dop,$01,$24
	fcb   $06,$70,ObjID_newt,$00,$0F
	fcb   $06,$90,ObjID_dop,$01,$24
	fcb   $06,$90,ObjID_dop,$01,$20
	fcb   $06,$A0,ObjID_dop,$00,$69
	fcb   $06,$E0,ObjID_dop,$01,$24
	fcb   $07,$34,ObjID_dop,$01,$2B
	fcb   $07,$80,ObjID_dop,$01,$2B
	fcb   $08,$32,ObjID_dop,$00,$20
	fcb   $09,$4A,ObjID_dop,$00,$39
	fcb   $09,$50,ObjID_newt,$01,$15
	fcb   $09,$6C,ObjID_dop,$00,$26
	fcb   $09,$7C,ObjID_dop,$01,$25
	fcb   $0A,$46,ObjID_dop,$01,$2F
	fcb   $0B,$18,ObjID_bink,$00,$62
	fcb   $0B,$5E,ObjID_dop,$01,$26
	fcb   $0C,$10,ObjID_bink,$00,$61
	fcb   $0C,$16,ObjID_bink,$01,$60
	fcb   $0C,$30,ObjID_bink,$00,$62
	fcb   $0C,$3A,ObjID_bink,$01,$60
	fcb   $0C,$40,ObjID_bink,$00,$62
	fcb   $0C,$56,ObjID_bink,$01,$60
	fcb   $0C,$80,ObjID_checkpoint,$00,$0C
	fcb   $0C,$80,ObjID_bink,$01,$60
	fcb   $0C,$96,ObjID_bink,$01,$60
;$0C,$A8,ObjID_cyclingPalette,$00,$12
;$0C,$A8,ObjID_cyclingPalette,$00,$13
;$0C,$A8,ObjID_cyclingPalette,$00,$14
;$0C,$A8,ObjID_cyclingPalette,$00,$15
;$0C,$A8,ObjID_cyclingPalette,$00,$16
	fcb   $0C,$AC,ObjID_bink,$01,$60
	fcb   $0C,$C0,ObjID_dop,$00,$21
	fcb   $0C,$C2,ObjID_bink,$01,$60
	fcb   $0C,$D8,ObjID_bink,$01,$70
	fcb   $0C,$EE,ObjID_bink,$01,$60
	fcb   $0D,$04,ObjID_bink,$01,$50
	fcb   $0D,$1A,ObjID_bink,$01,$60
	fcb   $0D,$30,ObjID_bink,$01,$50
	fcb   $0D,$46,ObjID_bink,$01,$60
	fcb   $0D,$48,ObjID_bink,$01,$60
	fcb   $0D,$4A,ObjID_pow,$00,$15
	fcb   $0D,$5E,ObjID_bink,$01,$50
	fcb   $0D,$74,ObjID_bink,$01,$60
	fcb   $0D,$8A,ObjID_bink,$01,$50
	fcb   $0D,$A0,ObjID_bink,$01,$50
	fcb   $0D,$B6,ObjID_bink,$01,$50
	fcb   $0D,$CC,ObjID_bink,$01,$60
	fcb   $0D,$E2,ObjID_bink,$01,$50
	fcb   $0D,$F8,ObjID_bink,$01,$50
	fcb   $0E,$0E,ObjID_bink,$01,$50
	fcb   $0E,$10,ObjID_bink,$01,$60
	fcb   $0E,$26,ObjID_bink,$01,$40
	fcb   $0E,$3C,ObjID_bink,$01,$50
	fcb   $0E,$52,ObjID_bink,$01,$50
	fcb   $0E,$68,ObjID_dop,$01,$24
	fcb   $0E,$74,ObjID_newt,$00,$17
	fcb   $0E,$9C,ObjID_dop,$01,$24
	fcb   $0E,$D6,ObjID_newt,$00,$02
	fcb   $0E,$D8,ObjID_dop,$01,$24
	fcb   $0F,$00,ObjID_newt,$00,$14
	fcb   $0F,$14,ObjID_dop,$01,$24
	fcb   $0F,$3C,ObjID_pow,$00,$06
	fcb   $0F,$50,ObjID_dop,$01,$24
	fcb   $0F,$5C,ObjID_newt,$00,$00
	fcb   $0F,$A0,ObjID_dop,$01,$24
	fcb   $0F,$F0,ObjID_newt,$00,$17
	fcb   $10,$A6,ObjID_newt,$00,$02
	fcb   $10,$A6,ObjID_newt,$00,$14
	fcb   $10,$CC,ObjID_dop,$01,$2B
	fcb   $11,$26,ObjID_dop,$01,$2B
	fcb   $11,$30,ObjID_dop,$01,$32
	fcb   $11,$F8,ObjID_dop,$00,$20
	fcb   $11,$F8,ObjID_dop,$01,$24
	fcb   $12,$10,ObjID_newt,$01,$11
	fcb   $12,$10,ObjID_newt,$01,$15
	fcb   $12,$70,ObjID_dop,$01,$22
	fcb   $12,$FC,ObjID_dop,$01,$2D
	fcb   $13,$14,ObjID_newt,$00,$10
	fcb   $13,$18,ObjID_pow,$00,$37
;$13,$88,ObjID_39,$00,$00
;   (ObjID 39, 40:F366 : la transition musicale de la borne — au premier
;   appel 0x21 puis 0x20 384 trames apres, ensuite les pieces du stage, table
;   0x8C16 tout de suite et 0x8C0C 256 trames apres (stage 7 : 0x15 a 4800,
;   0x14 a 5056, mesure sous MAME). Notre arrangement ADNZ n'a qu'un morceau
;   par stage : pas de piece de transition a jouer.)
	fcb   $13,$C4,ObjID_dop,$00,$2A
	fcb   $14,$98,ObjID_newt,$00,$17
	fcb   $14,$A0,ObjID_newt,$00,$10
	fcb   $14,$F8,ObjID_dopswarm,$00,$00
	fcb   $14,$FC,ObjID_bossmusic,$00,$00
	fdb   $FFFF
