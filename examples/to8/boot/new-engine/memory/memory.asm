heap     equ   $8000
maxcells equ   256
cellsize equ   8

freeregion STRUCT
nbcells  rmb BYTE
location rmb WORD
next     rmb WORD
        ENDSTRUCT

freeregionlist fdb   firstfreeregion
firstfreeregion
        fcb   maxcells
        fdb   heap
        fdb   0
        fill  0,(sizeof{freeregion}*(maxcells/2))-1

;-----------------------------------------------------------------
; memory.alloc
;
; input  REG : [A] number of requested cells
; output REG : [U] allocated memory location or 0 if no more space
;-----------------------------------------------------------------
memory.alloc
        ldu   #0                            ; Default value (no more free space)
        ldx   #freeregionlist               ; Keep next ptr of previous free region
        ldy   freeregionlist                ; Load first free region
@next   beq   @rts                          ; Branch if no more free region
        cmpa  freeregion.nbcells,y          ; Compare requested cells with the nb of free cells of this region
        beq   @fitcell                      ; Branch if same size
        blo   @dividecell                   ; Branch if more than requested
        leax  freeregion.next,y             ; Keep next ptr of previous free region
        ldy   freeregion.next,y             ; Move to next free region
        bra   @next
@fitcell
        ldd   freeregion.next,y             ; Chain previous region
        std   ,x                            ; with next region
        ldu   freeregion.location,y         ; Return allocated memory address
        ;ldd   #0                            ; Clean current free region
        clr   freeregion.nbcells,y
        ;std   freeregion.location,y
        ;std   freeregion.next,y
        rts
@dividecell
        nega                                ; Substract requested cells
        adda  freeregion.nbcells,y          ; to available region cells
        sta   freeregion.nbcells,y
        ldb   #cellsize                     ; Compute new free memory location for this region
        mul
        ldu   freeregion.location,y         ; Return allocated memory address
        leax  d,u                           ; Save new location
        stx   freeregion.location,y         ; for current free region
@rts    rts

;---------------------------------------
; memory.free
;
; input  REG : [A] number of released cells
; input  REG : [X] released memory address
;---------------------------------------
memory.free.endlocation fdb 0

memory.free
        sta   memory.free.nbcells
        stx   memory.free.location
        ldb   #cellsize
        mul
        leax  d,x
        stx   memory.free.endlocation
        ldu   freeregionlist
        beq   @newendentry                  ; No more free region, add a new entry
!       ldx   cell_end,u ; TODO COMPUTE !!! freeregion.location
        cmpx  memory.free.endlocation       ; Search the free region list that is ordered by location
        blo   @combinenext                  ; Branch if we reached position in list
        ldd   freeregion.next,u             ; Test next region
        beq   @combineatend                 ; Branch if no more region
        leax  freeregion.next,u             ; Keep next ptr of previous free region
        stx   @preventry
        ldu   freeregion.next,u             ; Move to next entry        
        bra   <
        ; ----------------------------------------------------------
        ; try to combine with next region
        ; ----------------------------------------------------------        
@combinenext
        stu   @nextentry
        ldx   memory.free.location
        cmpx  cell_end,u ; TODO COMPUTE !!! freeregion.location
        bne   @combineprev
        lda   freeregion.nbcells,u          ; released memory is adjacent to the end of actual free region
        adda  memory.free.nbcells           ; extend free region
        sta   freeregion.nbcells,u
        ldx   memory.free.endlocation       ; check if next region is now adjacent
        ldy   freeregionlist
        cmpx  freeregion.location,y         ; Branch if end location of dessalocated region
        beq   >                             ; match start of an existing free region
        rts
!       ldx   freeregion.location,u         ; extend free region by lowering location
        stx   freeregion.location,y         ; of existing region
        lda   freeregion.nbcells,u        
        adda  freeregion.nbcells,y
        sta   freeregion.nbcells,y
        ldd   freeregion.next,u
        std   freeregion.next,y
        clr   freeregion.nbcells,u          ; delete the entry
        rts 
        ; ----------------------------------------------------------
        ; try to combine with prev region 
        ; ----------------------------------------------------------      
@combineatend
        ldd   #$0000
        std   @nextentry
@combineprev
        ldx   memory.free.endlocation
        cmpx  freeregion.location,u
        bne   @newentry
        ldx   memory.free.location
        stx   freeregion.location,u
        lda   freeregion.nbcells,u        
        adda  memory.free.nbcells
        sta   freeregion.nbcells,u
        rts   
        ; ----------------------------------------------------------
        ; Add new entry to free region list
        ; ----------------------------------------------------------
@newendentry
        ldd   #$0000                        ; End of list
        std   @nextentry                    ; no next region
@newentry
        ldu   #firstfreeregion              ; Read free region list as a table
!       ldb   freeregion.nbcells,u          ; not as a linked list
        beq   @setnewentry                  ; branch if empty entry
        leau  sizeof{freeregion},u          ; move to next entry
        bra   <
@setnewentry        
        lda   #0
memory.free.nbcells equ *-1
        sta   freeregion.nbcells,u          ; store released cells
        ldd   #0
memory.free.location equ *-2
        std   freeregion.location,u         ; store free memory location
        ldd   #$0000                        ; (dynamic) next free region
@nextentry equ *-2
        std   freeregion.next,u             ; link next free region (0 if end of list)
        stu   >$0                           ; (dynamic) prev free region
@preventry equ *-2
        rts
