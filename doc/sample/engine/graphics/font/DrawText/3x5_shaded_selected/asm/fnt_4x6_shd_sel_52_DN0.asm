
	OPT C,CT
adr_fnt_4x6_shd_sel_52_DN0
	LEAU 80,U

	LDA #$ff
	STA -80,U
	LDA 80,U
	ANDA #$F0
	ORA #$0f
	STA 80,U
	LDA 40,U
	ANDA #$F0
	ORA #$0f
	STA 40,U
	LDA ,U
	ANDA #$F0
	ORA #$0f
	STA ,U
	LDA -40,U
	ANDA #$F0
	ORA #$0f
	STA -40,U

	LEAU -$2000+20,U

	LDA 100,U
	ANDA #$0F

	STA 100,U
	LDA 60,U
	ANDA #$0F

	STA 60,U
	LDA 20,U
	ANDA #$0F

	STA 20,U
	LDA -20,U
	ANDA #$0F

	STA -20,U
	LDA -100,U
	ANDA #$0F
	ORA #$f0
	STA -100,U
	CLRA
	STA -60,U
	RTS

