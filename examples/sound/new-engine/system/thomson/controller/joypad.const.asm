; masks for variables : 
; ---------------------
; joypad.state.dpad
; joypad.held.dpad
; joypad.pressed.dpad

joypad.x.UP    equ   %00010001 
joypad.x.DOWN  equ   %00100010 
joypad.x.LEFT  equ   %01000100 
joypad.x.RIGHT equ   %10001000 

joypad.0.DPAD  equ   %00001111 
joypad.0.UP    equ   %00000001 
joypad.0.DOWN  equ   %00000010 
joypad.0.LEFT  equ   %00000100 
joypad.0.RIGHT equ   %00001000 

joypad.1.DPAD  equ   %11110000
joypad.1.UP    equ   %00010000 
joypad.1.DOWN  equ   %00100000  
joypad.1.LEFT  equ   %01000000 
joypad.1.RIGHT equ   %10000000 

; masks for variables : 
; ---------------------
; joypad.state.fire
; joypad.held.fire
; joypad.pressed.fire

joypad.x.A     equ   %11000000 
joypad.x.B     equ   %00001100 

joypad.0.FIRE  equ   %01000100 
joypad.0.A     equ   %01000000 
joypad.0.B     equ   %00000100 

joypad.1.FIRE  equ   %10001000
joypad.1.A     equ   %10000000 
joypad.1.B     equ   %00001000 

; masks for variables : 
; ---------------------
; joypad.md6.held.dpad
; joypad.md6.pressed.dpad

joypad.md6.x.UP    equ   %00010001
joypad.md6.x.DOWN  equ   %00100010
joypad.md6.x.LEFT  equ   %01000100
joypad.md6.x.RIGHT equ   %10001000

joypad.md6.0.DPAD  equ   %00001111
joypad.md6.0.UP    equ   %00000001
joypad.md6.0.DOWN  equ   %00000010
joypad.md6.0.LEFT  equ   %00000100
joypad.md6.0.RIGHT equ   %00001000

joypad.md6.1.DPAD  equ   %11110000
joypad.md6.1.UP    equ   %00010000
joypad.md6.1.DOWN  equ   %00100000
joypad.md6.1.LEFT  equ   %01000000
joypad.md6.1.RIGHT equ   %10000000

; masks for variables : 
; ---------------------
; joypad.md6.held.fire
; joypad.md6.pressed.fire

joypad.md6.x.B equ   %11000000
joypad.md6.x.A equ   %00110000

joypad.md6.0.B equ   %01000000
joypad.md6.0.A equ   %00010000

joypad.md6.1.B equ   %10000000
joypad.md6.1.A equ   %00100000

; masks for variables : 
; ---------------------
; joypad.md6.held.fireExt
; joypad.md6.pressed.fireExt

joypad.md6.x.Z    equ   %00010001
joypad.md6.x.Y    equ   %00100010
joypad.md6.x.X    equ   %01000100
joypad.md6.x.MODE equ   %10001000

joypad.md6.0.Z    equ   %00000001
joypad.md6.0.Y    equ   %00000010
joypad.md6.0.X    equ   %00000100
joypad.md6.0.MODE equ   %00001000

joypad.md6.1.Z    equ   %00010000
joypad.md6.1.Y    equ   %00100000
joypad.md6.1.X    equ   %01000000
joypad.md6.1.MODE equ   %10000000