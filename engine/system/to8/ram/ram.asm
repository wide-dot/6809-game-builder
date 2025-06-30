;---------------------------------------
; Set ram page
;
; input  REG : [B] destination - page number
;              [U] destination - address
;---------------------------------------
ram.set
        cmpu  #map.ram.DATA_START ; Skip if not data space
        blo   >
        lda   #$10
        ora   <map.CF74021.SYS1.R ; Set RAM
        sta   <map.CF74021.SYS1.R ; over data
        sta   >map.CF74021.SYS1   ; space
        stb   >map.CF74021.DATA   ; Switch RAM page
        rts
!
        cmpu  #map.ram.SYS_START  ; Skip if not resident space
        blo   >
        rts                       ; nothing to do ... it's resident memory
!
        cmpu  #map.ram.VID_START  ; Skip if not video space
        blo   >
        lda   >map.HALFPAGE       ; Merge register value
        lsra                      ; Get rid of actual half page (bit0)
        rorb                      ; Keep only half page 0 or 1 in CC
        rola                      ; apply actual register
        sta   >map.HALFPAGE       ; Set desired half page in video space
        rts
!
        cmpu  #map.ram.MON_START  ; Skip if not valid address 
        bhs   >
        orb   #map.RAM_OVER_CART  ; Set RAM over cartridge space
        stb   >map.CF74021.CART   ; Switch RAM page
        rts
!       bra   *                   ; error trap