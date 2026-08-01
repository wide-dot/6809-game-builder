* ===========================================================================
* Object sizing and RAM placement — the game's side of the contract
* ===========================================================================
* The engine leaves these to the game : they size the object tables and the
* display priority structure. r-type level 1 uses 64 / 50 / 20.
*
* v1 emitted the tables as fill directives inside a section ORG'd at dp. A v2
* game mode is a relocatable object with no ORG, and its first byte is its
* entry point, so reserving space here would both push main away from offset
* zero and place the tables wherever the linker put the code. Everything is
* an equate instead : these live at fixed addresses in the resident RAM.

nb_dynamic_objects           equ 4
nb_graphical_objects         equ 8   ; max 64 total
ext_variables_size           equ 20  ; per dynamic object

* the bench objects. The first fits in the direct page user space ; a second
* one would not (149 bytes for 117 each), so the overlay sprite borrows the
* head of the dynamic pool — the bench never calls LoadObject, so the pool is
* otherwise unused.
sprite1                      equ dp
sprite2                      equ Dynamic_Object_RAM

* the dynamic object pool, right below the screen result area
Dynamic_Object_RAM           equ $9800
Dynamic_Object_RAM_End       equ Dynamic_Object_RAM+nb_dynamic_objects*object_size
