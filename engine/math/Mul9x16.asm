; ---------------------------------------------------------------------------
; Mul9x16 - a signed 9 bit multiplier (D, -256 to 256) times a signed 16 bit
; multiplicand (X) -> D : the product / 256 (signed 16 bit)
; e.g. D = $0100, X = $2000 -> D = $2000
; trashes : x ; dp_engine+0 to +5
; ---------------------------------------------------------------------------

@m      equ dp_engine                  ; the multiplier's magnitude
@m_h    equ dp_engine+1                ; the multiplicand's magnitude
@m_l    equ dp_engine+2
@r_h    equ dp_engine+3                ; the low partial product
@r_l    equ dp_engine+4
@r      equ dp_engine+5                ; its low byte : the fraction
Mul9x16
        tsta
        beq   @pos  ; $0000 <= d <= $00FF
        bpl   @p256 ; d = $0100
        tstb
        bne   @neg  ; $FF01 >= d >= $FFFF    
@n256   tfr   x,d   ; d = $FF00
        nega
        negb
        sbca  #0    ; *-1
        rts
@p256
        tfr   x,d   ; *1
        rts
@pos                
        stb   <@m    ; positive multiplier
        stx   <@m_h
        bpl   @mul  ; positive result
        ldd   <@m_h  ; negative multiplicand
        nega
        negb
        sbca  #0
        std   <@m_h
        ldb   <@m
@neg1   bsr   @mul
        coma        ; negative result
        comb
        neg   <@r
        bne   >
        addd  #1
!       rts
@neg    
        negb        ; negative multiplier
        stb   <@m
        stx   <@m_h
        bpl   @neg1 ; positive multiplicand
        ldd   <@m_h  ; negative multiplicand and positive result
        nega
        negb
        sbca  #0
        std   <@m_h
        ldb   <@m
@mul 
        lda   <@m_l  ; get lsb's of multiplicand
        mul         ; multiply lsb's
        std   <@r_l  ; save partial product
        lda   <@m    ; get multiplier
        ldb   <@m_h  ; get msb's of multiplicand
        mul         ; multiply msb's
        addb  <@r_l  ; add lsb's to msb's of previous partial product
        adca  #0    ; add carry to msb's
        ;std   @r_h  ; save sum of partial products 
        rts
