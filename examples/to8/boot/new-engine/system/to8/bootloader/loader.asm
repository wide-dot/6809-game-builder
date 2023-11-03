;*******************************************************************************
; FD File loader
; Benoit Rousseau 07/2023 (compressor, linker direntries)
; Based on loader from Prehisto (main direntry)
; ------------------------------------------------------------------------------
; A fully featured boot loader
;*******************************************************************************
 SETDP $ff
        INCLUDE "new-engine/constant/types.const.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/system/to8/map.const.asm"

; directory structure
; -------------------
dirheader STRUCT
tag     rmb types.BYTE*3 ; [I] [D] [X]
diskid  rmb types.BYTE   ; [0000 0000]              - [disk id 0-255]
nsector rmb types.BYTE   ; [0000 0000]              - [nb of sectors for direntries]
        ENDSTRUCT

; direntry main structure
; -----------------------
direntry STRUCT
bitfld   rmb types.BYTE   ; [0] [0] [00 0000]       - [compression 0:none, 1:packed] [load time linker 0:no, 1:yes] [free]
free     rmb types.BYTE   ; [0000 0000]             - [free]
track    rmb types.BYTE   ; [0000 000] [0]          - [track 0-128] [face 0-1]
sector   rmb types.BYTE   ; [0000 0000]             - [sector 0-255]
sizea    rmb types.BYTE   ; [0000 0000]             - [bytes in first sector]
offseta  rmb types.BYTE   ; [0000 0000]             - [start offset in first sector (0: no sector)]
nsector  rmb types.BYTE   ; [0000 0000]             - [full sectors to read]
sizez    rmb types.BYTE   ; [0000 0000]             - [bytes in last sector (0: no sector)]

; direntry compressor structure
; -----------------------------
coffset  rmb types.WORD   ; [0000 0000] [0000 0000] - [offset to compressed data]
cdataz   rmb types.BYTE*6 ; [0000 0000]             - [last 6 bytes of uncompressed file data]

; direntry linker structure
; -------------------------
lsize    rmb types.BYTE   ; [0000 0000] [0000 0000] - [linker data size]
ltrack   rmb types.BYTE   ; [0000 000] [0]          - [track 0-128] [face 0-1]
lsector  rmb types.BYTE   ; [0000 0000]             - [sector 0-255]
lsizea   rmb types.BYTE   ; [0000 0000]             - [bytes in first sector]
loffseta rmb types.BYTE   ; [0000 0000]             - [start offset in first sector (0: no sector)]
lnsector rmb types.BYTE   ; [0000 0000]             - [full sectors to read]
lsizez   rmb types.BYTE   ; [0000 0000]             - [bytes in last sector (0: no sector)]
        ENDSTRUCT

;----------------------------------------
; Loader routines
;----------------------------------------
        org   $6300
        jmp   >loaddir    ; Load directory entries
        jmp   >load       ; Load file
        jmp   >decompress ; Decompress file
        jmp   >alloc      ; Debug mode for Dynamic Memory Allocation
error   jmp   >dskerr     ; Error
pulse   jmp   >return     ; Load pulse

ptsec   equ   $6100       ; Temporary space for partial sector loading
diskid  fcb   $00         ; Disk id
nsect   fcb   $00         ; Sector counter
track   fcb   $00         ; Track number
sector  fcb   $00         ; Sector number

;---------------------------------------
; Load directory entries
;
; D: [diskid] [face]
; X: [track] [sector]
;---------------------------------------

loaddir
; read first directory sector
        sta   >diskid         ; Save desired directory id for check
        adda  #48+128         ; base index for ascii numbers (works for ten disks max) plus end string bit flag
        sta   messdiskid      ; update message string with id
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
@info   jsr   >info           ; Error
        bra   @retry
; check for directory tag match
!       ldx   #messinsertdisk
        lda   dirheader.tag,y
        cmpa  #'I'
        bne   @info
        lda   dirheader.tag+1,y
        cmpa  #'D'
        bne   @info
        lda   dirheader.tag+2,y
        cmpa  #'X'
        bne   @info
; check for directory id match
        lda   dirheader.diskid,y
        cmpa  >diskid
        bne   @info
; read remaining directory entries
        lda   dirheader.nsector,y ; init nb sectors to read       
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
; input  REG : [X] file number
; input  REG : [B] destination - page number
; input  REG : [U] destination - address
;
; output REG : [A] $ff = empty file
;---------------------------------------
load    pshs  dp,b,x,u
        lda   #$60
        tfr   a,dp               ; Set DP
        jsr   switchpage
* Prepare loading
        jsr   getfileentry
        ldd   direntry.sizea,y   ; check empty file flag
        cmpd  #$ff00
        bne   >
        rts                      ; file is empty, exit
!       ldb   direntry.bitfld,y  ; test if compressed data
        bpl   >                  ; skip if not compressed
        ldd   direntry.coffset,y ; get offset to write data
        leau  d,u
!       ldb   direntry.nsector,y ; Get number of sectors
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
* Exit
ld7     clra                     ; file is not empty
        puls  dp,b,x,u,pc

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
sclist  equ   *-1
        fcb   $01,$0f,$0d,$0b
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
err3    jmp   map.PUTC           ; Display for TO - PUTC

* Display info message and wait a keystroke
info    ldu   #messloc           ; Location
        bsr   err2               ; Display location
        leau  ,x                 ; Message pointer
        bsr   err2               ; Display message
!       jsr   map.KTST
        bcc   <
        rts

* Location message
messloc fcb   $1f,$21,$21
        fcb   $1f,$11,$13        ; 3 lines (11-13)
        fcb   $1b,$47            ; font : white
        fcb   $1b,$51            ; background : red
        fcb   $0c                ; cls
        fcb   $1f,$4c,$4b+$80    ; locate for MO

messIO         fcs   "     I/O|Error"
messinsertdisk fcs   "   Insert disk 0"
messdiskid     equ *-1

;---------------------------------------
; Switch page
;
; B: [destination - page number]
; U: [destination - address]
;---------------------------------------
switchpage
        lda   #$10
        ora   <$6081             ; Set RAM
        sta   <$6081             ; over data
        sta   >$e7e7             ; space
        cmpu  #$4000             ; Skip if
        blo   >                  ; cartridge space
        stb   >map.CF74021.DATA  ; Switch RAM page
        rts
!       orb   #$60               ; Set RAM over cartridge space
        stb   >map.CF74021.CART  ; Switch ram page
        rts

;---------------------------------------
; Get file directory entry
;
; X: [file number]
;---------------------------------------
getfileentry
        ldy   #direntries.data
        tfr   x,d
        _lsld                    ; Scale file id
        _lsld                    ; to dir entry size
        _lsld
        leay  d,y                ; Y ptr to file direntry
        rts

;---------------------------------------
; zx0
;
; X: [file number]
; B: [destination - page number]
; U: [destination - address]
;---------------------------------------

decompress
        jsr   switchpage
        jsr   getfileentry
        ldb   direntry.bitfld,y  ; test if compressed file
        bmi   >                  ; yes, continue
        rts                      ; no, exit
!       ldd   direntry.coffset,y ; get offset to write data
        leax  d,u                ; set x to start of compressed data
        pshs  y
        jsr   >zx0_decompress    ; decompress and set u to end of decompressed data
        puls  y
        lda   #6                 ; copy last 6 bytes
        leax  direntry.cdataz,y  ; set read ptr
        jmp   tfrxua

 align  $6500
 INCLUDE "./engine/compression/zx0/zx0_6809_mega.asm"
 SETDP $ff


;---------------------------------------
; link
;
;
;---------------------------------------
link
        rts


;---------------------------------------
; alloc
;
;
;---------------------------------------
alloc
        ; unit test
        ;jsr   tlsf.ut

        ; switch page
        ldb   #15
        ldu   #0
        jsr   switchpage

        ; init allocator
        ldd   #$4000
        ldx   #$0000
        jsr   tlsf.init

        ; allocate some memory space
        ldd   #63
        jsr   tlsf.malloc

        bra   *

        INCLUDE   "new-engine\memory\tlsf.asm"
        INCLUDE   "new-engine\memory\tlsf.ut.asm"

*---------------------------------------
* Directory entries
*---------------------------------------

dirheader.data
direntries.data equ dirheader.data+sizeof{dirheader}
