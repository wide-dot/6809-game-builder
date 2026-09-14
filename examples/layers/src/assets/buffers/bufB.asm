; vscroll code buffer, plane 1 (RAMB data, blasted into the $A000-$BFFF zone).
; Same layout as bufA.asm, for the second plane.

        INCLUDE "engine/graphics/tilemap/vscroll/vscroll.macro.asm"

vscroll.buffer.b
        INCLUDEBIN "assets/scroll/start.1.vscroll"
        _vscroll.buffer.line
        jmp   >vscroll.buffer.b            ; forced extended, see bufA.asm
