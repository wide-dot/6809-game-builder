#Joypad

## Thomson controller
### Pinout
    pin 1 : up
    pin 2 : down
    pin 3 : left
    pin 4 : right
    pin 5 : +5v
    pin 6 : A
    pin 7 : B
    pin 8 : ground
    pin 9 : <not connected>

### Joypads direction

    Register: $A7CC/$E7CC (8bits)
   
    Joypad2     Joypad1
    1111        1111 (0: press | 1: release)  
    ||||_Up     ||||_Up
    |||__Down   |||__Down
    ||___Left   ||___Left
    |____Right  |____Right
   
### Joypads bouttons

    Register: $A7CD/$E7CD (8bits)
   
      [------] 6 bits DAC
    11 001100 (0: press | 1: release) 
    ||   ||
    ||   ||_ Btn B Joypad1
    ||   |__ Btn B Joypad2
    ||
    ||______ Btn A Joypad1
    |_______ Btn A Joypad2

### Registers

    $E7CE/$E7CF (bit 2) allows selection of a register in $A7CC/E7CC and $A7CD/E7CD:
    (bit2) 0: Data Direction Register A (DDRA)
    (bit2) 1: Peripherial Interface A (PIA) Register

## Mega Drive controller
### Six button control pad
#### Pinout
    pin 1 : up/Z
    pin 2 : down/Y
    pin 3 : left/X
    pin 4 : right/mode
    pin 5 : +5v
    pin 6 : B/A
    pin 7 : line select
    pin 8 : ground
    pin 9 : C/Start

#### Line select sequence
WARNING : current cycle id is reset to cycle 1 every 20ms
6 button gamepad can be detected by testing TDLR to ON (0) on cycle 6
3 button gamepad can be detected by testing LR to ON (0) on cycle 2,4,6

    Cycle  TH out  TR in  TL in   D3 in  D2 in  D1 in  D0 in
    1      HI      C      B       Right  Left   Down   Up
    2      LO      Start  A       0      0      Down   Up
    3      HI      C      B       Right  Left   Down   Up
    4      LO      Start  A       0      0      Down   Up
    5      HI      C      B       Right  Left   Down   Up
    6      LO      Start  A       0      0      0      0
    7      HI      C      B       Mode   X      Y      Z
    8      LO      Start  A       1      1      1      1