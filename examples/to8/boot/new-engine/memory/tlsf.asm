;-----------------------------------------------------------------
; TLSF (Two Level Segregated Fit) - 16bit
; single RAM page only
;-----------------------------------------------------------------
; Benoit Rousseau - 22/08/2023
; Based on http://www.gii.upv.es/tlsf/files/spe_2008.pdf
;
; WORK IN PROGRESS :
; - this code does not fully handle single byte SL bitmap
; - default settings should be set by defines
;-----------------------------------------------------------------

 opt c

 INCLUDE "new-engine/constant/types.const.asm"

tlsf.block STRUCT
size      rmb types.WORD ; [0] [000 0000 0000 0000] - [0:free/1:used] [free size - 1]
prev.phys rmb types.WORD ; [0000 0000 0000 0000]    - [previous physical block in memory]
prev.free rmb types.WORD ; [0000 0000 0000 0000]    - [previous block in free list] (only for free block)
next.free rmb types.WORD ; [0000 0000 0000 0000]    - [next block in free list] (only for free block)
        ENDSTRUCT

tlsf.padbits  equ 0  ; non significant rightmost bits
tlsf.slbits   equ 4  ; significant bits for second level index
tlsf.slsize   equ 16 ; 2^tlsf.slbits
tlsf.flbits   equ types.WORD_BITS-tlsf.padbits-tlsf.slbits ; significant bits for first level index

tlsf.rsize           fdb   0 ; requested memory size
tlsf.fl              fcb   0 ; first level index
tlsf.sl              fcb   0 ; second level index (should be adjacent to fl in memory)
tlsf.fl.nonempty     fcb   0 ; non empty first level index
tlsf.sl.nonempty     fcb   0 ; non empty second level index (should be adjacent to fl in memory)

tlsf.memorypool      fdb   0 ; memory pool location     
tlsf.memorypool.size fdb   0 ; memory pool size

tlsf.index
tlsf.fl.bitmap       fdb   0 ; each bit is a boolean, does a free list exists for an fl index ?
tlsf.sl.bitmap.size  equ   (tlsf.slsize+types.BYTE_BITS-1)/types.BYTE_BITS
tlsf.sl.bitmaps      equ   *-2 ; fl=0, sl=0 is useless. Last fl index hold only one sl level (0)
                     fill  0,tlsf.flbits*tlsf.sl.bitmap.size ; each bit is a boolean, does a free list exists for an sl index ?
tlsf.headmatrix      equ   *-2 ; fl=0, sl=0 is useless. Last fl index hold only one sl level (0)
                     fill  0,tlsf.flbits*tlsf.slsize*2 ; head ptr to each free list by fl/sl, last fl index only hold one sl value
 IFNE (*-tlsf.index)/2-(*-tlsf.index+1)/2
                     fcb   0 ; index size should be even (see tlsf.init)
 ENDC
tlsf.index.end

;-----------------------------------------------------------------
; configuration check
;-----------------------------------------------------------------
 IFLT 8-tlsf.padbits-tlsf.slbits
        ERROR "Sum of tlsf.padbits and tlsf.slbits should not exceed 8"
 ENDC

 IFLT tlsf.slbits-1
        ERROR "tlsf.slbits should be >= 1"
 ENDC

 IFGT tlsf.slbits-4
        ERROR "tlsf.slbits should be <= 4"
 ENDC

;-----------------------------------------------------------------
; tlsf.init
; input  REG : [D] total memory pool size
; input  REG : [X] memory pool location
;-----------------------------------------------------------------
; this version can not address more than 32 768 bytes
; to handle up to 65 536 bytes, use one more byte in block struct
;-----------------------------------------------------------------
tlsf.init
        stx   tlsf.memorypool
        std   tlsf.memorypool.size
        ; cap min and max memory size
        ; TODO check for minimum, must cap or throw an error ?
        cmpd  #$8000
        bls   >
        ldd   #$8000

!       
        ; Zeroing the tlsf index
        ; TODO check if zeroing the matrix is useless
        ldx   #tlsf.index
        ldd   #0
!       std   ,x++
        cmpx  #tlsf.index.end
        bne   <

        ; set a single free block
        ldd   tlsf.memorypool.size
        subd  #1                     ; size is stored as val-1
        std   tlsf.block.size,x      ; implicitly set bit 7 to free
        ldd   #0
        std   tlsf.block.prev.phys,x ; no previous physical block (set to 0)
        std   tlsf.block.prev.free,x ; no previous free block (set to 0)
        std   tlsf.block.next.free,x ; no next free block (set to 0)

        ; insert into fl/sl head list matrix
        ldd   tlsf.memorypool.size
        jsr   tlsf.mappingsearch
        ldd   tlsf.fl                ; and tlsf.sl
        mul
        ldx   tlsf.memorypool
        ldu   #tlsf.headmatrix
        stx   d,u                    ; store head of free region list

        ; insert into fl/sl bitmap
        ldx   #tlsf.map.shift
        ldb   tlsf.fl
        ldd   b,x
        coma
        comb
        addd  #1
        ora   tlsf.fl.bitmap
        orb   tlsf.fl.bitmap+1
        std   tlsf.fl.bitmap

        ; insert into fl/sl bitmap
        lda   tlsf.fl
        asla
        ldb   #tlsf.sl.bitmap.size
        mul
        ldy   #tlsf.sl.bitmaps-(tlsf.padbits+tlsf.slbits-1)*tlsf.sl.bitmap.size ; implicit rescale of fl value
        leay  d,y
        ldb   tlsf.sl
        ldd   b,x                      ; x is already #tlsf.map.shift
        coma
        comb
        addd  #1
        ora   ,y
        orb   1,y
        std   ,y
        rts

;-----------------------------------------------------------------
; tlsf.malloc
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
tlsf.malloc
        jsr   tlsf.mappingsearch
        jsr   tlsf.findsuitableblock
        beq   @rts                          ; branch if no more space available
@rts    rts

;-----------------------------------------------------------------
; tlsf.free
;-----------------------------------------------------------------
;-----------------------------------------------------------------
tlsf.free
        rts

;-----------------------------------------------------------------
; tlsf.mappingsearch
; input  REG : [D] requested memory size
; output VAR : [tlsf.fl] first level index
; output VAR : [tlsf.sl] second level index
; trash      : [D,X]
;-----------------------------------------------------------------
; r  = r+(1<<(fls(r)-J))-1;
; fl = fls(r);
; sl = (r>>(fl-J))-2^J;
; 
; This function handle requested size up to $F800 (included)
; otherwise it will have an unexpected behaviour, keep input check
;-----------------------------------------------------------------
tlsf.mappingsearch
        std   tlsf.rsize
        cmpd  #$F800                      ; check input parameter upper limit
        bls   >
        ldd   #0                          ; error return 0 as fl/sl
@zero   std   tlsf.fl                     ; and tlsf.sl
        rts
        ; round up requested size to next list
!       std   tlsf.fls.in
        beq   @zero                       ; check input parameter lower limit 
        jsr   tlsf.fls                    ; split memory size in power of two
        cmpb  #tlsf.padbits+tlsf.slbits+1 ; (fls return bitpos range 1-16, so +1 here)
        bhi   >                           ; branch to round up if fl is not at minimum value
        ldd   tlsf.rsize
        bra   @computefl                  ; skip round up
!       subb  #tlsf.slbits+1              ; round up (fls return bitpos range 1-16, so +1 here)
        aslb
        ldx   #tlsf.map.shift
        ldd   b,x
        coma
        comb
        addd  tlsf.rsize
@computefl
        std   tlsf.fls.in
        jsr   tlsf.fls                    ; split memory size in power of two
        decb                              ; (fls return bitpos range 1-16, so -1 here)
        stb   tlsf.fl                     ; (..., 32>msize>=16 -> fl=5, 16>msize>=8 -> fl=4, ...)
        cmpb  #tlsf.padbits+tlsf.slbits-1 ; test if there is a fl bit
        bhi   @computesl                  ; if so branch
        ldb   #tlsf.padbits+tlsf.slbits-1 ; no fl bit, cap to fl minimum value
        stb   tlsf.fl
        incb
@computesl
        negb
        addb  #types.WORD_BITS+tlsf.slbits
        aslb                              ; 2 bytes of instructions for each element of @rshift table
        ldx   #@rshift-4                  ; saves 4 useless bytes (max 14 shift with slbits=1)
        abx                               ; cannot use indexed jump, so move x
        ldd   tlsf.fls.in                 ; get rounded requested size to rescale sl based on fl
        jmp   ,x
@rshift
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
!       andb  #tlsf.slsize-1              ; keep only sl bits
        stb   tlsf.sl
        rts

;-----------------------------------------------------------------
; tlsf.findsuitableblock
; input  VAR : [tlsf.fl] first level index
; input  VAR : [tlsf.sl] second level index
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
tlsf.findsuitableblock
        ; search for non empty list in selected fl/sl index
        lda   tlsf.fl
        ldb   #tlsf.sl.bitmap.size
        mul
        ldx   #tlsf.sl.bitmaps-(tlsf.padbits+tlsf.slbits-1)*tlsf.sl.bitmap.size ; implicit rescale of fl value
        leax  d,x                      ; set x to selected sl bitmap
        ldy   #tlsf.map.shift
        ldb   tlsf.sl
        aslb
        leay  b,y                      ; set y to selected sl mask
        ldd   ,x                       ; load selected sl bitmap value
        anda  ,y                       ; apply mask to keep only selected sl and upper values
        andb  1,y                      ; apply mask to keep only selected sl and upper values
        std   tlsf.ffs.in
        beq   @searchatupperfl
@foundatcurrentfl
        ; found non empty free list at current fl
        jsr   tlsf.ffs                 ; search first non empty sl index
        stb   tlsf.sl.nonempty
        lda   tlsf.fl
        sta   tlsf.fl.nonempty
        bra   @headlist
@searchatupperfl
        ; search for non empty list at upper fl
        ldx   #tlsf.map.shift
        ldb   tlsf.fl
        incb                           ; select upper fl value
        aslb
        abx                            ; set x to selected fl mask
        ldd   tlsf.fl.bitmap
        anda  ,x                       ; apply mask to keep only upper fl values
        andb  1,x                      ; apply mask to keep only upper fl values
        std   tlsf.ffs.in
        bne   >
        ldx   #0                       ; no suitable list found
        rts
!       jsr   tlsf.ffs                 ; search first non empty fl index
        stb   tlsf.fl.nonempty
        lda   #tlsf.sl.bitmap.size
        mul
        ldx   #tlsf.sl.bitmaps-(tlsf.padbits+tlsf.slbits-1)*tlsf.sl.bitmap.size ; implicit rescale of fl value
        ldd   d,x                      ; load suitable sl bitmap value
        std   tlsf.ffs.in              ; no need to test zero value here, no applied mask
        jsr   tlsf.ffs                 ; search first non empty sl index
        stb   tlsf.sl.nonempty
        lda   tlsf.fl.nonempty
@headlist
        ldx   #tlsf.headmatrix
        mul                            ; A and B are already loaded with suitable fl and sl
        ldx   d,x                      ; load head of free region list to X
        rts

tlsf.map.shift
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

tlsf.mappinginsert
        rts

tlsf.mergeprev
        rts

tlsf.mergenext
        rts

;-----------------------------------------------------------------
; tlsf.fls
; input  REG : [tlsf.fls.in] 16bit integer
; output REG : [B] last set bit
;-----------------------------------------------------------------
; Find last (msb) set bit in a 16 bit integer
; Bit position is from 1 to 16, 0 means no bit set
;-----------------------------------------------------------------
tlsf.fls.in fdb 0 ; input parameter
tlsf.fls
        lda   tlsf.fls.in
        beq   @lsb
@msb
        ldb   #types.WORD_BITS
        bra   >
@lsb
        lda   tlsf.fls.in+1
        beq   @zero
        ldb   #types.BYTE_BITS
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
; tlsf.ffs
; input  REG : [tlsf.ffs.in] 16bit integer
; output REG : [B] first set bit
;-----------------------------------------------------------------
; Find first (lsb) set bit in a 16 bit integer
; Bit position is from 1 to 16, 0 means no bit set
;-----------------------------------------------------------------
tlsf.ffs.in fdb 0 ; input parameter
tlsf.ffs
        lda   tlsf.ffs.in+1
        beq   @msb
@lsb
        clrb
        bra   >
@msb
        lda   tlsf.ffs.in
        beq   @zero
        ldb   #types.BYTE_BITS+1
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