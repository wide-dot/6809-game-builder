
	OPT C,CT
adr_fnt_4x6_shd_60_DN0
	LDA 80,U
	ANDA #$F0
	ORA #$03
	STA 80,U
	LDA 40,U
	ANDA #$0F
	ORA #$30
	STA 40,U

	LEAU -$2000+140,U

	LDA 20,U
	ANDA #$F0

	STA 20,U
	LDA -20,U
	ANDA #$0F
	ORA #$30
	STA -20,U
	RTS

