;-----------------------------------------------------------------
; TLSF (Two Level Segregated Fit) - 16bit
; single RAM page only
;-----------------------------------------------------------------
; Benoit Rousseau - 22/08/2023
; Based on http://www.gii.upv.es/tlsf/files/spe_2008.pdf
;-----------------------------------------------------------------

 opt c

memory.tlsf.padbits  equ 0  ; non significant rightmost bits
memory.tlsf.slbits   equ 4  ; significant bits for second level split
memory.tlsf.slsize   equ 16 ; 2^memory.tlsf.slbits

 IFLT 8-memory.tlsf.padbits-memory.tlsf.slbits
        ERROR "Sum of memory.tlsf.padbits and memory.tlsf.slbits should not exceed 8"
 ENDC

 IFLT memory.tlsf.slbits-1
        ERROR "memory.tlsf.slbits should be >= 1"
 ENDC

memory.tlsf.rsize    fdb 0  ; requested memory size
memory.tlsf.msize    fdb 0  ; memory size
memory.tlsf.fl       fcb 0  ; first level index
memory.tlsf.sl       fcb 0  ; second level index (should be adjacent to fl in memory)

;-----------------------------------------------------------------
; memory.tlsf.malloc
; input  REG : [D] requested memory size
; output REG : [U] allocated memory location or 0 if no more space
;-----------------------------------------------------------------
; mapping_search(r, fl, sl);
; free_block:= find_suitable_block(r, fl, sl);
; if not(free_block) then return error; end if;
; remove_head(free_block);
; if size(free_block)-r {>} split_size_threshold then
; remaining_block:= split(free_block, r);
; mapping_insert(size(remaining_block), fl, sl);
; insert_block(remaining_block, fl, sl);
; end if ;
; return free_block;
;-----------------------------------------------------------------
memory.tlsf.malloc
        std   memory.tlsf.rsize
        jsr   memory.tlsf.mappingsearch
        jsr   memory.tlsf.findsuitableblock
        rts

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
        ldx   #memory.tlsf.map.bitpos
        ldd   b,x
        subd  #1
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
        addb  #16+memory.tlsf.slbits
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

memory.tlsf.map.bitpos equ *-2         ; saves 2 useless bytes
        fdb   %0000000000000001
        fdb   %0000000000000010
        fdb   %0000000000000100
        fdb   %0000000000001000
        fdb   %0000000000010000
        fdb   %0000000000100000
        fdb   %0000000001000000
        fdb   %0000000010000000
        fdb   %0000000100000000
        fdb   %0000001000000000
        fdb   %0000010000000000
        fdb   %0000100000000000
        fdb   %0001000000000000
        fdb   %0010000000000000
        fdb   %0100000000000000
        fdb   %1000000000000000

;-----------------------------------------------------------------
; memory.tlsf.findsuitableblock
;
;-----------------------------------------------------------------
; bitmap_tmp:= SL_bitmaps[ f l] and (FFFFFFFF#16# left shift sl);
; if bitmap_tmp != 0 then
; non_empty_sl:= ffs(bitmap_tmp);
; non_empty_fl:= f l;
; else
; bitmap_tmp:= FL_bitmap and (FFFFFFFF#16# left shift ( f l+1));
; non_empty_fl:= ffs(bitmap_tmp);
; non_empty_sl:= ffs(SL_bitmaps[non_empty_fl]);
; end if ;
; return head_list(non_empty_fl, non empty_sl);
;-----------------------------------------------------------------
memory.tlsf.findsuitableblock
        rts

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
; Find last set bit in a 16 bit integer
; Bit position is from 1 to 16, 0 means no bit set
;-----------------------------------------------------------------
memory.tlsf.fls
        lda   ,x
        beq   @lsb
@msb
        ldb   #16
        bra   >
@lsb
        lda   1,x
        beq   @zero
        ldb   #8
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
; Find first set bit in a 16 bit integer
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
        ldb   #9
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