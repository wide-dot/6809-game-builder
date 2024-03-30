;*******************************************************************************
; Thomson MO6 - Memory map

; ------------------------------------------------------------------------------
;
; system addresses
;*******************************************************************************

 IFNDEF map.const.asm
map.const.asm equ 1

; -----------------------------------------------------------------------------
; memory map
map.ram.VID_START  equ $0000
map.ram.VID_END    equ $2000
map.ram.SYS_START  equ $2000
map.ram.SYS_END    equ $6000
map.ram.DATA_START equ $6000
map.ram.DATA_END   equ $A000
map.ram.MON_START  equ $A000
map.ram.MON_END    equ $B000
map.ram.CART_START equ $B000
map.ram.CART_END   equ $F000
map.ram.MON2_START equ $F000
map.ram.MON2_END   equ $0000

; -----------------------------------------------------------------------------
; devices

; mc6821 system
map.MC6821.PRA      equ $A7C0
map.MC6821.PRB      equ $A7C1
map.MC6821.CRA      equ $A7C2
map.MC6821.CRB      equ $A7C3

; mc6821 music and game
map.MC6821.PRA1     equ $A7CC
map.MC6821.PRA2     equ $A7CD
map.MC6821.CRA1     equ $A7CE
map.MC6821.CRA2     equ $A7CF

; thmfc01 gate controler floppy disk
map.THMFC01.STAT0   equ $A7D0
map.THMFC01.CMD0    equ $A7D0
map.THMFC01.STAT1   equ $A7D1
map.THMFC01.CMD1    equ $A7D1
map.THMFC01.CMD2    equ $A7D2
map.THMFC01.WDATA   equ $A7D3
map.THMFC01.RDATA   equ $A7D3
map.THMFC01.WCLK    equ $A7D4
map.THMFC01.WSECT   equ $A7D5
map.THMFC01.TRCK    equ $A7D6
map.THMFC01.CELL    equ $A7D7

; ef9369 palette
map.EF9369.D        equ $A7DA
map.EF9369.A        equ $A7DB

; gate array page mode
map.CF74021.LGAMOD  equ $A7DC
map.CF74021.SYS2    equ $A7DD ; (bit0-3) set screen border color, (bit6-7) set onscreen video memory page
map.CF74021.COM     equ $A7E4
map.CF74021.DATA    equ $A7E5 ; (bit0-4) set ram page in data area ($6000-$9FFF)
map.CF74021.CART    equ $A7E6 ; (bit0-4) set page in cartridge area ($B000-$EFFF), (bit5) set ram over cartridge, (bit6) enable write
map.CF74021.SYS1    equ $A7E7 ; (bit4) set ram over data area

; interface (RS232)
map.SIOTRANSM       equ $A7E8
map.SIORECEPT       equ $A7E8
map.SIORESET        equ $A7E9
map.SIOSTATUS       equ $A7E9
map.SIOCMDE         equ $A7EA
map.SIOCNTRL        equ $A7EB

; extension port
map.EXTPORT         equ $A7
map.IEEE488         equ $A7F0 ; to A7F7
map.EF5860.CTRL     equ $A7F2 ; MIDI
map.EF5860.TX       equ $A7F3 ; MIDI
map.MEA8000.D       equ $A7FE ; Vocal synth
map.MEA8000.A       equ $A7FF ; Vocal synth

; Musique PLUS Extension
map.MPLUS.EXT3      equ $A7F0 ; $E7F1 ; Extension 3
map.MPLUS.TIMER     equ $A7F4 ; $E7F5 ; MPlus Timer
map.MPLUS.CTRL      equ $A7F6 ; MPlus Ctrl.
                              ; Bit 7: R- TI    - READY pin
                              ; Bit 6: RW TI    - clock disable (silent audio)
                              ; Bit 5: -------- - unused bit
                              ; Bit 4: RW Timer - IRQ select    (0=FIRQ, 1=IRQ)
                              ; Bit 3: RW Timer - (F)IRQ enable
                              ; Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
                              ; Bit 1: RW Timer - enable countdown of counter
                              ; Bit 0: -W Timer - reset timer (0=do nothing, 1=reload period to counter)
map.MPLUS.EXT4      equ $A7F8 ; $E7FB ; Extension 4

; -----------------------------------------------------------------------------
; ROM routines
map.DKCONT          equ $A004 ; read sector
map.DKBOOT          equ $A007 ; boot
map.DKFMT           equ $A00A ; format
map.LECFA           equ $A00D ; read FAT
map.RECFI           equ $A010 ; search file
map.RECUP           equ $A010 ; clear file
map.ECRSE           equ $A010 ; sector write
map.ALLOD           equ $A019 ; catalog file allocation
map.ALLOB           equ $A01C ; bloc allocation
map.MAJCL           equ $A01F ; cluster update
map.FINTR           equ $A022 ; transfert end
map.QDDSTD          equ $A025 ; QDD std functions
map.QDDSYS          equ $A028 ; QDD sys functions

map.JSR_MENU        equ $00 ; Retour au menu
map.JSR_PUTC        equ $02 ; Affichage d'un caractère
map.JSR_FRM0        equ $04 ; Mise en mémoire couleur
map.JSR_FRM1        equ $06 ; Mise en mémoire forme
map.JSR_BIIP        equ $08 ; Emission d'un bip sonore
map.JSR_GETC        equ $0A ; Lecture du clavier
map.JSR_KTST        equ $0C ; Lecture rapide du clavier
map.JSR_DRAW        equ $0E ; Tracé d'un segment de droite
map.JSR_PLOT        equ $10 ; Allumage ou exctinction d'un point
map.JSR_CHPL        equ $12 ; Ecriture d'un point "caractères"
map.JSR_GETP        equ $14 ; Lecture de la couleur d'un point
map.JSR_LPIN        equ $16 ; Lecture du bouton du crayon optique
map.JSR_GETL        equ $18 ; Lecture du crayon optique
map.JSR_GETS        equ $1A ; Lecture de l'écran
map.JSR_JOYS        equ $1C ; Lecture des manettes de jeu
map.JSR_NOTE        equ $1E ; Génération de musique
map.JSR_K7CO        equ $20 ; Lecture/écrituresur la cassette
map.JSR_K7MO        equ $22 ; Mise en route/arrêt du moteur
map.JSR_PRCO        equ $24 ; Gestion de l'interface parallèle
map.JSR_DKCO        equ $26 ; Contrôleur de disquette
map.JSR_DKBOOT      equ $28 ; Lancement du boot
map.JSR_DKFMT       equ $2A ; Formattage disquette
map.JSR_ALLOB       equ $2C ; Allocation d'un bloc
map.JSR_ALLOD       equ $2E ; Allocation de depart 
map.JSR_ECRSE       equ $30 ; Ecriture d'un secteur
map.JSR_FINTR       equ $32 ; Fin du transfert
map.JSR_LECFA       equ $34 ; Lecture de la fat
map.JSR_MAJCL       equ $36 ; Mise a jour cluster
map.JSR_RECFI       equ $38 ; Recherche d'un fichier
map.JSR_RECUP       equ $3A ; Recuperation de la place occupee
map.JSR_SETP        equ $3C ; Programmation de la palette
map.JSR_MOUSEB      equ $3E ; Lecture des boutons de la souris
map.JSR_MOUSE       equ $40 ; Lecture de la souris
map.JSR_RSCO        equ $42 ; Gestion de la RS232

map.JMP_MENU        equ $80+map.JSR_MENU   ; Retour au menu
map.JMP_PUTC        equ $80+map.JSR_PUTC   ; Affichage d'un caractère
map.JMP_FRM0        equ $80+map.JSR_FRM0   ; Mise en mémoire couleur
map.JMP_FRM1        equ $80+map.JSR_FRM1   ; Mise en mémoire forme
map.JMP_BIIP        equ $80+map.JSR_BIIP   ; Emission d'un bip sonore
map.JMP_GETC        equ $80+map.JSR_GETC   ; Lecture du clavier
map.JMP_KTST        equ $80+map.JSR_KTST   ; Lecture rapide du clavier
map.JMP_DRAW        equ $80+map.JSR_DRAW   ; Tracé d'un segment de droite
map.JMP_PLOT        equ $80+map.JSR_PLOT   ; Allumage ou exctinction d'un point
map.JMP_CHPL        equ $80+map.JSR_CHPL   ; Ecriture d'un point "caractères"
map.JMP_GETP        equ $80+map.JSR_GETP   ; Lecture de la couleur d'un point
map.JMP_LPIN        equ $80+map.JSR_LPIN   ; Lecture du bouton du crayon optique
map.JMP_GETL        equ $80+map.JSR_GETL   ; Lecture du crayon optique
map.JMP_GETS        equ $80+map.JSR_GETS   ; Lecture de l'écran
map.JMP_JOYS        equ $80+map.JSR_JOYS   ; Lecture des manettes de jeu
map.JMP_NOTE        equ $80+map.JSR_NOTE   ; Génération de musique
map.JMP_K7CO        equ $80+map.JSR_K7CO   ; Lecture/écrituresur la cassette
map.JMP_K7MO        equ $80+map.JSR_K7MO   ; Mise en route/arrêt du moteur
map.JMP_PRCO        equ $80+map.JSR_PRCO   ; Gestion de l'interface parallèle
map.JMP_DKCO        equ $80+map.JSR_DKCO   ; Contrôleur de disquette
map.JMP_DKBOOT      equ $80+map.JSR_DKBOOT ; Lancement du boot
map.JMP_DKFMT       equ $80+map.JSR_DKFMT  ; Formattage disquette
map.JMP_ALLOB       equ $80+map.JSR_ALLOB  ; Allocation d'un bloc
map.JMP_ALLOD       equ $80+map.JSR_ALLOD  ; Allocation de depart 
map.JMP_ECRSE       equ $80+map.JSR_ECRSE  ; Ecriture d'un secteur
map.JMP_FINTR       equ $80+map.JSR_FINTR  ; Fin du transfert
map.JMP_LECFA       equ $80+map.JSR_LECFA  ; Lecture de la fat
map.JMP_MAJCL       equ $80+map.JSR_MAJCL  ; Mise a jour cluster
map.JMP_RECFI       equ $80+map.JSR_RECFI  ; Recherche d'un fichier
map.JMP_RECUP       equ $80+map.JSR_RECUP  ; Recuperation de la place occupee
map.JMP_SETP        equ $80+map.JSR_SETP   ; Programmation de la palette
map.JMP_MOUSEB      equ $80+map.JSR_MOUSEB ; Lecture des boutons de la souris
map.JMP_MOUSE       equ $80+map.JSR_MOUSE  ; Lecture de la souris
map.JMP_RSCO        equ $80+map.JSR_RSCO   ; Gestion de la RS232

; -----------------------------------------------------------------------------
; system monitor registers
map.REG.DP          equ $20   ; direct page for system monitor registers
map.STATUS          equ $2019 ; status bitfield
map.DK.OPC          equ $2048 ; operation
map.DK.DRV          equ $2049 ; drive
map.DK.SEC          equ $204C ; sector
map.DK.TRK          equ $204A ; $204B ; track
map.DK.STA          equ $204E ; return status
map.DK.BUF          equ $204F ; $2050 ; data write location
map.TIMERPT         equ $2061 ; routine irq timer
map.IRQSEMAPHORE    equ $2063 ; irq semaphore
map.IRQPT           equ $2064 ; routine irq
map.FIRQPT          equ $2067 ; routine firq
map.CHRPTR          equ $20FD ; 
map.LATCLV          equ $2076 ; keyboard repeat latency
map.CF74021.SYS1.R  equ $2081 ; reading value for map.CF74021.SYS1

; -----------------------------------------------------------------------------
; constants

map.EF5860.TX_IRQ_ON  equ %00110101 ; 8bits, no parity check, stop 1, tx interrupt
map.EF5860.TX_IRQ_OFF equ %00010101 ; 8bits, no parity check, stop 1, no interrupt
map.RAM_OVER_CART     equ %01100000
map.STATUS.MINUSCULE  equ %10000000
map.STATUS.SCROLL     equ %01000000
map.STATUS.QWERTY     equ %00100000
map.STATUS.GFXFORM    equ %00010000
map.STATUS.CUTBUZZER  equ %00001000
map.STATUS.CURSOR     equ %00000100
map.STATUS.KEYREPEAT  equ %00000010
map.STATUS.KEYREAD    equ %00000001

; -----------------------------------------------------------------------------
; mapping to generic names

map.DAC            equ map.MC6821.PRA2
map.RND            equ map.MC6846.TMSB
map.HALFPAGE       equ map.MC6821.PRA

    ENDC