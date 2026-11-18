* ---------------------------------------------------------------------------
* wallscaler : textured wall columns, the resident part
* ---------------------------------------------------------------------------
* Included by the game mode, after the builder's <wallscaler form="consts">.
*
* A column descriptor is 6 bytes (wallscaler.DESC), left to right in
* wallscaler.descriptors : the scaler's page ($E7E6 value), the wall's top
* row in the view, the texture column's address, the scaler's address.
* wallscaler.draw overwrites them.
*
* Entries (A, B, X, Y, U and CC lost), in the loop's gfxlock section :
*   wallscaler.draw         the descriptors drawn in the back buffer
*   wallscaler.background   the view of the buffer in the data window to
*                           the empty room : ceiling, floor. Both buffers,
*                           before the first frame
* ---------------------------------------------------------------------------

wallscaler.columns EXTERNAL

wallscaler.draw
        _GetCartPageB                      ; the caller's page, given back :
        pshs  b                            ; the columns mount the scalers'
        bsr   @go
        puls  b
        _SetCartPageB
        rts
@go     sts   wallscaler.stack             ; the columns end on lds ,s, rts
        lds   #wallscaler.descriptors
        jmp   wallscaler.columns

wallscaler.background
        ldx   #$A000+wallscaler.Y*40+wallscaler.X/2
        bsr   @bank
        ldx   #$C000+wallscaler.Y*40+wallscaler.X/2
@bank   lda   #wallscaler.CEIL
        ldb   #wallscaler.ROWS/2
        bsr   @rows
        lda   #wallscaler.FLOOR
        ldb   #wallscaler.ROWS/2
@rows   pshs  b
@row    ldb   #wallscaler.COLS/2
@byte   sta   ,x+
        decb
        bne   @byte
        leax  40-wallscaler.COLS/2,x
        dec   ,s
        bne   @row
        puls  b,pc

        fill  0,128                        ; room for the pushes under the descriptors
wallscaler.descriptors
        fill  0,wallscaler.COLS*wallscaler.DESC
wallscaler.stack
        fdb   0
