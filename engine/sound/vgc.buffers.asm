; ------------------------------------------------------
; *** WARNING ***
; this buffer should be aligned to multiple of 256 bytes
; ------------------------------------------------------

vgc.buffers EXPORT

 SECTION code

        align 256
vgc.buffers
        fill 0,256*8

 ENDSECTION