;*******************************************************************************
; FD File loader
; Benoit Rousseau 07/2023 (compressor, linker direntries)
; Based on loader from Prehisto (main direntry)
; ------------------------------------------------------------------------------
; A fully featured boot loader
;*******************************************************************************

BYTE equ 1
WORD equ 2

* directory structure
directory STRUCT
tag     rmb BYTE*3 ; [I] [D] [X]
diskid  rmb BYTE   ; [0000 0000] - [disk id 0-255]
nsector rmb BYTE   ; [0000 0000] - [nb of sectors to load direntries]
        ENDSTRUCT

* direntry main structure
direntry STRUCT
bitfld  rmb BYTE   ; [0] [0] [00 0000] - [compression 0:none, 1:packed] [load time linker 0:no, 1:yes] [free]
track   rmb BYTE   ; [0000 000] [0]    - [track 0-128] [face 0-1]
sector  rmb BYTE   ; [0000 0000]       - [sector 0-255]
sizea   rmb BYTE   ; [0000 0000]       - [bytes in first sector]
offseta rmb BYTE   ; [0000 0000]       - [start offset in first sector (0: no sector)]
nsector rmb BYTE   ; [0000 0000]       - [full sectors to read]
sizez   rmb BYTE   ; [0000 0000]       - [bytes in last sector (0: no sector)]
free    rmb BYTE   ; [0000 0000]       - [free]
        ENDSTRUCT

* direntry compressor structure
cdirentry STRUCT
offset  rmb WORD   ; [0000 0000] [0000 0000] - [offset to compressed data]
dataz   rmb BYTE*6 ; [0000 0000]             - [last 6 bytes of uncompressed file data]
        ENDSTRUCT

* direntry linker structure
ldirentry STRUCT
blocks  rmb BYTE ; [0000 0000]    - [nb of allocation blocks needed]
track   rmb BYTE ; [0000 000] [0] - [track 0-128] [face 0-1]
sector  rmb BYTE ; [0000 0000]    - [sector 0-255]
sizea   rmb BYTE ; [0000 0000]    - [bytes in first sector]
offseta rmb BYTE ; [0000 0000]    - [start offset in first sector (0: no sector)]
nsector rmb BYTE ; [0000 0000]    - [full sectors to read]
sizez   rmb BYTE ; [0000 0000]    - [bytes in last sector (0: no sector)]
free    rmb BYTE ; [0000 0000]    - [free]
        ENDSTRUCT

*---------------------------------------
* Loader routines
*---------------------------------------
        org   $6300
        jmp   >loaddir ; Load directory entries
        jmp   >load    ; Load file (D = File number)
error   jmp   >dskerr  ; Error
pulse   jmp   >return  ; Load pulse

ptsec   equ   $6200    ; temporary space for partial sector loading
nsect   fcb   $00      ; Sector counter
track   fcb   $00      ; Track number
sector  fcb   $00      ; Sector number

*---------------------------------------
* Load directory entries
*---------------------------------------
; TODO
; ldy    #directory.data
       
*---------------------------------------
* Load file (D = File number)
*---------------------------------------
load    pshs  dp
        ldy   #direntries.data
        _lsld
        _lsld
        _lsld
        leay  d,y                      ; Y ptr to main direntry
        ldb   direntry.nsector,y
        stb   >nsect                   ; Set sector count

; to be continued ... WIP

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
sclist fcb    $01,$0f,$0d,$0b
       fcb    $09,$07,$05,$03
       fcb    $08,$06,$04,$02
       fcb    $10,$0e,$0c,$0a

* directory header, followed by direntries
directory.data
direntries.data equ directory.data+sizeof{directory}
