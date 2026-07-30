; marker file "zz" : $0100 bytes, declared LAST in the directory on purpose :
; its directory entry lives in the last INDEX sector, which validates the
; multi-sector directory load path end to end
; body  : marker.zz.SIZE-6 bytes filled with the marker id
; tail  : $F0,$F1,$F2,$F3,$F4,id
marker.zz.begin EXPORT

marker.zz.SIZE equ $0100
marker.zz.ID   equ $5A

 SECTION code

marker.zz.begin
        fill  marker.zz.ID,marker.zz.SIZE-6
        fcb   $F0,$F1,$F2,$F3,$F4,marker.zz.ID

 ENDSECTION
