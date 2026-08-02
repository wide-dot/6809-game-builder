* ===========================================================================
* Object pool geometry and resident RAM — frozen for the whole game
* ===========================================================================
* Lane 4 of the stage boundary : these equates are baked into the engine when
* it is assembled, and the engine is assembled once. Every stage therefore
* shares them, which is the decision recorded in the boundary analysis — v1
* already used the same values in all its game modes.
*
* Everything is an equate, never a fill : a v2 unit is relocatable, its first
* byte is its entry point, and reserving space with fill would both push the
* entry point away from offset zero and leave the tables wherever the linker
* happened to put the code.

* Les pas de moveByScript, dans l'echelle de la v1 (global/scale.asm) : un
* pixel horizontal vaut 0,375 et un vertical 0,75 dans le repere du jeu.
moveByScript.NEGXSTEP        equ -$0060
moveByScript.POSXSTEP        equ  $0060
moveByScript.NEGYSTEP        equ -$00C0
moveByScript.POSYSTEP        equ  $00C0

nb_dynamic_objects           equ 16
nb_graphical_objects         equ 32
ext_variables_size           equ 20  ; per dynamic object

* The dynamic object pool, in resident RAM above the stage region. object_size
* is 117, so sixteen slots take $750 bytes and the pool ends below the bench
* result table at $9C00.
Dynamic_Object_RAM           equ $9800-nb_dynamic_objects*object_size
Dynamic_Object_RAM_End       equ $9800

* Les OST HORS POOL : des objets uniques, vivants pour toute la partie, que le
* jeu lance par _Obj_RunU avec l'adresse de leur OST. Ils ne passent pas par
* l'allocateur — la v1 les declarait de meme dans le ram_data de son game mode.
* Ils vivent juste au-dessus du pool, sous les temoins du banc en $9C00.
palettefade                  equ Dynamic_Object_RAM_End
