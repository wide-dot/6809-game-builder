; second member of a multi-object group : this asm is concatenated *after* a
; 256 byte raw blob inside the same direntry. Everything it produces — its
; exported symbol and its relocation offsets — is relative to itself, so the
; builder has to shift both by the size of what precedes it. Before that fix
; only the first member of a group could carry link data.
marker.grp.begin EXPORT
gm.anchor        EXTERNAL

marker.grp.SIZE equ $0100
marker.grp.ID   equ $6B

 SECTION code

marker.grp.begin
        fdb   gm.anchor
        fill  marker.grp.ID,marker.grp.SIZE-8
        fcb   $F0,$F1,$F2,$F3,$F4,marker.grp.ID

 ENDSECTION
