; stress "hub" : 64 bytes, stable file re-linked at every scene load
; word 0 : extern ref to marker.dd.begin (flips $1000/0 as dd is (un)loaded)
; word 1 : extern ref to marker.ee.begin (flips $1000/0 as ee is (un)loaded)
; word 2 : extern ref to gm.anchor (must stay constant across all re-links)
; then fill with $4B
marker.hub.begin EXPORT
marker.dd.begin  EXTERNAL
marker.ee.begin  EXTERNAL
gm.anchor        EXTERNAL

 SECTION code

marker.hub.begin
        fdb   marker.dd.begin
        fdb   marker.ee.begin
        fdb   gm.anchor
        fill  $4B,58

 ENDSECTION
