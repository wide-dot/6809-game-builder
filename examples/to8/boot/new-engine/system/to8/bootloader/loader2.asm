;*******************************************************************************
; FD File loader
; Benoit Rousseau 07/2023 (compressor, linker direntries)
; Based on loader from Prehisto (main direntry)
; ------------------------------------------------------------------------------
; A fully featured boot loader
;*******************************************************************************

        INCLUDE "./engine/constants.asm"
        INCLUDE "./engine/system/to8/map.const.asm"

BYTE equ 1
WORD equ 2

* directory structure
dirheader STRUCT
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
        jmp   >load    ; Load file
error   jmp   >dskerr  ; Error
pulse   jmp   >return  ; Load pulse

ptsec   equ   $6200    ; temporary space for partial sector loading
diskid   fcb   $00     ; disk id
nsect   fcb   $00      ; Sector counter
track   fcb   $00      ; Track number
sector  fcb   $00      ; Sector number

;---------------------------------------
; Load directory entries
;
; D: [diskid] [face]
; X: [track] [sector]
;---------------------------------------

loaddir
; read first directory sector
        sta   >diskid         ; Save desired directory id for check
        stb   <map.DK.DRV     ; Set directory location
        tfr   x,d             ; on floppy disk
        sta   <map.DK.TRK+1   ; B is loaded with sector id
        ldy   #dirheader.data ; Loading address for
        sty   <map.DK.BUF     ; directory data
        lda   #$02            ; Read code
        sta   <map.DK.OPC     ; operation
        ldu   #sclist         ; Interleave list
        ldx   #messIO         ; Info message
        lda   b,u             ; Get sector
        sta   <map.DK.SEC     ; number
@retry  jsr   >map.DKCONT     ; Load sector
        bcc   >               ; Skip if no error
        jsr   >map.DKCONT     ; Reload sector
        bcc   >               ; Skip if no error
        jsr   >info           ; Error
        bra   @retry
; check for directory id match
!       ldx   #messdiskid
        lda   directory.diskid,y
        cmpa  >diskid
        beq   >               ; Skip if disk id is ok
        jsr   >info
        bra   @retry
; read remaining directory entries
!       lda   directory.nsector,y ; init nb sectors to read       
        sta   >nsect
        ldx   #messIO      ; Error message
        bra   @next
@load   lda   b,u          ; Get sector
        sta   <map.DK.SEC  ; number
        jsr   >map.DKCONT  ; Load sector
        bcc   @next        ; Skip if no error
        jsr   >map.DKCONT  ; Reload sector
        bcc   @next        ; Skip if no error
        jmp   err          ; Error
@next   inc   <map.DK.BUF  ; Move sector ptr
        incb               ; Sector+1
        dec   >nsect       ; Next
        bne   @load        ; sector
        rts

;---------------------------------------
; Load file
;
; X: [file number]
; B: [destination - page number]
; U: [destination - address]
;---------------------------------------
load    pshs  dp
        lda   #$10
        ora   <$6081             ; Set RAM
        sta   <$6081             ; over data
        sta   >$e7e7             ; space
        lda   #$60
        tfr   a,dp               ; Set DP
* Switch page
        cmpu  #$4000             ; Skip if
        blo   ld0                ; cartridge space
        stb   >$e7e5             ; Switch RAM page
        bra   ld1                ; Load file
ld0     orb   #$60               ; Set RAM over data space
        stb   >$e7e6             ; Switch ram page
* Prepare loading
ld1     ldy   #direntries.data
        tfr   x,d
        _lsld                    ; Scale file id
        _lsld                    ; to dir entry size
        _lsld
        leay  d,y                ; Y ptr to file direntry
        ldb   direntry.nsector,y ; Get number of sectors
        stb   >nsect             ; Set sector count
        ldd   direntry.track,y   ; Set track, face and
        std   >track             ; sector number
* First sector
        ldb   direntry.sizea,y   ; Skip if
        beq   ld3                ; full sect
        ldx   #ptsec             ; Init buffer
        stx   <map.DK.BUF        ; location
        bsr   ldsec              ; Load sector
        ldd   direntry.sizea,y   ; Read A:size, B:offset
        abx                      ; Adjust data ptr
        bsr   tfrxua             ; Copy data from buffer to RAM
* Intermediate sectors
ld3     stu   <map.DK.BUF        ; Init dest location
ld4     ldb   >nsect             ; Exit if
        beq   ld7                ; no sector
        cmpb  #1
        bhi   ld5                ; Exit if 
        lda   direntry.sizez,y   ; last sector
        bne   ld6
ld5     bsr   ldsec              ; Load sector
        inc   <map.DK.BUF        ; Update dest location MSB
        bra   ld4                ; Next sector
* Last sector
ld6     ldb   >nsect             ; Skip if
        beq   ld7                ; no last sector
        ldu   <map.DK.BUF        ; Data pointer
        ldx   #ptsec             ; Init buffer
        stx   <map.DK.BUF        ; location
        bsr   ldsec              ; Load sector
        lda   direntry.sizez,y   ; Copy
        bsr   tfrxua             ; data
* Next entry
ld7     puls  dp,pc

* Copy memory space
tfrxua
        ldb   ,x+                ; Read data
        stb   ,u+                ; Write data
        deca                     ; Until las
        bne   tfrxua             ; data reached
return  rts

* Load a sector
ldsec   equ   *
        pshs  x,y,u
        lda   >track             ; [0000 000] track [0] drive
        lsr   <map.DK.DRV        ; make room to drive id
        lsra                     ; set cc with bit0 (drive) of track variable
        rol   <map.DK.DRV        ; set bit0 of drive id with cc
        ldb   >track
        andb  #$06               ; get skew based on track nb : 0, 2, 4, 6, 0, 2, 4, 6, ...
        addb  >sector            ; add sector to skew
        andb  #$0f               ; loop the index
        ldx   #sclist            ; interleave table
        ldb   b,x                ; read sector number
        clr   <map.DK.TRK        ; init track msb (always 0)
        std   <map.DK.TRK+1      ; track/sector
        jsr   >map.DKCONT        ; load sector
        bcc   ldsec1             ; skip if ok
        jsr   >map.DKCONT        ; reload sector
        lbcs  error              ; I/O Error
* Next sector
ldsec1  ldd   >track             ; read track/sect
        addd  #$f1               ; inc sector, move to next face and move to next track
        andb  #$0f               ; keep only sector bits
        std   >track             ; save track/face/sector
        dec   >nsect             ; counter-1
* Update load bar
        jsr   >pulse             ; send sector pulse
        puls  x,y,u,pc

* Default exit if disk error
dskerr  jmp   [$fffe]

* Interleave 2 with a default disk format (interleave 7)
sclist  fcb   $01,$0f,$0d,$0b
        fcb   $09,$07,$05,$03
        fcb   $08,$06,$04,$02
        fcb   $10,$0e,$0c,$0a

;---------------------------------------
; Display messages
;
; X : [ptr to ascii string]
;---------------------------------------

* Display error message
err     ldu   #messloc           ; Location
        bsr   err2               ; Display location
        leau  ,x                 ; Message pointer
        bsr   err2               ; Display message
err0    bra   err0               ; Infinite loop

* Display message
err1    bsr   err3               ; Display char
err2    ldb   ,u+                ; Read char
        bpl   err1               ; Next if not last
        andb  #$7f               ; Mask char
err3    bra   map.PUTC           ; Display for TO - PUTC

* Display info message and wait a keystroke
info    
!       jsr   KTST
        bcs   <
        rts

* Location message
messloc fcb   $1f,$21,$21
        fcb   $1f,$11,$13        ; 3 lines (11-13)
        fcb   $1b,$47            ; font : white
        fcb   $1b,$51            ; background : red
        fcb   $0c                ; cls
        fcb   $1f,$4c,$4b+$80    ; locate for MO

messIO     fcs   "     I/O|Error"
messdiskid fcs   " Insert disk "

*---------------------------------------
* Directory entries
*---------------------------------------

dirheader.data
direntries.data equ dirheader.data+sizeof{dirheader}
