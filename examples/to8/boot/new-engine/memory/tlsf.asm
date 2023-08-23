;-----------------------------------------------------------------
; TLSF (Two Level Segregated Fit) - 16bit
; single RAM page only
;-----------------------------------------------------------------
; Benoit Rousseau - 22/08/2023
; Based on http://www.gii.upv.es/tlsf/files/spe_2008.pdf
;-----------------------------------------------------------------

 opt c

memory.tlsf.sloffset equ 0  ; non significant rightmost bits
memory.tlsf.slbits   equ 4  ; significant bits for second level split
memory.tlsf.slsize   equ 16 ; 2^memory.tlsf.slbits

 IFLT 8-memory.tlsf.sloffset-memory.tlsf.slbits
        ERROR "Sum of memory.tlsf.sloffset and memory.tlsf.slbits should not exceed 8"
 ENDC

 IFLT memory.tlsf.slbits-1
        ERROR "memory.tlsf.slbits should be >= 1"
 ENDC

memory.tlsf.rsize    fdb 0  ; requested memory size
memory.tlsf.msize    fdb 0  ; memory size
memory.tlsf.fl       fcb 0  ; first level index
memory.tlsf.sl       fcb 0  ; second level index

;-----------------------------------------------------------------
; memory.tlsf.malloc
; input  REG : [D] requested memory size
; output REG : [U] allocated memory location or 0 if no more space
;-----------------------------------------------------------------
; size is splitted in two levels to find a "good fit" free region
;-----------------------------------------------------------------
memory.tlsf.malloc
        std   memory.tlsf.rsize
        jsr   memory.tlsf.mappingsearch



; free_block:= find_suitable_block(r, fl, sl);
; if not(free_block) then return error; end if;
; remove_head(free_block);
; if size(free_block)-r {>} split_size_threshold then
; remaining_block:= split(free_block, r);
; mapping_insert(size(remaining_block), fl, sl);
; insert_block(remaining_block, fl, sl);
; end if ;
; return free_block;
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
;-----------------------------------------------------------------
memory.tlsf.mappingsearch
        ; check in parameter
        cmpd  #$F800
        bls   >
        clra
        sta   memory.tlsf.fl
        sta   memory.tlsf.sl
        rts
        ; round up requested size to next list
!       std   memory.tlsf.msize
        jsr   memory.tlsf.fls
        cmpb  #memory.tlsf.sloffset+memory.tlsf.slbits
        bhs   >
       IFEQ  memory.tlsf.sloffset
        ldd   memory.tlsf.rsize       ; skip round up when list
        bra   @computefl              ; hold only one size
       ELSE
        addd  #memory.tlsf.sloffset
       ENDC
!       subb  #memory.tlsf.slbits     ; round up
        aslb
        ldx   #memory.tlsf.map.bitpos
        ldd   b,x
        subd  #1
        addd  memory.tlsf.rsize
@computefl
        std   memory.tlsf.msize
        jsr   memory.tlsf.fls
        stb   memory.tlsf.fl
@computesl
        addb  #memory.tlsf.sloffset-memory.tlsf.slbits
        stb   @rsb
        decb
        bmi   @skiplp
        ldd   memory.tlsf.msize
@loop   lsra
        rorb
        dec   @rsb
        bne   @loop
@skiplp 
       IFGE  255-memory.tlsf.sloffset ; when slbits=8, no need to strip (a is discarded)
        lda   memory.tlsf.fl
        cmpa  #memory.tlsf.sloffset+memory.tlsf.slbits ; if fl is too small (cap first level to 0)
        blo   >                                        ; do not strip fl bit
        subb  #memory.tlsf.slsize                      ; strip fl bit to keep only sl value
       ENDC
!       stb   memory.tlsf.sl
        rts
@rsb    fcb   0

memory.tlsf.map.bitpos
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
; memory.tlsf.fls
; input  VAR : [memory.tlsf.msize] memory size
; input  REG : [B] fl index
;-----------------------------------------------------------------
; split memory size in power of two
; (..., 32>m>=16 r=4, 16>m>=8 r=3, ...)
;-----------------------------------------------------------------
memory.tlsf.fls
        lda   memory.tlsf.msize
        beq   @lsb
@msb
        ldb   #15
        bra   >
@lsb
        lda   memory.tlsf.msize+1
        ldb   #7
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

memory.tlsf.findsuitableblock
        rts

memory.tlsf.mappinginsert
        rts

memory.tlsf.mergeprev
        rts

memory.tlsf.mergenext
        rts