
	OPT C,CT
adr_fnt_4x6_shd_51_DN0
	LEAU 100,U

	LDA 100,U
	ANDA #$F0

	STA 100,U
	LDA -20,U
	ANDA #$F0
	ORA #$03
	STA -20,U
	LDA -60,U
	ANDA #$0F
	ORA #$30
	STA -60,U
	LDA -100,U
	ANDA #$F0
	ORA #$03
	STA -100,U
	LDA #$33
	STA 60,U

	LEAU -$2000,U

	LDA 100,U
	ANDA #$0F

	STA 100,U
	LDA 60,U
	ANDA #$F0

	STA 60,U
	LDA 20,U
	ANDA #$0F
	ORA #$30
	STA 20,U
	LDA -100,U
	ANDA #$0F
	ORA #$30
	STA -100,U
	CLRA
	STA -60,U
	RTS

