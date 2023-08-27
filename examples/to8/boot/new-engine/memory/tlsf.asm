;-----------------------------------------------------------------
; TLSF (Two Level Segregated Fit) - 16bit
; single RAM page only
;-----------------------------------------------------------------
; Benoit Rousseau - 22/08/2023
; Based on http://www.gii.upv.es/tlsf/files/spe_2008.pdf
;-----------------------------------------------------------------

 opt c

 INCLUDE "new-engine/constant/types.asm"

memory.tlsf.padbits  equ 0  ; non significant rightmost bits
memory.tlsf.slbits   equ 4  ; significant bits for second level index
memory.tlsf.slsize   equ 16 ; 2^memory.tlsf.slbits
memory.tlsf.flbits   equ types.WORD-memory.tlsf.padbits-memory.tlsf.slbits ; significant bits for first level index

 IFLT 8-memory.tlsf.padbits-memory.tlsf.slbits
        ERROR "Sum of memory.tlsf.padbits and memory.tlsf.slbits should not exceed 8"
 ENDC

 IFLT memory.tlsf.slbits-1
        ERROR "memory.tlsf.slbits should be >= 1"
 ENDC

 IFGT memory.tlsf.slbits-4
        ERROR "memory.tlsf.slbits should be <= 4"
 ENDC

memory.tlsf.rsize       fdb 0 ; requested memory size
memory.tlsf.msize       fdb 0 ; memory size
memory.tlsf.fl          fcb 0 ; first level index
memory.tlsf.sl          fcb 0 ; second level index (should be adjacent to fl in memory)
memory.tlsf.fl.nonempty fcb 0 ; non empty first level index
memory.tlsf.sl.nonempty fcb 0 ; non empty second level index (should be adjacent to fl in memory)
memory.tlsf.fl.bitmap   fdb 0 ; each bit is a boolean, does a free list exists for an fl index ?
memory.tlsf.sl.bitmaps  fill 0,(1+memory.tlsf.flbits)*((memory.tlsf.slsize+types.BYTE-1)/types.BYTE) ; each bit is a boolean, does a free list exists for an sl index ?
memory.tlsf.bitmap      fdb 0 ; working bitmap
memory.tlsf.headlist    fill 0,(1+memory.tlsf.flbits)*memory.tlsf.slsize*2 ; ptr to each free list by fl/sl

;-----------------------------------------------------------------
; memory.tlsf.malloc
; input  REG : [D] requested memory size
; output REG : [X] allocated memory location or 0 if no more space
;-----------------------------------------------------------------
; mapping_search(r, fl, sl);
; free_block:= find_suitable_block(r, fl, sl);
; if not(free_block) then return error; end if;
; remove_head(free_block);
; if size(free_block)-r {>} split_size_threshold then
;    remaining_block:= split(free_block, r);
;    mapping_insert(size(remaining_block), fl, sl);
;    insert_block(remaining_block, fl, sl);
; end if ;
; return free_block;
;-----------------------------------------------------------------
memory.tlsf.malloc
        std   memory.tlsf.rsize
        jsr   memory.tlsf.mappingsearch
        jsr   memory.tlsf.findsuitableblock
        beq   @rts                          ; branch if no more space available
@rts    rts

;-----------------------------------------------------------------
; memory.tlsf.free
;-----------------------------------------------------------------
;-----------------------------------------------------------------
memory.tlsf.free
        rts

;-----------------------------------------------------------------
; memory.tlsf.mappingsearch
; input  REG : [D] requested memory size
; output VAR : [memory.tlsf.fl] first level index
; output VAR : [memory.tlsf.sl] second level index
;-----------------------------------------------------------------
; r  = r+(1<<(fls(r)-J))-1;
; fl = fls(r);
; sl = (r>>(fl-J))-2^J;
;-----------------------------------------------------------------
memory.tlsf.mappingsearch
        cmpd  #$F800                   ; check input parameter upper limit
        bls   >
        ldd   #0                       ; error return 0 as fl/sl
@zero   std   memory.tlsf.fl           ; and memory.tlsf.sl
        rts
        ; round up requested size to next list
!       std   memory.tlsf.msize
        beq   @zero                    ; check input parameter lower limit 
        ldx   #memory.tlsf.msize
        jsr   memory.tlsf.fls          ; split memory size in power of two
        cmpb  #memory.tlsf.padbits+memory.tlsf.slbits
        bhi   >                        ; branch to round up if fl is not at minimum value
        ldd   memory.tlsf.rsize
        bra   @computefl               ; skip round up
!       subb  #memory.tlsf.slbits      ; round up
        aslb
        ldx   #memory.tlsf.map.shiftoff-2 ; saves 2 useless bytes
        ldd   b,x
        addd  memory.tlsf.rsize
@computefl
        std   memory.tlsf.msize
        ldx   #memory.tlsf.msize
        jsr   memory.tlsf.fls          ; split memory size in power of two
        stb   memory.tlsf.fl           ; (..., 32>msize>=16 -> fl=5, 16>msize>=8 -> fl=4, ...)
        cmpb  #memory.tlsf.padbits+memory.tlsf.slbits
        bhi   @computesl
        ldb   #memory.tlsf.padbits+memory.tlsf.slbits+1 ; cap fl minimum value
@computesl
        negb
        addb  #types.WORD+memory.tlsf.slbits
        aslb
        ldx   #@rshift
        leax  b,x
        ldd   memory.tlsf.msize
        jmp   ,x
@rshift equ *-2                        ; saves 1 useless bytes (slbits should be >= 1)
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lsra
        rorb
        lda   memory.tlsf.fl           ; rescale fl
        suba  #memory.tlsf.padbits+memory.tlsf.slbits
        bpl   >
        clra                           ; cap fl to 0
!       sta   memory.tlsf.fl
        andb  #memory.tlsf.slsize-1
        stb   memory.tlsf.sl
        rts

memory.tlsf.map.shiftoff
        fdb   %0000000000000000
        fdb   %0000000000000001
        fdb   %0000000000000011
        fdb   %0000000000000111
        fdb   %0000000000001111
        fdb   %0000000000011111
        fdb   %0000000000111111
        fdb   %0000000001111111
        fdb   %0000000011111111
        fdb   %0000000111111111
        fdb   %0000001111111111
        fdb   %0000011111111111
        fdb   %0000111111111111
        fdb   %0001111111111111
        fdb   %0011111111111111
        fdb   %0111111111111111

;-----------------------------------------------------------------
; memory.tlsf.findsuitableblock
; input  VAR : [memory.tlsf.fl] first level index
; input  VAR : [memory.tlsf.sl] second level index
; output REG : [X] head of free memory region list or zero if err
;-----------------------------------------------------------------
; bitmap_tmp:= SL_bitmaps[fl] and (FFFFFFFF#16# left shift sl);
; if bitmap_tmp != 0 then
;    non_empty_sl:= ffs(bitmap_tmp);
;    non_empty_fl:= f l;
; else
;    bitmap_tmp:= FL_bitmap and (FFFFFFFF#16# left shift ( f l+1));
;    non_empty_fl:= ffs(bitmap_tmp);
;    non_empty_sl:= ffs(SL_bitmaps[non_empty_fl]);
; end if ;
; return head_list(non_empty_fl, non empty_sl);
;-----------------------------------------------------------------
memory.tlsf.findsuitableblock
        ; search for non empty list in selected fl/sl index
        ldx   #memory.tlsf.sl.bitmaps
        lda   memory.tlsf.fl
        ldb   #(memory.tlsf.slsize+types.BYTE-1)/types.BYTE
        mul
        leax  d,x                      ; set x to selected sl bitmap
        ldy   #memory.tlsf.map.shifton
        ldb   memory.tlsf.sl
        aslb
        leay  b,y                      ; set y to selected sl mask
        ldd   ,x                       ; load selected sl bitmap value
        anda  ,y                       ; apply mask to keep only selected sl and upper values
        andb  1,y                      ; apply mask to keep only selected sl and upper values
        std   memory.tlsf.bitmap
        beq   @searchatupperfl
@foundatcurrentfl
        ; found non empty free list at current fl
        ldx   #memory.tlsf.bitmap
        jsr   memory.tlsf.ffs          ; search first non empty sl index
        stb   memory.tlsf.sl.nonempty
        lda   memory.tlsf.fl
        sta   memory.tlsf.fl.nonempty
        bra   @headlist
@searchatupperfl
        ; search for non empty list at upper fl
        ldx   #memory.tlsf.map.shifton
        ldb   memory.tlsf.fl
        incb                           ; select upper fl value
        aslb
        leax  b,x                      ; set x to selected fl mask
        ldd   memory.tlsf.fl.bitmap
        anda  ,x                       ; apply mask to keep only upper fl values
        andb  1,x                      ; apply mask to keep only upper fl values
        std   memory.tlsf.bitmap
        bne   >
        ldx   #0                       ; no suitable list found
        rts
!       ldx   #memory.tlsf.bitmap
        jsr   memory.tlsf.ffs          ; search first non empty fl index
        stb   memory.tlsf.fl.nonempty
        lda   #(memory.tlsf.slsize+types.BYTE-1)/types.BYTE
        mul
        ldd   d,x                      ; load suitable sl bitmap value
        std   memory.tlsf.bitmap       ; no need to test zero value here, no applied mask
        ldx   #memory.tlsf.bitmap
        jsr   memory.tlsf.ffs          ; search first non empty sl index
        stb   memory.tlsf.sl.nonempty
        lda   memory.tlsf.fl.nonempty
@headlist
        ldx   #memory.tlsf.headlist
        mul                            ; A and B are already loaded with suitable fl and sl
        ldx   d,x                      ; load head of free region list to X
        rts

memory.tlsf.map.shifton
        fdb   %1111111111111111
        fdb   %1111111111111110
        fdb   %1111111111111100
        fdb   %1111111111111000
        fdb   %1111111111110000
        fdb   %1111111111100000
        fdb   %1111111111000000
        fdb   %1111111110000000
        fdb   %1111111100000000
        fdb   %1111111000000000
        fdb   %1111110000000000
        fdb   %1111100000000000
        fdb   %1111000000000000
        fdb   %1110000000000000
        fdb   %1100000000000000
        fdb   %1000000000000000

memory.tlsf.mappinginsert
        rts

memory.tlsf.mergeprev
        rts

memory.tlsf.mergenext
        rts

;-----------------------------------------------------------------
; memory.tlsf.fls
; input  REG : [X] ptr to a 16bit integer
; output REG : [B] last set bit
;-----------------------------------------------------------------
; Find last (msb) set bit in a 16 bit integer
; Bit position is from 1 to 16, 0 means no bit set
;-----------------------------------------------------------------
memory.tlsf.fls
        lda   ,x
        beq   @lsb
@msb
        ldb   #types.WORD
        bra   >
@lsb
        lda   1,x
        beq   @zero
        ldb   #types.BYTE
!
        bita  #$f0
        bne   >
        asla
        asla
        asla
        asla
        subb  #4
!       bita  #$c0
        bne   >
        asla
        asla
        subb  #2
!       bita  #$80
        bne   >
        decb
!       rts
@zero   clrb
        rts

;-----------------------------------------------------------------
; memory.tlsf.ffs
; input  REG : [X] ptr to a 16bit integer
; output REG : [B] first set bit
;-----------------------------------------------------------------
; Find first (lsb) set bit in a 16 bit integer
; Bit position is from 1 to 16, 0 means no bit set
;-----------------------------------------------------------------
memory.tlsf.ffs
        lda   1,x
        beq   @msb
@lsb
        clrb
        bra   >
@msb
        lda   ,x
        beq   @zero
        ldb   #types.BYTE+1
!
        bita  #$0f
        bne   >
        asra
        asra
        asra
        asra
        addb  #4
!       bita  #$03
        bne   >
        asra
        asra
        addb  #2
!       bita  #$01
        bne   >
        incb
!       rts
@zero   clrb
        rts