        ; new subscene
        fdb   $4000+5                  ; [type | nb files] (0: end marker)

        ; subscene data
        fcb   $01                      ; [destination - page id]
        fdb   $2100                    ; [destination - address]
        fdb   assets.gm.title          ; [file id]

        fcb   $06                      ; [destination - page id]
        fdb   $B000                    ; [destination - address]
        fdb   engine.object.sound.ymm

        fcb   $07                      ; [destination - page id]
        fdb   $B000                    ; [destination - address]
        fdb   engine.object.sound.vgc

        fcb   $06                      ; [destination - page id]
        fdb   $B400                    ; [destination - address]
        fdb   assets.sounds.title.ymm 

        fcb   $07                      ; [destination - page id]
        fdb   $BA80                    ; [destination - address]
        fdb   assets.sounds.title.vgc

        ; subscene with only link data
        fdb   $8000+2                  ; [type | nb files] (0: end marker)

        fcb   0                        ; [destination - page id]
        fdb   0                        ; [destination - address]
        fdb   engine.system.mo6.sound.ym.const
        fdb   engine.system.mo6.sound.sn.const

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)