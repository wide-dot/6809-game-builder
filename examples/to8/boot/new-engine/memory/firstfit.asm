;-----------------------------------------------------------------
; first fit dynamic memory allocator 
; ----------------------------------
; Benoit Rousseau - 22/08/2023
; ! WARNING ! This code is untested !
;-----------------------------------------------------------------

heap     equ   $8000
maxcells equ   256
cellsize equ   8

freeregion STRUCT
nbcells  rmb 1
location rmb 2
next     rmb 2
        ENDSTRUCT

freeregionlist fdb   firstfreeregion
firstfreeregion
        fcb   maxcells
        fdb   heap
        fdb   0
        fill  0,(sizeof{freeregion}*(maxcells/2))-1

;-----------------------------------------------------------------
; memory.malloc
;
; input  REG : [A] number of requested cells
; output REG : [U] allocated memory location or 0 if no more space
;-----------------------------------------------------------------
memory.malloc
        ldu   #0                            ; Default value (no more free space)
        ldx   #freeregionlist               ; Keep next ptr of previous free region
        ldy   ,x                            ; Load first free region
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
        clr   freeregion.nbcells,y
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
memory.free
        ; ----------------------------------------------------------
        ; Init
        ; ---------------------------------------------------------- 
        sta   memory.free.nbcells           ; Store parameters of released memory
        stx   memory.free.location
        ldb   #cellsize                     ; Compute end location of released memory
        mul
        leax  d,x
        stx   memory.free.endlocation
        ldy   #0                            ; Init previous region in list to 0
        ; ----------------------------------------------------------
        ; Check if free region list is empty (memory full)
        ; ---------------------------------------------------------- 
        ldu   freeregionlist
        beq   @newentry                     ; No free region, add a new one
        ; ----------------------------------------------------------
        ; Parse free region list
        ; ---------------------------------------------------------- 
!       ldx   freeregion.location,u         ; Get location of current region in list
        cmpx  #0                            ; Compare to location of released memory
memory.free.location equ *-2
        bhi   @mergenext                    ; Exit if current region in list is after released memory location
        leay  ,u                            ; Saves previous region to Y
        ldu   freeregion.next,u             ; Move to next region  
        beq   @mergeprev                    ; Branch if no more region
        bra   <
        ; ----------------------------------------------------------
        ; Check if next region is adjacent
        ; ----------------------------------------------------------        
@mergenext
        cmpx  memory.free.endlocation       ; Compare location of current region in list
memory.free.endlocation equ *-2
        bne   @mergeprev                    ; with released memory end location
        ; ----------------------------------------------------------
        ; Merge with next region
        ; ----------------------------------------------------------      
        lda   freeregion.nbcells,u          ; Released memory is adjacent to the end of actual free region
        adda  memory.free.nbcells           ; extend free region
        sta   freeregion.nbcells,u
        ldd   memory.free.location
        std   freeregion.location,u
        ; ----------------------------------------------------------
        ; Check if prev region is adjacent
        ; ----------------------------------------------------------  
        leay  ,y                            ; equivalent to cmpy #0
        beq   @rts                          ; Exit if no previous region
        ldx   freeregion.location,y         ; Compute previous region end location
        lda   freeregion.nbcells,y
        ldb   #cellsize
        mul
        leax  d,x
        cmpx  memory.free.location          ; Compare to location of released memory
        bne   @rts                          ; Exit if not adjacent
        ; ----------------------------------------------------------
        ; Merge with prev region
        ; ---------------------------------------------------------- 
        lda   freeregion.nbcells,u          ; Expand prev region
        adda  freeregion.nbcells,y          ; with next region
        sta   freeregion.nbcells,y
        ldd   freeregion.next,u
        std   freeregion.next,y
        clr   freeregion.nbcells,u          ; delete the next region
@rts    rts 
        ; ----------------------------------------------------------
        ; Check if prev region is adjacent
        ; ----------------------------------------------------------  
@mergeprev
        ldx   freeregion.location,y         ; Compute previous region end location
        lda   freeregion.nbcells,y
        ldb   #cellsize
        mul
        leax  d,x
        cmpx  memory.free.location          ; Compare to location of released memory
        bne   @newentry                     ; Branch if not adjacent
        ; ----------------------------------------------------------
        ; Merge with prev region
        ; ---------------------------------------------------------- 
        lda   freeregion.nbcells,y          ; Expand prev region        
        adda  memory.free.nbcells           ; with released memory
        sta   freeregion.nbcells,y
        rts   
        ; ----------------------------------------------------------
        ; Add new entry to free region list
        ; ----------------------------------------------------------
@newentry
        ldx   #firstfreeregion              ; Read free region list as a table
!       ldb   freeregion.nbcells,x          ; not as a linked list
        beq   @setnewentry                  ; Branch if empty slot
        leax  sizeof{freeregion},x          ; Move to next slot
        bra   <
@setnewentry        
        lda   #0                            ; (dynamic)
memory.free.nbcells equ *-1
        sta   freeregion.nbcells,x          ; Store released cells to new free region
        ldd   memory.free.location
        std   freeregion.location,x         ; Store released memory location to new free region
        stu   freeregion.next,x             ; Link next free region (0 if end of list)
        leay  ,y                            ; equivalent to cmpy #0
        bne   >
        stx   freeregionlist                ; No previous element, update start of linked list
        rts
!       stx   freeregion.next,y             ; Link new region to previous one
        rts
