; zx0_6809_mega.asm - ZX0 decompressor for M6809 - 189 bytes
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


; only get one bit from stream
zx0_get_1bit       macro
                   lsla                ; get next bit
                   bne done@           ; is bit stream empty? no, branch
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
done@              equ *
                   endm

; get elias value
zx0_elias_bt       macro
                   bcs done@
loop@              lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc loop@           ; loop until done
                   bne done@           ; is bit stream empty? no, branch
                   bsr zx0_reload      ; process rest of elias until done
done@              equ *
                   endm

;------------------------------------------------------------------------------
; Function    : zx0_decompress
; Entry       : Reg X = start of compressed data
;             : Reg U = start of decompression buffer
; Exit        : Reg X = end of compressed data + 1
;             : Reg U = end of decompression buffer + 1
; Destroys    : Regs D, Y
; Description : Decompress ZX0 data (version 1)
;------------------------------------------------------------------------------
; Options:
;
;   ZX0_ONE_TIME_USE
;     Defined variable to disable re-initialization of variables. Enable
;     this option for one-time use of depacker for smaller code size.
;       ex. ZX0_ONE_TIME_USE equ 1
;
;   ZX0_DISABLE_DISABLING_INTERRUPTS
;     Defined variable to disable the disabling of interrupts. Enable
;     this option if interrupts are already disable or if IRQ and FIRQ
;     code won't mind register DP being changed.
;       ex. ZX0_DISABLE_DISABLING_INTERRUPTS
;
; V2-DEVIATION: CC is saved unconditionally, and DP is not saved at all. The
; original had a ZX0_DISABLE_SAVE_REGS option covering both ; it saved DP
; because it changed DP, and this version never touches it. Nothing in the
; tree ever set the option, so what it guarded was a choice between saving a
; register that no longer needs saving and not saving one that does — CC is
; modified by orcc below whenever interrupts are being disabled.
zx0_decompress
                   pshs cc,dp          ; save registers

                   ifndef ZX0_DISABLE_DISABLING_INTERRUPTS
                   orcc #$50           ; disable interrupts
                   endc

                   ifndef ZX0_ONE_TIME_USE
                   ldd #$ffff          ; init offset = -1
                   std >zx0_offset+2
                   endc

; V2-DEVIATION: the two length registers moved out of the code and into the
; direct page ; the routine no longer constrains its own placement.
;
; The original padded onto a 256 byte boundary so that a handful of self
; modified bytes would share one page and could be reached through DP in two
; bytes each. That padding is meaningless in a relocatable object, where * is
; relative to the section and names a page the code will not be at — which is
; what kept compiled sprites from ever reaching this decoder.
;
; The includer now says where those bytes live, through ZX0_DP — a full
; address, page included. The routine sets DP from it and puts the caller's
; back on exit, so it does not matter which direct page the caller was on.
; That is not a detail : the bootloader runs on the monitor page at boot but
; on the engine page when a game mode asks it to load a scene, and the same
; code serves both. Each caller gets its own four bytes ; the loader and the
; game mode never share one :
;
;   bootloader : ZX0_DP is $609C, in the monitor page
;   game mode  : ZX0_DP is dp_engine, in the engine page
;
; zx0_offset is the exception and stays self modified. It computes Y = U +
; a 16 bit offset, which on this CPU needs D — and A carries the bit stream
; for the whole routine. Spilling and restoring it would cost more than the
; addressing saves. Its two writes are extended, and extended reaches any
; address, so that site constrains nothing either.
                   ifndef ZX0_DP
                   error "zx0_decompress : define ZX0_DP with four free bytes in the direct page the caller runs on, before including this file"
                   endc
zx0.len            equ ZX0_DP          ; word - match/literal length
zx0.savex          equ ZX0_DP+2        ; word - caller's X across the copy loop
zx0_start
                   lda #ZX0_DP/256     ; the page ZX0_DP names, as a constant :
                   tfr a,dp            ; no dependency on the caller's own DP
                   lda #$80            ; init bit stream
                   bra zx0_literals    ; start with literals

zx0_eof            puls cc,dp,pc       ; restore registers and exit


; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset     ldb #1              ; set elias = 1 (not necessary to set MSB)
                   zx0_get_1bit        ; obtain MSB offset
                   zx0_elias_bt        ;  "      "   "
                   clr <zx0.len        ; set MSB elias for below
                   negb                ; adjust for negative offset (set carry for RORB below)
                   beq zx0_eof         ; eof? (length = 256) if so exit
                   rorb                ; last offset bit becomes first length bit
                   stb zx0_offset+2    ; save MSB offset
                   ldb ,x+             ; load LSB offset
                   rorb                ; last offset bit becomes first length bit
                   stb zx0_offset+3    ; save LSB offset
                   ldb #1              ; set elias = 1
                   zx0_elias_bt        ; get elias but skip first bit
skip@              incb                ; elias = elias + 1
                   stb <zx0.len+1      ;  " "
                   bne zx0_copy        ;  " "
                   inc <zx0.len        ;  " "
zx0_copy           stx <zx0.savex      ; save reg X
                   ldx <zx0.len        ; setup length
zx0_offset         leay >$ffff,u       ; calculate offset address
loop@              ldb ,y+             ; copy match
                   stb ,u+             ;  "    "
                   leax -1,x           ; decrement loop counter
                   bne loop@           ; loop until done
                   ldx <zx0.savex      ; restore reg X
                   lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - literal (copy next N bytes from compressed data)
zx0_literals       ldb #1              ; set elias = 1
                   clr <zx0.len        ;  "    "
                   zx0_get_1bit        ; obtain length
                   zx0_elias_bt        ;  "      "
                   stb <zx0.len+1      ; save LSB elias
                   ldy <zx0.len        ; setup length
loop@              ldb ,x+             ; copy literals
                   stb ,u+             ;  "    "
                   leay -1,y           ; decrement loop counter
                   bne loop@           ; loop until done
                   lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   ldb #1              ; set elias = 1
                   clr <zx0.len        ;  "    "
                   zx0_get_1bit        ; obtain length
                   zx0_elias_bt        ;  "      "
                   stb <zx0.len+1      ; save LSB elias
                   bra zx0_copy        ; go copy last offset block

; interlaced elias gamma coding
zx0_reload         lda ,x+             ; load another group of 8 bits
                   rola                ; are we done?
                   bcs zx0_rts         ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_rts         ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_rts         ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_rts         ; yes, exit

; long elias gamma coding
loop@              lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   rol <zx0.len        ;  "      "   "    "     "
                   lsla                ; is bit stream empty?
                   bne skip@           ; no, branch
                   lda ,x+             ; reload bit stream
                   rola                ; are we done?
skip@              bcc loop@           ; no, loop again
zx0_rts            rts                 ; return
