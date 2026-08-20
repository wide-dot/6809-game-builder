; mscroll code buffer, plane 1 (RAMB data, blasted into the $A000-$BFFF zone).
; Same structure as bufA — see bufA.asm.

mscroll.buffer.b
        INCLUDEBIN "gen/mire/mire.start.1.bin"
        jmp   >mscroll.buffer.b            ; forced extended, see bufA.asm
