pixel.draw EXTERN

singlepix EXPORT
dualpix   EXPORT
gfx.ram.a EXPORT
gfx.ram.b EXPORT

 SECTION absval,constant
singlepix equ $CD
dualpix   equ $ABEF
gfx.ram.a equ $C000
gfx.ram.b equ $A000
 ENDSECTION

 SECTION code
        ;jsr   pixel.draw+1
        ldd   #testbro     
        bra   *
testbro equ *
 ENDSECTION