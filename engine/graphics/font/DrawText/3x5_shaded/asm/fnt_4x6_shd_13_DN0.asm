
	OPT C,CT
adr_fnt_4x6_shd_13_DN0
	LDA #$33
	STA 80,U
	LDA 120,U
	ANDA #$F0

	STA 120,U

	LEAU -$2000,U
	LDA 80,U
	ANDA #$0F
	ORA #$30
	STA 80,U
	CLRA
	STA 120,U
	RTS

