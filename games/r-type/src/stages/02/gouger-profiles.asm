; GENERE par tools/gen_gouger_profiles.py — ne pas editer a la main.
; Un profil par gouger de la wave : x de spawn (monde), puis les runs
; bit 7 = 1 reptation / 0 plongee, bits 0-6 = trames ; 0 = fin.
; Le 4e octet du descripteur de wave est l'index dans cette table.
stage.gougerProfiles EXPORT
stage.gougerProfiles
        fdb   gouger.profile.0
        fdb   gouger.profile.1
        fdb   gouger.profile.2
        fdb   gouger.profile.3
        fdb   gouger.profile.4
        fdb   gouger.profile.5
        fdb   gouger.profile.6
        fdb   gouger.profile.7
        fdb   gouger.profile.8
        fdb   gouger.profile.9
        fdb   gouger.profile.10
        fdb   gouger.profile.11
        fdb   gouger.profile.12
        fdb   gouger.profile.13
        fdb   gouger.profile.14
        fdb   gouger.profile.15
        fdb   gouger.profile.16
        fdb   gouger.profile.17
        fdb   gouger.profile.18
        fdb   gouger.profile.19
        fdb   gouger.profile.20
        fdb   gouger.profile.21
        fdb   gouger.profile.22
        fdb   gouger.profile.23
        fdb   gouger.profile.24
        fdb   gouger.profile.25
        fdb   gouger.profile.26
        fdb   gouger.profile.27
        fdb   gouger.profile.28
gouger.profile.0
        fdb   195                ; t=$00C8 var 2 (param $0A), 241 trames, 3 runs
        fcb   $AB,$58,$EE,0
gouger.profile.1
        fdb   233                ; t=$0190 var 0 (param $00), 219 trames, 3 runs
        fcb   $A6,$60,$D5,0
gouger.profile.2
        fdb   270                ; t=$0258 var 1 (param $01), 243 trames, 3 runs
        fcb   $B6,$58,$E5,0
gouger.profile.3
        fdb   308                ; t=$0320 var 3 (param $07), 229 trames, 3 runs
        fcb   $9B,$5C,$EE,0
gouger.profile.4
        fdb   341                ; t=$03D4 var 1 (param $01), 237 trames, 5 runs
        fcb   $A6,$02,$88,$58,$E5,0
gouger.profile.5
        fdb   364                ; t=$044C var 2 (param $02), 241 trames, 3 runs
        fcb   $AB,$58,$EE,0
gouger.profile.6
        fdb   366                ; t=$0456 var 0 (param $00), 264 trames, 4 runs
        fcb   $B6,$51,$FF,$82,0
gouger.profile.7
        fdb   368                ; t=$0460 var 2 (param $0E), 235 trames, 5 runs
        fcb   $AB,$58,$8B,$02,$DB,0
gouger.profile.8
        fdb   409                ; t=$053C var 3 (param $07), 220 trames, 5 runs
        fcb   $9B,$5C,$84,$03,$DE,0
gouger.profile.9
        fdb   409                ; t=$053C var 1 (param $05), 207 trames, 3 runs
        fcb   $96,$64,$D5,0
gouger.profile.10
        fdb   435                ; t=$05C8 var 2 (param $02), 241 trames, 3 runs
        fcb   $AB,$58,$EE,0
gouger.profile.11
        fdb   458                ; t=$0640 var 1 (param $01), 219 trames, 3 runs
        fcb   $A6,$60,$D5,0
gouger.profile.12
        fdb   465                ; t=$0668 var 3 (param $03), 205 trames, 5 runs
        fcb   $9B,$60,$82,$04,$CC,0
gouger.profile.13
        fdb   495                ; t=$0708 var 0 (param $00), 267 trames, 4 runs
        fcb   $B6,$50,$FF,$86,0
gouger.profile.14
        fdb   534                ; t=$07DA var 3 (param $03), 259 trames, 4 runs
        fcb   $AB,$52,$FF,$87,0
gouger.profile.15
        fdb   536                ; t=$07E4 var 0 (param $0C), 231 trames, 3 runs
        fcb   $B6,$5C,$D5,0
gouger.profile.16
        fdb   551                ; t=$0834 var 3 (param $03), 265 trames, 3 runs
        fcb   $CB,$50,$EE,0
gouger.profile.17
        fdb   593                ; t=$0910 var 0 (param $00), 255 trames, 3 runs
        fcb   $C6,$54,$E5,0
gouger.profile.18
        fdb   604                ; t=$094C var 2 (param $02), 229 trames, 3 runs
        fcb   $AB,$5C,$DE,0
gouger.profile.19
        fdb   649                ; t=$0A3C var 1 (param $01), 219 trames, 3 runs
        fcb   $A6,$60,$D5,0
gouger.profile.20
        fdb   653                ; t=$0A50 var 0 (param $04), 249 trames, 3 runs
        fcb   $AB,$56,$F8,0
gouger.profile.21
        fdb   673                ; t=$0ABC var 3 (param $07), 238 trames, 3 runs
        fcb   $AB,$59,$EA,0
gouger.profile.22
        fdb   683                ; t=$0AF0 var 1 (param $01), 219 trames, 3 runs
        fcb   $96,$60,$E5,0
gouger.profile.23
        fdb   714                ; t=$0B98 var 2 (param $02), 253 trames, 3 runs
        fcb   $BB,$54,$EE,0
gouger.profile.24
        fdb   750                ; t=$0C58 var 2 (param $02), 217 trames, 3 runs
        fcb   $9B,$60,$DE,0
gouger.profile.25
        fdb   795                ; t=$0D48 var 3 (param $03), 262 trames, 6 runs
        fcb   $9B,$01,$8C,$50,$FF,$8F,0
gouger.profile.26
        fdb   833                ; t=$0E10 var 2 (param $02), 235 trames, 5 runs
        fcb   $AB,$58,$8B,$02,$DB,0
gouger.profile.27
        fdb   833                ; t=$0E10 var 0 (param $00), 258 trames, 4 runs
        fcb   $AB,$53,$FF,$85,0
gouger.profile.28
        fdb   853                ; t=$0E7C var 1 (param $01), 219 trames, 3 runs
        fcb   $A6,$60,$D5,0
