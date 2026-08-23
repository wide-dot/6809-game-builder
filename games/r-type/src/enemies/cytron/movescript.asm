;******************************************************************************
; cytron — scripts de mouvement, EXPORTES de la rom arcade
; par re.arcade.r-type (--extract-movescript). Ne pas editer.
;
; Table des variantes : segment de donnees 0x1000, offset 0x92AC, 16 entrees de 4 octets (pointeur de script, puis octet de
; variante = nombre d'octets de deplacement consommes par trame).
; Le quartet HAUT du descripteur de spawn choisit l'entree.
;
; Format des octets de segment, bits lus du poids fort au faible :
;   7    pose l'image, les bits bas portent son index
;   6,5  01 = x++   11 = x--
;   4,3  01 = y--   11 = y++
;   2    fin de segment, on lit la commande suivante
;******************************************************************************

; --- la table des variantes -------------------------------------------
cytron.script.tbl
	fdb   ref_19D32   ; variante 0, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19D68   ; variante 1, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19DA4   ; variante 2, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19E0A   ; variante 3, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19E4E   ; variante 4, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19EF8   ; variante 5, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19F2E   ; variante 6, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19F7C   ; variante 7, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19FBC   ; variante 8, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_19FDE   ; variante 9, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_1A000   ; variante 10, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_1A046   ; variante 11, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_1A086   ; variante 12, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_1A086   ; variante 13, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_1A086   ; variante 14, 3 octets par trame
	fcb   3
	fcb   0
	fdb   ref_1A086   ; variante 15, 3 octets par trame
	fcb   3
	fcb   0

; --- les scripts : des listes de commandes -----------------------------
ref_19D32	fdb   ref_1AA5C
ref_19D34	fdb   ref_1AA5C
ref_19D36	fdb   ref_1AA5C
ref_19D38	fdb   ref_1AA5C
ref_19D3A	fdb   ref_1AA5C
ref_19D3C	fdb   ref_1AA5C
ref_19D3E	fdb   ref_1AA5C
ref_19D40	fdb   ref_1AA5C
ref_19D42	fdb   ref_1AA5C
ref_19D44	fdb   ref_1AA5C
ref_19D46	fdb   ref_1AA5C
ref_19D48	fdb   ref_1AA5C
ref_19D4A	fdb   ref_1AA5C
ref_19D4C	fdb   ref_1AA5C
ref_19D4E	fdb   ref_1AA5C
ref_19D50	fdb   ref_1AA5C
ref_19D52	fdb   ref_1AA5C
ref_19D54	fdb   ref_1AA5C
ref_19D56	fdb   ref_1AA5C
ref_19D58	fdb   ref_1AA5C
ref_19D5A	fdb   ref_1AA5C
ref_19D5C	fdb   ref_1AA5C
ref_19D5E	fdb   ref_1AA5C
ref_19D60	fdb   ref_1AA5C
ref_19D62	fdb   ref_1AA5C
ref_19D64	fdb   ref_1AA5C
ref_19D66	fdb   $0000                 ; fin de script

ref_19D68	fdb   ref_1AA6D
ref_19D6A	fdb   ref_1AA6D
ref_19D6C	fdb   ref_1AA6D
ref_19D6E	fdb   ref_1AA6D
ref_19D70	fdb   ref_1AA6D
ref_19D72	fdb   ref_1AA6D
ref_19D74	fdb   ref_1AA6D
ref_19D76	fdb   ref_1AA6D
ref_19D78	fdb   ref_1AA6D
ref_19D7A	fdb   ref_1AA6D
ref_19D7C	fdb   ref_1AA6D
ref_19D7E	fdb   ref_1AA6D
ref_19D80	fdb   ref_1AA6D
ref_19D82	fdb   ref_1AA6D
ref_19D84	fdb   ref_1AA6D
ref_19D86	fdb   ref_1AA6D
ref_19D88	fdb   ref_1AA6D
ref_19D8A	fdb   ref_1AA6D
ref_19D8C	fdb   ref_1B221
ref_19D8E	fdb   ref_1B23D
ref_19D90	fdb   ref_1B24F
ref_19D92	fdb   ref_1B260
ref_19D94	fdb   ref_1B10A
ref_19D96	fdb   ref_1AAA0
ref_19D98	fdb   ref_1AAA0
ref_19D9A	fdb   ref_1AAA0
ref_19D9C	fdb   ref_1AAA0
ref_19D9E	fdb   ref_1AAA0
ref_19DA0	fdb   ref_1AAA0
ref_19DA2	fdb   $0000                 ; fin de script

ref_19DA4	fdb   ref_1B356
ref_19DA6	fdb   ref_1B367
ref_19DA8	fdb   ref_1B379
ref_19DAA	fdb   ref_1B395
ref_19DAC	fdb   ref_1B3B1
ref_19DAE	fdb   ref_1AAA0
ref_19DB0	fdb   ref_1AAA0
ref_19DB2	fdb   ref_1AAA0
ref_19DB4	fdb   ref_1AAA0
ref_19DB6	fdb   ref_1AAA0
ref_19DB8	fdb   ref_1AAA0
ref_19DBA	fdb   ref_1AAA0
ref_19DBC	fdb   ref_1AAA0
ref_19DBE	fdb   ref_1AAA0
ref_19DC0	fdb   ref_1B139
ref_19DC2	fdb   ref_1B14B
ref_19DC4	fdb   ref_1B167
ref_19DC6	fdb   ref_1B183
ref_19DC8	fdb   ref_1B195
ref_19DCA	fdb   ref_1B1A6
ref_19DCC	fdb   ref_1B1C4
ref_19DCE	fdb   ref_1B1E2
ref_19DD0	fdb   ref_1B1F3
ref_19DD2	fdb   ref_1B205
ref_19DD4	fdb   ref_1AA6D
ref_19DD6	fdb   ref_1AA6D
ref_19DD8	fdb   ref_1AA6D
ref_19DDA	fdb   ref_1AA6D
ref_19DDC	fdb   ref_1AA6D
ref_19DDE	fdb   ref_1AA6D
ref_19DE0	fdb   ref_1AA6D
ref_19DE2	fdb   ref_1AA6D
ref_19DE4	fdb   ref_1AA6D
ref_19DE6	fdb   ref_1AA6D
ref_19DE8	fdb   ref_1AA6D
ref_19DEA	fdb   ref_1AA6D
ref_19DEC	fdb   ref_1B221
ref_19DEE	fdb   ref_1B23D
ref_19DF0	fdb   ref_1B24F
ref_19DF2	fdb   ref_1B260
ref_19DF4	fdb   ref_1B10A
ref_19DF6	fdb   ref_1B128
ref_19DF8	fdb   ref_1B139
ref_19DFA	fdb   ref_1AAE4
ref_19DFC	fdb   ref_1AAE4
ref_19DFE	fdb   ref_1AAE4
ref_19E00	fdb   ref_1AAE4
ref_19E02	fdb   ref_1AAE4
ref_19E04	fdb   ref_1AAE4
ref_19E06	fdb   ref_1AAE4
ref_19E08	fdb   $0000                 ; fin de script

ref_19E0A	fdb   ref_1ACB6
ref_19E0C	fdb   ref_1ACCE
ref_19E0E	fdb   ref_1ACE9
ref_19E10	fdb   ref_1AD11
ref_19E12	fdb   ref_1AD39
ref_19E14	fdb   ref_1AAC2
ref_19E16	fdb   ref_1AAC2
ref_19E18	fdb   ref_1AAC2
ref_19E1A	fdb   ref_1AAC2
ref_19E1C	fdb   ref_1AAC2
ref_19E1E	fdb   ref_1AAC2
ref_19E20	fdb   ref_1AAC2
ref_19E22	fdb   ref_1B446
ref_19E24	fdb   ref_1B456
ref_19E26	fdb   ref_1B466
ref_19E28	fdb   ref_1B46F
ref_19E2A	fdb   ref_1B479
ref_19E2C	fdb   ref_1B488
ref_19E2E	fdb   ref_1B497
ref_19E30	fdb   ref_1B4A1
ref_19E32	fdb   ref_1B4AA
ref_19E34	fdb   ref_1B3F2
ref_19E36	fdb   ref_1AAA0
ref_19E38	fdb   ref_1AAA0
ref_19E3A	fdb   ref_1AAA0
ref_19E3C	fdb   ref_1AAA0
ref_19E3E	fdb   ref_1AAA0
ref_19E40	fdb   ref_1AAA0
ref_19E42	fdb   ref_1AAA0
ref_19E44	fdb   ref_1B139
ref_19E46	fdb   ref_1B14B
ref_19E48	fdb   ref_1B167
ref_19E4A	fdb   ref_1B183
ref_19E4C	fdb   $0000                 ; fin de script

ref_19E4E	fdb   ref_1AB06
ref_19E50	fdb   ref_1AB06
ref_19E52	fdb   ref_1AB06
ref_19E54	fdb   ref_1AB06
ref_19E56	fdb   ref_1AB06
ref_19E58	fdb   ref_1AB06
ref_19E5A	fdb   ref_1AB06
ref_19E5C	fdb   ref_1AB06
ref_19E5E	fdb   ref_1AB06
ref_19E60	fdb   ref_1AB06
ref_19E62	fdb   ref_1AB06
ref_19E64	fdb   $F004                 ; vitesse : 4 octets par trame
ref_19E66	fdb   ref_1B541
ref_19E68	fdb   ref_1B550
ref_19E6A	fdb   ref_1B55F
ref_19E6C	fdb   ref_1B569
ref_19E6E	fdb   ref_1B572
ref_19E70	fdb   ref_1B4BA
ref_19E72	fdb   ref_1B4CA
ref_19E74	fdb   ref_1B4D3
ref_19E76	fdb   ref_1B4DD
ref_19E78	fdb   ref_1B488
ref_19E7A	fdb   ref_1B497
ref_19E7C	fdb   ref_1B4A1
ref_19E7E	fdb   ref_1B4AA
ref_19E80	fdb   ref_1B3F2
ref_19E82	fdb   ref_1B402
ref_19E84	fdb   ref_1B40B
ref_19E86	fdb   ref_1B55F
ref_19E88	fdb   ref_1B569
ref_19E8A	fdb   ref_1B572
ref_19E8C	fdb   ref_1B4BA
ref_19E8E	fdb   ref_1B4CA
ref_19E90	fdb   ref_1B4D3
ref_19E92	fdb   ref_1B497
ref_19E94	fdb   ref_1B4A1
ref_19E96	fdb   ref_1B4AA
ref_19E98	fdb   ref_1B3F2
ref_19E9A	fdb   ref_1B402
ref_19E9C	fdb   ref_1B40B
ref_19E9E	fdb   ref_1B415
ref_19EA0	fdb   ref_1B424
ref_19EA2	fdb   ref_1B433
ref_19EA4	fdb   ref_1B43D
ref_19EA6	fdb   $F002                 ; vitesse : 2 octets par trame
ref_19EA8	fdb   ref_1AB4A
ref_19EAA	fdb   ref_1AB4A
ref_19EAC	fdb   ref_1AB4A
ref_19EAE	fdb   ref_1AB4A
ref_19EB0	fdb   ref_1AB4A
ref_19EB2	fdb   ref_1AB4A
ref_19EB4	fdb   ref_1AB4A
ref_19EB6	fdb   ref_1AB4A
ref_19EB8	fdb   ref_1AB4A
ref_19EBA	fdb   $F004                 ; vitesse : 4 octets par trame
ref_19EBC	fdb   ref_1B52E
ref_19EBE	fdb   ref_1B537
ref_19EC0	fdb   ref_1B541
ref_19EC2	fdb   ref_1B550
ref_19EC4	fdb   ref_1B55F
ref_19EC6	fdb   ref_1B569
ref_19EC8	fdb   ref_1B572
ref_19ECA	fdb   ref_1B4BA
ref_19ECC	fdb   ref_1B4CA
ref_19ECE	fdb   ref_1B4D3
ref_19ED0	fdb   ref_1B4DD
ref_19ED2	fdb   ref_1B488
ref_19ED4	fdb   ref_1B497
ref_19ED6	fdb   ref_1B4A1
ref_19ED8	fdb   ref_1B4AA
ref_19EDA	fdb   ref_1B3F2
ref_19EDC	fdb   ref_1B402
ref_19EDE	fdb   ref_1B40B
ref_19EE0	fdb   ref_1B55F
ref_19EE2	fdb   ref_1B569
ref_19EE4	fdb   ref_1B572
ref_19EE6	fdb   ref_1B4BA
ref_19EE8	fdb   ref_1B4CA
ref_19EEA	fdb   ref_1B4D3
ref_19EEC	fdb   ref_1B4DD
ref_19EEE	fdb   ref_1B488
ref_19EF0	fdb   ref_1B497
ref_19EF2	fdb   ref_1B4A1
ref_19EF4	fdb   ref_1B4AA
ref_19EF6	fdb   $0000                 ; fin de script

ref_19EF8	fdb   ref_1AA6D
ref_19EFA	fdb   ref_1AA6D
ref_19EFC	fdb   ref_1AA6D
ref_19EFE	fdb   ref_1AA6D
ref_19F00	fdb   ref_1AA6D
ref_19F02	fdb   ref_1AA6D
ref_19F04	fdb   ref_1AA6D
ref_19F06	fdb   ref_1AA6D
ref_19F08	fdb   ref_1AA6D
ref_19F0A	fdb   ref_1AA6D
ref_19F0C	fdb   ref_1AA6D
ref_19F0E	fdb   ref_1AA6D
ref_19F10	fdb   ref_1AA6D
ref_19F12	fdb   ref_1AA6D
ref_19F14	fdb   ref_1AA6D
ref_19F16	fdb   ref_1AA6D
ref_19F18	fdb   ref_1AA6D
ref_19F1A	fdb   ref_1AA6D
ref_19F1C	fdb   ref_1AA6D
ref_19F1E	fdb   ref_1AA6D
ref_19F20	fdb   ref_1AA6D
ref_19F22	fdb   ref_1AA6D
ref_19F24	fdb   ref_1AA6D
ref_19F26	fdb   ref_1AA6D
ref_19F28	fdb   ref_1AA6D
ref_19F2A	fdb   ref_1AA6D
ref_19F2C	fdb   $0000                 ; fin de script

ref_19F2E	fdb   ref_1AB06
ref_19F30	fdb   ref_1AB06
ref_19F32	fdb   ref_1AB06
ref_19F34	fdb   ref_1AB06
ref_19F36	fdb   ref_1AB06
ref_19F38	fdb   ref_1AB06
ref_19F3A	fdb   ref_1AB06
ref_19F3C	fdb   ref_1AB06
ref_19F3E	fdb   ref_1AB06
ref_19F40	fdb   ref_1AB06
ref_19F42	fdb   ref_1AB06
ref_19F44	fdb   ref_1AB06
ref_19F46	fdb   ref_1B183
ref_19F48	fdb   ref_1B195
ref_19F4A	fdb   ref_1B1A6
ref_19F4C	fdb   ref_1B1C4
ref_19F4E	fdb   ref_1B1E2
ref_19F50	fdb   ref_1B1F3
ref_19F52	fdb   ref_1B205
ref_19F54	fdb   ref_1B221
ref_19F56	fdb   ref_1AB17
ref_19F58	fdb   ref_1AB17
ref_19F5A	fdb   ref_1AB17
ref_19F5C	fdb   ref_1AB17
ref_19F5E	fdb   ref_1AB17
ref_19F60	fdb   ref_1AB17
ref_19F62	fdb   ref_1AB17
ref_19F64	fdb   ref_1AB17
ref_19F66	fdb   ref_1AB17
ref_19F68	fdb   ref_1AB17
ref_19F6A	fdb   ref_1AB17
ref_19F6C	fdb   ref_1AB17
ref_19F6E	fdb   ref_1AB17
ref_19F70	fdb   ref_1AB17
ref_19F72	fdb   ref_1AB17
ref_19F74	fdb   ref_1AB17
ref_19F76	fdb   ref_1AB17
ref_19F78	fdb   ref_1AB17
ref_19F7A	fdb   $0000                 ; fin de script

ref_19F7C	fdb   ref_1AA7E
ref_19F7E	fdb   ref_1AA7E
ref_19F80	fdb   ref_1AA7E
ref_19F82	fdb   ref_1AA7E
ref_19F84	fdb   ref_1AA7E
ref_19F86	fdb   ref_1AA7E
ref_19F88	fdb   ref_1AD98
ref_19F8A	fdb   ref_1ADC4
ref_19F8C	fdb   ref_1ADDC
ref_19F8E	fdb   ref_1ADF7
ref_19F90	fdb   ref_1AE1F
ref_19F92	fdb   ref_1AE47
ref_19F94	fdb   ref_1AE62
ref_19F96	fdb   ref_1AE7A
ref_19F98	fdb   ref_1B10A
ref_19F9A	fdb   ref_1B128
ref_19F9C	fdb   ref_1B139
ref_19F9E	fdb   ref_1B14B
ref_19FA0	fdb   ref_1B167
ref_19FA2	fdb   ref_1B183
ref_19FA4	fdb   ref_1B195
ref_19FA6	fdb   ref_1B1A6
ref_19FA8	fdb   ref_1B1C4
ref_19FAA	fdb   ref_1AAB1
ref_19FAC	fdb   ref_1AAB1
ref_19FAE	fdb   ref_1AAB1
ref_19FB0	fdb   ref_1AAB1
ref_19FB2	fdb   ref_1AAB1
ref_19FB4	fdb   ref_1AAB1
ref_19FB6	fdb   ref_1AAB1
ref_19FB8	fdb   ref_1AAB1
ref_19FBA	fdb   $0000                 ; fin de script

ref_19FBC	fdb   ref_1AA8F
ref_19FBE	fdb   ref_1AA8F
ref_19FC0	fdb   ref_1AA8F
ref_19FC2	fdb   ref_1AA8F
ref_19FC4	fdb   ref_1AA8F
ref_19FC6	fdb   ref_1AA8F
ref_19FC8	fdb   ref_1AA8F
ref_19FCA	fdb   ref_1AA8F
ref_19FCC	fdb   ref_1AA8F
ref_19FCE	fdb   ref_1AA8F
ref_19FD0	fdb   ref_1AA8F
ref_19FD2	fdb   ref_1AA8F
ref_19FD4	fdb   ref_1AA8F
ref_19FD6	fdb   ref_1AA8F
ref_19FD8	fdb   ref_1AA8F
ref_19FDA	fdb   ref_1AA8F
ref_19FDC	fdb   $0000                 ; fin de script

ref_19FDE	fdb   ref_1AA7E
ref_19FE0	fdb   ref_1AA7E
ref_19FE2	fdb   ref_1AA7E
ref_19FE4	fdb   ref_1AA7E
ref_19FE6	fdb   ref_1AA7E
ref_19FE8	fdb   ref_1AA7E
ref_19FEA	fdb   ref_1AA7E
ref_19FEC	fdb   ref_1AA7E
ref_19FEE	fdb   ref_1AA7E
ref_19FF0	fdb   ref_1AA7E
ref_19FF2	fdb   ref_1AA7E
ref_19FF4	fdb   ref_1AA7E
ref_19FF6	fdb   ref_1AA7E
ref_19FF8	fdb   ref_1AA7E
ref_19FFA	fdb   ref_1AA7E
ref_19FFC	fdb   ref_1AA7E
ref_19FFE	fdb   $0000                 ; fin de script

ref_1A000	fdb   ref_1AA8F
ref_1A002	fdb   ref_1AA8F
ref_1A004	fdb   ref_1AA8F
ref_1A006	fdb   ref_1AA8F
ref_1A008	fdb   ref_1AA8F
ref_1A00A	fdb   ref_1AA8F
ref_1A00C	fdb   ref_1AA8F
ref_1A00E	fdb   ref_1AA8F
ref_1A010	fdb   ref_1AA8F
ref_1A012	fdb   ref_1AC8A
ref_1A014	fdb   ref_1ACB6
ref_1A016	fdb   ref_1ACCE
ref_1A018	fdb   ref_1ACE9
ref_1A01A	fdb   ref_1AD11
ref_1A01C	fdb   ref_1AD39
ref_1A01E	fdb   ref_1AD54
ref_1A020	fdb   ref_1AD6C
ref_1A022	fdb   ref_1AD98
ref_1A024	fdb   ref_1ADC4
ref_1A026	fdb   ref_1ADDC
ref_1A028	fdb   ref_1ADF7
ref_1A02A	fdb   ref_1AE1F
ref_1A02C	fdb   ref_1AE47
ref_1A02E	fdb   ref_1AE62
ref_1A030	fdb   ref_1AB5B
ref_1A032	fdb   ref_1AB5B
ref_1A034	fdb   ref_1AB5B
ref_1A036	fdb   ref_1AB5B
ref_1A038	fdb   ref_1AB5B
ref_1A03A	fdb   ref_1AB5B
ref_1A03C	fdb   ref_1AB5B
ref_1A03E	fdb   ref_1AB5B
ref_1A040	fdb   ref_1AB5B
ref_1A042	fdb   ref_1AB5B
ref_1A044	fdb   $0000                 ; fin de script

ref_1A046	fdb   ref_1AB17
ref_1A048	fdb   ref_1B2AD
ref_1A04A	fdb   ref_1B2BF
ref_1A04C	fdb   ref_1B2DB
ref_1A04E	fdb   ref_1B2F7
ref_1A050	fdb   ref_1B1F3
ref_1A052	fdb   ref_1B205
ref_1A054	fdb   ref_1B221
ref_1A056	fdb   ref_1B23D
ref_1A058	fdb   ref_1B2AD
ref_1A05A	fdb   ref_1B2BF
ref_1A05C	fdb   ref_1B2DB
ref_1A05E	fdb   ref_1B2F7
ref_1A060	fdb   ref_1AF8B
ref_1A062	fdb   ref_1AFAC
ref_1A064	fdb   ref_1AFD8
ref_1A066	fdb   ref_1B004
ref_1A068	fdb   ref_1B025
ref_1A06A	fdb   ref_1B049
ref_1A06C	fdb   ref_1B071
ref_1A06E	fdb   ref_1B099
ref_1A070	fdb   ref_1B0BD
ref_1A072	fdb   ref_1B0DE
ref_1A074	fdb   ref_1AEA6
ref_1A076	fdb   ref_1AB5B
ref_1A078	fdb   ref_1AB5B
ref_1A07A	fdb   ref_1AB5B
ref_1A07C	fdb   ref_1AB5B
ref_1A07E	fdb   ref_1AB5B
ref_1A080	fdb   ref_1AB5B
ref_1A082	fdb   ref_1AB5B
ref_1A084	fdb   $0000                 ; fin de script

ref_1A086	fdb   ref_1AB28
ref_1A088	fdb   ref_1AB28
ref_1A08A	fdb   ref_1AB28
ref_1A08C	fdb   ref_1AB28
ref_1A08E	fdb   ref_1AB28
ref_1A090	fdb   ref_1AB28
ref_1A092	fdb   ref_1AB28
ref_1A094	fdb   ref_1AB28
ref_1A096	fdb   ref_1AB28
ref_1A098	fdb   ref_1AB28
ref_1A09A	fdb   ref_1B128
ref_1A09C	fdb   ref_1B139
ref_1A09E	fdb   ref_1B14B
ref_1A0A0	fdb   ref_1B167
ref_1A0A2	fdb   ref_1B183
ref_1A0A4	fdb   ref_1B195
ref_1A0A6	fdb   ref_1AB4A
ref_1A0A8	fdb   ref_1AB4A
ref_1A0AA	fdb   ref_1AB4A
ref_1A0AC	fdb   ref_1AB4A
ref_1A0AE	fdb   ref_1AB4A
ref_1A0B0	fdb   ref_1AB4A
ref_1A0B2	fdb   ref_1AB4A
ref_1A0B4	fdb   ref_1AB4A
ref_1A0B6	fdb   ref_1AB4A
ref_1A0B8	fdb   ref_1AB4A
ref_1A0BA	fdb   $0000                 ; fin de script

; --- les segments : les octets de deplacement --------------------------
ref_1AA5C	fcb   %10001000	; image:  8
ref_1AA5D	fcb   %01100000	; x--     
ref_1AA5E	fcb   %01100000	; x--     
ref_1AA5F	fcb   %01100000	; x--     
ref_1AA60	fcb   %01100000	; x--     
ref_1AA61	fcb   %01100000	; x--     
ref_1AA62	fcb   %01100000	; x--     
ref_1AA63	fcb   %01100000	; x--     
ref_1AA64	fcb   %01100000	; x--     
ref_1AA65	fcb   %01100000	; x--     
ref_1AA66	fcb   %01100000	; x--     
ref_1AA67	fcb   %01100000	; x--     
ref_1AA68	fcb   %01100000	; x--     
ref_1AA69	fcb   %01100000	; x--     
ref_1AA6A	fcb   %01100000	; x--     
ref_1AA6B	fcb   %01100000	; x--     
ref_1AA6C	fcb   %01100100	; x--     end flag

ref_1AA6D	fcb   %10000000	; image:  0
ref_1AA6E	fcb   %00100000	; x++     
ref_1AA6F	fcb   %00100000	; x++     
ref_1AA70	fcb   %00100000	; x++     
ref_1AA71	fcb   %00100000	; x++     
ref_1AA72	fcb   %00100000	; x++     
ref_1AA73	fcb   %00100000	; x++     
ref_1AA74	fcb   %00100000	; x++     
ref_1AA75	fcb   %00100000	; x++     
ref_1AA76	fcb   %00100000	; x++     
ref_1AA77	fcb   %00100000	; x++     
ref_1AA78	fcb   %00100000	; x++     
ref_1AA79	fcb   %00100000	; x++     
ref_1AA7A	fcb   %00100000	; x++     
ref_1AA7B	fcb   %00100000	; x++     
ref_1AA7C	fcb   %00100000	; x++     
ref_1AA7D	fcb   %00100100	; x++     end flag

ref_1AA7E	fcb   %10001100	; image:  12

ref_1AA8F	fcb   %10000100	; image:  4

ref_1AAA0	fcb   %10000110	; image:  6

ref_1AAB1	fcb   %10001110	; image:  14

ref_1AAC2	fcb   %10001010	; image:  10
ref_1AAC3	fcb   %01101000	; x-- y++ 
ref_1AAC4	fcb   %01101000	; x-- y++ 
ref_1AAC5	fcb   %01101000	; x-- y++ 
ref_1AAC6	fcb   %01101000	; x-- y++ 
ref_1AAC7	fcb   %01101000	; x-- y++ 
ref_1AAC8	fcb   %01101000	; x-- y++ 
ref_1AAC9	fcb   %01101000	; x-- y++ 
ref_1AACA	fcb   %01101000	; x-- y++ 
ref_1AACB	fcb   %01101000	; x-- y++ 
ref_1AACC	fcb   %01101000	; x-- y++ 
ref_1AACD	fcb   %01101000	; x-- y++ 
ref_1AACE	fcb   %01101000	; x-- y++ 
ref_1AACF	fcb   %01101000	; x-- y++ 
ref_1AAD0	fcb   %01101000	; x-- y++ 
ref_1AAD1	fcb   %01101000	; x-- y++ 
ref_1AAD2	fcb   %01101100	; x-- y++ end flag

ref_1AAE4	fcb   %10000111	; image:  7

ref_1AB06	fcb   %10001001	; image:  9
ref_1AB07	fcb   %01100000	; x--     
ref_1AB08	fcb   %01101000	; x-- y++ 
ref_1AB09	fcb   %01100000	; x--     
ref_1AB0A	fcb   %01101000	; x-- y++ 
ref_1AB0B	fcb   %01100000	; x--     
ref_1AB0C	fcb   %01101000	; x-- y++ 
ref_1AB0D	fcb   %01100000	; x--     
ref_1AB0E	fcb   %01101000	; x-- y++ 
ref_1AB0F	fcb   %01100000	; x--     
ref_1AB10	fcb   %01101000	; x-- y++ 
ref_1AB11	fcb   %01100000	; x--     
ref_1AB12	fcb   %01101000	; x-- y++ 
ref_1AB13	fcb   %01100000	; x--     
ref_1AB14	fcb   %01101000	; x-- y++ 
ref_1AB15	fcb   %01100000	; x--     
ref_1AB16	fcb   %01101100	; x-- y++ end flag

ref_1AB17	fcb   %10000001	; image:  1
ref_1AB18	fcb   %00100000	; x++     
ref_1AB19	fcb   %00111000	; x++ y-- 
ref_1AB1A	fcb   %00100000	; x++     
ref_1AB1B	fcb   %00111000	; x++ y-- 
ref_1AB1C	fcb   %00100000	; x++     
ref_1AB1D	fcb   %00111000	; x++ y-- 
ref_1AB1E	fcb   %00100000	; x++     
ref_1AB1F	fcb   %00111000	; x++ y-- 
ref_1AB20	fcb   %00100000	; x++     
ref_1AB21	fcb   %00111000	; x++ y-- 
ref_1AB22	fcb   %00100000	; x++     
ref_1AB23	fcb   %00111000	; x++ y-- 
ref_1AB24	fcb   %00100000	; x++     
ref_1AB25	fcb   %00111000	; x++ y-- 
ref_1AB26	fcb   %00100000	; x++     
ref_1AB27	fcb   %00111100	; x++ y-- end flag

ref_1AB28	fcb   %10000101	; image:  5

ref_1AB4A	fcb   %10001011	; image:  11
ref_1AB4B	fcb   %00001000	;     y++ 
ref_1AB4C	fcb   %01101000	; x-- y++ 
ref_1AB4D	fcb   %00001000	;     y++ 
ref_1AB4E	fcb   %01101000	; x-- y++ 
ref_1AB4F	fcb   %00001000	;     y++ 
ref_1AB50	fcb   %01101000	; x-- y++ 
ref_1AB51	fcb   %00001000	;     y++ 
ref_1AB52	fcb   %01101000	; x-- y++ 
ref_1AB53	fcb   %00001000	;     y++ 
ref_1AB54	fcb   %01101000	; x-- y++ 
ref_1AB55	fcb   %00001000	;     y++ 
ref_1AB56	fcb   %01101000	; x-- y++ 
ref_1AB57	fcb   %00001000	;     y++ 
ref_1AB58	fcb   %01101000	; x-- y++ 
ref_1AB59	fcb   %00001000	;     y++ 
ref_1AB5A	fcb   %01101100	; x-- y++ end flag

ref_1AB5B	fcb   %10000011	; image:  3
ref_1AB5C	fcb   %00011000	;     y-- 
ref_1AB5D	fcb   %00111000	; x++ y-- 
ref_1AB5E	fcb   %00011000	;     y-- 
ref_1AB5F	fcb   %00111000	; x++ y-- 
ref_1AB60	fcb   %00011000	;     y-- 
ref_1AB61	fcb   %00111000	; x++ y-- 
ref_1AB62	fcb   %00011000	;     y-- 
ref_1AB63	fcb   %00111000	; x++ y-- 
ref_1AB64	fcb   %00011000	;     y-- 
ref_1AB65	fcb   %00111000	; x++ y-- 
ref_1AB66	fcb   %00011000	;     y-- 
ref_1AB67	fcb   %00111000	; x++ y-- 
ref_1AB68	fcb   %00011000	;     y-- 
ref_1AB69	fcb   %00111000	; x++ y-- 
ref_1AB6A	fcb   %00011000	;     y-- 
ref_1AB6B	fcb   %00111100	; x++ y-- end flag

ref_1AC8A	fcb   %10000100	; image:  4

ref_1ACB6	fcb   %10000101	; image:  5

ref_1ACCE	fcb   %10000110	; image:  6

ref_1ACE9	fcb   %10000111	; image:  7

ref_1AD11	fcb   %10001000	; image:  8
ref_1AD12	fcb   %01100000	; x--     
ref_1AD13	fcb   %01100000	; x--     
ref_1AD14	fcb   %01100000	; x--     
ref_1AD15	fcb   %01100000	; x--     
ref_1AD16	fcb   %01100000	; x--     
ref_1AD17	fcb   %01100000	; x--     
ref_1AD18	fcb   %01100000	; x--     
ref_1AD19	fcb   %01100000	; x--     
ref_1AD1A	fcb   %01100000	; x--     
ref_1AD1B	fcb   %01100000	; x--     
ref_1AD1C	fcb   %01100000	; x--     
ref_1AD1D	fcb   %01100000	; x--     
ref_1AD1E	fcb   %01100000	; x--     
ref_1AD1F	fcb   %01101000	; x-- y++ 
ref_1AD20	fcb   %01100000	; x--     
ref_1AD21	fcb   %01100000	; x--     
ref_1AD22	fcb   %01100000	; x--     
ref_1AD23	fcb   %01100000	; x--     
ref_1AD24	fcb   %01101000	; x-- y++ 
ref_1AD25	fcb   %10001001	; image:  9
ref_1AD26	fcb   %01100000	; x--     
ref_1AD27	fcb   %01100000	; x--     
ref_1AD28	fcb   %01100000	; x--     
ref_1AD29	fcb   %01100000	; x--     
ref_1AD2A	fcb   %01100000	; x--     
ref_1AD2B	fcb   %01101000	; x-- y++ 
ref_1AD2C	fcb   %01100000	; x--     
ref_1AD2D	fcb   %01100000	; x--     
ref_1AD2E	fcb   %01100000	; x--     
ref_1AD2F	fcb   %01101000	; x-- y++ 
ref_1AD30	fcb   %01100000	; x--     
ref_1AD31	fcb   %01100000	; x--     
ref_1AD32	fcb   %01101000	; x-- y++ 
ref_1AD33	fcb   %01100000	; x--     
ref_1AD34	fcb   %01100000	; x--     
ref_1AD35	fcb   %01100000	; x--     
ref_1AD36	fcb   %01101000	; x-- y++ 
ref_1AD37	fcb   %01100000	; x--     
ref_1AD38	fcb   %01100100	; x--     end flag

ref_1AD39	fcb   %10001001	; image:  9
ref_1AD3A	fcb   %01101000	; x-- y++ 
ref_1AD3B	fcb   %01100000	; x--     
ref_1AD3C	fcb   %01101000	; x-- y++ 
ref_1AD3D	fcb   %01100000	; x--     
ref_1AD3E	fcb   %01101000	; x-- y++ 
ref_1AD3F	fcb   %01100000	; x--     
ref_1AD40	fcb   %01100000	; x--     
ref_1AD41	fcb   %01101000	; x-- y++ 
ref_1AD42	fcb   %01100000	; x--     
ref_1AD43	fcb   %10001010	; image:  10
ref_1AD44	fcb   %01101000	; x-- y++ 
ref_1AD45	fcb   %01100000	; x--     
ref_1AD46	fcb   %01101000	; x-- y++ 
ref_1AD47	fcb   %01100000	; x--     
ref_1AD48	fcb   %01101000	; x-- y++ 
ref_1AD49	fcb   %01101000	; x-- y++ 
ref_1AD4A	fcb   %01100000	; x--     
ref_1AD4B	fcb   %01101000	; x-- y++ 
ref_1AD4C	fcb   %01100000	; x--     
ref_1AD4D	fcb   %01101000	; x-- y++ 
ref_1AD4E	fcb   %01101000	; x-- y++ 
ref_1AD4F	fcb   %01100000	; x--     
ref_1AD50	fcb   %01101000	; x-- y++ 
ref_1AD51	fcb   %01101000	; x-- y++ 
ref_1AD52	fcb   %01100000	; x--     
ref_1AD53	fcb   %01101100	; x-- y++ end flag

ref_1AD54	fcb   %10001010	; image:  10
ref_1AD55	fcb   %01101000	; x-- y++ 
ref_1AD56	fcb   %01101000	; x-- y++ 
ref_1AD57	fcb   %01100000	; x--     
ref_1AD58	fcb   %01101000	; x-- y++ 
ref_1AD59	fcb   %01101000	; x-- y++ 
ref_1AD5A	fcb   %01101000	; x-- y++ 
ref_1AD5B	fcb   %01101000	; x-- y++ 
ref_1AD5C	fcb   %01101000	; x-- y++ 
ref_1AD5D	fcb   %01101000	; x-- y++ 
ref_1AD5E	fcb   %10001011	; image:  11
ref_1AD5F	fcb   %01101000	; x-- y++ 
ref_1AD60	fcb   %01101000	; x-- y++ 
ref_1AD61	fcb   %01101000	; x-- y++ 
ref_1AD62	fcb   %01101000	; x-- y++ 
ref_1AD63	fcb   %01101000	; x-- y++ 
ref_1AD64	fcb   %01101000	; x-- y++ 
ref_1AD65	fcb   %01101000	; x-- y++ 
ref_1AD66	fcb   %00001000	;     y++ 
ref_1AD67	fcb   %01101000	; x-- y++ 
ref_1AD68	fcb   %01101000	; x-- y++ 
ref_1AD69	fcb   %01101000	; x-- y++ 
ref_1AD6A	fcb   %00001000	;     y++ 
ref_1AD6B	fcb   %01101100	; x-- y++ end flag

ref_1AD6C	fcb   %10001011	; image:  11
ref_1AD6D	fcb   %01101000	; x-- y++ 
ref_1AD6E	fcb   %00001000	;     y++ 
ref_1AD6F	fcb   %01101000	; x-- y++ 
ref_1AD70	fcb   %01101000	; x-- y++ 
ref_1AD71	fcb   %00001000	;     y++ 
ref_1AD72	fcb   %01101000	; x-- y++ 
ref_1AD73	fcb   %00001000	;     y++ 
ref_1AD74	fcb   %01101000	; x-- y++ 
ref_1AD75	fcb   %00001000	;     y++ 
ref_1AD76	fcb   %01101000	; x-- y++ 
ref_1AD77	fcb   %00001000	;     y++ 
ref_1AD78	fcb   %00001000	;     y++ 
ref_1AD79	fcb   %01101000	; x-- y++ 
ref_1AD7A	fcb   %00001000	;     y++ 
ref_1AD7B	fcb   %01101000	; x-- y++ 
ref_1AD7C	fcb   %00001000	;     y++ 
ref_1AD7D	fcb   %01101000	; x-- y++ 
ref_1AD7E	fcb   %00001000	;     y++ 
ref_1AD7F	fcb   %00001000	;     y++ 
ref_1AD80	fcb   %01101000	; x-- y++ 
ref_1AD81	fcb   %00001000	;     y++ 
ref_1AD82	fcb   %00001000	;     y++ 
ref_1AD83	fcb   %10001100	; image:  12

ref_1AD98	fcb   %10001100	; image:  12

ref_1ADC4	fcb   %10001101	; image:  13

ref_1ADDC	fcb   %10001110	; image:  14

ref_1ADF7	fcb   %10001111	; image:  15

ref_1AE1F	fcb   %10000000	; image:  0
ref_1AE20	fcb   %00100000	; x++     
ref_1AE21	fcb   %00100000	; x++     
ref_1AE22	fcb   %00100000	; x++     
ref_1AE23	fcb   %00100000	; x++     
ref_1AE24	fcb   %00100000	; x++     
ref_1AE25	fcb   %00100000	; x++     
ref_1AE26	fcb   %00100000	; x++     
ref_1AE27	fcb   %00100000	; x++     
ref_1AE28	fcb   %00100000	; x++     
ref_1AE29	fcb   %00100000	; x++     
ref_1AE2A	fcb   %00100000	; x++     
ref_1AE2B	fcb   %00100000	; x++     
ref_1AE2C	fcb   %00100000	; x++     
ref_1AE2D	fcb   %00111000	; x++ y-- 
ref_1AE2E	fcb   %00100000	; x++     
ref_1AE2F	fcb   %00100000	; x++     
ref_1AE30	fcb   %00100000	; x++     
ref_1AE31	fcb   %00100000	; x++     
ref_1AE32	fcb   %00111000	; x++ y-- 
ref_1AE33	fcb   %10000001	; image:  1
ref_1AE34	fcb   %00100000	; x++     
ref_1AE35	fcb   %00100000	; x++     
ref_1AE36	fcb   %00100000	; x++     
ref_1AE37	fcb   %00100000	; x++     
ref_1AE38	fcb   %00100000	; x++     
ref_1AE39	fcb   %00111000	; x++ y-- 
ref_1AE3A	fcb   %00100000	; x++     
ref_1AE3B	fcb   %00100000	; x++     
ref_1AE3C	fcb   %00100000	; x++     
ref_1AE3D	fcb   %00111000	; x++ y-- 
ref_1AE3E	fcb   %00100000	; x++     
ref_1AE3F	fcb   %00100000	; x++     
ref_1AE40	fcb   %00111000	; x++ y-- 
ref_1AE41	fcb   %00100000	; x++     
ref_1AE42	fcb   %00100000	; x++     
ref_1AE43	fcb   %00100000	; x++     
ref_1AE44	fcb   %00111000	; x++ y-- 
ref_1AE45	fcb   %00100000	; x++     
ref_1AE46	fcb   %00100100	; x++     end flag

ref_1AE47	fcb   %10000001	; image:  1
ref_1AE48	fcb   %00111000	; x++ y-- 
ref_1AE49	fcb   %00100000	; x++     
ref_1AE4A	fcb   %00111000	; x++ y-- 
ref_1AE4B	fcb   %00100000	; x++     
ref_1AE4C	fcb   %00111000	; x++ y-- 
ref_1AE4D	fcb   %00100000	; x++     
ref_1AE4E	fcb   %00100000	; x++     
ref_1AE4F	fcb   %00111000	; x++ y-- 
ref_1AE50	fcb   %00100000	; x++     
ref_1AE51	fcb   %00111000	; x++ y-- 
ref_1AE52	fcb   %10000010	; image:  2
ref_1AE53	fcb   %00100000	; x++     
ref_1AE54	fcb   %00111000	; x++ y-- 
ref_1AE55	fcb   %00100000	; x++     
ref_1AE56	fcb   %00111000	; x++ y-- 
ref_1AE57	fcb   %00111000	; x++ y-- 
ref_1AE58	fcb   %00100000	; x++     
ref_1AE59	fcb   %00111000	; x++ y-- 
ref_1AE5A	fcb   %00100000	; x++     
ref_1AE5B	fcb   %00111000	; x++ y-- 
ref_1AE5C	fcb   %00111000	; x++ y-- 
ref_1AE5D	fcb   %00100000	; x++     
ref_1AE5E	fcb   %00111000	; x++ y-- 
ref_1AE5F	fcb   %00111000	; x++ y-- 
ref_1AE60	fcb   %00100000	; x++     
ref_1AE61	fcb   %00111100	; x++ y-- end flag

ref_1AE62	fcb   %10000010	; image:  2
ref_1AE63	fcb   %00111000	; x++ y-- 
ref_1AE64	fcb   %00111000	; x++ y-- 
ref_1AE65	fcb   %00100000	; x++     
ref_1AE66	fcb   %00111000	; x++ y-- 
ref_1AE67	fcb   %00111000	; x++ y-- 
ref_1AE68	fcb   %00111000	; x++ y-- 
ref_1AE69	fcb   %00111000	; x++ y-- 
ref_1AE6A	fcb   %00111000	; x++ y-- 
ref_1AE6B	fcb   %00111000	; x++ y-- 
ref_1AE6C	fcb   %10000011	; image:  3
ref_1AE6D	fcb   %00111000	; x++ y-- 
ref_1AE6E	fcb   %00111000	; x++ y-- 
ref_1AE6F	fcb   %00111000	; x++ y-- 
ref_1AE70	fcb   %00111000	; x++ y-- 
ref_1AE71	fcb   %00111000	; x++ y-- 
ref_1AE72	fcb   %00111000	; x++ y-- 
ref_1AE73	fcb   %00111000	; x++ y-- 
ref_1AE74	fcb   %00011000	;     y-- 
ref_1AE75	fcb   %00111000	; x++ y-- 
ref_1AE76	fcb   %00111000	; x++ y-- 
ref_1AE77	fcb   %00111000	; x++ y-- 
ref_1AE78	fcb   %00011000	;     y-- 
ref_1AE79	fcb   %00111100	; x++ y-- end flag

ref_1AE7A	fcb   %10000011	; image:  3
ref_1AE7B	fcb   %00111000	; x++ y-- 
ref_1AE7C	fcb   %00011000	;     y-- 
ref_1AE7D	fcb   %00111000	; x++ y-- 
ref_1AE7E	fcb   %00111000	; x++ y-- 
ref_1AE7F	fcb   %00011000	;     y-- 
ref_1AE80	fcb   %00111000	; x++ y-- 
ref_1AE81	fcb   %00011000	;     y-- 
ref_1AE82	fcb   %00111000	; x++ y-- 
ref_1AE83	fcb   %00011000	;     y-- 
ref_1AE84	fcb   %00111000	; x++ y-- 
ref_1AE85	fcb   %00011000	;     y-- 
ref_1AE86	fcb   %00011000	;     y-- 
ref_1AE87	fcb   %00111000	; x++ y-- 
ref_1AE88	fcb   %00011000	;     y-- 
ref_1AE89	fcb   %00111000	; x++ y-- 
ref_1AE8A	fcb   %00011000	;     y-- 
ref_1AE8B	fcb   %00111000	; x++ y-- 
ref_1AE8C	fcb   %00011000	;     y-- 
ref_1AE8D	fcb   %00011000	;     y-- 
ref_1AE8E	fcb   %00111000	; x++ y-- 
ref_1AE8F	fcb   %00011000	;     y-- 
ref_1AE90	fcb   %00011000	;     y-- 
ref_1AE91	fcb   %00111000	; x++ y-- 
ref_1AE92	fcb   %10000100	; image:  4

ref_1AEA6	fcb   %10000100	; image:  4

ref_1AF8B	fcb   %10001110	; image:  14

ref_1AFAC	fcb   %10001101	; image:  13

ref_1AFD8	fcb   %10001100	; image:  12

ref_1B004	fcb   %10001011	; image:  11
ref_1B005	fcb   %01101000	; x-- y++ 
ref_1B006	fcb   %00001000	;     y++ 
ref_1B007	fcb   %00000000	;         
ref_1B008	fcb   %01101000	; x-- y++ 
ref_1B009	fcb   %01101000	; x-- y++ 
ref_1B00A	fcb   %01101000	; x-- y++ 
ref_1B00B	fcb   %00000000	;         
ref_1B00C	fcb   %00001000	;     y++ 
ref_1B00D	fcb   %01101000	; x-- y++ 
ref_1B00E	fcb   %01101000	; x-- y++ 
ref_1B00F	fcb   %00000000	;         
ref_1B010	fcb   %01101000	; x-- y++ 
ref_1B011	fcb   %01101000	; x-- y++ 
ref_1B012	fcb   %01101000	; x-- y++ 
ref_1B013	fcb   %00000000	;         
ref_1B014	fcb   %01101000	; x-- y++ 
ref_1B015	fcb   %10001010	; image:  10
ref_1B016	fcb   %01101000	; x-- y++ 
ref_1B017	fcb   %00000000	;         
ref_1B018	fcb   %01101000	; x-- y++ 
ref_1B019	fcb   %00000000	;         
ref_1B01A	fcb   %01101000	; x-- y++ 
ref_1B01B	fcb   %01101000	; x-- y++ 
ref_1B01C	fcb   %00000000	;         
ref_1B01D	fcb   %01101000	; x-- y++ 
ref_1B01E	fcb   %01101000	; x-- y++ 
ref_1B01F	fcb   %00000000	;         
ref_1B020	fcb   %01101000	; x-- y++ 
ref_1B021	fcb   %00000000	;         
ref_1B022	fcb   %01100000	; x--     
ref_1B023	fcb   %01101000	; x-- y++ 
ref_1B024	fcb   %01101100	; x-- y++ end flag

ref_1B025	fcb   %10001010	; image:  10
ref_1B026	fcb   %01101000	; x-- y++ 
ref_1B027	fcb   %00000000	;         
ref_1B028	fcb   %01100000	; x--     
ref_1B029	fcb   %01101000	; x-- y++ 
ref_1B02A	fcb   %00000000	;         
ref_1B02B	fcb   %01101000	; x-- y++ 
ref_1B02C	fcb   %01100000	; x--     
ref_1B02D	fcb   %01101000	; x-- y++ 
ref_1B02E	fcb   %00000000	;         
ref_1B02F	fcb   %01101000	; x-- y++ 
ref_1B030	fcb   %01100000	; x--     
ref_1B031	fcb   %01101000	; x-- y++ 
ref_1B032	fcb   %00000000	;         
ref_1B033	fcb   %01100000	; x--     
ref_1B034	fcb   %01101000	; x-- y++ 
ref_1B035	fcb   %00000000	;         
ref_1B036	fcb   %01101000	; x-- y++ 
ref_1B037	fcb   %01100000	; x--     
ref_1B038	fcb   %00000000	;         
ref_1B039	fcb   %01101000	; x-- y++ 
ref_1B03A	fcb   %01100000	; x--     
ref_1B03B	fcb   %00000000	;         
ref_1B03C	fcb   %10001001	; image:  9
ref_1B03D	fcb   %01101000	; x-- y++ 
ref_1B03E	fcb   %01100000	; x--     
ref_1B03F	fcb   %00000000	;         
ref_1B040	fcb   %01101000	; x-- y++ 
ref_1B041	fcb   %01100000	; x--     
ref_1B042	fcb   %01100000	; x--     
ref_1B043	fcb   %00000000	;         
ref_1B044	fcb   %01101000	; x-- y++ 
ref_1B045	fcb   %01100000	; x--     
ref_1B046	fcb   %01101000	; x-- y++ 
ref_1B047	fcb   %01100000	; x--     
ref_1B048	fcb   %01101100	; x-- y++ end flag

ref_1B049	fcb   %10001001	; image:  9
ref_1B04A	fcb   %01100000	; x--     
ref_1B04B	fcb   %01100000	; x--     
ref_1B04C	fcb   %01101000	; x-- y++ 
ref_1B04D	fcb   %01100000	; x--     
ref_1B04E	fcb   %01100000	; x--     
ref_1B04F	fcb   %01100000	; x--     
ref_1B050	fcb   %01101000	; x-- y++ 
ref_1B051	fcb   %01100000	; x--     
ref_1B052	fcb   %01100000	; x--     
ref_1B053	fcb   %01101000	; x-- y++ 
ref_1B054	fcb   %01100000	; x--     
ref_1B055	fcb   %01100000	; x--     
ref_1B056	fcb   %01100000	; x--     
ref_1B057	fcb   %01101000	; x-- y++ 
ref_1B058	fcb   %01100000	; x--     
ref_1B059	fcb   %01100000	; x--     
ref_1B05A	fcb   %01100000	; x--     
ref_1B05B	fcb   %01100000	; x--     
ref_1B05C	fcb   %01100000	; x--     
ref_1B05D	fcb   %01101000	; x-- y++ 
ref_1B05E	fcb   %10001000	; image:  8
ref_1B05F	fcb   %01100000	; x--     
ref_1B060	fcb   %01100000	; x--     
ref_1B061	fcb   %01100000	; x--     
ref_1B062	fcb   %01100000	; x--     
ref_1B063	fcb   %01101000	; x-- y++ 
ref_1B064	fcb   %01100000	; x--     
ref_1B065	fcb   %01100000	; x--     
ref_1B066	fcb   %01100000	; x--     
ref_1B067	fcb   %01100000	; x--     
ref_1B068	fcb   %01100000	; x--     
ref_1B069	fcb   %01100000	; x--     
ref_1B06A	fcb   %01100000	; x--     
ref_1B06B	fcb   %01100000	; x--     
ref_1B06C	fcb   %01100000	; x--     
ref_1B06D	fcb   %01100000	; x--     
ref_1B06E	fcb   %01100000	; x--     
ref_1B06F	fcb   %01100000	; x--     
ref_1B070	fcb   %01100100	; x--     end flag

ref_1B071	fcb   %10001000	; image:  8
ref_1B072	fcb   %01100000	; x--     
ref_1B073	fcb   %01100000	; x--     
ref_1B074	fcb   %01100000	; x--     
ref_1B075	fcb   %01100000	; x--     
ref_1B076	fcb   %01100000	; x--     
ref_1B077	fcb   %01100000	; x--     
ref_1B078	fcb   %01100000	; x--     
ref_1B079	fcb   %01100000	; x--     
ref_1B07A	fcb   %01100000	; x--     
ref_1B07B	fcb   %01100000	; x--     
ref_1B07C	fcb   %01100000	; x--     
ref_1B07D	fcb   %01100000	; x--     
ref_1B07E	fcb   %01100000	; x--     
ref_1B07F	fcb   %01111000	; x-- y-- 
ref_1B080	fcb   %01100000	; x--     
ref_1B081	fcb   %01100000	; x--     
ref_1B082	fcb   %01100000	; x--     
ref_1B083	fcb   %01100000	; x--     
ref_1B084	fcb   %01111000	; x-- y-- 
ref_1B085	fcb   %10000111	; image:  7

ref_1B099	fcb   %10000111	; image:  7

ref_1B0BD	fcb   %10000110	; image:  6

ref_1B0DE	fcb   %10000101	; image:  5

ref_1B10A	fcb   %10000100	; image:  4

ref_1B128	fcb   %10000101	; image:  5

ref_1B139	fcb   %10000110	; image:  6

ref_1B14B	fcb   %10000111	; image:  7

ref_1B167	fcb   %10001000	; image:  8
ref_1B168	fcb   %01100000	; x--     
ref_1B169	fcb   %01100000	; x--     
ref_1B16A	fcb   %01100000	; x--     
ref_1B16B	fcb   %01100000	; x--     
ref_1B16C	fcb   %01100000	; x--     
ref_1B16D	fcb   %01100000	; x--     
ref_1B16E	fcb   %01101000	; x-- y++ 
ref_1B16F	fcb   %01100000	; x--     
ref_1B170	fcb   %01100000	; x--     
ref_1B171	fcb   %01100000	; x--     
ref_1B172	fcb   %01100000	; x--     
ref_1B173	fcb   %01100000	; x--     
ref_1B174	fcb   %01100000	; x--     
ref_1B175	fcb   %01101000	; x-- y++ 
ref_1B176	fcb   %10001001	; image:  9
ref_1B177	fcb   %01100000	; x--     
ref_1B178	fcb   %01100000	; x--     
ref_1B179	fcb   %01100000	; x--     
ref_1B17A	fcb   %01100000	; x--     
ref_1B17B	fcb   %01101000	; x-- y++ 
ref_1B17C	fcb   %01100000	; x--     
ref_1B17D	fcb   %01100000	; x--     
ref_1B17E	fcb   %01101000	; x-- y++ 
ref_1B17F	fcb   %01100000	; x--     
ref_1B180	fcb   %01100000	; x--     
ref_1B181	fcb   %01101000	; x-- y++ 
ref_1B182	fcb   %01100100	; x--     end flag

ref_1B183	fcb   %10001001	; image:  9
ref_1B184	fcb   %01100000	; x--     
ref_1B185	fcb   %01101000	; x-- y++ 
ref_1B186	fcb   %01100000	; x--     
ref_1B187	fcb   %01101000	; x-- y++ 
ref_1B188	fcb   %01100000	; x--     
ref_1B189	fcb   %01101000	; x-- y++ 
ref_1B18A	fcb   %01100000	; x--     
ref_1B18B	fcb   %10001010	; image:  10
ref_1B18C	fcb   %01101000	; x-- y++ 
ref_1B18D	fcb   %01100000	; x--     
ref_1B18E	fcb   %01101000	; x-- y++ 
ref_1B18F	fcb   %01100000	; x--     
ref_1B190	fcb   %01101000	; x-- y++ 
ref_1B191	fcb   %01101000	; x-- y++ 
ref_1B192	fcb   %01100000	; x--     
ref_1B193	fcb   %01101000	; x-- y++ 
ref_1B194	fcb   %01101100	; x-- y++ end flag

ref_1B195	fcb   %10001010	; image:  10
ref_1B196	fcb   %01100000	; x--     
ref_1B197	fcb   %01101000	; x-- y++ 
ref_1B198	fcb   %01101000	; x-- y++ 
ref_1B199	fcb   %01101000	; x-- y++ 
ref_1B19A	fcb   %01101000	; x-- y++ 
ref_1B19B	fcb   %01101000	; x-- y++ 
ref_1B19C	fcb   %10001011	; image:  11
ref_1B19D	fcb   %01101000	; x-- y++ 
ref_1B19E	fcb   %01101000	; x-- y++ 
ref_1B19F	fcb   %01101000	; x-- y++ 
ref_1B1A0	fcb   %01101000	; x-- y++ 
ref_1B1A1	fcb   %01101000	; x-- y++ 
ref_1B1A2	fcb   %00001000	;     y++ 
ref_1B1A3	fcb   %01101000	; x-- y++ 
ref_1B1A4	fcb   %01101000	; x-- y++ 
ref_1B1A5	fcb   %01101100	; x-- y++ end flag

ref_1B1A6	fcb   %10001011	; image:  11
ref_1B1A7	fcb   %00001000	;     y++ 
ref_1B1A8	fcb   %01101000	; x-- y++ 
ref_1B1A9	fcb   %00001000	;     y++ 
ref_1B1AA	fcb   %01101000	; x-- y++ 
ref_1B1AB	fcb   %01101000	; x-- y++ 
ref_1B1AC	fcb   %00001000	;     y++ 
ref_1B1AD	fcb   %01101000	; x-- y++ 
ref_1B1AE	fcb   %00001000	;     y++ 
ref_1B1AF	fcb   %01101000	; x-- y++ 
ref_1B1B0	fcb   %00001000	;     y++ 
ref_1B1B1	fcb   %00001000	;     y++ 
ref_1B1B2	fcb   %01101000	; x-- y++ 
ref_1B1B3	fcb   %00001000	;     y++ 
ref_1B1B4	fcb   %00001000	;     y++ 
ref_1B1B5	fcb   %01101000	; x-- y++ 
ref_1B1B6	fcb   %00001000	;     y++ 
ref_1B1B7	fcb   %00001000	;     y++ 
ref_1B1B8	fcb   %00001000	;     y++ 
ref_1B1B9	fcb   %00001000	;     y++ 
ref_1B1BA	fcb   %01101000	; x-- y++ 
ref_1B1BB	fcb   %10001100	; image:  12

ref_1B1C4	fcb   %10001100	; image:  12

ref_1B1E2	fcb   %10001101	; image:  13

ref_1B1F3	fcb   %10001110	; image:  14

ref_1B205	fcb   %10001111	; image:  15

ref_1B221	fcb   %10000000	; image:  0
ref_1B222	fcb   %00100000	; x++     
ref_1B223	fcb   %00100000	; x++     
ref_1B224	fcb   %00100000	; x++     
ref_1B225	fcb   %00100000	; x++     
ref_1B226	fcb   %00100000	; x++     
ref_1B227	fcb   %00100000	; x++     
ref_1B228	fcb   %00111000	; x++ y-- 
ref_1B229	fcb   %00100000	; x++     
ref_1B22A	fcb   %00100000	; x++     
ref_1B22B	fcb   %00100000	; x++     
ref_1B22C	fcb   %00100000	; x++     
ref_1B22D	fcb   %00100000	; x++     
ref_1B22E	fcb   %00100000	; x++     
ref_1B22F	fcb   %00111000	; x++ y-- 
ref_1B230	fcb   %10000001	; image:  1
ref_1B231	fcb   %00100000	; x++     
ref_1B232	fcb   %00100000	; x++     
ref_1B233	fcb   %00100000	; x++     
ref_1B234	fcb   %00100000	; x++     
ref_1B235	fcb   %00111000	; x++ y-- 
ref_1B236	fcb   %00100000	; x++     
ref_1B237	fcb   %00100000	; x++     
ref_1B238	fcb   %00111000	; x++ y-- 
ref_1B239	fcb   %00100000	; x++     
ref_1B23A	fcb   %00100000	; x++     
ref_1B23B	fcb   %00111000	; x++ y-- 
ref_1B23C	fcb   %00100100	; x++     end flag

ref_1B23D	fcb   %10000001	; image:  1
ref_1B23E	fcb   %00100000	; x++     
ref_1B23F	fcb   %00111000	; x++ y-- 
ref_1B240	fcb   %00100000	; x++     
ref_1B241	fcb   %00111000	; x++ y-- 
ref_1B242	fcb   %00100000	; x++     
ref_1B243	fcb   %00111000	; x++ y-- 
ref_1B244	fcb   %00100000	; x++     
ref_1B245	fcb   %00111000	; x++ y-- 
ref_1B246	fcb   %10000010	; image:  2
ref_1B247	fcb   %00100000	; x++     
ref_1B248	fcb   %00111000	; x++ y-- 
ref_1B249	fcb   %00100000	; x++     
ref_1B24A	fcb   %00111000	; x++ y-- 
ref_1B24B	fcb   %00111000	; x++ y-- 
ref_1B24C	fcb   %00100000	; x++     
ref_1B24D	fcb   %00111000	; x++ y-- 
ref_1B24E	fcb   %00111100	; x++ y-- end flag

ref_1B24F	fcb   %10000010	; image:  2
ref_1B250	fcb   %00100000	; x++     
ref_1B251	fcb   %00111000	; x++ y-- 
ref_1B252	fcb   %00111000	; x++ y-- 
ref_1B253	fcb   %00111000	; x++ y-- 
ref_1B254	fcb   %00111000	; x++ y-- 
ref_1B255	fcb   %00111000	; x++ y-- 
ref_1B256	fcb   %10000011	; image:  3
ref_1B257	fcb   %00111000	; x++ y-- 
ref_1B258	fcb   %00111000	; x++ y-- 
ref_1B259	fcb   %00111000	; x++ y-- 
ref_1B25A	fcb   %00111000	; x++ y-- 
ref_1B25B	fcb   %00111000	; x++ y-- 
ref_1B25C	fcb   %00011000	;     y-- 
ref_1B25D	fcb   %00111000	; x++ y-- 
ref_1B25E	fcb   %00111000	; x++ y-- 
ref_1B25F	fcb   %00111100	; x++ y-- end flag

ref_1B260	fcb   %10000011	; image:  3
ref_1B261	fcb   %00011000	;     y-- 
ref_1B262	fcb   %00111000	; x++ y-- 
ref_1B263	fcb   %00011000	;     y-- 
ref_1B264	fcb   %00111000	; x++ y-- 
ref_1B265	fcb   %00111000	; x++ y-- 
ref_1B266	fcb   %00011000	;     y-- 
ref_1B267	fcb   %00111000	; x++ y-- 
ref_1B268	fcb   %00011000	;     y-- 
ref_1B269	fcb   %00111000	; x++ y-- 
ref_1B26A	fcb   %00011000	;     y-- 
ref_1B26B	fcb   %00011000	;     y-- 
ref_1B26C	fcb   %00111000	; x++ y-- 
ref_1B26D	fcb   %00011000	;     y-- 
ref_1B26E	fcb   %00011000	;     y-- 
ref_1B26F	fcb   %00111000	; x++ y-- 
ref_1B270	fcb   %00011000	;     y-- 
ref_1B271	fcb   %00011000	;     y-- 
ref_1B272	fcb   %00011000	;     y-- 
ref_1B273	fcb   %00011000	;     y-- 
ref_1B274	fcb   %00111000	; x++ y-- 
ref_1B275	fcb   %10000100	; image:  4

ref_1B2AD	fcb   %10000010	; image:  2
ref_1B2AE	fcb   %00111000	; x++ y-- 
ref_1B2AF	fcb   %00111000	; x++ y-- 
ref_1B2B0	fcb   %00100000	; x++     
ref_1B2B1	fcb   %00111000	; x++ y-- 
ref_1B2B2	fcb   %00111000	; x++ y-- 
ref_1B2B3	fcb   %00100000	; x++     
ref_1B2B4	fcb   %00111000	; x++ y-- 
ref_1B2B5	fcb   %00100000	; x++     
ref_1B2B6	fcb   %00111000	; x++ y-- 
ref_1B2B7	fcb   %10000001	; image:  1
ref_1B2B8	fcb   %00100000	; x++     
ref_1B2B9	fcb   %00111000	; x++ y-- 
ref_1B2BA	fcb   %00100000	; x++     
ref_1B2BB	fcb   %00111000	; x++ y-- 
ref_1B2BC	fcb   %00100000	; x++     
ref_1B2BD	fcb   %00111000	; x++ y-- 
ref_1B2BE	fcb   %00100100	; x++     end flag

ref_1B2BF	fcb   %10000001	; image:  1
ref_1B2C0	fcb   %00100000	; x++     
ref_1B2C1	fcb   %00111000	; x++ y-- 
ref_1B2C2	fcb   %00100000	; x++     
ref_1B2C3	fcb   %00100000	; x++     
ref_1B2C4	fcb   %00111000	; x++ y-- 
ref_1B2C5	fcb   %00100000	; x++     
ref_1B2C6	fcb   %00100000	; x++     
ref_1B2C7	fcb   %00111000	; x++ y-- 
ref_1B2C8	fcb   %00100000	; x++     
ref_1B2C9	fcb   %00100000	; x++     
ref_1B2CA	fcb   %00100000	; x++     
ref_1B2CB	fcb   %00100000	; x++     
ref_1B2CC	fcb   %00111000	; x++ y-- 
ref_1B2CD	fcb   %10000000	; image:  0
ref_1B2CE	fcb   %00100000	; x++     
ref_1B2CF	fcb   %00100000	; x++     
ref_1B2D0	fcb   %00100000	; x++     
ref_1B2D1	fcb   %00100000	; x++     
ref_1B2D2	fcb   %00100000	; x++     
ref_1B2D3	fcb   %00100000	; x++     
ref_1B2D4	fcb   %00111000	; x++ y-- 
ref_1B2D5	fcb   %00100000	; x++     
ref_1B2D6	fcb   %00100000	; x++     
ref_1B2D7	fcb   %00100000	; x++     
ref_1B2D8	fcb   %00100000	; x++     
ref_1B2D9	fcb   %00100000	; x++     
ref_1B2DA	fcb   %00100100	; x++     end flag

ref_1B2DB	fcb   %10000000	; image:  0
ref_1B2DC	fcb   %00100000	; x++     
ref_1B2DD	fcb   %00100000	; x++     
ref_1B2DE	fcb   %00100000	; x++     
ref_1B2DF	fcb   %00100000	; x++     
ref_1B2E0	fcb   %00100000	; x++     
ref_1B2E1	fcb   %00100000	; x++     
ref_1B2E2	fcb   %00101000	; x++ y++ 
ref_1B2E3	fcb   %00100000	; x++     
ref_1B2E4	fcb   %00100000	; x++     
ref_1B2E5	fcb   %00100000	; x++     
ref_1B2E6	fcb   %00100000	; x++     
ref_1B2E7	fcb   %00100000	; x++     
ref_1B2E8	fcb   %00100000	; x++     
ref_1B2E9	fcb   %00101000	; x++ y++ 
ref_1B2EA	fcb   %10001111	; image:  15

ref_1B2F7	fcb   %10001111	; image:  15

ref_1B356	fcb   %10001011	; image:  11
ref_1B357	fcb   %01101000	; x-- y++ 
ref_1B358	fcb   %01101000	; x-- y++ 
ref_1B359	fcb   %01101000	; x-- y++ 
ref_1B35A	fcb   %00001000	;     y++ 
ref_1B35B	fcb   %01101000	; x-- y++ 
ref_1B35C	fcb   %01101000	; x-- y++ 
ref_1B35D	fcb   %01101000	; x-- y++ 
ref_1B35E	fcb   %01101000	; x-- y++ 
ref_1B35F	fcb   %01101000	; x-- y++ 
ref_1B360	fcb   %10001010	; image:  10
ref_1B361	fcb   %01101000	; x-- y++ 
ref_1B362	fcb   %01101000	; x-- y++ 
ref_1B363	fcb   %01101000	; x-- y++ 
ref_1B364	fcb   %01101000	; x-- y++ 
ref_1B365	fcb   %01101000	; x-- y++ 
ref_1B366	fcb   %01100100	; x--     end flag

ref_1B367	fcb   %10001010	; image:  10
ref_1B368	fcb   %01101000	; x-- y++ 
ref_1B369	fcb   %01101000	; x-- y++ 
ref_1B36A	fcb   %01100000	; x--     
ref_1B36B	fcb   %01101000	; x-- y++ 
ref_1B36C	fcb   %01101000	; x-- y++ 
ref_1B36D	fcb   %01100000	; x--     
ref_1B36E	fcb   %01101000	; x-- y++ 
ref_1B36F	fcb   %01100000	; x--     
ref_1B370	fcb   %01101000	; x-- y++ 
ref_1B371	fcb   %10001001	; image:  9
ref_1B372	fcb   %01100000	; x--     
ref_1B373	fcb   %01101000	; x-- y++ 
ref_1B374	fcb   %01100000	; x--     
ref_1B375	fcb   %01101000	; x-- y++ 
ref_1B376	fcb   %01100000	; x--     
ref_1B377	fcb   %01101000	; x-- y++ 
ref_1B378	fcb   %01100100	; x--     end flag

ref_1B379	fcb   %10001001	; image:  9
ref_1B37A	fcb   %01100000	; x--     
ref_1B37B	fcb   %01101000	; x-- y++ 
ref_1B37C	fcb   %01100000	; x--     
ref_1B37D	fcb   %01100000	; x--     
ref_1B37E	fcb   %01101000	; x-- y++ 
ref_1B37F	fcb   %01100000	; x--     
ref_1B380	fcb   %01100000	; x--     
ref_1B381	fcb   %01101000	; x-- y++ 
ref_1B382	fcb   %01100000	; x--     
ref_1B383	fcb   %01100000	; x--     
ref_1B384	fcb   %01100000	; x--     
ref_1B385	fcb   %01100000	; x--     
ref_1B386	fcb   %01101000	; x-- y++ 
ref_1B387	fcb   %10001000	; image:  8
ref_1B388	fcb   %01100000	; x--     
ref_1B389	fcb   %01100000	; x--     
ref_1B38A	fcb   %01100000	; x--     
ref_1B38B	fcb   %01100000	; x--     
ref_1B38C	fcb   %01100000	; x--     
ref_1B38D	fcb   %01100000	; x--     
ref_1B38E	fcb   %01101000	; x-- y++ 
ref_1B38F	fcb   %01100000	; x--     
ref_1B390	fcb   %01100000	; x--     
ref_1B391	fcb   %01100000	; x--     
ref_1B392	fcb   %01100000	; x--     
ref_1B393	fcb   %01100000	; x--     
ref_1B394	fcb   %01100100	; x--     end flag

ref_1B395	fcb   %10001000	; image:  8
ref_1B396	fcb   %01100000	; x--     
ref_1B397	fcb   %01100000	; x--     
ref_1B398	fcb   %01100000	; x--     
ref_1B399	fcb   %01100000	; x--     
ref_1B39A	fcb   %01100000	; x--     
ref_1B39B	fcb   %01100000	; x--     
ref_1B39C	fcb   %01111000	; x-- y-- 
ref_1B39D	fcb   %01100000	; x--     
ref_1B39E	fcb   %01100000	; x--     
ref_1B39F	fcb   %01100000	; x--     
ref_1B3A0	fcb   %01100000	; x--     
ref_1B3A1	fcb   %01100000	; x--     
ref_1B3A2	fcb   %01100000	; x--     
ref_1B3A3	fcb   %01111000	; x-- y-- 
ref_1B3A4	fcb   %10000111	; image:  7

ref_1B3B1	fcb   %10000111	; image:  7

ref_1B3F2	fcb   %10000100	; image:  4

ref_1B402	fcb   %10000101	; image:  5

ref_1B40B	fcb   %10000110	; image:  6

ref_1B415	fcb   %10000111	; image:  7

ref_1B424	fcb   %10001000	; image:  8
ref_1B425	fcb   %01100000	; x--     
ref_1B426	fcb   %01100000	; x--     
ref_1B427	fcb   %01100000	; x--     
ref_1B428	fcb   %01100000	; x--     
ref_1B429	fcb   %01100000	; x--     
ref_1B42A	fcb   %01101000	; x-- y++ 
ref_1B42B	fcb   %10001001	; image:  9
ref_1B42C	fcb   %01100000	; x--     
ref_1B42D	fcb   %01100000	; x--     
ref_1B42E	fcb   %01100000	; x--     
ref_1B42F	fcb   %01100000	; x--     
ref_1B430	fcb   %01101000	; x-- y++ 
ref_1B431	fcb   %01100000	; x--     
ref_1B432	fcb   %01100100	; x--     end flag

ref_1B433	fcb   %10001001	; image:  9
ref_1B434	fcb   %01101000	; x-- y++ 
ref_1B435	fcb   %01100000	; x--     
ref_1B436	fcb   %01101000	; x-- y++ 
ref_1B437	fcb   %01100000	; x--     
ref_1B438	fcb   %01101000	; x-- y++ 
ref_1B439	fcb   %10001010	; image:  10
ref_1B43A	fcb   %01100000	; x--     
ref_1B43B	fcb   %01101000	; x-- y++ 
ref_1B43C	fcb   %01101100	; x-- y++ end flag

ref_1B43D	fcb   %10001010	; image:  10
ref_1B43E	fcb   %01101000	; x-- y++ 
ref_1B43F	fcb   %01101000	; x-- y++ 
ref_1B440	fcb   %01101000	; x-- y++ 
ref_1B441	fcb   %01101000	; x-- y++ 
ref_1B442	fcb   %10001011	; image:  11
ref_1B443	fcb   %01101000	; x-- y++ 
ref_1B444	fcb   %01101000	; x-- y++ 
ref_1B445	fcb   %01101100	; x-- y++ end flag

ref_1B446	fcb   %10001011	; image:  11
ref_1B447	fcb   %00001000	;     y++ 
ref_1B448	fcb   %01101000	; x-- y++ 
ref_1B449	fcb   %00001000	;     y++ 
ref_1B44A	fcb   %01101000	; x-- y++ 
ref_1B44B	fcb   %00001000	;     y++ 
ref_1B44C	fcb   %01101000	; x-- y++ 
ref_1B44D	fcb   %00001000	;     y++ 
ref_1B44E	fcb   %00001000	;     y++ 
ref_1B44F	fcb   %01101000	; x-- y++ 
ref_1B450	fcb   %10001100	; image:  12

ref_1B456	fcb   %10001100	; image:  12

ref_1B466	fcb   %10001101	; image:  13

ref_1B46F	fcb   %10001110	; image:  14

ref_1B479	fcb   %10001111	; image:  15

ref_1B488	fcb   %10000000	; image:  0
ref_1B489	fcb   %00100000	; x++     
ref_1B48A	fcb   %00100000	; x++     
ref_1B48B	fcb   %00100000	; x++     
ref_1B48C	fcb   %00100000	; x++     
ref_1B48D	fcb   %00100000	; x++     
ref_1B48E	fcb   %10000001	; image:  1
ref_1B48F	fcb   %00111000	; x++ y-- 
ref_1B490	fcb   %00100000	; x++     
ref_1B491	fcb   %00100000	; x++     
ref_1B492	fcb   %00100000	; x++     
ref_1B493	fcb   %00100000	; x++     
ref_1B494	fcb   %00111000	; x++ y-- 
ref_1B495	fcb   %00100000	; x++     
ref_1B496	fcb   %00100100	; x++     end flag

ref_1B497	fcb   %10000001	; image:  1
ref_1B498	fcb   %00111000	; x++ y-- 
ref_1B499	fcb   %00100000	; x++     
ref_1B49A	fcb   %00111000	; x++ y-- 
ref_1B49B	fcb   %00100000	; x++     
ref_1B49C	fcb   %10000010	; image:  2
ref_1B49D	fcb   %00111000	; x++ y-- 
ref_1B49E	fcb   %00100000	; x++     
ref_1B49F	fcb   %00111000	; x++ y-- 
ref_1B4A0	fcb   %00111100	; x++ y-- end flag

ref_1B4A1	fcb   %10000010	; image:  2
ref_1B4A2	fcb   %00111000	; x++ y-- 
ref_1B4A3	fcb   %00111000	; x++ y-- 
ref_1B4A4	fcb   %00111000	; x++ y-- 
ref_1B4A5	fcb   %00111000	; x++ y-- 
ref_1B4A6	fcb   %10000011	; image:  3
ref_1B4A7	fcb   %00111000	; x++ y-- 
ref_1B4A8	fcb   %00111000	; x++ y-- 
ref_1B4A9	fcb   %00111100	; x++ y-- end flag

ref_1B4AA	fcb   %10000011	; image:  3
ref_1B4AB	fcb   %00011000	;     y-- 
ref_1B4AC	fcb   %00111000	; x++ y-- 
ref_1B4AD	fcb   %00011000	;     y-- 
ref_1B4AE	fcb   %00111000	; x++ y-- 
ref_1B4AF	fcb   %00011000	;     y-- 
ref_1B4B0	fcb   %00111000	; x++ y-- 
ref_1B4B1	fcb   %00011000	;     y-- 
ref_1B4B2	fcb   %00011000	;     y-- 
ref_1B4B3	fcb   %00111000	; x++ y-- 
ref_1B4B4	fcb   %10000100	; image:  4

ref_1B4BA	fcb   %10000100	; image:  4

ref_1B4CA	fcb   %10000011	; image:  3
ref_1B4CB	fcb   %00111000	; x++ y-- 
ref_1B4CC	fcb   %00111000	; x++ y-- 
ref_1B4CD	fcb   %00111000	; x++ y-- 
ref_1B4CE	fcb   %00111000	; x++ y-- 
ref_1B4CF	fcb   %10000010	; image:  2
ref_1B4D0	fcb   %00111000	; x++ y-- 
ref_1B4D1	fcb   %00111000	; x++ y-- 
ref_1B4D2	fcb   %00111100	; x++ y-- end flag

ref_1B4D3	fcb   %10000010	; image:  2
ref_1B4D4	fcb   %00111000	; x++ y-- 
ref_1B4D5	fcb   %00111000	; x++ y-- 
ref_1B4D6	fcb   %00100000	; x++     
ref_1B4D7	fcb   %00111000	; x++ y-- 
ref_1B4D8	fcb   %10000001	; image:  1
ref_1B4D9	fcb   %00100000	; x++     
ref_1B4DA	fcb   %00111000	; x++ y-- 
ref_1B4DB	fcb   %00100000	; x++     
ref_1B4DC	fcb   %00111100	; x++ y-- end flag

ref_1B4DD	fcb   %10000001	; image:  1
ref_1B4DE	fcb   %00100000	; x++     
ref_1B4DF	fcb   %00100000	; x++     
ref_1B4E0	fcb   %00111000	; x++ y-- 
ref_1B4E1	fcb   %00100000	; x++     
ref_1B4E2	fcb   %00100000	; x++     
ref_1B4E3	fcb   %00100000	; x++     
ref_1B4E4	fcb   %00100000	; x++     
ref_1B4E5	fcb   %00111000	; x++ y-- 
ref_1B4E6	fcb   %10000000	; image:  0
ref_1B4E7	fcb   %00100000	; x++     
ref_1B4E8	fcb   %00100000	; x++     
ref_1B4E9	fcb   %00100000	; x++     
ref_1B4EA	fcb   %00100000	; x++     
ref_1B4EB	fcb   %00100100	; x++     end flag

ref_1B52E	fcb   %10001011	; image:  11
ref_1B52F	fcb   %01101000	; x-- y++ 
ref_1B530	fcb   %01101000	; x-- y++ 
ref_1B531	fcb   %01101000	; x-- y++ 
ref_1B532	fcb   %01101000	; x-- y++ 
ref_1B533	fcb   %10001010	; image:  10
ref_1B534	fcb   %01101000	; x-- y++ 
ref_1B535	fcb   %01101000	; x-- y++ 
ref_1B536	fcb   %01101100	; x-- y++ end flag

ref_1B537	fcb   %10001010	; image:  10
ref_1B538	fcb   %01101000	; x-- y++ 
ref_1B539	fcb   %01101000	; x-- y++ 
ref_1B53A	fcb   %01100000	; x--     
ref_1B53B	fcb   %01101000	; x-- y++ 
ref_1B53C	fcb   %01100000	; x--     
ref_1B53D	fcb   %10001001	; image:  9
ref_1B53E	fcb   %01101000	; x-- y++ 
ref_1B53F	fcb   %01100000	; x--     
ref_1B540	fcb   %01101100	; x-- y++ end flag

ref_1B541	fcb   %10001001	; image:  9
ref_1B542	fcb   %01100000	; x--     
ref_1B543	fcb   %01100000	; x--     
ref_1B544	fcb   %01101000	; x-- y++ 
ref_1B545	fcb   %01100000	; x--     
ref_1B546	fcb   %01100000	; x--     
ref_1B547	fcb   %01100000	; x--     
ref_1B548	fcb   %01100000	; x--     
ref_1B549	fcb   %01101000	; x-- y++ 
ref_1B54A	fcb   %10001000	; image:  8
ref_1B54B	fcb   %01100000	; x--     
ref_1B54C	fcb   %01100000	; x--     
ref_1B54D	fcb   %01100000	; x--     
ref_1B54E	fcb   %01100000	; x--     
ref_1B54F	fcb   %01100100	; x--     end flag

ref_1B550	fcb   %10001000	; image:  8
ref_1B551	fcb   %01100000	; x--     
ref_1B552	fcb   %01100000	; x--     
ref_1B553	fcb   %01100000	; x--     
ref_1B554	fcb   %01100000	; x--     
ref_1B555	fcb   %01100000	; x--     
ref_1B556	fcb   %01111000	; x-- y-- 
ref_1B557	fcb   %10000111	; image:  7

ref_1B55F	fcb   %10000111	; image:  7

ref_1B569	fcb   %10000110	; image:  6

ref_1B572	fcb   %10000101	; image:  5

; --- le decalage de repousse, par pose : un cercle de rayon 12 px arcade sur 16 directions. Cytron plante sa gomme DERRIERE lui -------------------------------------------
cytron.trail.tbl
	fdb   -12,0   ; pose 0
	fdb   -10,4   ; pose 1
	fdb   -8,8   ; pose 2
	fdb   -4,10   ; pose 3
	fdb   0,12   ; pose 4
	fdb   4,10   ; pose 5
	fdb   8,8   ; pose 6
	fdb   10,4   ; pose 7
	fdb   12,0   ; pose 8
	fdb   10,-4   ; pose 9
	fdb   8,-8   ; pose 10
	fdb   4,-10   ; pose 11
	fdb   0,-12   ; pose 12
	fdb   -4,-10   ; pose 13
	fdb   -8,-8   ; pose 14
	fdb   -10,-4   ; pose 15

