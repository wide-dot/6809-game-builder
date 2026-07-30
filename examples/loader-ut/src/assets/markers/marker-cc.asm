; marker file "cc" : $0400 bytes, loaded by scene "second" over marker bb
; body  : marker.SIZE-6 bytes filled with the marker id
; tail  : $F0,$F1,$F2,$F3,$F4,id
marker.cc.begin EXPORT

marker.SIZE equ $0400
marker.ID   equ $C3

 SECTION code

marker.cc.begin
        fill  marker.ID,marker.SIZE-6
        fcb   $F0,$F1,$F2,$F3,$F4,marker.ID

 ENDSECTION
