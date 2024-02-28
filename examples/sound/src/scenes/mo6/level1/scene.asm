        ; new scene
        fdb   $4000+2                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $B400                    ; [destination - address]
        fdb   assets.obj.snd.level1.ymm 

        fcb   $07                      ; [destination - page id]
        fdb   $BA80                    ; [destination - address]
        fdb   assets.obj.snd.level1.vgc

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)