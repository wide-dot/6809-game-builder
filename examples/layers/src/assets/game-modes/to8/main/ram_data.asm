* ===========================================================================
* Object sizing and RAM placement — the game's side of the contract
* ===========================================================================
* A 32-sprite swarm sharing one run routine : per-object pixel X (a word,
* the 320px plane needs it), signed velocities, bounce bounds, a variant
* table base and the s0 x1 the pre-shift pick derives from. display_plane
* stays first : the 1bpp pack requires it at ext_variables+0.
nb_dynamic_objects           equ 17  ; 16 swarm slots in pool, sprite1 spare
nb_graphical_objects         equ 40  ; max 64 total
ext_variables_size           equ 20  ; per dynamic object
* REQUIRED by sprite-background-erase-1bpp-pack : 0 = RAMA ($C000),
* 1 = RAMB ($A000). Each object sets it once, usually at init ; the draw
* routine reads it every frame, so a sprite can change planes at run time.
display_plane                equ ext_variables+0
* per-object movement state, the game's own business after display_plane
obj_tick                     equ ext_variables+1
obj_dir                      equ ext_variables+2
obj_x                        equ ext_variables+3   ; word, pixel X of the ink left edge (exact : gfxcomp anchors 1bpp code on the canvas centre byte)
obj_dx                       equ ext_variables+5   ; signed px per gated frame
obj_dy                       equ ext_variables+6   ; signed px per gated frame
obj_xmin                     equ ext_variables+7   ; word, bounce bounds
obj_xmax                     equ ext_variables+9   ; word, bounce bounds
obj_ymin                     equ ext_variables+11
obj_ymax                     equ ext_variables+12
obj_imgbase                  equ ext_variables+13  ; word, variant set table
obj_x1_0                     equ ext_variables+15  ; x1 of the s0 variant (signed)
obj_s                        equ ext_variables+16  ; current pre-shift 0..7
obj_gate                     equ ext_variables+17  ; move gating mask (0/1)
* the swarm lives in the dynamic pool, right below the screen result area.
* Base is computed, not fixed : 33 slots must fit whatever object_size the
* build flags select.
Dynamic_Object_RAM_End       equ $9C00
Dynamic_Object_RAM           equ Dynamic_Object_RAM_End-nb_dynamic_objects*object_size
