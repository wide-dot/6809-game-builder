
	OPT C,CT
adr_fnt_4x6_shd_sel_21_DN0
	LEAU 100,U

	LDA #$ff
	STA 60,U
	STA -20,U
	LDA #$f0
	STA -60,U
	LDA #$ff
	STA -100,U
	LDA 100,U
	ANDA #$F0

	STA 100,U
	LDA 20,U
	ANDA #$F0

	STA 20,U

	LEAU -$2000,U

	CLRA
	STA -60,U
	LDA 100,U
	ANDA #$0F

	STA 100,U
	LDA 60,U
	ANDA #$F0

	STA 60,U
	LDA 20,U
	ANDA #$0F
	ORA #$f0
	STA 20,U
	LDA -100,U
	ANDA #$0F
	ORA #$f0
	STA -100,U
	RTS

