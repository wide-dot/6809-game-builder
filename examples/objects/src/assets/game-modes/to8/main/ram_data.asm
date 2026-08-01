* ===========================================================================
* Object sizing and RAM placement — the game's side of the contract
* ===========================================================================
* The engine leaves these to the game. Four slots is deliberately small : T2
* fills the pool and checks that the fifth request is refused, and T7 checks
* that a freed slot comes back, both of which need a pool you can exhaust in
* a handful of calls.
*
* Everything is an equate. A v2 game mode is a relocatable object with no ORG
* and its first byte is its entry point, so reserving space with fill here
* would both push main away from offset zero and put the tables wherever the
* linker happened to place the code.

nb_dynamic_objects           equ 4
nb_graphical_objects         equ 8
ext_variables_size           equ 20  ; per dynamic object

* the dynamic object pool. object_size is 117, so four slots take $1D4 bytes
* and the pool ends well below the result table at $9C00.
Dynamic_Object_RAM           equ $9800
Dynamic_Object_RAM_End       equ Dynamic_Object_RAM+nb_dynamic_objects*object_size
