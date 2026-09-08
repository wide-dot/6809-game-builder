;-----------------------------------------------------------------
; tlsf.realloc
; input  REG : [D] requested user memory size
; input  REG : [U] actual allocated memory address
; output REG : [U] new allocated memory address
;-----------------------------------------------------------------
; reallocate memory, should be deallocated with a call to free
; WARNING : this does not initialize memory bytes
;
; If requested memory size is lower than actual size, it will
; shrink the allocated space by keeping data in place.
;
; If requested memory size is greater than actual size, it will
; look if next physical area is free and enough to hold new size,
; it will keep data in place.
;
; Otherwise realloc will use malloc, copy the existing data and
; free previous allocated memory.
;-----------------------------------------------------------------
tlsf.realloc
        pshs  d,x,y

        ; initial check
        cmpd  #tlsf.MIN_BLOCK_SIZE           ; Apply minimum size to requested memory size
        bhs   >
            ldd   #tlsf.MIN_BLOCK_SIZE
            std   ,s                         ; update input parameter: requested user memory size
!       cmpd  #$F800                         ; greater values are not handled by mappingSearch function
        bls   >                              ; this prevents unexpected behaviour
            lda   #tlsf.err.realloc.MAX_SIZE
            sta   tlsf.err
            ldx   tlsf.err.callback
            leas  8,s                        ; restore the stack position (dependency with pshs at routine start)
            jmp   ,x
!
        ; determines the strategy for realloc
        ; based on the physical state of memory
        ldd   tlsf.blockHdr.size-tlsf.BHDR_OVERHEAD,u
        addd  #1                             ; get actual block size, size is stored as size-1
        cmpd  ,s                             ; Get requested size
        bne   >
@same       puls  d,x,y,pc                   ; nothing to do ... this is the actual size
!       blo   @growth                        ; branch if actual size is strictly lower than requested size
        subd  sizeof{tlsf.blockHdr}          ; does actual size allows to split the block ?
        cmpd  ,s
        bhs   @shrink
            puls  d,x,y,pc                   ; nothing to do ... requested size is lower but does not allow a new block (need a minimum size)
@shrink jmp   tlsf.realloc.shrink
@growth
        leax  d,u                            ; X is now a ptr to next physical block header
        beq   tlsf.realloc.do                ; branch if end of memory (when memory pool goes up to the end of addressable 16bit memory)
        cmpx  tlsf.memoryPool.end
        bhs   tlsf.realloc.do                ; branch if no next physical block (beyond memorypool)
        tst   tlsf.blockHdr.size,x
        bpl   tlsf.realloc.do                ; branch if next physical block is not free
        addd  tlsf.blockHdr.size,x           ; add to actual size, the size of next free block
        addd  #tlsf.BHDR_OVERHEAD+1          ; available size takes header in account in case of merge, size is stored as size-1
        anda  #^tlsf.mask.FREE_BLOCK         ; unset free block bit
        subd  ,s                             ; substract requested size
        bmi   tlsf.realloc.do                ; branch if next physical block does not have enough space
        jmp   tlsf.realloc.growth            ; branch if next physical block fits, [d] is the remaining free memory bytes


;-----------------------------------------------------------------
; tlsf.realloc.do
;
; input  REG : [U] ptr to current block data
; output REG : [U] new allocated memory address
;-----------------------------------------------------------------
; Make a realloc by doing a free/malloc
; Data is copied
;
; Free FIRST : when nothing else fits, the block comes back merged with
; its free neighbours, and the memory peak never exceeds the bigger of
; the two sizes. The price of that order is that the allocator can write
; inside the old data before it is copied. Every such write is known,
; and saved here :
;
; - tlsf.free links the freed block into a free list : 4 bytes at the
;   start of the block (@data12/@data34) — unless it merged with the
;   free block BEFORE it, in which case they land in that hole ;
; - tlsf.malloc may give that merged block back and SPLIT it, at
;   [merged data + requested size] (tlsf.rsize is the raw request, the
;   rounding only picks the class) : the remainder's header and its list
;   links, 8 bytes, written where the old data still sits when the block
;   moves down. r-type, 07/09/2026 : the loader's link index grew from
;   16 to 24 slots, moved down 108 bytes, and one slot came back as a
;   block header. Those 8 bytes are saved before malloc and put back
;   after the copy, whatever malloc decided — another block, or no
;   split, and the bytes put back are the bytes already there.
;
; Nothing else reaches the old data : list operations touch other blocks
; and the index, a split updates the NEXT block's header.
; Cost of the guard : a compare when the block did not merge backwards,
; 8 bytes saved and put back when it did. tlsf.ut.realloc.merge covers
; both the split inside the data and the split inside the hole.
;
; When a realloc error is raised (out of memory) :
; Data may have been moved as best effort to provide more space,
; freed memory block may have been merged with prev or prev/next
; physical block(s)
;-----------------------------------------------------------------
tlsf.realloc.do
        ; Saves 4 bytes that will otherwise be lost when changing occupied block to free
        ldd   tlsf.blockHdr.prev-tlsf.BHDR_OVERHEAD,u
        std   @data12
        ldd   tlsf.blockHdr.next-tlsf.BHDR_OVERHEAD,u
        std   @data34
        stu   @start                                  ; Saves data location for later restoration
        ldd   tlsf.blockHdr.size-tlsf.BHDR_OVERHEAD,u ; Saves size for copying data
        addd  #1-4                                    ; size is stored as size-1, get rid of the 4 bytes already copied
        std   @size
;
        ; reallocate memory
        jsr   tlsf.free
        stx   @freeBlock                              ; Free block can be ahead of current deallocated block when merging
;
        ; the split guard : where malloc would cut the merged block
        ldb   #$20                                    ; bra : nothing to put back
        stb   @guard
        leay  tlsf.BHDR_OVERHEAD,x                    ; [y] data start of the merged block
        cmpy  @start
        beq   @noGuard                                ; no hole before : a split lands past the old data
        ldd   ,s                                      ; requested size : malloc splits right after it
        leay  d,y                                     ; [y] the split point (sizes < $8000 : d is signed)
        cmpy  @start
        blo   @noGuard                                ; inside the hole : nothing of ours there
        tfr   y,d
        subd  @start
        std   @offset                                 ; the same bytes, once the block has moved
        ldd   ,y
        std   @bytes01
        ldd   2,y
        std   @bytes23
        ldd   4,y
        std   @bytes45
        ldd   6,y
        std   @bytes67
        ldb   #$21                                    ; brn : put them back after the copy
        stb   @guard
@noGuard
        ldd   tlsf.err.callback                       ; Backup routine to call when tlsf raise an error
        std   @callback
        ldd   #tlsf.err.return
        std   tlsf.err.callback                       ; setup return callback
        clr   tlsf.err                                ; clear error code
        ldd   ,s                                      ; Get requested size
        jsr   tlsf.malloc                             ; try a malloc (size in [d])
        lda   tlsf.err
        beq   @continue                               ; Branch if no error
;
;       Handle out of memory
        clr   tlsf.err                                ; Clear error code
        ldu   #0                                      ; Out of memory, so reallocate the original block
@freeBlock equ *-2                                    ; When the block was freed, it may have been merged
        ldd   tlsf.blockHdr.size,u                    ; with prev or prev/next physical block(s)
        anda  #^tlsf.mask.FREE_BLOCK
        sta   tlsf.blockHdr.size,u
        addd  #1                                      ; Get (merged) free block size
        pshs  d,x,u                                   ; Reallocate free block
        jsr   tlsf.mappingFreeBlock                   ; by computing fl/sl index (size in [d])
        ldx   @freeBlock
        jsr   tlsf.removeBlock                        ; and removing free block from list and index (free block in [x])
        puls  d,x,u
        leau  4,u                                     ; [u] is reallocated block data
        cmpd  ,s                                      ; Check reallocated block against requested size
        bhs   @continue                               ; Branch if reallocated block is large enough
        lda   #tlsf.err.realloc.OUT_OF_MEMORY
        sta   tlsf.err                                ; Raise an error if realllocated block is not large enough
        cmpu  @start                                  ; Check against original block addr
        beq   @skipMemcpy                             ; Skip memcpy if block has not moved, but restore the 4 erased bytes
                                                      ; or move data to newly allocated block, even if block size is not enough
@continue
        ; move data to newly allocated space
        leay  4,u                                     ; [y] destination + skip 4 bytes that were saved earlier
        stu   @u
        ldu   #0                                      ; [u] source
@start  equ   *-2
        leau  4,u
        ldd   #0                                      ; [d] remaining size to copy
@size   equ   *-2
        beq   @skipMemcpy                             ; a 4-byte block : nothing but the saved bytes
        jsr   memcpy.uyd
;
        ; restore 4 erased bytes by free routine
@skipMemcpy
        ldu   #0                                      ; Restore new allocated addr in u
@u      equ   *-2
        leay  ,u                                      ; [y] destination
        ldd   #0                                      ; First 4 bytes are special case
@data12 equ   *-2
        std   ,y++
        ldd   #0
@data34 equ   *-2
        std   ,y++
;
        ; put back the 8 bytes a split may have taken (opcode patched above)
@guard  bra   @restored                               ; bra : nothing saved / brn : put back
        ldd   #0
@offset equ   *-2
        leay  d,u
        ldd   #0
@bytes01 equ  *-2
        std   ,y
        ldd   #0
@bytes23 equ  *-2
        std   2,y
        ldd   #0
@bytes45 equ  *-2
        std   4,y
        ldd   #0
@bytes67 equ  *-2
        std   6,y
@restored
        ldd   #0
@callback equ *-2
        std   tlsf.err.callback                       ; setup return callback
        lda   tlsf.err
        beq   @rts
        puls  d,x,y
        leas  2,s                                     ; Handle realloc error
        jmp   [tlsf.err.callback]                     ; by calling user callback
@rts    puls  d,x,y,pc


;-----------------------------------------------------------------
; tlsf.realloc.shrink
;
; input  REG : [U] ptr to current block data
; output REG : [U] unchanged allocated memory address
;-----------------------------------------------------------------
; Make a realloc by reducing current block size, and making a new
; free block.
; Data stays in place
;-----------------------------------------------------------------
tlsf.realloc.shrink
        stu   @u
        leax  -tlsf.BHDR_OVERHEAD,u                        ; x is now block to shrink (header)
        ldd   ,s                                           ; get requested size
        leau  d,u                                          ; set u to new block location (header)
        ldd   tlsf.blockHdr.size,x                         ; load size-1 of data block
        subd  ,s                                           ; substract requested size
        subd  #tlsf.BHDR_OVERHEAD                          ; substract new block overhead
        std   tlsf.blockHdr.size,u                         ; set size of new block
        stx   tlsf.blockHdr.prev.phys,u                    ; set previous physical block of new block
        ldd   ,s                                           ; get requested size
        subd  #1                                           ; size is stored as -1
        std   tlsf.blockHdr.size,x                         ; update shrinked bock to requested size
        leau  tlsf.BHDR_OVERHEAD,u                         ; set input parameter for free routine: block (data) location
        jsr   tlsf.free
        ldu   #0                                           ; return unchanged allocated addr in u
@u      equ   *-2
        puls  d,x,y,pc


;-----------------------------------------------------------------
; tlsf.realloc.growth
;
; input  REG : [U] ptr to current block data
; input  REG : [X] ptr to next physical block header
; input  REG : [D] size of remaining bytes in next physical block
; output REG : [U] unchanged allocated memory address
;-----------------------------------------------------------------
; Make a realloc by enlarging current block size
; Data stays in place
;-----------------------------------------------------------------
tlsf.realloc.growth
        stu   @u
        std   @freeSize
;
        ; remove following free block from index
        ldd   tlsf.blockHdr.size,x
        pshs  x,u
        jsr   tlsf.mappingFreeBlock                   ; compute fl/sl index of next physical free block
        ldx   ,s
        jsr   tlsf.removeBlock                        ; remove it from list and index
        puls  x,u
;
        ; check room for a new free block
        ldd   #0
@freeSize equ *-2
        cmpd  #sizeof{tlsf.blockHdr}
        bhs   >                                       ; branch if enough room to build a new free block
        addd  ,s                                      ; no room for a split, add requested size to free size
        subd  #1                                      ; size is stored as size-1 — it was stored whole
                                                      ; (07/09/2026 : a block one byte too long, the
                                                      ; physical chain drifting from there ; met when
                                                      ; the loader's directory buffer grew 512 -> 1024
                                                      ; into a free neighbour that fitted to the byte)
        std   tlsf.blockHdr.size-tlsf.BHDR_OVERHEAD,u ; update size of currently allocated block
        ; the block that followed the absorbed one now follows this one :
        ; tell it, or its next free reads the dead header as its previous
        ; block (07/09/2026 — tlsf.free merges backwards through prev.phys)
        addd  #1                                      ; [D] the new size
        leay  d,u                                     ; [Y] the next physical block header
        beq   @whole                                  ; end of memory
        cmpy  tlsf.memoryPool.end
        bhs   @whole                                  ; no next physical block
        leax  -tlsf.BHDR_OVERHEAD,u                   ; [X] this block's header
        stx   tlsf.blockHdr.prev.phys,y
@whole  puls  d,x,y,pc                                ; return
!
        ; create a new free block
        ldd   ,s                                      ; get requested size
        leax  d,u                                     ; [x] is now ptr to new free block header to create
        leau  -tlsf.BHDR_OVERHEAD,u                   ; [u] is now ptr to header
        stu   tlsf.blockHdr.prev.phys,x               ; link new free block with previous physical
        ldd   ,s                                      ; get requested size
        subd  #1                                      ; size is stored as -1
        std   tlsf.blockHdr.size,u                    ; update growthed bock to requested size
        ldd   @freeSize
        subd  #tlsf.BHDR_OVERHEAD+1
        ora   #tlsf.mask.FREE_BLOCK
        std   tlsf.blockHdr.size,x                    ; store size of new free block
        stx   tlsf.insertBlock.location               ; setup parameter for block insertion
        ldd   @freeSize
        leay  d,x                                     ; Y is now a ptr to next physical of free block
        beq   @nonext                                 ; branch if end of memory (when memory pool goes up to the end of addressable 16bit memory)
            cmpy  tlsf.memoryPool.end
            bhs   @nonext                             ; branch if no next of next physical block (beyond memorypool)
                stx   tlsf.blockHdr.prev.phys,y       ; update the physical link
@nonext
        ldd   tlsf.blockHdr.size,x
        jsr   tlsf.mappingFreeBlock
        jsr   tlsf.insertBlock
        ldu   #0                                      ; restore allocated addr in u
@u      equ   *-2
        puls  d,x,y,pc
