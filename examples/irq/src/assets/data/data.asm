;*******************************************************************************
; An imageset's page for GetImgIdA : an image is read at image_set, its id the
; byte before it. Mounted only by GetImgIdA, which must put the caller's page
; back.
;*******************************************************************************

 SECTION code

data.img1       EXPORT
data.img2       EXPORT

        fcb   $3C                      ; image 1's id
data.img1
        fcb   0
        fcb   $A5                      ; image 2's id
data.img2
        fcb   0

 ENDSECTION
