
	OPT C,CT
adr_fnt_4x6_shd_sel_69_DN0
	LEAU 100,U

	LDA #$ff
	STA 20,U
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

	LEAU -$2000+20,U

	LDA 40,U
	ANDA #$0F
	ORA #$f0
	STA 40,U
	LDA ,U
	ANDA #$F0

	STA ,U
	LDA -80,U
	ANDA #$0F
	ORA #$f0
	STA -80,U
	CLRA
	STA 80,U
	LDA #$f0
	STA -40,U
	RTS

