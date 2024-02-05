 IFNDEF glb.VARIABLES

glb.VARIABLES       equ $9E00
glb.nextGameMode    equ glb.VARIABLES+0 ; 1 byte
glb.score           equ glb.VARIABLES+1 ; 2 bytes
glb.lives           equ glb.VARIABLES+3 ; 2 bytes
glb.backgroundSolid equ glb.VARIABLES+5 ; 1 byte
glb.difficulty      equ glb.VARIABLES+6 ; 1 byte

 ENDC
