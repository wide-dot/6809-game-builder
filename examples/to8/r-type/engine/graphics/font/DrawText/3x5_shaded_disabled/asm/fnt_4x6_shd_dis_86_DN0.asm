
	OPT C,CT
adr_fnt_4x6_shd_dis_86_DN0
	LEAU 100,U

	LDA 60,U
	ANDA #$F0
	ORA #$01
	STA 60,U
	LDA -60,U
	ANDA #$0F
	ORA #$10
	STA -60,U
	LDA #$11
	STA 20,U
	LDA #$10
	STA -20,U

	LEAU -$2000+20,U

	CLRA
	STA 40,U
	LDA 80,U
	ANDA #$0F

	STA 80,U
	LDA -80,U
	ANDA #$0F
	ORA #$10
	STA -80,U
	LDA #$10
	STA ,U
	STA -40,U
	RTS

