        ; type of scene
        fdb   %10000000+3     ; [type | nb files] (0: end marker)

        ; scene data
        fcb   $01   ; [destination - page id]
        fdb   $0100 ; [destination - address]
        fdb   assets.main.runpixel         ; [file id]
        fdb   assets.object.pixel          ; [file id]
        fdb   builder.floppydisk.directory ; [file id]

        ; another type of scene, or 0 if end
        fdb   0               ; [type | nb files] (0: end marker)