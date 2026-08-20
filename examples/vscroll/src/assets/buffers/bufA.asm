; vscroll code buffer, plane 0 (RAMA data, blasted into the $C000-$DFFF zone).
; v1 vscroll object layout : the generated chunk stream (one line of screen =
; five ldd/ldx/ldy/ldu/pshs chunks, reverse order), one extra buffer line so
; the patched exit jmp always has room, and the wrap jmp that makes the buffer
; cycle. Runs mounted in cartridge space, so the wrap target is the load
; address of this file : $0000 in its page.

        INCLUDE "engine/graphics/tilemap/vscroll/vscroll.macro.asm"

vscroll.buffer.a
        INCLUDEBIN "assets/start.0.vscroll"
        _vscroll.buffer.line
        jmp   >vscroll.buffer.a            ; forced extended : the buffer runs
                                           ; with DP on the engine page, lwasm
                                           ; would otherwise emit a direct jmp
