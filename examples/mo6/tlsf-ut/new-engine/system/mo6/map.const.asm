; Thomson MO6 - Memory map

; -----------------------------------------------------------------------------
; system addresses

; mc6846
map.MC6846.CSR      equ $A7C0
map.MC6846.CRC      equ $A7C1
map.MC6846.DDRC     equ $A7C2
map.MC6846.PRC      equ $A7C3 ; (bit0) set half ram page 0 (low or high) in video area ($0000-$1FFF)
map.MC6846.CSR2     equ $A7C4
map.MC6846.TCR      equ $A7C5 ; irq timer ctrl
map.MC6846.TMSB     equ $A7C6 ; irq timer MSB
map.MC6846.TLSB     equ $A7C7 ; irq timer LSB

; mc6821 system
map.MC6821.PRA      equ $A7C8
map.MC6821.PRB      equ $A7C9
map.MC6821.CRA      equ $A7CA
map.MC6821.CRB      equ $A7CB

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

; cf74021 gate array page mode - (TO8D: EFG2021FN)
map.CF74021.LGAMOD  equ $A7DC
map.CF74021.SYS2    equ $A7DD ; (bit0-3) set screen border color, (bit6-7) set onscreen video memory page
map.CF74021.COM     equ $A7E4
map.CF74021.DATA    equ $A7E5 ; (bit0-4) set ram page in data area ($6000-$9FFF)
map.CF74021.CART    equ $A7E6 ; (bit0-4) set page in cartridge area ($B000-$EFFF), (bit5) set ram over cartridge, (bit6) enable write
map.CF74021.SYS1    equ $A7E7 ; (bit4) set ram over data area

; extension port
map.EXTPORT         equ $A7
map.IEEE488         equ $A7F0 ; to A7F7
map.EF5860.CTRL     equ $A7F2 ; MIDI
map.EF5860.TX       equ $A7F3 ; MIDI
 ifndef SOUND_CARD_PROTOTYPE
map.YM2413.A        equ $A7FC
map.YM2413.D        equ $A7FD
map.SN76489.D       equ $A7F7
 else
map.YM2413.A        equ $A7FC
map.YM2413.D        equ $A7FD
map.SN76489.D       equ $A7FF
 endc
map.MEA8000.D       equ $A7FE
map.MEA8000.A       equ $A7FF

; ROM routines
map.DKCONT          equ $A004 ; TO:DKCO, MO:SWI $26
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

map.PUTC            equ $A803
map.GETC            equ $A806
map.KTST            equ $A809
map.DKCO            equ $A82A ; read or write floppy disk routine
map.IRQ.EXIT        equ $A830 ; to exit an irq

; system monitor registers
map.REG.DP          equ $20   ; direct page for system monitor registers
map.STATUS          equ $2019 ; status bitfield
map.DK.OPC          equ $2048 ; operation
map.DK.DRV          equ $2049 ; drive
map.DK.SEC          equ $204C ; sector
map.DK.TRK          equ $204A ; $204B ; track
map.DK.STA          equ $204E ; return status
map.DK.BUF          equ $204F ; $2050 ; data write location
map.FIRQPT          equ $2023 ; routine firq
map.TIMERPT         equ $2027 ; routine irq timer
map.CF74021.SYS1.R  equ $2081 ; reading value for map.CF74021.SYS1

; -----------------------------------------------------------------------------
; constants

map.EF5860.TX_IRQ_ON  equ %00110101 ; 8bits, no parity check, stop 1, tx interrupt
map.EF5860.TX_IRQ_OFF equ %00010101 ; 8bits, no parity check, stop 1, no interrupt
map.IRQ.ONE_FRAME     equ 312*64-1  ; one frame timer (lines*cycles_per_lines-1), timer launch at -1

; -----------------------------------------------------------------------------
; mapping to generic names

map.DAC            equ map.MC6821.PRA2
map.RND            equ map.MC6846.TMSB
