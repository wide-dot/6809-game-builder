
	OPT C,CT
adr_fnt_4x6_shd_28_DN0
	LDA 120,U
	ANDA #$F0
	ORA #$03
	STA 120,U
	LDA 80,U
	ANDA #$0F
	ORA #$30
	STA 80,U
	LDA 40,U
	ANDA #$F0
	ORA #$03
	STA 40,U

	LEAU -$2000+100,U

	LDA 100,U
	ANDA #$F0

	STA 100,U
	LDA 60,U
	ANDA #$0F
	ORA #$30
	STA 60,U
	LDA -20,U
	ANDA #$0F

	STA -20,U
	LDA -60,U
	ANDA #$F0

	STA -60,U
	LDA -100,U
	ANDA #$0F
	ORA #$30
	STA -100,U
	RTS

