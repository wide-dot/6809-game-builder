
	OPT C,CT
adr_fnt_4x6_shd_sel_79_DN0
	LEAU 100,U

	LDA 60,U
	ANDA #$F0
	ORA #$0f
	STA 60,U
	LDA -20,U
	ANDA #$0F
	ORA #$f0
	STA -20,U
	LDA -60,U
	ANDA #$F0
	ORA #$0f
	STA -60,U
	LDA #$f0
	STA 20,U

	LEAU -$2000+40,U

	LDA #$f0
	STA -20,U
	LDA 60,U
	ANDA #$0F

	STA 60,U
	LDA 20,U
	ANDA #$F0

	STA 20,U
	LDA -60,U
	ANDA #$0F
	ORA #$f0
	STA -60,U
	RTS

