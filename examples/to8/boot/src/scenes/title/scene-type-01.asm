         ; type of scene
        fdb   $4000+2              ; [type | nb files] (0: end marker)

        ; scene data
        fcb   $05                  ; [destination - page id]
        fdb   $0000                ; [destination - address]
        fdb   assets.main.runpixel ; [file id]

        fcb   $06                  ; [destination - page id]
        fdb   $0000                ; [destination - address]
        fdb   assets.object.pixel  ; [file id]

        ; another type of scene, or 0 if end
        fdb   0                   ; [type | nb files] (0: end marker)
 