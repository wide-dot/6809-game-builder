
	OPT C,CT
adr_fnt_4x6_shd_sel_49_DN0
	LEAU 80,U

	LDA #$ff
	STA 40,U
	LDA #$f0
	STA ,U
	LDA 80,U
	ANDA #$F0
	ORA #$0f
	STA 80,U
	LDA -40,U
	ANDA #$0F
	ORA #$f0
	STA -40,U
	LDA -80,U
	ANDA #$F0
	ORA #$0f
	STA -80,U

	LEAU -$2000+40,U

	CLRA
	STA 80,U
	LDA #$f0
	STA 40,U
	STA ,U
	STA -40,U
	LDA -80,U
	ANDA #$0F
	ORA #$f0
	STA -80,U
	RTS

