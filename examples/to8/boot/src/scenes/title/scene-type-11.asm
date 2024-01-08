        ; type of scene
        fdb   $C000+2              ; [type | nb files] (0: end marker)

        ; scene data
        fcb   $05                  ; [destination - starting page id]
        fdb   $0000                ; [destination - starting address]
        fdb   assets.main.runpixel ; [starting file id]

        ; another type of scene, or 0 if end
        fdb   0                    ; [type | nb files] (0: end marker)
