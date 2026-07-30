; marker file "aa" : $0400 bytes
; body  : marker.SIZE-6 bytes filled with the marker id
; tail  : $F0,$F1,$F2,$F3,$F4,id (checks the loader's cdataz 6-byte tail handling)
marker.aa.begin EXPORT

marker.SIZE equ $0400
marker.ID   equ $A1

 SECTION code

marker.aa.begin
        fill  marker.ID,marker.SIZE-6
        fcb   $F0,$F1,$F2,$F3,$F4,marker.ID

 ENDSECTION
