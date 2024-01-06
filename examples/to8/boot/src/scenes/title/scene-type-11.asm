        ; type of scene
        fdb   %11000000+2     ; [type | nb files] (0: end marker)

        ; scene data
        fcb   $01   ; [destination - starting page id]
        fdb   $0100 ; [destination - starting address]
        fdb   assets.main.runpixel ; [starting file id]

        ; another type of scene, or 0 if end
        fdb   0               ; [type | nb files] (0: end marker)