; mscroll code buffer, plane 0 (RAMA data, blasted into the $C000-$DFFF zone).
; The generated chunk stream (one screen line = ten ldd/ldx/pshs d,x chunks,
; reverse order, BUFFER_LINES lines : the view plus the extra line that gives
; the patched exit jmp room, all carrying real map content) and the wrap jmp
; that makes the buffer cycle. Runs mounted in cartridge space, so the wrap
; target is the load address of this file : $0000 in its page.

mscroll.buffer.a
        INCLUDEBIN "gen/mire/mire.start.0.bin"
        jmp   >mscroll.buffer.a            ; forced extended : the buffer runs
                                           ; with DP on the engine page, lwasm
                                           ; would otherwise emit a direct jmp
