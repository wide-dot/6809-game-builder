; mscroll1 code buffer : BUFFER_LINES lines of ten ldd/ldx/pshs d,x chunks,
; operands all zero (mscroll1.init feeds them), and the wrap jmp that makes
; the buffer cycle. Runs mounted in cartridge space, so the wrap target is
; the load address of this file : $0000 in its page.
        INCLUDE "engine/graphics/tilemap/mscroll1/mscroll1.macro.asm"

mscroll1.buffer
        _mscroll1.buffer.linex8            ; 25 x 8 lines
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.linex8
        _mscroll1.buffer.line              ; + 1 : 201 lines
        jmp   >mscroll1.buffer             ; forced extended : the buffer runs
                                           ; with DP on the engine page, lwasm
                                           ; would otherwise emit a direct jmp
