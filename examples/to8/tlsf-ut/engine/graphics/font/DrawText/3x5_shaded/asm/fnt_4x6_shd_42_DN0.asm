
	OPT C,CT
adr_fnt_4x6_shd_42_DN0
	LEAU 140,U

	LDA 20,U
	ANDA #$F0
	ORA #$03
	STA 20,U
	LDA -20,U
	ANDA #$0F
	ORA #$30
	STA -20,U

	LEAU -$2000-40,U

	LDA #$30
	STA 20,U
	STA -20,U
	STA -60,U
	LDA 100,U
	ANDA #$0F

	STA 100,U
	LDA 60,U
	ANDA #$F0

	STA 60,U
	LDA -100,U
	ANDA #$0F
	ORA #$30
	STA -100,U
	RTS

