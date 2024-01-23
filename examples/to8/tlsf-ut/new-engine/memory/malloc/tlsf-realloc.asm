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
            puls  d,x,y,pc                   ; nothing to do ... this is the actual size
!       bhi   >                              ; branch if new size is greater
            subd  sizeof{tlsf.blockHdr}
            cmpd  ,s
            bhs   >
                puls  d,x,y,pc               ; nothing to do ... requested size is lower but does not allow a new block (need a minimum size)
!       jmp   tlsf.realloc.shrink
!       leax  d,u                            ; X is now a ptr to next physical block header
        beq   tlsf.realloc.do                ; branch if end of memory (when memory pool goes up to the end of addressable 16bit memory)
        cmpx  tlsf.memoryPool.end
        bhs   tlsf.realloc.do                ; branch if no next physical block (beyond memorypool)
        tst   tlsf.blockHdr.size,x
        bpl   tlsf.realloc.do                ; branch if next physical block is not free
        addd  tlsf.blockHdr.size,x           ; add to actual size, the size of next free block
        addd  #tlsf.BHDR_OVERHEAD+1          ; available size takes header in account in case of merge, size is stored as size-1
        anda  #^tlsf.mask.FREE_BLOCK         ; unset free block bit
        subd  ,s                             ; substract requested size
        cmpd  #0                             ; is the free space enough ?
        bmi   tlsf.realloc.do                ; branch if next physical block does not have enough space
        jmp   tlsf.realloc.growth            ; branch if next physical block fits, [d] is the remaining free memory bytes


;-----------------------------------------------------------------
; tlsf.realloc.do
;
; input  REG : [U] ptr to current physical block
; output REG : [U] new allocated memory address
;-----------------------------------------------------------------
; Make a realloc by doing a free/malloc
; Data is copied
;-----------------------------------------------------------------
tlsf.realloc.do
        ldd   tlsf.blockHdr.prev-tlsf.BHDR_OVERHEAD,u ; Saves 4 bytes that will otherwise be lost
        std   @data12                                 ; when changing occupied block to free
        ldd   tlsf.blockHdr.next-tlsf.BHDR_OVERHEAD,u
        std   @data34
        stu   @start                                  ; Saves data location for later copy
        ldd   tlsf.blockHdr.size-tlsf.BHDR_OVERHEAD,u
        addd  #1-4                                    ; size is stored as size-1, get rid of the 4 bytes already copied
        std   @size
;
        jsr   tlsf.free
        ldd   ,s                                      ; Get requested size
        jsr   tlsf.malloc
        stu   @u
;
        ; move data to newly allocated space
        leay  ,u                                      ; [y] destination set with returned malloc value
        ldd   #0                                      ; first 4 bytes are special case
@data12 equ   *-2
        std   ,y++
        ldd   #0
@data34 equ   *-2
        std   ,y++
;
        ldu   #0                                      ; [u] source
@start  equ   *-2
        leau  4,u
        ldd   #0                                      ; [d] remaining size to copy
@size   equ   *-2
        beq   @rts
        jsr   memcpy.uyd
        ldu   #0                                      ; restore new allocated addr in u
@u      equ   *-2
@rts    puls  d,x,y,pc


;-----------------------------------------------------------------
; tlsf.realloc.shrink
;
; input  REG : [U] ptr to current physical block
; output REG : [U] unchanged allocated memory address
;-----------------------------------------------------------------
; Make a realloc by reducing current block size
; Data stays in place
;-----------------------------------------------------------------
tlsf.realloc.shrink
        stu   @u
        ; split existing block in two parts (one occupied, one free)
        leax  ,u                                           ; x is block to shrink
        ldd   tlsf.blockHdr.size-tlsf.BHDR_OVERHEAD,x      ; load size-1 of data block
        subd  ,s                                           ; substract requested size
        addd  #1                                           ; size is stored as -1
        leau  d,x                                          ; set u to new block location (data)
        subd  #tlsf.BHDR_OVERHEAD+1                        ; substract new header size and size is stored as -1
        std   tlsf.blockHdr.size-tlsf.BHDR_OVERHEAD,u      ; set size of new block
        stx   tlsf.blockHdr.prev.phys-tlsf.BHDR_OVERHEAD,u ; set previous physical block of new block
        jsr   tlsf.free
        ldu   #0                                           ; restore allocated addr in u
@u      equ   *-2
        puls  d,x,y,pc


;-----------------------------------------------------------------
; tlsf.realloc.growth
;
; input  REG : [U] ptr to current physical block
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
        addd  ,s                                      ; add requested size
        std   tlsf.blockHdr.size-tlsf.BHDR_OVERHEAD,u ; update size of currently allocated block
        puls  d,x,y,pc                                ; return
!
        ; create a new free block
        ldd   ,s                                      ; get requested size
        addd  #tlsf.BHDR_OVERHEAD                     ; add overhead of block
        leax  d,u                                     ; [x] is now ptr to new free block header to create
        stu   tlsf.blockHdr.prev.phys,x               ; link new free block with previous physical
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
