        ; new subscene
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        ; subscene data
        fcb   $01                      ; [destination - page id]
        fdb   $6300                    ; [destination - address]
        fdb   assets.gm.title          ; [file id]

        ; new subscene
        fdb   $8000+9                  ; [type | nb files] (0: end marker)

        fcb   $05                      ; [destination - page id]
        fdb   $0000                    ; [destination - address] in half page
        fdb   assets.sounds.samples    ; [file id]
        fdb   assets.sounds.sn
        fdb   assets.sounds.sn.noise
        fdb   assets.sounds.ym
        fdb   assets.sounds.ym.rythm
        fdb   engine.system.to8.sound.mplus.const
        fdb   assets.sounds.mea8000
        fdb   assets.sounds.sn.music
        fdb   assets.sounds.ym.music

        ; end scenes
        fdb   0                        ; [type | nb files] (0: end marker)