; marker file "bb" : $0400 bytes (stored raw, no codec)
; body  : marker.SIZE-6 bytes filled with the marker id
; tail  : $F0,$F1,$F2,$F3,$F4,id
marker.bb.begin EXPORT

marker.SIZE equ $0400
marker.ID   equ $B2

 SECTION code

marker.bb.begin
        fill  marker.ID,marker.SIZE-6
        fcb   $F0,$F1,$F2,$F3,$F4,marker.ID

 ENDSECTION
