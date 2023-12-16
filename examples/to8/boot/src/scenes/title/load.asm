
        ; load direntries
        ldd   #$0000 ; D: [diskid] [face]
        ldx   #$000E ; X: [track] [sector]
        jsr   $6300  ; load direntries

        ; load files
        ldx   #$0000 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$A000 ; U: [destination - address]
        jsr   $6303  ; load file

        ldx   #$0003 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$B000 ; U: [destination - address]
        jsr   $6303  ; load file

        ; uncompress files
        ldx   #$0000 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$A000 ; U: [destination - address]
        jsr   $6306  ; uncompress file

        ldx   #$0003 ; X: [file number]
        ldb   #$04   ; B: [destination - page number]
        ldu   #$B000 ; U: [destination - address]
        jsr   $6306  ; uncompress file

        ; link files
        jmp   $6309  ;