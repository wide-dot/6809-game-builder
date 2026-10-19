;*******************************************************************************
; A page of its own : an imageset for GetImgIdA (an image is read at
; image_set, its id the byte before it), a routine for paged.call. Mounted only
; by them, which must put the caller's page back.
;*******************************************************************************

 SECTION code

data.img1       EXPORT
data.img2       EXPORT
data.sub        EXPORT

        fcb   $3C                      ; image 1's id
data.img1
        fcb   0
        fcb   $A5                      ; image 2's id
data.img2
        fcb   0

; paged.call's routine : -> A the page it runs in
data.sub
        lda   $E7E6
        rts

 ENDSECTION
