
	OPT C,CT
adr_fnt_4x6_shd_33_DN0
	LEAU 100,U

	LDA #$30
	STA 60,U
	STA 20,U
	LDA #$33
	STA -20,U
	LDA 100,U
	ANDA #$F0

	STA 100,U
	LDA -60,U
	ANDA #$0F
	ORA #$30
	STA -60,U
	LDA -100,U
	ANDA #$F0
	ORA #$03
	STA -100,U

	LEAU -$2000+20,U

	LDA 80,U
	ANDA #$F0

	STA 80,U
	LDA -80,U
	ANDA #$0F
	ORA #$30
	STA -80,U
	LDA #$30
	STA 40,U
	STA ,U
	STA -40,U
	RTS

