; ------------------------------------------------------------------------------
; YM2413 VGM playback system for 6809
; ------------------------------------------------------------------------------
; Play a compressed (ZX0) stream of ym2413 vgm data
;
; by Bentoc December 2022
; ------------------------------------------------------------------------------

irq.on       EXTERNAL
irq.off      EXTERNAL
map.YM2413.A EXTERNAL
map.YM2413.D EXTERNAL

ymm.play       EXPORT
ymm.obj.play   EXPORT
ymm.frame.play EXPORT

        IFNDEF  engine.sound.ym2413.macro.asm
        INCLUDE "engine/sound/ym2413.macro.asm"
        ENDC

        IFNDEF  engine.sound.ym2413.asm
        INCLUDE "engine/sound/ym2413.asm"
        ENDC

        IFNDEF  engine.sound.ymm.const.asm
        INCLUDE "engine/sound/ymm.const.asm"
        ENDC

 SECTION code
ymm.org equ *
        IFNDEF engine.6809.macros.asm
        INCLUDE "engine/6809/macros.asm"
        ENDC

ymm.data             fdb   0             ; address of song data
ymm.data.page        fcb   0             ; memory page of music data
ymm.data.pos         fdb   0             ; current playing position in Music Data
ymm.status           fcb   0             ; 0 : stop playing, 1-255 : play music
ymm.frame.waits      fcb   0             ; number of frames to wait before next play
ymm.loop             fcb   0             ; 0=no loop
ymm.callback         fdb   0             ; 0=no calback routine

; ------------------------------------------------------------------------------
; ymm.play - Load a new music and init all tracks
; ------------------------------------------------------------------------------
; input REG : [B] loop flag 0: no 1: yes
; input REG : [A] music data page
; input REG : [X] music data
; input REG : [Y] callback routine
; ------------------------------------------------------------------------------

ymm.play
        _GetCartPageA
        sta   @a
        _SetCartPageA
        jsr   ymm.obj.play
        lda   #0
@a      equ   *-1
        _SetCartPageA
        rts

ymm.obj.play
        pshs  u                        ; needed by RunObjects
        jsr   irq.off
        stb   ymm.loop
        sty   ymm.callback
        sta   ymm.data.page
        lda   #1
        sta   ymm.frame.waits
        sta   ymm.status
        stx   ymm.data
        ldu   #ymm.buffer
        stu   ymm.data.pos
        leax  2,x
        jsr   ymm.decompress
        _ym2413.init
        puls  u,pc

; ------------------------------------------------------------------------------
; ymm.frame.play - processes a music frame (VInt)
;
; format:
; -------
; x00-x38 xnn           : (2 bytes) YM2413 registers
; x39                   : (1 byte) end of stream
; x40                   : (1 byte) wait 1 frames
; ...
; xFF                   ; (1 byte) wait 198 frames
;
; ------------------------------------------------------------------------------
        
ymm.frame.play
        lda   ymm.status
        beq   @rts
        dec   ymm.frame.waits
        beq   >
@rts    rts
!       lda   ymm.data.page
        _SetCartPageA
YVGM_do_MusicFrame
        ldx   ymm.data.pos
@UpdateLoop
        lda   ,x+
        cmpx  #ymm.buffer.end
        bne >
        ldx   #ymm.buffer
!       cmpa  #$39
        blo   @YM2413
@YVGM_DoWait
        suba  #$39
        beq   @DoStopTrack
        sta   ymm.frame.waits
        stx   ymm.data.pos
        jmp   ymm.frame.resume         ; read next frame data
@DoStopTrack
        ldx   ymm.callback             ; check callback routine
        beq   >
        jmp   ,x
!       lda   ymm.loop
        beq   @no_looping
        ldb   #1
        stb   ymm.frame.waits
        ldx   ymm.data
        ldd   ,x
        leax  d,x                      ; move to loop point
        ldu   #ymm.buffer
        stu   ymm.data.pos
        jsr   ymm.decompress    
        jmp   ymm.frame.play  
@no_looping
        lda   #0
        sta   ymm.status
        jsr   ym2413.init
        rts
@YM2413
        sta   <map.YM2413.A
        ldb   ,x+
        cmpx  #ymm.buffer.end
        bne >
        ldx   #ymm.buffer
!       stb   <map.YM2413.D
        nop
        nop                            ; tempo (should be 24 cycles between two register writes)
        bra   @UpdateLoop

; @zx0_6809_mega.asm - ZX0 decompressor for M6809 - 189 bytes
; Written for the LWTOOLS assembler, http://www.lwtools.ca/.
;
; Copyright (c) 2021 Doug Masten
; ZX0 compression (c) 2021 Einar Saukas, https://github.com/einar-saukas/ZX0
;
; This software is provided 'as-is', without any express or implied
; warranty. In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.
;
; ************************************************************************
; ALTERED SOURCE TO BE ABLE TO UNCOMPRESS ON THE FLY WITH A CYCLING BUFFER
; ************************************************************************
;------------------------------------------------------------------------------
; Function    : zx0_decompress
; Entry       : Reg X = start of compressed data
;             : Reg U = start of decompression buffer
; Exit        : Reg X = end of compressed data + 1
;             : Reg U = end of decompression buffer + 1
; Destroys    : Regs D, Y
; Description : Decompress ZX0 data (version 1)
;------------------------------------------------------------------------------
ymm.decompress
; initialize variables
                   sts @saveS1
                   lds #@stackContext
                   ldd #$80ff
                   sta @zx0_bit          ; init bit stream
                   sex                   ; reg A = $FF
                   std @zx0_offset       ; init offset = -1
; 0 - literal (copy next N bytes from compressed data)
@ym2413zx0_literals bsr @zx0_elias       ; obtain length
                   tfr d,y               ;  "      "
                   clr @mode
                   bsr @zx0_copy_bytes   ; copy literals
                   bcs @zx0_new_offset   ; branch if next block is new-offset
; 0 - copy from last offset (repeat N bytes from last offset)
                   bsr @zx0_elias        ; obtain length
@zx0_copy          equ *
                   stx @saveX            ; save reg X
                   tfr d,y               ; setup length
@zx0_offset        equ *+2
                   leax >$ffff,u         ; calculate offset address
                   cmpx #ymm.buffer      ; this test is a shortcut that need a buffer to be stored
                   bhs >                 ; at an address >= buffer length
                   leax ymm.buffer.end-ymm.buffer,x ; cycle buffer
!                  lda #1
                   sta @mode
                   bsr @zx0_copy_bytes_b ; copy match
                   ldx #0                ; restore reg X
@saveX             equ *-2
                   bcc @ym2413zx0_literals ; branch if next block is literals
; 1 - copy from new offset (repeat N bytes from new offset)
@zx0_new_offset    bsr @zx0_elias        ; obtain offset MSB
                   negb                  ; adjust for negative offset (set carry for RORA below)
                   beq @zx0_eof          ; eof? (length = 256) if so exit
                   tfr b,a               ; transfer to MSB position
                   ldb ,x+               ; obtain LSB offset
                   ;cmpx #ymm.buffer.end
                   ;blo >
                   ;ldx  #ymm.buffer     ; cycle buffer
!                  rora                  ; last offset bit becomes first length bit
                   rorb                  ;  "     "     "    "      "     "      "
                   std @zx0_offset       ; preserve new offset
                   ldd #1                ; set elias = 1
                   bsr @zx0_elias_bt     ; get length but skip first bit
                   incb                  ; Tiny change to save a couple of CPU cycles
                   bne @zx0_copy        
                   inca
                   bra @zx0_copy         ; copy new offset match
; interlaced elias gamma coding
@zx0_elias         ldd #1                ; set elias = 1
                   bra @zx0_elias_start  ; goto start of elias gamma coding
@zx0_elias_loop    lsl @zx0_bit          ; get next bit
                   rolb                  ; rotate elias value
                   rola                  ;   "     "     "
@zx0_elias_start   lsl @zx0_bit          ; get next bit
                   bne @zx0_elias_bt     ; branch if bit stream is not empty
                   sta @saveA            ; save reg A
                   lda ,x+               ; load another 8-bits
                   ;cmpx #ymm.buffer.end
                   ;blo >
                   ;ldx  #ymm.buffer     ; cycle buffer
!                  rola                  ; get next bit
                   sta @zx0_bit          ; save bit stream
                   lda #0                ; restore reg A
@saveA             equ *-1
                   endc
@zx0_elias_bt      bcc @zx0_elias_loop   ; loop until done
                   rts
; copy Y bytes from X to U and get next bit
@zx0_copy_bytes    ldb ,x+               ; copy byte
                   bra >
@zx0_copy_bytes_b  ldb ,x+               ; copy byte
                   cmpx #ymm.buffer.end
                   blo >
                   ldx  #ymm.buffer      ; cycle buffer
!                  stb ,u+               ;  "    "
                   cmpu #ymm.buffer.end
                   bne >
                   ldu #ymm.buffer
; loop until a wait byte is found, this will unpack a whole sound frame
!                  tst @flip             ; handle 2 bytes cmd length
                   bne @nextByte
                   cmpb #$39
                   blo @nextByte         ; continue if a ym2413 cmd byte
; save context for next byte ... and exit
                   pshs d,x,y,u
                   sts @stackContextPos
@zx0_eof           lds #0
@saveS1            equ *-2
                   rts
; next call will resume here ...
ymm.frame.resume   com @flip
                   sts @saveS1
                   lds @stackContextPos
                   puls d,x,y,u
@nextByte          com @flip
                   tst @mode
                   bne >
                   leay -1,y             ; decrement loop counter
                   bne @zx0_copy_bytes   ; loop until done
                   lsl @zx0_bit          ; get next bit
                   rts
!                  leay -1,y             ; decrement loop counter
                   bne @zx0_copy_bytes_b ; loop until done
                   lsl @zx0_bit          ; get next bit
                   rts
@zx0_bit  fcb $80
@flip     fcb 0
@mode     fcb 0
@stackContextPos fdb 0
          fill 0,32
@stackContext equ *

@buffersize equ  512
@addr equ *
; !!! WARNING !!! buffer must be placed at absolute addr > buffer size
; if buffer is 512 bytes, buffer should be placed >= $0200
 iflt (@addr-ymm.org)-@buffersize
        fill 0,@buffersize-(@addr-ymm.org)
 endc
ymm.buffer
          fill 0,@buffersize
ymm.buffer.end
 ENDSECTION