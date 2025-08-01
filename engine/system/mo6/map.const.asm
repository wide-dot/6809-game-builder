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
map.EF6850.CTRL     equ $A7F2 ; MIDI
map.EF6850.TX       equ $A7F3 ; MIDI
map.EF6850.RX       equ $A7F3 ; MIDI
map.MEA8000.D       equ $A7FE ; Vocal synth
map.MEA8000.A       equ $A7FF ; Vocal synth

; Musique PLUS Extension
map.MPLUS.EXT3      equ $A7F0 ; $E7F1 ; Extension 3
map.MPLUS.TIMER     equ $A7F4 ; $E7F5 ; MPlus Timer
map.MPLUS.CTRL      equ $A7F6 ; MPlus Ctrl.
                              ; Control/status register
                              ;   Bit 7: R- Timer - INT requested by timer (0=NO, 1=YES)
                              ;          -W Timer - reset timer (0=do nothing, 1=reload period to counter)
                              ;   Bit 6: -------  - Unused
                              ;   Bit 5: -------  - Unused
                              ;   Bit 4: RW Timer - INT select (0=IRQ, 1=FIRQ)
                              ;   Bit 3: RW Timer - (F)IRQ enable (0=NO, 1=YES)
                              ;   Bit 2: RW Timer - clock select (0=1Mhz, 1=3.579545Mhz)
                              ;   Bit 1: RW Timer - enable countdown of timer (0=OFF, 1=ON)
                              ;   Bit 0: RW TI    - TI clock disable (0=enabled, 1=disabled)
                              ;   Note: Timer F/IRQ ack by CPU is done by reading this control register
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

; EF6850 ACIA Control Register (Write)
; Bits 7-0: CR7 CR6 CR5 CR4 CR3 CR2 CR1 CR0
; CR7    : Receive Interrupt Enable
; CR6-CR5: Transmitter Control
;          00 = RTS=low, TX INT disabled
;          01 = RTS=low, TX INT enabled
;          10 = RTS=high, TX INT disabled
;          11 = RTS=low, Transmit Break, TX INT disabled
; CR4-CR2: Word Select
;          000 = 7E2 (7 bits + Even Parity + 2 Stop Bits)
;          001 = 7O2 (7 bits + Odd Parity + 2 Stop Bits)
;          010 = 7E1 (7 bits + Even Parity + 1 Stop Bit)
;          011 = 7O1 (7 bits + Odd Parity + 1 Stop Bit)
;          100 = 8N2 (8 bits + No Parity + 2 Stop Bits)
;          101 = 8N1 (8 bits + No Parity + 1 Stop Bit)
;          110 = 8E1 (8 bits + Even Parity + 1 Stop Bit)
;          111 = 8O1 (8 bits + Odd Parity + 1 Stop Bit)
; CR1-CR0: Clock Divide Select
;          00 = ÷1
;          01 = ÷16
;          10 = ÷64
;          11 = Master Reset

; EF6850 ACIA Status Register (Read)
; Bits 7-0: IRQ PARITY OVERRUN FRAMING CTS DCD TDRE RDRF
; IRQ    : Interrupt Request (1=interrupt)
; PARITY : Parity Error (1=error)
; OVERRUN: Receiver Overrun (1=error)
; FRAMING: Framing Error (1=error)
; CTS    : Clear To Send (1=clear to send)
; DCD    : Data Carrier Detect (1=carrier present)
; TDRE   : Transmit Data Register Empty (1=empty)
; RDRF   : Receive Data Register Full (1=full)

; Control Register masks for MIDI (31250 bauds)
map.EF6850.MIDI       equ %00010101 ; ÷16 (CR1-0=01), 8N1 (CR4-2=101), No TX/RX INT (CR7=0,CR6-5=00)
map.EF6850.TX_ON      equ %00100000 ; CR6-5=01 (RTS=low, TX INT enabled)
map.EF6850.TX_OFF     equ %00000000 ; CR6-5=00 (RTS=low, TX INT disabled)
map.EF6850.RX_ON      equ %10000000 ; CR7=1 (RX INT enabled)
map.EF6850.RX_OFF     equ %00000000 ; CR7=0 (RX INT disabled)

; Status Register masks
map.EF6850.STAT_IRQ   equ %10000000 ; IRQ requested
map.EF6850.STAT_PE    equ %01000000 ; Parity error
map.EF6850.STAT_OVRN  equ %00100000 ; Overrun error
map.EF6850.STAT_FE    equ %00010000 ; Framing error
map.EF6850.STAT_CTS   equ %00001000 ; Clear to send
map.EF6850.STAT_DCD   equ %00000100 ; Data carrier detect
map.EF6850.STAT_TDRE  equ %00000010 ; TX data register empty
map.EF6850.STAT_RDRF  equ %00000001 ; RX data register full

; MEA8000 Control Register values
map.MEA8000.STOP_SLOW      equ $1A ; Recommended configuration (ROE=0, polling mode)
map.MEA8000.STOP_IMMEDIATE equ $10 ; Immediate stop only
map.MEA8000.INTERRUPT_MODE equ $1B ; External interrupt mode (ROE=1)
map.MEA8000.CONTINUOUS     equ $1E ; Continuous operation (STOP=0, CONT_E=1, CONT=1, ROE_E=1, ROE=0)

; MEA8000 Control Register bit masks
map.MEA8000.STOP_BIT       equ %00010000 ; Bit 4: STOP (0=normal, 1=stop)
map.MEA8000.CONT_E_BIT     equ %00001000 ; Bit 3: CONT_E (enable CONT bit)
map.MEA8000.CONT_BIT       equ %00000100 ; Bit 2: CONT (frame repeat)
map.MEA8000.ROE_E_BIT      equ %00000010 ; Bit 1: ROE_E (enable ROE bit)
map.MEA8000.ROE_BIT        equ %00000001 ; Bit 0: ROE (0=internal REQ, 1=external REQ)

; MEA8000 Status Register bit masks
map.MEA8000.REQ_BIT        equ %10000000 ; Bit 7: REQ (0=busy, 1=ready)

; STATUS bit masks
map.STATUS.MINUSCULE  equ %10000000
map.STATUS.SCROLL     equ %01000000
map.STATUS.QWERTY     equ %00100000
map.STATUS.GFXFORM    equ %00010000
map.STATUS.CUTBUZZER  equ %00001000
map.STATUS.CURSOR     equ %00000100
map.STATUS.KEYREPEAT  equ %00000010
map.STATUS.KEYREAD    equ %00000001

; MC6821.PRA bit masks
map.MC6821.PRA.HALFPAGE  equ %00000001
map.MC6821.PRA.PEN_BTN   equ %00000010
map.MC6821.PRA.DAC_MUTE  equ %00000100
map.MC6821.PRA.KEYB_LN8  equ %00001000
map.MC6821.PRA.SHIFTLOCK equ %00010000
map.MC6821.PRA.ROM_BANK  equ %00100000
map.MC6821.PRA.K7_WRITE  equ %01000000
map.MC6821.PRA.K7_READ   equ %10000000

map.RAM_OVER_CART     equ %01100000

; -----------------------------------------------------------------------------
; mapping to generic names

map.DAC            equ map.MC6821.PRA2
; map.RND            equ map.MC6846.TMSB find a register for random !
map.HALFPAGE       equ map.MC6821.PRA
map.DAC_MUTE       equ map.MC6821.PRA
map.bit.DAC_MUTE   equ map.MC6821.PRA.DAC_MUTE

    ENDC