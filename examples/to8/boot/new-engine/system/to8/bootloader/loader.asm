;*******************************************************************************
; FD File loader
; Original code from Prehisto
; Benoit Rousseau 07/2023 (...)
; ------------------------------------------------------------------------------
; A fully featured boot loader
;*******************************************************************************

BYTE   equ 1
POINTR equ 2

* Gfx structure
GFX     STRUCT
E_BANK  rmb BYTE   ;
E_NSEC  rmb BYTE   ; nb of full sectors
E_TRACK rmb BYTE   ; [0000 000] track [0] drive
E_SECT  rmb BYTE   ;
E_ADDR  rmb POINTR ;
E_SIZEA rmb BYTE   ; size in first sector
E_OFFSA rmb BYTE   ; offset in first sector
E_SIZEZ rmb BYTE   ; size in last sector
E_EXEC  rmb POINTR ;
        ENDSTRUCT

*---------------------------------------
* Loader reset (org $6300)

ptsec  equ    $6200

* A = File number
       jmp    >load   Load file
* A = File number
       jmp    >number Get sector count
* $604e = disk error
error  jmp    >dskerr Error
pulse  jmp    >return Load pulse

nsect  fcb    $00     Sector counter
track  fcb    $00     Track number
sector fcb    $00     Sector number

*---------------------------------------
* Get sector count
*---------------------------------------
number ldy    #list   List pointer
       bra    numb2   Enter program
numb0  ldb    GFX.E_BANK,y Read bank number
       bpl    numb1   Skip if no exec
       leay   2,y     Skip exec
numb1  leay   sizeof{GFX},y Next entry
numb2  deca           ! Next
       bpl    numb0   ! entry
       ldb    GFX.E_NSEC,y Read sector count
       rts
       
*---------------------------------------
* Load file
*---------------------------------------
load   pshs   dp
       bsr    number  Point to file
       stb    >nsect  Set sector count
       ldd    #$1060  Direst RAM code/DP
       tfr    b,dp    Set DP
       ora    <$6081  ! Activate
       sta    <$6081  ! direct
       sta    >$e7e7  ! RAM
* Switch bank
       ldb    GFX.E_BANK,y Read bank number
       ldu    GFX.E_ADDR,y Start address
       cmpu   #$4000   ! Skip if
       blo    ld0      ! ROM space
       stb    >$e7e5   Switch RAM bank
       bra    ld1      Load file
ld0    orb    #$60     >Write
       stb    >$e7e6   Switch ROM bank
* Prepare loading
ld1    ldd    GFX.E_TRACK,y ! Set track and
       std    >track    ! sector number
* First sector
       ldb    GFX.E_SIZEA,y ! Skip if
       beq    ld3       ! full sect
       ldx    #ptsec  ! Init sector
       stx    <$604f  ! pointer
       bsr    ldsec   Load sector
       ldd    GFX.E_SIZEA,y Read offs
       abx            Adjust data ptr
       bsr    tfrxua  Copy data
* Intermediate sectors
ld3    stu    <$604f  Init ptr secteur
ld4    ldb    >nsect  ! Exit if
       beq    ld7     ! no sector
       cmpb   #1        !
       bhi    ld5       ! Exit if 
       lda    GFX.E_SIZEZ,y ! last sector
       bne    ld6       !
ld5    bsr    ldsec   Load sector
       inc    <$604f  Move sector ptr
       bra    ld4     Next sector
* Last sector
ld6    ldb    >nsect  ! Skip if
       beq    ld7     ! no sector
       ldu    <$604f  Data pointer
       ldx    #ptsec  ! Init sector
       stx    <$604f  ! pointer
       bsr    ldsec   Load sector
       lda    GFX.E_SIZEZ,y ! Copy
       bsr    tfrxua    ! data
* Next entry
ld7    puls   dp
       ldb    GFX.E_BANK,y ! Next if
       bpl    ld8      ! no exec
       jmp    [GFX.E_EXEC,y] Exec
ld8    rts

* Copy memory area
tfrxua equ    *
       ldb    ,x+      Read data
       stb    ,u+      Write data
       deca            ! Until las
       bne    tfrxua   ! data reached
return equ    *
       rts

* Load a sector
ldsec  equ    *
       pshs   x,y,u
       lda    >track  ; [0000 000] track [0] drive
       lsr    <$6049  ; make room to drive id
       lsra           ; set cc with bit0 (drive) of track variable
       rol    <$6049  ; set bit0 of drive id with cc
       ldb    >track
       andb   #$06    ; get skew based on track nb : 0, 2, 4, 6, 0, 2, 4, 6, ...
       addb   >sector ; add sector to skew
       andb   #$0f    ; loop the index
       ldx    #sclist ; interleave table
       ldb    b,x     ; read sector number
       clr    <$604a  ; init track msb (always 0)
       std    <$604b  ; track/sector
       jsr    >$e004  ; load sector
       bcc    ldsec1  ; skip if ok
       jsr    >$e004  ; reload sector
       lbcs   error   ; I/O Error
* Next sector
ldsec1 ldd    >track  ; read track/sect
       addd   #$f1    ; inc sector, move to next face and move to next track
       andb   #$0f    ; keep only sector bits
       std    >track  ; save track/face/sector
       dec    >nsect  ; counter-1
* Update load bar
       jsr    >pulse  ; send sector pulse
       puls   x,y,u,pc

* Default exit if disk error
dskerr jmp    [$fffe]

* Interleave 2 with a default disk format (interleave 7)
sclist equ    *
       fcb    $01,$0f,$0d,$0b
       fcb    $09,$07,$05,$03
       fcb    $08,$06,$04,$02
       fcb    $10,$0e,$0c,$0a

* Entry list
list   equ    *

       end
