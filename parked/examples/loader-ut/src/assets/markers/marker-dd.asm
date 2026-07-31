; stress variant "dd" : $0400 bytes, swapped with "ee" at the same destination
; header : one word, extern ref to gm.anchor (re-patched at every load)
; body   : marker.SIZE-8 bytes filled with the marker id
; tail   : $F0,$F1,$F2,$F3,$F4,id
marker.dd.begin EXPORT
gm.anchor       EXTERNAL

marker.SIZE equ $0400
marker.ID   equ $D4

 SECTION code

marker.dd.begin
        fdb   gm.anchor
        fill  marker.ID,marker.SIZE-8
        fcb   $F0,$F1,$F2,$F3,$F4,marker.ID

 ENDSECTION
