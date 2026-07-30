        ; multi object group : blob of 256 bytes + asm member, one direntry
        fdb   $4000+1                  ; [type | nb files] (0: end marker)

        fcb   $06                      ; [destination - page id]
        fdb   $1C00                    ; [destination - address]
        fdb   data.group.multi         ; [file id]

        fdb   0                        ; end marker
