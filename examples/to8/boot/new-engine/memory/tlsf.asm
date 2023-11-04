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
;
; TODO - OPTIM :
; 1.
; tlsf.ffs => supprimer le decb qui suit tous les appels jsr tlsf.ffs
; et modifier ffs pour renvoyer la bonne valeur directement
;-----------------------------------------------------------------

 opt c

 INCLUDE "new-engine/constant/types.const.asm"

; tlsf structures
; ---------------
tlsf.freePtr STRUCT ; this structure is used only when block is free
prev rmb types.WORD ; [0000 0000 0000 0000]    - [previous block in free list]
next rmb types.WORD ; [0000 0000 0000 0000]    - [next block in free list]
 ENDSTRUCT

tlsf.blockHdr STRUCT ; this structure is common to all blocks (free or used)
size      rmb types.WORD ; [0] [000 0000 0000 0000] - [1:free/0:used] [free size - 1]
prev.phys rmb types.WORD ; [0000 0000 0000 0000]    - [previous physical block in memory]
freePtr   rmb sizeof{tlsf.freePtr}
 ENDSTRUCT

; tlsf configuration
; -----------------------
tlsf.PAD_BITS         equ   0  ; non significant rightmost bits
tlsf.SL_BITS          equ   4  ; significant bits for second level index
tlsf.SL_SIZE          equ   16 ; 2^tlsf.SL_BITS

; tlsf constants
; -----------------------
tlsf.FL_BITS          equ   types.WORD_BITS-tlsf.PAD_BITS-tlsf.SL_BITS ; significant bits for first level index
tlsf.MIN_BLOCK_SIZE   equ   sizeof{tlsf.freePtr} ; a memory block in use should be able to return to free state, so a min block size is mandatory
tlsf.BHDR_OVERHEAD    equ   sizeof{tlsf.blockHdr}-tlsf.MIN_BLOCK_SIZE ; overhead when a block is in use
tlsf.mask.FREE_BLOCK  equ   %10000000

; tlsf external variables and constants
; -------------------------------------
tlsf.err              fcb   0
tlsf.err.callback     fdb   tlsf.loop   ; error callback, default is an infinite loop
tlsf.err.init.MIN_SIZE        equ   1   ; memory pool should have sizeof{tlsf.blockHdr} as a minimum size
tlsf.err.init.MAX_SIZE        equ   2   ; memory pool should have 32768 ($8000) as a maximum size
tlsf.err.malloc.NO_MORE_SPACE equ   3   ; no more space in memory pool 
tlsf.err.malloc.MAX_SIZE      equ   4   ; malloc can not handle more than 63488 ($F800) bytes request
tlsf.err.free.NULL_PTR        equ   5   ; memory location to free cannot be NULL

; tlsf internal variables
; -----------------------
tlsf.fl               fcb   0 ; first level index
tlsf.sl               fcb   0 ; second level index (should be adjacent to fl in memory)
tlsf.memoryPool       fdb   0 ; memory pool location     
tlsf.memoryPool.size  fdb   0 ; memory pool size
tlsf.index
tlsf.fl.bitmap        fdb   0 ; each bit is a boolean, does a free list exists for a fl index ?
tlsf.sl.bitmap.size   equ   (tlsf.SL_SIZE+types.BYTE_BITS-1)/types.BYTE_BITS
tlsf.sl.bitmaps       equ   *-(types.WORD_BITS-(tlsf.FL_BITS+1))*tlsf.sl.bitmap.size ; Translate to get rid of useless space (fl values < min fl)
                      fill  0,(tlsf.FL_BITS+1)*tlsf.sl.bitmap.size ; each bit is a boolean, does a free list exists for a sl index ?
tlsf.headMatrix       equ   *-2-(types.WORD_BITS-(tlsf.FL_BITS+1))*tlsf.SL_SIZE*2 ; -2 because fl=0, sl=0 is useless
                      fill  0,tlsf.FL_BITS*tlsf.SL_SIZE*2 ; head ptr to each free list by fl/sl. Last fl index hold only one sl level (sl=0). Thus a whole fl level is saved (no +1 on flbits).
 IFNE (*-tlsf.index)/2-(*-tlsf.index+1)/2
                      fcb   0 ; index size should be even (see tlsf.init)
 ENDC
tlsf.index.end

;-----------------------------------------------------------------
; configuration check
;-----------------------------------------------------------------
 IFLT 8-(tlsf.PAD_BITS+tlsf.SL_BITS)
        ERROR "Sum of tlsf.PAD_BITS and tlsf.SL_BITS should not exceed 8"
 ENDC

 IFLT tlsf.SL_BITS-1
        ERROR "tlsf.SL_BITS should be >= 1"
 ENDC

 IFGT tlsf.SL_BITS-4
        ERROR "tlsf.SL_BITS should be <= 4"
 ENDC

;-----------------------------------------------------------------
; tlsf.loop
;-----------------------------------------------------------------
; default error callback
;-----------------------------------------------------------------
tlsf.loop
        bra   *

;-----------------------------------------------------------------
; tlsf.init
; input  REG : [D] total memory pool size (overhead included)
; input  REG : [X] memory pool location
; output VAR : [tlsf.err] error code
;-----------------------------------------------------------------
; this version can not address more than 32 768 bytes
;-----------------------------------------------------------------
tlsf.init
        stx   tlsf.memoryPool
        std   tlsf.memoryPool.size

        ; check memory pool size
        cmpd  #sizeof{tlsf.blockHdr}
        bhs   >
            lda   #tlsf.err.init.MIN_SIZE
            sta   tlsf.err
            jmp   tlsf.err.callback
!       cmpd  #$8000
        bls   >
            lda   #tlsf.err.init.MAX_SIZE
            sta   tlsf.err
            jmp   tlsf.err.callback

!       ; Zeroing the tlsf index
        ldx   #tlsf.index
        ldd   #0
!           std   ,x++
            cmpx  #tlsf.index.end
        bne   <

        ; set a single free block
        ldx   tlsf.memoryPool
        stx   tlsf.insertBlock.location
        ldd   tlsf.memoryPool.size
        subd  #tlsf.BHDR_OVERHEAD+1 ; size is stored as val-1
        ora   #tlsf.mask.FREE_BLOCK ; set free block bit
        std   tlsf.blockHdr.size,x
        ldd   #-1
        std   tlsf.blockHdr.prev.phys,x ; no previous physical block

        ldd   tlsf.memoryPool.size
        jsr   tlsf.mapping
        jmp   tlsf.insertBlock

;-----------------------------------------------------------------
; tlsf.malloc
; input  REG : [D] requested memory size
; output REG : [U] allocated memory address or 0 if no more space
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
tlsf.safe.malloc
        cmpd  #tlsf.MIN_BLOCK_SIZE           ; Apply minimum size to requested memory size
        bhs   >
            ldd   #tlsf.MIN_BLOCK_SIZE
!       cmpd  #$F800                         ; greater values are not handled by mappingSearch function
        bls   >                              ; this prevents unexpected behaviour
            lda   #tlsf.err.malloc.MAX_SIZE
            sta   tlsf.err
            jmp   tlsf.err.callback
tlsf.malloc
!       jsr   tlsf.mappingSearch             ; Set tlsf.rsize, fl and sl
        jsr   tlsf.findSuitableBlock         ; Searching a free block, this function changes the values of fl and sl
        jsr   tlsf.removeBlockHead           ; Remove the allocated block from the free matrix
        ; Should the block be split?
        ldd   tlsf.blockHdr.size,u           ; Size of available memory -1
        subd  tlsf.rsize                     ; Substract requested memory size
        cmpd  #$8000+sizeof{tlsf.blockHdr}-1 ; Check against block header size, Size is stored as size-1, take care of free flag
        blo   >                              ; Not enough bytes for a new splitted block
            ; Split a free block in two
            ; smaller blocks: one allocated,
            ; one free
            leax  $1234,u                    ; Compute address of new instancied free block into x
tlsf.rsize  equ *-2                          ; requested memory size
            leax  tlsf.BHDR_OVERHEAD,x
            std   tlsf.blockHdr.size,x       ; Set allocated size for used Block
            stu   tlsf.blockHdr.prev.phys,x  ; Set the prev phys of the new free block
            ldd   tlsf.rsize
            subd  #1                         ; Size is stored as size-1
            std   tlsf.blockHdr.size,u       ; Store new block size
            ldd   tlsf.blockHdr.size,x
            anda  #^tlsf.mask.FREE_BLOCK     ; Unset free block bit
            stx   tlsf.insertBlock.location
            jsr   tlsf.mapping               ; compute fl/sl index
            jmp   tlsf.insertBlock           ; update index
!       lda   tlsf.blockHdr.size,u           ; No split, use the whole block
        anda  #^tlsf.mask.FREE_BLOCK         ; Unset free block bit
        sta   tlsf.blockHdr.size,u
        leau  tlsf.MIN_BLOCK_SIZE,u          ; Skip block header when returning allocated memory address
        rts

;-----------------------------------------------------------------
; tlsf.free
; input REG : [U] allocated memory address to free
;-----------------------------------------------------------------
; 
;-----------------------------------------------------------------
tlsf.safe.free
        cmpu  #0
        bne   >
            lda   #tlsf.err.malloc.MAX_SIZE
            sta   tlsf.err
            jmp   tlsf.err.callback
tlsf.free
!       ; check previous physical block
        ; and extend if already free 
        ldx   tlsf.blockHdr.prev.phys,u
        cmpx  #-1
        beq   >                                 ; branch if no previous physical block
            ldd   tlsf.blockHdr.size,x
            bpl   >                             ; branch if previous physical block is used
                pshs  x,u
                jsr   tlsf.mapping              ; compute fl/sl index of previous physical free block
                jsr   tlsf.removeBlock          ; remove it from index
                puls  x,u
                subd  tlsf.blockHdr.size,u      ; add size of freed memory while keeping free bit on
                subd  tlsf.BHDR_OVERHEAD        ; TODO : do global change to make size reflect usage + overhead
                std   tlsf.blockHdr.size,x
                stx   tlsf.insertBlock.location
                anda  #^tlsf.mask.FREE_BLOCK    ; TODO : global move the AND to mapping routine
                jsr   tlsf.mapping
                jsr   tlsf.insertBlock
!       ; check next physical block
        ; and extend if already free
        ldx   tlsf.blockHdr.prev.phys,u
!       ; turn the current used block
        ; to a free one
        rts

;-----------------------------------------------------------------
; tlsf.mappingSearch
; input  REG : [D] requested memory size
; output VAR : [tlsf.rsize] requested memory size
; output VAR : [tlsf.fl] first level index
; output VAR : [tlsf.sl] second level index
; output VAR : [D] tlsf.fl and tlsf.sl
; trash      : [D,X]
;-----------------------------------------------------------------
; r  = r+(1<<(fls(r)-J))-1;
; fl = fls(r);
; sl = (r>>(fl-J))-2^J;
; 
; This function handle requested size from 1 up to $F800 (included)
;-----------------------------------------------------------------
tlsf.mappingSearch
        std   tlsf.rsize
        ; round up requested size to next list
!       std   tlsf.fls.in
        jsr   tlsf.fls                      ; Split memory size in power of two
        cmpb  #tlsf.PAD_BITS+tlsf.SL_BITS+1 ; (fls return bitpos range 1-16, so +1 here)
        bhi   >                             ; Branch to round up if fl is not at minimum value
        ldd   tlsf.rsize
        bra   tlsf.mapping                  ; Skip round up
!       subb  #tlsf.SL_BITS+1               ; Round up (fls return bitpos range 1-16, so +1 here)
        aslb                                ; Fit requested size
        ldx   #tlsf.map.mask                ; to a level that
        ldd   b,x                           ; is big enough
        coma
        comb
        addd  tlsf.rsize                    ; requested size is rounded up
tlsf.mapping
        std   tlsf.fls.in
        jsr   tlsf.fls                      ; Split memory size in power of two
        decb                                ; (fls return bitpos range 1-16, so -1 here)
        stb   tlsf.fl                       ; (..., 32>msize>=16 -> fl=5, 16>msize>=8 -> fl=4, ...)
        cmpb  #tlsf.PAD_BITS+tlsf.SL_BITS-1 ; Test if there is a fl bit
        bhi   @computesl                    ; if so branch
        ldb   #tlsf.PAD_BITS+tlsf.SL_BITS-1 ; No fl bit, cap to fl minimum value
        stb   tlsf.fl
        incb
@computesl
        negb
        addb  #types.WORD_BITS+tlsf.SL_BITS
        aslb                                ; 2 bytes of instructions for each element of @rshift table
        ldx   #@rshift-4                    ; Saves 4 useless bytes (max 14 shift with slbits=1)
        abx                                 ; Cannot use indexed jump, so move x
        ldd   tlsf.fls.in                   ; Get rounded requested size to rescale sl based on fl
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
!       andb  #tlsf.SL_SIZE-1               ; Keep only sl bits
        stb   tlsf.sl
        lda   tlsf.fl
        rts

;-----------------------------------------------------------------
; tlsf.findSuitableBlock
; input  VAR : [tlsf.fl] first level index
; input  VAR : [tlsf.sl] second level index
; output VAR : [tlsf.fl] suitable first level index
; output VAR : [tlsf.sl] suitable second level index
;-----------------------------------------------------------------
; bitmap_tmp:= SL_bitmaps[fl] and (FFFFFFFF#16# left shift sl);
; if bitmap_tmp != 0 then
;    non_empty_sl:= ffs(bitmap_tmp);
;    non_empty_fl:= fl;
; else
;    bitmap_tmp:= FL_bitmap and (FFFFFFFF#16# left shift ( f l+1));
;    non_empty_fl:= ffs(bitmap_tmp);
;    non_empty_sl:= ffs(SL_bitmaps[non_empty_fl]);
; end if ;
;-----------------------------------------------------------------
tlsf.findSuitableBlock
        ; search for free list in selected fl/sl index
        lda   tlsf.fl
        ldb   #tlsf.sl.bitmap.size
        mul
        ldx   #tlsf.sl.bitmaps
        leax  d,x                      ; set x to selected sl bitmap
        ldy   #tlsf.map.mask
        ldb   tlsf.sl
        aslb
        leay  b,y                      ; set y to selected sl mask
        ldd   ,x                       ; load selected sl bitmap value
        anda  ,y                       ; apply mask to keep only selected sl and upper values
        andb  1,y                      ; apply mask to keep only selected sl and upper values
        std   tlsf.ffs.in
        beq   @searchatupperfl
@foundatcurrentfl
        ; found free list at current fl
        jsr   tlsf.ffs                 ; search first non empty sl index
        decb
        stb   tlsf.sl
        rts
@searchatupperfl
        ; search for free list at upper fl
        ldx   #tlsf.map.mask
        ldb   tlsf.fl
        incb                           ; select upper fl value
        aslb
        abx                            ; set x to selected fl mask
        ldd   tlsf.fl.bitmap
        anda  ,x                       ; apply mask to keep only upper fl values
        andb  1,x                      ; apply mask to keep only upper fl values
        std   tlsf.ffs.in
        bne   >
            lda   #tlsf.err.malloc.NO_MORE_SPACE
            sta   tlsf.err
            jmp   tlsf.err.callback
!       jsr   tlsf.ffs                 ; search first non empty fl index
        decb
        stb   tlsf.fl
        lda   #tlsf.sl.bitmap.size
        mul
        ldx   #tlsf.sl.bitmaps
        ldd   d,x                      ; load suitable sl bitmap value
        std   tlsf.ffs.in              ; no need to test zero value here, no applied mask
        jsr   tlsf.ffs                 ; search first non empty sl index
        decb
        stb   tlsf.sl
        rts

tlsf.map.mask
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

tlsf.map.bitset
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
; tlsf.insertBlock
; input  VAR : [tlsf.fl] first level index
; input  VAR : [tlsf.sl] second level index
; input  REG : [X] memory block location
;-----------------------------------------------------------------
;
;-----------------------------------------------------------------
tlsf.insertBlock
        ; insert into head matrix
        ldx   #0
tlsf.insertBlock.location equ *-2
        ldd   #0
        std   tlsf.blockHdr.freePtr+tlsf.freePtr.prev,x ; no previous free block (set to 0)
        lda   tlsf.fl
        ldb   #tlsf.SL_SIZE*2
        mul
        ldu   #tlsf.headMatrix
        leau  d,u
        ldb   tlsf.sl
        aslb                                            ; HeadMatrix store WORD
        leau  b,u
        ldy   ,u                                        ; Check if a block exists
        sty   tlsf.blockHdr.freePtr+tlsf.freePtr.next,x
        beq   >                                         ; Branch if no Block
        stx   tlsf.blockHdr.freePtr+tlsf.freePtr.prev,y ; Link new block in free list
!       stx   ,u                                        ; Store new block as head of free list

tlsf.mappingInsert
        ; insert into fl bitmap
        ldx   #tlsf.map.bitset
        ldb   tlsf.fl
        aslb
        ldd   b,x
        ora   tlsf.fl.bitmap
        orb   tlsf.fl.bitmap+1
        std   tlsf.fl.bitmap

        ; insert into sl bitmap
        lda   tlsf.fl
        ldb   #tlsf.sl.bitmap.size
        mul
        ldy   #tlsf.sl.bitmaps
        leay  d,y
        ldb   tlsf.sl
        aslb
        ldd   b,x
        ora   ,y
        orb   1,y
        std   ,y
        rts

;-----------------------------------------------------------------
; tlsf.removeBlock
; input  VAR : [tlsf.fl] first level index
; input  VAR : [tlsf.sl] second level index
; input  REG : [U] address of block to remove
; trash      : [D,X]
;-----------------------------------------------------------------
; remove a free block in his linked list, and update index
;-----------------------------------------------------------------
tlsf.removeBlock
        ldx   tlsf.blockHdr.freePtr+tlsf.freePtr.prev,u     ; check if removed block is a head
        cmpx  #-1
        beq   tlsf.removeBlockHead                          ; branch if yes
            leay  ,u
            ldu   tlsf.blockHdr.freePtr+tlsf.freePtr.next,u ; not a head, just update the linked list
            stu   tlsf.blockHdr.freePtr+tlsf.freePtr.next,x
            cmpu  #-1
            beq   >
                ldd   tlsf.blockHdr.freePtr+tlsf.freePtr.prev,y
                std   tlsf.blockHdr.freePtr+tlsf.freePtr.prev,u
!           rts

;-----------------------------------------------------------------
; tlsf.removeBlockHead
; input  VAR : [tlsf.fl] first level index
; input  VAR : [tlsf.sl] second level index
; output REG : [U] address of block at head of list
; trash      : [D,X]
;-----------------------------------------------------------------
; remove a free block in his linked list, and update index
;-----------------------------------------------------------------
tlsf.removeBlockHead
        lda   tlsf.fl
        ldb   #tlsf.SL_SIZE*2
        mul
        ldx   #tlsf.headMatrix
        leax  d,x
        ldb   tlsf.sl
        aslb                                                ; headMatrix store WORD sized data
        leay  b,x                                           ; load head of free block list to Y
        ldu   ,y                                            ; load block to U (output value)

        ldx   tlsf.blockHdr.freePtr+tlsf.freePtr.next,u     ; load next block in list (if exists)
        stx   ,y                                            ; store new head of list
        cmpx  #-1
        beq   >                                             ; branch if no more head at this index
            ldd   #-1                                       ; update new head
            std   tlsf.blockHdr.freePtr+tlsf.freePtr.prev,x ; with no previous block
            rts                                         
!
        ; remove index from fl bitmap
        ldx   #tlsf.map.bitset
        ldb   tlsf.fl
        aslb
        ldd   b,x
        coma
        comb
        anda  tlsf.fl.bitmap
        andb  tlsf.fl.bitmap+1
        std   tlsf.fl.bitmap

        ; remove index from sl bitmap
        lda   tlsf.fl
        ldb   #tlsf.sl.bitmap.size
        mul
        ldy   #tlsf.sl.bitmaps
        leay  d,y
        ldb   tlsf.sl
        aslb
        ldd   b,x
        coma
        comb
        anda  ,y
        andb  1,y
        std   ,y
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
        subb  #4
        asla
        asla
        asla
        asla
!       bita  #$c0
        bne   >
        subb  #2
        asla
        asla
!       bmi   >
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
        ldb   #types.BYTE_BITS
!
        bita  #$0f
        bne   >
        addb  #4
        asra
        asra
        asra
        asra
!       bita  #$03
        bne   >
        addb  #2
        asra
        asra
!       beq   >
        incb
!       rts
@zero   clrb
        rts