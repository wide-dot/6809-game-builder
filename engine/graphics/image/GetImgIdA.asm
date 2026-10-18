* ---------------------------------------------------------------------------
* GetImgIdA - U an object -> A its image's id, the byte before image_set's
* image, read in the object's imageset page ; the caller's page kept
* trashes : b, x
* ---------------------------------------------------------------------------
GetImgIdA
        _GetCartPageA
        sta   GetImgIdA.page
        ldx   #Img_Page_Index               ; the object's imageset page
        ldb   id,u
        abx
        lda   ,x
        _SetCartPageA
        ldx   image_set,u
        lda   -1,x
        ldb   #$00
GetImgIdA.page equ *-1                      ; (dynamic) the caller's page
        _SetCartPageB
        rts