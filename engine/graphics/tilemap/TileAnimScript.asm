; ---------------------------------------------------------------------------
; TileAnimScript - animated tiles : up to 16 scripts run together, a frame
; (a tile index) shown for its duration D, D + 1 elapsed frames, in step with
; gfxlock.frameDrop.count (the frames past a frame's end shorten the next).
;
; A script : a header [D or -1][frames], then a byte a frame (its index)
; when D is global, or two (the index, its D) when the header says -1.
; Durations 0-127.
;
; TileAnimScriptInit   X a list of scripts, 0 ended : their first frames
; TileAnimScript       a call a rendered frame : each script's frame
;                      (ZACurFrame of its slot in TileAnimScriptData)
; TileAnimRun          A an offset, X a table of [page][address] : runs it
; V2-DEVIATION : a frame lasts D + 1 frames, the overshoot carried, clamped
; at 0 (v1 added it instead : D + 2 frames, longer under frame drops).
; ---------------------------------------------------------------------------

ZACurIndex equ   0                     ; the frame's index in the script
ZACurFrame equ   1                     ; the frame
ZADuration equ   2                     ; the frames left, 20 ms each
ZAMaxFrame equ   3                     ; the script's frames
ZASize     equ   4
TileAnimScriptData
        fill  0,16*ZASize

TileAnimScriptInit
        stx   TileAnimScriptList
        ldu   #TileAnimScriptData
@loop   ldy   ,x++
        beq   @rts
        ldd   ,y                       ; the header : D or -1, the frames
        bpl   @global
        stb   ZAMaxFrame,u
        ldd   2,y                      ; the first frame, its D
        std   ZACurFrame,u             ; and ZADuration
        bra   @common
@global std   ZADuration,u             ; and ZAMaxFrame
        lda   2,y
        sta   ZACurFrame,u
@common clr   ZACurIndex,u
        leau  ZASize,u
        bra   @loop
@rts    rts

TileAnimScript
        ldx   #0
TileAnimScriptList equ *-2             ; (dynamic) the scripts
        beq   @rts
        ldu   #TileAnimScriptData
@loop   ldy   ,x++
        beq   @rts
        lda   ZADuration,u
        suba  gfxlock.frameDrop.count  ; the frames elapsed
        bcs   @next
        sta   ZADuration,u             ; the frame goes on
        leau  ZASize,u
        bra   @loop
@next   sta   @over                    ; the frames past its end, -1 on time
        lda   ZACurIndex,u
        inca
        cmpa  ZAMaxFrame,u
        bne   >
        clra                           ; the script's start again
!       sta   ZACurIndex,u
        ldb   ,y
        bpl   @globalD
        asla                           ; two bytes a frame
        adda  #2                       ; past the header
        ldd   a,y                      ; the frame, its D
        bra   >
@globalD
        adda  #2
        lda   a,y                      ; the frame, B the global D
!       addb  #0
@over   equ   *-1
        incb                           ; D less the frames past the end
        bpl   >
        clrb                           ; a frame a call at most
!       std   ZACurFrame,u             ; and ZADuration
        leau  ZASize,u
        bra   @loop
@rts    rts

TileAnimRun
        ldb   a,x
        stb   $E7E6
        inca
        jmp   [a,x]
