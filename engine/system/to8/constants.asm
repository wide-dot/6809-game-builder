* ---------------------------------------------------------------------------
* Constants
*
* Naming convention
* -----------------
* - lower case
* - underscore-separated names
*
* ---------------------------------------------------------------------------

 ifndef TO8_CONSTANTS_ASM
TO8_CONSTANTS_ASM equ 1
        INCLUDE "./engine/constants.asm"
        INCLUDE "./engine/system/to8/memory-map.equ"

* ===========================================================================
* Globals
* ===========================================================================

dp                            equ $9F00 ; user space from dp to dp_extreg

* ===========================================================================
* TO8 - specific
* ===========================================================================

; WARNING - BuildSprite allow to cross $A000 limit by glb_camera_x_offset/4
; be sure to compile with enough margin here
glb_ram_end                   equ $A000-3