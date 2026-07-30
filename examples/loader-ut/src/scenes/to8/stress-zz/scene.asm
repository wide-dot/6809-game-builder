        ; stress scene : marker zz (last directory entry)
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $1400                    ; [destination - address]
        fdb   data.marker.zz           ; [file id]

        fdb   0                        ; end marker
