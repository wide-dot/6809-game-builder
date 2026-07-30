; marker file "d1" : $0200 bytes, lives on DISK 1
; header : one word, extern ref to gm.anchor — an export of the game mode
;          that lives on disk 0, so this checks cross-disk linking inbound
; body   : marker.d1.SIZE-8 bytes filled with the marker id
; tail   : $F0,$F1,$F2,$F3,$F4,id
; it also exports marker.d1.begin, referenced by the disk 0 game mode
; (cross-disk linking outbound)
marker.d1.begin EXPORT
gm.anchor       EXTERNAL

marker.d1.SIZE equ $0200
marker.d1.ID   equ $1D

 SECTION code

marker.d1.begin
        fdb   gm.anchor
        fill  marker.d1.ID,marker.d1.SIZE-8
        fcb   $F0,$F1,$F2,$F3,$F4,marker.d1.ID

 ENDSECTION
