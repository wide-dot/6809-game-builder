
	OPT C,CT
adr_fnt_4x6_shd_90_DN0
	LEAU 120,U

	LDA #$33
	STA 40,U
	STA ,U
	STA -80,U
	LDA 80,U
	ANDA #$F0

	STA 80,U
	LDA -40,U
	ANDA #$F0
	ORA #$03
	STA -40,U

	LEAU -$2000,U

	LDA 40,U
	ANDA #$0F
	ORA #$30
	STA 40,U
	LDA -80,U
	ANDA #$0F
	ORA #$30
	STA -80,U
	CLRA
	STA 80,U
	STA ,U
	LDA #$30
	STA -40,U
	RTS

