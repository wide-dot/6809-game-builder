; save.data : the writable file, 300 bytes declared (the builder rounds it up
; to 512 : two whole sectors of its own). Its signature, the boot count the
; bench increments at each boot, then the bytes the bench fills
        fcc   "SAVE"
        fcb   0                        ; +4 : the boot count
        fill  $00,295
