
	OPT C,CT
adr_fnt_4x6_shd_sel_92_DN0
	LEAU 80,U

	LDA 80,U
	ANDA #$F0
	ORA #$0f
	STA 80,U
	LDA 40,U
	ANDA #$F0
	ORA #$0f
	STA 40,U
	LDA -40,U
	ANDA #$F0
	ORA #$0f
	STA -40,U
	LDA -80,U
	ANDA #$F0
	ORA #$0f
	STA -80,U

	LEAU -$2000+40,U

	LDA 80,U
	ANDA #$0F

	STA 80,U
	LDA 40,U
	ANDA #$0F

	STA 40,U
	LDA -40,U
	ANDA #$0F

	STA -40,U
	LDA -80,U
	ANDA #$0F

	STA -80,U
	RTS

