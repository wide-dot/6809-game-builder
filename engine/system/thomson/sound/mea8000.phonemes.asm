; phonemes 3.3 from "Parole et Micros" book
; index table is no more offsets, but absolute addresses
; padding values originally found after offset table are gone
; phoneme header was: length(hi), length(lo), $3C, $3C
; new header is     : length(lo)
; 

 SECTION code

mea8000.phonemes
        fdb   mea8000.phonemes.data.a
        fdb   mea8000.phonemes.data.e
        fdb   mea8000.phonemes.data.i
        fdb   mea8000.phonemes.data.O
        fdb   mea8000.phonemes.data.u
        fdb   mea8000.phonemes.data.ai
        fdb   mea8000.phonemes.data.et
        fdb   mea8000.phonemes.data.eu
        fdb   mea8000.phonemes.data.ou
        fdb   mea8000.phonemes.data.an
        fdb   mea8000.phonemes.data.in
        fdb   mea8000.phonemes.data.on
        fdb   mea8000.phonemes.data.oi
        fdb   mea8000.phonemes.data.b
        fdb   mea8000.phonemes.data.d
        fdb   mea8000.phonemes.data.f
        fdb   mea8000.phonemes.data.g
        fdb   mea8000.phonemes.data.j
        fdb   mea8000.phonemes.data.k
        fdb   mea8000.phonemes.data.l
        fdb   mea8000.phonemes.data.m
        fdb   mea8000.phonemes.data.n
        fdb   mea8000.phonemes.data.p
        fdb   mea8000.phonemes.data.R
        fdb   mea8000.phonemes.data.r
        fdb   mea8000.phonemes.data.S
        fdb   mea8000.phonemes.data.t
        fdb   mea8000.phonemes.data.v
        fdb   mea8000.phonemes.data.z
        fdb   mea8000.phonemes.data.ch
        fdb   mea8000.phonemes.data.gn
        fdb   mea8000.phonemes.data.ail
        fdb   mea8000.phonemes.data.eil
        fdb   mea8000.phonemes.data.euil
        fdb   mea8000.phonemes.data.ien
        fdb   mea8000.phonemes.data.oin
        fdb   mea8000.phonemes.data.o
        fdb   mea8000.phonemes.data.s
        fdb   mea8000.phonemes.data.32ms
        fdb   mea8000.phonemes.data.64ms

mea8000.phonemes.data.f
        fcb   12
        fcb   $16,$B7,$FD,$D0,$16,$B7,$FE,$F0,$16,$B7,$FE,$F0

mea8000.phonemes.data.g
        fcb   20
        fcb   $FF,$97,$60,$60,$FF,$97,$63,$80,$FF,$97,$65,$00,$FA,$97,$66,$80
        fcb   $A6,$97,$66,$B0

mea8000.phonemes.data.j
        fcb   20
        fcb   $1E,$BA,$7B,$30,$1E,$BA,$7D,$A0,$1E,$BA,$76,$B0,$1E,$BA,$76,$A0
        fcb   $1E,$BA,$76,$B0

mea8000.phonemes.data.k
        fcb   20
        fcb   $09,$97,$88,$70,$0D,$97,$8F,$90,$0D,$97,$8F,$10,$09,$97,$8E,$90
        fcb   $67,$96,$86,$20

mea8000.phonemes.data.l
        fcb   12
        fcb   $74,$B5,$55,$40,$74,$B6,$2E,$40,$28,$B5,$56,$C0

mea8000.phonemes.data.m
        fcb   12
        fcb   $4C,$B4,$5D,$60,$4A,$B4,$5E,$E0,$4A,$B4,$5F,$A0

mea8000.phonemes.data.n
        fcb   16
        fcb   $B8,$B4,$55,$20,$48,$B4,$5E,$20,$4C,$B4,$5F,$20,$4A,$B4,$5F,$A0

mea8000.phonemes.data.p
        fcb   24
        fcb   $C2,$B9,$38,$70,$11,$B6,$93,$90,$11,$B6,$97,$90,$11,$B6,$97,$10
        fcb   $16,$B3,$BE,$10,$58,$B2,$8D,$A0

mea8000.phonemes.data.R
        fcb   20
        fcb   $3A,$B3,$80,$00,$3A,$B3,$84,$00,$36,$B3,$8D,$A0,$79,$B2,$96,$20
        fcb   $97,$B1,$CD,$20

mea8000.phonemes.data.S
        fcb   8
        fcb   $0E,$F3,$BC,$70,$0E,$F3,$8D,$70

mea8000.phonemes.data.v
        fcb   16
        fcb   $6A,$B2,$85,$40,$6A,$B2,$86,$C0,$6A,$B2,$86,$D0,$6A,$B2,$86,$B0

mea8000.phonemes.data.z
        fcb   8
        fcb   $12,$F5,$77,$40,$AA,$B4,$76,$C0

mea8000.phonemes.data.ch
        fcb   8
        fcb   $29,$BA,$8E,$F0,$29,$BA,$8E,$F0

mea8000.phonemes.data.gn
        fcb   32
        fcb   $98,$D7,$5D,$C0,$98,$D7,$5D,$A0,$99,$D6,$55,$20,$8E,$D6,$5C,$20
        fcb   $8F,$D8,$5E,$40,$AF,$DB,$56,$E0,$7F,$D8,$5F,$40,$6B,$87,$6F,$C0

mea8000.phonemes.data.ail
        fcb   40
        fcb   $57,$B3,$DD,$C0,$46,$B4,$E7,$C0,$46,$B4,$DF,$C0,$AB,$B4,$CF,$C0
        fcb   $EA,$B5,$C7,$40,$FA,$B6,$B6,$C0,$BA,$B7,$9E,$40,$BA,$DB,$7D,$40
        fcb   $FA,$DB,$73,$40,$FA,$DB,$70,$20

mea8000.phonemes.data.eil
        fcb   32
        fcb   $88,$B7,$B6,$40,$FB,$B7,$AF,$40,$FB,$B7,$AF,$C0,$BB,$B7,$9F,$E0
        fcb   $B6,$B8,$9F,$20,$BA,$D8,$8F,$40,$BA,$DB,$7E,$C0,$FA,$DB,$75,$C0

mea8000.phonemes.data.euil
        fcb   48
        fcb   $EB,$B3,$AE,$40,$97,$B4,$A7,$40,$97,$B4,$A7,$C0,$57,$B4,$A7,$C0
        fcb   $67,$B6,$9F,$40,$77,$B6,$87,$40,$BB,$B7,$7E,$C0,$EB,$B7,$7E,$A0
        fcb   $AB,$BB,$7E,$20,$AB,$D8,$76,$20,$6B,$D8,$76,$20,$BA,$B7,$8C,$C0

mea8000.phonemes.data.ien
        fcb   36
        fcb   $7F,$D8,$6D,$40,$7F,$D8,$6E,$C0,$BF,$D7,$87,$20,$FB,$D7,$8F,$20
        fcb   $BB,$D7,$9F,$A0,$67,$D6,$BF,$E0,$67,$D5,$BF,$40,$61,$D5,$BE,$40
        fcb   $61,$D4,$C5,$40

mea8000.phonemes.data.oin
        fcb   28
        fcb   $86,$94,$BD,$C0,$86,$96,$C7,$A0,$42,$B4,$D7,$A0,$53,$B4,$CF,$C0
        fcb   $53,$B5,$CF,$E0,$62,$B5,$C7,$40,$62,$B5,$C5,$40

mea8000.phonemes.data.32ms
        fcb   4
        fcb   $86,$B3,$C8,$40

mea8000.phonemes.data.64ms
        fcb   4
        fcb   $96,$B2,$C8,$60

mea8000.phonemes.data.a
        fcb   16
        fcb   $86,$B3,$CD,$C0,$86,$B2,$D6,$C0,$96,$B2,$CE,$C0,$97,$B1,$CD,$C0

mea8000.phonemes.data.e
        fcb   16
        fcb   $AF,$B3,$85,$40,$AB,$B3,$7E,$40,$AB,$B3,$86,$40,$FF,$B3,$85,$40

mea8000.phonemes.data.o
        fcb   16
        fcb   $AD,$AF,$A5,$40,$AD,$AF,$A6,$40,$AD,$AD,$96,$40,$F9,$AD,$8D,$40

mea8000.phonemes.data.u
        fcb   16
        fcb   $B7,$B7,$5D,$40,$B7,$B7,$66,$C0,$B7,$B7,$66,$C0,$B7,$B7,$5D,$40

mea8000.phonemes.data.ai
        fcb   16
        fcb   $A6,$B6,$B5,$40,$B6,$B6,$BF,$40,$B6,$B6,$B7,$40,$FA,$B7,$A5,$40

mea8000.phonemes.data.O
        fcb   16
        fcb   $C7,$AC,$84,$C0,$C6,$AB,$85,$40,$C6,$AB,$85,$40,$D6,$AB,$84,$C0

mea8000.phonemes.data.on
        fcb   24
        fcb   $82,$D1,$A5,$40,$83,$CF,$AE,$C0,$C3,$CE,$AF,$40,$C3,$D1,$9E,$C0
        fcb   $D2,$D3,$96,$40,$92,$D2,$95,$40

mea8000.phonemes.data.eu
        fcb   16
        fcb   $D6,$B3,$6E,$40,$FA,$B4,$67,$60,$F6,$B4,$66,$C0,$EA,$B4,$65,$C0

mea8000.phonemes.data.oi
        fcb   28
        fcb   $5A,$84,$9C,$40,$5A,$84,$9D,$40,$5A,$8A,$B6,$C0,$B7,$AD,$C6,$C0
        fcb   $47,$B1,$CE,$E0,$97,$B2,$C6,$40,$9B,$BA,$C4,$40

mea8000.phonemes.data.an
        fcb   20
        fcb   $52,$CA,$BD,$40,$97,$CA,$BD,$C0,$97,$CA,$DB,$C0,$97,$CA,$DB,$C0
        fcb   $83,$CA,$BD,$40

mea8000.phonemes.data.in
        fcb   16
        fcb   $66,$B4,$BD,$C0,$66,$B5,$BF,$40,$65,$B5,$C7,$60,$61,$B5,$D5,$C0

mea8000.phonemes.data.ou
        fcb   12
        fcb   $9B,$AD,$6D,$40,$DB,$AE,$6D,$E0,$9B,$AE,$6D,$40

mea8000.phonemes.data.s
        fcb   4
        fcb   $0E,$F3,$BC,$70
        
mea8000.phonemes.data.i
        fcb   16
        fcb   $AF,$DA,$5D,$40,$AF,$DA,$5E,$40,$AF,$DA,$66,$40,$AF,$DA,$65,$40

mea8000.phonemes.data.d
        fcb   20
        fcb   $80,$B5,$18,$60,$10,$05,$04,$A0,$A0,$D5,$0C,$20,$40,$D2,$2C,$A0
        fcb   $40,$D9,$5E,$20

mea8000.phonemes.data.b
        fcb   20
        fcb   $80,$D6,$1A,$60,$90,$B2,$13,$20,$A4,$B2,$13,$20,$A5,$B1,$24,$20
        fcb   $EA,$91,$75,$B0

mea8000.phonemes.data.t
        fcb   20
        fcb   $B6,$F6,$90,$70,$B6,$F6,$90,$10,$B6,$F6,$96,$90,$B6,$F6,$96,$10
        fcb   $9B,$B4,$BD,$A0
        
mea8000.phonemes.data.et
        fcb   16
        fcb   $BB,$B8,$85,$C0,$BB,$B8,$87,$40,$BB,$B8,$87,$40,$FB,$B8,$85,$C0
        
mea8000.phonemes.data.r
        fcb   12
        fcb   $F5,$B0,$A5,$40,$B5,$AF,$B3,$C0,$54,$B0,$39,$C0

 ENDSECTION