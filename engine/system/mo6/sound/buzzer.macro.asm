_buzzer.disable MACRO
	lda   map.STATUS
	ora   #map.STATUS.CUTBUZZER
	sta   map.STATUS
 ENDM

_buzzer.enable MACRO
	lda   map.STATUS
	anda  #^map.STATUS.CUTBUZZER
	sta   map.STATUS
 ENDM
