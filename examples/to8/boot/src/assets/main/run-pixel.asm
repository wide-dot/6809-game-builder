pixel.draw EXTERN

singlepix EXPORT
dualpix   EXPORT
gfx.ram.a EXPORT
gfx.ram.b EXPORT
rel8      EXPORT

 SECTION absval,constant
singlepix equ $CD
dualpix   equ $ABEF
gfx.ram.a equ $C000
gfx.ram.b equ $A000
 ENDSECTION

 SECTION code
        jsr   pixel.draw+2
        ldd   #testbro     
        bra   *
rel8 equ *
        fill  -1,248
        fill  -2,$3E00
        fill  -3,256
testbro equ *

 ENDSECTION