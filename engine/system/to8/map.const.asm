;*******************************************************************************
; Thomson TO8 - Memory map
; ------------------------------------------------------------------------------
;
; system addresses
;*******************************************************************************

 IFNDEF map.const.asm
map.const.asm equ 1

; -----------------------------------------------------------------------------
; memory map
map.ram.CART_START equ $0000
map.ram.CART_END   equ $4000
map.ram.VID_START  equ $4000
map.ram.VID_END    equ $6000
map.ram.SYS_START  equ $6000
map.ram.SYS_END    equ $A000
map.ram.DATA_START equ $A000
map.ram.DATA_END   equ $E000
map.ram.MON_START  equ $E000
map.ram.MON_END    equ $0000

; -----------------------------------------------------------------------------
; devices

; mc6846
map.MC6846.CSR      equ $E7C0
map.MC6846.PCR      equ $E7C1 ; (bit3) 0=unmute 1=mute
map.MC6846.DDR      equ $E7C2
map.MC6846.PDR      equ $E7C3 ; (bit0) set half ram page 0 (low or high) in video area ($4000-$5FFF)
map.MC6846.TCR      equ $E7C5 ; irq timer ctrl
map.MC6846.TMSB     equ $E7C6 ; irq timer MSB
map.MC6846.TLSB     equ $E7C7 ; irq timer LSB

; mc6821 system
map.MC6821.PRA      equ $E7C8
map.MC6821.PRB      equ $E7C9
map.MC6821.CRA      equ $E7CA
map.MC6821.CRB      equ $E7CB

; mc6821 music and game
map.MC6821.PRA1     equ $E7CC
map.MC6821.PRA2     equ $E7CD
map.MC6821.CRA1     equ $E7CE
map.MC6821.CRA2     equ $E7CF

; thmfc01 gate controler floppy disk
map.THMFC01.STAT0   equ $E7D0
map.THMFC01.CMD0    equ $E7D0
map.THMFC01.STAT1   equ $E7D1
map.THMFC01.CMD1    equ $E7D1
map.THMFC01.CMD2    equ $E7D2
map.THMFC01.WDATA   equ $E7D3
map.THMFC01.RDATA   equ $E7D3
map.THMFC01.WCLK    equ $E7D4
map.THMFC01.WSECT   equ $E7D5
map.THMFC01.TRCK    equ $E7D6
map.THMFC01.CELL    equ $E7D7

; ef9369 palette
map.EF9369.D        equ $E7DA
map.EF9369.A        equ $E7DB

; cf74021 gate array page mode - (TO8D: EFG2021FN)
map.CF74021.LGAMOD  equ $E7DC
map.CF74021.SYS2    equ $E7DD ; (bit0-3) set screen border color, (bit6-7) set onscreen video memory page
map.CF74021.COM     equ $E7E4
map.CF74021.DATA    equ $E7E5 ; (bit0-4) set ram page in data area ($A000-$DFFF)
map.CF74021.CART    equ $E7E6 ; (bit0-4) set page in cartridge area ($0000-$3FFF), (bit5) set ram over cartridge, (bit6) enable write
map.CF74021.SYS1    equ $E7E7 ; (bit4) set ram over data area

; extension port
map.EXTPORT         equ $E7
map.IEEE488         equ $E7F0 ; to E7F7
map.EF6850.CTRL     equ $E7F2 ; MIDI
map.EF6850.TX       equ $E7F3 ; MIDI
map.EF6850.RX       equ $E7F3 ; MIDI
map.MEA8000.D       equ $E7FE ; Vocal synth
map.MEA8000.A       equ $E7FF ; Vocal synth

; Musique PLUS Extension
map.MPLUS.EXT3      equ $E7F0 ; $E7F1 ; Extension 3
map.MPLUS.TIMER     equ $E7F4 ; $E7F5 ; MPlus Timer
map.MPLUS.CTRL      equ $E7F6 ; MPlus Ctrl.
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
map.MPLUS.EXT4      equ $E7F8 ; $E7FB ; Extension 4

; -----------------------------------------------------------------------------
; ROM routines
map.DKCONT          equ $E004 ; read sector
map.DKBOOT          equ $E007 ; boot
map.DKFMT           equ $E00A ; format
map.LECFA           equ $E00D ; read FAT
map.RECFI           equ $E010 ; search file
map.RECUP           equ $E010 ; clear file
map.ECRSE           equ $E010 ; sector write
map.ALLOD           equ $E019 ; catalog file allocation
map.ALLOB           equ $E01C ; bloc allocation
map.MAJCL           equ $E01F ; cluster update
map.FINTR           equ $E022 ; transfert end
map.QDDSTD          equ $E025 ; QDD std functions
map.QDDSYS          equ $E028 ; QDD sys functions

map.PUTC            equ $E803 ; display a char
map.GETC            equ $E806 ; read keyboard
map.KTST            equ $E809 ; test keyboard
map.DRAW            equ $E80C ; draw a line
map.PLOT            equ $E80F ; draw a plot
; ...
map.DKCO            equ $E82A ; read or write floppy disk routine
; ..
map.IRQ.EXIT        equ $E830 ; to exit an irq
map.SETP            equ $EC00 ; set color palette

; -----------------------------------------------------------------------------
; system monitor registers
map.REG.DP          equ $60   ; direct page for system monitor registers
map.STATUS          equ $6019 ; status bitfield
map.STATUS.IRQ      equ %00100000 ; IRQ custom timer routine enabled
map.DK.OPC          equ $6048 ; operation
map.DK.DRV          equ $6049 ; drive
map.DK.SEC          equ $604C ; sector
map.DK.TRK          equ $604A ; $604B ; track
map.DK.STA          equ $604E ; return status
map.DK.BUF          equ $604F ; $6050 ; data write location
map.IRQPT           equ $6021 ; $6022 ; routine - irq
map.FIRQPT          equ $6023 ; $6024 ; routine - firq
map.TIMERPT         equ $6027 ; $6028 ; routine - irq timer
map.CONFIG          equ $6074 ; péripherial flags, bit 6 (6821 Extension jeux et musique)
map.CF74021.SYS1.R  equ $6081 ; reading value for map.CF74021.SYS1

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

map.RAM_OVER_CART     equ %01100000

; -----------------------------------------------------------------------------
; mapping to generic names

map.DAC            equ map.MC6821.PRA2
map.RND            equ map.MC6846.TMSB
map.HALFPAGE       equ map.MC6846.PDR

    ENDC