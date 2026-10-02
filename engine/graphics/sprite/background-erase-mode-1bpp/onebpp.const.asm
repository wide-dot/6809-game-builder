; ----------------------------------------------------------------------------
; onebpp.const.asm - shared geometry for the 1bpp background-erase sprite pack
; ($26 two-plane mode, 320x200, 1 bit per pixel)
; ----------------------------------------------------------------------------
; x_pixel is a BYTE column in a 256 wide virtual space. The visible 40 bytes
; sit centered the way the BM16 160px frame does, so off-screen positions stay
; representable in a byte. y_pixel is pixels, same frame as BM16.
; The compiled 1bpp code draws whole bytes and cannot clip : without xloop a
; sprite must sit fully inside the visible bytes to be drawn.
; The game declares the per-object plane byte, usually next to its own
; ext variables, e.g. display_plane equ ext_variables+0, and each object sets
; it once (typically at init). The draw routine reads it every frame, so a
; sprite can change planes at run time. Missing definition fails assembly
; with an unknown-symbol error naming display_plane.
onebpp.screen.left.byte equ 108
onebpp.screen.right.byte equ 147
onebpp.screen.left.px equ 864
onebpp.screen.right.px equ 1183
DISPLAY_PLANE_RAMA equ 0 ; drawn at $C000 in the data window
DISPLAY_PLANE_RAMB equ 1 ; drawn at $A000 in the data window
