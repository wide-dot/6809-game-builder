pal.black EXPORT

 SECTION code
pal.black
	fill  0,$20
 ENDSECTION

pal.title EXPORT

 SECTION code
pal.title
        fdb   $0000 ; GR0B (0,4,0,0)
        fdb   $a00a ; GR0B (222,4,0,220)
        fdb   $aa09 ; GR0B (222,220,0,218)
        fdb   $4909 ; GR0B (150,204,0,204)
        fdb   $f70e ; GR0B (254,192,0,252)
        fdb   $aa0e ; GR0B (222,220,0,252)
        fdb   $4008 ; GR0B (158,0,0,204)
        fdb   $0a08 ; GR0B (2,220,0,204)
        fdb   $2002 ; GR0B (114,4,0,116)
        fdb   $4004 ; GR0B (160,4,0,164)
 ENDSECTION

pal.score EXPORT

 SECTION code
pal.score
        fdb   $0000 ; GR0B (0,0,0,0)
        fdb   $f00f ; GR0B (255,49,0,255)
        fdb   $0000 ; GR0B (0,0,0,0)
        fdb   $ff0f ; GR0B (255,255,0,255)
        fdb   $f50f ; GR0B (255,165,0,255)
        fdb   $0000 ; GR0B (0,0,0,0)
        fdb   $0001 ; GR0B (0,0,0,107)
        fdb   $0000 ; GR0B (0,0,0,0)
        fdb   $000c ; GR0B (33,0,0,222)
        fdb   $200e ; GR0B (132,16,0,255)
 ENDSECTION

