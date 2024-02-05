         ; type of scene
        fdb   $4000+2                  ; [type | nb files] (0: end marker)

        ; scene data
        fcb   $01                      ; [destination - page id]
        fdb   $6100                    ; [destination - address]
        fdb   assets.gm.title          ; [file id]

        fcb   $06                      ; [destination - page id]
        fdb   $0000                    ; [destination - address]
        fdb   engine.object.sound.ymm

        ; type of scene
        fdb   $8000+2                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $0460                    ; [destination - address]
        fdb   assets.obj.snd.title.ymm 
        fdb   engine.system.to8.sound.ym.const

        ; type of scene, or 0 if end
        fdb   0                        ; [type | nb files] (0: end marker)
